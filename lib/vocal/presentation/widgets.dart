// ./lib/vocal/presentation/widgets.dart

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.selected = false,
    this.selectedColor,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool selected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      iconSize: 21,
      color: selected
          ? (selectedColor ?? scheme.primary)
          : scheme.onSurfaceVariant,
      icon: Icon(icon),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.active,
    this.match = false,
  });

  final String label;
  final bool active;
  final bool match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final color = match
        ? scheme.tertiary
        : active
        ? scheme.primary
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class PlayerView extends StatelessWidget {
  const PlayerView({super.key, required this._controller});

  final YoutubePlayerController? _controller;

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    if (controller == null) {
      return Card(
        shape: shape,
        margin: EdgeInsets.zero,
        child: const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: Text('YouTubeプレイヤーを準備中...')),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: /* Stack(
        fit: StackFit.expand,
        children: [ */ YoutubePlayer(
        controller: controller,
        aspectRatio: 16 / 9,
        keepAlive: true,
        autoFullScreen: false,
      ),
      //     YoutubeValueBuilder(
      //       controller: controller,
      //       builder: (context, value) {
      //         final state = value.playerState;
      //         final isLoading =
      //             state == PlayerState.unknown ||
      //             state == PlayerState.buffering;

      //         if (!isLoading) return const SizedBox.shrink();

      //         return const Center(
      //           child: CircularProgressIndicator(strokeWidth: 2),
      //         );
      //       },
      //     ),
      //   ],
      // ),
    );
  }
}
