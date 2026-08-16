import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/share_bottom_nav.dart';
import '../widgets/victory_overlay.dart';
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

  List<NotificationItem> get _filtered {
    switch (_tab) {
      case 1:
        return _items.where((e) => e.isMention).toList();
      case 2:
        return _items.where((e) => e.isBattle).toList();
      case 3:
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

  /// عناصر العرض: مفردة أو مجموعات
  List<Object> get _entries => buildNotificationEntries(_filtered);

  Future<void> _openItem(NotificationItem item) async {
    // الفوز — يعرض المؤثر
    if (item.type == NotificationType.battleWon) {
      final me = await SupabaseService.instance.fetchMyProfile();
      if (!mounted) return;

      await VictoryOverlay.show(
        context,
        points: me?.battlePoints ?? 0,
        rankUp: null,
      );
      return;
    }

    // التحدي أو الخسارة — يفتح شاشة النزالات
    if (item.isBattle) {
      _snack('افتح تبويب النزالات لمتابعة التفاصيل');
      return;
    }

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

  Future<void> _openGroup(NotificationGroup group) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: group.postId),
      ),
    );
    _load();
  }

  void _openProfile(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
    );
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;

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
                      child: entries.isEmpty
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
                              itemCount: entries.length,
                              itemBuilder: (_, i) {
                                final e = entries[i];
                                if (e is NotificationGroup) {
                                  return _GroupTile(
                                    group: e,
                                    onTap: () => _openGroup(e),
                                  );
                                }
                                final item = e as NotificationItem;
                                return _NotificationTile(
                                  item: item,
                                  onTap: () => _openItem(item),
                                  onOpenProfile: _openProfile,
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.showChrome ? const ShareBottomNav(currentIndex: 3) : null,
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
          _tabItem(context, 'النزالات', 2),
          _tabItem(context, 'التفاعلات', 3),
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
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.text : AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 36,
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

/// بطاقة مجموعة تفاعلات — صور متراكبة وعدّاد، بمظهر هادئ
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, this.onTap});

  final NotificationGroup group;
  final VoidCallback? onTap;

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
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: group.unread
                ? group.iconColor.withOpacity(0.03)
                : AppColors.background,
            border: const Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // أيقونة النوع + العدد
              Column(
                children: [
                  Icon(group.icon, size: 22, color: group.iconColor),
                  const SizedBox(height: 3),
                  Text(
                    '${group.count}',
                    style: t.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: group.iconColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // صور متراكبة
                    SizedBox(
                      height: 30,
                      child: Stack(
                        children: [
                          for (var i = group.faces.length - 1;
                              i >= 0;
                              i--)
                            Positioned(
                              right: i * 21.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.background,
                                    width: 2,
                                  ),
                                ),
                                child: AvatarCircle(
                                  initial: group.faces[i].initial,
                                  seed: group.faces[i].avatarSeed,
                                  imageUrl: group.faces[i].avatarUrl,
                                  size: 26,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      group.label,
                      style: t.bodySmall?.copyWith(
                        fontSize: 13,
                        color: AppColors.text.withOpacity(0.75),
                      ),
                    ),
                    if (group.preview != null &&
                        group.preview!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bidiSafeMentions(group.preview!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text('· ${group.timeAgo}', style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف إشعار مفرد — بارز للمنشن والردود، هادئ للتفاعل المفرد
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
    final isWin = item.type == NotificationType.battleWon;
    final prominent = item.isMention;
    final quiet = item.isGroupable;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.screenPadding,
            vertical: prominent ? 15 : 13,
          ),
          decoration: BoxDecoration(
            color: isWin
                ? const Color(0xFFD4A017).withOpacity(0.07)
                : prominent && item.unread
                    ? AppColors.brand.withOpacity(0.06)
                    : item.unread
                        ? AppColors.brand.withOpacity(0.03)
                        : AppColors.background,
            border: Border(
              bottom: const BorderSide(color: AppColors.border),
              right: prominent
                  ? const BorderSide(color: AppColors.brand, width: 3)
                  : BorderSide.none,
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
                  size: prominent
                      ? AppSizes.avatarMedium
                      : AppSizes.avatarMedium - 6,
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
                          style: t.titleMedium?.copyWith(
                            fontSize: prominent ? 14.5 : 13.5,
                          ),
                        ),
                        if (item.verified)
                          const Icon(Icons.verified,
                              size: 15, color: AppColors.blue),
                        Text(atHandle(item.handle), style: t.bodySmall),
                        Text('· ${item.timeAgo}', style: t.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.actionLabel,
                      style: t.bodySmall?.copyWith(
                        color: isWin
                            ? const Color(0xFFD4A017)
                            : prominent
                                ? AppColors.brand
                                : quiet
                                    ? AppColors.text.withOpacity(0.7)
                                    : AppColors.text,
                        fontWeight: isWin || prominent
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    if (item.preview != null &&
                        item.preview!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        bidiSafeMentions(item.preview!),
                        maxLines: prominent ? 6 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: prominent
                            ? t.bodyMedium?.copyWith(
                                fontSize: 14.5,
                                color: AppColors.text,
                              )
                            : t.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                item.icon,
                size: prominent ? 20 : 17,
                color: quiet
                    ? item.iconColor.withOpacity(0.6)
                    : item.iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
