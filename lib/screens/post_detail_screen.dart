import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';
import 'hashtag_screen.dart';
import 'profile_screen.dart';

/// تفاصيل المنشور مع الردود — يفتح من التايم لاين أو من المنشن
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, this.post, this.postId})
      : assert(post != null || postId != null);

  final Post? post;
  final String? postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _controller = TextEditingController();

  Post? _post;
  List<Post> _replies = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final id = widget.post?.id ?? widget.postId!;
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

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await SupabaseService.instance.createPost(
        text,
        replyTo: _post!.id,
      );
      _controller.clear();
      FocusScope.of(context).unfocus();
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إرسال الرد')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('المنشور'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        shape: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && _post == null
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
                        if (_post != null)
                          PostCard(
                            post: _post!,
                            onOpenProfile: _openProfile,
                            onOpenHashtag: _openHashtag,
                            onChanged: _load,
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
                            onOpenHashtag: _openHashtag,
                            onChanged: _load,
                          ),
                        ),
                        if (_replies.isEmpty && !_loading)
                          Padding(
                            padding: const EdgeInsets.all(28),
                            child: Center(
                              child: Text(
                                'لا توجد ردود بعد — كن أول من يرد',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          _composer(context),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Material(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _sending ? null : _sendReply,
                child: SizedBox(
                  width: 44,
                  height: 40,
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Icon(Icons.send,
                          size: 19, color: AppColors.background),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.border.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.right,
                  minLines: 1,
                  maxLines: 4,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 11),
                    border: InputBorder.none,
                    hintText: 'اكتب ردك…',
                    hintStyle: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
