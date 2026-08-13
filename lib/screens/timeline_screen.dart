import 'package:flutter/material.dart';

import '../models/post.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/post_card.dart';
import '../widgets/share_bottom_nav.dart';

/// التايم لاين — الشاشة ١ من التصميم
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, this.showChrome = true});

  /// false عند العرض داخل AppShell — الشريط وزر share يأتيان من الهيكل
  final bool showChrome;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  int _tab = 0; // 0 لك · 1 المتابَعون

  // مؤقت — يُستبدل بجلب من Supabase
  static const _posts = <Post>[
    Post(
      id: '1',
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
      id: '2',
      authorName: 'خالد المطيري',
      handle: 'khalid.m',
      timeAgo: '4س',
      resharedBy: 'تركي',
      body:
          'أفضل نصيحة سمعتها هذا الأسبوع: اكتب المنشور، ثم احذف أول سطرين. الفكرة دائمًا تبدأ من السطر الثالث.',
      likes: 305,
      reshares: 64,
      comments: 18,
    ),
    Post(
      id: '3',
      authorName: 'استوديو مِداد',
      handle: 'midad.studio',
      verified: true,
      timeAgo: '6س',
      body: 'أطلقنا لوحة ألوان جديدة مستوحاة من الزخرفة النجدية. متاحة مجانًا للجميع.',
      hasMedia: true,
      likes: 1400,
      reshares: 240,
      comments: 73,
    ),
    Post(
      id: '4',
      authorName: 'سارة العتيبي',
      handle: 'sara.otb',
      timeAgo: '9س',
      body:
          'تذكير: المنشن ليس دعوة للنقاش، أحيانًا يكون مجرد تقدير. اذكر من ساعدك اليوم.',
      likes: 188,
      reshares: 27,
      comments: 9,
    ),
  ];

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
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _posts.length,
                itemBuilder: (_, i) => PostCard(post: _posts[i]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.showChrome ? const ShareBottomNav(currentIndex: 0) : null,
      floatingActionButton: widget.showChrome ? _shareButton(context) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18, left: 18, top: 8, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const AvatarCircle(
            initial: 'م',
            seed: AppColors.brand,
            size: 34,
            flat: true,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'S',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.background,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'شارِك',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.brand,
                    ),
              ),
            ],
          ),
          const Icon(
            Icons.settings_outlined,
            size: 22,
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
        onTap: () => setState(() => _tab = index),
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

  Widget _shareButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 19, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 18, color: AppColors.background),
                SizedBox(width: 7),
                Text(
                  'share',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.55,
                    color: AppColors.background,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
