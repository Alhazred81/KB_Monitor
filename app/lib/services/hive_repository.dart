import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

import '../hive_model.dart';
import 'treatment_adviser.dart';

class HiveRepository extends ChangeNotifier {
  static final HiveRepository instance = HiveRepository._internal();
  HiveRepository._internal() {
    _loadConfig();
  }

  // --- SUPABASE KONFIGURÁCIÓ ---
  String _supabaseUrl = '';
  String _supabaseAnonKey = '';
  bool _isSyncing = false;
  String _syncStatusText = 'Még nincs beállítva a Supabase kapcsolat';

  String get supabaseUrl => _supabaseUrl;
  String get supabaseAnonKey => _supabaseAnonKey;
  bool get isSyncing => _isSyncing;
  String get syncStatusText => _syncStatusText;

  String get sheetUrl => _supabaseUrl;

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _supabaseUrl = prefs.getString('supabase_url') ?? '';
    _supabaseAnonKey = prefs.getString('supabase_anon_key') ?? '';
    if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
      _syncStatusText = 'Supabase konfigurálva. Szinkronizációra kész.';
    }
    notifyListeners();
  }

  Future<void> setSupabaseConfig(String url, String anonKey) async {
    _supabaseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    _supabaseAnonKey = anonKey.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supabase_url', _supabaseUrl);
    await prefs.setString('supabase_anon_key', _supabaseAnonKey);
    notifyListeners();
  }

  // --- LOKÁLIS ADATOK ÉS GYORSÍTÓTÁR ---
  final List<QueenData> _queens = [];
  final List<HiveData> _hives = [];
  final List<FrameAnalysisRecord> _pendingFrameAnalyses = [];
  final List<ScheduledTask> _scheduledTasks = [];

  StationData _weatherStation = StationData(
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
    name: 'szirupszivattyú',
    location: const LatLng(37.422200, -122.083800),
    totalPumpedLiters: 0.0,
    lastOperationStatus: 'Készenlétben',
    status: 'green',
  );

  List<HiveData> get hives => _hives;
  List<QueenData> get queens => _queens;
  List<FrameAnalysisRecord> get pendingFrameAnalyses => _pendingFrameAnalyses;
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

  void addQueen(QueenData queen) {
    _queens.add(queen);
    _postToSupabase('queens', {
      'queen_number': queen.id,
      'origin': queen.origin,
      'birth_year':
          int.tryParse(queen.vintage.replaceAll(RegExp(r'[^0-9]'), '')) ??
          DateTime.now().year,
      'status': queen.isAlive ? 'Aktív' : 'Elveszett',
    });
    notifyListeners();
  }

  void addHive(HiveData hive) {
    if (!hive.boxes.any((b) => b.type == 'bottom')) {
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
    _hives.add(hive);
    _postToSupabase('monitors', {
      'mac_address': hive.id,
      'hive_number': hive.name,
    });
    notifyListeners();
  }

  void addBoxToHive(HiveData hive, BoxElement box) {
    hive.boxes.add(box);
    _postToSupabase('bodies', {
      'monitor_mac': hive.id,
      'body_type': box.size,
      'body_function': box.type,
      'position_index': hive.boxes.length,
      'is_active': box.isActive,
    });
    notifyListeners();
  }

  void toggleBoxActiveState(HiveData hive, BoxElement box, bool newValue) {
    box.isActive = newValue;
    box.statusUpdatedAt = DateTime.now();

    final String eventDesc = box.type == 'bottom'
        ? (newValue
              ? 'Aljdeszka betolva (3 napos varroa kontroll indítva)'
              : 'Aljdeszka kihúzva')
        : (newValue ? 'Pollengyűjtő bekapcsolva' : 'Pollengyűjtő kikapcsolva');

    _postToSupabase('history_logs', {
      'monitor_mac': hive.id,
      'event_type': box.type == 'bottom' ? 'atkaellenőrzés' : 'pollengyűjtő',
      'description': eventDesc,
    });

    notifyListeners();
  }

  void updateHive(HiveData hive) {
    notifyListeners();
  }

  void pumpSyrup(SyrupPumpData pump, double liters, String targetHiveName) {
    pump.totalPumpedLiters += liters;
    pump.lastOperationStatus =
        'Cél: $targetHiveName - ${liters.toStringAsFixed(1)}L (OK)';

    for (var hive in _hives) {
      if (hive.name == targetHiveName) {
        hive.syrupLiters += liters;
        _postToSupabase('treatments', {
          'monitor_mac': hive.id,
          'treatment_type': 'Szirup etetés',
          'scheduled_date': DateTime.now().toIso8601String().split('T').first,
          'is_completed': true,
          'dosage': '${liters.toStringAsFixed(1)} liter',
          'notes':
              'Összesen kapott szirup: ${hive.syrupLiters.toStringAsFixed(1)} L',
        });
        _postToSupabase('history_logs', {
          'monitor_mac': hive.id,
          'event_type': 'etetés',
          'description':
              'Adagolva: ${liters.toStringAsFixed(1)} L szirup (Összesen: ${hive.syrupLiters.toStringAsFixed(1)} L)',
        });
        break;
      }
    }
    notifyListeners();
  }

  void schedulePlanForHive(String hiveId, String planType, DateTime startDate) {
    List<ScheduledTask> newTasks = [];
    if (planType == 'petes_mesterterv') {
      newTasks = TreatmentAdviser.generatePetesMasterPlan(hiveId, startDate);
    } else if (planType == 'alcas_mesterterv') {
      newTasks = TreatmentAdviser.generateAlcasMasterPlan(hiveId, startDate);
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
    }

    _scheduledTasks.addAll(newTasks);

    for (var t in newTasks) {
      _postToSupabase('treatments', {
        'monitor_mac': hiveId,
        'treatment_type': t.title,
        'scheduled_date': t.scheduledDate.toIso8601String().split('T').first,
        'is_completed': false,
        'notes': t.description,
      });
    }
    notifyListeners();
  }

  void addLocalFrameAnalysis(FrameAnalysisRecord record) {
    _pendingFrameAnalyses.add(record);
    notifyListeners();
  }

  Future<int> syncPendingFramesAndCleanup() async {
    int processedCount = 0;
    final unsynced = _pendingFrameAnalyses
        .where((r) => !r.isSyncedWithCloud)
        .toList();

    for (var record in unsynced) {
      try {
        await _postToSupabase('history_logs', {
          'monitor_mac': record.hiveId,
          'event_type': 'keret_ai_elemzes',
          'description':
              'Népesség: ${record.populationEstimate}, Fedett fiasítás: ${record.cappedBroodPct}%, Nyílt: ${record.openBroodPct}%',
          'metadata': {
            'population': record.populationEstimate,
            'capped_brood_pct': record.cappedBroodPct,
            'open_brood_pct': record.openBroodPct,
            'queen_cells': record.queenCellsDetected,
            'health_note': record.broodHealthNote,
          },
        });

        record.isSyncedWithCloud = true;
        record.cloudDetailedReport = 'Felhős elemzés kész, adatbázisba mentve.';

        final file = File(record.localImagePath);
        if (await file.exists()) {
          await file.delete();
        }
        processedCount++;
      } catch (e) {
        debugPrint('Hiba a keret szinkronizálásakor: $e');
      }
    }

    _pendingFrameAnalyses.removeWhere((r) => r.isSyncedWithCloud);
    notifyListeners();
    return processedCount;
  }

  Future<void> _postToSupabase(String table, Map<String, dynamic> data) async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      return;
    }
    try {
      await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/$table'),
        headers: _headers,
        body: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('Supabase írási hiba ($table): $e');
    }
  }

  Future<void> syncWithSupabase() async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      _syncStatusText = 'Hiba: Add meg a Supabase URL-t és a kulcsot!';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _syncStatusText = 'Szinkronizáció a Supabase adatbázissal...';
    notifyListeners();

    try {
      // 1. Összes kaptár / monitor lekérése
      final monitorsRes = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/monitors?select=*'),
        headers: _headers,
      );

      if (monitorsRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(monitorsRes.body);
        _hives.clear();

        int index = 0;
        for (var row in data) {
          final String mac = row['mac_address'] ?? 'HIVE_01';
          final String name = row['hive_number'] ?? 'Család ($mac)';

          // Eltolás a GPS koordinátákban, hogy ne egymáson legyenek a markerek
          double latOffset = (index % 3) * 0.00015;
          double lngOffset = (index ~/ 3) * 0.00015;

          _hives.add(
            HiveData(
              id: mac,
              name: name,
              location: LatLng(37.422500 + latOffset, -122.084500 + lngOffset),
              status: 'green',
              temp: 34.5,
              humidity: 60.0,
              extTemp: _weatherStation.temp,
              extHumidity: _weatherStation.humidity,
              weight: 35.0,
              batteryVoltage: 4.1,
              zcr: 3800.0,
              boxes: [
                BoxElement(
                  name: 'Aljdeszka',
                  code: '${mac}_BOT',
                  type: 'bottom',
                  size: 'bottom',
                  isActive: false,
                ),
                BoxElement(
                  name: 'Fészek',
                  code: '${mac}_NEST',
                  type: 'nest',
                  size: 'hunor',
                  status: 'green',
                ),
              ],
              serverConnection: 'Supabase OK',
            ),
          );
          index++;
        }
      }

      // 2. Időjárás-állomás adatok lekérése
      final envRes = await http.get(
        Uri.parse(
          '$_supabaseUrl/rest/v1/environments?select=*&order=recorded_at.desc&limit=1',
        ),
        headers: _headers,
      );
      if (envRes.statusCode == 200) {
        final List<dynamic> envData = jsonDecode(envRes.body);
        if (envData.isNotEmpty) {
          final latest = envData.first;
          _weatherStation = StationData(
            id: latest['station_mac'] ?? 'WEATHER_01',
            name: 'időjárás-állomás',
            location: _weatherStation.location,
            temp: (latest['temp'] as num?)?.toDouble() ?? _weatherStation.temp,
            humidity:
                (latest['humidity'] as num?)?.toDouble() ??
                _weatherStation.humidity,
            pressure:
                (latest['pressure'] as num?)?.toDouble() ??
                _weatherStation.pressure,
            uvIndex:
                (latest['uv_index'] as num?)?.toDouble() ??
                _weatherStation.uvIndex,
            lightLux:
                (latest['sun'] as num?)?.toDouble() ?? _weatherStation.lightLux,
            windSpeed:
                (latest['wind_speed'] as num?)?.toDouble() ??
                _weatherStation.windSpeed,
            windDirection:
                latest['wind_direction'] ?? _weatherStation.windDirection,
            rainAmount:
                (latest['rain'] as num?)?.toDouble() ??
                _weatherStation.rainAmount,
            batteryVoltage: _weatherStation.batteryVoltage,
          );
        }
      }

      _syncStatusText =
          'Sikeres Supabase szinkron! (${_hives.length} kaptár betöltve)';
    } catch (e) {
      _syncStatusText = 'Hálózati hiba: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
