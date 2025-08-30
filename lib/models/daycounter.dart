import 'dart:async';
import 'package:flutter/material.dart';

class UserDayCounter extends ChangeNotifier {
  DateTime? _createdAt;
  Timer? _timer;

  void setCreatedAt(DateTime date) {
    _createdAt = date;
    _startDailyTimer();
    notifyListeners();
  }

  bool get isUserLoaded => _createdAt != null;

  int get daysSinceJoin {
    if (_createdAt == null) return 0;
    // 날짜(자정) 기준으로 계산: 시간 요소 제거
    final start = DateTime(_createdAt!.year, _createdAt!.month, _createdAt!.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays + 1;
  }

  int getWeekNumberFromJoin(DateTime targetDate) {
    if (_createdAt == null) return 0;
    // 날짜(자정) 기준 주차 계산
    final start = DateTime(_createdAt!.year, _createdAt!.month, _createdAt!.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final daysDiff = target.difference(start).inDays;
    return daysDiff < 0 ? 0 : (daysDiff ~/ 7) + 1;
  }

  void _startDailyTimer() {
    _timer?.cancel();

    void scheduleNextMidnightTick() {
      final now = DateTime.now();
      // 다음 자정(로컬) 시각
      final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final wait = nextMidnight.difference(now);

      _timer = Timer(wait, () {
        // 날짜가 바뀌는 시점에 갱신 후, 다음 자정으로 재예약
        notifyListeners();
        scheduleNextMidnightTick();
      });
    }

    scheduleNextMidnightTick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

