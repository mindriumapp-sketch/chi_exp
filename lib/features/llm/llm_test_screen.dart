// lib/features/llm/llm_test_screen.dart
import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

class LlmTestScreen extends StatefulWidget {
  const LlmTestScreen({super.key});

  @override
  State<LlmTestScreen> createState() => _LlmTestScreenState();
}

class _LlmTestScreenState extends State<LlmTestScreen> {
  final double diversity = 0.64;
  final List<(String, int)> emotions = [
    ('불안', 6),
    ('긴장', 4),
    ('초조', 3),
    ('성취감', 2),
    ('감사', 1)
  ];

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      background: Colors.white,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(title: 'LLM 테스트 화면'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow(),
                const SizedBox(height: 14),
                _emotionDiversityCard(),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: NavigationButtons(
            leftLabel: '돌아가기',
            rightLabel: '완료',
            onBack: () => Navigator.pop(context),
            onNext: () =>
                Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow() {
    return Row(
      children: [
        Expanded(
            child: _miniStat(
                '감정 다양성', '${(diversity * 100).round()}%', Icons.bubble_chart)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat('총 태그 수', emotions.length.toString(), Icons.sell_outlined)),
      ],
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.white.withValues(alpha: 0.96),
          Colors.white.withValues(alpha: 0.88)
        ]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          _softIcon(icon,
              bg: AppColors.indigo.withValues(alpha: 0.12), fg: AppColors.indigo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('감정 다양성',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _diversityDial(double v) {
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
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(AppColors.indigo),
            ),
          ),
          Text('${(v * 100).round()}%',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tag,
              size: 16, color: AppColors.indigo.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: AppColors.indigo,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _softIcon(IconData icon, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: fg, size: 20),
    );
  }
}
