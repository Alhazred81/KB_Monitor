import 'package:flutter/material.dart';

/// Kaptártorony (Hive Tower) vektoros ikon
/// Ábrázolja a klasszikus kaptártetőt, a mézteret fogantyúval, a fészekfiókot és az aljdeszkát röpdeszkával.
class HiveTowerIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const HiveTowerIcon({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? Colors.amberAccent;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _HiveTowerPainter(color: effectiveColor),
      ),
    );
  }
}

class _HiveTowerPainter extends CustomPainter {
  final Color color;

  _HiveTowerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();

    // 1. Tető (Kaptártető - túlnyúló fedél)
    path.addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 4, 38, 6.5),
        const Radius.circular(2),
      ),
    );

    // 2. Méztér (Felső fiók) fogantyú-kivágással
    var superPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 12.5, 32, 10),
          const Radius.circular(2),
        ),
      );
    final superHandle = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 16.5, 8, 2.5),
          const Radius.circular(1),
        ),
      );
    superPath = Path.combine(PathOperation.difference, superPath, superHandle);
    path.addPath(superPath, Offset.zero);

    // 3. Fészekfiók (Alsó, mélyebb fiók) fogantyú-kivágással
    var broodPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 24.5, 32, 12),
          const Radius.circular(2),
        ),
      );
    final broodHandle = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(19, 29.5, 10, 2.5),
          const Radius.circular(1),
        ),
      );
    broodPath = Path.combine(PathOperation.difference, broodPath, broodHandle);
    path.addPath(broodPath, Offset.zero);

    // 4. Aljdeszka & Röpdeszka kijárónyílással
    var bottomPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 38.5, 40, 5.5),
          const Radius.circular(2),
        ),
      );
    final entranceSlit = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(14, 39.5, 20, 2),
          const Radius.circular(1),
        ),
      );
    bottomPath = Path.combine(PathOperation.difference, bottomPath, entranceSlit);
    path.addPath(bottomPath, Offset.zero);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HiveTowerPainter oldDelegate) =>
      oldDelegate.color != color;
}
