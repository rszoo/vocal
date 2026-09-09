import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../domain/models.dart';

class PitchDetector {
  PitchDetector({
    this.sampleRate = 44100,
    this.bufferSize = 4096,
    this.minFrequency = 70.0,
    this.maxFrequency = 1000.0,
    this.silenceRms = 450.0,
    this.yinThreshold = 0.15,
  });

  final AudioRecorder _recorder = AudioRecorder();

  final int sampleRate;
  final int bufferSize;

  final double minFrequency;
  final double maxFrequency;

  final double silenceRms;
  final double yinThreshold;

  StreamSubscription<Uint8List>? _subscription;

  final List<int> _audioBuffer = [];

  final List<double> _frequencyHistory = [];

  final StreamController<PitchResult?> _resultController =
      StreamController<PitchResult?>.broadcast();

  bool _isRunning = false;

  Stream<PitchResult?> get results => _resultController.stream;

  bool get isRunning => _isRunning;

  // ============================================================
  // Start
  // ============================================================

  Future<bool> start() async {
    if (_isRunning) {
      return true;
    }

    final permission = await _recorder.hasPermission();

    if (!permission) {
      return false;
    }

    try {
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );

      _audioBuffer.clear();
      _frequencyHistory.clear();

      _subscription = stream.listen(
        _onAudioData,
        onError: (error) {
          // 必要ならログを追加
        },
      );

      _isRunning = true;

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // Stop
  // ============================================================

  Future<void> stop() async {
    await _subscription?.cancel();

    _subscription = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    _audioBuffer.clear();
    _frequencyHistory.clear();

    _isRunning = false;

    _resultController.add(null);
  }

  // ============================================================
  // Dispose
  // ============================================================

  Future<void> dispose() async {
    await stop();

    await _resultController.close();

    _recorder.dispose();
  }

  // ============================================================
  // PCM受信
  // ============================================================

  void _onAudioData(Uint8List bytes) {
    if (bytes.length < 2) {
      return;
    }

    final byteData = ByteData.sublistView(bytes);

    // PCM16をint16へ変換
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      _audioBuffer.add(byteData.getInt16(i, Endian.little));
    }

    // 解析に必要な量が溜まるまで待つ
    if (_audioBuffer.length < bufferSize) {
      return;
    }

    final samples = Int16List.fromList(
      _audioBuffer.sublist(_audioBuffer.length - bufferSize),
    );

    // バッファが大きくなりすぎないようにする
    if (_audioBuffer.length > bufferSize * 2) {
      _audioBuffer.removeRange(0, _audioBuffer.length - bufferSize);
    }

    _analyze(samples);
  }

  // ============================================================
  // 音声解析
  // ============================================================

  void _analyze(Int16List samples) {
    final rms = _calculateRms(samples);

    // --------------------------
    // 無音
    // --------------------------

    if (rms < silenceRms) {
      _frequencyHistory.clear();

      _resultController.add(null);

      return;
    }

    // --------------------------
    // YIN
    // --------------------------

    final frequency = _yin(samples);

    if (frequency == null) {
      return;
    }

    // --------------------------
    // 平滑化
    // --------------------------

    final smoothed = _smoothFrequency(frequency);

    if (smoothed == null) {
      return;
    }

    // --------------------------
    // ドレミ変換
    // --------------------------

    final result = _frequencyToNote(smoothed, rms);

    _resultController.add(result);
  }

  // ============================================================
  // RMS
  // ============================================================

  double _calculateRms(Int16List samples) {
    double sum = 0;

    for (final sample in samples) {
      final value = sample.toDouble();

      sum += value * value;
    }

    return sqrt(sum / samples.length);
  }

  // ============================================================
  // YIN
  // ============================================================

  double? _yin(Int16List samples) {
    final length = samples.length;

    final data = List<double>.filled(length, 0);

    // DC offset
    double mean = 0;

    for (int i = 0; i < length; i++) {
      mean += samples[i];
    }

    mean /= length;

    for (int i = 0; i < length; i++) {
      data[i] = samples[i] - mean;
    }

    final minTau = (sampleRate / maxFrequency).floor();

    final maxTau = min((sampleRate / minFrequency).ceil(), length - 1);

    final difference = List<double>.filled(maxTau + 1, 0);

    // ----------------------------------------------------------
    // Difference function
    // ----------------------------------------------------------

    for (int tau = minTau; tau <= maxTau; tau++) {
      double sum = 0;

      final limit = length - tau;

      for (int i = 0; i < limit; i++) {
        final delta = data[i] - data[i + tau];

        sum += delta * delta;
      }

      difference[tau] = sum;
    }

    // ----------------------------------------------------------
    // Cumulative mean normalized difference
    // ----------------------------------------------------------

    final cmnd = List<double>.filled(maxTau + 1, 1.0);

    double runningSum = 0;

    for (int tau = 1; tau <= maxTau; tau++) {
      runningSum += difference[tau];

      if (runningSum == 0) {
        cmnd[tau] = 1.0;
      } else {
        cmnd[tau] = difference[tau] * tau / runningSum;
      }
    }

    // ----------------------------------------------------------
    // Threshold
    // ----------------------------------------------------------

    int? tauEstimate;

    for (int tau = minTau; tau <= maxTau; tau++) {
      if (cmnd[tau] < yinThreshold) {
        while (tau + 1 <= maxTau && cmnd[tau + 1] < cmnd[tau]) {
          tau++;
        }

        tauEstimate = tau;
        break;
      }
    }

    // thresholdに入らなかった場合
    if (tauEstimate == null) {
      double minimum = double.infinity;

      int bestTau = minTau;

      for (int tau = minTau; tau <= maxTau; tau++) {
        if (cmnd[tau] < minimum) {
          minimum = cmnd[tau];
          bestTau = tau;
        }
      }

      // 信頼度が低い
      if (minimum > 0.35) {
        return null;
      }

      tauEstimate = bestTau;
    }

    final tau = tauEstimate;

    // ----------------------------------------------------------
    // Parabolic interpolation
    // ----------------------------------------------------------

    double betterTau = tau.toDouble();

    if (tau > minTau && tau < maxTau) {
      final s0 = cmnd[tau - 1];

      final s1 = cmnd[tau];

      final s2 = cmnd[tau + 1];

      final denominator = s0 - 2 * s1 + s2;

      if (denominator.abs() > 1e-12) {
        betterTau += 0.5 * (s0 - s2) / denominator;
      }
    }

    if (betterTau <= 0) {
      return null;
    }

    final frequency = sampleRate / betterTau;

    if (frequency < minFrequency || frequency > maxFrequency) {
      return null;
    }

    return frequency;
  }

  // ============================================================
  // 周波数平滑化
  // ============================================================

  double? _smoothFrequency(double frequency) {
    if (_frequencyHistory.isNotEmpty) {
      final previous = _frequencyHistory.last;

      final ratio = frequency / previous;

      // 1オクターブ以上の急激な変化は除外
      if (ratio > 2.0 || ratio < 0.5) {
        return null;
      }
    }

    _frequencyHistory.add(frequency);

    const historySize = 5;

    if (_frequencyHistory.length > historySize) {
      _frequencyHistory.removeAt(0);
    }

    // 対数周波数で平均
    double sumLog = 0;

    for (final value in _frequencyHistory) {
      sumLog += log(value);
    }

    return exp(sumLog / _frequencyHistory.length);
  }

  // ============================================================
  // Hz → ドレミ
  // ============================================================

  PitchResult _frequencyToNote(double frequency, double rms) {
    // A4 = 440Hz
    final midiFloat = 69 + 12 * (log(frequency / 440.0) / ln2);

    final midi = midiFloat.round();

    final cents = (midiFloat - midi) * 100;

    const notes = [
      'ド',
      'ド♯',
      'レ',
      'レ♯',
      'ミ',
      'ファ',
      'ファ♯',
      'ソ',
      'ソ♯',
      'ラ',
      'ラ♯',
      'シ',
    ];

    final noteIndex = ((midi % 12) + 12) % 12;

    return PitchResult(
      frequency: frequency,
      note: notes[noteIndex],
      midiNote: midi,
      cents: cents,
      rms: rms,
    );
  }
}
