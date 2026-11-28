import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';
import '../widgets/alert_dialogs.dart';

/// Heti Csoportosított Feladatnaptár képernyő:
/// Az elkövetkező 7 nap (és az esetleges lejárt) teendőit jeleníti meg úgy, hogy az azonos napra eső,
/// azonos típusú munkákat (pl. ha az összes kaptárat szublimálni kell) EGYETLEN közös kártyába csoportosítja!
class WeeklyCalendarScreen extends StatefulWidget {
  final HiveRepository repository;
  final ValueChanged<HiveData>? onOpenHiveOnMap;

  const WeeklyCalendarScreen({
    super.key,
    required this.repository,
    this.onOpenHiveOnMap,
  });

  @override
  State<WeeklyCalendarScreen> createState() => _WeeklyCalendarScreenState();
}

class _WeeklyCalendarScreenState extends State<WeeklyCalendarScreen> {
  // null = Teljes hét (7 nap + lejárt), -1 = Csak lejárt, 0 = Ma, 1 = Holnap, 2..7 = adott nap
  int? _selectedDayOffset;
  final Set<String> _expandedGroupKeys = <String>{};

  static const List<String> _huWeekdays = [
    'Hétfő',
    'Kedd',
    'Szerda',
    'Csütörtök',
    'Péntek',
    'Szombat',
    'Vasárnap',
  ];

  static const List<String> _huShortDays = [
    'H',
    'K',
    'Sze',
    'Cs',
    'P',
    'Szo',
    'V',
  ];

  String _formatDayHeader(int diffDays, DateTime dayDate) {
    if (diffDays < 0) {
      return '🚨 Lejárt / Azonnali beavatkozást igénylő teendők';
    }
    final String weekday = _huWeekdays[dayDate.weekday - 1];
    final String md =
        '${dayDate.month.toString().padLeft(2, '0')}.${dayDate.day.toString().padLeft(2, '0')}.';
    if (diffDays == 0) return 'Ma • $weekday ($md)';
    if (diffDays == 1) return 'Holnap • $weekday ($md)';
    return '$weekday ($md) • +$diffDays nap';
  }

  Color _urgencyColor(String code) {
    switch (code) {
      case 'flashing_red':
      case 'red':
        return Colors.redAccent;
      case 'flashing_orange':
      case 'orange':
        return Colors.orangeAccent;
      case 'yellow':
        return Colors.amberAccent;
      case 'green':
      default:
        return Colors.tealAccent;
    }
  }

  IconData _taskTypeIcon(String type, String title) {
    final lower = title.toLowerCase();
    if (lower.contains('szublimál') || lower.contains('oxálsav')) {
      return Icons.cloud;
    }
    if (lower.contains('hangyasav') || lower.contains('atka') || type == 'bottom_board') {
      return Icons.pest_control;
    }
    if (type == 'escapement_harvest') return Icons.filter_alt;
    if (type == 'pollen_trap') return Icons.local_florist;
    if (type == 'feeder_refill' || lower.contains('szirup') || lower.contains('lepény')) {
      return Icons.water_drop;
    }
    if (type.contains('queen') || lower.contains('anya')) {
      return Icons.workspace_premium;
    }
    return Icons.event_note;
  }

  void _showTomorrowPreviewDialog() {
    HapticFeedback.lightImpact();
    final tomorrowGroups = widget.repository.getTomorrowGroupedTasks();
    final todayOrOverdueCount = widget.repository
        .getGroupedTasksForWindow(daysAhead: 0, includeOverdue: true)
        .length;

    showDialog(
      context: context,
      builder: (ctx) => TomorrowTasksPopupDialog(
        tomorrowGroups: tomorrowGroups,
        todayOrOverdueCount: todayOrOverdueCount,
        onOpenCalendar: () {
          setState(() => _selectedDayOffset = 1);
        },
      ),
    );
  }

  Future<void> _confirmAndCompleteGroup(GroupedCalendarTask group) async {
    final int schedCount = group.entries
        .where((e) => e.isCompletableScheduled)
        .length;
    if (schedCount == 0) return;

    if (schedCount >= 2) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141428),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.tealAccent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.done_all, color: Colors.tealAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Csoportos készre jelentés',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Biztosan készre jelented a(z) „${group.displayTitle}” feladatot egyszerre mind a(z) $schedCount érintett családnál?',
            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Mégse',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                'Kész ($schedCount család)',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    HapticFeedback.mediumImpact();
    final int done = widget.repository.completeGroupedTask(group);
    if (mounted && done > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ „${group.displayTitle}” készre jelentve ($done család).',
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openScheduleBatchSheet() {
    final List<HiveData> availableHives = widget.repository.hives
        .where((h) => !h.isQuarantined)
        .toList();
    if (availableHives.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nincs aktív kaptár, amire ütemezni lehetne.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final Set<String> selectedIds = availableHives.map((h) => h.id).toSet();
    final TextEditingController titleCtrl = TextEditingController(
      text: 'Oxálsavas szublimálás',
    );
    final TextEditingController descCtrl = TextEditingController();
    int dayOffset = 1; // Alapértelmezés: Holnap
    DateTime customDate = DateTime.now().add(const Duration(days: 1));

    const List<String> presets = [
      'Oxálsavas szublimálás',
      'Hangyasavas kezelés ellenőrzése',
      'Serkentő cukorlepény felhelyezése',
      'Általános fészekvizsgálat',
      'Varroa aljdeszka betolása / leolvasása',
      'Méztéri bővítés ellenőrzése',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF141428),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bool allSelected =
                selectedIds.length == availableHives.length;
            final DateTime targetDate = dayOffset >= 0
                ? DateTime.now().add(Duration(days: dayOffset))
                : customDate;
            final String dateLabel =
                '${targetDate.year}.${targetDate.month.toString().padLeft(2, '0')}.${targetDate.day.toString().padLeft(2, '0')}. (${_huWeekdays[targetDate.weekday - 1]})';

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.playlist_add_check,
                          color: Colors.amberAccent,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Csoportos / Egyedi teendő ütemezése',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close, color: Colors.white60),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gyors sablonok:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presets.map((preset) {
                        final bool active = titleCtrl.text.trim() == preset;
                        return ChoiceChip(
                          label: Text(
                            preset,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: active ? Colors.black : Colors.white,
                            ),
                          ),
                          selected: active,
                          selectedColor: Colors.amberAccent,
                          backgroundColor: const Color(0xFF0F172A),
                          onSelected: (_) {
                            setSheetState(() {
                              titleCtrl.text = preset;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Teendő megnevezése',
                        labelStyle: const TextStyle(color: Colors.amberAccent),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Megjegyzés / adagolás (opcionális)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mikorra legyen ütemezve?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in const [
                          (0, 'Ma'),
                          (1, 'Holnap'),
                          (2, '+2 nap'),
                          (3, '+3 nap'),
                          (5, '+5 nap'),
                          (7, '+1 hét'),
                        ])
                          ChoiceChip(
                            label: Text(
                              entry.$2,
                              style: TextStyle(
                                color: dayOffset == entry.$1
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            selected: dayOffset == entry.$1,
                            selectedColor: Colors.tealAccent,
                            backgroundColor: const Color(0xFF0F172A),
                            onSelected: (_) {
                              setSheetState(() => dayOffset = entry.$1);
                            },
                          ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.date_range,
                            size: 16,
                            color: Colors.amberAccent,
                          ),
                          label: const Text(
                            'Egyéni dátum',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: const Color(0xFF0F172A),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: targetDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 120),
                              ),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                dayOffset = -1;
                                customDate = picked;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Érintett kaptárak (${selectedIds.length} / ${availableHives.length} db):',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.amberAccent,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            setSheetState(() {
                              if (allSelected) {
                                selectedIds.clear();
                              } else {
                                selectedIds
                                  ..clear()
                                  ..addAll(availableHives.map((h) => h.id));
                              }
                            });
                          },
                          icon: Icon(
                            allSelected
                                ? Icons.clear_all
                                : Icons.select_all,
                            size: 17,
                          ),
                          label: Text(
                            allSelected
                                ? 'Kijelölés törlése'
                                : 'Összes kaptár',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableHives.map((h) {
                        final bool isSel = selectedIds.contains(h.id);
                        return FilterChip(
                          label: Text(
                            h.name,
                            style: TextStyle(
                              color: isSel ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: Colors.amberAccent,
                          checkmarkColor: Colors.black,
                          backgroundColor: const Color(0xFF0F172A),
                          onSelected: (val) {
                            setSheetState(() {
                              if (val) {
                                selectedIds.add(h.id);
                              } else {
                                selectedIds.remove(h.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () {
                                final targets = availableHives
                                    .where((h) => selectedIds.contains(h.id))
                                    .toList();
                                final int added = widget.repository
                                    .scheduleBatchTaskForHives(
                                      targetHives: targets,
                                      title: titleCtrl.text,
                                      description: descCtrl.text,
                                      scheduledDate: targetDate,
                                    );
                                Navigator.pop(sheetCtx);
                                if (mounted && added > 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '📅 Ütemezve ($added családra, egy közös csoportban): ${titleCtrl.text.trim()}',
                                      ),
                                      backgroundColor: Colors.green.shade700,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.save),
                        label: Text(
                          allSelected
                              ? 'Ütemezés az ÖSSZES családra (${selectedIds.length} db)'
                              : 'Ütemezés mentése (${selectedIds.length} család)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final DateTime now = DateTime.now();
        final DateTime todayDay = DateTime(now.year, now.month, now.day);
        final List<GroupedCalendarTask> allGroups = widget.repository
            .getGroupedTasksForWindow(
              daysAhead: 7,
              includeOverdue: true,
              now: now,
            );

        // Napok szerinti darabszám a felső gyorsválasztó sávhoz
        final Map<int, int> countByDayOffset = {};
        for (final g in allGroups) {
          countByDayOffset[g.diffDays] =
              (countByDayOffset[g.diffDays] ?? 0) + 1;
        }

        final List<GroupedCalendarTask> filteredGroups =
            _selectedDayOffset == null
            ? allGroups
            : allGroups
                  .where((g) => g.diffDays == _selectedDayOffset)
                  .toList();

        // Csoportosítás napok szerint a szekciófejlécekhez
        final Map<int, List<GroupedCalendarTask>> byDay = {};
        for (final g in filteredGroups) {
          byDay.putIfAbsent(g.diffDays, () => <GroupedCalendarTask>[]).add(g);
        }
        final List<int> orderedOffsets = byDay.keys.toList()..sort();

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF141428),
            foregroundColor: Colors.amberAccent,
            title: const Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: Colors.amberAccent,
                  size: 22,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Heti Feladatnaptár (Csoportosított)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Másnapi teendők felugró ablak előnézete',
                icon: const Icon(
                  Icons.notifications_active,
                  color: Colors.tealAccent,
                ),
                onPressed: _showTomorrowPreviewDialog,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Colors.amberAccent,
            foregroundColor: Colors.black,
            onPressed: _openScheduleBatchSheet,
            icon: const Icon(Icons.add_task),
            label: const Text(
              'Csoportos teendő',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // --- FELSŐ NAPI GYORSSZŰRŐ SZALAG (7 NAP) ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF141428),
                    border: Border(
                      bottom: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill(
                          label: '7 nap egyben',
                          count: allGroups.length,
                          selected: _selectedDayOffset == null,
                          accent: Colors.amberAccent,
                          onTap: () =>
                              setState(() => _selectedDayOffset = null),
                        ),
                        if ((countByDayOffset[-1] ?? 0) > 0) ...[
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            label: 'Lejárt',
                            count: countByDayOffset[-1]!,
                            selected: _selectedDayOffset == -1,
                            accent: Colors.redAccent,
                            onTap: () =>
                                setState(() => _selectedDayOffset = -1),
                          ),
                        ],
                        for (int offset = 0; offset <= 7; offset++) ...[
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final d = todayDay.add(Duration(days: offset));
                              final String label = offset == 0
                                  ? 'Ma'
                                  : (offset == 1
                                        ? 'Holnap'
                                        : '${_huShortDays[d.weekday - 1]} (${d.day}.)');
                              return _buildFilterPill(
                                label: label,
                                count: countByDayOffset[offset] ?? 0,
                                selected: _selectedDayOffset == offset,
                                accent: offset == 1
                                    ? Colors.tealAccent
                                    : Colors.amberAccent,
                                onTap: () =>
                                    setState(() => _selectedDayOffset = offset),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // --- TARTALOM: CSOPORTOSÍTOTT KÁRTYÁK NAPOK SZERINT ---
                Expanded(
                  child: filteredGroups.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_available,
                                  color: Colors.tealAccent.withAlpha(180),
                                  size: 56,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedDayOffset == null
                                      ? 'A következő 7 napban nincs esedékes teendő!'
                                      : 'Erre a napra nincs ütemezett feladat.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'A jobb alsó „+ Csoportos teendő” gombbal egyszerre az összes kaptárra is felvehetsz kezelést (pl. szublimálást).',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
                          itemCount: orderedOffsets.length,
                          itemBuilder: (context, sectionIdx) {
                            final int offset = orderedOffsets[sectionIdx];
                            final List<GroupedCalendarTask> dayGroups =
                                byDay[offset]!;
                            final DateTime dayDate = dayGroups.first.dayDate;
                            final bool isOverdueSection = offset < 0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: sectionIdx == 0 ? 2 : 14,
                                    bottom: 8,
                                    left: 4,
                                  ),
                                  child: Text(
                                    _formatDayHeader(offset, dayDate),
                                    style: TextStyle(
                                      color: isOverdueSection
                                          ? Colors.redAccent
                                          : (offset == 0
                                                ? Colors.amberAccent
                                                : Colors.tealAccent),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                ...dayGroups.map(_buildGroupedTaskCard),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterPill({
    required String label,
    required int count,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? accent
                : (count > 0 ? accent.withAlpha(110) : Colors.white12),
            width: selected ? 1.8 : 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.black87 : accent.withAlpha(45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? accent : accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedTaskCard(GroupedCalendarTask group) {
    final Color urgColor = _urgencyColor(group.worstUrgencyCode);
    final bool coversAll = group.coversAllHives;
    final bool isMulti = group.affectedHiveCount > 1;
    final bool isExpanded = _expandedGroupKeys.contains(group.groupKey);

    final String scopeBadge = coversAll
        ? 'Összes család (${group.affectedHiveCount} db)'
        : (isMulti
              ? '${group.affectedHiveCount} család együtt'
              : group.uniqueHiveNames.first);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141428),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: coversAll
              ? Colors.amberAccent.withAlpha(190)
              : urgColor.withAlpha(160),
          width: coversAll ? 1.8 : 1.3,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: urgColor.withAlpha(32),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: urgColor.withAlpha(120)),
                  ),
                  child: Icon(
                    _taskTypeIcon(group.type, group.displayTitle),
                    color: urgColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.displayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: coversAll
                                  ? Colors.amber.withAlpha(45)
                                  : Colors.teal.withAlpha(40),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: coversAll
                                    ? Colors.amberAccent
                                    : Colors.tealAccent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  coversAll
                                      ? Icons.group
                                      : (isMulti ? Icons.hive : Icons.place),
                                  size: 13,
                                  color: coversAll
                                      ? Colors.amberAccent
                                      : Colors.tealAccent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  scopeBadge,
                                  style: TextStyle(
                                    color: coversAll
                                        ? Colors.amberAccent
                                        : Colors.tealAccent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMulti)
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedGroupKeys.remove(group.groupKey);
                                  } else {
                                    _expandedGroupKeys.add(group.groupKey);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isExpanded
                                          ? 'Családok elrejtése'
                                          : 'Családok listája',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Icon(
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: Colors.white60,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (group.sampleDescription.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                group.sampleDescription,
                maxLines: isExpanded ? 5 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],

            // Érintett családok jelvényei (mindig látszik tömören, vagy lenyitva egyenként is pipálható)
            if (!coversAll || isExpanded) ...[
              const SizedBox(height: 10),
              if (!isExpanded)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: group.entries.map((e) {
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Colors.white24),
                      label: Text(
                        e.hiveName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: widget.onOpenHiveOnMap == null
                          ? null
                          : () {
                              final hive = widget.repository.getHiveById(
                                e.hiveId,
                              );
                              if (hive != null) {
                                Navigator.pop(context);
                                widget.onOpenHiveOnMap!(hive);
                              }
                            },
                    );
                  }).toList(),
                )
              else
                Column(
                  children: group.entries.map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.hive,
                            color: Colors.amberAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.hiveName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          if (widget.onOpenHiveOnMap != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.lightBlueAccent,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                final hive = widget.repository.getHiveById(
                                  entry.hiveId,
                                );
                                if (hive != null) {
                                  Navigator.pop(context);
                                  widget.onOpenHiveOnMap!(hive);
                                }
                              },
                              icon: const Icon(Icons.place, size: 15),
                              label: const Text(
                                'Térkép',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                          if (entry.isCompletableScheduled)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Csak ennél a családnál kész',
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.tealAccent,
                                size: 20,
                              ),
                              onPressed: () {
                                widget.repository.completeTask(entry.taskId);
                              },
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],

            if (group.hasCompletableScheduledEntries) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.tealAccent),
                    ),
                  ),
                  onPressed: () => _confirmAndCompleteGroup(group),
                  icon: Icon(
                    isMulti ? Icons.done_all : Icons.check,
                    size: 19,
                    color: Colors.tealAccent,
                  ),
                  label: Text(
                    isMulti
                        ? 'Csoportos készre jelentés (${group.affectedHiveCount} család)'
                        : 'Készre jelentés (${group.uniqueHiveNames.first})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
