import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/internal_action_button.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/widgets/input_text_field.dart';
import 'package:gad_app_team/widgets/card_container.dart';
import 'package:gad_app_team/widgets/passwod_field.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool isCurrentPasswordVisible = false;
  bool isNewPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final userService = Provider.of<UserProvider>(context, listen: false);
      userService.loadUserData().then((_) {
        _nameController.text = userService.userName;
        _emailController.text = userService.userEmail;
      });
    });
  }

  Future<void> _updateUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    final newName = _nameController.text.trim();
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      _showMessage('기존 비밀번호를 입력해야 수정할 수 있습니다.');
      return;
    }
    if (newPassword.isNotEmpty && newPassword != confirmPassword) {
      _showMessage('새 비밀번호가 일치하지 않습니다.');
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(email: user!.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);

      await user.updateDisplayName(newName);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({ 'name': newName });
      if (!mounted) return;
      Provider.of<UserProvider>(context, listen: false).updateUserName(newName);

      if (newPassword.isNotEmpty) {
        await user.updatePassword(newPassword);
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showMessage('비밀번호가 변경되었습니다. 다시 로그인해주세요.');
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      _showMessage('계정 정보가 성공적으로 수정되었습니다.');
    } on FirebaseAuthException catch (e) {
      _showMessage('수정 실패: ${e.message}');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal:AppSizes.padding),
          children: [
            const SizedBox(height: AppSizes.space),
            _buildInfoCard(),
            TextButton(
              onPressed: _logout,
              child: const Text('로그아웃', style: TextStyle(color: AppColors.indigo)),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildInfoCard() {
    final userService = context.read<UserProvider>();
    final createdAt = userService.createdAt;
    final formattedDate = createdAt != null ? DateFormat('yyyy년 MM월 dd일').format(createdAt) : '가입일 정보 없음';

    return CardContainer(
      title: '계정 정보',
      child: Column(
        children: [
          InputTextField(label: '이름(닉네임)', controller: _nameController),
          const SizedBox(height: AppSizes.space),
          InputTextField(label: '이메일', controller: _emailController, enabled: false),
          const SizedBox(height: AppSizes.space),
          Align(
            alignment: Alignment.centerRight,
            child: Text('가입일: $formattedDate', style: const TextStyle(color: AppColors.grey)),
          ),
          const Divider(thickness: 1, color: AppColors.black12),
          const SizedBox(height: AppSizes.space),

          PasswordTextField(
            label: '기존 비밀번호',
            controller: _currentPasswordController,
            isVisible: isCurrentPasswordVisible,
            toggleVisibility: () {
              setState(() {
                isCurrentPasswordVisible = !isCurrentPasswordVisible;
              });
            },
          ),
          const SizedBox(height: AppSizes.space),

          PasswordTextField(
            label: '새 비밀번호',
            controller: _newPasswordController,
            isVisible: isNewPasswordVisible,
            toggleVisibility: () {
              setState(() {
                isNewPasswordVisible = !isNewPasswordVisible;
              });
            },
          ),
          const SizedBox(height: AppSizes.space),

          PasswordTextField(
            label: '새 비밀번호 확인',
            controller: _confirmPasswordController,
            isVisible: isConfirmPasswordVisible,
            toggleVisibility: () {
              setState(() {
                isConfirmPasswordVisible = !isConfirmPasswordVisible;
              });
            },
          ),
          const SizedBox(height: AppSizes.space),
          const SizedBox(height: AppSizes.space),
          Center(child: InternalActionButton(onPressed: _updateUserInfo, text: '계정 정보 수정')),
        ],
      ),
    );
  }
}