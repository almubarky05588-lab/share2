import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/post_card.dart';
import 'auth_screen.dart';
import 'compose_screen.dart';
import 'hashtag_screen.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';
import 'user_list_screen.dart';

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
      final posts = _tab == 1
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
                      _actions(context, p),
                      const SizedBox(height: 14),
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
                  ),
                ),
    );
  }

  /// الغلاف مع الصورة نصفها فوقه ونصفها تحته
  Widget _head(BuildContext context, UserProfile p) {
    return SizedBox(
      height: 136 + 46,
      child: Stack(
        clipBehavior: Clip.none,
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
                textDirection: TextDirection.rtl,
                children: [
                  if (Navigator.of(context).canPop())
                    InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(Icons.arrow_forward,
                          size: 20, color: AppColors.background),
                    ),
                  const Spacer(),
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

  /// الاسم فالمعرّف فالبايو فالبيانات فالإحصائيات
  Widget _info(BuildContext context, UserProfile p) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (p.verified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 19, color: AppColors.blue),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            textDirection: TextDirection.rtl,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('‎@${p.handle}', style: t.bodySmall),
              if (p.followsYou) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            SizedBox(
              width: double.infinity,
              child: Text(p.bio,
                  textAlign: TextAlign.right, style: t.bodyMedium),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            textDirection: TextDirection.rtl,
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
            textDirection: TextDirection.rtl,
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
    );
  }

  /// صف الأزرار كامل العرض
  Widget _actions(BuildContext context, UserProfile p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          if (_isMe)
            Expanded(child: _outlinedButton(context, 'تعديل الملف',
                onTap: _openSettings))
          else ...[
            Expanded(
              child: _filledButton(
                context,
                p.isFollowing ? 'يتابع' : 'متابعة',
                filled: !p.isFollowing,
                onTap: _toggleFollow,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _outlinedButton(context, 'رسالة', onTap: () {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _outlinedButton(BuildContext context, String label,
      {required VoidCallback onTap}) {
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
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
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
      textDirection: TextDirection.rtl,
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
        textDirection: TextDirection.rtl,
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
