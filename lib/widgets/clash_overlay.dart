import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sound_fx.dart';

/// مؤثر التحام السيفين — يُعرض عند بدء النزال
class ClashOverlay extends StatefulWidget {
  const ClashOverlay({super.key, this.onDone});

  final VoidCallback? onDone;

  static Future<void> show(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const ClashOverlay(),
    );
  }

  @override
  State<ClashOverlay> createState() => _ClashOverlayState();
}

class _ClashOverlayState extends State<ClashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _clashed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    _slide.addListener(() {
      if (!_clashed && _slide.value > 0.82) {
        _clashed = true;
        HapticFeedback.heavyImpact();
        _shake.forward(from: 0);
        SoundFx.play('assets/clash.mp3');
      }
    });

    await _slide.forward();
    await Future<void>.delayed(const Duration(milliseconds: 750));

    if (!mounted) return;
    Navigator.of(context).maybePop();
    widget.onDone?.call();
  }

  @override
  void dispose() {
    _slide.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_slide, _shake]),
        builder: (context, _) {
          final t = Curves.easeInCubic.transform(_slide.value);

          final shake = _shake.isAnimating
              ? math.sin(_shake.value * math.pi * 6) *
                  8 *
                  (1 - _shake.value)
              : 0.0;

          final flash = _shake.isAnimating
              ? (1 - _shake.value).clamp(0.0, 1.0) * 0.7
              : 0.0;

          return Transform.translate(
            offset: Offset(shake, 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (flash > 0)
                  Container(
                    color: Colors.white.withOpacity(flash * 0.45),
                  ),
                Transform.translate(
                  offset: Offset(w * 0.55 * (1 - t), 0),
                  child: Transform.rotate(
                    angle: -math.pi / 5,
                    child: const _Sword(color: Color(0xFFE0455C)),
                  ),
                ),
                Transform.translate(
                  offset: Offset(-w * 0.55 * (1 - t), 0),
                  child: Transform.rotate(
                    angle: math.pi / 5,
                    child: const _Sword(color: Color(0xFF2F6BFF)),
                  ),
                ),
                if (_clashed)
                  Opacity(
                    opacity: flash.clamp(0.0, 1.0),
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.95),
                            const Color(0xFFFFD166).withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.28,
                  child: AnimatedOpacity(
                    opacity: _clashed ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Text(
                      'بدأ النزال',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// سيف مرسوم
class _Sword extends StatelessWidget {
  const _Sword({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 210,
      child: CustomPaint(painter: _SwordPainter(color)),
    );
  }
}

class _SwordPainter extends CustomPainter {
  _SwordPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final blade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, const Color(0xFFD9DEE8)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.68));

    final path = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx + w * 0.17, h * 0.09)
      ..lineTo(cx + w * 0.17, h * 0.66)
      ..lineTo(cx - w * 0.17, h * 0.66)
      ..lineTo(cx - w * 0.17, h * 0.09)
      ..close();

    canvas.drawPath(path, blade);

    canvas.drawLine(
      Offset(cx, h * 0.06),
      Offset(cx, h * 0.64),
      Paint()
        ..color = const Color(0xFF9AA3B2)
        ..strokeWidth = 1.4,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.66, w, h * 0.045),
        const Radius.circular(4),
      ),
      Paint()..color = color,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.11, h * 0.70, w * 0.22, h * 0.22),
        const Radius.circular(5),
      ),
      Paint()..color = color.withOpacity(0.85),
    );

    canvas.drawCircle(
      Offset(cx, h * 0.95),
      w * 0.16,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SwordPainter old) => old.color != color;
}
