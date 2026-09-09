import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../domain/models.dart';
import '../domain/models/timeline_frame.dart';
import '../infrastructure/services/pitch_asset_loader.dart';
import '../presentation/timeline_calculator.dart';
import '../services/microphone_service.dart';
import '../services/pitch_matcher.dart';
import '../services/youtube_service.dart';

class MusicLearningController extends ChangeNotifier {
  MusicLearningController({
    PitchAssetLoader? assetRepository,
    MicrophoneService? microphoneService,
    PitchMatcher? pitchMatcher,
    TimelineCalculator? timelineCalculator,
  }) : _assetRepository = assetRepository ?? const PitchAssetLoader(),
       _microphoneService = microphoneService ?? MicrophoneService(),
       _pitchMatcher = pitchMatcher ?? const PitchMatcher(),
       _timelineCalculator = timelineCalculator ?? const TimelineCalculator();

  final PitchAssetLoader _assetRepository;
  final MicrophoneService _microphoneService;
  final PitchMatcher _pitchMatcher;
  final TimelineCalculator _timelineCalculator;

  YoutubeService? _youtubeService;
  int _selectionGeneration = 0;
  Timer? _timelineNotifyTimer;

  List<String> videoIds = const [];
  String? selectedVideoId;
  List<PitchEvent> referenceEvents = const [];
  List<LivePitch> livePitches = const [];
  List<WaveformSample> liveWaveform = const [];
  Set<int> matchingReferenceIndices = const {};

  double currentTime = 0;
  double videoDuration = 0;
  double viewportWidth = 0;
  bool isLoading = true;
  bool isMicrophoneEnabled = false;
  bool isWaveformVisible = false;
  bool isVideoLoading = true;
  final ValueNotifier<bool> videoLoadingListenable = ValueNotifier<bool>(true);
  PianoRollDisplayMode pianoRollDisplayMode = PianoRollDisplayMode.fullRange;
  String? errorMessage;

  YoutubePlayerController? get youtubeController => _youtubeService?.controller;

  TimelineFrame get timelineFrame => _timelineCalculator.calculate(
    currentTime: currentTime,
    duration: videoDuration,
    totalWidth: viewportWidth,
    referenceEvents: referenceEvents,
    livePitches: livePitches,
    liveWaveform: liveWaveform,
    matchingReferenceIndices: matchingReferenceIndices,
    displayMode: pianoRollDisplayMode,
  );

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    try {
      videoIds = await _assetRepository.loadVideoIds();
      if (videoIds.isEmpty) {
        throw StateError('assets/pitches/ に JSON ファイルがありません。');
      }

      await selectVideo(videoIds.first, notify: false);
      _microphoneService.onFrame = _onMicrophoneFrame;
      isLoading = false;
      notifyListeners();
    } catch (error) {
      isLoading = false;
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> selectVideo(String videoId, {bool notify = true}) async {
    if (!videoIds.contains(videoId)) return;

    final generation = ++_selectionGeneration;
    selectedVideoId = videoId;
    currentTime = 0;
    videoDuration = 0;
    livePitches = const [];
    liveWaveform = const [];
    matchingReferenceIndices = const {};
    isVideoLoading = true;
    videoLoadingListenable.value = true;
    errorMessage = null;
    if (notify) notifyListeners();

    try {
      final events = await _assetRepository.loadPitchEvents(videoId);
      if (generation != _selectionGeneration) return;
      referenceEvents = events;

      // fromVideoId() already queues the initial video. During initialize(),
      // the player widget has not been mounted yet because isLoading is true.
      // Calling loadVideoById() here would wait for the WebView/iframe to become
      // ready, while the widget needed to make it ready is not on the tree yet.
      // For the first video, only create the controller and let the first build
      // mount YoutubePlayer. Subsequent selections can load into the existing
      // player normally.
      final shouldLoadIntoExistingPlayer = _youtubeService != null;
      await _ensureYoutubeService(videoId);
      if (generation != _selectionGeneration) return;
      if (shouldLoadIntoExistingPlayer) {
        await _youtubeService!.loadVideo(videoId);
      }
    } catch (error) {
      if (generation != _selectionGeneration) return;
      errorMessage = '動画の読み込みに失敗しました: $error';
      isVideoLoading = false;
      videoLoadingListenable.value = false;
      notifyListeners();
    }

    if (notify) notifyListeners();
  }

  Future<void> _ensureYoutubeService(String videoId) async {
    if (_youtubeService != null) return;

    _youtubeService = YoutubeService(initialVideoId: videoId);
    _youtubeService!.listenToPosition(_onVideoPositionChanged);

    _youtubeService!.controller.listen((value) {
      isVideoLoading =
          value.playerState == PlayerState.unknown ||
          value.playerState == PlayerState.buffering;
      videoLoadingListenable.value = isVideoLoading;
      if (value.hasError) {
        errorMessage = 'YouTube エラー: ${value.error}';
      }
      final duration = value.metaData.duration;
      if (duration > Duration.zero)
        videoDuration = duration.inMilliseconds / 1000.0;
      notifyListeners();
    });
  }

  void _onVideoPositionChanged(double seconds) {
    currentTime = seconds;
    _microphoneService.syncToVideoTime(seconds);

    final match = _pitchMatcher.match(
      currentTime: currentTime,
      referenceEvents: referenceEvents,
      livePitches: livePitches,
      octaveOnly: pianoRollDisplayMode == PianoRollDisplayMode.singleOctave,
    );
    matchingReferenceIndices = match.matchingIndices;
    _scheduleTimelineNotify();
  }

  void updateViewportWidth(double width) {
    if ((viewportWidth - width).abs() < 0.5) return;
    viewportWidth = width;
    notifyListeners();
  }

  Future<void> toggleMicrophone() async {
    if (isMicrophoneEnabled) {
      await _microphoneService.stop();
      isMicrophoneEnabled = false;
      livePitches = const [];
      liveWaveform = const [];
      matchingReferenceIndices = const {};
      notifyListeners();
      return;
    }

    final started = await _microphoneService.start(
      initialVideoTime: currentTime,
    );
    if (!started) {
      errorMessage = 'マイクの権限が許可されていません。';
      notifyListeners();
      return;
    }

    isMicrophoneEnabled = true;
    errorMessage = null;
    notifyListeners();
  }

  void toggleWaveform() {
    isWaveformVisible = !isWaveformVisible;
    notifyListeners();
  }

  void togglePianoRollDisplayMode() {
    pianoRollDisplayMode =
        pianoRollDisplayMode == PianoRollDisplayMode.fullRange
        ? PianoRollDisplayMode.singleOctave
        : PianoRollDisplayMode.fullRange;
    _refreshMatching();
    notifyListeners();
  }

  void _refreshMatching() {
    final match = _pitchMatcher.match(
      currentTime: currentTime,
      referenceEvents: referenceEvents,
      livePitches: livePitches,
      octaveOnly: pianoRollDisplayMode == PianoRollDisplayMode.singleOctave,
    );
    matchingReferenceIndices = match.matchingIndices;
  }

  Future<void> seekTo(double seconds) async {
    await _youtubeService?.seekTo(seconds);
  }

  void _onMicrophoneFrame(MicrophoneFrame frame) {
    final pitch = frame.pitch;
    if (pitch != null) {
      final isNewTimestamp =
          livePitches.isEmpty ||
          (pitch.timeSeconds - livePitches.last.timeSeconds).abs() > 0.012;
      if (isNewTimestamp) {
        final nextPitches = [...livePitches, pitch];
        livePitches = nextPitches.length > 120
            ? nextPitches.sublist(nextPitches.length - 120)
            : nextPitches;
      }
    }

    // Keep a short rolling waveform history so the waveform remains visible
    // between microphone callbacks instead of being replaced by one tiny PCM
    // chunk on every update.
    final nextWaveform = [...liveWaveform, ...frame.waveform];
    final waveformCutoff = currentTime - 2.5;
    liveWaveform = nextWaveform
        .where((sample) => sample.timeSeconds >= waveformCutoff)
        .toList(growable: false);
    final match = _pitchMatcher.match(
      currentTime: currentTime,
      referenceEvents: referenceEvents,
      livePitches: livePitches,
      octaveOnly: pianoRollDisplayMode == PianoRollDisplayMode.singleOctave,
    );
    matchingReferenceIndices = match.matchingIndices;
    _scheduleTimelineNotify();
  }

  void _scheduleTimelineNotify() {
    if (_timelineNotifyTimer != null) return;
    _timelineNotifyTimer = Timer(const Duration(milliseconds: 33), () {
      _timelineNotifyTimer = null;
      if (hasListeners) notifyListeners();
    });
  }

  @override
  void dispose() {
    _timelineNotifyTimer?.cancel();
    _microphoneService.dispose();
    _youtubeService?.dispose();
    videoLoadingListenable.dispose();
    super.dispose();
  }
}
