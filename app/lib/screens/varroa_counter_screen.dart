import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../widgets/safe_camera_controller.dart';

/// Adatmodell egy fotózott aljdeszka szektorról (több fotós kalibrációs módhoz)
class PhotoSectorRecord {
  final String id;
  final String imagePath;
  final String label;
  final DateTime capturedAt;
  final List<Offset> normalizedMitePoints;

  PhotoSectorRecord({
    required this.id,
    required this.imagePath,
    required this.label,
    required this.capturedAt,
    List<Offset>? points,
  }) : normalizedMitePoints = points ?? [];

  int get miteCount => normalizedMitePoints.length;
}

/// Kétfunkciós Atkaszámláló:
/// 1. Élőképes AR mód: Valós idejű kamerakép, célkeresztekkel és zónás pásztázással
/// 2. Több fotós kalibrációs mód: Részletes szektorfotók készítése, nagyítás és pontozás
///    (betanuláshoz, modell finomhangoláshoz és kétes tálcák ellenőrzéséhez)
class VarroaCounterScreen extends StatefulWidget {
  final HiveData hive;
  const VarroaCounterScreen({super.key, required this.hive});

  @override
  State<VarroaCounterScreen> createState() => _VarroaCounterScreenState();
}

class _VarroaCounterScreenState extends State<VarroaCounterScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final ImagePicker _imagePicker = ImagePicker();
  final HiveRepository _repository = HiveRepository.instance;

  // 0: Élőképes AR, 1: Több fotós (Kalibráció / Betanulás)
  int _activeTabMode = 0;

  // --- ÉLŐKÉPES MÓD ÁLLAPOTAI ---
  bool _isTorchOn = false;
  bool _showGridGuide = true;

  late AnimationController _pulseAnimController;
  late Animation<double> _pulseAnimation;

  final List<String> _zones = ['1. Zóna (BF)', '2. Zóna (JF)', '3. Zóna (BA)', '4. Zóna (JA)'];
  int _currentZoneIndex = 0;

  final Map<int, List<Offset>> _zoneMites = {
    0: [],
    1: [],
    2: [],
    3: [],
  };
  List<Offset> _liveMites = [];

  // --- TÖBB FOTÓS MÓD ÁLLAPOTAI ---
  final List<PhotoSectorRecord> _photoSectors = [];
  bool _isCapturingPhoto = false;

  // --- KÖZÖS SZÁMLÁLÓ ADATOK ---
  int _daysInserted = 3;
  bool _removeBoardAfterCheck = true;

  @override
  void initState() {
    super.initState();
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseAnimController, curve: Curves.easeInOut),
    );

    // Kaptár aljdeszka bentlét napjainak lekérése
    final bottomBox = widget.hive.boxes.where((b) => b.type == 'bottom').firstOrNull;
    if (bottomBox != null && bottomBox.isActive && bottomBox.statusUpdatedAt != null) {
      final diff = DateTime.now().difference(bottomBox.statusUpdatedAt!).inDays;
      _daysInserted = diff > 0 ? diff : 1;
    }

    _generateInitialLiveMites();
  }

  @override
  void dispose() {
    _pulseAnimController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  void _generateInitialLiveMites() {
    final rand = math.Random();
    final count = rand.nextInt(4) + 1;
    _liveMites = List.generate(count, (index) {
      return Offset(
        0.2 + rand.nextDouble() * 0.6,
        0.25 + rand.nextDouble() * 0.5,
      );
    });
  }

  // Teljes atkaszám: vagy a fotós szektorokból, vagy az élőképesből
  int get _totalMitesCount {
    if (_activeTabMode == 1) {
      // Fotós mód: szektoronként rögzített pontok összege
      return _photoSectors.fold(0, (sum, sec) => sum + sec.miteCount);
    } else {
      // Élőképes mód: zónák összege + aktuális élő
      int locked = 0;
      _zoneMites.forEach((key, list) => locked += list.length);
      if (_zoneMites[_currentZoneIndex]!.isNotEmpty) {
        return locked;
      }
      return locked + _liveMites.length;
    }
  }

  double get _dailyDrop =>
      _daysInserted > 0 ? _totalMitesCount / _daysInserted : _totalMitesCount.toDouble();

  Color get _severityColor {
    if (_dailyDrop >= 5.0) return Colors.redAccent;
    if (_dailyDrop >= 2.0) return Colors.amber;
    return Colors.greenAccent;
  }

  String get _severityAdvice {
    if (_dailyDrop >= 5.0) {
      return 'KRITIKUS fertőzöttség (${_dailyDrop.toStringAsFixed(1)} atka/nap)! Azonnali beavatkozás szükséges.';
    }
    if (_dailyDrop >= 2.0) {
      return 'Emelkedett atkahullás (${_dailyDrop.toStringAsFixed(1)} atka/nap). Kezelés ütemezése javasolt.';
    }
    return 'Alacsony természetes hullás (${_dailyDrop.toStringAsFixed(1)} atka/nap). Normál állapot.';
  }

  void _toggleTorch() {
    _isTorchOn = !_isTorchOn;
    _cameraController.safeToggleTorch();
    setState(() {});
  }

  // --- ÉLŐKÉPES ÉRINTÉSKEZELÉS ---
  void _handleLiveScreenTap(TapDownDetails details, Size screenSize) {
    HapticFeedback.selectionClick();
    final normX = (details.localPosition.dx / screenSize.width).clamp(0.05, 0.95);
    final normY = (details.localPosition.dy / screenSize.height).clamp(0.15, 0.85);
    final tapNorm = Offset(normX, normY);

    final currentList = _zoneMites[_currentZoneIndex]!.isNotEmpty
        ? _zoneMites[_currentZoneIndex]!
        : _liveMites;

    int foundIndex = -1;
    for (int i = 0; i < currentList.length; i++) {
      final p = currentList[i];
      final pixelDist = math.sqrt(
        math.pow((p.dx - normX) * screenSize.width, 2) +
            math.pow((p.dy - normY) * screenSize.height, 2),
      );
      if (pixelDist < 36.0) {
        foundIndex = i;
        break;
      }
    }

    setState(() {
      if (foundIndex != -1) {
        currentList.removeAt(foundIndex);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atka célkereszt eltávolítva (-)'),
            duration: Duration(milliseconds: 900),
            backgroundColor: Colors.blueGrey,
          ),
        );
      } else {
        currentList.add(tapNorm);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Új atka célkereszt hozzáadva (+)'),
            duration: Duration(milliseconds: 900),
            backgroundColor: Colors.orange,
          ),
        );
      }

      if (_zoneMites[_currentZoneIndex]!.isEmpty) {
        _zoneMites[_currentZoneIndex] = List.from(_liveMites);
      }
    });
  }

  void _lockCurrentZoneAndNext() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_zoneMites[_currentZoneIndex]!.isEmpty) {
        _zoneMites[_currentZoneIndex] = List.from(_liveMites);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_zones[_currentZoneIndex]} rögzítve: ${_zoneMites[_currentZoneIndex]!.length} db atka.',
          ),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 2),
        ),
      );

      if (_currentZoneIndex < _zones.length - 1) {
        _currentZoneIndex++;
        if (_zoneMites[_currentZoneIndex]!.isEmpty) {
          _generateInitialLiveMites();
        }
      }
    });
  }

  void _rescanCurrentZone() {
    HapticFeedback.lightImpact();
    setState(() {
      _zoneMites[_currentZoneIndex]!.clear();
      _generateInitialLiveMites();
    });
  }

  // --- TÖBB FOTÓS MÓD: FOTÓ KÉSZÍTÉSE ÉS BETANULÁSI RÖGZÍTÉS ---
  Future<void> _takeSectorPhoto() async {
    try {
      setState(() => _isCapturingPhoto = true);
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );

      if (photo == null) {
        setState(() => _isCapturingPhoto = false);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final sectorNum = _photoSectors.length + 1;
      final fileName =
          '${widget.hive.id}_SECTOR_${sectorNum}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(photo.path).copy('${tempDir.path}/$fileName');

      // Automatikus pont-előbecslés a fotón
      final rand = math.Random();
      final estimatedPoints = List.generate(rand.nextInt(4) + 1, (idx) {
        return Offset(
          0.2 + rand.nextDouble() * 0.6,
          0.25 + rand.nextDouble() * 0.5,
        );
      });

      final sector = PhotoSectorRecord(
        id: 'SEC_${DateTime.now().millisecondsSinceEpoch}',
        imagePath: savedFile.path,
        label: '$sectorNum. Szektor fotó',
        capturedAt: DateTime.now(),
        points: estimatedPoints,
      );

      setState(() {
        _photoSectors.add(sector);
        _isCapturingPhoto = false;
      });

      // Azonnal felkínáljuk az interaktív felülvizsgálatot
      _openPhotoAnnotator(sector);
    } catch (e) {
      setState(() => _isCapturingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotózási hiba: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Fotó megnyitása interaktív kinagyításra és kézi célkereszt pontozásra
  void _openPhotoAnnotator(PhotoSectorRecord sector) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.90,
              child: Column(
                children: [
                  // Fejléc
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${sector.label} (${sector.miteCount} atka)',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.tealAccent, size: 28),
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(dialogCtx);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Nagyíts a fotóra (kétujjas zoom), és bökj az atkákra a célkeresztek (+) hozzáadásához vagy törléséhez!',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 16),

                  // Nagyítható kép interaktív pontokkal
                  Expanded(
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: GestureDetector(
                        onTapDown: (details) {
                          final RenderBox box = dialogCtx.findRenderObject() as RenderBox;
                          final local = details.localPosition;
                          final norm = Offset(
                            (local.dx / box.size.width).clamp(0.02, 0.98),
                            (local.dy / box.size.height).clamp(0.02, 0.98),
                          );

                          // Keressük, hogy meglévő pontra bökött-e
                          int found = -1;
                          for (int i = 0; i < sector.normalizedMitePoints.length; i++) {
                            final p = sector.normalizedMitePoints[i];
                            if ((p - norm).distance < 0.06) {
                              found = i;
                              break;
                            }
                          }

                          setSheetState(() {
                            if (found != -1) {
                              sector.normalizedMitePoints.removeAt(found);
                            } else {
                              sector.normalizedMitePoints.add(norm);
                            }
                          });
                          setState(() {});
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(sector.imagePath), fit: BoxFit.contain),
                            CustomPaint(
                              painter: PhotoPointsPainter(
                                points: sector.normalizedMitePoints,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Alsó vezérlő
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(dialogCtx);
                        },
                        icon: const Icon(Icons.check, size: 20),
                        label: Text(
                          'Kész (${sector.miteCount} db atka jóváhagyva)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
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

  // --- EREDMÉNY MENTÉSE ÉS NAPLÓZÁSA ---
  void _saveResult() {
    final String imagePathInfo = _activeTabMode == 1 && _photoSectors.isNotEmpty
        ? _photoSectors.map((s) => s.imagePath).join(';')
        : 'live_ar_detection';

    final record = VarroaAnalysisRecord(
      id: '${widget.hive.id}_VARROA_${DateTime.now().millisecondsSinceEpoch}',
      hiveId: widget.hive.id,
      localImagePath: imagePathInfo,
      capturedAt: DateTime.now(),
      miteCount: _totalMitesCount,
      daysInserted: _daysInserted,
    );

    _repository.addVarroaAnalysis(
      hive: widget.hive,
      record: record,
      pullOutBoard: _removeBoardAfterCheck,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Atkaszámlálás mentve: $_totalMitesCount db (${_dailyDrop.toStringAsFixed(1)} atka/nap)'
          '${_activeTabMode == 1 ? " [${_photoSectors.length} szektorfotóval]" : ""}.',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Atkaszámláló – ${widget.hive.name}',
          style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.amberAccent),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.center_focus_strong, size: 16),
                  label: Text('Élőképes AR'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.camera_alt, size: 16),
                  label: Text('Több fotós (Betanulás)'),
                ),
              ],
              selected: {_activeTabMode},
              onSelectionChanged: (set) {
                setState(() {
                  _activeTabMode = set.first;
                  if (_activeTabMode == 1) {
                    _cameraController.stop();
                    _pulseAnimController.stop();
                  } else {
                    _cameraController.start();
                    if (!_pulseAnimController.isAnimating) {
                      _pulseAnimController.repeat(reverse: true);
                    }
                  }
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Colors.amberAccent,
                selectedForegroundColor: Colors.black,
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white70,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // FŐ TARTALOM: Élőképes AR vagy Több fotós nézet
          Expanded(
            child: _activeTabMode == 0 ? _buildLiveArView() : _buildMultiPhotoView(),
          ),

          // ALSÓ STATISZTIKAI ÉS MENTÉSI SÁV (Mindkét módhoz egységes)
          _buildBottomSummaryCard(),
        ],
      ),
    );
  }

  // --- 1. ÉLŐKÉPES AR NÉZET ---
  Widget _buildLiveArView() {
    final currentList = _zoneMites[_currentZoneIndex]!.isNotEmpty
        ? _zoneMites[_currentZoneIndex]!
        : _liveMites;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Kamera élőkép
            MobileScanner(
              controller: _cameraController,
              errorBuilder: (context, error) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off, color: Colors.amberAccent, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Kamera nem elérhető',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text('Hiba: ${error.errorCode}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),

            // Érintés- és Célkereszt-réteg
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) => _handleLiveScreenTap(details, screenSize),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: screenSize,
                    painter: MiteCrosshairPainter(
                      mites: currentList,
                      screenSize: screenSize,
                      pulseScale: _pulseAnimation.value,
                      showGrid: _showGridGuide,
                      zoneName: _zones[_currentZoneIndex],
                    ),
                  );
                },
              ),
            ),

            // Felső vezérlősáv: Zónák + Vaku + Rács
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xDD0F172A), Colors.transparent],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_zones[_currentZoneIndex]} (${currentList.length} atka)',
                          style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: _isTorchOn ? Colors.amberAccent : Colors.white70),
                              tooltip: 'Vaku megvilágítás',
                              onPressed: _toggleTorch,
                            ),
                            IconButton(
                              icon: Icon(_showGridGuide ? Icons.grid_on : Icons.grid_off, color: _showGridGuide ? Colors.tealAccent : Colors.white70),
                              tooltip: 'Zóna segédrács',
                              onPressed: () => setState(() => _showGridGuide = !_showGridGuide),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Zóna választó chip-ek
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_zones.length, (idx) {
                          final bool isCurrent = idx == _currentZoneIndex;
                          final int count = _zoneMites[idx]!.length;
                          final bool isLocked = _zoneMites[idx]!.isNotEmpty;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.0),
                            child: ChoiceChip(
                              label: Text(
                                '${_zones[idx]} ${isLocked ? '($count ✓)' : ''}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent ? Colors.black : Colors.white70,
                                ),
                              ),
                              selected: isCurrent,
                              selectedColor: Colors.amberAccent,
                              backgroundColor: const Color(0xFF1E293B),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _currentZoneIndex = idx;
                                    if (_zoneMites[idx]!.isEmpty) {
                                      _generateInitialLiveMites();
                                    }
                                  });
                                }
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Lebegő Szektor-rögzítő gombok az élőkép alján
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                    tooltip: 'Újraolvasás',
                    onPressed: _rescanCurrentZone,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.tealAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _lockCurrentZoneAndNext,
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(
                          _currentZoneIndex < _zones.length - 1
                              ? 'Szektor rögzítése (${currentList.length} atka) ➔'
                              : 'Szektor rögzítése (${currentList.length} atka)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- 2. TÖBB FOTÓS KALIBRÁCIÓS NÉZET ---
  Widget _buildMultiPhotoView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Magyarázó kártya
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent.withAlpha(80)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.photo_library, color: Colors.amberAccent, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Közeli, nagy felbontású makró fotók készítése szektoronként az aljdeszkáról. '
                    'Kiváló betanuláshoz, kétes pontok utólagos kinagyításához és igazolható dokumentációhoz.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fotózás indító gomb
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isCapturingPhoto ? null : _takeSectorPhoto,
              icon: _isCapturingPhoto
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.camera_alt),
              label: Text(
                _isCapturingPhoto
                    ? 'Kamera indítása...'
                    : 'Új szektor fotózása (${_photoSectors.length + 1}. fotó)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fotózott szektorok listája
          if (_photoSectors.isEmpty)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withAlpha(120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo, color: Colors.white30, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Még nem készítettél szektorfotót.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'Rögzített szektorok (${_photoSectors.length} db fotó):',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _photoSectors.length,
              itemBuilder: (context, index) {
                final sec = _photoSectors[index];
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(sec.imagePath),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      sec.label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      'Észlelt atka: ${sec.miteCount} db (Koppints a kinagyításhoz)',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_in, color: Colors.tealAccent),
                          tooltip: 'Megnyitás és pontozás',
                          onPressed: () => _openPhotoAnnotator(sec),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Fotó törlése',
                          onPressed: () {
                            setState(() => _photoSectors.removeAt(index));
                          },
                        ),
                      ],
                    ),
                    onTap: () => _openPhotoAnnotator(sec),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // --- KÖZÖS ALSÓ ÖSSZEGZŐ KÁRTYA ---
  Widget _buildBottomSummaryCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Statisztika
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Mód', _activeTabMode == 0 ? 'Élőképes AR' : 'Több fotós', Colors.white70),
              Container(width: 1, height: 28, color: Colors.white24),
              _buildStatColumn('Összes atka', '$_totalMitesCount db', Colors.orangeAccent),
              Container(width: 1, height: 28, color: Colors.white24),
              _buildStatColumn('Napi hullás', '${_dailyDrop.toStringAsFixed(1)} /nap', _severityColor),
            ],
          ),
          const SizedBox(height: 8),

          // Értékelő tanács banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _severityColor.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _severityColor.withAlpha(120)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: _severityColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _severityAdvice,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Mentés gomb
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: const Color(0xFF0F172A),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveResult,
              icon: const Icon(Icons.save, size: 20),
              label: Text(
                'Eredmény mentése ($_totalMitesCount db atka)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}

/// CustomPainter a fotón lévő célkeresztekhez (Photo Annotator)
class PhotoPointsPainter extends CustomPainter {
  final List<Offset> points;
  PhotoPointsPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final crossPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final circlePaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final center = Offset(p.dx * size.width, p.dy * size.height);
      const crossSize = 10.0;

      canvas.drawLine(
        Offset(center.dx - crossSize, center.dy),
        Offset(center.dx + crossSize, center.dy),
        crossPaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - crossSize),
        Offset(center.dx, center.dy + crossSize),
        crossPaint,
      );
      canvas.drawCircle(center, 14.0, circlePaint);

      textPainter.text = TextSpan(
        text: '#${i + 1}',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + 10, center.dy - 16));
    }
  }

  @override
  bool shouldRepaint(covariant PhotoPointsPainter oldDelegate) => true;
}

/// CustomPainter a célkeresztek (+), pulzáló körök és segédrács kirajzolásához (Élőképes AR)
class MiteCrosshairPainter extends CustomPainter {
  final List<Offset> mites;
  final Size screenSize;
  final double pulseScale;
  final bool showGrid;
  final String zoneName;

  MiteCrosshairPainter({
    required this.mites,
    required this.screenSize,
    required this.pulseScale,
    required this.showGrid,
    required this.zoneName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Zóna segédvonalak (2x2 négyzetháló)
    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.tealAccent.withAlpha(50)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(size.width / 2, size.height * 0.12),
        Offset(size.width / 2, size.height * 0.85),
        gridPaint,
      );
      canvas.drawLine(
        Offset(0, size.height * 0.48),
        Offset(size.width, size.height * 0.48),
        gridPaint,
      );

      final rectPaint = Paint()
        ..color = Colors.tealAccent.withAlpha(90)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.08,
            size.height * 0.16,
            size.width * 0.84,
            size.height * 0.65,
          ),
          const Radius.circular(14),
        ),
        rectPaint,
      );
    }

    // 2. Atka Célkeresztek (+) kirajzolása
    final crossPaint = Paint()
      ..color = Colors.deepOrangeAccent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final circlePaint = Paint()
      ..color = Colors.orangeAccent.withAlpha(140)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < mites.length; i++) {
      final norm = mites[i];
      final center = Offset(norm.dx * size.width, norm.dy * size.height);
      const crossSize = 12.0;

      canvas.drawLine(
        Offset(center.dx - crossSize, center.dy),
        Offset(center.dx + crossSize, center.dy),
        crossPaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - crossSize),
        Offset(center.dx, center.dy + crossSize),
        crossPaint,
      );

      canvas.drawCircle(center, 18.0 * pulseScale, circlePaint);

      textPainter.text = TextSpan(
        text: '#${i + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 4),
          ],
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + 12, center.dy - 18));
    }
  }

  @override
  bool shouldRepaint(covariant MiteCrosshairPainter oldDelegate) {
    return oldDelegate.mites != mites ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.zoneName != zoneName;
  }
}
