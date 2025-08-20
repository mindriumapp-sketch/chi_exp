import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/features/2nd_treatment/week2_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_chip.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_text.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';

class AbcGuideScreen extends StatefulWidget {
  const AbcGuideScreen({super.key});

  @override
  State<AbcGuideScreen> createState() => _AbcGuideScreenState();
}

class _AbcGuideScreenState extends State<AbcGuideScreen> {
  @override
  Widget build(BuildContext context) {
    return AspectViewport(
        aspect: 9 / 16,
        background: AppColors.grey100,
        child: Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
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
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'ABC 모델은 인지행동치료(Cognitive Behavioral Therapy, CBT)에서 사용되는 대표적인 기법 중 하나로, 사람의 정서적 반응과 행동이 특정 사건 자체보다는 그 사건에 대한 생각(믿음)에 의해 결정된다는 개념을 바탕으로 합니다. 이 모델은 미국의 심리학자 앨버트 엘리스가 1950년대에 개발한 합리적 정서행동치료의 핵심 구성 요소로 소개되었습니다. 앞으로 감정 일기를 매일매일 작성할 예정이며, 인지행동치료(CBT)의 핵심 기법인 ABC 모델을 기반으로 기록할 것입니다.',
              style: TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
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
                    child: const Text('튜토리얼'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),)
    );
  }
}
