import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'avatar_circle.dart';

/// بطاقة منشور — تفاعل حقيقي مع قاعدة البيانات
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onOpenProfile,
    this.onOpenHashtag,
    this.onOpenPost,
    this.onReply,
    this.onChanged,
  });

  final Post post;
  final void Function(String userId)? onOpenProfile;
  final void Function(String tag)? onOpenHashtag;
  final void Function(Post post)? onOpenPost;
  final void Function(Post post)? onReply;
  final VoidCallback? onChanged;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Post _post = widget.post;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant PostCard old) {
    super.didUpdateWidget(old);
    if (old.post.id != widget.post.id) _post = widget.post;
  }

  /// المنشور المعروض فعليًا (الأصلي عند الريشير)
  Post get _shown => _post.resharedFrom ?? _post;

  Future<void> _toggleLike() async {
    if (_busy) return;
    final target = _shown;
    final next = !target.likedByMe;

    setState(() => _busy = true);

    try {
      await SupabaseService.instance.setLike(target.id, next);
      if (!mounted) return;

      setState(() {
        final updated = target.copyWith(
          likedByMe: next,
          likes: target.likes + (next ? 1 : -1),
        );

        _post = _post.resharedFrom != null
            ? Post(
                id: _post.id,
                authorId: _post.authorId,
                authorName: _post.authorName,
                handle: _post.handle,
                body: _post.body,
                timeAgo: _post.timeAgo,
                avatarUrl: _post.avatarUrl,
                verified: _post.verified,
                resharedFrom: updated,
              )
            : updated;
      });

      widget.onChanged?.call();
    } catch (_) {
      _snack('تعذّر تنفيذ الإعجاب');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleReshare() async {
    if (_busy) return;
    final target = _shown;
    final next = !target.resharedByMe;

    setState(() => _busy = true);

    try {
      await SupabaseService.instance.toggleReshare(target.id, next);
      if (!mounted) return;
      _snack(next ? 'تمت إعادة النشر' : 'أُلغيت إعادة النشر');
      widget.onChanged?.call();
    } catch (_) {
      _snack('تعذّرت إعادة النشر');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final p = _shown;

    return InkWell(
      onTap: widget.onOpenPost == null ? null : () => widget.onOpenPost!(p),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPadding,
          vertical: 14,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_post.isReshare) _reshareLabel(context),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => widget.onOpenProfile?.call(p.authorId),
                  child: AvatarCircle(
                    initial: p.initial,
                    seed: p.avatarSeed,
                    imageUrl: p.avatarUrl,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _header(context, p),
                      const SizedBox(height: 7),
                      _body(context, p),
                      if (p.hasMedia) ...[
                        const SizedBox(height: 9),
                        _media(p),
                      ],
                      const SizedBox(height: 13),
                      _actions(context, p),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reshareLabel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 52),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, size: 14, color: AppColors.reshare),
          const SizedBox(width: 7),
          Text(
            'أعاد ${_post.authorName} النشر',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppColors.reshare),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Post p) {
    final t = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: GestureDetector(
            onTap: () => widget.onOpenProfile?.call(p.authorId),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    p.authorName,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium,
                  ),
                ),
                if (p.verified) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.verified,
                      size: 15, color: AppColors.blue),
                ],
                const SizedBox(width: 5),
                Text('‎@${p.handle}', style: t.bodySmall),
                const SizedBox(width: 5),
                Text('·', style: t.bodySmall),
                const SizedBox(width: 5),
                Text(p.timeAgo, style: t.bodySmall),
              ],
            ),
          ),
        ),
        const Icon(Icons.more_horiz,
            size: AppSizes.iconSmall, color: AppColors.textMuted),
      ],
    );
  }

  /// نص المنشور مع تلوين المنشن والهاشتاق
  Widget _body(BuildContext context, Post p) {
    final t = Theme.of(context).textTheme;
    if (p.body.isEmpty) return const SizedBox.shrink();

    final spans = <InlineSpan>[];
    final re = RegExp(r'([@#][\w\u0600-\u06FF._]+)');
    var last = 0;

    for (final m in re.allMatches(p.body)) {
      if (m.start > last) {
        spans.add(TextSpan(text: p.body.substring(last, m.start)));
      }

      final token = m.group(0)!;
      spans.add(TextSpan(
        text: token,
        style: t.bodyMedium?.copyWith(
          color: AppColors.brand,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (token.startsWith('#')) {
              widget.onOpenHashtag?.call(token.substring(1));
            }
          },
      ));
      last = m.end;
    }

    if (last < p.body.length) {
      spans.add(TextSpan(text: p.body.substring(last)));
    }

    return SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(style: t.bodyMedium, children: spans),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _media(Post p) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusMedia),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            p.mediaUrl!,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 220,
              color: AppColors.border,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined,
                  color: AppColors.textMuted),
            ),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    height: 220,
                    color: AppColors.border.withOpacity(0.4),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                        color: AppColors.brand, strokeWidth: 2),
                  ),
          ),
          if (p.isVideo)
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow,
                  color: Colors.white, size: 32),
            ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, Post p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _action(
          context,
          icon: Icons.mode_comment_outlined,
          count: p.comments,
          color: AppColors.textMuted,
          onTap: () => widget.onReply?.call(p),
        ),
        _action(
          context,
          icon: Icons.repeat,
          count: p.reshares,
          color: p.resharedByMe ? AppColors.reshare : AppColors.textMuted,
          active: p.resharedByMe,
          onTap: _toggleReshare,
        ),
        _action(
          context,
          icon: p.likedByMe ? Icons.favorite : Icons.favorite_border,
          count: p.likes,
          color: p.likedByMe ? AppColors.like : AppColors.textMuted,
          active: p.likedByMe,
          onTap: _toggleLike,
        ),
        _action(
          context,
          icon: Icons.ios_share,
          count: null,
          color: AppColors.textMuted,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required int? count,
    required Color color,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconSmall, color: color),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                _format(count),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _format(int n) {
    if (n <= 0) return '';
    if (n < 1000) return '$n';
    final v = (n / 1000).toStringAsFixed(1).replaceAll('.0', '');
    return '$v ألف';
  }
}
