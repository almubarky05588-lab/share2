import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
    this.likedByMe = false,
    this.resharedByMe = false,
    this.bookmarkedByMe = false,
    this.mediaUrl,
    this.mediaType,
    this.replyTo,
    this.resharedFrom,
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
  final bool likedByMe;
  final bool resharedByMe;
  final bool bookmarkedByMe;

  final String? mediaUrl;
  final String? mediaType; // image | video
  final String? replyTo;

  /// عند الريشير: المنشور الأصلي
  final Post? resharedFrom;

  bool get isReshare => resharedFrom != null;
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isVideo => mediaType == 'video';

  String get initial => authorName.isEmpty ? '؟' : authorName.characters.first;

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
    bool? likedByMe,
    bool? resharedByMe,
    bool? bookmarkedByMe,
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
        likedByMe: likedByMe ?? this.likedByMe,
        resharedByMe: resharedByMe ?? this.resharedByMe,
        bookmarkedByMe: bookmarkedByMe ?? this.bookmarkedByMe,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        replyTo: replyTo,
        resharedFrom: resharedFrom,
      );

  /// يبني المنشور من صف عرض posts_feed
  factory Post.fromFeedRow(
    Map<String, dynamic> row, {
    required String Function(String?) formatTime,
  }) {
    final likes = (row['like_count'] as num?)?.toInt() ?? 0;
    final reshares = (row['reshare_count'] as num?)?.toInt() ?? 0;
    final replies = (row['reply_count'] as num?)?.toInt() ?? 0;
    final likedByMe = row['liked_by_me'] as bool? ?? false;
    final resharedByMe = row['reshared_by_me'] as bool? ?? false;
    final bookmarked = row['bookmarked_by_me'] as bool? ?? false;

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
        likedByMe: likedByMe,
        resharedByMe: resharedByMe,
        bookmarkedByMe: bookmarked,
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
      likedByMe: likedByMe,
      resharedByMe: resharedByMe,
      bookmarkedByMe: bookmarked,
      mediaUrl: row['media_url'] as String?,
      mediaType: row['media_type'] as String?,
      replyTo: row['reply_to']?.toString(),
      resharedFrom: original,
    );
  }
}
