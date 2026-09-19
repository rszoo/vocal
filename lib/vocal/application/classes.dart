// ./lib/vocal/application/classes.dart

import 'dart:math' as math;
import 'dart:typed_data';

import '../../shared/application/classes.dart';
import 'yin_v2.dart';

/// モノフォニック・ピッチ検出
class PitchDetection {
  PitchDetection({
    required int sampleRate,
    required int frameSize,
    required int minF0,
    required int maxF0,
    required double minConfidence,
  }) : minRmsDb = -65.0,
       noiseMarginDb = 8.0,
       initialNoiseFloorDb = -70.0,
       noiseFloorAlpha = 0.05,
       attackFrames = 1,
       releaseFrames = 3,
       _detection = YinV2(
         sampleRate: sampleRate,
         frameSize: frameSize,
         minF0: minF0,
         maxF0: maxF0,
         minConfidence: minConfidence,
       );

  /// 最低限必要な絶対音量（dBFS）
  final double minRmsDb;

  /// 推定ノイズフロアに加算するS/Nマージン
  final double noiseMarginDb;

  /// ノイズフロアの初期値（dBFS）
  final double initialNoiseFloorDb;

  /// ノイズフロアの追従係数
  /// 上昇時はこの値の1/10を使う
  final double noiseFloorAlpha;

  /// 音声状態に入るまでに必要な連続候補フレーム数
  final int attackFrames;

  /// 音声状態を解除するまでに必要な連続非候補フレーム数
  final int releaseFrames;

  final YinV2 _detection;

  /// 推定ノイズフロア（dBFS）
  double get noiseFloorDb => _noiseFloorDb ?? initialNoiseFloorDb;
  double? _noiseFloorDb;
  int _attackCount = 0;
  int _releaseCount = 0;
  bool _isVoice = false;

  /// 現在のRMSゲート閾値
  /// dBFSの上限を0 dBFSに制限する
  double get energyThresholdDb =>
      math.max(minRmsDb, noiseFloorDb + noiseMarginDb).clamp(-120.0, 0.0);

  /// attack/releaseを反映したvoice状態
  /// release中はtrueでも、そのフレームのピッチが無効ならestimate()はnullを返す
  bool get isVoice => _isVoice;

  /// 1フレームから周波数(Hz)を推定する
  ///
  /// YINの差分関数は一定のDCオフセットに不変なので、YINには入力を直接渡す
  /// RMSだけ平均値を引いて計算し、フレームごとの中間Float32List生成を避ける
  double? estimate(final Float32List input) {
    assert(input.length == _detection.frameSize);

    final rmsDb = AudUtils.measureAcAmpInDb(input);
    // if (rmsDb == null) {
    //   // NaN/Infinityを含むフレーム
    //   // ノイズフロアは汚染せず、releaseだけ進める
    //   _updateHysteresis(false);
    //   return null;
    // }

    final hasEnoughEnergy = rmsDb >= energyThresholdDb;
    final pitch = hasEnoughEnergy ? _detection.detect(input) : null;
    final candidate = pitch != null;

    // voice区間中の無声音・短い検出抜けをノイズとして学習しない
    if (!candidate && !_isVoice) {
      _updateNoiseFloor(rmsDb);
    }

    _updateHysteresis(candidate);
    return _isVoice ? pitch : null;
  }

  void _updateNoiseFloor(final double rmsDb) {
    if (!rmsDb.isFinite) return;

    final previous = noiseFloorDb;
    final alpha = rmsDb < previous ? noiseFloorAlpha : noiseFloorAlpha * 0.1;
    _noiseFloorDb = (previous + alpha * (rmsDb - previous))
        .clamp(-120.0, 0.0)
        .toDouble();
  }

  void _updateHysteresis(final bool candidate) {
    if (candidate) {
      _releaseCount = 0;
      if (_isVoice) return;

      _attackCount++;
      if (_attackCount >= attackFrames) {
        _isVoice = true;
        _attackCount = 0;
      }
      return;
    }

    _attackCount = 0;
    if (!_isVoice) {
      _releaseCount = 0;
      return;
    }

    _releaseCount++;
    if (_releaseCount >= releaseFrames) {
      _isVoice = false;
      _releaseCount = 0;
    }
  }

  void reset() {
    _noiseFloorDb = null;
    _attackCount = 0;
    _releaseCount = 0;
    _isVoice = false;
  }
}
