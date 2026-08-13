import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/post_card.dart';
import '../widgets/share_bottom_nav.dart';
import 'auth_screen.dart';
import 'hashtag_screen.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';

/// صفحة المستخدم — بدون userId تعرض ملفي أنا
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.userId,
    this.showBottomNav = false,
  });

  final String? userId;
  final bool showBottomNav;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  List<Post> _posts = const [];
  bool _loading = true;
  bool _busy = false;
  int _tab = 0; // 0 المنشورات · 1 المفضلة

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
      final posts = _tab == 1 && _isMe
          ? await service.fetchBookmarks()
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
          content: const Text('لن تظهر لك منشوراته، ولن يتابع أحدكما الآخر.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('حظر',
                  style: TextStyle(color: AppColors.like)),
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

  void _openProfile(String userId) {
    if (userId == _profile?.id) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
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
                      _cover(context, p),
                      _info(context, p),
                      if (_isMe) _tabs(context),
                      const Divider(height: 1, color: AppColors.border),
                      ..._posts.map(
                        (post) => PostCard(
                          post: post,
                          onOpenProfile: _openProfile,
                          onOpenHashtag: _openHashtag,
                          onOpenPost: _openPost,
                          onReply: _openPost,
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
                  ),
                ),
      bottomNavigationBar:
          widget.showBottomNav ? const ShareBottomNav(currentIndex: 4) : null,
    );
  }

  Widget _cover(BuildContext context, UserProfile p) {
    return SizedBox(
      height: 136,
      child: Stack(
        children: [
          Container(
            height: 136,
            width: double.infinity,
            decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isMe)
                    InkWell(
                      onTap: _openSettings,
                      child: const Icon(Icons.settings_outlined,
                          size: 22, color: AppColors.background),
                    )
                  else
                    InkWell(
                      onTap: _toggleBlock,
                      child: Icon(
                        p.isBlocked ? Icons.person_off : Icons.more_horiz,
                        size: 22,
                        color: AppColors.background,
                      ),
                    ),
                  if (Navigator.of(context).canPop())
                    InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(Icons.arrow_forward,
                          size: 20, color: AppColors.background),
                    )
                  else
                    const SizedBox(width: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بيانات الملف — الصورة في صف مستقل فلا يشرد النص عنها
  Widget _info(BuildContext context, UserProfile p) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // صف الصورة والأزرار
          Transform.translate(
            offset: const Offset(0, -44),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        if (_isMe)
                          _editButton(context)
                        else ...[
                          _messageButton(),
                          const SizedBox(width: 8),
                          _followButton(context, p),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
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
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (p.verified) ...[
                      const Icon(Icons.verified,
                          size: 19, color: AppColors.blue),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (p.followsYou) ...[
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
                      const SizedBox(width: 8),
                    ],
                    Text('‎@${p.handle}', style: t.bodySmall),
                  ],
                ),
                if (p.bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(p.bio, textAlign: TextAlign.right, style: t.bodyMedium),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    if (p.joined != null) _meta(context, Icons.calendar_today_outlined, p.joined!),
                    if (p.location != null && p.location!.isNotEmpty)
                      _meta(context, Icons.place_outlined, p.location!),
                    if (p.websiteLabel != null)
                      _meta(context, Icons.link, p.websiteLabel!,
                          color: AppColors.brand),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _stat(context, p.posts, 'منشور'),
                    const SizedBox(width: 18),
                    _stat(context, p.following, 'يتابع'),
                    const SizedBox(width: 18),
                    _stat(context, p.followers, 'متابِع'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text,
      {Color color = AppColors.textMuted}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
        const SizedBox(width: 5),
        Icon(icon, size: 15, color: color),
      ],
    );
  }

  Widget _stat(BuildContext context, int value, String label) {
    final t = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(UserProfile.formatCount(value),
            style: t.titleMedium?.copyWith(fontSize: 15)),
        const SizedBox(width: 5),
        Text(label, style: t.bodySmall),
      ],
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

  Widget _editButton(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openSettings,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text(
            'تعديل الملف',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.55,
              color: AppColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _followButton(BuildContext context, UserProfile p) {
    final following = p.isFollowing;

    return Material(
      color: following ? AppColors.background : AppColors.brand,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _toggleFollow,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: following ? AppColors.border : Colors.transparent,
            ),
          ),
          child: Text(
            following ? 'يتابع' : 'متابعة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.55,
              color: following ? AppColors.text : AppColors.background,
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageButton() {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Container(
          width: 41,
          height: 37,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.mail_outline,
              size: 19, color: AppColors.text),
        ),
      ),
    );
  }
}
