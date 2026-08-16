import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// نوع الإشعار
enum NotificationType {
  mention,
  reply,
  follow,
  reshare,
  like,
  battleChallenge,
  battleWon,
  battleLost,
}

/// عنصر واحد في شاشة المنشن والإشعارات
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.actorName,
    required this.handle,
    required this.timeAgo,
    this.postId,
    this.actorId,
    this.avatarUrl,
    this.preview,
    this.verified = false,
    this.unread = false,
  });

  final String id;
  final NotificationType type;
  final String actorName;
  final String handle;
  final String timeAgo;
  final String? postId;
  final String? actorId;
  final String? avatarUrl;
  final String? preview;
  final bool verified;
  final bool unread;

  bool get isFollow => type == NotificationType.follow;

  bool get isMention =>
      type == NotificationType.mention || type == NotificationType.reply;

  bool get isBattle =>
      type == NotificationType.battleChallenge ||
      type == NotificationType.battleWon ||
      type == NotificationType.battleLost;

  String get actionLabel {
    switch (type) {
      case NotificationType.mention:
        return 'ذكرك في منشور';
      case NotificationType.reply:
        return 'ردّ على منشورك';
      case NotificationType.follow:
        return 'بدأ بمتابعتك';
      case NotificationType.reshare:
        return 'أعاد نشر منشورك';
      case NotificationType.like:
        return 'أعجب بمنشورك';
      case NotificationType.battleChallenge:
        return 'يتحداك في نزال ⚔️';
      case NotificationType.battleWon:
        return 'فزتَ بالنزال ضده 🏆';
      case NotificationType.battleLost:
        return 'فاز عليك في النزال';
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.reply:
        return Icons.mode_comment_outlined;
      case NotificationType.follow:
        return Icons.person_add_alt;
      case NotificationType.reshare:
        return Icons.repeat;
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.battleChallenge:
        return Icons.bolt;
      case NotificationType.battleWon:
        return Icons.emoji_events;
      case NotificationType.battleLost:
        return Icons.shield_outlined;
    }
  }

  Color get iconColor {
    switch (type) {
      case NotificationType.mention:
      case NotificationType.reply:
        return AppColors.brand;
      case NotificationType.follow:
        return AppColors.blue;
      case NotificationType.reshare:
        return AppColors.reshare;
      case NotificationType.like:
        return AppColors.like;
      case NotificationType.battleChallenge:
        return AppColors.brand;
      case NotificationType.battleWon:
        return const Color(0xFFD4A017);
      case NotificationType.battleLost:
        return AppColors.textMuted;
    }
  }

  String get initial => actorName.isEmpty ? '؟' : actorName.characters.first;

  Color get avatarSeed {
    const palette = [
      AppColors.brand,
      AppColors.reshare,
      AppColors.blue,
      AppColors.like,
    ];
    return palette[handle.hashCode.abs() % palette.length];
  }

  factory NotificationItem.fromRow(
    Map<String, dynamic> row, {
    required String Function(String?) formatTime,
    required bool unread,
  }) {
    final kind = row['kind'] as String? ?? 'mention';

    final type = switch (kind) {
      'like' => NotificationType.like,
      'reshare' => NotificationType.reshare,
      'reply' => NotificationType.reply,
      'follow' => NotificationType.follow,
      'battle_challenge' => NotificationType.battleChallenge,
      'battle_won' => NotificationType.battleWon,
      'battle_lost' => NotificationType.battleLost,
      _ => NotificationType.mention,
    };

    final created = row['created_at'] as String?;

    return NotificationItem(
      id: '${kind}_${row['actor_id']}_${row['post_id'] ?? ''}_$created',
      type: type,
      actorId: row['actor_id']?.toString(),
      actorName: row['actor_name'] as String? ?? '',
      handle: row['actor_handle'] as String? ?? '',
      avatarUrl: row['actor_avatar'] as String?,
      verified: row['actor_verified'] as bool? ?? false,
      postId: row['post_id']?.toString(),
      preview: row['preview'] as String?,
      timeAgo: formatTime(created),
      unread: unread,
    );
  }
}
