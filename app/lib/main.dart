import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_compass/flutter_compass.dart';

import 'dart:math' as math;

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    MapAndScannerScreen(),
    ServerDiagnosticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kaptármonitor',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        iconSize: 32,
        selectedFontSize: 16,
        unselectedFontSize: 14,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Térkép & Olvasó',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dns_outlined),
            activeIcon: Icon(Icons.dns),
            label: 'Szerver',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[900],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class MapAndScannerScreen extends StatefulWidget {
  const MapAndScannerScreen({super.key});

  @override
  State<MapAndScannerScreen> createState() => _MapAndScannerScreenState();
}

class _MapAndScannerScreenState extends State<MapAndScannerScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  LatLng _myPosition = const LatLng(47.529881, 19.028227);
  bool _hasGpsFix = false;
  String _statusMessage = 'GPS pozíció keresése...';

  // Iránytű adatok
  double? _heading = 0.0;

  final TextEditingController _idController = TextEditingController(
    text: 'Nincs beolvasott azonosító',
  );

  // NFC villogáshoz
  late AnimationController _nfcAnimController;
  late Animation<Color?> _nfcColorAnim;
  bool _isNfcScanning = false;

  bool _isCameraActive = false;
  late MobileScannerController _cameraController;

  @override
  void initState() {
    super.initState();
    _updatePosition();
    _initCompass();

    _cameraController = MobileScannerController();

    _nfcAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _nfcColorAnim = ColorTween(
      begin: Colors.white,
      end: const Color(0xFF00FF66), // Neon zöld
    ).animate(_nfcAnimController);
  }

  // Iránytű figyelése a hardverből
  void _initCompass() {
    FlutterCompass.events?.listen((CompassEvent event) {
      if (mounted) {
        setState(() {
          _heading =
              event.heading; // 0 és 360 fok között az északi irányhoz képest
        });
      }
    });
  }

  @override
  void dispose() {
    _nfcAnimController.dispose();
    _idController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _updatePosition() async {
    setState(() => _statusMessage = 'GPS lekérése...');
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _statusMessage = 'A helymeghatározás ki van kapcsolva.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(
          () => _statusMessage = 'Helymeghatározási engedély megtagadva.',
        );
        return;
      }
    }

    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _myPosition = LatLng(pos.latitude, pos.longitude);
        _hasGpsFix = true;
        _statusMessage =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
      _mapController.move(_myPosition, 17.0);
    } catch (e) {
      setState(() => _statusMessage = 'GPS hiba: $e');
    }
  }

  String _getHeadingText(double? heading) {
    if (heading == null) return '---°';
    int h = heading.round();
    if (h >= 337.5 || h < 22.5) return 'É ($h°)';
    if (h >= 22.5 && h < 67.5) return 'ÉÉK ($h°)';
    if (h >= 67.5 && h < 112.5) return 'K ($h°)';
    if (h >= 112.5 && h < 157.5) return 'DDK ($h°)';
    if (h >= 157.5 && h < 202.5) return 'D ($h°)';
    if (h >= 202.5 && h < 247.5) return 'DDN ($h°)' /* DNY */;
    if (h >= 247.5 && h < 292.5) return 'NY ($h°)';
    if (h >= 292.5 && h < 337.5) return 'ÉNY ($h°)';
    return '$h°';
  }

  void _startNfcScan() {
    setState(() {
      _isNfcScanning = true;
      _idController.text = 'NFC olvasás folyamatban...';
    });
    _nfcAnimController.repeat(reverse: true);

    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isNfcScanning) {
        setState(() {
          _isNfcScanning = false;
          _idController.text = 'NFC időtúllépés';
        });
        _nfcAnimController.stop();
      }
    });
  }

  void _simulateNfcSuccess(String tagId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isNfcScanning = false;
      _idController.text = tagId;
    });
    _nfcAnimController.stop();
  }

  @override
  Widget build(BuildContext context) {
    // Irány fok átváltása radiánba a nyíl forgatásához
    double headingRad = (_heading ?? 0) * (math.pi / 180.0);

    return Stack(
      children: [
        _isCameraActive
            ? Stack(
                children: [
                  MobileScanner(
                    controller: _cameraController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          final String code = barcode.rawValue!;
                          HapticFeedback.lightImpact();
                          setState(() {
                            _idController.text = code;
                            _isCameraActive = false;
                          });
                          _cameraController.stop();
                          break;
                        }
                      }
                    },
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isCameraActive = false;
                        });
                        _cameraController.stop();
                      },
                      icon: const Icon(Icons.close, size: 28),
                      label: const Text(
                        'MÉGSE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xCC000000),
                        foregroundColor: Colors.amberAccent,
                        side: const BorderSide(color: Colors.amber, width: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _myPosition,
                  initialZoom: 16.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.balazs.hive_monitor',
                  ),
                  MarkerLayer(
                    markers: [
                      // Saját pozíció forgó navigációs nyíllal (merre nézel)
                      Marker(
                        point: _myPosition,
                        width: 70,
                        height: 70,
                        child: Transform.rotate(
                          angle: headingRad,
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.blueAccent,
                            size: 46,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

        // Felső GPS + Iránytű sáv
        if (!_isCameraActive)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xB3000000),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasGpsFix ? Icons.explore : Icons.explore_off,
                    color: Colors.amberAccent,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Irány: ${_getHeadingText(_heading)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.amber,
                        size: 30,
                      ),
                      onPressed: _updatePosition,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Alsó vezérlőpanel
        if (!_isCameraActive)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: _idController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xCC000000),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.amber,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.amber,
                              width: 2,
                            ),
                          ),
                          hintText: 'Azonosító...',
                          hintStyle: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isCameraActive = !_isCameraActive;
                                });
                                if (_isCameraActive) {
                                  _cameraController.start();
                                } else {
                                  _cameraController.stop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xBF000000),
                                foregroundColor: _isCameraActive
                                    ? Colors.greenAccent
                                    : Colors.amberAccent,
                                side: BorderSide(
                                  color: _isCameraActive
                                      ? Colors.greenAccent
                                      : Colors.amber,
                                  width: _isCameraActive ? 4 : 3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isCameraActive
                                        ? Icons.camera_alt
                                        : Icons.qr_code_scanner,
                                    size: 50,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isCameraActive ? 'BEZÁR' : 'KAMERA',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: AnimatedBuilder(
                              animation: _nfcColorAnim,
                              builder: (context, child) {
                                Color activeColor =
                                    _nfcColorAnim.value ?? Colors.white;
                                return ElevatedButton(
                                  onPressed: _isNfcScanning
                                      ? () {
                                          setState(
                                            () => _isNfcScanning = false,
                                          );
                                          _nfcAnimController.stop();
                                        }
                                      : () {
                                          _startNfcScan();
                                          Future.delayed(
                                            const Duration(seconds: 2),
                                            () {
                                              if (_isNfcScanning) {
                                                _simulateNfcSuccess(
                                                  'NFC_TAG_HIVE_99',
                                                );
                                              }
                                            },
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isNfcScanning
                                        ? Colors.black
                                        : const Color(0xBF000000),
                                    foregroundColor: _isNfcScanning
                                        ? activeColor
                                        : Colors.amberAccent,
                                    side: BorderSide(
                                      color: _isNfcScanning
                                          ? activeColor
                                          : Colors.amber,
                                      width: _isNfcScanning ? 6 : 3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.nfc,
                                        size: 50,
                                        color: _isNfcScanning
                                            ? activeColor
                                            : Colors.amberAccent,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _isNfcScanning ? 'OLVASÁS...' : 'NFC',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                          color: _isNfcScanning
                                              ? activeColor
                                              : Colors.amberAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ServerDiagnosticsScreen extends StatelessWidget {
  const ServerDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Szerverkapcsolat és diagnosztika',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
