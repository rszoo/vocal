// ./lib/vocal/presentation/pages.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../shared/application/classes.dart';
import '../../shared/domain/models.dart';
import '../../shared/infrastructure/settings.dart';
import '../application/controllers.dart';
import '../domain/models.dart';
import '../infrastructure/classes.dart';
import 'classes.dart';
import 'widgets.dart';
import 'widgets/piano_roll.dart';
import 'widgets/waveform.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  static const _timelineViewDuration = 20.0;
  static const _playheadRatio = .20;

  late final PracticeController _controller;

  final _microphone = MicImpl();

  final _pitches = ValueNotifier<List<PitchSegment>>(const []);
  final _liveSamples = ValueNotifier<List<LivePitchSample>>(const []);
  final _currentTime = ValueNotifier<double>(0);
  final _videoDuration = ValueNotifier<double>(0);
  final _lastCents = ValueNotifier<double>(double.nan);
  final _micOn = ValueNotifier<bool>(false);
  final _micStatus = ValueNotifier<MicStatus>(MicStatus.off);

  StreamSubscription<double?>? _micSubscription;
  Timer? _durationTimer;
  bool _isSeeking = false;

  double get _timelineStartTime =>
      math.max(0, _currentTime.value - _timelineViewDuration * _playheadRatio);

  @override
  void initState() {
    super.initState();

    _controller = PracticeController();

    _init();
  }

  Future<void> _init() async {
    try {
      // debugPrint('Prev _controller.loadAssets');
      await _controller.loadAssets();
      // debugPrint('Next _controller.loadAssets');

      if (!mounted) return;

      final ids = _controller.videoIds;
      if (ids.isNotEmpty) {
        final settings = context.read<Settings>();
        // 保存されている videoId が有効かチェックし、なければ先頭を使う
        String targetId = (ids.contains(settings.videoId))
            ? settings.videoId
            : ids.first;
        await _selectVideo(targetId);
        _startPlaybackSync();
      }
    } catch (e) {
      developer.log('Error: $e');
    }
  }

  Future<void> _selectVideo(String id) async {
    _durationTimer?.cancel();

    if (mounted) {
      context.read<Settings>().setVideoId(id);
    }

    _pitches.value = const [];
    _liveSamples.value = const [];
    _currentTime.value = 0;
    _videoDuration.value = 0;
    _lastCents.value = double.nan;
    _micStatus.value = _micOn.value ? MicStatus.listen : MicStatus.off;

    try {
      final pitches = await _controller.loadPitchEvents(id);
      await _controller.loadVideo(id, onPosition: _onVideoPositionChanged);

      _pitches.value = pitches;
      _videoDuration.value = pitches.maxEndTime;
    } catch (e) {
      developer.log('Error: ', error: e);
      if (!mounted) return;
    }
  }

  void _startPlaybackSync() {
    _durationTimer?.cancel();

    _durationTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final duration = await _controller.playerController?.duration ?? 0;

        if (duration > 0) {
          _videoDuration.value = duration;
          timer.cancel();
        }
      } catch (_) {
        // 次回リトライ
      }
    });
  }

  void _onVideoPositionChanged(Duration position) {
    if (!mounted || _isSeeking) return;

    final nextTime = position.inMilliseconds / 1000.0;
    final safeDuration = _videoDuration.value > 0 ? _videoDuration.value : null;

    // YouTube 側の 100ms 更新ストリームを、そのまま再生位置の正とする。
    // 独自 Timer + currentTime getter の二重ポーリングをやめることで、
    // カスタム再生ヘッダー / ピアノロール / 波形を同じ時刻へ揃える。
    _currentTime.value = safeDuration == null
        ? math.max(0, nextTime)
        : nextTime.clamp(0.0, safeDuration).toDouble();
  }

  Future<void> _toggleMic() async {
    if (_micOn.value) {
      await _stopMic();
    } else {
      await _startMic();
    }
  }

  Future<void> _startMic() async {
    Stream<double?> stream;
    try {
      stream = await _microphone.start();
    } catch (error, stackTrace) {
      developer.log('Mic start error: $error\n$stackTrace');
      if (!mounted) return;

      _micStatus.value = MicStatus.permission;
      _micOn.value = false;
      return;
    }

    await _micSubscription?.cancel();

    _micSubscription = stream.listen((freq) {
      if (!mounted || freq == null) return;

      final time = _currentTime.value;

      // 表示中の1オクターブに関係なく、現在時刻に存在する
      // すべての参照音の中から最も近い音を採用する。
      final reference = _nearestReference(time, freq);

      final cents = reference == null
          ? null
          : AudUtils.centsBetween(freq, reference.freq);

      final match =
          reference != null &&
          cents != null &&
          cents.abs() <= 50 /* && freq.confidence >= .55 */;

      final sample = LivePitchSample.from(
        time: time,
        frequency: freq,
        // confidence: freq.confidence,
        waveform: [],
        referenceFrequency: reference?.freq,
        cents: cents,
        match: match,
      );

      final next = [..._liveSamples.value, sample];
      final trimmed = next
          .where(
            (item) =>
                item.time >= time - _timelineViewDuration &&
                item.time <= time + .05,
          )
          .toList();

      _liveSamples.value = trimmed;
      _lastCents.value = cents ?? double.nan;
      _micStatus.value = match ? MicStatus.match : MicStatus.listen;
    });

    if (!mounted) return;
    _micOn.value = true;
    _micStatus.value = MicStatus.listen;
  }

  Future<void> _stopMic() async {
    await _micSubscription?.cancel();
    _micSubscription = null;
    await _microphone.stop();

    if (!mounted) return;

    _micOn.value = false;
    _micStatus.value = MicStatus.off;
  }

  void _setRangeMode(PianoRangeMode mode) {
    context.read<Settings>().setPrMode(mode);
  }

  PitchSegment? _referenceAt(double time) {
    return _pitches.value.firstWhereOrNull(
      (pitch) => time >= pitch.time && time <= pitch.endTime,
    );
  }

  PitchSegment? _nearestReference(double time, double frequency) {
    PitchSegment? nearest;
    var bestCents = double.infinity;

    for (final pitch in _pitches.value) {
      if (time < pitch.time || time > pitch.endTime) {
        continue;
      }

      final cents = AudUtils.centsBetween(frequency, pitch.freq).abs();
      if (cents < bestCents) {
        bestCents = cents;
        nearest = pitch;
      }
    }

    return nearest;
  }

  Future<void> _openVideoPicker() async {
    if (_controller.videoIds.isEmpty) return;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 現在の Settings から選択中の ID を取得
    final currentVideoId = context.read<Settings>().videoId;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      builder: (context) {
        final sheetTheme = Theme.of(context);
        final sheetScheme = sheetTheme.colorScheme;

        return PointerInterceptor(
          child: SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              itemCount: _controller.videoIds.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final id = _controller.videoIds[index];
                final isSelected = id == currentVideoId;

                return ListTile(
                  tileColor: isSelected
                      ? sheetScheme.primaryContainer
                      : sheetScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.play_circle_outline,
                    color: isSelected
                        ? sheetScheme.onPrimaryContainer
                        : sheetScheme.onSurfaceVariant,
                  ),
                  title: Text(id, style: sheetTheme.textTheme.titleSmall),
                  subtitle: Text(
                    'Pitch JSON',
                    style: sheetTheme.textTheme.bodySmall,
                  ),
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
          ),
        );
      },
    );

    if (selected != null && selected != currentVideoId) {
      await _selectVideo(selected);
      _startPlaybackSync();
    }
  }

  void _showSettings() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final settings = context.watch<Settings>();

        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('設定'),
          content: Text(
            'ピアノロール: ${settings.prMode.label}\n'
            '  ${PianoRangeMode.tone.label}時は現在の参照音域へ追従\n'
            '既定値: ${'120 BPM / 4 拍子'}\n'
            '一致判定: ${'±50 cents'}\n'
            'マイク: ${'16 kHz / mono / PCM16'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _togglePlayback() async {
    final controller = _controller.playerController;
    if (controller == null) return;

    final state = await controller.playerState;
    if (state == PlayerState.playing) {
      await controller.pauseVideo();
    } else {
      await controller.playVideo();
    }
  }

  Future<void> _seekTo(double seconds) async {
    final controller = _controller.playerController;
    if (controller == null) return;

    final target = seconds
        .clamp(0, _videoDuration.value > 0 ? _videoDuration.value : seconds)
        .toDouble();

    _isSeeking = true;
    _currentTime.value = target;

    try {
      await controller.seekTo(seconds: target, allowSeekAhead: true);
    } finally {
      // seek 後の実位置を YouTube が videoStateStream で返すまで短時間だけ
      // ローカル値を優先し、その後ストリーム同期へ戻す。
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _isSeeking = false;
      });
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _micSubscription?.cancel();
    _microphone.dispose();
    _controller.dispose();
    _pitches.dispose();
    _liveSamples.dispose();
    _currentTime.dispose();
    _videoDuration.dispose();
    _lastCents.dispose();
    _micOn.dispose();
    _micStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeaderDelegate(
              height: 68,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _buildHeader(),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPlaybackHeader(),
                        const SizedBox(height: 10),
                        _buildStatusRow(),
                        const SizedBox(height: 10),
                        _buildPianoRoll(),
                        _buildWaveform(),
                        const SizedBox(height: 14),
                        _PlayerViewIsolated(controller: _controller),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPianoRoll() {
    final settings = context.watch<Settings>();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _pitches,
        _liveSamples,
        _currentTime,
        settings,
      ]),
      builder: (context, _) {
        return AspectRatio(
          aspectRatio: 1.95,
          child: PianoRoll(
            pitches: _pitches.value,
            currentTime: _currentTime.value,
            liveSamples: _liveSamples.value,
            duration: _timelineViewDuration,
            rangeMode: settings.prMode,
            startTime: _timelineStartTime,
          ),
        );
      },
    );
  }

  Widget _buildWaveform() {
    final settings = context.watch<Settings>();
    if (!settings.waveformVisible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _currentTime,
        _pitches,
        _liveSamples,
        settings,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        return Column(
          children: [
            const SizedBox(height: 12),
            _buildWaveLegend(theme),
            const SizedBox(height: 8),
            WaveformPanel(
              currentTime: _currentTime.value,
              startTime: _timelineStartTime,
              duration: _timelineViewDuration,
              pitches: _pitches.value,
              liveSamples: _liveSamples.value,
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    final settings = context.watch<Settings>();

    return AnimatedBuilder(
      animation: Listenable.merge([_micOn, settings]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Material(
          color: scheme.surface,
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _buildVideoSelector(settings.videoId)),
                const SizedBox(width: 8),
                _PianoRangeSelector(
                  value: settings.prMode,
                  onChanged: _setRangeMode,
                ),
                HeaderIconButton(
                  tooltip: _micOn.value ? 'マイクを OFF' : 'マイクを ON',
                  selected: _micOn.value,
                  selectedColor: scheme.error,
                  onPressed: _toggleMic,
                  icon: _micOn.value
                      ? Icons.mic_rounded
                      : Icons.mic_none_rounded,
                ),
                HeaderIconButton(
                  tooltip: settings.waveformVisible ? '波形を OFF' : '波形を ON',
                  selected: settings.waveformVisible,
                  onPressed: () => settings.toggleWaveform(),
                  icon: Icons.graphic_eq_rounded,
                ),
                HeaderIconButton(
                  tooltip: '設定',
                  onPressed: _showSettings,
                  icon: Icons.settings_outlined,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoSelector(String videoId) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: .55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: _openVideoPicker,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(
                Icons.video_library_outlined,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  videoId.isEmpty ? '動画を選択' : videoId,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackHeader() {
    return AnimatedBuilder(
      animation: Listenable.merge([_currentTime, _videoDuration, _controller]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final controller = _controller.playerController;
        final max = math.max(1.0, _videoDuration.value);
        final value = _videoDuration.value > 0
            ? _currentTime.value.clamp(0.0, _videoDuration.value).toDouble()
            : 0.0;

        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: .4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '再生 / 一時停止',
                      visualDensity: VisualDensity.compact,
                      onPressed: controller == null ? null : _togglePlayback,
                      iconSize: 25,
                      icon: controller == null
                          ? const Icon(Icons.play_arrow_rounded)
                          : YoutubeValueBuilder(
                              controller: controller,
                              builder: (context, value) {
                                return Icon(
                                  value.playerState == PlayerState.playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                );
                              },
                            ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${_formatTime(_currentTime.value)} / ${_formatTime(_videoDuration.value)}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (controller != null)
                      YoutubeValueBuilder(
                        controller: controller,
                        builder: (context, value) {
                          return Text(
                            value.playerState == PlayerState.playing
                                ? 'PLAYING'
                                : 'PAUSED',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              letterSpacing: 1,
                            ),
                          );
                        },
                      ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: value,
                    min: 0,
                    max: max,
                    onChanged: _videoDuration.value > 0
                        ? (next) => _currentTime.value = next
                        : null,
                    onChangeEnd: _videoDuration.value > 0 ? _seekTo : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusRow() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pitches,
        _currentTime,
        _lastCents,
        _micOn,
        _micStatus,
      ]),
      builder: (context, _) {
        final currentReference = _referenceAt(_currentTime.value);
        final centsText = _lastCents.value.isFinite
            ? '${_lastCents.value >= 0 ? '+' : ''}${_lastCents.value.toStringAsFixed(0)}¢'
            : '—';

        return Row(
          children: [
            StatusChip(
              label: 'MIC ${_micStatus.value.label}',
              active: _micOn.value,
              match: _micStatus.value == MicStatus.match,
            ),
            const SizedBox(width: 8),
            StatusChip(
              label: currentReference == null
                  ? 'REF —'
                  : 'REF ${currentReference.freq.toStringAsFixed(1)} Hz',
              active: currentReference != null,
            ),
            const SizedBox(width: 8),
            StatusChip(
              label: 'Δ $centsText',
              active: _micOn.value && currentReference != null,
              match: _micStatus.value == MicStatus.match,
            ),
          ],
        );
      },
    );
  }

  Widget _buildWaveLegend(ThemeData theme) {
    final colors = PianoRollColors(colorScheme: theme.colorScheme);

    return Row(
      children: [
        LegendDot(color: colors.primaryNote, label: 'ピッチ'),
        const SizedBox(width: 14),
        LegendDot(color: colors.match, label: '一致'),
        const SizedBox(width: 14),
        LegendDot(color: colors.live, label: 'マイク'),
        const SizedBox(width: 14),
        LegendDot(color: colors.playhead, label: 'ヘッド'),
      ],
    );
  }

  String _formatTime(double seconds) {
    final total = seconds.isFinite ? seconds.clamp(0, 24 * 3600).round() : 0;
    final minutes = total ~/ 60;
    final secs = total % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

class _PlayerViewIsolated extends StatelessWidget {
  const _PlayerViewIsolated({required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final playerController = controller.playerController;

        if (playerController == null) {
          return const SizedBox.shrink();
        }

        return PlayerView(controller: playerController);
      },
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _PianoRangeSelector extends StatelessWidget {
  const _PianoRangeSelector({required this.value, required this.onChanged});

  final PianoRangeMode value;
  final ValueChanged<PianoRangeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SegmentedButton<PianoRangeMode>(
      segments: const [
        ButtonSegment<PianoRangeMode>(
          value: PianoRangeMode.real,
          label: Text('実音'),
        ),
        ButtonSegment<PianoRangeMode>(
          value: PianoRangeMode.tone,
          label: Text('楽音'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
      showSelectedIcon: false,
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(theme.textTheme.labelSmall),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
