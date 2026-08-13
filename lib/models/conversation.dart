import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// محادثة خاصة في قائمة الرسائل
class Conversation {
  const Conversation({
    required this.id,
    required this.name,
    required this.handle,
    required this.lastMessage,
    required this.time,
    this.otherUserId = '',
    this.avatarUrl,
    this.verified = false,
    this.sentByMe = false,
    this.unread = false,
  });

  final String id;
  final String otherUserId;
  final String name;
  final String handle; // بدون @
  final String lastMessage;
  final String time;
  final String? avatarUrl;
  final bool verified;

  /// آخر رسالة مني أنا
  final bool sentByMe;

  final bool unread;

  String get initial => name.isEmpty ? '؟' : name.characters.first;

  Color get avatarSeed {
    const palette = [
      AppColors.brand,
      AppColors.reshare,
      AppColors.blue,
      AppColors.like,
    ];
    return palette[handle.hashCode.abs() % palette.length];
  }

  String get preview =>
      lastMessage.isEmpty ? 'ابدأ المحادثة' : (sentByMe ? 'أنت: $lastMessage' : lastMessage);
}
