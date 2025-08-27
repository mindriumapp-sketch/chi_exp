import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'abc_belief_screen.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';

class AbcActivateScreen extends StatefulWidget {
  const AbcActivateScreen({super.key});

  @override
  State<AbcActivateScreen> createState() => _AbcActivateScreenState();
}

class _AbcActivateScreenState extends State<AbcActivateScreen> {
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
              'assets/image/activating event.png',
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
                'A(상황)\n주말 오후, 날씨가 맑고 공기도 선선해서 오랜만에 자전거를 타려고 공원에 나갔어요.',
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
                      pageBuilder: (_, __, ___) => const AbcBeliefScreen(),
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
