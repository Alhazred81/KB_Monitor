import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../services/treatment_adviser.dart';
import '../screens/frame_analysis_screen.dart';

class HiveSetupDialog extends StatefulWidget {
  final HiveData? selectedHive;
  const HiveSetupDialog({super.key, this.selectedHive});

  @override
  State<HiveSetupDialog> createState() => _HiveSetupDialogState();
}

class _HiveSetupDialogState extends State<HiveSetupDialog> {
  final HiveRepository _repository = HiveRepository.instance;
  late TextEditingController _urlController;
  late TextEditingController _anonKeyController;
  HiveData? _activeHive;
  String _selectedPlan = 'petes_mesterterv';
  bool _isApiKeyVisible = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _repository.supabaseUrl);
    _anonKeyController = TextEditingController(
      text: _repository.supabaseAnonKey,
    );
    _activeHive =
        widget.selectedHive ??
        (_repository.hives.isNotEmpty ? _repository.hives.first : null);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
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
          Icon(Icons.settings, color: Colors.amberAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Beállítások és Mestertervek',
              style: TextStyle(color: Colors.amberAccent, fontSize: 17),
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. SUPABASE BEÁLLÍTÁSOK
                  const Text(
                    'Supabase kapcsolat:',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Project URL (https://xyz.supabase.co)',
                      labelStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: Color(0xFF2C2C2C),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _anonKeyController,
                    obscureText: !_isApiKeyVisible,
                    enableInteractiveSelection: true,
                    contextMenuBuilder: (context, editableTextState) {
                      final List<ContextMenuButtonItem> buttonItems =
                          editableTextState.contextMenuButtonItems;
                      buttonItems.removeWhere(
                        (item) =>
                            item.type == ContextMenuButtonType.copy ||
                            item.type == ContextMenuButtonType.cut,
                      );
                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: editableTextState.contextMenuAnchors,
                        buttonItems: buttonItems,
                      );
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Publishable / Anon API Key',
                      labelStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isApiKeyVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.amberAccent,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isApiKeyVisible = !_isApiKeyVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _repository.syncStatusText,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _repository.isSyncing
                              ? null
                              : () async {
                                  await _repository.setSupabaseConfig(
                                    _urlController.text,
                                    _anonKeyController.text,
                                  );
                                  await _repository.syncWithSupabase();
                                },
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text(
                            'Adatbázis szinkron',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _repository.pendingFrameAnalyses.isEmpty
                              ? null
                              : () async {
                                  final count = await _repository
                                      .syncPendingFramesAndCleanup();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$count keretfotó szinkronizálva és törölve a telefonról.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.cloud_upload, size: 16),
                          label: Text(
                            'Képek (${_repository.pendingFrameAnalyses.length})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(color: Colors.white24, height: 24),

                  // 2. HANGYASAV IDŐJÁRÁS-ELLENŐRZÉS AZ IDŐJÁRÁS-ÁLLOMÁS ALAPJÁN
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

                  // 3. KAPTÁRRA VONATKOZÓ MŰVELETEK (Aljdeszka, Pollengyűjtő, Keretfotózás, Mestertervek)
                  if (_repository.hives.isNotEmpty) ...[
                    const Divider(color: Colors.white24, height: 24),
                    const Text(
                      'Kiválasztott kaptár műveletei:',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    DropdownButton<HiveData>(
                      value: _activeHive,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      items: _repository.hives
                          .map(
                            (h) => DropdownMenuItem(
                              value: h,
                              child: Text(
                                '${h.name} (Szirup: ${h.syrupLiters.toStringAsFixed(1)}L)',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _activeHive = val),
                    ),
                    if (_activeHive != null) ...[
                      // Aljdeszka és pollengyűjtő csúszkák
                      for (var box in _activeHive!.boxes.where(
                        (b) => b.type == 'bottom' || b.type == 'pollen_trap',
                      ))
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.amber,
                          title: Text(
                            box.type == 'bottom'
                                ? 'Aljdeszka betolva (Varroa kontroll)'
                                : 'Pollengyűjtő bekapcsolva',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            box.isVarroaCheckDue
                                ? 'FIGYELEM: 3 nap letelt, ellenőrizd az aljdeszkát!'
                                : (box.isActive
                                      ? 'Aktív'
                                      : 'Alapállapot (Kikapcsolva / Nincs bent)'),
                            style: TextStyle(
                              color: box.isVarroaCheckDue
                                  ? Colors.redAccent
                                  : Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          value: box.isActive,
                          onChanged: (val) {
                            _repository.toggleBoxActiveState(
                              _activeHive!,
                              box,
                              val,
                            );
                            setState(() {});
                          },
                        ),

                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    FrameAnalysisScreen(hive: _activeHive!),
                              ),
                            );
                          },
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text(
                            'Fészekkeret fotós elemzés indítása',
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Text(
                        'Mesterterv / Kezelés indítása:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<String>(
                        value: _selectedPlan,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'petes_mesterterv',
                            child: Text(
                              'Petés Anyanevelési Mesterterv (Zsidei)',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'alcas_mesterterv',
                            child: Text(
                              'Álcás Anyanevelési Mesterterv (Zsidei)',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'grumpy_cat',
                            child: Text(
                              'Anyásítás: "Grumpy cat - do not touch"',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'oxalsav_egyszeri',
                            child: Text('Oxálsavas egyszeri kezelés'),
                          ),
                          DropdownMenuItem(
                            value: 'oxalsav_sorozat',
                            child: Text('Oxálsavas sorozatkezelés (21-24 nap)'),
                          ),
                          DropdownMenuItem(
                            value: 'hereskeret',
                            child: Text(
                              'Heréskeret ciklus (Kivágás: 21-23. nap)',
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPlan = val);
                          }
                        },
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            _repository.schedulePlanForHive(
                              _activeHive!.id,
                              _selectedPlan,
                              DateTime.now(),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Terv ütemezve és naplózva a naptárba!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: const Text('Ütemezés indítása mától'),
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
}
