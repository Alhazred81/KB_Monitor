import 'package:flutter/material.dart';

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
