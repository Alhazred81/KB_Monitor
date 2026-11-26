import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';

class OfficeHistoryScreen extends StatefulWidget {
  final HiveRepository repository;
  final String? initialHiveFilter;
  final String initialCategory;

  const OfficeHistoryScreen({
    super.key,
    required this.repository,
    this.initialHiveFilter,
    this.initialCategory = 'all',
  });

  @override
  State<OfficeHistoryScreen> createState() => _OfficeHistoryScreenState();
}

class _OfficeHistoryScreenState extends State<OfficeHistoryScreen> {
  late String _selectedHiveFilter;
  late String _selectedCategory;
  String _directionFilter = 'all'; // 'all' | 'added' | 'removed'
  bool _showAutoTelemetryInAll =
      true; // A "Mind" nézetben alapból az automata mérések is látszanak időrendben
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isRefreshing = false;

  static const List<Map<String, dynamic>> _categoryTabs = [
    {'id': 'all', 'label': 'Mind', 'icon': Icons.history_rounded},
    {'id': 'boxes', 'label': 'Fiókok (+/−)', 'icon': Icons.inventory_2_rounded},
    {
      'id': 'zubehor',
      'label': 'Zubehör (Kellékek)',
      'icon': Icons.extension_rounded,
    },
    {
      'id': 'treatments',
      'label': 'Kezelések & Etetés',
      'icon': Icons.medical_services_rounded,
    },
    {
      'id': 'classification',
      'label': 'Osztályozás & Anya',
      'icon': Icons.workspace_premium_rounded,
    },
    {
      'id': 'telemetry',
      'label': 'Automata mérések',
      'icon': Icons.sensors_rounded,
    },
    {
      'id': 'other',
      'label': 'Pergetés & Egyéb',
      'icon': Icons.water_drop_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedHiveFilter = widget.initialHiveFilter ?? 'ALL';
    _selectedCategory = widget.initialCategory;
    widget.repository.addListener(_onRepoChanged);
    _triggerInitialRefresh();
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _triggerInitialRefresh() async {
    if (!widget.repository.isOnline) return;
    setState(() => _isRefreshing = true);
    await widget.repository.refreshHistoryFromSupabase(limit: 300);
    if (mounted) setState(() => _isRefreshing = false);
  }

  bool _matchesHiveFilter(HistoryLogEntry entry) {
    if (_selectedHiveFilter == 'ALL') return true;
    if (_selectedHiveFilter == 'NON_HIVE') {
      return !widget.repository.hives.any((h) => h.id == entry.monitorMac);
    }
    return entry.monitorMac == _selectedHiveFilter;
  }

  bool _matchesSearch(HistoryLogEntry entry, String query) {
    if (query.isEmpty) return true;
    final targetName = widget.repository
        .resolveTargetDisplayName(entry.monitorMac)
        .toLowerCase();
    return entry.description.toLowerCase().contains(query) ||
        entry.eventType.toLowerCase().contains(query) ||
        entry.actionBadgeLabel.toLowerCase().contains(query) ||
        targetName.contains(query) ||
        entry.monitorMac.toLowerCase().contains(query);
  }

  Color _getEntryColor(HistoryLogEntry entry) {
    switch (entry.actionKind) {
      case 'added':
        return const Color(0xFF10B981); // Smaragdzöld (+ felrakva)
      case 'removed':
        return const Color(0xFFF97316); // Narancs (- levéve)
      case 'reordered':
        return const Color(0xFF38BDF8); // Világoskék
      case 'active_on':
        return const Color(0xFF14B8A6); // Türkiz
      case 'active_off':
        return const Color(0xFF94A3B8); // Szürkéskék
      case 'warning':
        return const Color(0xFFEF4444); // Piros figyelmeztetés
      case 'strengthening':
        return const Color(0xFF22C55E); // Zöld erősítés
      case 'feeding':
        return const Color(0xFF06B6D4); // Cián szirup
      case 'treatment':
        return const Color(0xFFEC4899); // Rózsaszín kezelés
      case 'evaluation':
        return const Color(0xFFFBBF24); // Arany tenyészbírálat
      case 'status':
        return const Color(0xFFA855F7); // Lila státusz
      case 'function':
        return const Color(0xFFF59E0B); // Borostyán családfunkció
      case 'queen':
        return const Color(0xFFE879F9); // Királynő magenta
      case 'telemetry':
        return const Color(0xFF38BDF8); // Szenzor telemetria égszínkék
      case 'harvest':
        return const Color(0xFFFACC15); // Méz sárga
      default:
        return Colors.blueGrey.shade300;
    }
  }

  IconData _getEntryIcon(HistoryLogEntry entry) {
    switch (entry.actionKind) {
      case 'added':
        return entry.mainCategory == 'boxes'
            ? Icons.add_box_rounded
            : Icons.add_circle_outline_rounded;
      case 'removed':
        return entry.mainCategory == 'boxes'
            ? Icons.indeterminate_check_box_rounded
            : Icons.remove_circle_outline_rounded;
      case 'reordered':
        return Icons.swap_vert_circle_rounded;
      case 'active_on':
        return Icons.toggle_on_rounded;
      case 'active_off':
        return Icons.toggle_off_outlined;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'strengthening':
        return Icons.trending_up_rounded;
      case 'feeding':
        return Icons.opacity_rounded;
      case 'treatment':
        return Icons.medical_services_rounded;
      case 'evaluation':
        return Icons.star_rate_rounded;
      case 'status':
        return Icons.palette_rounded;
      case 'function':
        return Icons.work_outline_rounded;
      case 'queen':
        return Icons.workspace_premium_rounded;
      case 'telemetry':
        return Icons.sensors_rounded;
      case 'harvest':
        return Icons.breakfast_dining_rounded;
      default:
        return Icons.wysiwyg_rounded;
    }
  }

  String _formatDayHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    final dateStr =
        '${dt.year}. ${dt.month.toString().padLeft(2, '0')}. ${dt.day.toString().padLeft(2, '0')}.';
    if (diff == 0) return 'Ma – $dateStr';
    if (diff == 1) return 'Tegnap – $dateStr';
    return dateStr;
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildMetadataChips(HistoryLogEntry entry) {
    final meta = entry.metadata;
    if (meta == null || meta.isEmpty) return const [];

    final List<Widget> chips = [];
    void addChip(String label, IconData icon, Color color) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(28),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(90)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final rawSize = (meta['body_type'] ?? meta['size'] ?? '').toString().trim();
    if (rawSize.isNotEmpty && rawSize != 'bottom' && rawSize != 'none') {
      final prettySize = isHalfBoxSize(rawSize)
          ? (rawSize.toLowerCase().contains('nb')
                ? '1/2 NB'
                : rawSize.toLowerCase().contains('lang')
                ? '1/2 Langstroth'
                : '1/2 Dadant')
          : rawSize.toUpperCase();
      addChip('Méret: $prettySize', Icons.straighten, Colors.amberAccent);
    }

    if (meta['position_index'] != null) {
      addChip(
        '${meta['position_index']}. szint',
        Icons.layers,
        Colors.tealAccent,
      );
    }

    final code = (meta['code'] ?? meta['box_code'] ?? meta['escapement_code'] ?? '')
        .toString()
        .trim();
    if (code.isNotEmpty) {
      addChip(code, Icons.qr_code_2, Colors.lightBlueAccent);
    }

    if (meta['daily_drop'] is num) {
      addChip(
        'Atka: ${(meta['daily_drop'] as num).toStringAsFixed(1)} db/nap',
        Icons.bug_report,
        Colors.orangeAccent,
      );
    }

    if (meta['liters'] is num) {
      addChip(
        '+${(meta['liters'] as num).toStringAsFixed(1)} L szirup',
        Icons.water_drop,
        Colors.cyanAccent,
      );
    }

    if (meta['net_kg'] is num) {
      addChip(
        '${(meta['net_kg'] as num).toStringAsFixed(1)} kg méz',
        Icons.scale,
        Colors.amber,
      );
    }

    if (entry.isAutoTelemetry) {
      if (meta['inner_temp'] is num) {
        addChip(
          '${(meta['inner_temp'] as num).toStringAsFixed(1)} °C',
          Icons.thermostat_rounded,
          Colors.amberAccent,
        );
      }
      if (meta['humidity'] is num) {
        addChip(
          '${(meta['humidity'] as num).toStringAsFixed(0)}%',
          Icons.water_drop_outlined,
          Colors.lightBlueAccent,
        );
      }
      if (meta['weight'] is num) {
        addChip(
          '${(meta['weight'] as num).toStringAsFixed(2)} kg',
          Icons.scale_rounded,
          Colors.greenAccent,
        );
      }
      if (meta['noise'] is num) {
        addChip(
          '${(meta['noise'] as num).toStringAsFixed(0)} Hz',
          Icons.graphic_eq_rounded,
          Colors.purpleAccent,
        );
      }
    }

    if (meta['status'] is String &&
        (entry.actionKind == 'status' || entry.eventType == 'uj_kaptar')) {
      addChip(
        'Státusz: ${meta['status']}',
        Icons.circle,
        Colors.purpleAccent,
      );
    }

    if (meta['family_function'] is String &&
        (entry.actionKind == 'function' ||
            entry.actionKind == 'warning' ||
            entry.eventType == 'uj_kaptar')) {
      addChip(
        getHiveFamilyFunctionLabel(meta['family_function'].toString()),
        Icons.work_outline,
        Colors.amberAccent,
      );
    }

    return chips;
  }

  void _showEntryDetailsSheet(HistoryLogEntry entry) {
    final color = _getEntryColor(entry);
    final targetName = widget.repository.resolveTargetDisplayName(
      entry.monitorMac,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141428),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final meta = entry.metadata;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withAlpha(35),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Icon(_getEntryIcon(entry), color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.actionBadgeLabel,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$targetName (${entry.monitorMac})',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 24),
                Text(
                  entry.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: Colors.amberAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Időpont: ${_formatDayHeader(entry.createdAt)} ${_formatTime(entry.createdAt)}',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      entry.dbId != null
                          ? 'DB #${entry.dbId}'
                          : 'Offline sorban',
                      style: TextStyle(
                        color: entry.dbId != null
                            ? Colors.tealAccent
                            : Colors.orangeAccent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                if (meta != null && meta.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Rögzített paraméterek:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: meta.entries
                          .where((e) => e.value != null && e.value.toString().isNotEmpty)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 145,
                                    child: Text(
                                      '${e.key}:',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11.5,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${e.value}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchCtrl.text.trim().toLowerCase();
    final List<HistoryLogEntry> hiveScoped = widget.repository.historyLogs
        .where((e) => _matchesHiveFilter(e) && _matchesSearch(e, query))
        .toList();

    int boxesAdded = 0;
    int boxesRemoved = 0;
    int boxesTotal = 0;
    int zubehorCount = 0;
    int treatmentsCount = 0;
    int classificationCount = 0;
    int telemetryCount = 0;
    int otherCount = 0;

    for (final e in hiveScoped) {
      switch (e.mainCategory) {
        case 'boxes':
          boxesTotal++;
          if (e.isAddedAction) boxesAdded++;
          if (e.isRemovedAction) boxesRemoved++;
          break;
        case 'zubehor':
          zubehorCount++;
          break;
        case 'treatments':
          treatmentsCount++;
          break;
        case 'classification':
          classificationCount++;
          break;
        case 'telemetry':
          telemetryCount++;
          break;
        default:
          otherCount++;
      }
    }

    final Map<String, int> tabCounts = {
      'all': _showAutoTelemetryInAll
          ? hiveScoped.length
          : (hiveScoped.length - telemetryCount),
      'boxes': boxesTotal,
      'zubehor': zubehorCount,
      'treatments': treatmentsCount,
      'classification': classificationCount,
      'telemetry': telemetryCount,
      'other': otherCount,
    };

    final List<HistoryLogEntry> filtered = hiveScoped.where((e) {
      if (_selectedCategory == 'all' &&
          !_showAutoTelemetryInAll &&
          e.isAutoTelemetry) {
        return false;
      }
      if (_selectedCategory != 'all' && e.mainCategory != _selectedCategory) {
        return false;
      }
      if ((_selectedCategory == 'boxes' || _selectedCategory == 'zubehor') &&
          _directionFilter != 'all') {
        if (_directionFilter == 'added' && !e.isAddedAction) return false;
        if (_directionFilter == 'removed' && !e.isRemovedAction) return false;
      }
      return true;
    }).toList();

    // Napi csoportosítás a szép, átlátható idővonalhoz
    final List<MapEntry<String, List<HistoryLogEntry>>> groupedByDay = [];
    for (final entry in filtered) {
      final header = _formatDayHeader(entry.createdAt);
      if (groupedByDay.isEmpty || groupedByDay.last.key != header) {
        groupedByDay.add(MapEntry(header, [entry]));
      } else {
        groupedByDay.last.value.add(entry);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        foregroundColor: Colors.amberAccent,
        title: const Row(
          children: [
            Icon(Icons.manage_history_rounded, color: Colors.amberAccent, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Kaptárnapló & Előzmények',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Előzmények frissítése a Supabase-ből',
            onPressed: _isRefreshing
                ? null
                : () async {
                    setState(() => _isRefreshing = true);
                    await widget.repository.refreshHistoryFromSupabase(
                      limit: 300,
                    );
                    if (mounted) setState(() => _isRefreshing = false);
                  },
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.tealAccent,
                    ),
                  )
                : const Icon(Icons.sync, color: Colors.tealAccent),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── 1. FELSŐ SZŰRŐ PANEL (KAPTÁR + KERESÉS + 4 ÁTTEKINTŐ KÁRTYA + KATEGÓRIA FÜLEK) ───
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFF141428),
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedHiveFilter != 'ALL'
                                  ? Colors.amberAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedHiveFilter,
                              dropdownColor: const Color(0xFF1E293B),
                              isExpanded: true,
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.amberAccent,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text('🐝 Összes kaptár & egység'),
                                ),
                                ...widget.repository.hives.map(
                                  (h) => DropdownMenuItem(
                                    value: h.id,
                                    child: Text(
                                      h.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const DropdownMenuItem(
                                  value: 'NON_HIVE',
                                  child: Text('🏢 Iroda / Pergető / Rendszer'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedHiveFilter = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Keresés...',
                              hintStyle: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.white54,
                                size: 18,
                              ),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Colors.white54,
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Colors.white24,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 4 GYORS ÖSSZEFOGLALÓ KÁRTYA (FIÓKOK, ZUBEHÖR, KEZELÉSEK, OSZTÁLYOZÁS)
                  Row(
                    children: [
                      _buildSummaryMetricTile(
                        categoryKey: 'boxes',
                        title: 'Fiókok',
                        valueText: '+$boxesAdded / −$boxesRemoved',
                        icon: Icons.inventory_2_rounded,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      _buildSummaryMetricTile(
                        categoryKey: 'zubehor',
                        title: 'Zubehör',
                        valueText: '$zubehorCount db',
                        icon: Icons.extension_rounded,
                        color: const Color(0xFF14B8A6),
                      ),
                      const SizedBox(width: 6),
                      _buildSummaryMetricTile(
                        categoryKey: 'treatments',
                        title: 'Kezelés',
                        valueText: '$treatmentsCount db',
                        icon: Icons.medical_services_rounded,
                        color: const Color(0xFFEC4899),
                      ),
                      const SizedBox(width: 6),
                      _buildSummaryMetricTile(
                        categoryKey: 'classification',
                        title: 'Osztályzás',
                        valueText: '$classificationCount db',
                        icon: Icons.workspace_premium_rounded,
                        color: const Color(0xFFFBBF24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // KATEGÓRIA SZŰRŐ FÜLEK
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categoryTabs.map((tab) {
                        final String id = tab['id'] as String;
                        final bool isSelected = _selectedCategory == id;
                        final int count = tabCounts[id] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            selected: isSelected,
                            showCheckmark: false,
                            backgroundColor: const Color(0xFF0F172A),
                            selectedColor: Colors.amberAccent.withAlpha(45),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.amberAccent
                                  : Colors.white24,
                              width: isSelected ? 1.6 : 1.0,
                            ),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tab['icon'] as IconData,
                                  size: 15,
                                  color: isSelected
                                      ? Colors.amberAccent
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${tab['label']} ($count)',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.amberAccent
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = id;
                                if (id != 'boxes' && id != 'zubehor') {
                                  _directionFilter = 'all';
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // EXTRA IRÁNY-SZŰRŐ FIÓKOKHOZ ÉS ZUBEHÖRHÖZ (+ Felrakott vs − Levett)
                  if (_selectedCategory == 'boxes' ||
                      _selectedCategory == 'zubehor') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDirectionPill('all', 'Mind', Colors.amberAccent),
                        const SizedBox(width: 6),
                        _buildDirectionPill(
                          'added',
                          '+ Felrakott / Bekapcsolt',
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        _buildDirectionPill(
                          'removed',
                          '− Levett / Kikapcsolt',
                          const Color(0xFFF97316),
                        ),
                      ],
                    ),
                  ] else if (_selectedCategory == 'all') ...[
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(
                        () =>
                            _showAutoTelemetryInAll = !_showAutoTelemetryInAll,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _showAutoTelemetryInAll
                              ? const Color(0xFF38BDF8).withAlpha(28)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _showAutoTelemetryInAll
                                ? const Color(0xFF38BDF8).withAlpha(140)
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _showAutoTelemetryInAll
                                  ? Icons.sensors_rounded
                                  : Icons.sensors_off_rounded,
                              size: 15,
                              color: _showAutoTelemetryInAll
                                  ? const Color(0xFF38BDF8)
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _showAutoTelemetryInAll
                                    ? 'Automata ESP32 szenzormérések látszanak az idővonalon ($telemetryCount db)'
                                    : 'Automata ESP32 szenzormérések elrejtve ($telemetryCount db) – csak beavatkozások',
                                style: TextStyle(
                                  color: _showAutoTelemetryInAll
                                      ? const Color(0xFF38BDF8)
                                      : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch(
                              value: _showAutoTelemetryInAll,
                              activeThumbColor: const Color(0xFF38BDF8),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) =>
                                  setState(() => _showAutoTelemetryInAll = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ─── 2. IDŐRENDI NAPLÓ LISTA (NAPI CSOPORTOSÍTÁSSAL) ───
            Expanded(
              child: RefreshIndicator(
                color: Colors.amberAccent,
                backgroundColor: const Color(0xFF1E293B),
                onRefresh: () =>
                    widget.repository.refreshHistoryFromSupabase(limit: 300),
                child: groupedByDay.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 64,
                            color: Colors.white.withAlpha(45),
                          ),
                          const SizedBox(height: 12),
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Nincs a szűrőnek megfelelő naplóbejegyzés.\nMinden új fiók-, zubehör-, kezelés- és osztályozás-módosítás automatikusan megjelenik itt.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                        itemCount: groupedByDay.length,
                        itemBuilder: (context, dayIdx) {
                          final dayGroup = groupedByDay[dayIdx];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  bottom: 8,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.amberAccent.withAlpha(
                                            90,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.calendar_today_rounded,
                                            size: 12,
                                            color: Colors.amberAccent,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            dayGroup.key,
                                            style: const TextStyle(
                                              color: Colors.amberAccent,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${dayGroup.value.length} esemény',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Divider(
                                        color: Colors.white12,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...dayGroup.value.map(_buildHistoryCard),
                              const SizedBox(height: 6),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetricTile({
    required String categoryKey,
    required String title,
    required String valueText,
    required IconData icon,
    required Color color,
  }) {
    final bool active = _selectedCategory == categoryKey;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _selectedCategory = active ? 'all' : categoryKey;
            _directionFilter = 'all';
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? color.withAlpha(38) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color : color.withAlpha(80),
              width: active ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  valueText,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionPill(String key, String label, Color color) {
    final bool selected = _directionFilter == key;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _directionFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(40) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : Colors.white12,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? color : Colors.white60,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(HistoryLogEntry entry) {
    final Color color = _getEntryColor(entry);
    final IconData icon = _getEntryIcon(entry);
    final String targetName = widget.repository.resolveTargetDisplayName(
      entry.monitorMac,
    );
    final bool isHiveTarget = widget.repository.hives.any(
      (h) => h.id == entry.monitorMac,
    );
    final List<Widget> metaChips = _buildMetadataChips(entry);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showEntryDetailsSheet(entry),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141428),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(90)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: color, size: 17),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(35),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  entry.actionBadgeLabel,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: GestureDetector(
                                  onTap: isHiveTarget
                                      ? () {
                                          setState(() {
                                            _selectedHiveFilter =
                                                _selectedHiveFilter ==
                                                    entry.monitorMac
                                                ? 'ALL'
                                                : entry.monitorMac;
                                          });
                                        }
                                      : null,
                                  child: Text(
                                    targetName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatTime(entry.createdAt),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              height: 1.32,
                            ),
                          ),
                          if (metaChips.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 6,
                              runSpacing: 5,
                              children: metaChips,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
