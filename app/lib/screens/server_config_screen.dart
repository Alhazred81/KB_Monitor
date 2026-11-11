import 'package:flutter/material.dart';

import '../widgets/serverconfigform.dart';

class ServerAndWeatherConfigScreen extends StatefulWidget {
  final int initialTabIndex;

  const ServerAndWeatherConfigScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ServerAndWeatherConfigScreen> createState() =>
      _ServerAndWeatherConfigScreenState();
}

class _ServerAndWeatherConfigScreenState
    extends State<ServerAndWeatherConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isWeatherExpanded = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7, // 7 különböző fül a témák szerint (mint a weboldalon)
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: const Text('Szerver & Rendszer Konfig'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable:
              true, // Mivel sok tab van, oldalt iranyban lathatóan görgethető
          indicatorColor: const Color(0xFF10b981),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Áttekintés'),
            Tab(icon: Icon(Icons.wifi), text: 'Wi-Fi & AP'),
            Tab(icon: Icon(Icons.sensors), text: 'Szenzorok'),
            Tab(icon: Icon(Icons.cell_tower), text: 'GSM & SIM'),
            Tab(icon: Icon(Icons.cloud_sync), text: 'IoT / Felhő'),
            Tab(icon: Icon(Icons.notifications), text: 'Jelentések'),
            Tab(icon: Icon(Icons.bug_report), text: 'Diagnosztika'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── 1. ÁTTEKINTÉS & IDŐJÁRÁS-ÁLLOMÁS FÜL ───
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                color: const Color(0xFF1f2937),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Szerver Státusz',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Divider(color: Colors.grey),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle,
                          color: Colors.green,
                          size: 12,
                        ),
                        title: Text(
                          'Modem & Adatkapcsolat',
                          style: TextStyle(color: Colors.white70),
                        ),
                        trailing: Text(
                          'Aktív (IP: 10.0.0.2)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle,
                          color: Colors.green,
                          size: 12,
                        ),
                        title: Text(
                          'Supabase Szinkronizáció',
                          style: TextStyle(color: Colors.white70),
                        ),
                        trailing: Text(
                          'Szinkronizálva',
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () {
                  setState(() {
                    _isWeatherExpanded = !_isWeatherExpanded;
                  });
                },
                child: Card(
                  color: const Color(0xFF1f2937),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.cloud_queue,
                                  color: Colors.blueAccent,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Időjárás-állomás',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              _isWeatherExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                        if (_isWeatherExpanded) ...[
                          const Divider(color: Colors.grey, height: 24),
                          const Text(
                            'Aktuális Szenzoradatok:',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          _buildSensorRow(
                            Icons.thermostat,
                            'Hőmérséklet',
                            '28.1 °C',
                            Colors.orange,
                          ),
                          _buildSensorRow(
                            Icons.water_drop,
                            'Páratartalom',
                            '55 %',
                            Colors.blue,
                          ),
                          _buildSensorRow(
                            Icons.speed,
                            'Légnyomás',
                            '1013.2 hPa',
                            Colors.purple,
                          ),
                          _buildSensorRow(
                            Icons.air,
                            'Szélsebesség & Irány',
                            '14 km/h (ÉNY)',
                            Colors.tealAccent,
                          ),
                          _buildSensorRow(
                            Icons.wb_sunny,
                            'UV Index / Fény',
                            'UVI 2.4 | 4500 lx',
                            Colors.amber,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3b82f6),
                              ),
                              onPressed: () => _tabController.animateTo(
                                2,
                              ), // Átugrás a Szenzorok fülre
                              icon: const Icon(
                                Icons.settings_applications,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Szenzor Beállítások Szerkesztése',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ─── 2. FÜL: WI-FI & AP BEÁLLÍTÁSOK ───
          const ServerConfigForm(section: 'wifi'),

          // ─── 3. FÜL: SZENZOROK & RS485 ───
          const ServerConfigForm(section: 'sensors'),

          // ─── 4. FÜL: GSM & SIM ───
          const ServerConfigForm(section: 'gsm'),

          // ─── 5. FÜL: IOT & SUPABASE ───
          const ServerConfigForm(section: 'iot'),

          // ─── 6. FÜL: JELENTÉSEK & NTFY ───
          const ServerConfigForm(section: 'reports'),

          // ─── 7. FÜL: DIAGNOSZTIKA & LOGOK ───
          const ServerConfigForm(section: 'diag'),
        ],
      ),
    );
  }

  Widget _buildSensorRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white70)),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
