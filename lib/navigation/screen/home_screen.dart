import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_guide_screen.dart';
import 'package:gad_app_team/widgets/card_container.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/widgets/aspect_viewport.dart';
import 'package:gad_app_team/navigation/navigation.dart';
import 'package:gad_app_team/models/daycounter.dart';
import 'package:gad_app_team/data/user_provider.dart';

import 'package:gad_app_team/features/contents/diary_directory_screen.dart';
import 'myinfo_screen.dart';

/// 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = '';
  int daysSinceJoin = 0;
  final String date = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final dayCounter = Provider.of<UserDayCounter>(context, listen: false);
      userProvider.loadUserData(dayCounter: dayCounter);
    });
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
        aspect: 9 / 16,
        background: AppColors.grey100,
        child: Scaffold(
      backgroundColor: AppColors.grey100,
      body: _buildBody(),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    )
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _homePage();
      case 1:
        return const AbcGuideScreen();
      case 2:
        return const NotificationDirectoryScreen();
      case 3:
        return const MyInfoScreen();
      default:
        return _homePage();
    }
  }

  Widget _homePage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal:AppSizes.padding),
        children: [
          _buildHeader(),
          SizedBox(height: AppSizes.padding),
          CardContainer(
            title: '연구 참여 안내',
            titleStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안녕하세요.  \n성균관대학교 대학원 LAMDA LAB의 Flutter 연구팀입니다.',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  '저희 연구팀은 디지털 기기에서의 감정일기 작성 화면과 기록 절차가 사용자 경험에 미치는 영향을 연구하고 있습니다.',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  '※ 본 연구는 14일간 진행되며, 원활한 연구를 위해 매일 1회 이상 일기 작성을 부탁드립니다.\n',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold
                  ),
                ),
                Text(
                  '사용 안내',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  " - 하단 탭 '홈': 홈 화면으로 이동",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  " - 하단 탭 '일기 쓰기': 일기 작성 (튜토리얼은 최소 1회 진행 권장)",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  " - 하단 탭 '일기 목록': 작성한 일기 확인",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  " - 하단 탭 '내 정보': 계정 정보 확인, 이름(닉네임)/비밀번호 변경\n",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '개인정보 처리 안내',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  ' - 수집·이용 목적: ',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  ' - 수집 항목: ',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  ' - 보유·이용 기간: 설문조사 종료 후 1년',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  '제공해주신 개인정보는 철저히 관리하며 연구 목적 외에는 절대 사용하지 않습니다. \n',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
                Text(
                  '문의',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '대표 연락처: 010-6480-7296 (김민주)',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '이메일: mindriumapp@gmail.com \n',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '연구에 참여해주셔서 진심으로 감사드립니다.',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16)
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final userService = context.watch<UserProvider>();
    final dayCounter = context.watch<UserDayCounter>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${userService.userName}님, \n좋은 하루 되세요!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),    
              Text(
                '${dayCounter.daysSinceJoin}일째 되는 날',
                style: const TextStyle(fontSize: AppSizes.fontSize, color: AppColors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}