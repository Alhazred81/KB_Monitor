import 'dart:async';
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
    _loadConfig().then((_) {
      _loadOfflineQueue().then((_) {
        if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
          syncWithSupabase();
        } else {
          _isOnline = false;
          _weatherStation.status = 'red';
          notifyListeners();
        }
      });
      // Periodikus kapcsolat-ellenőrzés 20 másodpercenként
      _healthCheckTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => checkConnectionHealth(),
      );
    });
  }

  String _supabaseUrl = '';
  String _supabaseAnonKey = '';
  bool _isSyncing = false;
  bool _isOnline = true; // Hálózati státusz jelző
  String _syncStatusText = 'Még nincs beállítva a Supabase kapcsolat';
  Timer? _healthCheckTimer;

  // Offline műveletek várólistája (queue)
  List<Map<String, dynamic>> _offlineQueue = [];

  String get supabaseUrl => _supabaseUrl;
  String get supabaseAnonKey => _supabaseAnonKey;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  String get syncStatusText => _syncStatusText;
  int get offlineQueueLength => _offlineQueue.length;

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

  // Offline queue betöltése SharedPreferences-ből
  Future<void> _loadOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_queue', jsonEncode(_offlineQueue));
    } catch (e) {
      debugPrint('Hiba az offline sor mentésekor: $e');
    }
  }

  Future<void> setSupabaseConfig(String url, String anonKey) async {
    _supabaseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    _supabaseAnonKey = anonKey.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supabase_url', _supabaseUrl);
    await prefs.setString('supabase_anon_key', _supabaseAnonKey);
    notifyListeners();
  }

  Future<Map<String, dynamic>> testSupabaseConnection() async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      _isOnline = false;
      _weatherStation.status = 'red';
      notifyListeners();
      return {'success': false, 'message': 'Az URL vagy a kulcs üres.'};
    }

    try {
      final readRes = await http
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
    if (_isSyncing) return;
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      if (_isOnline || _weatherStation.status != 'red') {
        _isOnline = false;
        _weatherStation.status = 'red';
        notifyListeners();
      }
      return;
    }

    try {
      final res = await http
          .get(
            Uri.parse('$_supabaseUrl/rest/v1/monitors?select=mac_address&limit=1'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 4));

      final bool reachable = res.statusCode == 200;
      if (_isOnline != reachable || _weatherStation.status != (reachable ? 'green' : 'red')) {
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

  final List<QueenData> _queens = [];
  final List<HiveData> _hives = [];
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
    name: 'szirupszivattyú',
    location: const LatLng(37.422200, -122.083800),
    totalPumpedLiters: 0.0,
    lastOperationStatus: 'Készenlétben',
    status: 'green',
  );

  List<HiveData> get hives => _hives;
  List<QueenData> get queens => _queens;
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
    _hives.add(hive);
    _postToSupabase('monitors', {
      'mac_address': hive.id,
      'hive_number': hive.name,
    });

    for (var box in hive.boxes) {
      _postToSupabase('bodies', {
        'monitor_mac': hive.id,
        'body_type': box.size,
        'body_function': box.type,
        'position_index': hive.boxes.indexOf(box) + 1,
        'is_active': box.isActive,
      });
    }
    notifyListeners();
  }

  void addBoxToHive(HiveData hive, BoxElement box) {
    final isRoof = box.type == 'roof' ||
        box.name.toLowerCase().contains('tető') ||
        box.name.toLowerCase().contains('teto');
    final isBottom =
        box.type == 'bottom' || box.name.toLowerCase().contains('alj');

    if (isRoof &&
        hive.boxes.any((b) =>
            b.type == 'roof' ||
            b.name.toLowerCase().contains('tető') ||
            b.name.toLowerCase().contains('teto'))) {
      return; // Egynél több tető szigorúan tiltott
    }
    if (isBottom &&
        hive.boxes.any((b) =>
            b.type == 'bottom' || b.name.toLowerCase().contains('alj'))) {
      return; // Egynél több aljdeszka szigorúan tiltott
    }

    hive.boxes.add(box);
    sortHiveBoxes(hive.boxes); // Biztosítja a helyes rétegrendet (tetőetető mindig közvetlenül a tető alatt)
    final int calculatedPos = hive.boxes.indexOf(box) + 1;

    _postToSupabase('bodies', {
      'monitor_mac': hive.id,
      'body_type': box.size,
      'body_function': box.type,
      'position_index': calculatedPos,
      'is_active': box.isActive,
    });
    notifyListeners();
  }

  void reorderBox(HiveData hive, BoxElement box, {required bool moveUp}) {
    if (box.type == 'roof' || box.type == 'bottom') return;

    final int currentIndex = hive.boxes.indexOf(box);
    if (currentIndex == -1) return;

    int targetIndex = -1;
    if (moveUp) {
      // Feljebb mozgatás a képernyőn (a tető felé haladva a toronyban)
      targetIndex = currentIndex + 1;
      if (targetIndex >= hive.boxes.length) return;
      if (hive.boxes[targetIndex].type == 'roof') return;

      final temp = hive.boxes[currentIndex];
      hive.boxes[currentIndex] = hive.boxes[targetIndex];
      hive.boxes[targetIndex] = temp;
    } else {
      // Lejjebb mozgatás a képernyőn (az aljdeszka felé haladva a toronyban)
      targetIndex = currentIndex - 1;
      if (targetIndex < 0) return;
      if (hive.boxes[targetIndex].type == 'bottom') return;

      final temp = hive.boxes[currentIndex];
      hive.boxes[currentIndex] = hive.boxes[targetIndex];
      hive.boxes[targetIndex] = temp;
    }

    // Pozíciók újraindexelése a memóriában
    for (int i = 0; i < hive.boxes.length; i++) {
      hive.boxes[i].positionIndex = i;
    }

    // Hálózati optimalizáció: Csak a ténylegesen megcserélt két fiók pozícióját küldjük a szerverre
    final bCurrent = hive.boxes[currentIndex];
    final bTarget = hive.boxes[targetIndex];
    if (bCurrent.dbId != null) {
      _patchToSupabase('bodies', 'id=eq.${bCurrent.dbId}', {
        'position_index': currentIndex + 1,
      });
    }
    if (bTarget.dbId != null) {
      _patchToSupabase('bodies', 'id=eq.${bTarget.dbId}', {
        'position_index': targetIndex + 1,
      });
    }

    notifyListeners();
  }

  void insertEscapeBoardUnderHoney(HiveData hive, BoxElement honeyBox) {
    final int honeyIndex = hive.boxes.indexOf(honeyBox);
    if (honeyIndex == -1) return;

    // Ha közvetlenül alatta már szöktető van, nem teszünk be másikat
    if (honeyIndex > 0 && hive.boxes[honeyIndex - 1].type == 'escapement') {
      return;
    }

    final String escapementCode =
        '${hive.id}_ESCAPEMENT_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final escapementBox = BoxElement(
      name: 'Szöktető',
      code: escapementCode,
      type: 'escapement',
      size: honeyBox.size.isNotEmpty ? honeyBox.size : 'fel_dadant',
      status: 'green',
      isActive: true,
      statusUpdatedAt: DateTime.now(),
    );

    // Beillesztjük közvetlenül a méztér alá (a méztér jelenlegi indexére,
    // így a méztér és az összes felette lévő elem eggyel feljebb tolódik)
    hive.boxes.insert(honeyIndex, escapementBox);

    // Pozíciók újraindexelése
    for (int i = 0; i < hive.boxes.length; i++) {
      hive.boxes[i].positionIndex = i;
    }

    // Új elem mentése Supabase-be
    _postToSupabase('bodies', {
      'monitor_mac': hive.id,
      'body_type': escapementBox.size,
      'body_function': 'escapement',
      'position_index': honeyIndex + 1,
      'is_active': true,
    });

    // Frissítjük a többi elem pozícióját is Supabase-ben
    for (int i = 0; i < hive.boxes.length; i++) {
      final b = hive.boxes[i];
      if (b.dbId != null) {
        _patchToSupabase('bodies', 'id=eq.${b.dbId}', {
          'position_index': i + 1,
        });
      }
    }

    // Holnapi emlékeztető feladat automatikus létrehozása (24 óra)
    final tomorrow = DateTime.now().add(const Duration(hours: 24));
    addScheduledTask(ScheduledTask(
      id: 'TASK_${hive.id}_ESCAPEMENT_${DateTime.now().millisecondsSinceEpoch}',
      hiveId: hive.id,
      category: 'harvest',
      title: 'Méhszöktetés: Fiókok elvétele',
      description:
          'A méztér alá helyezett méhszöktető leürítette a méheket. A méztereket most azonnal el kell takarítani pergetéshez!',
      scheduledDate: tomorrow,
    ));

    notifyListeners();
  }

  void removeBoxFromHive(HiveData hive, BoxElement box) {
    if (box.type == 'bottom') return; // Az aljdeszka a kaptár fix alapeleme, nem törölhető
    hive.boxes.removeWhere((b) =>
        identical(b, box) ||
        (box.dbId != null && b.dbId == box.dbId) ||
        (box.code.isNotEmpty && b.code == box.code && b.type == box.type));
    if (box.dbId != null) {
      _deleteFromSupabase('bodies', 'id=eq.${box.dbId}');
    } else {
      _deleteFromSupabase(
        'bodies',
        'monitor_mac=eq.${hive.id}&body_function=eq.${box.type}',
      );
    }
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

    _patchToSupabase(
      'bodies',
      'monitor_mac=eq.${hive.id}&body_function=eq.${box.type}',
      {'is_active': newValue},
    );

    _postToSupabase('history_logs', {
      'monitor_mac': hive.id,
      'event_type': box.type == 'bottom' ? 'atkaellenőrzés' : 'pollengyűjtő',
      'description': eventDesc,
    });

    notifyListeners();
  }

  void updateHive(HiveData hive) {
    _patchToSupabase('monitors', 'mac_address=eq.${hive.id}', {
      'hive_number': hive.name,
      'status': hive.status,
      'family_function': hive.familyFunction,
      'protocol': hive.protocol,
      'feeding_mode': hive.feedingMode,
      'feeding_max_liters': hive.feedingMaxLiters,
      'feeding_interval_days': hive.feedingIntervalDays,
      'feeder_level_percent': hive.feederLevelPercent,
    });
    notifyListeners();
  }

  void updateHiveFeedingSettings(HiveData hive) {
    _patchToSupabase('monitors', 'mac_address=eq.${hive.id}', {
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
    });
    notifyListeners();
  }

  void pumpSyrup(SyrupPumpData pump, double liters, String targetHiveName) {
    pump.totalPumpedLiters += liters;
    pump.lastOperationStatus =
        'Cél: $targetHiveName\n${liters.toStringAsFixed(1)}L (OK)';

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

  void refillSyrupTank(SyrupPumpData pump, double liters) {
    pump.totalPumpedLiters = 0.0;
    pump.lastOperationStatus =
        'Tartály újratöltve (${liters.toStringAsFixed(0)} L)';
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

  void completeTask(String taskId) {
    for (var t in _scheduledTasks) {
      if (t.id == taskId) {
        t.isCompleted = true;
        _postToSupabase('treatments', {
          'id': taskId,
          'is_completed': true,
        });
        break;
      }
    }
    notifyListeners();
  }

  void addScheduledTask(ScheduledTask task) {
    _scheduledTasks.add(task);
    _postToSupabase('treatments', {
      'monitor_mac': task.hiveId,
      'treatment_type': task.title,
      'scheduled_date': task.scheduledDate.toIso8601String().split('T').first,
      'is_completed': task.isCompleted,
      'notes': task.description,
    });
    notifyListeners();
  }

  void addLocalFrameAnalysis(FrameAnalysisRecord record) {
    _pendingFrameAnalyses.add(record);
    notifyListeners();
  }

  void addVarroaAnalysis({
    required HiveData hive,
    required VarroaAnalysisRecord record,
    required bool pullOutBoard,
  }) {
    hive.dailyVarroaDrop = record.dailyDrop;

    if (pullOutBoard) {
      for (var box in hive.boxes) {
        if (box.type == 'bottom') {
          box.isActive = false;
          box.statusUpdatedAt = DateTime.now();
          _patchToSupabase(
            'bodies',
            'monitor_mac=eq.${hive.id}&body_function=eq.bottom',
            {'is_active': false},
          );
        }
      }
    }

    if (record.localImagePath.isNotEmpty) {
      _pendingVarroaAnalyses.add(record);
    }

    _postToSupabase('history_logs', {
      'monitor_mac': hive.id,
      'event_type': 'atkaszamlalas',
      'description':
          'Észlelt atka: ${record.miteCount} db / ${record.daysInserted} nap (${record.dailyDrop.toStringAsFixed(1)} db/nap)',
      'metadata': {
        'mite_count': record.miteCount,
        'days_inserted': record.daysInserted,
        'daily_drop': record.dailyDrop,
        'board_removed': pullOutBoard,
      },
    });

    notifyListeners();
  }

  Future<int> syncPendingFramesAndCleanup() async {
    int processedCount = 0;

    final unsyncedFrames = _pendingFrameAnalyses
        .where((r) => !r.isSyncedWithCloud)
        .toList();
    for (var record in unsyncedFrames) {
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

  // ---- OFFLINE QUEUE KEZELÉS ÉS HÁTTÉRSZINKRONIZÁLÁS ----

  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty || !_isOnline) return;

    final List<Map<String, dynamic>> failedItems = [];

    for (var item in List.from(_offlineQueue)) {
      final String method = item['method'];
      final String table = item['table'];
      final String? queryFilter = item['queryFilter'];
      final Map<String, dynamic> data = item['data'];

      try {
        bool success = false;
        if (method == 'POST') {
          final res = await http
              .post(
                Uri.parse('$_supabaseUrl/rest/v1/$table'),
                headers: _headers,
                body: jsonEncode(data),
              )
              .timeout(const Duration(seconds: 4));
          success = (res.statusCode >= 200 && res.statusCode < 300);
        } else if (method == 'PATCH') {
          final res = await http
              .patch(
                Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
                headers: _headers,
                body: jsonEncode(data),
              )
              .timeout(const Duration(seconds: 4));
          success = (res.statusCode >= 200 && res.statusCode < 300);
        } else if (method == 'DELETE') {
          final res = await http
              .delete(
                Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
                headers: _headers,
              )
              .timeout(const Duration(seconds: 4));
          success = (res.statusCode >= 200 && res.statusCode < 300);
        }

        if (!success) {
          failedItems.add(item);
        }
      } catch (e) {
        failedItems.add(item);
      }
    }

    _offlineQueue = failedItems;
    await _saveOfflineQueue();
    notifyListeners();
  }

  Future<void> _postToSupabase(String table, Map<String, dynamic> data) async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) return;

    if (!_isOnline) {
      _offlineQueue.add({'method': 'POST', 'table': table, 'data': data});
      await _saveOfflineQueue();
      notifyListeners();
      return;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_supabaseUrl/rest/v1/$table'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Server status: ${res.statusCode}');
      }
      _isOnline = true;
    } catch (e) {
      _isOnline = false;
      _offlineQueue.add({'method': 'POST', 'table': table, 'data': data});
      await _saveOfflineQueue();
      debugPrint('Supabase offline rögzítés ($table): $e');
      notifyListeners();
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
      final res = await http
          .patch(
            Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Server status: ${res.statusCode}');
      }
      _isOnline = true;
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
      final res = await http
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
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      _syncStatusText = 'Hiba: Add meg a Supabase URL-t és a kulcsot!';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _syncStatusText = 'Szinkronizáció a Supabase adatbázissal...';
    notifyListeners();

    try {
      // Először megpróbáljuk elküldeni az offline sorban gyűlt változtatásokat
      await _processOfflineQueue();

      final monitorsRes = await http
          .get(
            Uri.parse('$_supabaseUrl/rest/v1/monitors?select=*'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));

      if (monitorsRes.statusCode == 200) {
        _isOnline = true;
        _weatherStation.status = 'green';
        final List<dynamic> data = jsonDecode(monitorsRes.body);
        _hives.clear();

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

          final bodiesRes = await http
              .get(
                Uri.parse(
                  '$_supabaseUrl/rest/v1/bodies?monitor_mac=eq.$mac&select=*',
                ),
                headers: _headers,
              )
              .timeout(const Duration(seconds: 5));

          List<BoxElement> loadedBoxes = [
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

          if (bodiesRes.statusCode == 200) {
            final List<dynamic> bodiesData = jsonDecode(bodiesRes.body);
            if (bodiesData.isNotEmpty) {
              loadedBoxes.clear();
              for (var bRow in bodiesData) {
                String rawFunc = (bRow['body_function'] ?? bRow['function'] ?? 'honey').toString().trim();
                final String f = rawFunc.toLowerCase();
                String bFunc = rawFunc;
                String bName = 'Kaptárelem';

                if (f == 'brood_box' ||
                    f == 'broodbox' ||
                    f == 'nest' ||
                    f == '8' ||
                    f.contains('fészek') ||
                    f.contains('feszek')) {
                  bFunc = 'brood_box';
                  bName = 'Fészekfiók';
                } else if (f == 'honey' ||
                    f == 'mez' ||
                    f == 'mezter' ||
                    f == 'méztér' ||
                    f == '9') {
                  bFunc = 'honey';
                  bName = 'Méztér';
                } else if (f == 'bottom' ||
                    f == 'alj' ||
                    f == 'aljdeszka' ||
                    f == '15') {
                  bFunc = 'bottom';
                  bName = 'Aljdeszka';
                } else if (f == 'pollen_trap' ||
                    f == 'pollen' ||
                    f == 'viragpor' ||
                    f == 'virágpor' ||
                    f == '11') {
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
                    f == '13') {
                  bFunc = 'escapement';
                  bName = 'Szöktető';
                } else if (f == 'vent' ||
                    f == 'szellozo' ||
                    f == 'szellőző' ||
                    f == '12') {
                  bFunc = 'vent';
                  bName = 'Szellőző';
                } else if (f == 'roof' ||
                    f == 'teto' ||
                    f == 'tető' ||
                    f == 'dekli') {
                  bFunc = 'roof';
                  bName = 'Tető';
                } else if (f == 'treatment_strip' || f.contains('kezel')) {
                  bFunc = 'treatment_strip';
                  bName = 'Kezelőlap hordozó';
                } else if (f == 'queen_excluder' ||
                    f.contains('anyaracs') ||
                    f.contains('excluder')) {
                  bFunc = 'queen_excluder';
                  bName = 'Anyarács';
                } else {
                  bFunc = rawFunc;
                  bName = (bRow['name'] != null &&
                          bRow['name'].toString().trim().isNotEmpty &&
                          bRow['name'].toString().toLowerCase() != 'elem')
                      ? bRow['name'].toString()
                      : (rawFunc.isNotEmpty && rawFunc != 'elem'
                          ? rawFunc
                          : 'Kiegészítő elem');
                }

                final int? bodyDbId = (bRow['id'] as num?)?.toInt();
                final String bType = bRow['body_type'] ?? 'hunor';
                final bool isActive = bRow['is_active'] ?? false;
                loadedBoxes.add(
                  BoxElement(
                    dbId: bodyDbId,
                    name: bName,
                    code: '${mac}_${bFunc.toUpperCase()}',
                    type: bFunc,
                    size: bType,
                    isActive: isActive,
                    status: 'green',
                  ),
                );
              }
            }
          }

          // A kaptár pontosan azokat a fiókokat tartalmazza, amelyek a valóságban / adatbázisban léteznek
          final bool originallyMissingBrood =
              !loadedBoxes.any((b) => b.type == 'brood_box' || b.type == 'nest');

          sortHiveBoxes(loadedBoxes);

          final String rawStatus = row['status'] ??
              (swarmIdx >= 70.0
                  ? 'purple'
                  : (originallyMissingBrood ? 'yellow' : 'green'));
          final String familyFunction = row['family_function'] ??
              row['familyFunction'] ??
              row['function'] ??
              (originallyMissingBrood ? 'gyenge' : 'gyujto_mez');
          final String? protocol = row['protocol'];
          final double dailyVarroa =
              (row['daily_varroa_drop'] as num?)?.toDouble() ?? 0.0;
          final double temp = (row['temp'] as num?)?.toDouble() ??
              (row['temperature'] as num?)?.toDouble() ??
              34.5;
          final double weight = (row['weight'] as num?)?.toDouble() ?? 35.0;
          final String notes = row['notes'] ?? row['comment'] ?? '';

          double latOffset = (index % 3) * 0.00015;
          double lngOffset = (index ~/ 3) * 0.00015;

          _hives.add(
            HiveData(
              id: mac,
              name: name,
              location: LatLng(37.422500 + latOffset, -122.084500 + lngOffset),
              status: rawStatus,
              familyFunction: familyFunction,
              protocol: protocol,
              dailyVarroaDrop: dailyVarroa,
              temp: temp,
              humidity: 60.0,
              extTemp: _weatherStation.temp,
              extHumidity: _weatherStation.humidity,
              weight: weight,
              batteryVoltage: 4.1,
              zcr: 3800.0,
              swarmIndex: swarmIdx,
              feedingMode: feedingMode,
              feedingMaxLiters: feedingMaxLiters,
              feedingIntervalHours: feedingIntervalHours,
              feedingIntervalDays: feedingIntervalDays,
              feedingStopBeforeSunsetMinutes: feedingStopSunsetMin,
              feedingPortionLiters: feedingPortionLiters,
              feederLevelPercent: feederLevelPercent,
              feederCalibEmptyMm: feederCalibEmptyMm,
              feederCalibFullMm: feederCalibFullMm,
              feederRawDistanceMm: feederRawDistanceMm,
              boxes: loadedBoxes,
              serverConnection: 'Supabase OK',
              evaluation: EvaluationData(notes: notes),
            ),
          );
          index++;
        }
      } else {
        _isOnline = false;
        _weatherStation.status = 'red';
      }

      _syncStatusText = _isOnline
          ? 'Sikeres Supabase szinkron! (${_hives.length} kaptár betöltve)'
          : 'Offline mód: Helyi adatok használatban (${_offlineQueue.length} várakozó művelet)';
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

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    super.dispose();
  }
}
