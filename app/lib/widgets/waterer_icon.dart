import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 5-fokozatú vízadagoló / itató státusz színek helper
Color getWatererStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'green':
      return const Color(0xFF00E676); // Zöld: Optimális vízszint (> 50%)
    case 'yellow':
      return const Color(0xFFFFD600); // Sárga: Közepes vízszint (25-50%)
    case 'orange':
      return const Color(0xFFFF9100); // Narancs: Alacsony vízszint (< 25%, utántöltendő)
    case 'red':
      return const Color(0xFFFF1744); // Piros: Kiszáradt / Üres itató (<= 5%)
    case 'blinking_red':
      return const Color(0xFFFF0033); // Villogó piros: Vészleállítás, Fagyveszély (vízhő <= 1°C), zárolás
    default:
      return const Color(0xFF00E676);
  }
}

/// 5-fokozatú vízadagoló státusz szöveg
String getWatererStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'green':
      return 'Zöld: Optimális vízszint (> 50%)';
    case 'yellow':
      return 'Sárga: Közepes vízszint (25-50%)';
    case 'orange':
      return 'Narancs: Alacsony szint (< 25%, utántöltés szükséges)';
    case 'red':
      return 'Piros: Kiszáradt / Üres itató (<= 5%)';
    case 'blinking_red':
      return 'VILLOGÓ PIROS: Vészleállítás / Fagyveszély!';
    default:
      return 'Normál vízszint';
  }
}

/// Vektoros Vízcsepp (Itató) ikon, amely támogatja az 5-fokozatú állapotot és a villogó animációt
class WatererIcon extends StatefulWidget {
  final double size;
  final Color? color;
  final String? status; // 'green', 'yellow', 'orange', 'red', 'blinking_red'
  final bool animateBlink;

  const WatererIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.status,
    this.animateBlink = true,
  });

  @override
  State<WatererIcon> createState() => _WatererIconState();
}

class _WatererIconState extends State<WatererIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _blinkController;
  Animation<double>? _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _checkBlinkState();
  }

  @override
  void didUpdateWidget(covariant WatererIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _checkBlinkState();
    }
  }

  void _checkBlinkState() {
    final bool isBlinkingRed = (widget.status == 'blinking_red');
    if (isBlinkingRed && widget.animateBlink) {
      if (_blinkController == null) {
        _blinkController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 380),
        )..repeat(reverse: true);
        _blinkAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
          CurvedAnimation(parent: _blinkController!, curve: Curves.easeInOut),
        );
      }
    } else {
      _blinkController?.dispose();
      _blinkController = null;
      _blinkAnimation = null;
    }
  }

  @override
  void dispose() {
    _blinkController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ??
        (widget.status != null
            ? getWatererStatusColor(widget.status!)
            : const Color(0xFF00E676));

    if (_blinkAnimation != null) {
      return AnimatedBuilder(
        animation: _blinkAnimation!,
        builder: (context, child) {
          return Opacity(
            opacity: _blinkAnimation!.value,
            child: child,
          );
        },
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _WaterDropPainter(color: baseColor),
        ),
      );
    }

    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _WaterDropPainter(color: baseColor),
    );
  }
}

class _WaterDropPainter extends CustomPainter {
  final Color color;

  _WaterDropPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2.0;

    // Vízcsepp Path: hegyes csúcs fent, lekerekített teltség lent
    final Path dropPath = Path();
    dropPath.moveTo(cx, h * 0.08); // felső hegyes csúcs
    dropPath.cubicTo(
      cx + w * 0.42, h * 0.45, // kontrollpont 1
      cx + w * 0.46, h * 0.88, // kontrollpont 2
      cx, h * 0.94,            // alsó lekerekített ív közepe
    );
    dropPath.cubicTo(
      cx - w * 0.46, h * 0.88,
      cx - w * 0.42, h * 0.45,
      cx, h * 0.08,
    );
    dropPath.close();

    // 1. Kitöltés a státusz színével
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(dropPath, fillPaint);

    // 2. Sötét kontúr a térképen való éles megjelenésért
    final Paint outlinePaint = Paint()
      ..color = Colors.black.withAlpha(110)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.06)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dropPath, outlinePaint);

    // 3. Fénycsillanás a bal felső íven
    final Path shinePath = Path();
    shinePath.moveTo(cx - w * 0.16, h * 0.38);
    shinePath.cubicTo(
      cx - w * 0.28, h * 0.52,
      cx - w * 0.32, h * 0.72,
      cx - w * 0.18, h * 0.82,
    );

    final Paint shinePaint = Paint()
      ..color = Colors.white.withAlpha(190)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.2, w * 0.08);
    canvas.drawPath(shinePath, shinePaint);

    // 4. Belső vízszint / apró hullám ív lent
    final Path wavePath = Path();
    wavePath.moveTo(cx - w * 0.22, h * 0.65);
    wavePath.quadraticBezierTo(cx - w * 0.05, h * 0.58, cx + w * 0.08, h * 0.66);
    wavePath.quadraticBezierTo(cx + w * 0.18, h * 0.72, cx + w * 0.26, h * 0.65);

    final Paint wavePaint = Paint()
      ..color = Colors.white.withAlpha(90)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.8, w * 0.05);
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _WaterDropPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Státusz badge készítő segéd widget vízadagolóhoz
Widget buildWatererStatusBadge(String status, {bool isMini = false}) {
  final Color sColor = getWatererStatusColor(status);
  final String label = getWatererStatusLabel(status);

  if (isMini) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: sColor.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: sColor.withAlpha(180), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WatererIcon(size: 11, status: status),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: sColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: sColor.withAlpha(35),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: sColor.withAlpha(190), width: 1.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WatererIcon(size: 14, status: status),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: sColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
