import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../screens/brood_box_control_screen.dart';
import 'weak_colony_warning_dialog.dart';
import 'candy_icon.dart';
import 'queen_replacement_dialog.dart';
import 'help_bubble.dart';

class HiveDetailSheet extends StatefulWidget {
  final HiveData hive;
  final Animation<double> redFlashOpacityAnim;
  final VoidCallback onConfigurePressed;

  const HiveDetailSheet({
    super.key,
    required this.hive,
    required this.redFlashOpacityAnim,
    required this.onConfigurePressed,
  });

  @override
  State<HiveDetailSheet> createState() => _HiveDetailSheetState();
}

class _HiveDetailSheetState extends State<HiveDetailSheet> {
  void _showFinishEscapementConfirmation(
    BuildContext context,
    HiveData hive,
    HiveRepository repository,
  ) {
    final int escapementIndex = hive.boxes.indexWhere(
      (b) => b.type == 'escapement' || b.name.toLowerCase().contains('szöktet'),
    );
    int superCount = 0;
    if (escapementIndex != -1) {
      for (int i = escapementIndex + 1; i < hive.boxes.length; i++) {
        final b = hive.boxes[i];
        if (!isRoofBox(b)) {
          superCount++;
        }
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.tealAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Szöktetés kész',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Biztosan befejezted a méhszöktetést?\n\n'
          '• A méhszöktető eltávolításra kerül.\n'
          '• A felette lévő $superCount db fiók elvételre kerül (a tető megmarad a kaptáron).\n'
          '• A kapcsolódó feladat automatikusan lezárul.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Mégse',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('Igen, fiókok elvétele'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              final removedCount = repository.finishEscapementAndHarvest(hive);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Szöktetés kész: $removedCount db fiók és a szöktető elvéve a kaptárból.',
                  ),
                  backgroundColor: Colors.teal,
                  duration: const Duration(seconds: 4),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEscapementCountdown(BoxElement box) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final startTime = box.statusUpdatedAt ?? DateTime.now();
        final elapsedSec = DateTime.now().difference(startTime).inSeconds;
        final remainingSec = (24 * 3600) - elapsedSec;
        final bool isOverdue = remainingSec <= 0;

        String timeStr;
        if (isOverdue) {
          timeStr = '00:00:00 (Lejárt!)';
        } else {
          final hrs = remainingSec ~/ 3600;
          final mins = (remainingSec % 3600) ~/ 60;
          final secs = remainingSec % 60;
          timeStr =
              '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: isOverdue ? Colors.red.withAlpha(40) : Colors.teal.withAlpha(35),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isOverdue ? Colors.redAccent : Colors.tealAccent.withAlpha(120),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOverdue ? Icons.alarm_on : Icons.timer_outlined,
                size: 11,
                color: isOverdue ? Colors.redAccent : Colors.tealAccent,
              ),
              const SizedBox(width: 3),
              Text(
                timeStr,
                style: TextStyle(
                  color: isOverdue ? Colors.redAccent : Colors.tealAccent,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Segédfüggvény az aljdeszka hátralévő napjainak kiszámításához
  String _getBottomBoardStatusText(BoxElement box) {
    if (!box.isActive) {
      return 'Aljdeszka kihúzva';
    }
    if (box.statusUpdatedAt == null) {
      return 'Aljdeszka betolva (3 napos kontroll)';
    }

    final difference = DateTime.now().difference(box.statusUpdatedAt!);
    final elapsedDays = difference.inDays;
    final remainingDays = 3 - elapsedDays;

    if (remainingDays >= 3) {
      return 'Ellenőrzés: 3 nap múlva';
    } else if (remainingDays == 2) {
      return 'Ellenőrzés: 2 nap múlva';
    } else if (remainingDays == 1) {
      return 'Ellenőrzés: Holnap (1 nap)';
    } else {
      return 'Ellenőrzés: MA esedékes!';
    }
  }

  // Segédfüggvény: ha az adatbázisból "Elem" névvel jön a fiók, típus alapján elnevezzük
  String _getBoxDisplayName(BoxElement box) {
    final lowerName = box.name.trim().toLowerCase();
    final lowerType = box.type.trim().toLowerCase();

    if (lowerType == 'broodbox' ||
        lowerType == 'brood_box' ||
        lowerType == '8' ||
        lowerName.contains('fészek') ||
        (lowerName == 'elem' && box.size.toLowerCase() == 'dadant')) {
      return 'Fészek';
    }
    if (lowerType == 'honey' ||
        lowerType == '9' ||
        lowerName.contains('méztér') ||
        lowerName.contains('meztér')) {
      return 'Méztér';
    }
    if (lowerType == 'feeder' ||
        lowerType == 'roof_feeder' ||
        lowerType == '10' ||
        lowerName.contains('etető')) {
      return 'Tetőetető';
    }
    if (lowerType == 'escapement' ||
        lowerType == '13' ||
        lowerName.contains('szöktet') ||
        lowerName.contains('szoktet')) {
      return 'Szöktető';
    }
    if (lowerType == 'vent' || lowerType == '12') return 'Szellőző';
    if (lowerType == 'pollen_trap' || lowerType == '11') return 'Pollengyűjtő';
    if (lowerType == 'bottom' || lowerType == '15') return 'Aljdeszka';
    if (lowerType == 'roof' ||
        lowerName == 'tető' ||
        lowerName == 'teto' ||
        lowerName.contains('dekli') ||
        lowerName.contains('fedő') ||
        ((lowerName.contains('tető') || lowerName.contains('teto')) &&
            !lowerName.contains('szöktet') &&
            !lowerName.contains('szoktet') &&
            !lowerName.contains('etet'))) {
      return 'Tető';
    }

    if (lowerName == 'elem' || lowerName.isEmpty) {
      return 'Fészek';
    }
    return box.name.replaceAll(RegExp(r'\s*\(\s*\)'), '').trim();
  }

  // Segédfüggvény a tiszta, formázott fiókcímhez (pl. Fészek (DADANT), Tető, Tetőetető)
  String _getBoxFormattedTitle(BoxElement box) {
    String displayName = _getBoxDisplayName(box).replaceAll(RegExp(r'\s*\(\s*\)'), '').trim();
    final lowerSize = box.size.trim().toLowerCase().replaceAll(RegExp(r'[\(\)]'), '');
    final lowerName = displayName.toLowerCase();

    // Nem keretméret tartozékok esetén nem írunk ki felesleges méretet
    final nonFrameTypes = {
      'tető',
      'teto',
      'tetőetető',
      'eteto',
      'etető',
      'feeder',
      'roof',
      'aljdeszka',
      'bottom',
      'szellőző',
      'szellozo',
      'vent',
      'szöktető',
      'szokteto',
      'escapement',
      'pollengyűjtő',
      'pollen_trap',
      'trap',
      'kezelőlap hordozó',
      'treatment_strip',
      'anyarács',
      'queen_excluder',
    };

    if (nonFrameTypes.contains(lowerName) ||
        nonFrameTypes.contains(lowerSize) ||
        lowerSize.isEmpty ||
        lowerSize == 'elem') {
      return displayName;
    }

    // Ha Fészek vagy Méztér
    String sizeText = box.size.toUpperCase().replaceAll(RegExp(r'[\(\)]'), '').trim();
    if (displayName == 'Fészek') {
      if (lowerSize == 'fészek' || lowerSize.isEmpty || lowerSize == 'hunor') {
        sizeText = 'HUNOR';
      } else if (lowerSize.contains('dadant')) {
        sizeText = 'DADANT';
      }
    } else if (displayName == 'Méztér') {
      if (lowerSize.contains('1/2 dadant') ||
          lowerSize.contains('half_dadant') ||
          lowerSize.contains('fel_dadant')) {
        sizeText = '1/2 DADANT';
      } else if (lowerSize.contains('hunor')) {
        sizeText = 'HUNOR';
      }
    }

    if (sizeText.isEmpty || displayName.toUpperCase().contains(sizeText)) {
      return displayName;
    }

    return '$displayName ($sizeText)';
  }

  IconData _getBoxIcon(BoxElement box) {
    final lowerType = box.type.toLowerCase();
    final lowerName = _getBoxDisplayName(box).toLowerCase();

    if (lowerName.contains('szöktető') ||
        lowerType.contains('escapement') ||
        lowerType == '13') {
      return Icons.filter_alt;
    }
    if (lowerName.contains('tetőetető') ||
        lowerType.contains('feeder') ||
        lowerType == '10') {
      return Icons.water_drop;
    }
    if (lowerType.contains('roof') ||
        lowerName == 'tető' ||
        lowerName == 'teto' ||
        lowerName.contains('dekli') ||
        ((lowerName.contains('tető') || lowerName.contains('teto')) &&
            !lowerName.contains('szöktet') &&
            !lowerName.contains('szoktet') &&
            !lowerName.contains('etet'))) {
      return Icons.roofing;
    }
    if (lowerName.contains('pollen') ||
        lowerType.contains('trap') ||
        lowerType == '11') {
      return Icons.filter_vintage;
    }
    if (lowerName.contains('méz') ||
        lowerType.contains('honey') ||
        lowerType == '9') {
      return Icons.inventory_2;
    }
    if (lowerName.contains('anyarács') || lowerType.contains('excluder')) {
      return Icons.grid_4x4;
    }
    if (lowerName.contains('kezel') || lowerType.contains('strip')) {
      return Icons.medical_services;
    }
    return Icons.hive; // Fészek vagy alapértelmezett elem
  }

  @override
  Widget build(BuildContext context) {
    final HiveRepository repository = HiveRepository.instance;
    sortHiveBoxes(widget.hive.boxes);
    final displayedBoxes = widget.hive.boxes.reversed.toList();

    // Megkeressük a legalsó fészekfiókot
    BoxElement? bottomBroodBox;
    for (var b in widget.hive.boxes) {
      final name = _getBoxDisplayName(b).toLowerCase();
      if (b.type == 'brood_box' ||
          b.type == 'nest' ||
          name.contains('fészek') ||
          name.contains('feszek')) {
        bottomBroodBox = b;
        break;
      }
    }

    final double sheetHeight = MediaQuery.of(context).size.height * 0.88;
    return Material(
      color: const Color(0xFF0F172A),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
        children: [
          // Drag handle jelzés
          Center(
            child: Container(
              width: 46,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                Text(
                                  widget.hive.name,
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.hive.isLocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withAlpha(50),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amberAccent, width: 1.2),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lock, size: 12, color: Colors.amberAccent),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Zárolva: ${widget.hive.lockedDaysRemaining} nap',
                                          style: const TextStyle(color: Colors.amberAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.hive.isQueenReplacementActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withAlpha(50),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.redAccent, width: 1.2),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.female, size: 14, color: Colors.redAccent),
                                        SizedBox(width: 4),
                                        Text(
                                          'Anyacsere',
                                          style: TextStyle(color: Colors.redAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.hive.hasFeeder)
                                  _buildSyrupStatusBadge(widget.hive.feederStatus, isMini: true),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Család ID: ${widget.hive.id} | Kapott szirup: ${widget.hive.syrupLiters.toStringAsFixed(1)} L',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            if (widget.hive.serverConnection.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Kaptármonitor: ${widget.hive.serverConnection}',
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune, color: Colors.amberAccent),
                        tooltip: 'Torony Konfiguráció',
                        onPressed: widget.onConfigurePressed,
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),

                  _buildNextTaskCard(context, widget.hive, repository),
                  const SizedBox(height: 4),

                  _buildHealthStatusBanner(context, widget.hive, repository),
                  const SizedBox(height: 12),

            if (widget.hive.queen != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Méhanya: ${widget.hive.queen!.vintage}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Származás: ${widget.hive.queen!.origin} (${widget.hive.queen!.id})',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // --- ETETŐ & SZIRUPADAGOLÓ VEZÉRLÉS (CSAK HA VAN ETETŐ FELHELYEZVE) ---
            if (widget.hive.hasFeeder) ...[
              _buildFeederOverviewCard(context, widget.hive),
              const SizedBox(height: 16),
            ],

            if (bottomBroodBox == null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amberAccent.withAlpha(120)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.amberAccent, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Hiányos torony: Nincs fészekfiók rögzítve!',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          HelpBubbleButton(
                            title: 'Hiányzó fészekfiók',
                            message: 'A toronyban még nincs fészekfiók rögzítve. Kattints a jobb felső beállító gombra (tune ikon) fészekfiók hozzáadásához.',
                            iconColor: Colors.amberAccent,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Row(
              children: [
                const Text(
                  'Torony felépítése:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                HelpBubbleButton(
                  title: 'Kaptártorony fiókjai',
                  message: 'A torony elemei az aljdeszkától a tetőig. Bármelyik fiókra vagy elemre koppintva megnyithatod a dedikált vezérlőjét vagy beállításait.',
                  iconColor: Colors.white70,
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...displayedBoxes.map((box) {
              final displayName = _getBoxDisplayName(box);

              if (box.type == 'bottom' || displayName == 'Aljdeszka') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: box.isActive
                            ? Colors.deepOrange
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.dns_outlined,
                          color: box.isActive ? Colors.deepOrangeAccent : Colors.white54,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Aljdeszka',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  BoxInfoButton(box: box),
                                  const SizedBox(width: 4),
                                  BoxHelpButton(box: box),
                                ],
                              ),
                              if (box.isActive) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _getBottomBoardStatusText(box),
                                  style: TextStyle(
                                    color: box.statusUpdatedAt != null &&
                                            DateTime.now().difference(box.statusUpdatedAt!).inDays >= 3
                                        ? Colors.amberAccent
                                        : Colors.white60,
                                    fontSize: 10.5,
                                    fontWeight: box.statusUpdatedAt != null &&
                                            DateTime.now().difference(box.statusUpdatedAt!).inDays >= 3
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Switch(
                          value: box.isActive,
                          activeThumbColor: Colors.deepOrange,
                          onChanged: (val) {
                            setState(() {
                              repository.toggleBoxActiveState(
                                widget.hive,
                                box,
                                val,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              } else if (box.type == 'pollen_trap' ||
                  displayName == 'Pollengyűjtő') {
                void togglePollen(bool val) {
                  if (val && widget.hive.isWeakOrSick) {
                    showWeakColonyWarningDialog(
                      context: context,
                      hive: widget.hive,
                      actionTitle: 'Pollengyűjtő bekapcsolása',
                      onConfirm: () {
                        setState(() {
                          repository.toggleBoxActiveState(
                            widget.hive,
                            box,
                            true,
                          );
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Virágporgyűjtés bekapcsolva!'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                    );
                  } else {
                    setState(() {
                      repository.toggleBoxActiveState(
                        widget.hive,
                        box,
                        val,
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? 'Virágporgyűjtés bekapcsolva!'
                              : 'Virágporgyűjtés kikapcsolva',
                        ),
                        backgroundColor: val ? Colors.orange : Colors.teal,
                      ),
                    );
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => togglePollen(!box.isActive),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: box.isActive ? Colors.orange : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_vintage,
                              color: box.isActive ? Colors.amberAccent : Colors.white38,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    const Text(
                                      'Pollengyűjtő',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: box.isActive
                                            ? Colors.orange.withAlpha(50)
                                            : Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: box.isActive
                                              ? Colors.orange
                                              : Colors.white24,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        box.isActive ? 'AKTÍV' : 'INAKTÍV',
                                        style: TextStyle(
                                          color: box.isActive
                                              ? Colors.orangeAccent
                                              : Colors.white54,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    BoxInfoButton(box: box),
                                    const SizedBox(width: 4),
                                    BoxHelpButton(box: box),
                                  ],
                                ),
                              ),
                            ),
                            Switch(
                              value: box.isActive,
                              activeThumbColor: Colors.orange,
                              activeTrackColor: Colors.orange.withAlpha(120),
                              onChanged: togglePollen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                final bool isBottomBroodBox =
                    (bottomBroodBox != null && box.code == bottomBroodBox.code);
                final bool isFeeder = (displayName == 'Tetőetető' ||
                    displayName == 'Etető' ||
                    box.type == 'feeder' ||
                    box.type == 'roof_feeder');
                final bool isHoney = (displayName == 'Méztér' ||
                    box.type == 'honey' ||
                    box.type == '9');
                final bool isEscapement = (displayName == 'Szöktető' ||
                    box.type == 'escapement' ||
                    box.type == '13');

                // Bármely méztér VAGY felső fészekfiók leszöktethető (kivéve a legalsó fészekfiók)
                final bool canBeEscaped = (!isBottomBroodBox &&
                    !isFeeder &&
                    !isEscapement &&
                    box.type != 'roof' &&
                    box.type != 'bottom' &&
                    box.type != 'pollen_trap');

                final int escapementIndex = widget.hive.boxes.indexWhere(
                  (b) => b.type == 'escapement' || b.name.toLowerCase().contains('szöktet'),
                );
                final int currentBoxIndex = widget.hive.boxes.indexOf(box);
                final bool isDirectlyAboveEscapement =
                    (escapementIndex != -1 && currentBoxIndex == escapementIndex + 1);
                final bool isEscapedByBoard =
                    (escapementIndex != -1 && currentBoxIndex > escapementIndex && canBeEscaped);
                final bool isEscapementOverdue = isEscapement &&
                    box.statusUpdatedAt != null &&
                    DateTime.now().difference(box.statusUpdatedAt!).inMinutes >= 24 * 60;

                final IconData boxIcon = _getBoxIcon(box);
                final String boxTitle = _getBoxFormattedTitle(box);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: InkWell(
                    onTap: () {
                      if (isFeeder) {
                        _openFeederSettingsDialog(context, widget.hive);
                      } else if (isEscapement) {
                        // Szöktető kártyára kattintva nem nyitunk fészekfiókot
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => BroodBoxControlScreen(
                              hive: widget.hive,
                              broodBox: box,
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isEscapement
                              ? (isEscapementOverdue ? Colors.redAccent : Colors.amberAccent)
                              : (isEscapedByBoard
                                  ? Colors.orangeAccent
                                  : Colors.amberAccent.withAlpha(140)),
                          width: (isDirectlyAboveEscapement || isEscapement) ? 2.0 : 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isEscapement) ...[
                            // 1. Sor: Ikon, Cím, Info/Help gombok és Visszaszámláló
                            Row(
                              children: [
                                Icon(
                                  boxIcon,
                                  color: isEscapementOverdue ? Colors.redAccent : Colors.amberAccent,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  boxTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                BoxInfoButton(box: box),
                                const SizedBox(width: 4),
                                BoxHelpButton(box: box),
                                const Spacer(),
                                _buildEscapementCountdown(box),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // 2. Sor: Teljes szélességű műveleti gombok (nem törnek meg, nem lógnak túl)
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 38,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.tealAccent,
                                        foregroundColor: const Color(0xFF0F172A),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      onPressed: () => _showFinishEscapementConfirmation(
                                        context,
                                        widget.hive,
                                        repository,
                                      ),
                                      icon: const Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: Color(0xFF0F172A),
                                      ),
                                      label: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Szöktetés kész',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 38,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: BorderSide(
                                          color: Colors.redAccent.withAlpha(160),
                                          width: 1.2,
                                        ),
                                        backgroundColor: Colors.red.withAlpha(25),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                      ),
                                      onPressed: () {
                                        repository.removeBoxFromHive(widget.hive, box);
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Szöktető eltávolítva a kaptárból (fiókok a toronyban maradtak).',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 15,
                                        color: Colors.redAccent,
                                      ),
                                      label: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Kivétel',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Nem szöktető fiókok sora
                            Row(
                              children: [
                                if (isFeeder)
                                  CandyIcon(
                                    size: 22,
                                    status: widget.hive.feederStatus,
                                  )
                                else
                                  Icon(
                                    boxIcon,
                                    color: (box.type == 'roof'
                                        ? Colors.tealAccent
                                        : isEscapedByBoard
                                            ? Colors.orangeAccent
                                            : Colors.amberAccent),
                                    size: 22,
                                  ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          boxTitle,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      BoxInfoButton(box: box),
                                      const SizedBox(width: 2),
                                      BoxHelpButton(box: box),
                                    ],
                                  ),
                                ),
                                if (canBeEscaped) ...[
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        repository.insertEscapeBoardUnderBox(
                                          widget.hive,
                                          box,
                                        );
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Leszöktetés elindítva: Szöktető behelyezve a(z) "$boxTitle" alá!\n'
                                              'A felette levő mézterek max. 24 órán belül elveendők.',
                                            ),
                                            backgroundColor: Colors.teal,
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 5,
                                        ),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: isDirectlyAboveEscapement
                                              ? Colors.orangeAccent
                                              : (isEscapedByBoard
                                                  ? Colors.orange.shade400
                                                  : Colors.orange.withAlpha(30)),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.orangeAccent,
                                            width: isDirectlyAboveEscapement ? 1.8 : 1.2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isDirectlyAboveEscapement
                                                  ? Icons.check_circle
                                                  : (isEscapedByBoard
                                                      ? Icons.filter_alt
                                                      : Icons.filter_alt_outlined),
                                              color: isEscapedByBoard
                                                  ? const Color(0xFF0F172A)
                                                  : Colors.orangeAccent,
                                              size: 15,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isDirectlyAboveEscapement
                                                  ? 'Szöktető alatt ✓'
                                                  : (isEscapedByBoard
                                                      ? 'Leszöktetve'
                                                      : 'Leszöktetés'),
                                              style: TextStyle(
                                                color: isEscapedByBoard
                                                    ? const Color(0xFF0F172A)
                                                    : Colors.orangeAccent,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const Icon(
                                  Icons.open_in_full,
                                  color: Colors.amberAccent,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],

                          if (isBottomBroodBox) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(color: Colors.white24, height: 1),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSensorBadge(
                                    Icons.thermostat,
                                    '${widget.hive.temp.toStringAsFixed(1)} °C',
                                    Colors.amber,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSensorBadge(
                                    Icons.water_drop,
                                    '${widget.hive.humidity.toStringAsFixed(0)} %',
                                    Colors.lightBlueAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSensorBadge(
                                    Icons.mic,
                                    '${widget.hive.zcr.toStringAsFixed(0)} Hz',
                                    Colors.purpleAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSensorBadge(
                                    Icons.battery_full,
                                    '${widget.hive.batteryVoltage.toStringAsFixed(2)} V',
                                    Colors.tealAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSensorBadge(
                                    Icons.scale,
                                    '${widget.hive.weight.toStringAsFixed(1)} kg',
                                    Colors.greenAccent,
                                  ),
                                ],
                              ),
                            ),
                          ] else if (isFeeder) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(color: Colors.white24, height: 1),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CandyIcon(
                                        size: 16,
                                        status: widget.hive.feederStatus,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Szint: ${widget.hive.feederLevelPercent.toInt()}%',
                                        style: TextStyle(
                                          color: getSyrupStatusColor(widget.hive.feederStatus),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSensorBadge(
                                    widget.hive.feedingMode == 'auto_stim'
                                        ? Icons.auto_mode
                                        : (widget.hive.feedingMode == 'manual'
                                            ? Icons.touch_app
                                            : Icons.power_settings_new),
                                    widget.hive.feedingMode == 'auto_stim'
                                        ? 'Serkentés (${widget.hive.feedingMaxLiters.toStringAsFixed(1)}L / ${widget.hive.feedingIntervalDays} nap)'
                                        : (widget.hive.feedingMode == 'manual'
                                            ? 'Kézi feletetés (max ${widget.hive.feedingMaxLiters.toStringAsFixed(1)}L)'
                                            : 'Kikapcsolva'),
                                    widget.hive.feedingMode == 'auto_stim'
                                        ? Colors.tealAccent
                                        : (widget.hive.feedingMode == 'manual'
                                            ? Colors.lightBlueAccent
                                            : Colors.white60),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }
            }),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wb_sunny, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Időjárás-állomás: ${widget.hive.extTemp} °C (${widget.hive.extHumidity}%)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  ],
),
),
),
);
  }

  Widget _buildSensorBadge(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNextTaskCard(
    BuildContext context,
    HiveData hive,
    HiveRepository repository,
  ) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> allTasks = [];

    // 1. Ütemezett feladatok a repóból
    for (var t in repository.scheduledTasks) {
      if (t.hiveId == hive.id && !t.isCompleted) {
        if (t.id.contains('ESCAPEMENT') || t.title.contains('Méhszöktetés')) {
          continue;
        }
        allTasks.add({
          'id': t.id,
          'title': t.title,
          'description': t.description,
          'date': t.scheduledDate,
          'type': 'scheduled',
          'task': t,
        });
      }
    }

    // 0. Aktív méhszöktetés (mindent megelőző prioritás: max 24 órán belüli fiókelvétel)
    final int escapementIndex = hive.boxes.indexWhere(
      (b) => b.type == 'escapement' || b.name.toLowerCase().contains('szöktet'),
    );
    if (escapementIndex != -1) {
      final escapementBox = hive.boxes[escapementIndex];
      final startTime = escapementBox.statusUpdatedAt ?? now;
      final dueDate = startTime.add(const Duration(hours: 24));
      allTasks.insert(0, {
        'id': 'ESCAPEMENT_${escapementBox.code}',
        'title': 'Leszöktetett fiókok elvétele',
        'description':
            'A méhszöktető méhteleníti a felrakott méztereket. 24 órán belül el kell venni a méztereket a kaptárról!',
        'date': dueDate,
        'type': 'escapement_harvest',
        'box': escapementBox,
      });
    }

    // 2. Aljdeszka Varroa 3 napos ellenőrzés
    for (var box in hive.boxes) {
      if (box.type == 'bottom' && box.isActive) {
        final start = box.statusUpdatedAt ?? now.subtract(const Duration(days: 1));
        final dueDate = start.add(const Duration(days: 3));
        allTasks.add({
          'id': 'BOTTOM_${box.code}',
          'title': 'Aljdeszka Varroa ellenőrzés & tisztítás',
          'description':
              'Az atkavizsgáló tálca kihúzása, lehullott atkák számlálása és a tálca lefertőtlenítése.',
          'date': dueDate,
          'type': 'bottom_board',
          'box': box,
        });
      }
    }

    // 3. Etető utántöltés
    if (hive.hasFeeder &&
        hive.feederLevelPercent <= 20.0 &&
        hive.feedingMode != 'off') {
      allTasks.add({
        'id': 'FEEDER_${hive.id}',
        'title': 'Tetőetető szirup utántöltése',
        'description':
            'A szirupszint kritikusan alacsony (${hive.feederLevelPercent.toInt()}%), utántöltés szükséges.',
        'date': now,
        'type': 'feeder_refill',
      });
    }

    // 5. Sürgős fészekellenőrzés
    if (hive.worstStatus == 'red' || hive.worstStatus == 'flashing_red') {
      allTasks.add({
        'id': 'URGENT_${hive.id}',
        'title': 'Azonnali fészekvizsgálat & Családmentés',
        'description':
            'Kritikus fészekhőmérséklet vagy hirtelen súlycsökkenés miatt sürgős beavatkozás indokolt.',
        'date': now,
        'type': 'urgent_check',
      });
    }

    // Időrendi sorrendbe rendezzük a legkorábbi teendőt előre
    allTasks.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Ha nincs betervezett feladat
    if (allTasks.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.event_available,
                  color: Colors.greenAccent,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Következő teendő: Nincs ütemezve',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'A családnál minden feladat naprakész.',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!hive.hasExtraBoxes) ...[
              const SizedBox(height: 12),
              _buildGloveFriendlyActionButtons(context, hive, repository),
            ],
          ],
        ),
      );
    }

    final next = allTasks.first;
    final DateTime targetDate = next['date'] as DateTime;
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final diffDays = targetDay.difference(today).inDays;

    String dueBadgeText;
    Color badgeColor;
    Color borderColor;
    Color cardBg;
    IconData taskIcon = Icons.alarm;

    final String timeStr =
        '${targetDate.hour.toString().padLeft(2, '0')}:${targetDate.minute.toString().padLeft(2, '0')}';

    if (next['type'] == 'escapement_harvest') {
      final escapementBox = next['box'] as BoxElement;
      final startTime = escapementBox.statusUpdatedAt ?? now;
      final elapsedSec = now.difference(startTime).inSeconds;
      final remainingSec = (24 * 3600) - elapsedSec;
      if (remainingSec <= 0) {
        dueBadgeText = '24h LEJÁRT! AZONNAL!';
        badgeColor = Colors.redAccent;
        borderColor = Colors.redAccent;
        cardBg = const Color(0xFF7F1D1D).withAlpha(140);
        taskIcon = Icons.warning_rounded;
      } else {
        final remainingHours = (remainingSec + 3599) ~/ 3600;
        dueBadgeText = 'MÉG ~$remainingHours ÓRA (MAX. 24h)';
        badgeColor = Colors.tealAccent;
        borderColor = Colors.tealAccent;
        cardBg = const Color(0xFF134E4A).withAlpha(140);
        taskIcon = Icons.hourglass_top_rounded;
      }
    } else if (diffDays < 0) {
      dueBadgeText = 'LEJÁRT (${diffDays.abs()} napja késik!)';
      badgeColor = Colors.redAccent;
      borderColor = Colors.redAccent;
      cardBg = const Color(0xFF7F1D1D).withAlpha(140);
      taskIcon = Icons.assignment_late;
    } else if (diffDays == 0) {
      dueBadgeText = 'MA ESEDÉKES! ($timeStr)';
      badgeColor = Colors.amberAccent;
      borderColor = Colors.amberAccent;
      cardBg = const Color(0xFF78350F).withAlpha(140);
      taskIcon = Icons.notification_important;
    } else if (diffDays == 1) {
      dueBadgeText = 'HOLNAP esedékes ($timeStr)';
      badgeColor = Colors.orangeAccent;
      borderColor = Colors.orangeAccent;
      cardBg = const Color(0xFF7C2D12).withAlpha(120);
      taskIcon = Icons.today;
    } else if (diffDays <= 3) {
      dueBadgeText = '$diffDays nap múlva (${targetDate.month}.${targetDate.day})';
      badgeColor = Colors.cyanAccent;
      borderColor = Colors.cyanAccent;
      cardBg = const Color(0xFF164E63).withAlpha(120);
      taskIcon = Icons.event;
    } else {
      dueBadgeText = '${targetDate.month}.${targetDate.day} ($diffDays nap múlva)';
      badgeColor = Colors.lightBlueAccent;
      borderColor = Colors.lightBlueAccent.withAlpha(160);
      cardBg = const Color(0xFF1E293B);
      taskIcon = Icons.calendar_month;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(taskIcon, color: badgeColor, size: 17),
              const SizedBox(width: 6),
              const Text(
                'KÖVETKEZŐ TEENDŐ',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withAlpha(140)),
                  ),
                  child: Text(
                    dueBadgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            next['title'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            next['description'] as String,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                final type = next['type'] as String;
                if (type == 'escapement_harvest') {
                  _showFinishEscapementConfirmation(context, hive, repository);
                } else if (type == 'scheduled') {
                  final task = next['task'] as ScheduledTask;
                  setState(() {
                    task.isCompleted = true;
                  });
                  repository.completeTask(task.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Feladat készre jelentve: ${next['title']}'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                } else if (type == 'bottom_board') {
                  final box = next['box'] as BoxElement;
                  setState(() {
                    repository.toggleBoxActiveState(hive, box, false);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Feladat készre jelentve: ${next['title']}'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              },
              icon: Icon(
                next['type'] == 'escapement_harvest'
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline,
                size: 20,
                color: const Color(0xFF0F172A),
              ),
              label: Text(
                next['type'] == 'escapement_harvest'
                    ? 'Szöktetés kész (fiókok elvétele)'
                    : 'Feladat készre jelentése',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: next['type'] == 'escapement_harvest'
                    ? Colors.tealAccent
                    : Colors.greenAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (!hive.hasExtraBoxes) ...[
            const SizedBox(height: 12),
            _buildGloveFriendlyActionButtons(context, hive, repository),
          ],
        ],
      ),
    );
  }

  Widget _buildGloveFriendlyActionButtons(
    BuildContext context,
    HiveData hive,
    HiveRepository repository,
  ) {
    if (hive.hasExtraBoxes) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.lightBlueAccent,
                side: const BorderSide(color: Colors.lightBlueAccent, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => InvestigationsScreen.open(context, hive, repository),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 24, color: Colors.lightBlueAccent),
                  SizedBox(width: 8),
                  Text(
                    'Vizsgálatok',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.orangeAccent,
                side: const BorderSide(color: Colors.orangeAccent, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => TreatmentsScreen.open(context, hive, repository),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services, size: 24, color: Colors.orangeAccent),
                  SizedBox(width: 8),
                  Text(
                    'Kezelések',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddTaskDialog(
    BuildContext context,
    HiveData hive,
    HiveRepository repository,
  ) {
    String selectedCategory = 'oxalic';
    String taskTitle = 'Oxálsavas szublimálás';
    String taskDescription = 'Oxálsav gőzölése a füstölő nyíláson át (2g adag).';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    final titleController = TextEditingController(text: taskTitle);
    final descController = TextEditingController(text: taskDescription);

    final presetTasks = [
      {
        'title': 'Oxálsavas szublimálás',
        'desc': 'Oxálsav gőzölése a füstölő nyíláson át (2g adag).',
        'cat': 'oxalic',
      },
      {
        'title': 'Fészekvizsgálat & Átnézés',
        'desc': 'Fiasításkép, anya jelenléte, petézés és élelem ellenőrzése.',
        'cat': 'inspection',
      },
      {
        'title': 'Méztér felhelyezése / Fiókbővítés',
        'desc': 'Új fiók vagy anyarács felhelyezése a hordás támogatására.',
        'cat': 'expansion',
      },
      {
        'title': 'Serkentő etetés (szirup)',
        'desc': 'Tetőetető feltöltése 1:1 arányú sziruppal (max 1.5 L).',
        'cat': 'feeding',
      },
      {
        'title': 'Aljdeszka Varroa leolvasás',
        'desc': 'Atkahullás számlálása, tálca tisztítása és fertőtlenítése.',
        'cat': 'varroa_check',
      },
      {
        'title': 'Méhanya állapotfelmérés / Csere',
        'desc': 'Anyabölcsők keresése, anya petézési mintázatának értékelése.',
        'cat': 'queen',
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.amberAccent, width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.add_task, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Új teendő – ${hive.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gyakori feladattípusok:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF0F172A),
                      value: taskTitle,
                      items: presetTasks.map((t) {
                        return DropdownMenuItem<String>(
                          value: t['title'],
                          child: Text(
                            t['title']!,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final match = presetTasks.firstWhere((e) => e['title'] == val);
                          setDialogState(() {
                            taskTitle = match['title']!;
                            taskDescription = match['desc']!;
                            selectedCategory = match['cat']!;
                            titleController.text = taskTitle;
                            descController.text = taskDescription;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Feladat megnevezése',
                        labelStyle: TextStyle(color: Colors.amberAccent),
                      ),
                      onChanged: (val) => taskTitle = val,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Leírás / utasítások',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                      maxLines: 2,
                      onChanged: (val) => taskDescription = val,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Esedékesség időpontja:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '${selectedDate.year}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, color: Colors.amberAccent),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogCtx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  9,
                                  0,
                                );
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Mégse', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newTask = ScheduledTask(
                      id: 'TASK_${hive.id}_${DateTime.now().millisecondsSinceEpoch}',
                      hiveId: hive.id,
                      category: selectedCategory,
                      title: taskTitle.trim().isNotEmpty ? taskTitle : 'Egyedi teendő',
                      description: taskDescription,
                      scheduledDate: selectedDate,
                      isCompleted: false,
                    );
                    repository.addScheduledTask(newTask);
                    Navigator.pop(dialogCtx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Feladat ütemezve: ${newTask.title}'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
                  child: const Text('Rögzítés', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHealthStatusBanner(
    BuildContext context,
    HiveData hive,
    HiveRepository repository,
  ) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> diagnosticIssues = [];

    // 1. Kézi státusz beállítás
    if (hive.status == 'yellow') {
      diagnosticIssues.add({
        'icon': Icons.palette_outlined,
        'title': 'Kézi státusz besorolás: Sárga (Gyenge / Megfigyelendő)',
        'isManualStatus': true,
      });
    } else if (hive.status == 'orange') {
      diagnosticIssues.add({
        'icon': Icons.palette_outlined,
        'title': 'Kézi státusz besorolás: Narancs (Kezelés alatt / Tartalék)',
        'isManualStatus': true,
      });
    } else if (hive.status == 'purple') {
      diagnosticIssues.add({
        'icon': Icons.palette_outlined,
        'title': 'Kézi státusz besorolás: Lila (Rajzás / Kísérleti)',
        'isManualStatus': true,
      });
    } else if (hive.status == 'red' || hive.status == 'flashing_red') {
      diagnosticIssues.add({
        'icon': Icons.warning_amber_rounded,
        'title': 'Kézi státusz besorolás: Piros (Kritikus vészhelyzet)',
        'isManualStatus': true,
      });
    }

    // 2. Csak a lejárt, késésben lévő teendők számítanak figyelmeztetésnek (nem a betervezett jövőbeli feladatok!)
    final overdueTasks = repository.scheduledTasks.where((t) {
      if (t.hiveId != hive.id || t.isCompleted) return false;
      if (t.id.contains('ESCAPEMENT') || t.title.contains('Méhszöktetés')) {
        return false;
      }
      return t.scheduledDate.isBefore(now);
    }).toList();

    for (var t in overdueTasks) {
      diagnosticIssues.add({
        'icon': Icons.assignment_late,
        'title':
            'Késésben lévő feladat: ${t.title} (${t.scheduledDate.month}.${t.scheduledDate.day})',
        'isManualStatus': false,
      });
    }

    // 3. Fészekfiók jelenléte a toronyban
    final bool hasBrood = hive.boxes.any(
      (b) =>
          b.type == 'brood_box' ||
          b.type == 'nest' ||
          b.name.toLowerCase().contains('fészek'),
    );
    if (!hasBrood) {
      diagnosticIssues.add({
        'icon': Icons.error_outline,
        'title': 'Hiányos torony: Nincs fészekfiók hozzárendelve a kaptárhoz!',
        'isManualStatus': false,
      });
    }

    // 4. Szenzoros eltérések
    if (hive.tempStatus != 'green') {
      diagnosticIssues.add({
        'icon': Icons.thermostat,
        'title':
            'Fészekhőmérséklet eltérés: ${hive.temp.toStringAsFixed(1)} °C (Optimális: 34.0 - 36.0 °C)',
        'isManualStatus': false,
      });
    }

    if (hive.weightStatus != 'green') {
      diagnosticIssues.add({
        'icon': Icons.scale,
        'title':
            'Kaptársúly / Élelemtartalék figyelmeztetés: ${hive.weight.toStringAsFixed(1)} kg (Optimális: >= 30.0 kg)',
        'isManualStatus': false,
      });
    }

    if (hive.micStatus != 'green') {
      diagnosticIssues.add({
        'icon': Icons.mic,
        'title':
            'Méhzúgás frekvencia eltérés: ${hive.zcr.toStringAsFixed(0)} Hz (Nyugodt család: 3000 - 4200 Hz)',
        'isManualStatus': false,
      });
    }

    if (hive.batteryStatus != 'green') {
      diagnosticIssues.add({
        'icon': Icons.battery_alert,
        'title':
            'Alacsony akkumulátor feszültség: ${hive.batteryVoltage.toStringAsFixed(2)} V',
        'isManualStatus': false,
      });
    }

    if (hive.signalStatus != 'green') {
      diagnosticIssues.add({
        'icon': Icons.wifi_off,
        'title': 'Kaptármonitor kapcsolat: ${hive.serverConnection}',
        'isManualStatus': false,
      });
    }

    // 5. Varroa és kártevők
    if (hive.dailyVarroaDrop >= 2.0) {
      diagnosticIssues.add({
        'icon': Icons.bug_report,
        'title':
            'Magas napi atkahullás: ${hive.dailyVarroaDrop.toStringAsFixed(1)} db/nap (Küszöbérték: < 2 db/nap)',
        'isManualStatus': false,
      });
    }

    if (hive.boxes.any((b) => b.isVarroaCheckDue)) {
      diagnosticIssues.add({
        'icon': Icons.event_busy,
        'title':
            'Atkavizsgáló aljdeszka bent van > 3 napja (leolvasás esedékes)',
        'isManualStatus': false,
      });
    }

    // 6. Hardver és beavatkozások
    if (hive.boxes.any((b) => b.type == 'pollen_trap' && b.isActive)) {
      diagnosticIssues.add({
        'icon': Icons.filter_vintage,
        'title':
            'Aktív pollengyűjtő rács bekapcsolva (korlátozza a virágpor behordást)',
        'isManualStatus': false,
      });
    }

    if (hive.swarmIndex >= 70.0) {
      diagnosticIssues.add({
        'icon': Icons.warning_rounded,
        'title':
            'Magas rajzási hajlam index: ${hive.swarmIndex.toStringAsFixed(0)}%',
        'isManualStatus': false,
      });
    }

    if (hive.isQueenReplacementActive) {
      diagnosticIssues.add({
        'icon': Icons.emergency,
        'title':
            '🚨 Sürgős Anyacsere folyamatban: ${hive.queenReplacementState == 'needs_replacement' ? 'Anya eltávolításra vár' : 'Anya eltávolítva (Anyátlan család)'}',
        'isManualStatus': false,
      });
    } else if (hive.queen?.needsReplacement == true) {
      diagnosticIssues.add({
        'icon': Icons.star_border,
        'title': 'Anyacsere javasolt (méhanya kora vagy minősége miatt)',
        'isManualStatus': false,
      });
    }

    if (hive.isLocked) {
      diagnosticIssues.add({
        'icon': Icons.lock,
        'title':
            '🔒 Kaptár Zárolva (${hive.lockedDaysRemaining} napig: Kirágós anya, Ne nyúlj hozzá!)',
        'isManualStatus': false,
      });
    }

    if (hive.protocol != null && hive.protocol!.isNotEmpty) {
      diagnosticIssues.add({
        'icon': Icons.healing,
        'title': 'Aktív protokoll: ${hive.protocol}',
        'isManualStatus': false,
      });
    }

    final bool isAllGreen =
        diagnosticIssues.isEmpty && hive.worstStatus == 'green';

    // Ha teljesen zöld és nincs semmilyen probléma
    if (isAllGreen) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hive.hasExtraBoxes
              ? null
              : () => _openColonyClassificationDialog(context, hive, repository),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF064E3B).withAlpha(120),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withAlpha(160)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Család állapota: Egészséges & Optimális (Zöld)',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          HelpBubbleButton(
                            title: 'Egészséges kaptárállapot',
                            message: 'Minden mért szenzor, kaptárelem és betervezett teendő optimális rendben van.\n\nAkusztikai monitor: Nyugodt méhzúgás (${hive.zcr.toStringAsFixed(0)} Hz).',
                            iconColor: Colors.greenAccent,
                            size: 15,
                          ),
                          if (!hive.hasExtraBoxes) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tune,
                                    size: 11,
                                    color: Colors.greenAccent,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Osztályozás',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Ha nem zöld, színek és ikonok kiválasztása
    Color themeColor = Colors.amber;
    Color bgColor = const Color(0xFF78350F).withAlpha(110);
    String statusLabel = 'Figyelmet igénylő (Sárga)';
    IconData mainIcon = Icons.info_outline;

    final effStatus = hive.worstStatus;
    if (effStatus == 'red' || effStatus == 'flashing_red') {
      themeColor = Colors.redAccent;
      bgColor = const Color(0xFF7F1D1D).withAlpha(130);
      statusLabel = 'Kritikus vészjelzés (Piros)';
      mainIcon = Icons.warning_rounded;
    } else if (effStatus == 'orange') {
      themeColor = Colors.orangeAccent;
      bgColor = const Color(0xFF7C2D12).withAlpha(120);
      statusLabel = 'Kezelés / Korlátozás aktív (Narancs)';
      mainIcon = Icons.notifications_active;
    } else if (effStatus == 'purple') {
      themeColor = Colors.purpleAccent;
      bgColor = const Color(0xFF581C87).withAlpha(120);
      statusLabel = 'Rajzáskészültség / Kísérleti (Lila)';
      mainIcon = Icons.warning_amber_rounded;
    }

    final bool hasManualStatusIssue =
        diagnosticIssues.any((i) => i['isManualStatus'] == true);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hive.hasExtraBoxes
            ? null
            : () => _openColonyClassificationDialog(context, hive, repository),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor.withAlpha(190), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(mainIcon, color: themeColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Család állapota: $statusLabel',
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  HelpBubbleButton(
                    title: 'Diagnosztikai besorolás',
                    message: 'A kaptár jelenlegi állapota: $statusLabel.\n\nA státuszt a beépített fiókok, az aktív rácsok, a mért szenzoradatok vagy a kézi osztályozás határozza meg.',
                    iconColor: themeColor,
                    size: 15,
                  ),
                  if (!hive.hasExtraBoxes) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: themeColor.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, size: 11, color: themeColor),
                          const SizedBox(width: 4),
                          Text(
                            'Osztályozás',
                            style: TextStyle(
                              color: themeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 6),
              ...diagnosticIssues.map((issue) {
                final String title = issue['title'] as String;
                final bool isPollenIssue = title.contains('pollengyűjtő');
                final bool isBroodIssue = title.contains('Nincs fészekfiók');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(issue['icon'] as IconData, color: themeColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      if (isPollenIssue) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            BoxElement? pBox;
                            for (var b in hive.boxes) {
                              if (b.type == 'pollen_trap' ||
                                  b.name.toLowerCase().contains('pollen') ||
                                  b.name.toLowerCase().contains('virágpor')) {
                                pBox = b;
                                break;
                              }
                            }
                            if (pBox != null) {
                              setState(() {
                                repository.toggleBoxActiveState(hive, pBox!, false);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pollengyűjtő rács kikapcsolva!'),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(50),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orangeAccent, width: 1.2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.power_settings_new, size: 12, color: Colors.orangeAccent),
                                SizedBox(width: 4),
                                Text(
                                  'Kikapcsolás',
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (isBroodIssue) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            final newBrood = BoxElement(
                              name: 'Fészekfiók',
                              code: '${hive.id}_BROOD_01',
                              type: 'brood_box',
                              size: 'hunor',
                              status: 'green',
                              isActive: true,
                            );
                            setState(() {
                              repository.addBoxToHive(hive, newBrood);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fészekfiók sikeresen hozzáadva a toronyhoz!'),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(50),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amberAccent, width: 1.2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline, size: 12, color: Colors.amberAccent),
                                SizedBox(width: 4),
                                Text(
                                  '+ Fészekfiók',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (hasManualStatusIssue) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        widget.hive.status = 'green';
                      });
                      repository.updateHive(widget.hive);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'A kaptár kézi státusza Zöldre állítva!',
                          ),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check, size: 16, color: Colors.black),
                    label: const Text(
                      'Kézi státusz azonnali zöldre állítása',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openColonyClassificationDialog(
    BuildContext context,
    HiveData hive,
    HiveRepository repository,
  ) {
    String selectedFunctionMenu = 'termeles';
    if (['dajka', 'anya', 'tartalék'].contains(hive.familyFunction)) {
      selectedFunctionMenu = 'anyaneveles';
    } else if (['selejt', 'Hans'].contains(hive.familyFunction) ||
        hive.isQueenReplacementActive ||
        hive.isLocked) {
      selectedFunctionMenu = 'selejtezes';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final statuses = [
              {
                'key': 'green',
                'label': 'Zöld – Egészséges & Optimális',
                'color': Colors.greenAccent,
                'icon': Icons.check_circle_rounded,
                'desc': 'Minden mért szenzor, fiók és feladat rendben van.',
              },
              {
                'key': 'yellow',
                'label': 'Sárga – Figyelmet igénylő',
                'color': Colors.amber,
                'icon': Icons.info_outline,
                'desc': 'Megfigyelendő paraméterek (pl. zúgás, aljdeszka leolvasás).',
              },
              {
                'key': 'orange',
                'label': 'Narancs – Kezelés alatt / Korlátozás',
                'color': Colors.orangeAccent,
                'icon': Icons.notifications_active,
                'desc': 'Aktív gyógykezelés, serkentés vagy méhszöktetés.',
              },
              {
                'key': 'purple',
                'label': 'Lila – Rajzáskészültség (>4700 Hz)',
                'color': Colors.purpleAccent,
                'icon': Icons.warning_amber_rounded,
                'desc': 'Akusztikai rajzási figyelmeztetés vagy kísérleti család.',
              },
              {
                'key': 'red',
                'label': 'Piros – Kritikus vészhelyzet',
                'color': Colors.redAccent,
                'icon': Icons.warning_rounded,
                'desc': 'Azonnali beavatkozást igénylő krízis (súlyvesztés, kihűlés).',
              },
            ];

            // 3 FŐ KATEGÓRIA (Termelés, Anyanevelés, Selejtezés - "Gyenge család" törölve!)
            final productionFunctions = [
              {
                'id': 'méz',
                'name': 'Termelő (Méz)',
                'desc': 'Főhordás & mézgyűjtés',
                'icon': Icons.breakfast_dining,
                'color': Colors.amberAccent,
              },
              {
                'id': 'pollen',
                'name': 'Pollengyűjtő',
                'desc': 'Virágpor behordás & gyűjtés',
                'icon': Icons.spa,
                'color': Colors.orangeAccent,
              },
              {
                'id': 'propolisz',
                'name': 'Propoliszos',
                'desc': 'Propolisz rács & termelés',
                'icon': Icons.texture,
                'color': Colors.amber.shade700,
              },
            ];

            final queenBreedingFunctions = [
              {
                'id': 'dajka',
                'name': 'Dajkacsalád',
                'desc': 'Pempőzés & anyanevelés',
                'icon': Icons.child_care,
                'color': Colors.cyanAccent,
              },
              {
                'id': 'anya',
                'name': 'Tenyész (Anya/Apa)',
                'desc': 'Törzsállomány & génbank',
                'icon': Icons.workspace_premium,
                'color': Colors.amber,
              },
              {
                'id': 'tartalék',
                'name': 'Tartalék / Raj',
                'desc': 'Kölyökcsalád / tartalék anya',
                'icon': Icons.inventory_2_outlined,
                'color': Colors.lightGreenAccent,
              },
            ];

            final cullingFunctions = [
              {
                'id': 'selejt',
                'name': 'Selejt család',
                'desc': 'Szezon végén mások felerősítésére / egyesítés',
                'icon': Icons.call_merge,
                'color': Colors.deepOrangeAccent,
              },
              {
                'id': 'Hans',
                'name': 'Hans-protokoll',
                'desc': 'Súlyos fertőzés miatti azonnali elpusztítás!',
                'icon': Icons.local_fire_department,
                'color': Colors.redAccent,
              },
            ];

            List<Map<String, dynamic>> currentFunctions;
            if (selectedFunctionMenu == 'anyaneveles') {
              currentFunctions = queenBreedingFunctions;
            } else if (selectedFunctionMenu == 'selejtezes') {
              currentFunctions = cullingFunctions;
            } else {
              currentFunctions = productionFunctions;
            }

            return Material(
              color: const Color(0xFF0F172A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.92,
                child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.assessment_rounded, color: Colors.amberAccent, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Család állapota & Funkciója',
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${hive.name} (${hive.id})',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 24),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // --- 1. CSALÁDFUNKCIÓ MÓDOSÍTÁSA (3 BOKSZKESZTYŰ-BARÁT MENÜPONT) ---
                        const Row(
                          children: [
                            Icon(Icons.work_outline, color: Colors.amberAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '1. Család funkciójának módosítása:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 3 FŐ MENÜPONT GOMB (Bokszkesztyű-barát, nagy gombok)
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => selectedFunctionMenu = 'termeles'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: selectedFunctionMenu == 'termeles'
                                        ? Colors.amber.withAlpha(50)
                                        : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedFunctionMenu == 'termeles'
                                          ? Colors.amberAccent
                                          : Colors.white24,
                                      width: selectedFunctionMenu == 'termeles' ? 2.5 : 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '🍯 Termelés',
                                      style: TextStyle(
                                        color: selectedFunctionMenu == 'termeles'
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: selectedFunctionMenu == 'termeles'
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => selectedFunctionMenu = 'anyaneveles'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: selectedFunctionMenu == 'anyaneveles'
                                        ? Colors.cyan.withAlpha(50)
                                        : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedFunctionMenu == 'anyaneveles'
                                          ? Colors.cyanAccent
                                          : Colors.white24,
                                      width: selectedFunctionMenu == 'anyaneveles' ? 2.5 : 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '👑 Anyanevelés',
                                      style: TextStyle(
                                        color: selectedFunctionMenu == 'anyaneveles'
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: selectedFunctionMenu == 'anyaneveles'
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => selectedFunctionMenu = 'selejtezes'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: selectedFunctionMenu == 'selejtezes'
                                        ? Colors.deepOrange.withAlpha(50)
                                        : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedFunctionMenu == 'selejtezes'
                                          ? Colors.deepOrangeAccent
                                          : Colors.white24,
                                      width: selectedFunctionMenu == 'selejtezes' ? 2.5 : 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '⚠️ Selejtezés',
                                      style: TextStyle(
                                        color: selectedFunctionMenu == 'selejtezes'
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: selectedFunctionMenu == 'selejtezes'
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // FUNKCIÓK A KIVÁLASZTOTT MENÜ ALATT (SZÉLES, KESZTYŰBARÁT KÁRTYÁK)
                        ...currentFunctions.map((cat) {
                          final bool isSel = hive.familyFunction == cat['id'];
                          final Color catColor = cat['color'] as Color;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                if (cat['id'] == 'Hans') {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        side: const BorderSide(color: Colors.redAccent, width: 2),
                                      ),
                                      title: const Row(
                                        children: [
                                          Icon(
                                            Icons.local_fire_department,
                                            color: Colors.redAccent,
                                            size: 30,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Figyelem: Hans-protokoll!',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: const Text(
                                        'A Hans nem egy selejt család, hanem AZONNALI ÉS TELJES ELPUSZTÍTÁST jelent!\n\nAlkalmazása: Súlyos, fertőző betegség (pl. nyúlós költésrothadás) miatti kénlapos megsemmisítés.\n\nEbből a kaptárból szigorúan TILOS fiasítást, keretet vagy népet átadni más családoknak!\n\nBiztosan elpusztításra jelölöd ezt a családot?',
                                        style: TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Mégse', style: TextStyle(color: Colors.grey)),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            setModalState(() {
                                              hive.familyFunction = 'Hans';
                                              hive.status = 'red';
                                              hive.protocol = 'hans';
                                            });
                                            setState(() {});
                                            repository.updateHive(hive);
                                          },
                                          child: const Text('Igen, Hans (Elpusztítás)'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    hive.familyFunction = cat['id'] as String;
                                    if (cat['id'] != 'Hans' && hive.protocol == 'hans') {
                                      hive.protocol = 'standard';
                                    }
                                  });
                                  setState(() {});
                                  repository.updateHive(hive);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? catColor.withAlpha(50)
                                      : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSel ? catColor : Colors.white12,
                                    width: isSel ? 2.5 : 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: catColor.withAlpha(35),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(cat['icon'] as IconData, size: 24, color: catColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        cat['name'] as String,
                                        style: TextStyle(
                                          color: isSel ? Colors.white : Colors.white70,
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    HelpBubbleButton(
                                      title: cat['name'] as String,
                                      message: cat['desc'] as String,
                                      iconColor: catColor,
                                      size: 18,
                                    ),
                                    if (isSel) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.check_circle, size: 24, color: catColor),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                        if (selectedFunctionMenu == 'selejtezes') ...[
                          const SizedBox(height: 12),

                          // --- ANYACSERE & LAKAT VEZÉRLŐ BLOKK (Kizárólag a Selejtezés menüpont alatt!) ---
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: hive.isQueenReplacementActive
                                  ? Colors.red.withAlpha(40)
                                  : (hive.isLocked ? Colors.amber.withAlpha(35) : const Color(0xFF1E293B)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hive.isQueenReplacementActive
                                    ? Colors.redAccent
                                    : (hive.isLocked ? Colors.amberAccent : Colors.amberAccent.withAlpha(80)),
                                width: (hive.isQueenReplacementActive || hive.isLocked) ? 2 : 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      hive.isQueenReplacementActive
                                          ? Icons.warning_rounded
                                          : (hive.isLocked ? Icons.lock : Icons.workspace_premium),
                                      color: hive.isQueenReplacementActive
                                          ? Colors.redAccent
                                          : Colors.amberAccent,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        hive.isQueenReplacementActive
                                            ? '🚨 ANYACSERE FOLYAMATBAN'
                                            : (hive.isLocked ? '🔒 KAPTÁR ZÁROLVA (Kirágós anya)' : '👑 Anyacsere lehetőség'),
                                        style: TextStyle(
                                          color: hive.isQueenReplacementActive
                                              ? Colors.redAccent
                                              : Colors.amberAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                    HelpBubbleButton(
                                      title: hive.isQueenReplacementActive
                                          ? 'Anyacsere folyamat'
                                          : (hive.isLocked ? 'Kirágós anyásítás és lakat' : 'Anyacsere lehetőség'),
                                      message: hive.isQueenReplacementActive
                                          ? (hive.queenReplacementState == 'needs_replacement'
                                              ? 'Anya cserére jelölve! A kaptár pirossal jelez a térképen. A kaptárra kattintva jelöld, ha a régi anya eltávolítása megtörtént!'
                                              : 'Anya eltávolítva – a család anyátlan. Új anya beadása (szoktatósra vagy kirágósra) vagy a család egyesítése/felszámolása szükséges!')
                                          : (hive.isLocked
                                              ? 'Új anya kirágósra beadva! Hátralévő nyugalmi idő: ${hive.lockedDaysRemaining} nap (${hive.lockedUntilFormatted}). Ez alatt tilos a kaptár bolygatása! A nyugalmi időszak lejárta után a rendszer automatikusan vizsgálatot tervez be.'
                                              : 'Megjelöli ezt a családot anyacserére selejtezés helyett. A kaptár a térképen pirossal jelenik meg, és a folyamat lépésről-lépésre segít a régi anya eltávolításában, az új anya beadásában és a 2 hetes lakat kezelésében.'),
                                      iconColor: hive.isQueenReplacementActive ? Colors.redAccent : Colors.amberAccent,
                                      size: 18,
                                    ),
                                  ],
                                ),
                                if (hive.isLocked) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Nyugalmi idő: ${hive.lockedDaysRemaining} nap (${hive.lockedUntilFormatted}) – Bolygatni tilos!',
                                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                if (hive.isQueenReplacementActive) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () async {
                                            Navigator.pop(bottomSheetContext);
                                            await showQueenReplacementFlowDialog(
                                              context: context,
                                              hive: hive,
                                              repository: repository,
                                            );
                                            setState(() {});
                                          },
                                          icon: const Icon(Icons.arrow_forward, size: 18),
                                          label: const Text('Folyamat kezelése', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white70,
                                          side: const BorderSide(color: Colors.white24),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          hive.queenReplacementState = null;
                                          if (hive.queen != null) hive.queen!.needsReplacement = false;
                                          repository.updateHive(hive);
                                          setModalState(() {});
                                          setState(() {});
                                        },
                                        child: const Text('Visszavonás', style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ] else if (hive.isLocked) ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amberAccent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(bottomSheetContext);
                                      await showLockedHiveWarningDialog(
                                        context: context,
                                        hive: hive,
                                        repository: repository,
                                      );
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.lock, size: 18, color: Colors.black),
                                    label: const Text('Lakat részletei / Feloldás', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                                  ),
                                ] else ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      hive.queenReplacementState = 'needs_replacement';
                                      hive.status = 'red';
                                      if (hive.queen != null) hive.queen!.needsReplacement = true;
                                      repository.updateHive(hive);
                                      setModalState(() {});
                                      setState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Anyacsere megjelölve! A kaptár a térképen pirossal jelenik meg.'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.emergency, size: 20),
                                    label: const Text(
                                      'Anyacsere megjelölése (Sürgős csere)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        // --- 2. KAPTÁR OSZTÁLYOZÁSA & ÁLLAPOTA (BOXKESZTYŰ-BARÁT GOMBOK) ---
                        const Row(
                          children: [
                            Icon(Icons.palette_outlined, color: Colors.amberAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '2. Kaptár osztályozása & Állapota:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...statuses.map((st) {
                          final bool isSelected = hive.status == st['key'];
                          final Color color = st['color'] as Color;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: isSelected ? color.withAlpha(50) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? color : Colors.white12,
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(30),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(st['icon'] as IconData, color: color, size: 26),
                                ),
                                title: Text(
                                  st['label'] as String,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    HelpBubbleButton(
                                      title: st['label'] as String,
                                      message: st['desc'] as String,
                                      iconColor: color,
                                      size: 18,
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.check_circle, color: color, size: 24),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  setModalState(() {
                                    hive.status = st['key'] as String;
                                  });
                                  setState(() {});
                                  repository.updateHive(hive);
                                },
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 16),

                        // --- 3. TENYÉSZBÍRÁLATI GYORS MINŐSÍTÉS ---
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tenyészbírálati jegyek (Gyors minősítés):',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildTraitRow('Szelídség', hive.evaluation.temperament, (val) {
                                setModalState(() => hive.evaluation.temperament = val);
                                setState(() {});
                                repository.updateHive(hive);
                              }),
                              _buildTraitRow('Tisztogató hajlam (VSH)', hive.evaluation.hygiene, (val) {
                                setModalState(() => hive.evaluation.hygiene = val);
                                setState(() {});
                                repository.updateHive(hive);
                              }),
                              _buildTraitRow('Gyűjtési hajlam', hive.evaluation.gathering, (val) {
                                setModalState(() => hive.evaluation.gathering = val);
                                setState(() {});
                                repository.updateHive(hive);
                              }),
                              _buildTraitRow('Rajzási hajlam', hive.evaluation.swarming, (val) {
                                setModalState(() => hive.evaluation.swarming = val);
                                setState(() {});
                                repository.updateHive(hive);
                              }),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // --- GOMBOK A MESTERTERVEKHEZ ÉS KEZELÉSEKHEZ ---
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blueAccent.withAlpha(140)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                child: Icon(Icons.work_outline, color: Colors.white, size: 22),
                              ),
                              title: const Text(
                                'Családfunkció & Mestertervek megnyitása',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              subtitle: const Text(
                                'Petés, álcás mestertervek, dajkacsalád indítás, hereskeret és Hans-protokoll.',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                              onTap: () {
                                Navigator.pop(bottomSheetContext);
                                FamilyFunctionScreen.open(context, hive, repository);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF831843), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.pinkAccent.withAlpha(140)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.pinkAccent,
                                child: Icon(Icons.medical_services_outlined, color: Colors.white, size: 22),
                              ),
                              title: const Text(
                                'Kezelések & Gyógyszerezés megnyitása',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              subtitle: const Text(
                                'Oxálsav kúra, fészekvizsgálat, takarmányozás és egyéb feladatok.',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                              onTap: () {
                                Navigator.pop(bottomSheetContext);
                                TreatmentsScreen.open(context, hive, repository);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.check, size: 22),
                            label: const Text(
                              'Osztályozás jóváhagyása & Bezárás',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            onPressed: () {
                              repository.updateHive(hive);
                              setState(() {});
                              Navigator.pop(bottomSheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('A család osztályozása sikeresen mentve!'),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        );
      },
    );
  }

  Widget _buildTraitRow(String title, String currentValue, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: ['+', '0', '-'].map((val) {
              final bool isSel = currentValue == val;
              Color activeColor;
              if (val == '+') {
                activeColor = Colors.greenAccent;
              } else if (val == '0') {
                activeColor = Colors.amberAccent;
              } else {
                activeColor = Colors.redAccent;
              }
              return GestureDetector(
                onTap: () => onChanged(val),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? activeColor.withAlpha(60) : Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSel ? activeColor : Colors.white12,
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    val,
                    style: TextStyle(
                      color: isSel ? activeColor : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSyrupStatusBadge(String status, {bool isMini = false}) {
    final Color color = getSyrupStatusColor(status);
    final String label = getSyrupStatusLabel(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMini ? 6 : 8, vertical: isMini ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: status == 'blinking_red' ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CandyIcon(size: isMini ? 14 : 16, status: status),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: isMini ? 10 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeederOverviewCard(BuildContext context, HiveData hive) {
    String modeLabel;
    Color modeColor;
    IconData modeIcon;

    if (hive.feedingMode == 'smart_sensor') {
      final bool isOpen = hive.isSmartFeedingAllowedNow();
      modeLabel =
          'Szenzoralapú serkentés: ${hive.feedingPortionLiters.toStringAsFixed(2)}L mikro-adagok | Napnyugta előtt ${hive.feedingStopBeforeSunsetMinutes}p STOP (${isOpen ? "Ablak: AKTÍV" : "Ablak: ZÁRVA (Éjszakai védelem)"})';
      modeColor = isOpen ? Colors.tealAccent : Colors.orangeAccent;
      modeIcon = Icons.sensors;
    } else if (hive.feedingMode == 'auto_stim') {
      modeLabel =
          'Időzített serkentés: max ${hive.feedingMaxLiters.toStringAsFixed(1)} L (${hive.feedingIntervalHours} óránként)';
      modeColor = Colors.cyanAccent;
      modeIcon = Icons.schedule;
    } else if (hive.feedingMode == 'manual') {
      modeLabel =
          'Kézi feletetés: max ${hive.feedingMaxLiters.toStringAsFixed(1)} L szintfigyeléssel';
      modeColor = Colors.lightBlueAccent;
      modeIcon = Icons.touch_app;
    } else {
      modeLabel = 'Etetés kikapcsolva (szelep lezárva)';
      modeColor = Colors.white54;
      modeIcon = Icons.power_settings_new;
    }

    final double levelPct = hive.feederLevelPercent.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.lightBlueAccent.withAlpha(120),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CandyIcon(
                      size: 22,
                      status: hive.feederStatus,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Tetőetető & Szirupadagoló',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.lightBlueAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              HelpBubbleButton(
                                title: 'Tetőetető & Szirupadagoló',
                                message: 'Központi vezetékes sziruptöltő rendszer automatikus szintfigyeléssel, SZTOJ ütközésvédelemmel és szintemelkedési védelemmel.',
                                iconColor: Colors.lightBlueAccent,
                                size: 14,
                              ),
                            ],
                          ),
                          Text(
                            hive.pairedTankId != null
                                ? 'Párosítva: ${hive.pairedTankId} ${hive.isAutoPaired ? "(Auto)" : ""}'
                                : 'Tartály: Keresés auto-párosításkor...',
                            style: TextStyle(
                              color: hive.isAutoPaired ? Colors.tealAccent : Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildSyrupStatusBadge(hive.feederStatus, isMini: true),
            ],
          ),
          const SizedBox(height: 8),

          // VILLOGÓ PIROS VÉSZLEÁLLÍTÁS FIGYELMEZTETŐ DOBOZ
          if (hive.feederStatus == 'blinking_red') ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gpp_bad, color: Colors.redAccent, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'VÉSZLEÁLLÍTÁS: Szivattyú TILTVA!',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hive.feederStatusMessage ?? 'Szintemelkedési timeout: nem emelkedik a szirup szintje!',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(120, 32),
                      ),
                      onPressed: () {
                        HiveRepository.instance.resetPumpEmergencyInterlock(HiveRepository.instance.syrupPump);
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Retesz feloldása', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // SZTOJ JELZÉS / VÁRAKOZÓBAN FIGYELMEZTETÉS
          if (hive.sztojRemainingSeconds > 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orangeAccent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_empty, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SZTOJ JELZÉS: Várakozás másik kaptár feltöltésére (${hive.sztojRemainingSeconds}s) - Ütközésvédelem aktív.',
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: levelPct / 100.0,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                hive.feederStatus == 'blinking_red'
                    ? Colors.red
                    : (levelPct > 85
                        ? Colors.redAccent
                        : (levelPct < 20
                            ? Colors.orangeAccent
                            : Colors.lightBlueAccent)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(modeIcon, color: modeColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  modeLabel,
                  style: TextStyle(
                    color: modeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.lightBlueAccent,
                    side: const BorderSide(color: Colors.lightBlueAccent),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _openFeederSettingsDialog(context, hive),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text(
                    'Adagolás',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _openFeederCalibrationDialog(context, hive),
                  icon: const Icon(Icons.straighten, size: 16),
                  label: const Text(
                    'Kalibrálás',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openFeederSettingsDialog(BuildContext context, HiveData hive) {
    showDialog(
      context: context,
      builder: (ctx) {
        String mode = hive.feedingMode;
        double maxLiters = hive.feedingMaxLiters;
        int intervalHours = hive.feedingIntervalHours;
        int stopSunsetMin = hive.feedingStopBeforeSunsetMinutes;
        double portionLiters = hive.feedingPortionLiters;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  CandyIcon(
                    size: 26,
                    status: hive.feederStatus,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tetőetető Vezérlés (${hive.name})',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tetőetető szintmérés:',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${hive.feederLevelPercent.toInt()}%',
                                style: const TextStyle(
                                  color: Colors.lightBlueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: hive.feederLevelPercent / 100.0,
                              minHeight: 6,
                              backgroundColor: Colors.white12,
                              color: Colors.lightBlueAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Túlcsordulás-védelem: 90% felett az adagolás automatikusan leáll.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Adagolási üzemmód:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Kikapcsolva',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Nincs szirupadagolás',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      value: 'off',
                      groupValue: mode,
                      activeColor: Colors.amber,
                      onChanged: (val) =>
                          setDialogState(() => mode = val ?? 'off'),
                    ),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Szenzoralapú serkentés (Ajánlott)',
                        style: TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Reggeli virgoncságtól folyamatos mikro-adagok, napnyugta előtt 1-2 órával STOP',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      value: 'smart_sensor',
                      groupValue: mode,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) =>
                          setDialogState(() => mode = val ?? 'smart_sensor'),
                    ),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Időzített serkentés (Fix óránként)',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Rendszeres kis adagok (1-6 óránként)',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      value: 'auto_stim',
                      groupValue: mode,
                      activeColor: Colors.cyanAccent,
                      onChanged: (val) =>
                          setDialogState(() => mode = val ?? 'auto_stim'),
                    ),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Kézi feletetés',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Nagyobb adag feletetés szintfigyeléssel',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      value: 'manual',
                      groupValue: mode,
                      activeColor: Colors.lightBlueAccent,
                      onChanged: (val) =>
                          setDialogState(() => mode = val ?? 'manual'),
                    ),
                    if (mode == 'smart_sensor') ...[
                      const Divider(color: Colors.white24, height: 20),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.tealAccent.withAlpha(80)),
                        ),
                        child: const Text(
                          'Szenzorvezérlés: Amikor a méhek reggel megélénkülnek, megkapják a nyitó mikro-adagot. Napközben a lehordás ütemében folyamatosan kapnak kis adagokat, majd napnyugta előtt lezár a szelep, így éjszakára nem marad szirup az etetőben (nulla rablás, nincs erjedés).',
                          style: TextStyle(color: Colors.tealAccent, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Egyszeri mikro-adag:',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            '${portionLiters.toStringAsFixed(2)} Liter',
                            style: const TextStyle(
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: portionLiters,
                        min: 0.10,
                        max: 0.50,
                        divisions: 8,
                        activeColor: Colors.tealAccent,
                        onChanged: (val) =>
                            setDialogState(() => portionLiters = val),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Napnyugta előtti leállási idő:',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      DropdownButton<int>(
                        value: stopSunsetMin,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 60,
                            child: Text('Napnyugta előtt 1 órával (60 perc) STOP'),
                          ),
                          DropdownMenuItem(
                            value: 90,
                            child: Text('Napnyugta előtt 1.5 órával (90 perc) STOP - Javasolt'),
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child: Text('Napnyugta előtt 2 órával (120 perc) STOP'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => stopSunsetMin = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Napi maximális keret:',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            '${maxLiters.toStringAsFixed(1)} Liter / nap',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: maxLiters,
                        min: 0.5,
                        max: 3.0,
                        divisions: 10,
                        activeColor: Colors.amberAccent,
                        onChanged: (val) =>
                            setDialogState(() => maxLiters = val),
                      ),
                    ] else if (mode == 'auto_stim') ...[
                      const Divider(color: Colors.white24, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Egyszeri adag:',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            '${maxLiters.toStringAsFixed(1)} Liter',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: maxLiters,
                        min: 0.1,
                        max: 2.0,
                        divisions: 19,
                        activeColor: Colors.cyanAccent,
                        onChanged: (val) =>
                            setDialogState(() => maxLiters = val),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Adagolási időköz (Legritkább: 6 óra):',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      DropdownButton<int>(
                        value: intervalHours,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 1,
                            child: Text('1 óránként (Folyamatos mikro-adag)'),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text('2 óránként'),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text('3 óránként'),
                          ),
                          DropdownMenuItem(
                            value: 4,
                            child: Text('4 óránként'),
                          ),
                          DropdownMenuItem(
                            value: 6,
                            child: Text('6 óránként (Legritkább opció)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => intervalHours = val);
                          }
                        },
                      ),
                    ] else if (mode == 'manual') ...[
                      const Divider(color: Colors.white24, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kiadandó egyszeri adag:',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            '${maxLiters.toStringAsFixed(1)} Liter',
                            style: const TextStyle(
                              color: Colors.lightBlueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: maxLiters,
                        min: 0.5,
                        max: 5.0,
                        divisions: 18,
                        activeColor: Colors.lightBlueAccent,
                        onChanged: (val) =>
                            setDialogState(() => maxLiters = val),
                      ),
                    ],
                    const Divider(color: Colors.white24, height: 24),
                    const Text(
                      'Szerver Utántöltés & Auto-Párosítás:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hive.feederStatus == 'blinking_red'
                                  ? Colors.grey
                                  : Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: hive.feederStatus == 'blinking_red'
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    await HiveRepository.instance.requestSyrupRefillForHive(hive, maxLiters);
                                    setState(() {});
                                  },
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text(
                              'Utántöltés kérése',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await HiveRepository.instance.requestSyrupRefillForHive(hive, maxLiters, simulateTimeout: true);
                            setState(() {});
                          },
                          icon: const Icon(Icons.bug_report, size: 16),
                          label: const Text('Timeout Teszt', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mégse',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    void applySettings() {
                      hive.feedingMode = mode;
                      hive.feedingMaxLiters = maxLiters;
                      hive.feedingIntervalHours = intervalHours;
                      hive.feedingStopBeforeSunsetMinutes = stopSunsetMin;
                      hive.feedingPortionLiters = portionLiters;
                      HiveRepository.instance.updateHiveFeedingSettings(hive);
                      Navigator.pop(ctx);
                      setState(() {});
                      String feedbackText;
                      if (mode == 'smart_sensor') {
                        feedbackText =
                            'Szenzoralapú serkentés aktiválva (${portionLiters.toStringAsFixed(2)}L mikro-adagok, napnyugta előtt ${stopSunsetMin}p STOP).';
                      } else if (mode == 'auto_stim') {
                        feedbackText =
                            'Időzített serkentés: max ${maxLiters.toStringAsFixed(1)}L / ${intervalHours} óránként.';
                      } else if (mode == 'manual') {
                        feedbackText =
                            'Kézi feletetés beállítva: max ${maxLiters.toStringAsFixed(1)}L.';
                      } else {
                        feedbackText =
                            'Etetés kikapcsolva a(z) ${hive.name} kaptáron.';
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(feedbackText),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }

                    if (mode != 'off' && hive.hasHoneySuper) {
                      showFeederHoneyConflictDialog(
                        context: context,
                        hive: hive,
                        conflictType: 'feeding_with_honey',
                        onConfirm: applySettings,
                      );
                      return;
                    }

                    applySettings();
                  },
                  child: const Text('Mentés'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openFeederCalibrationDialog(BuildContext context, HiveData hive) {
    showDialog(
      context: context,
      builder: (ctx) {
        int emptyMm = hive.feederCalibEmptyMm;
        int fullMm = hive.feederCalibFullMm;
        int simulatedRawMm = hive.feederRawDistanceMm;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            double currentLevel = emptyMm > fullMm
                ? (((emptyMm - simulatedRawMm) / (emptyMm - fullMm)) * 100.0)
                    .clamp(0.0, 100.0)
                : 0.0;

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.straighten, color: Colors.amberAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tetőetető Ultrahang Kalibráció',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Aktuális mért távolság:',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              Text(
                                '$simulatedRawMm mm',
                                style: const TextStyle(
                                  color: Colors.lightBlueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Számított folyadékszint:',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              Text(
                                '${currentLevel.toInt()}%',
                                style: TextStyle(
                                  color: currentLevel > 85
                                      ? Colors.redAccent
                                      : (currentLevel < 20
                                          ? Colors.orangeAccent
                                          : Colors.tealAccent),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: currentLevel / 100.0,
                              minHeight: 8,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                currentLevel > 85
                                    ? Colors.redAccent
                                    : (currentLevel < 20
                                        ? Colors.orangeAccent
                                        : Colors.tealAccent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ÜRES állapot kalibrálása (0%)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orangeAccent.withAlpha(90)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.remove_circle_outline, color: Colors.orangeAccent, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    '1. ÜRES Állapot (0%)',
                                    style: TextStyle(
                                      color: Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$emptyMm mm',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'A szenzor és az üres tetőetető aljának mért távolsága.',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.withAlpha(60),
                                    foregroundColor: Colors.orangeAccent,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      emptyMm = simulatedRawMm;
                                    });
                                  },
                                  icon: const Icon(Icons.my_location, size: 14),
                                  label: const Text(
                                    'Aktuális rögzítése',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
                                onPressed: () => setDialogState(() {
                                  if (emptyMm > fullMm + 10) emptyMm -= 5;
                                }),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.white70, size: 18),
                                onPressed: () => setDialogState(() => emptyMm += 5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // TELE állapot kalibrálása (100%)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.tealAccent.withAlpha(90)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: Colors.tealAccent, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    '2. TELE Állapot (100%)',
                                    style: TextStyle(
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$fullMm mm',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'A szenzor és a maximális folyadékszint távolsága.',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.withAlpha(60),
                                    foregroundColor: Colors.tealAccent,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      fullMm = simulatedRawMm;
                                    });
                                  },
                                  icon: const Icon(Icons.my_location, size: 14),
                                  label: const Text(
                                    'Aktuális rögzítése',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
                                onPressed: () => setDialogState(() {
                                  if (fullMm > 15) fullMm -= 5;
                                }),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.white70, size: 18),
                                onPressed: () => setDialogState(() {
                                  if (fullMm < emptyMm - 10) fullMm += 5;
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Mégse', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    hive.feederCalibEmptyMm = emptyMm;
                    hive.feederCalibFullMm = fullMm;
                    hive.feederLevelPercent = currentLevel;
                    HiveRepository.instance.updateHiveFeedingSettings(hive);
                    Navigator.pop(ctx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Tetőetető kalibráció elmentve (${hive.name}): Üres = $emptyMm mm, Tele = $fullMm mm (Szint: ${currentLevel.toInt()}%)',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Kalibráció Mentése'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
