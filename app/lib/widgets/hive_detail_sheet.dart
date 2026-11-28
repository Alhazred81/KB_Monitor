import 'dart:async';
import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../screens/brood_box_control_screen.dart';
import '../screens/varroa_counter_screen.dart';
import 'weak_colony_warning_dialog.dart';
import 'candy_icon.dart';
import 'hive_tower_icon.dart';
import 'queen_replacement_dialog.dart';
import 'help_bubble.dart';

class HiveDetailSheet extends StatefulWidget {
  final HiveData hive;
  final Animation<double> redFlashOpacityAnim;
  final FutureOr<void> Function() onConfigurePressed;

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
  static final Stream<int> _sharedOneSecondTicker = Stream<int>.periodic(
    const Duration(seconds: 1),
    (i) => i,
  ).asBroadcastStream();

  @override
  void initState() {
    super.initState();
    HiveRepository.instance.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    HiveRepository.instance.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

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
          '• A felette lévő $superCount db fiók elvételre kerül.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              // 1. Nagy MÉGSE gomb
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24, width: 1.5),
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                    label: const Text(
                      'Mégse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 2. Nagy OK gomb
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
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
                    icon: const Icon(
                      Icons.check_circle_rounded,
                      size: 22,
                      color: Color(0xFF0F172A),
                    ),
                    label: const Text(
                      'OK',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEscapementCountdown(BoxElement box) {
    return RepaintBoundary(
      child: StreamBuilder<int>(
        stream: _sharedOneSecondTicker,
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
      ),
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
    if (lowerType == 'comb_builder' ||
        lowerName.contains('lépépít') ||
        lowerName.contains('lepepit')) {
      return 'Lépépítő';
    }
    if (lowerType == 'demaree' ||
        lowerName.contains('szaporít') ||
        lowerName.contains('szaporit') ||
        lowerName.contains('demaree')) {
      return 'Szaporító (Demaree)';
    }
    if (lowerType == 'queen_excluder' ||
        lowerName.contains('anyarács') ||
        lowerName.contains('anyaracs')) {
      return 'Anyarács';
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

  // Segédfüggvény a tiszta fiókcímhez (pl. Fészek, Méztér, Tető, Tetőetető)
  // A méhész számára nem szükséges a keretméretet (Dadant, Fél Dadant, Hunor) kiírni
  String _getBoxFormattedTitle(BoxElement box) {
    final raw = _getBoxDisplayName(box);
    if (raw.contains('Demaree')) return 'Szaporító (Demaree)';
    return raw.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }

  IconData _getBoxIcon(BoxElement box) {
    final lowerType = box.type.toLowerCase();
    final lowerName = _getBoxDisplayName(box).toLowerCase();

    if (lowerType == 'comb_builder' || lowerName.contains('lépépít')) {
      return Icons.grid_on;
    }
    if (lowerType == 'demaree' || lowerName.contains('demaree') || lowerName.contains('szaporít')) {
      return Icons.call_split;
    }

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
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        repository.resolveLiveHive(widget.hive);
        sortHiveBoxes(widget.hive.boxes);
        final displayedBoxes = widget.hive.boxes.reversed.toList();
        final int escapementIndex = widget.hive.boxes.indexWhere(
          (b) =>
              b.type == 'escapement' ||
              b.name.toLowerCase().contains('szöktet'),
        );
        final DateTime now = DateTime.now();

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
                                  sanitizeHiveDisplayName(widget.hive.name),
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.hive.isRelapsedAfterStrengthening)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withAlpha(70),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amberAccent, width: 1.5),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.priority_high_rounded, size: 14, color: Colors.amberAccent),
                                        SizedBox(width: 3),
                                        Text(
                                          'Visszaesett!',
                                          style: TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (widget.hive.isFreshlyStrengthened)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.lightGreen.withAlpha(40),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.lightGreenAccent.withAlpha(160), width: 1.1),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.group_add_rounded, size: 12, color: Colors.lightGreenAccent),
                                        SizedBox(width: 4),
                                        Text(
                                          'Felerősített',
                                          style: TextStyle(
                                            color: Colors.lightGreenAccent,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
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
                                if (widget.hive.hasExtraBoxes)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: widget.hive.requiresSpanifer
                                          ? Colors.orange.withAlpha(45)
                                          : Colors.amber.withAlpha(35),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: widget.hive.requiresSpanifer
                                            ? Colors.orangeAccent
                                            : Colors.amberAccent.withAlpha(180),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        HiveTowerIcon(
                                          size: 13,
                                          color: widget.hive.requiresSpanifer
                                              ? Colors.orangeAccent
                                              : Colors.amberAccent,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.hive.fullBoxEquivalentCount > 1.0 + 1e-6
                                              ? 'Torony (${widget.hive.formattedBoxEquivalent}/4)'
                                              : 'Felépítmény',
                                          style: TextStyle(
                                            color: widget.hive.requiresSpanifer
                                                ? Colors.orangeAccent
                                                : Colors.amberAccent,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                              'Család ID: ${widget.hive.id} • 🧭 Kijáró: ${widget.hive.entranceHeadingText}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kapott szirup: ${widget.hive.syrupLiters.toStringAsFixed(1)} L',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5,
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
                        icon: const HiveTowerIcon(
                          size: 24,
                          color: Colors.amberAccent,
                        ),
                        tooltip: 'Torony Konfiguráció',
                        onPressed: () async {
                          await Future.sync(widget.onConfigurePressed);
                          if (mounted) {
                            repository.resolveLiveHive(widget.hive);
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),

                  if (widget.hive.isRelapsedAfterStrengthening) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F1D1D).withAlpha(150),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amberAccent, width: 2),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.amberAccent, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.priority_high_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.hive.strengtheningCount > 1
                                      ? '❗ ISMÉTELT LEGYENGÜLÉS (${widget.hive.strengtheningCount}× erősítés után)!'
                                      : '❗ FELERŐSÍTÉS UTÁN ISMÉT LEGYENGÜLT!',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'A család a többihez képest ismét visszaesett'
                                  '${widget.hive.relapseReason != null ? " (${widget.hive.relapseReason})" : ""}. '
                                  'Nem egyszeri lemaradásról van szó – tartós probléma (pl. hibás/öreg méhanya, rejtett betegség vagy nosema) gyanúja áll fenn!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  _buildUnifiedStatusAndTaskCard(context, widget.hive, repository),
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
                  ],
                ),
              ),
            ],

            if (widget.hive.isQuarantined) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D).withAlpha(160),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.redAccent, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔥 HANS-PROTOKOLL AKTÍV – TELJES TORONY ZÁRLAT!',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Nyúlós költésrothadás miatt a teljes torony (minden fiók, aljdeszka, pollengyűjtő, etető és tető) Hans-protokoll zárlat és megsemmisítés alatt áll. '
                            'SZIGORÚAN TILOS bármilyen elemet vagy mézet áthelyezni máshová vagy a feldolgozóba!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (widget.hive.requiresSpanifer && !widget.hive.isQuarantined) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.orange.shade900.withAlpha(85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amberAccent, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '⚠️ Magas torony (${widget.hive.formattedBoxEquivalent} / 4 teljes fiók): 1 teljes + 4 db 1/2-Dadant (3 fiók) felett minimum spaniferes rögzítés szükséges!',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Text(
              'Torony felépítése (${widget.hive.formattedBoxEquivalent} / 4 fiók):',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            ...displayedBoxes.map((box) {
              final displayName = _getBoxDisplayName(box);
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

              final bool canBeEscaped = (!isBottomBroodBox &&
                  !isFeeder &&
                  !isEscapement &&
                  box.type != 'roof' &&
                  box.type != 'bottom' &&
                  box.type != 'pollen_trap' &&
                  !widget.hive.isQuarantined);

              final int currentBoxIndex = widget.hive.boxes.indexOf(box);
              final bool isDirectlyAboveEscapement =
                  (escapementIndex != -1 && currentBoxIndex == escapementIndex + 1);
              final bool isEscapedByBoard =
                  (escapementIndex != -1 && currentBoxIndex > escapementIndex && canBeEscaped);
              final bool isEscapementOverdue = isEscapement &&
                  box.statusUpdatedAt != null &&
                  now.difference(box.statusUpdatedAt!).inMinutes >= 24 * 60;

              final Color boxBorderColor = _getBoxBorderColor(
                box: box,
                isEscapedByBoard: isEscapedByBoard,
                isDirectlyAboveEscapement: isDirectlyAboveEscapement,
                isEscapementOverdue: isEscapementOverdue,
              );

              if (box.type == 'bottom' || displayName == 'Aljdeszka') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: boxBorderColor,
                        width: box.isActive ? 2.0 : 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.dns_outlined,
                          color: boxBorderColor,
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
                        if (box.isActive) ...[
                          IconButton(
                            icon: const Icon(Icons.center_focus_strong, color: Colors.amberAccent, size: 22),
                            tooltip: 'Élőképes Atkaszámláló',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VarroaCounterScreen(hive: widget.hive),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                        Switch(
                          value: box.isActive,
                          activeThumbColor: Colors.deepOrange,
                          onChanged: widget.hive.isQuarantined
                              ? null
                              : (val) {
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
                  if (widget.hive.isQuarantined) return;
                  if (val) {
                    // Ha nincs extra torony, és nincs függő kezelés / probléma / betegség,
                    // figyelmeztetés nélkül automatikusan átállunk Virágporgyűjtés feladatra!
                    if (repository.canAutoSwitchToPollenCollection(
                      widget.hive,
                    )) {
                      bool switchedFn = false;
                      setState(() {
                        switchedFn = repository.enablePollenTrapWithAutoSwitch(
                          widget.hive,
                          box,
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            switchedFn
                                ? 'Virágporgyűjtés bekapcsolva – a család feladata automatikusan Virágporgyűjtésre állítva!'
                                : 'Virágporgyűjtés bekapcsolva!',
                          ),
                          backgroundColor: switchedFn
                              ? Colors.green.shade700
                              : Colors.orange,
                        ),
                      );
                      return;
                    }

                    void doFinalEnable() {
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
                    }

                    void proceedWithEnable() {
                      final String? pendingTreatment = repository
                          .getPendingTreatmentReason(widget.hive);
                      if (widget.hive.isWeakOrSick ||
                          widget.hive.isPoorPerformer) {
                        showWeakColonyWarningDialog(
                          context: context,
                          hive: widget.hive,
                          actionTitle: 'Pollengyűjtő bekapcsolása',
                          onConfirm: doFinalEnable,
                        );
                      } else if (pendingTreatment != null) {
                        showWeakColonyWarningDialog(
                          context: context,
                          hive: widget.hive,
                          actionTitle: 'Pollengyűjtő bekapcsolása (kezelés alatt)',
                          customWarningMessage:
                              '$pendingTreatment.\n\nKezelés alatt álló családon a virágporgyűjtés szermaradvány-kockázatot jelent és gyengíti a családot.',
                          onConfirm: doFinalEnable,
                        );
                      } else {
                        doFinalEnable();
                      }
                    }

                    // Figyelmeztetés ha extra torony / probléma mellett a család feladata nem virágporgyűjtés, vagy ha méztér van fenn
                    final fnPollenMismatch = evaluateFamilyFunctionBoxMismatch(
                      hive: widget.hive,
                      boxType: 'pollen_trap',
                      boxName: 'Pollengyűjtő',
                    );
                    void checkHoneyAndProceed() {
                      if (widget.hive.hasHoneySuper) {
                        showPollenHoneyConflictDialog(
                          context: context,
                          hive: widget.hive,
                          conflictType: 'enabling_pollen_with_honey',
                          onConfirm: proceedWithEnable,
                        );
                      } else {
                        proceedWithEnable();
                      }
                    }

                    if (fnPollenMismatch != null) {
                      showFamilyFunctionBoxMismatchDialog(
                        context: context,
                        hive: widget.hive,
                        mismatch: fnPollenMismatch,
                        isActivation: true,
                        onConfirm: () {
                          repository.logHistoryEvent(
                            widget.hive.id,
                            'nem_megfelelo_elem_felulbiralas',
                            'Figyelmeztetés felülbírálva (${fnPollenMismatch.functionLabel}): Pollengyűjtő bekapcsolva.',
                          );
                          if (fnPollenMismatch.functionLabel == 'Méztermelés') {
                            proceedWithEnable();
                          } else {
                            checkHoneyAndProceed();
                          }
                        },
                      );
                    } else {
                      checkHoneyAndProceed();
                    }
                  } else {
                    setState(() {
                      repository.toggleBoxActiveState(
                        widget.hive,
                        box,
                        false,
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Virágporgyűjtés kikapcsolva'),
                        backgroundColor: Colors.teal,
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
                            color: boxBorderColor,
                            width: box.isActive ? 2.0 : 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_vintage,
                              color: boxBorderColor,
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
                              onChanged: widget.hive.isQuarantined
                                  ? null
                                  : togglePollen,
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

                // Bármely méztér VAGY felső fészekfiók leszöktethető (kivéve ha a torony karantén alatt áll)
                final bool canBeEscaped = (!isBottomBroodBox &&
                    !isFeeder &&
                    !isEscapement &&
                    box.type != 'roof' &&
                    box.type != 'bottom' &&
                    box.type != 'pollen_trap' &&
                    !widget.hive.isQuarantined);

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
                        if (widget.hive.isQuarantined) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '🔥 Hans-protokoll zárlat: az etetés le van tiltva ezen a tornyon!',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        _openFeederSettingsDialog(context, widget.hive);
                      } else if (isEscapement) {
                        // Szöktető kártyára kattintva nem nyitunk fészekfiókot
                      } else {
                        () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => BroodBoxControlScreen(
                                hive: widget.hive,
                                broodBox: box,
                              ),
                            ),
                          );
                          if (mounted) setState(() {});
                        }();
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
                          color: boxBorderColor,
                          width: (isDirectlyAboveEscapement ||
                                  isEscapement ||
                                  isEscapedByBoard ||
                                  boxBorderColor != Colors.greenAccent)
                              ? 2.0
                              : 1.5,
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
                                    color: boxBorderColor,
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
                                      if (BoxHelpButton.hasHelp(box)) ...[
                                        const SizedBox(width: 2),
                                        BoxHelpButton(box: box),
                                      ],
                                    ],
                                  ),
                                ),
                                if (canBeEscaped) ...[
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        void doInsertEscapement() {
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
                                        }

                                        final escMismatch =
                                            evaluateFamilyFunctionBoxMismatch(
                                              hive: widget.hive,
                                              boxType: 'escapement',
                                              boxName: 'Méhszöktető',
                                            );
                                        if (escMismatch != null) {
                                          showFamilyFunctionBoxMismatchDialog(
                                            context: context,
                                            hive: widget.hive,
                                            mismatch: escMismatch,
                                            onConfirm: () {
                                              repository.logHistoryEvent(
                                                widget.hive.id,
                                                'nem_megfelelo_elem_felulbiralas',
                                                'Figyelmeztetés felülbírálva (${escMismatch.functionLabel}): Méhszöktető behelyezve a(z) "$boxTitle" alá.',
                                              );
                                              doInsertEscapement();
                                            },
                                          );
                                          return;
                                        }
                                        doInsertEscapement();
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
      },
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

  Color _getBoxBorderColor({
    required BoxElement box,
    required bool isEscapedByBoard,
    required bool isDirectlyAboveEscapement,
    required bool isEscapementOverdue,
  }) {
    if (widget.hive.isQuarantined || box.isQuarantined) {
      return Colors.redAccent;
    }

    final lowerType = box.type.toLowerCase();
    final lowerName = box.name.toLowerCase();

    // 1. Aljdeszka
    if (isBottomBox(box)) {
      if (!box.isActive) {
        return Colors.greenAccent;
      }
      final bool isDue = box.isVarroaCheckDue ||
          (box.statusUpdatedAt != null &&
              DateTime.now().difference(box.statusUpdatedAt!).inDays >= 3);
      return isDue ? Colors.redAccent : Colors.amberAccent;
    }

    // 2. Pollengyűjtő
    if (isPollenBox(box)) {
      return box.isActive ? Colors.orangeAccent : Colors.greenAccent;
    }

    // 3. Méhszöktető
    if (lowerType == 'escapement' ||
        lowerType == '13' ||
        lowerName.contains('szöktet') ||
        lowerName.contains('szoktet')) {
      return isEscapementOverdue ? Colors.redAccent : Colors.amberAccent;
    }

    // 4. Szöktető feletti leszöktetett méztér / fiók
    if (isEscapedByBoard) {
      return isEscapementOverdue ? Colors.redAccent : Colors.orangeAccent;
    }

    // 5. Tetőetető
    if (isFeederBox(box) || lowerName.contains('etet')) {
      if (widget.hive.feederStatus == 'blinking_red') return Colors.redAccent;
      if (widget.hive.hasFeeder &&
          widget.hive.feederLevelPercent <= 20.0 &&
          widget.hive.feedingMode != 'off') {
        return Colors.orangeAccent;
      }
      return Colors.greenAccent;
    }

    // 6. Tető (ha nincs zárolva az anyacsere miatt, nincs teendő -> zöld)
    if (isRoofBox(box)) {
      return widget.hive.isLocked ? Colors.amberAccent : Colors.greenAccent;
    }

    // 7. Fészekfiók (ha a fészekhőmérséklet és akusztika rendben, nincs teendő -> zöld)
    final bool isBrood = (lowerType == 'brood_box' ||
        lowerType == 'broodbox' ||
        lowerType == 'nest' ||
        lowerType == '8' ||
        lowerName.contains('fészek') ||
        lowerName.contains('feszek'));
    if (isBrood) {
      if (box.status == 'red' ||
          box.status == 'flashing_red' ||
          widget.hive.tempStatus == 'flashing_red' ||
          widget.hive.tempStatus == 'red') {
        return Colors.redAccent;
      }
      if (box.status == 'orange') {
        return Colors.orangeAccent;
      }
      if (box.status == 'yellow' ||
          widget.hive.tempStatus == 'yellow' ||
          widget.hive.acousticColonyStatus == 'yellow') {
        return Colors.amberAccent;
      }
      return Colors.greenAccent;
    }

    // 8. Egyéb normál fiókok (méztér stb.)
    if (box.status == 'red' || box.status == 'flashing_red') return Colors.redAccent;
    if (box.status == 'orange') return Colors.orangeAccent;
    if (box.status == 'yellow') return Colors.amberAccent;
    if (box.status == 'purple') return Colors.purpleAccent;

    // Nincs teendő -> Zöld keret
    return Colors.greenAccent;
  }

  Widget _buildUnifiedStatusAndTaskCard(
    BuildContext context,
    HiveData hive,
    HiveRepository repository,
  ) {
    final now = DateTime.now();

    // 1. DIAGNOSZTIKAI ÉS STÁTUSZ SZÁMÍTÁSOK
    final List<Map<String, dynamic>> diagnosticIssues = [];

    if (hive.isQuarantined) {
      diagnosticIssues.add({
        'icon': Icons.warning_rounded,
        'title': '⚠️ TELJES TORONY HATÓSÁGI ZÁRLAT (Nyúlós költésrothadás)! Szigorúan tilos bármilyen elemet vagy mézet áthelyezni máshová!',
        'isManualStatus': false,
      });
    } else if (hive.isRelapsedAfterStrengthening) {
      diagnosticIssues.add({
        'icon': Icons.priority_high_rounded,
        'title':
            '❗ Felerősítés után ismét legyengült a többi családhoz képest${hive.relapseReason != null ? " (${hive.relapseReason})" : ""}: tartós probléma (pl. anyacsere / betegség) vizsgálata szükséges!',
        'isManualStatus': false,
      });
    }

    for (final dId in hive.reportedDiseases) {
      if (dId == 'nyulos') continue; // Már szerepel a teljes torony zárlatnál
      final dName = kHiveDiseaseLabels[dId] ?? dId;
      diagnosticIssues.add({
        'icon': Icons.coronavirus_outlined,
        'title': 'Lejelentett betegség: $dName',
        'isManualStatus': false,
      });
    }

    // Kézi státusz beállítás
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

    // Csak a lejárt, késésben lévő teendők számítanak figyelmeztetésnek
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

    // Fészekfiók jelenléte a toronyban
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

    // Szenzoros eltérések
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

    // Varroa és kártevők
    if (hive.isLocked && hive.acousticColonyStatus != 'green') {
      diagnosticIssues.add({
        'icon': Icons.hearing_disabled,
        'title':
            '🚨 Akusztikai anomália: Nyugtalan méhzúgás a kirágós anyánál (${hive.zcr.toStringAsFixed(0)} Hz)!',
        'isManualStatus': false,
      });
    }

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

    // Hardver és beavatkozások
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

    if (hive.protocol != null && hive.protocol!.isNotEmpty) {
      diagnosticIssues.add({
        'icon': Icons.healing,
        'title': 'Aktív protokoll: ${hive.protocol}',
        'isManualStatus': false,
      });
    }

    final bool isAllGreen =
        diagnosticIssues.isEmpty && hive.worstStatus == 'green';
    final bool isQuietLock = hive.isLocked;
    final bool isCageMode = hive.queenReplacementState == 'introduced_cage';

    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String helpMsg;

    if (isCageMode) {
      statusColor = Colors.tealAccent;
      statusIcon = Icons.lock_clock;
      statusTitle = 'Család állapota: Anyásítás folyamatban (Szoktatás • Zárt zárka)';
      helpMsg =
          'Új anya (${hive.queen?.id ?? ""}) zárt kalitkában beadva (3 napos beszoktatási időszak).\n\nA család ismerkedik az anya feromonjával. 3 nap múlva esedékes az anyakalitka kirágósra állítása!';
    } else if (isAllGreen) {
      statusColor = isQuietLock ? Colors.tealAccent : Colors.greenAccent;
      statusIcon = isQuietLock ? Icons.lock : Icons.check_circle_rounded;
      statusTitle = isQuietLock
          ? 'Család állapota: Védett nyugalmi időszak (Zöld • 🔒 Lakat • 🎧 15p Hallgatózás)'
          : 'Család állapota: Egészséges & Optimális (Zöld)';
      helpMsg = isQuietLock
          ? 'Új anya kirágósra adva (${hive.lockedDaysRemaining} nap nyugalmi idő van hátra).\n\nA kaptárt tilos bolygatni! A monitor sűrített akusztikai felügyelettel 15 percenként hallgatózik (${hive.zcr.toStringAsFixed(0)} Hz: békés méhzúgás), és anomália esetén azonnal riaszt!'
          : 'Minden mért szenzor, kaptárelem és betervezett teendő optimális rendben van.\n\nAkusztikai monitor: Nyugodt méhzúgás (${hive.zcr.toStringAsFixed(0)} Hz).';
    } else {
      final effStatus = hive.worstStatus;
      String? customHelpMsg;
      if (hive.isLocked && hive.acousticColonyStatus != 'green') {
        statusColor = Colors.redAccent;
        statusIcon = Icons.warning_rounded;
        statusTitle = 'Család állapota: Anyásítási Akusztikai Vészjelzés! (${hive.zcr.toStringAsFixed(0)} Hz)';
        customHelpMsg =
            'FIGYELEM! A 15 percenként hallgatózó akusztikai monitor rendellenes, heves méhzúgást észlelt (${hive.zcr.toStringAsFixed(0)} Hz)!\n\nA család nem fogadta el az új anyát vagy heves pánikban van. Sürgős ellenőrzés szükséges!';
      } else if (hive.isQuarantined) {
        statusColor = Colors.redAccent;
        statusIcon = Icons.local_fire_department;
        statusTitle = 'Család állapota: 🔥 HANS-PROTOKOLL AKTÍV (Teljes torony zárlat)';
        customHelpMsg =
            'A kaptáron a Nyúlós költésrothadás miatt HANS-PROTOKOLL és szigorú hatósági zárlat van érvényben!\n\n'
            'A TELJES TORONY (minden fészek- és méztéri fiók, lépépítő, aljdeszka, etető, tető, keret és mézkészlet) zárlat és megsemmisítés alá esik.\n\n'
            'Szigorúan TILOS bármilyen elemet, keretet vagy mézet áthelyezni másik kaptárba vagy a feldolgozóba!';
      } else if (effStatus == 'red' || effStatus == 'flashing_red') {
        statusColor = Colors.redAccent;
        statusIcon = Icons.warning_rounded;
        statusTitle = 'Család állapota: Kritikus vészjelzés (Piros)';
      } else if (effStatus == 'orange') {
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.notifications_active;
        statusTitle = 'Család állapota: Kezelés / Korlátozás aktív (Narancs)';
      } else if (effStatus == 'purple') {
        statusColor = Colors.purpleAccent;
        statusIcon = Icons.warning_amber_rounded;
        statusTitle = 'Család állapota: Rajzáskészültség / Kísérleti (Lila)';
      } else {
        statusColor = Colors.amber;
        statusIcon = Icons.info_outline;
        statusTitle = 'Család állapota: Figyelmet igénylő (Sárga)';
      }
      helpMsg = customHelpMsg ??
          'A kaptár jelenlegi állapota: $statusTitle.\n\nA státuszt a beépített fiókok, az aktív rácsok, a mért szenzoradatok vagy a kézi osztályozás határozza meg.';
    }

    final bool hasManualStatusIssue =
        diagnosticIssues.any((i) => i['isManualStatus'] == true);

    // 2. TEENDŐK FELTÉRKÉPEZÉSE
    final List<Map<String, dynamic>> allTasks = [];

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

    if (hive.queenReplacementState == 'introduced_cage') {
      final cageStart = hive.queenIntroducedAt ?? now;
      final dueDate = cageStart.add(const Duration(days: 3));
      final bool alreadyInTasks = allTasks.any((t) => (t['title'] as String).contains('kirágósra állítása'));
      if (!alreadyInTasks) {
        allTasks.add({
          'id': 'QUEEN_CAGE_${hive.id}',
          'title': 'Anyakalitka kirágósra állítása (3 nap)',
          'description':
              'A 3 napos beszoktatási idő letelt. Nyisd meg a cukorlepényes kirágónyílást a kalitkán, hogy a méhek ki tudják rágni az anyát!',
          'date': dueDate,
          'type': 'queen_cage_switch',
        });
      }
    }

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

    if (hive.isLocked && hive.acousticColonyStatus != 'green') {
      allTasks.insert(0, {
        'id': 'ACOUSTIC_ALERT_${hive.id}',
        'title': '🚨 Sürgős akusztikai felülvizsgálat (Anyásítási anomália)',
        'description':
            'A 15 perces sűrített hallgatózás során a monitor nyugtalan, anyátlan jellegű méhzúgást (${hive.zcr.toStringAsFixed(0)} Hz) regisztrált a lakat alatt!',
        'date': now,
        'type': 'acoustic_alert',
      });
    }

    if (!hive.isQuarantined &&
        (hive.worstStatus == 'red' || hive.worstStatus == 'flashing_red') &&
        !repository.isUrgentHiveCheckDismissed(hive)) {
      allTasks.add({
        'id': 'URGENT_${hive.id}',
        'title': 'Azonnali fészekvizsgálat & Családmentés',
        'description':
            'Kritikus fészekhőmérséklet vagy hirtelen súlycsökkenés miatt sürgős beavatkozás indokolt.',
        'date': now,
        'type': 'urgent_check',
      });
    }

    allTasks.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    Color taskUrgencyColor(String urgencyCode) {
      switch (urgencyCode) {
        case 'flashing_red':
        case 'red':
          return Colors.redAccent;
        case 'flashing_orange':
          return const Color(0xFFFF9100);
        case 'orange':
          return Colors.deepOrangeAccent;
        case 'yellow':
          return Colors.amberAccent;
        case 'green':
        default:
          return Colors.greenAccent;
      }
    }

    Color taskUrgencyBgColor(String urgencyCode) {
      switch (urgencyCode) {
        case 'flashing_red':
          return const Color(0xFFDC2626);
        case 'red':
          return const Color(0xFFB91C1C);
        case 'flashing_orange':
          return const Color(0xFFFF6D00);
        case 'orange':
          return const Color(0xFFEA580C);
        case 'yellow':
          return const Color(0xFFD97706);
        case 'green':
        default:
          return const Color(0xFF16A34A);
      }
    }

    String formatTaskDueLabel(Map<String, dynamic> taskMap) {
      final DateTime targetDate = taskMap['date'] as DateTime;
      final int diffDays = computeTaskDiffDays(targetDate, now: now);
      final String timeStr =
          '${targetDate.hour.toString().padLeft(2, '0')}:${targetDate.minute.toString().padLeft(2, '0')}';

      if (taskMap['type'] == 'escapement_harvest') {
        final escapementBox = taskMap['box'] as BoxElement;
        final startTime = escapementBox.statusUpdatedAt ?? now;
        final remainingSec = (24 * 3600) - now.difference(startTime).inSeconds;
        if (remainingSec <= 0) {
          return '24h LEJÁRT! AZONNAL!';
        }
        final remainingHours = (remainingSec + 3599) ~/ 3600;
        return 'AZNAPI • ~$remainingHours ÓRA (MAX. 24h)';
      }
      if (diffDays < 0) {
        return 'LEJÁRT (${diffDays.abs()} napja késik!)';
      }
      if (diffDays == 0) {
        return 'MA ESEDÉKES! ($timeStr)';
      }
      if (diffDays == 1) {
        return 'HOLNAP ESEDÉKES ($timeStr)';
      }
      return '$diffDays nap múlva (${targetDate.month.toString().padLeft(2, '0')}.${targetDate.day.toString().padLeft(2, '0')})';
    }

    String resolveTaskMapUrgency(Map<String, dynamic> taskMap) {
      final DateTime targetDate = taskMap['date'] as DateTime;
      final String tType = (taskMap['type'] ?? '').toString();
      if (tType == 'acoustic_alert') {
        return 'flashing_red';
      }
      if (tType == 'urgent_check') {
        return hive.worstStatus == 'flashing_red' ? 'flashing_red' : 'red';
      }
      if (tType == 'escapement_harvest') {
        final escapementBox = taskMap['box'] as BoxElement;
        final startTime = escapementBox.statusUpdatedAt ?? now;
        final remainingSec = (24 * 3600) - now.difference(startTime).inSeconds;
        return remainingSec <= 0 ? 'flashing_red' : 'flashing_orange';
      }
      bool isSevereScheduled = false;
      if (tType == 'scheduled' && taskMap['task'] is ScheduledTask) {
        final ScheduledTask st = taskMap['task'] as ScheduledTask;
        isSevereScheduled =
            st.category == 'hans_protocol' || st.id.startsWith('HANS_');
      }
      return computeTaskUrgencyCode(
        targetDate,
        now: now,
        isSevereEmergency: isSevereScheduled,
      );
    }

    Map<String, dynamic>? nextTask;
    String dueBadgeText = '';
    String nextTaskUrgency = 'green';
    bool isNextTaskBlinking = false;
    Color badgeColor = Colors.greenAccent;
    Color badgeFillColor = const Color(0xFF16A34A);
    IconData taskIcon = Icons.alarm;

    if (allTasks.isNotEmpty) {
      nextTask = allTasks.first;
      nextTaskUrgency = resolveTaskMapUrgency(nextTask);
      isNextTaskBlinking =
          nextTaskUrgency == 'flashing_orange' ||
          nextTaskUrgency == 'flashing_red';
      badgeColor = taskUrgencyColor(nextTaskUrgency);
      badgeFillColor = taskUrgencyBgColor(nextTaskUrgency);
      dueBadgeText = formatTaskDueLabel(nextTask);

      if (hive.isLocked &&
          (nextTask['title'] as String).contains('Anyásítás vizsgálata')) {
        dueBadgeText =
            '🔒 ${hive.lockedDaysRemaining} NAP NYUGALOM • $dueBadgeText';
        taskIcon = Icons.lock_clock;
      } else if (nextTaskUrgency == 'flashing_red' ||
          nextTaskUrgency == 'red') {
        taskIcon = Icons.assignment_late;
      } else if (nextTaskUrgency == 'flashing_orange') {
        taskIcon = Icons.notifications_active;
      } else if (nextTaskUrgency == 'orange') {
        taskIcon = Icons.schedule;
      } else if (nextTaskUrgency == 'yellow') {
        taskIcon = Icons.event;
      } else {
        taskIcon = Icons.calendar_month;
      }
    }

    final Color cardBorderColor = (isCageMode || isQuietLock)
        ? Colors.tealAccent.withAlpha(160)
        : (!isAllGreen
            ? statusColor.withAlpha(160)
            : Colors.greenAccent.withAlpha(130));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KÖVETKEZŐ TEENDŐ
          if (nextTask == null) ...[
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
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isNextTaskBlinking)
                        FadeTransition(
                          opacity: widget.redFlashOpacityAnim,
                          child: Icon(taskIcon, color: badgeColor, size: 17),
                        )
                      else
                        Icon(taskIcon, color: badgeColor, size: 17),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'KÖVETKEZŐ TEENDŐ (${allTasks.length} db)',
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: () {
                    final Widget badgeChip = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isNextTaskBlinking
                            ? badgeFillColor
                            : badgeFillColor.withAlpha(65),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: badgeColor,
                          width: isNextTaskBlinking ? 1.6 : 1.1,
                        ),
                      ),
                      child: Text(
                        dueBadgeText,
                        style: TextStyle(
                          color: isNextTaskBlinking ? Colors.white : badgeColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                    if (isNextTaskBlinking) {
                      return FadeTransition(
                        opacity: widget.redFlashOpacityAnim,
                        child: badgeChip,
                      );
                    }
                    return badgeChip;
                  }(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: badgeFillColor.withAlpha(28),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: badgeColor, width: 3.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nextTask['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    nextTask['description'] as String,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (nextTask['type'] != 'escapement_harvest') ...[
              const SizedBox(height: 10),
              _buildTaskActionButton(
                context,
                nextTask,
                hive,
                repository,
                urgencyCode: nextTaskUrgency,
              ),
            ],
            if (allTasks.length > 1) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withAlpha(170),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'További ütemezett teendők (${allTasks.length - 1} db):',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...allTasks.skip(1).take(5).map((tItem) {
                      final String uCode = resolveTaskMapUrgency(tItem);
                      final Color uCol = taskUrgencyColor(uCode);
                      final Color uBg = taskUrgencyBgColor(uCode);
                      final bool uBlink =
                          uCode == 'flashing_orange' || uCode == 'flashing_red';
                      final String uLabel = formatTaskDueLabel(tItem);

                      final Widget pill = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: uBlink ? uBg : uBg.withAlpha(55),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: uCol, width: 1.0),
                        ),
                        child: Text(
                          uLabel,
                          style: TextStyle(
                            color: uBlink ? Colors.white : uCol,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            final String subTitle = tItem['title'] as String;
                            final String subType = tItem['type'] as String;
                            if (subType == 'queen_cage_switch' ||
                                subTitle.contains('kirágósra állítása')) {
                              showQueenReplacementFlowDialog(
                                context: context,
                                hive: hive,
                                repository: repository,
                                initialStepOverride: 'introduced_cage',
                              ).then((_) {
                                if (mounted) setState(() {});
                              });
                            } else if (subType == 'scheduled' &&
                                tItem['task'] is ScheduledTask) {
                              final st = tItem['task'] as ScheduledTask;
                              repository.completeTask(st.id);
                              if (mounted) setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Feladat készre jelentve: $subTitle',
                                  ),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: uCol,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    tItem['title'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                uBlink
                                    ? FadeTransition(
                                        opacity: widget.redFlashOpacityAnim,
                                        child: pill,
                                      )
                                    : pill,
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Colors.white12, height: 1),
          ),

          // 2. CSALÁD ÁLLAPOTA
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await FamilyFunctionScreen.open(context, hive, repository);
              if (mounted) setState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            statusTitle,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (hive.isRelapsedAfterStrengthening) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amberAccent, width: 1.2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.priority_high_rounded, color: Colors.white, size: 13),
                                SizedBox(width: 2),
                                Text(
                                  'Tartós gond!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (hive.isTopPerformer) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(50),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amberAccent, width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: Colors.amberAccent, size: 13),
                                SizedBox(width: 3),
                                Text(
                                  'Rekorder',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (hive.isPoorPerformer) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(50),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.redAccent, width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_downward, color: Colors.redAccent, size: 13),
                                SizedBox(width: 3),
                                Text(
                                  'Gyenge',
                                  style: TextStyle(
                                    color: Colors.redAccent,
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
                  ),
                  if (isCageMode || isQuietLock || hive.isQuarantined)
                    HelpBubbleButton(
                      title: isQuietLock
                          ? 'Védett lakat időszak'
                          : (hive.isQuarantined
                              ? 'Hans-protokoll zárlat'
                              : 'Szoktatós anyásítás'),
                      message: helpMsg,
                      iconColor: statusColor,
                      size: 15,
                    ),
                ],
              ),
            ),
          ),

          if (diagnosticIssues.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...diagnosticIssues.map((issue) {
              final String title = issue['title'] as String;
              final bool isPollenIssue = title.contains('pollengyűjtő');
              final bool isBroodIssue = title.contains('Nincs fészekfiók');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(issue['icon'] as IconData, color: statusColor, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white70,
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      widget.hive.status = 'green';
                    });
                    repository.updateHive(
                      widget.hive,
                      historyEventType: 'statusz_valtozas',
                      historyDescription:
                          'Család státusza kézzel módosítva: green.',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('A kaptár kézi státusza Zöldre állítva!'),
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

          // 3. BOXKESZTYŰBARÁT AKCIÓGOMBOK: VIZSGÁLATOK, KEZELÉSEK, OSZTÁLYOZÁS
          if (!hive.hasExtraBoxes) ...[
            const SizedBox(height: 14),
            _buildGloveFriendlyActionButtons(context, hive, repository),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskActionButton(
    BuildContext context,
    Map<String, dynamic> next,
    HiveData hive,
    HiveRepository repository, {
    String urgencyCode = 'green',
  }) {
    final type = next['type'] as String;
    final String title = next['title'] as String;
    final bool isCageSwitch =
        type == 'queen_cage_switch' || title.contains('kirágósra állítása');
    final bool isQueenInspection = title.contains('Anyásítás vizsgálata');

    IconData btnIcon = Icons.check_circle_outline;
    String btnLabel = 'Feladat készre jelentése';
    Color btnBg;
    Color btnFg;
    switch (urgencyCode) {
      case 'flashing_red':
      case 'red':
        btnBg = Colors.redAccent;
        btnFg = Colors.white;
        break;
      case 'flashing_orange':
        btnBg = const Color(0xFFFF6D00);
        btnFg = Colors.white;
        break;
      case 'orange':
        btnBg = Colors.orange;
        btnFg = Colors.black;
        break;
      case 'yellow':
        btnBg = Colors.amber;
        btnFg = Colors.black;
        break;
      case 'green':
      default:
        btnBg = Colors.greenAccent;
        btnFg = const Color(0xFF0F172A);
        break;
    }

    if (isCageSwitch) {
      btnIcon = Icons.lock_open;
      btnLabel = 'Anyakalitka átállítása kirágósra';
      btnBg = Colors.amberAccent;
      btnFg = Colors.black;
    } else if (isQueenInspection && hive.isLocked) {
      btnIcon = Icons.lock;
      btnLabel = '🔒 Lakat aktív (Még ${hive.lockedDaysRemaining} nap nyugalmi idő)';
      btnBg = const Color(0xFF0F766E);
      btnFg = Colors.tealAccent;
    } else if (type == 'bottom_board') {
      btnIcon = Icons.center_focus_strong;
      btnLabel = 'Élőképes Atkaszámláló indítása';
      btnBg = Colors.orangeAccent;
      btnFg = Colors.black;
    } else if (type == 'acoustic_alert') {
      btnIcon = Icons.warning_amber_rounded;
      btnLabel = '🚨 Lakat feloldása & Sürgős beavatkozás';
      btnBg = Colors.redAccent;
      btnFg = Colors.white;
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          if (type == 'acoustic_alert') {
            showLockedHiveWarningDialog(
              context: context,
              hive: hive,
              repository: repository,
            );
          } else if (isCageSwitch) {
            showQueenReplacementFlowDialog(
              context: context,
              hive: hive,
              repository: repository,
              initialStepOverride: 'introduced_cage',
            ).then((_) {
              if (mounted) setState(() {});
            });
          } else if (isQueenInspection && hive.isLocked) {
            showLockedHiveWarningDialog(
              context: context,
              hive: hive,
              repository: repository,
            );
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
          } else if (type == 'urgent_check') {
            repository.acknowledgeUrgentHiveCheck(hive).then((_) {
              if (mounted) setState(() {});
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Azonnali fészekvizsgálat kézzel készre jelentve (nyugtázva).',
                ),
                backgroundColor: Colors.teal,
              ),
            );
          } else if (type == 'feeder_refill') {
            final double portion = hive.feedingPortionLiters > 0
                ? hive.feedingPortionLiters
                : 1.0;
            repository.requestSyrupRefillForHive(hive, portion);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Szirup utántöltés elindítva (+${portion.toStringAsFixed(1)} L).',
                ),
                backgroundColor: Colors.teal,
              ),
            );
          } else if (type == 'bottom_board') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VarroaCounterScreen(hive: hive),
              ),
            );
          }
        },
        icon: Icon(btnIcon, size: 20, color: btnFg),
        label: Text(
          btnLabel,
          style: TextStyle(
            color: btnFg,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: btnBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 460;

        final Widget investigationsBtn = SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.lightBlueAccent,
              side: const BorderSide(color: Colors.lightBlueAccent, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () async {
              await InvestigationsScreen.open(context, hive, repository);
              if (mounted) setState(() {});
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, size: 22, color: Colors.lightBlueAccent),
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
        );

        final Widget treatmentsBtn = SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.orangeAccent,
              side: const BorderSide(color: Colors.orangeAccent, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () async {
              await TreatmentsScreen.open(context, hive, repository);
              if (mounted) setState(() {});
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services, size: 22, color: Colors.orangeAccent),
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
        );

        final Widget classificationBtn = SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.tealAccent,
              side: const BorderSide(color: Colors.tealAccent, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () async {
              await FamilyFunctionScreen.open(context, hive, repository);
              if (mounted) setState(() {});
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tune, size: 22, color: Colors.tealAccent),
                SizedBox(width: 8),
                Text(
                  'Osztályozás',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );

        final int diseaseCount = hive.reportedDiseases.length;
        final Widget diseasesBtn = SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: diseaseCount > 0
                  ? const Color(0xFF3B1219)
                  : const Color(0xFF0F172A),
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => _showDiseasesDialog(context, hive, repository),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.coronavirus_outlined, size: 22, color: Colors.redAccent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    diseaseCount > 0 ? 'Betegségek ($diseaseCount)' : 'Betegségek',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: investigationsBtn),
              const SizedBox(width: 8),
              Expanded(child: treatmentsBtn),
              const SizedBox(width: 8),
              Expanded(child: classificationBtn),
              const SizedBox(width: 8),
              Expanded(child: diseasesBtn),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: investigationsBtn),
                const SizedBox(width: 10),
                Expanded(child: treatmentsBtn),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: classificationBtn),
                const SizedBox(width: 10),
                Expanded(child: diseasesBtn),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showDiseasesDialog(
    BuildContext context,
    HiveData hive,
    HiveRepository repository,
  ) {
    // Súlyosság és előfordulás szerinti színskála (kizárólag lejelentő gombok)
    const List<Map<String, dynamic>> diseases = [
      {
        'id': 'nyulos',
        'label': 'Nyúlós\nköltésrothadás',
        'color': Color(0xFFFF1744), // Mélyvörös: Kritikus zárlat / végzetes
      },
      {
        'id': 'varroa',
        'label': 'Varroatózis',
        'color': Color(0xFFFF5722), // Narancsvörös: Magas súlyosság + nagyon gyakori
      },
      {
        'id': 'alanyassag',
        'label': 'Álanyásság',
        'color': Color(0xFFD946EF), // Bíbor/Lila: Súlyos + közepes előfordulás
      },
      {
        'id': 'nozema',
        'label': 'Nozematózis',
        'color': Color(0xFFFF9800), // Narancs: Magas + gyakori (tavasz)
      },
      {
        'id': 'enyhe',
        'label': 'Enyhe\nköltésrothadás',
        'color': Color(0xFFFFC107), // Borostyán: Közepes + időszakos
      },
      {
        'id': 'meszesedes',
        'label': 'Költés-\nmeszesedés',
        'color': Color(0xFF38BDF8), // Világoskék: Mérsékelt + nedves időben gyakori
      },
    ];

    const List<Map<String, dynamic>> otherDiseases = [
      {
        'id': 'kovi',
        'label': 'Kövi költés',
        'color': Color(0xFFFF5722), // Narancsvörös: Súlyos (zoonózis), ritka
      },
      {
        'id': 'kronikus_benulas',
        'label': 'Krónikus\nméhbénulás',
        'color': Color(0xFFFF7043), // Súlyos vírusos, szórványos
      },
      {
        'id': 'szeptikemia',
        'label': 'Szeptikémia /\nParatífusz',
        'color': Color(0xFFEC407A), // Súlyos bakteriális, ritka
      },
      {
        'id': 'dwv',
        'label': 'Deformált\nszárny vírus',
        'color': Color(0xFFAB47BC), // Atkához kötött vírus
      },
      {
        'id': 'tomlos',
        'label': 'Tömlős\nköltésrothadás',
        'color': Color(0xFFFF9800), // Közepes, időszakos
      },
      {
        'id': 'legcsoatka',
        'label': 'Légcsőatka-\nkór',
        'color': Color(0xFFFFB300), // Közepes, ritka
      },
      {
        'id': 'amoba',
        'label': 'Amőbás kór',
        'color': Color(0xFFFDD835), // Mérsékelt, ritka
      },
      {
        'id': 'teli_hasmenes',
        'label': 'Téli\nhasmenés',
        'color': Color(0xFF38BDF8), // Mérsékelt, nem fertőző
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final int activeOtherCount = otherDiseases
                .where((d) => hive.reportedDiseases.contains(d['id'] as String))
                .length;

            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    top: BorderSide(color: Colors.redAccent, width: 2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.15,
                      ),
                      itemCount: diseases.length,
                      itemBuilder: (_, idx) {
                        final d = diseases[idx];
                        final String dId = d['id'] as String;
                        final Color color = d['color'] as Color;
                        final bool isActive = hive.reportedDiseases.contains(dId) ||
                            (dId == 'nyulos' && hive.isQuarantined);
                        final bool useDarkTextOnFill =
                            color == const Color(0xFFFFC107) ||
                            color == const Color(0xFF38BDF8);

                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActive
                                ? color
                                : color.withAlpha(32),
                            foregroundColor: isActive
                                ? (useDarkTextOnFill ? Colors.black : Colors.white)
                                : color,
                            side: BorderSide(
                              color: color,
                              width: isActive ? 3.0 : 2.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: isActive ? 6 : 2,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            if (dId == 'nyulos' && !isActive) {
                              _confirmHansProtocol(
                                modalCtx,
                                hive,
                                repository,
                                onConfirmed: () {
                                  if (mounted) setState(() {});
                                },
                              );
                              return;
                            }
                            if (dId == 'nyulos' && hive.isQuarantined) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ Nyúlós költésrothadás zárlat nem vonható vissza egyszerű érintéssel!',
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              return;
                            }

                            final bool added = repository.toggleHiveDisease(
                              hive,
                              dId,
                            );
                            setModalState(() {});
                            if (mounted) setState(() {});

                            final cleanName = kHiveDiseaseLabels[dId] ?? dId;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added
                                      ? 'Lejelentve: $cleanName'
                                      : 'Visszavonva: $cleanName',
                                ),
                                backgroundColor: added
                                    ? Colors.deepOrange.shade800
                                    : Colors.blueGrey.shade700,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isActive) ...[
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: useDarkTextOnFill
                                      ? Colors.black
                                      : Colors.white,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  d['label'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    color: isActive
                                        ? (useDarkTextOnFill
                                            ? Colors.black
                                            : Colors.white)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeOtherCount > 0
                              ? Colors.blueGrey.shade700
                              : const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: activeOtherCount > 0
                                ? Colors.amberAccent
                                : Colors.white38,
                            width: 2.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.more_horiz, size: 24, color: Colors.amberAccent),
                        label: Text(
                          activeOtherCount > 0
                              ? 'Egyéb ($activeOtherCount)'
                              : 'Egyéb',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () {
                          _showOtherDiseasesDialog(
                            context: context,
                            hive: hive,
                            repository: repository,
                            otherDiseases: otherDiseases,
                            onChanged: () {
                              setModalState(() {});
                              if (mounted) setState(() {});
                            },
                          );
                        },
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

  void _showOtherDiseasesDialog({
    required BuildContext context,
    required HiveData hive,
    required HiveRepository repository,
    required List<Map<String, dynamic>> otherDiseases,
    required VoidCallback onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (subModalCtx, setSubModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    top: BorderSide(color: Colors.amberAccent, width: 2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.15,
                      ),
                      itemCount: otherDiseases.length,
                      itemBuilder: (_, idx) {
                        final d = otherDiseases[idx];
                        final String dId = d['id'] as String;
                        final Color color = d['color'] as Color;
                        final bool isActive = hive.reportedDiseases.contains(dId);
                        final bool useDarkTextOnFill =
                            color == const Color(0xFFFFB300) ||
                            color == const Color(0xFFFDD835) ||
                            color == const Color(0xFF38BDF8);

                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActive
                                ? color
                                : color.withAlpha(32),
                            foregroundColor: isActive
                                ? (useDarkTextOnFill ? Colors.black : Colors.white)
                                : color,
                            side: BorderSide(
                              color: color,
                              width: isActive ? 3.0 : 2.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: isActive ? 6 : 2,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            final bool added = repository.toggleHiveDisease(
                              hive,
                              dId,
                            );
                            setSubModalState(() {});
                            onChanged();

                            final cleanName = kHiveDiseaseLabels[dId] ?? dId;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added
                                      ? 'Lejelentve: $cleanName'
                                      : 'Visszavonva: $cleanName',
                                ),
                                backgroundColor: added
                                    ? Colors.deepOrange.shade800
                                    : Colors.blueGrey.shade700,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isActive) ...[
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: useDarkTextOnFill
                                      ? Colors.black
                                      : Colors.white,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  d['label'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    color: isActive
                                        ? (useDarkTextOnFill
                                            ? Colors.black
                                            : Colors.white)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  void _confirmHansProtocol(
    BuildContext context,
    HiveData hive,
    HiveRepository repository, {
    VoidCallback? onConfirmed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Colors.redAccent, width: 2.5),
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
                        color: Colors.red.shade900.withAlpha(140),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent, width: 2),
                      ),
                      child: const Icon(
                        Icons.local_fire_department,
                        color: Colors.redAccent,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nyúlós költésrothadás!',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kaptár: ${hive.name} (${hive.boxes.length} elem a toronyban)',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 12.5,
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
                    color: const Color(0xFF7F1D1D).withAlpha(140),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent, width: 1.4),
                  ),
                  child: const Text(
                    '🔥 AZONNALI HANS-PROTOKOLL A TELJES TORONYRA!\n\n'
                    '• Az összes fiók, aljdeszka, etető, pollengyűjtő és tető hatósági zárlat és megsemmisítés alá kerül.\n'
                    '• Semmilyen keret, fiók vagy méz nem kerülhet át máshova!\n'
                    '• Az automatikus szirupetetés és virágporgyűjtés azonnal leáll.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Biztosan aktiválod a Hans-protokollt a teljes toronyra?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 3,
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close, size: 22),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'MÉGSE',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.amberAccent, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                          onPressed: () {
                            repository.activateHansProtocol(hive);
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            onConfirmed?.call();
                            Navigator.pop(dialogCtx);
                            Navigator.pop(context);
                            messenger?.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '🔥 HANS-PROTOKOLL AKTIVÁLVA: ${hive.name} teljes tornya zárlat alá került!',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: Colors.red.shade800,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                          icon: const Icon(Icons.local_fire_department, size: 22),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'IGEN, HANS!',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
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
      ),
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

  void _openColonyClassificationDialog(
    BuildContext context,
    HiveData hive,
    HiveRepository repository,
  ) {
    String selectedFunctionMenu = 'termeles';
    if (['dajka', 'anya', 'törzscsalád', 'tartalék'].contains(hive.familyFunction)) {
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
                'id': 'törzscsalád',
                'name': 'Törzscsalád',
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
                          final bool isSel = hive.familyFunction == cat['id'] ||
                              (cat['id'] == 'törzscsalád' &&
                                  hive.familyFunction == 'anya');
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
                                            repository.activateHansProtocol(hive);
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                          child: const Text('Igen, Hans (Elpusztítás)'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  final String newFnId = cat['id'] as String;
                                  final String newFnName = cat['name'] as String;
                                  void applyNewFunction() {
                                    setModalState(() {
                                      hive.familyFunction = newFnId;
                                      if (newFnId != 'Hans' && hive.protocol == 'hans') {
                                        hive.protocol = 'standard';
                                      }
                                    });
                                    setState(() {});
                                    repository.updateHive(
                                      hive,
                                      historyEventType: 'funkcio_valtozas',
                                      historyDescription:
                                          'Család funkciója módosítva: $newFnName ($newFnId).',
                                    );
                                  }

                                  final towerMismatches =
                                      findExistingTowerMismatchesForFunction(
                                        hive,
                                        newFnId,
                                      );
                                  if (towerMismatches.isNotEmpty) {
                                    showFunctionChangeTowerMismatchDialog(
                                      context: context,
                                      hive: hive,
                                      newFunctionLabel: newFnName,
                                      mismatches: towerMismatches,
                                      onConfirm: () {
                                        repository.logHistoryEvent(
                                          hive.id,
                                          'torony_funkcio_elteres',
                                          'Funkció átállítva ($newFnName) fennlévő eltérő elemekkel: ${towerMismatches.map((m) => m.elementLabel).join(", ")}.',
                                        );
                                        applyNewFunction();
                                      },
                                    );
                                  } else {
                                    applyNewFunction();
                                  }
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
                                if (hive.isRelapsedAfterStrengthening) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7F1D1D).withAlpha(140),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amberAccent, width: 1.3),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.priority_high_rounded, color: Colors.amberAccent, size: 16),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'A család erősítés után ismét legyengült a többihez képest – javasolt az anya ellenőrzése vagy sürgős cseréje!',
                                            style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
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
                                          repository.updateHive(
                                            hive,
                                            historyEventType: 'anyacsere_visszavonas',
                                            historyDescription: 'Anyacsere jelölés visszavonva.',
                                          );
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
                                      repository.updateHive(
                                        hive,
                                        historyEventType: 'anyacsere_jeloles',
                                        historyDescription: 'Sürgős anyacsere megjelölve.',
                                      );
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
                                trailing: isSelected
                                    ? Icon(Icons.check_circle, color: color, size: 24)
                                    : null,
                                onTap: () {
                                  setModalState(() {
                                    hive.status = st['key'] as String;
                                  });
                                  setState(() {});
                                  repository.updateHive(
                                    hive,
                                    historyEventType: 'statusz_valtozas',
                                    historyDescription:
                                        'Család állapota módosítva: ${st["label"]}.',
                                  );
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
                              Row(
                                children: [
                                  const Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Tenyészbírálati jegyek (Gyors minősítés):',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        hive.resetEvaluation(
                                          newQueenId: hive.queen?.id,
                                          reason: 'Tiszta lap - kézi alaphelyzetbe állítás',
                                        );
                                      });
                                      setState(() {});
                                      repository.updateHive(
                                        hive,
                                        historyEventType: 'biralat_alaphelyzet',
                                        historyDescription:
                                            'Tenyészbírálati minősítés alaphelyzetbe állítva (Tiszta lap).',
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Család minősítése alaphelyzetbe állítva (Tiszta lap)!'),
                                          backgroundColor: Colors.teal,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.refresh, size: 14, color: Colors.amberAccent),
                                    label: const Text(
                                      'Alaphelyzet',
                                      style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              if (hive.evaluation.notes.contains('Tiszta lap') || hive.queenReplacementState != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withAlpha(35),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.tealAccent.withAlpha(100)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          hive.evaluation.notes.isNotEmpty
                                              ? hive.evaluation.notes
                                              : 'Tiszta lap aktív - Új anya behelyezve, minősítések alapállapotban.',
                                          style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (hive.isFreshlyStrengthened && !hive.isRelapsedAfterStrengthening) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amberAccent.withAlpha(110)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.block, color: Colors.amberAccent, size: 15),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Frissen felerősített család (${hive.strengthenedDaysAgo} napja): külső erősítés miatt még ${hive.rekorderCooldownDaysRemaining} napig nem kaphat Rekorder státuszt.',
                                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              _buildTraitRow('Szelídség', hive.evaluation.temperament, (val) {
                                setModalState(() => hive.evaluation.temperament = val);
                                setState(() {});
                                repository.updateHive(
                                  hive,
                                  historyEventType: 'tenyeszbiralat',
                                  historyDescription: 'Tenyészbírálat módosítva – Szelídség: $val',
                                );
                              }),
                              _buildTraitRow('Tisztogató hajlam (VSH)', hive.evaluation.hygiene, (val) {
                                setModalState(() => hive.evaluation.hygiene = val);
                                setState(() {});
                                repository.updateHive(
                                  hive,
                                  historyEventType: 'tenyeszbiralat',
                                  historyDescription: 'Tenyészbírálat módosítva – Tisztogató hajlam (VSH): $val',
                                );
                              }),
                              _buildTraitRow('Gyűjtési hajlam', hive.evaluation.gathering, (val) {
                                setModalState(() => hive.evaluation.gathering = val);
                                setState(() {});
                                repository.updateHive(
                                  hive,
                                  historyEventType: 'tenyeszbiralat',
                                  historyDescription: 'Tenyészbírálat módosítva – Gyűjtési hajlam: $val',
                                );
                              }),
                              _buildTraitRow('Rajzási hajlam', hive.evaluation.swarming, (val) {
                                setModalState(() => hive.evaluation.swarming = val);
                                setState(() {});
                                repository.updateHive(
                                  hive,
                                  historyEventType: 'tenyeszbiralat',
                                  historyDescription: 'Tenyészbírálat módosítva – Rajzási hajlam: $val',
                                );
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
