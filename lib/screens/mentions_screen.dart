import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/share_bottom_nav.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

/// المنشن والإشعارات
class MentionsScreen extends StatefulWidget {
  const MentionsScreen({super.key, this.showChrome = true});

  final bool showChrome;

  @override
  State<MentionsScreen> createState() => _MentionsScreenState();
}

class _MentionsScreenState extends State<MentionsScreen> {
  int _tab = 0; // 0 الكل · 1 المنشن · 2 متابعات

  bool _loading = true;
  List<NotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final items = await SupabaseService.instance.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

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
            .where((e) => e.type == NotificationType.follow)
            .toList();
      default:
        return _items;
    }
  }

  Future<void> _openItem(NotificationItem item) async {
    if (item.isFollow) {
      if (item.actorId == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: item.actorId!),
        ),
      );
      return;
    }

    if (item.postId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: item.postId!),
      ),
    );
    _load();
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
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.brand),
                    )
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _load,
                      child: list.isEmpty
                          ? ListView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context)
                                          .size
                                          .height *
                                      0.28,
                                ),
                                Center(
                                  child: Text(
                                    'لا توجد إشعارات بعد',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              itemCount: list.length,
                              itemBuilder: (_, i) => _NotificationTile(
                                item: list[i],
                                onTap: () => _openItem(list[i]),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.showChrome ? const ShareBottomNav(currentIndex: 2) : null,
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18, left: 18, top: 6, bottom: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'المنشن',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
        ),
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
          _tabItem(context, 'متابعات', 2),
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
  const _NotificationTile({required this.item, this.onTap});

  final NotificationItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPadding,
          vertical: 14,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(bottom: BorderSide(color: AppColors.border)),
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
                        const Icon(Icons.verified,
                            size: 15, color: AppColors.blue),
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
                  if (item.preview != null &&
                      item.preview!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.preview!,
                      textAlign: TextAlign.right,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
