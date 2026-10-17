import 'package:flutter/material.dart';

import '../services/hive_repository.dart';
import '../widgets/hive_config_dialog.dart';

class ServerDiagnosticsScreen extends StatelessWidget {
  const ServerDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = HiveRepository.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Szerverkapcsolat és Naptár',
          style: TextStyle(color: Colors.amberAccent, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.amberAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const HiveSetupDialog(),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: const Color(0xFF1E1E1E),
                child: ListTile(
                  leading: const Icon(
                    Icons.cloud_done,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'Supabase Adatbázis Forrás',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    repository.supabaseUrl.isEmpty
                        ? 'Nincs beállítva URL'
                        : repository.supabaseUrl,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const HiveSetupDialog(),
                      );
                    },
                    child: const Text('Konfig'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ütemezett Mesterterv és Kezelési Feladatok:',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (repository.scheduledTasks.isEmpty)
                const Text(
                  'Nincs aktív ütemezett feladat.',
                  style: TextStyle(color: Colors.white54),
                )
              else
                for (var task in repository.scheduledTasks)
                  Card(
                    color: const Color(0xFF1E1E1E),
                    child: CheckboxListTile(
                      activeColor: Colors.amber,
                      value: task.isCompleted,
                      onChanged: (val) {
                        task.isCompleted = val ?? false;
                        repository.updateHive(repository.hives.first);
                      },
                      title: Text(
                        '${task.scheduledDate.toIso8601String().split('T').first} - ${task.title}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Kaptár: ${task.hiveId}\n${task.description}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
