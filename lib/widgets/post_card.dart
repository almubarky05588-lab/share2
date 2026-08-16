import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/post.dart';
import '../screens/battle_create_screen.dart';
import '../screens/media_viewer_screen.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/handle_text.dart';
import 'avatar_circle.dart';
import 'inline_video.dart';
import 'rank_badge.dart';

/// بطاقة منشور
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onOpenProfile,
    this.onOpenHandle,
    this.onOpenHashtag,
    this.onOpenPost,
    this.onReply,
    this.onChanged,
    this.onDeleted,
  });

  final Post post;
  final void Function(String userId)? onOpenProfile;
  final void Function(String handle)? onOpenHandle;
  final void Function(String tag)? onOpenHashtag;
  final void Function(Post post)? onOpenPost;
  final void Function(Post post)? onReply;
  final VoidCallback? onChanged;
  final VoidCallback? onDeleted;

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

  Post get _shown => _post.resharedFrom ?? _post;

  bool get _isMine =>
      _shown.authorId == SupabaseService.instance.currentUserId;

  bool get _isMyReshare =>
      _post.authorId == SupabaseService.instance.currentUserId;

  void _apply(Post updated) {
    setState(() {
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
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    final target = _shown;
    final next = !target.likedByMe;

    setState(() => _busy = true);

    try {
      await SupabaseService.instance.setLike(target.id, next);
      if (!mounted) return;
      _apply(target.copyWith(
        likedByMe: next,
        likes: target.likes + (next ? 1 : -1),
      ));
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
      _apply(target.copyWith(
        resharedByMe: next,
        reshares: target.reshares + (next ? 1 : -1),
      ));
      _snack(next ? 'تمت إعادة النشر' : 'أُلغيت إعادة النشر');
      widget.onChanged?.call();
    } catch (_) {
      _snack('تعذّرت إعادة النشر');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    final link = SupabaseService.instance.postLink(_shown.id);
    await Clipboard.setData(ClipboardData(text: link));
    _snack('نُسخ رابط المنشور');
  }

  Future<void> _challenge() async {
    final target = _shown;

    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BattleCreateScreen(target: target),
      ),
    );

    if (done == true) _snack('أُرسل التحدي — بانتظار القبول');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنشور'),
        content: const Text('هل تريد حذف هذا المنشور نهائيًا؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف',
                style: TextStyle(color: AppColors.like)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final id =
          _isMyReshare && _post.resharedFrom != null ? _post.id : _shown.id;
      await SupabaseService.instance.deletePost(id);
      if (!mounted) return;
      _snack('حُذف المنشور');
      widget.onDeleted?.call();
      widget.onChanged?.call();
    } catch (_) {
      _snack('تعذّر الحذف');
    }
  }

  Future<void> _block() async {
    final target = _shown;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حظر ${target.authorName}'),
        content:
            const Text('لن تظهر لك منشوراته، ولن يستطيع ذكرك أو الرد عليك.'),
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

    try {
      await SupabaseService.instance.setBlock(target.authorId, true);
      if (!mounted) return;
      _snack('تم الحظر');
      widget.onChanged?.call();
    } catch (_) {
      _snack('تعذّر الحظر');
    }
  }

  void _openMenu() {
    final target = _shown;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            if (!_isMine && target.body.trim().isNotEmpty)
              _menuItem(
                ctx,
                icon: Icons.bolt,
                label: 'تحدَّ هذا المنشور',
                color: AppColors.brand,
                onTap: _challenge,
              ),
            _menuItem(
              ctx,
              icon: Icons.link,
              label: 'نسخ رابط المنشور',
              onTap: _copyLink,
            ),
            if (_isMine || _isMyReshare)
              _menuItem(
                ctx,
                icon: Icons.delete_outline,
                label: 'حذف المنشور',
                color: AppColors.like,
                onTap: _delete,
              ),
            if (!_isMine)
              _menuItem(
                ctx,
                icon: Icons.block,
                label: 'حظر ${target.authorName}',
                color: AppColors.like,
                onTap: _block,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.text,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(ctx).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 15, color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _openMedia() {
    final p = _shown;
    if (!p.hasMedia) return;

    SupabaseService.instance.recordView(p.id);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          url: p.mediaUrl!,
          isVideo: p.isVideo,
        ),
      ),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final p = _shown;

    // منشور بموجة — إطار متدرّج وشريط علوي
    if (_post.isWave) return _waveWrapper(context, p);

    return _plain(context, p);
  }

  /// غلاف الموجة
  Widget _waveWrapper(BuildContext context, Post p) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B63E0), Color(0xFF2F6BFF), Color(0xFF00C2FF)],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            _waveBanner(context),
            _plain(context, p, inWave: true),
          ],
        ),
      ),
    );
  }

  Widget _waveBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF5B63E0).withOpacity(0.12),
            const Color(0xFF00C2FF).withOpacity(0.10),
          ],
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(17)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Text('🌊', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 7),
          Text(
            'موجة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 13.5,
                  color: AppColors.brand,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            '· تصل ${_post.waveReachLabel}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          if (_post.waveRank != null)
            RankBadge(rank: _post.waveRank!, size: 14),
        ],
      ),
    );
  }

  /// البطاقة العادية
  Widget _plain(BuildContext context, Post p, {bool inWave = false}) {
    return InkWell(
      onTap: widget.onOpenPost == null
          ? null
          : () {
              SupabaseService.instance.recordView(p.id);
              widget.onOpenPost!(p);
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPadding,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: inWave
              ? const BorderRadius.vertical(bottom: Radius.circular(17))
              : null,
          border: inWave
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
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
                      if (p.body.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _body(context, p),
                      ],
                      if (p.hasMedia) ...[
                        const SizedBox(height: 9),
                        _media(p),
                      ],
                      const SizedBox(height: 12),
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
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => widget.onOpenProfile?.call(p.authorId),
            child: Wrap(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 5,
              runSpacing: 2,
              children: [
                Text(p.authorName, style: t.titleMedium),
                if (p.verified)
                  const Icon(Icons.verified,
                      size: 15, color: AppColors.blue),
                RankBadge(rank: p.rank, size: 14),
                Text(atHandle(p.handle), style: t.bodySmall),
                Text('· ${p.timeAgo}', style: t.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: _openMenu,
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: Icon(Icons.more_horiz,
                size: AppSizes.iconSmall, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, Post p) {
    final t = Theme.of(context).textTheme;

    final spans = <InlineSpan>[];
    final re = RegExp(r'([@#][\w\u0600-\u06FF._]+)');
    var last = 0;

    for (final m in re.allMatches(p.body)) {
      if (m.start > last) {
        spans.add(TextSpan(text: p.body.substring(last, m.start)));
      }

      final token = m.group(0)!;
      final isTag = token.startsWith('#');
      final name = token.substring(1);

      spans.add(TextSpan(
        text: '\u2066$token\u2069',
        style: t.bodyMedium?.copyWith(
          color: AppColors.brand,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (isTag) {
              widget.onOpenHashtag?.call(name);
            } else {
              widget.onOpenHandle?.call(name);
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
    if (p.isVideo) {
      return InlineVideo(
        url: p.mediaUrl!,
        postId: p.id,
        onTap: _openMedia,
      );
    }

    return GestureDetector(
      onTap: _openMedia,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedia),
        child: Image.network(
          p.mediaUrl!,
          width: double.infinity,
          height: 240,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 240,
            color: AppColors.border,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined,
                color: AppColors.textMuted),
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Container(
                  height: 240,
                  color: AppColors.border.withOpacity(0.4),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                      color: AppColors.brand, strokeWidth: 2),
                ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, Post p) {
    return Row(
      textDirection: TextDirection.rtl,
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
          icon: Icons.bar_chart,
          count: p.views,
          color: AppColors.textMuted,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required int count,
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
          textDirection: TextDirection.rtl,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconSmall, color: color),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                _format(count),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _format(int n) {
    if (n < 1000) return '$n';
    final v = (n / 1000).toStringAsFixed(1).replaceAll('.0', '');
    return '$v ألف';
  }
}
