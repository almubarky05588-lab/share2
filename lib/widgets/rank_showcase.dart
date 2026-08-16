import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/battle.dart';

/// مشهد استعراض الرتبة — خلفية فاتحة، الصور بخلفيتها البيضاء
class RankShowcase extends StatefulWidget {
  const RankShowcase({
    super.key,
    required this.rank,
    required this.name,
    required this.points,
    this.battles = 0,
    this.wins = 0,
  });

  final BattleRank rank;
  final String name;
  final int points;
  final int battles;
  final int wins;

  static Future<void> show(
    BuildContext context, {
    required BattleRank rank,
    required String name,
    required int points,
    int battles = 0,
    int wins = 0,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.white,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => RankShowcase(
        rank: rank,
        name: name,
        points: points,
        battles: battles,
        wins: wins,
      ),
    );
  }

  @override
  State<RankShowcase> createState() => _RankShowcaseState();
}

class _RankShowcaseState extends State<RankShowcase>
    with TickerProviderStateMixin {
  static const _shout = 'assets/jnilsons-kung-fu-fu-464591.mp3';
  static const _swing =
      'assets/freesound_community-sword-swings-14592.mp3';

  static const _frames = [
    'assets/ninja1.png.JPG',
    'assets/ninja2.png.JPG',
    'assets/ninja3.png.JPG',
    'assets/ninja4.png.JPG',
  ];

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  final _p1 = AudioPlayer();
  final _p2 = AudioPlayer();

  int _frame = 0;
  bool _shouted = false;
  bool _swung = false;
  bool _done = false;

  bool get _hasFrames =>
      widget.rank == BattleRank.ninja ||
      widget.rank == BattleRank.samurai ||
      widget.rank == BattleRank.beast;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _run();
  }

  Future<void> _run() async {
    _c.addListener(_tick);
    await _c.forward();
    if (mounted) setState(() => _done = true);
  }

  void _tick() {
    final v = _c.value;

    final f = v < 0.22
        ? 0
        : v < 0.48
            ? 1
            : v < 0.72
                ? 2
                : 3;

    if (f != _frame) setState(() => _frame = f);

    if (!_shouted && v > 0.22 && _hasFrames) {
      _shouted = true;
      HapticFeedback.heavyImpact();
      _play(_p1, _shout);
    }

    if (!_swung && v > 0.50 && _hasFrames) {
      _swung = true;
      HapticFeedback.mediumImpact();
      _play(_p2, _swing);
    }
  }

  Future<void> _play(AudioPlayer p, String asset) async {
    try {
      await p.setAsset(asset);
      await p.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _c.dispose();
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = widget.rank;

    return Material(
      color: Colors.white,
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                _backdrop(rank),
                if (_hasFrames) _warrior() else _badgeOnly(rank),
                _info(context, rank),
              ],
            );
          },
        ),
      ),
    );
  }

  /// خلفية متدرّجة فاتحة بلون الرتبة
  Widget _backdrop(BattleRank rank) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            rank.color.withOpacity(0.06),
            rank.color.withOpacity(0.14),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 340,
          height: 340,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                rank.color.withOpacity(0.16),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// المحارب — تسلسل الصور بخلفيتها البيضاء
  Widget _warrior() {
    final v = _c.value;

    final enter = Curves.easeOutCubic.transform((v * 5).clamp(0.0, 1.0));
    final dx = (1 - enter) * 180;

    final hit = (v > 0.48 && v < 0.60)
        ? math.sin((v - 0.48) * math.pi * 18) * 5
        : 0.0;

    return Transform.translate(
      offset: Offset(dx + hit, -50),
      child: Opacity(
        opacity: enter,
        child: Image.asset(
          _frames[_frame],
          height: MediaQuery.of(context).size.height * 0.5,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _badgeOnly(BattleRank rank) {
    final v = Curves.elasticOut.transform(_c.value.clamp(0.0, 1.0));

    return Transform.translate(
      offset: const Offset(0, -50),
      child: Transform.scale(
        scale: 0.5 + v * 0.5,
        child: Transform.rotate(
          angle: (1 - v) * math.pi / 5,
          child: Icon(rank.icon, size: 130, color: rank.color),
        ),
      ),
    );
  }

  /// الاسم والرتبة والسجل
  Widget _info(BuildContext context, BattleRank rank) {
    final show = ((_c.value - 0.6) / 0.4).clamp(0.0, 1.0);

    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.09,
      child: Opacity(
        opacity: show,
        child: Transform.translate(
          offset: Offset(0, (1 - show) * 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: rank.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: rank.color, width: 1.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(rank.icon, size: 24, color: rank.color),
                    const SizedBox(width: 10),
                    Text(
                      rank.label,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.5,
                        color: rank.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF14171A),
                ),
              ),
              const SizedBox(height: 14),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stat('${widget.points}', 'نقطة'),
                    _dot(),
                    _stat('${widget.battles}', 'نزال'),
                    _dot(),
                    _stat('${widget.wins}', 'انتصار'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_done)
                const Text(
                  'اضغط للإغلاق',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA3B2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF14171A),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: Color(0xFF9AA3B2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() => Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: Color(0xFFD5DBE2),
          shape: BoxShape.circle,
        ),
      );
}
