import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../hive_model.dart';
import '../services/hive_repository.dart';

class _DailyWeatherAggregate {
  final DateTime day;
  final List<WeatherLogPoint> hours;
  final double minTemp;
  final double maxTemp;
  final double avgTemp;
  final double avgHumidity;
  final double avgPressure;
  final double maxWind;
  final String dominantWindDir;
  final double totalRainMm;
  final double maxUv;
  final int beeFlightHours;

  const _DailyWeatherAggregate({
    required this.day,
    required this.hours,
    required this.minTemp,
    required this.maxTemp,
    required this.avgTemp,
    required this.avgHumidity,
    required this.avgPressure,
    required this.maxWind,
    required this.dominantWindDir,
    required this.totalRainMm,
    required this.maxUv,
    required this.beeFlightHours,
  });

  static _DailyWeatherAggregate fromHours(
    DateTime day,
    List<WeatherLogPoint> pts,
  ) {
    double minT = pts.first.tempC;
    double maxT = pts.first.tempC;
    double sumT = 0;
    double sumH = 0;
    double sumP = 0;
    double maxW = 0;
    String maxWDir = pts.first.windDirection;
    double sumRain = 0;
    double peakUv = 0;
    int flightHrs = 0;

    for (final p in pts) {
      if (p.tempC < minT) minT = p.tempC;
      if (p.tempC > maxT) maxT = p.tempC;
      sumT += p.tempC;
      sumH += p.humidityPct;
      sumP += p.pressureHpa;
      if (p.windSpeedMs >= maxW) {
        maxW = p.windSpeedMs;
        maxWDir = p.windDirection;
      }
      sumRain += p.rainMm;
      if (p.uvIndex > peakUv) peakUv = p.uvIndex;
      if (p.isGoodBeeFlightHour) flightHrs++;
    }
    final n = pts.length;
    return _DailyWeatherAggregate(
      day: day,
      hours: pts,
      minTemp: minT,
      maxTemp: maxT,
      avgTemp: sumT / n,
      avgHumidity: sumH / n,
      avgPressure: sumP / n,
      maxWind: maxW,
      dominantWindDir: maxWDir,
      totalRainMm: sumRain,
      maxUv: peakUv,
      beeFlightHours: flightHrs,
    );
  }
}

class WeatherHistoryScreen extends StatefulWidget {
  final HiveRepository repository;
  final String initialRange;

  const WeatherHistoryScreen({
    super.key,
    required this.repository,
    this.initialRange = 'today',
  });

  @override
  State<WeatherHistoryScreen> createState() => _WeatherHistoryScreenState();
}

class _WeatherHistoryScreenState extends State<WeatherHistoryScreen> {
  // 'today' | 'yesterday' | 'this_week' | 'last_week' | 'month'
  late String _selectedRange;
  // 'temp' | 'humidity' | 'rain' | 'wind' | 'pressure'
  String _selectedMetric = 'temp';
  bool _isRefreshing = false;

  static const List<Map<String, dynamic>> _rangeTabs = [
    {'id': 'today', 'label': 'Ma (Óránként)', 'icon': Icons.today_rounded},
    {
      'id': 'yesterday',
      'label': 'Tegnap (Óránként)',
      'icon': Icons.history_rounded,
    },
    {
      'id': 'this_week',
      'label': 'Ezen a héten',
      'icon': Icons.date_range_rounded,
    },
    {
      'id': 'last_week',
      'label': 'Múlt héten',
      'icon': Icons.event_repeat_rounded,
    },
    {
      'id': 'month',
      'label': 'Elmúlt 30 nap',
      'icon': Icons.calendar_month_rounded,
    },
  ];

  static const List<Map<String, dynamic>> _metricOptions = [
    {
      'id': 'temp',
      'label': 'Hőfok (°C)',
      'icon': Icons.thermostat_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'id': 'rain',
      'label': 'Eső (mm)',
      'icon': Icons.umbrella_rounded,
      'color': Color(0xFF3B82F6),
    },
    {
      'id': 'wind',
      'label': 'Szél (m/s)',
      'icon': Icons.air_rounded,
      'color': Color(0xFF06B6D4),
    },
    {
      'id': 'humidity',
      'label': 'Pára (%)',
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF38BDF8),
    },
    {
      'id': 'pressure',
      'label': 'Nyomás (hPa)',
      'icon': Icons.speed_rounded,
      'color': Color(0xFFA855F7),
    },
  ];

  static const List<String> _hunWeekdays = [
    'Hétfő',
    'Kedd',
    'Szerda',
    'Csütörtök',
    'Péntek',
    'Szombat',
    'Vasárnap',
  ];

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.initialRange;
    widget.repository.addListener(_onRepoChanged);
    _refreshFromCloud();
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshFromCloud() async {
    if (!widget.repository.isOnline) return;
    setState(() => _isRefreshing = true);
    await widget.repository.refreshWeatherHistoryFromSupabase(days: 32);
    if (mounted) setState(() => _isRefreshing = false);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeekMonday(DateTime d) {
    final clean = DateTime(d.year, d.month, d.day);
    return clean.subtract(Duration(days: clean.weekday - 1));
  }

  String _formatDateShort(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}.';

  String _formatDateFull(DateTime d) =>
      '${d.year}. ${d.month.toString().padLeft(2, '0')}. ${d.day.toString().padLeft(2, '0')}. (${_hunWeekdays[d.weekday - 1]})';

  IconData _weatherConditionIcon({
    required double rainMm,
    required double lightLux,
    required int hour,
    required double humidityPct,
  }) {
    if (rainMm >= 1.5) return Icons.thunderstorm_rounded;
    if (rainMm >= 0.2) return Icons.grain_rounded;
    final bool isNight = lightLux < 500 && (hour < 6 || hour >= 20);
    if (isNight) return Icons.nights_stay_rounded;
    if (humidityPct >= 82) return Icons.cloud_rounded;
    if (humidityPct >= 64) return Icons.wb_cloudy_rounded;
    return Icons.wb_sunny_rounded;
  }

  Color _weatherConditionColor({
    required double rainMm,
    required double lightLux,
    required int hour,
    required double humidityPct,
  }) {
    if (rainMm >= 0.2) return Colors.lightBlueAccent;
    final bool isNight = lightLux < 500 && (hour < 6 || hour >= 20);
    if (isNight) return Colors.indigo.shade200;
    if (humidityPct >= 78) return Colors.blueGrey.shade200;
    return Colors.amberAccent;
  }

  void _showDayHourlySheet(_DailyWeatherAggregate dayAgg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final sortedHours = List<WeatherLogPoint>.from(dayAgg.hours)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.84,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF141428),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: Colors.amberAccent,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDateFull(dayAgg.day),
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Min ${dayAgg.minTemp.toStringAsFixed(1)}°C • Max ${dayAgg.maxTemp.toStringAsFixed(1)}°C • Eső: ${dayAgg.totalRainMm.toStringAsFixed(1)} mm • 🐝 ${dayAgg.beeFlightHours} röpóra',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: sortedHours.length,
                  itemBuilder: (_, i) => _buildHourlyRowCard(sortedHours[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPoints = widget.repository.getEffectiveWeatherHistory(days: 32);
    final bool isLiveCloudData = widget.repository.hasLiveWeatherLogs;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisMonday = _startOfWeekMonday(today);
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final lastSunday = thisMonday.subtract(const Duration(days: 1));
    final monthAgo = today.subtract(const Duration(days: 29));

    final bool isHourlyMode =
        _selectedRange == 'today' || _selectedRange == 'yesterday';

    List<WeatherLogPoint> rangePoints = [];
    String rangeSubtitle = '';

    if (_selectedRange == 'today') {
      rangePoints = allPoints
          .where((p) => _isSameDay(p.timestamp, today))
          .toList();
      rangeSubtitle = 'Ma óránként (${_formatDateFull(today)})';
    } else if (_selectedRange == 'yesterday') {
      rangePoints = allPoints
          .where((p) => _isSameDay(p.timestamp, yesterday))
          .toList();
      rangeSubtitle = 'Tegnap 00:00–23:00 (${_formatDateFull(yesterday)})';
    } else if (_selectedRange == 'this_week') {
      rangePoints = allPoints.where((p) {
        final d = DateTime(p.timestamp.year, p.timestamp.month, p.timestamp.day);
        return !d.isBefore(thisMonday) && !d.isAfter(today);
      }).toList();
      rangeSubtitle =
          'Ezen a héten (${_formatDateShort(thisMonday)} – ${_formatDateShort(today)})';
    } else if (_selectedRange == 'last_week') {
      rangePoints = allPoints.where((p) {
        final d = DateTime(p.timestamp.year, p.timestamp.month, p.timestamp.day);
        return !d.isBefore(lastMonday) && !d.isAfter(lastSunday);
      }).toList();
      rangeSubtitle =
          'Múlt héten (${_formatDateShort(lastMonday)} – ${_formatDateShort(lastSunday)})';
    } else {
      rangePoints = allPoints.where((p) {
        final d = DateTime(p.timestamp.year, p.timestamp.month, p.timestamp.day);
        return !d.isBefore(monthAgo) && !d.isAfter(today);
      }).toList();
      rangeSubtitle =
          'Elmúlt 30 nap (${_formatDateShort(monthAgo)} – ${_formatDateShort(today)})';
    }

    rangePoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Napi aggregációk kiszámítása a heti / havi nézethez
    final Map<DateTime, List<WeatherLogPoint>> byDayMap = {};
    for (final p in rangePoints) {
      final d = DateTime(p.timestamp.year, p.timestamp.month, p.timestamp.day);
      byDayMap.putIfAbsent(d, () => []).add(p);
    }
    final List<_DailyWeatherAggregate> dailyAggregates = byDayMap.entries
        .map((e) => _DailyWeatherAggregate.fromHours(e.key, e.value))
        .toList()
      ..sort((a, b) => b.day.compareTo(a.day)); // Legfrissebb nap felül a listában

    double periodMinTemp = 0;
    double periodMaxTemp = 0;
    double periodRain = 0;
    double periodMaxWind = 0;
    String periodWindDir = 'ÉNy';
    int periodBeeHours = 0;

    if (rangePoints.isNotEmpty) {
      periodMinTemp = rangePoints.first.tempC;
      periodMaxTemp = rangePoints.first.tempC;
      for (final p in rangePoints) {
        if (p.tempC < periodMinTemp) periodMinTemp = p.tempC;
        if (p.tempC > periodMaxTemp) periodMaxTemp = p.tempC;
        periodRain += p.rainMm;
        if (p.windSpeedMs >= periodMaxWind) {
          periodMaxWind = p.windSpeedMs;
          periodWindDir = p.windDirection;
        }
        if (p.isGoodBeeFlightHour) periodBeeHours++;
      }
    }

    // Grafikon adatpontok összeállítása (óránkénti vagy napi bontásban, kronológiai sorrendben)
    final List<double> chartValues = [];
    final List<String> chartLabels = [];
    if (isHourlyMode) {
      for (final p in rangePoints) {
        chartLabels.add('${p.timestamp.hour.toString().padLeft(2, '0')}h');
        chartValues.add(_extractMetricFromPoint(p, _selectedMetric));
      }
    } else {
      final ascDays = List<_DailyWeatherAggregate>.from(dailyAggregates)
        ..sort((a, b) => a.day.compareTo(b.day));
      for (final d in ascDays) {
        chartLabels.add(_formatDateShort(d.day));
        chartValues.add(_extractMetricFromDay(d, _selectedMetric));
      }
    }

    final activeMetricMeta = _metricOptions.firstWhere(
      (m) => m['id'] == _selectedMetric,
      orElse: () => _metricOptions.first,
    );
    final Color activeMetricColor = activeMetricMeta['color'] as Color;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141428),
        foregroundColor: Colors.amberAccent,
        title: Row(
          children: [
            const Icon(Icons.wb_sunny_rounded, color: Colors.amberAccent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Időjárás Előzmények (${widget.repository.weatherStation.name})',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Frissítés a Supabase weather_logs táblából',
            onPressed: _isRefreshing ? null : _refreshFromCloud,
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
            // ─── IDŐTARTAM VÁLASZTÓ SÁV (MA, TEGNAP, EZEN A HÉTEN, MÚLT HÉTEN, 30 NAP) ───
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: Color(0xFF141428),
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _rangeTabs.map((tab) {
                        final String id = tab['id'] as String;
                        final bool selected = _selectedRange == id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: selected,
                            showCheckmark: false,
                            backgroundColor: const Color(0xFF0F172A),
                            selectedColor: Colors.amberAccent.withAlpha(45),
                            side: BorderSide(
                              color: selected
                                  ? Colors.amberAccent
                                  : Colors.white24,
                              width: selected ? 1.8 : 1.0,
                            ),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tab['icon'] as IconData,
                                  size: 16,
                                  color: selected
                                      ? Colors.amberAccent
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tab['label'] as String,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.amberAccent
                                        : Colors.white70,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedRange = id),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rangeSubtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isLiveCloudData
                              ? Colors.teal.withAlpha(45)
                              : Colors.blueGrey.withAlpha(45),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isLiveCloudData
                                ? Colors.tealAccent
                                : Colors.white24,
                          ),
                        ),
                        child: Text(
                          isLiveCloudData
                              ? 'Élő Supabase mérések'
                              : 'Előnézeti adatsor',
                          style: TextStyle(
                            color: isLiveCloudData
                                ? Colors.tealAccent
                                : Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── GÖRGETHETŐ TARTALOM: KPI KÁRTYÁK + GRAFIKON + ÓRÁNKÉNTI/NAPI LISTA ───
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                children: [
                  // 1. ÖSSZEFOGLALÓ MÉRŐSZÁMOK (4 KÁRTYA)
                  Row(
                    children: [
                      _buildKpiTile(
                        title: 'Min / Max',
                        value:
                            '${periodMinTemp.toStringAsFixed(1)}° / ${periodMaxTemp.toStringAsFixed(1)}°C',
                        icon: Icons.thermostat_rounded,
                        color: Colors.amberAccent,
                      ),
                      const SizedBox(width: 8),
                      _buildKpiTile(
                        title: 'Csapadék',
                        value: '${periodRain.toStringAsFixed(1)} mm',
                        icon: Icons.umbrella_rounded,
                        color: Colors.lightBlueAccent,
                      ),
                      const SizedBox(width: 8),
                      _buildKpiTile(
                        title: 'Max Szél',
                        value:
                            '${periodMaxWind.toStringAsFixed(1)} m/s ($periodWindDir)',
                        icon: Icons.air_rounded,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(width: 8),
                      _buildKpiTile(
                        title: 'Méhrepülés',
                        value: '$periodBeeHours röpóra',
                        icon: Icons.hive_rounded,
                        color: Colors.greenAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. INTERAKTÍV TREND GRAFIKON KÁRTYA
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141428),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: activeMetricColor.withAlpha(100),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _metricOptions.map((m) {
                              final String mId = m['id'] as String;
                              final bool sel = _selectedMetric == mId;
                              final Color mColor = m['color'] as Color;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () =>
                                      setState(() => _selectedMetric = mId),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? mColor.withAlpha(42)
                                          : const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: sel ? mColor : Colors.white12,
                                        width: sel ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          m['icon'] as IconData,
                                          size: 14,
                                          color: sel ? mColor : Colors.white60,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          m['label'] as String,
                                          style: TextStyle(
                                            color: sel ? mColor : Colors.white70,
                                            fontSize: 11,
                                            fontWeight: sel
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 155,
                          width: double.infinity,
                          child: chartValues.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Nincs megjeleníthető mérési pont',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : CustomPaint(
                                  painter: _WeatherChartPainter(
                                    values: chartValues,
                                    labels: chartLabels,
                                    color: activeMetricColor,
                                    isBarChart: _selectedMetric == 'rain',
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. RÉSZLETES ÓRÁNKÉNTI VAGY NAPI BONTÁSÚ LISTA
                  Row(
                    children: [
                      Icon(
                        isHourlyMode
                            ? Icons.access_time_filled_rounded
                            : Icons.calendar_view_day_rounded,
                        color: Colors.amberAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHourlyMode
                              ? 'Óránkénti részletezés (${rangePoints.length} óra)'
                              : 'Napi összesítő (${dailyAggregates.length} nap – koppints egy napra az óránkénti bontáshoz!)',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (isHourlyMode)
                    ...(List<WeatherLogPoint>.from(rangePoints.reversed))
                        .map(_buildHourlyRowCard)
                  else
                    ...dailyAggregates.map(
                      (d) => _buildDailyRowCard(
                        d,
                        periodMinTemp: periodMinTemp,
                        periodMaxTemp: periodMaxTemp,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _extractMetricFromPoint(WeatherLogPoint p, String metric) {
    switch (metric) {
      case 'rain':
        return p.rainMm;
      case 'wind':
        return p.windSpeedMs;
      case 'humidity':
        return p.humidityPct;
      case 'pressure':
        return p.pressureHpa;
      default:
        return p.tempC;
    }
  }

  double _extractMetricFromDay(_DailyWeatherAggregate d, String metric) {
    switch (metric) {
      case 'rain':
        return d.totalRainMm;
      case 'wind':
        return d.maxWind;
      case 'humidity':
        return d.avgHumidity;
      case 'pressure':
        return d.avgPressure;
      default:
        return d.maxTemp;
    }
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF141428),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyRowCard(WeatherLogPoint p) {
    final condIcon = _weatherConditionIcon(
      rainMm: p.rainMm,
      lightLux: p.lightLux,
      hour: p.timestamp.hour,
      humidityPct: p.humidityPct,
    );
    final condColor = _weatherConditionColor(
      rainMm: p.rainMm,
      lightLux: p.lightLux,
      hour: p.timestamp.hour,
      humidityPct: p.humidityPct,
    );

    String flightText;
    Color flightColor;
    if (p.isGoodBeeFlightHour) {
      flightText = '🐝 Jó röp';
      flightColor = Colors.greenAccent;
    } else if (p.rainMm >= 0.2) {
      flightText = '🌧️ Eső (${p.rainMm.toStringAsFixed(1)} mm)';
      flightColor = Colors.lightBlueAccent;
    } else if (p.windSpeedMs >= 7.5) {
      flightText = '💨 Erős szél';
      flightColor = Colors.orangeAccent;
    } else if (p.timestamp.hour < 6 || p.timestamp.hour >= 20) {
      flightText = '🌙 Éjjel';
      flightColor = Colors.white38;
    } else {
      flightText = '❄️ Hűvös';
      flightColor = Colors.cyanAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141428),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: p.isGoodBeeFlightHour
              ? Colors.greenAccent.withAlpha(55)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              '${p.timestamp.hour.toString().padLeft(2, '0')}:00',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          Icon(condIcon, color: condColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${p.tempC.toStringAsFixed(1)} °C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '💧 ${p.humidityPct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '💨 ${p.windSpeedMs.toStringAsFixed(1)} m/s (${p.windDirection})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${p.pressureHpa.toStringAsFixed(1)} hPa • UV ${p.uvIndex.toStringAsFixed(1)} • ${(p.lightLux / 1000).toStringAsFixed(1)} klx',
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: flightColor.withAlpha(28),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: flightColor.withAlpha(90)),
            ),
            child: Text(
              flightText,
              style: TextStyle(
                color: flightColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRowCard(
    _DailyWeatherAggregate d, {
    required double periodMinTemp,
    required double periodMaxTemp,
  }) {
    final condIcon = _weatherConditionIcon(
      rainMm: d.totalRainMm,
      lightLux: 15000,
      hour: 13,
      humidityPct: d.avgHumidity,
    );
    final condColor = _weatherConditionColor(
      rainMm: d.totalRainMm,
      lightLux: 15000,
      hour: 13,
      humidityPct: d.avgHumidity,
    );

    final double span = math.max(1.0, periodMaxTemp - periodMinTemp);
    final double startFrac = ((d.minTemp - periodMinTemp) / span).clamp(
      0.0,
      1.0,
    );
    final double widthFrac = ((d.maxTemp - d.minTemp) / span).clamp(0.08, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDayHourlySheet(d),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF141428),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(condIcon, color: condColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatDateShort(d.day)} ${_hunWeekdays[d.day.weekday - 1]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '🐝 ${d.beeFlightHours} röpóra • Szél max ${d.maxWind.toStringAsFixed(1)} m/s (${d.dominantWindDir})',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (d.totalRainMm > 0) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🌧️ ${d.totalRainMm.toStringAsFixed(1)} mm',
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    Text(
                      '${d.minTemp.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 58,
                      height: 7,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Positioned(
                                left: w * startFrac,
                                width: math.min(
                                  w * widthFrac,
                                  w * (1.0 - startFrac),
                                ),
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.lightBlueAccent,
                                        Colors.amberAccent,
                                        Colors.orangeAccent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${d.maxTemp.toStringAsFixed(0)}°C',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final bool isBarChart;

  _WeatherChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.isBarChart,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const double leftPad = 36.0;
    const double rightPad = 8.0;
    const double topPad = 10.0;
    const double bottomPad = 22.0;

    final double chartW = math.max(10.0, size.width - leftPad - rightPad);
    final double chartH = math.max(10.0, size.height - topPad - bottomPad);

    double minV = values.reduce(math.min);
    double maxV = values.reduce(math.max);
    if (isBarChart) {
      minV = 0.0;
      if (maxV < 1.0) maxV = 1.0;
    } else if ((maxV - minV).abs() < 0.5) {
      minV -= 1.0;
      maxV += 1.0;
    } else {
      final pad = (maxV - minV) * 0.12;
      minV -= pad;
      maxV += pad;
    }
    final double range = math.max(0.001, maxV - minV);

    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(22)
      ..strokeWidth = 1;

    // 3 vízszintes segédvonal + Y tengely feliratok
    for (int i = 0; i <= 2; i++) {
      final double frac = i / 2.0;
      final double y = topPad + chartH * (1.0 - frac);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + chartW, y),
        gridPaint,
      );
      final double val = minV + range * frac;
      final tp = TextPainter(
        text: TextSpan(
          text: val.abs() >= 900
              ? val.toStringAsFixed(0)
              : val.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9.5,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPad - 4);
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    final int n = values.length;
    double xAt(int i) =>
        n <= 1 ? leftPad + chartW / 2 : leftPad + (i / (n - 1)) * chartW;
    double yAt(double v) =>
        topPad + chartH * (1.0 - ((v - minV) / range).clamp(0.0, 1.0));

    if (isBarChart) {
      final double slotW = chartW / math.max(1, n);
      final double barW = (slotW * 0.62).clamp(3.0, 18.0);
      final barPaint = Paint()..color = color;
      for (int i = 0; i < n; i++) {
        final double cx = leftPad + slotW * (i + 0.5);
        final double topY = yAt(values[i]);
        final double bottomY = topPad + chartH;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              cx - barW / 2,
              math.min(topY, bottomY - 2),
              cx + barW / 2,
              bottomY,
            ),
            const Radius.circular(3),
          ),
          barPaint,
        );
      }
    } else {
      final Path linePath = Path();
      final Path fillPath = Path();
      for (int i = 0; i < n; i++) {
        final pt = Offset(xAt(i), yAt(values[i]));
        if (i == 0) {
          linePath.moveTo(pt.dx, pt.dy);
          fillPath.moveTo(pt.dx, topPad + chartH);
          fillPath.lineTo(pt.dx, pt.dy);
        } else {
          linePath.lineTo(pt.dx, pt.dy);
          fillPath.lineTo(pt.dx, pt.dy);
        }
      }
      fillPath.lineTo(xAt(n - 1), topPad + chartH);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(90), color.withAlpha(5)],
        ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH));
      canvas.drawPath(fillPath, fillPaint);

      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, strokePaint);

      final dotPaint = Paint()..color = color;
      if (n <= 31) {
        for (int i = 0; i < n; i++) {
          canvas.drawCircle(Offset(xAt(i), yAt(values[i])), 2.6, dotPaint);
        }
      }
    }

    // X tengely időfeliratok (max 6 felirat, hogy ne érjenek össze)
    final int step = math.max(1, (n / 5).ceil());
    for (int i = 0; i < n; i += step) {
      if (i >= labels.length) break;
      final double x = isBarChart
          ? leftPad + (chartW / n) * (i + 0.5)
          : xAt(i);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.white54, fontSize: 9.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (x - tp.width / 2).clamp(
        leftPad,
        leftPad + chartW - tp.width,
      );
      tp.paint(canvas, Offset(dx, topPad + chartH + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.isBarChart != isBarChart;
  }
}
