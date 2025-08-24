// lib/features/llm/abc_analysis_screen.dart
// ABC 감정일기 "분석" 전용 화면 (UI 목업) — 데이터 연결 없이 시각만 화려하게
// - 네비게이션/스타일은 기존 앱 컴포넌트에 맞춤 (CustomAppBar, AspectViewport, NavigationButtons, AppColors)
// - 실제 분석 데이터 연결 전까지 더미 값으로 동작

import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

class AbcAnalysisScreen extends StatefulWidget {
  const AbcAnalysisScreen({super.key});

  @override
  State<AbcAnalysisScreen> createState() => _AbcAnalysisScreenState();
}

class _AbcAnalysisScreenState extends State<AbcAnalysisScreen> {
  // ====== 더미 데이터 (API 연결 전) ======
  // 오늘 기록 스냅샷
  final String aKey = '발표 10분 전 대기';
  final String bKey = '내가 실수하면 모두가 비웃을 거야';
  final String c1Key = '심장 두근거림 · 손떨림';
  final String c2Key = '불안 · 초조 · 압박감';
  final String c3Key = '시선 회피 · 내용을 급히 수정함';

  // 감정 다양성(0~1 가정)
  final double diversity = 0.64;

  // 감정 태그 클라우드(항목, 등장 횟수)
  final List<(String, int)> emotions = [
    ('불안', 6), ('긴장', 4), ('초조', 3), ('성취감', 2), ('감사', 1)
  ];

  // 단계별 소요시간(ms 가정 → UI에서는 분:초로 표기)
  final Map<String, int> stepTimeMs = const {
    'A': 78 * 1000, // 1:18
    'B': 125 * 1000, // 2:05
    'C1': 43 * 1000,
    'C2': 52 * 1000,
    'C3': 36 * 1000,
  };

  // 패턴/트리거/대처 습관 더미
  final List<String> triggers = ['공식 발표', '낯선 청중', '시간 압박'];
  final List<String> distortions = ['흑백논리', '재앙화', '과잉일반화'];
  final List<String> coping = ['심호흡 4-6-4', '메모로 생각 정리', '발표 전 리허설'];

  // 성찰 질문 더미
  final List<String> reflectionPrompts = [
    '오늘의 불안이 내게 알려주는 유용한 신호는 무엇이었나?',
    '다음 비슷한 상황에서 반복하고 싶은 대처 한 가지는?'
  ];

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      background: _bgGradient().colors.first,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(title: '오늘의 분석'),
        body: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _banner(),
                  const SizedBox(height: 14),
                  _summaryRow(),
                  const SizedBox(height: 14),
                  _emotionDiversityCard(),
                  const SizedBox(height: 14),
                  _abcKeyCards(),
                  const SizedBox(height: 14),
                  _patternRow(),
                  const SizedBox(height: 14),
                  _reflectionBox(),
                  const SizedBox(height: 90), // bottom nav 공간
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: NavigationButtons(
            leftLabel: '돌아가기',
            rightLabel: '완료',
            onBack: () => Navigator.pop(context),
            onNext: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
          ),
        ),
      ),
    );
  }

  // ======= 위젯 빌더 =======
  Widget _banner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          _softIcon(Icons.auto_graph, bg: AppColors.indigo.withOpacity(.12), fg: AppColors.indigo),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '기록 기반 자동 분석 결과입니다.\n패턴·감정 다양성·핵심 문장을 한눈에 확인해보세요.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow() {
    return Row(
      children: [
        Expanded(child: _miniStat('감정 다양성', '${(diversity * 100).round()}%', Icons.bubble_chart)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat('총 작성 시간', _totalDuration(stepTimeMs), Icons.timer_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat('태그 수', emotions.length.toString(), Icons.sell_outlined)),
      ],
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white.withOpacity(.96), Colors.white.withOpacity(.88)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _softIcon(icon, bg: AppColors.indigo.withOpacity(.12), fg: AppColors.indigo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emotionDiversityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFeef2ff), Color(0xFFe0e7ff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('감정 다양성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              _diversityDial(diversity),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in emotions) _chipCount(e.$1, e.$2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _abcKeyCards() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _abcCard('A', '상황', aKey, const Color(0xFFe3f2fd), Icons.location_on_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _abcCard('B', '생각', bKey, const Color(0xFFf3e8ff), Icons.psychology_alt_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _abcCard('C', '결과', '$c1Key\n$c2Key\n$c3Key', const Color(0xFFe8fff3), Icons.favorite_outline)),
      ],
    );
  }

  Widget _patternRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _patternCard('트리거', triggers, const Color(0xFFFEF3C7), Icons.flash_on_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _patternCard('사고 패턴', distortions, const Color(0xFFFFE4E6), Icons.track_changes_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _patternCard('대처 습관', coping, const Color(0xFFDCFCE7), Icons.self_improvement_outlined)),
      ],
    );
  }

  Widget _reflectionBox() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.indigo,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.indigo.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘의 성찰 질문', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ...reflectionPrompts.map((q) => _bullet(q)).toList(),
        ],
      ),
    );
  }

  // ======= 요소 위젯 =======
  Widget _diversityDial(double v) {
    // CircularProgressIndicator 커스텀 느낌으로 구현
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 6,
              backgroundColor: Colors.white.withOpacity(.6),
              valueColor: AlwaysStoppedAnimation(AppColors.indigo),
            ),
          ),
          Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _chipCount(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tag, size: 16, color: AppColors.indigo.withOpacity(.9)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.indigo.withOpacity(.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count', style: TextStyle(color: AppColors.indigo, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _abcCard(String label, String title, String content, Color tint, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white, tint], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(label),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.bold)),
              ),
              _softIcon(icon, bg: AppColors.indigo.withOpacity(.08), fg: AppColors.indigo),
            ],
          ),
          const SizedBox(height: 10),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _patternCard(String title, List<String> items, Color tint, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [Colors.white, tint], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _softIcon(icon, bg: Colors.black.withOpacity(.06), fg: Colors.black87),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        ...items.map((e) => _bullet(e)).toList(),
      ]),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6, right: 8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black54, width: 1.2), shape: BoxShape.circle)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45))),
        ],
      ),
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.indigo,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.indigo.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _softIcon(IconData icon, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: fg, size: 20),
    );
  }

  String _totalDuration(Map<String, int> map) {
    final totalMs = map.values.fold<int>(0, (a, b) => a + b);
    final m = (totalMs / 60000).floor();
    final s = ((totalMs % 60000) / 1000).round();
    final mm = m.toString().padLeft(1, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // 배경 그라디언트
  Color _mix(Color a, Color b, double t) {
    return Color.lerp(a, b, t)!;
  }

  LinearGradient _bgGradient() {
    return LinearGradient(
      colors: [
        _mix(AppColors.indigo, Colors.white, .86),
        _mix(Colors.purple, Colors.white, .90),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
