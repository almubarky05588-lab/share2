import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان التطبيق — مشتقة من شعار حرف S
class AppColors {
  /// لون الشعار الأساسي
  static const brand = Color(0xFF5B63E0);

  /// درجة أعمق للتدرّجات
  static const brandDeep = Color(0xFF3F47C4);

  /// درجة فاتحة للخلفيات الخفيفة
  static const brandSoft = Color(0xFFEEEFFC);

  static const text = Color(0xFF16121F);
  static const textMuted = Color(0xFF6E6880);
  static const border = Color(0xFFE7E7F5);
  static const background = Color(0xFFFFFFFF);

  static const blue = Color(0xFF2E8BE0);
  static const like = Color(0xFFE23E68);
  static const reshare = Color(0xFF17A67B);
}

/// مقاسات ثابتة
class AppSizes {
  static const screenPadding = 16.0;
  static const avatarLarge = 44.0;
  static const avatarMedium = 42.0;
  static const iconSmall = 17.0;
  static const iconNav = 23.0;
  static const radiusMedia = 16.0;
  static const radiusPill = 28.0;
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        primary: AppColors.brand,
        surface: AppColors.background,
        brightness: Brightness.light,
      ),
      dividerColor: AppColors.border,
    );

    final cairo = GoogleFonts.cairoTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: cairo.copyWith(
        titleMedium: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.55,
          color: AppColors.text,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.75,
          color: AppColors.text,
        ),
        bodySmall: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.55,
          color: AppColors.textMuted,
        ),
        labelMedium: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.55,
          color: AppColors.textMuted,
        ),
        labelSmall: GoogleFonts.cairo(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          height: 1.55,
          color: AppColors.textMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
        iconTheme: const IconThemeData(color: AppColors.text, size: 22),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: AppColors.background,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.background,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: AppColors.textMuted,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  /// تدرّج الصورة الرمزية
  static LinearGradient avatarGradient(Color seed) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [seed, AppColors.text.withOpacity(0.55)],
        stops: const [0.0, 0.714],
      );

  /// تدرّج العلامة — للأغلفة وشاشة البداية
  static const brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [AppColors.brand, AppColors.brandDeep],
  );
}
