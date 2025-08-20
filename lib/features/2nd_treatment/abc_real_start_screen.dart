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
        child:Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.edit_note, size: 64, color: AppColors.indigo),
              const SizedBox(height: 32),
              const Text(
                'ABC 모델은 A(상황)-B(생각)-C(결과)로 나눠 적어 내 감정과 행동의 패턴을 발견하는 일기 작성 기법이에요! \n',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                '실제로 작성해볼까요?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                '이제 실제로 나의 사례를 떠올리며 걱정일기를 작성해보세요.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
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
                  backgroundColor: AppColors.indigo,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('작성하기'),
              ),
            ],
          ),
        ),
      ),)
    );
  }
}
