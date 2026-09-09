import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../infrastructure/services.dart';

class WarmUpScreen extends StatefulWidget {
  const WarmUpScreen({super.key});

  @override
  State createState() => _WarmUpScreenState();
}

class _WarmUpScreenState extends State {
  late final PitchDetector _detector;
  StreamSubscription<PitchResult?>? _subscription;
  bool _microphoneOn = false;
  PitchResult? _result;

  @override
  void initState() {
    super.initState();

    _detector = PitchDetector();
    _subscription = _detector.results.listen((result) {
      if (!mounted) return;

      setState(() {
        _result = result;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _detector.dispose();
    super.dispose();
  }

  Future<void> _onMicrophoneChanged(bool value) async {
    if (value) {
      final success = await _detector.start();
      if (!mounted) return;

      if (success) {
        setState(() {
          _microphoneOn = true;
        });
      } else {
        setState(() {
          _microphoneOn = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'マイクを使用できません。'
              '権限を確認してください。',
            ),
          ),
        );
      }
    } else {
      await _detector.stop();
      if (!mounted) return;

      setState(() {
        _microphoneOn = false;
        _result = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // チューニング状態に応じた色をThemeDataから決定
    Color tuningColor;
    if (result == null) {
      tuningColor = colorScheme.onSurfaceVariant;
    } else if (result.isInTune) {
      tuningColor = colorScheme.primary;
    } else {
      tuningColor = colorScheme.error;
    }

    return SafeArea(
      child: Center(
        // 画面幅が広い場合に広がりすぎるのを防ぎ、中央に配置する
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildToolbar(context),

                const SizedBox(height: 16),

                Expanded(child: _buildTunerDisplay(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// マイク設定等
  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(_microphoneOn ? Icons.mic : Icons.mic_off),
          const SizedBox(width: 12),
          Text(_microphoneOn ? 'ON' : 'OFF', style: textTheme.titleMedium),
          const SizedBox(width: 12),
          Switch(value: _microphoneOn, onChanged: _onMicrophoneChanged),
        ],
      ),
    );
  }

  /// ノート、セント等
  Widget _buildTunerDisplay(BuildContext context) {
    final result = _result;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // チューニング状態に応じた色をThemeDataから決定
    Color tuningColor;
    if (result == null) {
      tuningColor = colorScheme.onSurfaceVariant;
    } else if (result.isInTune) {
      tuningColor = colorScheme.primary;
    } else {
      tuningColor = colorScheme.error;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        // mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ドレミ
          Text(result?.note ?? '--', style: textTheme.displayLarge),
          const SizedBox(height: 8),

          Text(
            result == null ? ' ' : 'MIDI ${result.midiNote}',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 32),

          // 周波数
          Text(
            result == null
                ? '-- Hz'
                : '${result.frequency.toStringAsFixed(2)} Hz',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),

          // cents
          Text(
            result?.tuningText ?? ' ',
            style: textTheme.titleMedium?.copyWith(color: tuningColor),
          ),

          const SizedBox(height: 48),

          // チューナーメーター
          Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('-50'),
                  Text('-25'),
                  Text('0'),
                  Text('+25'),
                  Text('+50'),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 4,
                        height: 24,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (result != null)
                      Align(
                        alignment: Alignment(
                          (result.cents / 50).clamp(-1.0, 1.0),
                          0,
                        ),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
