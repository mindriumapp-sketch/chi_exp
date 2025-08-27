import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_real_start_screen.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';

class AbcConsequenceScreen extends StatelessWidget {
  const AbcConsequenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
        aspect: 9 / 16,
        background: Colors.grey.shade100,
        child:Scaffold(
      appBar: CustomAppBar(title: '예시보기'),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/image/consequence.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              color: Colors.black.withValues(alpha: 0.7),
              child: const Text(
                "C(결과) - 감정, 신체증상, 행동\n가슴이 철렁하면서 두려워졌고, 결국 자전거에서 내려버렸어요.\n그래서 그날은 자전거를 타지 않고 끌면서 산책만 하고 돌아왔어요.",
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
                      pageBuilder: (_, __, ___) => const AbcRealStartScreen(),
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
