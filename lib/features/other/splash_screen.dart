import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 앱 실행 시 처음 보여지는 스플래시 화면
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<String> _resolveNextRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') == true;
    if (!isLoggedIn) return '/login';

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '/login';

    // 10일 경과 여부 판단: FirebaseAuth의 계정 생성 시간 기준
    final createdAt = user.metadata.creationTime;
    if (createdAt == null) {
      // 생성 시간이 없으면 홈으로 (보수적 처리)
      return '/home';
    }

    final now = DateTime.now();
    final diffDays = now.difference(createdAt).inDays;

    // 10일 이전이면 홈으로
    if (diffDays < 10) {
      return '/home';
    }

    // 10일 이후: after_survey_completed에 따라 분기
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chi_users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final completed = data != null && data['after_survey_completed'] == true;
      return completed ? '/thanks' : '/after_survey';
    } catch (_) {
      // 실패 시 홈으로 포워드 (네트워크/권한 오류 등)
      return '/home';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolveNextRoute(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildSplashUI();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final route = snapshot.data ?? '/login';
          Navigator.pushReplacementNamed(context, route);
        });

        return _buildSplashUI();
      },
    );
  }

  Widget _buildSplashUI() {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/image/logo.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: AppSizes.space),
                const Text(
                  'Mindrium',
                  style: TextStyle(
                    fontSize: AppSizes.fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: AppSizes.space),
                const CircularProgressIndicator(color: AppColors.indigo),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppSizes.padding),
            child: Text(
              '걱정하지 마세요. 충분히 잘하고있어요.',
              style: TextStyle(fontSize: AppSizes.fontSize, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}