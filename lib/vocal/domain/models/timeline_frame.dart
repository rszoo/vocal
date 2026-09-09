import 'package:flutter/foundation.dart';

import '../models.dart';

@immutable
class TimelineFrame {
  const TimelineFrame({
    required this.currentTime,
    required this.duration,
    required this.playheadX,
    required this.referenceEvents,
    required this.livePitches,
    required this.liveWaveform,
    required this.referenceWaveform,
    required this.matchingReferenceIndices,
    required this.visibleStart,
    required this.visibleEnd,
    required this.pianoWidth,
    required this.contentWidth,
    required this.displayMode,
  });

  final double currentTime;
  final double duration;
  final double playheadX;
  final List<PitchEvent> referenceEvents;
  final List<LivePitch> livePitches;
  final List<WaveformSample> liveWaveform;
  final List<WaveformSample> referenceWaveform;
  final Set<int> matchingReferenceIndices;
  final double visibleStart;
  final double visibleEnd;
  final double pianoWidth;
  final double contentWidth;
  final PianoRollDisplayMode displayMode;
}
