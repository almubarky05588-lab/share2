import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';
import 'compose_screen.dart';
import 'hashtag_screen.dart';
import 'profile_screen.dart';

/// تفاصيل المنشور مع الردود
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, this.post, this.postId})
      : assert(post != null || postId != null);

  final Post? post;
  final String? postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  List<Post> _replies = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final id = widget.post?.id ?? widget.postId!;
      SupabaseService.instance.recordView(id);

      final post = await SupabaseService.instance.fetchPost(id);
      final replies = await SupabaseService.instance.fetchReplies(id);

      if (!mounted) return;
      setState(() {
        _post = post ?? _post;
        _replies = replies;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _reply(Post target) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ComposeScreen(replyTo: target),
      ),
    );
    if (done == true) _load();
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

  void _openHashtag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HashtagScreen(tag: tag)),
    );
  }

  Future<void> _openPost(Post post) async {
    if (post.id == _post?.id) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('المنشور'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: _loading && p == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  if (p != null)
                    PostCard(
                      post: p,
                      onOpenProfile: _openProfile,
                      onOpenHandle: _openHandle,
                      onOpenHashtag: _openHashtag,
                      onReply: _reply,
                      onChanged: _load,
                      onDeleted: () => Navigator.of(context).maybePop(),
                    ),
                  if (_replies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'الردود (${_replies.length})',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ..._replies.map(
                    (r) => PostCard(
                      post: r,
                      onOpenProfile: _openProfile,
                      onOpenHandle: _openHandle,
                      onOpenHashtag: _openHashtag,
                      onOpenPost: _openPost,
                      onReply: _reply,
                      onChanged: _load,
                      onDeleted: _load,
                    ),
                  ),
                  if (_replies.isEmpty && !_loading)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Text(
                          'لا توجد ردود بعد — كن أول من يرد',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
      floatingActionButton: p == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.background,
              onPressed: () => _reply(p),
              icon: const Icon(Icons.mode_comment_outlined, size: 19),
              label: const Text(
                'رد',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}
