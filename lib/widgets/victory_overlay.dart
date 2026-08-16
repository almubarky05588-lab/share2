import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/battle.dart';

/// مؤثر الفوز — تاج ينزل مع ومضة ذهبية
class VictoryOverlay extends StatefulWidget {
  const VictoryOverlay({
    super.key,
    required this.points,
    this.rankUp,
  });

  final int points;
  final BattleRank? rankUp;

  static Future<void> show(
    BuildContext context, {
    required int points,
    BattleRank? rankUp,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) =>
          VictoryOverlay(points: points, rankUp: rankUp),
    );
  }

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFD4A017);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _playSound();
    _c.forward();
  }

  Future<void> _playSound() async {
    try {
      await _player.setAsset('assets/victory.mp3');
      await _player.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _c.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final drop = Curves.elasticOut.transform(
              _c.value.clamp(0.0, 1.0),
            );
            final fade = Curves.easeOut.transform(
              (_c.value * 1.6).clamp(0.0, 1.0),
            );

            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: fade * 0.5,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [_gold, Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: _c.value * math.pi / 3,
                  child: Opacity(
                    opacity: fade * 0.35,
                    child: CustomPaint(
                      size: const Size(280, 280),
                      painter: _RaysPainter(),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -60 * (1 - drop)),
                      child: Transform.scale(
                        scale: 0.6 + drop * 0.4,
                        child: const Icon(
                          Icons.emoji_events,
                          size: 110,
                          color: _gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: fade,
                      child: Column(
                        children: [
                          const Text(
                            'فزتَ بالنزال',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: _gold.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _gold.withOpacity(0.5)),
                            ),
                            child: Text(
                              '+٣ نقاط · المجموع ${widget.points}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.6,
                                color: _gold,
                              ),
                            ),
                          ),
                          if (widget.rankUp != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: widget.rankUp!.color
                                    .withOpacity(0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: widget.rankUp!.color),
                              ),
                              child: Column(
                                children: [
                                  Icon(widget.rankUp!.icon,
                                      size: 30,
                                      color: widget.rankUp!.color),
                                  const SizedBox(height: 7),
                                  Text(
                                    'ترقّيتَ إلى ${widget.rankUp!.label}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: widget.rankUp!.color,
                                    ),
                                  ),
                                  if (widget.rankUp!.grantsJump) ...[
                                    const SizedBox(height: 5),
                                    const Text(
                                      'حصلتَ على موجة 🌊',
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.6,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 26),
                          const Text(
                            'اضغط للإغلاق',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// أشعة خلف التاج
class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFD4A017)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2;
      canvas.drawLine(
        center + Offset(math.cos(a) * 70, math.sin(a) * 70),
        center + Offset(math.cos(a) * 130, math.sin(a) * 130),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
