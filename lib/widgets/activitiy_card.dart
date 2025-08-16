import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';

class ActivityCard extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String title;
  final String subtitle;
  final bool showSubtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final List<BoxShadow>? boxShadow;
  final FontWeight titleFontWeight;

  const ActivityCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.showSubtitle = true,
    this.iconSize = 28,
    this.onTap,
    this.enabled = false,
    this.boxShadow,
    this.titleFontWeight = FontWeight.normal, // 기본값 설정
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor = enabled ? AppColors.indigo : Colors.grey;
    final Color textColor = enabled ? Colors.black : Colors.grey;
    final Color backgroundColor = enabled ? Colors.white : Colors.grey.shade300;
    final Color arrowColor = enabled ? AppColors.indigo : Colors.grey;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal:AppSizes.margin),
        padding: const EdgeInsets.all(AppSizes.padding),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          boxShadow: boxShadow ?? const [
            BoxShadow(
              color: AppColors.black12,
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: iconSize),
            const SizedBox(width: AppSizes.space),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: titleFontWeight, // 선택 가능
                      color: textColor,
                    ),
                  ),
                  if (showSubtitle && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: arrowColor),
          ],
        ),
      ),
    );
  }
}