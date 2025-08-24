// lib/features/llm/abc_complete_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

class AbcCompleteScreen extends StatelessWidget {
  final String userId;
  final String abcId;

  const AbcCompleteScreen({
    super.key,
    required this.userId,
    required this.abcId,
  });

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      background: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(gradient: _bgGradient()),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const CustomAppBar(title: '감정일기 리포트'),
          body: SafeArea(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('chi_users')
                  .doc(userId)
                  .collection('abc_models')
                  .doc(abcId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('일기 데이터가 없습니다.'));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ABC 섹션은 컴팩트하게
                      _AbcCompact(
                        activatingEvent: data['activatingEvent'] ?? '',
                        belief: data['belief'] ?? '',
                        c1Physical: data['c1_physical'] ?? '',
                        c2Emotion: data['c2_emotion'] ?? '',
                        c3Behavior: data['c3_behavior'] ?? '',
                      ),
                      const SizedBox(height: 18),
                      _ReportCard(report: data['report'] ?? '리포트가 없습니다.'),
                    ],
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: NavigationButtons(
              leftLabel: '돌아가기',
              rightLabel: '홈으로',
              onBack: () => Navigator.pop(context),
              onNext: () =>
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- ABC 컴팩트 섹션 ----------------
class _AbcCompact extends StatelessWidget {
  final String activatingEvent;
  final String belief;
  final String c1Physical;
  final String c2Emotion;
  final String c3Behavior;

  const _AbcCompact({
    required this.activatingEvent,
    required this.belief,
    required this.c1Physical,
    required this.c2Emotion,
    required this.c3Behavior,
  });

  // 콤마로 구분된 칩 문자열을 리스트로 변환
  List<String> _splitChips(String value) {
    return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(text: '오늘의 ABC 일기'),
            const SizedBox(height: 12),

            // A: 상황 (칩 형태, 텍스트 길이에 맞게)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _circleBadge('A', AppColors.indigo),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('상황',
                          style: TextStyle(
                              color: AppColors.indigo,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _splitChips(activatingEvent)
                            .map((chip) => _autoChipBox(chip, AppColors.indigo))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // B: 생각 (칩 형태, 텍스트 길이에 맞게)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _circleBadge('B', Colors.pink),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('생각',
                          style: TextStyle(
                              color: Colors.pink,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _splitChips(belief)
                            .map((chip) => _autoChipBox(chip, Colors.pink))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // C: 신체/감정/행동을 세로로 나열, 각 칩을 길게(텍스트 길이에 맞게)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _circleBadge('C', Colors.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 신체
                      Row(
                        children: [
                          Icon(Icons.favorite, color: Colors.pink.shade400, size: 17),
                          const SizedBox(width: 4),
                          Text('신체',
                              style: TextStyle(
                                  color: Colors.pink.shade400,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _splitChips(c1Physical)
                            .map((chip) => _autoChipBox(chip, Colors.pink.shade400))
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      // 감정
                      Row(
                        children: [
                          Icon(Icons.emoji_emotions, color: Colors.amber.shade700, size: 17),
                          const SizedBox(width: 4),
                          Text('감정',
                              style: TextStyle(
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _splitChips(c2Emotion)
                            .map((chip) => _autoChipBox(chip, Colors.amber.shade700))
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      // 행동
                      Row(
                        children: [
                          Icon(Icons.directions_run, color: Colors.teal, size: 17),
                          const SizedBox(width: 4),
                          Text('행동',
                              style: TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _splitChips(c3Behavior)
                            .map((chip) => _autoChipBox(chip, Colors.teal))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 텍스트 길이에 맞는 칩 박스
  Widget _autoChipBox(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }

  Widget _circleBadge(String text, Color color) {
    return CircleAvatar(
      backgroundColor: color,
      radius: 16,
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

// ---------------- 리포트 카드 (더보기/접기, 풀폭, 화사한 스타일) ----------------
class _ReportCard extends StatefulWidget {
  final String report;
  const _ReportCard({required this.report});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> with TickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.indigo.shade700;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity, // 화면 꽉 채움
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFc7d2fe), Color(0xFFe0e7ff), Color(0xFFeef2ff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: primary.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primary.withOpacity(0.2)),
                  ),
                  child: Icon(Icons.auto_awesome, color: primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '감정일기 리포트',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 0.3,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    foregroundColor: primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  child: Text(
                    _expanded ? '접기' : '더보기',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 본문 (회색 페이드 제거, 더보기 시 전체 표시)
            AnimatedCrossFade(
              firstChild: Text(
                widget.report,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  height: 1.7,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Pretendard',
                ),
              ),
              secondChild: Text(
                widget.report,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  height: 1.8,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Pretendard',
                ),
              ),
              crossFadeState:
                  _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w900,
        fontSize: 16,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ---------------- 배경 그라데이션 ----------------
LinearGradient _bgGradient() {
  return const LinearGradient(
    colors: [Color(0xFFeef2ff), Color(0xFFe0e7ff), Color(0xFFf8fafc)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
