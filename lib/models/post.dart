import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// منشور واحد في الفيد
class Post {
  const Post({
    required this.id,
    required this.authorName,
    required this.handle,
    required this.body,
    required this.timeAgo,
    this.verified = false,
    this.likes = 0,
    this.reshares = 0,
    this.comments = 0,
    this.hasMedia = false,
    this.resharedBy,
  });

  final String id;
  final String authorName;
  final String handle; // بدون @
  final String body;
  final String timeAgo; // مثل: 2س
  final bool verified;
  final int likes;
  final int reshares;
  final int comments;
  final bool hasMedia;
  final String? resharedBy; // اسم من أعاد النشر (ريشير)

  /// الحرف الأول للصورة الرمزية
  String get initial => authorName.isEmpty ? '؟' : authorName.characters.first;

  /// لون ثابت لكل مستخدم — مشتق من المعرّف
  Color get avatarSeed {
    const palette = [
      AppColors.brand,
      AppColors.reshare,
      AppColors.blue,
      AppColors.like,
    ];
    return palette[handle.hashCode.abs() % palette.length];
  }

  /// للربط مع Supabase لاحقًا
  factory Post.fromMap(Map<String, dynamic> map) => Post(
        id: map['id'].toString(),
        authorName: map['author_name'] as String? ?? '',
        handle: map['handle'] as String? ?? '',
        body: map['body'] as String? ?? '',
        timeAgo: map['time_ago'] as String? ?? '',
        verified: map['verified'] as bool? ?? false,
        likes: map['likes'] as int? ?? 0,
        reshares: map['reshares'] as int? ?? 0,
        comments: map['comments'] as int? ?? 0,
        hasMedia: map['has_media'] as bool? ?? false,
        resharedBy: map['reshared_by'] as String?,
      );
}
