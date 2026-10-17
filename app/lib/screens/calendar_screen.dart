import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final HiveRepository _repository = HiveRepository.instance;
  int _selectedRangeDays = 1; // 1 = Napi, 3 = Háromnapi, 7 = Heti
  DateTime _startDate = DateTime.now();

  DateTime _stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  void _shiftDate(int days) {
    setState(() {
      _startDate = _startDate.add(Duration(days: days));
    });
  }

  List<ScheduledTask> _getTasksForDay(DateTime day) {
    final target = _stripTime(day);
    final tasks = _repository.scheduledTasks.where((t) {
      return _stripTime(t.scheduledDate) == target;
    }).toList();

    // Ha van olyan kaptár, ahol az aljdeszka 3 napos ellenőrzése ma esedékes, megjelenítjük
    for (var hive in _repository.hives) {
      for (var box in hive.boxes) {
        if (box.type == 'bottom' &&
            box.isActive &&
            box.statusUpdatedAt != null) {
          final checkDate = _stripTime(
            box.statusUpdatedAt!.add(const Duration(days: 3)),
          );
          if (checkDate == target) {
            tasks.add(
              ScheduledTask(
                id: 'VARROA_${hive.id}_${checkDate.millisecondsSinceEpoch}',
                hiveId: hive.id,
                category: 'varroa_check',
                title: 'Aljdeszka (Varroa) 3 napos ellenőrzés',
                description:
                    'Az aljdeszka 3 napja bent van a(z) ${hive.name} kaptárban. Ellenőrizd az atkahullást és húzd ki a tálcát!',
                scheduledDate: checkDate,
                isCompleted: false,
              ),
            );
          }
        }
      }
    }

    return tasks;
  }

  String _formatDate(DateTime dt) {
    // Rövidített napnevek: hétfőtől vasárnapig
    const shortWeekdays = ['h', 'k', 'sze', 'cs', 'p', 'szo', 'v'];
    final dayName = shortWeekdays[dt.weekday - 1];
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '${dt.year}.$month.$day. ($dayName)';
  }

  @override
  Widget build(BuildContext context) {
    final today = _stripTime(DateTime.now());
    final baseDate = _stripTime(_startDate);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Méhészeti Naptár',
          style: TextStyle(color: Colors.amberAccent, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _startDate = DateTime.now()),
            icon: const Icon(Icons.today, color: Colors.amberAccent, size: 18),
            label: const Text(
              'Ma',
              style: TextStyle(color: Colors.amberAccent),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _repository,
        builder: (context, _) {
          return Column(
            children: [
              // Felbontás választó (Napi / Háromnapi / Heti)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: const Color(0xFF1E1E1E),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment<int>(
                            value: 1,
                            label: Text('Napi'),
                            icon: Icon(Icons.calendar_view_day, size: 16),
                          ),
                          ButtonSegment<int>(
                            value: 3,
                            label: Text('3 napos'),
                            icon: Icon(Icons.view_column, size: 16),
                          ),
                          ButtonSegment<int>(
                            value: 7,
                            label: Text('Heti'),
                            icon: Icon(Icons.calendar_view_week, size: 16),
                          ),
                        ],
                        selected: {_selectedRangeDays},
                        style: SegmentedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2C2C),
                          foregroundColor: Colors.white70,
                          selectedBackgroundColor: Colors.amber,
                          selectedForegroundColor: Colors.black,
                        ),
                        onSelectionChanged: (selection) {
                          setState(() {
                            _selectedRangeDays = selection.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Időszak léptető sáv
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
                          onPressed: () => _shiftDate(-_selectedRangeDays),
                        ),
                        Text(
                          _selectedRangeDays == 1
                              ? _formatDate(baseDate)
                              : '${_formatDate(baseDate)} – ${_formatDate(baseDate.add(Duration(days: _selectedRangeDays - 1)))}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                          onPressed: () => _shiftDate(_selectedRangeDays),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Naptári napok és feladatok listája
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _selectedRangeDays,
                  itemBuilder: (context, index) {
                    final currentDay = baseDate.add(Duration(days: index));
                    final dayTasks = _getTasksForDay(currentDay);
                    final isToday = currentDay == today;

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isToday ? Colors.amber : Colors.white12,
                          width: isToday ? 1.5 : 1.0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDate(currentDay),
                                  style: TextStyle(
                                    color: isToday
                                        ? Colors.amberAccent
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isToday)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'MA',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 16),
                            if (dayTasks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Erre a napra nincs ütemezett feladat.',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              for (var task in dayTasks)
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: Colors.amber,
                                  value: task.isCompleted,
                                  onChanged: (val) {
                                    setState(() {
                                      task.isCompleted = val ?? false;
                                    });
                                    if (_repository.hives.isNotEmpty) {
                                      _repository.updateHive(
                                        _repository.hives.first,
                                      );
                                    }
                                  },
                                  title: Text(
                                    task.title,
                                    style: TextStyle(
                                      color: task.isCompleted
                                          ? Colors.white38
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Kaptár: ${task.hiveId} • ${task.description}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
