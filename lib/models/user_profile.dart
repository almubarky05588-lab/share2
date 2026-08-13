import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// بيانات صفحة المستخدم — الشاشة ٥ من التصميم
class UserProfile {
  const UserProfile({
    required this.name,
    required this.handle,
    required this.bio,
    required this.followers,
    required this.following,
    required this.posts,
    this.location,
    this.joined,
    this.verified = false,
    this.followsYou = false,
    this.isFollowing = false,
  });

  final String name;
  final String handle; // بدون @
  final String bio;
  final int followers; // عدد المتابِعين
  final int following; // عدد من يتابعهم
  final int posts; // عدد المنشورات
  final String? location;
  final String? joined; // انضمّت في مارس 2019
  final bool verified;

  /// يظهر وسم «يتابعك»
  final bool followsYou;

  /// هل أنا متابعه حاليًا
  final bool isFollowing;

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

  UserProfile copyWith({bool? isFollowing}) => UserProfile(
        name: name,
        handle: handle,
        bio: bio,
        followers: followers,
        following: following,
        posts: posts,
        location: location,
        joined: joined,
        verified: verified,
        followsYou: followsYou,
        isFollowing: isFollowing ?? this.isFollowing,
      );

  /// للربط مع Supabase لاحقًا
  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        name: map['name'] as String? ?? '',
        handle: map['handle'] as String? ?? '',
        bio: map['bio'] as String? ?? '',
        followers: map['followers'] as int? ?? 0,
        following: map['following'] as int? ?? 0,
        posts: map['posts'] as int? ?? 0,
        location: map['location'] as String?,
        joined: map['joined'] as String?,
        verified: map['verified'] as bool? ?? false,
        followsYou: map['follows_you'] as bool? ?? false,
        isFollowing: map['is_following'] as bool? ?? false,
      );
}
