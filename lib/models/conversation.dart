import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// محادثة في قائمة الرسائل الخاصة
class Conversation {
  const Conversation({
    required this.id,
    required this.name,
    required this.handle,
    required this.lastMessage,
    required this.time,
    this.otherUserId = '',
    this.verified = false,
    this.unread = false,
    this.sentByMe = false,
  });

  final String id;

  /// معرّف الطرف الآخر — لفتح ملفه
  final String otherUserId;

  final String name;
  final String handle; // بدون @
  final String lastMessage;
  final String time;
  final bool verified;
  final bool unread;
  final bool sentByMe;

  String get preview => sentByMe ? 'أنت: $lastMessage' : lastMessage;

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

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
        id: map['id'].toString(),
        otherUserId: map['other_user_id']?.toString() ?? '',
        name: map['name'] as String? ?? '',
        handle: map['handle'] as String? ?? '',
        lastMessage: map['last_message'] as String? ?? '',
        time: map['time'] as String? ?? '',
        verified: map['verified'] as bool? ?? false,
        unread: map['unread'] as bool? ?? false,
        sentByMe: map['sent_by_me'] as bool? ?? false,
      );
}
