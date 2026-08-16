import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/battle.dart';
import 'sound_fx.dart';

/// مشهد استعراض الرتبة
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

  /// صورة كل رتبة — المفرغة الجديدة للنينجا
  static const Map<BattleRank, String> _art = {
    BattleRank.ninja: 'assets/IMG_7470.png',
  };

  /// دخول المشهد
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  /// طفو مستمر بعد الدخول
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  bool _shouted = false;
  bool _done = false;

  String? get _image => _art[widget.rank];

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
    if (!_shouted && _c.value > 0.15 && _image != null) {
      _shouted = true;
      HapticFeedback.heavyImpact();
      SoundFx.play(_shout);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _idle.dispose();
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
          animation: Listenable.merge([_c, _idle]),
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                _backdrop(rank),
                _rings(rank),
                if (_image != null) _speedLines(rank),
                if (_image != null) _hero() else _badgeOnly(rank),
                _info(context, rank),
              ],
            );
          },
        ),
      ),
    );
  }

  /// تدرج الخلفية
  Widget _backdrop(BattleRank rank) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            rank.color.withOpacity(0.05),
            rank.color.withOpacity(0.16),
          ],
        ),
      ),
    );
  }

  /// حلقات توهج تتنفس خلف البطل
  Widget _rings(BattleRank rank) {
    final breath = 1 + _idle.value * 0.06;
    final appear = Curves.easeOut.transform(_c.value.clamp(0.0, 1.0));

    return Transform.translate(
      offset: const Offset(0, -60),
      child: Opacity(
        opacity: appear,
        child: Transform.scale(
          scale: breath,
          child: Container(
            width: 330,
            height: 330,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  rank.color.withOpacity(0.20),
                  rank.color.withOpacity(0.06),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: rank.color.withOpacity(0.25),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// خطوط سرعة خلف القفزة — تظهر لحظة الدخول ثم تتلاشى
  Widget _speedLines(BattleRank rank) {
    final v = _c.value;
    if (v > 0.55) return const SizedBox.shrink();

    final fade = (1 - v / 0.55).clamp(0.0, 1.0);
    final w = MediaQuery.of(context).size.width;

    return Opacity(
      opacity: fade * 0.6,
      child: Transform.translate(
        offset: Offset(v * -90, -70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (i) {
            final len = w * (0.3 + (i % 3) * 0.14);
            return Container(
              margin: EdgeInsets.only(bottom: 26 + (i % 2) * 12),
              width: len,
              height: 2.4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    rank.color.withOpacity(0.55),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// البطل — قفزة دخول ثم طفو
  Widget _hero() {
    final v = _c.value;

    // دخول قوسي من اليمين مع تكبير مرن
    final enter = Curves.easeOutBack.transform((v * 2.2).clamp(0.0, 1.0));
    final dx = (1 - enter) * 230;
    final dy = -60 + (1 - enter) * -70;

    // هبوط بارتجاجة خفيفة
    final land = (v > 0.42 && v < 0.56)
        ? math.sin((v - 0.42) * math.pi * 14) * 4
        : 0.0;

    // طفو مستمر بعد الاستقرار
    final float = _done ? math.sin(_idle.value * math.pi) * 7 : 0.0;

    return Transform.translate(
      offset: Offset(dx, dy + land + float),
      child: Transform.scale(
        scale: 0.7 + enter * 0.3,
        child: Opacity(
          opacity: enter.clamp(0.0, 1.0),
          child: Image.asset(
            _image!,
            height: MediaQuery.of(context).size.height * 0.42,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
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
