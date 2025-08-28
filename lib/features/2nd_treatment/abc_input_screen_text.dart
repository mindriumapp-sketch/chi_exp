import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import '../../widgets/navigation_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AbcInputTextScreen extends StatefulWidget {
  final Map<String, String>? exampleData;
  final String? abcId;
  final DateTime? startedAt;
  final bool isEditMode;

  const AbcInputTextScreen({
    super.key,
    this.exampleData,
    this.abcId,
    this.startedAt,
    this.isEditMode = false,
  });

  @override
  State<AbcInputTextScreen> createState() => _AbcInputTextScreenState();
}

class _AbcInputTextScreenState extends State<AbcInputTextScreen> with WidgetsBindingObserver {
  ///////check box///////
  bool isCheckedA = false;
  bool isCheckedB = false;
  bool isCheckedC1 = false;
  bool isCheckedC2 = false;
  bool isCheckedC3 = false;

  Timer? _idleTimer;
  Timer? _bgAbandonTimer;
  static const Duration _idleTimeout = Duration(minutes: 1);
  static const Duration _bgAbandonTimeout = Duration(minutes: 5);

  bool _validateBeforeNext() {
    final hasText = _textDiaryController.text.trim().isNotEmpty;

    bool requiredChecked;
    switch (_currentStep) {
      case 0:
        requiredChecked = isCheckedA;
        break;
      case 1:
        requiredChecked = isCheckedB;
        break;
      case 2:
        switch (_currentCSubStep) {
          case 0:
            requiredChecked = isCheckedC1;
            break;
          case 1:
            requiredChecked = isCheckedC2;
            break;
          default:
            requiredChecked = isCheckedC3;
            break;
        }
        break;
      default:
        requiredChecked = false;
    }

    String? message;
    if (!hasText && !requiredChecked) {
      message = '내용을 입력하고 아래 체크박스를 체크해주세요.';
    } else if (!hasText) {
      message = '내용을 입력해주세요.';
    } else if (!requiredChecked) {
      message = '아래 체크박스를 체크해주세요.';
    }

    if (message != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      return false;
    }
    return true;
  }

bool get _isEditing => widget.isEditMode && (widget.abcId != null && widget.abcId!.isNotEmpty);
int _currentStep = 0;
int _currentCSubStep = 0;
String? _sessionId;
bool _sessionCompleted = false;
int _pageTimeMs = 0;
DateTime _stepEnteredAt = DateTime.now();
bool _isPaused = false;
final TextEditingController _textDiaryController = TextEditingController();

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

  Future<void> _loadExistingAbcText() async {
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

      setState(() {
        _textDiaryController.text = (data['text_diary'] ?? '').toString();
      });
    } catch (e) {
      debugPrint('기존 ABC 불러오기 실패(Text): $e');
    }
  }



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stepEnteredAt = DateTime.now();
    _startSession();
    if (_isEditing) {
      _loadExistingAbcText();
    }
    _resetIdleTimer();
  }


  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
        if (_currentStep == 2) _currentCSubStep = 0;
      });
    } else {
      if (_currentCSubStep < 2) {
        setState(() {
          _currentCSubStep++;
        });
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _currentCSubStep = 0;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb && (state == AppLifecycleState.inactive || state == AppLifecycleState.paused)) {
      if (!_isPaused) {
        _bumpStepTimeToNow(_currentStepKey());
        _isPaused = true;
      }
      _markAbandoned('page_hide'); // ✅ 즉시 abandon 시도
      return;                      // 타이머 대기 없이 바로 종료
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Stop the current step timer and mark as paused (do not count paused duration)
      if (!_isPaused) {
        _bumpStepTimeToNow(_currentStepKey());
        _isPaused = true;
      }
      // Schedule abandonment if not resumed within timeout
      _bgAbandonTimer?.cancel();
      _bgAbandonTimer = Timer(_bgAbandonTimeout, () {
        // Make sure we enter paused state at timeout and stop counting time
        _bumpStepTimeToNow(_currentStepKey());
        _isPaused = true;
        _markAbandoned('app_background');
      });
    } else if (state == AppLifecycleState.resumed) {
      // Resume timing from now so time while paused isn't counted
      if (_isPaused) {
        _isPaused = false;
        _stepEnteredAt = DateTime.now();
      }
      _bgAbandonTimer?.cancel();
      _resetIdleTimer();
      _maybeResumeAbandoned();
    }
  }

  Future<void> _maybeResumeAbandoned() async {
    try {
      if (_sessionCompleted || _sessionId == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final docRef = FirebaseFirestore.instance
          .collection('chi_users')
          .doc(uid)
          .collection('abc_sessions')
          .doc(_sessionId);
      final snap = await docRef.get();
      final data = snap.data();
      if (data == null) return;

      final status = data['status'];
      final reason = data['reason'];
      if (status == 'abandoned' && (reason == 'app_background' || reason == 'inactive_timeout')) {
        await docRef.set({
          'status': 'in_progress',
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('세션 재개 처리 실패: $e');
    }
  }

  Future<void> _confirmExitFromFirstPage() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('종료하시겠어요?'),
        content: const Text('지금 종료하면 진행 상황이 저장되지 않을 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('나가기', style: TextStyle(color: Colors.red),),
          ),
        ],
      ),
    ) ?? false;

    if (shouldLeave) {
      _markAbandoned('page_back');
      _cancelTimers();
      if (mounted) {
        Navigator.pop(context);
      }
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
        child:Scaffold(
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: NavigationButtons(
            leftLabel: '이전',
            rightLabel: _currentStep < 2
                ? '다음'
                : (_currentCSubStep < 2 ? '다음' : (_isEditing ? '수정' : '저장')),
            onBack: () {
              if (_currentStep == 0) {
                _confirmExitFromFirstPage();
              } else if (_currentStep == 2 && _currentCSubStep > 0) {
                setState(() => _currentCSubStep--);
              } else {
                _previousStep();
              }
            },
            onNext: () async {
              if (!_validateBeforeNext()) return;
              if (_currentStep < 2) {
                _nextStep();
              } else {
                if (_currentCSubStep < 2) {
                  _nextStep();
                } else {
                  await _saveAbcAndExit();
                }
              }
            }
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
          _buildInputText(),
          const SizedBox(height: 32),
          _buildStepContent(),
        ],
      ),
    );
  }
  
  Widget _buildInputText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘 있었던 일 중 기억에 남는 일에 대하여 자유롭게 작성해주세요.',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _textDiaryController,
          maxLines: 12,
          onChanged: (_) {
            _resetIdleTimer();
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
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
          '아래 내용을 작성하셨나요?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        CheckboxListTile(
          title: const Text(
            "오늘 일어난 사건이나 상황 (A. 상황)",
            style: TextStyle(fontSize: 16),
          ),
          value: isCheckedA,
          onChanged: (bool? value) {
            setState(() {
              isCheckedA = value ?? false;
            });
            _resetIdleTimer();
          },
        )
      ],
    );
  }

  Widget _buildStepB() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '아래 내용을 작성하셨나요?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        CheckboxListTile(
          title: const Text(
            '사건에 대한 해석이나 생각 (B. 생각)',
            style: TextStyle(fontSize: 16),
          ),
          value: isCheckedB,
          onChanged: (bool? value) {
            setState(() {
              isCheckedB = value ?? false;
            });
            _resetIdleTimer();
          },
        )
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
              '아래 내용을 작성하셨나요?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            CheckboxListTile(
              title: const Text(
                '결과로 나타나는 감정 (C1. 감정)',
                style: TextStyle(fontSize: 16),
              ),
              value: isCheckedC1,
              onChanged: (bool? value) {
                setState(() {
                  isCheckedC1 = value ?? false;
                });
                _resetIdleTimer();
              },
            )
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '아래 내용을 작성하셨나요?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            CheckboxListTile(
              title: const Text(
                '결과로 나타나는 신체증상 (C2. 신체증상)',
                style: TextStyle(fontSize: 16),
              ),
              value: isCheckedC2,
              onChanged: (bool? value) {
                setState(() {
                  isCheckedC2 = value ?? false;
                });
                _resetIdleTimer();
              },
            )
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '아래 내용을 작성하셨나요?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            CheckboxListTile(
              title: const Text(
                '결과로 나타나는 행동 (C3. 행동)',
                style: TextStyle(fontSize: 16),
              ),
              value: isCheckedC3,
              onChanged: (bool? value) {
                setState(() {
                  isCheckedC3 = value ?? false;
                });
                _resetIdleTimer();
              },
            )
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _onEdit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final fs = FirebaseFirestore.instance;
    final userDoc = fs.collection('chi_users').doc(uid);
    final docRef = userDoc.collection('abc_models').doc(widget.abcId);
    final backupRef = userDoc.collection('abc_backup').doc(widget.abcId);
    // 기존 데이터 백업
    try {
      final snap = await docRef.get();
      final Map<String, dynamic>? data = snap.data();
      final backup = <String, dynamic>{
        ...?data,
        'backupAt': FieldValue.serverTimestamp(),
      };
      await backupRef.set(backup, SetOptions(merge: true));
    } catch (_) {}
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

      final textDiary = _textDiaryController;

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
                // String savedAbcId;
                if (_isEditing) {
                  // 편집: 기존 문서 덮어쓰기 (onEdit에서 백업 완료된 상태)
                  final docRef = firestore
                      .collection('chi_users')
                      .doc(userId)
                      .collection('abc_models')
                      .doc(widget.abcId!);

                  final payload = {
                    'text_diary': textDiary.text,
                    'startedAt': widget.startedAt,
                    'completedAt': FieldValue.serverTimestamp(),
                  };
                  await docRef.set(payload, SetOptions(merge: true));
                  _onEdit();
                } else {
                  // 신규: 시퀀스 ID 생성 후 저장
                  final newModelId = await _nextSequencedDocId(userId, 'abc_models');
                  await firestore
                      .collection('chi_users')
                      .doc(userId)
                      .collection('abc_models')
                      .doc(newModelId)
                      .set({
                        'text_diary': textDiary.text,
                        'startedAt'  : widget.startedAt,
                        'completedAt': FieldValue.serverTimestamp(),
                      });
                }

                // 세션 완료 처리
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
                    'endedAt': FieldValue.serverTimestamp(),
                    'durationMs': widget.startedAt != null
                        ? DateTime.now().millisecondsSinceEpoch - widget.startedAt!.millisecondsSinceEpoch
                        : null,
                    'pageTimeMs': _pageTimeMs,
                    
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

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      _bumpStepTimeToNow(_currentStepKey());
      _isPaused = true;
      _markAbandoned('inactive_timeout');
    });
  }

  void _cancelTimers() {
    _idleTimer?.cancel();
    _bgAbandonTimer?.cancel();
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
    if (delta > 0) {
      _pageTimeMs += delta;
    }
    _stepEnteredAt = now;
  }

  Future<void> _startSession() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final userDoc = FirebaseFirestore.instance.collection('chi_users').doc(uid);
      final sessions = userDoc.collection('abc_sessions');
      final newSessionId = await _nextSequencedDocId(uid, 'abc_sessions');
      _sessionId = newSessionId;
      await sessions.doc(newSessionId).set({
        'status': 'in_progress',
        'experimentCondition': 'Text_input',
        'startedAt': widget.startedAt ?? FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('세션 시작 실패: $e');
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
        'endedAt': FieldValue.serverTimestamp(),
        'durationMs': widget.startedAt != null
            ? DateTime.now().millisecondsSinceEpoch - widget.startedAt!.millisecondsSinceEpoch
            : null,
        'reason': reason,
        'screen': 'AbcInputScreen_text/${_currentStepKey()}',
        'textLength': _textDiaryController.text.replaceAll(RegExp(r'\s+'), '').length,
        'checkStates': {
          'A': isCheckedA,
          'B': isCheckedB,
          'C1': isCheckedC1,
          'C2': isCheckedC2,
          'C3': isCheckedC3,
        },
        'pageTimeMs': _pageTimeMs,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('세션 중도이탈 기록 실패: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    _markAbandoned('dispose_without_save');
    _textDiaryController.dispose();
    super.dispose();
  }
}