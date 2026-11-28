import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/alarm_sound_service.dart';
import '../services/hive_repository.dart';

/// Kritikus vészhelyzeti felugró ablak (pl. Kaptár borulás, Szivattyú csőtörés, Fagyveszély, Zárlat):
/// folyamatosan villog és csipog (némítást felülírva az Alarm csatornán), amíg a gazda le nem okézza!
class EmergencySirenDialog extends StatefulWidget {
  final AppAlertEvent event;
  final VoidCallback onAcknowledge;
  final VoidCallback? onJumpToHive;

  const EmergencySirenDialog({
    super.key,
    required this.event,
    required this.onAcknowledge,
    this.onJumpToHive,
  });

  @override
  State<EmergencySirenDialog> createState() => _EmergencySirenDialogState();
}

class _EmergencySirenDialogState extends State<EmergencySirenDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _strobeCtrl;

  @override
  void initState() {
    super.initState();
    _strobeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..repeat(reverse: true);
    AlarmSoundService.instance.startContinuousSiren();
  }

  @override
  void dispose() {
    AlarmSoundService.instance.stopSiren();
    _strobeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleOk({bool jumpToHive = false}) async {
    HapticFeedback.heavyImpact();
    await AlarmSoundService.instance.stopSiren();
    widget.onAcknowledge();
    if (mounted) {
      Navigator.of(context).pop();
    }
    if (jumpToHive && widget.onJumpToHive != null) {
      widget.onJumpToHive!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = widget.event.createdAt;
    final String timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: false,
      child: AnimatedBuilder(
        animation: _strobeCtrl,
        builder: (context, _) {
          final double t = _strobeCtrl.value;
          final Color borderColor = Color.lerp(
            const Color(0xFFFF1744),
            Colors.amberAccent,
            t,
          )!;
          final Color bgTint = Color.lerp(
            const Color(0xFF28050B),
            const Color(0xFF4A0813),
            t,
          )!;
          final Color headerBg = Color.lerp(
            const Color(0xFFB71C1C),
            const Color(0xFFFF5252),
            t,
          )!;

          return Dialog(
            backgroundColor: bgTint,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: borderColor, width: 3.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: headerBg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: borderColor.withAlpha(180),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: t > 0.5 ? Colors.yellowAccent : Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.event.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Észlelve: $timeStr • Némítást felülíró sziréna aktív',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.event.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (widget.onJumpToHive != null &&
                      widget.event.hiveName != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amberAccent,
                          side: const BorderSide(
                            color: Colors.amberAccent,
                            width: 1.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _handleOk(jumpToHive: true),
                        icon: const Icon(Icons.my_location, size: 20),
                        label: Text(
                          'Leokézás és ugrás: ${widget.event.hiveName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _handleOk(jumpToHive: false),
                      icon: const Icon(Icons.check_circle_rounded, size: 28),
                      label: const Text(
                        'LEOKÉZOM (SZIRÉNA LEÁLLÍTÁSA)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sima, nyugodt felugró ablak a másnapi (holnapi) teendők csoportosított áttekintésével.
class TomorrowTasksPopupDialog extends StatelessWidget {
  final List<GroupedCalendarTask> tomorrowGroups;
  final int todayOrOverdueCount;
  final VoidCallback onOpenCalendar;

  const TomorrowTasksPopupDialog({
    super.key,
    required this.tomorrowGroups,
    required this.todayOrOverdueCount,
    required this.onOpenCalendar,
  });

  static const List<String> _huWeekdays = [
    'Hétfő',
    'Kedd',
    'Szerda',
    'Csütörtök',
    'Péntek',
    'Szombat',
    'Vasárnap',
  ];

  @override
  Widget build(BuildContext context) {
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    final String weekday = _huWeekdays[tomorrow.weekday - 1];
    final String dateStr =
        '${tomorrow.month.toString().padLeft(2, '0')}.${tomorrow.day.toString().padLeft(2, '0')}.';

    return AlertDialog(
      backgroundColor: const Color(0xFF141428),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.amberAccent, width: 1.8),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent.withAlpha(140)),
            ),
            child: const Icon(
              Icons.event_note,
              color: Colors.amberAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Másnapi teendők',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Holnap • $weekday ($dateStr)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tomorrowGroups.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.greenAccent,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Holnapra nincs beütemezett teendő a kaptárakon.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...tomorrowGroups.map((group) {
                  final bool allHives = group.coversAllHives;
                  final String countBadge = allHives
                      ? 'Összes család (${group.affectedHiveCount} db)'
                      : (group.affectedHiveCount > 1
                            ? '${group.affectedHiveCount} család'
                            : group.uniqueHiveNames.first);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: allHives
                            ? Colors.amberAccent.withAlpha(170)
                            : Colors.tealAccent.withAlpha(120),
                        width: 1.3,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              allHives ? Icons.group : Icons.check_circle_outline,
                              color: allHives
                                  ? Colors.amberAccent
                                  : Colors.tealAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                group.displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: allHives
                                    ? Colors.amber.withAlpha(45)
                                    : Colors.teal.withAlpha(45),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: allHives
                                      ? Colors.amberAccent
                                      : Colors.tealAccent,
                                ),
                              ),
                              child: Text(
                                countBadge,
                                style: TextStyle(
                                  color: allHives
                                      ? Colors.amberAccent
                                      : Colors.tealAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!allHives && group.affectedHiveCount > 1) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: group.uniqueHiveNames
                                .map(
                                  (name) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              if (todayOrOverdueCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(28),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orangeAccent.withAlpha(120)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.today,
                        color: Colors.orangeAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mára / lejárva is van $todayOrOverdueCount csoportosított feladat a naptárban.',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.tealAccent,
            side: const BorderSide(color: Colors.tealAccent),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onOpenCalendar();
          },
          icon: const Icon(Icons.calendar_month, size: 18),
          label: const Text(
            'Heti Naptár',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amberAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.check, size: 18),
          label: const Text(
            'Rendben',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
