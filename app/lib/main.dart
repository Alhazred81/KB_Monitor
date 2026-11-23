import 'package:flutter/material.dart';

import 'screens/map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Térképi csempék (OpenStreetMap) és képek memória-optimalizálása memóriaszivárgás ellen
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024; // 30 MB
  runApp(const HiveMonitorApp());
}

class HiveMonitorApp extends StatelessWidget {
  const HiveMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kaptármonitor & Szerver',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF111827),
      ),
      home: const Scaffold(
        body: SafeArea(
          child: MapAndScannerScreen(),
        ),
      ),
    );
  }
}
