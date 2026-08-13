import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

/// منشورات هاشتاق معيّن
class HashtagScreen extends StatefulWidget {
  const HashtagScreen({super.key, required this.tag});

  final String tag;

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  bool _loading = true;
  List<Post> _posts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final posts = await SupabaseService.instance.fetchByHashtag(widget.tag);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  void _openHashtag(String tag) {
    if (tag.toLowerCase() == widget.tag.toLowerCase()) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('#${widget.tag}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _load,
              child: _posts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height:
                                MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Text(
                            'لا توجد منشورات بهذا الهاشتاق',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _posts.length,
                      itemBuilder: (_, i) => PostCard(
                        post: _posts[i],
                        onOpenProfile: _openProfile,
                        onOpenHashtag: _openHashtag,
                        onOpenPost: _openPost,
                        onReply: _openPost,
                        onChanged: _load,
                      ),
                    ),
            ),
    );
  }
}
