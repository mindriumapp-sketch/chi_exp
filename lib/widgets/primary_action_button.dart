import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';

class PrimaryActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool withAnimation; // 애니메이션 적용 여부

  const PrimaryActionButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.withAnimation = false, // 기본값 false
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: onPressed == null ? Colors.grey[300] : Colors.indigo, // 상태 반영
          foregroundColor: onPressed == null ? Colors.grey[600] : AppColors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );

    // 애니메이션 선택 적용
    return withAnimation
        ? AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(text), // text가 바뀌면 애니메이션 발생
        child: button,
      ),
    )
        : button;
  }
}
