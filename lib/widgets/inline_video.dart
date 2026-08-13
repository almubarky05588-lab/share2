import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../theme/app_theme.dart';

/// فيديو داخل التايم لاين — يشتغل تلقائيًا بلا صوت عند ظهوره
class InlineVideo extends StatefulWidget {
  const InlineVideo({
    super.key,
    required this.url,
    required this.postId,
    this.onTap,
    this.height = 240,
  });

  final String url;
  final String postId;
  final VoidCallback? onTap;
  final double height;

  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _failed = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;

    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0); // صامت في الفيد
      if (!mounted) return;
      setState(() => _ready = true);
      if (_visible) c.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _onVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction > 0.6;
    if (visible == _visible) return;

    _visible = visible;
    final c = _c;
    if (c == null || !_ready) return;

    if (visible) {
      c.play();
    } else {
      c.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video_${widget.postId}'),
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedia),
          child: SizedBox(
            width: double.infinity,
            height: widget.height,
            child: _content(),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_failed) {
      return Container(
        color: AppColors.text,
        alignment: Alignment.center,
        child: const Icon(Icons.videocam_off_outlined,
            color: Colors.white54, size: 36),
      );
    }

    final c = _c;
    if (!_ready || c == null) {
      return Container(
        color: AppColors.text,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: Colors.white38,
          strokeWidth: 2,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.size.width == 0 ? 16 : c.value.size.width,
            height: c.value.size.height == 0 ? 9 : c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
        // مؤشر الصمت — الضغط يفتح الفيديو بالصوت
        Positioned(
          bottom: 10,
          left: 10,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volume_off,
                color: Colors.white, size: 17),
          ),
        ),
      ],
    );
  }
}
