import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/post_card.dart';
import '../widgets/share_bottom_nav.dart';
import '../widgets/share_logo.dart';
import 'compose_screen.dart';
import 'hashtag_screen.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

/// التايم لاين — الشاشة الرئيسية
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, this.showChrome = true});

  final bool showChrome;

  @override
  State<TimelineScreen> createState() => TimelineScreenState();
}

class TimelineScreenState extends State<TimelineScreen> {
  int _tab = 0;

  bool _loading = true;
  String? _error;
  List<Post> _posts = const [];
  String? _myAvatar;
  String _myInitial = 'م';

  @override
  void initState() {
    super.initState();
    _load();
    _loadMe();
  }

  Future<void> refresh() async {
    await _load();
    await _loadMe();
  }

  Future<void> _loadMe() async {
    final me = await SupabaseService.instance.fetchMyProfile();
    if (!mounted || me == null) return;
    setState(() {
      _myAvatar = me.avatarUrl;
      _myInitial = me.initial;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final posts = await SupabaseService.instance
          .fetchTimeline(followingOnly: _tab == 1);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل المنشورات';
        _loading = false;
      });
    }
  }

  void _switchTab(int index) {
    if (_tab == index) return;
    setState(() => _tab = index);
    _load();
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  Future<void> _openHandle(String handle) async {
    final id = await SupabaseService.instance.userIdByHandle(handle);
    if (!mounted || id == null) return;
    _openProfile(id);
  }

  Future<void> _openMyProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    refresh();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            _tabs(context),
            Expanded(child: _body(context)),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.showChrome ? const ShareBottomNav(currentIndex: 0) : null,
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: _error != null
          ? _messageList(_error!, retry: true)
          : _posts.isEmpty
              ? _messageList(
                  _tab == 1
                      ? 'لا توجد منشورات ممن تتابعهم بعد'
                      : 'لا توجد منشورات بعد — اكتب أول منشور',
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _posts.length,
                  itemBuilder: (_, i) => PostCard(
                    post: _posts[i],
                    onOpenProfile: _openProfile,
                    onOpenHandle: _openHandle,
                    onOpenHashtag: _openHashtag,
                    onOpenPost: _openPost,
                    onReply: _reply,
                    onChanged: _load,
                    onDeleted: _load,
                  ),
                ),
    );
  }

  Widget _messageList(String text, {bool retry = false}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (retry) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _load,
                  child: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(color: AppColors.brand),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18, left: 18, top: 8, bottom: 10),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          GestureDetector(
            onTap: _openMyProfile,
            child: AvatarCircle(
              initial: _myInitial,
              seed: AppColors.brand,
              imageUrl: _myAvatar,
              size: 34,
              flat: true,
            ),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ShareLogo(size: 32),
                  const SizedBox(width: 7),
                  Text(
                    'share',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brand,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 34),
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
          _tabItem(context, 'لك', 0),
          _tabItem(context, 'المتابَعون', 1),
        ],
      ),
    );
  }

  Widget _tabItem(BuildContext context, String label, int index) {
    final active = _tab == index;

    return Expanded(
      child: InkWell(
        onTap: () => _switchTab(index),
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.text : AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 46,
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
