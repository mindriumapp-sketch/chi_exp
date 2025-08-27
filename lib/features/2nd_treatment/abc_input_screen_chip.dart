import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import '../../common/constants.dart';
import '../../widgets/navigation_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:gad_app_team/widgets/aspect_viewport.dart';

class GridItem {
  // final IconData icon;
  final String label;
  final bool isAdd;
  final Color? borderColor; 
  final double? borderWidth;
  const GridItem({
    // required this.icon,
    required this.label,
    this.isAdd = false,
    this.borderColor = Colors.black12,
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

  bool get _isEditing => widget.isEditMode && (widget.abcId != null && widget.abcId!.isNotEmpty);

  CollectionReference<Map<String, dynamic>> _chipsRef(String uid) {
    final userRef = FirebaseFirestore.instance.collection('chi_users').doc(uid);
    return userRef.collection('custom_abc_chips');
  }

  /// Legacy (singular) collection for backward compatibility
  CollectionReference<Map<String, dynamic>> _legacyChipsRef(String uid) {
    final userRef = FirebaseFirestore.instance.collection('chi_users').doc(uid);
    return userRef.collection('custom_abc_chip'); // legacy (singular)
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
  int _currentCSubStep = 0;
  String? _sessionId;
  bool _sessionCompleted = false;
  bool _isPaused = false;
  Timer? _idleTimer;
  Timer? _bgAbandonTimer;
  static const Duration _idleTimeout = Duration(minutes: 1);
  static const Duration _bgAbandonTimeout = Duration(minutes: 5);
  int _chipToggles = 0;

  // Step time tracking
  final Map<String, int> _stepTimeMs = {'A': 0, 'B': 0, 'C1': 0, 'C2': 0, 'C3': 0};
  DateTime _stepEnteredAt = DateTime.now();
  int get _pageTimeMsTotal => _stepTimeMs.values.fold(0, (acc, v) => acc + v);

  // Raw input listening
  final Map<TextEditingController, String> _prevText = {};
  final Map<TextEditingController, Timer> _debouncers = {};
  final Map<TextEditingController, int> _lastLoggedLen = {};
  bool _suspendTextLogging = false;
  final Map<TextEditingController, String> _lastLoggedText = {};

  // 현재 세션에서 추가된 칩들을 추적하는 Set들
  final Set<String> _currentSessionAChips = {};
  final Set<String> _currentSessionBChips = {};
  final Set<String> _currentSessionCPhysicalChips = {};
  final Set<String> _currentSessionCEmotionChips = {};
  final Set<String> _currentSessionCBehaviorChips = {};

  final TextEditingController _customSymptomController = TextEditingController();
  final TextEditingController _customEmotionController = TextEditingController();
  final TextEditingController _customAKeywordController = TextEditingController();
  final TextEditingController _customBKeywordController = TextEditingController();

  // 1. 신체증상 전용 칩
  final List<GridItem> _physicalChips = [
    GridItem(label: '가슴 두근거림'),
    GridItem(label: '+ 추가', isAdd: true),
  ];
  final Set<int> _selectedPhysical = {};

  // 2. 감정 전용 칩
  final List<GridItem> _emotionChips = [
    GridItem(label: '두려움'),
    GridItem(label: '+ 추가', isAdd: true),
  ];
  final Set<int> _selectedEmotion = {};

  late List<GridItem> _behaviorChips;
  final Set<int> _selectedBehavior = {};
  final TextEditingController _addCGridController = TextEditingController();

  // 1. 칩 데이터 및 선택 상태 추가
  final List<GridItem> _aGridChips = [
    GridItem(label: '자전거 타기'),
    GridItem(label: '+ 추가', isAdd: true),
  ];
  final Set<int> _selectedAGrid = {};

  final List<GridItem> _bGridChips = [
    GridItem(label: '넘어질 것 같음'),
    GridItem(label: '+ 추가', isAdd: true),
  ];
  final Set<int> _selectedBGrid = {};

  // 사용자 정의 칩 저장 함수 (중복 방지: (type,label) 키로 단일 문서만)
  Future<void> _saveCustomChip(String type, String label) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Use a stable document ID per (type,label) so the same chip never creates duplicates
      final docId = '${type}_$label';
      await _chipsRef(user.uid).doc(docId).set({
        'type': type,
        'label': label,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'is_deleted': false,
        // Ensure the field exists; no-op increment when first created
        'count': FieldValue.increment(0),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('칩 저장 실패: $e');
    }
  }

  Future<void> _bumpCustomChipCount(String type, String label) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docRef = _chipsRef(user.uid).doc('${type}_$label');
      await docRef.set({
        'type': type,
        'label': label,
        'updatedAt': FieldValue.serverTimestamp(),
        'count': FieldValue.increment(1),
        'is_deleted': false
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('칩 카운트 증가 실패: $e');
    }
  }

  // 사용자 정의 칩 불러오기 함수 (backward compatibility with legacy collection, dedupes by type+label)
  Future<void> _loadCustomChips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final uid = user.uid;

      // Load from both collections (plural + legacy singular) with server-side filter
      final results = await Future.wait([
        _chipsRef(uid).where('is_deleted', isEqualTo: false).get(),
        _legacyChipsRef(uid).where('is_deleted', isEqualTo: false).get(),
      ]);

      final seen = <String>{};
      final addsA = <String>[];
      final addsB = <String>[];
      final addsPhys = <String>[];
      final addsEmo = <String>[];
      final addsBeh = <String>[];

      for (final snap in results) {
        for (final doc in snap.docs) {
          final data = doc.data();
          final type = data['type'];
          final label = (data['label'] ?? '').toString().trim();

          if (label.isEmpty || type == null) continue;
          final key = '$type|$label';
          if (seen.contains(key)) continue; // dedupe across both collections
          seen.add(key);

          switch (type) {
            case 'A':
              addsA.add(label);
              break;
            case 'B':
              addsB.add(label);
              break;
            case 'C-physical':
              addsPhys.add(label);
              break;
            case 'C-emotion':
              addsEmo.add(label);
              break;
            case 'C-behavior':
              addsBeh.add(label);
              break;
            default:
              // Unknown type → ignore to avoid UI breakage
              break;
          }
        }
      }

      // Batch a single rebuild
      if (mounted) {
        setState(() {
          for (final label in addsA) {
            if (!_aGridChips.any((c) => c.label == label)) {
              _aGridChips.insert(_aGridChips.length - 1, GridItem(label: label, isAdd: true));
            }
          }
          for (final label in addsB) {
            if (!_bGridChips.any((c) => c.label == label)) {
              _bGridChips.insert(_bGridChips.length - 1, GridItem(label: label, isAdd: true));
            }
          }
          for (final label in addsPhys) {
            if (!_physicalChips.any((c) => c.label == label)) {
              _physicalChips.insert(_physicalChips.length - 1, GridItem(label: label, isAdd: true));
            }
          }
          for (final label in addsEmo) {
            if (!_emotionChips.any((c) => c.label == label)) {
              _emotionChips.insert(_emotionChips.length - 1, GridItem(label: label, isAdd: true));
            }
          }
          for (final label in addsBeh) {
            if (!_behaviorChips.any((c) => c.label == label)) {
              _behaviorChips.insert(_behaviorChips.length - 1, GridItem(label: label, isAdd: true));
            }
          }
        });
      }
    } catch (e) {
      debugPrint('칩 불러오기 실패: $e');
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

  int _ensureChip(List<GridItem> chips, String label) {
    final idx = chips.indexWhere((c) => c.label == label);
    if (idx != -1) return idx;
    final insertIdx = chips.length - 1; // '추가' 칩 앞에 삽입
    chips.insert(insertIdx, GridItem(label: label));
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

    // ✅ 리스트 안전하게 변환
    final ae = List<String>.from(data['activatingEvent'] ?? []);
    final bl = List<String>.from(data['belief'] ?? []);
    final c1 = List<String>.from(data['c1_emotion'] ?? []);
    final c2 = List<String>.from(data['c2_physical'] ?? []);
    final c3 = List<String>.from(data['c3_behavior'] ?? []);

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
        final idx = _ensureChip(_bGridChips, s.toString());
        _selectedBGrid.add(idx);
      }

      // C1
      _selectedEmotion.clear();
      for (final s in c1) {
        final idx = _ensureChip(_emotionChips, s.toString());
        _selectedEmotion.add(idx);
      }

      // C2
      _selectedPhysical.clear();
      for (final s in c2) {
        final idx = _ensureChip(_physicalChips, s.toString());
        _selectedPhysical.add(idx);
      }

      // C3
      _selectedBehavior.clear();
      for (final s in c3) {
        final idx = _ensureChip(_behaviorChips, s.toString());
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
      GridItem(label: '자전거 끌고 돌아가기'),
      GridItem(label: '+ 추가', isAdd: true),
    ];

      _loadCustomChips();

    if (_isEditing) {
      _loadExistingAbc();
    }
    _resetIdleTimer();
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

  bool _hasSelectionForCurrentStep() {
    if (_currentStep == 0) return _selectedAGrid.isNotEmpty;
    if (_currentStep == 1) return _selectedBGrid.isNotEmpty;
    switch (_currentCSubStep) {
      case 0:
        return _selectedEmotion.isNotEmpty;
      case 1:
        return _selectedPhysical.isNotEmpty;
      default:
        return _selectedBehavior.isNotEmpty;
    }
  }

  bool _validateStepOrToast() {
    final ok = _hasSelectionForCurrentStep();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('칩을 선택해주세요.')),
      );
    }
    return ok;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // 즉시 카운트 마감 + 일시정지, 복귀 없으면 이탈 예약
      if (!_isPaused) {
        _bumpStepTimeToNow(_currentStepKey());
        _isPaused = true;
      }
      _bgAbandonTimer?.cancel();
      _bgAbandonTimer = Timer(_bgAbandonTimeout, () {
        _bumpStepTimeToNow(_currentStepKey());
        _isPaused = true;
        _markAbandoned('app_background');
      });
    } else if (state == AppLifecycleState.resumed) {
      if (_isPaused) {
        _isPaused = false;
        _stepEnteredAt = DateTime.now();
      }
      _bgAbandonTimer?.cancel();
      _resetIdleTimer();
      _maybeResumeAbandoned();
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
                    '오늘 있었던 기억에 남는 일은 무엇인가요?',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
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
                                // hintText: '예: 자전거 타기',
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
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final val = _customAKeywordController.text.trim();
                      if (val.isNotEmpty) {
                        // 중복 체크
                        if (_isDuplicateChip('A', val)) {
                          _showDuplicateAlert(context);
                          return;
                        }
                        setState(() {
                          _aGridChips.insert(
                            _aGridChips.length - 1,
                            GridItem(label: val, isAdd: true),
                          );
                          // 현재 세션에 추가된 칩으로 추적
                          _addToCurrentSession('A', val);
                        });
                        _resetIdleTimer();
                        _suspendTextLogging = true;
                        _customAKeywordController.clear();
                        _prevText[_customAKeywordController] = '';
                        _lastLoggedLen[_customAKeywordController] = 0;
                        _lastLoggedText[_customAKeywordController] = '';
                        _suspendTextLogging = false;
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
                    '그 상황에서 어떤 생각이 떠올랐나요?',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
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
                                // hintText: '예: 넘어질까봐 두려움',
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
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final val = _customBKeywordController.text.trim();
                      if (val.isNotEmpty) {
                        // 중복 체크
                        if (_isDuplicateChip('B', val)) {
                          _showDuplicateAlert(context);
                          return;
                        }
                        setState(() {
                          _bGridChips.insert(
                            _bGridChips.length - 1,
                            GridItem(label: val, isAdd: true),
                          );
                          // 현재 세션에 추가된 칩으로 추적
                          _addToCurrentSession('B', val);
                        });
                        _resetIdleTimer();
                        _suspendTextLogging = true;
                        _customBKeywordController.clear();
                        _prevText[_customBKeywordController] = '';
                        _lastLoggedLen[_customBKeywordController] = 0;
                        _lastLoggedText[_customBKeywordController] = '';
                        _suspendTextLogging = false;
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
                    '그때 몸에서 어떤 변화가 있었나요?\n',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            GridItem(label: value, isAdd: true),
                          );
                          _addToCurrentSession('C-physical', value);
                        });
                        _resetIdleTimer();
                        _suspendTextLogging = true;
                        _customSymptomController.clear();
                        _prevText[_customSymptomController] = '';
                        _lastLoggedLen[_customSymptomController] = 0;
                        _lastLoggedText[_customSymptomController] = '';
                        _suspendTextLogging = false;
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
                    '그 순간 어떤 감정을 느꼈나요?',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                        if (_isDuplicateChip('C-emotion', val)) {
                          _showDuplicateAlert(context);
                          return;
                        }
                        setState(() {
                          _emotionChips.insert(
                            _emotionChips.length - 1,
                            GridItem(label: val, isAdd: true),
                          );
                          _addToCurrentSession('C-emotion', val);
                        });
                        _resetIdleTimer();
                        _suspendTextLogging = true;
                        _customEmotionController.clear();
                        _prevText[_customEmotionController] = '';
                        _lastLoggedLen[_customEmotionController] = 0;
                        _lastLoggedText[_customEmotionController] = '';
                        _suspendTextLogging = false;
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
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      // 무활동 타임아웃 → 일시정지로 전환 후 이탈 기록
      _bumpStepTimeToNow(_currentStepKey());
      _isPaused = true;
      _markAbandoned('inactive_timeout');
    });
  }

  void _cancelTimers() {
    _idleTimer?.cancel();
    _bgAbandonTimer?.cancel();
  }

  Future<void> _maybeResumeAbandoned() async {
    try {
      if (_sessionCompleted || _sessionId == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final docRef = FirebaseFirestore.instance
          .collection('chi_users').doc(uid)
          .collection('abc_sessions').doc(_sessionId);
      final snap = await docRef.get();
      final data = snap.data();
      if (data == null) return;

      final status = data['status'];
      final reason = data['reason'];
      if (status == 'abandoned' && (reason == 'app_background' || reason == 'inactive_timeout')) {
        await docRef.set({'status': 'in_progress'}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('세션 재개 처리 실패: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
        _markAbandoned('page_back');
      }
      },
      child: AspectViewport(
        aspect: 9 / 16,
        background: Colors.grey.shade100,
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: CustomAppBar(
            title: _isEditing ? '일기 수정' : '일기 작성',
            confirmOnBack: true,
            confirmOnHome: true,
          ),
          body: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
            child: SafeArea(
              child: _buildMainContent(),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: NavigationButtons(
              leftLabel: '이전',
              rightLabel: _currentStep < 2
                  ? '다음'
                  : (_currentCSubStep < 2 ? '다음' : (_isEditing ? '수정' : '저장')),
              onBack: () {
                if (_currentStep == 0) {
                  _markAbandoned('page_back');
                  _cancelTimers();
                  Navigator.pop(context);
                } else if (_currentStep == 2 && _currentCSubStep > 0) {
                  setState(() => _currentCSubStep--);
                } else {
                  _previousStep();
                }
              },
              onNext: () async {
                // 현재 단계에서 최소 1개 선택했는지 검사
                if (!_validateStepOrToast()) return;

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChipSummary(),
          const SizedBox(height: 32),
          _buildStepContent(),
        ],
      ),
    );
  }

  Widget _buildChipSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '아래 질문에 대한 키워드를 선택하여 일기의 빈칸을 채워주세요.',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        _buildFeedbackContent()
      ],
    );
  }

  Widget _buildFeedbackContent() {
    // Build lists first
    final situationItems = _selectedAGrid.map((i) => _aGridChips[i].label).toList();
    final thoughtItems   = _selectedBGrid.map((i) => _bGridChips[i].label).toList();
    final emotionItems    = _selectedEmotion.map((i) => _emotionChips[i].label).toList();
    final physicalItems  = _selectedPhysical.map((i) => _physicalChips[i].label).toList();
    final behaviorItems   = _selectedBehavior.map((i) => _behaviorChips[i].label).toList();

    // Fallbacks for empty selections (표시용 기본값)
    final situation = situationItems.isNotEmpty ? situationItems.join(', ') : '';
    final thought   = thoughtItems.isNotEmpty   ? thoughtItems.join(', ')   : '';
    final emotion  = emotionItems.isNotEmpty  ? emotionItems.join(', ') : '';
    final physical = physicalItems.isNotEmpty ? physicalItems.join(', ') : '';
    final behavior = behaviorItems.isNotEmpty ? behaviorItems.join(', ') : '';

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black, width: 1),
      ),
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Builder(
                builder: (context) {
                  // Highlight style for selected text
                  final TextStyle selectedHighlight = TextStyle(
                    // backgroundColor: Colors.amberAccent,
                    color: Colors.black,
                    fontSize: 16
                  );
                  int linesToShow = 1;
                  if (_currentStep == 0) {
                    linesToShow = 1;
                  } else if (_currentStep == 1) {
                    linesToShow = 2;
                  } else {
                    // _currentStep == 2 (C 단계)
                    if (_currentCSubStep == 0) {
                      linesToShow = 3; // C1까지
                    } else if (_currentCSubStep == 1) {
                      linesToShow = 4; // C2까지
                    } else {
                      linesToShow = 5; // C3까지 전부
                    }
                  }

                  WidgetSpan box(String text) => WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12, width: 1),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black)),
                        ),
                      );

                  final spans = <InlineSpan>[];

                  // Line 1: A
                  spans.add(const TextSpan(text: "오늘 나는 "));
                  if (situationItems.isNotEmpty) {
                    spans.add(TextSpan(text: situation, style: selectedHighlight));
                  } else {
                    spans.add(box('A. 상황'));
                  }
                  spans.add(const TextSpan(text: " (이)라는 일이 있었다."));

                  // Line 2: B
                  if (linesToShow >= 2) {
                    spans.add(const TextSpan(text: "\n그 상황에서 나는 "));
                    if (thoughtItems.isNotEmpty) {
                      spans.add(TextSpan(text: thought, style: selectedHighlight));
                    } else {
                      spans.add(box('B. 생각'));
                    }
                    spans.add(const TextSpan(text: " (이)라는 생각이 떠올랐고,"));
                  }

                  // Line 3: C1 Emotion
                  if (linesToShow >= 3) {
                    spans.add(const TextSpan(text: "\n"));
                    if (emotionItems.isNotEmpty) {
                      spans.add(TextSpan(text: emotion, style: selectedHighlight));
                    } else {
                      spans.add(box('C1. 감정'));
                    }
                    spans.add(const TextSpan(text: " (이)라는 감정을 느꼈다."));
                  }

                  // Line 4: C2 Physical
                  if (linesToShow >= 4) {
                    spans.add(const TextSpan(text: "\n그 순간 몸에서 "));
                    if (physicalItems.isNotEmpty) {
                      spans.add(TextSpan(text: physical, style: selectedHighlight));
                    } else {
                      spans.add(box('C2. 신체증상'));
                    }
                    spans.add(const TextSpan(text: " (이)라는 변화가 있었고,"));
                  }

                  // Line 5: C3 Behavior
                  if (linesToShow >= 5) {
                    spans.add(const TextSpan(text: "\n나는 "));
                    if (behaviorItems.isNotEmpty) {
                      spans.add(TextSpan(text: behavior, style: selectedHighlight));
                    } else {
                      spans.add(box('C3. 행동'));
                    }
                    spans.add(const TextSpan(text: " (이)라는 행동을 했다."));
                  }

                  return RichText(
                    textAlign: TextAlign.left,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                      children: spans,
                    ),
                  );
                },
              ),
            ),
          ],
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

  Widget _buildStepA() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘 있었던 기억에 남는 일은 무엇인가요? (복수 선택 가능)',
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
                    label: const Text(
                      '+ 추가',
                      style: TextStyle(color: AppColors.indigo, fontSize: 13.5),
                    ),
                    backgroundColor: AppColors.indigo50,
                    side: BorderSide(color: AppColors.indigo.shade100, width: 1),
                    onPressed: _addAKeyword,
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
              return FilterChip(
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
                        ? _selectedAGrid.remove(i)
                        : _selectedAGrid.add(i);
                    _chipToggles++;
                  }); _resetIdleTimer();
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
                onDeleted: item.isAdd ? () => _deleteCustomChip('A', item.label, i) : null,
                deleteIcon: item.isAdd
                    ? const Icon(Icons.close, size: 18, color: Colors.redAccent)
                    : null,
              );
            }
          }),
        ),
      ],
    );
  }

  Widget _buildStepB() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '그 상황에서 어떤 생각이 떠올랐나요? (복수 선택 가능)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_bGridChips.length, (i) {
            if (i == _bGridChips.length - 1) {
              return ActionChip(
                label: const Text(
                  '+ 추가',
                  style: TextStyle(color: AppColors.indigo, fontSize: 13.5),
                ),
                backgroundColor: AppColors.indigo50,
                side: BorderSide(color: AppColors.indigo.shade100, width: 1),
                onPressed: _addBKeyword,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              );
            } else {
              final item = _bGridChips[i];
              final isSelected = _selectedBGrid.contains(i);
              return FilterChip(
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
                    _chipToggles++;
                  }); _resetIdleTimer();
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
                onDeleted: item.isAdd ? () => _deleteCustomChip('B', item.label, i) : null,
                deleteIcon: item.isAdd
                    ? const Icon(Icons.close, size: 18, color: Colors.redAccent)
                    : null,
              );
            }
          }),
        ),
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
              '그 순간 어떤 감정을 느꼈나요? (복수 선택 가능)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildCEmotionChips(),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '그때 몸에서 어떤 변화가 있었나요? (복수 선택 가능)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildCPhysicalChips(),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '그래서 어떤 행동을 했나요? (복수 선택 가능)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildCBehaviorChips(),
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
            label: const Text(
              '+ 추가',
              style: TextStyle(color: AppColors.indigo, fontSize: 13.5),
            ),
            backgroundColor: AppColors.indigo50,
            side: BorderSide(color: AppColors.indigo.shade100, width: 1),
            onPressed: _addCustomSymptom,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          );
        } else {
          final item = _physicalChips[i];
          final isSelected = _selectedPhysical.contains(i);
          return FilterChip(
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
                _chipToggles++;
              }); _resetIdleTimer();
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
            onDeleted: item.isAdd ? () => _deleteCustomChip('C-physical', item.label, i) : null,
            deleteIcon: item.isAdd
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
            label: const Text(
              '+ 추가',
              style: TextStyle(color: AppColors.indigo, fontSize: 13.5),
            ),
            backgroundColor: AppColors.indigo50,
            side: BorderSide(color: AppColors.indigo.shade100, width: 1),
            onPressed: _addEmotion,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          );
        } else {
          final item = _emotionChips[i];
          final isSelected = _selectedEmotion.contains(i);
          return FilterChip(
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
                _chipToggles++;
              }); _resetIdleTimer();
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
            onDeleted: item.isAdd ? () => _deleteCustomChip('C-emotion', item.label, i) : null,
            deleteIcon: item.isAdd
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
            label: const Text(
              '+ 추가',
              style: TextStyle(color: AppColors.indigo, fontSize: 13.5),
            ),
            backgroundColor: AppColors.indigo50,
            side: BorderSide(color: AppColors.indigo.shade100, width: 1),
            onPressed: _showAddCGridDialog,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          );
        } else {
          final item = _behaviorChips[i];
          final isSelected = _selectedBehavior.contains(i);
          return FilterChip(
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
                _chipToggles++;
              }); _resetIdleTimer();
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
            onDeleted: item.isAdd ? () => _deleteCustomChip('C-behavior', item.label, i) : null,
            deleteIcon: item.isAdd
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
                    '그래서 어떤 행동을 했나요?',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      final value = _addCGridController.text.trim();
                      if (value.isNotEmpty) {
                        if (_isDuplicateChip('C-behavior', value)) {
                          _showDuplicateAlert(context);
                          return;
                        }
                        setState(() {
                          _behaviorChips.insert(
                            _behaviorChips.length - 1,
                            GridItem(label: value, isAdd: true),
                          );
                          _addToCurrentSession('C-behavior', value);
                        });
                        _resetIdleTimer();
                        _suspendTextLogging = true;
                        _addCGridController.clear();
                        _prevText[_addCGridController] = '';
                        _lastLoggedLen[_addCGridController] = 0;
                        _lastLoggedText[_addCGridController] = '';
                        _suspendTextLogging = false;
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

  bool _isDuplicateChip(String type, String label) {
    switch (type) {
      case 'A':
        return _aGridChips.any((chip) => chip.label == label);
      case 'B':
        return _bGridChips.any((chip) => chip.label == label);
      case 'C-emotion':
        return _emotionChips.any((chip) => chip.label == label);
      case 'C-physical':
        return _physicalChips.any((chip) => chip.label == label);
      case 'C-behavior':
        return _behaviorChips.any((chip) => chip.label == label);
      default:
        return false;
    }
  }

  bool _isCustomChip(String type, String label) {
    List<GridItem> list;
    switch (type) {
      case 'A':
        list = _aGridChips;
        break;
      case 'B':
        list = _bGridChips;
        break;
      case 'C-emotion':
        list = _emotionChips;
        break;
      case 'C-physical':
        list = _physicalChips;
        break;
      case 'C-behavior':
        list = _behaviorChips;
        break;
      default:
        return false;
    }
    final idx = list.indexWhere((c) => c.label == label);
    if (idx == -1) return false;
    return list[idx].isAdd == true;
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

    // 현재 사용자 커스텀 칩 목록(기존 저장본) 조회 (문서당 유일키를 문자열로 구성)
    final snapshot = await _chipsRef(user.uid).get();
    final existingKeys = snapshot.docs.map((doc) {
      final data = doc.data();
      return '${data['type']}_${data['label']}';
    }).toSet();

    Future<void> saveIfNew(String type, String label) async {
      final key = '${type}_$label';
      if (!existingKeys.contains(key)) {
        await _saveCustomChip(type, label);
        existingKeys.add(key);
      }
    }

    for (final label in _currentSessionAChips) {
      await saveIfNew('A', label);
    }
    for (final label in _currentSessionBChips) {
      await saveIfNew('B', label);
    }
    for (final label in _currentSessionCEmotionChips) {
      await saveIfNew('C-emotion', label);
    }
    for (final label in _currentSessionCPhysicalChips) {
      await saveIfNew('C-physical', label);
    }
    for (final label in _currentSessionCBehaviorChips) {
      await saveIfNew('C-behavior', label);
    }
  }

  void _adjustSelectionAfterRemoval(Set<int> selectedSet, int removedIndex) {
    if (selectedSet.isEmpty) return;
    final updated = <int>{};
    for (final idx in selectedSet) {
      if (idx == removedIndex) {
      } else if (idx > removedIndex) {
        updated.add(idx - 1);
      } else {
        updated.add(idx);
      }
    }
    selectedSet
      ..clear()
      ..addAll(updated);
  }

  // Firestore에서 커스텀 칩 삭제 함수 (is_deleted로 soft delete)
  Future<void> _deleteCustomChip(String type, String label, int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final query = await _chipsRef(user.uid)
          .where('type', isEqualTo: type)
          .where('label', isEqualTo: label)
          .get();
      for (var doc in query.docs) {
        await doc.reference.update({
          'is_deleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('칩 삭제 중 Firestore 오류: $e');
    }

    setState(() {
      switch (type) {
        case 'A':
          _aGridChips.removeAt(index);
          _adjustSelectionAfterRemoval(_selectedAGrid, index);
          break;
        case 'B':
          _bGridChips.removeAt(index);
          _adjustSelectionAfterRemoval(_selectedBGrid, index);
          break;
        case 'C-emotion':
          _emotionChips.removeAt(index);
          _adjustSelectionAfterRemoval(_selectedEmotion, index);
          break;
        case 'C-physical':
          _physicalChips.removeAt(index);
          _adjustSelectionAfterRemoval(_selectedPhysical, index);
          break;
        case 'C-behavior':
          _behaviorChips.removeAt(index);
          _adjustSelectionAfterRemoval(_selectedBehavior, index);
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
      final c1 = _selectedEmotion.map((i) => _emotionChips[i].label).toList();
      final c2 = _selectedPhysical.map((i) => _physicalChips[i].label).toList();
      final c3 = _selectedBehavior.map((i) => _behaviorChips[i].label).toList();
      final activatingEvent = _selectedAGrid.map((i) => _aGridChips[i].label).toList();
      final belief          = _selectedBGrid.map((i) => _bGridChips[i].label).toList();


      final baseData = {
        'activatingEvent': activatingEvent,
        'belief'         : belief,
        'c1_emotion'     : c1,
        'c2_physical'    : c2,
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
              child: Text('확인'),
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
                  await docRef.set(payload, SetOptions(merge: true));
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
                        'report'     : null, 
                      });
                }
                for (final label in activatingEvent) {
                  if (_isCustomChip('A', label)) {
                    await _bumpCustomChipCount('A', label);
                  }
                }
                for (final label in belief) {
                  if (_isCustomChip('B', label)) {
                    await _bumpCustomChipCount('B', label);
                  }
                }
                for (final label in c1) {
                  if (_isCustomChip('C-emotion', label)) {
                    await _bumpCustomChipCount('C-emotion', label);
                  }
                }
                for (final label in c2) {
                  if (_isCustomChip('C-physical', label)) {
                    await _bumpCustomChipCount('C-physical', label);
                  }
                }
                for (final label in c3) {
                  if (_isCustomChip('C-behavior', label)) {
                    await _bumpCustomChipCount('C-behavior', label);
                  }
                }

                await _saveSelectedChipsToFirestore();

                // 세션 완료 처리: 누적 시간/카운터 반영 및 이벤트 버퍼 플러시
                _cancelTimers(); 
                final fromKey = _currentStepKey();
                _bumpStepTimeToNow(fromKey);

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
                    'chipToggles': _chipToggles,
                    'pageTimeMs': _pageTimeMsTotal,
                  }, SetOptions(merge: true));
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
      });
      _sessionId = newSessionId;
    } catch (e) {
      debugPrint('세션 시작 실패: $e');
    }
  }

  void _attachTextWatchers() {
    void watch(TextEditingController c) {
      // Initialize baselines for this controller
      _prevText[c] = c.text;
      _lastLoggedLen[c] = c.text.length;
      _lastLoggedText[c] = c.text;
      _debouncers[c]?.cancel();

      c.addListener(() {
        // Capture old/new BEFORE any early returns
        final oldText = _prevText[c] ?? '';
        final newText = c.text;

        if (_suspendTextLogging) {
          // Keep baseline in sync while suppressed to avoid large deltas later
          _prevText[c] = newText;
          return;
        }

        // --- Approximate key press counting from text delta (works with soft keyboard & in dialogs) ---
        if (newText != oldText) {
          _resetIdleTimer();
        }

        // Update instantaneous previous text baseline for per-change tracking
        _prevText[c] = newText;

        // Debounce to emit a single logical text_change per burst
        _debouncers[c]?.cancel();
        _debouncers[c] = Timer(const Duration(milliseconds: 400), () {
          final curText = c.text;
          final curLen = curText.length;
          final lastLen = _lastLoggedLen[c] ?? curLen;
          final lastText = _lastLoggedText[c] ?? curText;

          if (curLen == lastLen && curText == lastText) {
            return;
          }
          _lastLoggedLen[c] = curLen;
          _lastLoggedText[c] = curText;
        });
      });
    }

    watch(_customSymptomController);
    watch(_customEmotionController);
    watch(_customAKeywordController);
    watch(_customBKeywordController);
    watch(_addCGridController);
  }

  Future<void> _onStepChange(String fromKey, String toKey) async {
    if (fromKey != toKey) {
      _bumpStepTimeToNow(fromKey);
    }
  }

  Future<void> _markAbandoned(String reason) async {
    try {
      if (_sessionCompleted || _sessionId == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      _bumpStepTimeToNow(_currentStepKey());

      await FirebaseFirestore.instance
          .collection('chi_users')
          .doc(uid)
          .collection('abc_sessions')
          .doc(_sessionId)
          .set({
        'status': 'abandoned',
        'screen': 'AbcInputScreen_chip/${_currentStepKey()}',
        'endedAt': FieldValue.serverTimestamp(),
        'durationMs': widget.startedAt != null
            ? DateTime.now().millisecondsSinceEpoch - widget.startedAt!.millisecondsSinceEpoch
            : null,
        'reason': reason,
        'checkStates': {
          'A': _selectedAGrid.isNotEmpty,
          'B': _selectedBGrid.isNotEmpty,
          'C1': _selectedEmotion.isNotEmpty,
          'C2': _selectedPhysical.isNotEmpty,
          'C3': _selectedBehavior.isNotEmpty,
        },
        'chipToggles': _chipToggles,
        'pageTimeMs': _pageTimeMsTotal,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('세션 중도이탈 기록 실패: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    for (final t in _debouncers.values) {
      t.cancel();
    }
    _markAbandoned('dispose_without_save');
    super.dispose();
  }
}
