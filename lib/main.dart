import 'app.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Firebase 설정 및 사용자 프로바이더
import 'package:gad_app_team/firebase_options.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/daycounter.dart';

// 알림
import 'package:gad_app_team/data/notification_provider.dart';

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
        // 기본 Provider
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => UserDayCounter()),
        // 알림
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}