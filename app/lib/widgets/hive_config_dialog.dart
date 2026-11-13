import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../services/treatment_adviser.dart';
import 'weak_colony_warning_dialog.dart';

typedef HiveSetupDialog = HiveConfigDialog;

class HiveConfigDialog extends StatefulWidget {
  final HiveData? selectedHive;
  const HiveConfigDialog({super.key, this.selectedHive});

  @override
  State<HiveConfigDialog> createState() => _HiveConfigDialogState();
}

class _HiveConfigDialogState extends State<HiveConfigDialog> {
  final HiveRepository _repository = HiveRepository.instance;
  HiveData? _activeHive;

  String _newBoxType = 'honey';
  String _newBoxSize = 'dadant';

  String _selectedCategory = 'Gyűjtő';
  String _selectedFunction = 'méz';
  String _selectedPlanType = 'petes_mesterterv';

  @override
  void initState() {
    super.initState();
    _activeHive =
        widget.selectedHive ??
        (_repository.hives.isNotEmpty ? _repository.hives.first : null);
  }

  bool get _activeHiveHasRoof =>
      _activeHive != null &&
      _activeHive!.boxes.any((b) =>
          b.type == 'roof' ||
          b.name.toLowerCase().contains('tető') ||
          b.name.toLowerCase().contains('teto'));

  bool _isRealBox(String type) {
    return type == 'brood_box' || type == 'nest' || type == 'honey';
  }

  bool _isBroodBox(String type) {
    return type == 'brood_box' || type == 'nest';
  }

  String _normalizeSystem(String size) {
    final s = size
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('/', '');
    if (s.contains('dadant')) return 'dadant';
    if (s.contains('hunor') ||
        s.contains('nb') ||
        s.contains('nagyboczonadi')) {
      return 'nb_hunor';
    }
    if (s.contains('langstroth')) return 'langstroth';
    return s;
  }

  bool _checkCompatibility(String existingSize, String newSize) {
    if (existingSize.trim().isEmpty || newSize.trim().isEmpty) return true;
    final s1 = existingSize.toLowerCase().trim();
    final s2 = newSize.toLowerCase().trim();
    if (s1 == 'bottom' || s2 == 'bottom' || s1 == 'none' || s2 == 'none') return true;
    final sys1 = _normalizeSystem(existingSize);
    final sys2 = _normalizeSystem(newSize);
    return sys1 == sys2;
  }

  String _getBoxDisplayName(BoxElement box) {
    final lowerName = box.name.trim().toLowerCase();
    final lowerType = box.type.trim().toLowerCase();

    if (lowerType == 'broodbox' ||
        lowerType == 'brood_box' ||
        lowerType == 'nest' ||
        lowerType == '8' ||
        lowerName.contains('fészek') ||
        lowerName.contains('feszek') ||
        (lowerName == 'elem' && box.size.toLowerCase() == 'dadant')) {
      return 'Fészekfiók';
    }
    if (lowerType == 'honey' ||
        lowerType == '9' ||
        lowerName.contains('méztér') ||
        lowerName.contains('mezter')) {
      return 'Méztér';
    }
    if (lowerType == 'feeder' ||
        lowerType == 'roof_feeder' ||
        lowerType == 'tetoeteto' ||
        lowerType == '10' ||
        lowerName.contains('etető') ||
        lowerName.contains('eteto')) {
      return 'Tetőetető';
    }
    if (lowerType == 'escapement' ||
        lowerType == '13' ||
        lowerName.contains('szöktet') ||
        lowerName.contains('szoktet')) {
      return 'Szöktető';
    }
    if (lowerType == 'vent' ||
        lowerType == '12' ||
        lowerName.contains('szellőz') ||
        lowerName.contains('szelloz')) {
      return 'Szellőző';
    }
    if (lowerType == 'pollen_trap' ||
        lowerType == '11' ||
        lowerName.contains('pollen') ||
        lowerName.contains('virágpor')) {
      return 'Pollengyűjtő';
    }
    if (lowerType == 'bottom' ||
        lowerType == '15' ||
        lowerName.contains('alj')) {
      return 'Aljdeszka';
    }
    if (lowerType == 'roof' ||
        lowerName.contains('tető') ||
        lowerName.contains('teto')) {
      return 'Tető';
    }
    if (lowerType == 'treatment_strip' || lowerName.contains('kezel')) {
      return 'Kezelőlap hordozó';
    }
    if (lowerType == 'queen_excluder' ||
        lowerName.contains('anyarács') ||
        lowerName.contains('racs')) {
      return 'Anyarács';
    }

    if (lowerName == 'elem' || lowerName.isEmpty) {
      if (box.type.isNotEmpty && box.type != 'elem') {
        return box.type;
      }
      return 'Kiegészítő elem';
    }
    return box.name;
  }

  String _formatSize(String size) {
    switch (size.toLowerCase().trim()) {
      case 'hunor':
        return 'Hunor';
      case 'dadant':
        return 'Dadant';
      case 'fel_dadant':
      case '1/2 dadant':
      case '1/2dadant':
        return '1/2 Dadant';
      case 'langstroth':
        return 'Langstroth';
      case 'nb':
        return 'NB';
      case 'fel_nb':
      case '1/2 nb':
      case '1/2nb':
        return '1/2 NB';
      case 'nb_fekvo':
      case 'nagyboczonadi':
        return 'NB Fekvő';
      default:
        return size.isNotEmpty ? size : '';
    }
  }

  String _formatBoxTitle(BoxElement box) {
    final displayName = _getBoxDisplayName(box);
    final formattedSize = _formatSize(box.size);
    if (formattedSize.isNotEmpty &&
        displayName != 'Aljdeszka' &&
        displayName != 'Tető' &&
        displayName != 'Szöktető' &&
        displayName != 'Szellőző' &&
        displayName != 'Pollengyűjtő') {
      return '$displayName ($formattedSize)';
    }
    return displayName;
  }

  IconData _getBoxIcon(BoxElement box) {
    final t = box.type.toLowerCase();
    final n = box.name.toLowerCase();
    if (t == 'roof' || n.contains('tető') || n.contains('teto')) {
      return Icons.roofing;
    }
    if (t == 'feeder' ||
        t == 'roof_feeder' ||
        n.contains('etető') ||
        n.contains('eteto')) {
      return Icons.water_drop;
    }
    if (t == 'vent' || n.contains('szellőz') || n.contains('szelloz')) {
      return Icons.air;
    }
    if (t == 'escapement' ||
        n.contains('szöktet') ||
        n.contains('szoktet')) {
      return Icons.swap_horiz;
    }
    if (t == 'honey' || n.contains('méz') || n.contains('mez')) {
      return Icons.hive;
    }
    if (t == 'brood_box' ||
        t == 'nest' ||
        n.contains('fészek') ||
        n.contains('feszek')) {
      return Icons.hive;
    }
    if (t == 'pollen_trap' ||
        n.contains('pollen') ||
        n.contains('virágpor')) {
      return Icons.grain;
    }
    if (t == 'bottom' || n.contains('alj')) {
      return Icons.crop_portrait;
    }
    return Icons.extension;
  }

  Color _getBoxColor(BoxElement box) {
    final t = box.type.toLowerCase();
    final n = box.name.toLowerCase();
    if (t == 'roof' || n.contains('tető') || n.contains('teto')) {
      return Colors.tealAccent;
    }
    if (t == 'feeder' ||
        t == 'roof_feeder' ||
        n.contains('etető') ||
        n.contains('eteto')) {
      return Colors.lightBlueAccent;
    }
    if (t == 'vent' || n.contains('szellőz') || n.contains('szelloz')) {
      return Colors.cyanAccent;
    }
    if (t == 'escapement' ||
        n.contains('szöktet') ||
        n.contains('szoktet')) {
      return Colors.indigoAccent;
    }
    if (t == 'honey' || n.contains('méz') || n.contains('mez')) {
      return Colors.amber;
    }
    if (t == 'brood_box' ||
        t == 'nest' ||
        n.contains('fészek') ||
        n.contains('feszek')) {
      return Colors.amberAccent;
    }
    if (t == 'pollen_trap' ||
        n.contains('pollen') ||
        n.contains('virágpor')) {
      return Colors.orangeAccent;
    }
    if (t == 'bottom' || n.contains('alj')) {
      return Colors.deepOrangeAccent;
    }
    return Colors.tealAccent;
  }

  void _addNewElementToActiveHive() {
    if (_activeHive == null) return;

    // Tető duplikáció elleni védelem (egy kaptárban szigorúan legfeljebb 1 tető lehet)
    if (_newBoxType == 'roof' && _activeHiveHasRoof) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A kaptárnak már van teteje! Egy kaptárban csak 1 tető lehet.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_isRealBox(_newBoxType)) {
      final incompatibleBox = _activeHive!.boxes.firstWhere(
        (b) =>
            _isRealBox(b.type) &&
            b.type != 'bottom' &&
            b.size.isNotEmpty &&
            b.size.toLowerCase() != 'bottom' &&
            !_checkCompatibility(b.size, _newBoxSize),
        orElse: () => BoxElement(name: '', code: '', type: '', size: ''),
      );

      if (incompatibleBox.size.isNotEmpty) {
        final existingSizeName = _formatSize(incompatibleBox.size);
        final newSizeName = _formatSize(_newBoxSize);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.redAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Méret összeférhetetlenség',
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              ],
            ),
            content: Text(
              'A kiválasztott méret ($newSizeName) nem kombinálható a kaptárban lévő $existingSizeName mérettel!\n\n'
              '• A Dadant rendszerben teljes Dadant és 1/2 Dadant fiókok használhatók.\n'
              '• Az NB, Hunor és 1/2 NB egymással kompatibilisek, de a Dadanttal keresztbe nem keverhetők.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Megértettem',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }
    }

    // 1. Etető és Méztér összeférhetetlenség ellenőrzése (Mézhamisítás védelem)
    if (_newBoxType == 'feeder' && _activeHive!.hasHoneySuper) {
      showFeederHoneyConflictDialog(
        context: context,
        hive: _activeHive!,
        conflictType: 'adding_feeder_with_honey',
        onConfirm: _executeAddElementToActiveHive,
      );
      return;
    }

    if (_newBoxType == 'honey' &&
        (_activeHive!.hasFeeder || _activeHive!.feedingMode != 'off')) {
      showFeederHoneyConflictDialog(
        context: context,
        hive: _activeHive!,
        conflictType: 'adding_honey_with_feeder',
        onConfirm: _executeAddElementToActiveHive,
      );
      return;
    }

    // 2. Gyenge / beteg család megcsapolás elleni védelme
    final bool isHoneyOrPollen =
        (_newBoxType == 'honey' || _newBoxType == 'pollen_trap');
    if (isHoneyOrPollen && _activeHive!.isWeakOrSick) {
      final String actionTitle = _newBoxType == 'honey'
          ? 'Méztér hozzáadása'
          : 'Pollengyűjtő hozzáadása';
      showWeakColonyWarningDialog(
        context: context,
        hive: _activeHive!,
        actionTitle: actionTitle,
        onConfirm: _executeAddElementToActiveHive,
      );
      return;
    }

    _executeAddElementToActiveHive();
  }

  void _executeAddElementToActiveHive() {
    if (_activeHive == null) return;

    String boxName = 'Elem';
    if (_newBoxType == 'brood_box') boxName = 'Fészekfiók';
    if (_newBoxType == 'honey') boxName = 'Méztér';
    if (_newBoxType == 'feeder') boxName = 'Tetőetető';
    if (_newBoxType == 'escapement') boxName = 'Szöktető';
    if (_newBoxType == 'vent') boxName = 'Szellőző';
    if (_newBoxType == 'pollen_trap') boxName = 'Pollengyűjtő';
    if (_newBoxType == 'roof') boxName = 'Tető';

    final newBox = BoxElement(
      name: boxName,
      code:
          '${_activeHive!.id}_${_newBoxType.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      type: _newBoxType,
      size: _isRealBox(_newBoxType) ? _newBoxSize : '',
      status: 'green',
    );

    _repository.addBoxToHive(_activeHive!, newBox);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$boxName hozzáadva a toronyhoz.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeElementFromActiveHive(BoxElement box) {
    if (_activeHive == null) return;

    if (box.type == 'bottom') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Az aljdeszka a kaptár fix alapeleme, nem törölhető.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (_isBroodBox(box.type)) {
      int broodBoxCount = _activeHive!.boxes
          .where((b) => _isBroodBox(b.type))
          .length;
      if (broodBoxCount <= 1) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
                SizedBox(width: 8),
                Text(
                  'Fészekfiók törlése',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: const Text(
              'Ez az utolsó fészekfiók a kaptáron! Ha eltávolítod, a család fészek nélkül marad (pl. üres aljdeszka / tartalék marad). Biztosan folytatod?',
              style: TextStyle(color: Colors.white70),
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
                  _executeRemoveBox(box);
                },
                child: const Text('Fiók eltávolítása'),
              ),
            ],
          ),
        );
        return;
      }
    }

    _executeRemoveBox(box);
  }

  void _executeRemoveBox(BoxElement box) {
    if (_activeHive == null) return;
    _repository.removeBoxFromHive(_activeHive!, box);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${box.name} eltávolítva.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _updateHiveStatus(String newStatus) {
    if (_activeHive == null) return;
    setState(() {
      _activeHive!.status = newStatus;
    });
    _repository.updateHive(_activeHive!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Család státusza frissítve: $newStatus'),
        backgroundColor: Colors.amber,
      ),
    );
  }

  void _startSelectedPlan() {
    if (_activeHive == null) return;
    if (_selectedCategory == 'Tenyész') {
      _repository.schedulePlanForHive(
        _activeHive!.id,
        _selectedPlanType,
        DateTime.now(),
      );
    }
    _activeHive!.familyFunction = _selectedCategory == 'Felszámol'
        ? 'felszamol_$_selectedFunction'
        : _selectedFunction;
    _repository.updateHive(_activeHive!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedCategory == 'Tenyész'
              ? 'Funkció rögzítve: $_selectedFunction | Mesterterv elindítva!'
              : 'Család funkció rögzítve: $_selectedFunction',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formicCheck = TreatmentAdviser.checkFormicAcidConditions(
      _repository.weatherStation,
    );

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0F172A),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Row(
            children: [
              Icon(Icons.tune, color: Colors.amberAccent, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Torony Konfiguráció',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Kész',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ListenableBuilder(
              listenable: _repository,
              builder: (context, _) {
                if (_activeHive != null &&
                    !_repository.hives.contains(_activeHive)) {
                  _activeHive = _repository.hives.isNotEmpty
                      ? _repository.hives.first
                      : null;
                }

                if (_activeHive != null) {
                  sortHiveBoxes(_activeHive!.boxes);
                  if (_activeHiveHasRoof && _newBoxType == 'roof') {
                    _newBoxType = 'honey';
                  }
                }
                final displayedBoxes =
                    _activeHive?.boxes.reversed.toList() ?? [];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (formicCheck['recommended'] as bool)
                          ? Colors.green.withAlpha(40)
                          : Colors.red.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (formicCheck['recommended'] as bool)
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formicCheck['title'] as String,
                          style: TextStyle(
                            color: (formicCheck['recommended'] as bool)
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formicCheck['reason'] as String,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_repository.hives.isNotEmpty) ...[
                    const Divider(color: Colors.white24, height: 24),
                    const Text(
                      'Kiválasztott család:',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<HiveData>(
                      value: _activeHive,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      items: _repository.hives.map((h) {
                        int count = h.boxes
                            .where((b) => _isRealBox(b.type))
                            .length;
                        return DropdownMenuItem(
                          value: h,
                          child: Text(
                            '${h.name} (Fiókok: $count db, Szirup: ${h.syrupLiters.toStringAsFixed(1)} L)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _activeHive = val),
                    ),

                    if (_activeHive != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Család státusza (színkód):',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatusButton('Zöld', 'green', Colors.green),
                          _buildStatusButton(
                            'Sárga',
                            'yellow',
                            Colors.amber.shade700,
                          ),
                          _buildStatusButton(
                            'Narancs',
                            'orange',
                            Colors.orange,
                          ),
                          _buildStatusButton(
                            'Lila',
                            'purple',
                            Colors.purpleAccent,
                          ),
                          _buildStatusButton('Piros', 'red', Colors.red),
                        ],
                      ),

                      const Divider(color: Colors.white24, height: 24),
                      const Text(
                        'Család funkció & Mesterterv:',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              dropdownColor: const Color(0xFF2C2C2C),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Gyűjtő',
                                  child: Text('Gyűjtő'),
                                ),
                                DropdownMenuItem(
                                  value: 'Tenyész',
                                  child: Text('Tenyész'),
                                ),
                                DropdownMenuItem(
                                  value: 'Felszámol',
                                  child: Text('Felszámol'),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedCategory = val ?? 'Gyűjtő';
                                  if (_selectedCategory == 'Gyűjtő') {
                                    _selectedFunction = 'méz';
                                    _selectedPlanType = 'petes_mesterterv';
                                  } else if (_selectedCategory == 'Tenyész') {
                                    _selectedFunction = 'dajka';
                                    _selectedPlanType =
                                        'anyanevelesi_mesterterv';
                                  } else {
                                    _selectedFunction = 'szezon végén';
                                    _selectedPlanType = 'oxalsav_egyszeri';
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedFunction,
                              dropdownColor: const Color(0xFF2C2C2C),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              isExpanded: true,
                              items: _getSubFunctionItems(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedFunction = val;
                                    if (val == 'méz') {
                                      _selectedPlanType = 'petes_mesterterv';
                                    }
                                    if (val == 'pollen') {
                                      _selectedPlanType = 'alcas_mesterterv';
                                    }
                                    if (val == 'propolisz') {
                                      _selectedPlanType = 'hereskeret';
                                    }
                                    if (val == 'méhméreg') {
                                      _selectedPlanType = 'grumpy_cat';
                                    }
                                    if (val == 'dajka') {
                                      _selectedPlanType =
                                          'anyanevelesi_mesterterv';
                                    }
                                    if (val == 'donor') {
                                      _selectedPlanType = 'petes_mesterterv';
                                    }
                                    if (val == 'starter') {
                                      _selectedPlanType = 'alcas_mesterterv';
                                    }
                                    if (val == 'anya') {
                                      _selectedPlanType = 'oxalsav_sorozat';
                                    }
                                    if (val == 'apa') {
                                      _selectedPlanType = 'hereskeret';
                                    }
                                    if (val == 'selejt') {
                                      _selectedPlanType = 'felerosites_mesterterv';
                                    }
                                    if (val == 'szezon végén') {
                                      _selectedPlanType = 'oxalsav_egyszeri';
                                    }
                                    if (val == 'Hans') {
                                      _selectedPlanType = 'grumpy_cat';
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedCategory == 'Tenyész'
                                ? Colors.amber
                                : Colors.teal.shade700,
                            foregroundColor: _selectedCategory == 'Tenyész'
                                ? Colors.black
                                : Colors.white,
                          ),
                          onPressed: _startSelectedPlan,
                          icon: Icon(
                            _selectedCategory == 'Tenyész'
                                ? Icons.play_arrow
                                : Icons.check,
                            size: 16,
                          ),
                          label: Text(
                            _selectedCategory == 'Tenyész'
                                ? 'Terv indítása ($_selectedFunction)'
                                : 'Funkció rögzítése ($_selectedFunction)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const Divider(color: Colors.white24, height: 24),
                      const Row(
                        children: [
                          Icon(Icons.layers, color: Colors.amberAccent, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Torony felépítése (Fentről lefelé):',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141428),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            if (displayedBoxes.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text(
                                  'A kaptár még nem tartalmaz fiókokat.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              for (var box in displayedBoxes)
                                Builder(
                                  builder: (context) {
                                    final bool isBottom = box.type == 'bottom' ||
                                        box.name.toLowerCase() == 'aljdeszka';
                                    final bool isRoof = box.type == 'roof' ||
                                        box.name.toLowerCase().contains('tető') ||
                                        box.name.toLowerCase().contains('teto');
                                    final int rawIdx = _activeHive != null
                                        ? _activeHive!.boxes.indexOf(box)
                                        : -1;
                                    final bool canMoveUp = _activeHive != null &&
                                        !isBottom &&
                                        !isRoof &&
                                        rawIdx != -1 &&
                                        rawIdx + 1 < _activeHive!.boxes.length &&
                                        _activeHive!.boxes[rawIdx + 1].type != 'roof';
                                    final bool canMoveDown = _activeHive != null &&
                                        !isBottom &&
                                        !isRoof &&
                                        rawIdx != -1 &&
                                        rawIdx - 1 >= 0 &&
                                        _activeHive!.boxes[rawIdx - 1].type != 'bottom';

                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 3.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E293B),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _getBoxColor(box).withAlpha(100),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getBoxIcon(box),
                                              size: 18,
                                              color: _getBoxColor(box),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _formatBoxTitle(box),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (!isBottom && !isRoof) ...[
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.arrow_upward,
                                                  size: 18,
                                                ),
                                                color: canMoveUp
                                                    ? Colors.amberAccent
                                                    : Colors.white24,
                                                tooltip: 'Fiók mozgatása feljebb',
                                                onPressed: canMoveUp
                                                    ? () {
                                                        _repository.reorderBox(
                                                          _activeHive!,
                                                          box,
                                                          moveUp: true,
                                                        );
                                                        setState(() {});
                                                      }
                                                    : null,
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.arrow_downward,
                                                  size: 18,
                                                ),
                                                color: canMoveDown
                                                    ? Colors.amberAccent
                                                    : Colors.white24,
                                                tooltip: 'Fiók mozgatása lejjebb',
                                                onPressed: canMoveDown
                                                    ? () {
                                                        _repository.reorderBox(
                                                          _activeHive!,
                                                          box,
                                                          moveUp: false,
                                                        );
                                                        setState(() {});
                                                      }
                                                    : null,
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            if (box.type != 'bottom' &&
                                                box.name.toLowerCase() !=
                                                    'aljdeszka')
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                  size: 20,
                                                ),
                                                tooltip:
                                                    '${_getBoxDisplayName(box)} eltávolítása',
                                                onPressed: () =>
                                                    _removeElementFromActiveHive(
                                                        box),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                              )
                                            else
                                              const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.lock_outline,
                                                    size: 14,
                                                    color: Colors.white38,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Fix alap',
                                                    style: TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Text(
                        'Új fiók vagy tartozék hozzáadása:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: _newBoxType,
                              dropdownColor: const Color(0xFF2C2C2C),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: 'brood_box',
                                  child: Text('Fészekfiók'),
                                ),
                                const DropdownMenuItem(
                                  value: 'honey',
                                  child: Text('Méztér'),
                                ),
                                const DropdownMenuItem(
                                  value: 'feeder',
                                  child: Text('Tetőetető'),
                                ),
                                const DropdownMenuItem(
                                  value: 'escapement',
                                  child: Text('Szöktető'),
                                ),
                                const DropdownMenuItem(
                                  value: 'vent',
                                  child: Text('Szellőző'),
                                ),
                                const DropdownMenuItem(
                                  value: 'pollen_trap',
                                  child: Text('Virágporgyűjtő'),
                                ),
                                if (!_activeHiveHasRoof)
                                  const DropdownMenuItem(
                                    value: 'roof',
                                    child: Text('Tető'),
                                  ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _newBoxType = val);
                                }
                              },
                            ),
                          ),
                          if (_isRealBox(_newBoxType)) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _newBoxSize,
                                dropdownColor: const Color(0xFF2C2C2C),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'hunor',
                                    child: Text('Hunor'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'dadant',
                                    child: Text('Dadant'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'fel_dadant',
                                    child: Text('1/2 Dadant'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'langstroth',
                                    child: Text('Langstroth'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'nb',
                                    child: Text('NB'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'fel_nb',
                                    child: Text('1/2 NB'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _newBoxSize = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _addNewElementToActiveHive,
                          icon: const Icon(Icons.add_box, size: 16),
                          label: const Text(
                            'Hozzáadás a toronyhoz',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

  Widget _buildStatusButton(String label, String statusKey, Color color) {
    bool isSelected = _activeHive?.status == statusKey;
    return InkWell(
      onTap: () => _updateHiveStatus(statusKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  List<DropdownMenuItem<String>> _getSubFunctionItems() {
    if (_selectedCategory == 'Gyűjtő') {
      return const [
        DropdownMenuItem(value: 'méz', child: Text('Méz')),
        DropdownMenuItem(value: 'pollen', child: Text('Pollen')),
        DropdownMenuItem(value: 'propolisz', child: Text('Propolisz')),
        DropdownMenuItem(value: 'méhméreg', child: Text('Méhméreg')),
      ];
    } else if (_selectedCategory == 'Tenyész') {
      return const [
        DropdownMenuItem(value: 'dajka', child: Text('Dajka')),
        DropdownMenuItem(value: 'donor', child: Text('Donor')),
        DropdownMenuItem(value: 'starter', child: Text('Starter')),
        DropdownMenuItem(value: 'anya', child: Text('Anya')),
        DropdownMenuItem(value: 'apa', child: Text('Apa')),
      ];
    } else {
      return const [
        DropdownMenuItem(value: 'selejt', child: Text('Selejt (Felerősítéshez)')),
        DropdownMenuItem(value: 'szezon végén', child: Text('Szezon végén')),
        DropdownMenuItem(value: 'Hans', child: Text('Hans (Azonnali elpusztítás)')),
      ];
    }
  }
}
