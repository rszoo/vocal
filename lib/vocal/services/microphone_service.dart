import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../domain/models.dart';
import 'pitch_detector.dart';
import 'pitch_stabilizer.dart';

class MicrophoneFrame {
  const MicrophoneFrame({required this.pitch, required this.waveform});

  final LivePitch? pitch;
  final List<WaveformSample> waveform;
}

class MicrophoneService {
  MicrophoneService({PitchDetector? detector, PitchStabilizer? stabilizer})
    : _detector = detector ?? const PitchDetector(),
      _stabilizer = stabilizer ?? PitchStabilizer();

  final AudioRecorder _recorder = AudioRecorder();
  final PitchDetector _detector;
  final PitchStabilizer _stabilizer;
  StreamSubscription<Uint8List>? _subscription;

  double _videoAnchorSeconds = 0;
  double _audioElapsedSeconds = 0;
  bool _hasVideoAnchor = false;

  static const int sampleRate = 44100;
  static const int channelCount = 1;
  static const int waveformPointsPerFrame = 48;

  void syncToVideoTime(double seconds, {bool force = false}) {
    if (!_hasVideoAnchor) {
      _videoAnchorSeconds = seconds;
      _audioElapsedSeconds = 0;
      _hasVideoAnchor = true;
      return;
    }

    final estimated = _videoAnchorSeconds + _audioElapsedSeconds;
    final drift = seconds - estimated;

    // Do not constantly reset the microphone clock on normal 100 ms YouTube
    // position updates. Only re-anchor after a real seek/pause/resume jump.
    if (force || drift.abs() > 0.45) {
      _videoAnchorSeconds = seconds - _audioElapsedSeconds;
    }
  }

  Future<bool> start({double initialVideoTime = 0}) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return false;

    await stop();
    _stabilizer.reset();
    _videoAnchorSeconds = initialVideoTime;
    _audioElapsedSeconds = 0;
    _hasVideoAnchor = true;

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: channelCount,
      ),
    );

    _subscription = stream.listen((bytes) {
      final frame = _createFrame(bytes);
      _audioElapsedSeconds += bytes.length / 2 / sampleRate;
      onFrame?.call(frame);
    });
    return true;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    _audioElapsedSeconds = 0;
    _hasVideoAnchor = false;
    _stabilizer.reset();
  }

  void Function(MicrophoneFrame frame)? onFrame;

  MicrophoneFrame _createFrame(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    final frameDuration = sampleCount / sampleRate;
    final frameStart = _videoAnchorSeconds + _audioElapsedSeconds;
    final frameCenter = frameStart + frameDuration / 2;

    final rawFrequency = _detector.detect(bytes, sampleRate);
    final frequency = _stabilizer.process(rawFrequency);
    final waveform = _createWaveform(bytes, frameStart, frameDuration);
    final pitch = frequency == null
        ? null
        : LivePitch(
            timeSeconds: frameCenter,
            frequencyHz: frequency,
            confidence: 1.0,
          );

    return MicrophoneFrame(pitch: pitch, waveform: waveform);
  }

  List<WaveformSample> _createWaveform(
    Uint8List bytes,
    double frameStart,
    double frameDuration,
  ) {
    final sampleCount = bytes.length ~/ 2;
    if (sampleCount == 0) return const [];

    final view = ByteData.sublistView(bytes);
    final points = mathMin(sampleCount, waveformPointsPerFrame);
    final samplesPerPoint = sampleCount / points;
    final result = <WaveformSample>[];

    for (var point = 0; point < points; point++) {
      final start = (point * samplesPerPoint).floor();
      final end = ((point + 1) * samplesPerPoint).ceil();
      var peak = 0.0;

      for (var i = start; i < end && i < sampleCount; i++) {
        final value = view.getInt16(i * 2, Endian.little).abs() / 32768.0;
        if (value > peak) peak = value;
      }

      final time =
          frameStart + ((point + 0.5) / points).clamp(0.0, 1.0) * frameDuration;
      result.add(WaveformSample(timeSeconds: time, amplitude: peak));
    }
    return result;
  }

  int mathMin(int a, int b) => a < b ? a : b;

  Future<void> dispose() async {
    await stop();
    _recorder.dispose();
  }
}
