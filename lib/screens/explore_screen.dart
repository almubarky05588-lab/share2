import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_circle.dart';
import 'hashtag_screen.dart';
import 'profile_screen.dart';

/// استكشاف — بحث عن مستخدمين وعرض الهاشتاقات الرائجة
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  bool _searching = false;
  List<UserProfile> _results = const [];
  List<({String tag, int count})> _trending = const [];

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    try {
      final tags = await SupabaseService.instance.fetchTrendingHashtags();
      if (!mounted) return;
      setState(() => _trending = tags);
    } catch (_) {
      // تجاهل — القسم اختياري
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    final q = value.trim();

    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      final users = await SupabaseService.instance.searchUsers(q);
      if (!mounted) return;
      setState(() {
        _results = users;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  void _openHashtag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HashtagScreen(tag: tag)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _search_(context),
            Expanded(
              child: hasQuery ? _resultsView(context) : _trendingView(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _search_(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.border.withOpacity(0.45),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const Icon(Icons.search,
                size: AppSizes.iconSmall, color: AppColors.textMuted),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: (v) {
                  setState(() {});
                  _onChanged(v);
                },
                textAlign: TextAlign.right,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'ابحث عن شخص أو هاشتاق',
                  hintStyle: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              InkWell(
                onTap: () {
                  _controller.clear();
                  setState(() => _results = const []);
                },
                child: const Icon(Icons.close,
                    size: 18, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultsView(BuildContext context) {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    final q = _controller.text.trim().replaceAll('#', '');

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        InkWell(
          onTap: () => _openHashtag(q),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'ابحث في هاشتاق #$q',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 14, color: AppColors.brand),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.tag, size: 18, color: AppColors.brand),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(30),
            child: Center(
              child: Text(
                'لا يوجد مستخدمون بهذا الاسم',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
        else
          ..._results.map((u) => _userTile(context, u)),
      ],
    );
  }

  Widget _userTile(BuildContext context, UserProfile u) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => _openProfile(u.id),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (u.verified) ...[
                        const Icon(Icons.verified,
                            size: 15, color: AppColors.blue),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          u.name,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  Text('‎@${u.handle}', style: t.bodySmall),
                  if (u.bio.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      u.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: t.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AvatarCircle(
              initial: u.initial,
              seed: u.avatarSeed,
              imageUrl: u.avatarUrl,
              size: 46,
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendingView(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _loadTrending,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'الأكثر تداولًا',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          if (_trending.isEmpty)
            Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: Text(
                  'لا توجد هاشتاقات بعد — استخدم # في منشوراتك',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else
            ..._trending.map(
              (h) => InkWell(
                onTap: () => _openHashtag(h.tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${h.count} منشور',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '#${h.tag}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
