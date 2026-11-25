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

    final infoText =
        '🏷️ Megnevezés: ${box.name}\n'
        '📏 Fiókméret: $sizeStr\n'
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

/// Segítség gomb (❓): Részletezi a kaptárelem szakmai rendeltetését és használatát
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

  String _getHelpText() {
    final t = box.type.toLowerCase();
    final n = box.name.toLowerCase();

    if (t == 'bottom' || n.contains('alj')) {
      return 'Higiénikus aljdeszka atkavizsgáló tálcával. Betolt állapotban 3 napos természetes atkahullás vizsgálat végezhető. Kihúzva biztosítja az alsó szellőzést.';
    }
    if (t == 'pollen_trap' || n.contains('pollen') || n.contains('virágpor')) {
      return 'Pollengyűjtő rács virágpor behordásának gyűjtésére. Szabály szerint közvetlenül az aljdeszkán helyezkedik el. Gyenge vagy fiasításnevelő családoknál ne hagyd tartósan bekapcsolva!';
    }
    if (t == 'brood_box' || t == 'nest' || n.contains('fészek') || n.contains('feszek')) {
      return 'Fészekfiók: a méhcsalád központi része, ahol az anya petézik és a fiasítás nevelése zajlik. Ide kerülnek a fedett és nyitott fiasításos keretek.';
    }
    if (t == 'comb_builder' || n.contains('lépépít') || n.contains('lepepit')) {
      return 'Lépépítő fiók: műlépes keretek gyors kiépíttetésére erős hordásban vagy serkentés mellett, a viasztermelő fiatal méhek munkára fogásához és a rajzási hajlam csökkentéséhez.';
    }
    if (t == 'demaree' || n.contains('szaporít') || n.contains('szaporit') || n.contains('demaree')) {
      return 'Szaporító (Demaree) fiók: rajzásgátló és szaporító eljáráshoz. Az anyarács fölé (gyakran méztér közbeiktatásával) emelt fiasításos fiók dajkaméheket vonz fel, tehermentesíti az alsó fészket, és kölyökcsalád képzésére is kiváló.';
    }
    if (t == 'queen_excluder' || n.contains('anyarács') || n.contains('anyaracs')) {
      return 'Anyarács: megakadályozza, hogy a méhanya felmenjen a méztérbe vagy a Demaree-fiókba petézni, miközben a dolgozók szabadon átjárhatnak rajta.';
    }
    if (t == 'honey' || n.contains('méz') || n.contains('mez')) {
      return 'Méztéri fiók: a méhek ide hordják be a tiszta felesleges nektárt és érlelik mézzé. Pergetés előtt alá helyezett méhszöktetővel kíméletesen, méhmentesen elvehető.';
    }
    if (t == 'feeder' || t == 'roof_feeder' || n.contains('etet')) {
      return 'Tetőetető: szirupos serkentéshez és telelő etetéshez. Szabály szerint közvetlenül a dekli (tető) alatt helyezkedik el, úszóval a méhek fulladásának megakadályozására.';
    }
    if (t == 'roof' || n.contains('tető') || n.contains('teto') || n.contains('dekli')) {
      return 'Tető / Dekli: a kaptártorony legfelső záróeleme, amely védelmet nyújt az időjárás, beázás és túlmelegedés ellen, valamint hőszigetelést biztosít.';
    }
    if (t == 'escapement' || n.contains('szöktet')) {
      return 'Méhszöktető keret: a méztér alá helyezve 24-48 óra alatt kitereli a méheket a fészek felé, így a méztér szúrásmentesen pergethető.';
    }
    if (t == 'vent' || n.contains('szellőz')) {
      return 'Szellőzőfiók / rács: vándorláskor és kánikulában biztosítja a torony átáramló levegőztetését.';
    }
    return '${box.name}: kaptárelem a toronyban.';
  }

  @override
  Widget build(BuildContext context) {
    return HelpBubbleButton(
      icon: Icons.help_outline_rounded,
      iconColor: Colors.amberAccent,
      title: '${box.name} – Szakmai Súgó',
      message: _getHelpText(),
      size: size,
      padding: padding,
    );
  }
}
