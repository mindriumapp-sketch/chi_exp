import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';

/// 화면 이동이 가능한 공통 TaskTile 위젯 (route 또는 onTap 사용 가능)
class TaskTile extends StatelessWidget {
  final String title;
  final String? route; // 선택적: 네이밍된 라우트
  final VoidCallback? onTap; // 선택적: 직접 콜백

  const TaskTile({
    super.key,
    required this.title,
    this.route,
    this.onTap,
  });

  void _handleTap(BuildContext context) {
    if (route != null) {
      Navigator.pushNamed(context, route!);
    } else if (onTap != null) {
      onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = route != null || onTap != null;

    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.fromLTRB(16,8,8,8),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, color: AppColors.indigo),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: AppSizes.fontSize, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: isEnabled ? () => _handleTap(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.indigo100,
              elevation: 0,
              padding: const EdgeInsets.fromLTRB(16,0,16,0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              ),
            ),
            child: const Text('이동하기', style: TextStyle(color: AppColors.black)),
          ),
        ],
      ),
    );
  }
}