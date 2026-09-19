// ./lib/voice/infrastructure/classes.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import '../../shared/application/classes.dart';
import '../../shared/infrastructure/classes.dart';
import '../application/classes.dart';
import '../domain/models.dart';

class MicImpl extends Mic {
  MicImpl({PitchDetection? detector}) : _started = false, super() {
    _detector =
        detector ??
        PitchDetection(
          sampleRate: super.sampleRate,
          frameSize: samplesPerFrame,
          minF0: AudUtils.minF0,
          maxF0: AudUtils.maxF0,
          minConfidence: 0.72,
        );
  }

  bool _started;
  bool get isStarted => _started;

  final _controller = StreamController<VoiceData?>.broadcast();
  Stream<VoiceData?> get stream => _controller.stream;

  StreamSubscription<Float32List>? _subscription;

  late final PitchDetection _detector;

  Future<bool> start() async {
    if (_started) throw StateError('started: $_started');

    final permit = await super.hasPermission();
    if (!permit) throw StateError('permission: $permit');

    try {
      final stream = await super.startStream();

      _subscription = stream.listen(
        _onAudioData,
        onError: (error) {
          developer.log('Error: $error');
        },
      );
      _started = true;
    } catch (error, stackTrace) {
      developer.log('Mic start error: $error\n$stackTrace');
      _started = false;
    }

    return _started;
  }

  Future<void> stop() async {
    if (!_started) return;

    try {
      await _subscription?.cancel();
      _controller.add(null);
      await super.stopStream();
    } catch (error, stackTrace) {
      developer.log('Mic stop error: $error\n$stackTrace');
    } finally {
      _subscription = null;
      _started = false;
    }
  }

  void _onAudioData(Float32List samples) {
    if (samples.length < 2) {
      return;
    }

    final result = _detector.estimate(samples);
    _controller.add((result.isVoice && result.pitch > 0) ? result : null);
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
    await super.dispose();
  }
}
