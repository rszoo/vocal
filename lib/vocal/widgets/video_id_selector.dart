import 'package:flutter/material.dart';

class VideoIdSelector extends StatelessWidget {
  const VideoIdSelector({
    super.key,
    required this.videoIds,
    required this.selectedVideoId,
    required this.onSelected,
  });

  final List<String> videoIds;
  final String? selectedVideoId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: videoIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final videoId = videoIds[index];
          final selected = videoId == selectedVideoId;

          return InkWell(
            onTap: () => onSelected(videoId),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF514A63)
                    : const Color(0xFF1B1A22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF716784)
                      : const Color(0xFF2A2932),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6C647D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    videoId,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
