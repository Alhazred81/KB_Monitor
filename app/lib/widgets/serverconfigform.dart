import 'package:flutter/material.dart';

class ServerConfigForm extends StatefulWidget {
  final String
  section; // 'all', 'wifi', 'sensors', 'gsm', 'iot', 'reports', 'diag'

  const ServerConfigForm({super.key, this.section = 'all'});

  @override
  State<ServerConfigForm> createState() => _ServerConfigFormState();
}

class _ServerConfigFormState extends State<ServerConfigForm> {
  final _apSsidController = TextEditingController(text: 'Server-AP');
  final _apPassController = TextEditingController(text: '12345678');
  final _staSsidController = TextEditingController();
  final _staPassController = TextEditingController();
  final _simPinController = TextEditingController();
  final _ntfyTopicController = TextEditingController(
    text: 'kb_sim7000g_balazs',
  );
  final _supaUrlController = TextEditingController(
    text: 'nlpfnnkinesxgxfxndnx.supabase.co',
  );
  final _supaKeyController = TextEditingController();
  final _reportTimesController = TextEditingController(text: '08:00,20:00');
  final _windThController = TextEditingController(text: '60');
  final _rainThController = TextEditingController(text: '20');
  final _rs485BaudController = TextEditingController(text: '9600');

  bool _dataConnActive = true;
  bool _hideAp = false;
  bool _ntfyStartup = true;
  String _selectedCommMode = 'wireless';
  bool _sensWindSpeed = true,
      _sensWindDir = true,
      _sensSht = true,
      _sensRain = true,
      _sensMpu = true,
      _sensBmp = true,
      _sensLtr = true;

  @override
  void dispose() {
    _apSsidController.dispose();
    _apPassController.dispose();
    _staSsidController.dispose();
    _staPassController.dispose();
    _simPinController.dispose();
    _ntfyTopicController.dispose();
    _supaUrlController.dispose();
    _supaKeyController.dispose();
    _reportTimesController.dispose();
    _windThController.dispose();
    _rainThController.dispose();
    _rs485BaudController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (widget.section == 'all' || widget.section == 'wifi') ...[
          _buildSectionHeader('Kommunikációs Mód'),
          Card(
            color: const Color(0xFF1f2937),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text(
                      'Vezeték nélküli (ESP-NOW / LoRa)',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: 'wireless',
                    groupValue: _selectedCommMode,
                    onChanged: (val) =>
                        setState(() => _selectedCommMode = val ?? 'wireless'),
                  ),
                  RadioListTile<String>(
                    title: const Text(
                      'Vezetékes CAN Busz (TJA1043)',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: 'wired_can',
                    groupValue: _selectedCommMode,
                    onChanged: (val) =>
                        setState(() => _selectedCommMode = val ?? 'wired_can'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('Hálózati & Wi-Fi Beállítások'),
          Card(
            color: const Color(0xFF1f2937),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Rejtett AP',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _hideAp,
                    onChanged: (v) => setState(() => _hideAp = v),
                  ),
                  TextField(
                    controller: _staSsidController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('Otthoni Wi-Fi SSID'),
                  ),
                  TextField(
                    controller: _staPassController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('Otthoni Wi-Fi Jelszó'),
                  ),
                  TextField(
                    controller: _apSsidController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('Hotspot AP SSID'),
                  ),
                  TextField(
                    controller: _apPassController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('Hotspot AP Jelszó'),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (widget.section == 'all' || widget.section == 'sensors') ...[
          _buildSectionHeader('Időjárás-állomás Szenzorok & RS485'),
          Card(
            color: const Color(0xFF1f2937),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _rs485BaudController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('RS485 Baudrate'),
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'Szélsebesség',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _sensWindSpeed,
                    onChanged: (v) => setState(() => _sensWindSpeed = v!),
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'Szélirány',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _sensWindDir,
                    onChanged: (v) => setState(() => _sensWindDir = v!),
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'Hőmérséklet / Pára (SHT)',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _sensSht,
                    onChanged: (v) => setState(() => _sensSht = v!),
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'Csapadékmérő',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _sensRain,
                    onChanged: (v) => setState(() => _sensRain = v!),
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'MPU6050 (Dőlés / Rezgés)',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _sensMpu,
                    onChanged: (v) => setState(() => _sensMpu = v!),
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'BMP280 (Légnyomás)',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _sensBmp,
                    onChanged: (v) => setState(() => _sensBmp = v!),
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'LTR390 (UV / Fényerő)',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _sensLtr,
                    onChanged: (v) => setState(() => _sensLtr = v!),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (widget.section == 'all' || widget.section == 'gsm') ...[
          _buildSectionHeader('GSM & LTE Adatkapcsolat'),
          Card(
            color: const Color(0xFF1f2937),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'GPRS Engedélyezése',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _dataConnActive,
                    onChanged: (v) => setState(() => _dataConnActive = v),
                  ),
                  TextField(
                    controller: _simPinController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('SIM PIN kód'),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (widget.section == 'all' || widget.section == 'iot') ...[
          _buildSectionHeader('IoT & Felhő Integráció'),
          Card(
            color: const Color(0xFF1f2937),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _supaUrlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('Supabase URL'),
                  ),
                  TextField(
                    controller: _supaKeyController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('Supabase Key'),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (widget.section == 'all' || widget.section == 'reports') ...[
          _buildSectionHeader('Ütemezett Jelentések & ntfy'),
          Card(
            color: const Color(0xFF1f2937),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Indulási ntfy értesítés (Boot teszt)',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _ntfyStartup,
                    onChanged: (v) => setState(() => _ntfyStartup = v),
                  ),
                  TextField(
                    controller: _ntfyTopicController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('ntfy.sh Topic'),
                  ),
                  TextField(
                    controller: _reportTimesController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('Jelentési idők (pl. 08:00,20:00)'),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (widget.section == 'all' || widget.section == 'diag') ...[
          _buildSectionHeader('Diagnosztika & Rendszernaplók'),
          Card(
            color: const Color(0xFF1f2937),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Rendszer futásidő / Diag adatok letöltése:',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download),
                    label: const Text('Diag Log Letöltése (Serial Dump)'),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10b981),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Beállítások mentve!')),
            );
          },
          child: const Text(
            '💾 Mentés az ESP32-re',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, top: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF3b82f6),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF3b82f6)),
      ),
    );
  }
}
