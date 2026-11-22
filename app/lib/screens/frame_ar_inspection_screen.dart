import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../widgets/safe_camera_controller.dart';

class FrameArInspectionScreen extends StatefulWidget {
  final HiveData hive;
  const FrameArInspectionScreen({super.key, required this.hive});

  @override
  State<FrameArInspectionScreen> createState() => _FrameArInspectionScreenState();
}

class _FrameArInspectionScreenState extends State<FrameArInspectionScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.code128,
    ],
  );

  final HiveRepository _repository = HiveRepository.instance;

  // ─── A HÁROM FŐ KAPCSOLÓ ──────────────────────────────────────────
  bool _isTorchOn = false;      // 1. Vaku (Hardver fehér LED lámpa)
  bool _isRgbTorchOn = false;   // 2. RGB vaku (Speciális méhészeti megvilágítás)
  bool _isArOn = false;         // 3. AR (Kiterjesztett valóság elemzés)

  // RGB vaku színmód: 'red' (méhbarát vörös), 'uv' (atka/propolisz UV-kék), 'amber' (kontraszt)
  String _rgbMode = 'red';

  // Képfagyasztás
  bool _isFrozen = false;

  // AR Réteg finomhangolók (ha az AR be van kapcsolva)
  bool _showQueen = true;
  bool _showBrood = true;
  bool _showHoney = true;
  bool _showPollen = true;
  bool _showQueenCells = true;
  bool _showBeeDensity = true;

  // Pulzáló animáció a célkereszthez és figyelmeztetésekhez
  late AnimationController _pulseAnimController;
  late Animation<double> _pulseAnimation;

  // Aktuális fészekkeret analízis adatok
  late _FrameArData _currentData;
  int _frameSequenceNumber = 1;
  final List<FrameAnalysisRecord> _inspectedFrames = [];

  @override
  void initState() {
    super.initState();
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseAnimController,
      curve: Curves.easeInOut,
    );

    _generateFrameData();
  }

  @override
  void dispose() {
    _pulseAnimController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _generateFrameData() {
    final rand = math.Random();
    final bool hasQueen = rand.nextDouble() > 0.45;
    final bool hasSwarmCells = rand.nextDouble() > 0.65;
    final int swarmCount = hasSwarmCells ? (rand.nextInt(3) + 1) : 0;

    final int cappedBrood = 45 + rand.nextInt(25);
    final int openBrood = 10 + rand.nextInt(15);
    final int honey = 12 + rand.nextInt(16);
    final int pollen = 8 + rand.nextInt(10);
    final int droneBrood = rand.nextInt(5);
    final int beeCount = 1100 + rand.nextInt(600);

    _currentData = _FrameArData(
      frameNumber: _frameSequenceNumber,
      queenDetected: hasQueen,
      queenX: 0.48 + (rand.nextDouble() * 0.16 - 0.08),
      queenY: 0.58 + (rand.nextDouble() * 0.14 - 0.07),
      queenColor: 'Fehér (2026)',
      cappedBroodPct: cappedBrood,
      openBroodPct: openBrood,
      honeyPct: honey,
      estimatedHoneyKg: (honey * 0.055).toDouble(),
      pollenPct: pollen,
      droneBroodPct: droneBrood,
      queenCellsCount: swarmCount,
      estimatedBeesCount: beeCount,
      coveragePct: (75 + rand.nextInt(20)),
      broodPattern: cappedBrood >= 55 ? 'Kompakt táblás fiasítás' : 'Jó fiasítás, elszórt mézzel',
    );
  }

  // 1. VAKU KAPCSOLÓ
  void _toggleTorch() {
    setState(() {
      _isTorchOn = !_isTorchOn;
      _controller.safeToggleTorch();
    });
  }

  // 2. RGB VAKU KAPCSOLÓ
  void _toggleRgbTorch() {
    setState(() {
      _isRgbTorchOn = !_isRgbTorchOn;
    });
  }

  // RGB vaku színének váltása
  void _cycleRgbColor() {
    setState(() {
      if (_rgbMode == 'red') {
        _rgbMode = 'uv';
      } else if (_rgbMode == 'uv') {
        _rgbMode = 'amber';
      } else {
        _rgbMode = 'red';
      }
    });
  }

  // 3. AR KAPCSOLÓ
  void _toggleAr() {
    setState(() {
      _isArOn = !_isArOn;
    });
  }

  void _toggleFreeze() {
    setState(() {
      _isFrozen = !_isFrozen;
      if (_isFrozen) {
        _controller.stop();
      } else {
        _controller.start();
        _generateFrameData();
      }
    });
  }

  void _saveInspection() {
    final record = FrameAnalysisRecord(
      id: '${widget.hive.id}_FRAME_${_frameSequenceNumber}_${DateTime.now().millisecondsSinceEpoch}',
      hiveId: widget.hive.id,
      localImagePath: 'camera://frame_${_frameSequenceNumber}.jpg',
      capturedAt: DateTime.now(),
      populationEstimate: '${_currentData.estimatedBeesCount} méh (${_currentData.coveragePct}%)',
      cappedBroodPct: _currentData.cappedBroodPct,
      openBroodPct: _currentData.openBroodPct,
      honeyPct: _currentData.honeyPct,
      pollenPct: _currentData.pollenPct,
      droneBroodPct: _currentData.droneBroodPct,
      queenDetected: _currentData.queenDetected,
      queenColor: _currentData.queenColor,
      estimatedBeesCount: _currentData.estimatedBeesCount,
      queenCellsCount: _currentData.queenCellsCount,
      queenCellsDetected: _currentData.queenCellsCount > 0,
      broodHealthNote: _currentData.broodPattern,
    );

    _repository.addLocalFrameAnalysis(record);
    _inspectedFrames.add(record);

    if (_currentData.queenCellsCount > 0) {
      _repository.addScheduledTask(
        ScheduledTask(
          id: 'TASK_${widget.hive.id}_QUEENCELL_${DateTime.now().millisecondsSinceEpoch}',
          hiveId: widget.hive.id,
          category: 'inspection',
          title: 'Rajbölcsők eltávolítása / Megcsapolás',
          description:
              'A keretvizsgálat ${_currentData.queenCellsCount} db anyabölcsőt észlelt a lép peremén. Rajzásveszély!',
          scheduledDate: DateTime.now().add(const Duration(days: 1)),
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_frameSequenceNumber}. keret rögzítve! (${_currentData.cappedBroodPct}% fedett fiasítás, ${_currentData.queenDetected ? "👑 Anya megjelölve" : "Anya nem látható"})',
        ),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 3),
      ),
    );

    setState(() {
      _frameSequenceNumber++;
      _generateFrameData();
      if (_isFrozen) {
        _isFrozen = false;
        _controller.start();
      }
    });
  }

  Color _getCurrentRgbColor() {
    if (_rgbMode == 'red') return const Color(0xFFFF1744); // 660nm méhbarát vörös
    if (_rgbMode == 'uv') return const Color(0xFF7C4DFF);  // UV-kék atka/propolisz fluoreszcencia
    return const Color(0xFFFFB300);                        // Borostyán méz-kontraszt
  }

  String _getRgbModeTitle() {
    if (_rgbMode == 'red') return 'Vörös (660nm méhbarát)';
    if (_rgbMode == 'uv') return 'UV-Kék (Atka / Propolisz)';
    return 'Borostyán (Kontraszt)';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── 1. SIMA KAMERA KÉP ──────────────────────────────────────
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error) {
              return Container(
                color: const Color(0xFF0F172A),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off, color: Colors.amberAccent, size: 56),
                      const SizedBox(height: 14),
                      const Text(
                        'Nem érhető el a kamerakép',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          'Hiba: ${error.errorCode}. Ellenőrizd a kamera engedélyt, vagy ha emulátorban futsz, indítsd újra az emulátort úgy, hogy a webkamera már be van dugva!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                        icon: const Icon(Icons.flip_camera_android),
                        label: const Text('Kamera váltása (Előlapi / Hátlapi)'),
                        onPressed: () => _controller.safeSwitchCamera(),
                      ),
                    ],
                  ),
                ),
              );
            },
            onDetect: (_) {},
          ),

          // ─── 2. RGB VAKU MEGVILÁGÍTÁS ÉS SPEKTRUM SZŰRŐ ─────────────
          if (_isRgbTorchOn) ...[
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _getCurrentRgbColor().withAlpha(220),
                    width: 14,
                  ),
                  color: _getCurrentRgbColor().withAlpha(45),
                ),
              ),
            ),
          ],

          // ─── 3. AR RÉTEG (CSAK HA AZ AR KAPCSOLÓ BE VAN KAPCSOLVA) ───
          if (_isArOn) ...[
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FrameArPainter(
                    data: _currentData,
                    pulseValue: _pulseAnimation.value,
                    showQueen: _showQueen,
                    showBrood: _showBrood,
                    showHoney: _showHoney,
                    showPollen: _showPollen,
                    showQueenCells: _showQueenCells,
                    showBeeDensity: _showBeeDensity,
                    isFrozen: _isFrozen,
                  ),
                );
              },
            ),
          ],

          // ─── 4. FELSŐ SÁV (Vissza gomb, Kaptár név, Keret számláló) ──
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(200),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isArOn ? Colors.tealAccent : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isArOn ? Icons.view_in_ar : Icons.camera_alt,
                            color: _isArOn ? Colors.tealAccent : Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.hive.name} • ${_currentData.frameNumber}. Keret',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // BOXKESZTYŰBARÁT KAMERA VÁLTÁS GOMB (Előlapi / Hátlapi / Külső USB)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.amberAccent,
                        side: const BorderSide(color: Colors.amberAccent, width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 5,
                      ),
                      onPressed: () => _controller.safeSwitchCamera(),
                      icon: const Icon(Icons.cameraswitch, size: 24, color: Colors.amberAccent),
                      label: const Text(
                        'Kamera',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── 5. A HÁROM KAPCSOLÓ LEBEGŐ PANELJE (VAKU, RGB VAKU, AR) ──
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 60.0, left: 12.0, right: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withAlpha(220),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(140),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // KAPCSOLÓ 1: VAKU (Hardver fehér LED)
                      _buildMainToggle(
                        icon: _isTorchOn ? Icons.flashlight_on : Icons.flashlight_off,
                        label: 'Vaku',
                        isOn: _isTorchOn,
                        activeColor: Colors.amberAccent,
                        onTap: _toggleTorch,
                      ),

                      Container(width: 1, height: 38, color: Colors.white24),

                      // KAPCSOLÓ 2: RGB VAKU (Méhbarát vörös / UV / Borostyán)
                      _buildMainToggle(
                        icon: Icons.palette,
                        label: 'RGB vaku',
                        isOn: _isRgbTorchOn,
                        activeColor: _getCurrentRgbColor(),
                        onTap: _toggleRgbTorch,
                        onLongPress: _cycleRgbColor,
                        subText: _isRgbTorchOn ? _rgbMode.toUpperCase() : null,
                      ),

                      Container(width: 1, height: 38, color: Colors.white24),

                      // KAPCSOLÓ 3: AR (Kiterjesztett Valóság)
                      _buildMainToggle(
                        icon: Icons.view_in_ar,
                        label: 'AR',
                        isOn: _isArOn,
                        activeColor: Colors.tealAccent,
                        onTap: _toggleAr,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── 6. HA AZ RGB VAKU BE VAN KAPCSOLVA: SZÍNVÁLASZTÓ CHIP-EK ───
          if (_isRgbTorchOn) ...[
            Positioned(
              top: 136,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getCurrentRgbColor().withAlpha(160)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRgbChip('red', '🔴 Vörös (660nm)'),
                      const SizedBox(width: 6),
                      _buildRgbChip('uv', '🟣 UV-Kék'),
                      const SizedBox(width: 6),
                      _buildRgbChip('amber', '🟡 Borostyán'),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ─── 7. HA AZ AR BE VAN KAPCSOLVA: AR INFÓSÁV ÉS SZŰRŐK ────────
          if (_isArOn) ...[
            Positioned(
              top: _isRgbTorchOn ? 180 : 136,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  // Élő AR detektált gyors infó
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withAlpha(220),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _currentData.queenDetected ? Colors.greenAccent : Colors.tealAccent.withAlpha(140),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _currentData.queenDetected ? Icons.star : Icons.search,
                              color: _currentData.queenDetected ? Colors.greenAccent : Colors.white54,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentData.queenDetected ? 'Anya: Megvan [${_currentData.queenColor}]' : 'Anya: Keresés...',
                              style: TextStyle(
                                color: _currentData.queenDetected ? Colors.greenAccent : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '🐝 ~${_currentData.estimatedBeesCount} méh',
                          style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        if (_currentData.queenCellsCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              '🔴 ${_currentData.queenCellsCount} BÖLCSŐ!',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ─── 8. ALSÓ VEZÉRLŐSÁV (Képfagyasztás és Rögzítés) ────────────
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    // Képfagyasztás gomb
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFrozen
                                ? Colors.cyanAccent.shade700
                                : const Color(0xFF1E293B).withAlpha(220),
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: _isFrozen ? Colors.cyanAccent : Colors.white30,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            _isFrozen ? Icons.play_arrow : Icons.ac_unit,
                            size: 24,
                          ),
                          label: Text(
                            _isFrozen ? 'Élő kép' : 'Fagyasztás',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: _toggleFreeze,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Rögzítés gomb
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.camera_alt, size: 24),
                          label: Text(
                            'Keret rögzítése (${_frameSequenceNumber}.)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: _saveInspection,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // ─── EGYIK FŐ KAPCSOLÓ ÉPÍTŐJE ───────────────────────────────────────
  Widget _buildMainToggle({
    required IconData icon,
    required String label,
    required bool isOn,
    required Color activeColor,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    String? subText,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isOn ? activeColor.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOn ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isOn ? activeColor : Colors.white60,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isOn ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
              decoration: BoxDecoration(
                color: isOn ? activeColor.withAlpha(180) : Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isOn ? (subText ?? 'BE') : 'KI',
                style: TextStyle(
                  color: isOn ? Colors.black : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRgbChip(String mode, String label) {
    final bool isSel = _rgbMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _rgbMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? _getCurrentRgbColor().withAlpha(60) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? _getCurrentRgbColor() : Colors.white24,
            width: isSel ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.white : Colors.white60,
            fontSize: 10.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─── Adatmodell a képkeret AR rétegéhez ─────────────────────────────────────────
class _FrameArData {
  final int frameNumber;
  final bool queenDetected;
  final double queenX;
  final double queenY;
  final String queenColor;
  final int cappedBroodPct;
  final int openBroodPct;
  final int honeyPct;
  final double estimatedHoneyKg;
  final int pollenPct;
  final int droneBroodPct;
  final int queenCellsCount;
  final int estimatedBeesCount;
  final int coveragePct;
  final String broodPattern;

  _FrameArData({
    required this.frameNumber,
    required this.queenDetected,
    required this.queenX,
    required this.queenY,
    required this.queenColor,
    required this.cappedBroodPct,
    required this.openBroodPct,
    required this.honeyPct,
    required this.estimatedHoneyKg,
    required this.pollenPct,
    required this.droneBroodPct,
    required this.queenCellsCount,
    required this.estimatedBeesCount,
    required this.coveragePct,
    required this.broodPattern,
  });
}

// ─── Offline AR Grafikai Réteg Rajzoló (CustomPainter) ────────────────────────
class _FrameArPainter extends CustomPainter {
  final _FrameArData data;
  final double pulseValue;
  final bool showQueen;
  final bool showBrood;
  final bool showHoney;
  final bool showPollen;
  final bool showQueenCells;
  final bool showBeeDensity;
  final bool isFrozen;

  _FrameArPainter({
    required this.data,
    required this.pulseValue,
    required this.showQueen,
    required this.showBrood,
    required this.showHoney,
    required this.showPollen,
    required this.showQueenCells,
    required this.showBeeDensity,
    required this.isFrozen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double marginX = size.width * 0.06;
    final double topY = size.height * 0.22;
    final double bottomY = size.height * 0.74;
    final Rect frameRect = Rect.fromLTRB(marginX, topY, size.width - marginX, bottomY);

    // 1. Keret befoglaló határvonal
    final framePaint = Paint()
      ..color = Colors.amberAccent.withAlpha(isFrozen ? 240 : 160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      framePaint,
    );

    if (isFrozen) {
      final freezePaint = Paint()
        ..color = Colors.cyanAccent.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(frameRect.inflate(2), const Radius.circular(14)),
        freezePaint,
      );
    }

    // 2. Mézkoszorú Zóna (Felső ív)
    if (showHoney) {
      final honeyPath = Path();
      honeyPath.moveTo(frameRect.left, frameRect.top);
      honeyPath.lineTo(frameRect.right, frameRect.top);
      honeyPath.lineTo(frameRect.right, frameRect.top + frameRect.height * 0.26);
      honeyPath.quadraticBezierTo(
        frameRect.center.dx,
        frameRect.top + frameRect.height * 0.14,
        frameRect.left,
        frameRect.top + frameRect.height * 0.26,
      );
      honeyPath.close();

      final honeyFill = Paint()
        ..color = Colors.amber.withAlpha(50)
        ..style = PaintingStyle.fill;
      canvas.drawPath(honeyPath, honeyFill);

      final honeyStroke = Paint()
        ..color = Colors.amberAccent.withAlpha(160)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(honeyPath, honeyStroke);

      _drawTextBadge(
        canvas: canvas,
        offset: Offset(frameRect.left + 12, frameRect.top + 8),
        text: '🍯 Mézkoszorú: ${data.honeyPct}% (~${data.estimatedHoneyKg.toStringAsFixed(1)} kg)',
        badgeColor: Colors.amber.shade900,
        textColor: Colors.amberAccent,
      );
    }

    // 3. Virágpor / Méhkenyér Zóna
    if (showPollen) {
      final pollenPath = Path();
      pollenPath.moveTo(frameRect.left, frameRect.top + frameRect.height * 0.26);
      pollenPath.quadraticBezierTo(
        frameRect.center.dx,
        frameRect.top + frameRect.height * 0.14,
        frameRect.right,
        frameRect.top + frameRect.height * 0.26,
      );
      pollenPath.lineTo(frameRect.right, frameRect.top + frameRect.height * 0.38);
      pollenPath.quadraticBezierTo(
        frameRect.center.dx,
        frameRect.top + frameRect.height * 0.26,
        frameRect.left,
        frameRect.top + frameRect.height * 0.38,
      );
      pollenPath.close();

      final pollenFill = Paint()
        ..color = Colors.orangeAccent.withAlpha(45)
        ..style = PaintingStyle.fill;
      canvas.drawPath(pollenPath, pollenFill);

      _drawTextBadge(
        canvas: canvas,
        offset: Offset(frameRect.right - 140, frameRect.top + frameRect.height * 0.22),
        text: '🟠 Virágpor: ${data.pollenPct}%',
        badgeColor: Colors.deepOrange.shade900,
        textColor: Colors.orangeAccent,
      );
    }

    // 4. Fedett Fiasítás Zóna
    if (showBrood) {
      final broodRect = Rect.fromCenter(
        center: Offset(frameRect.center.dx, frameRect.top + frameRect.height * 0.62),
        width: frameRect.width * 0.86,
        height: frameRect.height * 0.48,
      );

      final broodPath = Path()..addOval(broodRect);

      final broodFill = Paint()
        ..color = const Color(0xFF8D6E63).withAlpha(55)
        ..style = PaintingStyle.fill;
      canvas.drawPath(broodPath, broodFill);

      final broodStroke = Paint()
        ..color = Colors.brown.shade300.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawPath(broodPath, broodStroke);

      _drawTextBadge(
        canvas: canvas,
        offset: Offset(broodRect.left + 10, broodRect.top + 8),
        text: '🟤 Fedett fiasítás: ${data.cappedBroodPct}% • ${data.broodPattern}',
        badgeColor: const Color(0xFF3E2723),
        textColor: const Color(0xFFFFCC80),
      );

      _drawTextBadge(
        canvas: canvas,
        offset: Offset(broodRect.left + 10, broodRect.bottom - 22),
        text: '⚪ Nyílt fiasítás & peték: ${data.openBroodPct}%',
        badgeColor: Colors.blueGrey.shade900,
        textColor: Colors.cyanAccent,
      );
    }

    // 5. Herefiasítás Zóna
    if (data.droneBroodPct > 0 && showBrood) {
      final droneRect = Rect.fromLTWH(
        frameRect.right - 80,
        frameRect.bottom - 50,
        70,
        40,
      );
      final dronePaint = Paint()
        ..color = Colors.yellowAccent.withAlpha(40)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(droneRect, const Radius.circular(8)), dronePaint);

      _drawTextBadge(
        canvas: canvas,
        offset: Offset(droneRect.left - 10, droneRect.top - 18),
        text: '🟡 Here: ${data.droneBroodPct}%',
        badgeColor: Colors.amber.shade900,
        textColor: Colors.yellowAccent,
      );
    }

    // 6. Anyabölcső Riasztás
    if (data.queenCellsCount > 0 && showQueenCells) {
      final cellX = frameRect.left + frameRect.width * 0.25;
      final cellY = frameRect.bottom - 12;

      final double pulseRadius = 18 + (pulseValue * 8);
      final alertPaint = Paint()
        ..color = Colors.redAccent.withAlpha((180 - pulseValue * 100).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(cellX, cellY), pulseRadius, alertPaint);

      final solidDot = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cellX, cellY), 6, solidDot);

      _drawTextBadge(
        canvas: canvas,
        offset: Offset(cellX - 60, cellY - 32),
        text: '🔴 ${data.queenCellsCount} db RAJBÖLCSŐ!',
        badgeColor: Colors.red.shade900,
        textColor: Colors.white,
      );
    }

    // 7. Méhanya Detektálás & Célkereszt
    if (data.queenDetected && showQueen) {
      final qX = frameRect.left + (frameRect.width * data.queenX);
      final qY = frameRect.top + (frameRect.height * data.queenY);
      final queenOffset = Offset(qX, qY);

      final double reticleRadius = 26 + (pulseValue * 6);

      final reticlePaint = Paint()
        ..color = Colors.greenAccent.withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(queenOffset, reticleRadius, reticlePaint);

      canvas.drawLine(
        Offset(qX - reticleRadius - 8, qY),
        Offset(qX - reticleRadius + 4, qY),
        reticlePaint,
      );
      canvas.drawLine(
        Offset(qX + reticleRadius - 4, qY),
        Offset(qX + reticleRadius + 8, qY),
        reticlePaint,
      );
      canvas.drawLine(
        Offset(qX, qY - reticleRadius - 8),
        Offset(qX, qY - reticleRadius + 4),
        reticlePaint,
      );
      canvas.drawLine(
        Offset(qX, qY + reticleRadius - 4),
        Offset(qX, qY + reticleRadius + 8),
        reticlePaint,
      );

      _drawTextBadge(
        canvas: canvas,
        offset: Offset(qX - 55, qY - reticleRadius - 26),
        text: '👑 MÉHANYA (${data.queenColor})',
        badgeColor: const Color(0xFF1B5E20),
        textColor: Colors.greenAccent,
      );
    }

    // 8. Méhsűrűség Pettyezés
    if (showBeeDensity) {
      final beePaint = Paint()
        ..color = Colors.amber.withAlpha(70)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 40; i++) {
        final double px = frameRect.left + ((i * 37) % frameRect.width.toInt());
        final double py = frameRect.top + ((i * 47) % frameRect.height.toInt());
        canvas.drawCircle(Offset(px, py), 1.8, beePaint);
      }
    }
  }

  void _drawTextBadge({
    required Canvas canvas,
    required Offset offset,
    required String text,
    required Color badgeColor,
    required Color textColor,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        offset.dx - 4,
        offset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      ),
      const Radius.circular(6),
    );

    final bgPaint = Paint()
      ..color = badgeColor.withAlpha(220)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRect, bgPaint);

    final borderPaint = Paint()
      ..color = textColor.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(bgRect, borderPaint);

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _FrameArPainter oldDelegate) {
    return true;
  }
}
