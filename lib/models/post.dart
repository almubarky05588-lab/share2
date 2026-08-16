import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'battle.dart';

/// منشور واحد في الفيد — مبني من عرض posts_feed
class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.handle,
    required this.body,
    required this.timeAgo,
    this.avatarUrl,
    this.verified = false,
    this.likes = 0,
    this.reshares = 0,
    this.comments = 0,
    this.views = 0,
    this.likedByMe = false,
    this.resharedByMe = false,
    this.mediaUrl,
    this.mediaType,
    this.replyTo,
    this.resharedFrom,
    this.battlePoints = 0,
    this.waveId,
    this.waveRank,
    this.waveReach = 0,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String handle;
  final String body;
  final String timeAgo;
  final String? avatarUrl;
  final bool verified;

  final int likes;
  final int reshares;
  final int comments;
  final int views;
  final bool likedByMe;
  final bool resharedByMe;

  final String? mediaUrl;
  final String? mediaType; // image | video
  final String? replyTo;

  /// عند الريشير: المنشور الأصلي
  final Post? resharedFrom;

  /// نقاط النزال لصاحب المنشور
  final int battlePoints;

  /// الموجة — إن كان المنشور مدفوعًا بها
  final String? waveId;
  final BattleRank? waveRank;
  final int waveReach;

  bool get isWave => waveId != null;
  bool get isReshare => resharedFrom != null;
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isVideo => mediaType == 'video';

  BattleRank get rank => BattleRankInfo.fromPoints(battlePoints);

  String get initial => authorName.isEmpty ? '؟' : authorName.characters.first;

  /// وصف وصول الموجة
  String get waveReachLabel {
    if (waveReach >= 2000000000) return 'كل المستخدمين';
    if (waveReach >= 1000000) {
      final v =
          (waveReach / 1000000).toStringAsFixed(1).replaceAll('.0', '');
      return '$v مليون';
    }
    if (waveReach >= 1000) {
      return '${(waveReach / 1000).toStringAsFixed(0)} ألف';
    }
    return '$waveReach';
  }

  Color get avatarSeed {
    const palette = [
      AppColors.brand,
      AppColors.reshare,
      AppColors.blue,
      AppColors.like,
    ];
    return palette[handle.hashCode.abs() % palette.length];
  }

  Post copyWith({
    int? likes,
    int? reshares,
    int? views,
    bool? likedByMe,
    bool? resharedByMe,
  }) =>
      Post(
        id: id,
        authorId: authorId,
        authorName: authorName,
        handle: handle,
        body: body,
        timeAgo: timeAgo,
        avatarUrl: avatarUrl,
        verified: verified,
        likes: likes ?? this.likes,
        reshares: reshares ?? this.reshares,
        comments: comments,
        views: views ?? this.views,
        likedByMe: likedByMe ?? this.likedByMe,
        resharedByMe: resharedByMe ?? this.resharedByMe,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        replyTo: replyTo,
        resharedFrom: resharedFrom,
        battlePoints: battlePoints,
        waveId: waveId,
        waveRank: waveRank,
        waveReach: waveReach,
      );

  /// يبني المنشور من صف عرض posts_feed
  factory Post.fromFeedRow(
    Map<String, dynamic> row, {
    required String Function(String?) formatTime,
  }) {
    final likes = (row['like_count'] as num?)?.toInt() ?? 0;
    final reshares = (row['reshare_count'] as num?)?.toInt() ?? 0;
    final replies = (row['reply_count'] as num?)?.toInt() ?? 0;
    final views = (row['view_count'] as num?)?.toInt() ?? 0;
    final likedByMe = row['liked_by_me'] as bool? ?? false;
    final resharedByMe = row['reshared_by_me'] as bool? ?? false;

    Post? original;

    if (row['reshare_of'] != null && row['original_handle'] != null) {
      original = Post(
        id: row['reshare_of'].toString(),
        authorId: row['original_author_id']?.toString() ?? '',
        authorName: row['original_author_name'] as String? ?? '',
        handle: row['original_handle'] as String? ?? '',
        body: row['original_body'] as String? ?? '',
        timeAgo: formatTime(row['original_created_at'] as String?),
        avatarUrl: row['original_avatar_url'] as String?,
        verified: row['original_verified'] as bool? ?? false,
        mediaUrl: row['original_media_url'] as String?,
        mediaType: row['original_media_type'] as String?,
        likes: likes,
        reshares: reshares,
        comments: replies,
        views: views,
        likedByMe: likedByMe,
        resharedByMe: resharedByMe,
      );
    }

    return Post(
      id: row['id'].toString(),
      authorId: row['author_id']?.toString() ?? '',
      authorName: row['author_name'] as String? ?? '',
      handle: row['handle'] as String? ?? '',
      body: row['body'] as String? ?? '',
      timeAgo: formatTime(row['created_at'] as String?),
      avatarUrl: row['avatar_url'] as String?,
      verified: row['verified'] as bool? ?? false,
      likes: likes,
      reshares: reshares,
      comments: replies,
      views: views,
      likedByMe: likedByMe,
      resharedByMe: resharedByMe,
      mediaUrl: row['media_url'] as String?,
      mediaType: row['media_type'] as String?,
      replyTo: row['reply_to']?.toString(),
      resharedFrom: original,
      battlePoints: (row['battle_points'] as num?)?.toInt() ?? 0,
      waveId: row['wave_id']?.toString(),
      waveRank: row['wave_rank'] == null
          ? null
          : BattleRankInfo.fromKey(row['wave_rank'] as String?),
      waveReach: (row['wave_reach'] as num?)?.toInt() ?? 0,
    );
  }
}
