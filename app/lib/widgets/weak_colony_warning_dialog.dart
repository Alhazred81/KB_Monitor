import 'package:flutter/material.dart';
import '../hive_model.dart';

/// Nagy formátumú, hangsúlyos figyelmeztető ablak nagy "Mégse" és "Csakazértis!" gombokkal.
class _LargeBeekeepingWarningDialog extends StatelessWidget {
  final String title;
  final String badgeText;
  final String primaryMessage;
  final String biologicalExplanation;
  final String targetHiveInfo;
  final String confirmationQuestion;
  final String confirmButtonLabel;
  final Color badgeColor;

  const _LargeBeekeepingWarningDialog({
    required this.title,
    required this.badgeText,
    required this.primaryMessage,
    required this.biologicalExplanation,
    required this.targetHiveInfo,
    this.confirmationQuestion = 'Biztosan végrehajtod ezt a műveletet?',
    this.confirmButtonLabel = 'FELÜLBÍRÁLÁS',
    this.badgeColor = const Color(0xFFEF4444),
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.amber.shade500, width: 2.0),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fejléc
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amberAccent, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amberAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          targetHiveInfo,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Görgethető tartalom, hogy semmilyen képernyőn ne csorduljon túl
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Riasztási sáv
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: badgeColor, width: 1.2),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.report_problem, color: badgeColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Fő üzenet
                      Text(
                        primaryMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Részletes magyarázat (tömör!)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          biologicalExplanation,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Kérdés
                      Center(
                        child: Text(
                          confirmationQuestion,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Gombok (egy soros, kesztyűbarát, túlcsordulás-mentes)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669), // Zöld
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.shield, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'MÉGSE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626), // Piros
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.priority_high, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            confirmButtonLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1. FIGYELMEZTETÉS: ETETŐ ÉS MÉZTÉR ÖSSZEFÉRHETETLENSÉGE
Future<bool> showFeederHoneyConflictDialog({
  required BuildContext context,
  required HiveData hive,
  required String conflictType,
  VoidCallback? onConfirm,
}) async {
  String title;
  String badgeText;
  String primaryMessage;
  String biologicalExplanation;

  if (conflictType == 'adding_feeder_with_honey') {
    title = 'Tetőetető felhelyezés';
    badgeText = 'Méztéri fiók van a kaptáron!';
    primaryMessage = 'Etetéshez a méztéri fiókot le kell venni!';
    biologicalExplanation =
        'A méhek a cukorszirupot a mézkamrába hordhatják, ami mézhamisításhoz vezet. Etetés előtt vedd le a mézteret.';
  } else if (conflictType == 'adding_honey_with_feeder') {
    title = 'Méztér hozzáadás';
    badgeText = 'Tetőetető / aktív etetés van a kaptáron!';
    primaryMessage = 'Etetés alatt tilos mézteret felhelyezni!';
    biologicalExplanation =
        'A beadott szirup bekerül a méztéri lépekbe, ami elszennyezi a tiszta virágmézet.';
  } else {
    title = 'Szirupadagolás aktiválás';
    badgeText = 'Méztéri fiók van a kaptáron!';
    primaryMessage = 'Méztér jelenlétében tilos a szirupetetés!';
    biologicalExplanation =
        'A szirup közvetlenül a mézkamrába kerül. Etetés előtt a mézteret le kell venni.';
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _LargeBeekeepingWarningDialog(
      title: title,
      badgeText: badgeText,
      primaryMessage: primaryMessage,
      biologicalExplanation: biologicalExplanation,
      targetHiveInfo: 'Kaptár: ${hive.name} (${hive.id})',
      badgeColor: const Color(0xFFF59E0B),
      confirmationQuestion: 'Biztosan összeengeded az etetést a méztérrel?',
    ),
  );

  if (result == true) {
    onConfirm?.call();
    return true;
  }
  return false;
}

/// 2. FIGYELMEZTETÉS: GYENGE / BETEG CSALÁDOK BŐVÍTÉSE VAGY MEGCSAPOLÁSA
Future<bool> showWeakColonyWarningDialog({
  required BuildContext context,
  required HiveData hive,
  required String actionTitle,
  String? customWarningMessage,
  VoidCallback? onConfirm,
}) async {
  final String lower = actionTitle.toLowerCase();
  final bool isCombBuilder = lower.contains('lépépít');
  final bool isDemaree = lower.contains('szaporít') || lower.contains('demaree');
  final bool isExtraBrood = lower.contains('fészek');
  final bool isHoneySuper = lower.contains('méztér');
  final bool isExtraFrames =
      isCombBuilder || isDemaree || isExtraBrood || isHoneySuper || lower.contains('fiók');
  final bool isPollenTrap =
      lower.contains('pollen') || lower.contains('virágpor');

  final String dialogTitle = isExtraFrames
      ? 'Gyenge Család Bővítése!'
      : 'Megcsapolási Figyelmeztetés';
  final String badgeText = 'Gyenge vagy beteg család (${hive.weakOrSickReason})';

  String primaryMessage;
  if (isPollenTrap) {
    primaryMessage = 'A virágpor elvonása a család összeomlásához vezethet!';
  } else if (isCombBuilder) {
    primaryMessage = 'Gyenge családot plusz műlépes keretekkel terhelni veszélyes!';
  } else if (isDemaree) {
    primaryMessage = 'Gyenge családon a fészekmegosztás (Demaree) összeomlást okozhat!';
  } else if (isExtraFrames) {
    primaryMessage = 'A plusz keretek és megnövelt légtér kihűléshez vezethetnek!';
  } else {
    primaryMessage = 'A megcsapolás veszélyezteti a családot!';
  }

  String defaultExplanation;
  if (isPollenTrap) {
    defaultExplanation =
        'A virágpor a család egyetlen fehérjeforrása az álcák és dajkák számára. Elvonása leállítja a fiasítást.';
  } else if (isCombBuilder) {
    defaultExplanation =
        'A gyenge családnak nincs elég viasztermelő méhe és fűtőereje a lépépítő keretek kihúzásához és takarásához.';
  } else if (isDemaree) {
    defaultExplanation =
        'A gyenge család nem bírja el a fészek kettéosztását és a plusz fiókot: a fiasítás megfázhat és leáll a fejlődés.';
  } else if (isExtraFrames) {
    defaultExplanation =
        'A gyenge család nem tudja kifűteni és takarni a plusz fiók kereteit, a fiasítás megfázhat és elvész a tartalék élelem.';
  } else {
    defaultExplanation =
        'A veszélyeztetett családok megcsapolása súlyos stresszt okoz.';
  }

  final String confirmationQuestion = isExtraFrames
      ? 'Tényleg meg akarod büntizni plusz keretekkel ezt a gyenge családot?'
      : 'Biztosan megcsapolod ezt a családot?';

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _LargeBeekeepingWarningDialog(
      title: dialogTitle,
      badgeText: badgeText,
      primaryMessage: primaryMessage,
      biologicalExplanation: customWarningMessage ?? defaultExplanation,
      targetHiveInfo: 'Kaptár: ${hive.name} (${hive.id}) - $actionTitle',
      badgeColor: const Color(0xFFEF4444),
      confirmationQuestion: confirmationQuestion,
      confirmButtonLabel: 'CSAKAZÉRTIS!',
    ),
  );

  if (result == true) {
    onConfirm?.call();
    return true;
  }
  return false;
}

/// 3. FIGYELMEZTETÉS: POLLENGYŰJTŐ ÉS MÉZTÉR ÖSSZEFÉRHETETLENSÉGE
Future<bool> showPollenHoneyConflictDialog({
  required BuildContext context,
  required HiveData hive,
  required String conflictType,
  VoidCallback? onConfirm,
}) async {
  String title;
  String badgeText;
  String primaryMessage;
  String biologicalExplanation;
  String confirmationQuestion;

  if (conflictType == 'enabling_pollen_with_honey') {
    title = 'Pollengyűjtő bekapcsolása';
    badgeText = 'Méztéri fiók van a kaptáron!';
    primaryMessage = 'Fennlévő méztér mellett a pollengyűjtő nem javasolt!';
    biologicalExplanation =
        'A pollengyűjtő rács lelassítja a kijárást és akadályozza a mézhordást a mézkamrába. Méztermelés alatt a virágporgyűjtést kapcsold ki.';
    confirmationQuestion = 'Bekapcsolod így is a méztér alatt?';
  } else {
    title = 'Méztér felhelyezése';
    badgeText = 'Aktív pollengyűjtő van a kaptáron!';
    primaryMessage = 'Aktív pollengyűjtő mellett nem javasolt méztért felrakni!';
    biologicalExplanation =
        'A bekapcsolt rács gátolja a nektár behordását a méztérbe. Mézkamra felrakása előtt kapcsold ki a pollengyűjtőt.';
    confirmationQuestion = 'Felhelyezed így is a mézteret?';
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _LargeBeekeepingWarningDialog(
      title: title,
      badgeText: badgeText,
      primaryMessage: primaryMessage,
      biologicalExplanation: biologicalExplanation,
      targetHiveInfo: 'Kaptár: ${hive.name} (${hive.id})',
      badgeColor: const Color(0xFFF97316),
      confirmationQuestion: confirmationQuestion,
    ),
  );

  if (result == true) {
    onConfirm?.call();
    return true;
  }
  return false;
}

/// 4. FIGYELMEZTETÉS: 1 TELJES + 4 DB 1/2-DADANT (3 TELJES FIÓK) FELETTI TORONY -> MINIMUM SPANIFER SZÜKSÉGES!
Future<bool> showSpaniferRequiredWarningDialog({
  required BuildContext context,
  required HiveData hive,
  required String addedBoxLabel,
  required double projectedFullEquivalent,
  VoidCallback? onConfirm,
}) async {
  final String projStr = HiveData.formatBoxEquivalent(projectedFullEquivalent);
  final String currStr = hive.formattedBoxEquivalent;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _LargeBeekeepingWarningDialog(
      title: 'Spanifer Rögzítés Szükséges!',
      badgeText:
          'Spanifer határ (3 fiók) felett: $currStr ➔ $projStr / 4 teljes fiók',
      primaryMessage:
          '1 teljes + 4 db 1/2-Dadant (ill. 3 teljes) fiók felett ehhez a magassághoz már minimum spanifer kell!',
      biologicalExplanation:
          '1 teljes és 4 db 1/2-Dadant fióknál (3 teljes fiók-egyenértékig) még pont nincs szükség spaniferre, '
          'viszont a(z) "$addedBoxLabel" felhelyezésével a torony magassága eléri a $projStr teljes fiók-egyenértéket.\n\n'
          'Ilyen magasságnál (különösen teli mézterekkel és szélben) a súlypont magasra kerül, a kaptár megbillenhet vagy felborulhat – '
          'csak akkor helyezd fel, ha a tornyot minimum spaniferrel (racsnis hevederrel) biztonságosan rögzíted!',
      targetHiveInfo: 'Kaptár: ${hive.name} (${hive.id})',
      badgeColor: const Color(0xFFF59E0B),
      confirmationQuestion:
          'Biztosítod a torony minimum spaniferes rögzítését?',
      confirmButtonLabel: 'IGEN, SPANIFERREL!',
    ),
  );

  if (result == true) {
    onConfirm?.call();
    return true;
  }
  return false;
}

/// 5. TILTÓ ABLAK: 4 TELJES FIÓK (VAGY 8 DB 1/2 FIÓK) FELETTI TORONY NEM ENGEDÉLYEZETT!
Future<void> showMaxTowerHeightBlockedDialog({
  required BuildContext context,
  required HiveData hive,
  required String addedBoxLabel,
  required double addedEquivalent,
}) async {
  final double currentEq = hive.fullBoxEquivalentCount;
  final double projectedEq = currentEq + addedEquivalent;
  final double remainingEq = (HiveData.kMaxFullBoxEquivalent - currentEq).clamp(
    0.0,
    HiveData.kMaxFullBoxEquivalent,
  );
  final String currStr = HiveData.formatBoxEquivalent(currentEq);
  final String projStr = HiveData.formatBoxEquivalent(projectedEq);
  final bool halfBoxStillFits =
      remainingEq >= 0.5 - 1e-6 && addedEquivalent > 0.5;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) => Dialog(
      backgroundColor: const Color(0xFF1E293B),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.redAccent, width: 2.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent, width: 2),
                    ),
                    child: const Icon(
                      Icons.block,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Maximális Toronymagasság!',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kaptár: ${hive.name} (Jelenleg: $currStr / 4 fiók)',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent, width: 1.3),
                ),
                child: Text(
                  'A kaptártorony maximális megengedett magassága 4 teljes fiók (vagy ezzel egyenértékű 8 db 1/2 fiók, pl. 1 teljes fészek + 6 db 1/2 Dadant méztér)!\n\n'
                  '• Jelenlegi magasság: $currStr teljes fiók\n'
                  '• Kiválasztott elem ($addedBoxLabel): +${HiveData.formatBoxEquivalent(addedEquivalent)} fiók ➔ $projStr / 4 fiók (TÚLLÉPÉS!)'
                  '${halfBoxStillFits ? "\n\n💡 Tipp: Egy teljes fiók már nem fér fel, de még 1 db 1/2 fiók (+0.5) felhelyezhető spaniferes rögzítéssel!" : ""}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: const Text(
                    'MEGÉRTETTEM',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 6. FIGYELMEZTETÉS: A CSALÁD FELADATÁHOZ (FAMILY FUNCTION) NEM ILLŐ FIÓK VAGY ZUBEHÖR (KELLÉK)!
Future<bool> showFamilyFunctionBoxMismatchDialog({
  required BuildContext context,
  required HiveData hive,
  required FamilyFunctionBoxMismatch mismatch,
  bool isActivation = false,
  VoidCallback? onConfirm,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _LargeBeekeepingWarningDialog(
      title: isActivation
          ? 'Nem megfelelő kellék a feladathoz!'
          : 'Nem megfelelő fiók / kellék!',
      badgeText: mismatch.badgeText,
      primaryMessage: mismatch.primaryMessage,
      biologicalExplanation: mismatch.explanation,
      targetHiveInfo:
          'Kaptár: ${hive.name} (${hive.id}) • Feladat: ${mismatch.functionLabel}',
      badgeColor: const Color(0xFFF59E0B),
      confirmationQuestion: isActivation
          ? 'Biztosan bekapcsolod a(z) "${mismatch.elementLabel}" elemet ezen a családon?'
          : 'Biztosan felrakod a(z) "${mismatch.elementLabel}" elemet erre a családra?',
      confirmButtonLabel: isActivation ? 'BEKAPCSOLÁS ÍGY IS' : 'FELRAKÁS ÍGY IS',
    ),
  );

  if (result == true) {
    onConfirm?.call();
    return true;
  }
  return false;
}

/// 7. FIGYELMEZTETÉS: CSALÁDFUNKCIÓ ÁTÁLLÍTÁSA, AMIKOR A TORNYON MÁR NEM ODAILLŐ FIÓK/KELLÉK VAN!
Future<bool> showFunctionChangeTowerMismatchDialog({
  required BuildContext context,
  required HiveData hive,
  required String newFunctionLabel,
  required List<FamilyFunctionBoxMismatch> mismatches,
  VoidCallback? onConfirm,
}) async {
  final String conflictingItems = mismatches
      .map((m) => m.elementLabel)
      .join(', ');
  final String detailedReasons = mismatches
      .map((m) => '• ${m.elementLabel}: ${m.explanation}')
      .join('\n\n');

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _LargeBeekeepingWarningDialog(
      title: 'Torony & Feladat Eltérés!',
      badgeText:
          'Új feladat: $newFunctionLabel • Fennlévő elem: $conflictingItems',
      primaryMessage:
          'A kaptáron jelenleg olyan fiók / kellék ($conflictingItems) van, ami nem illik a(z) "$newFunctionLabel" feladathoz!',
      biologicalExplanation:
          '$detailedReasons\n\n💡 Javaslat: Az átállítás után a Konfig ablakban vedd le vagy kapcsold ki a nem odaillő elemet!',
      targetHiveInfo: 'Kaptár: ${hive.name} (${hive.id})',
      badgeColor: const Color(0xFFF59E0B),
      confirmationQuestion:
          'Átállítod így is a család feladatát "$newFunctionLabel" módra?',
      confirmButtonLabel: 'ÁTÁLLÍTÁS ÍGY IS',
    ),
  );

  if (result == true) {
    onConfirm?.call();
    return true;
  }
  return false;
}
