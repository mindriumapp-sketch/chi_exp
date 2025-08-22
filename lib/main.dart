import 'app.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Firebase 설정 및 사용자 프로바이더
import 'package:gad_app_team/firebase_options.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/models/daycounter.dart';

// 알림
import 'package:gad_app_team/data/notification_provider.dart';

// ✅ [임시 테스트용] LLM 테스트 화면 import
// import 'package:gad_app_team/features/llm/llm_test_screen.dart'; // ← 이 파일만 임시로 추가

/// 앱 시작점 (entry point)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase 초기화 (환경별 설정 적용)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2) 전역 상태 관리를 위한 MultiProvider 설정 및 앱 실행
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => UserDayCounter()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      // ✅ [임시 테스트용] LLM 화면으로 진입점 임시 변경
      // child: const MaterialApp(
      //   debugShowCheckedModeBanner: false,
      //   home: AbcAnalysisScreen(), // ← ✅ 이 줄만 나중에 삭제 or 변경하면 됨
      // ),

      // 🔁 원래 진입점 복구할 때는 아래처럼 바꾸면 됩니다:
      child: const MyApp(),
    ),
  );
}
