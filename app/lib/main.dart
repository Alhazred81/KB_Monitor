import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Állapotsor és navigációs sáv sötét témához igazítása
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const HiveMonitorApp());
}

class HiveMonitorApp extends StatelessWidget {
  const HiveMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaptármonitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: Colors.amber,
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.amberAccent,
          surface: Color(0xFF141428),
        ),
        useMaterial3: true,
      ),
      home: const MainWrapperScreen(),
    );
  }
}

class MainWrapperScreen extends StatelessWidget {
  const MainWrapperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        title: const Text(
          'Kaptármonitor',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          // --- FIRMWARE IKON ÉS FELIRAT (Teljes képernyős almenü) ---
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FirmwareScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
            icon: const Icon(
              Icons.system_update_alt,
              color: Colors.amber,
              size: 20,
            ),
            label: const Text(
              'Firmware',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // --- BEÁLLÍTÁSOK FOGASKERÉK (Teljes képernyős almenü) ---
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Beállítások',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        ],
      ),
      body: const SafeArea(child: MapAndScannerScreen()),
    );
  }
}

// --- TELJES KÉPERNYŐS BEÁLLÍTÁSOK ALMENÜ ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverIpCtrl = TextEditingController(
    text: '192.168.4.1',
  );
  final TextEditingController _supaUrlCtrl = TextEditingController();
  final TextEditingController _supaKeyCtrl = TextEditingController();

  @override
  void dispose() {
    _serverIpCtrl.dispose();
    _supaUrlCtrl.dispose();
    _supaKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        title: const Text('Beállítások'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Helyi Szerver Kapcsolat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serverIpCtrl,
              decoration: InputDecoration(
                labelText: 'Szerver IP címe',
                filled: true,
                fillColor: const Color(0xFF141428),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Adatbázis (Supabase)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supaUrlCtrl,
              decoration: InputDecoration(
                labelText: 'Supabase URL',
                filled: true,
                fillColor: const Color(0xFF141428),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supaKeyCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Supabase Anon Key',
                filled: true,
                fillColor: const Color(0xFF141428),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Beállítások elmentve')),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save),
              label: const Text(
                'Mentés',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TELJES KÉPERNYŐS FIRMWARE ALMENÜ ---
class FirmwareScreen extends StatefulWidget {
  const FirmwareScreen({super.key});

  @override
  State<FirmwareScreen> createState() => _FirmwareScreenState();
}

class _FirmwareScreenState extends State<FirmwareScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        title: const Text('Firmware Frissítés'),
      ),
      body: const SafeArea(
        child: Center(
          child: Text(
            'Ide jön a Firmware almenü tartalma...',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
