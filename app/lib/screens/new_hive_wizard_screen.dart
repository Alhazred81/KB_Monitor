import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../services/location_compass_service.dart';

class NewHiveWizardScreen extends StatefulWidget {
  final LocationCompassService locationService;
  final HiveRepository repository;
  final String? initialCode;

  const NewHiveWizardScreen({
    super.key,
    required this.locationService,
    required this.repository,
    this.initialCode,
  });

  @override
  State<NewHiveWizardScreen> createState() => _NewHiveWizardScreenState();
}

class _NewHiveWizardScreenState extends State<NewHiveWizardScreen> {
  int _currentStep = 0;

  // 1. lépés: Kaptármonitor MAC és Méhanya adatai
  bool _isSearchingAp = true;
  late TextEditingController _macController;
  bool _isNewQueen = true;
  late String _generatedQueenId;
  late TextEditingController _queenOriginCtrl;
  String _queenVintage = '2026 (Fehér)';
  HiveData? _donorHive;

  // 2. lépés: Torony elemei (Aljdeszka, Fészekfiók, Opcionális Etető, Fedő)
  late TextEditingController _bottomCodeCtrl;
  late TextEditingController _broodCodeCtrl;
  String _broodSize = 'hunor';
  bool _includeFeeder = false;
  late TextEditingController _feederCodeCtrl;
  late TextEditingController _roofCodeCtrl;
  String? _activeScannerTarget; // 'bottom', 'brood', 'feeder', 'roof'

  // 3. lépés: Pozíció és Kijáró iránya (Telefon a deklin)
  LatLng? _capturedPosition;
  double? _capturedHeading;
  String _capturedHeadingText = '---°';
  bool _isCalibrating = false;

  @override
  void initState() {
    super.initState();
    final int nextNum = widget.repository.hives.length + 1;
    final String ts = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(9);

    _macController = TextEditingController(text: '');

    _bottomCodeCtrl = TextEditingController(text: 'BOT_${nextNum}_$ts');
    _broodCodeCtrl = TextEditingController(
      text: widget.initialCode ?? 'BROOD_${nextNum}_$ts',
    );
    _feederCodeCtrl = TextEditingController(text: 'FEED_${nextNum}_$ts');
    _roofCodeCtrl = TextEditingController(text: 'ROOF_${nextNum}_$ts');

    _generatedQueenId =
        'Q_${DateTime.now().year}_${nextNum.toString().padLeft(2, '0')}_$ts';
    _queenOriginCtrl = TextEditingController(text: 'Saját nevelés');

    if (widget.repository.hives.isNotEmpty) {
      _donorHive = widget.repository.hives.first;
    }

    _simulateApDiscovery();
  }

  void _simulateApDiscovery() {
    setState(() => _isSearchingAp = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isSearchingAp && _macController.text.trim().isEmpty) {
        final rnd = math.Random();
        String hex() =>
            rnd.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase();
        setState(() {
          _macController.text = '24:6F:28:${hex()}:${hex()}:${hex()}';
          _isSearchingAp = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _macController.dispose();
    _bottomCodeCtrl.dispose();
    _broodCodeCtrl.dispose();
    _feederCodeCtrl.dispose();
    _roofCodeCtrl.dispose();
    _queenOriginCtrl.dispose();
    super.dispose();
  }

  void _assignScannedCode(String target, String code) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (target == 'bottom') _bottomCodeCtrl.text = code;
      if (target == 'brood') _broodCodeCtrl.text = code;
      if (target == 'feeder') _feederCodeCtrl.text = code;
      if (target == 'roof') _roofCodeCtrl.text = code;
      _activeScannerTarget = null;
    });
  }

  Future<void> _measurePositionAndEntrance() async {
    setState(() => _isCalibrating = true);
    HapticFeedback.heavyImpact();

    final LatLng? pos = await widget.locationService.updatePosition();
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _capturedPosition = pos ?? widget.locationService.currentPosition;
        _capturedHeading = widget.locationService.heading ?? 135.0;
        _capturedHeadingText = widget.locationService.getHeadingText(
          _capturedHeading,
        );
        _isCalibrating = false;
      });
    }
  }

  void _saveNewHive() {
    HapticFeedback.heavyImpact();
    final String cleanMac = _macController.text.trim().isNotEmpty
        ? _macController.text.trim()
        : 'HIVE_${DateTime.now().millisecondsSinceEpoch}';

    QueenData assignedQueen;
    if (_isNewQueen) {
      assignedQueen = QueenData(
        id: _generatedQueenId,
        origin: _queenOriginCtrl.text.trim().isNotEmpty
            ? _queenOriginCtrl.text.trim()
            : 'Saját nevelés',
        vintage: _queenVintage,
      );
      widget.repository.addQueen(assignedQueen);
    } else if (_donorHive?.queen != null) {
      assignedQueen = _donorHive!.queen!;
    } else {
      assignedQueen = QueenData(
        id: _generatedQueenId,
        origin: _donorHive != null
            ? 'Átrakva innen: ${_donorHive!.queen?.id ?? "Ismeretlen"}'
            : 'Átrakott anya',
        vintage: _queenVintage,
      );
      widget.repository.addQueen(assignedQueen);
    }

    final List<BoxElement> tower = [
      BoxElement(
        name: 'Aljdeszka',
        code: _bottomCodeCtrl.text.trim(),
        type: 'bottom',
        size: 'bottom',
        status: 'green',
        isActive: false,
      ),
      BoxElement(
        name: 'Fészekfiók',
        code: _broodCodeCtrl.text.trim(),
        type: 'brood_box',
        size: _broodSize,
        status: 'green',
      ),
      if (_includeFeeder)
        BoxElement(
          name: 'Etető',
          code: _feederCodeCtrl.text.trim(),
          type: 'feeder',
          size: _broodSize,
          status: 'green',
        ),
      BoxElement(
        name: 'Tető',
        code: _roofCodeCtrl.text.trim(),
        type: 'roof',
        size: _broodSize,
        status: 'green',
      ),
    ];

    final LatLng finalPos =
        _capturedPosition ?? widget.locationService.currentPosition;

    final newHive = HiveData(
      id: cleanMac,
      name: 'Kaptár (${assignedQueen.id})',
      location: finalPos,
      status: 'green',
      temp: 34.5,
      humidity: 60.0,
      extTemp: widget.repository.weatherStation.temp,
      extHumidity: widget.repository.weatherStation.humidity,
      weight: 28.0,
      batteryVoltage: 4.15,
      zcr: 3600.0,
      queen: assignedQueen,
      boxes: tower,
      serverConnection: 'MAC: $cleanMac | Kijáró: $_capturedHeadingText',
    );

    widget.repository.addHive(newHive);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Új kaptár rögzítve (Anya: ${assignedQueen.id}, Kijáró: $_capturedHeadingText)',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepsTitles = [
      '1/4. Monitor MAC és Méhanya',
      '2/4. Torony felépítése (Alj, Fiók, Etető, Fedő)',
      '3/4. Pozíció és Kijáró tájolása',
      '4/4. Ellenőrzés és Megerősítés',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.amberAccent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Új Kaptár Létrehozása',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              stepsTitles[_currentStep],
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: List.generate(4, (idx) {
                  return Expanded(
                    child: Container(
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: idx <= _currentStep
                            ? Colors.amber
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(child: _buildCurrentStepContent()),
              ),

              const SizedBox(height: 16),
              _buildBottomNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1MonitorAndQueen();
      case 1:
        return _buildStep2TowerElements();
      case 2:
        return _buildStep3PositionAndOrientation();
      case 3:
      default:
        return _buildStep4Confirmation();
    }
  }

  // --- 1. LÉPÉS: KAPTÁRMONITOR MAC ÉS MÉHANYA ---
  Widget _buildStep1MonitorAndQueen() {
    final vintages = [
      '2026 (Fehér)',
      '2025 (Kék)',
      '2024 (Zöld)',
      '2023 (Piros)',
      '2022 (Sárga)',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isSearchingAp ? Colors.amber : Colors.tealAccent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (_isSearchingAp)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Colors.amber,
                        strokeWidth: 3,
                      ),
                    )
                  else
                    const Icon(
                      Icons.wifi_tethering,
                      color: Colors.tealAccent,
                      size: 36,
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _isSearchingAp
                          ? 'Várakozás a kaptármonitor MAC-címére...\n(AP SSID = MAC-cím)'
                          : 'Kaptármonitor Wi-Fi AP észlelve vagy megadva!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    _macController.clear();
                    _simulateApDiscovery();
                  },
                  icon: const Icon(Icons.refresh, size: 24),
                  label: const Text(
                    'AP keresése újra',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Kaptármonitor MAC-címe:',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _macController,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            hintText: 'pl. 24:6F:28:AE:3B:12',
            hintStyle: const TextStyle(color: Colors.white38),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(color: Colors.white24, height: 24),

        // Méhanya adatai
        const Text(
          'Méhanya adatai:',
          style: TextStyle(
            color: Colors.amberAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 70,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNewQueen
                        ? Colors.amber
                        : const Color(0xFF1E293B),
                    foregroundColor: _isNewQueen
                        ? Colors.black
                        : Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _isNewQueen
                            ? Colors.amberAccent
                            : Colors.white24,
                        width: 2,
                      ),
                    ),
                  ),
                  onPressed: () => setState(() => _isNewQueen = true),
                  icon: const Icon(Icons.auto_awesome, size: 24),
                  label: const Text(
                    'Új anya',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 70,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isNewQueen
                        ? Colors.amber
                        : const Color(0xFF1E293B),
                    foregroundColor: !_isNewQueen
                        ? Colors.black
                        : Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: !_isNewQueen
                            ? Colors.amberAccent
                            : Colors.white24,
                        width: 2,
                      ),
                    ),
                  ),
                  onPressed: () => setState(() => _isNewQueen = false),
                  icon: const Icon(Icons.swap_horiz, size: 24),
                  label: const Text(
                    'Átrakott anya',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isNewQueen) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withAlpha(100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Generált egyedi anya-azonosító:',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  _generatedQueenId,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Mikori évjárat (jelölés színe)?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: vintages.map((v) {
              final selected = _queenVintage == v;
              return ChoiceChip(
                label: Text(
                  v,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: selected,
                selectedColor: Colors.amber,
                backgroundColor: const Color(0xFF1E293B),
                onSelected: (_) => setState(() => _queenVintage = v),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Származás / Vonal:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _queenOriginCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E293B),
              hintText: 'pl. Saját nevelés / Zsidei vonal',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ] else ...[
          const Text(
            'Melyik anyát raktad át másik kaptárból?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (widget.repository.hives.isEmpty)
            const Text(
              'Nincs még másik kaptár a rendszerben, válaszd az "Új anya" opciót!',
              style: TextStyle(color: Colors.orangeAccent),
            )
          else
            ...widget.repository.hives.map((h) {
              final bool selected = _donorHive == h;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _donorHive = h),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected ? Colors.amber : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? Colors.white : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: selected ? Colors.black : Colors.amberAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Anya ID: ${h.queen?.id ?? "Nincs adat"} (${h.name})',
                            style: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }

  // --- 2. LÉPÉS: TORONY ELEMEI ---
  Widget _buildStep2TowerElements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_activeScannerTarget != null) ...[
          Container(
            height: 220,
            margin: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty &&
                          barcodes.first.rawValue != null) {
                        _assignScannedCode(
                          _activeScannerTarget!,
                          barcodes.first.rawValue!,
                        );
                      }
                    },
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black87,
                      ),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () =>
                          setState(() => _activeScannerTarget = null),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        _buildBoxInputCard(
          title: '1. Aljdeszka',
          icon: Icons.layers,
          controller: _bottomCodeCtrl,
          targetKey: 'bottom',
          color: Colors.tealAccent,
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amberAccent.withAlpha(120),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.hive, color: Colors.amberAccent, size: 28),
                  SizedBox(width: 10),
                  Text(
                    '2. Fészekfiók (1 fiókos új család)',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Fiók mérete:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSizeChip('Hunor', 'hunor'),
                  _buildSizeChip('NB', 'nb'),
                  _buildSizeChip('Dadant', 'dadant'),
                  _buildSizeChip('Langstroth', 'langstroth'),
                ],
              ),
              const SizedBox(height: 12),
              _buildQrNfcRow(_broodCodeCtrl, 'brood'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _includeFeeder ? Colors.lightBlueAccent : Colors.white24,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Colors.lightBlueAccent,
                title: const Text(
                  '3. Etető felhelyezése (Opcionális)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                value: _includeFeeder,
                onChanged: (val) => setState(() => _includeFeeder = val),
              ),
              if (_includeFeeder) ...[
                const SizedBox(height: 8),
                _buildQrNfcRow(_feederCodeCtrl, 'feeder'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildBoxInputCard(
          title: '4. Fedő (Dekli)',
          icon: Icons.roofing,
          controller: _roofCodeCtrl,
          targetKey: 'roof',
          color: Colors.orangeAccent,
        ),
      ],
    );
  }

  Widget _buildSizeChip(String label, String value) {
    final bool selected = _broodSize == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      selected: selected,
      selectedColor: Colors.amber,
      backgroundColor: const Color(0xFF0F172A),
      onSelected: (_) => setState(() => _broodSize = value),
    );
  }

  Widget _buildBoxInputCard({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required String targetKey,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildQrNfcRow(controller, targetKey),
        ],
      ),
    );
  }

  Widget _buildQrNfcRow(TextEditingController controller, String targetKey) {
    return Column(
      children: [
        TextField(
          controller: controller,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            labelText: 'Azonosító (QR / NFC)',
            labelStyle: const TextStyle(color: Colors.white60),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    setState(() => _activeScannerTarget = targetKey);
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 24),
                  label: const Text(
                    'QR Kamera',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.tealAccent,
                    side: const BorderSide(color: Colors.tealAccent, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final String nfcCode =
                        'NFC_${targetKey.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
                    _assignScannedCode(targetKey, nfcCode);
                  },
                  icon: const Icon(Icons.nfc, size: 24),
                  label: const Text(
                    'NFC Érintés',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 3. LÉPÉS: POZÍCIÓ ÉS KIJÁRÓ IRÁNYA ---
  Widget _buildStep3PositionAndOrientation() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amberAccent, width: 2),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.screen_rotation_alt,
                color: Colors.amberAccent,
                size: 56,
              ),
              const SizedBox(height: 12),
              const Text(
                'Helyezd a telefont a fedőre (deklire)!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Miután a dekli a helyére került, fektesd rá a telefont a kaptár tetejére úgy, hogy a telefon felső éle a kijáró irányába mutasson, majd nyomd meg a lenti gombot.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _isCalibrating
                      ? null
                      : _measurePositionAndEntrance,
                  icon: _isCalibrating
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.explore, size: 36),
                  label: Text(
                    _isCalibrating
                        ? 'MÉRÉS FOLYAMATBAN...'
                        : 'POZÍCIÓ ÉS KIJÁRÓ RÖGZÍTÉSE',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_capturedPosition != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(30),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.greenAccent, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent),
                    SizedBox(width: 8),
                    Text(
                      'Mérés sikeresen rögzítve:',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'GPS Koordináta: ${_capturedPosition!.latitude.toStringAsFixed(5)}, ${_capturedPosition!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kijáró tájolása: $_capturedHeadingText',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- 4. LÉPÉS: ÖSSZEGZÉS ÉS MEGERŐSÍTÉS ---
  Widget _buildStep4Confirmation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Új Kaptár Összegzése',
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildSummaryItem('Kaptármonitor MAC:', _macController.text),
          _buildSummaryItem('Aljdeszka kód:', _bottomCodeCtrl.text),
          _buildSummaryItem(
            'Fészekfiók:',
            '${_broodCodeCtrl.text} (${_broodSize.toUpperCase()})',
          ),
          _buildSummaryItem(
            'Etető:',
            _includeFeeder ? _feederCodeCtrl.text : 'Nincs felhelyezve',
          ),
          _buildSummaryItem('Fedő (Dekli):', _roofCodeCtrl.text),
          _buildSummaryItem(
            'Méhanya:',
            _isNewQueen
                ? 'Új ($_generatedQueenId - $_queenVintage)'
                : 'Átrakott (Anya ID: ${_donorHive?.queen?.id ?? "-"})',
          ),
          _buildSummaryItem('Kijáró iránya:', _capturedHeadingText),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ALSÓ NAVIGÁCIÓS ÉS MEGERŐSÍTŐ GOMBOK ---
  Widget _buildBottomNavigationButtons() {
    if (_currentStep == 3) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 68,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 28),
                label: const Text(
                  'MÉGSE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 68,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _saveNewHive,
                icon: const Icon(Icons.check, size: 28),
                label: const Text(
                  'MEGERŐSÍTÉS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 64,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () {
                if (_currentStep == 0) {
                  Navigator.pop(context);
                } else {
                  setState(() => _currentStep--);
                }
              },
              child: Text(
                _currentStep == 0 ? 'MÉGSE' : 'ELŐZŐ',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: SizedBox(
            height: 64,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () {
                if (_currentStep == 2 && _capturedPosition == null) {
                  _measurePositionAndEntrance().then((_) {
                    if (mounted) setState(() => _currentStep++);
                  });
                } else {
                  setState(() => _currentStep++);
                }
              },
              child: const Text(
                'TOVÁBB',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
