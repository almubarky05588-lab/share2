import 'package:flutter/material.dart';

import '../models/post.dart';
import '../theme/app_theme.dart';
import 'avatar_circle.dart';

/// بطاقة منشور — كما في الشاشة ١ من التصميم
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
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
          if (post.resharedBy != null) _reshareLabel(context),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarCircle(initial: post.initial, seed: post.avatarSeed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _header(context),
                    const SizedBox(height: 7),
                    Text(
                      post.body,
                      textAlign: TextAlign.right,
                      style: t.bodyMedium,
                    ),
                    if (post.hasMedia) ...[
                      const SizedBox(height: 7),
                      _media(),
                    ],
                    const SizedBox(height: 13),
                    _actions(context),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reshareLabel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 52),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 7),
          Text(
            'أعاد ${post.resharedBy} النشر',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  post.authorName,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium,
                ),
              ),
              if (post.verified) ...[
                const SizedBox(width: 5),
                _verifiedBadge(),
              ],
              const SizedBox(width: 5),
              Text('‎@${post.handle}', style: t.bodySmall),
              const SizedBox(width: 5),
              Text('·', style: t.bodySmall),
              const SizedBox(width: 5),
              Text(post.timeAgo, style: t.bodySmall),
            ],
          ),
        ),
        const Icon(
          Icons.more_horiz,
          size: AppSizes.iconSmall,
          color: AppColors.textMuted,
        ),
      ],
    );
  }

  Widget _verifiedBadge() {
    return Container(
      width: 15,
      height: 15,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.blue,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 9, color: AppColors.background),
    );
  }

  Widget _media() {
    return Container(
      width: double.infinity,
      height: 168,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedia),
        gradient: const LinearGradient(
          colors: [AppColors.brand, AppColors.blue],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _action(context, Icons.mode_comment_outlined, post.comments,
            AppColors.textMuted),
        _action(context, Icons.repeat, post.reshares, AppColors.reshare),
        _action(context, Icons.favorite_border, post.likes, AppColors.like),
        _action(context, Icons.ios_share, null, AppColors.textMuted),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    int? count,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconSmall, color: color),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            _format(count),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color),
          ),
        ],
      ],
    );
  }

  static String _format(int n) {
    if (n < 1000) return '$n';
    final v = (n / 1000).toStringAsFixed(1).replaceAll('.0', '');
    return '$v ألف';
  }
}
