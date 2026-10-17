import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'dart:math' as math;

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../services/location_compass_service.dart';
import '../widgets/top_gps_bar.dart';
import '../widgets/scanner_controls.dart';
import '../widgets/hive_detail_sheet.dart';
import '../widgets/hive_config_dialog.dart';
import '../widgets/scanner_overlay.dart';

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

  bool _isAdvancedMode = false;
  bool _isMapFreeRotate = true;

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
    _repository.removeListener(_onRepositoryChanged);
    _nfcAnimController.dispose();
    _redFlashingAnimController.dispose();
    _compassRedAnimController.dispose();
    _idController.dispose();
    super.dispose();
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
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Ismeretlen azonosító 🐝',
            style: TextStyle(color: Colors.amberAccent),
          ),
          content: Text(
            'A(z) "$code" kód nincs még a rendszerben. Tényleg új elem vagy kaptár?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mégse', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
                _showNewBoxOrHiveWizard(code);
              },
              icon: const Icon(Icons.add_box),
              label: const Text('Igen, új regisztrálása'),
            ),
          ],
        );
      },
    );
  }

  void _showNewBoxOrHiveWizard(String primaryCode) {
    bool createNewQueen = true;
    String queenOrigin = 'Saját nevelés';
    String queenVintageYear = '2026 (Fehér)';
    QueenData? selectedExistingQueen = _repository.queens.isNotEmpty
        ? _repository.queens.first
        : null;
    String macAddress = '';

    String selectedType = 'honey';
    String boxName = 'Méztér';
    String? secondaryCode;
    HiveData? selectedTargetHive = _repository.hives.isNotEmpty
        ? _repository.hives.first
        : null;
    bool isNewHive = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(
                'Új elem / kaptár regisztráció\n(Kód: $primaryCode)',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hová szánod az elemet?',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButton<bool>(
                      value: isNewHive,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Text('Teljesen új kaptárként (Fészekkel)'),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('Meglévő kaptárhoz fiókként'),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => isNewHive = val ?? true),
                    ),
                    const SizedBox(height: 12),

                    if (isNewHive) ...[
                      TextField(
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monitor MAC-cím',
                          hintText: 'pl. 24:6F:28:AE:3B:12',
                          labelStyle: TextStyle(color: Colors.amber),
                        ),
                        onChanged: (val) => macAddress = val,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Méhanya hozzárendelése:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text(
                                'Új anya',
                                style: TextStyle(fontSize: 12),
                              ),
                              icon: Icon(Icons.add_circle_outline, size: 16),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text(
                                'Meglévő',
                                style: TextStyle(fontSize: 12),
                              ),
                              icon: Icon(Icons.list, size: 16),
                            ),
                          ],
                          selected: {createNewQueen},
                          style: SegmentedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C2C2C),
                            foregroundColor: Colors.white70,
                            selectedBackgroundColor: Colors.amber,
                            selectedForegroundColor: Colors.black,
                          ),
                          onSelectionChanged: (Set<bool> newSelection) {
                            setDialogState(
                              () => createNewQueen = newSelection.first,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (createNewQueen) ...[
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Származás / Típus',
                            labelStyle: TextStyle(color: Colors.amber),
                          ),
                          controller: TextEditingController(text: queenOrigin),
                          onChanged: (val) => queenOrigin = val,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Évjárat és szín',
                            labelStyle: TextStyle(color: Colors.amber),
                          ),
                          controller: TextEditingController(
                            text: queenVintageYear,
                          ),
                          onChanged: (val) => queenVintageYear = val,
                        ),
                      ] else ...[
                        DropdownButton<QueenData>(
                          value: selectedExistingQueen,
                          dropdownColor: const Color(0xFF2C2C2C),
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          items: _repository.queens
                              .map(
                                (q) => DropdownMenuItem(
                                  value: q,
                                  child: Text(
                                    '${q.id} - ${q.origin} (${q.vintage})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => selectedExistingQueen = val);
                          },
                        ),
                      ],
                    ] else ...[
                      const Text(
                        'Család / Kaptár kiválasztása:',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      DropdownButton<HiveData>(
                        value: selectedTargetHive,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        items: _repository.hives
                            .map(
                              (h) => DropdownMenuItem(
                                value: h,
                                child: Text(h.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedTargetHive = val),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Elem típusa:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<String>(
                        value: selectedType,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'honey',
                            child: Text('Méztér'),
                          ),
                          DropdownMenuItem(
                            value: 'feeder',
                            child: Text('Etető'),
                          ),
                          DropdownMenuItem(
                            value: 'escapement',
                            child: Text('Szöktető'),
                          ),
                          DropdownMenuItem(
                            value: 'vent',
                            child: Text('Szellőző'),
                          ),
                          DropdownMenuItem(
                            value: 'pollen_trap',
                            child: Text('Pollengyűjtő'),
                          ),
                          DropdownMenuItem(value: 'roof', child: Text('Tető')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedType = val;
                              boxName = (val == 'honey')
                                  ? 'Méztér'
                                  : 'Tartozék';
                            });
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242424),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withAlpha(100)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🔗 Másodlagos azonosító (pl. NFC tag):',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Opcionális NFC kód',
                              hintStyle: TextStyle(color: Colors.white38),
                              isDense: true,
                            ),
                            controller: TextEditingController(
                              text: secondaryCode,
                            ),
                            onChanged: (val) => secondaryCode = val,
                          ),
                        ],
                      ),
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
                    if (isNewHive) {
                      QueenData assignedQueen;
                      if (createNewQueen) {
                        String timestampId =
                            'QUEEN_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';
                        assignedQueen = QueenData(
                          id: timestampId,
                          origin: queenOrigin,
                          vintage: queenVintageYear,
                        );
                        _repository.addQueen(assignedQueen);
                      } else {
                        assignedQueen = selectedExistingQueen!;
                      }

                      final newHive = HiveData(
                        id: primaryCode,
                        name: 'Család ($primaryCode)',
                        location: _locationService.currentPosition,
                        status: 'green',
                        temp: 35.0,
                        humidity: 60.0,
                        extTemp: 22.0,
                        extHumidity: 50.0,
                        weight: 35.0,
                        batteryVoltage: 4.2,
                        zcr: 3800.0,
                        queen: assignedQueen,
                        boxes: [
                          BoxElement(
                            name: 'Fészek',
                            code: primaryCode,
                            secondaryCode: secondaryCode,
                            type: 'nest',
                            size: 'dadant',
                            status: 'green',
                          ),
                        ],
                        serverConnection: 'Párosítva (MAC: $macAddress)',
                      );
                      _repository.addHive(newHive);
                    } else if (selectedTargetHive != null) {
                      _repository.addBoxToHive(
                        selectedTargetHive!,
                        BoxElement(
                          name: boxName,
                          code: primaryCode,
                          secondaryCode: secondaryCode,
                          type: selectedType,
                          size: selectedType,
                          status: 'green',
                        ),
                      );
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sikeresen rögzítve és összerendelve!'),
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
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HiveDetailSheet(
        hive: hive,
        redFlashOpacityAnim: _redFlashOpacityAnim,
        onConfigurePressed: () {
          Navigator.pop(context);
          _openSetupDialog();
        },
      ),
    );
  }

  void _openSetupDialog() {
    showDialog(context: context, builder: (context) => const HiveSetupDialog());
  }

  // --- IDŐJÁRÁS-ÁLLOMÁS RÉSZLETEK ---
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

  // --- ITATÓ RÉSZLETEK ---
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
                'Vízszint',
                '${waterer.waterLevel}%',
                Icons.waves,
                Colors.lightBlueAccent,
              ),
              const SizedBox(height: 8),
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

  // --- SZIRUPSZIVATTYÚ RÉSZLETEK ---
  void _showSyrupPumpDetails(SyrupPumpData pump) {
    double selectedLiters = 1.0;
    String targetHive = _repository.hives.isNotEmpty
        ? _repository.hives.first.name
        : '1. Család';

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
                      if (val != null) setDialogState(() => targetHive = val);
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
                          'Sikeres szirupadagolás ($targetHive részére: ${selectedLiters.toStringAsFixed(1)}L)!',
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

    return Stack(
      fit: StackFit.expand,
      children: [
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

                  // 1. Kaptár markerek (Feliratmentes, csak tiszta státuszszínek)
                  for (var hive in _repository.hives)
                    Marker(
                      point: hive.location,
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => _showHiveDetails(hive),
                        child: () {
                          final worstStatus = hive.worstStatus;
                          if (worstStatus == 'flashing_red') {
                            return FadeTransition(
                              opacity: _redFlashOpacityAnim,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.warning,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return Container(
                              decoration: BoxDecoration(
                                color: _getStatusColor(worstStatus),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
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
                    width: 42,
                    height: 42,
                    child: GestureDetector(
                      onTap: () => _showWatererDetails(_repository.waterer),
                      child: Container(
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
                    ),
                  ),

                  // 4. Szirupszivattyú marker
                  Marker(
                    point: _repository.syrupPump.location,
                    width: 42,
                    height: 42,
                    child: GestureDetector(
                      onTap: () => _showSyrupPumpDetails(_repository.syrupPump),
                      child: Container(
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

        if (!_isCameraActive)
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'settingsBtn',
                      backgroundColor: const Color(0xB3000000),
                      foregroundColor: Colors.amberAccent,
                      tooltip: 'Beállítások & Mestertervek',
                      onPressed: _openSetupDialog,
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
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'advancedBtn',
                      backgroundColor: _isAdvancedMode
                          ? Colors.amber
                          : const Color(0xB3000000),
                      foregroundColor: _isAdvancedMode
                          ? Colors.black
                          : Colors.white,
                      tooltip: 'Részletes GPS adatok',
                      child: const Icon(Icons.tune),
                      onPressed: () =>
                          setState(() => _isAdvancedMode = !_isAdvancedMode),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoomInBtn',
                      backgroundColor: const Color(0xB3000000),
                      foregroundColor: Colors.white,
                      tooltip: 'Közelítés',
                      onPressed: () {
                        final zoom = _mapController.camera.zoom;
                        _mapController.move(
                          _mapController.camera.center,
                          zoom + 1,
                        );
                      },
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'zoomOutBtn',
                      backgroundColor: const Color(0xB3000000),
                      foregroundColor: Colors.white,
                      tooltip: 'Távolítás',
                      onPressed: () {
                        final zoom = _mapController.camera.zoom;
                        _mapController.move(
                          _mapController.camera.center,
                          zoom - 1,
                        );
                      },
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ],
            ),
          ),

        if (!_isCameraActive && _isAdvancedMode)
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
