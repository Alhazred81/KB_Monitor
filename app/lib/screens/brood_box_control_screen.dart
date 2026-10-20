import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../widgets/hive_config_dialog.dart';

class BroodBoxControlScreen extends StatefulWidget {
  final HiveData hive;
  final BoxElement broodBox;

  const BroodBoxControlScreen({
    super.key,
    required this.hive,
    required this.broodBox,
  });

  @override
  State<BroodBoxControlScreen> createState() => _BroodBoxControlScreenState();
}

class _BroodBoxControlScreenState extends State<BroodBoxControlScreen> {
  final HiveRepository _repository = HiveRepository.instance;

  bool _hasHoneySuper() {
    return widget.hive.boxes.any((b) => b.type == 'honey');
  }

  void _confirmTreatmentAction(
    BuildContext context,
    String actionTitle,
    VoidCallback onConfirmed,
  ) {
    if (_hasHoneySuper()) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 28,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Figyelem: Méztér található!',
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            'A(z) "${widget.hive.name}" tornyán méztér (is) fel van helyezve.\n\nBiztosan el akarod végezni a(z) "$actionTitle" gyógykezelést? Fennáll a méz szennyeződésének veszélye!',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                onConfirmed();
              },
              child: const Text('Mégis elvégzem'),
            ),
          ],
        ),
      );
    } else {
      onConfirmed();
    }
  }

  void _updateHiveStatus(String newStatus) {
    setState(() {
      widget.hive.status = newStatus;
    });
    _repository.updateHive(widget.hive);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Család státusza frissítve: $newStatus'),
        backgroundColor: Colors.amber,
      ),
    );
  }

  void _startTowerScanWizard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TowerScanScreen(
          hive: widget.hive,
          broodBox: widget.broodBox,
          repository: _repository,
        ),
      ),
    );
  }

  void _showSensorsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SensorsScreen(hive: widget.hive),
      ),
    );
  }

  void _showConfigOptionsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ConfigOptionsScreen(
          hive: widget.hive,
          onScanTower: () => _startTowerScanWizard(context),
        ),
      ),
    );
  }

  void _showInvestigationsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _InvestigationsScreen(hive: widget.hive, repository: _repository),
      ),
    );
  }

  void _showTreatmentsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TreatmentsScreen(
          hive: widget.hive,
          repository: _repository,
          confirmAction: _confirmTreatmentAction,
        ),
      ),
    );
  }

  void _showMasterPlansScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _FamilyFunctionScreen(hive: widget.hive, repository: _repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.amberAccent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.hive.name} – Fészekfiók',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Kód: ${widget.broodBox.code} (${widget.broodBox.size.toUpperCase()})',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Család státusza (színkód):',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatusButton('Zöld', 'green', Colors.green),
                      _buildStatusButton(
                        'Sárga',
                        'yellow',
                        Colors.amber.shade700,
                      ),
                      _buildStatusButton('Narancs', 'orange', Colors.orange),
                      _buildStatusButton('Lila', 'purple', Colors.purpleAccent),
                      _buildStatusButton('Piros', 'red', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Válassz funkciót (Boxkesztyű-barát vezérlés):',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildBigIconButton(
                      icon: Icons.sensors,
                      color: Colors.tealAccent,
                      label: 'Szenzorok',
                      onPressed: () => _showSensorsScreen(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBigIconButton(
                      icon: Icons.tune,
                      color: Colors.amberAccent,
                      label: 'Konfiguráció',
                      onPressed: () => _showConfigOptionsScreen(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildBigIconButton(
                      icon: Icons.camera_alt,
                      color: Colors.lightBlueAccent,
                      label: 'Vizsgálatok',
                      onPressed: () => _showInvestigationsScreen(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBigIconButton(
                      icon: Icons.medical_services,
                      color: Colors.orangeAccent,
                      label: 'Kezelések',
                      onPressed: () => _showTreatmentsScreen(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amber, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () => _showMasterPlansScreen(context),
                icon: const Icon(Icons.work_outline, size: 32),
                label: const Text(
                  'Család funkció & Mestertervek',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String label, String statusKey, Color color) {
    bool isSelected = widget.hive.status == statusKey;
    return InkWell(
      onTap: () => _updateHiveStatus(statusKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withAlpha(50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: isSelected ? 2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBigIconButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(120), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EGYSÉGESÍTETT, TELJES KÉPERNYŐS IKONOS ALMENÜK (Boxkesztyű-barát rácsok)
// ============================================================================

class _SensorsScreen extends StatelessWidget {
  final HiveData hive;
  const _SensorsScreen({required this.hive});

  @override
  Widget build(BuildContext context) {
    final sensors = [
      {
        'label': 'Belső Hőmérséklet',
        'value': '${hive.temp.toStringAsFixed(1)} °C',
        'icon': Icons.thermostat,
        'color': Colors.amber,
      },
      {
        'label': 'Páratartalom',
        'value': '${hive.humidity.toStringAsFixed(1)} %',
        'icon': Icons.water_drop,
        'color': Colors.lightBlueAccent,
      },
      {
        'label': 'Akusztika (ZCR)',
        'value': '${hive.zcr.toStringAsFixed(0)} Hz',
        'icon': Icons.mic,
        'color': Colors.purpleAccent,
      },
      {
        'label': 'Kaptármérleg',
        'value': '${hive.weight.toStringAsFixed(1)} kg',
        'icon': Icons.scale,
        'color': Colors.greenAccent,
      },
      {
        'label': 'Akkumulátor',
        'value': '${hive.batteryVoltage.toStringAsFixed(2)} V',
        'icon': Icons.battery_full,
        'color': Colors.tealAccent,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.amberAccent,
        title: const Text(
          'Fészek Szenzor Adatok',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: sensors.length,
                itemBuilder: (context, index) {
                  final s = sensors[index];
                  final Color c = s['color'] as Color;
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: c.withAlpha(120), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(s['icon'] as IconData, size: 40, color: c),
                        const SizedBox(height: 12),
                        Text(
                          s['label'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s['value'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigOptionsScreen extends StatelessWidget {
  final HiveData hive;
  final VoidCallback onScanTower;

  const _ConfigOptionsScreen({required this.hive, required this.onScanTower});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.amberAccent,
        title: const Text(
          'Konfiguráció',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildTile(
                      context,
                      icon: Icons.edit,
                      color: Colors.tealAccent,
                      label: 'Kézi Bevitel\n(Torony szerkesztése)',
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (dialogCtx) =>
                              HiveConfigDialog(selectedHive: hive),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTile(
                      context,
                      icon: Icons.qr_code_scanner,
                      color: Colors.amberAccent,
                      label: 'Torony beolvasása\nlentről felfelé',
                      onPressed: () {
                        Navigator.pop(context);
                        onScanTower();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(120), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestigationsScreen extends StatefulWidget {
  final HiveData hive;
  final HiveRepository repository;

  const _InvestigationsScreen({required this.hive, required this.repository});

  @override
  State<_InvestigationsScreen> createState() => _InvestigationsScreenState();
}

class _InvestigationsScreenState extends State<_InvestigationsScreen> {
  bool _isCameraActive = false;
  final bool _pullOutBoard = true;

  void _saveVarroaResult(int mites, int days) {
    widget.repository.addVarroaAnalysis(
      hive: widget.hive,
      record: VarroaAnalysisRecord(
        id: 'VAR_${DateTime.now().millisecondsSinceEpoch}',
        hiveId: widget.hive.id,
        capturedAt: DateTime.now(),
        localImagePath: '',
        miteCount: mites,
        daysInserted: days > 0 ? days : 1,
      ),
      pullOutBoard: _pullOutBoard,
    );
    setState(() => _isCameraActive = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Varroa vizsgálat rögzítve.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.amberAccent,
        title: const Text(
          'Vizsgálatok',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isCameraActive
          ? Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      _saveVarroaResult(4, 3);
                    }
                  },
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Keresd a fészekkeretet vagy tálcát...',
                          style: TextStyle(
                            color: Colors.white,
                            backgroundColor: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _isCameraActive = false),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 32,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        SizedBox(
                          height: 140,
                          child: _buildTile(
                            context,
                            icon: Icons.bug_report,
                            color: Colors.deepOrangeAccent,
                            label: 'Kamerás Varroa Vizsgálat',
                            onPressed: () =>
                                setState(() => _isCameraActive = true),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 140,
                          child: _buildTile(
                            context,
                            icon: Icons.grid_on,
                            color: Colors.lightBlueAccent,
                            label: 'Kamerás Fészek Vizsgálat',
                            onPressed: () =>
                                setState(() => _isCameraActive = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(120), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42, color: color),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TreatmentsScreen extends StatelessWidget {
  final HiveData hive;
  final HiveRepository repository;
  final Function(BuildContext, String, VoidCallback) confirmAction;

  const _TreatmentsScreen({
    required this.hive,
    required this.repository,
    required this.confirmAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.amberAccent,
        title: const Text(
          'Kezelések & Beavatkozások',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildTile(
                    context,
                    icon: Icons.layers,
                    color: Colors.brown.shade300,
                    label: 'Tartós hordozó',
                    onPressed: () {
                      confirmAction(context, 'Tartós hordozó', () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tartós hordozós kezelés naplózva.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      });
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.warning_amber,
                    color: Colors.redAccent,
                    label: 'Hangyasavazás',
                    onPressed: () {
                      confirmAction(context, 'Hangyasavazás', () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hangyasavas kezelés naplózva.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      });
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.science,
                    color: Colors.orangeAccent,
                    label: 'Oxálsavas\nKezelések',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => _OxalicScreen(
                            hive: hive,
                            repository: repository,
                            confirmAction: confirmAction,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.restaurant,
                    color: Colors.tealAccent,
                    label: 'Etetés Almenü',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => _FeedingScreen(
                            hive: hive,
                            repository: repository,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(120), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42, color: color),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _OxalicScreen extends StatelessWidget {
  final HiveData hive;
  final HiveRepository repository;
  final Function(BuildContext, String, VoidCallback) confirmAction;

  const _OxalicScreen({
    required this.hive,
    required this.repository,
    required this.confirmAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.amberAccent,
        title: const Text(
          'Oxálsavas Kezelések',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildTile(
                    context,
                    icon: Icons.flash_on,
                    color: Colors.orange,
                    label: 'Egyszeri\nszublimálás',
                    onPressed: () {
                      confirmAction(context, 'Egyszeri szublimálás', () {
                        repository.schedulePlanForHive(
                          hive.id,
                          'oxalsav_egyszeri',
                          DateTime.now(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Egyszeri szublimálás naplózva.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      });
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.repeat,
                    color: Colors.amberAccent,
                    label: 'Sorozat-\nszublimálás',
                    onPressed: () {
                      confirmAction(context, 'Sorozatszublimálás', () {
                        repository.schedulePlanForHive(
                          hive.id,
                          'oxalsav_sorozat',
                          DateTime.now(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sorozatszublimálás ütemezve.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      });
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.layers,
                    color: Colors.brown.shade300,
                    label: 'Tartós hordozó',
                    onPressed: () {
                      confirmAction(context, 'Tartós hordozó', () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tartós hordozós oxálsav naplózva.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      });
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.water_drop,
                    color: Colors.tealAccent,
                    label: 'Csurgatás',
                    onPressed: () {
                      confirmAction(context, 'Csurgatás', () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Oxálsavas csurgatás naplózva.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(120), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42, color: color),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedingScreen extends StatelessWidget {
  final HiveData hive;
  final HiveRepository repository;

  const _FeedingScreen({required this.hive, required this.repository});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.amberAccent,
        title: const Text(
          'Etetés Almenü',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildTile(
                    context,
                    icon: Icons.water_drop,
                    color: Colors.tealAccent,
                    label: 'Szirup\n(+1 L)',
                    onPressed: () {
                      repository.pumpSyrup(
                        repository.syrupPump,
                        1.0,
                        hive.name,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('1 liter szirup etetés naplózva.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.cookie,
                    color: Colors.amber,
                    label: 'Cukorlepény',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cukorlepény etetés naplózva.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.egg,
                    color: Colors.amber.shade300,
                    label: 'Fehérjés lepény',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fehérjés lepény etetés naplózva.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.medical_services,
                    color: Colors.deepOrangeAccent,
                    label: 'Gyógyszeres lepény',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gyógyszeres lepény etetés naplózva.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(120), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42, color: color),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TELJES KÉPERNYŐS CSALÁD FUNKCIÓ & MESTERTERV NÉZET (Kesztyűbarát rácsok)
// ============================================================================
class _FamilyFunctionScreen extends StatefulWidget {
  final HiveData hive;
  final HiveRepository repository;

  const _FamilyFunctionScreen({required this.hive, required this.repository});

  @override
  State<_FamilyFunctionScreen> createState() => _FamilyFunctionScreenState();
}

class _FamilyFunctionScreenState extends State<_FamilyFunctionScreen> {
  String _selectedCategory = 'Gyűjtő';
  String _selectedSubFunction = 'méz';
  String _selectedPlanType = 'petes_mesterterv';

  bool get _isBreedingCategory => _selectedCategory == 'Tenyész';

  List<Map<String, dynamic>> _getSubFunctions() {
    if (_selectedCategory == 'Gyűjtő') {
      return [
        {
          'id': 'méz',
          'label': 'Méz',
          'icon': Icons.breakfast_dining,
          'plan': 'petes_mesterterv',
        },
        {
          'id': 'pollen',
          'label': 'Pollen',
          'icon': Icons.spa,
          'plan': 'alcas_mesterterv',
        },
        {
          'id': 'propolisz',
          'label': 'Propolisz',
          'icon': Icons.texture,
          'plan': 'hereskeret',
        },
        {
          'id': 'méhméreg',
          'label': 'Méhméreg',
          'icon': Icons.dangerous,
          'plan': 'grumpy_cat',
        },
      ];
    } else if (_selectedCategory == 'Tenyész') {
      return [
        {
          'id': 'dajka',
          'label': 'Dajka',
          'icon': Icons.child_care,
          'plan': 'anyanevelesi_mesterterv',
        },
        {
          'id': 'donor',
          'label': 'Donor',
          'icon': Icons.group,
          'plan': 'petes_mesterterv',
        },
        {
          'id': 'starter',
          'label': 'Starter',
          'icon': Icons.bolt,
          'plan': 'alcas_mesterterv',
        },
        {
          'id': 'anya',
          'label': 'Anya',
          'icon': Icons.workspace_premium,
          'plan': 'oxalsav_sorozat',
        },
        {'id': 'apa', 'label': 'Apa', 'icon': Icons.male, 'plan': 'hereskeret'},
      ];
    } else {
      return [
        {
          'id': 'szezon végén',
          'label': 'Szezon végén',
          'icon': Icons.timer_off,
          'plan': 'oxalsav_egyszeri',
        },
        {
          'id': 'Hans',
          'label': 'Hans',
          'icon': Icons.front_hand,
          'plan': 'grumpy_cat',
        },
      ];
    }
  }

  void _executeFunctionSelection(Map<String, dynamic> item) {
    setState(() {
      _selectedSubFunction = item['id'];
      _selectedPlanType = item['plan'];
    });

    widget.hive.familyFunction = _selectedSubFunction;

    if (_isBreedingCategory) {
      // Tenyész esetén csak eltároljuk, a tervet a lenti gomb indítja
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Család funkció rögzítve: $_selectedSubFunction'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _onSubFunctionSelected(Map<String, dynamic> item) {
    if (item['id'] == 'Hans') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 28,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Figyelem: Hans-protokoll!',
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'A Hans-protokoll egy rendkívül radikális beavatkozás. Biztosan végre akarod hajtani ezen a családon?',
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
                _executeFunctionSelection(item);
              },
              child: const Text('Igen, végrehajtom'),
            ),
          ],
        ),
      );
    } else {
      _executeFunctionSelection(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.amberAccent,
        title: const Text(
          'Család funkció & Mesterterv',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Válassz kategóriát:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryButton(
                      label: 'Gyűjtő',
                      icon: Icons.opacity,
                      isSelected: _selectedCategory == 'Gyűjtő',
                      onTap: () {
                        setState(() {
                          _selectedCategory = 'Gyűjtő';
                          _selectedSubFunction = 'méz';
                          _selectedPlanType = 'petes_mesterterv';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCategoryButton(
                      label: 'Tenyész',
                      icon: Icons.workspace_premium,
                      isSelected: _selectedCategory == 'Tenyész',
                      onTap: () {
                        setState(() {
                          _selectedCategory = 'Tenyész';
                          _selectedSubFunction = 'dajka';
                          _selectedPlanType = 'anyanevelesi_mesterterv';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCategoryButton(
                      label: 'Felszámol',
                      icon: Icons.cancel_outlined,
                      isSelected: _selectedCategory == 'Felszámol',
                      onTap: () {
                        setState(() {
                          _selectedCategory = 'Felszámol';
                          _selectedSubFunction = 'szezon végén';
                          _selectedPlanType = 'oxalsav_egyszeri';
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                '2. Válassz részletes funkciót (Boxkesztyű-barát):',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _getSubFunctions().length,
                  itemBuilder: (context, index) {
                    final item = _getSubFunctions()[index];
                    final isSelected = _selectedSubFunction == item['id'];
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Colors.amber
                            : const Color(0xFF1E293B),
                        foregroundColor: isSelected
                            ? Colors.black
                            : Colors.amberAccent,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.amberAccent
                              : Colors.white24,
                          width: isSelected ? 2 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () => _onSubFunctionSelected(item),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item['icon'],
                            size: 42,
                            color: isSelected
                                ? Colors.black
                                : Colors.amberAccent,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item['label'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              if (_isBreedingCategory)
                SizedBox(
                  width: double.infinity,
                  height: 70,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      widget.hive.familyFunction = _selectedSubFunction;
                      widget.repository.schedulePlanForHive(
                        widget.hive.id,
                        _selectedPlanType,
                        DateTime.now(),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Funkció rögzítve: $_selectedSubFunction | Mesterterv elindítva!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow, size: 28),
                    label: Text(
                      'Terv indítása ($_selectedSubFunction)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade700 : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.tealAccent : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.tealAccent,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TowerScanScreen extends StatelessWidget {
  final HiveData hive;
  final BoxElement broodBox;
  final HiveRepository repository;
  const _TowerScanScreen({
    required this.hive,
    required this.broodBox,
    required this.repository,
  });
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Torony beolvasása')));
}
