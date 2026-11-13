import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../screens/brood_box_control_screen.dart';
import 'weak_colony_warning_dialog.dart';

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
    if (lowerType == 'escapement' || lowerType == '13') return 'Szöktető';
    if (lowerType == 'vent' || lowerType == '12') return 'Szellőző';
    if (lowerType == 'pollen_trap' || lowerType == '11') return 'Pollengyűjtő';
    if (lowerType == 'bottom' || lowerType == '15') return 'Aljdeszka';
    if (lowerType == 'roof' ||
        lowerName.contains('tető') ||
        lowerName.contains('teto') ||
        lowerName.contains('dekli')) {
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
      if (lowerSize.contains('1/2 dadant')) {
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

    if (lowerName.contains('tetőetető') ||
        lowerType.contains('feeder') ||
        lowerType == '10') {
      return Icons.water_drop;
    }
    if (lowerName.contains('tető') || lowerType.contains('roof')) {
      return Icons.roofing;
    }
    if (lowerName.contains('alj') ||
        lowerType.contains('bottom') ||
        lowerType == '15') {
      return Icons.table_rows_outlined;
    }
    if (lowerName.contains('szellőző') ||
        lowerType.contains('vent') ||
        lowerType == '12') {
      return Icons.air;
    }
    if (lowerName.contains('szöktető') ||
        lowerType.contains('escapement') ||
        lowerType == '13') {
      return Icons.swap_horiz;
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

  // Segédfüggvény a QR és NFC azonosítók tiszta megjelenítéséhez
  String _getBoxCodesText(BoxElement box) {
    if (box.secondaryCode != null && box.secondaryCode!.trim().isNotEmpty) {
      return 'QR: ${box.code} | NFC: ${box.secondaryCode}';
    }
    return 'QR: ${box.code}';
  }

  @override
  Widget build(BuildContext context) {
    final HiveRepository repository = HiveRepository.instance;
    sortHiveBoxes(widget.hive.boxes);
    final displayedBoxes = widget.hive.boxes.reversed.toList();

    // Megkeressük a legalsó fészekfiókot
    BoxElement? bottomBroodBox;
    for (var b in widget.hive.boxes) {
      if (_getBoxDisplayName(b) == 'Fészek') {
        bottomBroodBox = b;
        break;
      }
    }

    final double sheetHeight = MediaQuery.of(context).size.height * 0.88;
    return Container(
      height: sheetHeight,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                            Text(
                              widget.hive.name,
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hiányos torony: Nincs fészekfiók rögzítve!',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Kattints a jobb felső beállító gombra (tune ikon) fészekfiók hozzáadásához.',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Text(
              'Torony felépítése (Kattints bármelyik fiókra a vezérléshez):',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            ...displayedBoxes.map((box) {
              final displayName = _getBoxDisplayName(box);

              if (box.type == 'bottom' || displayName == 'Aljdeszka') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aljdeszka',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getBottomBoardStatusText(box),
                              style: TextStyle(
                                color:
                                    box.isActive &&
                                        box.statusUpdatedAt != null &&
                                        DateTime.now()
                                                .difference(
                                                  box.statusUpdatedAt!,
                                                )
                                                .inDays >=
                                            3
                                    ? Colors.amberAccent
                                    : Colors.white60,
                                fontSize: 11,
                                fontWeight:
                                    box.isActive &&
                                        box.statusUpdatedAt != null &&
                                        DateTime.now()
                                                .difference(
                                                  box.statusUpdatedAt!,
                                                )
                                                .inDays >=
                                            3
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: box.isActive ? Colors.orange : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.filter_vintage,
                              color: box.isActive ? Colors.amberAccent : Colors.white38,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Pollengyűjtő',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
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
                                        box.isActive
                                            ? 'AKTÍV (Gyűjtés)'
                                            : 'INAKTÍV (Kész)',
                                        style: TextStyle(
                                          color: box.isActive
                                              ? Colors.orangeAccent
                                              : Colors.white54,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getBoxCodesText(box),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  box.isActive
                                      ? 'Gyűjtés folyamatban • Kapcsold le a készre jelentéshez'
                                      : 'Gyűjtés kikapcsolva • Készre jelentve',
                                  style: TextStyle(
                                    color: box.isActive
                                        ? Colors.orangeAccent.withAlpha(200)
                                        : Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: box.isActive,
                          activeThumbColor: Colors.orange,
                          activeTrackColor: Colors.orange.withAlpha(120),
                          onChanged: (val) {
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
                                        : 'Virágporgyűjtés kikapcsolva (készre jelentve)!',
                                  ),
                                  backgroundColor:
                                      val ? Colors.orange : Colors.teal,
                                ),
                              );
                            }
                          },
                        ),
                      ],
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
                final IconData boxIcon = _getBoxIcon(box);
                final String boxTitle = _getBoxFormattedTitle(box);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: InkWell(
                    onTap: () {
                      if (isFeeder) {
                        _openFeederSettingsDialog(context, widget.hive);
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
                          color: Colors.amberAccent.withAlpha(140),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                boxIcon,
                                color: isFeeder
                                    ? Colors.lightBlueAccent
                                    : (box.type == 'roof'
                                        ? Colors.tealAccent
                                        : Colors.amberAccent),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      boxTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getBoxCodesText(box),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isHoney) ...[
                                Tooltip(
                                  message: 'Méhszöktető behelyezése a méztér alá',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        repository.insertEscapeBoardUnderHoney(
                                          widget.hive,
                                          box,
                                        );
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Méhszöktető behelyezve a méztér alá! A kaptár villog a térképen (holnap elvétel).',
                                            ),
                                            backgroundColor: Colors.teal,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withAlpha(50),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.orangeAccent,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.filter_alt_outlined,
                                              color: Colors.orangeAccent,
                                              size: 18,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Szöktető',
                                              style: TextStyle(
                                                color: Colors.orangeAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ] else if (isEscapement) ...[
                                Tooltip(
                                  message: 'Szöktető kivétele a toronyból',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        repository.removeBoxFromHive(
                                          widget.hive,
                                          box,
                                        );
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Szöktető eltávolítva a kaptárból.',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withAlpha(40),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.redAccent,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 18,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Kivétel',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
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

                          if (isBottomBroodBox) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(color: Colors.white24, height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSensorBadge(
                                  Icons.thermostat,
                                  '${widget.hive.temp.toStringAsFixed(1)} °C',
                                  Colors.amber,
                                ),
                                _buildSensorBadge(
                                  Icons.water_drop,
                                  '${widget.hive.humidity.toStringAsFixed(0)} %',
                                  Colors.lightBlueAccent,
                                ),
                                _buildSensorBadge(
                                  Icons.mic,
                                  '${widget.hive.zcr.toStringAsFixed(0)} Hz',
                                  Colors.purpleAccent,
                                ),
                                _buildSensorBadge(
                                  Icons.battery_full,
                                  '${widget.hive.batteryVoltage.toStringAsFixed(2)} V',
                                  Colors.tealAccent,
                                ),
                                _buildSensorBadge(
                                  Icons.scale,
                                  '${widget.hive.weight.toStringAsFixed(1)} kg',
                                  Colors.greenAccent,
                                ),
                              ],
                            ),
                          ] else if (isFeeder) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(color: Colors.white24, height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSensorBadge(
                                  Icons.water_drop,
                                  'Szint: ${widget.hive.feederLevelPercent.toInt()}%',
                                  Colors.lightBlueAccent,
                                ),
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
            const SizedBox(height: 12),
            _buildGloveFriendlyActionButtons(context, hive, repository),
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

    if (diffDays < 0) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withAlpha(140)),
                ),
                child: Text(
                  dueBadgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
                if (type == 'scheduled') {
                  final task = next['task'] as ScheduledTask;
                  setState(() {
                    task.isCompleted = true;
                  });
                  repository.completeTask(task.id);
                } else if (type == 'bottom_board') {
                  final box = next['box'] as BoxElement;
                  setState(() {
                    repository.toggleBoxActiveState(hive, box, false);
                  });
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Feladat készre jelentve: ${next['title']}'),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.black),
              label: const Text(
                'Feladat készre jelentése',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildGloveFriendlyActionButtons(context, hive, repository),
        ],
      ),
    );
  }

  Widget _buildGloveFriendlyActionButtons(
    BuildContext context,
    HiveData hive,
    HiveRepository repository,
  ) {
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
    final oneWeekLater = now.add(const Duration(days: 7));

    // Közelgő feladatok ellenőrzése a következő 7 napban
    final upcomingTasks = repository.scheduledTasks.where((t) {
      if (t.hiveId != hive.id || t.isCompleted) return false;
      return t.scheduledDate.isAfter(now.subtract(const Duration(days: 1))) &&
          t.scheduledDate.isBefore(oneWeekLater);
    }).toList();

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

    // 2. Közelgő kezelések és teendők
    for (var t in upcomingTasks) {
      diagnosticIssues.add({
        'icon': Icons.event_note,
        'title':
            'Közelgő feladat 7 napon belül: ${t.title} (${t.scheduledDate.month}.${t.scheduledDate.day})',
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

    if (hive.queen?.needsReplacement == true) {
      diagnosticIssues.add({
        'icon': Icons.star_border,
        'title': 'Anyacsere javasolt (méhanya kora vagy minősége miatt)',
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
          onTap: () => _openColonyClassificationDialog(context, hive, repository),
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
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Minden mért szenzor, kaptárelem és feladat optimális rendben van (Nyugodt méhzúgás: ${hive.zcr.toStringAsFixed(0)} Hz).',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
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
        onTap: () => _openColonyClassificationDialog(context, hive, repository),
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
              ),
              const SizedBox(height: 8),
              Text(
                'A kaptár az alábbi diagnosztikai ok(ok) miatt nem zöld:',
                style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 6),
              ...diagnosticIssues.map((issue) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(issue['icon'] as IconData, color: themeColor, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          issue['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
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

            final functionCategories = [
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
                'desc': 'Virágpor behordás',
                'icon': Icons.spa,
                'color': Colors.orangeAccent,
              },
              {
                'id': 'propolisz',
                'name': 'Propoliszos',
                'desc': 'Propolisz termelés',
                'icon': Icons.texture,
                'color': Colors.amber.shade700,
              },
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
                'desc': 'Kölyökcsalád / tartalék',
                'icon': Icons.inventory_2_outlined,
                'color': Colors.lightGreenAccent,
              },
              {
                'id': 'gyenge',
                'name': 'Gyenge család',
                'desc': 'Megfigyelendő fejlődés',
                'icon': Icons.heart_broken_outlined,
                'color': Colors.orange,
              },
              {
                'id': 'selejt',
                'name': 'Selejt család',
                'desc': 'Szezon végén felerősítésre!',
                'icon': Icons.call_merge,
                'color': Colors.deepOrangeAccent,
              },
              {
                'id': 'Hans',
                'name': 'Hans-protokoll',
                'desc': 'Azonnali elpusztítás!',
                'icon': Icons.local_fire_department,
                'color': Colors.redAccent,
              },
            ];

            return Container(
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
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
                        // --- 1. CSALÁDFUNKCIÓ MÓDOSÍTÁSA (BOXKESZTYŰ-BARÁT CSAMPÉK) ---
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: functionCategories.map((cat) {
                            final bool isSel = hive.familyFunction == cat['id'];
                            final Color catColor = cat['color'] as Color;
                            final double cardWidth =
                                (MediaQuery.of(context).size.width - 42) / 2;

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
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
                                        'A Hans nem egy selejt család, hanem AZONNALI ÉS TELJES ELPUSZTÍTÁST jelent!\n\nAlkalmazása: Súlyos, fertőző betegség (pl. nyúlós költésrothadás) vagy agresszivitás miatti kénlapos megsemmisítés.\n\nEbből a kaptárból szigorúan TILOS fiasítást, keretet vagy népet átadni más családoknak (ellentétben egy selejt családdal, amivel szezon végén felerősíthetsz másokat)!\n\nBiztosan elpusztításra jelölöd ezt a családot?',
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
                                width: cardWidth,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? catColor.withAlpha(50)
                                      : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSel ? catColor : Colors.white12,
                                    width: isSel ? 2.5 : 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(cat['icon'] as IconData, size: 28, color: catColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            cat['name'] as String,
                                            style: TextStyle(
                                              color: isSel ? Colors.white : Colors.white70,
                                              fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                              fontSize: 12.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            cat['desc'] as String,
                                            style: TextStyle(
                                              color: Colors.white.withAlpha(160),
                                              fontSize: 9.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSel)
                                      Icon(Icons.check_circle, size: 16, color: catColor),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

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
                            decoration: BoxDecoration(
                              color: isSelected ? color.withAlpha(50) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? color : Colors.white12,
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
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
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                st['desc'] as String,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(160),
                                  fontSize: 11,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle, color: color, size: 24)
                                  : null,
                              onTap: () {
                                setModalState(() {
                                  hive.status = st['key'] as String;
                                });
                                setState(() {});
                                repository.updateHive(hive);
                              },
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
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blueAccent.withAlpha(140)),
                          ),
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

                        const SizedBox(height: 14),

                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF831843), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.pinkAccent.withAlpha(140)),
                          ),
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.water_drop,
                      color: Colors.lightBlueAccent,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.lightBlueAccent.withAlpha(100),
                  ),
                ),
                child: Text(
                  'Szint: ${levelPct.toInt()}%',
                  style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: levelPct / 100.0,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                levelPct > 85
                    ? Colors.redAccent
                    : (levelPct < 20
                          ? Colors.orangeAccent
                          : Colors.lightBlueAccent),
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
                  const Icon(Icons.water_drop, color: Colors.lightBlueAccent),
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
