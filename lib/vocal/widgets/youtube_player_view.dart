import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubePlayerView extends StatelessWidget {
  const YoutubePlayerView({
    super.key,
    required this.controller,
    required this.isLoading,
  });

  final YoutubePlayerController? controller;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final playerController = controller;
    if (playerController == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: Text('YouTubeプレイヤーを準備中...')),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        YoutubePlayer(
          controller: playerController,
          aspectRatio: 16 / 9,
          keepAlive: true,
        ),
        if (isLoading)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
