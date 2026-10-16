import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../hive_model.dart';
import '../services/location_compass_service.dart';

class HiveConfigDialog extends StatefulWidget {
  final HiveData hive;
  final Function(HiveData updatedHive) onSaved;

  const HiveConfigDialog({
    super.key,
    required this.hive,
    required this.onSaved,
  });

  @override
  State<HiveConfigDialog> createState() => _HiveConfigDialogState();
}

class _HiveConfigDialogState extends State<HiveConfigDialog> {
  late String _selectedFunction;
  late List<BoxElement> _editableBoxes;
  late bool _queenNeedsReplacement;
  late LatLng _currentHiveLocation;

  final LocationCompassService _locationService = LocationCompassService();
  bool _isMeasuringGps = false;
  String _gpsStatusText = '';

  static const List<String> _validFunctions = [
    'gyujto_mez',
    'gyujto_propolisz',
    'gyujto_viragpor',
    'gyujto_mehmereg',
    'szaporitas_donor',
    'szaporitas_starter',
    'szaporitas_anya',
    'szaporitas_apa',
    'kiselejtezendo',
    'hans',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFunction = _validFunctions.contains(widget.hive.familyFunction)
        ? widget.hive.familyFunction
        : 'gyujto_mez';

    _queenNeedsReplacement = widget.hive.queen?.needsReplacement ?? false;
    _currentHiveLocation = widget.hive.location;

    _editableBoxes = widget.hive.boxes
        .map(
          (b) => BoxElement(
            name: b.name,
            code: b.code,
            secondaryCode: b.secondaryCode,
            type: b.type,
            size: b.size,
            status: b.status,
          ),
        )
        .toList();

    _ensureNestAtBottom();
  }

  void _ensureNestAtBottom() {
    _editableBoxes.removeWhere((b) => b.type == 'nest');
    final nestSize =
        widget.hive.boxes.where((b) => b.type == 'nest').firstOrNull?.size ??
        'dadant';
    final nestCode =
        widget.hive.boxes.where((b) => b.type == 'nest').firstOrNull?.code ??
        'BOX_NEST';
    final nestSec = widget.hive.boxes
        .where((b) => b.type == 'nest')
        .firstOrNull
        ?.secondaryCode;

    _editableBoxes.insert(
      0,
      BoxElement(
        name: 'Fészek',
        code: nestCode,
        secondaryCode: nestSec,
        type: 'nest',
        size: nestSize,
        status: 'green',
      ),
    );
  }

  void _startGpsCalibration() async {
    setState(() {
      _isMeasuringGps = true;
      _gpsStatusText = 'GPS vevő indítása... Tedd a telefont a tetőre! 📱🐝';
    });

    for (int i = 0; i < 5; i++) {
      await _locationService.updatePosition();
      final acc = _locationService.accuracy ?? 99.0;
      setState(() {
        _gpsStatusText =
            'Mérés ${i + 1}/5 (Pontosság: ${acc.toStringAsFixed(1)}m)...';
      });
      await Future.delayed(const Duration(milliseconds: 800));
    }

    setState(() {
      _currentHiveLocation = _locationService.currentPosition;
      _isMeasuringGps = false;
      _gpsStatusText =
          '✅ Pozíció rögzítve: ${_currentHiveLocation.latitude.toStringAsFixed(5)}, ${_currentHiveLocation.longitude.toStringAsFixed(5)}';
    });
  }

  String get _nestSize {
    final nest = _editableBoxes.where((b) => b.type == 'nest').firstOrNull;
    if (nest != null && (nest.size == 'dadant' || nest.size == 'nb')) {
      return nest.size;
    }
    return 'dadant';
  }

  // --- KATEGÓRIÁS FUNKCIÓ VÁLASZTÓ ---
  void _showFunctionCategorySelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            '🎯 Család funkciójának kiválasztása',
            style: TextStyle(color: Colors.amberAccent, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBigCategoryButton(
                context,
                title: '🍯 Gyűjtő család',
                subtitle: 'Méz, virágpor, propolisz, méhméreg',
                color: Colors.amber,
                onTap: () {
                  Navigator.pop(context);
                  _showSubMenuGyujto(context);
                },
              ),
              const SizedBox(height: 12),
              _buildBigCategoryButton(
                context,
                title: '🌱 Szaporítás',
                subtitle: 'Donor, starter, anya, hernevelő apa',
                color: Colors.lightGreenAccent,
                onTap: () {
                  Navigator.pop(context);
                  _showSubMenuSzaporitas(context);
                },
              ),
              const SizedBox(height: 12),
              _buildBigCategoryButton(
                context,
                title: '⚠️ Megszüntetés & Karantén',
                subtitle: 'Felszámolás / Kiselejtezés, Hans-mód',
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _showSubMenuMegszuntetes(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBigCategoryButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withAlpha(180), width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubMenuGyujto(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            '🍯 Gyűjtő család almenü',
            style: TextStyle(color: Colors.amber, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSubMenuButton(
                context,
                'Méz gyűjtő',
                'gyujto_mez',
                Colors.amber,
              ),
              const SizedBox(height: 10),
              _buildSubMenuButton(
                context,
                'Virágpor gyűjtő',
                'gyujto_viragpor',
                Colors.amber,
              ),
              const SizedBox(height: 10),
              _buildSubMenuButton(
                context,
                'Propolisz gyűjtő',
                'gyujto_propolisz',
                Colors.amber,
              ),
              const SizedBox(height: 10),
              _buildSubMenuButton(
                context,
                'Méhméreg gyűjtő',
                'gyujto_mehmereg',
                Colors.amber,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubMenuSzaporitas(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            '🌱 Szaporítási almenü',
            style: TextStyle(color: Colors.lightGreenAccent, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSubMenuButton(
                context,
                'Donor család',
                'szaporitas_donor',
                Colors.lightGreenAccent,
              ),
              const SizedBox(height: 10),
              _buildSubMenuButton(
                context,
                'Starter család',
                'szaporitas_starter',
                Colors.lightGreenAccent,
              ),
              const SizedBox(height: 10),
              _buildSubMenuButton(
                context,
                'Anya család',
                'szaporitas_anya',
                Colors.lightGreenAccent,
              ),
              const SizedBox(height: 10),
              _buildSubMenuButton(
                context,
                'Apa család (hernevelő)',
                'szaporitas_apa',
                Colors.lightGreenAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubMenuMegszuntetes(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            '⚠️ Megszüntetés & Karantén',
            style: TextStyle(color: Colors.redAccent, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSubMenuButton(
                context,
                'Felszámolás / Kiselejtezendő',
                'kiselejtezendo',
                Colors.redAccent,
              ),
              const SizedBox(height: 10),
              _buildSubMenuButton(
                context,
                '🔥 Hans Protokoll (Karantén)',
                'hans',
                Colors.redAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubMenuButton(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    bool isSelected = (_selectedFunction == value);
    return Material(
      color: isSelected ? color.withAlpha(40) : const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          setState(() => _selectedFunction = value);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : color.withAlpha(100),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  String _getFunctionName(String func) {
    switch (func) {
      case 'gyujto_mez':
        return '🍯 Gyűjtő - Méz';
      case 'gyujto_propolisz':
        return '🍯 Gyűjtő - Propolisz';
      case 'gyujto_viragpor':
        return '🍯 Gyűjtő - Virágpor';
      case 'gyujto_mehmereg':
        return '🍯 Gyűjtő - Méhméreg';
      case 'szaporitas_donor':
        return '🌱 Szaporítás - Donor';
      case 'szaporitas_starter':
        return '🌱 Szaporítás - Starter';
      case 'szaporitas_anya':
        return '🌱 Szaporítás - Anya család';
      case 'szaporitas_apa':
        return '🌱 Szaporítás - Apa (hernevelő)';
      case 'kiselejtezendo':
        return '⚠️ Felszámolás / Kiselejtezendő';
      case 'hans':
        return '🔥 Hans Protokoll (Karantén)';
      default:
        return func;
    }
  }

  void _showSequentialScanWizard(BuildContext context) {
    List<BoxElement> tempScannedBoxes = [];
    int step = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String scannedCode =
                'BOX_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
            String selectedType = step == 1 ? 'pollen_trap' : 'honey';
            String boxName = step == 1 ? 'Pollengyűjtő' : 'Méztér';

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(
                '🔄 Sorozatos beolvasás (Lépés: $step)',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step == 1
                          ? '1. Lépés: Olvassa be a legalsó elemet (pl. Pollengyűjtő vagy Aljközeliek):'
                          : '$step. Lépés: Olvassa be a következő elemet felfelé haladva:',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                            ),
                            controller: TextEditingController(
                              text: scannedCode,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Elem azonosító (QR / Kód)',
                              labelStyle: TextStyle(color: Colors.amber),
                            ),
                            onChanged: (val) => scannedCode = val,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildBigScanButton(
                          icon: Icons.qr_code_scanner,
                          color: Colors.amberAccent,
                          tooltip: 'QR beolvasás',
                          onTap: () {
                            setDialogState(() {
                              scannedCode =
                                  'BOX_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

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
                          value: 'pollen_trap',
                          child: Text('Pollengyűjtő'),
                        ),
                        DropdownMenuItem(value: 'honey', child: Text('Méztér')),
                        DropdownMenuItem(value: 'feeder', child: Text('Etető')),
                        DropdownMenuItem(
                          value: 'escapement',
                          child: Text('Szöktető'),
                        ),
                        DropdownMenuItem(
                          value: 'vent',
                          child: Text('Szellőző'),
                        ),
                        DropdownMenuItem(value: 'roof', child: Text('Tető')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedType = val;
                            boxName = val == 'pollen_trap'
                                ? 'Pollengyűjtő'
                                : (val == 'honey' ? 'Méztér' : 'Tartozék');
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Eddig felvett elemek: ${tempScannedBoxes.length} db',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Bezárás',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final newBox = BoxElement(
                      name: boxName,
                      code: scannedCode,
                      type: selectedType,
                      size: selectedType == 'honey'
                          ? 'fel_dadant'
                          : selectedType,
                      status: 'green',
                    );
                    setDialogState(() {
                      tempScannedBoxes.add(newBox);
                      step++;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Rögzítve: $boxName ($scannedCode). Jöhet a következő!',
                        ),
                        duration: const Duration(milliseconds: 800),
                      ),
                    );
                  },
                  child: const Text('Következő elem ->'),
                ),
                if (tempScannedBoxes.isNotEmpty)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        for (var box in tempScannedBoxes) {
                          if (box.type == 'pollen_trap') {
                            _editableBoxes.insert(1, box);
                          } else {
                            _editableBoxes.add(box);
                          }
                        }
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Torony sorozat sikeresen mentve!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: const Text('Kész / Mentés'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddBoxWizard(BuildContext context) {
    String scannedCode =
        'BOX_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    String? secondaryNfcCode;
    String selectedType = 'honey';
    String selectedSize = _nestSize == 'nb' ? 'hunor' : 'fel_dadant';
    String boxName = 'Méztér';

    final qrController = TextEditingController(text: scannedCode);
    final nfcController = TextEditingController(text: secondaryNfcCode ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                '➕ Új elem beolvasása & Hozzáadása',
                style: TextStyle(color: Colors.amberAccent, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Olvassa be a fizikai fiókot (QR vagy NFC), vagy írja be a kódot:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                            ),
                            controller: qrController,
                            decoration: const InputDecoration(
                              labelText: 'Fiók QR azonosító',
                              labelStyle: TextStyle(color: Colors.amber),
                            ),
                            onChanged: (val) => scannedCode = val,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildBigScanButton(
                          icon: Icons.qr_code_scanner,
                          color: Colors.amberAccent,
                          tooltip: 'QR-kód beolvasása',
                          onTap: () {
                            setDialogState(() {
                              scannedCode =
                                  'BOX_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                              qrController.text = scannedCode;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            controller: nfcController,
                            decoration: const InputDecoration(
                              labelText: 'Másodlagos NFC azonosító',
                              labelStyle: TextStyle(color: Colors.amber),
                            ),
                            onChanged: (val) => secondaryNfcCode = val,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildBigScanButton(
                          icon: Icons.nfc,
                          color: Colors.lightGreenAccent,
                          tooltip: 'NFC tag olvasása',
                          onTap: () {
                            setDialogState(() {
                              secondaryNfcCode =
                                  'NFC_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                              nfcController.text = secondaryNfcCode!;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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
                        DropdownMenuItem(value: 'honey', child: Text('Méztér')),
                        DropdownMenuItem(value: 'feeder', child: Text('Etető')),
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
                            boxName = val == 'honey'
                                ? 'Méztér'
                                : (val == 'feeder' ? 'Etető' : 'Tartozék');
                          });
                        }
                      },
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
                    final newBox = BoxElement(
                      name: boxName,
                      code: scannedCode,
                      secondaryCode: secondaryNfcCode,
                      type: selectedType,
                      size: selectedSize,
                      status: 'green',
                    );

                    setState(() {
                      if (selectedType == 'pollen_trap') {
                        _editableBoxes.insert(1, newBox);
                      } else {
                        _editableBoxes.add(newBox);
                      }
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fiók sikeresen hozzáadva a toronyhoz!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Hozzáadás'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBigScanButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(180), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }

  void _moveBox(int index, int direction) {
    setState(() {
      int newIndex = index + direction;
      if (newIndex <= 0 || newIndex >= _editableBoxes.length) return;

      final item = _editableBoxes.removeAt(index);
      _editableBoxes.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayEntries = _editableBoxes
        .asMap()
        .entries
        .toList()
        .reversed
        .toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        'Kaptár torony & Konfiguráció\n(${widget.hive.id})',
        style: const TextStyle(color: Colors.amberAccent, fontSize: 18),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Család funkciója:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              InkWell(
                onTap: () => _showFunctionCategorySelector(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.category,
                            color: Colors.amberAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _getFunctionName(_selectedFunction),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.amberAccent,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amber),
                ),
                onPressed: _isMeasuringGps ? null : _startGpsCalibration,
                icon: _isMeasuringGps
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.amber,
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _isMeasuringGps
                      ? 'GPS bemérés a tetőn...'
                      : 'GPS bemérés a kaptár tetejéről',
                ),
              ),
              if (_gpsStatusText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _gpsStatusText,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                  ),
                ),
              ],

              if (widget.hive.queen != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Anyacsere esedékes (villogó jelzés)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  activeColor: Colors.amber,
                  value: _queenNeedsReplacement,
                  onChanged: (val) =>
                      setState(() => _queenNeedsReplacement = val),
                ),
              ],

              const Divider(color: Colors.grey, height: 24),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _showAddBoxWizard(context),
                      icon: const Icon(Icons.add_box, size: 20),
                      label: const Text(
                        'Egyesével (+)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _showSequentialScanWizard(context),
                      icon: const Icon(Icons.playlist_add, size: 20),
                      label: const Text(
                        'Sorozat (Lent->Fent)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(color: Colors.grey, height: 24),
              const Text(
                '↕️ Fiókok sorrendje (Nyilakkal állítható):',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayEntries.length,
                itemBuilder: (context, index) {
                  int realIndex = displayEntries[index].key;
                  BoxElement box = displayEntries[index].value;
                  bool isNest = (box.type == 'nest');

                  return Container(
                    key: ValueKey(box.code),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isNest
                          ? Colors.green.shade900.withAlpha(50)
                          : const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isNest
                            ? Colors.greenAccent
                            : Colors.grey.shade700,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!isNest)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _moveBox(realIndex, 1),
                                child: const Icon(
                                  Icons.arrow_drop_up,
                                  color: Colors.amberAccent,
                                  size: 28,
                                ),
                              ),
                              InkWell(
                                onTap: () => _moveBox(realIndex, -1),
                                child: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.amberAccent,
                                  size: 28,
                                ),
                              ),
                            ],
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.home, color: Colors.greenAccent),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isNest
                                    ? 'Fészek (Alul - Fix)'
                                    : '${box.name} (${box.code})',
                                style: TextStyle(
                                  color: isNest
                                      ? Colors.greenAccent
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (box.secondaryCode != null &&
                                  box.secondaryCode!.isNotEmpty)
                                Text(
                                  'NFC: ${box.secondaryCode}',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              if (box.type == 'pollen_trap') ...[
                                const SizedBox(height: 4),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Pollengyűjtő bekapcsolva',
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                  activeColor: Colors.orange,
                                  value:
                                      box.status == 'green' ||
                                      box.status == 'yellow',
                                  onChanged: (val) {
                                    setState(() {
                                      box.status = val ? 'green' : 'grey';
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isNest)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_forever,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                            tooltip: 'Fiók eltávolítása',
                            onPressed: () {
                              setState(() {
                                _editableBoxes.removeAt(realIndex);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mégse', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            widget.hive.familyFunction = _selectedFunction;
            widget.hive.boxes = _editableBoxes;
            widget.hive.location = _currentHiveLocation;
            if (widget.hive.queen != null) {
              widget.hive.queen!.needsReplacement = _queenNeedsReplacement;
            }
            if (_selectedFunction == 'hans') {
              widget.hive.protocol = 'hans';
              widget.hive.status = 'flashing_red';
            } else {
              widget.hive.protocol = null;
              if (widget.hive.status == 'flashing_red') {
                widget.hive.status = 'green';
              }
            }
            widget.onSaved(widget.hive);
            Navigator.pop(context);
          },
          child: const Text('Mentés'),
        ),
      ],
    );
  }
}
