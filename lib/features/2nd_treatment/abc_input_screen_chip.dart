import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
// import 'package:provider/provider.dart';
import '../../common/constants.dart';
import '../../widgets/navigation_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';
// import 'package:gad_app_team/data/user_provider.dart';

class GridItem {
  final IconData icon;
  final String label;
  final bool isAdd;
  final Color? borderColor; // per-item border color (when not selected)
  final double? borderWidth; // per-item border width
  const GridItem({
    required this.icon,
    required this.label,
    this.isAdd = false,
    this.borderColor,
    this.borderWidth,
  });
}

class AbcInputScreen extends StatefulWidget {
  // final bool isExampleMode;
  final Map<String, String>? exampleData;
  final String? abcId;
  final DateTime? startedAt;
  final bool isEditMode;

  const AbcInputScreen({
    super.key,
    this.exampleData,
    this.abcId,
    this.startedAt,
    this.isEditMode = false,
  });

  @override
  State<AbcInputScreen> createState() => _AbcInputScreenState();
}

class _AbcInputScreenState extends State<AbcInputScreen> with WidgetsBindingObserver {
  bool _didInit = false;

  bool get _isEditing => widget.isEditMode && (widget.abcId != null && widget.abcId!.isNotEmpty);

  CollectionReference<Map<String, dynamic>> _chipsRef(String uid) {
    final userRef = FirebaseFirestore.instance.collection('chi_users').doc(uid);
    return userRef.collection('custom_abc_chips');
  }

  // --- Sequential ID helpers (per-user, per-collection) ---
  DocumentReference<Map<String, dynamic>> _counterRef(String uid, String collection) {
    return FirebaseFirestore.instance
        .collection('chi_users')
        .doc(uid)
        .collection('counters')
        .doc(collection);
  }

  Future<String> _nextSequencedDocId(String uid, String collection) async {
    // Returns IDs like "abc_models_000001" / "abc_sessions_000001"
    return FirebaseFirestore.instance.runTransaction<String>((tx) async {
      final ref = _counterRef(uid, collection);
      final snap = await tx.get(ref);
      final current = (snap.data()?['seq'] as int?) ?? 0;
      final next = current + 1;
      tx.set(ref, {'seq': next}, SetOptions(merge: true));
      final padded = next.toString().padLeft(6, '0');
      return '${collection}_$padded';
    });
  }
  int _currentStep = 0;
  // Sub-step for C-step questions
  int _currentCSubStep = 0;

  // ===== Session & instrumentation (efficient buffered logging) =====
  String? _sessionId;
  bool _sessionCompleted = false;

  // Counters for summarized metrics (unified)
  int _keyPresses = 0; // all key downs including backspace
  int _touches = 0;
  int _textChanges = 0;
  int _chipToggles = 0; // 칩 토글 누적 카운트
  int _eventSeq = 0;    // 이벤트 문서 순번

  // Step time tracking
  final Map<String, int> _stepTimeMs = {'A': 0, 'B': 0, 'C1': 0, 'C2': 0, 'C3': 0};
  DateTime _stepEnteredAt = DateTime.now();

  // Raw input listening
  final FocusNode _rawFocus = FocusNode();
  final Map<TextEditingController, String> _prevText = {};
  final Map<TextEditingController, Timer> _debouncers = {};

  // Heartbeat & event buffer
  Timer? _heartbeatTimer;
  final List<Map<String, dynamic>> _eventBuffer = [];
  Timer? _flushTimer;
  static const int _bufferMax = 25;
  static const Duration _flushInterval = Duration(seconds: 5);

  // Throttle touch logging
  DateTime? _lastTouchTs;
  static const int _touchThrottleMs = 300;

  // 현재 세션에서 추가된 칩들을 추적하는 Set들
  final Set<String> _currentSessionAChips = {};
  final Set<String> _currentSessionBChips = {};
  final Set<String> _currentSessionCPhysicalChips = {};
  final Set<String> _currentSessionCEmotionChips = {};
  final Set<String> _currentSessionCBehaviorChips = {};

  final TextEditingController _customSymptomController =
      TextEditingController();

  // Emotion and behavior lists for C-step
  final TextEditingController _customEmotionController =
      TextEditingController();

  // Controllers for custom keyword dialogs
  final TextEditingController _customAKeywordController =
      TextEditingController();
  final TextEditingController _customBKeywordController =
      TextEditingController();

  // 1. 신체증상 전용 칩
  final List<GridItem> _physicalChips = [
    GridItem(icon: Icons.bed, label: '불면'),
    GridItem(icon: Icons.favorite, label: '두근거림'),
    GridItem(icon: Icons.sick, label: '메스꺼움'),
    GridItem(icon: Icons.spa, label: '식은땀'),
    GridItem(icon: Icons.waves, label: '호흡곤란'),
    GridItem(icon: Icons.healing, label: '근육긴장'),
    GridItem(icon: Icons.thermostat, label: '열감'),
    GridItem(icon: Icons.bug_report, label: '두통'),
    GridItem(icon: Icons.sports_handball, label: '손떨림'),
    GridItem(icon: Icons.add, label: '추가', isAdd: true),
  ];
  final Set<int> _selectedPhysical = {};

  // 2. 감정 전용 칩
  final List<GridItem> _emotionChips = [
    GridItem(icon: Icons.sentiment_very_dissatisfied, label: '불안'),
    GridItem(icon: Icons.flash_on, label: '분노'),
    GridItem(icon: Icons.sentiment_dissatisfied, label: '슬픔'),
    GridItem(icon: Icons.visibility_off, label: '두려움'),
    GridItem(icon: Icons.sentiment_neutral, label: '당황스러움'),
    GridItem(icon: Icons.person_off, label: '외로움'),
    GridItem(icon: Icons.thumb_down, label: '실망'),
    GridItem(icon: Icons.emoji_people, label: '수치심'),
    GridItem(icon: Icons.sentiment_dissatisfied, label: '걱정됨'),
    GridItem(icon: Icons.add, label: '추가', isAdd: true),
  ];
  // Emotion labels for filtering C-2 chips in feedback
  final Set<int> _selectedEmotion = {};

  // 3. 행동 전용 칩
  late List<GridItem> _behaviorChips;
  final Set<int> _selectedBehavior = {};
  final TextEditingController _addCGridController = TextEditingController();

  // 1. 칩 데이터 및 선택 상태 추가
  final List<GridItem> _aGridChips = [
    GridItem(icon: Icons.work, label: '회의'),
    GridItem(icon: Icons.school, label: '수업'),
    GridItem(icon: Icons.people, label: '모임'),
    // ... (상황에 맞는 칩 추가)
    GridItem(icon: Icons.add, label: '추가', isAdd: true),
  ];
  final Set<int> _selectedAGrid = {};

  final List<GridItem> _bGridChips = [
    GridItem(icon: Icons.psychology, label: '실수할까 걱정'),
    GridItem(icon: Icons.warning, label: '비난받을까 두려움'),
    // ... (생각에 맞는 칩 추가)
    GridItem(icon: Icons.add, label: '추가', isAdd: true),
  ];
  final Set<int> _selectedBGrid = {};

  // 튜토리얼 단계 상태 (0: 칩 안내, 1: 상황 입력 안내, 2: 상황 입력 후 다음 안내, 3: 생각 입력 안내, 4: 생각 입력 후 다음 안내, 5: 결과 입력 안내, 6: 결과 입력 후 다음 안내)
  // int _tutorialStep = 0;
  String? _tutorialError;

  // 사용자 정의 칩 저장 함수
  Future<void> _saveCustomChip(String type, String label) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _chipsRef(user.uid).add({
        'type': type, // 'A', 'B', 'C-physical', 'C-emotion', 'C-behavior'
        'label': label,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('칩 저장 실패: $e');
    }
  }

  // 사용자 정의 칩 불러오기 함수
  Future<void> _loadCustomChips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _chipsRef(user.uid).orderBy('createdAt').get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type'];
        final label = data['label'];

        setState(() {
          switch (type) {
            case 'A':
              if (!_aGridChips.any((chip) => chip.label == label)) {
                _aGridChips.insert(
                  _aGridChips.length - 1,
                  GridItem(icon: Icons.circle, label: label),
                );
              }
              break;
            case 'B':
              if (!_bGridChips.any((chip) => chip.label == label)) {
                _bGridChips.insert(
                  _bGridChips.length - 1,
                  GridItem(icon: Icons.circle, label: label),
                );
              }
              break;
            case 'C-physical':
              if (!_physicalChips.any((chip) => chip.label == label)) {
                _physicalChips.insert(
                  _physicalChips.length - 1,
                  GridItem(icon: Icons.circle, label: label),
                );
              }
              break;
            case 'C-emotion':
              if (!_emotionChips.any((chip) => chip.label == label)) {
                _emotionChips.insert(
                  _emotionChips.length - 1,
                  GridItem(icon: Icons.circle, label: label),
                );
              }
              break;
            case 'C-behavior':
              if (!_behaviorChips.any((chip) => chip.label == label)) {
                _behaviorChips.insert(
                  _behaviorChips.length - 1,
                  GridItem(icon: Icons.circle, label: label),
                );
              }
              break;
          }
        });
      }
    } catch (e) {
      debugPrint('칩 불러오기 실패: $e');
    }
  }

  // 현재 세션에서 추가된 칩인지 확인하는 함수
  bool _isCurrentSessionChip(String type, String label) {
    switch (type) {
      case 'A':
        return _currentSessionAChips.contains(label);
      case 'B':
        return _currentSessionBChips.contains(label);
      case 'C-physical':
        return _currentSessionCPhysicalChips.contains(label);
      case 'C-emotion':
        return _currentSessionCEmotionChips.contains(label);
      case 'C-behavior':
        return _currentSessionCBehaviorChips.contains(label);
      default:
        return false;
    }
  }

  // 현재 세션에서 추가된 칩을 추적하는 함수
  void _addToCurrentSession(String type, String label) {
    switch (type) {
      case 'A':
        _currentSessionAChips.add(label);
        break;
      case 'B':
        _currentSessionBChips.add(label);
        break;
      case 'C-physical':
        _currentSessionCPhysicalChips.add(label);
        break;
      case 'C-emotion':
        _currentSessionCEmotionChips.add(label);
        break;
      case 'C-behavior':
        _currentSessionCBehaviorChips.add(label);
        break;
    }
  }

  // 현재 세션에서 추가된 칩을 제거하는 함수
  void _removeFromCurrentSession(String type, String label) {
    switch (type) {
      case 'A':
        _currentSessionAChips.remove(label);
        break;
      case 'B':
        _currentSessionBChips.remove(label);
        break;
      case 'C-physical':
        _currentSessionCPhysicalChips.remove(label);
        break;
      case 'C-emotion':
        _currentSessionCEmotionChips.remove(label);
        break;
      case 'C-behavior':
        _currentSessionCBehaviorChips.remove(label);
        break;
    }
  }

  // === 편집 모드: 기존 ABC 불러오기 유틸 ===
  List<String> _splitLabels(dynamic v) {
    if (v == null) return const [];
    return v.toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  int _ensureChip(List<GridItem> chips, String label) {
    final idx = chips.indexWhere((c) => c.label == label);
    if (idx != -1) return idx;
    final insertIdx = chips.length - 1; // '추가' 칩 앞에 삽입
    chips.insert(insertIdx, GridItem(icon: Icons.circle, label: label));
    return insertIdx;
  }

  Future<void> _loadExistingAbc() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final abcId = widget.abcId;
      if (uid == null || abcId == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('chi_users')
          .doc(uid)
          .collection('abc_models')
          .doc(abcId)
          .get();

      final data = snap.data();
      if (data == null) return;

      final ae = _splitLabels(data['activatingEvent']);
      final bl = _splitLabels(data['belief']);
      final c1 = _splitLabels(data['c1_physical']);
      final c2 = _splitLabels(data['c2_emotion']);
      final c3 = _splitLabels(data['c3_behavior']);

      setState(() {

        // A: 단일 선택
        if (ae.isNotEmpty) {
          final idx = _ensureChip(_aGridChips, ae.first);
          _selectedAGrid
            ..clear()
            ..add(idx);
        }
        // B: 멀티 선택 가능
        _selectedBGrid.clear();
        for (final s in bl) {
          final idx = _ensureChip(_bGridChips, s);
          _selectedBGrid.add(idx);
        }
        // C1
        _selectedPhysical.clear();
        for (final s in c1) {
          final idx = _ensureChip(_physicalChips, s);
          _selectedPhysical.add(idx);
        }
        // C2
        _selectedEmotion.clear();
        for (final s in c2) {
          final idx = _ensureChip(_emotionChips, s);
          _selectedEmotion.add(idx);
        }
        // C3
        _selectedBehavior.clear();
        for (final s in c3) {
          final idx = _ensureChip(_behaviorChips, s);
          _selectedBehavior.add(idx);
        }
      });
    } catch (e) {
      debugPrint('기존 ABC 불러오기 실패: $e');
    }
  }

  /// Wrap dialog content to match the same viewport width calculation as AspectViewport (aspect = 9/16).
  Widget _viewportWrap({
    required Widget child,
    double horizontal = 24,
    double vertical = 28,
  }) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double aspect = 9 / 16;
          final double usableH = constraints.maxHeight;
          double targetW = constraints.maxWidth;
          double targetH = targetW / aspect;
          if (targetH > usableH) {
            targetH = usableH;
            targetW = targetH * aspect;
          }
          return SizedBox(
            width: targetW,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stepEnteredAt = DateTime.now();
    _startSession();
    _attachTextWatchers();

    // 기본 칩 세팅
    _behaviorChips = [
      GridItem(icon: Icons.event_busy, label: '결석'),
      GridItem(icon: Icons.event_note, label: '약속 안 잡기'),
      GridItem(icon: Icons.phone_disabled, label: '전화 안 받기'),
      GridItem(icon: Icons.mark_email_unread, label: '문자 안 읽기'),
      GridItem(icon: Icons.event_seat, label: '뒷자리나 구석에 앉기'),
      GridItem(icon: Icons.question_mark, label: '질문 피하기'),
      GridItem(icon: Icons.phone_android, label: '휴대폰 만지기'),
      GridItem(icon: Icons.visibility_off, label: '시선 피하기'),
      GridItem(icon: Icons.bed, label: '잠 자기'),
      GridItem(icon: Icons.sports_esports, label: '게임'),
      // 튜토리얼 칩 추가
      // if (widget.isExampleMode)
      //   GridItem(icon: Icons.circle, label: '자전거를 타지 않았어요'),
      GridItem(icon: Icons.add, label: '추가', isAdd: true),
    ];

    // 사용자 정의 칩 불러오기
    // if (!widget.isExampleMode) {
      _loadCustomChips();
    // }

    if (_isEditing) {
      _loadExistingAbc();
    }

    // 튜토리얼 모드 전용 기본 칩 세팅
    // if (widget.isExampleMode) {
    //   if (!_aGridChips.any((c) => c.label == '자전거를 타려고 함')) {
    //     _aGridChips.insert(
    //       _aGridChips.length - 1,
    //       GridItem(icon: Icons.circle, label: '자전거를 타려고 함'),
    //     );
    //   }
    //   if (!_bGridChips.any((c) => c.label == '넘어질까봐 두려움')) {
    //     _bGridChips.insert(
    //       _bGridChips.length - 1,
    //       GridItem(icon: Icons.circle, label: '넘어질까봐 두려움'),
    //     );
    //   }
    //   if (!_behaviorChips.any((c) => c.label == '자전거를 타지 않았어요')) {
    //     _behaviorChips.insert(
    //       _behaviorChips.length - 1,
    //       GridItem(icon: Icons.circle, label: '자전거를 타지 않았어요'),
    //     );
    //   }
    //   _tutorialStep = 0;
    //   _tutorialError = null;
    // }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
    }
  }

  void _nextStep() {
    final fromKey = _currentStepKey();
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
        if (_currentStep == 2) _currentCSubStep = 0;
      });
      _onStepChange(fromKey, _currentStepKey());
    } else {
      if (_currentCSubStep < 2) {
        setState(() {
          _currentCSubStep++;
        });
        _onStepChange(fromKey, _currentStepKey());
      }
    }
  }

  void _previousStep() {
    final fromKey = _currentStepKey();
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _currentCSubStep = 0;
      });
      _onStepChange(fromKey, _currentStepKey());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _markAbandoned('app_background');
    }
  }

  void _addAKeyword() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
            backgroundColor: AppColors.indigo50,
            insetPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: _viewportWrap(
              horizontal: 20,
              vertical: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'A. 오늘 있었던 기억에 남는 일은 무엇인가요?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.indigo,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  // Combine input box and first suffix on one line, then break
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // White input box
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.indigo.shade100),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _customAKeywordController,
                              decoration: const InputDecoration(
                                hintText: '예: 자전거 타기',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(이)라는 일이 있었습니다.',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                  if (_tutorialError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _tutorialError!,
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final val = _customAKeywordController.text.trim();
                      // if (widget.isExampleMode && _tutorialStep == 1) {
                      //   if (val == '자전거를 타려고 함') {
                      //     setState(() {
                      //       _aGridChips.insert(
                      //         _aGridChips.length - 1,
                      //         GridItem(icon: Icons.circle, label: val),
                      //       );
                      //       _tutorialStep = 2;
                      //       _tutorialError = null;
                      //     });
                      //     _customAKeywordController.clear();
                      //     Navigator.pop(context);
                      //   } else {
                      //     setState(() {
                      //       _tutorialError = '예시와 똑같이 입력해보세요!';
                      //     });
                      //   }
                      //   return;
                      // }
                      if (val.isNotEmpty) {
                        // 중복 체크
                        if (_isDuplicateChip('A', val)) {
                          _showDuplicateAlert(context);
                          return;
                        }
                        setState(() {
                          _aGridChips.insert(
                            _aGridChips.length - 1,
                            GridItem(icon: Icons.circle, label: val),
                          );
                          // 현재 세션에 추가된 칩으로 추적
                          _addToCurrentSession('A', val);
                        });
                        _customAKeywordController.clear();
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('추가'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _addBKeyword() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppColors.indigo50,
            insetPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: _viewportWrap(
              horizontal: 24,
              vertical: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'B. 그 상황에서 어떤 생각이 떠올랐나요?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.indigo,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  // Combine input box and first suffix on one line, then break
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // White input box
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.indigo.shade100),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _customBKeywordController,
                              decoration: const InputDecoration(
                                hintText: '예: 넘어질까봐 두려움',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(이)라는 생각이 떠올랐습니다.',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                  if (_tutorialError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _tutorialError!,
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final val = _customBKeywordController.text.trim();
                      // if (widget.isExampleMode && _tutorialStep == 3) {
                      //   if (val == '넘어질까봐 두려움') {
                      //     setState(() {
                      //       _bGridChips.insert(
                      //         _bGridChips.length - 1,
                      //         GridItem(icon: Icons.circle, label: val),
                      //       );
                      //       _tutorialStep = 4;
                      //       _tutorialError = null;
                      //     });
                      //     _customBKeywordController.clear();
                      //     Navigator.pop(context);
                      //   } else {
                      //     setState(() {
                      //       _tutorialError = '예시와 똑같이 입력해보세요!';
                      //     });
                      //   }
                      //   return;
                      // }
                      if (val.isNotEmpty) {
                        // 중복 체크
                        if (_isDuplicateChip('B', val)) {
                          _showDuplicateAlert(context);
                          return;
                        }
                        setState(() {
                          _bGridChips.insert(
                            _bGridChips.length - 1,
                            GridItem(icon: Icons.circle, label: val),
                          );
                          // 현재 세션에 추가된 칩으로 추적
                          _addToCurrentSession('B', val);
                        });
                        _customBKeywordController.clear();
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('추가'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _addCustomSymptom() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
            backgroundColor: AppColors.indigo50,
            insetPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: _viewportWrap(
              horizontal: 20,
              vertical: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'C-1. 그때 몸에서 어떤 변화가 있었나요?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.indigo,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  // Combine input box and first suffix on one line, then break
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // White input box
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.indigo.shade100),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _customSymptomController,
                              decoration: const InputDecoration(
                                hintText: '예: 가슴 두근거림',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(이)라는 변화가 있었습니다.',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final value = _customSymptomController.text.trim();
                      if (value.isNotEmpty) {
                        // 중복 체크
                        if (_isDuplicateChip('C-physical', value)) {
                          _showDuplicateAlert(context);
                          return;
                        }
                        setState(() {
                          _physicalChips.insert(
                            _physicalChips.length - 1,
                            GridItem(icon: Icons.circle, label: value),
                          );
                          // 현재 세션에 추가된 칩으로 추적
                          _addToCurrentSession('C-physical', value);
                        });
                        _customSymptomController.clear();
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('추가'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _addEmotion() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppColors.indigo50,
            insetPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: _viewportWrap(
              horizontal: 24,
              vertical: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'C-2. 그 순간 어떤 감정을 느꼈나요?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.indigo,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  // Combine input box and first suffix on one line, then break
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // White input box
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.indigo.shade100),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _customEmotionController,
                              decoration: const InputDecoration(
                                hintText: '예: 두려움',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(이)라는 감정을 느꼈습니다.',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final val = _customEmotionController.text.trim();
                      if (val.isNotEmpty) {
                        // 중복 체크
                        if (_isDuplicateChip('C-emotion', val)) {
                          _showDuplicateAlert(context);
                          return;
                        }
                        setState(() {
                          _emotionChips.insert(
                            _emotionChips.length - 1,
                            GridItem(icon: Icons.circle, label: val),
                          );
                          // 현재 세션에 추가된 칩으로 추적
                          _addToCurrentSession('C-emotion', val);
                        });
                        _customEmotionController.clear();
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('추가'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _logEvent('system_back', {
            'step': _currentStep,
            'cSubStep': _currentCSubStep,
          });
          _markAbandoned('system_back');
        }
      },
      child: AspectViewport(
        aspect: 9 / 16,
        background: Colors.grey.shade100,
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: CustomAppBar(title: _isEditing ? '일기 수정' : '일기 쓰기'),
          body: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
            child: SafeArea(
              child: KeyboardListener(
                focusNode: _rawFocus,
                onKeyEvent: (KeyEvent event) {
                  if (event is KeyDownEvent) {
                    _keyPresses++;
                    final isBackspace = event.logicalKey == LogicalKeyboardKey.backspace;
                    if (isBackspace) {
                      _logEvent('key', {
                        'logicalKey': event.logicalKey.keyLabel,
                        'backspace': true,
                      });
                    }
                  }
                },
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (e) {
                    final now = DateTime.now();
                    if (_lastTouchTs == null ||
                        now.difference(_lastTouchTs!).inMilliseconds > _touchThrottleMs) {
                      _touches++;
                      _logEvent('touch', {'x': e.position.dx, 'y': e.position.dy});
                      _lastTouchTs = now;
                    } else {
                      _touches++;
                    }
                  },
                  child: _buildMainContent(),
                ),
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: NavigationButtons(
              leftLabel: '이전',
              rightLabel: _currentStep < 2
                  ? '다음'
                  : (_currentCSubStep < 2 ? '다음' : (_isEditing ? '수정' : '저장')),
              onBack: () {
                if (_currentStep == 0) {
                  _markAbandoned('nav_back');
                  Navigator.pop(context);
                } else if (_currentStep == 2 && _currentCSubStep > 0) {
                  setState(() => _currentCSubStep--);
                } else {
                  _previousStep();
                }
              },
              onNext: () async {
                if (_currentStep < 2) {
                  _nextStep();
                } else {
                  if (_currentCSubStep < 2) {
                    _nextStep();
                  } else {
                    await _saveAbcAndExit();
                  }
                }
              },
            ),
          ),
        ),)
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // 2. A-B-C 인디케이터 (가로선 포함)
          _buildAbcStepIndicator(),
          const SizedBox(height: 24),
          // 3. 단계별 질문/입력 UI
          _buildStepContent(),
        ],
      ),
    );
  }

  // 인디케이터(가로선 포함)
  Widget _buildAbcStepIndicator() {
    List<String> labels = ['A', 'B', 'C'];
    List<String> titles = ['상황', '생각', '결과'];
    List<String> descriptions = [
      '반응을 유발하는 사건이나 상황',
      '사건에 대한 해석이나 생각',
      '결과로 나타나는 감정이나 행동',
    ];
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: const Color.fromARGB(255, 242, 243, 254),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(5, (i) {
            if (i % 2 == 1) {
              // Horizontal line between steps - always active color
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(height: 2, color: AppColors.indigo),
                ),
              );
            } else {
              int idx = i ~/ 2;
              final isActive = _currentStep == idx;
              return Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Container(
                      width: isActive ? 64 : 48,
                      height: isActive ? 64 : 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isActive ? AppColors.indigo : Colors.grey.shade300,
                        boxShadow:
                            isActive
                                ? [
                                  BoxShadow(
                                    color: AppColors.indigo.withValues(
                                      alpha: 0.18,
                                    ),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                                : [],
                      ),
                      child: Center(
                        child: Text(
                          labels[idx],
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: isActive ? 22 : 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      titles[idx],
                      style: TextStyle(
                        color: isActive ? AppColors.indigo : Colors.grey[600],
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descriptions[idx],
                      style: const TextStyle(color: Colors.black, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
          }),
        ),
      ),
    );
  }

  // 단계별 질문/입력 UI
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepA();
      case 1:
        return _buildStepB();
      case 2:
        return _buildStepC();
      default:
        return const SizedBox.shrink();
    }
  }

  // 튜토리얼 안내 인라인 메시지 위젯
  // Widget _buildTutorialInlineMessage() {
  //   String text = '';
  //   switch (_tutorialStep) {
  //     case 0:
  //       text = "위에 '자전거를 타려고 함' 칩을 눌러 선택해보세요!";
  //       break;
  //     case 1:
  //       text = "선택한 뒤 아래의 '다음' 버튼을 눌러주세요!";
  //       break;
  //     case 2:
  //       text = "입력한 내용을 선택하고\n'다음' 버튼을 눌러주세요!";
  //       break;
  //     case 3:
  //       text = "위에 '넘어질까봐 두려움' 칩을 눌러 선택해보세요!";
  //       break;
  //     case 4:
  //       text = "선택한 뒤 아래의 '다음' 버튼을 눌러주세요!";
  //       break;
  //     case 5:
  //       text = "위에 '자전거를 타지 않았어요' 칩을 눌러 선택해보세요!";
  //       break;
  //     case 6:
  //       text = "선택한 뒤 '확인' 버튼을 눌러주세요!";
  //       break;
  //     default:
  //       return SizedBox.shrink();
  //   }
  //   return Align(
  //     alignment: Alignment.center,
  //     child: Padding(
  //       padding: const EdgeInsets.symmetric(horizontal: 24),
  //       child: Container(
  //         margin: const EdgeInsets.only(top: 8),
  //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //         decoration: BoxDecoration(
  //           color: Colors.white.withValues(alpha: 0.95),
  //           borderRadius: BorderRadius.circular(16),
  //           boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
  //         ),
  //         child: Text(
  //           text,
  //           style: const TextStyle(
  //             color: Colors.indigo,
  //             fontWeight: FontWeight.bold,
  //             fontSize: 16,
  //           ),
  //           textAlign: TextAlign.center,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildStepA() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A. 오늘 있었던 기억에 남는 일은 무엇인가요?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_aGridChips.length, (i) {
            if (i == _aGridChips.length - 1) {
              // Add chip
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ActionChip(
                    avatar: const Icon(
                      Icons.add,
                      size: 18,
                      color: AppColors.indigo,
                    ),
                    label: const Text(
                      '추가',
                      style: TextStyle(color: AppColors.indigo, fontSize: 13.5),
                    ),
                    backgroundColor: AppColors.indigo50,
                    side: BorderSide(color: AppColors.indigo, width: 1),
                    onPressed:_addAKeyword,
                    // onPressed: widget.isExampleMode ? null : _addAKeyword,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                  ),
                ],
              );
            } else {
              final item = _aGridChips[i];
              final isSelected = _selectedAGrid.contains(i);
              final isCurrentSessionChip = _isCurrentSessionChip(
                'A',
                item.label,
              );
              return FilterChip(
                avatar: Icon(
                  item.icon,
                  size: 18,
                  color: isSelected ? AppColors.white : Colors.grey.shade800,
                ),
                label: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.white : Colors.grey.shade800,
                    fontSize: 13.5,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (isSelected) {
                      _selectedAGrid.remove(i);
                    } else {
                      _selectedAGrid
                        ..clear()
                        ..add(i);
                    }
                    _logEvent('chip_toggle', {
                      'section': 'A',
                      'label': item.label,
                      'selected': !isSelected,
                      'origin': _isCurrentSessionChip('A', item.label) ? 'custom' : 'preset',
                    });
                    _chipToggles++;
                  });
                },
                showCheckmark: false,
                selectedColor: AppColors.indigo,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.indigo
                      : (item.borderColor ?? Colors.grey.shade800),
                  width: item.borderWidth ?? 1,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                onDeleted:
                    isCurrentSessionChip
                        ? () => _deleteCustomChip('A', item.label, i)
                        : null,
                deleteIcon:
                    isCurrentSessionChip
                        ? const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.redAccent,
                        )
                        : null,
              );
            }
          }),
        ),
        // 아래에 여백 추가
        // if (widget.isExampleMode && (_tutorialStep >= 0 && _tutorialStep <= 1))
        //   SizedBox(height: 120), // 원하는 만큼 조절
        // if (widget.isExampleMode && (_tutorialStep >= 0 && _tutorialStep <= 1))
          // _buildTutorialInlineMessage(),
      ],
    );
  }

  Widget _buildStepB() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'B. 그 상황에서 어떤 생각이 떠올랐나요?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_bGridChips.length, (i) {
            if (i == _bGridChips.length - 1) {
              return ActionChip(
                avatar: const Icon(
                  Icons.add,
                  size: 18,
                  color: AppColors.indigo,
                ),
                label: const Text(
                  '추가',
                  style: TextStyle(color: AppColors.indigo, fontSize: 13.5),
                ),
                backgroundColor: AppColors.indigo50,
                side: BorderSide(color: AppColors.indigo, width: 1),
                onPressed: _addBKeyword,
                // onPressed: widget.isExampleMode ? null : _addBKeyword,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              );
            } else {
              final item = _bGridChips[i];
              final isSelected = _selectedBGrid.contains(i);
              final isCurrentSessionChip = _isCurrentSessionChip(
                'B',
                item.label,
              );
              return FilterChip(
                avatar: Icon(
                  item.icon,
                  size: 18,
                  color: isSelected ? AppColors.white : Colors.grey.shade800,
                ),
                label: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.white : Colors.grey.shade800,
                    fontSize: 13.5,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    isSelected
                        ? _selectedBGrid.remove(i)
                        : _selectedBGrid.add(i);
                    _logEvent('chip_toggle', {
                      'section': 'B',
                      'label': item.label,
                      'selected': !isSelected,
                      'origin': _isCurrentSessionChip('B', item.label) ? 'custom' : 'preset',
                    });
                    _chipToggles++;
                  });
                },
                showCheckmark: false,
                selectedColor: AppColors.indigo,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.indigo
                      : (item.borderColor ?? Colors.grey.shade800),
                  width: item.borderWidth ?? 1,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                onDeleted:
                    isCurrentSessionChip
                        ? () => _deleteCustomChip('B', item.label, i)
                        : null,
                deleteIcon:
                    isCurrentSessionChip
                        ? const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.redAccent,
                        )
                        : null,
              );
            }
          }),
        ),
        // if (widget.isExampleMode && (_tutorialStep >= 3 && _tutorialStep <= 4))
          // SizedBox(height: 120),
        // if (widget.isExampleMode && (_tutorialStep >= 3 && _tutorialStep <= 4))
          // _buildTutorialInlineMessage(),
      ],
    );
  }

  Widget _buildStepC() {
    switch (_currentCSubStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'C-1. 그때 몸에서 어떤 변화가 있었나요?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            // if (widget.isExampleMode)
            //   Container(
            //     margin: const EdgeInsets.only(bottom: 16),
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 16,
            //       vertical: 12,
            //     ),
            //     decoration: BoxDecoration(
            //       color: Colors.white.withValues(alpha: 0.95),
            //       borderRadius: BorderRadius.circular(16),
            //       boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            //     ),
            //     child: const Text(
            //       '현재 C단계는 신체증상, 감정, 행동을 각각 입력하는 단계입니다.\n각 항목을 차례로 진행해 주세요!',
            //       style: TextStyle(
            //         color: Colors.indigo,
            //         fontWeight: FontWeight.bold,
            //         fontSize: 15,
            //       ),
            //       textAlign: TextAlign.center,
            //     ),
            //   ),
            _buildCPhysicalChips(),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'C-2. 그 순간 어떤 감정을 느꼈나요?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildCEmotionChips(),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'C-3. 그래서 어떤 행동을 했나요?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildCBehaviorChips(),
            // if (widget.isExampleMode &&
            //     (_tutorialStep >= 5 && _tutorialStep <= 6))
            //   SizedBox(height: 20),
            // if (widget.isExampleMode &&
            //     (_tutorialStep >= 5 && _tutorialStep <= 6))
              // _buildTutorialInlineMessage(),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCPhysicalChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_physicalChips.length, (i) {
        if (i == _physicalChips.length - 1) {
          return ActionChip(
            avatar: const Icon(Icons.add, size: 18, color: AppColors.indigo),
            label: const Text(
              '추가',
              style: TextStyle(color: AppColors.indigo, fontSize: 13.5),
            ),
            backgroundColor: AppColors.indigo50,
            side: BorderSide(color: AppColors.indigo, width: 1),
            onPressed: _addCustomSymptom,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          );
        } else {
          final item = _physicalChips[i];
          final isSelected = _selectedPhysical.contains(i);
          final isCurrentSessionChip = _isCurrentSessionChip(
            'C-physical',
            item.label,
          );
          return FilterChip(
            avatar: Icon(
              item.icon,
              size: 18,
              color: isSelected ? AppColors.white : Colors.grey.shade800,
            ),
            label: Text(
              item.label,
              style: TextStyle(
                color: isSelected ? AppColors.white : Colors.grey.shade800,
                fontSize: 13.5,
              ),
            ),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                isSelected
                    ? _selectedPhysical.remove(i)
                    : _selectedPhysical.add(i);
                _logEvent('chip_toggle', {
                  'section': 'C1',
                  'label': item.label,
                  'selected': !isSelected,
                  'origin': _isCurrentSessionChip('C-physical', item.label) ? 'custom' : 'preset',
                });
                _chipToggles++;
              });
            },
            showCheckmark: false,
            selectedColor: AppColors.indigo,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected
                  ? AppColors.indigo
                  : (item.borderColor ?? Colors.grey.shade800),
              width: item.borderWidth ?? 1,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            onDeleted:
                isCurrentSessionChip
                    ? () => _deleteCustomChip('C-physical', item.label, i)
                    : null,
            deleteIcon:
                isCurrentSessionChip
                    ? const Icon(Icons.close, size: 18, color: Colors.redAccent)
                    : null,
          );
        }
      }),
    );
  }

  Widget _buildCEmotionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_emotionChips.length, (i) {
        if (i == _emotionChips.length - 1) {
          return ActionChip(
            avatar: const Icon(Icons.add, size: 18, color: AppColors.indigo),
            label: const Text(
              '추가',
              style: TextStyle(color: AppColors.indigo, fontSize: 13.5),
            ),
            backgroundColor: AppColors.indigo50,
            side: BorderSide(color: AppColors.indigo, width: 1),
            onPressed: _addEmotion,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          );
        } else {
          final item = _emotionChips[i];
          final isSelected = _selectedEmotion.contains(i);
          final isCurrentSessionChip = _isCurrentSessionChip(
            'C-emotion',
            item.label,
          );
          return FilterChip(
            avatar: Icon(
              item.icon,
              size: 18,
              color: isSelected ? AppColors.white : Colors.grey.shade800,
            ),
            label: Text(
              item.label,
              style: TextStyle(
                color: isSelected ? AppColors.white : Colors.grey.shade800,
                fontSize: 13.5,
              ),
            ),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                isSelected
                    ? _selectedEmotion.remove(i)
                    : _selectedEmotion.add(i);
                _logEvent('chip_toggle', {
                  'section': 'C2',
                  'label': item.label,
                  'selected': !isSelected,
                  'origin': _isCurrentSessionChip('C-emotion', item.label) ? 'custom' : 'preset',
                });
                _chipToggles++;
              });
            },
            showCheckmark: false,
            selectedColor: AppColors.indigo,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected
                  ? AppColors.indigo
                  : (item.borderColor ?? Colors.grey.shade800),
              width: item.borderWidth ?? 1,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            onDeleted:
                isCurrentSessionChip
                    ? () => _deleteCustomChip('C-emotion', item.label, i)
                    : null,
            deleteIcon:
                isCurrentSessionChip
                    ? const Icon(Icons.close, size: 18, color: Colors.redAccent)
                    : null,
          );
        }
      }),
    );
  }

  Widget _buildCBehaviorChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_behaviorChips.length, (i) {
        if (i == _behaviorChips.length - 1) {
          return ActionChip(
            avatar: const Icon(Icons.add, size: 18, color: AppColors.indigo),
            label: const Text(
              '추가',
              style: TextStyle(color: AppColors.indigo, fontSize: 13.5),
            ),
            backgroundColor: AppColors.indigo50,
            side: BorderSide(color: AppColors.indigo, width: 1),
            onPressed: _showAddCGridDialog,
            // onPressed: widget.isExampleMode ? null : _showAddCGridDialog,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          );
        } else {
          final item = _behaviorChips[i];
          final isSelected = _selectedBehavior.contains(i);
          final isCurrentSessionChip = _isCurrentSessionChip(
            'C-behavior',
            item.label,
          );
          return FilterChip(
            avatar: Icon(
              item.icon,
              size: 18,
              color: isSelected ? AppColors.white : Colors.grey.shade800,
            ),
            label: Text(
              item.label,
              style: TextStyle(
                color: isSelected ? AppColors.white : Colors.grey.shade800,
                fontSize: 13.5,
              ),
            ),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                isSelected
                    ? _selectedBehavior.remove(i)
                    : _selectedBehavior.add(i);
                _logEvent('chip_toggle', {
                  'section': 'C3',
                  'label': item.label,
                  'selected': !isSelected,
                  'origin': _isCurrentSessionChip('C-behavior', item.label) ? 'custom' : 'preset',
                });
                _chipToggles++;
              });
            },
            showCheckmark: false,
            selectedColor: AppColors.indigo,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected
                  ? AppColors.indigo
                  : (item.borderColor ?? Colors.grey.shade800),
              width: item.borderWidth ?? 1,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            onDeleted:
                isCurrentSessionChip
                    ? () => _deleteCustomChip('C-behavior', item.label, i)
                    : null,
            deleteIcon:
                isCurrentSessionChip
                    ? const Icon(Icons.close, size: 18, color: Colors.redAccent)
                    : null,
          );
        }
      }),
    );
  }

  void _showAddCGridDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppColors.indigo50,
            insetPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: _viewportWrap(
              horizontal: 24,
              vertical: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'C-3. 그래서 어떤 행동을 했나요?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.indigo,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  // Combine input box and first suffix on one line, then break
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // White input box
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.indigo.shade100),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _addCGridController,
                              decoration: const InputDecoration(
                                hintText: '예: 자전거 끌고가기',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(이)라는 행동을 했습니다.',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                  if (_tutorialError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _tutorialError!,
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final value = _addCGridController.text.trim();
                      // if (widget.isExampleMode && _tutorialStep == 5) {
                      //   if (value == '자전거를 타지 않았어요') {
                      //     setState(() {
                      //       _behaviorChips.insert(
                      //         _behaviorChips.length - 1,
                      //         GridItem(icon: Icons.circle, label: value),
                      //       );
                      //       _tutorialStep = 6;
                      //       _tutorialError = null;
                      //     });
                      //     _addCGridController.clear();
                      //     Navigator.pop(context);
                      //   } else {
                      //     setState(() {
                      //       _tutorialError = '예시와 똑같이 입력해보세요!';
                      //     });
                      //   }
                      //   return;
                      // }
                      if (value.isNotEmpty) {
                        // 중복 체크
                        if (_isDuplicateChip('C-behavior', value)) {
                          _showDuplicateAlert(context);
                          return;
                        }
                        setState(() {
                          _behaviorChips.insert(
                            _behaviorChips.length - 1,
                            GridItem(icon: Icons.circle, label: value),
                          );
                          // 현재 세션에 추가된 칩으로 추적
                          _addToCurrentSession('C-behavior', value);
                        });
                        _addCGridController.clear();
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('추가'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // 중복 체크 함수 추가
  bool _isDuplicateChip(String type, String label) {
    switch (type) {
      case 'A':
        return _aGridChips.any((chip) => chip.label == label);
      case 'B':
        return _bGridChips.any((chip) => chip.label == label);
      case 'C-physical':
        return _physicalChips.any((chip) => chip.label == label);
      case 'C-emotion':
        return _emotionChips.any((chip) => chip.label == label);
      case 'C-behavior':
        return _behaviorChips.any((chip) => chip.label == label);
      default:
        return false;
    }
  }

  // 중복 알림 다이얼로그 표시
  void _showDuplicateAlert(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('중복된 항목'),
            content: const Text('이미 동일한 내용이 존재합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  // 3. Firestore에 이번 세션에서 "추가" 버튼으로 만든 칩만 저장 (중복 방지)
  Future<void> _saveSelectedChipsToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 현재 사용자 커스텀 칩 목록(기존 저장본) 조회
    final snapshot = await _chipsRef(user.uid).get();
    final existing = snapshot.docs
        .map((doc) => {'type': doc['type'], 'label': doc['label']})
        .toSet();

    Future<void> saveIfNew(String type, String label) async {
      final key = {'type': type, 'label': label};
      if (!existing.contains(key)) {
        await _saveCustomChip(type, label);
        existing.add(key);
      }
    }

    // ✅ 이번 세션에서 "추가" 버튼으로 새로 만든 칩들만 저장
    for (final label in _currentSessionAChips) {
      await saveIfNew('A', label);
    }
    for (final label in _currentSessionBChips) {
      await saveIfNew('B', label);
    }
    for (final label in _currentSessionCPhysicalChips) {
      await saveIfNew('C-physical', label);
    }
    for (final label in _currentSessionCEmotionChips) {
      await saveIfNew('C-emotion', label);
    }
    for (final label in _currentSessionCBehaviorChips) {
      await saveIfNew('C-behavior', label);
    }
  }

  // Firestore에서 커스텀 칩 삭제 함수
  Future<void> _deleteCustomChip(String type, String label, int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 현재 세션에서 추가된 칩인 경우에만 Firestore에서 삭제
    if (_isCurrentSessionChip(type, label)) {
      final query = await _chipsRef(user.uid)
          .where('type', isEqualTo: type)
          .where('label', isEqualTo: label)
          .get();
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    }

    setState(() {
      switch (type) {
        case 'A':
          _aGridChips.removeAt(index);
          break;
        case 'B':
          _bGridChips.removeAt(index);
          break;
        case 'C-physical':
          _physicalChips.removeAt(index);
          break;
        case 'C-emotion':
          _emotionChips.removeAt(index);
          break;
        case 'C-behavior':
          _behaviorChips.removeAt(index);
          break;
      }
      // 현재 세션 추적에서도 제거
      _removeFromCurrentSession(type, label);
    });
  }
  Future<void> _saveAbcAndExit() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 정보가 없어 저장할 수 없습니다.')),
        );
        return;
      }

      final firestore = FirebaseFirestore.instance;

      // 사용자 문서 머지 생성 (존재 보장)
      await firestore.collection('chi_users').doc(userId).set({}, SetOptions(merge: true));

      // ABC 모델 데이터 구성 (기본 필드)
      final c1 = _selectedPhysical.map((i) => _physicalChips[i].label).join(', ');
      final c2 = _selectedEmotion.map((i) => _emotionChips[i].label).join(', ');
      final c3 = _selectedBehavior.map((i) => _behaviorChips[i].label).join(', ');
      final activatingEvent = _selectedAGrid.map((i) => _aGridChips[i].label).join(', ');
      final belief          = _selectedBGrid.map((i) => _bGridChips[i].label).join(', ');

      final baseData = {
        'activatingEvent': activatingEvent,
        'belief'         : belief,
        'c1_physical'    : c1,
        'c2_emotion'     : c2,
        'c3_behavior'    : c3,
      };

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_isEditing ? '수정' : '저장'),
          content: Text(_isEditing ? '수정 내용을 저장하시겠습니까?' : '작성한 일기를 저장하시겠습니까?'),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(_isEditing ? '수정' : '확인'),
              onPressed: () async {
                if (_isEditing) {
                  // 편집: 기존 문서에 덮어쓰기 (백업은 onEdit에서 수행)
                  final docRef = firestore
                      .collection('chi_users')
                      .doc(userId)
                      .collection('abc_models')
                      .doc(widget.abcId!);

                  final payload = {
                    ...baseData,
                    'startedAt': widget.startedAt,
                    'completedAt': FieldValue.serverTimestamp(),
                  };
                  await docRef.set(payload, SetOptions(merge: false));
                } else {
                  // 신규: 시퀀스 ID로 생성
                  final newId = await _nextSequencedDocId(userId, 'abc_models');
                  await firestore
                      .collection('chi_users')
                      .doc(userId)
                      .collection('abc_models')
                      .doc(newId)
                      .set({
                        ...baseData,
                        'startedAt'  : widget.startedAt,
                        'completedAt': FieldValue.serverTimestamp(),
                      });
                }

                await _saveSelectedChipsToFirestore();

                // 세션 완료 처리: 누적 시간/카운터 반영 및 이벤트 버퍼 플러시
                final fromKey = _currentStepKey();
                _bumpStepTimeToNow(fromKey);
                await _flushEvents();

                if (_sessionId != null) {
                  await firestore
                      .collection('chi_users')
                      .doc(userId)
                      .collection('abc_sessions')
                      .doc(_sessionId)
                      .set({
                    'status': 'completed',
                    'screen': 'AbcInputScreen_chip/${_currentStepKey()}',
                    'endedAt': FieldValue.serverTimestamp(),
                    'durationMs': widget.startedAt != null
                        ? DateTime.now().millisecondsSinceEpoch - widget.startedAt!.millisecondsSinceEpoch
                        : null,
                    'keyPresses': _keyPresses,
                    'touches': _touches,
                    'textChanges': _textChanges,
                    'chipToggles': _chipToggles,
                    'stepTimeMs': _stepTimeMs,
                  }, SetOptions(merge: true));
                  await _logEvent('session_completed', {});
                  await _flushEvents();
                }
                _sessionCompleted = true;

                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('ABC 모델 저장 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // ==== Efficient session logging and helpers (class-scope) ====
  String _currentStepKey() {
    if (_currentStep == 0) return 'A';
    if (_currentStep == 1) return 'B';
    switch (_currentCSubStep) {
      case 0:
        return 'C1';
      case 1:
        return 'C2';
      default:
        return 'C3';
    }
  }

  void _bumpStepTimeToNow(String stepKey) {
    final now = DateTime.now();
    final delta = now.difference(_stepEnteredAt).inMilliseconds;
    _stepTimeMs[stepKey] = (_stepTimeMs[stepKey] ?? 0) + (delta < 0 ? 0 : delta);
    _stepEnteredAt = now;
  }

  Future<void> _startSession() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final userDoc = FirebaseFirestore.instance.collection('chi_users').doc(uid);
      final sessions = userDoc.collection('abc_sessions');
      final newSessionId = await _nextSequencedDocId(uid, 'abc_sessions');
      await sessions.doc(newSessionId).set({
        'status': 'in_progress',
        'screen': 'AbcInputScreen_chip',
        'experimentCondition': 'Chip_input',
        'startedAt': widget.startedAt ?? FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _sessionId = newSessionId;

      _eventBuffer.clear();
      _flushTimer?.cancel();
      _flushTimer = Timer.periodic(_flushInterval, (_) => _flushEvents());

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        final u = FirebaseAuth.instance.currentUser?.uid;
        if (u == null || _sessionId == null) return;
        await FirebaseFirestore.instance
            .collection('chi_users')
            .doc(u)
            .collection('abc_sessions')
            .doc(_sessionId)
            .set({'heartbeatAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      });

      await _logEvent('session_start', {
        'step': _currentStep,
        'cSubStep': _currentCSubStep,
      });
    } catch (e) {
      debugPrint('세션 시작 실패: $e');
    }
  }

  Future<void> _enqueueEvent(String type, Map<String, dynamic> data) async {
    if (_sessionId == null) return;
    final seq = ++_eventSeq; // 1부터 증가
    _eventBuffer.add({
      'seq': seq,
      'type': type,
      'ts': FieldValue.serverTimestamp(),
      'step': _currentStep,
      'cSubStep': _currentCSubStep,
      ...data,
    });
    if (_eventBuffer.length >= _bufferMax) {
      await _flushEvents();
    }
  }

  Future<void> _flushEvents() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || _sessionId == null) return;
      if (_eventBuffer.isEmpty) return;

      final toWrite = List<Map<String, dynamic>>.from(_eventBuffer);
      _eventBuffer.clear();

      final base = FirebaseFirestore.instance
          .collection('chi_users')
          .doc(uid)
          .collection('abc_sessions')
          .doc(_sessionId)
          .collection('events');

      final batch = FirebaseFirestore.instance.batch();
      for (final ev in toWrite) {
        final int seq = ev['seq'] as int;
        final String id = seq.toString().padLeft(6, '0'); // 000001, 000002, ...
        final doc = base.doc(id);
        batch.set(doc, ev);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('이벤트 배치 기록 실패: $e');
    }
  }

  Future<void> _logEvent(String type, Map<String, dynamic> data) async {
    await _enqueueEvent(type, data);
  }

  void _attachTextWatchers() {
    void watch(String field, TextEditingController c) {
      _prevText[c] = c.text;
      _debouncers[c]?.cancel();
      c.addListener(() {
        final prev = _prevText[c] ?? '';
        final cur = c.text;
        final delta = cur.length - prev.length;
        final deletion = cur.length < prev.length;
        _prevText[c] = cur;

        _textChanges++;
        _debouncers[c]?.cancel();
        _debouncers[c] = Timer(const Duration(milliseconds: 400), () {
          _logEvent('text_change', {
            'field': field,
            'len': cur.length,
            'delta': delta,
            'deletion': deletion,
          });
        });
      });
    }

    watch('C1_customSymptom', _customSymptomController);
    watch('C2_customEmotion', _customEmotionController);
    watch('A_customKeyword', _customAKeywordController);
    watch('B_customKeyword', _customBKeywordController);
    watch('C3_customBehavior', _addCGridController);
  }

  Future<void> _onStepChange(String fromKey, String toKey) async {
    if (fromKey != toKey) {
      _bumpStepTimeToNow(fromKey);
      await _logEvent('step_change', {'from': fromKey, 'to': toKey});
    }
  }

  Future<void> _markAbandoned(String reason) async {
    try {
      if (_sessionCompleted || _sessionId == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      _bumpStepTimeToNow(_currentStepKey());
      await _flushEvents();

      await FirebaseFirestore.instance
          .collection('chi_users')
          .doc(uid)
          .collection('abc_sessions')
          .doc(_sessionId)
          .set({
        'status': 'abandoned',
        'screen': 'AbcInputScreen_chip/${_currentStepKey()}',
        'endedAt': FieldValue.serverTimestamp(),
        'reason': reason,
        'keyPresses': _keyPresses,
        'touches': _touches,
        'textChanges': _textChanges,
        'chipToggles': _chipToggles,
        'stepTimeMs': _stepTimeMs,
      }, SetOptions(merge: true));

      await _logEvent('session_abandoned', {'reason': reason});
      await _flushEvents();
    } catch (e) {
      debugPrint('세션 중도이탈 기록 실패: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _flushTimer?.cancel();
    _rawFocus.dispose();
    for (final t in _debouncers.values) {
      t.cancel();
    }
    _flushEvents();
    _markAbandoned('dispose_without_save');
    super.dispose();
  }
}