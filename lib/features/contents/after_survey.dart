import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';
import 'package:gad_app_team/widgets/card_container.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const List<String> kFrequencyOptions = [
  "없음",
  "2, 3일 이상",
  "7일 이상",
  "거의 매일",
];

class AfterSurveyScreen extends StatefulWidget {
  const AfterSurveyScreen({super.key});

  @override
  State<AfterSurveyScreen> createState() => _AfterSurveyScreenState();
}

class _AfterSurveyScreenState extends State<AfterSurveyScreen> {
  // 각 문항의 선택 값을 저장 (0: 없음, 1: 2~3일, 2: 7일 이상, 3: 거의 매일)
  final List<int?> _answers = List<int?>.filled(9, null);

  final List<String> _questions = [
    "1. 최근 10일간, 일 또는 활동을 하는 데 흥미나 즐거움을 느끼지 못한다.",
    "2. 최근 10일간, 기분이 가라앉거나, 우울하거나, 희망이 없다고 느낀다.",
    "3. 최근 10일간, 잠이 들거나 계속 잠을 자는 것이 어렵다. 또는 잠을 너무 많이 잔다.",
    "4. 최근 10일간, 피곤하다고 느끼거나, 기운이 거의 없다.",
    "5. 최근 10일간, 입맛이 없거나, 과식을 한다.",
    "6. 최근 10일간, 자신을 부정적으로 본다. 혹은 자신이 실패자라고 느끼거나, 자신 또는 가족을 실망시킨다.",
    "7. 최근 10일간, 신문을 읽거나 텔레비전을 보는 것과 같은 일상적인 일에 집중하는 것이 어렵다.",
    "8. 최근 10일간, 다른 사람들이 주목할 정도로 너무 느리게 움직이거나 말한다. 또는 반대로 평소보다 많이 움직여서 너무 안절부절못하거나 들떠 있다.",
    "9. 최근 10일간, 자신이 죽는 것이 더 낫다고 생각하거나, 어떤 식으로든 자신을 해칠 것이라고 생각한다.",
  ];

  void _next() {
    if (_answers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 문항에 답해주세요.")),
      );
      return;
    }
    final phq9 = _answers.map((e) => e!).toList();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Gad7SurveyScreen(phq9: phq9)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
        aspect: 9 / 16,
        background: AppColors.grey100,
        child: Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: CustomAppBar(
        title: '사후설문',
        showHome: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardContainer(
              title: 'PHQ-9 (우울 관련 질문)', 
              child: Text(
                "다음 질문들은 우울 정도를 평가하기 위한 검사입니다. \n이 척도는 전 세계적으로 널리 사용되는 'Patient Health Questionnaire-9' 척도의 한국어판이며, 총 9문항으로 구성되어 있습니다.\n\n"
                "일기를 작성하는 최근 10일간, 얼마나 자주 다음과 같은 문제들로 곤란을 겪으셨습니까?",
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_questions.length, (qIndex) {
              return CardContainer(
                margin: const EdgeInsets.symmetric(vertical: 8),
                title: _questions[qIndex],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: List.generate(kFrequencyOptions.length, (oIndex) {
                        return RadioListTile<int>(
                          title: Text(kFrequencyOptions[oIndex]),
                          value: oIndex,
                          groupValue: _answers[qIndex],
                          onChanged: (val) {
                            setState(() {
                              _answers[qIndex] = val;
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            PrimaryActionButton(
                onPressed: _next,
                text: "다음",
            ),
          ],
        ),
      ),)
    );
  }
}

class Gad7SurveyScreen extends StatefulWidget {
  final List<int> phq9;
  const Gad7SurveyScreen({super.key, required this.phq9});

  @override
  State<Gad7SurveyScreen> createState() => _Gad7SurveyScreenState();
}

class _Gad7SurveyScreenState extends State<Gad7SurveyScreen> {
  final List<int?> _gadAnswers = List<int?>.filled(7, null);

  final List<String> _gadQuestions = [
    "1. 최근 10일 간, 너무 긴장하거나 불안하거나 초조한 느낌이 들었습니까?",
    "2. 최근 10일 간, 통제할 수 없을 정도로 걱정이 많았습니까?",
    "3. 최근 10일 간, 여러 가지 일에 대해 걱정하는 것을 멈추기 어려웠습니까?",
    "4. 최근 10일 간, 불안하거나 초조해서 가만히 있지 못하고 안절부절 못했습니까?",
    "5. 최근 10일 간, 쉽게 피곤하거나 지쳤습니까?",
    "6. 최근 10일 간, 집중하기 어렵거나 마음이 멍해진 느낌이 들었습니까?",
    "7. 최근 10일 간, 신체적으로 긴장하거나 근육이 뻣뻣하거나 떨렸습니까?",
  ];

  void _next() {
    if (_gadAnswers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 문항에 답해주세요.")),
      );
      return;
    }
    final gad7 = _gadAnswers.map((e) => e!).toList();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CognitiveLoadSurveyScreen(phq9: widget.phq9, gad7: gad7)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      background: AppColors.grey100,
      child: Scaffold(
        backgroundColor: AppColors.grey100,
        appBar: CustomAppBar(
          title: '사후설문',
          showHome: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardContainer(
                title: 'GAD-7 (불안 관련 질문)',
                child: Text(
                  "다음 질문들은 불안 정도를 평가하기 위한 검사입니다. \n이 척도는 전 세계적으로 널리 사용되는 'Generalized Anxiety Disorder-7' 척도의 한국어판이며, 총 7문항으로 구성되어 있습니다.\n\n"
                  "일기를 작성하는 최근 10일간, 얼마나 자주 다음과 같은 문제들로 곤란을 겪으셨습니까?",
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(_gadQuestions.length, (qIndex) {
                return CardContainer(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  title: _gadQuestions[qIndex],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: List.generate(kFrequencyOptions.length, (oIndex) {
                          return RadioListTile<int>(
                            title: Text(kFrequencyOptions[oIndex]),
                            value: oIndex,
                            groupValue: _gadAnswers[qIndex],
                            onChanged: (val) {
                              setState(() {
                                _gadAnswers[qIndex] = val;
                              });
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              PrimaryActionButton(
                onPressed: _next,
                text: "다음",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CognitiveLoadSurveyScreen extends StatefulWidget {
  final List<int> phq9;
  final List<int> gad7;
  const CognitiveLoadSurveyScreen({super.key, required this.phq9, required this.gad7});

  @override
  State<CognitiveLoadSurveyScreen> createState() => _CognitiveLoadSurveyScreenState();
}

class _CognitiveLoadSurveyScreenState extends State<CognitiveLoadSurveyScreen> {
  // 10 cognitive-load items scored 0~10
  final List<int?> _cog = List<int?>.filled(10, null);

  final List<String> _cogQuestions = const [
    "1. '사건', '믿음', '결과'에 따라 감정을 기록하는 것이 어려웠다.",
    "2. 감정일기 작성을 위해 '사건-믿음-결과'를 떠올리는 과정이 매우 복잡하게 느껴진다.",
    "3. '사건’과 ‘믿음’, ‘믿음’과 ‘결과’의 관계를 명확하게 구분하는 것이 어려웠다.",
    "4. 일기를 입력할 때 제공된 지시나 안내가 불분명하게 느껴졌다.",
    "5. 일기를 입력하는 방식이 불편하게 느껴졌다.",
    "6. 일기를 입력하는 방식이 직관적이지 않아 혼란스러웠다.",
    "7. 일기 작성을 통해 나의 감정 상태를 더 잘 이해하게 되었다.",
    "8. 일기 작성은 나의 생각 패턴을 파악하는 데 효과적이었다.",
    "9. 일기 작성을 통해 해당 상황에 대한 결과를 더 잘 이해하게 되었다.",
    "10. 일기 작성을 통해 사건-생각-결과 간의 상관관계를 더 잘 이해하게 되었다.",
  ];

  List<DropdownMenuItem<int>> _build0to10() =>
      List.generate(11, (i) => DropdownMenuItem(value: i, child: Text(i.toString())));

  void _next() {
    if (_cog.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 문항에 답해주세요.")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LlmSurveyScreen(
          phq9: widget.phq9,
          gad7: widget.gad7,
          cognitive: _cog.map((e) => e!).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      background: AppColors.grey100,
      child: Scaffold(
        backgroundColor: AppColors.grey100,
        appBar: const CustomAppBar(
          title: '사후설문',
          showHome: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardContainer(
                title: '인지 부하 평가 (0점=전혀 그렇지 않다, 10점=완전히 그렇다)',
                child: const Text('지난 10일간 앱 사용 시 느끼신 인지적 부담에 대해 각 문항에 0~10점으로 응답해 주세요.'),
              ),
              const SizedBox(height: 8),
              ...List.generate(_cogQuestions.length, (i) {
                return CardContainer(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  title: _cogQuestions[i],
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(), 
                      hintText: '점수 선택 (0~10)'
                    ),
                    value: _cog[i],
                    items: _build0to10(),
                    onChanged: (v) => setState(() => _cog[i] = v),
                  ),
                );
              }),
              const SizedBox(height: 16),
              PrimaryActionButton(onPressed: _next, text: '다음'),
            ],
          ),
        ),
      ),
    );
  }
}

class LlmSurveyScreen extends StatefulWidget {
  final List<int> phq9;
  final List<int> gad7;
  final List<int> cognitive; // from previous screen
  const LlmSurveyScreen({super.key, required this.phq9, required this.gad7, required this.cognitive});

  @override
  State<LlmSurveyScreen> createState() => _LlmSurveyScreenState();
}

class _LlmSurveyScreenState extends State<LlmSurveyScreen> {
  int? _llmOverall; // 1~5
  int? _llmAccuracy; // 1~5

  List<Widget> _buildLikert5(String title, int? groupValue, void Function(int?) onChanged) {
    return [
      CardContainer(
        margin: const EdgeInsets.symmetric(vertical: 8),
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("(1~5점: 1점- 매우 불만족/부정확, 5점- 매우 만족/매우 정확)", style: TextStyle(fontSize: 12)),
            ...List.generate(5, (idx) {
              final v = idx + 1;
              return RadioListTile<int>(
                title: Text(v.toString()),
                value: v,
                groupValue: groupValue,
                onChanged: onChanged,
              );
            }),
          ],
        ),
      ),
    ];
  }

  void _next() {
    if (_llmOverall == null || _llmAccuracy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 문항에 답해주세요.")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeepOpinionSurveyScreen(
          phq9: widget.phq9,
          gad7: widget.gad7,
          llmOverall: _llmOverall!,
          llmAccuracy: _llmAccuracy!,
          cognitive: widget.cognitive,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      background: AppColors.grey100,
      child: Scaffold(
        backgroundColor: AppColors.grey100,
        appBar: const CustomAppBar(
          title: '사후설문',
          showHome: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardContainer(
                title: 'AI 분석 결과에 대한 만족도 측정',
                child: const Text(
                  '실험 기간 동안 작성하신 일기에 대한 분석에 대한 만족도와 유용성을 평가해 주세요\n\n해당 기록들은 실험 과정 중 가명 처리되었으며, 분석 결과 또한 작성자의 신원을 유추할 수 없도록 안전하게 처리되었습니다.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              ..._buildLikert5('1) 전반적 만족도', _llmOverall, (v) => setState(() => _llmOverall = v)),
              ..._buildLikert5('2) 실제 감정 상태 반영 정확도', _llmAccuracy, (v) => setState(() => _llmAccuracy = v)),
              const SizedBox(height: 16),
              PrimaryActionButton(onPressed: _next, text: '다음'),
            ],
          ),
        ),
      ),
    );
  }
}

class DeepOpinionSurveyScreen extends StatefulWidget {
  final List<int> phq9;
  final List<int> gad7;
  final int llmOverall;
  final int llmAccuracy;
  final List<int> cognitive; // length 10
  const DeepOpinionSurveyScreen({
    super.key,
    required this.phq9,
    required this.gad7,
    required this.llmOverall,
    required this.llmAccuracy,
    required this.cognitive,
  });

  @override
  State<DeepOpinionSurveyScreen> createState() => _DeepOpinionSurveyScreenState();
}

class _DeepOpinionSurveyScreenState extends State<DeepOpinionSurveyScreen> {
  final _convenient = TextEditingController();
  final _difficult = TextEditingController();
  final _reflection = TextEditingController();

  @override
  void dispose() {
    _convenient.dispose();
    _difficult.dispose();
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다.")),
      );
      return;
    }
    try {
      final userRef = FirebaseFirestore.instance.collection('chi_users').doc(uid);

      await userRef.set({'after_survey_completed': true}, SetOptions(merge: true));

      await userRef.collection('after_survey').add({
        'createdAt': FieldValue.serverTimestamp(),
        'after_phq9_answers': widget.phq9,
        'after_gad7_answers': widget.gad7,
        'llm_overall_satisfaction': widget.llmOverall,
        'llm_accuracy_reflection': widget.llmAccuracy,
        'cognitive_load_answers': widget.cognitive,
        'opinion_convenient': _convenient.text.trim(),
        'opinion_difficult': _difficult.text.trim(),
        'opinion_self_reflection_change': _reflection.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사후 설문이 제출되었습니다. 감사합니다.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/thanks', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제출 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      background: AppColors.grey100,
      child: Scaffold(
        backgroundColor: AppColors.grey100,
        appBar: const CustomAppBar(
          title: '사후설문',
          showHome: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardContainer(
                title: '지난 10일간의 실험 참여 경험에 대한 심층 의견',
                child: const Text('아래 문항을 읽고 떠오르는 생각과 느낌을 자유롭게 작성해 주세요. (선택 사항)'),
              ),
              const SizedBox(height: 16),
              CardContainer(
                title: '1) 앱 사용 중 가장 편리하거나 유용했던 점은 무엇인가요?',
                child: TextField(
                  controller: _convenient,
                  maxLines: 5,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '자유롭게 작성'),
                ),
              ),
              const SizedBox(height: 16),
              CardContainer(
                title: '2) 앱 사용 중 가장 불편하거나 어려웠던 점은 무엇인가요?',
                child: TextField(
                  controller: _difficult,
                  maxLines: 5,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '자유롭게 작성'),
                ),
              ),
              const SizedBox(height: 16),
              CardContainer(
                title: '3) 이 앱을 사용하며 자기성찰(회상) 경험에 어떤 변화가 있었나요?',
                child: TextField(
                  controller: _reflection,
                  maxLines: 5,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '자유롭게 작성'),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryActionButton(onPressed: _submit, text: '제출'),
            ],
          ),
        ),
      ),
    );
  }
}

class HabitSurveyScreen extends StatefulWidget {
  final List<int> phq9;
  final List<int> gad7;
  final int llmOverall; // 1~5
  final int llmAccuracy; // 1~5
  final List<int> cognitive; // length 10, 0~10
  final String opinionConvenient;
  final String opinionDifficult;
  final String opinionReflection;

  const HabitSurveyScreen({
    super.key,
    required this.phq9,
    required this.gad7,
    required this.llmOverall,
    required this.llmAccuracy,
    required this.cognitive,
    required this.opinionConvenient,
    required this.opinionDifficult,
    required this.opinionReflection,
  });

  @override
  State<HabitSurveyScreen> createState() => _HabitSurveyScreenState();
}

class _HabitSurveyScreenState extends State<HabitSurveyScreen> {
  final List<int?> _answers = List<int?>.filled(3, null);

  final List<String> _questions = [
    "귀하께서 평소 글을 쓸 때 가장 자주 사용하는 기기는 무엇입니까?",
    "키보드/터치 타이핑 숙련도에 대해 귀하의 숙련도를 표시해 주세요. (1점: 매우 느림, 5점: 매우 빠름)",
    "귀하께서는 과거에 일기나 기록을 꾸준히 해 본 경험이 있습니까?",
  ];

  final List<List<String>> _options = [
    ["스마트폰", "태블릿", "노트북/데스크톱"],
    ["1", "2", "3", "4", "5"],
    ["네, 주기적으로 (매일, 주 3회 이상)", "네, 비정기적으로 (가끔)", "아니오"],
  ];

  bool _saving = false;

  Future<void> _submit() async {
    if (_answers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 문항에 답해주세요.")),
      );
      return;
    }
    if (_saving) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다.")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final userRef = FirebaseFirestore.instance.collection('chi_users').doc(uid);

      await userRef.set({
        'after_survey_completed': true,
      }, SetOptions(merge: true));

      await userRef.collection('after_survey').add({
        'createdAt': FieldValue.serverTimestamp(),
        'phq9_answers': widget.phq9,
        'gad7_answers': widget.gad7,
        'habit_device': _options[0][_answers[0]!],
        'habit_typing_skill': int.tryParse(_options[1][_answers[1]!]),
        'habit_journaling_experience': _options[2][_answers[2]!],
        'llm_overall_satisfaction': widget.llmOverall,
        'llm_accuracy_reflection': widget.llmAccuracy,
        'cognitive_load_answers': widget.cognitive,
        'opinion_convenient': widget.opinionConvenient,
        'opinion_difficult': widget.opinionDifficult,
        'opinion_self_reflection_change': widget.opinionReflection,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사후 설문이 제출되었습니다. 감사합니다.')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/thanks', (_) => false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제출 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectViewport(
      aspect: 9 / 16,
      background: AppColors.grey100,
      child: Scaffold(
        backgroundColor: AppColors.grey100,
        appBar: CustomAppBar(
          title: '사후설문',
          showHome: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(_questions.length, (qIndex) {
                return CardContainer(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  title: _questions[qIndex],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: List.generate(_options[qIndex].length, (oIndex) {
                          return RadioListTile<int>(
                            title: Text(_options[qIndex][oIndex]),
                            value: oIndex,
                            groupValue: _answers[qIndex],
                            onChanged: (val) {
                              setState(() {
                                _answers[qIndex] = val;
                              });
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              PrimaryActionButton(
                onPressed: _submit,
                text: "제출",
              ),
            ],
          ),
        ),
      ),
    );
  }
}