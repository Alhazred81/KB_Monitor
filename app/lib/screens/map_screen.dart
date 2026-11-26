import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../services/location_compass_service.dart';
import '../widgets/hive_config_dialog.dart';
import '../widgets/hive_detail_sheet.dart';
import '../widgets/weak_colony_warning_dialog.dart';
import '../widgets/scanner_controls.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/top_gps_bar.dart';
import '../widgets/candy_icon.dart';
import '../widgets/hive_tower_icon.dart';
import '../widgets/waterer_icon.dart';
import '../widgets/queen_replacement_dialog.dart';
import '../widgets/help_bubble.dart';
import 'new_hive_wizard_screen.dart';
import 'office_dashboard_screen.dart';
import 'processing_room_screen.dart';
import 'settings_screen.dart';
import 'server_config_screen.dart'; // <-- Beimportálva az új fülös konfig képernyő
import 'weather_history_screen.dart';

const String kSecretProtocolPassword = "Multioptipupiloptómia";

class MapAndScannerScreen extends StatefulWidget {
  const MapAndScannerScreen({super.key});

  @override
  State<MapAndScannerScreen> createState() => _MapAndScannerScreenState();
}

class _MapAndScannerScreenState extends State<MapAndScannerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  final LocationCompassService _locationService = LocationCompassService();
  final HiveRepository _repository = HiveRepository.instance;

  final TextEditingController _idController = TextEditingController();

  String _serverUrl = '';
  String _anonKey = '';

  bool _isAdvancedMode = false;
  bool _isMapFreeRotate = true;
  double _currentMapRotationRad = 0.0;

  // --- IKON ÁTRENDEZŐ (SZERKESZTŐ) MÓD ---
  bool _isEditMode = false;

  // --- OTA ÁLLAPOTOK ---
  bool _isApAndOtaServerActive = false;
  String? _serverFwPath;
  String? _monitorFwPath;
  HttpServer? _localOtaServer;

  late AnimationController _nfcAnimController;
  late Animation<Color?> _nfcColorAnim;
  bool _isNfcScanning = false;

  late AnimationController _redFlashingAnimController;
  late Animation<double> _redFlashOpacityAnim;

  late AnimationController _compassRedAnimController;
  late Animation<double> _compassRedOpacityAnim;

  MobileScannerController? _mapScannerCtrl;
  bool _isCameraActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _serverUrl = _repository.supabaseUrl;
    _anonKey = _repository.supabaseAnonKey;
    _repository.addListener(_onRepositoryChanged);
    _initSensors();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _repository.setAppLifecycleActive(true);
      if (!_isCameraActive) {
        _locationService.resumeCompass();
      }
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _locationService.pauseCompass();
      _repository.setAppLifecycleActive(false);
      _redFlashingAnimController.stop();
      _compassRedAnimController.stop();
      if (_isCameraActive) {
        _setCameraActive(false);
      }
    }
  }

  void _onRepositoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initSensors() async {
    _nfcAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _nfcColorAnim = ColorTween(
      begin: Colors.white,
      end: const Color(0xFF00FF66),
    ).animate(_nfcAnimController);

    _redFlashingAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _redFlashOpacityAnim = Tween<double>(
      begin: 0.25,
      end: 1.0,
    ).animate(_redFlashingAnimController);

    _compassRedAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _compassRedOpacityAnim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(_compassRedAnimController);

    LatLng? pos = await _locationService.updatePosition();
    if (pos != null && mounted) {
      setState(() {});
      if (_isMapReady && !_isCameraActive) {
        try {
          _mapController.move(pos, 17.0);
        } catch (_) {}
      }
    }

    _locationService.initCompass((heading, accuracy) {
      if (mounted) {
        if (_isMapFreeRotate && !_isEditMode && !_isCameraActive && heading != null && _isMapReady) {
          try {
            _mapController.rotate(-heading);
          } catch (_) {}
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapScannerCtrl?.dispose();
    _mapScannerCtrl = null;
    _locationService.dispose();
    _localOtaServer?.close(force: true);
    _repository.removeListener(_onRepositoryChanged);
    _nfcAnimController.dispose();
    _redFlashingAnimController.dispose();
    _compassRedAnimController.dispose();
    _idController.dispose();
    super.dispose();
  }

  LatLng _applyDragDelta(LatLng currentLatLng, Offset pixelDelta) {
    double zoom = 17.0;
    if (_isMapReady && !_isCameraActive) {
      try {
        zoom = _mapController.camera.zoom;
      } catch (_) {}
    }
    final double scale = 0.000009 * math.pow(2, 17 - zoom);
    return LatLng(
      currentLatLng.latitude - (pixelDelta.dy * scale),
      currentLatLng.longitude + (pixelDelta.dx * scale),
    );
  }

  void _toggleEditMode() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isEditMode = !_isEditMode;
    });
    if (!_isEditMode) {
      _repository.saveMapLayoutPositions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Ikonok új elrendezése mentve az adatbázisba és a naplóba.',
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _setCameraActive(bool active) {
    if (_isCameraActive == active) return;
    if (active) {
      _locationService.pauseCompass();
      _mapScannerCtrl?.dispose();
      _mapScannerCtrl = MobileScannerController(
        formats: const [
          BarcodeFormat.qrCode,
          BarcodeFormat.dataMatrix,
          BarcodeFormat.code128,
        ],
      );
      _redFlashingAnimController.stop();
      _compassRedAnimController.stop();
    } else {
      _mapScannerCtrl?.dispose();
      _mapScannerCtrl = null;
      _locationService.resumeCompass();
    }
    setState(() {
      _isCameraActive = active;
    });
  }

  void _syncBlinkControllers({
    required bool anyHiveFlashing,
    required bool shouldFlashCompass,
  }) {
    if (_isCameraActive || !anyHiveFlashing) {
      if (_redFlashingAnimController.isAnimating) {
        _redFlashingAnimController.stop();
      }
    } else if (!_redFlashingAnimController.isAnimating) {
      _redFlashingAnimController.repeat(reverse: true);
    }

    if (_isCameraActive || !shouldFlashCompass) {
      if (_compassRedAnimController.isAnimating) {
        _compassRedAnimController.stop();
      }
    } else if (!_compassRedAnimController.isAnimating) {
      _compassRedAnimController.repeat(reverse: true);
    }
  }

  Future<void> _manageLocalOtaServer(bool enable) async {
    await _localOtaServer?.close(force: true);
    _localOtaServer = null;

    if (!enable) return;

    try {
      _localOtaServer = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      _localOtaServer!.listen((HttpRequest request) async {
        final String path = request.uri.path;
        String? targetFile;

        if (path == '/server.bin') {
          targetFile = _serverFwPath;
        } else {
          targetFile = _monitorFwPath ?? _serverFwPath;
        }

        if (targetFile != null && await File(targetFile).exists()) {
          final file = File(targetFile);
          request.response.headers.contentType = ContentType.binary;
          request.response.contentLength = await file.length();
          await request.response.addStream(file.openRead());
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('Firmware binaris nem talalhato.');
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint('OTA HTTP szerver hiba: $e');
    }
  }

  Future<void> _refreshPosition() async {
    HapticFeedback.lightImpact();
    if (_isMapReady && !_isCameraActive) {
      try {
        _mapController.move(_locationService.currentPosition, 17.0);
      } catch (_) {}
    }
    LatLng? pos = await _locationService.updatePosition();
    if (pos != null && mounted) {
      setState(() {});
      if (_isMapReady && !_isCameraActive) {
        try {
          _mapController.move(pos, 17.0);
        } catch (_) {}
      }
    }
  }

  void _openNewHiveWizard({String? initialCode}) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewHiveWizardScreen(
          locationService: _locationService,
          repository: _repository,
          initialCode: initialCode,
        ),
      ),
    );
  }

  void _findAndShowHive(String scannedCode) {
    final result = _repository.findElementByCode(scannedCode);

    if (result != null) {
      if (result is HiveData) {
        _showHiveDetails(result);
      } else if (result is Map) {
        _showHiveDetails(result['hive']);
      }
    } else {
      _showUnknownCodeDialog(scannedCode);
    }
  }

  void _showUnknownCodeDialog(String code) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Ismeretlen QR / NFC azonosító',
            style: TextStyle(color: Colors.amberAccent),
          ),
          content: Text(
            'A(z) "$code" azonosító nincs még a rendszerben. Szeretnél új kaptárt létrehozni, vagy meglévő kaptárhoz fiókot/tartozékot regisztrálni?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mégse', style: TextStyle(color: Colors.grey)),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.tealAccent,
                side: const BorderSide(color: Colors.tealAccent),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showExistingHiveBoxDialog(code);
              },
              icon: const Icon(Icons.inventory_2),
              label: const Text('Fiók meglévőhöz'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
                _openNewHiveWizard(initialCode: code);
              },
              icon: const Icon(Icons.add),
              label: const Text('Új kaptár'),
            ),
          ],
        );
      },
    );
  }

  void _showExistingHiveBoxDialog(String primaryCode) {
    String selectedType = 'honey';
    String boxName = 'Méztér';
    String boxSize = '1/2 dadant';
    String? secondaryCode;
    HiveData? selectedTargetHive = _repository.hives.isNotEmpty
        ? _repository.hives.first
        : null;

    if (selectedTargetHive == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nincs még rögzített kaptár a rendszerben!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text(
                'Fiók / Tartozék regisztráció\n(Kód: $primaryCode)',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Család / Kaptár kiválasztása:',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    DropdownButton<HiveData>(
                      value: selectedTargetHive,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      items: _repository.hives
                          .map(
                            (h) =>
                                DropdownMenuItem(value: h, child: Text(h.name)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedTargetHive = val),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Fiók / Tartozék típusa:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<String>(
                      value: selectedType,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'brood_box',
                          child: Text('Fészek (Dadant)'),
                        ),
                        DropdownMenuItem(
                          value: 'honey',
                          child: Text('Méztér (1/2 Dadant)'),
                        ),
                        DropdownMenuItem(
                          value: 'feeder',
                          child: Text('Tetőetető (Tartozék)'),
                        ),
                        DropdownMenuItem(
                          value: 'escapement',
                          child: Text('Szöktető (Tartozék)'),
                        ),
                        DropdownMenuItem(
                          value: 'vent',
                          child: Text('Szellőző (Tartozék)'),
                        ),
                        DropdownMenuItem(
                          value: 'pollen_trap',
                          child: Text('Virágporgyűjtő (Tartozék)'),
                        ),
                        DropdownMenuItem(
                          value: 'roof',
                          child: Text('Tető (Tartozék)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedType = val;
                            if (val == 'brood_box') {
                              boxName = 'Fészekfiók';
                              boxSize = 'dadant';
                            } else if (val == 'honey') {
                              boxName = 'Méztér';
                              boxSize = '1/2 dadant';
                            } else if (val == 'feeder') {
                              boxName = 'Tetőetető';
                              boxSize = 'dadant';
                            } else if (val == 'escapement') {
                              boxName = 'Szöktető';
                              boxSize = 'dadant';
                            } else if (val == 'vent') {
                              boxName = 'Szellőző';
                              boxSize = 'dadant';
                            } else if (val == 'pollen_trap') {
                              boxName = 'Pollengyűjtő';
                              boxSize = 'dadant';
                            } else if (val == 'roof') {
                              boxName = 'Tető';
                              boxSize = 'dadant';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Másodlagos NFC ID (opcionális)',
                        labelStyle: TextStyle(color: Colors.amberAccent),
                      ),
                      onChanged: (val) => secondaryCode = val,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
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
                    if (selectedTargetHive != null) {
                      void executeAdd({bool overriddenMismatch = false}) {
                        final target = selectedTargetHive!;
                        if (overriddenMismatch) {
                          _repository.logHistoryEvent(
                            target.id,
                            'nem_megfelelo_elem_felulbiralas',
                            'Figyelmeztetés felülbírálva (${getHiveFamilyFunctionLabel(target.familyFunction)}): $boxName [$primaryCode] felhelyezve.',
                            metadata: {
                              'family_function': target.familyFunction,
                              'box_type': selectedType,
                              'box_name': boxName,
                              'code': primaryCode,
                            },
                          );
                        }
                        _repository.addBoxToHive(
                          target,
                          BoxElement(
                            name: boxName,
                            code: primaryCode,
                            secondaryCode: secondaryCode,
                            type: selectedType,
                            size: boxSize,
                            status: 'green',
                          ),
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fiók rögzítve a kaptárhoz.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }

                      // 0. Méret kompatibilitás és 4 fiókos magasságkorlát ellenőrzése
                      final bool isRealBox = isFrameBoxType(
                        selectedType,
                        name: boxName,
                      );
                      if (isRealBox && boxSize.isNotEmpty) {
                        String norm(String s) {
                          final c = s.toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('/', '');
                          if (c.contains('dadant')) return 'dadant';
                          if (c.contains('hunor') || c.contains('nb') || c.contains('nagyboczonadi')) return 'nb_hunor';
                          if (c.contains('langstroth')) return 'langstroth';
                          return c;
                        }

                        final incompatibleBox = selectedTargetHive!.boxes.firstWhere(
                          (b) => b.size.isNotEmpty && isFrameBoxType(b.type, name: b.name) && norm(b.size) != norm(boxSize),
                          orElse: () => BoxElement(name: '', code: '', type: '', size: ''),
                        );

                        if (incompatibleBox.size.isNotEmpty) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.warning_amber, color: Colors.redAccent, size: 22),
                                  SizedBox(width: 8),
                                  Text('Méret összeférhetetlenség', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                                ],
                              ),
                              content: const Text(
                                'A kiválasztott méret nem kombinálható a kaptárban lévő mérettel!\n\n'
                                '• A Dadant rendszerben teljes Dadant és 1/2 Dadant fiókok használhatók.\n'
                                '• Az NB, Hunor és 1/2 NB egymással kompatibilis, de a Dadanttal keresztbe nem keverhető.',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Megértettem', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        final double addedEq = boxFullEquivalentFor(
                          type: selectedType,
                          size: boxSize,
                          name: boxName,
                        );
                        final double projectedEq =
                            selectedTargetHive!.fullBoxEquivalentCount + addedEq;
                        if (projectedEq > HiveData.kMaxFullBoxEquivalent + 1e-6) {
                          showMaxTowerHeightBlockedDialog(
                            context: context,
                            hive: selectedTargetHive!,
                            addedBoxLabel: boxName,
                            addedEquivalent: addedEq,
                          );
                          return;
                        }
                      }

                      final FamilyFunctionBoxMismatch? fnMismatch =
                          evaluateFamilyFunctionBoxMismatch(
                            hive: selectedTargetHive!,
                            boxType: selectedType,
                            boxName: boxName,
                          );
                      final double scanAddedEq = isRealBox
                          ? boxFullEquivalentFor(
                              type: selectedType,
                              size: boxSize,
                              name: boxName,
                            )
                          : 0.0;
                      final double scanProjectedEq =
                          selectedTargetHive!.fullBoxEquivalentCount +
                          scanAddedEq;
                      final bool needsSpanifer =
                          isRealBox &&
                          scanProjectedEq >
                              HiveData.kSpaniferWarningThreshold + 1e-6;

                      void stepOtherConflicts({bool overriddenMismatch = false}) {
                        // 1. Etető és Méztér összeférhetetlenség ellenőrzése
                        if (!overriddenMismatch &&
                            selectedType == 'feeder' &&
                            selectedTargetHive!.hasHoneySuper) {
                          showFeederHoneyConflictDialog(
                            context: context,
                            hive: selectedTargetHive!,
                            conflictType: 'adding_feeder_with_honey',
                            onConfirm: () => executeAdd(
                              overriddenMismatch: overriddenMismatch,
                            ),
                          );
                          return;
                        }
                        if (selectedType == 'honey' &&
                            (selectedTargetHive!.hasFeeder ||
                                selectedTargetHive!.feedingMode != 'off')) {
                          showFeederHoneyConflictDialog(
                            context: context,
                            hive: selectedTargetHive!,
                            conflictType: 'adding_honey_with_feeder',
                            onConfirm: () => executeAdd(
                              overriddenMismatch: overriddenMismatch,
                            ),
                          );
                          return;
                        }

                        // 2. Pollengyűjtő és Méztér összeférhetetlenség ellenőrzése
                        if (!overriddenMismatch &&
                            selectedType == 'honey' &&
                            selectedTargetHive!.hasActivePollenTrap) {
                          showPollenHoneyConflictDialog(
                            context: context,
                            hive: selectedTargetHive!,
                            conflictType: 'adding_honey_with_pollen',
                            onConfirm: () => executeAdd(
                              overriddenMismatch: overriddenMismatch,
                            ),
                          );
                          return;
                        }
                        if (!overriddenMismatch &&
                            selectedType == 'pollen_trap' &&
                            selectedTargetHive!.hasHoneySuper) {
                          showPollenHoneyConflictDialog(
                            context: context,
                            hive: selectedTargetHive!,
                            conflictType: 'enabling_pollen_with_honey',
                            onConfirm: () => executeAdd(
                              overriddenMismatch: overriddenMismatch,
                            ),
                          );
                          return;
                        }

                        // 3. Gyenge vagy beteg család védelme
                        final bool isHoneyOrPollen = (selectedType == 'honey' ||
                            selectedType == 'pollen_trap');
                        if (isHoneyOrPollen && selectedTargetHive!.isWeakOrSick) {
                          final String actionTitle = selectedType == 'honey'
                              ? 'Méztér hozzáadása'
                              : 'Pollengyűjtő hozzáadása';
                          showWeakColonyWarningDialog(
                            context: context,
                            hive: selectedTargetHive!,
                            actionTitle: actionTitle,
                            onConfirm: () => executeAdd(
                              overriddenMismatch: overriddenMismatch,
                            ),
                          );
                          return;
                        }

                        executeAdd(overriddenMismatch: overriddenMismatch);
                      }

                      void stepScanSpanifer({bool overriddenMismatch = false}) {
                        if (needsSpanifer) {
                          showSpaniferRequiredWarningDialog(
                            context: context,
                            hive: selectedTargetHive!,
                            addedBoxLabel: boxName,
                            projectedFullEquivalent: scanProjectedEq,
                            onConfirm: () => stepOtherConflicts(
                              overriddenMismatch: overriddenMismatch,
                            ),
                          );
                          return;
                        }
                        stepOtherConflicts(
                          overriddenMismatch: overriddenMismatch,
                        );
                      }

                      if (fnMismatch != null) {
                        showFamilyFunctionBoxMismatchDialog(
                          context: context,
                          hive: selectedTargetHive!,
                          mismatch: fnMismatch,
                          onConfirm: () =>
                              stepScanSpanifer(overriddenMismatch: true),
                        );
                        return;
                      }

                      stepScanSpanifer();
                      return;
                    }
                    Navigator.pop(context);
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

  void _showHiveDetails(HiveData hive) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HiveDetailSheet(
        hive: hive,
        redFlashOpacityAnim: _redFlashOpacityAnim,
        onConfigurePressed: () async {
          await _openHiveConfigDialog(hive);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _openHiveConfigDialog(HiveData hive) async {
    await showDialog(
      context: context,
      builder: (context) => HiveConfigDialog(selectedHive: hive),
    );
    if (mounted) setState(() {});
  }

  void _openSettingsScreen() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => SettingsScreen(
          repository: _repository,
          initialUrl: _serverUrl,
          initialAnonKey: _anonKey,
          initialAdvancedMode: _isAdvancedMode,
          initialApEnabled: _isApAndOtaServerActive,
          initialServerFwPath: _serverFwPath,
          initialMonitorFwPath: _monitorFwPath,
          onAdvancedModeChanged: (val) {
            setState(() {
              _isAdvancedMode = val;
            });
          },
          onConfigSaved: (newUrl, newKey, newAdv) {
            setState(() {
              _serverUrl = newUrl;
              _anonKey = newKey;
              _isAdvancedMode = newAdv;
            });
          },
          onOtaSave: (apEnabled, serverFw, monitorFw) async {
            setState(() {
              _isApAndOtaServerActive = apEnabled;
              _serverFwPath = serverFw;
              _monitorFwPath = monitorFw;
            });
            await _manageLocalOtaServer(apEnabled);
          },
        ),
      ),
    );
  }

  void _openOfficeDashboard() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => OfficeDashboardScreen(repository: _repository),
      ),
    );
  }

  void _openProcessingRoom() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ProcessingRoomScreen(repository: _repository),
      ),
    );
  }

  // ITT HELYEZTÜK BE A FÜLÖS KONFIG NAVIGÁCIÓT AZ IDŐJÁRÁS-ÁLLOMÁS RÁKATTINTÁSAKOR
  void _showStationDetails(StationData station) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1f2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 36.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.wb_sunny,
                        color: Colors.tealAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        station.name,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),

              // Szerver / Supabase kapcsolat státusz kártya (Zöld / Piros) - rábökve azonnal a beállításokhoz ugrik
              ListenableBuilder(
                listenable: _repository,
                builder: (context, _) {
                  final stationLive = _repository.weatherStation;
                  final bool isConnected =
                      stationLive.isOnline && _repository.isOnline;
                  final Color statusColor =
                      isConnected ? Colors.greenAccent : Colors.redAccent;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const ServerAndWeatherConfigScreen(
                              initialTabIndex: 4, // 5. FÜL: IOT & SUPABASE
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? Colors.green.withAlpha(35)
                              : Colors.red.withAlpha(45),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withAlpha(140), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isConnected ? Icons.cloud_done : Icons.cloud_off,
                              color: statusColor,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isConnected
                                        ? 'Supabase Kapcsolat: AKTÍV (Zöld)'
                                        : 'Supabase Kapcsolat: MEGSZAKADT (Piros)',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isConnected
                                        ? 'A szerver adatai szinkronizálva vannak a felhővel.'
                                        : 'A szerver nem érhető el vagy hiányzik az internetkapcsolat.',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (!isConnected) ...[
                                    const SizedBox(height: 6),
                                    const Row(
                                      children: [
                                        Icon(Icons.tune, color: Colors.amberAccent, size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Koppints ide a kapcsolat beállításához ➔',
                                          style: TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: statusColor.withAlpha(180),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Szenzoradatok listája
              _buildStationRow(
                'Hőmérséklet',
                '${station.temp} °C',
                Icons.thermostat,
                Colors.amber,
              ),
              const SizedBox(height: 6),
              _buildStationRow(
                'Páratartalom',
                '${station.humidity} %',
                Icons.water_drop,
                Colors.lightBlueAccent,
              ),
              const SizedBox(height: 6),
              _buildStationRow(
                'Légnyomás',
                '${station.pressure} hPa',
                Icons.speed,
                Colors.orangeAccent,
              ),
              const SizedBox(height: 6),
              _buildStationRow(
                'UV-index',
                '${station.uvIndex}',
                Icons.wb_sunny_outlined,
                Colors.yellowAccent,
              ),
              const SizedBox(height: 6),
              _buildStationRow(
                'Fényerősség',
                '${station.lightLux.toInt()} Lux',
                Icons.light_mode,
                Colors.amberAccent,
              ),
              const SizedBox(height: 6),
              _buildStationRow(
                'Szélsebesség',
                '${station.windSpeed} m/s (${station.windDirection})',
                Icons.air,
                Colors.cyanAccent,
              ),
              const SizedBox(height: 6),
              _buildStationRow(
                'Esőmennyiség',
                '${station.rainAmount} mm',
                Icons.umbrella,
                Colors.blueAccent,
              ),
              const SizedBox(height: 6),
              _buildStationRow(
                'Akkumulátor / Táp',
                '${station.batteryVoltage} V',
                Icons.battery_full,
                Colors.greenAccent,
              ),

              const SizedBox(height: 18),

              // Kiemelt Időjárás History gomb (Ma óránként, Tegnap, Ezen a héten, Múlt héten, 30 nap)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            WeatherHistoryScreen(repository: _repository),
                      ),
                    );
                  },
                  icon: const Icon(Icons.timeline_rounded, size: 22),
                  label: const Text(
                    'Időjárás History (Óránként / Heti / Havi)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Navigáció a szerver weboldal-szerű, fülös beállításaihoz
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3b82f6)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ServerAndWeatherConfigScreen(
                                  initialTabIndex: 0,
                                ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.dashboard, color: Colors.white),
                      label: const Text(
                        'Áttekintés',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10b981),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ServerAndWeatherConfigScreen(
                                  initialTabIndex: 2,
                                ), // Szenzorok fül
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings, color: Colors.white),
                      label: const Text(
                        'Konfig',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

  void _showWatererDetails(WatererData waterer) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double levelPct = waterer.waterLevel.clamp(0.0, 100.0);
            final Color waterColor = getWatererStatusColor(waterer.status);
            final String statusLabel = getWatererStatusLabel(waterer.status);
            final bool isFreeze = waterer.waterTemp <= 1.0;
            final bool isBlinking = (waterer.status == 'blinking_red');

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: waterColor.withAlpha(140), width: 1.5),
              ),
              title: Row(
                children: [
                  WatererIcon(
                    size: 32,
                    status: waterer.status,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          waterer.name,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: waterColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  HelpBubbleButton(
                    title: 'Vízadagoló Állapot Súgó',
                    message: 'Itató 5-fokozatú állapotai:\n\n'
                        '• Zöld: Optimális vízszint (> 50%)\n'
                        '• Sárga: Közepes vízszint (25-50%)\n'
                        '• Narancs: Alacsony szint (< 25%, utántöltés szükséges)\n'
                        '• Piros: Kiszáradt / Üres itató (<= 5%)\n'
                        '• Villogó Piros: Fagyveszély (vízhő <= 1.0°C) vagy vészleállítás.',
                    iconColor: waterColor,
                    size: 20,
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Azonosító: ${waterer.id}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 10),

                    // VILLOGÓ PIROS VÉSZLEÁLLÍTÁS / FAGYVESZÉLY BANNER
                    if (waterer.isInterlocked || isBlinking) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(45),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isFreeze ? Icons.ac_unit : Icons.gpp_bad,
                                  color: Colors.redAccent,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isFreeze
                                        ? 'FAGYVESZÉLY (VILLOGÓ PIROS): Vízhő <= 1.0°C!'
                                        : 'VÉSZLEÁLLÍTÁS (VILLOGÓ PIROS): Itató leállítva!',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              waterer.emergencyStopReason ??
                                  (isFreeze
                                      ? 'A vízhőmérséklet ${waterer.waterTemp.toStringAsFixed(1)}°C-ra süllyedt! Jégképződés veszélye miatt vészleállás!'
                                      : 'Kézi vagy automatikus védelmi retesz aktív.'),
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 36),
                              ),
                              onPressed: () {
                                _repository.resetWatererEmergency();
                                setDialogState(() {});
                                setState(() {});
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text(
                                'Vészretesz feloldása & Normál üzem',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    _buildStationRow(
                      'Folyadékszint (Vízszint)',
                      '${levelPct.toStringAsFixed(1)}%',
                      Icons.waves,
                      waterColor,
                      customIcon: WatererIcon(size: 20, status: waterer.status),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (levelPct / 100.0).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(waterColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildWatererStatusBadge(waterer.status),
                    const SizedBox(height: 12),
                    _buildStationRow(
                      'Vízhőmérséklet',
                      '${waterer.waterTemp.toStringAsFixed(1)} °C${isFreeze ? " ❄️ (FAGY!)" : ""}',
                      Icons.thermostat,
                      isFreeze ? Colors.cyanAccent : Colors.amber,
                    ),
                    const SizedBox(height: 8),
                    _buildStationRow(
                      'Akkumulátor',
                      '${waterer.batteryVoltage.toStringAsFixed(2)} V',
                      Icons.battery_full,
                      Colors.greenAccent,
                    ),

                    const Divider(color: Colors.white24, height: 24),

                    // --- VÍZSZINT & STÁTUSZ SZIMULÁLÁS ---
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242C38),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune, size: 16, color: Colors.amberAccent),
                              SizedBox(width: 6),
                              Text(
                                'Vízszint beállítása & 5 állapot teszt:',
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: levelPct,
                            min: 0.0,
                            max: 100.0,
                            divisions: 20,
                            activeColor: waterColor,
                            label: '${levelPct.toStringAsFixed(0)}%',
                            onChanged: (val) {
                              _repository.updateWatererLevel(val);
                              setDialogState(() {});
                              setState(() {});
                            },
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ActionChip(
                                label: const Text('Üres (3% Piros)'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.white),
                                backgroundColor: const Color(0xFFFF1744).withAlpha(160),
                                onPressed: () {
                                  _repository.updateWatererLevel(3.0);
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                              ActionChip(
                                label: const Text('Kevés (15% Narancs)'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.white),
                                backgroundColor: const Color(0xFFFF9100).withAlpha(160),
                                onPressed: () {
                                  _repository.updateWatererLevel(15.0);
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                              ActionChip(
                                label: const Text('Közepes (35% Sárga)'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                                backgroundColor: const Color(0xFFFFD600),
                                onPressed: () {
                                  _repository.updateWatererLevel(35.0);
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                              ActionChip(
                                label: const Text('Tele (85% Zöld)'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                                backgroundColor: const Color(0xFF00E676),
                                onPressed: () {
                                  _repository.updateWatererLevel(85.0);
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ActionChip(
                                label: const Text('❄️ -1.5°C Fagy teszt'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                backgroundColor: Colors.cyan.shade900,
                                onPressed: () {
                                  _repository.updateWatererTemp(-1.5);
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                              ActionChip(
                                label: const Text('🚨 Kézi vészleállítás'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                backgroundColor: Colors.red.shade900,
                                onPressed: () {
                                  _repository.setWatererEmergency(true, reason: 'Kézi vészleállítás teszt: Szivárgás észlelve!');
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                              ActionChip(
                                label: const Text('21.0°C Normál hő'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.white),
                                backgroundColor: Colors.blueGrey.shade800,
                                onPressed: () {
                                  _repository.updateWatererTemp(21.0);
                                  setDialogState(() {});
                                  setState(() {});
                                },
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Bezárás'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSyrupPumpDetails(SyrupPumpData pump) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double levelPct = pump.tankLevelPercent.clamp(0.0, 100.0);
            final double remainingLiters = (pump.tankCapacityLiters * levelPct) / 100.0;
            final Color pumpColor = getSyrupStatusColor(pump.status);
            final String statusLabel = getSyrupStatusLabel(pump.status);

            final hivesWithFeeder = _repository.hives
                .where((h) => h.hasFeeder)
                .toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: pumpColor.withAlpha(120), width: 1.5),
              ),
              title: Row(
                children: [
                  CandyIcon(
                    size: 32,
                    status: pump.status,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pump.name,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: pumpColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  HelpBubbleButton(
                    title: 'Szirup Rendszer Súgó',
                    message: 'Szirupadagoló 5-fokozatú állapotai:\n\n'
                        '• Zöld: Normál üzemkész állapot (Tartályszint > 50%)\n'
                        '• Sárga: Figyelmeztető szint (20-50%)\n'
                        '• Narancs: Adagolás alatt / SZTOJ ütközésvédelem aktív\n'
                        '• Piros: Üres etető / tartály (töltésre kész)\n'
                        '• Villogó Piros: Szivattyú TILTVA (szintemelkedési timeout vagy fagyveszély).',
                    iconColor: pumpColor,
                    size: 20,
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // VILLOGÓ PIROS VÉSZLEÁLLÍTÁS BANNER ÉS RETESZ FELOLDÁS
                    if (pump.isPumpInterlocked || pump.status == 'blinking_red') ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(45),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.gpp_bad, color: Colors.redAccent, size: 22),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'VÉSZLEÁLLÍTÁS (VILLOGÓ PIROS): Szivattyú TILTVA!',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              pump.emergencyStopReason ??
                                  'Szintemelkedési timeout: a szivattyú járt, de a folyadékszint nem emelkedett!',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 36),
                              ),
                              onPressed: () {
                                _repository.resetPumpEmergencyInterlock(pump);
                                setDialogState(() {});
                                setState(() {});
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text(
                                'Vészretesz feloldása & Szivattyú engedélyezése',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    _buildStationRow(
                      'Központi Tartály Szint',
                      '${remainingLiters.toStringAsFixed(1)} L (${levelPct.toStringAsFixed(0)}%)',
                      Icons.opacity,
                      pumpColor,
                      customIcon: CandyIcon(size: 20, status: pump.status),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (levelPct / 100.0).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(pumpColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Szezonban kiadagolva: ${pump.totalPumpedLiters.toStringAsFixed(1)} liter',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Rendszerállapot: ${pump.lastOperationStatus}',
                      style: TextStyle(
                        color: pumpColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const Divider(color: Colors.white24, height: 20),

                    // --- SZINTVEZÉRLÉS ÉS STÁTUSZ SZIMULÁLÁS ---
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242C38),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tartály szint kézi állítása:',
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${levelPct.toInt()}%',
                                style: TextStyle(color: pumpColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          Slider(
                            value: levelPct,
                            min: 0.0,
                            max: 100.0,
                            activeColor: pumpColor,
                            inactiveColor: Colors.white12,
                            onChanged: (val) {
                              _repository.updateSyrupTankLevel(val);
                              setDialogState(() {});
                              setState(() {});
                            },
                          ),
                          const Text(
                            '5-állapotú gyors tesztelés:',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                label: const Text('🟢 90% (Zöld)'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                backgroundColor: const Color(0xFF1B5E20),
                                onPressed: () {
                                  _repository.setSyrupPumpEmergency(false);
                                  _repository.updateSyrupTankLevel(90.0);
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                              ActionChip(
                                label: const Text('🟡 35% (Sárga)'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                backgroundColor: const Color(0xFF7F6000),
                                onPressed: () {
                                  _repository.setSyrupPumpEmergency(false);
                                  _repository.updateSyrupTankLevel(35.0);
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                              ActionChip(
                                label: const Text('🟠 15% (Narancs)'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                backgroundColor: const Color(0xFFBF360C),
                                onPressed: () {
                                  _repository.setSyrupPumpEmergency(false);
                                  _repository.updateSyrupTankLevel(15.0);
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                              ActionChip(
                                label: const Text('🔴 3% (Piros)'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                backgroundColor: const Color(0xFF880E4F),
                                onPressed: () {
                                  _repository.setSyrupPumpEmergency(false);
                                  _repository.updateSyrupTankLevel(3.0);
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                              ActionChip(
                                label: const Text('🚨 Vészleállítás'),
                                labelStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                backgroundColor: Colors.red.shade900,
                                onPressed: () {
                                  _repository.setSyrupPumpEmergency(true, reason: 'Kézi vészleállítás teszt: Szintemelkedési timeout');
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    const Text(
                      'Szirupvonalra kötött kaptárak:',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hivesWithFeeder.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Text(
                          'Egyetlen kaptárra sincs felhelyezve etető szintméréssel.\n\n'
                          'Az automatikus serkentést vagy feletetést az adott kaptár adatlapján tudod beállítani, miután felhelyeztél rá egy szintmérős etető fiókot!',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ] else ...[
                      ...hivesWithFeeder.map((h) {
                        Color badgeColor;
                        String badgeText;
                        if (h.feedingMode == 'auto_stim') {
                          badgeColor = Colors.tealAccent;
                          badgeText =
                              'Auto serkentés (max ${h.feedingMaxLiters.toStringAsFixed(1)}L / ${h.feedingIntervalDays} nap)';
                        } else if (h.feedingMode == 'manual') {
                          badgeColor = Colors.lightBlueAccent;
                          badgeText =
                              'Kézi feletetés (max ${h.feedingMaxLiters.toStringAsFixed(1)}L)';
                        } else {
                          badgeColor = Colors.white54;
                          badgeText = 'Kikapcsolva';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: badgeColor.withAlpha(100),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.hive, color: badgeColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      badgeText,
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${h.feederLevelPercent.toInt()}% szint',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Bezárás'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getHiveIcon(HiveData hive) {
    if (hive.isQuarantined ||
        hive.protocol?.toLowerCase() == 'hans' ||
        hive.familyFunction.toLowerCase() == 'hans') {
      return Icons.local_fire_department;
    }
    if (hive.isQueenReplacementActive) {
      return Icons.warning_amber_rounded;
    }
    if (hive.isLocked) {
      return Icons.lock;
    }
    if (hive.protocol == 'oxalsav' ||
        hive.protocol == 'oxalsav_egyszeri' ||
        hive.protocol == 'oxalsav_sorozat') {
      return Icons.cloud;
    }
    if (hive.protocol == 'hangyasav' || hive.protocol == 'hangyasavazas') {
      return Icons.pest_control;
    }
    if (hive.protocol == 'gyogyszeres' || hive.protocol == 'gyogyszer') {
      return Icons.medication;
    }

    if (hive.familyFunction == 'meztermeles' ||
        hive.familyFunction == 'gyujto_mez' ||
        hive.familyFunction == 'méz') {
      return Icons.breakfast_dining;
    }
    if (hive.familyFunction == 'viragpor' ||
        hive.familyFunction == 'viragpor_termeles' ||
        hive.familyFunction == 'pollen') {
      return Icons.local_florist;
    }
    if (hive.familyFunction == 'mehpempo' || hive.familyFunction == 'pempo') {
      return Icons.water_drop;
    }
    if (hive.familyFunction == 'propolisz') {
      return Icons.texture;
    }
    if (hive.familyFunction == 'mehmereg' ||
        hive.familyFunction == 'méhméreg') {
      return Icons.dangerous;
    }

    if (hive.familyFunction == 'donor' ||
        hive.familyFunction == 'donor_csalad') {
      return Icons.group;
    }
    if (hive.familyFunction == 'anyacsalad' ||
        hive.familyFunction == 'tenyeszcsalad' ||
        hive.familyFunction == 'anya') {
      return Icons.workspace_premium;
    }
    if (hive.familyFunction == 'apacsalad' || hive.familyFunction == 'apa') {
      return Icons.male;
    }
    if (hive.familyFunction == 'starter') {
      return Icons.bolt;
    }
    if (hive.familyFunction == 'dajka' ||
        hive.familyFunction == 'dajkacsalad') {
      return Icons.child_care;
    }

    return Icons.cloud;
  }

  Widget _buildStationRow(
    String label,
    String value,
    IconData icon,
    Color color, {
    Widget? customIcon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            customIcon ?? Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.amber.shade700;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purpleAccent;
      case 'red':
        return Colors.red;
      case 'flashing_red':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  void _startNfcScan() {
    setState(() {
      _isNfcScanning = true;
      _idController.text = 'NFC olvasás folyamatban...';
    });
    _nfcAnimController.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isNfcScanning) {
        setState(() {
          _isNfcScanning = false;
        });
        _nfcAnimController.stop();
      }
    });
  }

  void _simulateNfcSuccess(String tagId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isNfcScanning = false;
    });
    _nfcAnimController.stop();
    _findAndShowHive(tagId);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final Set<String> hivesWithOverdueTasks = _repository.scheduledTasks
        .where((t) =>
            !t.isCompleted &&
            t.scheduledDate.isBefore(now) &&
            !t.id.contains('ESCAPEMENT') &&
            !t.title.contains('Méhszöktetés'))
        .map((t) => t.hiveId)
        .toSet();

    double headingRad = (_locationService.heading ?? 0) * (math.pi / 180.0);
    Color compassColor =
        (_locationService.accuracy == null || _locationService.accuracy! > 40.0)
        ? Colors.redAccent
        : (_locationService.accuracy! > 15.0
              ? Colors.amberAccent
              : Colors.greenAccent);
    bool isRedFlashing =
        (_locationService.accuracy == null ||
        _locationService.accuracy! > 40.0);

    bool anyHiveNeedsFlash = false;
    final Map<String, String> hiveWorstStatusCache = {};
    for (final h in _repository.hives) {
      final rawWorst = h.worstStatus;
      final effectiveWorst = hivesWithOverdueTasks.contains(h.id) && rawWorst == 'green'
          ? 'yellow'
          : rawWorst;
      hiveWorstStatusCache[h.id] = effectiveWorst;
      if (!anyHiveNeedsFlash) {
        final hasSpecialBox = h.boxes.any(
          (b) =>
              b.isActive &&
              (b.type == 'bottom' ||
                  b.type == 'pollen_trap' ||
                  b.type == 'escapement'),
        );
        if (hasSpecialBox ||
            h.isQueenReplacementActive ||
            effectiveWorst == 'flashing_red' ||
            effectiveWorst == 'red' ||
            h.status == 'red') {
          anyHiveNeedsFlash = true;
        }
      }
    }
    _syncBlinkControllers(
      anyHiveFlashing: anyHiveNeedsFlash,
      shouldFlashCompass: _isAdvancedMode && isRedFlashing,
    );

    return PopScope(
      canPop: !_isCameraActive && !_isEditMode && !_isAdvancedMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isCameraActive) {
          _setCameraActive(false);
          return;
        }
        if (_isEditMode) {
          setState(() => _isEditMode = false);
          return;
        }
        if (_isAdvancedMode) {
          setState(() => _isAdvancedMode = false);
          return;
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
        if (!_isCameraActive && _isAdvancedMode)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => _isAdvancedMode = false);
              },
              child: const SizedBox.expand(),
            ),
          ),

        RepaintBoundary(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _locationService.currentPosition,
              initialZoom: 17.0,
              onMapReady: () {
                _isMapReady = true;
              },
              interactionOptions: InteractionOptions(
                flags: (_isEditMode || _isCameraActive) ? InteractiveFlag.none : InteractiveFlag.all,
              ),
              onPositionChanged: (camera, hasGesture) {
                _currentMapRotationRad = camera.rotationRad;
              },
              onLongPress: (tapPosition, point) {
                if (!_isCameraActive) {
                  _toggleEditMode();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.balazs.hive_monitor',
                maxNativeZoom: 19,
                keepBuffer: 2,
                panBuffer: 1,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _locationService.currentPosition,
                    width: 70,
                    height: 70,
                    child: RepaintBoundary(
                      child: Transform.rotate(
                        angle: headingRad,
                        child: Icon(
                          Icons.navigation,
                          color: compassColor,
                          size: 46,
                        ),
                      ),
                    ),
                  ),

                  // 1. Kaptár markerek
                  for (var hive in _repository.hives)
                    Marker(
                      point: hive.location,
                      width: 58,
                      height: 58,
                      child: GestureDetector(
                        onTap: () {
                          if (!_isEditMode) {
                            if (hive.isQueenReplacementActive) {
                              showQueenReplacementFlowDialog(
                                context: context,
                                hive: hive,
                                repository: _repository,
                                onOpenDetails: () => _showHiveDetails(hive),
                              );
                            } else if (hive.isLocked) {
                              showLockedHiveWarningDialog(
                                context: context,
                                hive: hive,
                                repository: _repository,
                                onOpenDetails: () => _showHiveDetails(hive),
                              );
                            } else {
                              _showHiveDetails(hive);
                            }
                          }
                        },
                        onLongPress: _toggleEditMode,
                        onPanUpdate: _isEditMode
                            ? (details) {
                                setState(() {
                                  hive.location = _applyDragDelta(
                                    hive.location,
                                    details.delta,
                                  );
                                });
                              }
                            : null,
                        child: () {
                          final bool hasActiveBottomBoard = hive.boxes.any(
                            (b) => b.type == 'bottom' && b.isActive,
                          );
                          final bool isPollenTrapActive = hive.boxes.any(
                            (b) => b.type == 'pollen_trap' && b.isActive,
                          );
                          final bool hasActiveEscapement = hive.boxes.any(
                            (b) => b.type == 'escapement' && b.isActive,
                          );

                          final bool hasOverdueTask =
                              hivesWithOverdueTasks.contains(hive.id);

                          final worstStatus =
                              hiveWorstStatusCache[hive.id] ?? hive.worstStatus;

                          final bool hasTartorHordozo =
                              hive.protocol == 'tarto_hordozo' ||
                              hive.boxes.any(
                                (b) => b.type == 'treatment_strip',
                              );

                          final IconData hiveIcon = _getHiveIcon(hive);

                          final bool isEscapementOverdue = hive.boxes.any(
                            (b) =>
                                (b.type == 'escapement' ||
                                    b.name.toLowerCase().contains('szöktet')) &&
                                b.isActive &&
                                b.statusUpdatedAt != null &&
                                now.difference(b.statusUpdatedAt!).inHours >= 24,
                          );

                          final bool isImmediateIntervention = hive.isQueenReplacementActive ||
                              isEscapementOverdue ||
                              worstStatus == 'flashing_red' ||
                              worstStatus == 'red' ||
                              hive.status == 'red';

                          Widget markerWidget;

                          // Ha azonnali beavatkozásra van szükség (Anyacsere / 24h szöktetés lejárat / piros riasztás),
                          // az elsőbbséget élvez az egyéb fiók (pl. pollengyűjtő / aljdeszka) jelzésekkel szemben!
                          if (!isImmediateIntervention &&
                              (hasActiveEscapement ||
                                  hasActiveBottomBoard ||
                                  isPollenTrapActive)) {
                            Color badgeColor;
                            IconData badgeIcon;
                            if (hasActiveEscapement) {
                              badgeColor = Colors.amber[800]!;
                              badgeIcon = Icons.filter_alt;
                            } else if (isPollenTrapActive) {
                              badgeColor = Colors.orange;
                              badgeIcon = Icons.local_florist;
                            } else {
                              badgeColor = Colors.deepOrange;
                              badgeIcon = Icons.bug_report;
                            }

                            markerWidget = Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isEditMode
                                          ? Colors.amberAccent
                                          : (hive.isRelapsedAfterStrengthening
                                              ? Colors.redAccent
                                              : Colors.white),
                                      width: (_isEditMode || hive.isRelapsedAfterStrengthening) ? 3 : 2,
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Center(
                                        child: Icon(
                                          badgeIcon,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                      if (hasTartorHordozo)
                                        Positioned(
                                          child: Container(
                                            width: 28,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(
                                                2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (hive.isRelapsedAfterStrengthening)
                                  Positioned(
                                    top: -6,
                                    left: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.amberAccent,
                                          width: 1.8,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black87,
                                            blurRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.priority_high_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                    ),
                                  ),
                                if (hive.hasExtraBoxes)
                                  Positioned(
                                    bottom: -6,
                                    right: _isEditMode ? null : -6,
                                    left: _isEditMode ? -6 : null,
                                    child: Container(
                                      width: 21,
                                      height: 21,
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: hive.requiresSpanifer
                                              ? Colors.orangeAccent
                                              : Colors.amberAccent,
                                          width: 1.6,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black87,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: HiveTowerIcon(
                                          size: 13,
                                          color: hive.requiresSpanifer
                                              ? Colors.orangeAccent
                                              : Colors.amberAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          } else {
                            final Color markerBorderColor = _isEditMode
                                ? Colors.amberAccent
                                : (isImmediateIntervention
                                    ? Colors.redAccent
                                    : (hive.isLocked ? Colors.amberAccent : Colors.white));

                            markerWidget = Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(worstStatus),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: markerBorderColor,
                                      width: (isImmediateIntervention || _isEditMode) ? 3 : 2,
                                    ),
                                    boxShadow: [
                                      if (isImmediateIntervention)
                                        BoxShadow(
                                          color: Colors.redAccent.withAlpha(200),
                                          blurRadius: 12,
                                          spreadRadius: 3,
                                        )
                                      else if (hive.isLocked)
                                        BoxShadow(
                                          color: Colors.amberAccent.withAlpha(120),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Center(
                                        child: Icon(
                                          hiveIcon,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                      if (hasTartorHordozo)
                                        Positioned(
                                          child: Container(
                                            width: 28,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Teljesítmény és visszaesés jelző:
                                // 1. Felkiáltójel (!): erősítés után ismét legyengült a többihez képest (tartós probléma!)
                                // 2. Aranysárga csillag (⭐): Rekorder család (frissen erősített nem kaphatja!)
                                // 3. Piros lefelé nyíl: rosszul teljesítő család
                                if (hive.isRelapsedAfterStrengthening)
                                  Positioned(
                                    top: -6,
                                    left: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.amberAccent,
                                          width: 1.8,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black87,
                                            blurRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.priority_high_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                    ),
                                  )
                                else if (hive.isTopPerformer)
                                  Positioned(
                                    top: -4,
                                    left: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.amberAccent,
                                          width: 1.5,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black87,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.star,
                                        color: Colors.amberAccent,
                                        size: 11,
                                      ),
                                    ),
                                  )
                                else if (hive.isPoorPerformer)
                                  Positioned(
                                    top: -4,
                                    left: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7F1D1D),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.redAccent,
                                          width: 1.5,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black87,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.arrow_downward,
                                        color: Colors.white,
                                        size: 11,
                                      ),
                                    ),
                                  ),
                                if (hive.isQueenReplacementActive)
                                  Positioned(
                                    top: -5,
                                    right: -5,
                                    child: Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black54, blurRadius: 4),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.female, // NŐ-JEL (♀), nem virág!
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                    ),
                                  ),
                                if (hive.isLocked)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.amberAccent, width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black87, blurRadius: 4),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.lock,
                                        color: Colors.amberAccent,
                                        size: 11,
                                      ),
                                    ),
                                  ),
                                if (hasOverdueTask && !isImmediateIntervention && !hive.isLocked)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.cloud_sync,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                                if (hive.hasExtraBoxes)
                                  Positioned(
                                    bottom: -6,
                                    right: _isEditMode ? null : -6,
                                    left: _isEditMode ? -6 : null,
                                    child: Container(
                                      width: 21,
                                      height: 21,
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: hive.requiresSpanifer
                                              ? Colors.orangeAccent
                                              : Colors.amberAccent,
                                          width: 1.6,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black87,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: HiveTowerIcon(
                                          size: 13,
                                          color: hive.requiresSpanifer
                                              ? Colors.orangeAccent
                                              : Colors.amberAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_isEditMode)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.amberAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.open_with,
                                        color: Colors.black,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }

                          // Kaptár kijáró / repülőnyílás tájolási kis nyila
                          final double headingDeg = hive.entranceHeading ?? 180.0;
                          final double headingRad = (headingDeg * math.pi / 180.0) - _currentMapRotationRad;

                          final entranceArrow = Positioned.fill(
                            child: Transform.rotate(
                              angle: headingRad,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Transform.translate(
                                  offset: const Offset(0, -6),
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.amberAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black87, width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black54,
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.navigation,
                                        size: 9,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );

                          final completeMarker = Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              markerWidget,
                              entranceArrow,
                            ],
                          );

                          // Azonnali beavatkozást igénylő kaptár villogjon (FadeTransition), RepaintBoundary-vel izolálva
                          if (isImmediateIntervention ||
                              hasActiveEscapement ||
                              hasActiveBottomBoard ||
                              isPollenTrapActive) {
                            return RepaintBoundary(
                              child: FadeTransition(
                                opacity: _redFlashOpacityAnim,
                                child: completeMarker,
                              ),
                            );
                          }

                          return completeMarker;
                        }(),
                      ),
                    ),

                  // 2. Időjárás-állomás marker (Zöld = Supabase OK, Piros = Nincs kapcsolat)
                  Marker(
                    point: _repository.weatherStation.location,
                    width: 54,
                    height: 54,
                    child: GestureDetector(
                      onTap: () {
                        if (!_isEditMode) {
                          _showStationDetails(_repository.weatherStation);
                        }
                      },
                      onLongPress: _toggleEditMode,
                      onPanUpdate: _isEditMode
                          ? (details) {
                              setState(() {
                                _repository.weatherStation.location =
                                    _applyDragDelta(
                                      _repository.weatherStation.location,
                                      details.delta,
                                    );
                              });
                            }
                          : null,
                      child: () {
                        final station = _repository.weatherStation;
                        final bool isConnected =
                            station.status == 'green' &&
                            _repository.isOnline;
                        final bool isBatteryLow =
                            station.batteryVoltage > 0 && station.batteryVoltage < 3.4;

                        // Az időjárás-állomás marker színe:
                        // - Zöld: ha van kapcsolat, vagy az állomás szenzorai/akkumulátora épek
                        // - Narancs: helyi offline mód (ha nincs felhő szinkron, de az állomás él)
                        // - Piros: kizárólag kritikus hardverhiba (pl. lemerült akku < 3.4V)
                        final Color stationColor = isBatteryLow
                            ? const Color(0xFFef4444)
                            : (isConnected || station.status == 'green'
                                ? const Color(0xFF10b981)
                                : const Color(0xFFF59E0B));

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: stationColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isEditMode
                                      ? Colors.amberAccent
                                      : Colors.white,
                                  width: _isEditMode ? 3 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: stationColor.withAlpha(150),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  isBatteryLow
                                      ? Icons.battery_alert
                                      : Icons.wb_sunny,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: isBatteryLow
                                      ? Colors.redAccent
                                      : (isConnected
                                          ? Colors.greenAccent
                                          : Colors.amberAccent),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black87,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  isBatteryLow
                                      ? Icons.close
                                      : (isConnected
                                          ? Icons.check
                                          : Icons.cloud_off),
                                  size: 10,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        );
                      }(),
                    ),
                  ),

                  // 3. Itató marker 5-fokozatú színkódolással és animált villogással
                  Marker(
                    point: _repository.waterer.location,
                    width: 62,
                    height: 62,
                    child: () {
                      final waterer = _repository.waterer;
                      final wStatus = waterer.status;
                      final Color wColor = getWatererStatusColor(wStatus);
                      final bool isBlinking = (wStatus == 'blinking_red');

                      return GestureDetector(
                        onTap: () {
                          if (!_isEditMode) {
                            _showWatererDetails(waterer);
                          }
                        },
                        onLongPress: _toggleEditMode,
                        onPanUpdate: _isEditMode
                            ? (details) {
                                setState(() {
                                  waterer.location = _applyDragDelta(
                                    waterer.location,
                                    details.delta,
                                  );
                                });
                              }
                            : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isEditMode ? Colors.amberAccent : wColor,
                                  width: _isEditMode ? 3.0 : (isBlinking ? 3.5 : 2.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: wColor.withAlpha(isBlinking ? 190 : 120),
                                    blurRadius: isBlinking ? 12 : 6,
                                    spreadRadius: isBlinking ? 3 : 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: WatererIcon(
                                  size: 24,
                                  status: wStatus,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: wColor,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${waterer.waterLevel.toInt()}%',
                                  style: TextStyle(
                                    color: wColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }(),
                  ),

                  // 4. Szirupszivattyú / Központi Sziruptartály marker
                  Marker(
                    point: _repository.syrupPump.location,
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () {
                        if (!_isEditMode) {
                          _showSyrupPumpDetails(_repository.syrupPump);
                        }
                      },
                      onLongPress: _toggleEditMode,
                      onPanUpdate: _isEditMode
                          ? (details) {
                              setState(() {
                                _repository.syrupPump.location =
                                    _applyDragDelta(
                                      _repository.syrupPump.location,
                                      details.delta,
                                    );
                              });
                            }
                          : null,
                      child: () {
                        final pump = _repository.syrupPump;
                        final String pStatus = pump.status;
                        final Color pColor = getSyrupStatusColor(pStatus);
                        final double remPct =
                            pump.tankLevelPercent.clamp(0.0, 100.0);

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isEditMode
                                      ? Colors.amberAccent
                                      : pColor,
                                  width: (pStatus == 'blinking_red' ||
                                          _isEditMode)
                                      ? 3.5
                                      : 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: pColor.withAlpha(140),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: CandyIcon(
                                  size: 28,
                                  status: pStatus,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: pColor,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: pColor.withAlpha(70),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${remPct.toInt()}%',
                                  style: TextStyle(
                                    color: pColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_isCameraActive && _mapScannerCtrl != null)
          ScannerOverlay(
            cameraController: _mapScannerCtrl!,
            onDetect: (code) {
              _setCameraActive(false);
              _idController.text = code;
              _findAndShowHive(code);
            },
            onClose: () => _setCameraActive(false),
          ),

        // --- ÁTRENDEZŐ MÓD FIGYELMEZTETŐ ÉS MENTŐ SÁV ---
        if (!_isCameraActive && _isEditMode)
          Positioned(
            top: 92,
            left: 16,
            right: 84,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xEB141428),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amberAccent, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.open_with, color: Colors.amberAccent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Átrendező mód: húzd az ikonokat a kívánt helyre!',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _toggleEditMode,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(
                      'Kész',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bal felső NAGY + GOMB: Új kaptár létrehozása varázsló
        if (!_isCameraActive)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _isAdvancedMode ? 88 : 12,
            left: 12,
            child: SizedBox(
              width: 68,
              height: 68,
              child: FloatingActionButton(
                heroTag: 'addNewHiveWizardBtn',
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                elevation: 6,
                tooltip: 'Új kaptár létrehozása',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white, width: 2),
                ),
                onPressed: () => _openNewHiveWizard(),
                child: const Icon(Icons.add, size: 40),
              ),
            ),
          ),

        // Felső vezérlőgombok (Iroda + Feldolgozóhelyiség + Pozíció + Forgatás)
        if (!_isCameraActive)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _isAdvancedMode ? 88 : 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- IRODA GOMB ---
                FloatingActionButton.small(
                  heroTag: 'officeBtn',
                  backgroundColor: const Color(0xB3000000),
                  foregroundColor: Colors.amberAccent,
                  tooltip: 'Iroda (Statisztika, Nyomtatás, Összerendelés)',
                  onPressed: _openOfficeDashboard,
                  child: const Icon(Icons.desktop_windows),
                ),
                const SizedBox(width: 14),
                // --- FELDOLGOZÓHELYISÉG GOMB ---
                FloatingActionButton.small(
                  heroTag: 'processingRoomBtn',
                  backgroundColor: const Color(0xB3000000),
                  foregroundColor: Colors.tealAccent,
                  tooltip: 'Feldolgozóhelyiség (Pergetés, Mérleg, Hordók, Műlépezés)',
                  onPressed: _openProcessingRoom,
                  child: const Icon(Icons.factory),
                ),
                const SizedBox(width: 14),
                FloatingActionButton.small(
                  heroTag: 'centerPositionBtn',
                  backgroundColor: const Color(0xB3000000),
                  foregroundColor: Colors.lightBlueAccent,
                  tooltip: 'Saját helyzetre ugrás',
                  onPressed: _refreshPosition,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(width: 14),
                FloatingActionButton.small(
                  heroTag: 'rotateBtn',
                  backgroundColor: const Color(0xB3000000),
                  foregroundColor: _isMapFreeRotate
                      ? Colors.greenAccent
                      : Colors.amberAccent,
                  tooltip: 'Térkép forgatása',
                  child: Icon(
                    _isMapFreeRotate ? Icons.navigation : Icons.explore,
                  ),
                  onPressed: () {
                    setState(() {
                      _isMapFreeRotate = !_isMapFreeRotate;
                      if (!_isMapFreeRotate && _isMapReady && !_isCameraActive) {
                        try {
                          _mapController.rotate(0);
                        } catch (_) {}
                      }
                    });
                  },
                ),
              ],
            ),
          ),

        // Boxkesztyű-kompatibilis Nagyítós Zoom gombok + ALATTA A BEÁLLÍTÁSOK GOMB
        if (!_isCameraActive)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _isAdvancedMode ? 156 : 84,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'zoomInBtn',
                  backgroundColor: const Color(0xD90F172A),
                  foregroundColor: Colors.amberAccent,
                  tooltip: 'Közelítés (Nagyítás)',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (_isMapReady && !_isCameraActive) {
                      try {
                        final zoom = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, zoom + 1);
                      } catch (_) {}
                    }
                  },
                  child: const Icon(Icons.zoom_in, size: 32),
                ),
                const SizedBox(height: 20),
                FloatingActionButton(
                  heroTag: 'zoomOutBtn',
                  backgroundColor: const Color(0xD90F172A),
                  foregroundColor: Colors.amberAccent,
                  tooltip: 'Távolítás (Kicsinyítés)',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (_isMapReady && !_isCameraActive) {
                      try {
                        final zoom = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, zoom - 1);
                      } catch (_) {}
                    }
                  },
                  child: const Icon(Icons.zoom_out, size: 32),
                ),
                const SizedBox(height: 20),
                // --- BEÁLLÍTÁSOK GOMB KÖZVETLENÜL A ZOOM ALATT ---
                FloatingActionButton(
                  heroTag: 'settingsBtn',
                  backgroundColor: const Color(0xD90F172A),
                  foregroundColor: Colors.amberAccent,
                  tooltip: 'Beállítások & Firmware (OTA)',
                  onPressed: _openSettingsScreen,
                  child: const Icon(Icons.settings, size: 28),
                ),
              ],
            ),
          ),

        // Felugró GPS sáv
        if (!_isCameraActive && _isAdvancedMode)
          Stack(
            children: [
              TopGpsBar(
                hasGpsFix: true,
                isRedFlashing: isRedFlashing,
                redOpacityAnim: _compassRedOpacityAnim,
                compassColor: compassColor,
                statusMessage: _locationService.statusMessage,
                headingText: _locationService.getHeadingText(
                  _locationService.heading,
                ),
                onRefresh: _refreshPosition,
              ),
              Positioned(
                top: 18,
                right: 54,
                child: GestureDetector(
                  onTap: () => setState(() => _isAdvancedMode = false),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),

        if (!_isCameraActive)
          ScannerControls(
            isNfcScanning: _isNfcScanning,
            nfcColorAnim: _nfcColorAnim,
            onCameraPressed: () => _setCameraActive(true),
            onNfcPressed: () {
              _startNfcScan();
              Future.delayed(const Duration(seconds: 2), () {
                if (_isNfcScanning) {
                  _simulateNfcSuccess('BOX_05_A');
                }
              });
            },
            onNfcStop: () => setState(() {
              _isNfcScanning = false;
            }),
          ),
      ],
    ),
  );
}
}
