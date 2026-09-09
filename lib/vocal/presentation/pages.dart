import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../controllers/music_learning_controller.dart';
import '../widgets/control_bar.dart';
import '../widgets/piano_roll.dart';
import '../widgets/timeline_header.dart';
import '../widgets/timeline_legend.dart';
import '../widgets/video_id_selector.dart';
import '../widgets/waveform_view.dart';
import '../widgets/youtube_player_view.dart';
import 'timeline_calculator.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  late final MusicLearningController controller;
  static const timelineCalculator = TimelineCalculator();
  bool _initialized = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    controller = MusicLearningController();
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _initializationError = controller.errorMessage;
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        if (!_initialized) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.videoIds.isEmpty) {
          return Center(
            child: Text(_initializationError ?? '動画データを読み込めませんでした。'),
          );
        }

        return _MusicLearningContent(
          controller: controller,
          calculator: timelineCalculator,
        );
      },
    );
  }
}

class _MusicLearningContent extends StatelessWidget {
  const _MusicLearningContent({
    required this.controller,
    required this.calculator,
  });

  final MusicLearningController controller;
  final TimelineCalculator calculator;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final contentWidth = availableWidth.clamp(1.0, 760.0).toDouble();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.hasListeners) {
            controller.updateViewportWidth(contentWidth);
          }
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // These controls are independent of the 100 ms timeline
                  // updates, so they are kept out of the hot rebuild path.
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => VideoIdSelector(
                      videoIds: controller.videoIds,
                      selectedVideoId: controller.selectedVideoId,
                      onSelected: controller.selectVideo,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => ControlBar(
                      microphoneEnabled: controller.isMicrophoneEnabled,
                      waveformVisible: controller.isWaveformVisible,
                      pianoRollDisplayMode: controller.pianoRollDisplayMode,
                      onMicrophonePressed: controller.toggleMicrophone,
                      onWaveformPressed: controller.toggleWaveform,
                      onPianoRollDisplayModePressed:
                          controller.togglePianoRollDisplayMode,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => TimelineHeader(
                      currentTime: controller.currentTime,
                      duration: controller.videoDuration,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final frame = controller.timelineFrame;
                      return _TimelinePanel(
                        height: 320,
                        child: RepaintBoundary(
                          child: PianoRoll(
                            frame: frame,
                            calculator: calculator,
                            onSeek: controller.seekTo,
                          ),
                        ),
                      );
                    },
                  ),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      if (!controller.isWaveformVisible) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          const SizedBox(height: 10),
                          _TimelinePanel(
                            height: 116,
                            child: RepaintBoundary(
                              child: WaveformView(
                                frame: controller.timelineFrame,
                                calculator: calculator,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const TimelineLegend(),
                  const SizedBox(height: 12),
                  _VideoPanel(
                    controller: controller.youtubeController,
                    isLoadingListenable: controller.videoLoadingListenable,
                  ),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final error = controller.errorMessage;
                      if (error == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1018),
          border: Border.all(color: const Color(0xFF263142)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}

class _VideoPanel extends StatelessWidget {
  const _VideoPanel({
    required this.controller,
    required this.isLoadingListenable,
  });

  final YoutubePlayerController? controller;
  final ValueListenable<bool> isLoadingListenable;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ValueListenableBuilder<bool>(
          valueListenable: isLoadingListenable,
          builder: (context, isLoading, _) =>
              YoutubePlayerView(controller: controller, isLoading: isLoading),
        ),
      ),
    );
  }
}
