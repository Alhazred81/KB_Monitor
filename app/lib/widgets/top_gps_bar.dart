import 'package:flutter/material.dart';

class TopGpsBar extends StatelessWidget {
  final bool hasGpsFix;
  final bool isRedFlashing;
  final Animation<double> redOpacityAnim;
  final Color compassColor;
  final String statusMessage;
  final String headingText;
  final VoidCallback onRefresh;

  const TopGpsBar({
    super.key,
    required this.hasGpsFix,
    required this.isRedFlashing,
    required this.redOpacityAnim,
    required this.compassColor,
    required this.statusMessage,
    required this.headingText,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xB3000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: compassColor, width: 2),
        ),
        child: Row(
          children: [
            isRedFlashing
                ? FadeTransition(
                    opacity: redOpacityAnim,
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 30,
                    ),
                  )
                : Icon(Icons.explore, color: compassColor, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isRedFlashing
                        ? '⚠️ Pontatlan irány: Nyolcasolj!'
                        : 'Irány: $headingText',
                    style: TextStyle(
                      color: compassColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.amber, size: 30),
                onPressed: onRefresh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
