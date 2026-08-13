import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'timeline_screen.dart';

/// شاشة البداية — الشاشة ٧ في التصميم
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TimelineScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // مؤقتًا: مربّع العلامة بحرف S — يُستبدل بملف الشعار لاحقًا
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(34),
              ),
              alignment: Alignment.center,
              child: const Text(
                'S',
                style: TextStyle(
                  fontSize: 62,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'شارِك',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brand,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              'تواصل عربي — من اليمين لليسار',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
