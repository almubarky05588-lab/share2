import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شعار share — حرف S بحلقتين وطرفين مدوّرين، مرسوم بالكود
class ShareLogo extends StatelessWidget {
  const ShareLogo({
    super.key,
    this.size = 28,
    this.color = AppColors.brand,
    this.background,
    this.radius,
  });

  /// الحجم الكلي للشعار
  final double size;

  /// لون حرف S
  final Color color;

  /// لون الخلفية — إن كان null فالخلفية شفافة
  final Color? background;

  /// نصف قطر زوايا الخلفية
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final glyph = CustomPaint(
      size: Size.square(size * 0.68),
      painter: _SPainter(color),
    );

    if (background == null) {
      return SizedBox.square(dimension: size, child: Center(child: glyph));
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius ?? size * 0.29),
      ),
      child: glyph,
    );
  }
}

class _SPainter extends CustomPainter {
  const _SPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.22;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final r = s * 0.245;

    // الحلقة العليا — مفتوحة من أعلى اليمين
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s / 2, s * 0.27), radius: r),
      -math.pi * 0.32,
      math.pi * 1.42,
      false,
      paint,
    );

    // الحلقة السفلى — مفتوحة من أسفل اليسار
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s / 2, s * 0.73), radius: r),
      math.pi * 0.68,
      math.pi * 1.42,
      false,
      paint,
    );

    // الوصلة القُطرية بين الحلقتين
    canvas.drawLine(
      Offset(s * 0.5 - r * 0.55, s * 0.27 + r * 0.72),
      Offset(s * 0.5 + r * 0.55, s * 0.73 - r * 0.72),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SPainter old) => old.color != color;
}
