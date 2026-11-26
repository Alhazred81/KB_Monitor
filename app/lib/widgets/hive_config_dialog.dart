import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../screens/brood_box_control_screen.dart';
import '../services/hive_repository.dart';
import 'candy_icon.dart';
import 'help_bubble.dart';
import 'hive_tower_icon.dart';
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

  // 'box' = Fiók (Fészek, Lépépítő, Szaporító (Demaree), Méztéri)
  // 'accessory' = Kellékek (Tetőetető, Szöktető, Anyarács, Virágporgyűjtő, Szellőző, Tető)
  String _addCategory = 'box';
  String _newBoxType = 'honey';
  String _newBoxSize = 'dadant';

  static const List<Map<String, dynamic>> _boxTypeOptions = [
    {
      'id': 'brood_box',
      'label': 'Fészek',
      'icon': Icons.hive,
      'color': Colors.amberAccent,
    },
    {
      'id': 'comb_builder',
      'label': 'Lépépítő',
      'icon': Icons.grid_on,
      'color': Colors.tealAccent,
    },
    {
      'id': 'demaree',
      'label': 'Szaporító\n(Demaree)',
      'icon': Icons.call_split,
      'color': Colors.purpleAccent,
    },
    {
      'id': 'honey',
      'label': 'Méztéri',
      'icon': Icons.inventory_2,
      'color': Colors.amber,
    },
  ];

  static const List<Map<String, String>> _sizeOptions = [
    {'id': 'dadant', 'label': 'Dadant'},
    {'id': 'fel_dadant', 'label': '1/2 Dadant'},
    {'id': 'hunor', 'label': 'Hunor'},
    {'id': 'nb', 'label': 'NB'},
    {'id': 'fel_nb', 'label': '1/2 NB'},
    {'id': 'langstroth', 'label': 'Langstroth'},
    {'id': 'fel_langstroth', 'label': '1/2 Langstroth'},
  ];

  @override
  void initState() {
    super.initState();
    _activeHive =
        widget.selectedHive ??
        (_repository.hives.isNotEmpty ? _repository.hives.first : null);
    _syncDefaultSizeWithHive();
  }

  /// Meghatározza a kaptáron már meglévő alapfiók szabványrendszerét ('dadant', 'nb_hunor', 'langstroth'),
  /// vagy null-t ad vissza, ha még nincs egyetlen valódi fiók sem a kaptáron.
  String? _getActiveHiveSystem() {
    if (_activeHive == null) return null;
    // Először a fészekfiókot nézzük mint alapfiókot
    for (final b in _activeHive!.boxes) {
      final sz = b.size.trim().toLowerCase();
      if (_isBroodBox(b.type) &&
          sz.isNotEmpty &&
          sz != 'bottom' &&
          sz != 'none') {
        return _normalizeSystem(b.size);
      }
    }
    // Ha nincs fészekfiók, bármely más meglévő valódi fiók méretét vesszük alapul
    for (final b in _activeHive!.boxes) {
      final sz = b.size.trim().toLowerCase();
      if (_isRealBox(b.type) &&
          sz.isNotEmpty &&
          sz != 'bottom' &&
          sz != 'none') {
        return _normalizeSystem(b.size);
      }
    }
    return null;
  }

  /// Csak a kaptár meglévő alapfiókjával kompatibilis méreteket adja vissza.
  /// Ha még nincs alapfiók a kaptáron, az összes méret elérhető.
  List<Map<String, String>> _getCompatibleSizeOptions() {
    final String? sys = _getActiveHiveSystem();
    if (sys == null) return _sizeOptions;
    return _sizeOptions
        .where((opt) => _normalizeSystem(opt['id']!) == sys)
        .toList();
  }

  void _syncDefaultSizeWithHive() {
    if (_activeHive == null) return;
    final String? sys = _getActiveHiveSystem();
    if (sys == 'dadant') {
      _newBoxSize = _newBoxType == 'honey' ? 'fel_dadant' : 'dadant';
    } else if (sys == 'nb_hunor') {
      final hasHunor = _activeHive!.boxes.any(
        (b) => _isRealBox(b.type) && b.size.toLowerCase().contains('hunor'),
      );
      if (_newBoxType == 'honey') {
        _newBoxSize = hasHunor ? 'hunor' : 'fel_nb';
      } else {
        _newBoxSize = hasHunor ? 'hunor' : 'nb';
      }
    } else if (sys == 'langstroth') {
      _newBoxSize = _newBoxType == 'honey' ? 'fel_langstroth' : 'langstroth';
    }
  }

  void _ensureValidSelectedSize() {
    final compatible = _getCompatibleSizeOptions();
    if (compatible.isEmpty) return;
    if (!compatible.any((opt) => opt['id'] == _newBoxSize)) {
      _syncDefaultSizeWithHive();
      if (!compatible.any((opt) => opt['id'] == _newBoxSize)) {
        _newBoxSize = compatible.first['id']!;
      }
    }
  }

  bool get _activeHiveHasRoof =>
      _activeHive != null &&
      _activeHive!.boxes.any((b) {
        final t = b.type.toLowerCase();
        final n = b.name.toLowerCase();
        if (t == 'escapement' ||
            n.contains('szöktet') ||
            n.contains('szoktet') ||
            n.contains('etet')) {
          return false;
        }
        return t == 'roof' || n.contains('tető') || n.contains('teto');
      });

  bool _isRealBox(String type) {
    return type == 'brood_box' ||
        type == 'nest' ||
        type == 'comb_builder' ||
        type == 'demaree' ||
        type == 'honey';
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
    if (s1 == 'bottom' || s2 == 'bottom' || s1 == 'none' || s2 == 'none') {
      return true;
    }
    return _normalizeSystem(existingSize) == _normalizeSystem(newSize);
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
    if (lowerType == 'comb_builder' ||
        lowerName.contains('lépépít') ||
        lowerName.contains('lepepit')) {
      return 'Lépépítő';
    }
    if (lowerType == 'demaree' ||
        lowerName.contains('szaporít') ||
        lowerName.contains('szaporit') ||
        lowerName.contains('demaree')) {
      return 'Szaporító (Demaree)';
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
      return 'Virágporgyűjtő';
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
    final lower = size.toLowerCase().trim();
    if (isHalfBoxSize(lower)) {
      if (lower.contains('nb')) return '1/2 NB';
      if (lower.contains('lang')) return '1/2 Langstroth';
      return '1/2 Dadant';
    }
    switch (lower) {
      case 'hunor':
        return 'Hunor';
      case 'dadant':
        return 'Dadant';
      case 'langstroth':
      case 'lang_deep':
        return 'Langstroth';
      case 'nb':
      case 'nb_rakodo':
        return 'NB';
      case 'nb_fekvo':
      case 'nagyboczonadi':
        return 'NB Fekvő';
      default:
        return size.isNotEmpty ? size : '';
    }
  }

  String _formatBoxTitle(BoxElement box) {
    final raw = _getBoxDisplayName(box);
    if (raw.contains('Demaree')) return 'Szaporító (Demaree)';
    return raw.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
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
      return Icons.filter_alt;
    }
    if (t == 'comb_builder' || n.contains('lépépít') || n.contains('lepepit')) {
      return Icons.grid_on;
    }
    if (t == 'demaree' || n.contains('szaporít') || n.contains('demaree')) {
      return Icons.call_split;
    }
    if (t == 'queen_excluder' || n.contains('anyarács') || n.contains('racs')) {
      return Icons.grid_4x4;
    }
    if (t == 'honey' || n.contains('méz') || n.contains('mez')) {
      return Icons.inventory_2;
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
    if (_activeHive?.isQuarantined == true || box.isQuarantined) {
      return Colors.redAccent;
    }
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
      return Colors.orangeAccent;
    }
    if (t == 'comb_builder' || n.contains('lépépít') || n.contains('lepepit')) {
      return Colors.tealAccent;
    }
    if (t == 'demaree' || n.contains('szaporít') || n.contains('demaree')) {
      return Colors.purpleAccent;
    }
    if (t == 'queen_excluder' || n.contains('anyarács') || n.contains('racs')) {
      return Colors.amberAccent;
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
      return Colors.deepOrangeAccent;
    }
    if (t == 'bottom' || n.contains('alj')) {
      return Colors.deepOrangeAccent;
    }
    return Colors.tealAccent;
  }

  List<Map<String, dynamic>> _getAccessoryOptions() {
    return [
      {
        'id': 'feeder',
        'label': 'Tetőetető',
        'icon': Icons.water_drop,
        'color': Colors.lightBlueAccent,
      },
      {
        'id': 'escapement',
        'label': 'Szöktető',
        'icon': Icons.filter_alt,
        'color': Colors.orangeAccent,
      },
      {
        'id': 'queen_excluder',
        'label': 'Anyarács',
        'icon': Icons.grid_4x4,
        'color': Colors.amberAccent,
      },
      {
        'id': 'pollen_trap',
        'label': 'Virágpor-\ngyűjtő',
        'icon': Icons.grain,
        'color': Colors.deepOrangeAccent,
      },
      {
        'id': 'vent',
        'label': 'Szellőző',
        'icon': Icons.air,
        'color': Colors.cyanAccent,
      },
      if (!_activeHiveHasRoof)
        {
          'id': 'roof',
          'label': 'Tető',
          'icon': Icons.roofing,
          'color': Colors.tealAccent,
        },
    ];
  }

  String _getSelectedElementLabel() {
    switch (_newBoxType) {
      case 'brood_box':
        return 'Fészek (${_formatSize(_newBoxSize)})';
      case 'comb_builder':
        return 'Lépépítő (${_formatSize(_newBoxSize)})';
      case 'demaree':
        return 'Szaporító – Demaree (${_formatSize(_newBoxSize)})';
      case 'honey':
        return 'Méztéri (${_formatSize(_newBoxSize)})';
      case 'feeder':
        return 'Tetőetető';
      case 'escapement':
        return 'Szöktető';
      case 'queen_excluder':
        return 'Anyarács';
      case 'pollen_trap':
        return 'Virágporgyűjtő';
      case 'vent':
        return 'Szellőző';
      case 'roof':
        return 'Tető';
      default:
        return _newBoxType;
    }
  }

  void _addNewElementToActiveHive() {
    if (_activeHive == null) return;

    if (_activeHive!.isQuarantined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ ZÁRLAT: Nyúlós költésrothadás miatt a teljes torony karantén alatt áll, nem bővíthető!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
                Icon(Icons.warning_amber, color: Colors.redAccent, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Méret összeférhetetlenség',
                    style: TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(120, 46),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Megértettem',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        return;
      }

      // Maximális toronymagasság ellenőrzése: max. 4.0 teljes fiók (vagy 8 db 1/2 fiók)!
      final double addedEq = boxFullEquivalentFor(
        type: _newBoxType,
        size: _newBoxSize,
      );
      final double projectedEq =
          _activeHive!.fullBoxEquivalentCount + addedEq;
      if (projectedEq > HiveData.kMaxFullBoxEquivalent + 1e-6) {
        showMaxTowerHeightBlockedDialog(
          context: context,
          hive: _activeHive!,
          addedBoxLabel: _getSelectedElementLabel(),
          addedEquivalent: addedEq,
        );
        return;
      }
    }

    final bool alreadyHasBroodBox = _activeHive!.boxes.any(
      (b) => _isBroodBox(b.type),
    );
    final bool isExtraFrameBox =
        _newBoxType == 'honey' ||
        _newBoxType == 'comb_builder' ||
        _newBoxType == 'demaree' ||
        (_newBoxType == 'brood_box' && alreadyHasBroodBox);
    final bool needsWeakColonyConfirm =
        (isExtraFrameBox || _newBoxType == 'pollen_trap') &&
        (_activeHive!.isWeakOrSick || _activeHive!.isPoorPerformer);
    final double addedBoxEq = _isRealBox(_newBoxType)
        ? boxFullEquivalentFor(type: _newBoxType, size: _newBoxSize)
        : 0.0;
    final double projectedTowerEq =
        _activeHive!.fullBoxEquivalentCount + addedBoxEq;
    final bool needsSpaniferConfirm =
        _isRealBox(_newBoxType) &&
        projectedTowerEq > HiveData.kSpaniferWarningThreshold + 1e-6;

    final FamilyFunctionBoxMismatch? functionMismatch =
        evaluateFamilyFunctionBoxMismatch(
          hive: _activeHive!,
          boxType: _newBoxType,
          boxName: _getSelectedElementLabel(),
        );

    void finishAndAdd({bool overriddenMismatch = false}) {
      if (overriddenMismatch && functionMismatch != null) {
        _repository.logHistoryEvent(
          _activeHive!.id,
          'nem_megfelelo_elem_felulbiralas',
          'Figyelmeztetés felülbírálva (${functionMismatch.functionLabel}): ${functionMismatch.elementLabel} felhelyezve.',
          metadata: {
            'family_function': _activeHive!.familyFunction,
            'box_type': _newBoxType,
            'element_label': functionMismatch.elementLabel,
          },
        );
      }
      _executeAddElementToActiveHive();
    }

    void stepPollenConflict({bool overriddenMismatch = false}) {
      if (!overriddenMismatch &&
          _newBoxType == 'honey' &&
          _activeHive!.hasActivePollenTrap) {
        showPollenHoneyConflictDialog(
          context: context,
          hive: _activeHive!,
          conflictType: 'adding_honey_with_pollen',
          onConfirm: () => finishAndAdd(overriddenMismatch: overriddenMismatch),
        );
        return;
      }
      if (!overriddenMismatch &&
          _newBoxType == 'pollen_trap' &&
          _activeHive!.hasHoneySuper) {
        showPollenHoneyConflictDialog(
          context: context,
          hive: _activeHive!,
          conflictType: 'enabling_pollen_with_honey',
          onConfirm: () => finishAndAdd(overriddenMismatch: overriddenMismatch),
        );
        return;
      }
      finishAndAdd(overriddenMismatch: overriddenMismatch);
    }

    void stepFeederConflict({bool overriddenMismatch = false}) {
      if (!overriddenMismatch &&
          _newBoxType == 'feeder' &&
          _activeHive!.hasHoneySuper) {
        showFeederHoneyConflictDialog(
          context: context,
          hive: _activeHive!,
          conflictType: 'adding_feeder_with_honey',
          onConfirm: () =>
              stepPollenConflict(overriddenMismatch: overriddenMismatch),
        );
        return;
      }
      if (_newBoxType == 'honey' &&
          (_activeHive!.hasFeeder || _activeHive!.feedingMode != 'off')) {
        showFeederHoneyConflictDialog(
          context: context,
          hive: _activeHive!,
          conflictType: 'adding_honey_with_feeder',
          onConfirm: () =>
              stepPollenConflict(overriddenMismatch: overriddenMismatch),
        );
        return;
      }
      stepPollenConflict(overriddenMismatch: overriddenMismatch);
    }

    void stepSpaniferWarning({bool overriddenMismatch = false}) {
      if (needsSpaniferConfirm) {
        showSpaniferRequiredWarningDialog(
          context: context,
          hive: _activeHive!,
          addedBoxLabel: _getSelectedElementLabel(),
          projectedFullEquivalent: projectedTowerEq,
          onConfirm: () =>
              stepFeederConflict(overriddenMismatch: overriddenMismatch),
        );
        return;
      }
      stepFeederConflict(overriddenMismatch: overriddenMismatch);
    }

    void stepFunctionMismatchWarning() {
      if (functionMismatch != null) {
        showFamilyFunctionBoxMismatchDialog(
          context: context,
          hive: _activeHive!,
          mismatch: functionMismatch,
          onConfirm: () => stepSpaniferWarning(overriddenMismatch: true),
        );
        return;
      }
      stepSpaniferWarning();
    }

    if (needsWeakColonyConfirm) {
      String actionTitle;
      switch (_newBoxType) {
        case 'brood_box':
          actionTitle = 'Plusz fészekfiók hozzáadása';
          break;
        case 'comb_builder':
          actionTitle = 'Lépépítő fiók hozzáadása';
          break;
        case 'demaree':
          actionTitle = 'Szaporító (Demaree) fiók hozzáadása';
          break;
        case 'honey':
          actionTitle = 'Méztéri fiók hozzáadása';
          break;
        case 'pollen_trap':
          actionTitle = 'Virágporgyűjtő hozzáadása';
          break;
        default:
          actionTitle = 'Fiók hozzáadása';
      }
      showWeakColonyWarningDialog(
        context: context,
        hive: _activeHive!,
        actionTitle: actionTitle,
        onConfirm: stepFunctionMismatchWarning,
      );
      return;
    }

    stepFunctionMismatchWarning();
  }

  void _executeAddElementToActiveHive() {
    if (_activeHive == null) return;

    String boxName = 'Elem';
    switch (_newBoxType) {
      case 'brood_box':
        boxName = 'Fészekfiók';
        break;
      case 'comb_builder':
        boxName = 'Lépépítő';
        break;
      case 'demaree':
        boxName = 'Szaporító (Demaree)';
        break;
      case 'honey':
        boxName = 'Méztér';
        break;
      case 'feeder':
        boxName = 'Tetőetető';
        break;
      case 'escapement':
        boxName = 'Szöktető';
        break;
      case 'queen_excluder':
        boxName = 'Anyarács';
        break;
      case 'vent':
        boxName = 'Szellőző';
        break;
      case 'pollen_trap':
        boxName = 'Virágporgyűjtő';
        break;
      case 'roof':
        boxName = 'Tető';
        break;
    }

    final bool isEscapement = _newBoxType == 'escapement';
    final newBox = BoxElement(
      name: boxName,
      code:
          '${_activeHive!.id}_${_newBoxType.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      type: _newBoxType,
      size: _isRealBox(_newBoxType)
          ? _newBoxSize
          : (isEscapement ? _newBoxSize : ''),
      status: 'green',
      isActive: isEscapement,
      statusUpdatedAt: isEscapement ? DateTime.now() : null,
    );

    _repository.addBoxToHive(_activeHive!, newBox);
    if (_newBoxType == 'roof') {
      _newBoxType = 'feeder';
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$boxName hozzáadva a toronyhoz.'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _removeElementFromActiveHive(BoxElement box) {
    if (_activeHive == null) return;

    if (_activeHive!.isQuarantined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ ZÁRLAT: Nyúlós költésrothadás miatt a teljes torony karantén alatt áll! Semmi nem vehető le róla!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fészekfiók törlése',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Ez az utolsó fészekfiók a kaptáron! Ha eltávolítod, a család fészek nélkül marad. Biztosan folytatod?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Mégse',
                  style: TextStyle(color: Colors.white60, fontSize: 15),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(140, 48),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _executeRemoveBox(box);
                },
                child: const Text(
                  'Eltávolítás',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
        backgroundColor: Colors.orange.shade800,
      ),
    );
  }

  void _updateHiveStatus(String newStatus) {
    if (_activeHive == null) return;
    setState(() {
      _activeHive!.status = newStatus;
    });
    _repository.updateHive(
      _activeHive!,
      historyEventType: 'statusz_valtozas',
      historyDescription: 'Család státusza kézzel módosítva: $newStatus.',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Család státusza frissítve: $newStatus'),
        backgroundColor: Colors.amber.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0F172A),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              const HiveTowerIcon(size: 24, color: Colors.amberAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _activeHive != null
                      ? 'Konfiguráció – ${_activeHive!.name}'
                      : 'Torony Konfiguráció',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(76, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Kész',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
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
                  _newBoxType = 'feeder';
                }
                _ensureValidSelectedSize();
              }

              final compatibleSizes = _getCompatibleSizeOptions();
              final displayedBoxes =
                  _activeHive?.boxes.reversed.toList() ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kaptár választó gombok (csak ha nincs konkrét kaptár átadva, legördülő menü NÉLKÜL)
                    if (widget.selectedHive == null &&
                        _repository.hives.length > 1) ...[
                      const Text(
                        'Válassz kaptárt:',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _repository.hives.map((h) {
                          final bool selected = h == _activeHive;
                          return SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selected
                                    ? Colors.amber
                                    : const Color(0xFF1E293B),
                                foregroundColor: selected
                                    ? Colors.black
                                    : Colors.white,
                                side: BorderSide(
                                  color: selected
                                      ? Colors.amberAccent
                                      : Colors.white24,
                                  width: selected ? 2.5 : 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _activeHive = h;
                                  _syncDefaultSizeWithHive();
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (h.hasExtraBoxes) ...[
                                    HiveTowerIcon(
                                      size: 16,
                                      color: selected
                                          ? Colors.black87
                                          : (h.requiresSpanifer
                                                ? Colors.orangeAccent
                                                : Colors.amberAccent),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    h.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_activeHive != null) ...[
                      // 1. ÚJ FIÓK VAGY KELLÉK HOZZÁADÁSA (BOXKESZTYŰ-BARÁT NAGY GOMBOK)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF162032),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.amberAccent.withAlpha(110),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Új elem hozzáadása (Boxkesztyű-barát):',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Fő kategória választó: [ Fiók ]  vs  [ Kellékek ]
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMainCategoryButton(
                                    id: 'box',
                                    label: 'Fiók',
                                    icon: Icons.layers,
                                    onTap: () {
                                      setState(() {
                                        _addCategory = 'box';
                                        if (!_isRealBox(_newBoxType)) {
                                          _newBoxType = 'honey';
                                        }
                                        _syncDefaultSizeWithHive();
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMainCategoryButton(
                                    id: 'accessory',
                                    label: 'Kellékek',
                                    icon: Icons.construction,
                                    onTap: () {
                                      setState(() {
                                        _addCategory = 'accessory';
                                        if (_isRealBox(_newBoxType)) {
                                          _newBoxType = 'feeder';
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            if (_addCategory == 'box') ...[
                              // 4 Fióktípus: Fészek, Lépépítő, Szaporító (Demaree), Méztéri
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 2.25,
                                children: _boxTypeOptions.map((opt) {
                                  final String id = opt['id'] as String;
                                  final bool selected = _newBoxType == id;
                                  final Color c = opt['color'] as Color;
                                  return _buildOptionTile(
                                    label: opt['label'] as String,
                                    icon: opt['icon'] as IconData,
                                    color: c,
                                    isSelected: selected,
                                    onTap: () {
                                      setState(() {
                                        _newBoxType = id;
                                        _syncDefaultSizeWithHive();
                                        _ensureValidSelectedSize();
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Kompatibilis fiókméret:',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (compatibleSizes.length <= 3)
                                Row(
                                  children: [
                                    for (int i = 0; i < compatibleSizes.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 10),
                                      Expanded(
                                        child: SizedBox(
                                          height: 52,
                                          child: _buildSizeButton(compatibleSizes[i]),
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              else
                                GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 2.8,
                                  children: compatibleSizes
                                      .map(_buildSizeButton)
                                      .toList(),
                                ),
                            ] else ...[
                              // Szokásos kellékek / tartozékok nagy gombokkal
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 2.25,
                                children: _getAccessoryOptions().map((opt) {
                                  final String id = opt['id'] as String;
                                  final bool selected = _newBoxType == id;
                                  final Color c = opt['color'] as Color;
                                  return _buildOptionTile(
                                    label: opt['label'] as String,
                                    icon: opt['icon'] as IconData,
                                    color: c,
                                    isSelected: selected,
                                    onTap: () =>
                                        setState(() => _newBoxType = id),
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Colors.tealAccent,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                ),
                                onPressed: _addNewElementToActiveHive,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_circle, size: 26),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Hozzáadás: ${_getSelectedElementLabel()}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 2. TORONY FELÉPÍTÉSE (NAGY FEL / LE / TÖRLÉS GOMBOKKAL)
                      Row(
                        children: [
                          const HiveTowerIcon(size: 18, color: Colors.amberAccent),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Torony felépítése (Fentről lefelé):',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _activeHive!.isAtMaxBoxCapacity
                                  ? Colors.red.withAlpha(55)
                                  : (_activeHive!.requiresSpanifer
                                        ? Colors.orange.withAlpha(55)
                                        : Colors.teal.withAlpha(45)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _activeHive!.isAtMaxBoxCapacity
                                    ? Colors.redAccent
                                    : (_activeHive!.requiresSpanifer
                                          ? Colors.orangeAccent
                                          : Colors.tealAccent),
                                width: 1.4,
                              ),
                            ),
                            child: Text(
                              '${_activeHive!.formattedBoxEquivalent} / 4 fiók',
                              style: TextStyle(
                                color: _activeHive!.isAtMaxBoxCapacity
                                    ? Colors.redAccent
                                    : (_activeHive!.requiresSpanifer
                                          ? Colors.orangeAccent
                                          : Colors.tealAccent),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_activeHive!.requiresSpanifer) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade900.withAlpha(90),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amberAccent,
                              width: 1.6,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amberAccent,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _activeHive!.isAtMaxBoxCapacity
                                      ? '⚠️ Maximális magasság (${_activeHive!.formattedBoxEquivalent} / 4 teljes fiók) elérve! Minimum spaniferes rögzítés kötelező!'
                                      : '⚠️ 1 teljes + 4 db 1/2-Dadant (3 teljes fiók) feletti torony (${_activeHive!.formattedBoxEquivalent} / 4 fiók): minimum spaniferes rögzítés szükséges!',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141428),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            if (displayedBoxes.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'A kaptár még nem tartalmaz fiókokat.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              for (var box in displayedBoxes)
                                _buildTowerBoxRow(box),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 3. CSALÁD STÁTUSZA (BOXKESZTYŰ-BARÁT SZÍNKÓD GOMBOK)
                      const Text(
                        'Család státusza (színkód):',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusButton(
                              'Zöld',
                              'green',
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildStatusButton(
                              'Sárga',
                              'yellow',
                              Colors.amber.shade700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildStatusButton(
                              'Narancs',
                              'orange',
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildStatusButton(
                              'Lila',
                              'purple',
                              Colors.purpleAccent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildStatusButton(
                              'Piros',
                              'red',
                              Colors.red,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 4. CSALÁD FUNKCIÓ & MESTERTERV (NAGY BOXKESZTYŰ-BARÁT GOMB, LEGÖRDÜLŐ NÉLKÜL)
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.amberAccent,
                            side: const BorderSide(
                              color: Colors.amber,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => FamilyFunctionScreen.open(
                            context,
                            _activeHive!,
                            _repository,
                          ),
                          icon: const Icon(Icons.workspace_premium, size: 26),
                          label: Text(
                            'Család funkció & Mesterterv (${_activeHive!.familyFunction})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSizeButton(Map<String, String> sz) {
    final String sId = sz['id']!;
    final bool selected = _newBoxSize == sId;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.amber : const Color(0xFF0F172A),
        foregroundColor: selected ? Colors.black : Colors.white,
        side: BorderSide(
          color: selected ? Colors.amberAccent : Colors.white24,
          width: selected ? 2.5 : 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () => setState(() => _newBoxSize = sId),
      child: Text(
        sz['label']!,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: selected ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildMainCategoryButton({
    required String id,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final bool isSelected = _addCategory == id;
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.amber : const Color(0xFF0F172A),
          foregroundColor: isSelected ? Colors.black : Colors.white70,
          side: BorderSide(
            color: isSelected ? Colors.amberAccent : Colors.white24,
            width: isSelected ? 2.5 : 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isSelected ? 4 : 1,
        ),
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 24,
          color: isSelected ? Colors.black : Colors.amberAccent,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bool darkText = isSelected &&
        (color == Colors.amberAccent ||
            color == Colors.amber ||
            color == Colors.tealAccent ||
            color == Colors.cyanAccent ||
            color == Colors.lightBlueAccent ||
            color == Colors.orangeAccent);

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : const Color(0xFF0F172A),
        foregroundColor: darkText ? Colors.black : Colors.white,
        side: BorderSide(
          color: isSelected ? Colors.white : color.withAlpha(150),
          width: isSelected ? 2.5 : 1.8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: isSelected ? 5 : 1,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: isSelected ? (darkText ? Colors.black : Colors.white) : color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? (darkText ? Colors.black : Colors.white)
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTowerBoxRow(BoxElement box) {
    final bool isBottom =
        box.type == 'bottom' || box.name.toLowerCase() == 'aljdeszka';
    final bool isRoof = isRoofBox(box);
    final bool isPollen = isPollenBox(box);
    final bool isFeeder = isFeederBox(box);

    final int rawIdx = _activeHive != null
        ? _activeHive!.boxes.indexOf(box)
        : -1;

    final bool canMoveUp =
        _activeHive != null &&
        !_activeHive!.isQuarantined &&
        !isBottom &&
        !isRoof &&
        !isPollen &&
        !isFeeder &&
        rawIdx != -1 &&
        rawIdx + 1 < _activeHive!.boxes.length &&
        !isRoofBox(_activeHive!.boxes[rawIdx + 1]) &&
        !isFeederBox(_activeHive!.boxes[rawIdx + 1]);

    final bool canMoveDown =
        _activeHive != null &&
        !_activeHive!.isQuarantined &&
        !isBottom &&
        !isRoof &&
        !isPollen &&
        !isFeeder &&
        rawIdx != -1 &&
        rawIdx - 1 >= 0 &&
        !isBottomBox(_activeHive!.boxes[rawIdx - 1]) &&
        !isPollenBox(_activeHive!.boxes[rawIdx - 1]);

    final Color boxColor = _getBoxColor(box);
    final String sizeText = _isRealBox(box.type) ? _formatSize(box.size) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: boxColor.withAlpha(140), width: 1.5),
        ),
        child: Row(
          children: [
            if (isFeeder)
              CandyIcon(
                size: 22,
                status: _activeHive?.feederStatus ?? 'green',
              )
            else
              Icon(_getBoxIcon(box), size: 22, color: boxColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _formatBoxTitle(box),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      BoxInfoButton(box: box, size: 15),
                      if (BoxHelpButton.hasHelp(box)) ...[
                        const SizedBox(width: 2),
                        BoxHelpButton(box: box, size: 15),
                      ],
                    ],
                  ),
                  if (sizeText.isNotEmpty)
                    Text(
                      sizeText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (isPollen)
              Switch(
                value: box.isActive,
                activeThumbColor: Colors.orange,
                activeTrackColor: Colors.orange.withAlpha(120),
                onChanged: (_activeHive?.isQuarantined == true)
                    ? null
                    : (val) {
                  if (val) {
                    void doEnable() {
                      _repository.toggleBoxActiveState(_activeHive!, box, true);
                      setState(() {});
                    }

                    void checkHoneyConflict() {
                      if (_activeHive!.hasHoneySuper) {
                        showPollenHoneyConflictDialog(
                          context: context,
                          hive: _activeHive!,
                          conflictType: 'enabling_pollen_with_honey',
                          onConfirm: doEnable,
                        );
                        return;
                      }
                      doEnable();
                    }

                    if (_activeHive!.isWeakOrSick ||
                        _activeHive!.isPoorPerformer) {
                      showWeakColonyWarningDialog(
                        context: context,
                        hive: _activeHive!,
                        actionTitle: 'Virágporgyűjtő bekapcsolása',
                        onConfirm: checkHoneyConflict,
                      );
                      return;
                    }

                    checkHoneyConflict();
                    return;
                  }
                  _repository.toggleBoxActiveState(_activeHive!, box, false);
                  setState(() {});
                },
              ),
            if (!isBottom && !isRoof && !isPollen && !isFeeder) ...[
              _buildGloveSquareIconBtn(
                icon: Icons.arrow_upward_rounded,
                color: canMoveUp ? Colors.amberAccent : Colors.white24,
                onTap: canMoveUp
                    ? () {
                        _repository.reorderBox(
                          _activeHive!,
                          box,
                          moveUp: true,
                        );
                        setState(() {});
                      }
                    : null,
              ),
              const SizedBox(width: 6),
              _buildGloveSquareIconBtn(
                icon: Icons.arrow_downward_rounded,
                color: canMoveDown ? Colors.amberAccent : Colors.white24,
                onTap: canMoveDown
                    ? () {
                        _repository.reorderBox(
                          _activeHive!,
                          box,
                          moveUp: false,
                        );
                        setState(() {});
                      }
                    : null,
              ),
              const SizedBox(width: 6),
            ],
            if (!isBottom)
              _buildGloveSquareIconBtn(
                icon: Icons.delete_outline_rounded,
                color: Colors.redAccent,
                bgColor: Colors.red.withAlpha(28),
                onTap: () => _removeElementFromActiveHive(box),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: Colors.white38,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGloveSquareIconBtn({
    required IconData icon,
    required Color color,
    Color? bgColor,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: bgColor ?? const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: onTap != null ? color.withAlpha(140) : Colors.white12,
                width: 1.4,
              ),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusButton(String label, String statusKey, Color color) {
    final bool isSelected = _activeHive?.status == statusKey;
    return SizedBox(
      height: 46,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _updateHiveStatus(statusKey),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withAlpha(45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: isSelected ? 2.5 : 1.2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
