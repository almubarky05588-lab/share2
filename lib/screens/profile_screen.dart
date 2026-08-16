import 'package:flutter/material.dart';

import '../models/battle.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/post_card.dart';
import '../widgets/rank_badge.dart';
import '../widgets/rank_showcase.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';
import 'compose_screen.dart';
import 'hashtag_screen.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';
import 'spoils_screen.dart';
import 'user_list_screen.dart';
import 'waves_screen.dart';

/// صفحة المستخدم — بدون userId تعرض ملفي أنا
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  List<Post> _posts = const [];
  bool _loading = true;
  bool _busy = false;
  int _tab = 0;

  bool get _isMe {
    final me = SupabaseService.instance.currentUserId;
    return widget.userId == null || widget.userId == me;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final service = SupabaseService.instance;
      final id = widget.userId ?? service.currentUserId;
      if (id == null) {
        setState(() => _loading = false);
        return;
      }

      final profile = await service.fetchProfile(id);

      final blockedEither =
          (profile?.isBlocked ?? false) || (profile?.blockedMe ?? false);

      final posts = blockedEither
          ? <Post>[]
          : _tab == 1
              ? await service.fetchLikedPosts(id)
              : await service.fetchUserPosts(id);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _switchTab(int i) {
    if (_tab == i) return;
    setState(() => _tab = i);
    _load();
  }

  /// مشهد الرتبة
  void _showRank() {
    final p = _profile;
    if (p == null) return;

    RankShowcase.show(
      context,
      rank: p.rank,
      name: p.name,
      points: p.battlePoints,
      battles: p.battlesCount,
      wins: p.battlesWon,
    );
  }

  void _openWaves() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WavesScreen()),
    );
  }

  void _openSpoils() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpoilsScreen()),
    );
  }

  Future<void> _mention() async {
    final p = _profile;
    if (p == null) return;

    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ComposeScreen(initialText: '@${p.handle} '),
      ),
    );

    if (done == true) _snack('تم النشر');
  }

  Future<void> _openChat() async {
    final p = _profile;
    if (p == null || _busy) return;

    setState(() => _busy = true);

    try {
      final cid = await SupabaseService.instance.openConversationWith(p.id);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: cid,
            otherUserId: p.id,
            name: p.name,
            handle: p.handle,
            avatarUrl: p.avatarUrl,
            verified: p.verified,
          ),
        ),
      );
    } catch (_) {
      _snack('تعذّر فتح المحادثة');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFollow() async {
    final p = _profile;
    if (p == null || _busy) return;

    setState(() => _busy = true);
    final next = !p.isFollowing;

    try {
      await SupabaseService.instance.setFollow(p.id, next);
      if (!mounted) return;
      setState(() {
        _profile = p.copyWith(
          isFollowing: next,
          followers: p.followers + (next ? 1 : -1),
        );
      });
    } catch (_) {
      _snack('تعذّر تنفيذ المتابعة');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlock() async {
    final p = _profile;
    if (p == null) return;

    final next = !p.isBlocked;

    if (next) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('حظر ${p.name}'),
          content: const Text(
            'لن تظهر لك منشوراته، ولن يستطيع رؤية محتواك ولا ذكرك ولا الرد عليك.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
                  const Text('حظر', style: TextStyle(color: AppColors.like)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    try {
      await SupabaseService.instance.setBlock(p.id, next);
      if (!mounted) return;
      _snack(next ? 'تم الحظر' : 'أُلغي الحظر');
      _load();
    } catch (_) {
      _snack('تعذّر تنفيذ العملية');
    }
  }

  void _openMenu() {
    final p = _profile;
    if (p == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            _menuItem(
              ctx,
              icon: Icons.alternate_email,
              label: 'منشن ${p.name}',
              onTap: _mention,
            ),
            _menuItem(
              ctx,
              icon: p.isBlocked ? Icons.lock_open : Icons.block,
              label: p.isBlocked ? 'إلغاء الحظر' : 'حظر ${p.name}',
              color: AppColors.like,
              onTap: _toggleBlock,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.text,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(ctx).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 15, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (changed == true) _load();

    if (!mounted) return;
    if (!SupabaseService.instance.isSignedIn) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    }
  }

  void _openUserList(UserListKind kind) {
    final id = _profile?.id;
    if (id == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserListScreen(userId: id, kind: kind),
      ),
    );
  }

  void _openProfile(String userId) {
    if (userId == _profile?.id) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  Future<void> _openHandle(String handle) async {
    final id = await SupabaseService.instance.userIdByHandle(handle);
    if (!mounted || id == null) return;
    _openProfile(id);
  }

  void _openHashtag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HashtagScreen(tag: tag)),
    );
  }

  Future<void> _openPost(Post post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );
    _load();
  }

  Future<void> _reply(Post post) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ComposeScreen(replyTo: post),
      ),
    );
    if (done == true) _load();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading && p == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : p == null
              ? Center(
                  child: Text(
                    'تعذّر تحميل الملف الشخصي',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.brand,
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _head(context, p),
                      _info(context, p),
                      _actionsRow(context, p),
                      const SizedBox(height: 14),
                      if (p.isBlocked || p.blockedMe)
                        _blockedNotice(context, p)
                      else ...[
                        _tabs(context),
                        const Divider(height: 1, color: AppColors.border),
                        ..._posts.map(
                          (post) => PostCard(
                            post: post,
                            onOpenProfile: _openProfile,
                            onOpenHandle: _openHandle,
                            onOpenHashtag: _openHashtag,
                            onOpenPost: _openPost,
                            onReply: _reply,
                            onChanged: _load,
                            onDeleted: _load,
                          ),
                        ),
                        if (_posts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(30),
                            child: Center(
                              child: Text(
                                _tab == 1
                                    ? 'لا توجد منشورات في المفضلة'
                                    : 'لا توجد منشورات بعد',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _blockedNotice(BuildContext context, UserProfile p) {
    final t = Theme.of(context).textTheme;
    final iBlocked = p.isBlocked;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 40),
      child: Column(
        children: [
          Icon(
            iBlocked ? Icons.block : Icons.lock_outline,
            size: 44,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            iBlocked ? 'أنت حاظر هذا الحساب' : 'هذا الحساب حاظرك',
            textAlign: TextAlign.center,
            style: t.titleMedium?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            iBlocked
                ? 'لا ترى منشوراته، ولا يستطيع رؤية محتواك ولا ذكرك ولا الرد عليك.'
                : 'لا يمكنك رؤية منشوراته ولا التفاعل معه.',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
          if (iBlocked) ...[
            const SizedBox(height: 18),
            Material(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _toggleBlock,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.like),
                  ),
                  child: const Text(
                    'إلغاء الحظر',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.like,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _head(BuildContext context, UserProfile p) {
    return SizedBox(
      height: 136 + 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 136,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: p.coverUrl == null ? AppTheme.brandGradient : null,
              image: p.coverUrl == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(p.coverUrl!),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  if (Navigator.of(context).canPop())
                    _circleButton(
                      icon: Icons.arrow_forward,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  const Spacer(),
                  if (_isMe) ...[
                    _circleButton(
                      icon: Icons.military_tech_outlined,
                      onTap: _openSpoils,
                    ),
                    const SizedBox(width: 8),
                    _circleButton(icon: Icons.waves, onTap: _openWaves),
                    const SizedBox(width: 8),
                    _circleButton(
                      icon: Icons.settings_outlined,
                      onTap: _openSettings,
                    ),
                  ] else
                    _circleButton(
                      icon: Icons.more_horiz,
                      onTap: _openMenu,
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 136 - 46,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: AvatarCircle(
                initial: p.initial,
                seed: p.avatarSeed,
                imageUrl: p.avatarUrl,
                size: 84,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withOpacity(0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 19, color: AppColors.background),
        ),
      ),
    );
  }

  Widget _info(BuildContext context, UserProfile p) {
    final t = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    p.name,
                    style: t.titleMedium?.copyWith(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
                if (p.verified) ...[
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.verified,
                        size: 19, color: AppColors.blue),
                  ),
                ],
                if (p.rank != BattleRank.rookie) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InkWell(
                      onTap: _showRank,
                      borderRadius: BorderRadius.circular(20),
                      child: RankBadge(
                        rank: p.rank,
                        withLabel: true,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(atHandle(p.handle), style: t.bodySmall),
                if (p.followsYou) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.border.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('يتابعك',
                        style: t.bodySmall?.copyWith(fontSize: 11)),
                  ),
                ],
              ],
            ),
            if (p.bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(p.bio, style: t.bodyMedium),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (p.location != null && p.location!.isNotEmpty)
                  _meta(context, Icons.place_outlined, p.location!),
                if (p.websiteLabel != null)
                  _meta(context, Icons.link, p.websiteLabel!,
                      color: AppColors.brand),
                if (p.joined != null)
                  _meta(context, Icons.calendar_today_outlined, p.joined!),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat(context, p.followers, 'متابِع',
                    onTap: () => _openUserList(UserListKind.followers)),
                const SizedBox(width: 18),
                _stat(context, p.following, 'يتابع',
                    onTap: () => _openUserList(UserListKind.following)),
                const SizedBox(width: 18),
                _stat(context, p.posts, 'منشور'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsRow(BuildContext context, UserProfile p) {
    if (p.blockedMe) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          if (_isMe)
            Expanded(
              child: _outlinedButton(context, 'تعديل الملف',
                  onTap: _openSettings),
            )
          else if (p.isBlocked)
            Expanded(
              child: _outlinedButton(context, 'إلغاء الحظر',
                  onTap: _toggleBlock, danger: true),
            )
          else ...[
            Expanded(
              child: _filledButton(
                context,
                p.isFollowing ? 'يتابع' : 'متابعة',
                filled: !p.isFollowing,
                onTap: _toggleFollow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _outlinedButton(context, 'رسالة', onTap: _openChat),
            ),
            const SizedBox(width: 8),
            _iconButton(icon: Icons.alternate_email, onTap: _mention),
          ],
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 19, color: AppColors.text),
        ),
      ),
    );
  }

  Widget _outlinedButton(BuildContext context, String label,
      {required VoidCallback onTap, bool danger = false}) {
    final color = danger ? AppColors.like : AppColors.text;

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border:
                Border.all(color: danger ? AppColors.like : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filledButton(BuildContext context, String label,
      {required bool filled, required VoidCallback onTap}) {
    return Material(
      color: filled ? AppColors.brand : AppColors.background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: filled ? Colors.transparent : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: filled ? AppColors.background : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text,
      {Color color = AppColors.textMuted}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, int value, String label,
      {VoidCallback? onTap}) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(UserProfile.formatCount(value),
              style: t.titleMedium?.copyWith(fontSize: 15)),
          const SizedBox(width: 5),
          Text(label, style: t.bodySmall),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    return Row(
      children: [
        _tabItem(context, 'المنشورات', 0),
        _tabItem(context, 'المفضلة', 1),
      ],
    );
  }

  Widget _tabItem(BuildContext context, String label, int index) {
    final active = _tab == index;

    return Expanded(
      child: InkWell(
        onTap: () => _switchTab(index),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
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
                width: 44,
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
