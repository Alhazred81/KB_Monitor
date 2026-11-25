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
