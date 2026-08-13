import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان التصميم — مستخرجة من ملف فيجما «شارِك»
class AppColors {
  static const brand = Color(0xFF7A3FE0); // العلامة
  static const text = Color(0xFF16121F); // نص
  static const textMuted = Color(0xFF6E6880); // نص ثانوي
  static const border = Color(0xFFE9E6F2); // حد
  static const background = Color(0xFFFFFFFF); // الخلفية
  static const blue = Color(0xFF2E8BE0); // موثّق
  static const like = Color(0xFFE23E68); // إعجاب
  static const reshare = Color(0xFF17A67B); // ريشير
}

/// مقاسات ثابتة من التصميم
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
        // اسم المستخدم داخل المنشور
        titleMedium: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.55,
          color: AppColors.text,
        ),
        // نص المنشور
        bodyMedium: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.75,
          color: AppColors.text,
        ),
        // المعرّف والوقت
        bodySmall: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.55,
          color: AppColors.textMuted,
        ),
        // عدّادات الإجراءات
        labelMedium: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.55,
          color: AppColors.textMuted,
        ),
        // تسميات شريط التنقل
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
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
        iconTheme: const IconThemeData(color: AppColors.text, size: 22),
      ),
    );
  }

  /// تدرّج الصورة الرمزية — كما في التصميم
  static LinearGradient avatarGradient(Color seed) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [seed, AppColors.text.withOpacity(0.55)],
        stops: const [0.0, 0.714],
      );
}
