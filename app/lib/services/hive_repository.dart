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

  static List<BoxElement> createStandardBoxes(String mac, {required bool isHoneyProducer}) {
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
    final isEscapement = box.type == 'escapement' ||
        box.name.toLowerCase().contains('szöktet') ||
        box.name.toLowerCase().contains('szoktet');
    final isRoof = !isEscapement &&
        (box.type == 'roof' ||
            ((box.name.toLowerCase().contains('tető') ||
                    box.name.toLowerCase().contains('teto')) &&
                !box.name.toLowerCase().contains('etet')));
    final isBottom =
        box.type == 'bottom' || box.name.toLowerCase().contains('alj');
    final isPollen = box.type == 'pollen_trap' ||
        box.name.toLowerCase().contains('pollen') ||
        box.name.toLowerCase().contains('virágpor');
    final isFeeder = box.type == 'feeder' ||
        box.type == 'roof_feeder' ||
        box.name.toLowerCase().contains('etet');

    if (isRoof &&
        hive.boxes.any((b) =>
            b.type == 'roof' ||
            ((b.name.toLowerCase().contains('tető') ||
                    b.name.toLowerCase().contains('teto')) &&
                !b.name.toLowerCase().contains('szöktet') &&
                !b.name.toLowerCase().contains('szoktet') &&
                !b.name.toLowerCase().contains('etet')))) {
      return; // Egynél több tető szigorúan tiltott
    }
    if (isBottom &&
        hive.boxes.any((b) =>
            b.type == 'bottom' || b.name.toLowerCase().contains('alj'))) {
      return; // Egynél több aljdeszka szigorúan tiltott
    }
    if (isPollen &&
        hive.boxes.any((b) =>
            b.type == 'pollen_trap' ||
            b.name.toLowerCase().contains('pollen') ||
            b.name.toLowerCase().contains('virágpor'))) {
      return; // Egynél több pollengyűjtő szigorúan tiltott
    }
    if (isFeeder &&
        hive.boxes.any((b) =>
            b.type == 'feeder' ||
            b.type == 'roof_feeder' ||
            b.name.toLowerCase().contains('etet'))) {
      return; // Egynél több tetőetető szigorúan tiltott
    }

    hive.boxes.add(box);
    sortHiveBoxes(hive.boxes); // Szigorú méhészeti szabályok betartása (pollengyűjtő közvetlenül az aljdeszkán, tetőetető közvetlenül a tető alatt)
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
    // Szigorú szabály: pollengyűjtő csak közvetlenül az aljdeszkán, tetőetető csak a dekli alatt lehet!
    final isPollen = box.type == 'pollen_trap' ||
        box.name.toLowerCase().contains('pollen') ||
        box.name.toLowerCase().contains('virágpor');
    final isFeeder = box.type == 'feeder' ||
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

  void insertEscapeBoardUnderBox(HiveData hive, BoxElement targetBox) {
    int targetIndex = hive.boxes.indexWhere(
      (b) => identical(b, targetBox) || (targetBox.dbId != null && b.dbId == targetBox.dbId),
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
        (b) => identical(b, targetBox) || (targetBox.dbId != null && b.dbId == targetBox.dbId),
      );
      if (targetIndex == -1) {
        targetIndex = hive.boxes.indexWhere((b) => b.code == targetBox.code);
      }
      if (targetIndex <= 0) return;
    }

    final String escapementCode =
        '${hive.id}_ESCAPEMENT_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final escapementBox = BoxElement(
      name: 'Szöktető',
      code: escapementCode,
      type: 'escapement',
      size: targetBox.size.isNotEmpty ? targetBox.size : 'fel_dadant',
      status: 'green',
      isActive: true,
      statusUpdatedAt: DateTime.now(),
    );

    // Beillesztjük közvetlenül a kiválasztott fiók ALÁ
    // (a targetIndex pozícióra szúrjuk be, így a célfiók és a felette lévő összes fiók feljebb tolódik)
    hive.boxes.insert(targetIndex, escapementBox);

    // Pozíciók újraindexelése
    for (int i = 0; i < hive.boxes.length; i++) {
      hive.boxes[i].positionIndex = i;
    }

    // Új elem mentése Supabase-be
    _postToSupabase('bodies', {
      'monitor_mac': hive.id,
      'body_type': escapementBox.size,
      'body_function': 'escapement',
      'position_index': targetIndex + 1,
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

    // Tisztítjuk az esetleges feladatokat, a méhszöktetés a toronyban lévő Szöktető kereten él visszaszámlálóval
    scheduledTasks.removeWhere((t) =>
        t.hiveId == hive.id &&
        (t.id.contains('ESCAPEMENT') || t.title.contains('Méhszöktetés')));

    notifyListeners();
  }

  void insertEscapeBoardUnderHoney(HiveData hive, BoxElement honeyBox) {
    insertEscapeBoardUnderBox(hive, honeyBox);
  }

  void removeBoxFromHive(HiveData hive, BoxElement box) {
    if (box.type == 'bottom') return; // Az aljdeszka a kaptár fix alapeleme, nem törölhető
    hive.boxes.removeWhere((b) =>
        identical(b, box) ||
        (box.dbId != null && b.dbId == box.dbId));

    // Ha szöktetőt veszünk ki, töröljük a kapcsolódó 24 órás feladatot is
    if (box.type == 'escapement' || box.name.toLowerCase().contains('szöktet')) {
      scheduledTasks.removeWhere((t) =>
          t.hiveId == hive.id &&
          (t.id.contains('ESCAPEMENT') || t.title.contains('Méhszöktetés')));
    }

    if (box.dbId != null) {
      _deleteFromSupabase('bodies', 'id=eq.${box.dbId}');
    }
    notifyListeners();
  }

  /// Szöktetés kész: eltávolítja a méhszöktetőt és az összes felette lévő fiókot (tető kivételével).
  /// A szöktető ALATT lévő fiókok (fészek, alsóbb mézterek, aljdeszka) garantáltan érintetlenül a kaptáron maradnak!
  int finishEscapementAndHarvest(HiveData hive) {
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

    // 3. Supabase-ből CSAK a konkrétan elvett fiókok törlése egyedi ID alapján
    for (var b in removedBoxes) {
      if (b.dbId != null) {
        _deleteFromSupabase('bodies', 'id=eq.${b.dbId}');
      }
    }

    // 4. Kapcsolódó méhszöktetési feladatok törlése
    scheduledTasks.removeWhere((t) =>
        t.hiveId == hive.id &&
        (t.id.contains('ESCAPEMENT') || t.title.contains('Méhszöktetés')));

    // 5. Pozíciók újrarendezése és mentése
    for (int i = 0; i < hive.boxes.length; i++) {
      hive.boxes[i].positionIndex = i;
      if (hive.boxes[i].dbId != null) {
        _patchToSupabase('bodies', 'id=eq.${hive.boxes[i].dbId}', {
          'position_index': i + 1,
        });
      }
    }

    final int removedSuperCount = removedBoxes.length - 1; // Szöktető nélkül az elvett mézterek száma

    _postToSupabase('history_logs', {
      'monitor_mac': hive.id,
      'event_type': 'pergetes',
      'description':
          'Szöktetés kész: $removedSuperCount db méztéri fiók és a méhszöktető elvéve a toronyból. Megmaradt fiókok száma: ${hive.boxes.length}.',
    });

    notifyListeners();
    return removedSuperCount;
  }

  void toggleBoxActiveState(HiveData hive, BoxElement box, bool newValue) {
    box.isActive = newValue;
    box.statusUpdatedAt = DateTime.now();

    final String eventDesc = box.type == 'bottom'
        ? (newValue
              ? 'Aljdeszka betolva (3 napos varroa kontroll indítva)'
              : 'Aljdeszka kihúzva')
        : (newValue ? 'Pollengyűjtő bekapcsolva' : 'Pollengyűjtő kikapcsolva');

    if (box.dbId != null) {
      _patchToSupabase('bodies', 'id=eq.${box.dbId}', {'is_active': newValue});
    } else {
      final String funcFilter = box.type == 'bottom'
          ? 'bottom'
          : 'in.(${box.type},pollen_trap,pollen,viragpor,11)';
      _patchToSupabase(
        'bodies',
        'monitor_mac=eq.${hive.id}&body_function=$funcFilter',
        {'is_active': newValue},
      );
    }

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
      await http.post(
        url,
        headers: headers,
        body: message,
      );
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
      hive.feederStatusMessage = 'Szivattyú LETILTVA (Villogó Piros): Vészleállítás aktív!';
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
      hive.feederStatusMessage = 'SZTOJ: Várakozás másik adagoló (${busyHive.name}) feltöltésére (5 perc)';
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
    hive.feederStatusMessage = 'Utántöltés folyamatban: ${liters.toStringAsFixed(1)}L -> ${_syrupPump.name}';
    _syrupPump.status = 'orange';
    _syrupPump.lastOperationStatus = 'Adagolás: ${hive.name} (${liters.toStringAsFixed(1)}L)';
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
    hive.feederLevelPercent = (hive.feederLevelPercent + (liters * 18.0)).clamp(0.0, 100.0);
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
    hive.feederStatusMessage = 'Auto-párosítva: ${_syrupPump.name} | Utántöltve: +${liters.toStringAsFixed(1)}L';

    _syrupPump.status = 'green';
    _syrupPump.lastOperationStatus = 'Cél: ${hive.name} | ${liters.toStringAsFixed(1)}L (OK)';

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
    pump.lastOperationStatus = 'VÉSZLEÁLLÍTÁS: Szivattyú letiltva (Villogó Piros)!';

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
      _waterer.waterTemp = 18.5; // Normál hőmérséklet visszaállítása feloldáskor
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

  void scheduleQueenAcceptanceInspection(HiveData hive, DateTime scheduledDate) {
    scheduleQueenReplacementTasks(hive, isCageMode: false, custom14DayDate: scheduledDate);
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
      final lockEnd = custom14DayDate ?? (hive.lockedUntil ?? now.add(const Duration(days: 14)));
      final inspection14Day = DateTime(lockEnd.year, lockEnd.month, lockEnd.day, 10, 0);
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
        final Map<String, HiveData> existingHivesMap = {for (var h in _hives) h.id: h};
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
                  '$_supabaseUrl/rest/v1/bodies?monitor_mac=eq.$mac&select=*&order=position_index.asc',
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
                final int? posIndex = (bRow['position_index'] as num?)?.toInt();
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
                  ),
                );
              }
            }
          }

          final String familyFunction = row['family_function'] ??
              row['familyFunction'] ??
              row['function'] ??
              (name.toLowerCase().contains('méz') || mac.endsWith('01')
                  ? 'méz'
                  : 'gyujto_mez');
          final bool isHoneyColony = familyFunction == 'méz' ||
              familyFunction == 'gyujto_mez' ||
              familyFunction == 'méztermelő' ||
              name.toLowerCase().contains('méz') ||
              mac.endsWith('01');

          // Felhasználói előírás: Torony rétegrend ellenőrzése és szükség esetén szabványosítása
          final bool hasBottom = loadedBoxes.any((b) => b.type == 'bottom');
          final bool hasPollen = loadedBoxes.any((b) => b.type == 'pollen_trap');
          final bool hasBrood = loadedBoxes.any((b) => b.type == 'brood_box' || b.type == 'nest');
          final bool hasRoof = loadedBoxes.any((b) => b.type == 'roof');
          final int honeyCount = loadedBoxes.where((b) => b.type == 'honey').length;
          final bool hasFeeder = loadedBoxes.any((b) => b.type == 'feeder' || b.type == 'roof_feeder');

          final bool isStandard = hasBottom &&
              hasPollen &&
              hasBrood &&
              hasRoof &&
              (isHoneyColony ? (honeyCount >= 4) : hasFeeder);

          if (!isStandard) {
            // Nem felel meg az előírásnak: azonnal szabványosítjuk és elmentjük Supabase-be is!
            loadedBoxes = createStandardBoxes(mac, isHoneyProducer: isHoneyColony);
            _deleteFromSupabase('bodies', 'monitor_mac=eq.$mac');
            for (int bi = 0; bi < loadedBoxes.length; bi++) {
              final box = loadedBoxes[bi];
              _postToSupabase('bodies', {
                'monitor_mac': mac,
                'body_type': box.size,
                'body_function': box.type,
                'position_index': bi + 1,
                'is_active': box.isActive,
              });
            }
          }

          final bool originallyMissingBrood =
              !loadedBoxes.any((b) => b.type == 'brood_box' || b.type == 'nest');

          sortHiveBoxes(loadedBoxes);

          // Konzekvens üzem: Ha a sziruptartály (ABC tartály) nem üres és nem hibás,
          // akkor a kaptár automatikusan össze van vele lőve, és az etető üzemképes (nincs üres tartály miatti letiltás)!
          final bool hasFeederOnHive = loadedBoxes.any((b) =>
              b.type == 'feeder' ||
              b.type == 'roof_feeder' ||
              b.name.toLowerCase().contains('etet'));
          final bool isTankHealthy = !_syrupPump.isPumpInterlocked &&
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

          final String rawStatus = row['status'] ??
              (swarmIdx >= 70.0
                  ? 'purple'
                  : (originallyMissingBrood ? 'yellow' : 'green'));
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
          final prevHive = existingHivesMap[mac];

          _hives.add(
            HiveData(
              id: mac,
              name: name,
              location: LatLng(37.422500 + latOffset, -122.084500 + lngOffset),
              status: prevHive?.status ?? rawStatus,
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
              evaluation: prevHive?.evaluation ?? EvaluationData(notes: notes),
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

  /// Kaptártornyok szabványosítása az adatbázisban és a helyi memóriában a felhasználói előírás alapján:
  /// - Mindegyik alul: Aljdeszka + Pollengyűjtő (dadant) + Fészekfiók (dadant)
  /// - Mézgyűjtő család: 4 db 1/2 dadant méztér + Tető
  /// - A többi család: Tetőetető (dadant) + Tető
  Future<void> standardizeAllTowersInDatabase({bool forceDbSync = true}) async {
    for (var hive in _hives) {
      final bool isHoneyColony = hive.familyFunction == 'méz' ||
          hive.familyFunction == 'gyujto_mez' ||
          hive.familyFunction == 'méztermelő' ||
          hive.name.toLowerCase().contains('méz') ||
          hive.id.endsWith('01');

      hive.boxes = createStandardBoxes(hive.id, isHoneyProducer: isHoneyColony);

      if (forceDbSync && _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
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
    notifyListeners();
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    super.dispose();
  }
}
