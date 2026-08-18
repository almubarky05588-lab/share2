import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

/// تظهر عندما يكون الحساب موقوفًا
class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key, required this.info});

  final BanInfo info;

  Future<void> _signOut(BuildContext context) async {
    await SupabaseService.instance.signOut();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    color: AppColors.like.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gavel,
                      size: 44, color: AppColors.like),
                ),
                const SizedBox(height: 22),
                Text(
                  'حسابك موقوف',
                  style: t.titleMedium?.copyWith(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'تم إيقاف حسابك عن استخدام شارِك',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 22),
                if (info.reason != null && info.reason!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.like.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.like.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('السبب', style: t.bodySmall),
                        const SizedBox(height: 5),
                        Text(
                          info.reason!,
                          style: t.bodyMedium?.copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 19, color: AppColors.textMuted),
                      const SizedBox(width: 9),
                      Text(
                        info.untilLabel,
                        style: t.bodyMedium?.copyWith(fontSize: 14.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'إن كنت ترى أن الإيقاف عن طريق الخطأ، تواصل معنا عبر البريد',
                  textAlign: TextAlign.center,
                  style: t.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'support@shareapp.sa',
                  style: t.bodyMedium?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 30),
                Material(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _signOut(context),
                    child: Container(
                      height: 46,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'تسجيل الخروج',
                        style: t.titleMedium?.copyWith(fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
