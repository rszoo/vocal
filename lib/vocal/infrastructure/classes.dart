// ./lib/vocal/infrastructure/classes.dart

import 'dart:async';
import 'dart:developer' as developer;

import '../../shared/application/classes.dart';
import '../../shared/infrastructure/classes.dart';
import '../application/classes.dart';

class MicImpl extends Mic {
  MicImpl({PitchDetection? detector}) : _started = false, super() {
    _detector =
        detector ??
        PitchDetection(
          sampleRate: super.sampleRate,
          frameSize: super.samplesPerFrame,
          minF0: AudUtils.minF0,
          maxF0: AudUtils.maxF0,
          minConfidence: 0.12,
        );
  }

  bool _started;
  bool get isStarted => _started;

  StreamController<double?>? _controller;
  StreamSubscription<double?>? _subscription;

  late final PitchDetection _detector;

  Future<Stream<double?>> start() async {
    if (_started) throw StateError('started: $_started');

    final permit = await super.hasPermission();
    if (!permit) throw StateError('permission: $permit');

    final controller = StreamController<double?>();
    try {
      _detector.reset();
      final stream = await super.startStream();

      _controller = controller;
      _subscription = stream
          // .where(_detector.rms)
          .map(_detector.estimate)
          .listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              if (!controller.isClosed) controller.close();
            },
          );
      _started = true;
    } catch (error, stackTrace) {
      developer.log('Mic start error: $error\n$stackTrace');
      _subscription = null;
      _controller = null;
      _started = false;
      rethrow;
    }

    return controller.stream;
  }

  Future<void> stop() async {
    if (!_started) return;

    _detector.reset();
    try {
      await _subscription?.cancel();
      final controller = _controller;
      if (controller != null && !controller.isClosed) await controller.close();
      await super.stopStream();
    } catch (error, stackTrace) {
      developer.log('Mic stop error: $error\n$stackTrace');
    } finally {
      _subscription = null;
      _controller = null;
      _started = false;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await super.dispose();
  }
}
