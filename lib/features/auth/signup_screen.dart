import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:gad_app_team/widgets/input_text_field.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';
import 'package:gad_app_team/widgets/passwod_field.dart';

/// 회원가입 화면 - 이메일, 이름, 비밀번호, 마인드리움 코드로 회원가입
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final codeController = TextEditingController();

  bool showPassword = false;
  bool showConfirmPassword = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> checkMindriumCode(String inputCode) async {
    String code = inputCode.trim();
    try {
      final doc = await FirebaseFirestore.instance.collection('codes').doc(code).get();
      return doc.exists && (doc.data()?['valid'] == true);
    } catch (e) {
      debugPrint("코드 확인 중 오류 발생: $e");
      return false;
    }
  }

  Future<void> _signup() async {
    final email = emailController.text.trim();
    final name = nameController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final code = codeController.text.trim();

    if ([email, name, password, confirmPassword, code].any((e) => e.isEmpty)) {
      _showError('모든 필드를 입력해주세요.');
      return;
    }

    if (password.length < 6) {
      _showError('비밀번호는 6자리 이상이어야 합니다.');
      return;
    }

    if (password != confirmPassword) {
      _showError('비밀번호가 일치하지 않습니다.');
      return;
    }

    final isValidCode = await checkMindriumCode(code);
    if (!isValidCode) {
      _showError('유효하지 않은 마인드리움 코드입니다.');
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance.collection('chi_users').doc(userCredential.user!.uid).set({
        'email': email,
        'name': name,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다.')),
      );

      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'email-already-in-use') {
        _showError('이미 등록된 이메일입니다. 로그인 화면으로 이동합니다.');
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login', arguments: {
          'email': email,
          'password': password,
        });
      } else if (e.code == 'network-request-failed') {
        _showError('네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.');
      } else {
        _showError('회원가입 실패: ${e.message}');
        debugPrint("FirebaseAuthException: ${e.code} / ${e.message}");
      }
    } catch (e, stack) {
      _showError('알 수 없는 오류 발생: $e');
      debugPrint("Exception: $e");
      debugPrint("Stack trace: $stack");
    }
  }

  @override
  void didChangeDependencies() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      emailController.text = args['email'] ?? '';
      passwordController.text = args['password'] ?? '';
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('회원가입'),
        leading: Padding(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () {Navigator.pop(context);},
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          children: [
            InputTextField(
              controller: emailController, 
              fillColor:Colors.white,
              label: '이메일', 
              keyboardType: TextInputType.emailAddress
            ),
            const SizedBox(height: AppSizes.space),
            InputTextField(
              controller: nameController, 
              label: '이름(닉네임)',
              fillColor:Colors.white,
            ),
            const SizedBox(height: AppSizes.space),
            PasswordTextField(
              controller: passwordController,
              label: '비밀번호',
              isVisible: showPassword,
              toggleVisibility: () {
                setState(() {
                  showPassword = !showPassword;
                });
              },
            ),
            const SizedBox(height: AppSizes.space),
            PasswordTextField(
              controller: confirmPasswordController,
              label: '비밀번호 확인',
              isVisible: showConfirmPassword,
              toggleVisibility: () {
                setState(() {
                  showConfirmPassword = !showConfirmPassword;
                });
              },
            ),
            const SizedBox(height: AppSizes.space),
            InputTextField(
              controller: codeController, 
              label: '마인드리움 코드',
              fillColor:Colors.white,
            ),
            const SizedBox(height: AppSizes.space),
            const SizedBox(height: AppSizes.space),
            PrimaryActionButton(text: '회원가입', onPressed: _signup),
          ],
        ),
      ),
    );
  }
}
