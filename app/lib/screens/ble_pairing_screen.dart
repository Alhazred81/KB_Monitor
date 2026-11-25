import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../widgets/safe_camera_controller.dart';
import 'server_config_screen.dart';

class BlePairingScreen extends StatefulWidget {
  const BlePairingScreen({super.key});

  @override
  State<BlePairingScreen> createState() => _BlePairingScreenState();
}

class _BlePairingScreenState extends State<BlePairingScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.code128,
    ],
  );
  bool _isScanning = true;
  bool _isConnected = false;
  String _detectedServerName = '';
  String _detectedPin = '';
  String _statusMessage =
      'Érintsd a mágnest a dobozhoz, majd olvasd be a fedél belső QR kódját!';

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (!_isScanning) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String raw = barcodes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    // QR formátum ellenőrzés: pl. "KB_BLE:A1B2:PIN_123456" vagy egyszerű szerver név
    String serverName = 'BeeServer';
    String pin = '123456';

    if (raw.contains('KB_BLE')) {
      final parts = raw.split(':');
      if (parts.length >= 2) serverName = 'BeeServer_${parts[1]}';
      if (parts.length >= 3) pin = parts[2].replaceAll('PIN_', '');
    } else {
      serverName = raw;
    }

    // STEALTH VISSZAJELZÉS: A telefon vibrál egy erőset a kézben!
    HapticFeedback.heavyImpact();
    _scannerController.stop();

    setState(() {
      _isScanning = false;
      _detectedServerName = serverName;
      _detectedPin = pin;
      _statusMessage = 'Szerver azonosítva! Bluetooth kapcsolat kiépítése...';
    });

    // Szimulált gyors párosítás és kapcsolat (offline BLE Handshake)
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isConnected = true;
          _statusMessage =
              'Sikeresen párosítva a szerverrel ($_detectedServerName)!';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Bluetooth Párosítás (Stealth Mód)'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.tealAccent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lépések és magyarázat
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.shield_outlined,
                          color: Colors.tealAccent,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Lopásbiztos / Fénymentes Csatlakozás',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Érintsd a kulcstartód mágnesét a dobozhoz 2 mp-re.\n'
                      '2. Nincs villogó LED (sötétben is észrevétlen marad!).\n'
                      '3. Olvasd be a doboz belsejében lévő QR kódot a kamerával.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Kamera QR Szkenner mező
              if (_isScanning) ...[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          errorBuilder: (context, error) {
                            return Container(
                              color: const Color(0xFF1E293B),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.videocam_off,
                                      color: Colors.amberAccent,
                                      size: 42,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Nem érhető el a kamerakép',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hiba: ${error.errorCode}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        foregroundColor: Colors.black,
                                      ),
                                      icon: const Icon(Icons.cameraswitch),
                                      label: const Text('Kamera váltása'),
                                      onPressed: () => _scannerController.safeSwitchCamera(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          onDetect: _onQrDetected,
                        ),
                        // BOXKESZTYŰBARÁT KAMERA VÁLTÓ GOMB
                        Positioned(
                          top: 12,
                          right: 12,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black87,
                              foregroundColor: Colors.amberAccent,
                              side: const BorderSide(color: Colors.amberAccent, width: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              minimumSize: const Size(130, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                            ),
                            onPressed: () => _scannerController.safeSwitchCamera(),
                            icon: const Icon(Icons.cameraswitch, size: 24, color: Colors.amberAccent),
                            label: const Text(
                              'Kamera',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.tealAccent,
                              width: 2.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(180),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Irányítsd a kamerát a kódra',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Csatlakozott állapot kártya
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isConnected
                              ? Colors.greenAccent
                              : Colors.amberAccent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isConnected
                                ? Icons.bluetooth_connected
                                : Icons.bluetooth_searching,
                            color: _isConnected
                                ? Colors.greenAccent
                                : Colors.amberAccent,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _detectedServerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isConnected
                                  ? Colors.greenAccent
                                  : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          if (_isConnected) ...[
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10b981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ServerAndWeatherConfigScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.dashboard_customize),
                              label: const Text(
                                'Szerver Konfiguráció Megnyitása',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Újraolvasás gomb, ha szükséges
              if (!_isScanning && !_isConnected)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _isScanning = true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Újraolvasás'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
