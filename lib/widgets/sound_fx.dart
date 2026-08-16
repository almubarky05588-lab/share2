import 'package:video_player/video_player.dart';

/// تشغيل مؤثر صوتي قصير عبر video_player
class SoundFx {
  SoundFx._();

  static Future<void> play(String asset) async {
    VideoPlayerController? c;

    try {
      c = VideoPlayerController.asset(asset);
      await c.initialize();
      await c.setVolume(1);
      await c.play();

      final ms = c.value.duration.inMilliseconds;
      await Future<void>.delayed(
        Duration(milliseconds: ms > 0 ? ms + 250 : 1800),
      );
    } catch (_) {
      // تجاهل — الصوت ليس حرجًا
    } finally {
      await c?.dispose();
    }
  }
}
