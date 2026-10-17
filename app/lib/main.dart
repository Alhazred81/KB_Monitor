import 'package:flutter/material.dart';

import 'screens/map_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'services/hive_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final HiveRepository _repository = HiveRepository.instance;

  final List<Widget> _screens = const [
    MapAndScannerScreen(),
    CalendarScreen(),
    ServerDiagnosticsScreen(),
  ];

  // A naptár ikon színének kiszámítása a legközelebbi esedékes feladat alapján
  Color _getCalendarUrgencyColor() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Ha valamelyik kaptárban 3 napja bent van az aljdeszka, azonnal piros
    for (var hive in _repository.hives) {
      if (hive.boxes.any((b) => b.isVarroaCheckDue)) {
        return Colors.redAccent;
      }
    }

    // 2. El nem végzett feladatok vizsgálata
    final pendingTasks = _repository.scheduledTasks
        .where((t) => !t.isCompleted)
        .toList();
    if (pendingTasks.isEmpty) {
      return Colors.grey;
    }

    pendingTasks.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final nextTaskDate = DateTime(
      pendingTasks.first.scheduledDate.year,
      pendingTasks.first.scheduledDate.month,
      pendingTasks.first.scheduledDate.day,
    );

    final int diffDays = nextTaskDate.difference(today).inDays;

    if (diffDays <= 0) {
      return Colors.redAccent; // Ma esedékes vagy lejárt
    } else if (diffDays <= 3) {
      return Colors.orangeAccent; // 1-3 napon belül esedékes
    } else if (diffDays <= 7) {
      return Colors.amber; // Ezen a héten esedékes
    } else {
      return Colors.green; // 7 napnál távolabbi feladat
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repository,
      builder: (context, _) {
        final Color calendarColor = _getCalendarUrgencyColor();

        return Scaffold(
          body: _screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.deepOrange,
            unselectedItemColor: Colors.grey,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Térkép & Olvasó',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month, color: calendarColor),
                activeIcon: Icon(Icons.calendar_month, color: calendarColor),
                label: 'Naptár',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.dns_outlined),
                activeIcon: Icon(Icons.dns),
                label: 'Szerver',
              ),
            ],
          ),
        );
      },
    );
  }
}
