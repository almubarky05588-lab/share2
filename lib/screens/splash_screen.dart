import 'dart:async';

import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/share_logo.dart';
import 'app_shell.dart';
import 'auth_screen.dart';
import 'banned_screen.dart';

/// شاشة البداية
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final minWait = Future.delayed(const Duration(milliseconds: 1300));

    if (!SupabaseService.instance.isSignedIn) {
      await minWait;
      if (!mounted) return;
      _to(const AuthScreen());
      return;
    }

    // تسجيل الجلسة وفحص حالة الحساب معًا
    final ban = await SessionService.instance.checkBan();
    unawaited(SessionService.instance.recordLogin());

    await minWait;
    if (!mounted) return;

    _to(ban.banned ? BannedScreen(info: ban) : const AppShell());
  }

  void _to(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ShareLogo(size: 132),
            const SizedBox(height: 20),
            Text(
              'share',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brand,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
