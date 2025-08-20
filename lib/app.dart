import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_guide_screen.dart';
import 'package:gad_app_team/features/contents/after_survey.dart';
import 'package:gad_app_team/features/contents/before_survey.dart';

//notification
import 'package:gad_app_team/features/contents/diary_directory_screen.dart';

// Feature imports
import 'package:gad_app_team/features/auth/login_screen.dart';
import 'package:gad_app_team/features/auth/signup_screen.dart';
import 'package:gad_app_team/features/auth/terms_screen.dart';
import 'package:gad_app_team/features/contents/thanks_screen.dart';
import 'package:gad_app_team/features/other/splash_screen.dart';

// Navigation screen imports
import 'package:gad_app_team/navigation/screen/home_screen.dart';
import 'package:gad_app_team/navigation/screen/myinfo_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
/// Mindrium 메인 앱 클래스
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 
      debugShowCheckedModeBanner: false,
      title: 'Mindrium',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.indigo),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko'), // 한국어
        Locale('en'), // 영어 (기본값)
      ],
      home: const SplashScreen(),
      routes: {
        // 인증 관련
        '/login': (context) => const LoginScreen(),
        '/terms': (context) => const TermsScreen(),
        '/signup': (context) => const SignupScreen(),

        // 네비게이션
        '/home': (context) => const HomeScreen(),
        '/myinfo': (context) => const MyInfoScreen(),

        //treatment
        '/week2': (context) => const AbcGuideScreen(),

        '/diary_directory': (context) => NotificationDirectoryScreen(),
        '/before_survey': (context) => BeforeSurveyScreen(),
        '/after_survey': (context) => AfterSurveyScreen(),
        '/thanks': (context) => ThanksScreen(),

      },
    );
  }
}