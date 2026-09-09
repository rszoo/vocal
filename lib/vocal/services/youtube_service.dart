import 'dart:async';

import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubeService {
  YoutubeService({required String initialVideoId})
    : controller = YoutubePlayerController.fromVideoId(
        videoId: initialVideoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          strictRelatedVideos: true,
          showVideoAnnotations: false,
          enableCaption: false,
          videoStateUpdateInterval: 100,
        ),
      );

  final YoutubePlayerController controller;
  StreamSubscription<YoutubeVideoState>? _positionSubscription;

  void listenToPosition(void Function(double seconds) onPosition) {
    _positionSubscription?.cancel();
    _positionSubscription = controller.videoStateStream.listen(
      (state) => onPosition(state.position.inMilliseconds / 1000.0),
    );
  }

  Future<void> loadVideo(String videoId) {
    // Keep the same controller/WebView alive. Recreating the player widget
    // for every selection can leave the iframe in a transient invalid state.
    return controller.loadVideoById(videoId: videoId);
  }

  Future<void> seekTo(double seconds) {
    return controller.seekTo(seconds: seconds, allowSeekAhead: true);
  }

  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await controller.close();
  }
}
