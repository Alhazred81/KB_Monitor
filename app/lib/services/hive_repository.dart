import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

import '../hive_model.dart';
import 'treatment_adviser.dart';

class HiveRepository extends ChangeNotifier {
  static final HiveRepository instance = HiveRepository._internal();
  HiveRepository._internal() {
    _initializeStartup();
  }

  Future<void> _initializeStartup() async {
    evaluateColonyRelapses(notify: false);
    await _loadConfig(notify: false);
    await _loadHivesBoxesLocally(notify: false);
    await _loadOfflineQueue();
    if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
      notifyListeners();
      syncWithSupabase();
    } else {
      _isOnline = false;
      _weatherStation.status = 'red';
      evaluateColonyRelapses(notify: false);
      notifyListeners();
    }
    // Periodikus kapcsolat-ellenőrzés 30 másodpercenként (háttérbe küldéskor automatikusan szünetel)
    _startHealthCheckTimer();
  }

  final http.Client _httpClient = http.Client();
  SharedPreferences? _cachedPrefs;
  Timer? _localSaveDebounceTimer;
  bool _isAppInForeground = true;
  bool _isProcessingQueue = false;

  String _supabaseUrl = '';
  String _supabaseAnonKey = '';
  bool _isSyncing = false;
  bool _isOnline = true; // Hálózati státusz jelző
  String _syncStatusText = 'Még nincs beállítva a Supabase kapcsolat';
  Timer? _healthCheckTimer;

  // Offline műveletek várólistája (queue)
  List<Map<String, dynamic>> _offlineQueue = [];
  final Set<String> _locallyPersistedHiveIds = {};
  List<Map<String, dynamic>>? _customCatalogItems;
  List<Map<String, dynamic>> get customCatalogItems =>
      _customCatalogItems ??= <Map<String, dynamic>>[];

  List<HistoryLogEntry>? _historyLogs;
  List<HistoryLogEntry> get historyLogs =>
      _historyLogs ??= <HistoryLogEntry>[];

  List<WeatherLogPoint>? _weatherLogs;
  List<WeatherLogPoint> get weatherLogs =>
      _weatherLogs ??= <WeatherLogPoint>[];

  bool get hasLiveWeatherLogs => weatherLogs.isNotEmpty;

  String resolveTargetDisplayName(String monitorMac) {
    final clean = monitorMac.trim();
    for (final h in _hives) {
      if (h.id == clean) return h.name;
    }
    switch (clean.toUpperCase()) {
      case 'OFFICE':
        return 'Iroda';
      case 'PROCESSING_ROOM':
        return 'Feldolgozó / Pergető';
      case 'MAP_LAYOUT':
        return 'Térkép elrendezés';
      case 'PUMP_01':
      case 'PUMP_MAIN':
        return _syrupPump.name;
      case 'WATER_01':
        return 'Itató';
      case 'WEATHER_01':
        return 'Időjárás-állomás';
      case 'ESP32_SERVER':
      case 'SYSTEM':
        return 'Szerver & Rendszer';
      default:
        return clean;
    }
  }

  void resetUnsupportedColumnsCache() {
    _unsupportedCols.clear();
  }

  Future<SharedPreferences> _getPrefs() async {
    return _cachedPrefs ??= await SharedPreferences.getInstance();
  }

  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    if (!_isAppInForeground) return;
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkConnectionHealth(),
    );
  }

  /// Alkalmazás életciklus váltás (háttérben leállítjuk a felesleges hálózati poll-t és azonnal mentünk)
  void setAppLifecycleActive(bool active) {
    if (_isAppInForeground == active) return;
    _isAppInForeground = active;
    if (!active) {
      _healthCheckTimer?.cancel();
      _healthCheckTimer = null;
      if (_localSaveDebounceTimer?.isActive == true) {
        _localSaveDebounceTimer?.cancel();
        _localSaveDebounceTimer = null;
        _flushHivesBoxesLocallyNow();
      }
    } else {
      _startHealthCheckTimer();
      checkConnectionHealth();
    }
  }

  String get supabaseUrl => _supabaseUrl;
  String get supabaseAnonKey => _supabaseAnonKey;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  String get syncStatusText => _syncStatusText;
  int get offlineQueueLength => _offlineQueue.length;

  String get sheetUrl => _supabaseUrl;

  Future<void> _loadConfig({bool notify = true}) async {
    final prefs = await _getPrefs();
    _supabaseUrl = prefs.getString('supabase_url') ?? '';
    _supabaseAnonKey = prefs.getString('supabase_anon_key') ?? '';
    if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
      _syncStatusText = 'Supabase konfigurálva. Szinkronizációra kész.';
    }
    if (notify) notifyListeners();
  }

  // Offline queue betöltése SharedPreferences-ből
  Future<void> _loadOfflineQueue() async {
    try {
      final prefs = await _getPrefs();
      final String? queueStr = prefs.getString('offline_queue');
      if (queueStr != null) {
        final List<dynamic> decoded = jsonDecode(queueStr);
        _offlineQueue = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Hiba az offline sor betöltésekor: $e');
    }
  }

  // Offline queue mentése SharedPreferences-be
  Future<void> _saveOfflineQueue() async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString('offline_queue', jsonEncode(_offlineQueue));
    } catch (e) {
      debugPrint('Hiba az offline sor mentésekor: $e');
    }
  }

  // Kaptárak torony/doboz-struktúrájának késleltetett (debounced) mentése, hogy a gyors sorozatműveletek ne terheljék a főszálat
  Future<void> _saveHivesBoxesLocally({bool immediate = false}) async {
    for (final hive in _hives) {
      _locallyPersistedHiveIds.add(hive.id);
    }
    if (immediate || !_isAppInForeground) {
      _localSaveDebounceTimer?.cancel();
      _localSaveDebounceTimer = null;
      await _flushHivesBoxesLocallyNow();
      return;
    }
    _localSaveDebounceTimer?.cancel();
    _localSaveDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      _localSaveDebounceTimer = null;
      _flushHivesBoxesLocallyNow();
    });
  }

  Future<void> _flushHivesBoxesLocallyNow() async {
    try {
      final prefs = await _getPrefs();
      final Map<String, dynamic> hivesMap = {};
      for (var hive in _hives) {
        _locallyPersistedHiveIds.add(hive.id);
        hivesMap[hive.id] = {
          'name': hive.name,
          'latitude': hive.location.latitude,
          'longitude': hive.location.longitude,
          'entrance_heading': hive.entranceHeading,
          'updated_at': hive.updatedAt.toIso8601String(),
          'tower_updated_at': hive.towerUpdatedAt.toIso8601String(),
          'status': hive.status,
          'protocol': hive.protocol,
          'family_function': hive.familyFunction,
          'daily_varroa_drop': hive.dailyVarroaDrop,
          'syrup_liters': hive.syrupLiters,
          'feeding_mode': hive.feedingMode,
          'feeding_max_liters': hive.feedingMaxLiters,
          'feeding_interval_hours': hive.feedingIntervalHours,
          'feeding_interval_days': hive.feedingIntervalDays,
          'feeding_stop_sunset_min': hive.feedingStopBeforeSunsetMinutes,
          'feeding_portion_liters': hive.feedingPortionLiters,
          'feeder_level_percent': hive.feederLevelPercent,
          'feeder_calib_empty_mm': hive.feederCalibEmptyMm,
          'feeder_calib_full_mm': hive.feederCalibFullMm,
          'feeder_raw_distance_mm': hive.feederRawDistanceMm,
          'paired_tank_id': hive.pairedTankId,
          'is_auto_paired': hive.isAutoPaired,
          'queen': hive.queen?.toJson(),
          'queen_replacement_state': hive.queenReplacementState,
          'queen_introduced_at': hive.queenIntroducedAt?.toIso8601String(),
          'locked_until': hive.lockedUntil?.toIso8601String(),
          'lock_reason': hive.lockReason,
          'acoustic_sentinel_active': hive.isAcousticSentinelActive,
          'acoustic_sample_interval_min': hive.acousticSampleIntervalMinutes,
          'evaluation': hive.evaluation.toJson(),
          'evaluation_notes': hive.evaluation.notes,
          'reported_diseases': hive.reportedDiseases,
          'last_strengthened_at': hive.lastStrengthenedAt?.toIso8601String(),
          'strengthening_count': hive.strengtheningCount,
          'weight_at_strengthening': hive.weightAtStrengthening,
          'has_relapsed_after_strengthening':
              hive.hasRelapsedAfterStrengthening,
          'relapse_reason': hive.relapseReason,
          'boxes': hive.boxes.map((b) => b.toJson()).toList(),
        };
      }
      await prefs.setString('local_hives_boxes', jsonEncode(hivesMap));
      await prefs.setString(
        'local_queens',
        jsonEncode(_queens.map((q) => q.toJson()).toList()),
      );
      await prefs.setString(
        'local_scheduled_tasks',
        jsonEncode(_scheduledTasks.map((t) => t.toJson()).toList()),
      );
      await prefs.setString(
        'local_custom_catalogs',
        jsonEncode(customCatalogItems),
      );
      await prefs.setString(
        'local_history_logs',
        jsonEncode(historyLogs.take(500).map((e) => e.toJson()).toList()),
      );
      if (weatherLogs.isNotEmpty) {
        await prefs.setString(
          'local_weather_logs',
          jsonEncode(weatherLogs.take(800).map((w) => w.toJson()).toList()),
        );
      }
      await prefs.setString(
        'local_map_devices',
        jsonEncode({
          'weather_lat': _weatherStation.location.latitude,
          'weather_lng': _weatherStation.location.longitude,
          'waterer_lat': _waterer.location.latitude,
          'waterer_lng': _waterer.location.longitude,
          'waterer_level': _waterer.waterLevel,
          'waterer_temp': _waterer.waterTemp,
          'waterer_interlocked': _waterer.isInterlocked,
          'waterer_reason': _waterer.emergencyStopReason,
          'pump_lat': _syrupPump.location.latitude,
          'pump_lng': _syrupPump.location.longitude,
          'pump_level': _syrupPump.tankLevelPercent,
          'pump_total_liters': _syrupPump.totalPumpedLiters,
          'pump_interlocked': _syrupPump.isPumpInterlocked,
          'pump_reason': _syrupPump.emergencyStopReason,
          'pump_status': _syrupPump.status,
        }),
      );
    } catch (e) {
      debugPrint('Hiba a kaptárfiókok helyi mentésekor: $e');
    }
  }

  // Kaptárak torony/doboz-struktúrájának és időbélyegeinek betöltése helyi memóriából
  Future<void> _loadHivesBoxesLocally({bool notify = true}) async {
    try {
      final prefs = await _getPrefs();

      final String? queensStr = prefs.getString('local_queens');
      if (queensStr != null && queensStr.isNotEmpty) {
        final List<dynamic> qDecoded = jsonDecode(queensStr);
        for (final item in qDecoded) {
          if (item is Map) {
            final q = QueenData.fromJson(Map<String, dynamic>.from(item));
            if (q.id.isNotEmpty) {
              final idx = _queens.indexWhere((eq) => eq.id == q.id);
              if (idx >= 0) {
                _queens[idx] = q;
              } else {
                _queens.add(q);
              }
            }
          }
        }
      }

      final String? tasksStr = prefs.getString('local_scheduled_tasks');
      if (tasksStr != null && tasksStr.isNotEmpty) {
        final List<dynamic> tDecoded = jsonDecode(tasksStr);
        _scheduledTasks
          ..clear()
          ..addAll(
            tDecoded.whereType<Map>().map(
              (m) => ScheduledTask.fromJson(Map<String, dynamic>.from(m)),
            ),
          );
      }

      final String? catStr = prefs.getString('local_custom_catalogs');
      if (catStr != null && catStr.isNotEmpty) {
        final List<dynamic> cDecoded = jsonDecode(catStr);
        customCatalogItems
          ..clear()
          ..addAll(
            cDecoded.whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
          );
      }

      final String? histStr = prefs.getString('local_history_logs');
      if (histStr != null && histStr.isNotEmpty) {
        final List<dynamic> hDecoded = jsonDecode(histStr);
        historyLogs
          ..clear()
          ..addAll(
            hDecoded.whereType<Map>().map(
              (m) => HistoryLogEntry.fromJson(Map<String, dynamic>.from(m)),
            ),
          );
        historyLogs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      final String? weatherStr = prefs.getString('local_weather_logs');
      if (weatherStr != null && weatherStr.isNotEmpty) {
        final List<dynamic> wDecoded = jsonDecode(weatherStr);
        weatherLogs
          ..clear()
          ..addAll(
            wDecoded.whereType<Map>().map(
              (m) => WeatherLogPoint.fromJson(Map<String, dynamic>.from(m)),
            ),
          );
        weatherLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }

      final String? devStr = prefs.getString('local_map_devices');
      if (devStr != null && devStr.isNotEmpty) {
        final dynamic d = jsonDecode(devStr);
        if (d is Map) {
          if (d['weather_lat'] is num && d['weather_lng'] is num) {
            _weatherStation.location = LatLng(
              (d['weather_lat'] as num).toDouble(),
              (d['weather_lng'] as num).toDouble(),
            );
          }
          if (d['waterer_lat'] is num && d['waterer_lng'] is num) {
            _waterer.location = LatLng(
              (d['waterer_lat'] as num).toDouble(),
              (d['waterer_lng'] as num).toDouble(),
            );
          }
          if (d['waterer_level'] is num) {
            _waterer.waterLevel = (d['waterer_level'] as num).toDouble();
          }
          if (d['waterer_temp'] is num) {
            _waterer.waterTemp = (d['waterer_temp'] as num).toDouble();
          }
          if (d['waterer_interlocked'] is bool) {
            _waterer.isInterlocked = d['waterer_interlocked'] as bool;
          }
          if (d['waterer_reason'] is String) {
            _waterer.emergencyStopReason = d['waterer_reason'] as String;
          }
          if (d['pump_lat'] is num && d['pump_lng'] is num) {
            _syrupPump.location = LatLng(
              (d['pump_lat'] as num).toDouble(),
              (d['pump_lng'] as num).toDouble(),
            );
          }
          if (d['pump_level'] is num) {
            _syrupPump.tankLevelPercent = (d['pump_level'] as num).toDouble();
          }
          if (d['pump_total_liters'] is num) {
            _syrupPump.totalPumpedLiters = (d['pump_total_liters'] as num)
                .toDouble();
          }
          if (d['pump_interlocked'] is bool) {
            _syrupPump.isPumpInterlocked = d['pump_interlocked'] as bool;
          }
          if (d['pump_reason'] is String) {
            _syrupPump.emergencyStopReason = d['pump_reason'] as String;
          }
          if (d['pump_status'] is String) {
            _syrupPump.status = d['pump_status'] as String;
          }
        }
      }

      final String? boxesStr = prefs.getString('local_hives_boxes');
      if (boxesStr != null && boxesStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(boxesStr);
        for (final mapEntry in decoded.entries) {
          final String hiveId = mapEntry.key;
          final dynamic entry = mapEntry.value;
          int hIdx = _hives.indexWhere((h) => h.id == hiveId);
          if (hIdx == -1 && entry is Map) {
            _hives.add(
              HiveData(
                id: hiveId,
                name: (entry['name'] ?? 'Kaptár ($hiveId)').toString(),
                location: LatLng(
                  (entry['latitude'] as num?)?.toDouble() ?? 37.422500,
                  (entry['longitude'] as num?)?.toDouble() ?? -122.084500,
                ),
                status: (entry['status'] ?? 'green').toString(),
                temp: 34.5,
                humidity: 60.0,
                extTemp: _weatherStation.temp,
                extHumidity: _weatherStation.humidity,
                weight: 30.0,
                batteryVoltage: 4.1,
                zcr: 3650.0,
                boxes: [],
                serverConnection: 'Helyi mentés',
              ),
            );
            hIdx = _hives.length - 1;
          }
          if (hIdx != -1) {
            final hive = _hives[hIdx];
            _locallyPersistedHiveIds.add(hive.id);
            if (entry is Map) {
              if (entry['name'] is String &&
                  (entry['name'] as String).trim().isNotEmpty) {
                hive.name = entry['name'] as String;
              }
              if (entry['latitude'] is num && entry['longitude'] is num) {
                hive.location = LatLng(
                  (entry['latitude'] as num).toDouble(),
                  (entry['longitude'] as num).toDouble(),
                );
              }
              if (entry['entrance_heading'] is num) {
                hive.entranceHeading = (entry['entrance_heading'] as num)
                    .toDouble();
              }
              if (entry['updated_at'] != null) {
                final dt = DateTime.tryParse(entry['updated_at'].toString());
                if (dt != null) hive.updatedAt = dt;
              }
              if (entry['tower_updated_at'] != null) {
                final dt = DateTime.tryParse(
                  entry['tower_updated_at'].toString(),
                );
                if (dt != null) hive.towerUpdatedAt = dt;
              }
              if (entry['status'] is String) {
                hive.status = entry['status'] as String;
              }
              if (entry['protocol'] is String) {
                hive.protocol = entry['protocol'] as String;
              }
              if (entry['family_function'] is String) {
                hive.familyFunction = entry['family_function'] as String;
              }
              if (entry['daily_varroa_drop'] is num) {
                hive.dailyVarroaDrop = (entry['daily_varroa_drop'] as num)
                    .toDouble();
              }
              if (entry['syrup_liters'] is num) {
                hive.syrupLiters = (entry['syrup_liters'] as num).toDouble();
              }
              if (entry['feeding_mode'] is String) {
                hive.feedingMode = entry['feeding_mode'] as String;
              }
              if (entry['feeding_max_liters'] is num) {
                hive.feedingMaxLiters = (entry['feeding_max_liters'] as num)
                    .toDouble();
              }
              if (entry['feeding_interval_hours'] is num) {
                hive.feedingIntervalHours =
                    (entry['feeding_interval_hours'] as num).toInt();
              }
              if (entry['feeding_interval_days'] is num) {
                hive.feedingIntervalDays =
                    (entry['feeding_interval_days'] as num).toInt();
              }
              if (entry['feeding_stop_sunset_min'] is num) {
                hive.feedingStopBeforeSunsetMinutes =
                    (entry['feeding_stop_sunset_min'] as num).toInt();
              }
              if (entry['feeding_portion_liters'] is num) {
                hive.feedingPortionLiters =
                    (entry['feeding_portion_liters'] as num).toDouble();
              }
              if (entry['feeder_level_percent'] is num) {
                hive.feederLevelPercent = (entry['feeder_level_percent'] as num)
                    .toDouble();
              }
              if (entry['feeder_calib_empty_mm'] is num) {
                hive.feederCalibEmptyMm =
                    (entry['feeder_calib_empty_mm'] as num).toInt();
              }
              if (entry['feeder_calib_full_mm'] is num) {
                hive.feederCalibFullMm = (entry['feeder_calib_full_mm'] as num)
                    .toInt();
              }
              if (entry['feeder_raw_distance_mm'] is num) {
                hive.feederRawDistanceMm =
                    (entry['feeder_raw_distance_mm'] as num).toInt();
              }
              if (entry['paired_tank_id'] is String) {
                hive.pairedTankId = entry['paired_tank_id'] as String;
              }
              if (entry['is_auto_paired'] is bool) {
                hive.isAutoPaired = entry['is_auto_paired'] as bool;
              }
              if (entry['queen'] is Map) {
                hive.queen = QueenData.fromJson(
                  Map<String, dynamic>.from(entry['queen'] as Map),
                );
              }
              if (entry['queen_replacement_state'] is String) {
                hive.queenReplacementState =
                    entry['queen_replacement_state'] as String;
              }
              if (entry['queen_introduced_at'] != null) {
                hive.queenIntroducedAt = DateTime.tryParse(
                  entry['queen_introduced_at'].toString(),
                );
              }
              if (entry['locked_until'] != null) {
                hive.lockedUntil = DateTime.tryParse(
                  entry['locked_until'].toString(),
                );
              }
              if (entry['lock_reason'] is String) {
                hive.lockReason = entry['lock_reason'] as String;
              }
              if (entry['acoustic_sentinel_active'] is bool) {
                hive.isAcousticSentinelActive =
                    entry['acoustic_sentinel_active'] as bool;
              }
              if (entry['acoustic_sample_interval_min'] is num) {
                hive.acousticSampleIntervalMinutes =
                    (entry['acoustic_sample_interval_min'] as num).toInt();
              }
              if (entry['evaluation'] is Map) {
                hive.evaluation = EvaluationData.fromJson(
                  Map<String, dynamic>.from(entry['evaluation'] as Map),
                );
              } else if (entry['evaluation_notes'] is String) {
                hive.evaluation.notes = entry['evaluation_notes'] as String;
              }
              if (entry['reported_diseases'] is List) {
                hive.reportedDiseases = (entry['reported_diseases'] as List)
                    .map((e) => e.toString())
                    .toList();
              }
              if (entry['last_strengthened_at'] != null) {
                hive.lastStrengthenedAt = DateTime.tryParse(
                  entry['last_strengthened_at'].toString(),
                );
              }
              if (entry['strengthening_count'] is num) {
                hive.strengtheningCount = (entry['strengthening_count'] as num)
                    .toInt();
              }
              if (entry['weight_at_strengthening'] is num) {
                hive.weightAtStrengthening =
                    (entry['weight_at_strengthening'] as num).toDouble();
              }
              if (entry['has_relapsed_after_strengthening'] is bool) {
                hive.hasRelapsedAfterStrengthening =
                    entry['has_relapsed_after_strengthening'] as bool;
              }
              if (entry['relapse_reason'] is String) {
                hive.relapseReason = entry['relapse_reason'] as String;
              }
              final List<dynamic> boxList = (entry['boxes'] as List?) ?? [];
              hive.boxes = boxList
                  .map((b) => BoxElement.fromJson(Map<String, dynamic>.from(b)))
                  .toList();
            } else if (entry is List) {
              hive.boxes = entry
                  .map((b) => BoxElement.fromJson(Map<String, dynamic>.from(b)))
                  .toList();
            }
            sortHiveBoxes(hive.boxes);
          }
        }
        evaluateColonyRelapses(notify: false);
        if (notify) notifyListeners();
      }
    } catch (e) {
      debugPrint('Hiba a kaptárfiókok helyi betöltésekor: $e');
    }
  }

  Future<void> setSupabaseConfig(String url, String anonKey) async {
    _supabaseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    _supabaseAnonKey = anonKey.trim();
    resetUnsupportedColumnsCache();
    final prefs = await _getPrefs();
    await prefs.setString('supabase_url', _supabaseUrl);
    await prefs.setString('supabase_anon_key', _supabaseAnonKey);
    logHistoryEvent(
      'SYSTEM',
      'szerver_konfig',
      'Supabase kapcsolat konfiguráció frissítve ($_supabaseUrl).',
    );
    notifyListeners();
  }

  Future<Map<String, dynamic>> testSupabaseConnection() async {
    resetUnsupportedColumnsCache();
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      _isOnline = false;
      _weatherStation.status = 'red';
      notifyListeners();
      return {'success': false, 'message': 'Az URL vagy a kulcs üres.'};
    }

    try {
      final readRes = await _httpClient
          .get(
            Uri.parse('$_supabaseUrl/rest/v1/monitors?select=*&limit=1'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));

      if (readRes.statusCode != 200) {
        _isOnline = false;
        _weatherStation.status = 'red';
        notifyListeners();
        return {
          'success': false,
          'message':
              'Olvasási hiba (Státusz: ${readRes.statusCode}): ${readRes.body}',
        };
      }

      _isOnline = true;
      _weatherStation.status = 'green';
      notifyListeners();
      return {
        'success': true,
        'message': 'Sikeres kapcsolat! Az adatbázis válaszolt (Olvasás OK).',
      };
    } catch (e) {
      _isOnline = false;
      _weatherStation.status = 'red';
      notifyListeners();
      return {
        'success': false,
        'message': 'Hálózati kivétel történt (Offline mód): $e',
      };
    }
  }

  // Időszakos háttér kapcsolat-ellenőrzés a szerver és Supabase állapotához
  Future<void> checkConnectionHealth() async {
    if (_isSyncing || !_isAppInForeground) return;
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      if (_isOnline || _weatherStation.status != 'red') {
        _isOnline = false;
        _weatherStation.status = 'red';
        notifyListeners();
      }
      return;
    }

    try {
      final res = await _httpClient
          .get(
            Uri.parse(
              '$_supabaseUrl/rest/v1/monitors?select=mac_address&limit=1',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 4));

      final bool reachable = res.statusCode == 200;
      if (_isOnline != reachable ||
          _weatherStation.status != (reachable ? 'green' : 'red')) {
        _isOnline = reachable;
        _weatherStation.status = reachable ? 'green' : 'red';
        notifyListeners();
      }
    } catch (_) {
      if (_isOnline || _weatherStation.status != 'red') {
        _isOnline = false;
        _weatherStation.status = 'red';
        notifyListeners();
      }
    }
  }

  static List<BoxElement> createStandardBoxes(
    String mac, {
    required bool isHoneyProducer,
  }) {
    final List<BoxElement> boxes = [
      BoxElement(
        name: 'Aljdeszka',
        code: '${mac}_BOT',
        type: 'bottom',
        size: 'bottom',
        isActive: false,
      ),
      BoxElement(
        name: 'Pollengyűjtő',
        code: '${mac}_POLLEN',
        type: 'pollen_trap',
        size: 'dadant',
        isActive: false,
      ),
      BoxElement(
        name: 'Fészekfiók',
        code: '${mac}_BROOD',
        type: 'brood_box',
        size: 'dadant',
        status: 'green',
        isActive: true,
      ),
    ];

    if (isHoneyProducer) {
      for (int i = 1; i <= 4; i++) {
        boxes.add(
          BoxElement(
            name: 'Méztér',
            code: '${mac}_HONEY_0$i',
            type: 'honey',
            size: 'half_dadant',
            status: 'green',
            isActive: true,
          ),
        );
      }
    } else {
      boxes.add(
        BoxElement(
          name: 'Tetőetető',
          code: '${mac}_FEEDER',
          type: 'feeder',
          size: 'dadant',
          status: 'green',
          isActive: true,
        ),
      );
    }

    boxes.add(
      BoxElement(
        name: 'Tető',
        code: '${mac}_ROOF',
        type: 'roof',
        size: 'dadant',
        isActive: false,
      ),
    );

    sortHiveBoxes(boxes);
    return boxes;
  }

  final List<QueenData> _queens = [
    // Kaptárhoz rendelt anyák
    QueenData(
      id: 'HU-2024-015',
      origin: 'Pannon méh (Törzsállomány)',
      vintage: '2024 (Zöld)',
      isAlive: true,
      needsReplacement: false,
    ),
    QueenData(
      id: 'HU-2025-055',
      origin: 'Krajnai F1 (Termékenyített)',
      vintage: '2025 (Kék)',
      isAlive: true,
      needsReplacement: false,
    ),
    // Kaptárhoz nem rendelt, szabad tartalék anyák
    QueenData(
      id: 'HU-2026-042',
      origin: 'Pannon méh (Törzsállomány)',
      vintage: '2026 (Fehér)',
      isAlive: true,
      needsReplacement: false,
    ),
    QueenData(
      id: 'HU-2025-118',
      origin: 'Krajnai F1 (Pároztatóból)',
      vintage: '2025 (Kék)',
      isAlive: true,
      needsReplacement: false,
    ),
    QueenData(
      id: 'HU-2026-089',
      origin: 'Buckfast F0 (Tenyésztői)',
      vintage: '2026 (Fehér)',
      isAlive: true,
      needsReplacement: false,
    ),
  ];
  final List<HiveData> _hives = [
    HiveData(
      id: 'AA:BB:CC:DD:EE:01',
      name: '1. Család (Méztermelő)',
      location: const LatLng(37.422500, -122.084500),
      status: 'green',
      familyFunction: 'méz',
      entranceHeading: 165.0,
      queen: QueenData(
        id: 'HU-2024-015',
        origin: 'Pannon méh (Törzsállomány)',
        vintage: '2024 (Zöld)',
        isAlive: true,
        needsReplacement: false,
      ),
      evaluation: EvaluationData(
        gathering: '+',
        temperament: '+',
        hygiene: '+',
      ),
      temp: 34.8,
      humidity: 60.0,
      extTemp: 21.5,
      extHumidity: 54.0,
      weight: 38.5,
      batteryVoltage: 4.15,
      zcr: 3800.0,
      swarmIndex: 12.0,
      feedingMode: 'off',
      feederLevelPercent: 0.0,
      boxes: createStandardBoxes('AA:BB:CC:DD:EE:01', isHoneyProducer: true),
      serverConnection: 'Supabase OK',
    ),
    HiveData(
      id: 'AA:BB:CC:DD:EE:02',
      name: '2. Család (Bővülő)',
      location: const LatLng(37.422650, -122.084500),
      status: 'green',
      familyFunction: 'tartalék',
      entranceHeading: 180.0,
      queen: QueenData(
        id: 'HU-2025-055',
        origin: 'Krajnai F1 (Termékenyített)',
        vintage: '2025 (Kék)',
        isAlive: true,
        needsReplacement: false,
      ),
      temp: 34.5,
      humidity: 58.0,
      extTemp: 21.5,
      extHumidity: 54.0,
      weight: 29.0,
      batteryVoltage: 4.10,
      zcr: 3600.0,
      swarmIndex: 8.0,
      feedingMode: 'auto_stim',
      feederLevelPercent: 60.0,
      pairedTankId: 'ABC tartály & Szivattyú',
      isAutoPaired: true,
      boxes: createStandardBoxes('AA:BB:CC:DD:EE:02', isHoneyProducer: false),
      serverConnection: 'Supabase OK',
    ),
    HiveData(
      id: 'AA:BB:CC:DD:EE:03',
      name: '3. Család (Termelő)',
      location: const LatLng(37.422800, -122.084500),
      status: 'green',
      familyFunction: 'propolisz',
      entranceHeading: 195.0,
      temp: 34.6,
      humidity: 59.0,
      extTemp: 21.5,
      extHumidity: 54.0,
      weight: 31.0,
      batteryVoltage: 4.08,
      zcr: 3700.0,
      swarmIndex: 10.0,
      feedingMode: 'auto_stim',
      feederLevelPercent: 60.0,
      pairedTankId: 'ABC tartály & Szivattyú',
      isAutoPaired: true,
      boxes: createStandardBoxes('AA:BB:CC:DD:EE:03', isHoneyProducer: true),
      serverConnection: 'Supabase OK',
    ),
    HiveData(
      id: 'AA:BB:CC:DD:EE:04',
      name: '4. Család (Dajka / Anyanevelő)',
      location: const LatLng(37.422500, -122.084350),
      status: 'green',
      familyFunction: 'dajka',
      entranceHeading: 175.0,
      temp: 34.7,
      humidity: 61.0,
      extTemp: 21.5,
      extHumidity: 54.0,
      weight: 32.5,
      batteryVoltage: 4.12,
      zcr: 3650.0,
      swarmIndex: 5.0,
      feedingMode: 'auto_stim',
      feederLevelPercent: 60.0,
      pairedTankId: 'ABC tartály & Szivattyú',
      isAutoPaired: true,
      boxes: createStandardBoxes('AA:BB:CC:DD:EE:04', isHoneyProducer: false),
      serverConnection: 'Supabase OK',
    ),
  ];
  final List<FrameAnalysisRecord> _pendingFrameAnalyses = [];
  final List<VarroaAnalysisRecord> _pendingVarroaAnalyses = [];
  final List<ScheduledTask> _scheduledTasks = [];

  final StationData _weatherStation = StationData(
    id: 'WEATHER_01',
    name: 'időjárás-állomás',
    location: const LatLng(37.422000, -122.085000),
    temp: 21.5,
    humidity: 54.0,
    pressure: 1013.2,
    uvIndex: 4.5,
    lightLux: 45000.0,
    windSpeed: 3.2,
    windDirection: 'ÉNy',
    rainAmount: 0.0,
    batteryVoltage: 4.10,
    status: 'green',
  );

  final WatererData _waterer = WatererData(
    id: 'WATER_01',
    name: 'itató',
    location: const LatLng(37.422800, -122.085200),
    waterLevel: 78.5,
    waterTemp: 19.2,
    batteryVoltage: 4.05,
    status: 'green',
  );

  final SyrupPumpData _syrupPump = SyrupPumpData(
    id: 'PUMP_01',
    name: 'ABC tartály & Szivattyú',
    location: const LatLng(37.422200, -122.083800),
    totalPumpedLiters: 0.0,
    lastOperationStatus: 'Készenlétben (Zöld: OK)',
    status: 'green',
    pairedHiveNames: ['Kaptár 01'],
  );

  List<HiveData> get hives => _hives;
  List<QueenData> get queens => _queens;

  /// Kaptárhoz nem rendelt, szabad regisztrált anyák listája
  List<QueenData> getUnassignedQueens() {
    final assignedQueenIds = _hives
        .where((h) => h.queen != null && h.queen!.id.isNotEmpty)
        .map((h) => h.queen!.id)
        .toSet();
    return _queens
        .where((q) => q.isAlive && !assignedQueenIds.contains(q.id))
        .toList();
  }

  List<FrameAnalysisRecord> get pendingFrameAnalyses => _pendingFrameAnalyses;
  List<VarroaAnalysisRecord> get pendingVarroaAnalyses =>
      _pendingVarroaAnalyses;
  int get totalPendingPhotos =>
      _pendingFrameAnalyses.length + _pendingVarroaAnalyses.length;
  List<ScheduledTask> get scheduledTasks => _scheduledTasks;
  StationData get weatherStation => _weatherStation;
  WatererData get waterer => _waterer;
  SyrupPumpData get syrupPump => _syrupPump;

  Map<String, String> get _headers => {
    'apikey': _supabaseAnonKey,
    'Authorization': 'Bearer $_supabaseAnonKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  dynamic findElementByCode(String scannedCode) {
    final cleanCode = scannedCode.trim();
    for (var hive in _hives) {
      if (hive.id == cleanCode) {
        return hive;
      }
      for (var box in hive.boxes) {
        if (box.code == cleanCode || box.secondaryCode == cleanCode) {
          return {'hive': hive, 'box': box};
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _buildMonitorPayload(HiveData hive) => {
    'hive_number': hive.name,
    'status': hive.status,
    'family_function': hive.familyFunction,
    'protocol': hive.protocol,
    'latitude': hive.location.latitude,
    'longitude': hive.location.longitude,
    'entrance_heading': hive.entranceHeading,
    'daily_varroa_drop': hive.dailyVarroaDrop,
    'syrup_liters': hive.syrupLiters,
    'feeding_mode': hive.feedingMode,
    'feeding_max_liters': hive.feedingMaxLiters,
    'feeding_interval_hours': hive.feedingIntervalHours,
    'feeding_interval_days': hive.feedingIntervalDays,
    'feeding_stop_sunset_min': hive.feedingStopBeforeSunsetMinutes,
    'feeding_portion_liters': hive.feedingPortionLiters,
    'feeder_level_percent': hive.feederLevelPercent,
    'feeder_calib_empty_mm': hive.feederCalibEmptyMm,
    'feeder_calib_full_mm': hive.feederCalibFullMm,
    'feeder_raw_distance_mm': hive.feederRawDistanceMm,
    'paired_tank_id': hive.pairedTankId,
    'is_auto_paired': hive.isAutoPaired,
    'queen_id': hive.queen?.id,
    'queen_replacement_state': hive.queenReplacementState,
    'queen_introduced_at': hive.queenIntroducedAt?.toUtc().toIso8601String(),
    'locked_until': hive.lockedUntil?.toUtc().toIso8601String(),
    'lock_reason': hive.lockReason,
    'acoustic_sentinel_active': hive.isAcousticSentinelActive,
    'acoustic_sample_interval_min': hive.acousticSampleIntervalMinutes,
    'last_strengthened_at': hive.lastStrengthenedAt?.toUtc().toIso8601String(),
    'strengthening_count': hive.strengtheningCount,
    'weight_at_strengthening': hive.weightAtStrengthening,
    'has_relapsed': hive.hasRelapsedAfterStrengthening,
    'relapse_reason': hive.relapseReason,
    'reported_diseases': hive.reportedDiseases,
    'evaluation': hive.evaluation.toJson(),
    'notes': hive.evaluation.notes,
    'tower_updated_at': hive.towerUpdatedAt.toUtc().toIso8601String(),
    'updated_at': hive.updatedAt.toUtc().toIso8601String(),
  };

  Map<String, dynamic> _buildBodyPayload(
    String monitorMac,
    BoxElement box,
    int positionIndex,
  ) => {
    'monitor_mac': monitorMac,
    'name': box.name,
    'code': box.code,
    'secondary_code': box.secondaryCode,
    'body_type': box.size,
    'body_function': box.type,
    'position_index': positionIndex,
    'status': box.status,
    'is_active': box.isActive,
    'is_quarantined': box.isQuarantined,
    'status_updated_at': box.statusUpdatedAt?.toUtc().toIso8601String(),
    'updated_at': box.updatedAt.toUtc().toIso8601String(),
  };

  void _syncQueenToSupabase(QueenData queen) {
    final idx = _queens.indexWhere((q) => q.id == queen.id);
    if (idx >= 0) {
      _queens[idx] = queen;
    } else {
      _queens.add(queen);
    }
    _patchToSupabase('queens', 'queen_number=eq.${queen.id}', {
      'origin': queen.origin,
      'vintage': queen.vintage,
      'birth_year':
          int.tryParse(queen.vintage.replaceAll(RegExp(r'[^0-9]'), '')) ??
          DateTime.now().year,
      'status': queen.isAlive ? 'Aktív' : 'Elveszett',
      'is_alive': queen.isAlive,
      'needs_replacement': queen.needsReplacement,
      'breeder': queen.breeder,
      'mother_line': queen.motherLine,
      'father_line': queen.fatherLine,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void _syncPumpAndDevicesToSupabase() {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    _patchToSupabase('syrup_pumps', 'id=eq.${_syrupPump.id}', {
      'name': _syrupPump.name,
      'status': _syrupPump.status,
      'tank_level_percent': _syrupPump.tankLevelPercent,
      'total_pumped_liters': _syrupPump.totalPumpedLiters,
      'is_interlocked': _syrupPump.isPumpInterlocked,
      'emergency_reason': _syrupPump.emergencyStopReason,
      'last_operation_status': _syrupPump.lastOperationStatus,
      'latitude': _syrupPump.location.latitude,
      'longitude': _syrupPump.location.longitude,
      'updated_at': nowIso,
    });
    _patchToSupabase('syrup_pumps', 'id=eq.${_weatherStation.id}', {
      'name': _weatherStation.name,
      'status': _weatherStation.status,
      'latitude': _weatherStation.location.latitude,
      'longitude': _weatherStation.location.longitude,
      'updated_at': nowIso,
    });
    _patchToSupabase('syrup_pumps', 'id=eq.${_waterer.id}', {
      'name': _waterer.name,
      'status': _waterer.status,
      'tank_level_percent': _waterer.waterLevel,
      'is_interlocked': _waterer.isInterlocked,
      'emergency_reason': _waterer.emergencyStopReason,
      'latitude': _waterer.location.latitude,
      'longitude': _waterer.location.longitude,
      'updated_at': nowIso,
    });
  }

  /// Térképi szerkesztő módban áthúzott kaptárak és telephelyi egységek pozícióinak mentése az adatbázisba és a history-ba
  void saveMapLayoutPositions() {
    final nowUtc = DateTime.now().toUtc();
    for (final hive in _hives) {
      hive.updatedAt = nowUtc;
      _patchToSupabase(
        'monitors',
        'mac_address=eq.${hive.id}',
        _buildMonitorPayload(hive),
      );
    }
    _syncPumpAndDevicesToSupabase();
    logHistoryEvent(
      'MAP_LAYOUT',
      'terkep_elrendezes',
      'Telephelyi térkép ikon-elrendezés frissítve (${_hives.length} kaptár + állomás/itató/szivattyú koordináták mentve).',
      metadata: {
        'hives': _hives
            .map(
              (h) => {
                'id': h.id,
                'name': h.name,
                'lat': h.location.latitude,
                'lng': h.location.longitude,
                'heading': h.entranceHeading,
              },
            )
            .toList(),
        'weather': {
          'lat': _weatherStation.location.latitude,
          'lng': _weatherStation.location.longitude,
        },
        'waterer': {
          'lat': _waterer.location.latitude,
          'lng': _waterer.location.longitude,
        },
        'syrup_pump': {
          'lat': _syrupPump.location.latitude,
          'lng': _syrupPump.location.longitude,
        },
      },
    );
    _saveHivesBoxesLocally(immediate: true);
    notifyListeners();
  }

  /// Irodai törzsadat (új katalóguselem) mentése az adatbázisba és a history-ba
  void addCatalogItem(Map<String, dynamic> itemJson) {
    final String code = (itemJson['code'] ?? '').toString().trim();
    final String category = (itemJson['category'] ?? '').toString().trim();
    if (code.isEmpty || category.isEmpty) return;

    customCatalogItems.removeWhere(
      (c) => c['code'] == code && c['category'] == category,
    );
    customCatalogItems.add(Map<String, dynamic>.from(itemJson));

    _postToSupabase('catalogs', {
      'category': category,
      'code': code,
      'label': itemJson['label'],
      'default_size': itemJson['default_size'],
      'icon_name': itemJson['icon_name'],
      'color_hex': itemJson['color_hex'],
    });

    logHistoryEvent(
      'OFFICE',
      'torzsadat_uj_elem',
      'Új törzsadat rögzítve ($category): ${itemJson['label']} [$code].',
      metadata: itemJson,
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void addQueen(QueenData queen, {String? hiveId}) {
    _syncQueenToSupabase(queen);
    logHistoryEvent(
      hiveId ?? 'OFFICE',
      'uj_anya',
      'Méhanya rögzítve / frissítve: ${queen.id} (${queen.origin}, évjárat: ${queen.vintage}).',
      metadata: queen.toJson(),
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void addHive(HiveData hive) {
    if (!hive.boxes.any((b) => b.type == 'bottom')) {
      final bottomBox = BoxElement(
        name: 'Aljdeszka',
        code: '${hive.id}_BOT',
        type: 'bottom',
        size: 'bottom',
        isActive: false,
      );
      hive.boxes.insert(0, bottomBox);
    } else {
      hive.boxes.removeWhere((b) => b.type == 'bottom');
      hive.boxes.insert(
        0,
        BoxElement(
          name: 'Aljdeszka',
          code: '${hive.id}_BOT',
          type: 'bottom',
          size: 'bottom',
          isActive: false,
        ),
      );
    }

    sortHiveBoxes(hive.boxes);
    hive.updatedAt = DateTime.now().toUtc();
    hive.towerUpdatedAt = DateTime.now().toUtc();
    _hives.add(hive);
    if (hive.queen != null) {
      _syncQueenToSupabase(hive.queen!);
    }
    _postToSupabase('monitors', {
      'mac_address': hive.id,
      ..._buildMonitorPayload(hive),
    });

    for (int i = 0; i < hive.boxes.length; i++) {
      final box = hive.boxes[i];
      box.updatedAt = hive.towerUpdatedAt;
      _postToSupabase('bodies', _buildBodyPayload(hive.id, box, i + 1)).then((
        inserted,
      ) {
        final int? newId = (inserted?['id'] as num?)?.toInt();
        if (newId != null && box.dbId == null) {
          box.dbId = newId;
          _saveHivesBoxesLocally();
        }
      });
    }
    logHistoryEvent(
      hive.id,
      'uj_kaptar',
      'Új kaptár regisztrálva: ${hive.name} (${hive.boxes.length} toronyelemmel, funkció: ${hive.familyFunction}).',
      metadata: _buildMonitorPayload(hive),
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void addBoxToHive(HiveData hive, BoxElement box) {
    final isEscapement =
        box.type == 'escapement' ||
        box.name.toLowerCase().contains('szöktet') ||
        box.name.toLowerCase().contains('szoktet');
    final isRoof =
        !isEscapement &&
        (box.type == 'roof' ||
            ((box.name.toLowerCase().contains('tető') ||
                    box.name.toLowerCase().contains('teto')) &&
                !box.name.toLowerCase().contains('etet')));
    final isBottom =
        box.type == 'bottom' || box.name.toLowerCase().contains('alj');
    final isPollen =
        box.type == 'pollen_trap' ||
        box.name.toLowerCase().contains('pollen') ||
        box.name.toLowerCase().contains('virágpor');
    final isFeeder =
        box.type == 'feeder' ||
        box.type == 'roof_feeder' ||
        box.name.toLowerCase().contains('etet');

    if (isRoof &&
        hive.boxes.any(
          (b) =>
              b.type == 'roof' ||
              ((b.name.toLowerCase().contains('tető') ||
                      b.name.toLowerCase().contains('teto')) &&
                  !b.name.toLowerCase().contains('szöktet') &&
                  !b.name.toLowerCase().contains('szoktet') &&
                  !b.name.toLowerCase().contains('etet')),
        )) {
      return; // Egynél több tető szigorúan tiltott
    }
    if (isBottom &&
        hive.boxes.any(
          (b) => b.type == 'bottom' || b.name.toLowerCase().contains('alj'),
        )) {
      return; // Egynél több aljdeszka szigorúan tiltott
    }
    if (isPollen &&
        hive.boxes.any(
          (b) =>
              b.type == 'pollen_trap' ||
              b.name.toLowerCase().contains('pollen') ||
              b.name.toLowerCase().contains('virágpor'),
        )) {
      return; // Egynél több pollengyűjtő szigorúan tiltott
    }
    if (isFeeder &&
        hive.boxes.any(
          (b) =>
              b.type == 'feeder' ||
              b.type == 'roof_feeder' ||
              b.name.toLowerCase().contains('etet'),
        )) {
      return; // Egynél több tetőetető szigorúan tiltott
    }
    if (!hive.canFitAdditionalBox(box)) {
      debugPrint(
        'Toronymagasság korlát: ${hive.name} már elérte a max. 4 teljes fiókot (${hive.formattedBoxEquivalent}/4), ${box.name} nem adható hozzá!',
      );
      return; // Szigorúan maximum 4 teljes (vagy 8 db 1/2) fiók!
    }

    final DateTime nowLocal = DateTime.now();
    hive.towerUpdatedAt = nowLocal.toUtc();
    box.updatedAt = hive.towerUpdatedAt;
    if (isEscapement) {
      box.isActive = true;
      box.statusUpdatedAt ??= nowLocal;
    }
    hive.boxes.add(box);
    sortHiveBoxes(hive.boxes); // Szigorú méhészeti szabályok betartása (pollengyűjtő közvetlenül az aljdeszkán, tetőetető közvetlenül a tető alatt)
    final int calculatedPos = hive.boxes.indexOf(box) + 1;

    final Map<String, dynamic> bodyPayload = _buildBodyPayload(
      hive.id,
      box,
      calculatedPos,
    );

    _postToSupabase('bodies', bodyPayload).then((inserted) {
      final int? newId = (inserted?['id'] as num?)?.toInt();
      if (newId != null && box.dbId == null) {
        box.dbId = newId;
        _saveHivesBoxesLocally();
      }
    });
    // Az eltolódott felsőbb fiókok pozíciójának frissítése az adatbázisban is
    for (int i = calculatedPos; i < hive.boxes.length; i++) {
      final shifted = hive.boxes[i];
      if (!identical(shifted, box) && shifted.dbId != null) {
        _patchToSupabase('bodies', 'id=eq.${shifted.dbId}', {
          'position_index': i + 1,
        });
      }
    }
    _patchToSupabase('monitors', 'mac_address=eq.${hive.id}', {
      'tower_updated_at': hive.towerUpdatedAt.toIso8601String(),
      'updated_at': hive.towerUpdatedAt.toIso8601String(),
    });
    logHistoryEvent(
      hive.id,
      'torony_bovites',
      'Torony bővítve: ${box.name}${box.size.isNotEmpty ? " (${box.size})" : ""} hozzáadva ($calculatedPos. pozíció, magasság: ${hive.formattedBoxEquivalent}/4 fiók)${hive.requiresSpanifer ? " – FIGYELEM: 1 teljes + 4 db 1/2-Dadant (3 teljes fiók) felett minimum spanifer szükséges!" : ""}.',
      metadata: bodyPayload,
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void reorderBox(HiveData hive, BoxElement box, {required bool moveUp}) {
    if (box.type == 'roof' || box.type == 'bottom') return;
    // Szigorú szabály: pollengyűjtő csak közvetlenül az aljdeszkán, tetőetető csak a dekli alatt lehet!
    final isPollen =
        box.type == 'pollen_trap' ||
        box.name.toLowerCase().contains('pollen') ||
        box.name.toLowerCase().contains('virágpor');
    final isFeeder =
        box.type == 'feeder' ||
        box.type == 'roof_feeder' ||
        box.name.toLowerCase().contains('etet');
    if (isPollen || isFeeder) return;

    final int currentIndex = hive.boxes.indexOf(box);
    if (currentIndex == -1) return;

    int targetIndex = -1;
    if (moveUp) {
      // Feljebb mozgatás a képernyőn (a tető felé haladva a toronyban)
      targetIndex = currentIndex + 1;
      if (targetIndex >= hive.boxes.length) return;
      final target = hive.boxes[targetIndex];
      // Nem lehet a tető vagy a tetőetető helyére / fölé tolni
      if (target.type == 'roof' ||
          target.type == 'feeder' ||
          target.type == 'roof_feeder' ||
          target.name.toLowerCase().contains('etet')) {
        return;
      }

      final temp = hive.boxes[currentIndex];
      hive.boxes[currentIndex] = hive.boxes[targetIndex];
      hive.boxes[targetIndex] = temp;
    } else {
      // Lejjebb mozgatás a képernyőn (az aljdeszka felé haladva a toronyban)
      targetIndex = currentIndex - 1;
      if (targetIndex < 0) return;
      final target = hive.boxes[targetIndex];
      // Nem lehet az aljdeszka vagy a pollengyűjtő helyére / alá tolni
      if (target.type == 'bottom' ||
          target.type == 'pollen_trap' ||
          target.name.toLowerCase().contains('pollen') ||
          target.name.toLowerCase().contains('virágpor')) {
        return;
      }

      final temp = hive.boxes[currentIndex];
      hive.boxes[currentIndex] = hive.boxes[targetIndex];
      hive.boxes[targetIndex] = temp;
    }

    // Pozíciók újraindexelése a memóriában
    hive.towerUpdatedAt = DateTime.now().toUtc();
    for (int i = 0; i < hive.boxes.length; i++) {
      hive.boxes[i].positionIndex = i;
    }

    // Hálózati optimalizáció: Csak a ténylegesen megcserélt két fiók pozícióját küldjük a szerverre
    // Szöktető esetén nem írjuk felül az updated_at mezőt, hogy a leszöktetés kezdési ideje sose vesszen el!
    final bCurrent = hive.boxes[currentIndex];
    final bTarget = hive.boxes[targetIndex];
    final bool currentIsEscapement = bCurrent.type == 'escapement';
    final bool targetIsEscapement = bTarget.type == 'escapement';
    if (!currentIsEscapement) bCurrent.updatedAt = hive.towerUpdatedAt;
    if (!targetIsEscapement) bTarget.updatedAt = hive.towerUpdatedAt;
    if (bCurrent.dbId != null) {
      _patchToSupabase('bodies', 'id=eq.${bCurrent.dbId}', {
        'position_index': currentIndex + 1,
        if (!currentIsEscapement)
          'updated_at': bCurrent.updatedAt.toIso8601String(),
      });
    }
    if (bTarget.dbId != null) {
      _patchToSupabase('bodies', 'id=eq.${bTarget.dbId}', {
        'position_index': targetIndex + 1,
        if (!targetIsEscapement)
          'updated_at': bTarget.updatedAt.toIso8601String(),
      });
    }

    logHistoryEvent(
      hive.id,
      'torony_atrendezes',
      'Toronyelem áthelyezve: ${box.name} (${moveUp ? "feljebb" : "lejjebb"}, ${targetIndex + 1}. pozícióba).',
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void insertEscapeBoardUnderBox(HiveData hive, BoxElement targetBox) {
    if (hive.isQuarantined) {
      debugPrint(
        'Zárlat: Karantén alatti torony alá tilos szöktetőt helyezni!',
      );
      return;
    }
    int targetIndex = hive.boxes.indexWhere(
      (b) =>
          identical(b, targetBox) ||
          (targetBox.dbId != null && b.dbId == targetBox.dbId),
    );
    if (targetIndex == -1) {
      targetIndex = hive.boxes.indexWhere((b) => b.code == targetBox.code);
    }
    if (targetIndex <= 0) return;

    // Ha a toronyban máshol volt már szöktető, azt eltávolítjuk és áthelyezzük az új fiók alá
    final existingEscapementIdx = hive.boxes.indexWhere(
      (b) => b.type == 'escapement' || b.name.toLowerCase().contains('szöktet'),
    );
    if (existingEscapementIdx != -1) {
      // Ha már közvetlenül ez alatt a fiók alatt volt, nincs további teendő
      if (existingEscapementIdx == targetIndex - 1) return;
      final oldEscapement = hive.boxes.removeAt(existingEscapementIdx);
      if (oldEscapement.dbId != null) {
        _deleteFromSupabase('bodies', 'id=eq.${oldEscapement.dbId}');
      }
      // Index újraszámítása az eltávolítás után
      targetIndex = hive.boxes.indexWhere(
        (b) =>
            identical(b, targetBox) ||
            (targetBox.dbId != null && b.dbId == targetBox.dbId),
      );
      if (targetIndex == -1) {
        targetIndex = hive.boxes.indexWhere((b) => b.code == targetBox.code);
      }
      if (targetIndex <= 0) return;
    }

    final DateTime startLocal = DateTime.now();
    final String startUtcIso = startLocal.toUtc().toIso8601String();
    final String escapementCode =
        '${hive.id}_ESCAPEMENT_${startLocal.millisecondsSinceEpoch.toString().substring(8)}';

    final escapementBox = BoxElement(
      name: 'Szöktető',
      code: escapementCode,
      type: 'escapement',
      size: targetBox.size.isNotEmpty ? targetBox.size : 'fel_dadant',
      status: 'green',
      isActive: true,
      statusUpdatedAt: startLocal,
      updatedAt: startLocal.toUtc(),
    );

    // Beillesztjük közvetlenül a kiválasztott fiók ALÁ
    // (a targetIndex pozícióra szúrjuk be, így a célfiók és a felette lévő összes fiók feljebb tolódik)
    hive.boxes.insert(targetIndex, escapementBox);
    hive.towerUpdatedAt = startLocal.toUtc();

    // Pozíciók újraindexelése
    for (int i = 0; i < hive.boxes.length; i++) {
      hive.boxes[i].positionIndex = i;
    }

    // Új szöktető mentése Supabase-be a pontos kezdési UTC időbélyeggel (telefoncsere-biztos visszaszámláláshoz)
    _postToSupabase(
      'bodies',
      _buildBodyPayload(hive.id, escapementBox, targetIndex + 1),
    ).then((inserted) {
      final int? newId = (inserted?['id'] as num?)?.toInt();
      if (newId != null && escapementBox.dbId == null) {
        escapementBox.dbId = newId;
        _saveHivesBoxesLocally();
      }
    });

    _patchToSupabase('monitors', 'mac_address=eq.${hive.id}', {
      'tower_updated_at': startUtcIso,
      'updated_at': startUtcIso,
    });

    logHistoryEvent(
      hive.id,
      'szoktetes',
      'Méhszöktetés elindítva (${targetBox.name} alatt) – kezdete: $startUtcIso',
      metadata: {
        'target_box': targetBox.name,
        'escapement_code': escapementCode,
        'position_index': targetIndex + 1,
      },
    );

    // Csak a szöktető FELETT eltolódott elemek pozícióját frissítjük Supabase-ben (az alatta lévők indexe nem változott)
    for (int i = targetIndex + 1; i < hive.boxes.length; i++) {
      final b = hive.boxes[i];
      if (!identical(b, escapementBox) && b.dbId != null) {
        _patchToSupabase('bodies', 'id=eq.${b.dbId}', {
          'position_index': i + 1,
        });
      }
    }

    // Tisztítjuk az esetleges feladatokat, a méhszöktetés a toronyban lévő Szöktető kereten él visszaszámlálóval
    scheduledTasks.removeWhere(
      (t) =>
          t.hiveId == hive.id &&
          (t.id.contains('ESCAPEMENT') || t.title.contains('Méhszöktetés')),
    );

    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void insertEscapeBoardUnderHoney(HiveData hive, BoxElement honeyBox) {
    insertEscapeBoardUnderBox(hive, honeyBox);
  }

  void removeBoxFromHive(HiveData hive, BoxElement box) {
    if (box.type == 'bottom')
      return; // Az aljdeszka a kaptár fix alapeleme, nem törölhető
    final int removedIdx = hive.boxes.indexWhere(
      (b) =>
          identical(b, box) ||
          (box.dbId != null && b.dbId == box.dbId) ||
          (box.code.isNotEmpty && b.code == box.code),
    );
    hive.boxes.removeWhere(
      (b) =>
          identical(b, box) ||
          (box.dbId != null && b.dbId == box.dbId) ||
          (box.code.isNotEmpty && b.code == box.code),
    );
    hive.towerUpdatedAt = DateTime.now().toUtc();
    for (int i = 0; i < hive.boxes.length; i++) {
      hive.boxes[i].positionIndex = i;
      if (hive.boxes[i].dbId != null) {
        _patchToSupabase('bodies', 'id=eq.${hive.boxes[i].dbId}', {
          'position_index': i + 1,
        });
      }
    }

    // Ha szöktetőt veszünk ki, töröljük a kapcsolódó 24 órás feladatot is
    if (box.type == 'escapement' ||
        box.name.toLowerCase().contains('szöktet')) {
      scheduledTasks.removeWhere(
        (t) =>
            t.hiveId == hive.id &&
            (t.id.contains('ESCAPEMENT') || t.title.contains('Méhszöktetés')),
      );
    }

    if (box.dbId != null) {
      _deleteFromSupabase('bodies', 'id=eq.${box.dbId}');
    } else if (removedIdx >= 0) {
      _deleteFromSupabase(
        'bodies',
        'monitor_mac=eq.${hive.id}&body_function=eq.${box.type}&position_index=eq.${removedIdx + 1}',
      );
    } else {
      _deleteFromSupabase(
        'bodies',
        'monitor_mac=eq.${hive.id}&body_function=eq.${box.type}',
      );
    }
    _patchToSupabase('monitors', 'mac_address=eq.${hive.id}', {
      'tower_updated_at': hive.towerUpdatedAt.toIso8601String(),
      'updated_at': hive.towerUpdatedAt.toIso8601String(),
    });
    logHistoryEvent(
      hive.id,
      'torony_csokkentes',
      'Toronyelem eltávolítva: ${box.name}${box.size.isNotEmpty ? " (${box.size})" : ""}.',
      metadata: box.toJson(),
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  /// Szöktetés kész: eltávolítja a méhszöktetőt és az összes felette lévő fiókot (tető kivételével).
  /// A szöktető ALATT lévő fiókok (fészek, alsóbb mézterek, aljdeszka) garantáltan érintetlenül a kaptáron maradnak!
  int finishEscapementAndHarvest(HiveData hive) {
    if (hive.isQuarantined) {
      debugPrint(
        'Zárlat: Karantén alatti toronyból tilos mézteret elvenni vagy pergetni!',
      );
      return 0;
    }
    final int escapementIndex = hive.boxes.indexWhere(
      (b) => b.type == 'escapement' || b.name.toLowerCase().contains('szöktet'),
    );
    if (escapementIndex == -1) return 0;

    final escapementBox = hive.boxes[escapementIndex];

    // 1. Különválogatjuk a megmaradó és az elveendő fiókokat:
    // - Ami a szöktető ALATT van (i < escapementIndex): BIZTOSAN MEGMARAD (aljdeszka, fészek, alsóbb mézterek)
    // - Maga a szöktető (i == escapementIndex): ELVÉTELRE KERÜL
    // - Ami a szöktető FELETT van (i > escapementIndex):
    //     - Ha tető (dekli): MEGMARAD A KAPTÁRON!
    //     - Ha fiók (méztér, kiegészítő): ELVÉTELRE KERÜL
    final List<BoxElement> remainingBoxes = [];
    final List<BoxElement> removedBoxes = [];

    // Alatta lévő elemek: mind érintetlenül megmarad a kaptáron
    for (int i = 0; i < escapementIndex; i++) {
      remainingBoxes.add(hive.boxes[i]);
    }

    // Maga a szöktető elvételre kerül
    removedBoxes.add(escapementBox);

    // Felette lévő elemek: a tető megmarad, a mézterek elvételre kerülnek
    for (int i = escapementIndex + 1; i < hive.boxes.length; i++) {
      final b = hive.boxes[i];
      if (isRoofBox(b)) {
        remainingBoxes.add(b);
      } else {
        removedBoxes.add(b);
      }
    }

    // Biztosítjuk, hogy a tető mindig a torony tetején legyen
    if (!remainingBoxes.any((b) => isRoofBox(b))) {
      remainingBoxes.add(
        BoxElement(
          name: 'Tető',
          code: '${hive.id}_ROOF',
          type: 'roof',
          size: 'dadant',
          isActive: false,
        ),
      );
    }

    // 2. Csere a megmaradó fiókokra (garantáltan érintetlen marad minden alsó fiók)
    hive.boxes.clear();
    hive.boxes.addAll(remainingBoxes);

    // 3. Supabase-ből a konkrétan elvett fiókok törlése egyedi ID vagy típus alapján
    for (var b in removedBoxes) {
      if (b.dbId != null) {
        _deleteFromSupabase('bodies', 'id=eq.${b.dbId}');
      } else {
        _deleteFromSupabase(
          'bodies',
          'monitor_mac=eq.${hive.id}&body_function=eq.${b.type}',
        );
      }
    }

    // 4. Kapcsolódó méhszöktetési feladatok törlése
    scheduledTasks.removeWhere(
      (t) =>
          t.hiveId == hive.id &&
          (t.id.contains('ESCAPEMENT') || t.title.contains('Méhszöktetés')),
    );

    // 5. Pozíciók újrarendezése és mentése (csak a megváltozott indexű felső elemre küldünk PATCH-et)
    for (int i = 0; i < hive.boxes.length; i++) {
      hive.boxes[i].positionIndex = i;
      if (i >= escapementIndex && hive.boxes[i].dbId != null) {
        _patchToSupabase('bodies', 'id=eq.${hive.boxes[i].dbId}', {
          'position_index': i + 1,
        });
      }
    }

    final int removedSuperCount =
        removedBoxes.length - 1; // Szöktető nélkül az elvett mézterek száma

    _postToSupabase('history_logs', {
      'monitor_mac': hive.id,
      'event_type': 'pergetes',
      'description':
          'Szöktetés kész: $removedSuperCount db méztéri fiók és a méhszöktető elvéve a toronyból. Megmaradt fiókok száma: ${hive.boxes.length}.',
    });

    _saveHivesBoxesLocally();
    notifyListeners();
    return removedSuperCount;
  }

  void toggleBoxActiveState(HiveData hive, BoxElement box, bool newValue) {
    final DateTime nowLocal = DateTime.now();
    box.isActive = newValue;
    box.statusUpdatedAt = newValue ? nowLocal : null;
    box.updatedAt = nowLocal.toUtc();

    final String eventDesc = box.type == 'bottom'
        ? (newValue
              ? 'Aljdeszka betolva (3 napos varroa kontroll indítva)'
              : 'Aljdeszka kihúzva')
        : (newValue ? 'Pollengyűjtő bekapcsolva' : 'Pollengyűjtő kikapcsolva');

    final Map<String, dynamic> patchPayload = {
      'is_active': newValue,
      'status_updated_at': newValue ? nowLocal.toUtc().toIso8601String() : null,
      'updated_at': box.updatedAt.toIso8601String(),
    };

    if (box.dbId != null) {
      _patchToSupabase('bodies', 'id=eq.${box.dbId}', patchPayload);
    } else {
      final String funcFilter = box.type == 'bottom'
          ? 'eq.bottom'
          : 'in.(${box.type},pollen_trap,pollen,viragpor,11)';
      _patchToSupabase(
        'bodies',
        'monitor_mac=eq.${hive.id}&body_function=$funcFilter',
        patchPayload,
      );
    }

    _postToSupabase('history_logs', {
      'monitor_mac': hive.id,
      'event_type': box.type == 'bottom' ? 'atkaellenőrzés' : 'pollengyűjtő',
      'description': eventDesc,
    });

    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void logHistoryEvent(
    String monitorMac,
    String eventType,
    String description, {
    Map<String, dynamic>? metadata,
  }) {
    _postToSupabase('history_logs', {
      'monitor_mac': monitorMac,
      'event_type': eventType,
      'description': description,
      'metadata': ?metadata,
    });
  }

  /// Általános kezelés / etetés / higiéniai beavatkozás rögzítése a treatments és a history_logs táblákba
  void logTreatmentIntervention({
    required HiveData hive,
    required String category,
    required String treatmentName,
    String? details,
    String? newProtocol,
  }) {
    if (hive.isQuarantined) return;
    if (newProtocol != null && newProtocol.isNotEmpty) {
      hive.protocol = newProtocol;
    }
    final String desc = details ?? 'Kezelés elvégezve: $treatmentName';

    _postToSupabase('treatments', {
      'monitor_mac': hive.id,
      'treatment_type': treatmentName,
      'scheduled_date': DateTime.now().toIso8601String().split('T').first,
      'is_completed': true,
      'notes': desc,
    });

    logHistoryEvent(hive.id, category, desc);
    updateHive(hive);
  }

  void updateHive(
    HiveData hive, {
    String? historyEventType,
    String? historyDescription,
    bool skipRelapseCheck = false,
  }) {
    hive.updatedAt = DateTime.now().toUtc();
    if (!skipRelapseCheck) {
      evaluateColonyRelapses(onlyHive: hive, notify: false);
    } else {
      _recomputeApiaryRekorders();
    }
    if (hive.queen != null && hive.queen!.id.isNotEmpty) {
      _syncQueenToSupabase(hive.queen!);
    }
    final payload = _buildMonitorPayload(hive);
    _patchToSupabase('monitors', 'mac_address=eq.${hive.id}', payload);
    if (historyEventType != null &&
        historyDescription != null &&
        historyDescription.isNotEmpty) {
      logHistoryEvent(
        hive.id,
        historyEventType,
        historyDescription,
        metadata: payload,
      );
    }
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  /// Kiszámítja, hogy melyik család (legfeljebb a telephely top 20%-a, pl. 4-9 kaptárnál max. 1 db!)
  /// kaphat Rekorder (⭐) státuszt: nem lehet minden család rekorder!
  void _recomputeApiaryRekorders() {
    for (final h in _hives) {
      h.isApiaryRekorder = false;
    }
    final activeHives = _hives.where((h) => !h.isQuarantined).toList();
    if (activeHives.length < 2) return;

    double avgWeight = 0.0;
    int weightCount = 0;
    for (final h in activeHives) {
      if (h.weight > 0) {
        avgWeight += h.weight;
        weightCount++;
      }
    }
    if (weightCount > 0) {
      avgWeight /= weightCount;
    }

    // Csak az egyedileg kiváló (isRekorderEligible) ÉS a telephelyi átlagsúlyt legalább 5%-kal
    // meghaladó családok indulhatnak a Rekorder címért
    final candidates = activeHives.where((h) {
      if (!h.isRekorderEligible) return false;
      if (avgWeight > 0 && h.weight < avgWeight * 1.05) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return;

    candidates.sort((a, b) {
      final scoreA = (a.positiveEvaluationCount * 3.0) + a.weight;
      final scoreB = (b.positiveEvaluationCount * 3.0) + b.weight;
      return scoreB.compareTo(scoreA);
    });

    // Legfeljebb a telephely top 20%-a (2-9 család esetén szigorúan maximum 1 család!) lehet Rekorder
    final int maxRekorders = math.max(1, (activeHives.length * 0.20).floor());
    for (int i = 0; i < candidates.length && i < maxRekorders; i++) {
      candidates[i].isApiaryRekorder = true;
    }
  }

  /// Átvizsgálja a korábban már felerősített családokat a többi (kontroll) családhoz képest.
  /// Ha egy felerősített család ismét legyengül (relatív súly-, fészekhő-, népesedési/zúgás-elmaradás
  /// vagy negatív állapot/bírálat miatt), felkiáltójeles visszaesést rögzít és naplózza a history_logs-ba.
  void evaluateColonyRelapses({HiveData? onlyHive, bool notify = false}) {
    final targets = onlyHive != null ? <HiveData>[onlyHive] : _hives;
    bool changed = false;

    for (final hive in targets) {
      if (!hive.wasEverStrengthened || hive.isQuarantined) continue;

      List<HiveData> peers = _hives
          .where(
            (h) =>
                h.id != hive.id &&
                !h.isQuarantined &&
                !h.hasRelapsedAfterStrengthening &&
                !h.hasIntrinsicWeakness,
          )
          .toList();
      if (peers.isEmpty) {
        peers = _hives
            .where((h) => h.id != hive.id && !h.isQuarantined)
            .toList();
      }

      double avgPeerComparableWeight = 0.0;
      int weightPeers = 0;
      double avgPeerTemp = 0.0;
      int tempPeers = 0;
      double avgPeerZcr = 0.0;
      int zcrPeers = 0;

      for (final p in peers) {
        if (p.weight > 0) {
          avgPeerComparableWeight += p.comparableNestWeight;
          weightPeers++;
        }
        if (p.temp > 0) {
          avgPeerTemp += p.temp;
          tempPeers++;
        }
        if (p.zcr > 0) {
          avgPeerZcr += p.zcr;
          zcrPeers++;
        }
      }
      if (weightPeers > 0) avgPeerComparableWeight /= weightPeers;
      if (tempPeers > 0) avgPeerTemp /= tempPeers;
      if (zcrPeers > 0) avgPeerZcr /= zcrPeers;

      String? detectedRelapse;

      // 1. Összehasonlítás a többi családdal (relatív lemaradás a telephely átlagától)
      if (weightPeers > 0 &&
          hive.weight > 0 &&
          hive.comparableNestWeight < avgPeerComparableWeight * 0.80) {
        detectedRelapse =
            'súlyban elmarad a többi családtól (${hive.comparableNestWeight.toStringAsFixed(1)} kg vs. átlag ${avgPeerComparableWeight.toStringAsFixed(1)} kg)';
      } else if (hive.weightAtStrengthening != null &&
          hive.weight > 0 &&
          hive.weight <= hive.weightAtStrengthening! - 4.0 &&
          (weightPeers == 0 ||
              hive.comparableNestWeight < avgPeerComparableWeight * 0.88)) {
        detectedRelapse =
            'erősítés óta ${(hive.weightAtStrengthening! - hive.weight).toStringAsFixed(1)} kg visszaesés a többihez képest';
      } else if (tempPeers > 0 &&
          avgPeerTemp >= 33.0 &&
          hive.temp > 0 &&
          hive.temp <= avgPeerTemp - 2.2) {
        detectedRelapse =
            'fészekhő elmarad a többi családtól (${hive.temp.toStringAsFixed(1)} °C vs. átlag ${avgPeerTemp.toStringAsFixed(1)} °C)';
      } else if (zcrPeers > 0 &&
          avgPeerZcr >= 3200.0 &&
          hive.zcr > 0 &&
          hive.zcr <= avgPeerZcr * 0.78) {
        detectedRelapse =
            'népességzúgás gyengébb a többi családnál (${hive.zcr.toStringAsFixed(0)} Hz vs. átlag ${avgPeerZcr.toStringAsFixed(0)} Hz)';
      } else if (hive.hasIntrinsicWeakness) {
        if (hive.status == 'yellow' || hive.status == 'red') {
          detectedRelapse =
              'ismét gyenge/kritikus státuszba került (${hive.status})';
        } else if (hive.reportedDiseases.isNotEmpty) {
          final names = hive.reportedDiseases
              .map((id) => kHiveDiseaseLabels[id] ?? id)
              .join(', ');
          detectedRelapse = 'betegség jelentkezett ($names)';
        } else if (hive.dailyVarroaDrop >= 3.0) {
          detectedRelapse =
              'magas atkahullás (${hive.dailyVarroaDrop.toStringAsFixed(1)} db/nap)';
        } else {
          detectedRelapse = 'ismételt gyengülés / kedvezőtlen bírálat';
        }
      }

      if (detectedRelapse != null && !hive.hasRelapsedAfterStrengthening) {
        hive.hasRelapsedAfterStrengthening = true;
        hive.relapseReason = detectedRelapse;
        if (hive.status == 'green') {
          hive.status = 'orange';
        }
        changed = true;

        final countLabel = hive.strengtheningCount > 1
            ? '${hive.strengtheningCount}× felerősítés után'
            : 'Felerősítés után';
        hive.updatedAt = DateTime.now().toUtc();
        _patchToSupabase(
          'monitors',
          'mac_address=eq.${hive.id}',
          _buildMonitorPayload(hive),
        );
        logHistoryEvent(
          hive.id,
          'visszaeses_erosites_utan',
          '❗ VISSZAESETT CSALÁD ($countLabel): ismét legyengült a többi családhoz képest – $detectedRelapse. Tartós probléma (pl. hibás anya / betegség) gyanúja!',
          metadata: {
            'relapse_reason': detectedRelapse,
            'strengthening_count': hive.strengtheningCount,
            'status': hive.status,
          },
        );
      } else if (detectedRelapse != null && hive.relapseReason == null) {
        hive.relapseReason = detectedRelapse;
        changed = true;
      }
    }

    _recomputeApiaryRekorders();

    if (changed) {
      _saveHivesBoxesLocally();
      if (notify) notifyListeners();
    }
  }

  /// HANS-PROTOKOLL azonnali aktiválása az adott kaptár TELJES TORNYÁRA:
  /// minden fiók, aljdeszka, etető, pollengyűjtő és tető zárlat alá kerül,
  /// az etetés és pollengyűjtés leáll, és ütemeződik az azonnali megsemmisítés.
  void activateHansProtocol(HiveData hive) {
    final DateTime nowUtc = DateTime.now().toUtc();
    if (!hive.reportedDiseases.contains('nyulos')) {
      hive.reportedDiseases.add('nyulos');
    }
    hive.protocol = 'hans';
    hive.familyFunction = 'Hans';
    hive.status = 'flashing_red';
    hive.feedingMode = 'off';
    hive.isQueuedForRefill = false;
    hive.isAutoPaired = false;
    _syrupPump.pairedHiveNames.remove(hive.name);

    for (final b in hive.boxes) {
      b.status = 'flashing_red';
      b.isQuarantined = true;
      b.updatedAt = nowUtc;
      if (b.type == 'pollen_trap' || b.type == 'bottom') {
        b.isActive = false;
      }
      if (b.dbId != null) {
        _patchToSupabase('bodies', 'id=eq.${b.dbId}', {
          'status': 'flashing_red',
          'is_quarantined': true,
          'is_active': b.isActive,
          'updated_at': nowUtc.toIso8601String(),
        });
      }
    }
    hive.towerUpdatedAt = nowUtc;
    hive.updatedAt = nowUtc;

    // Minden korábbi nyitott teendő törlése a kaptáron, helyette azonnali Hans-protokoll feladat
    _scheduledTasks.removeWhere((t) => t.hiveId == hive.id && !t.isCompleted);
    final hansTask = ScheduledTask(
      id: 'HANS_${hive.id}',
      hiveId: hive.id,
      category: 'hans_protocol',
      title: '🔥 HANS-PROTOKOLL: Teljes torony zárlat & megsemmisítés',
      description: 'Nyúlós költésrothadás! A kaptár teljes tornya (minden fiók, aljdeszka, etető, tető, keret és méz) hatósági zárlat alatt áll. Azonnali kénlapos megsemmisítés szükséges — semmi nem kerülhet át máshova!',
      scheduledDate: DateTime.now(),
    );
    _scheduledTasks.insert(0, hansTask);

    _postToSupabase('treatments', {
      'monitor_mac': hive.id,
      'category': hansTask.category,
      'treatment_type': hansTask.title,
      'scheduled_date': hansTask.scheduledDate
          .toIso8601String()
          .split('T')
          .first,
      'is_completed': false,
      'notes': hansTask.description,
    }).then((inserted) {
      final int? newId = (inserted?['id'] as num?)?.toInt();
      if (newId != null && hansTask.dbId == null) {
        hansTask.dbId = newId;
        _saveHivesBoxesLocally();
      }
    });

    logHistoryEvent(
      hive.id,
      'hans_protokoll',
      'HANS-PROTOKOLL AKTIVÁLVA (Nyúlós költésrothadás): a teljes kaptártorony (${hive.boxes.length} elem) zárlat és megsemmisítés alá vonva!',
      metadata: _buildMonitorPayload(hive),
    );

    sendNtfyNotification(
      'NYÚLÓS KÖLTÉSROTHADÁS! ${hive.name} (${hive.id}) teljes tornya HANS-PROTOKOLL és zárlat alá került! Etetés leállítva, semmilyen elem nem vihető át máshova!',
      title: '🔥 HANS-PROTOKOLL: ${hive.name}',
      priority: 5,
      tags: 'rotating_light,fire,biohazard',
    );

    _patchToSupabase(
      'monitors',
      'mac_address=eq.${hive.id}',
      _buildMonitorPayload(hive),
    );
    _saveHivesBoxesLocally(immediate: true);
    notifyListeners();
  }

  /// Betegség lejelentése vagy visszavonása a kaptáron (kezelés ütemezése nélkül, kivéve Nyúlós -> Hans-protokoll).
  /// Visszatérési érték: true, ha a betegség aktívra lett állítva, false, ha törölve lett.
  bool toggleHiveDisease(HiveData hive, String diseaseId) {
    if (diseaseId == 'nyulos') {
      if (!hive.isQuarantined && !hive.reportedDiseases.contains('nyulos')) {
        activateHansProtocol(hive);
        return true;
      }
      return true;
    }

    final String label = kHiveDiseaseLabels[diseaseId] ?? diseaseId;
    final bool isAdding = !hive.reportedDiseases.contains(diseaseId);

    if (isAdding) {
      hive.reportedDiseases.add(diseaseId);
    } else {
      hive.reportedDiseases.remove(diseaseId);
    }

    _postToSupabase('history_logs', {
      'monitor_mac': hive.id,
      'event_type': 'betegseg_jelentes',
      'description': isAdding
          ? 'Betegség lejelentve: $label'
          : 'Betegség jelölés visszavonva: $label',
    });

    updateHive(hive);
    return isAdding;
  }

  /// Népesség felerősítése (fedett fias kerettel és/vagy dajkaméhekkel).
  /// A gyenge család státuszát automatikusan visszaállítja normál (Zöld) állapotra,
  /// és rögzíti a műveletet a treatments és a history_logs táblákban.
  void strengthenColony({
    required HiveData targetHive,
    required bool withBroodFrames,
    required int broodFrameCount,
    required bool withNurseBees,
    HiveData? donorHive,
  }) {
    if (targetHive.isQuarantined) return;
    if (donorHive != null && donorHive.isQuarantined) return;

    final List<String> parts = [];
    if (withBroodFrames && broodFrameCount > 0) {
      parts.add('$broodFrameCount db fedett fias kerettel');
    }
    if (withNurseBees) {
      parts.add('dajkaméhekkel');
    }
    if (parts.isEmpty) return;

    final String methodDesc = parts.join(' és ');
    final String donorDesc = donorHive != null
        ? ' (Donor: ${donorHive.name})'
        : '';

    final bool wasWeak = targetHive.isWeakOrSick || targetHive.isPoorPerformer;

    // 1. Gyenge státusz és paraméterek visszaállítása normálra (Zöld)
    if (!targetHive.isQueenReplacementActive) {
      targetHive.status = 'green';
    }
    final String fnLower = targetHive.familyFunction.toLowerCase();
    if (fnLower.contains('selejt') ||
        fnLower.contains('gyenge') ||
        fnLower.contains('beteg') ||
        fnLower.contains('felszámol') ||
        fnLower.contains('felszamol') ||
        fnLower.contains('mentés') ||
        fnLower.contains('mentes') ||
        fnLower.contains('szezon végén') ||
        fnLower.contains('szezon vegen')) {
      targetHive.familyFunction = 'tartalék';
    }

    // Ha a névben "(Gyenge)" vagy hasonló szerepelt, normálra cseréljük
    if (targetHive.name.toLowerCase().contains('gyenge')) {
      targetHive.name = targetHive.name.replaceAll(
        RegExp(r'gyenge', caseSensitive: false),
        'Felerősített',
      );
    }

    // Értékelési megjegyzés és negatív jegyek normalizálása felerősítés után
    final ev = targetHive.evaluation;
    final String notesLower = ev.notes.toLowerCase();
    if (notesLower.contains('gyenge') ||
        notesLower.contains('beteg') ||
        notesLower.contains('selejt') ||
        notesLower.contains('felszámol') ||
        notesLower.contains('felszamol')) {
      ev.notes = 'Népesség felerősítve ($methodDesc)';
    }
    if (ev.reproduction.contains('-')) ev.reproduction = '0';
    if (ev.building.contains('-')) ev.building = '0';
    if (ev.gathering.contains('-')) ev.gathering = '0';
    if (ev.winterSurvival.contains('-')) ev.winterSurvival = '0';

    // Beadott fias keretek és dajkaméhek fizikai hatása (súly, fészekhő, nyugodt zúgás)
    final double addedKg =
        (withBroodFrames ? broodFrameCount * 2.5 : 0.0) +
        (withNurseBees ? 0.8 : 0.0);
    if (targetHive.weight > 0) {
      targetHive.weight += addedKg;
      if (targetHive.weight < 30.5) {
        targetHive.weight = 30.5;
      }
    }
    if (targetHive.temp > 0 && targetHive.temp < 33.5) {
      targetHive.temp = 34.5;
    }
    if (targetHive.zcr > 0 && targetHive.zcr < 3000.0) {
      targetHive.zcr = 3650.0;
    }
    for (final b in targetHive.boxes) {
      if (!b.isQuarantined &&
          (b.status == 'yellow' || b.status == 'orange' || b.status == 'red')) {
        b.status = 'green';
      }
    }

    // Felerősítés tényének, idejének és bázissúlyának rögzítése:
    // - 60 napig nem kaphat Rekorder státuszt
    // - Ha ezután a többi családhoz képest ismét legyengül, felkiáltójelet (❗) kap!
    targetHive.lastStrengthenedAt = DateTime.now();
    targetHive.strengtheningCount += 1;
    targetHive.weightAtStrengthening = targetHive.weight;
    targetHive.hasRelapsedAfterStrengthening = false;
    targetHive.relapseReason = null;

    final String statusNote = wasWeak
        ? ' Státusz visszaállítva normál (Zöld) állapotra (Rekorder státusz zárolva).'
        : ' (Frissen erősített család: Rekorder státusz zárolva).';

    _postToSupabase('treatments', {
      'monitor_mac': targetHive.id,
      'treatment_type': 'Népesség felerősítése ($methodDesc)',
      'scheduled_date': DateTime.now().toIso8601String().split('T').first,
      'is_completed': true,
      'notes': 'Beadva: $methodDesc$donorDesc.$statusNote',
    });

    if (donorHive != null) {
      logHistoryEvent(
        donorHive.id,
        'donor_megcsapolas',
        'Megcsapolva (${targetHive.name} felerősítéséhez): $methodDesc átadva.',
      );
    }

    updateHive(
      targetHive,
      historyEventType: 'felerosites',
      historyDescription:
          'Népesség felerősítve (${targetHive.strengtheningCount}. alkalommal): $methodDesc$donorDesc.$statusNote',
      skipRelapseCheck: true,
    );
  }

  void updateHiveFeedingSettings(HiveData hive) {
    hive.updatedAt = DateTime.now().toUtc();
    _patchToSupabase(
      'monitors',
      'mac_address=eq.${hive.id}',
      _buildMonitorPayload(hive),
    );
    logHistoryEvent(
      hive.id,
      'etetes_beallitas',
      'Etető beállítás módosítva: mód=${hive.feedingMode}, adag=${hive.feedingPortionLiters}L, max=${hive.feedingMaxLiters}L, szint=${hive.feederLevelPercent.toInt()}%.',
      metadata: {
        'feeding_mode': hive.feedingMode,
        'feeding_max_liters': hive.feedingMaxLiters,
        'feeding_interval_hours': hive.feedingIntervalHours,
        'feeding_stop_sunset_min': hive.feedingStopBeforeSunsetMinutes,
        'feeding_portion_liters': hive.feedingPortionLiters,
        'feeder_level_percent': hive.feederLevelPercent,
        'feeder_calib_empty_mm': hive.feederCalibEmptyMm,
        'feeder_calib_full_mm': hive.feederCalibFullMm,
      },
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  // ==========================================================================
  // NTFY ÉRTESÍTÉSEK KÜLDÉSE (ntfy.sh / kb_sim7000g_balazs)
  // ==========================================================================
  Future<void> sendNtfyNotification(
    String message, {
    String title = 'Szirup Rendszer',
    int priority = 3,
    dynamic tags,
  }) async {
    try {
      final url = Uri.parse('https://ntfy.sh/kb_sim7000g_balazs');
      final headers = <String, String>{
        'Title': title,
        'Priority': priority.toString(),
      };
      if (tags != null) {
        if (tags is List) {
          headers['Tags'] = tags.join(',');
        } else {
          headers['Tags'] = tags.toString();
        }
      }
      await http.post(url, headers: headers, body: message);
    } catch (e) {
      debugPrint('Ntfy küldési hiba: $e');
    }
  }

  // ==========================================================================
  // SZIRUP UTÁNTÖLTÉS, AUTO-PÁROSÍTÁS, ÜTKÖZÉSVÉDELEM (SZTOJ) ÉS RETESZELÉS
  // ==========================================================================

  /// Monitor utántöltés kérése auto-párosítással és ütközéskezeléssel
  Future<void> requestSyrupRefillForHive(
    HiveData hive,
    double liters, {
    bool simulateTimeout = false,
  }) async {
    // 1. RETESZ ELLENŐRZÉS: Ha a szivattyú villogó piros retesz alatt van, NEM indulhat el!
    if (_syrupPump.isPumpInterlocked || _syrupPump.status == 'blinking_red') {
      hive.feederStatus = 'blinking_red';
      hive.feederStatusMessage =
          'Szivattyú LETILTVA (Villogó Piros): Vészleállítás aktív!';
      notifyListeners();
      return;
    }

    // 2. ÜTKÖZÉSVIZSGÁLAT (COLLISION DETECTION):
    // Ha egy másik kaptár éppen töltés alatt áll, a szerver küld egy "SZTOJ" jelet (5 perc várakozás)
    final busyHive = _hives.firstWhere(
      (h) => h.id != hive.id && h.isQueuedForRefill,
      orElse: () => HiveData(
        id: '',
        name: '',
        location: const LatLng(0, 0),
        status: 'green',
        temp: 0,
        humidity: 0,
        extTemp: 0,
        extHumidity: 0,
        weight: 0,
        batteryVoltage: 0,
        zcr: 0,
        boxes: [],
        serverConnection: '',
      ),
    );

    if (busyHive.id.isNotEmpty) {
      // ÜTKÖZÉS VAN! -> SZTOJ jelzés küldése ennek a monitornak (5 perc / 300 mp)
      hive.feederStatus = 'orange'; // Narancs: várakozóban
      hive.isQueuedForRefill = false;
      hive.sztojRemainingSeconds = 300;
      hive.feederStatusMessage =
          'SZTOJ: Várakozás másik adagoló (${busyHive.name}) feltöltésére (5 perc)';
      notifyListeners();

      await sendNtfyNotification(
        'SZTOJ JELZÉS: ${hive.name} kaptár utántöltése 5 percre várakoztatva, mert ${busyHive.name} töltése éppen folyamatban van.',
        title: 'Szirup Ütközésvédelem (SZTOJ)',
        priority: 2,
        tags: 'hourglass,warning',
      );
      return;
    }

    // 3. HA TISZTA A PÁLYA: Kijelöljük a szivattyút és elindítjuk a folyamatot
    hive.isQueuedForRefill = true;
    hive.feederStatus = 'orange'; // Narancs: adagolás folyamatban
    hive.feederStatusMessage =
        'Utántöltés folyamatban: ${liters.toStringAsFixed(1)}L -> ${_syrupPump.name}';
    _syrupPump.status = 'orange';
    _syrupPump.lastOperationStatus =
        'Adagolás: ${hive.name} (${liters.toStringAsFixed(1)}L)';
    notifyListeners();

    // 4. SZINTEMELKEDÉS WATCHDOG TIMEOUT VIZSGÁLAT
    if (simulateTimeout) {
      // Szimulált vagy valós hiba: a szivattyú jár, de NEM emelkedik a szirup szintje!
      await Future.delayed(const Duration(seconds: 2));
      triggerSyrupEmergencyTimeout(
        hive,
        _syrupPump,
        'Szintemelkedési timeout: nem emelkedik a szirup (csőtörés / dugulás / üres tartály)',
      );
      return;
    }

    // 5. NORMÁLIS MENET: Sikeres szintemelkedés és AUTO-PÁROSÍTÁS megerősítése
    await Future.delayed(const Duration(milliseconds: 1500));
    hive.isQueuedForRefill = false;
    hive.pairedTankId = _syrupPump.name;
    hive.isAutoPaired = true;
    if (!_syrupPump.pairedHiveNames.contains(hive.name)) {
      _syrupPump.pairedHiveNames.add(hive.name);
    }

    // Szint növelése
    hive.feederLevelPercent = (hive.feederLevelPercent + (liters * 18.0)).clamp(
      0.0,
      100.0,
    );
    hive.syrupLiters += liters;
    _syrupPump.totalPumpedLiters += liters;

    // Állapot beállítása a szint alapján
    if (hive.feederLevelPercent >= 50.0) {
      hive.feederStatus = 'green';
    } else if (hive.feederLevelPercent >= 20.0) {
      hive.feederStatus = 'yellow';
    } else {
      hive.feederStatus = 'orange';
    }
    hive.feederStatusMessage =
        'Auto-párosítva: ${_syrupPump.name} | Utántöltve: +${liters.toStringAsFixed(1)}L';

    _syrupPump.status = 'green';
    _syrupPump.lastOperationStatus =
        'Cél: ${hive.name} | ${liters.toStringAsFixed(1)}L (OK)';

    hive.updatedAt = DateTime.now().toUtc();
    _patchToSupabase(
      'monitors',
      'mac_address=eq.${hive.id}',
      _buildMonitorPayload(hive),
    );
    _syncPumpAndDevicesToSupabase();

    logHistoryEvent(
      hive.id,
      'etetes',
      'Szirup etetés: +${liters.toStringAsFixed(1)} L beadagolva (${_syrupPump.name}). Összesen: ${hive.syrupLiters.toStringAsFixed(1)} L.',
      metadata: {
        'liters': liters,
        'total_syrup_liters': hive.syrupLiters,
        'feeder_level_percent': hive.feederLevelPercent,
        'pump_id': _syrupPump.id,
      },
    );
    _saveHivesBoxesLocally();
    notifyListeners();

    await sendNtfyNotification(
      'Sikeres auto-párosítás és adagolás: ${hive.name} <-> ${_syrupPump.name} összerendelve! (+${liters.toStringAsFixed(1)}L beadagolva)',
      title: 'Szirup Párosítás & Adagolás OK',
      priority: 3,
      tags: 'white_check_mark,droplet',
    );
  }

  /// VÉSZLEÁLLÍTÁS: Szintemelkedési timeout -> Villogó Piros és Szivattyú Reteszelése
  void triggerSyrupEmergencyTimeout(
    HiveData hive,
    SyrupPumpData pump,
    String reason,
  ) {
    hive.isQueuedForRefill = false;
    hive.feederStatus = 'blinking_red';
    hive.feederStatusMessage = 'VÉSZLEÁLLÍTÁS: $reason';

    pump.status = 'blinking_red';
    pump.isPumpInterlocked = true; // SZIVATTYÚ TELJESEN LETILTVA!
    pump.emergencyStopReason = reason;
    pump.lastOperationStatus =
        'VÉSZLEÁLLÍTÁS: Szivattyú letiltva (Villogó Piros)!';

    _syncPumpAndDevicesToSupabase();
    logHistoryEvent(
      hive.id,
      'szirup_veszleallitas',
      'Szirup vészleállítás (${pump.name}): $reason',
    );
    _saveHivesBoxesLocally();
    notifyListeners();

    // Sürgős NTFY riasztás
    sendNtfyNotification(
      'VÉSZLEÁLLÍTÁS! ${hive.name} kaptárnál a szivattyú (${pump.name}) bekapcsolt, de a szirup szintje hosszabb ideig NEM emelkedett (Timeout)! A szivattyú azonnal leállítva és VILLOGÓ PIROS retesszel letiltva.',
      title: '🚨 SZIRUP VÉSZLEÁLLÍTÁS: ${hive.name}',
      priority: 5,
      tags: 'rotating_light,skull,warning',
    );
  }

  /// Vészleállítás / Villogó piros retesz feloldása a gazda által
  void resetPumpEmergencyInterlock(SyrupPumpData pump) {
    pump.isPumpInterlocked = false;
    pump.status = 'green';
    pump.emergencyStopReason = null;
    pump.lastOperationStatus = 'Készenlétben (Retesz feloldva)';

    for (var h in _hives) {
      if (h.feederStatus == 'blinking_red') {
        h.feederStatus = h.feederLevelPercent >= 50.0 ? 'green' : 'yellow';
        h.feederStatusMessage = 'Retesz feloldva, normál üzem visszaállítva.';
      }
    }

    _syncPumpAndDevicesToSupabase();
    logHistoryEvent(
      pump.id,
      'szirup_retesz_feloldva',
      'Szirup szivattyú (${pump.name}) vészretesz feloldva a gazda által.',
    );
    _saveHivesBoxesLocally();
    notifyListeners();

    sendNtfyNotification(
      'A szirup szivattyú (${pump.name}) vészretesze feloldva a gazda által. A rendszer újra üzemkész.',
      title: 'Szirup Retesz Törölve',
      priority: 3,
      tags: 'wrench,green_circle',
    );
  }

  void pumpSyrup(SyrupPumpData pump, double liters, String targetHiveName) {
    // 1. RETESZ ELLENŐRZÉS: Villogó piros esetén azonnali tiltás
    if (pump.isPumpInterlocked || pump.status == 'blinking_red') {
      pump.lastOperationStatus = 'SZIVATTYÚ TILTVA (VILLOGÓ PIROS)!';
      notifyListeners();
      return;
    }

    final targetHive = _hives.firstWhere(
      (h) => h.name == targetHiveName,
      orElse: () => _hives.first,
    );

    requestSyrupRefillForHive(targetHive, liters);
  }

  /// Sziruptartály valós idejű szenzoros szintjének frissítése
  void updateSyrupTankLevel(double levelPercent) {
    _syrupPump.tankLevelPercent = levelPercent.clamp(0.0, 100.0);
    _syncPumpAndDevicesToSupabase();
    logHistoryEvent(
      _syrupPump.id,
      'sziruptartaly_szint',
      'Központi sziruptartály (${_syrupPump.name}) szint frissítve: ${_syrupPump.tankLevelPercent.toStringAsFixed(0)}%.',
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void setSyrupPumpEmergency(bool isEmergency, {String? reason}) {
    _syrupPump.isPumpInterlocked = isEmergency;
    if (isEmergency) {
      _syrupPump.status = 'blinking_red';
      _syrupPump.emergencyStopReason =
          reason ?? 'Vészleállítás: szivattyú reteszelve és tiltva!';
    } else {
      _syrupPump.status = 'green';
      _syrupPump.emergencyStopReason = null;
    }
    _syncPumpAndDevicesToSupabase();
    logHistoryEvent(
      _syrupPump.id,
      isEmergency ? 'szirup_veszleallitas' : 'szirup_retesz_feloldva',
      isEmergency
          ? 'Szirupszivattyú vészretesz aktiválva: ${_syrupPump.emergencyStopReason}'
          : 'Szirupszivattyú retesz feloldva.',
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  /// Vízadagoló valós idejű vízszintjének frissítése
  void updateWatererLevel(double levelPercent) {
    _waterer.waterLevel = levelPercent.clamp(0.0, 100.0);
    _syncPumpAndDevicesToSupabase();
    logHistoryEvent(
      _waterer.id,
      'itato_szint',
      'Itató (${_waterer.name}) vízszint frissítve: ${_waterer.waterLevel.toStringAsFixed(0)}%.',
    );
    if (_waterer.waterLevel <= 5.0) {
      sendNtfyNotification(
        'Az itató (${_waterer.name}) vízszintje 5% alá esett! Utántöltés szükséges!',
        title: '⚠️ Kiszáradt vízadagoló!',
        priority: 4,
        tags: 'warning,droplet',
      );
    }
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  /// Vízadagoló hőmérsékletének frissítése (fagyvédelem)
  void updateWatererTemp(double temp) {
    _waterer.waterTemp = temp;
    if (_waterer.waterTemp <= 1.0) {
      _waterer.emergencyStopReason =
          'FAGYVESZÉLY: A vízhőmérséklet ${_waterer.waterTemp.toStringAsFixed(1)}°C-ra süllyedt!';
      sendNtfyNotification(
        'Az itató vízhőmérséklete ${_waterer.waterTemp.toStringAsFixed(1)}°C! Fagyás és jégképződés veszély!',
        title: '❄️ Vízadagoló fagyveszély!',
        priority: 5,
        tags: 'snowflake,rotating_light',
      );
    }
    _syncPumpAndDevicesToSupabase();
    logHistoryEvent(
      _waterer.id,
      'itato_homerseklet',
      'Itató vízhőmérséklet frissítve: ${_waterer.waterTemp.toStringAsFixed(1)} °C.',
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  /// Vízadagoló vészleállítása / kézi reteszelése
  void setWatererEmergency(bool isEmergency, {String? reason}) {
    _waterer.isInterlocked = isEmergency;
    if (isEmergency) {
      _waterer.emergencyStopReason =
          reason ?? 'Vészleállítás / szivárgás védelem aktív!';
      sendNtfyNotification(
        'Az itató (${_waterer.name}) leállítva: ${_waterer.emergencyStopReason}',
        title: '🚨 Vízadagoló vészleállítás!',
        priority: 5,
        tags: 'rotating_light,alert',
      );
    } else {
      _waterer.emergencyStopReason = null;
    }
    _syncPumpAndDevicesToSupabase();
    logHistoryEvent(
      _waterer.id,
      isEmergency ? 'itato_veszleallitas' : 'itato_retesz_feloldva',
      isEmergency
          ? 'Itató vészretesz aktiválva: ${_waterer.emergencyStopReason}'
          : 'Itató vészretesz feloldva.',
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  /// Vízadagoló vészhelyzeti reteszének feloldása
  void resetWatererEmergency() {
    _waterer.isInterlocked = false;
    _waterer.emergencyStopReason = null;
    _waterer.status = 'green';
    if (_waterer.waterTemp <= 1.0) {
      _waterer.waterTemp =
          18.5; // Normál hőmérséklet visszaállítása feloldáskor
    }
    _syncPumpAndDevicesToSupabase();
    logHistoryEvent(
      _waterer.id,
      'itato_retesz_feloldva',
      'Itató (${_waterer.name}) vészretesz feloldva.',
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void schedulePlanForHive(String hiveId, String planType, DateTime startDate) {
    List<ScheduledTask> newTasks = [];
    if (planType == 'petes_mesterterv') {
      newTasks = TreatmentAdviser.generatePetesMasterPlan(hiveId, startDate);
    } else if (planType == 'alcas_mesterterv') {
      newTasks = TreatmentAdviser.generateAlcasMasterPlan(hiveId, startDate);
    } else if (planType == 'anyanevelesi_mesterterv') {
      newTasks = TreatmentAdviser.generatePetesMasterPlan(hiveId, startDate);
    } else if (planType == 'grumpy_cat') {
      newTasks = TreatmentAdviser.generateGrumpyCatProtocol(hiveId, startDate);
    } else if (planType == 'oxalsav_egyszeri') {
      newTasks = TreatmentAdviser.generateOxalicPlan(
        hiveId,
        startDate,
        isSeries: false,
      );
    } else if (planType == 'oxalsav_sorozat') {
      newTasks = TreatmentAdviser.generateOxalicPlan(
        hiveId,
        startDate,
        isSeries: true,
      );
    } else if (planType == 'hereskeret') {
      newTasks = TreatmentAdviser.generateDroneFramePlan(hiveId, startDate);
    } else if (planType == 'tarto_hordozo') {
      newTasks = [
        ScheduledTask(
          id: 'STRIP_${hiveId}_${startDate.millisecondsSinceEpoch}_0',
          hiveId: hiveId,
          category: 'atkairtas',
          title: 'Tartós hordozós atkairtó csík behelyezése',
          description:
              'Tartós hordozós atkairtó csíkok behelyezése a fészekbe.',
          scheduledDate: startDate,
          isCompleted: true,
        ),
        ScheduledTask(
          id: 'STRIP_${hiveId}_${startDate.millisecondsSinceEpoch}_42',
          hiveId: hiveId,
          category: 'atkairtas',
          title: 'Tartós hordozós csíkok eltávolítása (6 hét)',
          description: 'A 6 hetes kezelési ciklus lejárt: a hordozócsíkokat el kell távolítani a rezisztencia megelőzésére!',
          scheduledDate: startDate.add(const Duration(days: 42)),
        ),
      ];
    } else if (planType == 'hangyasav') {
      newTasks = [
        ScheduledTask(
          id: 'FORMIC_${hiveId}_${startDate.millisecondsSinceEpoch}_0',
          hiveId: hiveId,
          category: 'atkairtas',
          title: 'Hangyasavas kezelés (párologtatás)',
          description: 'Hangyasavas atkairtó kezelés elindítva az időjárási ablak figyelembevételével.',
          scheduledDate: startDate,
          isCompleted: true,
        ),
        ScheduledTask(
          id: 'FORMIC_${hiveId}_${startDate.millisecondsSinceEpoch}_7',
          hiveId: hiveId,
          category: 'atkairtas',
          title: 'Hangyasavas kezelés kontroll & atkahullás ellenőrzése',
          description: 'Párolgás ütemének, méhanya meglétének és a lehullott atkák számának ellenőrzése.',
          scheduledDate: startDate.add(const Duration(days: 7)),
        ),
      ];
    } else if (planType == 'felerosites_mesterterv') {
      newTasks = [
        ScheduledTask(
          id: 'STRENGTHEN_PLAN_${hiveId}_${startDate.millisecondsSinceEpoch}',
          hiveId: hiveId,
          category: 'felerosites',
          title: 'Selejt család hasznosítása (felerősítés / egyesítés)',
          description: 'Fedett fias keretek vagy dajkaméhek átcsoportosítása gyengébb családok felerősítéséhez.',
          scheduledDate: startDate.add(const Duration(days: 1)),
        ),
      ];
    }

    final int hiveIdx = _hives.indexWhere((h) => h.id == hiveId);
    if (hiveIdx != -1 && !_hives[hiveIdx].isQuarantined) {
      _hives[hiveIdx].protocol = planType;
      updateHive(_hives[hiveIdx]);
    }

    _scheduledTasks.addAll(newTasks);

    for (var t in newTasks) {
      _postToSupabase('treatments', {
        'monitor_mac': hiveId,
        'category': t.category,
        'treatment_type': t.title,
        'scheduled_date': t.scheduledDate.toIso8601String().split('T').first,
        'is_completed': t.isCompleted,
        'notes': t.description,
      }).then((inserted) {
        final int? newId = (inserted?['id'] as num?)?.toInt();
        if (newId != null && t.dbId == null) {
          t.dbId = newId;
          _saveHivesBoxesLocally();
        }
      });
    }

    logHistoryEvent(
      hiveId,
      'kezelési_terv',
      'Kezelés / munkaterv rögzítve: $planType (${newTasks.length} lépés).',
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void completeTask(String taskId) {
    for (var t in _scheduledTasks) {
      if (t.id == taskId) {
        t.isCompleted = true;
        if (t.dbId != null) {
          _patchToSupabase('treatments', 'id=eq.${t.dbId}', {
            'is_completed': true,
            'notes': 'Elvégezve: ${t.description}',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        } else {
          _postToSupabase('treatments', {
            'monitor_mac': t.hiveId,
            'category': t.category,
            'treatment_type': t.title,
            'scheduled_date': DateTime.now().toIso8601String().split('T').first,
            'is_completed': true,
            'notes': 'Elvégezve: ${t.description}',
          });
        }
        logHistoryEvent(
          t.hiveId,
          'feladat_kesz',
          'Ütemezett feladat elvégezve: ${t.title}',
        );
        break;
      }
    }
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void addScheduledTask(ScheduledTask task) {
    _scheduledTasks.add(task);
    _postToSupabase('treatments', {
      'monitor_mac': task.hiveId,
      'category': task.category,
      'treatment_type': task.title,
      'scheduled_date': task.scheduledDate.toIso8601String().split('T').first,
      'is_completed': task.isCompleted,
      'notes': task.description,
    }).then((inserted) {
      final int? newId = (inserted?['id'] as num?)?.toInt();
      if (newId != null && task.dbId == null) {
        task.dbId = newId;
        _saveHivesBoxesLocally();
      }
    });
    logHistoryEvent(
      task.hiveId,
      'feladat_utemezes',
      'Új feladat ütemezve (${task.scheduledDate.toIso8601String().split("T").first}): ${task.title}',
    );
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void scheduleQueenAcceptanceInspection(
    HiveData hive,
    DateTime scheduledDate,
  ) {
    scheduleQueenReplacementTasks(
      hive,
      isCageMode: false,
      custom14DayDate: scheduledDate,
    );
  }

  void scheduleQueenReplacementTasks(
    HiveData hive, {
    required bool isCageMode,
    DateTime? custom14DayDate,
  }) {
    final now = DateTime.now();
    final inspection3Day = DateTime(now.year, now.month, now.day + 3, 10, 0);

    // Eltávolítjuk a korábbi anyacserés teendőket ennél a kaptárnál a duplikáció elkerülésére
    _scheduledTasks.removeWhere(
      (t) =>
          t.hiveId == hive.id &&
          (t.id.contains('QUEEN') ||
              t.title.contains('Anyakalitka') ||
              t.title.contains('Anya elfogadás') ||
              t.title.contains('Anyásítás vizsgálata')),
    );

    if (isCageMode) {
      // Szoktatós mód: 3 nap múlva kalitka átállítása kirágósra
      final cageTask = ScheduledTask(
        id: 'TASK_${hive.id}_QUEEN_CAGE_${now.millisecondsSinceEpoch}',
        hiveId: hive.id,
        category: 'inspection',
        title: 'Anyakalitka kirágósra állítása (3 nap)',
        description:
            'A 3 napos beszoktatási idő letelt a(z) ${hive.name} kaptárban. Nyisd meg a cukorlepényes kirágónyílást a kalitkán, hogy a méhek ki tudják rágni az anyát!',
        scheduledDate: inspection3Day,
        isCompleted: false,
      );
      addScheduledTask(cageTask);
    } else {
      // Kirágós mód: 2 hétig (14 napig) teljes nyugalom (lakat: tilos bolygatni)!
      // Kizárólag a 14 napos lakat lejárata napjára ütemezünk vizsgálatot.
      final lockEnd =
          custom14DayDate ??
          (hive.lockedUntil ?? now.add(const Duration(days: 14)));
      final inspection14Day = DateTime(
        lockEnd.year,
        lockEnd.month,
        lockEnd.day,
        10,
        0,
      );
      final inspectionTask = ScheduledTask(
        id: 'TASK_${hive.id}_QUEEN_INSP_${now.millisecondsSinceEpoch}',
        hiveId: hive.id,
        category: 'inspection',
        title: 'Anyásítás vizsgálata: Petézés & Fiasítás (14 nap)',
        description:
            'Lejárt a 14 napos nyugalmi időszak ("ne nyúlj hozzá") a(z) ${hive.name} kaptárban. Vizsgáld meg az új anya elfogadását, a petézést és a fiasításképet!',
        scheduledDate: inspection14Day,
        isCompleted: false,
      );
      addScheduledTask(inspectionTask);
    }
  }

  void addLocalFrameAnalysis(FrameAnalysisRecord record) {
    _pendingFrameAnalyses.add(record);
    logHistoryEvent(
      record.hiveId,
      'keret_ai_elemzes',
      'Fészekkeret vizsgálat: Népesség: ${record.populationEstimate}, Fedett fiasítás: ${record.cappedBroodPct}%, Nyílt: ${record.openBroodPct}%${record.queenCellsDetected ? " (Anyabölcső észlelve!)" : ""} – ${record.broodHealthNote}',
      metadata: {
        'population': record.populationEstimate,
        'capped_brood_pct': record.cappedBroodPct,
        'open_brood_pct': record.openBroodPct,
        'queen_cells': record.queenCellsDetected,
        'health_note': record.broodHealthNote,
      },
    );

    final int hIdx = _hives.indexWhere((h) => h.id == record.hiveId);
    if (hIdx != -1) {
      final hive = _hives[hIdx];
      final popLower = record.populationEstimate.toLowerCase();
      if (hive.wasEverStrengthened &&
          !hive.isQuarantined &&
          (popLower.contains('gyenge') ||
              popLower.contains('kevés') ||
              popLower.contains('keves') ||
              popLower.contains('alacsony') ||
              record.cappedBroodPct < 15)) {
        if (!hive.hasRelapsedAfterStrengthening) {
          hive.hasRelapsedAfterStrengthening = true;
          hive.relapseReason =
              'keretvizsgálaton ismét gyenge népesség/fiasítás (${record.populationEstimate}, ${record.cappedBroodPct}% fedett fias)';
          if (hive.status == 'green') hive.status = 'orange';
          hive.updatedAt = DateTime.now().toUtc();
          _patchToSupabase(
            'monitors',
            'mac_address=eq.${hive.id}',
            _buildMonitorPayload(hive),
          );
          logHistoryEvent(
            hive.id,
            'visszaeses_erosites_utan',
            '❗ VISSZAESETT CSALÁD: felerősítés után keretvizsgálaton ismét legyengült (${record.populationEstimate}, fedett fias: ${record.cappedBroodPct}%).',
          );
          _saveHivesBoxesLocally();
        }
      }
    }
    notifyListeners();
  }

  void addVarroaAnalysis({
    required HiveData hive,
    required VarroaAnalysisRecord record,
    required bool pullOutBoard,
  }) {
    final DateTime nowUtc = DateTime.now().toUtc();
    hive.dailyVarroaDrop = record.dailyDrop;
    hive.updatedAt = nowUtc;

    if (pullOutBoard) {
      for (var box in hive.boxes) {
        if (box.type == 'bottom') {
          box.isActive = false;
          box.statusUpdatedAt = null;
          box.updatedAt = nowUtc;
          final Map<String, dynamic> patchData = {
            'is_active': false,
            'status_updated_at': null,
            'updated_at': nowUtc.toIso8601String(),
          };
          if (box.dbId != null) {
            _patchToSupabase('bodies', 'id=eq.${box.dbId}', patchData);
          } else {
            _patchToSupabase(
              'bodies',
              'monitor_mac=eq.${hive.id}&body_function=eq.bottom',
              patchData,
            );
          }
        }
      }
    }

    evaluateColonyRelapses(onlyHive: hive, notify: false);
    _patchToSupabase(
      'monitors',
      'mac_address=eq.${hive.id}',
      _buildMonitorPayload(hive),
    );

    if (record.localImagePath.isNotEmpty) {
      _pendingVarroaAnalyses.add(record);
    }

    logHistoryEvent(
      hive.id,
      'atkaszamlalas',
      'Észlelt atka: ${record.miteCount} db / ${record.daysInserted} nap (${record.dailyDrop.toStringAsFixed(1)} db/nap)',
      metadata: {
        'mite_count': record.miteCount,
        'days_inserted': record.daysInserted,
        'daily_drop': record.dailyDrop,
        'board_removed': pullOutBoard,
      },
    );

    _saveHivesBoxesLocally();
    notifyListeners();
  }

  Future<int> syncPendingFramesAndCleanup() async {
    int processedCount = 0;

    final unsyncedFrames = _pendingFrameAnalyses
        .where((r) => !r.isSyncedWithCloud)
        .toList();
    for (var record in unsyncedFrames) {
      try {
        record.isSyncedWithCloud = true;
        if (record.localImagePath.isNotEmpty &&
            !record.localImagePath.startsWith('camera://')) {
          final file = File(record.localImagePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        processedCount++;
      } catch (e) {
        debugPrint('Hiba a keret szinkronizálásakor: $e');
      }
    }
    _pendingFrameAnalyses.removeWhere((r) => r.isSyncedWithCloud);

    final unsyncedVarroa = _pendingVarroaAnalyses
        .where((r) => !r.isSyncedWithCloud)
        .toList();
    for (var record in unsyncedVarroa) {
      try {
        record.isSyncedWithCloud = true;
        final file = File(record.localImagePath);
        if (await file.exists()) {
          await file.delete();
        }
        processedCount++;
      } catch (e) {
        debugPrint('Hiba az aljdeszka fotó törlésekor: $e');
      }
    }
    _pendingVarroaAnalyses.removeWhere((r) => r.isSyncedWithCloud);

    notifyListeners();
    return processedCount;
  }

  // ---- OFFLINE QUEUE KEZELÉS, SÉMA-TOLERÁNS ÍRÁS ÉS HÁTTÉRSZINKRONIZÁLÁS ----

  Map<String, Set<String>>? _unsupportedTableColumns;
  Map<String, Set<String>> get _unsupportedCols =>
      _unsupportedTableColumns ??= <String, Set<String>>{};

  Map<String, dynamic> _filterKnownSupportedColumns(
    String table,
    Map<String, dynamic> data,
  ) {
    final unsupported = _unsupportedCols[table];
    if (unsupported == null || unsupported.isEmpty) {
      return Map<String, dynamic>.from(data);
    }
    final filtered = Map<String, dynamic>.from(data);
    for (final col in unsupported) {
      filtered.remove(col);
    }
    return filtered;
  }

  String? _detectMissingColumnFromError(
    String body,
    Map<String, dynamic> attemptedData,
  ) {
    final m1 = RegExp(r"Could not find the '([^']+)' column").firstMatch(body);
    if (m1 != null && attemptedData.containsKey(m1.group(1))) {
      return m1.group(1);
    }
    final m2 = RegExp(r'column "([^"]+)"').firstMatch(body);
    if (m2 != null && attemptedData.containsKey(m2.group(1))) {
      return m2.group(1);
    }
    for (final key in attemptedData.keys) {
      if (body.contains("'$key'") ||
          body.contains('"$key"') ||
          body.contains('.$key ')) {
        return key;
      }
    }
    return null;
  }

  Future<http.Response> _postWithSchemaFallback(
    String table,
    Map<String, dynamic> data,
  ) async {
    final payload = _filterKnownSupportedColumns(table, data);
    if (payload.isEmpty) {
      return http.Response('[]', 200);
    }
    var res = await _httpClient
        .post(
          Uri.parse('$_supabaseUrl/rest/v1/$table'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 4));

    int guards = 0;
    while (res.statusCode == 400 && payload.isNotEmpty && guards < 45) {
      final missingCol = _detectMissingColumnFromError(res.body, payload);
      if (missingCol == null) break;
      _unsupportedCols.putIfAbsent(table, () => <String>{}).add(missingCol);
      payload.remove(missingCol);
      if (payload.isEmpty) {
        return http.Response('[]', 200);
      }
      res = await _httpClient
          .post(
            Uri.parse('$_supabaseUrl/rest/v1/$table'),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
      guards++;
    }

    // Ha a history_logs táblán még él a régi monitors(mac_address) idegenkulcs-megszorítás (409),
    // és egy telephelyi / irodai eseményt ('OFFICE', 'PROCESSING_ROOM' stb.) küldünk,
    // automatikusan átirányítjuk az első ismert kaptár MAC-címére címkézve, hogy semmi se vesszen el!
    if (table == 'history_logs' &&
        res.statusCode == 409 &&
        _hives.isNotEmpty &&
        payload['monitor_mac'] != _hives.first.id) {
      final String origTarget = (payload['monitor_mac'] ?? '').toString();
      final fallbackPayload = Map<String, dynamic>.from(payload);
      fallbackPayload['monitor_mac'] = _hives.first.id;
      fallbackPayload['description'] =
          '[$origTarget] ${payload['description'] ?? ''}';
      res = await _httpClient
          .post(
            Uri.parse('$_supabaseUrl/rest/v1/$table'),
            headers: _headers,
            body: jsonEncode(fallbackPayload),
          )
          .timeout(const Duration(seconds: 4));
    }

    return res;
  }

  Future<http.Response> _patchWithSchemaFallback(
    String table,
    String queryFilter,
    Map<String, dynamic> data,
  ) async {
    final payload = _filterKnownSupportedColumns(table, data);
    if (payload.isEmpty) {
      return http.Response('[]', 200);
    }
    var res = await _httpClient
        .patch(
          Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 4));

    int guards = 0;
    while (res.statusCode == 400 && payload.isNotEmpty && guards < 45) {
      final missingCol = _detectMissingColumnFromError(res.body, payload);
      if (missingCol == null) break;
      _unsupportedCols.putIfAbsent(table, () => <String>{}).add(missingCol);
      payload.remove(missingCol);
      if (payload.isEmpty) {
        return http.Response('[]', 200);
      }
      res = await _httpClient
          .patch(
            Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
      guards++;
    }

    // Automatikus UPSERT fallback: ha a sor még nem létezik az adatbázisban (üres '[]' válasz), beszúrjuk
    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        res.body.trim() == '[]') {
      if (table == 'monitors' && queryFilter.startsWith('mac_address=eq.')) {
        final String mac = queryFilter.substring('mac_address=eq.'.length);
        if (mac.isNotEmpty) {
          res = await _postWithSchemaFallback('monitors', {
            'mac_address': mac,
            ...payload,
          });
        }
      } else if (table == 'queens' &&
          queryFilter.startsWith('queen_number=eq.')) {
        final String qNum = queryFilter.substring('queen_number=eq.'.length);
        if (qNum.isNotEmpty) {
          res = await _postWithSchemaFallback('queens', {
            'queen_number': qNum,
            ...payload,
          });
        }
      } else if (table == 'syrup_pumps' && queryFilter.startsWith('id=eq.')) {
        final String pId = queryFilter.substring('id=eq.'.length);
        if (pId.isNotEmpty) {
          res = await _postWithSchemaFallback('syrup_pumps', {
            'id': pId,
            ...payload,
          });
        }
      }
    }
    return res;
  }

  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty || !_isOnline || _isProcessingQueue) return;
    _isProcessingQueue = true;

    final List<Map<String, dynamic>> failedItems = [];

    try {
      for (var item in List.from(_offlineQueue)) {
        final String method = item['method'];
        final String table = item['table'];
        final String? queryFilter = item['queryFilter'];
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          item['data'] as Map,
        );

        try {
          int statusCode = 200;
          if (method == 'POST') {
            final res = await _postWithSchemaFallback(table, data);
            statusCode = res.statusCode;
          } else if (method == 'PATCH') {
            final res = await _patchWithSchemaFallback(
              table,
              queryFilter ?? '',
              data,
            );
            statusCode = res.statusCode;
          } else if (method == 'DELETE') {
            final res = await _httpClient
                .delete(
                  Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
                  headers: _headers,
                )
                .timeout(const Duration(seconds: 4));
            statusCode = res.statusCode;
          }

          // Csak 5xx szerverhiba esetén tartjuk meg a sorban; 4xx séma/kliens hiba ne ragadjon be végtelen ciklusba!
          if (statusCode >= 500) {
            failedItems.add(item);
          }
        } catch (e) {
          failedItems.add(item);
        }
      }

      _offlineQueue = failedItems;
      await _saveOfflineQueue();
    } finally {
      _isProcessingQueue = false;
    }
    notifyListeners();
  }

  HistoryLogEntry _recordLocalHistoryEntry(Map<String, dynamic> data) {
    final DateTime now = DateTime.now();
    Map<String, dynamic>? meta;
    if (data['metadata'] is Map) {
      meta = Map<String, dynamic>.from(data['metadata'] as Map);
    }
    final entry = HistoryLogEntry(
      localId:
          'LOC_${now.microsecondsSinceEpoch}_${historyLogs.length}',
      monitorMac: (data['monitor_mac'] ?? 'SYSTEM').toString(),
      eventType: (data['event_type'] ?? 'esemeny').toString(),
      description: (data['description'] ?? '').toString(),
      createdAt: now,
      metadata: meta,
    );
    historyLogs.insert(0, entry);
    if (historyLogs.length > 500) {
      historyLogs.removeRange(500, historyLogs.length);
    }
    _saveHivesBoxesLocally();
    return entry;
  }

  void _mergeRemoteHistoryLogs(List<dynamic> histList) {
    for (final raw in histList) {
      if (raw is! Map) continue;
      final rowMap = Map<String, dynamic>.from(raw);
      if (rowMap['metadata'] is String) {
        final mStr = (rowMap['metadata'] as String).trim();
        if (mStr.startsWith('{')) {
          try {
            rowMap['metadata'] = Map<String, dynamic>.from(
              jsonDecode(mStr) as Map,
            );
          } catch (_) {}
        }
      }
      final remote = HistoryLogEntry.fromJson(rowMap);
      final int existingByDbId = remote.dbId != null
          ? historyLogs.indexWhere(
              (e) => !e.isAutoTelemetry && e.dbId == remote.dbId,
            )
          : -1;
      if (existingByDbId >= 0) {
        historyLogs[existingByDbId] = remote;
        continue;
      }
      // Optimista helyi bejegyzés összepárosítása, ha még nem kapott dbId-t
      final int optimisticIdx = historyLogs.indexWhere(
        (e) =>
            !e.isAutoTelemetry &&
            e.dbId == null &&
            e.monitorMac == remote.monitorMac &&
            e.eventType == remote.eventType &&
            e.description == remote.description &&
            (e.createdAt.difference(remote.createdAt).inSeconds).abs() <= 60,
      );
      if (optimisticIdx >= 0) {
        historyLogs[optimisticIdx] = remote;
      } else {
        historyLogs.add(remote);
      }
    }
    _sortAndTrimHistoryLogs();
  }

  void _mergeRemoteHiveMeters(
    List<dynamic> meterList, {
    Map<String, Map<String, dynamic>>? latestMeterByMacOut,
  }) {
    for (final raw in meterList) {
      if (raw is! Map) continue;
      final rowMap = Map<String, dynamic>.from(raw);
      final String mac =
          (rowMap['monitor_mac'] ?? rowMap['mac_address'] ?? '').toString();
      if (mac.isNotEmpty && latestMeterByMacOut != null) {
        latestMeterByMacOut.putIfAbsent(mac, () => rowMap);
      }
      final entry = HistoryLogEntry.fromHiveMeterRow(rowMap);
      final int existingIdx = historyLogs.indexWhere(
        (e) =>
            e.isAutoTelemetry &&
            ((entry.dbId != null && e.dbId == entry.dbId) ||
                e.localId == entry.localId),
      );
      if (existingIdx >= 0) {
        historyLogs[existingIdx] = entry;
      } else {
        historyLogs.add(entry);
      }
    }
    _sortAndTrimHistoryLogs();
  }

  void _sortAndTrimHistoryLogs() {
    historyLogs.sort((a, b) {
      final cmp = b.createdAt.compareTo(a.createdAt);
      if (cmp != 0) return cmp;
      return (b.dbId ?? 0).compareTo(a.dbId ?? 0);
    });
    if (historyLogs.length > 600) {
      historyLogs.removeRange(600, historyLogs.length);
    }
  }

  /// Irodai History nézet gyors frissítése közvetlenül a Supabase history_logs ÉS hive_meters tábláiból
  Future<bool> refreshHistoryFromSupabase({int limit = 300}) async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) return false;
    try {
      await _processOfflineQueue();
      final Future<http.Response?> metersFuture = _httpClient
          .get(
            Uri.parse(
              '$_supabaseUrl/rest/v1/hive_meters?select=*&order=id.desc&limit=200',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5))
          .then<http.Response?>((r) => r, onError: (_) => null);

      http.Response res = await _httpClient
          .get(
            Uri.parse(
              '$_supabaseUrl/rest/v1/history_logs?select=*&order=id.desc&limit=$limit',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 400) {
        res = await _httpClient
            .get(
              Uri.parse(
                '$_supabaseUrl/rest/v1/history_logs?select=*&order=created_at.desc&limit=$limit',
              ),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 5));
      }

      http.Response? metersRes = await metersFuture;
      if (metersRes != null && metersRes.statusCode == 400) {
        metersRes = await _httpClient
            .get(
              Uri.parse(
                '$_supabaseUrl/rest/v1/hive_meters?select=*&order=created_at.desc&limit=200',
              ),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 4))
            .then<http.Response?>((r) => r, onError: (_) => null);
      }

      bool updatedAny = false;
      if (res.statusCode == 200) {
        _isOnline = true;
        final List<dynamic> histList = jsonDecode(res.body);
        _mergeRemoteHistoryLogs(histList);
        updatedAny = true;
      }
      if (metersRes != null && metersRes.statusCode == 200) {
        _isOnline = true;
        final List<dynamic> meterList = jsonDecode(metersRes.body);
        final Map<String, Map<String, dynamic>> latestByMac = {};
        _mergeRemoteHiveMeters(meterList, latestMeterByMacOut: latestByMac);
        for (final hive in _hives) {
          final latest = latestByMac[hive.id];
          if (latest != null) {
            if (latest['inner_temp'] is num) {
              hive.temp = (latest['inner_temp'] as num).toDouble();
            }
            if (latest['humidity'] is num) {
              hive.humidity = (latest['humidity'] as num).toDouble();
            }
            if (latest['noise'] is num) {
              hive.zcr = (latest['noise'] as num).toDouble();
            }
            if (latest['weight'] is num) {
              hive.weight = (latest['weight'] as num).toDouble();
            }
          }
        }
        updatedAny = true;
      }
      if (updatedAny) {
        await _saveHivesBoxesLocally(immediate: true);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('History gyorsfrissítés hiba: $e');
    }
    return false;
  }

  /// Időjárás-állomás előzmények frissítése a Supabase `public.weather_logs` táblájából
  Future<bool> refreshWeatherHistoryFromSupabase({int days = 32}) async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) return false;
    try {
      final sinceIso = DateTime.now()
          .toUtc()
          .subtract(Duration(days: days))
          .toIso8601String();
      final res = await _httpClient
          .get(
            Uri.parse(
              '$_supabaseUrl/rest/v1/weather_logs?select=*&created_at=gte.$sinceIso&order=created_at.asc&limit=1000',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        _isOnline = true;
        final List<dynamic> rows = jsonDecode(res.body);
        if (rows.isNotEmpty) {
          final parsed = rows
              .whereType<Map>()
              .map(
                (r) => WeatherLogPoint.fromJson(Map<String, dynamic>.from(r)),
              )
              .toList();
          parsed.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          weatherLogs
            ..clear()
            ..addAll(parsed);
          await _saveHivesBoxesLocally();
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Időjárás history lekérés hiba: $e');
    }
    return false;
  }

  /// Visszaadja az időjárás-állomás idősoros adatait az elmúlt `days` napra (óránkénti bontásban).
  /// Ha már vannak valós Supabase `weather_logs` sorok, azokat adja vissza;
  /// amíg a hardver még nem küldött idősoros adatot, az állomás aktuális paramétereihez illesztett,
  /// determinisztikus óránkénti előnézeti adatsort generál (ma, tegnap, ezen a héten, múlt héten, 30 nap).
  List<WeatherLogPoint> getEffectiveWeatherHistory({int days = 32}) {
    if (weatherLogs.isNotEmpty) {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      return weatherLogs
          .where((p) => !p.timestamp.isBefore(cutoff))
          .toList();
    }

    final now = DateTime.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);
    final int totalHours = days * 24;
    final List<WeatherLogPoint> generated = [];
    const List<String> dirs = ['ÉNy', 'Ny', 'DNy', 'D', 'DK', 'K', 'ÉK', 'É'];

    final double anchorTemp = _weatherStation.temp;
    final double anchorHum = _weatherStation.humidity;
    final double anchorPress = _weatherStation.pressure;

    for (int hBack = totalHours; hBack >= 0; hBack--) {
      final dt = currentHour.subtract(Duration(hours: hBack));
      final int daySeed = dt.year * 372 + dt.month * 31 + dt.day;
      final int hour = dt.hour;

      // Napi szinuszos hőmérséklet-görbe (minimum ~05:00-kor, maximum ~15:00-kor) + többnapos front-hullámzás
      final double diurnal = math.sin(((hour - 9) / 24.0) * 2.0 * math.pi);
      final double synopticWave =
          3.4 * math.sin(daySeed * 0.45) + 1.8 * math.cos(daySeed * 0.21);
      // Az aktuális órában pontosan az állomás élő értékéhez simul
      final double blendToLive = hBack <= 6 ? (6 - hBack) / 6.0 : 0.0;

      final double rawTemp = (anchorTemp - 3.2) + synopticWave + (5.8 * diurnal);
      final double tempC = double.parse(
        (rawTemp * (1.0 - blendToLive) + anchorTemp * blendToLive)
            .toStringAsFixed(1),
      );

      // Frontátvonulás és csapadék szimuláció néhány esős órával a héten és múlt héten
      final double frontDrop = -7.5 * math.max(0.0, math.sin(daySeed * 0.62));
      final double rawPress =
          anchorPress + frontDrop + 1.8 * math.cos((hour / 24.0) * 2 * math.pi);
      final double pressureHpa = double.parse(
        (rawPress * (1.0 - blendToLive) + anchorPress * blendToLive)
            .toStringAsFixed(1),
      );

      final bool isRainyFront =
          frontDrop < -4.8 && (hour >= 14 && hour <= 19) && hBack > 3;
      final double rainMm = isRainyFront
          ? double.parse(
              (0.6 + ((daySeed + hour) % 5) * 0.55).toStringAsFixed(1),
            )
          : 0.0;

      final double rawHum =
          (anchorHum + 14.0 - (16.0 * diurnal) + (isRainyFront ? 22.0 : 0.0))
              .clamp(32.0, 96.0);
      final double humidityPct = double.parse(
        (rawHum * (1.0 - blendToLive) + anchorHum * blendToLive)
            .toStringAsFixed(0),
      );

      final double windBase =
          1.6 +
          (hour >= 10 && hour <= 17 ? 2.1 : 0.6) +
          (isRainyFront ? 3.2 : 0.0) +
          ((daySeed + hour) % 4) * 0.45;
      final double windSpeedMs = hBack == 0
          ? _weatherStation.windSpeed
          : double.parse(windBase.toStringAsFixed(1));
      final String windDir = hBack == 0
          ? _weatherStation.windDirection
          : dirs[(daySeed + (hour ~/ 4)) % dirs.length];

      double sunFactor = 0.0;
      if (hour >= 6 && hour <= 19) {
        sunFactor = math.max(
          0.0,
          math.sin(((hour - 6) / 13.0) * math.pi),
        );
        if (isRainyFront) sunFactor *= 0.25;
      }
      final double uvIndex = hBack == 0
          ? _weatherStation.uvIndex
          : double.parse((6.2 * sunFactor).toStringAsFixed(1));
      final double lightLux = hBack == 0
          ? _weatherStation.lightLux
          : double.parse((58000.0 * sunFactor).toStringAsFixed(0));

      generated.add(
        WeatherLogPoint(
          timestamp: dt,
          tempC: tempC,
          humidityPct: humidityPct,
          pressureHpa: pressureHpa,
          windSpeedMs: windSpeedMs,
          windDirection: windDir,
          rainMm: rainMm,
          uvIndex: uvIndex,
          lightLux: lightLux,
          batteryVoltage: hBack == 0
              ? _weatherStation.batteryVoltage
              : double.parse(
                  (3.98 + 0.16 * sunFactor).toStringAsFixed(2),
                ),
          isSimulated: true,
        ),
      );
    }
    return generated;
  }

  Future<Map<String, dynamic>?> _postToSupabase(
    String table,
    Map<String, dynamic> data,
  ) async {
    HistoryLogEntry? localHistoryEntry;
    if (table == 'history_logs') {
      localHistoryEntry = _recordLocalHistoryEntry(data);
    }

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      if (localHistoryEntry != null) notifyListeners();
      return null;
    }

    if (!_isOnline) {
      _offlineQueue.add({'method': 'POST', 'table': table, 'data': data});
      await _saveOfflineQueue();
      notifyListeners();
      return null;
    }

    try {
      final res = await _postWithSchemaFallback(table, data);
      _isOnline = true;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
          'Supabase POST elutasítva ($table, ${res.statusCode}): ${res.body}',
        );
        if (res.statusCode >= 500) {
          _offlineQueue.add({'method': 'POST', 'table': table, 'data': data});
          await _saveOfflineQueue();
        }
        if (localHistoryEntry != null) notifyListeners();
        return null;
      }
      Map<String, dynamic>? insertedRow;
      if (res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          insertedRow = Map<String, dynamic>.from(decoded.first as Map);
        } else if (decoded is Map) {
          insertedRow = Map<String, dynamic>.from(decoded);
        }
      }
      if (localHistoryEntry != null && insertedRow != null) {
        final int? newDbId = (insertedRow['id'] as num?)?.toInt();
        if (newDbId != null) localHistoryEntry.dbId = newDbId;
        if (insertedRow['created_at'] != null) {
          final dt = DateTime.tryParse(
            insertedRow['created_at'].toString(),
          )?.toLocal();
          if (dt != null) localHistoryEntry.createdAt = dt;
        }
        _saveHivesBoxesLocally();
        notifyListeners();
      }
      return insertedRow;
    } catch (e) {
      _isOnline = false;
      _offlineQueue.add({'method': 'POST', 'table': table, 'data': data});
      await _saveOfflineQueue();
      debugPrint('Supabase offline rögzítés ($table): $e');
      notifyListeners();
      return null;
    }
  }

  Future<void> _patchToSupabase(
    String table,
    String queryFilter,
    Map<String, dynamic> data,
  ) async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) return;

    if (!_isOnline) {
      _offlineQueue.add({
        'method': 'PATCH',
        'table': table,
        'queryFilter': queryFilter,
        'data': data,
      });
      await _saveOfflineQueue();
      notifyListeners();
      return;
    }

    try {
      final res = await _patchWithSchemaFallback(table, queryFilter, data);
      _isOnline = true;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
          'Supabase PATCH elutasítva ($table, ${res.statusCode}): ${res.body}',
        );
        if (res.statusCode >= 500) {
          _offlineQueue.add({
            'method': 'PATCH',
            'table': table,
            'queryFilter': queryFilter,
            'data': data,
          });
          await _saveOfflineQueue();
        }
      }
    } catch (e) {
      _isOnline = false;
      _offlineQueue.add({
        'method': 'PATCH',
        'table': table,
        'queryFilter': queryFilter,
        'data': data,
      });
      await _saveOfflineQueue();
      debugPrint('Supabase offline frissítés ($table): $e');
      notifyListeners();
    }
  }

  /// Ha a monitors táblában még nem szerepel dedikált status oszlop, a history_logs legutóbbi
  /// státuszmódosító bejegyzéséből is pontosan visszaállítjuk az elmentett kaptárstátuszt!
  String? _resolveStatusFromHistoryLogs(
    List<Map<String, dynamic>>? logsForMac,
  ) {
    if (logsForMac == null || logsForMac.isEmpty) return null;
    for (final log in logsForMac) {
      final String ev = (log['event_type'] ?? '').toString().toLowerCase();
      final String desc = (log['description'] ?? '').toString().toLowerCase();
      if (ev == 'hans_protokoll') return 'flashing_red';
      if (ev == 'visszaeses_erosites_utan') return 'orange';
      if (ev == 'felerosites' || ev == 'anyasitas') return 'green';
      if (ev == 'anyacsere_jeloles' || ev == 'anyacsere') return 'red';
      if (ev == 'felszamolas') return 'yellow';
      if (ev == 'statusz_valtozas') {
        if (desc.contains('flashing_red')) return 'flashing_red';
        if (desc.contains('green') ||
            desc.contains('zöld') ||
            desc.contains('zold')) {
          return 'green';
        }
        if (desc.contains('yellow') ||
            desc.contains('sárga') ||
            desc.contains('sarga')) {
          return 'yellow';
        }
        if (desc.contains('orange') || desc.contains('narancs')) {
          return 'orange';
        }
        if (desc.contains('purple') || desc.contains('lila')) {
          return 'purple';
        }
        if (desc.contains('red') || desc.contains('piros')) {
          return 'red';
        }
      }
    }
    return null;
  }

  Future<void> _deleteFromSupabase(String table, String queryFilter) async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) return;

    if (!_isOnline) {
      _offlineQueue.add({
        'method': 'DELETE',
        'table': table,
        'queryFilter': queryFilter,
        'data': {},
      });
      await _saveOfflineQueue();
      notifyListeners();
      return;
    }

    try {
      final res = await _httpClient
          .delete(
            Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Server status: ${res.statusCode}');
      }
      _isOnline = true;
    } catch (e) {
      _isOnline = false;
      _offlineQueue.add({
        'method': 'DELETE',
        'table': table,
        'queryFilter': queryFilter,
        'data': {},
      });
      await _saveOfflineQueue();
      debugPrint('Supabase offline törlés ($table): $e');
      notifyListeners();
    }
  }

  Future<void> syncWithSupabase() async {
    if (_isSyncing) return;
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      _syncStatusText = 'Hiba: Add meg a Supabase URL-t és a kulcsot!';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _syncStatusText = 'Szinkronizáció a Supabase adatbázissal...';
    notifyListeners();

    try {
      // Minden szinkron előtt töröljük az ideiglenes oszlop-kihagyási cache-t,
      // hogy ha a gazda lefuttatta az SQL migrációt, az új oszlopok azonnal élesedjenek!
      resetUnsupportedColumnsCache();

      // Először megpróbáljuk elküldeni az offline sorban gyűlt változtatásokat
      await _processOfflineQueue();

      // Párhuzamosan töltjük le az összes konfigurációs és történeti táblát a Supabase-ből!
      final Future<http.Response?> allBodiesFuture = _httpClient
          .get(
            Uri.parse(
              '$_supabaseUrl/rest/v1/bodies?select=*&order=position_index.asc',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6))
          .then<http.Response?>((r) => r, onError: (_) => null);

      final Future<http.Response?> queensFuture = _httpClient
          .get(
            Uri.parse('$_supabaseUrl/rest/v1/queens?select=*'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5))
          .then<http.Response?>((r) => r, onError: (_) => null);

      final Future<http.Response?> openTreatmentsFuture = _httpClient
          .get(
            Uri.parse(
              '$_supabaseUrl/rest/v1/treatments?select=*&is_completed=eq.false',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5))
          .then<http.Response?>((r) => r, onError: (_) => null);

      final Future<http.Response?> pumpsFuture = _httpClient
          .get(
            Uri.parse('$_supabaseUrl/rest/v1/syrup_pumps?select=*'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5))
          .then<http.Response?>((r) => r, onError: (_) => null);

      final Future<http.Response?> catalogsFuture = _httpClient
          .get(
            Uri.parse('$_supabaseUrl/rest/v1/catalogs?select=*'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5))
          .then<http.Response?>((r) => r, onError: (_) => null);

      final Future<http.Response?> recentHistoryFuture = _httpClient
          .get(
            Uri.parse(
              '$_supabaseUrl/rest/v1/history_logs?select=*&order=id.desc&limit=250',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5))
          .then<http.Response?>((r) => r, onError: (_) => null);

      final Future<http.Response?> recentMetersFuture = _httpClient
          .get(
            Uri.parse(
              '$_supabaseUrl/rest/v1/hive_meters?select=*&order=id.desc&limit=200',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5))
          .then<http.Response?>((r) => r, onError: (_) => null);

      final monitorsRes = await _httpClient
          .get(
            Uri.parse('$_supabaseUrl/rest/v1/monitors?select=*'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));

      if (monitorsRes.statusCode == 200) {
        _isOnline = true;
        _weatherStation.status = 'green';
        final List<dynamic> data = jsonDecode(monitorsRes.body);
        final Map<String, HiveData> existingHivesMap = {
          for (var h in _hives) h.id: h,
        };

        // 1. Méhanyák szinkronizálása (public.queens)
        final Map<String, QueenData> queensById = {
          for (final q in _queens) q.id: q,
        };
        try {
          final http.Response? queensRes = await queensFuture;
          if (queensRes != null && queensRes.statusCode == 200) {
            final List<dynamic> qList = jsonDecode(queensRes.body);
            for (final qRow in qList) {
              if (qRow is Map) {
                final q = QueenData.fromJson(Map<String, dynamic>.from(qRow));
                if (q.id.isNotEmpty) {
                  queensById[q.id] = q;
                  final idx = _queens.indexWhere((eq) => eq.id == q.id);
                  if (idx >= 0) {
                    _queens[idx] = q;
                  } else {
                    _queens.add(q);
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Kötegelt queens lekérés hiba: $e');
        }

        // 2. Nyitott kezelések / teendők szinkronizálása (public.treatments)
        try {
          final http.Response? trRes = await openTreatmentsFuture;
          if (trRes != null && trRes.statusCode == 200) {
            final List<dynamic> trList = jsonDecode(trRes.body);
            for (final tRow in trList) {
              if (tRow is Map) {
                final int? dbId = (tRow['id'] as num?)?.toInt();
                final String hMac = (tRow['monitor_mac'] ?? '').toString();
                final String title = (tRow['treatment_type'] ?? '').toString();
                if (hMac.isEmpty || title.isEmpty) continue;
                final bool exists = _scheduledTasks.any(
                  (et) =>
                      (dbId != null && et.dbId == dbId) ||
                      (et.hiveId == hMac && et.title == title && !et.isCompleted),
                );
                if (!exists) {
                  _scheduledTasks.add(
                    ScheduledTask(
                      dbId: dbId,
                      id: 'DB_TR_${dbId ?? title.hashCode}',
                      hiveId: hMac,
                      category: (tRow['category'] ?? 'kezeles').toString(),
                      title: title,
                      description: (tRow['notes'] ?? '').toString(),
                      scheduledDate:
                          DateTime.tryParse(
                            (tRow['scheduled_date'] ?? '').toString(),
                          ) ??
                          DateTime.now(),
                      isCompleted: tRow['is_completed'] == true,
                    ),
                  );
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Kötegelt treatments lekérés hiba: $e');
        }

        // 3. Szirupszivattyú, itató és időjárás-állomás szinkronizálása (public.syrup_pumps)
        try {
          final http.Response? pumpsRes = await pumpsFuture;
          if (pumpsRes != null && pumpsRes.statusCode == 200) {
            final List<dynamic> pList = jsonDecode(pumpsRes.body);
            for (final pRow in pList) {
              if (pRow is Map) {
                final String pId = (pRow['id'] ?? '').toString();
                final double? lat = (pRow['latitude'] as num?)?.toDouble();
                final double? lng = (pRow['longitude'] as num?)?.toDouble();
                if (pId == _syrupPump.id || pId == 'PUMP_MAIN') {
                  if (lat != null && lng != null) {
                    _syrupPump.location = LatLng(lat, lng);
                  }
                  if (pRow['tank_level_percent'] is num) {
                    _syrupPump.tankLevelPercent =
                        (pRow['tank_level_percent'] as num).toDouble();
                  }
                  if (pRow['total_pumped_liters'] is num) {
                    _syrupPump.totalPumpedLiters =
                        (pRow['total_pumped_liters'] as num).toDouble();
                  }
                  if (pRow['is_interlocked'] is bool) {
                    _syrupPump.isPumpInterlocked =
                        pRow['is_interlocked'] as bool;
                  }
                  if (pRow['emergency_reason'] != null) {
                    _syrupPump.emergencyStopReason = pRow['emergency_reason']
                        .toString();
                  }
                  if (pRow['status'] is String &&
                      (pRow['status'] as String).isNotEmpty) {
                    _syrupPump.status = pRow['status'] as String;
                  }
                } else if (pId == _weatherStation.id &&
                    lat != null &&
                    lng != null) {
                  _weatherStation.location = LatLng(lat, lng);
                } else if (pId == _waterer.id) {
                  if (lat != null && lng != null) {
                    _waterer.location = LatLng(lat, lng);
                  }
                  if (pRow['tank_level_percent'] is num) {
                    _waterer.waterLevel = (pRow['tank_level_percent'] as num)
                        .toDouble();
                  }
                  if (pRow['is_interlocked'] is bool) {
                    _waterer.isInterlocked = pRow['is_interlocked'] as bool;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Kötegelt syrup_pumps lekérés hiba: $e');
        }

        // 4. Irodai egyedi törzsadatok szinkronizálása (public.catalogs)
        try {
          final http.Response? catRes = await catalogsFuture;
          if (catRes != null && catRes.statusCode == 200) {
            final List<dynamic> cList = jsonDecode(catRes.body);
            for (final cRow in cList) {
              if (cRow is Map) {
                final String code = (cRow['code'] ?? '').toString();
                final String category = (cRow['category'] ?? '').toString();
                if (code.isNotEmpty && category.isNotEmpty) {
                  customCatalogItems.removeWhere(
                    (c) => c['code'] == code && c['category'] == category,
                  );
                  customCatalogItems.add(Map<String, dynamic>.from(cRow));
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Kötegelt catalogs lekérés hiba: $e');
        }

        final Map<String, List<dynamic>> bodiesByMac = {};
        try {
          final http.Response? allBodiesRes = await allBodiesFuture;
          if (allBodiesRes != null && allBodiesRes.statusCode == 200) {
            final List<dynamic> allBodies = jsonDecode(allBodiesRes.body);
            for (final bRow in allBodies) {
              final String bMac = (bRow['monitor_mac'] ?? '').toString();
              if (bMac.isNotEmpty) {
                bodiesByMac.putIfAbsent(bMac, () => []).add(bRow);
              }
            }
          }
        } catch (e) {
          debugPrint('Kötegelt bodies lekérés hiba: $e');
        }

        final Map<String, List<Map<String, dynamic>>> historyByMac = {};
        try {
          http.Response? histRes = await recentHistoryFuture;
          if (histRes != null && histRes.statusCode == 400) {
            histRes = await _httpClient
                .get(
                  Uri.parse(
                    '$_supabaseUrl/rest/v1/history_logs?select=*&order=created_at.desc&limit=150',
                  ),
                  headers: _headers,
                )
                .timeout(const Duration(seconds: 4));
          }
          if (histRes != null && histRes.statusCode == 200) {
            final List<dynamic> histList = jsonDecode(histRes.body);
            _mergeRemoteHistoryLogs(histList);
            for (final hRow in histList) {
              if (hRow is Map) {
                final String hMac = (hRow['monitor_mac'] ?? '').toString();
                if (hMac.isNotEmpty) {
                  historyByMac
                      .putIfAbsent(hMac, () => [])
                      .add(Map<String, dynamic>.from(hRow));
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Kötegelt history_logs lekérés hiba: $e');
        }

        final Map<String, Map<String, dynamic>> latestMeterByMac = {};
        try {
          http.Response? metersRes = await recentMetersFuture;
          if (metersRes != null && metersRes.statusCode == 400) {
            metersRes = await _httpClient
                .get(
                  Uri.parse(
                    '$_supabaseUrl/rest/v1/hive_meters?select=*&order=created_at.desc&limit=200',
                  ),
                  headers: _headers,
                )
                .timeout(const Duration(seconds: 4))
                .then<http.Response?>((r) => r, onError: (_) => null);
          }
          if (metersRes != null && metersRes.statusCode == 200) {
            final List<dynamic> meterList = jsonDecode(metersRes.body);
            _mergeRemoteHiveMeters(
              meterList,
              latestMeterByMacOut: latestMeterByMac,
            );
          }
        } catch (e) {
          debugPrint('Kötegelt hive_meters lekérés hiba: $e');
        }

        final List<HiveData> syncedHives = [];

        int index = 0;
        for (var row in data) {
          final String mac = row['mac_address'] ?? 'HIVE_01';
          final String name = row['hive_number'] ?? 'Család ($mac)';
          final double swarmIdx =
              (row['swarm_index'] as num?)?.toDouble() ?? 0.0;
          final String feedingMode = row['feeding_mode'] ?? 'off';
          final double feedingMaxLiters =
              (row['feeding_max_liters'] as num?)?.toDouble() ?? 1.0;
          final int feedingIntervalHours =
              (row['feeding_interval_hours'] as num?)?.toInt() ?? 6;
          final int feedingIntervalDays =
              (row['feeding_interval_days'] as num?)?.toInt() ?? 1;
          final int feedingStopSunsetMin =
              (row['feeding_stop_sunset_min'] as num?)?.toInt() ?? 90;
          final double feedingPortionLiters =
              (row['feeding_portion_liters'] as num?)?.toDouble() ?? 0.2;
          final double feederLevelPercent =
              (row['feeder_level_percent'] as num?)?.toDouble() ?? 45.0;
          final int feederCalibEmptyMm =
              (row['feeder_calib_empty_mm'] as num?)?.toInt() ?? 200;
          final int feederCalibFullMm =
              (row['feeder_calib_full_mm'] as num?)?.toInt() ?? 30;
          final int feederRawDistanceMm =
              (row['feeder_raw_distance_mm'] as num?)?.toInt() ?? 120;

          List<BoxElement> loadedBoxes = [];
          if (existingHivesMap.containsKey(mac) &&
              existingHivesMap[mac]!.boxes.isNotEmpty) {
            loadedBoxes = List<BoxElement>.from(existingHivesMap[mac]!.boxes);
          } else {
            loadedBoxes = [
              BoxElement(
                name: 'Aljdeszka',
                code: '${mac}_BOT',
                type: 'bottom',
                size: 'bottom',
                isActive: false,
              ),
              BoxElement(
                name: 'Fészekfiók',
                code: '${mac}_BROOD',
                type: 'brood_box',
                size: 'hunor',
                status: 'green',
              ),
            ];
          }

          final List<dynamic>? bodiesData = bodiesByMac[mac];
          if (bodiesData != null && bodiesData.isNotEmpty) {
            loadedBoxes.clear();
            for (var bRow in bodiesData) {
              String rawFunc =
                  (bRow['body_function'] ?? bRow['function'] ?? 'honey')
                      .toString()
                      .trim();
              final String f = rawFunc.toLowerCase();
              String bFunc = rawFunc;
              String bName = 'Kaptárelem';

              if (f == 'bottom' ||
                  f == 'alj' ||
                  f == 'aljdeszka' ||
                  f == '15' ||
                  f.contains('alj')) {
                bFunc = 'bottom';
                bName = 'Aljdeszka';
              } else if (f == 'pollen_trap' ||
                  f == 'pollen' ||
                  f == 'viragpor' ||
                  f == 'virágpor' ||
                  f == '11' ||
                  f.contains('pollen') ||
                  f.contains('virágpor') ||
                  f.contains('viragpor')) {
                bFunc = 'pollen_trap';
                bName = 'Pollengyűjtő';
              } else if (f == 'feeder' ||
                  f == 'roof_feeder' ||
                  f == 'tetoeteto' ||
                  f.contains('etet') ||
                  f == '10') {
                bFunc = 'feeder';
                bName = 'Tetőetető';
              } else if (f == 'escapement' ||
                  f == 'szokteto' ||
                  f == 'szöktető' ||
                  f.contains('szöktet') ||
                  f.contains('szoktet') ||
                  f == '13') {
                bFunc = 'escapement';
                bName = 'Szöktető';
              } else if (f == 'vent' ||
                  f == 'szellozo' ||
                  f == 'szellőző' ||
                  f.contains('szellőz') ||
                  f.contains('szelloz') ||
                  f == '12') {
                bFunc = 'vent';
                bName = 'Szellőző';
              } else if (f == 'roof' ||
                  f == 'teto' ||
                  f == 'tető' ||
                  f == 'dekli' ||
                  f.contains('dekli') ||
                  f.contains('fedő')) {
                bFunc = 'roof';
                bName = 'Tető';
              } else if (f == 'treatment_strip' || f.contains('kezel')) {
                bFunc = 'treatment_strip';
                bName = 'Kezelőlap hordozó';
              } else if (f == 'queen_excluder' ||
                  f.contains('anyarács') ||
                  f.contains('anyaracs') ||
                  f.contains('excluder')) {
                bFunc = 'queen_excluder';
                bName = 'Anyarács';
              } else if (f == 'brood_box' ||
                  f == 'broodbox' ||
                  f == 'nest' ||
                  f == '8' ||
                  f.contains('fészek') ||
                  f.contains('feszek')) {
                bFunc = 'brood_box';
                bName = 'Fészekfiók';
              } else if (f == 'comb_builder' ||
                  f.contains('lépépít') ||
                  f.contains('lepepit')) {
                bFunc = 'comb_builder';
                bName = 'Lépépítő';
              } else if (f == 'demaree' ||
                  f.contains('szaporít') ||
                  f.contains('szaporit')) {
                bFunc = 'demaree';
                bName = 'Szaporító (Demaree)';
              } else if (f == 'honey' ||
                  f == 'mez' ||
                  f == 'mezter' ||
                  f == 'méztér' ||
                  f == '9' ||
                  f.contains('méz') ||
                  f.contains('mez') ||
                  f.contains('honey')) {
                bFunc = 'honey';
                bName = 'Méztér';
              } else {
                bFunc = rawFunc;
                bName =
                    (bRow['name'] != null &&
                        bRow['name'].toString().trim().isNotEmpty &&
                        bRow['name'].toString().toLowerCase() != 'elem')
                    ? bRow['name'].toString()
                    : (rawFunc.isNotEmpty && rawFunc != 'elem'
                          ? rawFunc
                          : 'Kiegészítő elem');
              }

              final int? bodyDbId = (bRow['id'] as num?)?.toInt();
              final String rawBodyType =
                  (bRow['body_type'] ?? bRow['size'] ?? '').toString().trim();
              final String rawRowName = (bRow['name'] ?? '').toString().trim();
              String bType = rawBodyType;
              if (bType.isEmpty && existingHivesMap.containsKey(mac)) {
                for (final prevBox in existingHivesMap[mac]!.boxes) {
                  if (bodyDbId != null &&
                      prevBox.dbId == bodyDbId &&
                      prevBox.size.trim().isNotEmpty) {
                    bType = prevBox.size.trim();
                    break;
                  }
                }
              }
              if (bType.isEmpty) {
                bType = rawFunc == '9' ? 'fel_dadant' : 'dadant';
              } else if (rawFunc == '9' && bType.toLowerCase() == 'dadant') {
                bType = 'fel_dadant';
              }
              if (!isHalfBoxSize(bType) &&
                  isHalfBoxSize('', name: rawRowName, type: rawFunc)) {
                final lowerSys = bType.toLowerCase();
                if (lowerSys.contains('nb')) {
                  bType = 'fel_nb';
                } else if (lowerSys.contains('lang')) {
                  bType = 'fel_langstroth';
                } else {
                  bType = 'fel_dadant';
                }
              }
              final bool isActive =
                  bRow['is_active'] ?? (bFunc == 'escapement');
              final int? posIndex = (bRow['position_index'] as num?)?.toInt();

              final DateTime? dbUpdatedAt = bRow['updated_at'] != null
                  ? DateTime.tryParse(bRow['updated_at'].toString())?.toUtc()
                  : null;

              // Leszöktetés (24h) és aktív aljdeszka (3 napos kontroll) kezdési idejének feloldása az adatbázisból:
              // 1. status_updated_at (dedikált oszlop), 2. started_at, 3. created_at / updated_at, 4. helyi mentett érték
              DateTime? resolvedStatusUpdatedAt;
              final dynamic rawStatusTs =
                  bRow['status_updated_at'] ??
                  bRow['started_at'] ??
                  (bFunc == 'escapement'
                      ? (bRow['created_at'] ?? bRow['updated_at'])
                      : (isActive &&
                                (bFunc == 'bottom' || bFunc == 'pollen_trap')
                            ? (bRow['updated_at'] ?? bRow['created_at'])
                            : null));
              if (rawStatusTs != null &&
                  rawStatusTs.toString().trim().isNotEmpty) {
                resolvedStatusUpdatedAt = DateTime.tryParse(
                  rawStatusTs.toString(),
                )?.toLocal();
              }
              if (resolvedStatusUpdatedAt == null &&
                  existingHivesMap.containsKey(mac)) {
                for (final prevBox in existingHivesMap[mac]!.boxes) {
                  if ((bodyDbId != null && prevBox.dbId == bodyDbId) ||
                      prevBox.type == bFunc) {
                    if (prevBox.statusUpdatedAt != null &&
                        (bFunc == 'escapement' || isActive)) {
                      resolvedStatusUpdatedAt = prevBox.statusUpdatedAt;
                    }
                    break;
                  }
                }
              }

              final String resolvedBoxCode =
                  (bRow['code'] != null &&
                      bRow['code'].toString().trim().isNotEmpty)
                  ? bRow['code'].toString().trim()
                  : '${mac}_${bFunc.toUpperCase()}';
              final String? resolvedSecondaryCode =
                  (bRow['secondary_code'] != null &&
                      bRow['secondary_code'].toString().trim().isNotEmpty)
                  ? bRow['secondary_code'].toString().trim()
                  : null;
              final String resolvedBoxStatus =
                  (bRow['status'] != null &&
                      bRow['status'].toString().trim().isNotEmpty)
                  ? bRow['status'].toString().trim()
                  : 'green';
              final bool resolvedBoxQuarantined =
                  (bRow['is_quarantined'] as bool?) ??
                  (resolvedBoxStatus == 'flashing_red' ||
                      resolvedBoxStatus == 'quarantine');

              loadedBoxes.add(
                BoxElement(
                  dbId: bodyDbId,
                  name: bName,
                  code: resolvedBoxCode,
                  secondaryCode: resolvedSecondaryCode,
                  type: bFunc,
                  size: bType,
                  isActive: isActive,
                  isQuarantined: resolvedBoxQuarantined,
                  status: resolvedBoxStatus,
                  positionIndex: posIndex,
                  statusUpdatedAt: resolvedStatusUpdatedAt,
                  updatedAt: dbUpdatedAt,
                ),
              );
            }
          }

          final prevHive = existingHivesMap[mac];
          final String? dbFamilyFunction =
              (row['family_function'] ??
                      row['familyFunction'] ??
                      row['function'])
                  ?.toString()
                  .trim();
          final String familyFunction =
              (dbFamilyFunction != null && dbFamilyFunction.isNotEmpty)
              ? dbFamilyFunction
              : (prevHive?.familyFunction ??
                    (name.toLowerCase().contains('méz') || mac.endsWith('01')
                        ? 'méz'
                        : 'gyujto_mez'));

          // Alapvető elemek (aljdeszka és tető) ellenőrzése
          if (!loadedBoxes.any((b) => isBottomBox(b))) {
            loadedBoxes.insert(
              0,
              BoxElement(
                name: 'Aljdeszka',
                code: '${mac}_BOT',
                type: 'bottom',
                size: 'bottom',
                isActive: false,
              ),
            );
          }
          if (!loadedBoxes.any((b) => isRoofBox(b))) {
            loadedBoxes.add(
              BoxElement(
                name: 'Tető',
                code: '${mac}_ROOF',
                type: 'roof',
                size: 'dadant',
                isActive: false,
              ),
            );
          }

          final bool originallyMissingBrood = !loadedBoxes.any(
            (b) => b.type == 'brood_box' || b.type == 'nest',
          );

          sortHiveBoxes(loadedBoxes);

          // Konzekvens üzem: Ha a sziruptartály (ABC tartály) nem üres és nem hibás,
          // akkor a kaptár automatikusan össze van vele lőve, és az etető üzemképes (nincs üres tartály miatti letiltás)!
          final bool hasFeederOnHive = loadedBoxes.any(
            (b) =>
                b.type == 'feeder' ||
                b.type == 'roof_feeder' ||
                b.name.toLowerCase().contains('etet'),
          );
          final bool isTankHealthy =
              !_syrupPump.isPumpInterlocked &&
              _syrupPump.status != 'blinking_red' &&
              _syrupPump.tankLevelPercent > 10.0;

          double effectiveFeederLevel = feederLevelPercent;
          String effectiveFeedingMode = feedingMode;
          String? pairedTank = hasFeederOnHive ? _syrupPump.name : null;
          bool isAutoPaired = hasFeederOnHive && isTankHealthy;

          if (hasFeederOnHive && isTankHealthy) {
            // Ha van szirup a tartályban, az etető szintje legalább üzemszerű vagy automatán töltődik
            if (effectiveFeederLevel <= 5.0) {
              effectiveFeederLevel = 60.0;
            }
            if (effectiveFeedingMode == 'off' || effectiveFeedingMode.isEmpty) {
              effectiveFeedingMode = 'auto_stim';
            }
            if (!_syrupPump.pairedHiveNames.contains(name)) {
              _syrupPump.pairedHiveNames.add(name);
            }
          }

          final String? dbStatus = row['status']?.toString().trim();
          final String? historyStatus = _resolveStatusFromHistoryLogs(
            historyByMac[mac],
          );
          final bool hasPendingOfflineStatusPatch = _offlineQueue.any(
            (q) =>
                q['table'] == 'monitors' &&
                q['queryFilter']?.toString().contains(mac) == true,
          );
          final String fallbackStatus = swarmIdx >= 70.0
              ? 'purple'
              : (originallyMissingBrood ? 'yellow' : 'green');
          String resolvedStatus;
          if (hasPendingOfflineStatusPatch && prevHive != null) {
            resolvedStatus = prevHive.status;
          } else if (dbStatus != null && dbStatus.isNotEmpty) {
            resolvedStatus = dbStatus;
          } else if (historyStatus != null && historyStatus.isNotEmpty) {
            resolvedStatus = historyStatus;
          } else if (prevHive != null &&
              _locallyPersistedHiveIds.contains(mac)) {
            resolvedStatus = prevHive.status;
          } else {
            resolvedStatus = fallbackStatus;
          }

          final DateTime? dbLastStrengthenedAt =
              row['last_strengthened_at'] != null
              ? DateTime.tryParse(row['last_strengthened_at'].toString())
                    ?.toLocal()
              : prevHive?.lastStrengthenedAt;
          final int dbStrengtheningCount =
              (row['strengthening_count'] as num?)?.toInt() ??
              prevHive?.strengtheningCount ??
              0;
          final bool dbHasRelapsed =
              (row['has_relapsed'] as bool?) ??
              prevHive?.hasRelapsedAfterStrengthening ??
              false;
          final String? dbRelapseReason =
              row['relapse_reason']?.toString() ?? prevHive?.relapseReason;

          final String? protocol =
              row['protocol']?.toString() ?? prevHive?.protocol;
          final bool isHansHive =
              protocol?.toLowerCase() == 'hans' ||
              familyFunction.toLowerCase() == 'hans' ||
              resolvedStatus == 'flashing_red' ||
              (prevHive?.isQuarantined ?? false) ||
              (prevHive?.reportedDiseases.contains('nyulos') ?? false);

          if (isHansHive) {
            resolvedStatus = 'flashing_red';
            effectiveFeedingMode = 'off';
            isAutoPaired = false;
            pairedTank = null;
            _syrupPump.pairedHiveNames.remove(name);
            for (final b in loadedBoxes) {
              b.status = 'flashing_red';
              b.isQuarantined = true;
              if (b.type == 'pollen_trap' || b.type == 'bottom') {
                b.isActive = false;
              }
            }
          }
          final double dailyVarroa =
              (row['daily_varroa_drop'] as num?)?.toDouble() ??
              prevHive?.dailyVarroaDrop ??
              0.0;
          final double syrupLiters =
              (row['syrup_liters'] as num?)?.toDouble() ??
              prevHive?.syrupLiters ??
              0.0;
          final latestMeter = latestMeterByMac[mac];
          final double temp =
              (latestMeter?['inner_temp'] as num?)?.toDouble() ??
              (row['temp'] as num?)?.toDouble() ??
              (row['temperature'] as num?)?.toDouble() ??
              prevHive?.temp ??
              34.5;
          final double resolvedHumidity =
              (latestMeter?['humidity'] as num?)?.toDouble() ??
              (row['humidity'] as num?)?.toDouble() ??
              prevHive?.humidity ??
              60.0;
          final double resolvedZcr =
              (latestMeter?['noise'] as num?)?.toDouble() ??
              (row['zcr'] as num?)?.toDouble() ??
              prevHive?.zcr ??
              3800.0;
          final double weight =
              (latestMeter?['weight'] as num?)?.toDouble() ??
              (row['weight'] as num?)?.toDouble() ??
              prevHive?.weight ??
              35.0;
          final String notes = (row['notes'] ?? row['comment'] ?? '')
              .toString();

          double latOffset = (index % 3) * 0.00015;
          double lngOffset = (index ~/ 3) * 0.00015;
          final double? dbLat = (row['latitude'] as num?)?.toDouble();
          final double? dbLng = (row['longitude'] as num?)?.toDouble();
          final LatLng resolvedLocation = (dbLat != null && dbLng != null)
              ? LatLng(dbLat, dbLng)
              : (prevHive?.location ??
                    LatLng(37.422500 + latOffset, -122.084500 + lngOffset));

          final double resolvedEntranceHeading =
              (row['entrance_heading'] as num?)?.toDouble() ??
              prevHive?.entranceHeading ??
              180.0;

          EvaluationData mergedEvaluation;
          final dynamic rawEval = row['evaluation'];
          if (rawEval is Map && rawEval.isNotEmpty) {
            mergedEvaluation = EvaluationData.fromJson(
              Map<String, dynamic>.from(rawEval),
            );
          } else if (rawEval is String && rawEval.trim().startsWith('{')) {
            try {
              mergedEvaluation = EvaluationData.fromJson(
                Map<String, dynamic>.from(jsonDecode(rawEval) as Map),
              );
            } catch (_) {
              mergedEvaluation =
                  prevHive?.evaluation ?? EvaluationData(notes: notes);
            }
          } else {
            mergedEvaluation =
                prevHive?.evaluation ?? EvaluationData(notes: notes);
          }
          if (mergedEvaluation.notes.trim().isEmpty &&
              notes.trim().isNotEmpty) {
            mergedEvaluation.notes = notes;
          }

          List<String> resolvedDiseases = [];
          final dynamic rawDiseases = row['reported_diseases'];
          if (rawDiseases is List) {
            resolvedDiseases = rawDiseases.map((e) => e.toString()).toList();
          } else if (rawDiseases is String &&
              rawDiseases.trim().startsWith('[')) {
            try {
              resolvedDiseases = (jsonDecode(rawDiseases) as List)
                  .map((e) => e.toString())
                  .toList();
            } catch (_) {
              resolvedDiseases = List<String>.from(
                prevHive?.reportedDiseases ?? const [],
              );
            }
          } else if (prevHive != null) {
            resolvedDiseases = List<String>.from(prevHive.reportedDiseases);
          }
          if (isHansHive && !resolvedDiseases.contains('nyulos')) {
            resolvedDiseases.add('nyulos');
          }

          final String? dbQueenId = row['queen_id']?.toString().trim();
          final QueenData? resolvedQueen =
              (dbQueenId != null && dbQueenId.isNotEmpty)
              ? (queensById[dbQueenId] ??
                    prevHive?.queen ??
                    QueenData(
                      id: dbQueenId,
                      origin: 'Regisztrált anya',
                      vintage: '${DateTime.now().year}',
                    ))
              : prevHive?.queen;

          final String? resolvedQueenRepState =
              row['queen_replacement_state']?.toString() ??
              prevHive?.queenReplacementState;
          final DateTime? resolvedQueenIntroAt =
              row['queen_introduced_at'] != null
              ? DateTime.tryParse(
                  row['queen_introduced_at'].toString(),
                )?.toLocal()
              : prevHive?.queenIntroducedAt;
          final DateTime? resolvedLockedUntil = row['locked_until'] != null
              ? DateTime.tryParse(row['locked_until'].toString())?.toLocal()
              : prevHive?.lockedUntil;
          final String? resolvedLockReason =
              row['lock_reason']?.toString() ?? prevHive?.lockReason;
          final bool resolvedAcousticSentinel =
              (row['acoustic_sentinel_active'] as bool?) ??
              prevHive?.isAcousticSentinelActive ??
              false;
          final int resolvedAcousticInterval =
              (row['acoustic_sample_interval_min'] as num?)?.toInt() ??
              prevHive?.acousticSampleIntervalMinutes ??
              60;
          final double? resolvedWeightAtStrengthening =
              (row['weight_at_strengthening'] as num?)?.toDouble() ??
              prevHive?.weightAtStrengthening;

          syncedHives.add(
            HiveData(
              id: mac,
              name: name,
              location: resolvedLocation,
              status: resolvedStatus,
              entranceHeading: resolvedEntranceHeading,
              familyFunction: familyFunction,
              protocol: protocol,
              dailyVarroaDrop: dailyVarroa,
              syrupLiters: syrupLiters,
              temp: temp,
              humidity: resolvedHumidity,
              extTemp: _weatherStation.temp,
              extHumidity: _weatherStation.humidity,
              weight: weight,
              batteryVoltage: 4.1,
              zcr: resolvedZcr,
              swarmIndex: swarmIdx,
              feedingMode: effectiveFeedingMode,
              feedingMaxLiters: feedingMaxLiters,
              feedingIntervalHours: feedingIntervalHours,
              feedingIntervalDays: feedingIntervalDays,
              feedingStopBeforeSunsetMinutes: feedingStopSunsetMin,
              feedingPortionLiters: feedingPortionLiters,
              feederLevelPercent: effectiveFeederLevel,
              feederCalibEmptyMm: feederCalibEmptyMm,
              feederCalibFullMm: feederCalibFullMm,
              feederRawDistanceMm: feederRawDistanceMm,
              pairedTankId: (row['paired_tank_id']?.toString()) ?? pairedTank,
              isAutoPaired: (row['is_auto_paired'] as bool?) ?? isAutoPaired,
              boxes: loadedBoxes,
              serverConnection: 'Supabase OK',
              queen: resolvedQueen,
              queenReplacementState: resolvedQueenRepState,
              queenIntroducedAt: resolvedQueenIntroAt,
              lockedUntil: resolvedLockedUntil,
              lockReason: resolvedLockReason,
              isAcousticSentinelActive: resolvedAcousticSentinel,
              acousticSampleIntervalMinutes: resolvedAcousticInterval,
              lastStrengthenedAt: dbLastStrengthenedAt,
              strengtheningCount: dbStrengtheningCount,
              weightAtStrengthening: resolvedWeightAtStrengthening,
              hasRelapsedAfterStrengthening: dbHasRelapsed,
              relapseReason: dbRelapseReason,
              reportedDiseases: resolvedDiseases,
              evaluation: mergedEvaluation,
            ),
          );
          index++;
        }
        _hives
          ..clear()
          ..addAll(syncedHives);
        evaluateColonyRelapses(notify: false);
      } else {
        _isOnline = false;
        _weatherStation.status = 'red';
      }

      _syncStatusText = _isOnline
          ? 'Sikeres Supabase szinkron! (${_hives.length} kaptár betöltve)'
          : 'Offline mód: Helyi adatok használatban (${_offlineQueue.length} várakozó művelet)';
      await _saveHivesBoxesLocally(immediate: true);
    } catch (e) {
      _isOnline = false;
      _weatherStation.status = 'red';
      _syncStatusText =
          'Offline mód (Nincs net): ${_offlineQueue.length} elem vár szinkronra.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Kaptártornyok szabványosítása az adatbázisban és a helyi memóriában a felhasználói előírás alapján:
  /// - Mindegyik alul: Aljdeszka + Pollengyűjtő (dadant) + Fészekfiók (dadant)
  /// - Mézgyűjtő család: 4 db 1/2 dadant méztér + Tető
  /// - A többi család: Tetőetető (dadant) + Tető
  Future<void> standardizeAllTowersInDatabase({bool forceDbSync = true}) async {
    for (var hive in _hives) {
      final bool isHoneyColony =
          hive.familyFunction == 'méz' ||
          hive.familyFunction == 'gyujto_mez' ||
          hive.familyFunction == 'méztermelő' ||
          hive.name.toLowerCase().contains('méz') ||
          hive.id.endsWith('01');

      hive.boxes = createStandardBoxes(hive.id, isHoneyProducer: isHoneyColony);

      if (forceDbSync &&
          _supabaseUrl.isNotEmpty &&
          _supabaseAnonKey.isNotEmpty) {
        _deleteFromSupabase('bodies', 'monitor_mac=eq.${hive.id}');
        for (int bi = 0; bi < hive.boxes.length; bi++) {
          final box = hive.boxes[bi];
          _postToSupabase(
            'bodies',
            _buildBodyPayload(hive.id, box, bi + 1),
          ).then((inserted) {
            final int? newId = (inserted?['id'] as num?)?.toInt();
            if (newId != null && box.dbId == null) {
              box.dbId = newId;
              _saveHivesBoxesLocally();
            }
          });
        }
        logHistoryEvent(
          hive.id,
          'torony_szabvanyositas',
          'Kaptártorony szabványosítva (${hive.boxes.length} elem).',
        );
      }
    }
    await _saveHivesBoxesLocally(immediate: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    if (_localSaveDebounceTimer?.isActive == true) {
      _localSaveDebounceTimer?.cancel();
      _localSaveDebounceTimer = null;
      _flushHivesBoxesLocallyNow();
    }
    _httpClient.close();
    super.dispose();
  }
}
