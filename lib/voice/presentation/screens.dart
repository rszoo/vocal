// ./lib/voice/presentation/screens.dart

import 'package:flutter/material.dart';

import '../infrastructure/classes.dart';

class WarmUpScreen extends StatefulWidget {
  const WarmUpScreen({super.key});

  @override
  State createState() => _WarmUpScreenState();
}

class _WarmUpScreenState extends State {
  late final MicImpl _microphone;
  bool _microphoneOn = false;

  @override
  void initState() {
    super.initState();
    _microphone = MicImpl();
  }

  @override
  void dispose() {
    _microphone.dispose();
    super.dispose();
  }

  Future<void> _onMicrophoneChanged(bool value) async {
    bool nextState = false;

    if (value) {
      nextState = await _microphone.start();
    } else {
      await _microphone.stop();
    }

    if (!mounted) return;

    if (value && !nextState) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'マイクを使用できません。'
            '権限を確認してください。',
          ),
        ),
      );
    }

    setState(() {
      _microphoneOn = nextState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder(
        stream: _microphone.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('エラー: ${snapshot.error}');
          }

          final textTheme = theme.textTheme;
          final result = snapshot.data;
          final tuningColor = switch (result) {
            null => colorScheme.onSurfaceVariant,
            var r when r.isInTune => colorScheme.primary,
            _ => colorScheme.error,
          };

          return Column(
            children: [
              // ドレミ
              Text(result?.note ?? '--', style: textTheme.displayLarge),
              const SizedBox(height: 8),

              Text(
                result != null ? 'MIDI ${result.midiNote}' : ' ',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // 周波数
              Text(
                '${result != null ? result.pitch.toStringAsFixed(2) : '--'} Hz',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),

              // cents
              Text(
                result?.tuningText ?? ' ',
                style: textTheme.titleMedium?.copyWith(color: tuningColor),
              ),

              const Spacer(),

              // チューナーメーター
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
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOutCubic,
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
          );
        },
      ),
    );
  }
}
