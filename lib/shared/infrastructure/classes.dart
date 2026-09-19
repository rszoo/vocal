// ./lib/shared/infrastructure/classes.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:typed_data/typed_data.dart';

/// PCM 16-bit の最大絶対値（0x8000 = 32768）
const pcm16MaxAbs = 0x8000;

/// PCM 16-bit の 1 サンプルあたりのバイト数
const _bytesPerSample = 2;

abstract class Mic {
  Mic({AudioRecorder? recorder, RecordConfig? config})
    : recorder = recorder ?? AudioRecorder(),
      config =
          config ??
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
            // autoGain: true,
            echoCancel: true,
            // noiseSuppress: true,
            streamBufferSize: 4096,
          );

  @protected
  final AudioRecorder recorder;

  RecordConfig config;

  /// PCM のサンプルレート
  int get sampleRate => config.sampleRate;

  /// 1 フレームのバイト数
  int get bufferSize => config.streamBufferSize ?? 2048;

  /// 1 フレームのサンプル数
  int get samplesPerFrame => bufferSize ~/ _bytesPerSample;

  Future<Stream<Float32List>> startStream({RecordConfig? config}) async {
    if (config != null) this.config = config;
    final stream = await recorder.startStream(this.config);
    return stream.transform(
      _Pcm16Transformer(frameSize: bufferSize, hopSize: bufferSize ~/ 2),
    );
  }

  Future<void> stopStream() => recorder.stop();

  Future<bool> hasPermission() => recorder.hasPermission();

  Future<void> dispose() => recorder.dispose();
}

/// PCM16 (Little Endian, Mono) のバイトストリームを正規化
/// Float32 [-1.0, 1.0] のフレームに変換
class _Pcm16Transformer extends StreamTransformerBase<Uint8List, Float32List> {
  _Pcm16Transformer({required this.frameSize, int? hopSize})
    : assert(frameSize.isEven, 'frameSize must be even'),
      assert((hopSize ?? frameSize).isEven),
      hopSize = hopSize ?? frameSize;

  /// フレームあたりのバイト数
  final int frameSize;
  int get _samplesPerFrame => frameSize ~/ _bytesPerSample;

  /// 次のフレームに進むステップ（ホップ）のバイト数
  final int hopSize;

  @override
  Stream<Float32List> bind(Stream<Uint8List> stream) async* {
    final buffer = Uint8Queue();
    await for (final chunk in stream) {
      buffer.addAll(chunk);
      while (buffer.length >= frameSize) {
        yield _decode(buffer);
        buffer.removeRange(0, hopSize);
      }
    }
  }

  Float32List _decode(Uint8Queue buffer) {
    final n = _samplesPerFrame;
    final result = Float32List(n);
    for (var i = 0; i < n; i++) {
      final offset = i * _bytesPerSample;
      // PCM16 little-endian の 16-bit 符号付き整数を復元する
      final unsignedSample = buffer[offset] | (buffer[offset + 1] << 8);
      final signedSample = unsignedSample >= pcm16MaxAbs
          ? unsignedSample - 0x10000
          : unsignedSample;

      result[i] = signedSample / pcm16MaxAbs;
    }

    return result;
  }
}
