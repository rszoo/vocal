// ./lib/vocal/application/controllers.dart

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../shared/domain/models.dart';
import '../infrastructure/asset_loader.dart';

final class PracticeController extends ChangeNotifier {
  PracticeController({AssetLoader? assetLoader})
    : _assetLoader = assetLoader ?? const AssetLoader();

  List<String> _videoIds = const [];
  List<String> get videoIds => _videoIds;
  bool get hasVideoIds => _videoIds.isNotEmpty;

  final AssetLoader _assetLoader;

  YoutubePlayerController? _playerController;
  YoutubePlayerController? get playerController => _playerController;
  StreamSubscription<YoutubeVideoState>? _videoStateSubscription;

  Future<void> loadAssets() async {
    try {
      final ids = await _assetLoader.loadVideoIds();
      _videoIds = List.unmodifiable(ids);
    } catch (e) {
      _videoIds = const [];
      developer.log('Error: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<List<PitchSegment>> loadPitchEvents(String videoId) =>
      _assetLoader.loadPitchEvents(videoId);

  Future<void> loadVideo(
    String videoId, {
    void Function(Duration)? onPosition,
  }) async {
    if (_playerController == null) {
      await _initVideo(onPosition: onPosition);
    }
    await _playerController!.cueVideoById(videoId: videoId);
  }

  Future<void> _initVideo({void Function(Duration)? onPosition}) async {
    final controller = YoutubePlayerController(params: playerParams);

    _videoStateSubscription = controller.videoStateStream.listen(
      (state) => onPosition?.call(state.position),
      onError: (e) {
        developer.log('Error: ', error: e);
      },
    );

    _playerController = controller;
    notifyListeners();
  }

  @override
  void dispose() {
    _videoStateSubscription?.cancel();
    _playerController?.close();
    super.dispose();
  }

  static YoutubePlayerParams get playerParams => const YoutubePlayerParams(
    enableCaption: false,
    // showControls: true,
    interfaceLanguage: 'ja',
    showVideoAnnotations: false,
    strictRelatedVideos: true,
    videoStateUpdateInterval: 100,
  );
}
