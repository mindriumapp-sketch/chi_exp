import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'abc_belief_screen.dart';

class AbcActivateScreen extends StatefulWidget {
  const AbcActivateScreen({super.key});

  @override
  State<AbcActivateScreen> createState() => _AbcActivateScreenState();
}

class _AbcActivateScreenState extends State<AbcActivateScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: '일기 쓰기 (튜토리얼)'),
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
              color: Colors.black.withValues(alpha: 0.45),
              child: const Text(
                'A(상황)\n주말 오후, 날씨가 맑고 공기도 선선해서 오랜만에 자전거를 타려고 공원에 나갔어요. 사람들이 삼삼오오 자전거를 타고 있는 모습을 보니 저도 괜히 설레었죠.\n한참 안 타다가 다시 탈 생각을 하니 조금 긴장되긴 했지만, \'괜찮아, 천천히 하면 되지\' 하며 자전거를 꺼냈어요.',
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
      ),
    );
  }
}
