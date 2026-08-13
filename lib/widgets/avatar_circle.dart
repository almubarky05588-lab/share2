import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// الصورة الرمزية — دائرة بتدرّج وحرف أول
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.initial,
    required this.seed,
    this.size = AppSizes.avatarLarge,
    this.flat = false,
  });

  final String initial;
  final Color seed;
  final double size;

  /// لون مصمت بدل التدرّج (كما في صورة الهيدر)
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: flat ? seed : null,
        gradient: flat ? null : AppTheme.avatarGradient(seed),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.41,
          fontWeight: FontWeight.w700,
          height: 1.55,
          color: AppColors.background,
        ),
      ),
    );
  }
}
