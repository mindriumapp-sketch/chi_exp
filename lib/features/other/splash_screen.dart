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

    try {
      final doc = await FirebaseFirestore.instance
          .collection('chi_users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && data['after_survey_completed'] == true) {
        return '/thanks';
      }
    } catch (_) {
      // 실패 시 홈으로 포워드 (네트워크/권한 오류 등)
    }
    return '/home';
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