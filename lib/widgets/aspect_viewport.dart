import 'package:flutter/material.dart';
/// 재사용 가능한 고정 화면비 뷰포트
class AspectViewport extends StatelessWidget {
  const AspectViewport({
    super.key,
    required this.child,
    this.aspect = 9 / 16,      // 인스타그램/모바일 비율
    this.maxHeight,            // 필요하면 최대 높이 제한
    this.background = Colors.white,
    this.radius = 16,
    this.showShadow = true,
  });

  final Widget child;
  final double aspect;
  final double? maxHeight;
  final Color background;
  final double radius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final double usableH = maxHeight == null ? h : h.clamp(0.0, maxHeight!).toDouble();
        double targetW = w;
        double targetH = targetW / aspect;
        if (targetH > usableH) {
          targetH = usableH;
          targetW = targetH * aspect;
        }

        return Container(
          color: background, // 바깥 거터
          alignment: Alignment.center,
          child: Container(
            width: targetW,
            height: targetH,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: showShadow
                  ? [BoxShadow(blurRadius: 24, color: Colors.black12)]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: child, // 실제 화면
          ),
        );
      },
    );
  }
}