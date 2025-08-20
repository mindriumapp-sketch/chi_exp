

import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class ThanksScreen extends StatelessWidget {
  const ThanksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userService = context.watch<UserProvider>();
    return AspectViewport(
      aspect: 9 / 16,
      background: AppColors.grey100,
      child: Scaffold(
        backgroundColor: AppColors.grey100,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '실험 종료 안내',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: AppSizes.space),
                    Text(
                      '${userService.userName}님 실험에 끝까지 참여해 주셔서 다시 한번 진심으로 감사드립니다.',
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: AppSizes.space),
                    Text(
                      '${userService.userName}님께서 제공해주신 소중한 데이터는 저희 연구팀에게 큰 도움이 될 것입니다. \n저희는 이 연구를 통해 더 나은 감정일기 앱을 개발하고, 디지털 기술이 정신건강 증진에 기여할 수 있는 방안을 모색하겠습니다.',
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: AppSizes.space),
                    Text(
                      '사례비는 설문 종료 후 기재해주신 연락처로 안내 드릴 예정입니다.',
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: AppSizes.space),
                    Text(
                      '추가 문의사항은 아래 연락망을 통해 연락주시면 감사하겠습니다.',
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: AppSizes.space),
                    Text(
                      '항상 건강하시고, 좋은 하루 보내시길 바랍니다.',
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: AppSizes.space),
                    Text(
                      '감사합니다.',
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: AppSizes.space),
                    Text(
                      '대표 연락처: 010-6480-7296 (김민주)',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      'E-mail: mindriumapp@gmail.com',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: AppSizes.space*2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '성균관대학교 LAMDA Lab',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Flutter 팀',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}