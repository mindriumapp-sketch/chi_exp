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

  // ✅ 빈도/칩 요약(연구 지표 반영)
  final int daysWritten = 8;
  final int totalDays = 10;
  final List<String> selectedChips = ['발표', '불안', '성취감', '사람들', '초조'];

  // 성찰 질문 더미
  final List<String> reflectionPrompts = const [
    '오늘의 불안이 내게 알려주는 유용한 신호는 무엇이었나?',
    '다음 비슷한 상황에서 반복하고 싶은 대처 한 가지는?'
  ];

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      // Gradient는 Container.decoration에 적용, 여기엔 투명만 전달
      background: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(gradient: _bgGradient()),
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
              '기록 기반 자동 분석 결과입니다.\n감정 스펙트럼·핵심 문장을 한눈에 확인해보세요.',
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
        Expanded(child: _miniStat('작성 빈도', '$daysWritten/$totalDays일', Icons.event_available)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat('평균 작성 시간', _averageDurationStr(), Icons.timer_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat('칩 사용', '${selectedChips.length}개 · ${_chipsCharCount(selectedChips)}자', Icons.sell_outlined)),
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
    return SizedBox(
      height: 168, // ✅ 세 카드 동일 높이 유지 (긴 텍스트는 요약 + 더보기)
      child: Container(
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
            Expanded(
              child: Text(
                content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton.icon(
                onPressed: () => _showAbcDetailSheet(label, title, content),
                icon: const Icon(Icons.open_in_full, size: 16),
                label: const Text('더보기'),
                style: TextButton.styleFrom(foregroundColor: AppColors.indigo),
              ),
            ),
          ],
        ),
      ),
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

  String _averageDurationStr() {
    // 목업: 현재 세션 총합을 평균처럼 표기 (실제 연결 시 세션 수로 나눔)
    return _totalDuration(stepTimeMs);
  }

  int _chipsCharCount(List<String> chips) {
    return chips.fold<int>(0, (sum, e) => sum + e.characters.length);
  }

  // 상세 시트 (A/B는 단일 텍스트, C는 탭 3분할)
  void _showAbcDetailSheet(String label, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        if (label != 'C') {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _badge(label),
                    const SizedBox(width: 10),
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
                const SizedBox(height: 20),
              ],
            ),
          );
        } else {
          return DefaultTabController(
            length: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _badge('C'),
                      const SizedBox(width: 10),
                      const Text('결과', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const TabBar(
                      labelColor: Colors.black,
                      indicatorColor: Colors.black,
                      tabs: [
                        Tab(text: '신체'),
                        Tab(text: '감정'),
                        Tab(text: '행동'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(child: Text(c1Key, style: TextStyle(fontSize: 14, height: 1.5))),
                        SingleChildScrollView(child: Text(c2Key, style: TextStyle(fontSize: 14, height: 1.5))),
                        SingleChildScrollView(child: Text(c3Key, style: TextStyle(fontSize: 14, height: 1.5))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  // 배경 그라디언트
  Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

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
