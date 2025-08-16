import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onHomePressed;
  final bool showHome;
  final bool confirmOnBack;
  final bool confirmOnHome;
  final IconData? extraIcon;
  final String? extraRoute;
  final VoidCallback? onExtraPressed;
  final Color? backgroundColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.onHomePressed,
    this.showHome = true,
    this.confirmOnBack = false,
    this.confirmOnHome = false,
    this.extraIcon,
    this.extraRoute,
    this.onExtraPressed,
    this.backgroundColor,
  }): assert(extraRoute == null || onExtraPressed == null, 'extraRoute와 onExtraPressed는 둘 중 하나만 지정하세요.');

  Future<bool> _confirmExit(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('종료하시겠어요?'),
        content: const Text('지금 종료하면 진행 상황이 저장되지 않을 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.white,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () async {
            if (confirmOnBack) {
              final confirmed = await _confirmExit(context);
              if (!confirmed) return;
              if (!context.mounted) return;
            }
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      titleSpacing: 8,
      title: Row(
        children: [
          Text(title, style: const TextStyle(color: AppColors.black)),
        ],
      ),
      actions: [
        if (showHome)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
            child: IconButton(
              icon: const Icon(Icons.home_outlined, color: AppColors.black),
              onPressed: () async {
                if (confirmOnHome) {
                  final confirmed = await _confirmExit(context);
                  if (!confirmed) return;
                  if (!context.mounted) return;
                }
                if (onHomePressed != null) {
                  onHomePressed!();
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                }
              },
            ),
          ),
          if (extraIcon != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
            child: IconButton(
              icon: Icon(extraIcon, color: Colors.black,),
              onPressed: onExtraPressed ??
                  () {
                    if (extraRoute != null) {
                      Navigator.pushNamed(context, extraRoute!);
                    }
                  },
            ),
          ),  
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}