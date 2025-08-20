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

class BeforeSurveyScreen extends StatefulWidget {
  const BeforeSurveyScreen({super.key});

  @override
  State<BeforeSurveyScreen> createState() => _BeforeSurveyScreenState();
}

class _BeforeSurveyScreenState extends State<BeforeSurveyScreen> {
  // 각 문항의 선택 값을 저장 (0: 없음, 1: 2~3일, 2: 7일 이상, 3: 거의 매일)
  final List<int?> _answers = List<int?>.filled(9, null);

  final List<String> _questions = [
    "1. 최근 2주간, 일 또는 활동을 하는 데 흥미나 즐거움을 느끼지 못한다.",
    "2. 최근 2주간, 기분이 가라앉거나, 우울하거나, 희망이 없다고 느낀다.",
    "3. 최근 2주간, 잠이 들거나 계속 잠을 자는 것이 어렵다. 또는 잠을 너무 많이 잔다.",
    "4. 최근 2주간, 피곤하다고 느끼거나, 기운이 거의 없다.",
    "5. 최근 2주간, 입맛이 없거나, 과식을 한다.",
    "6. 최근 2주간, 자신을 부정적으로 본다. 혹은 자신이 실패자라고 느끼거나, 자신 또는 가족을 실망시킨다.",
    "7. 최근 2주간, 신문을 읽거나 텔레비전을 보는 것과 같은 일상적인 일에 집중하는 것이 어렵다.",
    "8. 최근 2주간, 다른 사람들이 주목할 정도로 너무 느리게 움직이거나 말한다. 또는 반대로 평소보다 많이 움직여서 너무 안절부절못하거나 들떠 있다.",
    "9. 최근 2주간, 자신이 죽는 것이 더 낫다고 생각하거나, 어떤 식으로든 자신을 해칠 것이라고 생각한다.",
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
        title: '사전설문',
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
                "최근 2주간, 얼마나 자주 다음과 같은 문제들로 곤란을 겪으셨습니까?",
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
    "1. 지난 2주 동안, 너무 긴장하거나 불안하거나 초조한 느낌이 들었습니까?",
    "2. 지난 2주 동안, 통제할 수 없을 정도로 걱정이 많았습니까?",
    "3. 지난 2주 동안, 여러 가지 일에 대해 걱정하는 것을 멈추기 어려웠습니까?",
    "4. 지난 2주 동안, 불안하거나 초조해서 가만히 있지 못하고 안절부절 못했습니까?",
    "5. 지난 2주 동안, 쉽게 피곤하거나 지쳤습니까?",
    "6. 지난 2주 동안, 집중하기 어렵거나 마음이 멍해진 느낌이 들었습니까?",
    "7. 지난 2주 동안, 신체적으로 긴장하거나 근육이 뻣뻣하거나 떨렸습니까?",
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
      MaterialPageRoute(builder: (_) => HabitSurveyScreen(phq9: widget.phq9, gad7: gad7)),
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
          title: '사전설문 (GAD-7)',
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
                  "최근 2주간, 얼마나 자주 다음과 같은 문제들로 곤란을 겪으셨습니까?",
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

class HabitSurveyScreen extends StatefulWidget {
  final List<int> phq9;
  final List<int> gad7;
  const HabitSurveyScreen({super.key, required this.phq9, required this.gad7});

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
        'before_survey_completed': true,
      }, SetOptions(merge: true));

      await userRef.collection('before_survey').add({
        'createdAt': FieldValue.serverTimestamp(),
        'phq9_answers': widget.phq9,
        'gad7_answers': widget.gad7,
        'habit_device': _options[0][_answers[0]!],
        'habit_typing_skill': int.tryParse(_options[1][_answers[1]!]),
        'habit_journaling_experience': _options[2][_answers[2]!],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사전 설문이 제출되었습니다. 감사합니다.')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
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
          title: '평소 습관 및 경험',
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