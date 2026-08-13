import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/post_card.dart';
import '../widgets/share_bottom_nav.dart';

/// صفحة المستخدم — الشاشة ٥ من التصميم
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.showBottomNav = true});

  final bool showBottomNav;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0; // 0 المنشورات · 1 الردود · 2 الوسائط · 3 الإعجابات

  // مؤقت — يُستبدل بجلب من Supabase
  UserProfile _profile = const UserProfile(
    name: 'نورة السالم',
    handle: 'noura_s',
    verified: true,
    followsYou: true,
    bio: 'مصمّمة واجهات · أكتب عن التصميم العربي وتفاصيله الصغيرة.',
    followers: 18400,
    following: 1240,
    posts: 342,
    location: 'الرياض، السعودية',
    joined: 'انضمّت في مارس 2019',
  );

  static const _posts = <Post>[
    Post(
      id: 'p1',
      authorName: 'نورة السالم',
      handle: 'noura_s',
      verified: true,
      timeAgo: '2س',
      body:
          'ثلاث سنوات وأنا أبحث عن تطبيق عربي يحترم اتجاه الكتابة من اليمين لليسار… قررت أخيرًا أبنيه بنفسي.',
      likes: 910,
      reshares: 128,
      comments: 42,
    ),
    Post(
      id: 'p2',
      authorName: 'نورة السالم',
      handle: 'noura_s',
      verified: true,
      timeAgo: 'أمس',
      body:
          'قاعدة بسيطة: إذا كان النص العربي يبدو مزدحمًا، المشكلة غالبًا في تباعد الأسطر لا في حجم الخط.',
      likes: 640,
      reshares: 96,
      comments: 21,
    ),
  ];

  void _toggleFollow() {
    setState(() {
      _profile = _profile.copyWith(isFollowing: !_profile.isFollowing);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _cover(context),
          _info(context),
          _tabs(context),
          ..._posts.map((p) => PostCard(post: p)),
        ],
      ),
      bottomNavigationBar:
          widget.showBottomNav ? const ShareBottomNav(currentIndex: 4) : null,
    );
  }

  Widget _cover(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 136,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.brand, AppColors.blue],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: AppColors.background,
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.arrow_forward,
                      size: 19,
                      color: AppColors.background,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 92,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: AvatarCircle(
                initial: _profile.initial,
                seed: _profile.avatarSeed,
                size: 80,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _messageButton(),
              const SizedBox(width: 8),
              _followButton(context),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _profile.name,
                style: t.titleMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_profile.verified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified,
                  size: 19,
                  color: AppColors.blue,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('‎@${_profile.handle}', style: t.bodySmall),
              if (_profile.followsYou) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'يتابعك',
                    style: t.bodySmall?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _profile.bio,
            textAlign: TextAlign.right,
            style: t.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_profile.location != null) ...[
                Text(_profile.location!, style: t.bodySmall),
                const SizedBox(width: 5),
                const Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 16),
              ],
              if (_profile.joined != null) ...[
                Text(_profile.joined!, style: t.bodySmall),
                const SizedBox(width: 5),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AppColors.textMuted,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _stat(context, _profile.posts, 'منشور'),
              const SizedBox(width: 18),
              _stat(context, _profile.following, 'يتابع'),
              const SizedBox(width: 18),
              _stat(context, _profile.followers, 'متابِع'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, int value, String label) {
    final t = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          UserProfile.formatCount(value),
          style: t.titleMedium?.copyWith(fontSize: 15),
        ),
        const SizedBox(width: 5),
        Text(label, style: t.bodySmall),
      ],
    );
  }

  Widget _followButton(BuildContext context) {
    final following = _profile.isFollowing;

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
          child: const Icon(
            Icons.mail_outline,
            size: 19,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    const labels = ['المنشورات', 'الردود', 'الوسائط', 'الإعجابات'];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = _tab == i;

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _tab = i),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[i],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color:
                                active ? AppColors.text : AppColors.textMuted,
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
        }),
      ),
    );
  }
}
