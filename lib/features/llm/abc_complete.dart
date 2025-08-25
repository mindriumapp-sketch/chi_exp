// lib/features/llm/abc_complete_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

class AbcCompleteScreen extends StatefulWidget {
  final String userId;
  final String abcId;
  final bool fromAbcInput; // true if routed from abc_input

  const AbcCompleteScreen({
    super.key,
    required this.userId,
    required this.abcId,
    this.fromAbcInput = false,
  });

  @override
  State<AbcCompleteScreen> createState() => _AbcCompleteScreenState();
}

class _AbcCompleteScreenState extends State<AbcCompleteScreen> {
  bool _loadingTimeout = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _loadingTimeout = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      background: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(gradient: _bgGradient()),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(
                title: '감정일기 리포트',
                onBack: () {
                  if (widget.fromAbcInput) {
                    // 입력 → 완료 흐름에서는 홈으로 이동
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
                  } else {
                    // 목록에서 들어왔을 때는 단순 뒤로가기
                    Navigator.pop(context);
                  }
                },
              ),
          body: SafeArea(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('chi_users')
                  .doc(widget.userId)
                  .collection('abc_models')
                  .doc(widget.abcId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('일기 데이터가 없습니다.'));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final report = data['report'];

                // ✅ report 생성중
                if (report == null) {
                  if (_loadingTimeout) {
                    // 5초 넘으면 예시 메시지 보여주기
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Column(
                          children: [
                            _AbcCompact(
                              activatingEvent: data['activatingEvent'] ?? '',
                              belief: data['belief'] ?? '',
                              c1Physical: data['c1_physical'] ?? '',
                              c2Emotion: data['c2_emotion'] ?? '',
                              c3Behavior: data['c3_behavior'] ?? '',
                            ),
                            const SizedBox(height: 18),
                            Text(
                              "AI가 리포트를 생성하는 데 시간이 오래 걸리고 있습니다.\n\n"
                              "생성된 리포트는 일기 목록에서 확인할 수 있습니다.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]
                        )
                      ),
                    );
                  }
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "AI가 리포트를 생성 중입니다...\n잠시만 기다려주세요.",
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // ✅ report가 실패 문구일 경우
                if (report is String && report.toLowerCase().contains("실패")) {
                  return const Center(
                    child: Text(
                      "리포트 생성에 실패했습니다.\n잠시 후 다시 시도해주세요.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  );
                }

                // ✅ 정상적으로 리포트 생성됨 — 버튼을 동일 스크롤 안에서 자연스럽게 연결
                final bottomPad = 18.0 + MediaQuery.of(context).viewPadding.bottom;
                return SingleChildScrollView(
                  
                        padding: EdgeInsets.fromLTRB(18, 18, 18, bottomPad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.fromAbcInput) ...[
                              _AbcCompact(
                                activatingEvent: data['activatingEvent'] ?? '',
                                belief: data['belief'] ?? '',
                                c1Physical: data['c1_physical'] ?? '',
                                c2Emotion: data['c2_emotion'] ?? '',
                                c3Behavior: data['c3_behavior'] ?? '',
                              ),
                              const SizedBox(height: 18),
                            ],
                            _ReportCard(
                              report: data['report'] ?? '리포트가 없습니다.',
                              alwaysExpanded: !widget.fromAbcInput,
                            ),
                            
                            if (widget.fromAbcInput) ...[
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: PrimaryActionButton(
                                  onPressed: () {
                                    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
                                  },
                                  text: '홈으로',
                                ),
                              ),
                            ],
                          ],
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- ABC Compact ----------------
class _AbcCompact extends StatelessWidget {
  final dynamic activatingEvent;
  final dynamic belief;
  final dynamic c1Physical;
  final dynamic c2Emotion;
  final dynamic c3Behavior;

  const _AbcCompact({
    required this.activatingEvent,
    required this.belief,
    required this.c1Physical,
    required this.c2Emotion,
    required this.c3Behavior,
  });

  List<String> _splitChips(dynamic value) {
    if (value == null) return [];

    if (value is String) {
      return [value.trim()];
    }

    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(text: '오늘의 ABC 일기'),
            const SizedBox(height: 12),
            // A
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
                            .map((chip) =>
                                _autoChipBox(chip, AppColors.indigo))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // B
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
            // C
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _circleBadge('C', Colors.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.favorite,
                              color: Colors.pink.shade400, size: 17),
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
                            .map((chip) =>
                                _autoChipBox(chip, Colors.pink.shade400))
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.emoji_emotions,
                              color: Colors.amber.shade700, size: 17),
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
                            .map((chip) =>
                                _autoChipBox(chip, Colors.amber.shade700))
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.directions_run,
                              color: Colors.teal, size: 17),
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
                            .map((chip) =>
                                _autoChipBox(chip, Colors.teal))
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

  Widget _autoChipBox(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10), // 수정
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1), // 수정
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

// ---------------- Report Card ----------------
class _ReportCard extends StatefulWidget {
  final String report;
  final bool alwaysExpanded;
  const _ReportCard({required this.report, this.alwaysExpanded = false});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard>
    with TickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.indigo.shade700;
    final bool expanded = widget.alwaysExpanded ? true : _expanded;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFc7d2fe), Color(0xFFe0e7ff), Color(0xFFeef2ff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: primary.withValues(alpha: 0.2), width: 1), // 수정
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.12), // 수정
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9), // 수정
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primary.withValues(alpha: 0.2)), // 수정
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
                if (!widget.alwaysExpanded)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(
                      foregroundColor: primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    child: Text(
                      _expanded ? '접기' : '더보기',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
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
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
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

LinearGradient _bgGradient() {
  return const LinearGradient(
    colors: [Color(0xFFeef2ff), Color(0xFFe0e7ff), Color(0xFFf8fafc)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
