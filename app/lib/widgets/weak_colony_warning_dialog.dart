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
  final Color badgeColor;

  const _LargeBeekeepingWarningDialog({
    required this.title,
    required this.badgeText,
    required this.primaryMessage,
    required this.biologicalExplanation,
    required this.targetHiveInfo,
    this.confirmationQuestion = 'Biztosan végrehajtod ezt a műveletet?',
    this.badgeColor = const Color(0xFFEF4444),
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.amber.shade500, width: 2.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fejléc nagy figyelmeztető ikonnal
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amberAccent, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amberAccent,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          targetHiveInfo,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Riasztási sáv
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor, width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.report_problem, color: badgeColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Fő üzenet
              Text(
                primaryMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),

              // Részletes biológiai / szakmai magyarázat
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  biologicalExplanation,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Kérdés
              Center(
                child: Text(
                  confirmationQuestion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // GOMBOK: Nagy MÉGSE és CSAKAZÉRTIS! gombok
              Row(
                children: [
                  // NAGY MÉGSE GOMB (Ésszerű, biztonságos döntés)
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669), // Smaragdzöld
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.shield, size: 20),
                        label: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'MÉGSE',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Védjük a mézet & családot',
                              style: TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // NAGY FELÜLBÍRÁLÁS GOMB (Szakszerű override / saját felelősségre)
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626), // Piros
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.priority_high, size: 20),
                        label: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'FELÜLBÍRÁLÁS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Végrehajtás saját felelősségre',
                              style: TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          ],
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
/// "Ha etetőre van szükség, akkor méztéri fiókok nem nagyon vannak a környéken..."
/// Cukorszirup mézkamrába hordásának (mézhamisítás) megelőzése.
Future<bool> showFeederHoneyConflictDialog({
  required BuildContext context,
  required HiveData hive,
  required String conflictType, // 'adding_feeder_with_honey' | 'adding_honey_with_feeder' | 'feeding_with_honey'
  VoidCallback? onConfirm,
}) async {
  String title;
  String badgeText;
  String primaryMessage;
  String biologicalExplanation;

  if (conflictType == 'adding_feeder_with_honey') {
    title = 'Tetőetető felhelyezés';
    badgeText = 'ÖSSZEFÉRHETETLENSÉG: Méztéri fiók van a kaptáron!';
    primaryMessage = 'Ha etetőre van szükség, méztéri fiókoknak nincs keresnivalójuk a kaptáron!';
    biologicalExplanation =
        'A kaptáron jelenleg méztér található. A szirupetetés során a méhek a cukorszirupot közvetlenül a mézkamrába hordhatják, ami a tiszta virágméz cukorral történő elszennyeződéséhez (mézhamisításhoz) vezet!\n\nEtetés előtt a mézteret le kell venni, vagy a pergetést be kell fejezni.';
  } else if (conflictType == 'adding_honey_with_feeder') {
    title = 'Méztér hozzáadás';
    badgeText = 'ÖSSZEFÉRHETETLENSÉG: Tetőetető / aktív etetés van a kaptáron!';
    primaryMessage = 'Etetés vagy serkentés alatt tilos mézteret felhelyezni!';
    biologicalExplanation =
        'A kaptár jelenleg tetőetetővel rendelkezik vagy etetés alatt áll. Ha egy család etetésre szorul, még nem termelőképes. A méztér felrakásakor a beadott cukorszirup bekerül a méztéri lépekbe, ami tönkreteszi a méz tisztaságát!';
  } else {
    // feeding_with_honey
    title = 'Szirupadagolás aktiválás';
    badgeText = 'SZIRUP VESZÉLY: Méztéri fiók van a kaptáron!';
    primaryMessage = 'Pergetésre szánt méztér jelenlétében szigorúan tilos az etetés!';
    biologicalExplanation =
        'A kaptáron mézkamra található. A szirupos serkentés vagy feletetés azonnali cukorlerakódást eredményez a mézsejtekben. Csak akkor indíts etetést, ha a mézteret előtte leszedted!';
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
      badgeColor: const Color(0xFFF59E0B), // Sárga/narancs
      confirmationQuestion: 'Biztosan összeengeded az etetést a méztérrel?',
    ),
  );

  if (result == true) {
    onConfirm?.call();
    return true;
  }
  return false;
}

/// 2. FIGYELMEZTETÉS: GYENGE / BETEG CSALÁDOK MEGCSAPOLÁSA
/// Gyenge családoknál méztér felrakás vagy virágporgyűjtő bekapcsolás ellen.
Future<bool> showWeakColonyWarningDialog({
  required BuildContext context,
  required HiveData hive,
  required String actionTitle,
  String? customWarningMessage,
  VoidCallback? onConfirm,
}) async {
  final bool isHoneySuper = actionTitle.toLowerCase().contains('méztér');
  final bool isPollenTrap = actionTitle.toLowerCase().contains('pollen') ||
      actionTitle.toLowerCase().contains('virágpor');

  String badgeText = 'FIGYELEM: Gyenge vagy beteg család (${hive.weakOrSickReason})';
  String primaryMessage = isPollenTrap
      ? 'A virágpor elvonása a család összeomlásához vezethet!'
      : isHoneySuper
          ? 'Méztérrel a légtér hűtési/fűtési túlterhelése végzetes lehet!'
          : 'A megcsapolás veszélyezteti a család túlélését!';

  String biologicalExplanation = customWarningMessage ??
      (isPollenTrap
          ? 'A virágpor a méhcsalád egyetlen fehérjeforrása, ami nélkülözhetetlen a fiasítás táplálásához, a dajkaméhek garatmirigy-működéséhez és az immunvédelemhez. Beteg vagy gyenge család elől elvonni a virágport a fiasítás leállását és a család pusztulását okozza.'
          : isHoneySuper
              ? 'A méztér felhelyezése jelentősen megnöveli a kaptár légterét. A gyenge család nem képes kifűteni a megnövelt teret (a fiasítás megfázhat), ráadásul a megcsapolás elveszi a túléléshez szükséges méztartalékokat.'
              : 'A gyenge vagy megbetegedett családok megcsapolása súlyos biológiai stresszt jelent.');

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _LargeBeekeepingWarningDialog(
      title: 'Megcsapolási Figyelmeztetés',
      badgeText: badgeText,
      primaryMessage: primaryMessage,
      biologicalExplanation: biologicalExplanation,
      targetHiveInfo: 'Kaptár: ${hive.name} (${hive.id}) - $actionTitle',
      badgeColor: const Color(0xFFEF4444), // Piros
      confirmationQuestion: 'Biztosan megcsapolod ezt a veszélyeztetett családot?',
    ),
  );

  if (result == true) {
    onConfirm?.call();
    return true;
  }
  return false;
}
