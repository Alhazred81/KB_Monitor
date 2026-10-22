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
import '../widgets/scanner_controls.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/top_gps_bar.dart';
import 'new_hive_wizard_screen.dart';
import 'firmware_screen.dart';

const String kSecretProtocolPassword = "Multioptipupiloptómia";

class MapAndScannerScreen extends StatefulWidget {
  const MapAndScannerScreen({super.key});

  @override
  State<MapAndScannerScreen> createState() => _MapAndScannerScreenState();
}

class _MapAndScannerScreenState extends State<MapAndScannerScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LocationCompassService _locationService = LocationCompassService();
  final HiveRepository _repository = HiveRepository.instance;

  final TextEditingController _idController = TextEditingController();

  String _serverUrl = '';
  String _anonKey = '';

  bool _isAdvancedMode = false;
  bool _isMapFreeRotate = true;

  // --- FIRMWARE OTA ÁLLAPOTOK ---
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

  bool _isCameraActive = false;

  @override
  void initState() {
    super.initState();
    _serverUrl = _repository.supabaseUrl;
    _anonKey = _repository.supabaseAnonKey;
    _repository.addListener(_onRepositoryChanged);
    _initSensors();
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
      duration: const Duration(milliseconds: 350),
      vsync: this,
    )..repeat(reverse: true);
    _redFlashOpacityAnim = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(_redFlashingAnimController);

    _compassRedAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);
    _compassRedOpacityAnim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(_compassRedAnimController);

    LatLng? pos = await _locationService.updatePosition();
    if (pos != null && mounted) {
      setState(() {});
      _mapController.move(pos, 17.0);
    }

    _locationService.initCompass((heading, accuracy) {
      if (mounted) {
        setState(() {
          if (_isMapFreeRotate && heading != null) {
            _mapController.rotate(-heading);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _localOtaServer?.close(force: true);
    _repository.removeListener(_onRepositoryChanged);
    _nfcAnimController.dispose();
    _redFlashingAnimController.dispose();
    _compassRedAnimController.dispose();
    _idController.dispose();
    super.dispose();
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
    _mapController.move(_locationService.currentPosition, 17.0);
    LatLng? pos = await _locationService.updatePosition();
    if (pos != null && mounted) {
      setState(() {});
      _mapController.move(pos, 17.0);
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
                          child: Text('Etető (Tartozék)'),
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
                              boxName = 'Etető';
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
                      _repository.addBoxToHive(
                        selectedTargetHive!,
                        BoxElement(
                          name: boxName,
                          code: primaryCode,
                          secondaryCode: secondaryCode,
                          type: selectedType,
                          size: boxSize,
                          status: 'green',
                        ),
                      );
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fiók rögzítve a kaptárhoz.'),
                        backgroundColor: Colors.green,
                      ),
                    );
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
      backgroundColor: Colors.transparent,
      builder: (context) => HiveDetailSheet(
        hive: hive,
        redFlashOpacityAnim: _redFlashOpacityAnim,
        onConfigurePressed: () {
          Navigator.pop(context);
          _openHiveConfigDialog(hive);
        },
      ),
    );
  }

  void _openHiveConfigDialog(HiveData hive) {
    showDialog(
      context: context,
      builder: (context) => HiveConfigDialog(selectedHive: hive),
    );
  }

  void _openDatabaseConfigDialog() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenSettingsPage(
          repository: _repository,
          initialUrl: _serverUrl,
          initialAnonKey: _anonKey,
          initialAdvancedMode: _isAdvancedMode,
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
        ),
      ),
    );
  }

  void _openFirmwareScreen() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FirmwareScreen(
          initialApEnabled: _isApAndOtaServerActive,
          initialServerFwPath: _serverFwPath,
          initialMonitorFwPath: _monitorFwPath,
          onSave: (apEnabled, serverFw, monitorFw) async {
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

  void _showStationDetails(StationData station) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Row(
            children: [
              const Icon(Icons.wb_sunny, color: Colors.tealAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  station.name,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 18,
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
                Text(
                  'Azonosító: ${station.id}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const Divider(color: Colors.white24, height: 20),
                _buildStationRow(
                  'Hőmérséklet',
                  '${station.temp} °C',
                  Icons.thermostat,
                  Colors.amber,
                ),
                const SizedBox(height: 8),
                _buildStationRow(
                  'Páratartalom',
                  '${station.humidity} %',
                  Icons.water_drop,
                  Colors.lightBlueAccent,
                ),
                const SizedBox(height: 8),
                _buildStationRow(
                  'Légnyomás',
                  '${station.pressure} hPa',
                  Icons.speed,
                  Colors.orangeAccent,
                ),
                const SizedBox(height: 8),
                _buildStationRow(
                  'UV-index',
                  '${station.uvIndex}',
                  Icons.wb_sunny_outlined,
                  Colors.yellowAccent,
                ),
                const SizedBox(height: 8),
                _buildStationRow(
                  'Fényerősség',
                  '${station.lightLux.toInt()} Lux',
                  Icons.light_mode,
                  Colors.amberAccent,
                ),
                const SizedBox(height: 8),
                _buildStationRow(
                  'Szélsebesség',
                  '${station.windSpeed} m/s (${station.windDirection})',
                  Icons.air,
                  Colors.cyanAccent,
                ),
                const SizedBox(height: 8),
                _buildStationRow(
                  'Esőmennyiség',
                  '${station.rainAmount} mm',
                  Icons.umbrella,
                  Colors.blueAccent,
                ),
                const SizedBox(height: 8),
                _buildStationRow(
                  'Akkumulátor / Táp',
                  '${station.batteryVoltage} V',
                  Icons.battery_full,
                  Colors.greenAccent,
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
  }

  void _showWatererDetails(WatererData waterer) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Row(
            children: [
              const Icon(Icons.water, color: Colors.lightBlueAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  waterer.name,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
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
              const Divider(color: Colors.white24, height: 20),
              _buildStationRow(
                'Folyadékszint (Vízszint)',
                '${waterer.waterLevel}%',
                Icons.waves,
                Colors.lightBlueAccent,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (waterer.waterLevel / 100.0).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  color: Colors.lightBlueAccent,
                ),
              ),
              const SizedBox(height: 12),
              _buildStationRow(
                'Vízhőmérséklet',
                '${waterer.waterTemp} °C',
                Icons.thermostat,
                Colors.amber,
              ),
              const SizedBox(height: 8),
              _buildStationRow(
                'Akkumulátor',
                '${waterer.batteryVoltage} V',
                Icons.battery_full,
                Colors.greenAccent,
              ),
            ],
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
  }

  void _showSyrupPumpDetails(SyrupPumpData pump) {
    double selectedLiters = 1.0;
    String targetHive = _repository.hives.isNotEmpty
        ? _repository.hives.first.name
        : '1. Család';

    const double maxTankCapacity = 100.0;
    final double remainingLiters = (maxTankCapacity - pump.totalPumpedLiters)
        .clamp(0.0, maxTankCapacity);
    final double levelPct = (remainingLiters / maxTankCapacity) * 100.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Row(
                children: [
                  const Icon(
                    Icons.settings_input_component,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pump.name,
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStationRow(
                    'Tartály folyadékszint',
                    '${remainingLiters.toStringAsFixed(1)} L (${levelPct.toStringAsFixed(0)}%)',
                    Icons.opacity,
                    Colors.orangeAccent,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (levelPct / 100.0).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Összes kiszivattyúzott: ${pump.totalPumpedLiters.toStringAsFixed(1)} liter',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Text(
                    'Állapot: ${pump.lastOperationStatus}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  const Text(
                    'Szirup adagolása családnak:',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: targetHive,
                    dropdownColor: const Color(0xFF2C2C2C),
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    items: _repository.hives
                        .map(
                          (h) => DropdownMenuItem(
                            value: h.name,
                            child: Text(h.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => targetHive = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mennyiség: ${selectedLiters.toStringAsFixed(1)} liter',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Slider(
                    value: selectedLiters,
                    min: 0.5,
                    max: 5.0,
                    divisions: 9,
                    activeColor: Colors.amber,
                    onChanged: (val) =>
                        setDialogState(() => selectedLiters = val),
                  ),
                ],
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
                    _repository.pumpSyrup(pump, selectedLiters, targetHive);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Szirupadagolás rögzítve ($targetHive: ${selectedLiters.toStringAsFixed(1)} L).',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Szivattyúzás indítása'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getHiveIcon(HiveData hive) {
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
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
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

    const double maxTankCapacity = 100.0;
    final double remainingSyrupPct =
        ((maxTankCapacity - _repository.syrupPump.totalPumpedLiters).clamp(
              0.0,
              maxTankCapacity,
            ) /
            maxTankCapacity) *
        100.0;

    return Stack(
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

        if (!_isCameraActive)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _locationService.currentPosition,
              initialZoom: 17.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.balazs.hive_monitor',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _locationService.currentPosition,
                    width: 70,
                    height: 70,
                    child: Transform.rotate(
                      angle: headingRad,
                      child: isRedFlashing
                          ? FadeTransition(
                              opacity: _compassRedOpacityAnim,
                              child: const Icon(
                                Icons.navigation,
                                color: Colors.redAccent,
                                size: 46,
                              ),
                            )
                          : Icon(
                              Icons.navigation,
                              color: compassColor,
                              size: 46,
                            ),
                    ),
                  ),

                  // 1. Kaptár markerek
                  for (var hive in _repository.hives)
                    Marker(
                      point: hive.location,
                      width: 42,
                      height: 42,
                      child: GestureDetector(
                        onTap: () => _showHiveDetails(hive),
                        child: () {
                          final bool hasActiveBottomBoard = hive.boxes.any(
                            (b) => b.type == 'bottom' && b.isActive,
                          );
                          final bool isPollenTrapActive = hive.boxes.any(
                            (b) => b.type == 'pollen_trap' && b.isActive,
                          );

                          final now = DateTime.now();
                          final oneWeekLater = now.add(const Duration(days: 7));
                          final bool hasUpcomingTaskSoon = _repository
                              .scheduledTasks
                              .any((t) {
                                if (t.hiveId != hive.id || t.isCompleted) {
                                  return false;
                                }
                                return t.scheduledDate.isAfter(
                                      now.subtract(const Duration(days: 1)),
                                    ) &&
                                    t.scheduledDate.isBefore(oneWeekLater);
                              });

                          final worstStatus = hasUpcomingTaskSoon
                              ? 'yellow'
                              : hive.worstStatus;

                          final bool hasTartorHordozo =
                              hive.protocol == 'tarto_hordozo' ||
                              hive.boxes.any(
                                (b) => b.type == 'treatment_strip',
                              );

                          final IconData hiveIcon = _getHiveIcon(hive);

                          if (hasActiveBottomBoard || isPollenTrapActive) {
                            return FadeTransition(
                              opacity: _redFlashOpacityAnim,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isPollenTrapActive
                                      ? Colors.orange
                                      : Colors.deepOrange,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Center(
                                      child: Icon(
                                        isPollenTrapActive
                                            ? Icons.local_florist
                                            : Icons.bug_report,
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
                            );
                          } else {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(worstStatus),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
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
                                if (hasUpcomingTaskSoon)
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
                              ],
                            );
                          }
                        }(),
                      ),
                    ),

                  // 2. Időjárás-állomás marker
                  Marker(
                    point: _repository.weatherStation.location,
                    width: 42,
                    height: 42,
                    child: GestureDetector(
                      onTap: () =>
                          _showStationDetails(_repository.weatherStation),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.teal.shade700,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.wb_sunny,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Itató marker
                  Marker(
                    point: _repository.waterer.location,
                    width: 58,
                    height: 58,
                    child: GestureDetector(
                      onTap: () => _showWatererDetails(_repository.waterer),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.water,
                                color: Colors.white,
                                size: 20,
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
                                  color: Colors.lightBlueAccent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${_repository.waterer.waterLevel.toInt()}%',
                                style: const TextStyle(
                                  color: Colors.lightBlueAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Szirupszivattyú marker
                  Marker(
                    point: _repository.syrupPump.location,
                    width: 58,
                    height: 58,
                    child: GestureDetector(
                      onTap: () => _showSyrupPumpDetails(_repository.syrupPump),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade800,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.settings_input_component,
                                color: Colors.white,
                                size: 20,
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
                                  color: Colors.orangeAccent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${remainingSyrupPct.toInt()}%',
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          ScannerOverlay(
            cameraController: MobileScannerController(),
            onDetect: (code) {
              setState(() {
                _idController.text = code;
                _isCameraActive = false;
              });
              _findAndShowHive(code);
            },
            onClose: () => setState(() => _isCameraActive = false),
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

        // Felső vezérlőgombok (Firmware + Beállítások + Pozíció + Forgatás)
        if (!_isCameraActive)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _isAdvancedMode ? 88 : 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'firmwareBtn',
                  backgroundColor: const Color(0xB3000000),
                  foregroundColor: _isApAndOtaServerActive
                      ? Colors.greenAccent
                      : Colors.tealAccent,
                  tooltip: 'Firmware',
                  onPressed: _openFirmwareScreen,
                  child: const Icon(Icons.system_update_alt),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'settingsBtn',
                  backgroundColor: const Color(0xB3000000),
                  foregroundColor: Colors.amberAccent,
                  tooltip: 'Beállítások & GPS adatok',
                  onPressed: _openDatabaseConfigDialog,
                  child: const Icon(Icons.settings),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'centerPositionBtn',
                  backgroundColor: const Color(0xB3000000),
                  foregroundColor: Colors.lightBlueAccent,
                  tooltip: 'Saját helyzetre ugrás',
                  onPressed: _refreshPosition,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(width: 8),
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
                      if (!_isMapFreeRotate) {
                        _mapController.rotate(0);
                      }
                    });
                  },
                ),
              ],
            ),
          ),

        // Boxkesztyű-kompatibilis Nagyítós Zoom gombok
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
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom + 1);
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
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom - 1);
                  },
                  child: const Icon(Icons.zoom_out, size: 32),
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
            idController: _idController,
            isNfcScanning: _isNfcScanning,
            nfcColorAnim: _nfcColorAnim,
            onSubmitted: (val) => _findAndShowHive(val),
            onCameraPressed: () => setState(() => _isCameraActive = true),
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
    );
  }
}

// ============================================================================
// TELJES KÉPERNYŐS BEÁLLÍTÁSOK OLDAL
// ============================================================================
class FullScreenSettingsPage extends StatefulWidget {
  final HiveRepository repository;
  final String initialUrl;
  final String initialAnonKey;
  final bool initialAdvancedMode;
  final ValueChanged<bool> onAdvancedModeChanged;
  final void Function(String url, String key, bool advMode) onConfigSaved;

  const FullScreenSettingsPage({
    super.key,
    required this.repository,
    required this.initialUrl,
    required this.initialAnonKey,
    required this.initialAdvancedMode,
    required this.onAdvancedModeChanged,
    required this.onConfigSaved,
  });

  @override
  State<FullScreenSettingsPage> createState() => _FullScreenSettingsPageState();
}

class _FullScreenSettingsPageState extends State<FullScreenSettingsPage> {
  late TextEditingController _urlController;
  late TextEditingController _keyController;
  late bool _isAdvancedMode;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _keyController = TextEditingController(text: widget.initialAnonKey);
    _isAdvancedMode = widget.initialAdvancedMode;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOnline = widget.repository.isOnline;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        foregroundColor: Colors.amberAccent,
        title: const Row(
          children: [
            Icon(Icons.storage, color: Colors.lightBlueAccent, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Adatbázis & GPS Beállítások',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isOnline
                  ? Colors.green.withAlpha(50)
                  : Colors.red.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOnline ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: isOnline ? Colors.greenAccent : Colors.redAccent,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  isOnline
                      ? 'Online'
                      : 'Offline (${widget.repository.offlineQueueLength})',
                  style: TextStyle(
                    color: isOnline ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141428),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Főképernyő megjelenítés',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    title: const Text(
                      'Részletes GPS adatok sáv megjelenítése',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    value: _isAdvancedMode,
                    activeThumbColor: Colors.amber,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() => _isAdvancedMode = val);
                      widget.onAdvancedModeChanged(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141428),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Supabase Projekt & Szerver Kapcsolat',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add meg a Supabase projekt adatait és teszteld a kapcsolatot:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Supabase / Szerver URL',
                      labelStyle: const TextStyle(color: Colors.amber),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Supabase Anon Key',
                      labelStyle: const TextStyle(color: Colors.amber),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        side: const BorderSide(color: Colors.tealAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isTesting
                          ? null
                          : () async {
                              setState(() => _isTesting = true);
                              await widget.repository.setSupabaseConfig(
                                _urlController.text,
                                _keyController.text,
                              );
                              final result = await widget.repository
                                  .testSupabaseConnection();
                              if (mounted) {
                                setState(() => _isTesting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result['message']),
                                    backgroundColor: result['success']
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                );
                              }
                            },
                      icon: _isTesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.tealAccent,
                              ),
                            )
                          : const Icon(Icons.wifi_protected_setup, size: 20),
                      label: Text(
                        _isTesting
                            ? 'Kapcsolat tesztelése...'
                            : 'Kapcsolat tesztelése',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Mégse'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        final trimmedUrl = _urlController.text.trim();
                        final trimmedKey = _keyController.text.trim();
                        widget.onConfigSaved(
                          trimmedUrl,
                          trimmedKey,
                          _isAdvancedMode,
                        );
                        widget.repository.setSupabaseConfig(
                          trimmedUrl,
                          trimmedKey,
                        );
                        widget.repository.syncWithSupabase();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Beállítások elmentve és szinkronizálás indítva.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Mentés',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
  }
}
