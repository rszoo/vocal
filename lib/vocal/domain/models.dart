// ./lib/vocal/domain/models.dart

import '../../feature/monophony.dart';

enum PianoRangeMode {
  real('実音'),
  tone('楽音');

  final String label;
  const PianoRangeMode(this.label);
}

enum MicStatus {
  off('OFF'),
  listen('LISTEN'),
  match('MATCH'),
  permission('PERMISSION');

  final String label;
  const MicStatus(this.label);
}

/// 1 フレーム分のマイク推定結果
extension type LivePitchSample(
  ({
    double time,
    double frequency,
    // double confidence,
    List<double> waveform,
    double? referenceFrequency,
    double? cents,
    bool match,
  })
  _
) {
  LivePitchSample.from({
    required double time,
    required double frequency,
    required List<double> waveform,
    double? referenceFrequency,
    double? cents,
    required bool match,
  }) : _ = (
         time: time,
         frequency: frequency,
         waveform: waveform,
         referenceFrequency: referenceFrequency,
         cents: cents,
         match: match,
       );

  double get time => _.time;
  double get frequency => _.frequency;
  List<double> get waveform => _.waveform;
  double? get referenceFrequency => _.referenceFrequency;
  double? get cents => _.cents;
  bool get match => _.match;

  Midi get midi => convertF0ToMidi(frequency);
}
