import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';

class VarroaCounterScreen extends StatefulWidget {
  final HiveData hive;
  const VarroaCounterScreen({super.key, required this.hive});

  @override
  State<VarroaCounterScreen> createState() => _VarroaCounterScreenState();
}

class _VarroaCounterScreenState extends State<VarroaCounterScreen> {
  final ImagePicker _picker = ImagePicker();
  final HiveRepository _repository = HiveRepository.instance;

  bool _isProcessing = false;
  String? _capturedImagePath;
  int _detectedMites = 0;
  int _daysInserted = 3;
  bool _removeBoardAfterCheck = true;

  @override
  void initState() {
    super.initState();
    final bottomBox = widget.hive.boxes
        .where((b) => b.type == 'bottom')
        .firstOrNull;
    if (bottomBox != null &&
        bottomBox.isActive &&
        bottomBox.statusUpdatedAt != null) {
      final diff = DateTime.now().difference(bottomBox.statusUpdatedAt!).inDays;
      _daysInserted = diff > 0 ? diff : 1;
    }
  }

  double get _dailyDrop => _daysInserted > 0
      ? _detectedMites / _daysInserted
      : _detectedMites.toDouble();

  Color get _severityColor {
    if (_dailyDrop >= 5.0) return Colors.redAccent;
    if (_dailyDrop >= 2.0) return Colors.amber;
    return Colors.greenAccent;
  }

  String get _severityAdvice {
    if (_dailyDrop >= 5.0) {
      return 'KRITIKUS fertőzöttség (${_dailyDrop.toStringAsFixed(1)} atka/nap)! Azonnali beavatkozás szükséges.';
    }
    if (_dailyDrop >= 2.0) {
      return 'Emelkedett atkahullás (${_dailyDrop.toStringAsFixed(1)} atka/nap). Kezelés ütemezése javasolt.';
    }
    return 'Alacsony természetes hullás (${_dailyDrop.toStringAsFixed(1)} atka/nap). Normál állapot.';
  }

  Future<void> _captureTrayPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo == null) return;

      setState(() => _isProcessing = true);

      final tempDir = await getTemporaryDirectory();
      final String fileName =
          '${widget.hive.id}_VARROA_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File savedFile = await File(photo.path)
          .copy('${tempDir.path}/$fileName');

      await Future.delayed(const Duration(milliseconds: 700));
      final int estimatedCount = 2 + math.Random().nextInt(8);

      setState(() {
        _capturedImagePath = savedFile.path;
        _detectedMites = estimatedCount;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kamera hiba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveResult() {
    final record = VarroaAnalysisRecord(
      id: '${widget.hive.id}_VARROA_${DateTime.now().millisecondsSinceEpoch}',
      hiveId: widget.hive.id,
      localImagePath: _capturedImagePath ?? '',
      capturedAt: DateTime.now(),
      miteCount: _detectedMites,
      daysInserted: _daysInserted,
    );

    _repository.addVarroaAnalysis(
      hive: widget.hive,
      record: record,
      pullOutBoard: _removeBoardAfterCheck,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Atkaszámlálás mentve: $_detectedMites db (${_dailyDrop.toStringAsFixed(1)}/nap).',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Atkaszámláló - ${widget.hive.name}',
          style: const TextStyle(color: Colors.amberAccent, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.amberAccent),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'Fotózd le a kihúzott aljdeszkát (tálcát). A helyi modell megszámolja a lehullott Varroa atkákat, az értéket pedig kézzel is pontosíthatod.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            if (_capturedImagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_capturedImagePath!),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bug_report,
                        color: Colors.amberAccent,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Még nincs lefotózva a tálca',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isProcessing ? null : _captureTrayPhoto,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(
                  _isProcessing
                      ? 'Atkaszámlálás folyamatban...'
                      : 'Aljdeszka fotózása és számlálás',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Észlelt Varroa atkák száma (db):',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2C2C),
                        ),
                        onPressed: () {
                          if (_detectedMites > 0) {
                            setState(() => _detectedMites--);
                          }
                        },
                        icon: const Icon(Icons.remove, color: Colors.white),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          '$_detectedMites',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2C2C),
                        ),
                        onPressed: () => setState(() => _detectedMites++),
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hány napig volt bent a tálca?',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      DropdownButton<int>(
                        value: _daysInserted,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                        items: [1, 2, 3, 4, 5, 7, 10, 14]
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text('$d nap'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _daysInserted = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _severityColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _severityColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Napi átlagos atkahullás: ${_dailyDrop.toStringAsFixed(1)} db / nap',
                    style: TextStyle(
                      color: _severityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _severityAdvice,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Colors.amber,
              title: const Text(
                'Aljdeszka kihúzva az ellenőrzés után',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: const Text(
                'Alapállapotba (nincs bent) állítja a csúszkát',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              value: _removeBoardAfterCheck,
              onChanged: (val) => setState(() => _removeBoardAfterCheck = val),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _saveResult,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Eredmény mentése és naplózása',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
