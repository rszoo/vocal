import 'dart:math' as math;

import '../domain/models.dart';
import '../domain/models/timeline_frame.dart';

class TimelineCalculator {
  const TimelineCalculator({
    this.pianoWidth = 64,
    this.secondsPerScreen = 12,
    this.playheadRatio = 0.2,
  });

  final double pianoWidth;
  final double secondsPerScreen;
  final double playheadRatio;

  TimelineFrame calculate({
    required double currentTime,
    required double duration,
    required double totalWidth,
    required List<PitchEvent> referenceEvents,
    required List<LivePitch> livePitches,
    required List<WaveformSample> liveWaveform,
    required Set<int> matchingReferenceIndices,
    required PianoRollDisplayMode displayMode,
  }) {
    final contentWidth = math.max(1.0, totalWidth - pianoWidth).toDouble();
    // Keep a fixed scrolling window instead of fitting the entire video into
    // one screen. This keeps note and waveform detail readable throughout
    // playback, including long videos.
    final windowSeconds = secondsPerScreen;
    final pixelsPerSecond = contentWidth / windowSeconds;
    final playheadX = pianoWidth + contentWidth * playheadRatio;
    final maxStart = duration > 0
        ? math.max(0.0, duration - windowSeconds).toDouble()
        : double.infinity;
    final visibleStart = math
        .min(
          maxStart,
          math.max(0.0, currentTime - windowSeconds * playheadRatio),
        )
        .toDouble();
    final visibleEnd = duration > 0
        ? math.min(duration, visibleStart + windowSeconds).toDouble()
        : visibleStart + windowSeconds;

    final referenceWaveform = _createReferenceWaveform(
      referenceEvents,
      visibleStart,
      visibleEnd,
      pixelsPerSecond,
    );

    return TimelineFrame(
      currentTime: currentTime,
      duration: duration,
      playheadX: playheadX,
      referenceEvents: referenceEvents,
      livePitches: livePitches,
      liveWaveform: liveWaveform,
      referenceWaveform: referenceWaveform,
      matchingReferenceIndices: matchingReferenceIndices,
      visibleStart: visibleStart,
      visibleEnd: visibleEnd,
      pianoWidth: pianoWidth,
      contentWidth: contentWidth,
      displayMode: displayMode,
    );
  }

  List<WaveformSample> _createReferenceWaveform(
    List<PitchEvent> events,
    double start,
    double end,
    double pixelsPerSecond,
  ) {
    final pointCount = math.max(240, (end - start) * pixelsPerSecond).round();
    if (pointCount <= 0 || end <= start) return const [];

    final result = <WaveformSample>[];
    final step = (end - start) / pointCount;
    var eventIndex = 0;

    for (var i = 0; i < pointCount; i++) {
      final time = start + (i + 0.5) * step;
      while (eventIndex < events.length &&
          events[eventIndex].endSeconds < time) {
        eventIndex++;
      }

      PitchEvent? event;
      if (eventIndex < events.length) {
        final candidate = events[eventIndex];
        if (candidate.startSeconds <= time && time <= candidate.endSeconds) {
          event = candidate;
        }
      }

      // The JSON contains pitch events, not PCM. This is intentionally a
      // visual reference envelope: every active note produces a clearly
      // visible amplitude rather than disappearing into the baseline.
      final amplitude = event == null
          ? 0.0
          : (0.22 +
                    0.18 *
                        ((12 * (math.log(event.f0Hz / 440.0) / math.ln2))
                                .abs() %
                            12) /
                        12)
                .clamp(0.0, 0.42)
                .toDouble();
      result.add(WaveformSample(timeSeconds: time, amplitude: amplitude));
    }
    return result;
  }

  double xToTime(TimelineFrame frame, double x) {
    final pixelsPerSecond =
        frame.contentWidth / (frame.visibleEnd - frame.visibleStart);
    return frame.visibleStart + (x - frame.pianoWidth) / pixelsPerSecond;
  }

  double timeToX(TimelineFrame frame, double timeSeconds) {
    final pixelsPerSecond =
        frame.contentWidth / (frame.visibleEnd - frame.visibleStart);
    return frame.pianoWidth +
        (timeSeconds - frame.visibleStart) * pixelsPerSecond;
  }

  double frequencyToY(TimelineFrame frame, double frequencyHz, double height) {
    final normalized = _frequencyToNormalized(frequencyHz, frame.displayMode);
    return height - normalized * height;
  }

  double _frequencyToNormalized(
    double frequencyHz,
    PianoRollDisplayMode displayMode,
  ) {
    const minMidi = 36.0; // C2
    const maxMidi = 96.0; // C7
    final midi = 69.0 + 12.0 * (math.log(frequencyHz / 440.0) / math.ln2);

    if (displayMode == PianoRollDisplayMode.singleOctave) {
      var pitchClass = midi % 12.0;
      if (pitchClass < 0) pitchClass += 12.0;
      return (pitchClass / 12.0).clamp(0.0, 0.999999).toDouble();
    }

    return ((midi - minMidi) / (maxMidi - minMidi)).clamp(0.0, 1.0).toDouble();
  }
}
