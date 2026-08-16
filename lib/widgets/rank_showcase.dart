import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/battle.dart';

/// مشهد استعراض الرتبة — يُعرض عند الضغط على الشارة
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
      barrierColor: Colors.black.withOpacity(0.94),
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
  static const _shout =
      'assets/jnilsons-kung-fu-fu-464591.mp3';
  static const _swing =
      'assets/freesound_community-sword-swings-14592.mp3';

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  final _player = AudioPlayer();
  final _player2 = AudioPlayer();

  /// الإطار الحالي 1..4
  int _frame = 1;
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
    _run();
  }

  Future<void> _run() async {
    _c.addListener(_onTick);
    await _c.forward();
    if (mounted) setState(() => _done = true);
  }

  void _onTick() {
    final v = _c.value;

    // تسلسل الإطارات
    final f = v < 0.18
        ? 1
        : v < 0.42
            ? 2
            : v < 0.66
                ? 3
                : 4;

    if (f != _frame) setState(() => _frame = f);

    // الصرخة عند القفزة
    if (!_shouted && v > 0.18 && _hasFrames) {
      _shouted = true;
      HapticFeedback.heavyImpact();
      _play(_player, _shout);
    }

    // صفير السيف
    if (!_swung && v > 0.44 && _hasFrames) {
      _swung = true;
      HapticFeedback.mediumImpact();
      _play(_player2, _swing);
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
    _player.dispose();
    _player2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = widget.rank;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;

            return Stack(
              alignment: Alignment.center,
              children: [
                _glow(rank, v),
                if (_hasFrames) _smoke(v),
                if (_hasFrames) _warrior(v) else _badgeOnly(rank, v),
                _info(context, rank, v),
                if (_done) _hint(context),
              ],
            );
          },
        ),
      ),
    );
  }

  /// هالة لون الرتبة
  Widget _glow(BattleRank rank, double v) {
    final pulse = 0.5 + math.sin(v * math.pi * 3) * 0.2;

    return Opacity(
      opacity: (v * 2).clamp(0.0, 1.0) * 0.55,
      child: Container(
        width: 420,
        height: 420,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              rank.color.withOpacity(pulse),
              rank.color.withOpacity(0.12),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }

  /// دخان يتصاعد
  Widget _smoke(double v) {
    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _SmokePainter(v, widget.rank.color),
      ),
    );
  }

  /// المحارب — تسلسل الإطارات
  Widget _warrior(double v) {
    // دخول من اليمين ثم استقرار
    final enter = Curves.easeOutCubic.transform((v * 4).clamp(0.0, 1.0));
    final dx = (1 - enter) * 220;

    // ارتجاج لحظة الضربة
    final hit = (v > 0.42 && v < 0.52)
        ? math.sin((v - 0.42) * math.pi * 20) * 6
        : 0.0;

    // اختفاء تدريجي في النهاية
    final fade = v > 0.9 ? (1 - (v - 0.9) / 0.1).clamp(0.0, 1.0) : 1.0;

    return Transform.translate(
      offset: Offset(dx + hit, -30),
      child: Opacity(
        opacity: enter * fade,
        child: Image.asset(
          'assets/ninja_$_frame.png',
          height: MediaQuery.of(context).size.height * 0.46,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// للرتب التي لا صور لها — شارة كبيرة
  Widget _badgeOnly(BattleRank rank, double v) {
    final scale = Curves.elasticOut.transform(v.clamp(0.0, 1.0));

    return Transform.scale(
      scale: 0.5 + scale * 0.5,
      child: Transform.rotate(
        angle: (1 - scale) * math.pi / 4,
        child: Icon(rank.icon, size: 130, color: rank.color),
      ),
    );
  }

  /// الاسم والرتبة والسجل
  Widget _info(BuildContext context, BattleRank rank, double v) {
    final show = (v - 0.55).clamp(0.0, 1.0) / 0.45;

    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.14,
      child: Opacity(
        opacity: show.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - show) * 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 9),
                decoration: BoxDecoration(
                  color: rank.color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: rank.color, width: 1.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(rank.icon, size: 22, color: rank.color),
                    const SizedBox(width: 9),
                    Text(
                      rank.label,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.5,
                        color: rank.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: Colors.white54,
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
          color: Colors.white24,
          shape: BoxShape.circle,
        ),
      );

  Widget _hint(BuildContext context) {
    return Positioned(
      bottom: 44,
      child: Text(
        'اضغط للإغلاق',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.35),
        ),
      ),
    );
  }
}

/// دخان متصاعد
class _SmokePainter extends CustomPainter {
  _SmokePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final base = size.height * 0.72;

    final rnd = math.Random(7);

    for (var i = 0; i < 14; i++) {
      final seed = rnd.nextDouble();
      final phase = (t + seed) % 1.0;

      final x = cx + (seed - 0.5) * size.width * 0.75;
      final y = base - phase * size.height * 0.5;
      final r = 20 + phase * 70 + seed * 25;

      final opacity = (1 - phase) * 0.16;
      if (opacity <= 0) continue;

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = color.withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter old) => old.t != t;
}
