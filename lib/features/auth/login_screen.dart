import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gad_app_team/widgets/input_text_field.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

/// 로그인 화면: 이메일과 비밀번호로 인증
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요.');
      return;
    }

    // 1) Auth 단계: FirebaseAuthException 은 사용자 친화 메시지로 분기
    UserCredential cred;
    try {
      cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _handleLoginError(e.code, email, password);
      return;
    } catch (e, st) {
      // 예기치 못한 인증 오류
      debugPrint('[LOGIN][Auth] Unhandled error: $e\n$st');
      _showError('로그인 중 알 수 없는 오류가 발생했습니다. (디버그 콘솔 참고)');
      return;
    }

    final user = cred.user;
    if (user == null) {
      _showError('로그인에 실패했습니다. 다시 시도해주세요.');
      return;
    }

    // 2) Firestore 단계: FirebaseException 코드 별 안내
    DocumentSnapshot<Map<String, dynamic>> userDoc;
    try {
      userDoc = await FirebaseFirestore.instance
          .collection('chi_users')
          .doc(user.uid)
          .get();
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          _showError('계정 정보를 읽을 권한이 없습니다. 관리자에게 문의하세요.');
          break;
        case 'unavailable':
          _showError('네트워크 상태가 불안정합니다. 연결 후 다시 시도해주세요.');
          break;
        default:
          _showError('사용자 정보 조회 실패: ${e.code}');
      }
      return;
    } catch (e, st) {
      debugPrint('[LOGIN][Firestore] Unhandled error: $e\n$st');
      _showError('사용자 정보 조회 중 알 수 없는 오류가 발생했습니다.');
      return;
    }

    // Firestore 문서가 없으면 약관/회원가입 플로우로 유도 (앱 흐름에 맞게 조정)
    if (!userDoc.exists) {
      if (!mounted) return;
      Navigator.pushNamed(context, '/terms', arguments: {
        'email': email,
        'password': password,
      });
      return;
    }

    // 3) SharedPreferences 단계: 실패해도 치명적이지 않으므로 로그만 남김
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('uid', user.uid);
    } catch (e, st) {
      debugPrint('[LOGIN][Prefs] $e\n$st');
    }

    if (!mounted) return;

    // 4) 라우팅 단계: 라우트 미등록/오타 등 대비
    try {
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {
          'uid': user.uid,
          'email': user.email,
          'userData': userDoc.data(),
        },
      );
    } catch (e, st) {
      debugPrint('[LOGIN][Routing] $e\n$st');
      _showError('화면 전환 실패: /home 라우트를 확인해주세요.');
    }
  }

  void _handleLoginError(String code, String email, String password) {
    switch (code) {
      case 'user-not-found':
        Navigator.pushNamed(context, '/terms', arguments: {
          'email': email,
          'password': password,
        });
        break;
      case 'wrong-password':
        _showError('비밀번호가 잘못되었습니다.');
        break;
      case 'invalid-email':
        _showError('유효하지 않은 이메일 형식입니다.');
        break;
      case 'user-disabled':
        _showError('해당 계정은 비활성화되었습니다.');
        break;
      case 'too-many-requests':
        _showError('로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요.');
        break;
      case 'operation-not-allowed':
        _showError('이메일/비밀번호 로그인이 비활성화되어 있습니다.');
        break;
      default:
        _showError('로그인 실패: $code');
    }
  }

  void _goToSignup() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    Navigator.pushNamed(context, '/terms', arguments: {
      'email': email,
      'password': password,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSizes.space),
              Center(
                child: Image.asset(
                  'assets/image/logo.png',
                  height: 160,
                  width: 160,
                ),
              ),
              const SizedBox(height: AppSizes.space),
              InputTextField(
                controller: emailController,
                fillColor:Colors.white,
                label: '이메일',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSizes.space),
              InputTextField(
                controller: passwordController,
                fillColor:Colors.white,
                label: '비밀번호',
                obscureText: true,
              ),
              const SizedBox(height: AppSizes.space),

              PrimaryActionButton(
                text: '로그인',
                onPressed: _login,
              ),

              TextButton(
                onPressed: _goToSignup,
                child: const Text('회원가입')
              ),
            ],
          ),
        ),
      ),
    );
  }
}