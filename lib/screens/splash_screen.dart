import 'dart:async';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/share_logo.dart';
import 'app_shell.dart';
import 'auth_screen.dart';

/// شاشة البداية
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
    _timer = Timer(const Duration(milliseconds: 1300), _go);
  }

  void _go() {
    if (!mounted) return;

    final signedIn = SupabaseService.instance.isSignedIn;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => signedIn ? const AppShell() : const AuthScreen(),
      ),
    );
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
            const ShareLogo(
              size: 118,
              color: AppColors.background,
              background: AppColors.brand,
              radius: 34,
            ),
            const SizedBox(height: 24),
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
