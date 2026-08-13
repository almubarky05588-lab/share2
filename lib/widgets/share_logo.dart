import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شعار share — الصورة الأصلية بخلفية شفافة
class ShareLogo extends StatelessWidget {
  const ShareLogo({
    super.key,
    this.size = 28,
    this.background,
    this.radius,
    this.padding,
  });

  /// الحجم الكلي
  final double size;

  /// لون الخلفية — null = شفافة
  final Color? background;

  /// نصف قطر زوايا الخلفية
  final double? radius;

  /// هامش داخلي حول الشعار
  final double? padding;

  static const _asset = 'assets/480F58B0-B46F-490B-A1DF-3664552353E1.png';

  @override
  Widget build(BuildContext context) {
    final inner = padding ?? (background == null ? 0 : size * 0.14);

    final logo = Padding(
      padding: EdgeInsets.all(inner),
      child: Image.asset(
        _asset,
        width: size - inner * 2,
        height: size - inner * 2,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.circle,
          size: size * 0.6,
          color: AppColors.brand,
        ),
      ),
    );

    if (background == null) {
      return SizedBox.square(dimension: size, child: logo);
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius ?? size * 0.29),
      ),
      child: logo,
    );
  }
}
