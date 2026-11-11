import 'dart:io';

import 'package:flutter/material.dart';

import '../services/hive_repository.dart';
import 'server_config_screen.dart';

class SettingsScreen extends StatefulWidget {
  final HiveRepository repository;
  final String initialUrl;
  final String initialAnonKey;
  final bool initialAdvancedMode;
  final bool initialApEnabled;
  final String? initialServerFwPath;
  final String? initialMonitorFwPath;
  final ValueChanged<bool> onAdvancedModeChanged;
  final void Function(String url, String key, bool advMode) onConfigSaved;
  final Future<void> Function(
    bool apEnabled,
    String? serverFwPath,
    String? monitorFwPath,
  )
  onOtaSave;

  const SettingsScreen({
    super.key,
    required this.repository,
    required this.initialUrl,
    required this.initialAnonKey,
    required this.initialAdvancedMode,
    required this.initialApEnabled,
    required this.initialServerFwPath,
    required this.initialMonitorFwPath,
    required this.onAdvancedModeChanged,
    required this.onConfigSaved,
    required this.onOtaSave,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  late TextEditingController _keyController;
  late bool _isAdvancedMode;
  bool _isTesting = false;

  // OTA / Firmware állapotok
  late bool _apEnabled;
  String? _serverFwPath;
  String? _monitorFwPath;
  HttpServer? _localOtaServer;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _keyController = TextEditingController(text: widget.initialAnonKey);
    _isAdvancedMode = widget.initialAdvancedMode;
    _apEnabled = widget.initialApEnabled;
    _serverFwPath = widget.initialServerFwPath;
    _monitorFwPath = widget.initialMonitorFwPath;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _localOtaServer?.close(force: true);
    super.dispose();
  }

  Future<void> _manageLocalOtaServer(bool enable) async {
    await _localOtaServer?.close(force: true);
    _localOtaServer = null;

    if (!enable) return;

    try {
      _localOtaServer = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      _localOtaServer!.listen((HttpRequest request) async {
        final String path = request.uri.path;
        String? targetFile;

        if (path == '/server.bin') {
          targetFile = _serverFwPath;
        } else {
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amberAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  fileName,
                  style: TextStyle(
                    color: selectedPath != null
                        ? Colors.tealAccent
                        : Colors.white54,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selectedPath != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red, size: 16),
                  onPressed: onClear,
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: onBrowse,
                child: const Text('Tallózás', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOnline = widget.repository.isOnline;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        foregroundColor: Colors.amberAccent,
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.amberAccent, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rendszer Beállítások & Firmware (OTA)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isOnline
                  ? Colors.green.withAlpha(50)
                  : Colors.red.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOnline ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: isOnline ? Colors.greenAccent : Colors.redAccent,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  isOnline
                      ? 'Online'
                      : 'Offline (${widget.repository.offlineQueueLength})',
                  style: TextStyle(
                    color: isOnline ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- 0. SZERVER & RENDSZER KONFIGURÁCIÓ KÁRTYA ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141428),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF10b981).withAlpha(120),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.developer_board,
                        color: Color(0xFF10b981),
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ESP32 Szerver & Időjárás Konfig',
                        style: TextStyle(
                          color: Color(0xFF10b981),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Wi-Fi, AP, Időjárás-állomás, CAN busz, GSM/SIM, ntfy és felhő beállítások közvetlen szerkesztése.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10b981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ServerAndWeatherConfigScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune),
                      label: const Text(
                        'Szerver Konfigurációs Panel Megnyitása',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- 1. MEGJELENÍTÉSI BEÁLLÍTÁSOK ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141428),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Főképernyő',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Részletes GPS adatok sáv megjelenítése',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    value: _isAdvancedMode,
                    activeThumbColor: Colors.amber,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() => _isAdvancedMode = val);
                      widget.onAdvancedModeChanged(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- 2. FIRMWARE OTA FRISSÍTÉSI KÁRTYA ---
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
                    'Firmware Frissítés (Helyi OTA Fájlszerver)',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kapcsold be a hotspotot a telefonon, majd indítsd el a fájlszervert, hogy az ESP32 eszközök letölthessék a frissítést.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text(
                      'OTA Fájlszerver indítása (:8080)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _apEnabled
                          ? 'Aktív: a háttérben futó HTTP szerver kiszolgálja a fájlokat.'
                          : 'Kikapcsolva.',
                      style: TextStyle(
                        color: _apEnabled ? Colors.tealAccent : Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    value: _apEnabled,
                    activeThumbColor: Colors.tealAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() => _apEnabled = val);
                    },
                  ),
                  if (_apEnabled) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24, height: 16),
                    const SizedBox(height: 4),
                    _buildFileSelectorBar(
                      title: 'Szerver Firmware (.bin)',
                      subtitle: 'TTGO T-SIM7000G frissítés',
                      icon: Icons.dns,
                      selectedPath: _serverFwPath,
                      onBrowse: () => _selectFirmwareFile(isServer: true),
                      onClear: () => setState(() => _serverFwPath = null),
                    ),
                    const SizedBox(height: 12),
                    _buildFileSelectorBar(
                      title: 'Kaptármonitor Firmware (.bin)',
                      subtitle: 'ESP32-S3-MINI-1U frissítés',
                      icon: Icons.memory,
                      selectedPath: _monitorFwPath,
                      onBrowse: () => _selectFirmwareFile(isServer: false),
                      onClear: () => setState(() => _monitorFwPath = null),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- 3. SUPABASE BEÁLLÍTÁSOK ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141428),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Supabase Projekt & Szerver Kapcsolat',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Supabase URL',
                      labelStyle: const TextStyle(color: Colors.amber),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Supabase Anon Key',
                      labelStyle: const TextStyle(color: Colors.amber),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // --- KÉT GOMB EGYMÁS MELLETT ---
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.tealAccent,
                              side: const BorderSide(color: Colors.tealAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isTesting
                                ? null
                                : () async {
                                    setState(() => _isTesting = true);
                                    await widget.repository.setSupabaseConfig(
                                      _urlController.text,
                                      _keyController.text,
                                    );
                                    final result = await widget.repository
                                        .testSupabaseConnection();
                                    if (mounted) {
                                      setState(() => _isTesting = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(result['message']),
                                              backgroundColor: result['success']
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          );
                                    }
                                  },
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.tealAccent,
                                    ),
                                  )
                                : const Icon(
                                    Icons.wifi_protected_setup,
                                    size: 16,
                                  ),
                            label: const Text(
                              'Teszt',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              final trimmedUrl = _urlController.text.trim();
                              final trimmedKey = _keyController.text.trim();

                              widget.onConfigSaved(
                                trimmedUrl,
                                trimmedKey,
                                _isAdvancedMode,
                              );
                              widget.repository.setSupabaseConfig(
                                trimmedUrl,
                                trimmedKey,
                              );

                              await _manageLocalOtaServer(_apEnabled);
                              await widget.onOtaSave(
                                _apEnabled,
                                _serverFwPath,
                                _monitorFwPath,
                              );

                              widget.repository.syncWithSupabase();
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Beállítások elmentve és szinkronizálás indítva.',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text(
                              'Mentés',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
