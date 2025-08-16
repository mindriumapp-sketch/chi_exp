import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'daycounter.dart';

class UserProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _userName = '사용자';
  String get userName => _userName;

  String _userEmail = '';
  String get userEmail => _userEmail;

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;

  String _uid = '';
  String get userId => _uid;

  /// 사용자 정보 로딩
  Future<void> loadUserData({UserDayCounter? dayCounter}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      final uid = refreshedUser?.uid;
      if (uid == null) return;

      final doc = await _firestore.collection('chi_users').doc(uid).get();
      final data = doc.data();

      _userName = data?['name'] ?? refreshedUser?.displayName ?? '사용자';
      _userEmail = refreshedUser?.email ?? '';
      _uid = uid;

      if (data?['createdAt'] is Timestamp) {
        _createdAt = (data!['createdAt'] as Timestamp).toDate();
        dayCounter?.setCreatedAt(_createdAt!);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('유저 정보 불러오기 실패: $e');
    }
  }

  /// 사용자 이름 변경
  void updateUserName(String name) {
    _userName = name;
    notifyListeners();
  }
}