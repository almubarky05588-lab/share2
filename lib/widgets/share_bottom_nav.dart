import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شريط التنقل السفلي — خمسة عناصر، النشط بلون العلامة
class ShareBottomNav extends StatelessWidget {
  const ShareBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  /// 0 الرئيسية · 1 استكشاف · 2 المنشن · 3 الرسائل · 4 حسابي
  final int currentIndex;
  final ValueChanged<int>? onTap;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_outlined, label: 'الرئيسية'),
    (icon: Icons.search, label: 'استكشاف'),
    (icon: Icons.alternate_email, label: 'المنشن'),
    (icon: Icons.mail_outline, label: 'الرسائل'),
    (icon: Icons.person_outline, label: 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final active = i == currentIndex;
            final color = active ? AppColors.brand : AppColors.textMuted;

            return Expanded(
              child: InkWell(
                onTap: onTap == null ? null : () => onTap!(i),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: AppSizes.iconNav, color: color),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: color,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
