import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../hive_model.dart';
import '../services/hive_repository.dart';
import 'help_bubble.dart';

/// Segédfüggvény: Anyajelölő szín meghatározása évjárat alapján
Color getQueenVintageColor(String vintage) {
  final v = vintage.toLowerCase();
  if (v.contains('fehér') || v.contains('feher') || v.contains('white') || v.contains('2026') || v.contains('2021')) {
    return Colors.white;
  }
  if (v.contains('kék') || v.contains('kek') || v.contains('blue') || v.contains('2025') || v.contains('2020')) {
    return Colors.lightBlueAccent;
  }
  if (v.contains('zöld') || v.contains('zold') || v.contains('green') || v.contains('2024')) {
    return Colors.greenAccent;
  }
  if (v.contains('piros') || v.contains('red') || v.contains('2023')) {
    return Colors.redAccent;
  }
  if (v.contains('sárga') || v.contains('sarga') || v.contains('yellow') || v.contains('2022')) {
    return Colors.amberAccent;
  }
  return Colors.amberAccent;
}

/// Anyacsere munkafolyamat és Lakat figyelmeztető párbeszédpanelek
/// Teljes mértékben bokszkesztyű- és méhészkestyű-barát nagy nyomógombokkal.

/// 1. Anyacsere folyamat párbeszédpanel (Anya eltávolítása ➔ Új anya / Felszámolás ➔ Szoktatós / Kirágós 14 napos lakat)
Future<void> showQueenReplacementFlowDialog({
  required BuildContext context,
  required HiveData hive,
  required HiveRepository repository,
  VoidCallback? onOpenDetails,
}) async {
  // Állapotok a több lépéses folyamathoz
  QueenData? selectedQueen;
  bool isSelectingQueenSource = false;
  bool isShowingRegisteredPicker = false;
  bool isShowingQueenWizard = false;
  bool isShowingIntroductionChoice = (hive.queenReplacementState == 'choosing_intro_mode');

  // Varázsló állapotok
  final random = math.Random();
  String wizardQueenId = 'HU-${DateTime.now().year}-${100 + random.nextInt(900)}';
  final TextEditingController idController = TextEditingController(text: wizardQueenId);
  String wizardVintage = '${DateTime.now().year} (Fehér)';
  String wizardOrigin = 'Pannon méh (Apis m. carnica)';

  final List<String> vintageOptions = [
    '${DateTime.now().year} (Fehér)',
    '${DateTime.now().year - 1} (Kék)',
    '${DateTime.now().year - 2} (Zöld)',
    '${DateTime.now().year - 3} (Piros)',
    '${DateTime.now().year - 4} (Sárga)',
  ];

  final List<String> originOptions = [
    'Pannon méh (Apis m. carnica)',
    'Krajnai F1 (Termékenyített)',
    'Buckfast F0 (Tenyésztői)',
    'Saját nevelés (Bölcső/Pároztató)',
  ];

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final String state = hive.queenReplacementState ?? 'needs_replacement';

          final bool isWarningState = (state == 'needs_replacement' ||
              (state == 'queen_removed' &&
                  !isSelectingQueenSource &&
                  !isShowingRegisteredPicker &&
                  !isShowingQueenWizard &&
                  !isShowingIntroductionChoice));

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isWarningState
                    ? Colors.redAccent
                    : (isShowingQueenWizard || isSelectingQueenSource)
                        ? const Color(0xFF10b981)
                        : Colors.amberAccent,
                width: 2,
              ),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isWarningState
                        ? Colors.red.withAlpha(50)
                        : (isShowingQueenWizard || isSelectingQueenSource)
                            ? const Color(0xFF10b981).withAlpha(50)
                            : Colors.amber.withAlpha(50),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    (state == 'needs_replacement')
                        ? Icons.warning_rounded
                        : (state == 'queen_removed' &&
                                !isSelectingQueenSource &&
                                !isShowingRegisteredPicker &&
                                !isShowingQueenWizard &&
                                !isShowingIntroductionChoice)
                            ? Icons.heart_broken_outlined
                            : isSelectingQueenSource
                                ? Icons.tune
                                : isShowingRegisteredPicker
                                    ? Icons.inventory_2_outlined
                                    : isShowingQueenWizard
                                        ? Icons.auto_awesome
                                        : (state == 'introduced_cage')
                                            ? Icons.lock_clock
                                            : Icons.workspace_premium,
                    color: isWarningState
                        ? Colors.redAccent
                        : (isShowingQueenWizard || isSelectingQueenSource)
                            ? const Color(0xFF10b981)
                            : Colors.amberAccent,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (state == 'needs_replacement')
                            ? 'Anyacsere: ${hive.name}'
                            : (state == 'queen_removed' &&
                                    !isSelectingQueenSource &&
                                    !isShowingRegisteredPicker &&
                                    !isShowingQueenWizard &&
                                    !isShowingIntroductionChoice)
                                ? 'Anya eltávolítva: ${hive.name}'
                                : isSelectingQueenSource
                                    ? 'Új anya választás'
                                    : isShowingRegisteredPicker
                                        ? 'Szabad anyák listája'
                                        : isShowingQueenWizard
                                            ? 'Új anya regisztráció'
                                            : (state == 'introduced_cage')
                                                ? 'Szoktatós anya: ${hive.name}'
                                                : 'Új anya beadása: ${hive.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isWarningState
                                  ? Colors.redAccent.withAlpha(40)
                                  : (isShowingQueenWizard || isSelectingQueenSource)
                                      ? const Color(0xFF10b981).withAlpha(40)
                                      : Colors.amberAccent.withAlpha(40),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (state == 'needs_replacement')
                                  ? '🚨 SÜRGŐS BEAVATKOZÁS'
                                  : (state == 'queen_removed' &&
                                          !isSelectingQueenSource &&
                                          !isShowingRegisteredPicker &&
                                          !isShowingQueenWizard &&
                                          !isShowingIntroductionChoice)
                                      ? '⚠️ ANYÁTLAN CSALÁD'
                                      : isSelectingQueenSource
                                          ? '👑 ANYA FORRÁS'
                                          : isShowingRegisteredPicker
                                              ? '📋 SZABAD ANYÁK'
                                              : isShowingQueenWizard
                                                  ? '✨ VARÁZSLÓ'
                                                  : (state == 'introduced_cage')
                                                      ? '🔒 ZÁRT ZÁRKA (Szoktatás)'
                                                      : '👑 BEADÁSI MÓD',
                              style: TextStyle(
                                color: isWarningState
                                    ? Colors.redAccent
                                    : (isShowingQueenWizard || isSelectingQueenSource)
                                        ? const Color(0xFF10b981)
                                        : Colors.amberAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          HelpBubbleButton(
                            title: 'Anyacsere folyamat súgó',
                            message: (state == 'needs_replacement')
                                ? 'Anya eltávolítási fázis: A család anyacserére lett jelölve. A kaptár a térképen pirossal jelez. Miután a régi anyát megkerested és eltávolítottad, bökj az "Anya eltávolítva" gombra.'
                                : (state == 'queen_removed' &&
                                        !isSelectingQueenSource &&
                                        !isShowingRegisteredPicker &&
                                        !isShowingQueenWizard &&
                                        !isShowingIntroductionChoice)
                                    ? 'Anyátlan állapot: A régi anya el lett távolítva. Bökj az "Új anya" gombra a forrás (regisztrált vagy varázsló) kiválasztásához, vagy a "Család felszámolása" gombra.'
                                    : isSelectingQueenSource
                                        ? 'Válassz a már meglévő, nyilvántartott szabad anyák közül, vagy készíts új anyát a regisztrációs varázslóval.'
                                        : isShowingRegisteredPicker
                                            ? 'A listában a kaptárhoz még nem rendelt, élő tartalék anyák láthatók. Bökj a választott anyára a beadási módhoz!'
                                            : isShowingQueenWizard
                                                ? 'Generált azonosító, évjárat és származás beállítása. Mentés után a család értékelése tiszta lappal indul.'
                                                : (state == 'introduced_cage')
                                                    ? 'Szoktatós anyásítás: Az új anya zárt kalitkában szokja a családot. Pár nap után állítsd át kirágósra.'
                                                    : 'Beadási módok:\n• Szoktatósra: Zárt zárka (nem rághatják ki még).\n• Kirágósra: Cukorlepényes kirágásra adva + 14 napos LAKAT védelem (tilos bolygatni)!',
                            iconColor: isWarningState
                                ? Colors.redAccent
                                : (isShowingQueenWizard || isSelectingQueenSource)
                                    ? const Color(0xFF10b981)
                                    : Colors.amberAccent,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- 1. LÉPÉS: ANYA CSERÉRE JELÖLVE (ELTÁVOLÍTÁS SZÜKSÉGES) ---
                  if (state == 'needs_replacement') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      onPressed: () {
                        hive.queenReplacementState = 'queen_removed';
                        hive.status = 'red';
                        repository.updateHive(hive);
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 24),
                      label: const Text(
                        'Anya eltávolítva',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Mégse', style: TextStyle(fontSize: 14)),
                    ),
                  ]

                  // --- 2. LÉPÉS: ANYA ELTÁVOLÍTVA (FŐ MENÜ: ÚJ ANYA VAGY FELSZÁMOLÁS) ---
                  else if (state == 'queen_removed' &&
                      !isSelectingQueenSource &&
                      !isShowingRegisteredPicker &&
                      !isShowingQueenWizard &&
                      !isShowingIntroductionChoice) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10b981), // Zöld
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          isSelectingQueenSource = true;
                        });
                      },
                      icon: const Icon(Icons.workspace_premium, size: 24),
                      label: const Text(
                        'Új anya',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrangeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (confirmCtx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Row(
                              children: [
                                Icon(Icons.call_merge, color: Colors.deepOrangeAccent, size: 26),
                                SizedBox(width: 8),
                                Text('Család felszámolása?', style: TextStyle(color: Colors.white, fontSize: 16)),
                              ],
                            ),
                            content: const Text(
                              'A család funkciója Selejtre vált. A nép lesöpörhető vagy más családok felerősítésére használható fel.\n\nBiztosan felszámolod?',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(confirmCtx),
                                child: const Text('Mégse', style: TextStyle(color: Colors.grey)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrangeAccent),
                                onPressed: () {
                                  Navigator.pop(confirmCtx);
                                  hive.familyFunction = 'selejt';
                                  hive.queenReplacementState = null;
                                  hive.status = 'yellow';
                                  repository.updateHive(hive);
                                  Navigator.pop(dialogCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Család felszámolásra jelölve (Selejt funkció)!'),
                                      backgroundColor: Colors.deepOrange,
                                    ),
                                  );
                                },
                                child: const Text('Igen, felszámolás', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.call_merge, size: 22),
                      label: const Text(
                        'Család felszámolása',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Mégse', style: TextStyle(fontSize: 14)),
                    ),
                  ]

                  // --- 2/A. LÉPÉS: ÚJ ANYA FORRÁS VÁLASZTÁSA (Már regisztrált VAGY Új anya regisztrációja) ---
                  else if (isSelectingQueenSource) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7), // Kék
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          isSelectingQueenSource = false;
                          isShowingRegisteredPicker = true;
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, size: 24, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Már regisztrált anya',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  'Kaptárhoz nem rendelt anyák (${repository.getUnassignedQueens().length} db szabad)',
                                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white70),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10b981), // Zöld
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          wizardQueenId = 'HU-${DateTime.now().year}-${100 + random.nextInt(900)}';
                          idController.text = wizardQueenId;
                          isSelectingQueenSource = false;
                          isShowingQueenWizard = true;
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.auto_awesome, size: 24, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Új anya regisztrációja',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  'Varázsló: Generált ID, évjárat, tiszta lap',
                                  style: TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white70),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          isSelectingQueenSource = false;
                        });
                      },
                      child: const Text('Vissza', style: TextStyle(fontSize: 14)),
                    ),
                  ]

                  // --- 2/B. LÉPÉS: REGISZTRÁLT, KAPTÁRHOZ NEM RENDELT ANYÁK LISTÁJA ---
                  else if (isShowingRegisteredPicker) ...[
                    Builder(
                      builder: (context) {
                        final unassignedQueens = repository.getUnassignedQueens();

                        if (unassignedQueens.isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, size: 40, color: Colors.white38),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Nincs szabad regisztrált anya!',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'A nyilvántartásban minden élő anya egy-egy családhoz van már rendelve.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white60, fontSize: 11.5),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10b981),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          wizardQueenId = 'HU-${DateTime.now().year}-${100 + random.nextInt(900)}';
                                          idController.text = wizardQueenId;
                                          isShowingRegisteredPicker = false;
                                          isShowingQueenWizard = true;
                                        });
                                      },
                                      icon: const Icon(Icons.auto_awesome, size: 18),
                                      label: const Text('Új anya regisztrációja (Varázsló)'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Válassz ki egy szabad anyát a beadáshoz:',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: unassignedQueens.length,
                                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final q = unassignedQueens[index];
                                  final color = getQueenVintageColor(q.vintage);

                                  return Material(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        setDialogState(() {
                                          selectedQueen = q;
                                          isShowingRegisteredPicker = false;
                                          isShowingIntroductionChoice = true;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: color.withAlpha(40),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: color, width: 2),
                                              ),
                                              child: Icon(Icons.workspace_premium, color: color, size: 18),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    q.id,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${q.vintage} • ${q.origin}',
                                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.amberAccent),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          isShowingRegisteredPicker = false;
                          isSelectingQueenSource = true;
                        });
                      },
                      child: const Text('Vissza', style: TextStyle(fontSize: 14)),
                    ),
                  ]

                  // --- 2/C. LÉPÉS: ÚJ ANYA REGISZTRÁCIÓS VARÁZSLÓ (Véletlen ID, évjárat, származás, tiszta lap) ---
                  else if (isShowingQueenWizard) ...[
                    // 1. Azonosító mező sorsolással
                    Row(
                      children: [
                        const Text(
                          'Anya azonosítója:',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              wizardQueenId = 'HU-${DateTime.now().year}-${100 + random.nextInt(900)}';
                              idController.text = wizardQueenId;
                            });
                          },
                          icon: const Icon(Icons.casino_outlined, size: 16, color: Colors.amberAccent),
                          label: const Text('Sorsolás 🎲', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: TextField(
                        controller: idController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'pl. HU-2026-101',
                          hintStyle: TextStyle(color: Colors.white30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. Évjárat & színkód választó
                    const Text(
                      'Évjárat & Jelölőszín:',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: vintageOptions.map((v) {
                        final isSelected = (wizardVintage == v);
                        final dotColor = getQueenVintageColor(v);

                        return ChoiceChip(
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                wizardVintage = v;
                              });
                            }
                          },
                          backgroundColor: const Color(0xFF0F172A),
                          selectedColor: const Color(0xFF1E3A8A),
                          side: BorderSide(
                            color: isSelected ? Colors.amberAccent : Colors.white24,
                            width: isSelected ? 1.5 : 1,
                          ),
                          avatar: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black45),
                            ),
                          ),
                          label: Text(
                            v,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // 3. Származás választó
                    const Text(
                      'Származás / Vonal:',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: originOptions.map((o) {
                        final isSelected = (wizardOrigin == o);

                        return ChoiceChip(
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                wizardOrigin = o;
                              });
                            }
                          },
                          backgroundColor: const Color(0xFF0F172A),
                          selectedColor: const Color(0xFF065F46),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF10b981) : Colors.white24,
                            width: isSelected ? 1.5 : 1,
                          ),
                          label: Text(
                            o,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // 4. "Tiszta lap :)" információs kártya
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.tealAccent.withAlpha(80)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_stories, color: Colors.tealAccent, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tiszta lap :) Az értékelési pontszámok és feljegyzések alaphelyzetbe állnak az új anyához.',
                              style: TextStyle(color: Colors.tealAccent, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mentés és továbblépés a beadáshoz
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10b981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      onPressed: () {
                        final chosenId = idController.text.trim().isEmpty ? wizardQueenId : idController.text.trim();
                        final newQueen = QueenData(
                          id: chosenId,
                          origin: wizardOrigin,
                          vintage: wizardVintage,
                          isAlive: true,
                          needsReplacement: false,
                        );

                        // Regisztráció az adatbázisba
                        repository.addQueen(newQueen);

                        setDialogState(() {
                          selectedQueen = newQueen;
                          isShowingQueenWizard = false;
                          isShowingIntroductionChoice = true;
                        });
                      },
                      icon: const Icon(Icons.arrow_forward, size: 20),
                      label: const Text(
                        'Mentés és továbblépés a beadáshoz',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          isShowingQueenWizard = false;
                          isSelectingQueenSource = true;
                        });
                      },
                      child: const Text('Vissza', style: TextStyle(fontSize: 14)),
                    ),
                  ]

                  // --- 3. LÉPÉS: ÚJ ANYA BEADÁSA (SZOKTATÓSRA VS KIRÁGÓSRA) ---
                  else if (isShowingIntroductionChoice) ...[
                    // Kiválasztott anya információs sáv
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amberAccent.withAlpha(120)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.workspace_premium,
                            color: getQueenVintageColor(selectedQueen?.vintage ?? ''),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Anya: ${selectedQueen?.id ?? "Új anya"}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${selectedQueen?.vintage ?? ""} • ${selectedQueen?.origin ?? ""}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                isShowingIntroductionChoice = false;
                                isSelectingQueenSource = true;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Módosít', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7), // Kék / Cyan
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final queenToAssign = selectedQueen ??
                            QueenData(
                              id: 'Új anya (${DateTime.now().year})',
                              origin: 'Saját / Anyanevelés',
                              vintage: '${DateTime.now().year}',
                              isAlive: true,
                              needsReplacement: false,
                            );

                        hive.queenReplacementState = 'introduced_cage';
                        hive.queenIntroducedAt = DateTime.now();
                        hive.status = 'yellow';
                        hive.queen = queenToAssign;
                        // Tiszta lap - Minden jegy alapállapotba kerül
                        hive.resetEvaluation(
                          newQueenId: queenToAssign.id,
                          reason: 'Tiszta lap - beadva szoktatósra (${queenToAssign.id})',
                        );

                        repository.scheduleQueenReplacementTasks(hive, isCageMode: true);
                        repository.updateHive(hive);
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Új anya (${queenToAssign.id}) szoktatósra beadva! 3 nap múlva esedékes az anyakalitka kirágósra állítása.',
                            ),
                            backgroundColor: Colors.blueAccent,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.lock_clock, size: 24),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Új anya beadva szoktatósra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Zárt kalitka (3 nap múlva kirágósra állítás)', style: TextStyle(fontSize: 10.5, color: Colors.white70)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final queenToAssign = selectedQueen ??
                            QueenData(
                              id: 'Új anya (${DateTime.now().year})',
                              origin: 'Saját / Anyanevelés',
                              vintage: '${DateTime.now().year}',
                              isAlive: true,
                              needsReplacement: false,
                            );

                        // 14 napos lakat aktiválása
                        hive.queenReplacementState = 'introduced_chewout';
                        hive.queenIntroducedAt = DateTime.now();
                        final lockEnd = DateTime.now().add(const Duration(days: 14));
                        hive.lockedUntil = lockEnd;
                        hive.lockReason = 'Új anya kirágósra adva (${queenToAssign.id} - Ne nyúlj hozzá!)';
                        hive.status = 'green';
                        hive.queen = queenToAssign;
                        // Tiszta lap - Minden jegy alapállapotba kerül
                        hive.resetEvaluation(
                          newQueenId: queenToAssign.id,
                          reason: 'Tiszta lap - beadva kirágósra (${queenToAssign.id})',
                        );

                        // Szokásos délelőtti (10:00) vizsgálat beütemezése a lakat lejárata napjára
                        final inspectionDate = DateTime(
                          lockEnd.year,
                          lockEnd.month,
                          lockEnd.day,
                          10,
                          0,
                        );
                        repository.scheduleQueenReplacementTasks(
                          hive,
                          isCageMode: false,
                          custom14DayDate: inspectionDate,
                        );
                        repository.updateHive(hive);

                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Új anya (${queenToAssign.id}) kirágósra beadva! Tiszta lap indult.\n'
                              '🔒 14 napos LAKAT aktív (Tilos bolygatni, a monitor hallgatózik)!\n'
                              '📅 Vizsgálat a lakat lejáratakor: ${inspectionDate.year}.${inspectionDate.month.toString().padLeft(2, '0')}.${inspectionDate.day.toString().padLeft(2, '0')} (10:00)',
                            ),
                            backgroundColor: Colors.teal,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.lock, size: 24, color: Colors.black),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Új anya beadva kirágósra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                                Text('Cukorlepényes zárka + 2 hetes LAKAT védelem', style: TextStyle(fontSize: 10.5, color: Colors.black87)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          isShowingIntroductionChoice = false;
                          isSelectingQueenSource = true;
                        });
                      },
                      child: const Text('Vissza', style: TextStyle(fontSize: 14)),
                    ),
                  ]

                  // --- 4. LÉPÉS: SZOKTATÓSBÓL KIRÁGÓSBA VÁLTÁS ---
                  else if (state == 'introduced_cage') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        hive.queenReplacementState = 'introduced_chewout';
                        hive.queenIntroducedAt = DateTime.now();
                        final lockEnd = DateTime.now().add(const Duration(days: 14));
                        hive.lockedUntil = lockEnd;
                        hive.lockReason = 'Új anya kirágósra adva (Ne nyúlj hozzá!)';
                        hive.status = 'green';

                        // Szokásos délelőtti (10:00) vizsgálat beütemezése a lakat lejárata napjára
                        final inspectionDate = DateTime(
                          lockEnd.year,
                          lockEnd.month,
                          lockEnd.day,
                          10,
                          0,
                        );
                        repository.scheduleQueenReplacementTasks(
                          hive,
                          isCageMode: false,
                          custom14DayDate: inspectionDate,
                        );
                        repository.updateHive(hive);

                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Kirágósra állítva! Kaptár 14 napra zárolva (🔒 Lakat: Tilos bolygatni)!\n'
                              '📅 Vizsgálat a lakat lejáratakor: ${inspectionDate.year}.${inspectionDate.month.toString().padLeft(2, '0')}.${inspectionDate.day.toString().padLeft(2, '0')} (10:00)',
                            ),
                            backgroundColor: Colors.teal,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      },
                      icon: const Icon(Icons.lock, color: Colors.black, size: 22),
                      label: const Text(
                        'Átállítás kirágósra (14 napos Lakat)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Mégse', style: TextStyle(fontSize: 14)),
                    ),
                  ],

                  if (onOpenDetails != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        onOpenDetails();
                      },
                      icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white54),
                      label: const Text(
                        'Kaptár adatlap megtekintése',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// 2. Zárolt Kaptár (LAKAT: Ne nyúlj hozzá!) figyelmeztető párbeszédpanel
Future<void> showLockedHiveWarningDialog({
  required BuildContext context,
  required HiveData hive,
  required HiveRepository repository,
  VoidCallback? onOpenDetails,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final int remainingDays = hive.lockedDaysRemaining;
      final String untilFormatted = hive.lockedUntilFormatted;

      return AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amberAccent, width: 2.5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amberAccent, width: 2),
              ),
              child: const Icon(Icons.lock, color: Colors.amberAccent, size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KAPTÁR ZÁROLVA',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${hive.name} • NE NYÚLJ HOZZÁ!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent.withAlpha(90)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hátralévő nyugalmi idő:',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        '$remainingDays nap',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Zárolás lejárata:',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        untilFormatted,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: Colors.white24, height: 10),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.event_available, color: Colors.tealAccent, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ütemezett vizsgálat: $untilFormatted (10:00)\nAnyásítás, petézés & fiasítás ellenőrzése',
                          style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withAlpha(60)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.report_problem, color: Colors.amberAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tilos a kaptár bolygatása a nyugalmi idő alatt!',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  HelpBubbleButton(
                    title: 'Lakat védelem miértje',
                    message: 'Új anya kirágósra beadva! A korai bolygatás, füstölés vagy keretmozgatás az új anya azonnali lefojtásához (megöléséhez) vezethet!\n\nA kirágás és a petézés megkezdése 2 hetes teljes nyugalmat igényel.',
                    iconColor: Colors.amberAccent,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10b981),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Értem, nem nyúlok hozzá (Bezárás)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (unlockCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Zárolás kényszerű feloldása?', style: TextStyle(color: Colors.redAccent)),
                      content: const Text(
                        'Biztosan feloldod a 2 hetes nyugalmi lakatot?\nCsak akkor ajánlott, ha súlyos vészhelyzet miatt elkerülhetetlen a kaptár megnyitása!',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(unlockCtx),
                          child: const Text('Mégse', style: TextStyle(color: Colors.grey)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () {
                            Navigator.pop(unlockCtx);
                            hive.lockedUntil = null;
                            hive.lockReason = null;
                            repository.updateHive(hive);
                            Navigator.pop(ctx);
                            if (onOpenDetails != null) onOpenDetails();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kaptár zárolása feloldva!'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          child: const Text('Feloldás és megnyitás', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  'Zárolás feloldása',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
              if (onOpenDetails != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onOpenDetails();
                  },
                  child: const Text(
                    'Adatlap megnyitása ➔',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}
