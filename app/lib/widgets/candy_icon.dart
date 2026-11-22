import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 5-fokozatú szirup státusz színek helper
Color getSyrupStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'green':
      return const Color(0xFF00E676); // Élénk zöld (OK, szint > 50%)
    case 'yellow':
      return const Color(0xFFFFD600); // Sárga (Figyelmeztetés, 20-50%)
    case 'orange':
      return const Color(0xFFFF9100); // Narancs (Alacsony < 20% / SZTOJ várakozó)
    case 'red':
      return const Color(0xFFFF1744); // Piros (Üres etető / Töltésre kész)
    case 'blinking_red':
      return const Color(0xFFFF0033); // Villogó piros (Vészleállítás, timeout, szivattyú tiltva)
    default:
      return const Color(0xFF00E676);
  }
}

String getSyrupStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'green':
      return 'Zöld: Normál (OK)';
    case 'yellow':
      return 'Sárga: Alacsony szint';
    case 'orange':
      return 'Narancs: Utántöltésre vár / SZTOJ';
    case 'red':
      return 'Piros: Üres etető (Töltésre kész)';
    case 'blinking_red':
      return 'VILLOGÓ PIROS: Szivattyú TILTVA!';
    default:
      return 'Normál';
  }
}

/// Cukorka (szaloncukor / wrapped candy) vektoros ikon a szirupadagolóhoz
class CandyIcon extends StatefulWidget {
  final double size;
  final Color? color;
  final String? status; // Ha megadjuk, automatikusan a zöld/sárga/narancs/piros/villogó piros színt veszi fel
  final bool animateBlink;

  const CandyIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.status,
    this.animateBlink = true,
  });

  @override
  State<CandyIcon> createState() => _CandyIconState();
}

class _CandyIconState extends State<CandyIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _blinkController;
  Animation<double>? _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _checkBlinkState();
  }

  @override
  void didUpdateWidget(covariant CandyIcon oldWidget) {
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
        (widget.status != null ? getSyrupStatusColor(widget.status!) : Colors.amberAccent);

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
          painter: _CandyPainter(color: baseColor),
        ),
      );
    }

    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _CandyPainter(color: baseColor),
    );
  }
}

class _CandyPainter extends CustomPainter {
  final Color color;

  _CandyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2.0;
    final double cy = h / 2.0;

    canvas.save();
    // Enyhe 15 fokos dőlés a természetes, játékos szaloncukor hatáshoz
    canvas.translate(cx, cy);
    canvas.rotate(-math.pi / 12.0);
    canvas.translate(-cx, -cy);

    // Színek és ecsetek
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Paint darkOutline = Paint()
      ..color = Colors.black.withAlpha(90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.04)
      ..strokeJoin = StrokeJoin.round;

    final Paint wrapperFoldPaint = Paint()
      ..color = Colors.black.withAlpha(45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, w * 0.03);

    final Paint whiteStripePaint = Paint()
      ..color = Colors.white.withAlpha(220)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.5, w * 0.08);

    final Paint knotPaint = Paint()
      ..color = Colors.white.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.04);

    // 1. BAL OLDALI CSOMAGOLÓVÉG (Klasszikus fodros / csavart szárny)
    final double leftKnotX = cx - w * 0.22;
    final Path leftWrapper = Path();
    leftWrapper.moveTo(leftKnotX, cy - h * 0.08);
    leftWrapper.lineTo(cx - w * 0.46, cy - h * 0.32); // felső csúcs
    leftWrapper.lineTo(cx - w * 0.40, cy - h * 0.16); // felső hullám
    leftWrapper.lineTo(cx - w * 0.48, cy);             // középső csúcs
    leftWrapper.lineTo(cx - w * 0.40, cy + h * 0.16); // alsó hullám
    leftWrapper.lineTo(cx - w * 0.46, cy + h * 0.32); // alsó csúcs
    leftWrapper.lineTo(leftKnotX, cy + h * 0.08);
    leftWrapper.close();

    canvas.drawPath(leftWrapper, fillPaint);
    canvas.drawPath(leftWrapper, darkOutline);
    // Redők
    canvas.drawLine(Offset(leftKnotX, cy), Offset(cx - w * 0.42, cy - h * 0.14), wrapperFoldPaint);
    canvas.drawLine(Offset(leftKnotX, cy), Offset(cx - w * 0.44, cy), wrapperFoldPaint);
    canvas.drawLine(Offset(leftKnotX, cy), Offset(cx - w * 0.42, cy + h * 0.14), wrapperFoldPaint);

    // 2. JOBB OLDALI CSOMAGOLÓVÉG (Klasszikus fodros / csavart szárny)
    final double rightKnotX = cx + w * 0.22;
    final Path rightWrapper = Path();
    rightWrapper.moveTo(rightKnotX, cy - h * 0.08);
    rightWrapper.lineTo(cx + w * 0.46, cy - h * 0.32); // felső csúcs
    rightWrapper.lineTo(cx + w * 0.40, cy - h * 0.16); // felső hullám
    rightWrapper.lineTo(cx + w * 0.48, cy);             // középső csúcs
    rightWrapper.lineTo(cx + w * 0.40, cy + h * 0.16); // alsó hullám
    rightWrapper.lineTo(cx + w * 0.46, cy + h * 0.32); // alsó csúcs
    rightWrapper.lineTo(rightKnotX, cy + h * 0.08);
    rightWrapper.close();

    canvas.drawPath(rightWrapper, fillPaint);
    canvas.drawPath(rightWrapper, darkOutline);
    // Redők
    canvas.drawLine(Offset(rightKnotX, cy), Offset(cx + w * 0.42, cy - h * 0.14), wrapperFoldPaint);
    canvas.drawLine(Offset(rightKnotX, cy), Offset(cx + w * 0.44, cy), wrapperFoldPaint);
    canvas.drawLine(Offset(rightKnotX, cy), Offset(cx + w * 0.42, cy + h * 0.14), wrapperFoldPaint);

    // 3. KÖZÉPSŐ CUKORKA TEST (Kerekded, telt bonbon forma)
    final Rect bodyRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: w * 0.50,
      height: h * 0.48,
    );
    final RRect bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(h * 0.24),
    );

    // Árnyékolt / telített cukorka test
    canvas.drawRRect(bodyRRect, fillPaint);

    // 4. BOLD FEHÉR CSÍKOZÁS (Klasszikus cukorka spirál)
    canvas.save();
    canvas.clipRRect(bodyRRect);

    // 3 ferde csík a testen
    canvas.drawLine(
      Offset(cx - w * 0.16, cy + h * 0.30),
      Offset(cx - w * 0.02, cy - h * 0.30),
      whiteStripePaint,
    );
    canvas.drawLine(
      Offset(cx - w * 0.04, cy + h * 0.30),
      Offset(cx + w * 0.10, cy - h * 0.30),
      whiteStripePaint,
    );
    canvas.drawLine(
      Offset(cx + w * 0.08, cy + h * 0.30),
      Offset(cx + w * 0.22, cy - h * 0.30),
      whiteStripePaint,
    );

    // Felső fényív
    final Paint shinePaint = Paint()
      ..color = Colors.white.withAlpha(140)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.0, w * 0.04);
    canvas.drawLine(
      Offset(cx - w * 0.15, cy - h * 0.15),
      Offset(cx + w * 0.15, cy - h * 0.15),
      shinePaint,
    );

    canvas.restore();

    // Test kontúr
    canvas.drawRRect(bodyRRect, darkOutline);

    // 5. CSOMÓK A CSAVARÁSNÁL
    canvas.drawLine(
      Offset(leftKnotX, cy - h * 0.12),
      Offset(leftKnotX, cy + h * 0.12),
      knotPaint,
    );
    canvas.drawLine(
      Offset(rightKnotX, cy - h * 0.12),
      Offset(rightKnotX, cy + h * 0.12),
      knotPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CandyPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
