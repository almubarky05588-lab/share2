import 'package:flutter/material.dart';

import '../models/battle.dart';

/// شارة الرتبة — تظهر جنب الاسم
class RankBadge extends StatelessWidget {
  const RankBadge({
    super.key,
    required this.rank,
    this.size = 14,
    this.withLabel = false,
  });

  final BattleRank rank;
  final double size;
  final bool withLabel;

  @override
  Widget build(BuildContext context) {
    // المبتدئ بلا شارة
    if (rank == BattleRank.rookie) return const SizedBox.shrink();

    if (!withLabel) {
      return Icon(rank.icon, size: size, color: rank.color);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: rank.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rank.color.withOpacity(0.4)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(rank.icon, size: size, color: rank.color),
          const SizedBox(width: 5),
          Text(
            rank.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: rank.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط تقدّم نحو الرتبة التالية
class RankProgress extends StatelessWidget {
  const RankProgress({
    super.key,
    required this.points,
    this.showLabel = true,
  });

  final int points;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final rank = BattleRankInfo.fromPoints(points);
    final next = rank.next;

    if (next == null) {
      return Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: [
          RankBadge(rank: rank, withLabel: true, size: 15),
          const SizedBox(width: 8),
          Text(
            'بلغتَ القمة · $points نقطة',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: rank.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final from = rank.threshold;
    final to = next.threshold;
    final ratio = ((points - from) / (to - from)).clamp(0.0, 1.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RankBadge(rank: rank, withLabel: true, size: 15),
              const Spacer(),
              if (showLabel)
                Text(
                  '${to - points} نقطة لـ${next.label}',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: next.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: rank.color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(rank.color),
            ),
          ),
        ],
      ),
    );
  }
}
