import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/share_bottom_nav.dart';

/// المنشن والإشعارات — الشاشة ٢ من التصميم
class MentionsScreen extends StatefulWidget {
  const MentionsScreen({super.key});

  @override
  State<MentionsScreen> createState() => _MentionsScreenState();
}

class _MentionsScreenState extends State<MentionsScreen> {
  int _tab = 0; // 0 الكل · 1 المنشن · 2 إعجابات

  // مؤقت — يُستبدل بجلب من Supabase
  static const _items = <NotificationItem>[
    NotificationItem(
      id: '1',
      type: NotificationType.mention,
      actorName: 'نورة السالم',
      handle: 'noura_s',
      timeAgo: '12د',
      unread: true,
      preview: '@mubarak رأيك في اتجاه الأيقونات داخل البطاقة؟ حسّيت أنها تحتاج مراجعة.',
    ),
    NotificationItem(
      id: '2',
      type: NotificationType.follow,
      actorName: 'خالد المطيري',
      handle: 'khalid.m',
      timeAgo: '40د',
      unread: true,
    ),
    NotificationItem(
      id: '3',
      type: NotificationType.reshare,
      actorName: 'استوديو مِداد',
      handle: 'midad.studio',
      timeAgo: '2س',
      preview: 'تذكير: المنشن ليس دعوة للنقاش، أحيانًا يكون مجرد تقدير.',
    ),
    NotificationItem(
      id: '4',
      type: NotificationType.like,
      actorName: 'سارة العتيبي',
      handle: 'sara.otb',
      timeAgo: '5س',
      preview: 'أطلقنا لوحة ألوان جديدة مستوحاة من الزخرفة النجدية.',
    ),
    NotificationItem(
      id: '5',
      type: NotificationType.commentMention,
      actorName: 'فهد الحربي',
      handle: 'fahad_hr',
      timeAgo: 'يوم',
      preview: 'وافقك @mubarak — الخط العربي يحتاج تباعد أسطر أوسع من اللاتيني.',
    ),
  ];

  List<NotificationItem> get _visible {
    switch (_tab) {
      case 1:
        return _items
            .where((e) =>
                e.type == NotificationType.mention ||
                e.type == NotificationType.commentMention)
            .toList();
      case 2:
        return _items
            .where((e) => e.type == NotificationType.like)
            .toList();
      default:
        return _items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            _tabs(context),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: list.length,
                itemBuilder: (_, i) => _NotificationTile(item: list[i]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ShareBottomNav(currentIndex: 2),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18, left: 18, top: 6, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'المنشن',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
          ),
          const Icon(
            Icons.tune,
            size: 21,
            color: AppColors.text,
          ),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _tabItem(context, 'الكل', 0),
          _tabItem(context, 'المنشن', 1),
          _tabItem(context, 'إعجابات', 2),
        ],
      ),
    );
  }

  Widget _tabItem(BuildContext context, String label, int index) {
    final active = _tab == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.text : AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: active ? AppColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف إشعار واحد
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.screenPadding,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: item.unread
            ? AppColors.brand.withOpacity(0.04)
            : AppColors.background,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 18, color: item.iconColor),
          const SizedBox(width: 11),
          AvatarCircle(
            initial: item.initial,
            seed: item.avatarSeed,
            size: AppSizes.avatarMedium,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        item.actorName,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(fontSize: 14),
                      ),
                    ),
                    if (item.verified) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.verified,
                        size: 15,
                        color: AppColors.blue,
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text('‎@${item.handle}', style: t.bodySmall),
                    const SizedBox(width: 6),
                    Text('· ${item.timeAgo}', style: t.bodySmall),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.actionLabel,
                  style: t.bodySmall?.copyWith(color: AppColors.text),
                ),
                if (item.preview != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.preview!,
                    textAlign: TextAlign.right,
                    style: t.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (item.isFollow) ...[
            const SizedBox(width: 11),
            _followButton(context),
          ],
        ],
      ),
    );
  }

  Widget _followButton(BuildContext context) {
    return Material(
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () {},
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Text(
            'متابعة',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.55,
              color: AppColors.background,
            ),
          ),
        ),
      ),
    );
  }
}
