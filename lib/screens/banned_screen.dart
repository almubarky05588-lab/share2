import 'package:flutter/material.dart';

import '../services/push_service.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';
import 'auth_screen.dart';

/// تظهر عند إيقاف الحساب أو جدولته للحذف
class BannedScreen extends StatefulWidget {
  const BannedScreen({super.key, required this.status});

  final AccountStatus status;

  @override
  State<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends State<BannedScreen> {
  bool _busy = false;

  Future<void> _signOut() async {
    await PushService.instance.unregisterDevice();
    await SupabaseService.instance.signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  /// استعادة حساب مجدول للحذف
  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await SessionService.instance.restoreAccount();
      await PushService.instance.registerDevice();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّرت الاستعادة، حاول لاحقًا')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final t = Theme.of(context).textTheme;
    final isDeleted = s.deleted && !s.banned;

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
                    color: (isDeleted ? AppColors.brand : AppColors.like)
                        .withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDeleted ? Icons.restore_from_trash : Icons.gavel,
                    size: 44,
                    color: isDeleted ? AppColors.brand : AppColors.like,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  isDeleted ? 'حسابك مجدول للحذف' : 'حسابك موقوف',
                  style: t.titleMedium?.copyWith(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isDeleted
                      ? 'يمكنك استعادته الآن ويعود كل شيء كما كان'
                      : 'تم إيقاف حسابك عن استخدام شارِك',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 22),

                // ── حساب مجدول للحذف ──
                if (isDeleted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.brand.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${s.daysLeft}',
                          style: t.titleMedium?.copyWith(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: AppColors.brand,
                          ),
                        ),
                        Text(
                          s.daysLeft == 1 ? 'يوم متبقٍ' : 'يومًا متبقيًا',
                          style: t.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'بعدها يُحذف حسابك ومحتواه نهائيًا',
                          textAlign: TextAlign.center,
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Material(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(26),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: _busy ? null : _restore,
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.background,
                                ),
                              )
                            : const Text(
                                'استعادة حسابي',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.background,
                                ),
                              ),
                      ),
                    ),
                  ),
                ]

                // ── حساب موقوف ──
                else ...[
                  if (s.reason != null && s.reason!.isNotEmpty)
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
                            s.reason!,
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
                          s.untilLabel,
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
                ],

                const SizedBox(height: 22),
                Material(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _busy ? null : _signOut,
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
