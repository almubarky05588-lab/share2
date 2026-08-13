import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شريط التنقل السفلي — أربعة عناصر مع شارة إشعارات على المنشن
class ShareBottomNav extends StatelessWidget {
  const ShareBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
    this.mentionsBadge = 0,
  });

  /// 0 الرئيسية · 1 استكشاف · 2 المنشن · 3 الرسائل
  final int currentIndex;
  final ValueChanged<int>? onTap;

  /// عدد الإشعارات غير المقروءة
  final int mentionsBadge;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_outlined, label: 'الرئيسية'),
    (icon: Icons.search, label: 'استكشاف'),
    (icon: Icons.alternate_email, label: 'المنشن'),
    (icon: Icons.mail_outline, label: 'الرسائل'),
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
            final badge = i == 2 ? mentionsBadge : 0;

            return Expanded(
              child: InkWell(
                onTap: onTap == null ? null : () => onTap!(i),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(item.icon,
                              size: AppSizes.iconNav, color: color),
                          if (badge > 0)
                            Positioned(
                              top: -4,
                              left: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 17,
                                  minHeight: 17,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.like,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: AppColors.background,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  badge > 99 ? '99+' : '$badge',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    color: AppColors.background,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w400,
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
