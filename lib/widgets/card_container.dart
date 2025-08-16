import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';

// 공통 카드형 컨테이너 위젯
class CardContainer extends StatelessWidget {
  final String title; // 카드 상단 제목
  final Widget child; // 카드 내부 콘텐츠
  final TextStyle titleStyle;
  final Widget? trailing; // 제목 오른쪽에 붙일 위젯 (선택)
  final List<BoxShadow>? boxShadow;
  final CrossAxisAlignment crossAxisAlignment; // 정렬 옵션 

  const CardContainer({
    super.key,
    required this.title,
    required this.child,
    this.titleStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: AppSizes.fontSize,
    ),
    this.trailing,
    this.boxShadow,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        boxShadow: boxShadow ?? const [BoxShadow(color: AppColors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Row(
            children: [
              Text(
                title,
                style: titleStyle,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space),
          child,
        ],
      ),
    );
  }
}