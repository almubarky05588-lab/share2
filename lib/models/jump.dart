import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'battle.dart';

/// حالة القفزة
enum JumpStatus { available, listed, frozen, used, expired }

extension JumpStatusInfo on JumpStatus {
  String get label => switch (this) {
        JumpStatus.available => 'متاحة',
        JumpStatus.listed => 'معروضة للبيع',
        JumpStatus.frozen => 'مجمّدة — قيد التحكيم',
        JumpStatus.used => 'مستخدمة',
        JumpStatus.expired => 'منتهية',
      };

  Color get color => switch (this) {
        JumpStatus.available => const Color(0xFF16A34A),
        JumpStatus.listed => AppColors.brand,
        JumpStatus.frozen => const Color(0xFFD97706),
        JumpStatus.used => AppColors.textMuted,
        JumpStatus.expired => AppColors.textMuted,
      };

  static JumpStatus fromKey(String? key) => JumpStatus.values.firstWhere(
        (s) => s.name == key,
        orElse: () => JumpStatus.available,
      );
}

/// قفزة — منشور يصل لجمهور واسع
class Jump {
  const Jump({
    required this.id,
    required this.ownerId,
    required this.grantedRank,
    required this.reachCap,
    required this.status,
    required this.expiresAt,
    this.postId,
    this.usedAt,
    this.reviewStatus,
    this.reviewNote,
  });

  final String id;
  final String ownerId;
  final BattleRank grantedRank;

  /// سقف الوصول
  final int reachCap;

  final JumpStatus status;
  final DateTime expiresAt;
  final String? postId;
  final DateTime? usedAt;

  /// pending | approved | rejected
  final String? reviewStatus;
  final String? reviewNote;

  bool get isUsable => status == JumpStatus.available && !isExpired;
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get daysLeft {
    final d = expiresAt.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  /// وصف السقف بصيغة مقروءة
  String get reachLabel {
    if (reachCap >= 2000000000) return 'كل المستخدمين';
    if (reachCap >= 1000000) {
      final v = (reachCap / 1000000).toStringAsFixed(1).replaceAll('.0', '');
      return 'حتى $v مليون';
    }
    if (reachCap >= 1000) {
      final v = (reachCap / 1000).toStringAsFixed(0);
      return 'حتى $v ألف';
    }
    return 'حتى $reachCap';
  }

  factory Jump.fromRow(Map<String, dynamic> row) => Jump(
        id: row['id'].toString(),
        ownerId: row['owner_id'].toString(),
        grantedRank: BattleRankInfo.fromKey(row['granted_rank'] as String?),
        reachCap: (row['reach_cap'] as num?)?.toInt() ?? 0,
        status: JumpStatusInfo.fromKey(row['status'] as String?),
        expiresAt: DateTime.tryParse(row['expires_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
        postId: row['post_id']?.toString(),
        usedAt: row['used_at'] == null
            ? null
            : DateTime.tryParse(row['used_at'] as String)?.toLocal(),
        reviewStatus: row['review_status'] as String?,
        reviewNote: row['review_note'] as String?,
      );
}

/// عرض قفزة في السوق
class JumpListing {
  const JumpListing({
    required this.id,
    required this.jumpId,
    required this.sellerId,
    required this.sellerName,
    required this.sellerHandle,
    required this.contact,
    required this.reachCap,
    required this.grantedRank,
    required this.status,
    required this.createdAgo,
    this.priceNote,
    this.note,
    this.sellerAvatar,
    this.sellerVerified = false,
  });

  final String id;
  final String jumpId;
  final String sellerId;
  final String sellerName;
  final String sellerHandle;
  final String? sellerAvatar;
  final bool sellerVerified;

  final String contact;
  final String? priceNote;
  final String? note;

  final int reachCap;
  final BattleRank grantedRank;

  /// open | reserved | sold | cancelled
  final String status;
  final String createdAgo;

  bool get isOpen => status == 'open';

  String get initial =>
      sellerName.isEmpty ? '؟' : sellerName.characters.first;

  String get reachLabel {
    if (reachCap >= 2000000000) return 'كل المستخدمين';
    if (reachCap >= 1000000) {
      final v = (reachCap / 1000000).toStringAsFixed(1).replaceAll('.0', '');
      return '$v مليون';
    }
    if (reachCap >= 1000) {
      return '${(reachCap / 1000).toStringAsFixed(0)} ألف';
    }
    return '$reachCap';
  }

  factory JumpListing.fromRow(
    Map<String, dynamic> row, {
    required String Function(String?) formatTime,
  }) {
    final seller = row['seller'] as Map<String, dynamic>? ?? const {};
    final jump = row['jump'] as Map<String, dynamic>? ?? const {};

    return JumpListing(
      id: row['id'].toString(),
      jumpId: row['jump_id'].toString(),
      sellerId: row['seller_id'].toString(),
      sellerName: seller['name'] as String? ?? '',
      sellerHandle: seller['handle'] as String? ?? '',
      sellerAvatar: seller['avatar_url'] as String?,
      sellerVerified: seller['verified'] as bool? ?? false,
      contact: row['contact'] as String? ?? '',
      priceNote: row['price_note'] as String?,
      note: row['note'] as String?,
      reachCap: (jump['reach_cap'] as num?)?.toInt() ?? 0,
      grantedRank: BattleRankInfo.fromKey(jump['granted_rank'] as String?),
      status: row['status'] as String? ?? 'open',
      createdAgo: formatTime(row['created_at'] as String?),
    );
  }
}
