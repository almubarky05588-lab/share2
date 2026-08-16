import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// حالة الغنيمة
enum SpoilStatus { available, listed, frozen, used, expired }

extension SpoilStatusInfo on SpoilStatus {
  String get label => switch (this) {
        SpoilStatus.available => 'متاحة',
        SpoilStatus.listed => 'معروضة للبيع',
        SpoilStatus.frozen => 'مجمّدة',
        SpoilStatus.used => 'مستخدمة',
        SpoilStatus.expired => 'منتهية',
      };

  Color get color => switch (this) {
        SpoilStatus.available => const Color(0xFF16A34A),
        SpoilStatus.listed => AppColors.brand,
        SpoilStatus.frozen => const Color(0xFFD97706),
        SpoilStatus.used => AppColors.textMuted,
        SpoilStatus.expired => AppColors.textMuted,
      };

  static SpoilStatus fromKey(String? key) => SpoilStatus.values.firstWhere(
        (s) => s.name == key,
        orElse: () => SpoilStatus.available,
      );
}

/// غنيمة — وصول لجمهور خصم هزمته
class Spoil {
  const Spoil({
    required this.id,
    required this.ownerId,
    required this.loserId,
    required this.loserName,
    required this.loserHandle,
    required this.reach,
    required this.status,
    required this.expiresAt,
    this.loserAvatar,
    this.battleId,
    this.postId,
    this.usedAt,
  });

  final String id;
  final String ownerId;
  final String loserId;
  final String loserName;
  final String loserHandle;
  final String? loserAvatar;
  final int reach;
  final SpoilStatus status;
  final DateTime expiresAt;
  final String? battleId;
  final String? postId;
  final DateTime? usedAt;

  bool get isUsable => status == SpoilStatus.available && !isExpired;
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get daysLeft {
    final d = expiresAt.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  int get hoursLeft {
    final h = expiresAt.difference(DateTime.now()).inHours;
    return h < 0 ? 0 : h;
  }

  String get timeLeftLabel {
    if (isExpired) return 'انتهت';
    if (daysLeft >= 1) return '$daysLeft يومًا';
    return '$hoursLeft ساعة';
  }

  String get loserInitial =>
      loserName.isEmpty ? '؟' : loserName.characters.first;

  Color get loserSeed {
    const palette = [
      AppColors.brand,
      AppColors.reshare,
      AppColors.blue,
      AppColors.like,
    ];
    return palette[loserHandle.hashCode.abs() % palette.length];
  }

  factory Spoil.fromRow(Map<String, dynamic> row) {
    final loser = row['loser'] as Map<String, dynamic>? ?? const {};

    return Spoil(
      id: row['id'].toString(),
      ownerId: row['owner_id'].toString(),
      loserId: row['loser_id'].toString(),
      loserName: loser['name'] as String? ?? '',
      loserHandle: loser['handle'] as String? ?? '',
      loserAvatar: loser['avatar_url'] as String?,
      reach: (row['reach'] as num?)?.toInt() ?? 0,
      status: SpoilStatusInfo.fromKey(row['status'] as String?),
      expiresAt:
          DateTime.tryParse(row['expires_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      battleId: row['battle_id']?.toString(),
      postId: row['post_id']?.toString(),
      usedAt: row['used_at'] == null
          ? null
          : DateTime.tryParse(row['used_at'] as String)?.toLocal(),
    );
  }
}

/// حجّة في النزال — نص · مصادر · صور · فيديو
class BattleArgument {
  const BattleArgument({
    required this.id,
    required this.battleId,
    required this.authorId,
    required this.side,
    required this.body,
    required this.timeAgo,
    this.sources = const [],
    this.images = const [],
    this.videoUrl,
  });

  final String id;
  final String battleId;
  final String authorId;

  /// challenger | opponent
  final String side;

  final String body;
  final String timeAgo;

  /// حتى ٣ روابط مصادر
  final List<String> sources;

  /// حتى ٤ صور
  final List<String> images;

  /// فيديو واحد
  final String? videoUrl;

  bool get hasSources => sources.isNotEmpty;
  bool get hasImages => images.isNotEmpty;
  bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;
  bool get hasMedia => hasImages || hasVideo;

  /// اسم نطاق رابط
  static String hostOf(String url) {
    try {
      final h = Uri.parse(url).host;
      return h.isEmpty ? url : h.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  factory BattleArgument.fromRow(
    Map<String, dynamic> row, {
    required String Function(String?) formatTime,
  }) {
    List<String> list(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    // دعم الحقل القديم source_url
    final srcs = list(row['sources']);
    final legacy = row['source_url'] as String?;
    if (srcs.isEmpty && legacy != null && legacy.trim().isNotEmpty) {
      srcs.add(legacy);
    }

    return BattleArgument(
      id: row['id'].toString(),
      battleId: row['battle_id'].toString(),
      authorId: row['author_id'].toString(),
      side: row['side'] as String? ?? 'challenger',
      body: row['body'] as String? ?? '',
      sources: srcs,
      images: list(row['images']),
      videoUrl: row['video_url'] as String?,
      timeAgo: formatTime(row['created_at'] as String?),
    );
  }
}
