import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';

/// 하단 네비게이션 바 커스텀 위젯 (BottomNavigationBar 기반)
class CustomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const CustomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onDestinationSelected,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      iconSize: 24,
      selectedItemColor: AppColors.indigo,
      unselectedItemColor: Colors.grey,
      backgroundColor: AppColors.grey100,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
        BottomNavigationBarItem(icon: Icon(Icons.library_add), label: '일기 쓰기'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: '일기 목록'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '내 정보'),
        //BottomNavigationBarItem(icon: Icon(Icons.menu), label: '분석'),
      ],
    );
  }
}
