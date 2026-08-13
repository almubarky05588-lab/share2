import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// عارض الوسائط بشاشة كاملة — صورة قابلة للتكبير أو فيديو بمشغّل حقيقي
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.url,
    required this.isVideo,
  });

  final String url;
  final bool isVideo;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;

    try {
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_ready) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: widget.isVideo ? _video() : _image(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image() {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Image.network(
        widget.url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _video() {
    if (_failed) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.white54, size: 44),
          SizedBox(height: 10),
          Text(
            'تعذّر تشغيل الفيديو',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    final c = _controller;
    if (!_ready || c == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
          if (!c.value.isPlaying)
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow,
                  color: Colors.white, size: 38),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            ),
          ),
        ],
      ),
    );
  }
}
