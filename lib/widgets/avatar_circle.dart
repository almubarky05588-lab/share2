import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// الصورة الرمزية — صورة حقيقية إن وُجدت، وإلا تدرّج بحرف أول
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.initial,
    required this.seed,
    this.imageUrl,
    this.size = AppSizes.avatarLarge,
    this.flat = false,
  });

  final String initial;
  final Color seed;
  final String? imageUrl;
  final double size;
  final bool flat;

  bool get _hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_hasImage) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _fallback(),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
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
