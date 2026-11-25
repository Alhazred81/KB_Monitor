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
    _initializeStartup();
  }

  Future<void> _initializeStartup() async {
    await _loadConfig(notify: false);
    await _loadHivesBoxesLocally(notify: false);
    await _loadOfflineQueue();
    if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
      notifyListeners();
      syncWithSupabase();
    } else {
      _isOnline = false;
      _weatherStation.status = 'red';
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
          'updated_at': hive.updatedAt.toIso8601String(),
          'tower_updated_at': hive.towerUpdatedAt.toIso8601String(),
          'status': hive.status,
          'protocol': hive.protocol,
          'family_function': hive.familyFunction,
          'queen_replacement_state': hive.queenReplacementState,
          'evaluation_notes': hive.evaluation.notes,
          'reported_diseases': hive.reportedDiseases,
          'boxes': hive.boxes.map((b) => b.toJson()).toList(),
        };
      }
      await prefs.setString('local_hives_boxes', jsonEncode(hivesMap));
    } catch (e) {
      debugPrint('Hiba a kaptárfiókok helyi mentésekor: $e');
    }
  }

  // Kaptárak torony/doboz-struktúrájának és időbélyegeinek betöltése helyi memóriából
  Future<void> _loadHivesBoxesLocally({bool notify = true}) async {
    try {
      final prefs = await _getPrefs();
      final String? boxesStr = prefs.getString('local_hives_boxes');
      if (boxesStr != null && boxesStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(boxesStr);
        for (var hive in _hives) {
          if (decoded.containsKey(hive.id)) {
            _locallyPersistedHiveIds.add(hive.id);
            final dynamic entry = decoded[hive.id];
            if (entry is Map) {
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
              if (entry['queen_replacement_state'] is String) {
                hive.queenReplacementState =
                    entry['queen_replacement_state'] as String;
              }
              if (entry['evaluation_notes'] is String) {
                hive.evaluation.notes = entry['evaluation_notes'] as String;
              }
              if (entry['reported_diseases'] is List) {
                hive.reportedDiseases = (entry['reported_diseases'] as List)
                    .map((e) => e.toString())
                    .toList();
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
        if (notify) notifyListeners();
      }
    } catch (e) {
      debugPrint('Hiba a kaptárfiókok helyi betöltésekor: $e');
    }
  }

  Future<void> setSupabaseConfig(String url, String anonKey) async {
    _supabaseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    _supabaseAnonKey = anonKey.trim();
    final prefs = await _getPrefs();
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

  void addQueen(QueenData queen) {
    final idx = _queens.indexWhere((q) => q.id == queen.id);
    if (idx >= 0) {
      _queens[idx] = queen;
    } else {
      _queens.add(queen);
    }
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
    hive.updatedAt = DateTime.now().toUtc();
    hive.towerUpdatedAt = DateTime.now().toUtc();
    _hives.add(hive);
    _postToSupabase('monitors', {
      'mac_address': hive.id,
      'hive_number': hive.name,
      'entrance_heading': hive.entranceHeading,
      'updated_at': hive.updatedAt.toIso8601String(),
    });

    for (var box in hive.boxes) {
      box.updatedAt = hive.towerUpdatedAt;
      _postToSupabase('bodies', {
        'monitor_mac': hive.id,
        'body_type': box.size,
        'body_function': box.type,
        'position_index': hive.boxes.indexOf(box) + 1,
        'is_active': box.isActive,
        'updated_at': box.updatedAt.toIso8601String(),
      });
    }
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

    final Map<String, dynamic> bodyPayload = {
      'monitor_mac': hive.id,
      'body_type': box.size,
      'body_function': box.type,
      'position_index': calculatedPos,
      'is_active': box.isActive,
      'updated_at': box.updatedAt.toIso8601String(),
      if (box.statusUpdatedAt != null)
        'status_updated_at': box.statusUpdatedAt!.toUtc().toIso8601String(),
    };

    _postToSupabase('bodies', bodyPayload).then((inserted) {
      final int? newId = (inserted?['id'] as num?)?.toInt();
      if (newId != null && box.dbId == null) {
        box.dbId = newId;
        _saveHivesBoxesLocally();
      }
    });
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

    _saveHivesBoxesLocally();
    notifyListeners();
  }

  void insertEscapeBoardUnderBox(HiveData hive, BoxElement targetBox) {
    if (hive.isQuarantined) {
      debugPrint('Zárlat: Karantén alatti torony alá tilos szöktetőt helyezni!');
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
    _postToSupabase('bodies', {
      'monitor_mac': hive.id,
      'body_type': escapementBox.size,
      'body_function': 'escapement',
      'position_index': targetIndex + 1,
      'is_active': true,
      'status_updated_at': startUtcIso,
      'updated_at': startUtcIso,
    }).then((inserted) {
      final int? newId = (inserted?['id'] as num?)?.toInt();
      if (newId != null && escapementBox.dbId == null) {
        escapementBox.dbId = newId;
        _saveHivesBoxesLocally();
      }
    });

    _postToSupabase('history_logs', {
      'monitor_mac': hive.id,
      'event_type': 'szoktetes',
      'description':
          'Méhszöktetés elindítva (${targetBox.name} alatt) – kezdete: $startUtcIso',
    });

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
    hive.boxes.removeWhere(
      (b) =>
          identical(b, box) ||
          (box.dbId != null && b.dbId == box.dbId) ||
          (box.code.isNotEmpty && b.code == box.code),
    );

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
    } else {
      _deleteFromSupabase(
        'bodies',
        'monitor_mac=eq.${hive.id}&body_function=eq.${box.type}',
      );
    }
    _saveHivesBoxesLocally();
    notifyListeners();
  }

  /// Szöktetés kész: eltávolítja a méhszöktetőt és az összes felette lévő fiókot (tető kivételével).
  /// A szöktető ALATT lévő fiókok (fészek, alsóbb mézterek, aljdeszka) garantáltan érintetlenül a kaptáron maradnak!
  int finishEscapementAndHarvest(HiveData hive) {
    if (hive.isQuarantined) {
      debugPrint('Zárlat: Karantén alatti toronyból tilos mézteret elvenni vagy pergetni!');
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

  void updateHive(HiveData hive) {
    hive.updatedAt = DateTime.now().toUtc();
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
    _saveHivesBoxesLocally();
    notifyListeners();
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
        if (b.isActive) {
          b.isActive = false;
          if (b.dbId != null) {
            _patchToSupabase('bodies', 'id=eq.${b.dbId}', {
              'is_active': false,
              'updated_at': nowUtc.toIso8601String(),
            });
          }
        }
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
      description:
          'Nyúlós költésrothadás! A kaptár teljes tornya (minden fiók, aljdeszka, etető, tető, keret és méz) hatósági zárlat alatt áll. Azonnali kénlapos megsemmisítés szükséges — semmi nem kerülhet át máshova!',
      scheduledDate: DateTime.now(),
    );
    _scheduledTasks.insert(0, hansTask);

    _postToSupabase('treatments', {
      'monitor_mac': hive.id,
      'treatment_type': hansTask.title,
      'scheduled_date': hansTask.scheduledDate.toIso8601String().split('T').first,
      'is_completed': false,
      'notes': hansTask.description,
    });

    _postToSupabase('history_logs', {
      'monitor_mac': hive.id,
      'event_type': 'hans_protokoll',
      'description':
          'HANS-PROTOKOLL AKTIVÁLVA (Nyúlós költésrothadás): a teljes kaptártorony (${hive.boxes.length} elem) zárlat és megsemmisítés alá vonva!',
    });

    sendNtfyNotification(
      'NYÚLÓS KÖLTÉSROTHADÁS! ${hive.name} (${hive.id}) teljes tornya HANS-PROTOKOLL és zárlat alá került! Etetés leállítva, semmilyen elem nem vihető át máshova!',
      title: '🔥 HANS-PROTOKOLL: ${hive.name}',
      priority: 5,
      tags: 'rotating_light,fire,biohazard',
    );

    _patchToSupabase('monitors', 'mac_address=eq.${hive.id}', {
      'hive_number': hive.name,
      'status': 'flashing_red',
      'family_function': 'Hans',
      'protocol': 'hans',
      'feeding_mode': 'off',
    });
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
    notifyListeners();
  }

  void setSyrupPumpEmergency(bool isEmergency, {String? reason}) {
    _syrupPump.isPumpInterlocked = isEmergency;
    if (isEmergency) {
      _syrupPump.emergencyStopReason =
          reason ?? 'Vészleállítás: szivattyú reteszelve és tiltva!';
    } else {
      _syrupPump.emergencyStopReason = null;
    }
    notifyListeners();
  }

  /// Vízadagoló valós idejű vízszintjének frissítése
  void updateWatererLevel(double levelPercent) {
    _waterer.waterLevel = levelPercent.clamp(0.0, 100.0);
    if (_waterer.waterLevel <= 5.0) {
      sendNtfyNotification(
        'Az itató (${_waterer.name}) vízszintje 5% alá esett! Utántöltés szükséges!',
        title: '⚠️ Kiszáradt vízadagoló!',
        priority: 4,
        tags: 'warning,droplet',
      );
    }
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
        _postToSupabase('treatments', {'id': taskId, 'is_completed': true});
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
    if (_offlineQueue.isEmpty || !_isOnline || _isProcessingQueue) return;
    _isProcessingQueue = true;

    final List<Map<String, dynamic>> failedItems = [];

    try {
      for (var item in List.from(_offlineQueue)) {
        final String method = item['method'];
        final String table = item['table'];
        final String? queryFilter = item['queryFilter'];
        final Map<String, dynamic> data = item['data'];

        try {
          bool success = false;
          if (method == 'POST') {
            var res = await _httpClient
                .post(
                  Uri.parse('$_supabaseUrl/rest/v1/$table'),
                  headers: _headers,
                  body: jsonEncode(data),
                )
                .timeout(const Duration(seconds: 4));
            if (res.statusCode == 400 &&
                data.containsKey('status_updated_at') &&
                res.body.contains('status_updated_at')) {
              final fallbackData = Map<String, dynamic>.from(data)
                ..remove('status_updated_at');
              res = await _httpClient
                  .post(
                    Uri.parse('$_supabaseUrl/rest/v1/$table'),
                    headers: _headers,
                    body: jsonEncode(fallbackData),
                  )
                  .timeout(const Duration(seconds: 4));
            }
            success = (res.statusCode >= 200 && res.statusCode < 300);
          } else if (method == 'PATCH') {
            var res = await _httpClient
                .patch(
                  Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
                  headers: _headers,
                  body: jsonEncode(data),
                )
                .timeout(const Duration(seconds: 4));
            if (res.statusCode == 400 &&
                data.containsKey('status_updated_at') &&
                res.body.contains('status_updated_at')) {
              final fallbackData = Map<String, dynamic>.from(data)
                ..remove('status_updated_at');
              res = await _httpClient
                  .patch(
                    Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
                    headers: _headers,
                    body: jsonEncode(fallbackData),
                  )
                  .timeout(const Duration(seconds: 4));
            }
            success = (res.statusCode >= 200 && res.statusCode < 300);
          } else if (method == 'DELETE') {
            final res = await _httpClient
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
    } finally {
      _isProcessingQueue = false;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _postToSupabase(
    String table,
    Map<String, dynamic> data,
  ) async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) return null;

    if (!_isOnline) {
      _offlineQueue.add({'method': 'POST', 'table': table, 'data': data});
      await _saveOfflineQueue();
      notifyListeners();
      return null;
    }

    try {
      var res = await _httpClient
          .post(
            Uri.parse('$_supabaseUrl/rest/v1/$table'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 400 &&
          data.containsKey('status_updated_at') &&
          res.body.contains('status_updated_at')) {
        final fallbackData = Map<String, dynamic>.from(data)
          ..remove('status_updated_at');
        res = await _httpClient
            .post(
              Uri.parse('$_supabaseUrl/rest/v1/$table'),
              headers: _headers,
              body: jsonEncode(fallbackData),
            )
            .timeout(const Duration(seconds: 4));
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Server status: ${res.statusCode}');
      }
      _isOnline = true;
      if (res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          return Map<String, dynamic>.from(decoded.first as Map);
        } else if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
      return null;
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
      var res = await _httpClient
          .patch(
            Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 400 &&
          data.containsKey('status_updated_at') &&
          res.body.contains('status_updated_at')) {
        final fallbackData = Map<String, dynamic>.from(data)
          ..remove('status_updated_at');
        res = await _httpClient
            .patch(
              Uri.parse('$_supabaseUrl/rest/v1/$table?$queryFilter'),
              headers: _headers,
              body: jsonEncode(fallbackData),
            )
            .timeout(const Duration(seconds: 4));
      }

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
      // Először megpróbáljuk elküldeni az offline sorban gyűlt változtatásokat
      await _processOfflineQueue();

      // Párhuzamosan töltjük le a kaptármonitorokat és az összes fiókot egyetlen keep-alive kapcsolaton!
      final Future<http.Response?> allBodiesFuture = _httpClient
          .get(
            Uri.parse(
              '$_supabaseUrl/rest/v1/bodies?select=*&order=position_index.asc',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6))
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

                if (f == 'brood_box' ||
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
                final String bType = bRow['body_type'] ?? 'hunor';
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

                loadedBoxes.add(
                  BoxElement(
                    dbId: bodyDbId,
                    name: bName,
                    code: '${mac}_${bFunc.toUpperCase()}',
                    type: bFunc,
                    size: bType,
                    isActive: isActive,
                    status: 'green',
                    positionIndex: posIndex,
                    statusUpdatedAt: resolvedStatusUpdatedAt,
                    updatedAt: dbUpdatedAt,
                  ),
                );
              }
          }

          final prevHive = existingHivesMap[mac];
          final String? dbFamilyFunction =
              (row['family_function'] ?? row['familyFunction'] ?? row['function'])
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
          final String fallbackStatus = swarmIdx >= 70.0
              ? 'purple'
              : (originallyMissingBrood ? 'yellow' : 'green');
          String resolvedStatus;
          if (dbStatus != null && dbStatus.isNotEmpty) {
            // Ha az adatbázisban nem-zöld (pl. sárga, narancs, piros) státusz van, vagy nincs helyi mentett felülírás, azt vesszük
            if (prevHive != null &&
                _locallyPersistedHiveIds.contains(mac) &&
                prevHive.status != 'green' &&
                dbStatus == 'green') {
              resolvedStatus = prevHive.status;
            } else {
              resolvedStatus = dbStatus;
            }
          } else {
            resolvedStatus =
                (prevHive != null &&
                    (_locallyPersistedHiveIds.contains(mac) ||
                        prevHive.status != 'green'))
                ? prevHive.status
                : fallbackStatus;
          }

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
              (row['daily_varroa_drop'] as num?)?.toDouble() ?? 0.0;
          final double temp =
              (row['temp'] as num?)?.toDouble() ??
              (row['temperature'] as num?)?.toDouble() ??
              34.5;
          final double weight = (row['weight'] as num?)?.toDouble() ?? 35.0;
          final String notes = (row['notes'] ?? row['comment'] ?? '').toString();

          double latOffset = (index % 3) * 0.00015;
          double lngOffset = (index ~/ 3) * 0.00015;

          final EvaluationData mergedEvaluation =
              prevHive?.evaluation ?? EvaluationData(notes: notes);
          if (mergedEvaluation.notes.trim().isEmpty && notes.trim().isNotEmpty) {
            mergedEvaluation.notes = notes;
          }

          syncedHives.add(
            HiveData(
              id: mac,
              name: name,
              location: LatLng(37.422500 + latOffset, -122.084500 + lngOffset),
              status: resolvedStatus,
              entranceHeading:
                  prevHive?.entranceHeading ??
                  ((row['entrance_heading'] as num?)?.toDouble() ?? 180.0),
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
              pairedTankId: pairedTank,
              isAutoPaired: isAutoPaired,
              boxes: loadedBoxes,
              serverConnection: 'Supabase OK',
              queen: prevHive?.queen,
              queenReplacementState: prevHive?.queenReplacementState,
              queenIntroducedAt: prevHive?.queenIntroducedAt,
              lockedUntil: prevHive?.lockedUntil,
              lockReason: prevHive?.lockReason,
              reportedDiseases: prevHive?.reportedDiseases,
              evaluation: mergedEvaluation,
            ),
          );
          index++;
        }
        _hives
          ..clear()
          ..addAll(syncedHives);
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
          _postToSupabase('bodies', {
            'monitor_mac': hive.id,
            'body_type': box.size,
            'body_function': box.type,
            'position_index': bi + 1,
            'is_active': box.isActive,
          });
        }
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
