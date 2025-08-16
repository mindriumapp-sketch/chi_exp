import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';

class NavigationButtons extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const NavigationButtons({
    super.key,
    this.leftLabel = '이전',
    this.rightLabel = '다음',
    this.onNext,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 이전
        Expanded(
          child: FilledButton(
            onPressed: onBack,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                (states) => states.contains(WidgetState.disabled)
                    ? AppColors.grey300
                    : AppColors.white,
              ),
              foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                (states) => states.contains(WidgetState.disabled)
                    ? Colors.grey
                    : Colors.indigo,
              ),
              shape: WidgetStateProperty.resolveWith<OutlinedBorder>(
                (states) {
                  final borderColor = states.contains(WidgetState.disabled)
                      ? Colors.grey.shade300
                      : Colors.indigo.shade100;
                  return RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    side: BorderSide(color: borderColor),
                  );
                },
              ),
            ),
            child: Text(leftLabel, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 12), // 버튼 사이 간격
        // 다음
        Expanded(
          child: FilledButton(
            onPressed: onNext,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                (states) => states.contains(WidgetState.disabled)
                    ? AppColors.grey300
                    : Colors.indigo,
              ),
              foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                (states) => states.contains(WidgetState.disabled)
                    ? Colors.grey
                    : AppColors.white,
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
              ),
            ),
            child: Text(rightLabel, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}