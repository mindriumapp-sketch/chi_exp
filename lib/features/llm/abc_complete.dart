// lib/features/llm/abc_complete_screen.dart
import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

class AbcCompleteScreen extends StatelessWidget {
  const AbcCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 더미 값 (추후 LLM 연결)
    final String aSummary = '발표 10분 전, 청중 앞에 섰다';
    final String bSummary = '실수하면 어쩌지? 불안한 생각이 떠올랐다';
    final String cSummary = '심장이 두근거리고, 불안했지만 끝까지 발표했다';
    final double diversity = 0.68; // 감정 다양성 지표(0~1)
    final List<String> reflectionPrompts = [
      '오늘의 불안이 내게 남긴 의미는 무엇일까요?',
      '내일은 어떤 감정을 더 표현하고 싶나요?'
    ];

    return AspectViewport(
      aspect: 9 / 16,
      background: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(gradient: _bgGradient()),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(title: '기록 완료'),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _banner(),
                  const SizedBox(height: 20),
                  _abcSummaryCard(aSummary, bSummary, cSummary),
                  const SizedBox(height: 20),
                  _diversityCard(diversity),
                  const SizedBox(height: 20),
                  _reflectionBox(reflectionPrompts),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: NavigationButtons(
              leftLabel: '돌아가기',
              rightLabel: '홈으로',
              onBack: () => Navigator.pop(context),
              onNext: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
            ),
          ),
        ),
      ),
    );
  }

  // ===== 위젯 =====
  Widget _banner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.indigo, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '일기가 저장되었어요 ✅\nAI 분석 결과를 확인해보세요.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _abcSummaryCard(String a, String b, String c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘의 ABC 요약',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _bullet('A. 상황: $a'),
          _bullet('B. 생각: $b'),
          _bullet('C. 결과: $c'),
        ],
      ),
    );
  }

  Widget _diversityCard(double v) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFeef2ff), Color(0xFFe0e7ff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '감정 다양성 지표',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: v,
                  strokeWidth: 6,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation(AppColors.indigo),
                ),
                Text('${(v * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reflectionBox(List<String> prompts) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.indigo,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.indigo.withOpacity(.25), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘의 성찰 질문',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...prompts.map((q) => _bullet(q, color: Colors.white)).toList(),
        ],
      ),
    );
  }

  Widget _bullet(String text, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 14, height: 1.4, color: color)),
          ),
        ],
      ),
    );
  }

  LinearGradient _bgGradient() {
    return LinearGradient(
      colors: [
        AppColors.indigo.withOpacity(.1),
        Colors.purple.withOpacity(.1),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
