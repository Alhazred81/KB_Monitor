import 'package:flutter/material.dart';

import 'screens/map_screen.dart'; // Ez most már helyes, mert benne van a MapAndScannerScreen

void main() {
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
      home: Scaffold(
        body: SafeArea(
          child: MapAndScannerScreen(), // <-- Itt volt a néveltérés (MapScreen helyett ez kell)
        ),
      ),
    );
  }
}
