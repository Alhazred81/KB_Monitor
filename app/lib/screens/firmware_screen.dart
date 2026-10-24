import 'dart:io';

import 'package:flutter/material.dart';

class FirmwareScreen extends StatefulWidget {
  final bool initialApEnabled;
  final String? initialServerFwPath;
  final String? initialMonitorFwPath;
  final Future<void> Function(
    bool apEnabled,
    String? serverFwPath,
    String? monitorFwPath,
  )
  onSave;

  const FirmwareScreen({
    super.key,
    required this.initialApEnabled,
    required this.initialServerFwPath,
    required this.initialMonitorFwPath,
    required this.onSave,
  });

  @override
  State<FirmwareScreen> createState() => _FirmwareScreenState();
}

class _FirmwareScreenState extends State<FirmwareScreen> {
  late bool _apEnabled;
  String? _serverFwPath;
  String? _monitorFwPath;
  HttpServer? _localOtaServer;

  @override
  void initState() {
    super.initState();
    _apEnabled = widget.initialApEnabled;
    _serverFwPath = widget.initialServerFwPath;
    _monitorFwPath = widget.initialMonitorFwPath;
  }

  @override
  void dispose() {
    _localOtaServer?.close(force: true);
    super.dispose();
  }

  Future<void> _manageLocalOtaServer(bool enable) async {
    await _localOtaServer?.close(force: true);
    _localOtaServer = null;

    if (!enable) return;

    try {
      // Helyi HTTP szerver indítása a 8080-as porton
      _localOtaServer = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      _localOtaServer!.listen((HttpRequest request) async {
        final String path = request.uri.path;
        String? targetFile;

        if (path == '/server.bin') {
          targetFile = _serverFwPath;
        } else {
          // Alapértelmezett végpont a kaptármonitoroknak
          targetFile = _monitorFwPath ?? _serverFwPath;
        }

        if (targetFile != null && await File(targetFile).exists()) {
          final file = File(targetFile);
          request.response.headers.contentType = ContentType.binary;
          request.response.contentLength = await file.length();
          await request.response.addStream(file.openRead());
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('Firmware binaris nem talalhato.');
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint('OTA HTTP szerver hiba: $e');
    }
  }

  Future<void> _selectFirmwareFile({required bool isServer}) async {
    final TextEditingController pathCtrl = TextEditingController(
      text: isServer
          ? (_serverFwPath ?? '/storage/emulated/0/Download/server_fw.bin')
          : (_monitorFwPath ?? '/storage/emulated/0/Download/monitor_fw.bin'),
    );

    final String? chosenPath = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141428),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            isServer
                ? 'Szerver Firmware (.bin) kiválasztása'
                : 'Kaptármonitor Firmware (.bin) kiválasztása',
            style: const TextStyle(color: Colors.amberAccent, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add meg vagy válaszd ki a telefonon lévő .bin fájl elérési útját:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pathCtrl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  labelText: 'Fájl elérési útja',
                  labelStyle: const TextStyle(color: Colors.tealAccent),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mégse', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, pathCtrl.text.trim()),
              child: const Text('Kiválasztás'),
            ),
          ],
        );
      },
    );

    if (chosenPath != null && chosenPath.isNotEmpty) {
      setState(() {
        if (isServer) {
          _serverFwPath = chosenPath;
        } else {
          _monitorFwPath = chosenPath;
        }
      });
    }
  }

  Widget _buildFileSelectorBar({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? selectedPath,
    required VoidCallback onBrowse,
    required VoidCallback onClear,
  }) {
    final String fileName = (selectedPath != null && selectedPath.isNotEmpty)
        ? selectedPath.split('/').last
        : 'Nincs fájl kiválasztva';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141428),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amberAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onBrowse,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selectedPath != null
                      ? Colors.tealAccent.withAlpha(140)
                      : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedPath != null
                        ? Icons.insert_drive_file
                        : Icons.folder_open,
                    color: selectedPath != null
                        ? Colors.tealAccent
                        : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            color: selectedPath != null
                                ? Colors.white
                                : Colors.white54,
                            fontWeight: selectedPath != null
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selectedPath != null)
                          Text(
                            selectedPath,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (selectedPath != null)
                    IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      tooltip: 'Törlés',
                      onPressed: onClear,
                    ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: onBrowse,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text(
                      'Tallózás',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        foregroundColor: Colors.tealAccent,
        title: const Row(
          children: [
            Icon(Icons.system_update_alt, color: Colors.tealAccent, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Firmware Frissítés (OTA)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141428),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _apEnabled
                            ? Colors.tealAccent.withAlpha(120)
                            : Colors.white12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Helyi Hotspot & OTA Fájlszerver',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile(
                          title: const Text(
                            'OTA Fájlszerver indítása (:8080)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            _apEnabled
                                ? 'Aktív: a háttérben futó HTTP szerver azonnal kiszolgálja a .bin fájlokat, amint a kliens rácsatlakozik.'
                                : 'Kikapcsolva: a szerver inaktív.',
                            style: TextStyle(
                              color: _apEnabled
                                  ? Colors.tealAccent
                                  : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          value: _apEnabled,
                          activeThumbColor: Colors.tealAccent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setState(() => _apEnabled = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildFileSelectorBar(
                    title: 'Szerver Firmware (.bin)',
                    subtitle: 'A központi szerver (TTGO T-SIM7000G) frissítési fájlja.',
                    icon: Icons.dns,
                    selectedPath: _serverFwPath,
                    onBrowse: () => _selectFirmwareFile(isServer: true),
                    onClear: () => setState(() => _serverFwPath = null),
                  ),
                  const SizedBox(height: 20),
                  _buildFileSelectorBar(
                    title: 'Kliens / Kaptármonitor Firmware (.bin)',
                    subtitle: 'A kopogtatásra ébredő kaptármonitorok (ESP32-S3-MINI-1U) által letöltendő fájl.',
                    icon: Icons.memory,
                    selectedPath: _monitorFwPath,
                    onBrowse: () => _selectFirmwareFile(isServer: false),
                    onClear: () => setState(() => _monitorFwPath = null),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF141428),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Mégse'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          // HTTP szerver vezérlése a mentéskor
                          await _manageLocalOtaServer(_apEnabled);
                          await widget.onSave(
                            _apEnabled,
                            _serverFwPath,
                            _monitorFwPath,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _apEnabled
                                      ? 'Helyi OTA fájlszerver elindult a :8080 porton!'
                                      : 'Firmware beállítások elmentve.',
                                ),
                                backgroundColor: _apEnabled
                                    ? Colors.teal.shade700
                                    : Colors.green,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const Text(
                          'OK',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
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
}
