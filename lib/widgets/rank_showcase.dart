import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

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
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 250),
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
    with SingleTickerProviderStateMixin {
  /// نافذة العرض من الفيديو
  static const _start = Duration(milliseconds: 2400);
  static const _end = Duration(milliseconds: 6800);

  /// نسبة ما يُقتطع من أسفل الفيديو (العلامة المائية)
  static const _cropBottom = 0.14;

  VideoPlayerController? _video;
  bool _ready = false;
  bool _finished = false;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool get _hasVideo =>
      widget.rank == BattleRank.ninja ||
      widget.rank == BattleRank.samurai ||
      widget.rank == BattleRank.beast;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();

    if (_hasVideo) {
      _initVideo();
    } else {
      _ready = true;
      _finished = true;
      _fade.forward();
    }
  }

  Future<void> _initVideo() async {
    final c = VideoPlayerController.asset('assets/ninja.MP4');
    _video = c;

    try {
      await c.initialize();
      await c.seekTo(_start);
      await c.setVolume(1);
      await c.play();

      c.addListener(_watch);

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _finished = true;
      });
      _fade.forward();
    }
  }

  void _watch() {
    final c = _video;
    if (c == null || !c.value.isInitialized) return;

    if (c.value.position >= _end && !_finished) {
      _finished = true;
      c.pause();
      HapticFeedback.lightImpact();
      _fade.forward();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _video?.removeListener(_watch);
    _video?.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = widget.rank;

    return Material(
      color: Colors.black,
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _glow(rank),
            if (_hasVideo && _ready && _video != null)
              _videoLayer()
            else if (!_hasVideo)
              _badgeOnly(rank),
            if (!_ready)
              const CircularProgressIndicator(color: Colors.white24),
            _info(context, rank),
          ],
        ),
      ),
    );
  }

  /// هالة لون الرتبة خلف المشهد
  Widget _glow(BattleRank rank) {
    return Container(
      width: 460,
      height: 460,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            rank.color.withOpacity(0.30),
            rank.color.withOpacity(0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  /// الفيديو — مقصوص من الأسفل لإخفاء العلامة المائية
  Widget _videoLayer() {
    final c = _video!;
    final size = MediaQuery.of(context).size;

    return SizedBox(
      width: size.width,
      height: size.height * 0.62,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1 - _cropBottom,
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
        ),
      ),
    );
  }

  Widget _badgeOnly(BattleRank rank) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (_, v, __) => Transform.scale(
        scale: 0.5 + v * 0.5,
        child: Transform.rotate(
          angle: (1 - v) * math.pi / 5,
          child: Icon(rank.icon, size: 130, color: rank.color),
        ),
      ),
    );
  }

  /// الاسم والرتبة والسجل — يظهر بعد المشهد
  Widget _info(BuildContext context, BattleRank rank) {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.11,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _fade,
            curve: Curves.easeOutCubic,
          )),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: rank.color.withOpacity(0.18),
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
                  color: Colors.white,
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
              const SizedBox(height: 26),
              Text(
                'اضغط للإغلاق',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.3),
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
}
