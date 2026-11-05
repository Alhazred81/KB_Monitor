import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../services/treatment_adviser.dart';

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
  String _newBoxSize = 'hunor';

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

  bool _isRealBox(String type) {
    return type == 'brood_box' || type == 'nest' || type == 'honey';
  }

  bool _isBroodBox(String type) {
    return type == 'brood_box' || type == 'nest';
  }

  bool _checkCompatibility(String existingSize, String newSize) {
    final trio = ['nb', 'hunor', 'fel_nb'];
    if (trio.contains(existingSize) && trio.contains(newSize)) {
      return true;
    }
    if (existingSize == newSize) {
      return true;
    }
    return false;
  }

  void _addNewElementToActiveHive() {
    if (_activeHive == null) return;

    if (_isRealBox(_newBoxType)) {
      final primaryBroodBox = _activeHive!.boxes.firstWhere(
        (b) => _isBroodBox(b.type),
        orElse: () => BoxElement(name: '', code: '', type: '', size: 'hunor'),
      );

      if (primaryBroodBox.size.isNotEmpty &&
          !_checkCompatibility(primaryBroodBox.size, _newBoxSize)) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Kompatibilitási figyelmeztetés',
              style: TextStyle(color: Colors.redAccent),
            ),
            content: Text(
              'A kiválasztott méret (${_newBoxSize.toUpperCase()}) nem kompatibilis a meglévő fészekfiók méretével (${primaryBroodBox.size.toUpperCase()}).\n\nMegjegyzés: Az NB, Hunor és 1/2 NB családok kompatibilisek egymással, de a Langstroth és Dadant rendszerek nem keverhetők szabadon.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Megértettem',
                  style: TextStyle(color: Colors.amber),
                ),
              ),
            ],
          ),
        );
        return;
      }
    }

    String boxName = 'Elem';
    if (_newBoxType == 'brood_box') boxName = 'Fészekfiók';
    if (_newBoxType == 'honey') boxName = 'Méztér';
    if (_newBoxType == 'feeder') boxName = 'Etető';
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
          content: Text('Az aljdeszkát nem lehet törölni.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isBroodBox(box.type)) {
      int broodBoxCount = _activeHive!.boxes
          .where((b) => _isBroodBox(b.type))
          .length;
      if (broodBoxCount <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Az elsődleges fészekfiókot nem törölheted, mielőtt lenne másik.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

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
    _activeHive!.familyFunction = _selectedFunction;
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

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.tune, color: Colors.amberAccent),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kaptár & Torony Konfiguráció',
              style: TextStyle(color: Colors.amberAccent, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: _repository,
            builder: (context, _) {
              if (_activeHive != null &&
                  !_repository.hives.contains(_activeHive)) {
                _activeHive = _repository.hives.isNotEmpty
                    ? _repository.hives.first
                    : null;
              }

              final realBoxes =
                  _activeHive?.boxes
                      .where((b) => _isRealBox(b.type))
                      .toList() ??
                  [];
              final accessories =
                  _activeHive?.boxes
                      .where((b) => !_isRealBox(b.type))
                      .toList() ??
                  [];

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
                      const Text(
                        'Fiókok:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141428),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            for (var box in realBoxes)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _isBroodBox(box.type)
                                            ? Icons.hive
                                            : Icons.inventory_2,
                                        size: 16,
                                        color: _isBroodBox(box.type)
                                            ? Colors.amberAccent
                                            : Colors.amber,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${box.name} (${box.size})',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!_isBroodBox(box.type) ||
                                      realBoxes
                                              .where((b) => _isBroodBox(b.type))
                                              .length >
                                          1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          _removeElementFromActiveHive(box),
                                    )
                                  else
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Fő fészek',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Text(
                        'Tartozékok:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141428),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            for (var acc in accessories)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.extension,
                                        size: 16,
                                        color: Colors.tealAccent,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        acc.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (acc.type != 'bottom')
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          _removeElementFromActiveHive(acc),
                                    )
                                  else
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Alap',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
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
                              items: const [
                                DropdownMenuItem(
                                  value: 'brood_box',
                                  child: Text('Fészekfiók'),
                                ),
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
                                  child: Text('Virágporgyűjtő'),
                                ),
                                DropdownMenuItem(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bezárás', style: TextStyle(color: Colors.grey)),
        ),
      ],
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
        DropdownMenuItem(value: 'szezon végén', child: Text('Szezon végén')),
        DropdownMenuItem(value: 'Hans', child: Text('Hans')),
      ];
    }
  }
}
