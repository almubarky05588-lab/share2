import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// بيانات صفحة المستخدم
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.handle,
    required this.bio,
    required this.followers,
    required this.following,
    required this.posts,
    this.avatarUrl,
    this.location,
    this.website,
    this.joined,
    this.verified = false,
    this.followsYou = false,
    this.isFollowing = false,
    this.isBlocked = false,
  });

  final String id;
  final String name;
  final String handle; // بدون @
  final String bio;
  final int followers;
  final int following;
  final int posts;
  final String? avatarUrl;
  final String? location;
  final String? website;
  final String? joined;
  final bool verified;
  final bool followsYou;
  final bool isFollowing;

  /// هل حظرتُ هذا المستخدم
  final bool isBlocked;

  String get initial => name.isEmpty ? '؟' : name.characters.first;

  /// الرابط كاملًا للفتح
  String? get websiteUrl {
    final w = website?.trim();
    if (w == null || w.isEmpty) return null;
    if (w.startsWith('http://') || w.startsWith('https://')) return w;
    return 'https://$w';
  }

  /// الرابط مختصرًا للعرض
  String? get websiteLabel {
    final w = website?.trim();
    if (w == null || w.isEmpty) return null;
    return w
        .replaceFirst('https://', '')
        .replaceFirst('http://', '')
        .replaceFirst(RegExp(r'/$'), '');
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

  /// 18400 → 18.4 ألف
  static String formatCount(int n) {
    if (n < 1000) return '$n';
    if (n < 10000) {
      final s = n.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    final v = (n / 1000).toStringAsFixed(1).replaceAll('.0', '');
    return '$v ألف';
  }

  UserProfile copyWith({
    String? name,
    String? handle,
    String? bio,
    String? location,
    String? website,
    String? avatarUrl,
    bool? isFollowing,
    bool? isBlocked,
    int? followers,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        handle: handle ?? this.handle,
        bio: bio ?? this.bio,
        followers: followers ?? this.followers,
        following: following,
        posts: posts,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        location: location ?? this.location,
        website: website ?? this.website,
        joined: joined,
        verified: verified,
        followsYou: followsYou,
        isFollowing: isFollowing ?? this.isFollowing,
        isBlocked: isBlocked ?? this.isBlocked,
      );

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id']?.toString() ?? '',
        name: map['name'] as String? ?? '',
        handle: map['handle'] as String? ?? '',
        bio: map['bio'] as String? ?? '',
        followers: (map['followers'] as num?)?.toInt() ?? 0,
        following: (map['following'] as num?)?.toInt() ?? 0,
        posts: (map['posts'] as num?)?.toInt() ?? 0,
        avatarUrl: map['avatar_url'] as String?,
        location: map['location'] as String?,
        website: map['website'] as String?,
        joined: map['joined'] as String?,
        verified: map['verified'] as bool? ?? false,
        followsYou: map['follows_you'] as bool? ?? false,
        isFollowing: map['is_following'] as bool? ?? false,
        isBlocked: map['is_blocked'] as bool? ?? false,
      );
}
