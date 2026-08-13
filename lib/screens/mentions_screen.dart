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
  State<MentionsScreen> createState() => MentionsScreenState();
}

class MentionsScreenState extends State<MentionsScreen> {
  int _tab = 0;

  bool _loading = true;
  List<NotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() => _load();

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
        return _items.where((e) => e.isMention).toList();
      case 2:
        return _items
            .where((e) =>
                e.type == NotificationType.like ||
                e.type == NotificationType.reshare ||
                e.type == NotificationType.follow)
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

  void _openProfile(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
    );
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
                                  height:
                                      MediaQuery.of(context).size.height *
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
                                onOpenProfile: _openProfile,
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
          _tabItem(context, 'التفاعلات', 2),
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

/// صف إشعار — كل شيء يبدأ من اليمين بجانب الصورة
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    this.onTap,
    this.onOpenProfile,
  });

  final NotificationItem item;
  final VoidCallback? onTap;
  final void Function(String userId)? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.screenPadding,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: item.unread
                ? AppColors.brand.withOpacity(0.05)
                : AppColors.background,
            border: const Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: item.actorId == null
                    ? null
                    : () => onOpenProfile?.call(item.actorId!),
                child: AvatarCircle(
                  initial: item.initial,
                  seed: item.avatarSeed,
                  imageUrl: item.avatarUrl,
                  size: AppSizes.avatarMedium,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        Text(
                          item.actorName,
                          style: t.titleMedium?.copyWith(fontSize: 14),
                        ),
                        if (item.verified)
                          const Icon(Icons.verified,
                              size: 15, color: AppColors.blue),
                        Text('‎@${item.handle}', style: t.bodySmall),
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
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(item.icon, size: 18, color: item.iconColor),
            ],
          ),
        ),
      ),
    );
  }
}
