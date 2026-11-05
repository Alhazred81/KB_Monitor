import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';

class HoneyContainer {
  final String id;
  String type;
  String honeyType;
  double tareWeightKg;
  double currentNetWeightKg;
  double maxCapacityKg;
  double avgMoisture;
  String batchCode;
  String status;

  HoneyContainer({
    required this.id,
    required this.type,
    required this.honeyType,
    required this.tareWeightKg,
    required this.currentNetWeightKg,
    required this.maxCapacityKg,
    required this.avgMoisture,
    required this.batchCode,
    this.status = 'Töltés alatt',
  });
}

class ExtractionRecord {
  final DateTime timestamp;
  final String boxCode;
  final String hiveName;
  final String honeyType;
  final double grossKg;
  final double tareKg;
  final double moisture;
  final String cappingLook;
  final String consistency;
  final String tasteNotes;
  final String targetContainerId;

  ExtractionRecord({
    required this.timestamp,
    required this.boxCode,
    required this.hiveName,
    required this.honeyType,
    required this.grossKg,
    required this.tareKg,
    required this.moisture,
    required this.cappingLook,
    required this.consistency,
    required this.tasteNotes,
    required this.targetContainerId,
  });

  double get netKg => (grossKg - tareKg).clamp(0.0, 999.0);
}

class BottlingRecord {
  final DateTime timestamp;
  final String sourceContainerId;
  final String honeyType;
  final String jarSizeLabel;
  final double jarWeightKg;
  final int count;
  final String lotNumber;

  BottlingRecord({
    required this.timestamp,
    required this.sourceContainerId,
    required this.honeyType,
    required this.jarSizeLabel,
    required this.jarWeightKg,
    required this.count,
    required this.lotNumber,
  });

  double get totalKg => jarWeightKg * count;
}

class ProcessingRoomScreen extends StatefulWidget {
  final HiveRepository repository;

  const ProcessingRoomScreen({super.key, required this.repository});

  @override
  State<ProcessingRoomScreen> createState() => _ProcessingRoomScreenState();
}

class _ProcessingRoomScreenState extends State<ProcessingRoomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  BoxElement? _selectedBox;
  HiveData? _parentHive;

  final TextEditingController _boxCodeCtrl = TextEditingController();
  final TextEditingController _grossWeightCtrl = TextEditingController(
    text: '16.4',
  );
  final TextEditingController _tareWeightCtrl = TextEditingController(
    text: '4.2',
  );
  final TextEditingController _moistureCtrl = TextEditingController(
    text: '17.2',
  );
  final TextEditingController _tasteCtrl = TextEditingController();

  String _selectedHoneyType = 'Akácméz';
  String _selectedCappingLook = 'Száraz (fehér, légbuborékos)';
  double _cappingPercent = 90.0;
  String _selectedConsistency = 'Sűrűn folyó';
  String _selectedTasteProfile = 'Tiszta, fajtajelleges';
  String _selectedTargetContainerId = 'C_0000001';

  final List<String> _honeyTypes = [
    'Akácméz',
    'Repceméz',
    'Hársméz',
    'Napraforgóméz',
    'Vegyes virágméz',
    'Selyemfűméz',
    'Erdei méz (Édesharmat)',
  ];

  final List<String> _cappingOptions = [
    'Száraz (fehér, légbuborékos)',
    'Nedves (zsíros fényű, mézre tapadó)',
    'Vegyes fedelezés',
    'Részben fedetlen (friss hordás)',
  ];

  final List<String> _consistencyOptions = [
    'Sűrűn folyó',
    'Víztiszta, hígabb',
    'Enyhén opálos / szemcsésedő',
    'Krémes / finomkristályos',
    'Kocsonyás (tixotróp)',
  ];

  final List<String> _tasteOptions = [
    'Tiszta, fajtajelleges',
    'Enyhe, lágy zamatú',
    'Karakteres, fűszeres / mentolos',
    'Karamellás / malátás utóíz',
    'Idegen szag/íz (elkülönítendő)',
  ];

  final List<ExtractionRecord> _extractionHistory = [];

  final List<HoneyContainer> _containers = [
    HoneyContainer(
      id: 'C_0000001',
      type: '200L Hordó (300 kg)',
      honeyType: 'Akácméz',
      tareWeightKg: 18.5,
      currentNetWeightKg: 142.0,
      maxCapacityKg: 300.0,
      avgMoisture: 17.1,
      batchCode: 'LOT-2026-AKAC-01',
      status: 'Töltés alatt',
    ),
    HoneyContainer(
      id: 'C_0000002',
      type: '20L Vödör (28 kg)',
      honeyType: 'Repceméz',
      tareWeightKg: 1.1,
      currentNetWeightKg: 27.5,
      maxCapacityKg: 28.0,
      avgMoisture: 17.6,
      batchCode: 'LOT-2026-REP-01',
      status: 'Krémesítés',
    ),
  ];

  String _bottlingSourceId = 'C_0000001';
  String _selectedJarLabel = '1000 g (720 ml OMME üveg)';
  final TextEditingController _jarCountCtrl = TextEditingController(text: '24');
  final TextEditingController _lotCtrl = TextEditingController(
    text: 'LOT-2026-AKAC-01',
  );
  final List<BottlingRecord> _bottlingHistory = [];

  final Map<String, double> _jarSizes = {
    '1000 g (720 ml OMME üveg)': 1.0,
    '500 g (370 ml OMME üveg)': 0.5,
    '250 g (212 ml üveg)': 0.25,
    '120 g (Kóstoló / Maci)': 0.12,
    '400 g (Lépesméz tálca)': 0.4,
  };

  double _cleanWaxKg = 18.5;
  double _cappingWaxKg = 6.2;
  int _foundationSheetsDadant = 140;
  int _foundationSheetsHalf = 210;
  int _readyFramesDadant = 35;
  int _readyFramesHalf = 60;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _boxCodeCtrl.dispose();
    _grossWeightCtrl.dispose();
    _tareWeightCtrl.dispose();
    _moistureCtrl.dispose();
    _tasteCtrl.dispose();
    _jarCountCtrl.dispose();
    _lotCtrl.dispose();
    super.dispose();
  }

  void _searchBoxByCode(String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;

    BoxElement? foundBox;
    HiveData? foundHive;

    for (final hive in widget.repository.hives) {
      for (final box in hive.boxes) {
        if (box.code.toUpperCase() == clean ||
            box.secondaryCode?.toUpperCase() == clean) {
          foundBox = box;
          foundHive = hive;
          break;
        }
      }
      if (foundBox != null) break;
    }

    setState(() {
      _boxCodeCtrl.text = clean;
      _selectedBox =
          foundBox ??
          BoxElement(
            name: 'Méztér ($clean)',
            code: clean,
            type: 'honey',
            size: '1/2 dadant',
            status: 'green',
          );
      _parentHive = foundHive;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          foundHive != null
              ? 'Azonosítva: ${foundBox!.name} – Kaptár: ${foundHive.name}'
              : 'Kód betöltve ($clean) – Nem található aktív kaptáron.',
        ),
        backgroundColor: foundHive != null
            ? Colors.green.shade700
            : Colors.orange.shade800,
      ),
    );
  }

  void _simulateRaspberryPiScaleRead() {
    final String mockCode = 'B_0000014';
    _searchBoxByCode(mockCode);
    setState(() {
      _grossWeightCtrl.text = '17.8';
      _tareWeightCtrl.text = '4.2';
    });
  }

  void _saveExtraction() {
    final String code = _boxCodeCtrl.text.trim().isEmpty
        ? (_selectedBox?.code ?? 'B_ISMERETLEN')
        : _boxCodeCtrl.text.trim().toUpperCase();

    final double gross =
        double.tryParse(_grossWeightCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final double tare =
        double.tryParse(_tareWeightCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final double moisture =
        double.tryParse(_moistureCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final double net = (gross - tare).clamp(0.0, 999.0);

    if (net <= 0) return;

    final record = ExtractionRecord(
      timestamp: DateTime.now(),
      boxCode: code,
      hiveName: _parentHive?.name ?? 'Központi / Tartalék',
      honeyType: _selectedHoneyType,
      grossKg: gross,
      tareKg: tare,
      moisture: moisture,
      cappingLook: '$_selectedCappingLook (${_cappingPercent.round()}%)',
      consistency: _selectedConsistency,
      tasteNotes: _tasteCtrl.text.trim().isEmpty
          ? _selectedTasteProfile
          : '$_selectedTasteProfile – ${_tasteCtrl.text.trim()}',
      targetContainerId: _selectedTargetContainerId,
    );

    setState(() {
      _extractionHistory.insert(0, record);

      final containerIdx = _containers.indexWhere(
        (c) => c.id == _selectedTargetContainerId,
      );
      if (containerIdx != -1) {
        final c = _containers[containerIdx];
        final totalOldMoisture = c.currentNetWeightKg * c.avgMoisture;
        final newTotalWeight = c.currentNetWeightKg + net;
        if (newTotalWeight > 0) {
          c.avgMoisture = double.parse(
            ((totalOldMoisture + (net * moisture)) / newTotalWeight)
                .toStringAsFixed(1),
          );
        }
        c.currentNetWeightKg = double.parse(newTotalWeight.toStringAsFixed(1));
        c.honeyType = _selectedHoneyType;
      }

      _cappingWaxKg = double.parse(
        (_cappingWaxKg + (net * 0.015)).toStringAsFixed(2),
      );

      _selectedBox = null;
      _parentHive = null;
      _boxCodeCtrl.clear();
      _tasteCtrl.clear();
    });

    widget.repository.syncWithSupabase();
  }

  void _showAddContainerDialog() {
    final int nextNum = _containers.length + 1;
    final TextEditingController idCtrl = TextEditingController(
      text: 'C_${nextNum.toString().padLeft(7, '0')}',
    );
    final TextEditingController tareCtrl = TextEditingController(text: '1.1');
    final TextEditingController maxCapCtrl = TextEditingController(
      text: '28.0',
    );
    final TextEditingController batchCtrl = TextEditingController(
      text:
          'LOT-2026-${_selectedHoneyType.substring(0, 4).toUpperCase()}-0$nextNum',
    );
    String containerType = '20L Vödör (28 kg)';
    String honeyType = _selectedHoneyType;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141428),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.amberAccent, width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.inventory, color: Colors.amberAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Új Hordó / Vödör Felvétele',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idCtrl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tároló QR / Azonosító (C_...)',
                        labelStyle: const TextStyle(color: Colors.amber),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: containerType,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Tároló edény típusa',
                        labelStyle: const TextStyle(color: Colors.tealAccent),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '20L Vödör (28 kg)',
                          child: Text('20L Műanyag Vödör (max ~28 kg)'),
                        ),
                        DropdownMenuItem(
                          value: '50L Saválló Kanna (70 kg)',
                          child: Text('50L Saválló Kanna (max ~70 kg)'),
                        ),
                        DropdownMenuItem(
                          value: '200L Hordó (300 kg)',
                          child: Text('200L Acélhordó (max ~300 kg)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            containerType = val;
                            if (val.startsWith('20L')) {
                              tareCtrl.text = '1.1';
                              maxCapCtrl.text = '28.0';
                            } else if (val.startsWith('50L')) {
                              tareCtrl.text = '6.2';
                              maxCapCtrl.text = '70.0';
                            } else {
                              tareCtrl.text = '18.5';
                              maxCapCtrl.text = '300.0';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: honeyType,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Méz fajtája',
                        labelStyle: const TextStyle(color: Colors.tealAccent),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _honeyTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => honeyType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tareCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Tára (kg)',
                              labelStyle: const TextStyle(
                                color: Colors.white60,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maxCapCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Kapacitás (kg)',
                              labelStyle: const TextStyle(
                                color: Colors.white60,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: batchCtrl,
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        labelText: 'LOT / Tétel azonosító',
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mégse',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final newContainer = HoneyContainer(
                      id: idCtrl.text.trim().toUpperCase(),
                      type: containerType,
                      honeyType: honeyType,
                      tareWeightKg:
                          double.tryParse(tareCtrl.text.replaceAll(',', '.')) ??
                          1.1,
                      currentNetWeightKg: 0.0,
                      maxCapacityKg:
                          double.tryParse(
                            maxCapCtrl.text.replaceAll(',', '.'),
                          ) ??
                          28.0,
                      avgMoisture: 17.0,
                      batchCode: batchCtrl.text.trim(),
                      status: 'Töltés alatt',
                    );
                    setState(() {
                      _containers.add(newContainer);
                      _selectedTargetContainerId = newContainer.id;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Mentés',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _recordBottling() {
    final int count = int.tryParse(_jarCountCtrl.text.trim()) ?? 0;
    final double jarKg = _jarSizes[_selectedJarLabel] ?? 1.0;
    final double totalRequiredKg = count * jarKg;

    if (count <= 0) return;

    final containerIdx = _containers.indexWhere(
      (c) => c.id == _bottlingSourceId,
    );
    if (containerIdx == -1) return;

    final source = _containers[containerIdx];
    if (source.currentNetWeightKg < totalRequiredKg) return;

    setState(() {
      source.currentNetWeightKg = double.parse(
        (source.currentNetWeightKg - totalRequiredKg).toStringAsFixed(2),
      );
      if (source.currentNetWeightKg <= 0.1) {
        source.status = 'Üres';
      }

      _bottlingHistory.insert(
        0,
        BottlingRecord(
          timestamp: DateTime.now(),
          sourceContainerId: source.id,
          honeyType: source.honeyType,
          jarSizeLabel: _selectedJarLabel,
          jarWeightKg: jarKg,
          count: count,
          lotNumber: _lotCtrl.text.trim().isEmpty
              ? source.batchCode
              : _lotCtrl.text.trim(),
        ),
      );
    });
  }

  Widget _buildExtractionTab() {
    final double gross =
        double.tryParse(_grossWeightCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final double tare =
        double.tryParse(_tareWeightCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final double netWeight = (gross - tare).clamp(0.0, 999.0);
    final double moisture =
        double.tryParse(_moistureCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final bool isMoistureHigh = moisture > 18.0;

    final double totalExtractedToday = _extractionHistory.fold(
      0.0,
      (sum, item) => sum + item.netKg,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141428),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.tealAccent.withAlpha(80)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text(
                    'Kipergetett fiókok',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_extractionHistory.length} db',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 28, color: Colors.white12),
              Column(
                children: [
                  const Text(
                    'Összes nettó méz',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${totalExtractedToday.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141428),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withAlpha(90)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.scale, color: Colors.amberAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '1. Mérleg & Méztér Azonosítás',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.tealAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _simulateRaspberryPiScaleRead,
                    icon: const Icon(Icons.sensors, size: 16),
                    label: const Text(
                      'Mérleg olvasás',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _boxCodeCtrl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Méztéri fiók QR / NFC (pl. B_0000012)',
                        labelStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: _searchBoxByCode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF141428),
                          title: const Text(
                            'Méztér QR beolvasása',
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          content: SizedBox(
                            width: 280,
                            height: 280,
                            child: MobileScanner(
                              onDetect: (capture) {
                                final barcodes = capture.barcodes;
                                if (barcodes.isNotEmpty &&
                                    barcodes.first.rawValue != null) {
                                  Navigator.pop(ctx);
                                  _searchBoxByCode(barcodes.first.rawValue!);
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (_parentHive != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hive,
                        color: Colors.tealAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Termelő család: ${_parentHive!.name}',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _grossWeightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Bruttó (kg)',
                        labelStyle: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _tareWeightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tára (kg)',
                        labelStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.tealAccent),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'NETTÓ',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${netWeight.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141428),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.fact_check, color: Colors.tealAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '2. Minőségellenőrzés',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedHoneyType,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Méz fajtája',
                        labelStyle: const TextStyle(color: Colors.amber),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _honeyTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedHoneyType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _moistureCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: isMoistureHigh
                            ? Colors.redAccent
                            : Colors.tealAccent,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Víz (%)',
                        helperText: isMoistureHigh ? '>18.0%!' : '≤18%',
                        helperStyle: TextStyle(
                          color: isMoistureHigh
                              ? Colors.redAccent
                              : Colors.white54,
                          fontSize: 10,
                        ),
                        labelStyle: const TextStyle(color: Colors.amber),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCappingLook,
                dropdownColor: const Color(0xFF0F172A),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Fedelezés kinézete',
                  labelStyle: const TextStyle(color: Colors.amber),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _cappingOptions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCappingLook = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedTargetContainerId,
                dropdownColor: const Color(0xFF0F172A),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Cél tároló (Hordó / Vödör)',
                  labelStyle: const TextStyle(color: Colors.amberAccent),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _containers.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.id} – ${c.honeyType} (${c.currentNetWeightKg}/${c.maxCapacityKg} kg)',
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedTargetContainerId = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _saveExtraction,
                  icon: const Icon(Icons.save_alt),
                  label: Text(
                    'Pergetés Rögzítése (+${netWeight.toStringAsFixed(1)} kg)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContainersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _showAddContainerDialog,
            icon: const Icon(Icons.add_box),
            label: const Text(
              'Új Hordó / Vödör Regisztrálása',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._containers.map((c) {
          final double fillRatio = (c.currentNetWeightKg / c.maxCapacityKg)
              .clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF141428),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.oil_barrel,
                          color: Colors.amberAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${c.id} – ${c.honeyType}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    DropdownButton<String>(
                      value: c.status,
                      dropdownColor: const Color(0xFF0F172A),
                      underline: const SizedBox(),
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Töltés alatt',
                          child: Text('Töltés alatt'),
                        ),
                        DropdownMenuItem(
                          value: 'Ülepítés',
                          child: Text('Ülepítés'),
                        ),
                        DropdownMenuItem(
                          value: 'Krémesítés',
                          child: Text('Krémesítés'),
                        ),
                        DropdownMenuItem(
                          value: 'Raktáron',
                          child: Text('Raktáron'),
                        ),
                        DropdownMenuItem(value: 'Üres', child: Text('Üres')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => c.status = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${c.type} • LOT: ${c.batchCode} • Átl. víz: ${c.avgMoisture}%',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fillRatio,
                    minHeight: 10,
                    backgroundColor: const Color(0xFF0F172A),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      fillRatio > 0.9 ? Colors.amberAccent : Colors.tealAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nettó méz: ${c.currentNetWeightKg.toStringAsFixed(1)} / ${c.maxCapacityKg.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBottlingTab() {
    final int count = int.tryParse(_jarCountCtrl.text.trim()) ?? 0;
    final double jarKg = _jarSizes[_selectedJarLabel] ?? 1.0;
    final double totalKg = count * jarKg;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141428),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.storefront, color: Colors.amberAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Üvegezés & Kiszerelés Indítása',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _bottlingSourceId,
                dropdownColor: const Color(0xFF0F172A),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Forrás hordó / vödör',
                  labelStyle: const TextStyle(color: Colors.tealAccent),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _containers.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.id} – ${c.honeyType} (${c.currentNetWeightKg} kg)',
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final found = _containers.firstWhere((c) => c.id == val);
                    setState(() {
                      _bottlingSourceId = val;
                      _lotCtrl.text = found.batchCode;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedJarLabel,
                dropdownColor: const Color(0xFF0F172A),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Üveg mérete',
                  labelStyle: const TextStyle(color: Colors.tealAccent),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _jarSizes.keys
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedJarLabel = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _jarCountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Darabszám (üveg)',
                  labelStyle: const TextStyle(color: Colors.amber),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _recordBottling,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    'Kiszerelés Levonása (${totalKg.toStringAsFixed(1)} kg)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaxAndFramesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141428),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.hexagon, color: Colors.amberAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Viaszműhely & Olvasztás',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Tisztított Viasz',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_cleanWaxKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Fedelezési Viasz',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_cappingWaxKg.toStringAsFixed(2)} kg',
                            style: const TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        foregroundColor: Colors.amberAccent,
        title: const Row(
          children: [
            Icon(Icons.factory, color: Colors.amberAccent, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Feldolgozóhelyiség',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.scale, size: 18), text: 'Pergetés & Mérleg'),
            Tab(
              icon: Icon(Icons.oil_barrel, size: 18),
              text: 'Hordók & Vödrök',
            ),
            Tab(icon: Icon(Icons.storefront, size: 18), text: 'Üvegezés'),
            Tab(icon: Icon(Icons.grid_on, size: 18), text: 'Műlépezés & Viasz'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildExtractionTab(),
            _buildContainersTab(),
            _buildBottlingTab(),
            _buildWaxAndFramesTab(),
          ],
        ),
      ),
    );
  }
}
