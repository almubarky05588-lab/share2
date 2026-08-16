import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// رتبة المنازل
enum BattleRank { rookie, warrior, knight, ninja, samurai, beast }

extension BattleRankInfo on BattleRank {
  String get key => name;

  String get label => switch (this) {
        BattleRank.rookie => 'مبتدئ',
        BattleRank.warrior => 'محارب',
        BattleRank.knight => 'فارس',
        BattleRank.ninja => 'نينجا',
        BattleRank.samurai => 'ساموراي',
        BattleRank.beast => 'الوحش',
      };

  /// النقاط المطلوبة للوصول
  int get threshold => switch (this) {
        BattleRank.rookie => 0,
        BattleRank.warrior => 15,
        BattleRank.knight => 45,
        BattleRank.ninja => 120,
        BattleRank.samurai => 300,
        BattleRank.beast => 600,
      };

  Color get color => switch (this) {
        BattleRank.rookie => AppColors.textMuted,
        BattleRank.warrior => AppColors.blue,
        BattleRank.knight => AppColors.brand,
        BattleRank.ninja => const Color(0xFF7B2FF7),
        BattleRank.samurai => const Color(0xFFE0455C),
        BattleRank.beast => const Color(0xFFD4A017),
      };

  IconData get icon => switch (this) {
        BattleRank.rookie => Icons.shield_outlined,
        BattleRank.warrior => Icons.shield,
        BattleRank.knight => Icons.military_tech_outlined,
        BattleRank.ninja => Icons.bolt,
        BattleRank.samurai => Icons.workspace_premium,
        BattleRank.beast => Icons.emoji_events,
      };

  /// عدد النزالات المسموح بها يوميًا
  int get dailyLimit => switch (this) {
        BattleRank.rookie => 1,
        BattleRank.warrior => 2,
        BattleRank.knight => 3,
        BattleRank.ninja => 5,
        BattleRank.samurai => 99,
        BattleRank.beast => 99,
      };

  /// هل تمنح قفزة
  bool get grantsJump =>
      this == BattleRank.ninja ||
      this == BattleRank.samurai ||
      this == BattleRank.beast;

  static BattleRank fromPoints(int points) {
    if (points >= 600) return BattleRank.beast;
    if (points >= 300) return BattleRank.samurai;
    if (points >= 120) return BattleRank.ninja;
    if (points >= 45) return BattleRank.knight;
    if (points >= 15) return BattleRank.warrior;
    return BattleRank.rookie;
  }

  static BattleRank fromKey(String? key) => BattleRank.values.firstWhere(
        (r) => r.name == key,
        orElse: () => BattleRank.rookie,
      );

  /// الرتبة التالية — null عند القمة
  BattleRank? get next {
    final i = BattleRank.values.indexOf(this);
    return i < BattleRank.values.length - 1
        ? BattleRank.values[i + 1]
        : null;
  }
}

/// مجال النزال
enum BattleTopic { sports, food, movies, daily, general }

extension BattleTopicInfo on BattleTopic {
  String get key => name;

  String get label => switch (this) {
        BattleTopic.sports => 'رياضة',
        BattleTopic.food => 'طعام',
        BattleTopic.movies => 'أفلام',
        BattleTopic.daily => 'مواقف',
        BattleTopic.general => 'عام',
      };

  IconData get icon => switch (this) {
        BattleTopic.sports => Icons.sports_soccer,
        BattleTopic.food => Icons.restaurant,
        BattleTopic.movies => Icons.movie_outlined,
        BattleTopic.daily => Icons.wb_sunny_outlined,
        BattleTopic.general => Icons.chat_bubble_outline,
      };

  static BattleTopic fromKey(String? key) => BattleTopic.values.firstWhere(
        (t) => t.name == key,
        orElse: () => BattleTopic.general,
      );
}

/// حالة النزال
enum BattleStatus { pending, active, finished, declined, expired }

/// طرف في النزال
class BattleSide {
  const BattleSide({
    required this.userId,
    required this.name,
    required this.handle,
    required this.text,
    this.avatarUrl,
    this.verified = false,
    this.votes = 0,
  });

  final String userId;
  final String name;
  final String handle;
  final String text;
  final String? avatarUrl;
  final bool verified;
  final int votes;

  String get initial => name.isEmpty ? '؟' : name.characters.first;
}

/// نزال بين منشورين
class Battle {
  const Battle({
    required this.id,
    required this.challenger,
    required this.opponent,
    required this.topic,
    required this.status,
    this.endsAt,
    this.winnerId,
    this.myVote,
    this.durationHours = 6,
  });

  final String id;
  final BattleSide challenger;
  final BattleSide opponent;
  final BattleTopic topic;
  final BattleStatus status;
  final DateTime? endsAt;
  final String? winnerId;

  /// challenger | opponent | null
  final String? myVote;

  final int durationHours;

  bool get isActive => status == BattleStatus.active;
  bool get isFinished => status == BattleStatus.finished;
  bool get voted => myVote != null;

  int get totalVotes => challenger.votes + opponent.votes;

  double get challengerRatio =>
      totalVotes == 0 ? 0.5 : challenger.votes / totalVotes;

  bool get isTie => isFinished && winnerId == null;

  /// الوقت المتبقي
  Duration get remaining {
    final e = endsAt;
    if (e == null) return Duration.zero;
    final d = e.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  String get countdown {
    final d = remaining;
    if (d == Duration.zero) return 'انتهى';

    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;

    if (h > 0) return '$h:${_two(m)}:${_two(s)}';
    return '${_two(m)}:${_two(s)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  Battle copyWith({
    BattleSide? challenger,
    BattleSide? opponent,
    String? myVote,
    BattleStatus? status,
    String? winnerId,
  }) =>
      Battle(
        id: id,
        challenger: challenger ?? this.challenger,
        opponent: opponent ?? this.opponent,
        topic: topic,
        status: status ?? this.status,
        endsAt: endsAt,
        winnerId: winnerId ?? this.winnerId,
        myVote: myVote ?? this.myVote,
        durationHours: durationHours,
      );

  factory Battle.fromRow(Map<String, dynamic> row, {String? myVote}) {
    final ch = row['challenger'] as Map<String, dynamic>? ?? const {};
    final op = row['opponent'] as Map<String, dynamic>? ?? const {};

    return Battle(
      id: row['id'].toString(),
      topic: BattleTopicInfo.fromKey(row['topic'] as String?),
      status: BattleStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => BattleStatus.pending,
      ),
      endsAt: row['ends_at'] == null
          ? null
          : DateTime.tryParse(row['ends_at'] as String)?.toLocal(),
      winnerId: row['winner_id']?.toString(),
      durationHours: (row['duration_hours'] as num?)?.toInt() ?? 6,
      myVote: myVote,
      challenger: BattleSide(
        userId: row['challenger_id'].toString(),
        name: ch['name'] as String? ?? '',
        handle: ch['handle'] as String? ?? '',
        avatarUrl: ch['avatar_url'] as String?,
        verified: ch['verified'] as bool? ?? false,
        text: row['challenger_text'] as String? ?? '',
        votes: (row['challenger_votes'] as num?)?.toInt() ?? 0,
      ),
      opponent: BattleSide(
        userId: row['opponent_id'].toString(),
        name: op['name'] as String? ?? '',
        handle: op['handle'] as String? ?? '',
        avatarUrl: op['avatar_url'] as String?,
        verified: op['verified'] as bool? ?? false,
        text: row['opponent_text'] as String? ?? '',
        votes: (row['opponent_votes'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
