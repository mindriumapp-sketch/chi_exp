// import 'package:flutter/material.dart';
// import 'package:gad_app_team/widgets/navigation_button.dart';
// import 'package:gad_app_team/features/2nd_treatment/abc_input_screen.dart';

// class AbcPracticeScreen extends StatelessWidget {
//   const AbcPracticeScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFFBF8FF),
//       body: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             const Spacer(),
//             const Icon(Icons.edit, size: 72, color: Color(0xFF3F51B5)),
//             const SizedBox(height: 32),
//             const Text(
//               '한번 연습해볼까요?',
//               style: TextStyle(
//                 fontSize: 28,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 24),
//             const Text(
//               '방금 본 자전거 예시 상황에 몰입해 보면서\nABC 모델 연습을 해볼 거예요.',
//               style: TextStyle(fontSize: 20, color: Colors.black87),
//               textAlign: TextAlign.center,
//             ),
//             const Spacer(),
//             NavigationButtons(
//               leftLabel: '이전',
//               rightLabel: '연습',
//               onBack: () => Navigator.pop(context),
//               onNext: () {
//                 Navigator.push(
//                   context,
//                   PageRouteBuilder(
//                     pageBuilder:
//                         (_, __, ___) => const AbcInputScreen(
//                           isExampleMode: true,
//                           showGuide: false,
//                         ),
//                     transitionDuration: Duration.zero,
//                     reverseTransitionDuration: Duration.zero,
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
