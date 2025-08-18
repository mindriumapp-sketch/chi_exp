import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'abc_consequence_screen.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';

class AbcBeliefScreen extends StatelessWidget {
  const AbcBeliefScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: '일기 쓰기 (튜토리얼)'),
      body: AspectViewport(
        aspect: 9 / 16,
        background: Colors.grey.shade100,
        child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/image/belief.png', fit: BoxFit.cover),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              color: Colors.black.withValues(alpha: 0.45),
              child: const Text(
                'B(생각)\n막 자전거에 올라타서 페달을 밟으려는 순간, 균형이 살짝 흔들렸고 ‘넘어질 것 같아…’ 라는 생각이 들었어요.\n예전에 자전거 타다 넘어져서 다쳤던 기억이 갑자기 떠올랐고, 그때의 아픔이 다시 느껴지는 것 같았어요.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.left,
                softWrap: true,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: NavigationButtons(
                onBack: () => Navigator.pop(context),
                onNext: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const AbcConsequenceScreen(),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),)
    );
  }
}
