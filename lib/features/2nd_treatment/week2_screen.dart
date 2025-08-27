import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_activate_screen.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';

class Week2Screen extends StatefulWidget {
  const Week2Screen({super.key});

  @override
  State<Week2Screen> createState() => _Week2ScreenState();
}

class _Week2ScreenState extends State<Week2Screen> {
  @override
  Widget build(BuildContext context) {
    return AspectViewport(
        aspect: 9 / 16,
        background: AppColors.grey100,
        child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: CustomAppBar(title: '예시보기'),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(Icons.lightbulb, size: 72, color: Color(0xFF3F51B5)),
                const SizedBox(height: 32),
                const Text(
                  '예시를 통해 알아볼까요?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  '자전거를 타려고 했을 때의 상황을\n예시로 살펴볼게요.',
                  style: TextStyle(fontSize: 20, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                NavigationButtons(
                  onBack: () => Navigator.pop(context),
                  onNext: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const AbcActivateScreen(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                ),
              ],
            ),
          )
        )
      )
    );
  }
}
