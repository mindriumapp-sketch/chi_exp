import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/features/2nd_treatment/week2_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_chip.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_text.dart';

class AbcGuideScreen extends StatefulWidget {
  const AbcGuideScreen({super.key});

  @override
  State<AbcGuideScreen> createState() => _AbcGuideScreenState();
}

class _AbcGuideScreenState extends State<AbcGuideScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Icon(Icons.psychology, size: 100, color: Colors.indigo),
                  const SizedBox(height: 32),
                  const Text(
                    'ABC 모델이란?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 20, color: Colors.black),
                      children: [
                        TextSpan(text: 'ABC 일기는 인지행동치료에서 사용되는 일기 쓰기 방식입니다. '),
                        TextSpan(text: '오늘 있었던 사건(A)', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '에 대한 '),
                        TextSpan(text: '나의 생각(B) ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '을 기록하면, 그 생각이 '),
                        TextSpan(text: '어떤 감정이나 행동(C)', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '을 유발했는지 이해하는 데 도움이 됩니다.'),
                      ]
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 16),

                  const Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 20, color: Colors.black),
                      children: [
                        TextSpan(text: '앞으로 ABC 모델을 기반으로 '),
                        TextSpan(text: '걱정 일기를 '),
                        TextSpan(text: '매일 1회 ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '작성 부탁드립니다.'),
                      ],
                    ),
                    textAlign: TextAlign.left,
                  ),
                  Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                            ),
                          ),
                          onPressed: () async {
                            final startedAt = DateTime.now();
                            final ctx = context;

                            // 기본 화면: 칩 버전
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
                                  // 칩 입력 화면
                                  next = AbcInputScreen(
                                    startedAt: startedAt,
                                  );
                                  debugPrint('Chip input');
                                } else if (codes == 1234) {
                                  // 텍스트 입력 화면
                                  next = AbcInputTextScreen(
                                    startedAt: startedAt,
                                  );
                                  debugPrint('Text input');
                                }
                              }
                            } catch (_) {
                              debugPrint('default input');
                            }

                            if (!ctx.mounted) return;
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(builder: (_) => next),
                            );
                          },
                          child: const Text('작성하기'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.indigo,
                            side: BorderSide(color: Colors.indigo.shade100),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => const Week2Screen(),
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          },
                          child: const Text('예시보기'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ),
    );
  }
}
