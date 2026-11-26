import 'package:flutter/material.dart';

import '../hive_model.dart';

/// Megjelenít egy univerzális gondolatbuborék (thought bubble) súgót.
/// Bárhová kattintva (a háttérre, a kereten kívülre, vagy magára a buborékra) azonnal eltűnik.
Future<void> showHelpBubble(
  BuildContext context, {
  required String message,
  String? title,
  IconData? icon,
  Color accentColor = Colors.amberAccent,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Bezárás',
    barrierColor: Colors.black.withAlpha(140), // Finom fókuszáló sötétítés
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // BÁRHOVÁ kattintva (akár a háttérre) azonnal eltűnik
        onTap: () => Navigator.of(ctx).pop(),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              // Magára a buborékra kattintva is azonnal eltűnik!
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                constraints: const BoxConstraints(maxWidth: 390),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // FŐ GONDOLATBUBORÉK KÁRTYA
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A), // Mélykék / pala sötét háttér
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: accentColor.withAlpha(220),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withAlpha(90),
                            blurRadius: 22,
                            spreadRadius: 3,
                          ),
                          const BoxShadow(
                            color: Colors.black87,
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fejléc: 💭 Gondolatbuborék ikon + Cím + Bezárás ikon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: accentColor.withAlpha(35),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '💭',
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title ?? 'Méhész Súgó',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.close_rounded,
                                color: Colors.white.withAlpha(150),
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Súgó / magyarázó szöveg
                          Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.48,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Lábléc: Egyértelmű jelzés az azonnali elrejthetőségről
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.touch_app_outlined,
                                size: 14,
                                color: Colors.white.withAlpha(140),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Érints bárhová a bezáráshoz',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(140),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // GONDOLATBUBORÉK FAROK (3 csökkenő méretű felhőgömb a klasszikus gondolatbuborék formához)
                    Align(
                      alignment: const Alignment(-0.65, 0.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 5),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentColor.withAlpha(200),
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withAlpha(60),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentColor.withAlpha(170),
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentColor.withAlpha(140),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.75, end: 1.0).animate(curved),
        child: FadeTransition(
          opacity: anim1,
          child: child,
        ),
      );
    },
  );
}

/// Univerzális Kérdőjel-ikon gomb, amire bökve felugrik a gondolatbuborék súgó.
/// Bárhol elhelyezhető kártyákban, ListTile-ban, fejlécekben stb.
class HelpBubbleButton extends StatelessWidget {
  final String message;
  final String? title;
  final Color? iconColor;
  final IconData icon;
  final double size;
  final EdgeInsetsGeometry padding;

  const HelpBubbleButton({
    super.key,
    required this.message,
    this.title,
    this.iconColor,
    this.icon = Icons.help_outline_rounded,
    this.size = 18.0,
    this.padding = const EdgeInsets.all(6.0),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? Colors.amberAccent;

    return Semantics(
      label: 'Súgó buborék megnyitása',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showHelpBubble(
            context,
            message: message,
            title: title,
            accentColor: effectiveColor,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: effectiveColor.withAlpha(22),
              border: Border.all(
                color: effectiveColor.withAlpha(130),
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              color: effectiveColor,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

/// Infó gomb (ℹ️): Kiírja az azonosított kaptárelem részleteit (QR-kód, NFC, méret, adatbázis ID)
class BoxInfoButton extends StatelessWidget {
  final BoxElement box;
  final double size;
  final EdgeInsetsGeometry padding;

  const BoxInfoButton({
    super.key,
    required this.box,
    this.size = 16.0,
    this.padding = const EdgeInsets.all(5.0),
  });

  @override
  Widget build(BuildContext context) {
    final nfc = (box.secondaryCode != null && box.secondaryCode!.trim().isNotEmpty)
        ? box.secondaryCode!
        : 'Nincs párosítva';
    final db = box.dbId != null ? '#${box.dbId}' : 'Helyi azonosító';
    final sizeStr = box.size.trim().isNotEmpty ? box.size.toUpperCase() : 'Standard';
    final double eq = box.fullBoxEquivalent;
    final String eqLine = eq > 0.0
        ? '\n⚖️ Magassági egyenérték: ${eq == 0.5 ? "0.5 (1/2 fiók)" : "1.0 (teljes fiók)"}'
        : '';

    final infoText =
        '🏷️ Megnevezés: ${box.name}\n'
        '📏 Fiókméret: $sizeStr$eqLine\n'
        '📱 QR azonosító: ${box.code}\n'
        '📡 NFC kód: $nfc\n'
        '🗄️ Adatbázis azonosító: $db';

    return HelpBubbleButton(
      icon: Icons.info_outline_rounded,
      iconColor: Colors.lightBlueAccent,
      title: '${box.name} – Azonosító adatok',
      message: infoText,
      size: size,
      padding: padding,
    );
  }
}

/// Segítség gomb (❓): Kizárólag olyan elemeknél jelenik meg, ahol nem triviális,
/// időkritikus méhészeti vagy protokoll-szabályra kell figyelni (pl. napi ürítés, 3 napos kontroll, 24h leszöktetés).
class BoxHelpButton extends StatelessWidget {
  final BoxElement box;
  final double size;
  final EdgeInsetsGeometry padding;

  const BoxHelpButton({
    super.key,
    required this.box,
    this.size = 16.0,
    this.padding = const EdgeInsets.all(5.0),
  });

  static String? helpTextFor(BoxElement box) {
    final t = box.type.toLowerCase();
    final n = box.name.toLowerCase();

    if (t == 'bottom' || t == '15' || n.contains('alj')) {
      return 'Betolt atkavizsgáló tálcánál 3 naponta ellenőrizni kell a természetes atkahullást és tisztítani a tálcát! Kihúzva biztosítja az alsó szellőzést.';
    }
    if (t == 'pollen_trap' ||
        t == '11' ||
        n.contains('pollen') ||
        n.contains('virágpor') ||
        n.contains('viragpor')) {
      return 'Bekapcsolt pollengyűjtő tálcáját naponta üríteni kell a virágpor penészedésének elkerülésére! Gyenge családnál vagy főhordásban ne hagyd tartósan bekapcsolva.';
    }
    if (t == 'escapement' ||
        t == '13' ||
        n.contains('szöktet') ||
        n.contains('szoktet')) {
      return 'A méhszöktető felhelyezése után 24 (legfeljebb 48) órán belül el kell venni a felette lévő méztereket!';
    }
    return null;
  }

  static bool hasHelp(BoxElement box) => helpTextFor(box) != null;

  @override
  Widget build(BuildContext context) {
    final msg = helpTextFor(box);
    if (msg == null) {
      return const SizedBox.shrink();
    }
    return HelpBubbleButton(
      icon: Icons.help_outline_rounded,
      iconColor: Colors.amberAccent,
      title: '${box.name} – Fontos tudnivaló',
      message: msg,
      size: size,
      padding: padding,
    );
  }
}
