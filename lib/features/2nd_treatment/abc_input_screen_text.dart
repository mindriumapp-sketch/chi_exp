//TODO: text 입력 page
import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
// import 'package:provider/provider.dart';
import '../../common/constants.dart';
import '../../widgets/navigation_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/services.dart';
// import 'package:gad_app_team/data/user_provider.dart';


class AbcInputTextScreen extends StatefulWidget {
  // final bool isExampleMode;
  final Map<String, String>? exampleData;
  final String? abcId;
  final DateTime? startedAt;

  const AbcInputTextScreen({
    super.key,
    // this.isExampleMode = false,
    this.exampleData,
    this.abcId,
    this.startedAt,
  });

  @override
  State<AbcInputTextScreen> createState() => _AbcInputTextScreenState();
}

class _AbcInputTextScreenState extends State<AbcInputTextScreen> with WidgetsBindingObserver {
  bool _didInit = false;

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
  final int _chipToggles = 0; // 칩 토글 누적 카운트
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


  
  // === Text mode controllers (A, B, C1~C3) ===

  final TextEditingController _aTextController = TextEditingController();
  final TextEditingController _bTextController = TextEditingController();
  final TextEditingController _c1TextController = TextEditingController();
  final TextEditingController _c2TextController = TextEditingController();
  final TextEditingController _c3TextController = TextEditingController();

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



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stepEnteredAt = DateTime.now();
    _startSession();
    _attachTextWatchers();
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
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: CustomAppBar(title: '일기 쓰기'),
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
            rightLabel: _currentStep < 2 ? '다음' : (_currentCSubStep < 2 ? '다음' : '저장'),
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
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  Widget _buildStepA() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A. 불안감을 느꼈을 때 어떤 상황이었나요?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _aTextController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: '예: 발표 전 사람들 앞에 서 있었어요',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStepB() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'B. 그 상황에서 어떤 생각이 들었나요?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bTextController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: '예: 모두가 나를 비웃을 거야',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
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
              'C-1. 어떤 신체 증상이 나타났나요?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _c1TextController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '예: 두근거림, 손떨림, 땀 등',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'C-2. 어떤 감정이 들었나요?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _c2TextController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '예: 불안, 두려움, 당황스러움 등',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'C-3. 어떤 행동을 했나요?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _c3TextController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '예: 회피, 대화 피함, 자리 바꿈 등',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
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

      final c1 = _c1TextController.text;
      final c2 = _c2TextController.text;
      final c3 = _c3TextController.text;
      final activatingEvent = _aTextController.text;
      final belief          = _bTextController.text;

      final data = {
        'activatingEvent': activatingEvent,
        'belief'         : belief,
        'c1_physical'    : c1,
        'c2_emotion'     : c2,
        'c3_behavior'    : c3,
        'startedAt': widget.startedAt,
        'completedAt'      : FieldValue.serverTimestamp(),
      };

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('저장'),
          content: const Text('작성한 일기를 저장하시겠습니까?'),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text('확인'),
              onPressed: () async {
                final newModelId = await _nextSequencedDocId(userId, 'abc_models');
                await firestore
                    .collection('chi_users')
                    .doc(userId)
                    .collection('abc_models')
                    .doc(newModelId)
                    .set(data);

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
                    'screen': 'AbcInputScreen_text/${_currentStepKey()}',
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
        'screen': 'AbcInputScreen_text',
        'experimentCondition': 'Text_input',
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
    // attach watchers to text controllers
    watch('A_text', _aTextController);
    watch('B_text', _bTextController);
    watch('C1_text', _c1TextController);
    watch('C2_text', _c2TextController);
    watch('C3_text', _c3TextController);
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
        'screen': 'AbcInputScreen_text/${_currentStepKey()}',
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
    _aTextController.dispose();
    _bTextController.dispose();
    _c1TextController.dispose();
    _c2TextController.dispose();
    _c3TextController.dispose();
    super.dispose();
  }
}