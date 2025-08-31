import 'package:flutter/material.dart';
import '../../common/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_chip.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_text.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';

class AbcRealStartScreen extends StatelessWidget {
  const AbcRealStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      background: Colors.grey.shade100,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Scrollable content
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 148), // space for fixed buttons
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const [
                          Icon(Icons.edit_note, size: 100, color: AppColors.indigo),
                          SizedBox(height: 32),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(fontSize: 20, color: Colors.black),
                              children: [
                                TextSpan(text: 'ABC 모델은 '),
                                TextSpan(text: 'A(상황)-B(생각)-C(결과)\n', style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: '로 나눠 적어 내 감정과 행동의 패턴을 발견하는 일기 작성 기법입니다.\n'),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'ABC 모델을 예시로 알아보는 과정이 끝났습니다!\n이제 실제로 작성해볼까요?',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Fixed bottom buttons
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: () async {
                              final startedAt = DateTime.now();
                              final ctx = context;
                              // 기본값: 칩 입력 화면
                              Widget next = AbcInputScreen(
                                startedAt: startedAt,
                              );
                              try {
                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                if (uid != null) {
                                  final snap = await FirebaseFirestore.instance
                                      .collection('chi_users')
                                      .doc(uid)
                                      .get();
                                  final data = snap.data();
                                  final dynamic rawCodes = data?['code'];
                                  int? codes;
                                  if (rawCodes is int) {
                                    codes = rawCodes;
                                  } else if (rawCodes is String) {
                                    codes = int.tryParse(rawCodes);
                                  }
                                  if (codes == 7890) {
                                    next = AbcInputScreen(
                                      startedAt: startedAt,
                                    );
                                    debugPrint('Chip input');
                                  } else if (codes == 1234) {
                                    next = AbcInputTextScreen(
                                      startedAt: startedAt,
                                    );
                                    debugPrint('Text input');
                                  }
                                }
                              } catch (_) {
                                // 실패 시 기본(next) 사용
                              }
                              if (!ctx.mounted) return;
                              Navigator.pushReplacement(
                                ctx,
                                MaterialPageRoute(builder: (_) => next),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                              ),
                            ),
                            child: const Text('작성하기'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.indigo,
                              side: BorderSide(color: Colors.indigo),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                              ),
                            ),
                            child: const Text('홈으로'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
