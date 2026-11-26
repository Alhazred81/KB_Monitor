import 'dart:convert';

import 'package:latlong2/latlong.dart';

class QueenData {
  final String id;
  final String origin;
  final String vintage;
  final bool isAlive;
  bool needsReplacement;
  final String? breeder;
  final String? motherLine;
  final String? fatherLine;

  QueenData({
    required this.id,
    required this.origin,
    required this.vintage,
    this.isAlive = true,
    this.needsReplacement = false,
    this.breeder,
    this.motherLine,
    this.fatherLine,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': origin,
    'vintage': vintage,
    'isAlive': isAlive,
    'needsReplacement': needsReplacement,
    'breeder': breeder,
    'motherLine': motherLine,
    'fatherLine': fatherLine,
  };

  factory QueenData.fromJson(Map<String, dynamic> json) => QueenData(
    id: (json['id'] ?? json['queen_number'] ?? '').toString(),
    origin: (json['origin'] ?? 'Ismeretlen').toString(),
    vintage:
        (json['vintage'] ??
                (json['birth_year'] != null
                    ? json['birth_year'].toString()
                    : '2025'))
            .toString(),
    isAlive:
        json['isAlive'] as bool? ??
        json['is_alive'] as bool? ??
        ((json['status']?.toString().toLowerCase() ?? 'aktív') != 'elveszett'),
    needsReplacement:
        json['needsReplacement'] as bool? ??
        json['needs_replacement'] as bool? ??
        false,
    breeder: json['breeder']?.toString(),
    motherLine: (json['motherLine'] ?? json['mother_line'])?.toString(),
    fatherLine: (json['fatherLine'] ?? json['father_line'])?.toString(),
  );
}

class EvaluationData {
  String gathering;
  String temperament;
  String hygiene;
  String consumption;
  String pollenCollection;
  String building;
  String propolis;
  String swarming;
  String robbing;
  String diseaseResistance;
  String miteResistance;
  String reproduction;
  String winterSurvival;
  String notes;

  EvaluationData({
    this.gathering = '0',
    this.temperament = '0',
    this.hygiene = '0',
    this.consumption = '0',
    this.pollenCollection = '0',
    this.building = '0',
    this.propolis = '0',
    this.swarming = '0',
    this.robbing = '0',
    this.diseaseResistance = '0',
    this.miteResistance = '0',
    this.reproduction = '0',
    this.winterSurvival = '0',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'gathering': gathering,
    'temperament': temperament,
    'hygiene': hygiene,
    'consumption': consumption,
    'pollenCollection': pollenCollection,
    'building': building,
    'propolis': propolis,
    'swarming': swarming,
    'robbing': robbing,
    'diseaseResistance': diseaseResistance,
    'miteResistance': miteResistance,
    'reproduction': reproduction,
    'winterSurvival': winterSurvival,
    'notes': notes,
  };

  factory EvaluationData.fromJson(Map<String, dynamic> json) => EvaluationData(
    gathering: json['gathering']?.toString() ?? '0',
    temperament: json['temperament']?.toString() ?? '0',
    hygiene: json['hygiene']?.toString() ?? '0',
    consumption: json['consumption']?.toString() ?? '0',
    pollenCollection: json['pollenCollection']?.toString() ?? '0',
    building: json['building']?.toString() ?? '0',
    propolis: json['propolis']?.toString() ?? '0',
    swarming: json['swarming']?.toString() ?? '0',
    robbing: json['robbing']?.toString() ?? '0',
    diseaseResistance: json['diseaseResistance']?.toString() ?? '0',
    miteResistance: json['miteResistance']?.toString() ?? '0',
    reproduction: json['reproduction']?.toString() ?? '0',
    winterSurvival: json['winterSurvival']?.toString() ?? '0',
    notes: json['notes']?.toString() ?? '',
  );
}

class BoxElement {
  int? dbId;
  String name;
  String code; // QR-kód
  String? secondaryCode; // NFC azonosító
  String type; // 'brood_box', 'honey', 'feeder', 'escapement', 'vent', 'pollen_trap', 'bottom', 'roof'
  String size; // 'hunor', 'nb_rakodo', 'nb_fekvo', 'fel_nb', 'lang_deep', 'lang_med', 'lang_shal', 'dadant', 'fel_dadant'
  String status; // 'green', 'yellow', 'red', 'flashing_red'
  bool isActive; // Aljdeszka bent/kint, vagy pollengyűjtő be/ki
  DateTime? statusUpdatedAt;
  int? positionIndex;
  DateTime
  updatedAt; // Utolsó módosítás időbélyege (UTC) a Last-Write-Wins szinkronhoz
  bool? _isQuarantined; // Hot-reload biztos mező (Nyúlós költésrothadás / Hans-protokoll zárlat)
  bool get isQuarantined => _isQuarantined ?? false;
  set isQuarantined(bool val) => _isQuarantined = val;

  BoxElement({
    this.dbId,
    required this.name,
    required this.code,
    this.secondaryCode,
    required this.type,
    this.size = 'dadant',
    this.status = 'green',
    this.isActive = false,
    bool this._isQuarantined = false,
    this.statusUpdatedAt,
    this.positionIndex,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BoxElement) return false;
    if (dbId != null && other.dbId != null) return dbId == other.dbId;
    return code == other.code && type == other.type;
  }

  @override
  int get hashCode =>
      dbId != null ? dbId.hashCode : (code.hashCode ^ type.hashCode);

  bool get isVarroaCheckDue {
    if (type != 'bottom' || !isActive || statusUpdatedAt == null) {
      return false;
    }
    return DateTime.now().difference(statusUpdatedAt!).inDays >= 3;
  }

  bool get isFrameBox => isFrameBoxType(type, name: name);

  /// A fiók magassága "teljes fiók" egyenértékben:
  /// - Kellékek (aljdeszka, tető, etető, szöktető, anyarács, pollengyűjtő, szellőző): 0.0
  /// - 1/2 fiókok (1/2 Dadant, 1/2 NB, 1/2 Langstroth): 0.5
  /// - Teljes fiókok (Dadant, NB, Hunor, Langstroth): 1.0
  double get fullBoxEquivalent =>
      boxFullEquivalentFor(type: type, size: size, name: name);

  Map<String, dynamic> toJson() => {
    'dbId': dbId,
    'name': name,
    'code': code,
    'secondaryCode': secondaryCode,
    'type': type,
    'size': size,
    'status': status,
    'isActive': isActive,
    'isQuarantined': isQuarantined,
    'statusUpdatedAt': statusUpdatedAt?.toIso8601String(),
    'positionIndex': positionIndex,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory BoxElement.fromJson(Map<String, dynamic> json) => BoxElement(
    dbId: (json['dbId'] as num?)?.toInt(),
    name: json['name'] as String? ?? 'Kaptárelem',
    code: json['code'] as String? ?? '',
    secondaryCode: json['secondaryCode'] as String?,
    type: json['type'] as String? ?? 'honey',
    size: json['size'] as String? ?? 'dadant',
    status: json['status'] as String? ?? 'green',
    isActive: json['isActive'] as bool? ?? false,
    isQuarantined:
        json['isQuarantined'] as bool? ??
        (json['status'] == 'quarantine' || json['status'] == 'flashing_red'),
    statusUpdatedAt: json['statusUpdatedAt'] != null
        ? DateTime.tryParse(json['statusUpdatedAt'] as String)?.toLocal()
        : null,
    positionIndex: (json['positionIndex'] as num?)?.toInt(),
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'] as String)
        : null,
  );
}

int getBoxRank(BoxElement b) {
  final t = b.type.toLowerCase();
  final n = b.name.toLowerCase();

  // Sorrend a kaptártoronyban alulról felfelé (0 = aljdeszka, 70 = tető)
  if (t == 'bottom' || n.contains('alj')) return 0;
  if (t == 'pollen_trap' || n.contains('pollen') || n.contains('virágpor'))
    return 10;
  if (t == 'brood_box' ||
      t == 'nest' ||
      n.contains('fészek') ||
      n.contains('feszek'))
    return 20;
  if (t == 'comb_builder' || n.contains('lépépít') || n.contains('lepepit'))
    return 22;
  if (t == 'queen_excluder' || n.contains('anyarács') || n.contains('anyaracs'))
    return 24;
  if (t == 'escapement' || n.contains('szöktet') || n.contains('szoktet'))
    return 25; // Alapértelmezetten a fészek felett / méztér alatt
  if (t == 'honey' || n.contains('méz') || n.contains('mez')) return 30;
  if (t == 'demaree' ||
      n.contains('szaporít') ||
      n.contains('szaporit') ||
      n.contains('demaree'))
    return 35;
  if (t == 'vent' || n.contains('szellőz') || n.contains('szelloz')) return 50;
  if (t == 'feeder' ||
      t == 'roof_feeder' ||
      n.contains('etető') ||
      n.contains('eteto'))
    return 60; // Közvetlenül a tető alatt
  if (t == 'roof' ||
      ((n.contains('tető') || n.contains('teto')) &&
          !n.contains('szöktet') &&
          !n.contains('szoktet') &&
          !n.contains('etet')) ||
      n.contains('fedő') ||
      n.contains('dekli'))
    return 70; // Legfelül
  return 35;
}

bool isBottomBox(BoxElement b) {
  final t = b.type.toLowerCase();
  final n = b.name.toLowerCase();
  return t == 'bottom' || t == '15' || n.contains('alj');
}

String _normalizeBoxToken(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ő', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ű', 'u');
}

bool isFrameBoxType(String type, {String name = ''}) {
  final t = _normalizeBoxToken(type);
  final n = _normalizeBoxToken(name);

  // 1. Minden kellék / tartozék kizárása (0.0 fiók-egyenérték)
  if (t == 'bottom' ||
      t == '15' ||
      t.contains('alj') ||
      n.contains('alj') ||
      t == 'pollen_trap' ||
      t == '11' ||
      t.contains('pollen') ||
      t.contains('viragpor') ||
      n.contains('pollen') ||
      n.contains('viragpor') ||
      t == 'feeder' ||
      t == 'roof_feeder' ||
      t == 'tetoeteto' ||
      t == '10' ||
      t.contains('etet') ||
      n.contains('etet') ||
      t == 'escapement' ||
      t == '13' ||
      t.contains('szoktet') ||
      n.contains('szoktet') ||
      t == 'queen_excluder' ||
      t.contains('anyaracs') ||
      t.contains('excluder') ||
      n.contains('anyaracs') ||
      n.contains('excluder') ||
      t == 'vent' ||
      t == '12' ||
      t.contains('szelloz') ||
      n.contains('szelloz') ||
      t == 'treatment_strip' ||
      t.contains('strip') ||
      t.contains('kezel') ||
      n.contains('kezel') ||
      t == 'roof' ||
      t == 'dekli' ||
      t == 'fedo' ||
      n == 'teto' ||
      n.contains('dekli') ||
      n.contains('fedo') ||
      (t.contains('teto') && !t.contains('szoktet') && !t.contains('etet')) ||
      (n.contains('teto') && !n.contains('szoktet') && !n.contains('etet'))) {
    return false;
  }

  // 2. Valódi keretes fiókok (fészek, lépépítő, Demaree, méztér)
  if (t == 'brood_box' ||
      t == 'broodbox' ||
      t == 'nest' ||
      t == '8' ||
      t.contains('feszek') ||
      t == 'comb_builder' ||
      t.contains('lepepit') ||
      t == 'demaree' ||
      t.contains('szaporit') ||
      t == 'honey' ||
      t == '9' ||
      t.contains('mez')) {
    return true;
  }
  return n.contains('feszek') ||
      n.contains('lepepit') ||
      n.contains('szaporit') ||
      n.contains('demaree') ||
      n.contains('mez');
}

final RegExp _halfFelTokenRegex = RegExp(
  r'(^|[^a-z])fel($|[^a-z]|dadant|nb|lang|mez|fiok)',
);

bool _matchesHalfIndicator(String raw) {
  if (raw.isEmpty) return false;
  final norm = _normalizeBoxToken(raw);
  if (norm.contains('1/2') ||
      norm.contains('½') ||
      norm.contains('1_2') ||
      norm.contains('0.5') ||
      norm.contains('0,5') ||
      norm.contains('half') ||
      norm.contains('lang_shal') ||
      norm.contains('shallow') ||
      norm.contains('alacsony')) {
    return true;
  }
  return _halfFelTokenRegex.hasMatch(norm);
}

bool isHalfBoxSize(String size, {String name = '', String type = ''}) {
  return _matchesHalfIndicator(size) ||
      _matchesHalfIndicator(name) ||
      _matchesHalfIndicator(type);
}

double boxFullEquivalentFor({
  required String type,
  required String size,
  String name = '',
}) {
  if (!isFrameBoxType(type, name: name)) return 0.0;
  return isHalfBoxSize(size, name: name, type: type) ? 0.5 : 1.0;
}

bool isRoofBox(BoxElement b) {
  final t = b.type.toLowerCase();
  final n = b.name.toLowerCase();
  if (t == 'feeder' || t == 'roof_feeder' || t == '10' || n.contains('etet')) {
    return false;
  }
  // Szigorú védelem: A "szöktető" szó tartalmazza a "tető" szórészletet, de nem tető!
  if (t == 'escapement' ||
      t == '13' ||
      n.contains('szöktet') ||
      n.contains('szoktet')) {
    return false;
  }
  return t == 'roof' ||
      n == 'tető' ||
      n == 'teto' ||
      n.contains('fedő') ||
      n.contains('dekli') ||
      ((n.contains('tető') || n.contains('teto')) &&
          !n.contains('szöktet') &&
          !n.contains('szoktet') &&
          !n.contains('etet'));
}

bool isPollenBox(BoxElement b) {
  final t = b.type.toLowerCase();
  final n = b.name.toLowerCase();
  return t == 'pollen_trap' ||
      t == '11' ||
      n.contains('pollen') ||
      n.contains('virágpor');
}

bool isFeederBox(BoxElement b) {
  final t = b.type.toLowerCase();
  final n = b.name.toLowerCase();
  return t == 'feeder' || t == 'roof_feeder' || t == '10' || n.contains('etet');
}

void sortHiveBoxes(List<BoxElement> boxes) {
  // Szigorú méhészeti szabályok:
  // 1. Kizárólag egyetlen aljdeszka és egyetlen tető (dekli) lehet a toronyban.
  // 2. Kizárólag egyetlen pollengyűjtő és egyetlen tetőetető lehet.
  // 3. A pollengyűjtő KIZÁRÓLAG közvetlenül az aljdeszkán lehet (alulról a 2. elem).
  // 4. A tetőetető KIZÁRÓLAG közvetlenül a dekli (tető) alatt lehet (felülről a 2. elem).

  bool seenRoof = false;
  bool seenBottom = false;
  bool seenPollen = false;
  bool seenFeeder = false;

  boxes.removeWhere((b) {
    if (isRoofBox(b)) {
      if (seenRoof) return true;
      seenRoof = true;
      return false;
    }
    if (isBottomBox(b)) {
      if (seenBottom) return true;
      seenBottom = true;
      return false;
    }
    if (isPollenBox(b)) {
      if (seenPollen) return true;
      seenPollen = true;
      return false;
    }
    if (isFeederBox(b)) {
      if (seenFeeder) return true;
      seenFeeder = true;
      return false;
    }
    return false;
  });

  BoxElement? bottom;
  BoxElement? pollen;
  BoxElement? feeder;
  BoxElement? roof;
  final List<BoxElement> middleBoxes = [];

  for (var b in boxes) {
    if (isBottomBox(b)) {
      bottom = b;
    } else if (isRoofBox(b)) {
      roof = b;
    } else if (isPollenBox(b)) {
      pollen = b;
    } else if (isFeederBox(b)) {
      feeder = b;
    } else {
      middleBoxes.add(b);
    }
  }

  // A köztes fiókok (fészekfiók, mézterek, szöktetőkeret, szellőző stb.) sorrendezése:
  // Ha még nincs pozíció-indexük, alapértelmezett típus-sorrendbe állítjuk.
  // Ha már van pozíció-indexük (pl. méhszöktető behelyezve egy adott fiók alá), szigorúan megtartjuk a toronysorrendet!
  final hasExplicitPositions = middleBoxes.any((b) => b.positionIndex != null);
  if (!hasExplicitPositions) {
    middleBoxes.sort((a, b) => getBoxRank(a).compareTo(getBoxRank(b)));
  } else {
    middleBoxes.sort((a, b) {
      final posA = a.positionIndex ?? 999;
      final posB = b.positionIndex ?? 999;
      return posA.compareTo(posB);
    });
  }

  boxes.clear();

  // 1. Aljdeszka legalsó elemként
  if (bottom != null) boxes.add(bottom);

  // 2. Pollengyűjtő KÖZVETLENÜL az aljdeszkán
  if (pollen != null) boxes.add(pollen);

  // 3. Fészek- és méztéri, kiegészítő fiókok
  boxes.addAll(middleBoxes);

  // 4. Tetőetető KÖZVETLENÜL a dekli (tető) alatt
  if (feeder != null) boxes.add(feeder);

  // 5. Dekli / Tető legfelső elemként
  if (roof != null) boxes.add(roof);

  // Pozíciók frissítése a rendezett sorrend alapján
  for (int i = 0; i < boxes.length; i++) {
    boxes[i].positionIndex = i;
  }
}

class FrameAnalysisRecord {
  final String id;
  final String hiveId;
  final String localImagePath;
  final DateTime capturedAt;
  final String populationEstimate;
  final int cappedBroodPct;
  final int openBroodPct;
  final int honeyPct;
  final int pollenPct;
  final int droneBroodPct;
  final bool queenDetected;
  final String queenColor;
  final int estimatedBeesCount;
  final int queenCellsCount;
  final bool queenCellsDetected;
  final String broodHealthNote;
  bool isSyncedWithCloud;
  String? cloudDetailedReport;

  FrameAnalysisRecord({
    required this.id,
    required this.hiveId,
    required this.localImagePath,
    required this.capturedAt,
    required this.populationEstimate,
    required this.cappedBroodPct,
    required this.openBroodPct,
    this.honeyPct = 0,
    this.pollenPct = 0,
    this.droneBroodPct = 0,
    this.queenDetected = false,
    this.queenColor = 'Fehér (2026)',
    this.estimatedBeesCount = 0,
    this.queenCellsCount = 0,
    this.queenCellsDetected = false,
    this.broodHealthNote = 'Szabályos',
    this.isSyncedWithCloud = false,
    this.cloudDetailedReport,
  });
}

class VarroaAnalysisRecord {
  final String id;
  final String hiveId;
  final String localImagePath;
  final DateTime capturedAt;
  int miteCount;
  int daysInserted;
  bool isSyncedWithCloud;

  VarroaAnalysisRecord({
    required this.id,
    required this.hiveId,
    required this.localImagePath,
    required this.capturedAt,
    required this.miteCount,
    this.daysInserted = 3,
    this.isSyncedWithCloud = false,
  });

  double get dailyDrop =>
      daysInserted > 0 ? miteCount / daysInserted : miteCount.toDouble();
}

class ScheduledTask {
  int? dbId;
  final String id;
  final String hiveId;
  final String category;
  final String title;
  final String description;
  final DateTime scheduledDate;
  bool isCompleted;

  ScheduledTask({
    this.dbId,
    required this.id,
    required this.hiveId,
    required this.category,
    required this.title,
    required this.description,
    required this.scheduledDate,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'dbId': dbId,
    'id': id,
    'hiveId': hiveId,
    'category': category,
    'title': title,
    'description': description,
    'scheduledDate': scheduledDate.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory ScheduledTask.fromJson(Map<String, dynamic> json) => ScheduledTask(
    dbId: (json['dbId'] as num?)?.toInt() ?? (json['id_db'] as num?)?.toInt(),
    id: (json['id'] ?? '').toString(),
    hiveId: (json['hiveId'] ?? json['monitor_mac'] ?? '').toString(),
    category: (json['category'] ?? 'altalanos').toString(),
    title: (json['title'] ?? json['treatment_type'] ?? '').toString(),
    description: (json['description'] ?? json['notes'] ?? '').toString(),
    scheduledDate:
        DateTime.tryParse(
          (json['scheduledDate'] ?? json['scheduled_date'] ?? '').toString(),
        ) ??
        DateTime.now(),
    isCompleted:
        json['isCompleted'] as bool? ?? json['is_completed'] as bool? ?? false,
  );
}

const Map<String, String> kHiveDiseaseLabels = {
  'nyulos': 'Nyúlós költésrothadás',
  'varroa': 'Varroatózis',
  'alanyassag': 'Álanyásság',
  'nozema': 'Nozematózis',
  'enyhe': 'Enyhe költésrothadás',
  'meszesedes': 'Költésmeszesedés',
  // Egyéb, kevésbé jellemző betegségek:
  'kovi': 'Kövi költés',
  'kronikus_benulas': 'Krónikus méhbénulás',
  'tomlos': 'Tömlős költésrothadás',
  'legcsoatka': 'Légcsőatka-kór',
  'dwv': 'Deformált szárny vírus',
  'szeptikemia': 'Szeptikémia / Paratífusz',
  'amoba': 'Amőbás kór',
  'teli_hasmenes': 'Téli hasmenés',
};

class HiveData {
  final String id;
  String name;
  LatLng location;
  String status;
  double temp;
  double humidity;
  double extTemp;
  double extHumidity;
  double weight;
  double batteryVoltage;
  double zcr;
  double syrupLiters;
  double swarmIndex;
  double dailyVarroaDrop;
  QueenData? queen;
  EvaluationData evaluation;
  String familyFunction;
  List<BoxElement> boxes;
  String serverConnection;
  String? protocol;
  List<String> reportedDiseases; // Lejelentett aktív betegségek azonosítói
  DateTime updatedAt; // Kaptár beállítások utolsó módosítása (UTC) a Last-Write-Wins szinkronhoz
  DateTime towerUpdatedAt; // Toronyszerkezet / fiókok utolsó módosítása (UTC) a Last-Write-Wins szinkronhoz

  double? entranceHeading; // Kaptár kijáró / repülőnyílás tájolása fokban (0 - 360°, Észak = 0°)

  String get entranceHeadingText {
    if (entranceHeading == null) return 'Nincs megadva';
    int h = entranceHeading!.round() % 360;
    if (h >= 338 || h < 23) return 'Észak ($h°)';
    if (h >= 23 && h < 68) return 'Északkelet ($h°)';
    if (h >= 68 && h < 113) return 'Kelet ($h°)';
    if (h >= 113 && h < 158) return 'Délkelet ($h°)';
    if (h >= 158 && h < 203) return 'Dél ($h°)';
    if (h >= 203 && h < 248) return 'Délnyugat ($h°)';
    if (h >= 248 && h < 293) return 'Nyugat ($h°)';
    if (h >= 293 && h < 338) return 'Északnyugat ($h°)';
    return '$h°';
  }

  // --- ETETŐ & SZIRUPADAGOLÁS BEÁLLÍTÁSOK (Csak ha van felhelyezett etető) ---
  String feedingMode; // 'off', 'manual', 'auto_stim', 'smart_sensor'
  double
  feedingMaxLiters; // Egyszerre kiadható maximum mennyiség vagy napi max keret
  int feedingIntervalHours; // Időzített serkentés időköz órában (1, 2, 3, 4, max 6 óra)
  int feedingIntervalDays; // Visszafelé kompatibilitáshoz
  int feedingStopBeforeSunsetMinutes; // Napnyugta előtt hány perccel álljon le (60, 90, 120 perc)
  double
  feedingPortionLiters; // Mikro-adag mérete smart módban (pl. 0.15 - 0.3 L)
  double feederLevelPercent; // Ultrahangos/nyomás alapú szintmérés (0 - 100%)
  int feederCalibEmptyMm; // Üres tartály távolsága a szenzortól mm-ben (0%)
  int feederCalibFullMm; // Tele tartály távolsága a szenzortól mm-ben (100%)
  int feederRawDistanceMm; // Aktuális mért ultrahang távolság mm-ben
  String _customFeederStatus;
  String get feederStatus {
    if (_customFeederStatus == 'blinking_red') return 'blinking_red';
    if (_customFeederStatus == 'orange' &&
        (isQueuedForRefill || sztojRemainingSeconds > 0)) {
      return 'orange';
    }
    if (feederLevelPercent <= 5.0) return 'red';
    if (feederLevelPercent < 20.0) return 'orange';
    if (feederLevelPercent < 50.0) return 'yellow';
    return 'green';
  }

  set feederStatus(String val) => _customFeederStatus = val;
  String? pairedTankId; // Automatikusan vagy kézzel párosított sziruptartály (pl. 'ABC tartály')
  bool
  isAutoPaired; // A szerver automatikusan összelőtte-e szintemelkedés alapján
  bool isQueuedForRefill; // Utántöltési kérelem aktív vagy sorban áll
  int
  sztojRemainingSeconds; // SZTOJ esetén hátralevő várakozási idő másodpercben
  String? feederStatusMessage; // Részletes állapot vagy hibaüzenet

  // --- ANYACSERE & LAKAT MEZŐK ---
  String? queenReplacementState; // null / 'none', 'needs_replacement', 'queen_removed', 'introduced_cage', 'introduced_chewout'
  DateTime?
  queenIntroducedAt; // Anyabehelyezés időpontja (3 napos vizsgálathoz)
  DateTime?
  lockedUntil; // Zárolás lejárati ideje (kirágós anyabeadás esetén kb. 2 hét)
  String? lockReason; // Zárolás oka (pl. 'Új anya kirágósra adva')
  bool isAcousticSentinelActive; // Fokozott akusztikai felügyelet (kirágós lakat alatt sűrített hallgatózás)
  int acousticSampleIntervalMinutes; // Mintavételezési időköz (alapesetben 60 perc, lakat alatt 15 perc)

  // --- TORONYMAGASSÁG KORLÁTOK ---
  // • 1 teljes + 4 db 1/2-Dadant fiók (= 1.0 + 4×0.5 = 3.0 teljes fiók-egyenérték) magasságig
  //   még pont NINCS szükség spaniferre!
  // • Efölött (> 3.0, pl. 1 teljes + 5–6 db 1/2-Dadant, vagy 3.5–4.0 egyenérték) minimum spanifer kell!
  // • Maximum: 4.0 teljes fiók-egyenérték (4 teljes, vagy 1 teljes + 6 db 1/2-Dadant, vagy 8 db 1/2 fiók).
  static const double kSpaniferWarningThreshold = 3.0;
  static const double kMaxFullBoxEquivalent = 4.0;

  static String formatBoxEquivalent(double value) {
    if ((value - value.roundToDouble()).abs() < 0.01) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  /// A kaptáron lévő fészek/méztér/lépépítő/szaporító fiókok összmagassága teljes fiók egyenértékben
  /// (1/2 Dadant / 1/2 NB / 1/2 Langstroth = 0.5, teljes fiók = 1.0)
  double get fullBoxEquivalentCount {
    double sum = 0.0;
    for (final b in boxes) {
      sum += b.fullBoxEquivalent;
    }
    return sum;
  }

  String get formattedBoxEquivalent =>
      formatBoxEquivalent(fullBoxEquivalentCount);

  /// 3 teljes fiók (vagy 6 db 1/2 fiók) felett minimum spaniferes rögzítés szükséges!
  bool get requiresSpanifer =>
      fullBoxEquivalentCount > kSpaniferWarningThreshold + 1e-6;

  /// Elérte-e a maximális 4 teljes fióknyi magasságot
  bool get isAtMaxBoxCapacity =>
      fullBoxEquivalentCount >= kMaxFullBoxEquivalent - 1e-6;

  bool canFitAdditionalBox(BoxElement box) {
    final added = box.fullBoxEquivalent;
    if (added <= 0.0) return true;
    return (fullBoxEquivalentCount + added) <= kMaxFullBoxEquivalent + 1e-6;
  }

  // --- NÉPESSÉG FELERŐSÍTÉS & VISSZAESÉS FIGYELÉS (Hot-reload biztos háttérmezőkkel) ---
  static const int kFreshStrengtheningCooldownDays =
      60; // 60 napig (~2 fiasítási ciklus) nem kaphat Rekorder státuszt
  DateTime? lastStrengthenedAt; // Mikor erősítettük fel utoljára fias kerettel / dajkaméhekkel
  int? _strengtheningCount; // Hányszor kellett már felerősíteni a családot
  int get strengtheningCount => _strengtheningCount ?? 0;
  set strengtheningCount(int val) => _strengtheningCount = val;

  double? weightAtStrengthening; // Felerősítés utáni induló súly a relatív visszaesés méréséhez

  bool? _hasRelapsedAfterStrengthening; // Felerősítés után ismét legyengült (tartós hiba / felkiáltójel)
  bool get hasRelapsedAfterStrengthening =>
      _hasRelapsedAfterStrengthening ?? false;
  set hasRelapsedAfterStrengthening(bool val) =>
      _hasRelapsedAfterStrengthening = val;

  String? relapseReason; // Konkrét ok (pl. elmaradás a többi család súlyától / fiasításától)

  bool? _isApiaryRekorder; // Telephelyi rangsor alapján valóban a legkiemelkedőbb (max top 20%) család-e
  bool get isApiaryRekorder => _isApiaryRekorder ?? false;
  set isApiaryRekorder(bool val) => _isApiaryRekorder = val;

  void resetEvaluation({String? newQueenId, String? reason}) {
    // Új anya ("Tiszta lap") esetén a régi anyához kötődő krónikus visszaesés törlődik,
    // minden bírálati jegy semleges ('0') alapállapotra áll, és a lastStrengthenedAt megmarad,
    // hogy frissen erősített vagy még nem bizonyított család ne lehessen Rekorder!
    hasRelapsedAfterStrengthening = false;
    relapseReason = null;
    strengtheningCount = 0;
    isApiaryRekorder = false;
    evaluation = EvaluationData(
      gathering: '0',
      temperament: '0',
      hygiene: '0',
      consumption: '0',
      pollenCollection: '0',
      building: '0',
      propolis: '0',
      swarming: '0',
      robbing: '0',
      diseaseResistance: '0',
      miteResistance: '0',
      reproduction: '0',
      winterSurvival: '0',
      notes:
          reason ?? 'Tiszta lap - új anya (${newQueenId ?? queen?.id ?? ""})',
    );
  }

  bool get wasEverStrengthened =>
      lastStrengthenedAt != null || strengtheningCount > 0;

  /// Frissen felerősített család (60 napon belül kapott fias keretet vagy dajkaméheket):
  /// nem kaphat Rekorder státuszt, mert az ereje külső segítségből származik.
  bool get isFreshlyStrengthened =>
      lastStrengthenedAt != null &&
      DateTime.now().difference(lastStrengthenedAt!).inDays <
          kFreshStrengtheningCooldownDays;

  int get strengthenedDaysAgo => lastStrengthenedAt == null
      ? 0
      : DateTime.now().difference(lastStrengthenedAt!).inDays.clamp(0, 9999);

  int get rekorderCooldownDaysRemaining => !isFreshlyStrengthened
      ? 0
      : (kFreshStrengtheningCooldownDays - strengthenedDaysAgo).clamp(
          1,
          kFreshStrengtheningCooldownDays,
        );

  /// Összehasonlítható fészeksúly (levonva a felhelyezett extra mézterek/fiókok ~2.5 kg-os súlyát),
  /// hogy a családok egymáshoz viszonyított ereje torzításmentesen mérhető legyen.
  double get comparableNestWeight {
    int extraBoxCount = 0;
    bool seenFirstBrood = false;
    for (final b in boxes) {
      if (isRoofBox(b) || isBottomBox(b) || isPollenBox(b)) continue;
      final t = b.type.toLowerCase();
      if (t == 'feeder' ||
          t == 'roof_feeder' ||
          t == 'escapement' ||
          t == 'queen_excluder' ||
          t == 'vent') {
        continue;
      }
      final bool isBrood =
          t == 'brood_box' || t == 'broodbox' || t == 'nest' || t == '8';
      if (isBrood && !seenFirstBrood) {
        seenFirstBrood = true;
        continue;
      }
      extraBoxCount++;
    }
    return (weight - (extraBoxCount * 2.5)).clamp(0.0, 500.0);
  }

  /// Valódi biológiai / minősítési gyengeség (rutin pollengyűjtő és aljdeszka időzítő nélkül)
  bool get hasIntrinsicWeakness {
    if (isQuarantined) return false; // A nyúlós karantén külön Hans-protokoll
    if (reportedDiseases.isNotEmpty) return true;
    if (status == 'red' || status == 'flashing_red' || status == 'yellow') {
      return true;
    }
    if (isQueenReplacementActive ||
        queen?.needsReplacement == true ||
        queen?.isAlive == false) {
      return true;
    }
    if (_containsWeakKeyword(name) ||
        _containsWeakKeyword(familyFunction) ||
        _containsWeakKeyword(evaluation.notes)) {
      return true;
    }
    if (_negativeEvaluationCount >= 2) return true;
    if (dailyVarroaDrop >= 3.0) return true;
    if (temp > 0.0 && temp < 32.0) return true;
    if (weight > 0.0 && weight < 24.0) return true;
    if (zcr > 0.0 && zcr < 3000.0) return true;
    return false;
  }

  /// Erősítés után ismét legyengült család (tartós probléma, felkiáltójel figyelmeztetés!)
  bool get isRelapsedAfterStrengthening =>
      !isQuarantined &&
      wasEverStrengthened &&
      (hasRelapsedAfterStrengthening || hasIntrinsicWeakness);

  bool get isQueenReplacementActive =>
      queenReplacementState == 'needs_replacement' ||
      queenReplacementState == 'queen_removed';

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  int get lockedDaysRemaining {
    if (!isLocked) return 0;
    final diff = lockedUntil!.difference(DateTime.now());
    return diff.inDays + (diff.inHours % 24 > 0 ? 1 : 0);
  }

  /// Van-e a toronyban bármilyen extra felépítmény az alap (egyetlen) fészekfiókon felül
  /// (pl. méztér, lépépítő, Demaree, plusz fészekfiók, tetőetető, szöktető, anyarács, szellőző).
  /// Szigorú méhészeti szabály: Családot kizárólag akkor vizsgálunk vagy kezelünk,
  /// ha nincs fenn egyetlen extra felépítmény sem!
  bool get hasExtraBoxes {
    int broodCount = 0;
    for (final b in boxes) {
      if (isRoofBox(b) || isBottomBox(b) || isPollenBox(b)) continue;
      final t = b.type.toLowerCase();
      final n = b.name.toLowerCase();
      if (t == 'treatment_strip' ||
          n.contains('kezelőlap') ||
          n.contains('kezelolap')) {
        continue;
      }
      final bool isBrood =
          t == 'brood_box' ||
          t == 'broodbox' ||
          t == 'nest' ||
          t == '8' ||
          n.contains('fészek') ||
          n.contains('feszek');
      if (isBrood) {
        broodCount++;
        if (broodCount > 1) return true;
        continue;
      }
      return true;
    }
    return false;
  }

  String get lockedUntilFormatted {
    if (lockedUntil == null) return '';
    return '${lockedUntil!.year}.${lockedUntil!.month.toString().padLeft(2, '0')}.${lockedUntil!.day.toString().padLeft(2, '0')}';
  }

  double calculateLevelFromDistance(int distanceMm) {
    if (feederCalibEmptyMm <= feederCalibFullMm) return 0.0;
    double pct =
        ((feederCalibEmptyMm - distanceMm) /
            (feederCalibEmptyMm - feederCalibFullMm)) *
        100.0;
    return pct.clamp(0.0, 100.0);
  }

  // Szenzoralapú intelligens serkentési ablak ellenőrzése
  bool isSmartFeedingAllowedNow({
    double currentLux = 15000.0,
    double ambientTemp = 20.0,
    DateTime? now,
  }) {
    if (feedingMode != 'smart_sensor') return false;
    final currentTime = now ?? DateTime.now();

    // 1. Hidegben a méhek nem hordanak szirupot (dermedés veszélye)
    if (ambientTemp < 14.0) return false;

    // 2. Szürkület / fényszint védelem: ha a fény 2500 Lux alá esik, leállás
    if (currentLux < 2500.0) return false;

    final int totalMinutes = currentTime.hour * 60 + currentTime.minute;

    // 3. Reggeli aktiválódás: reggel 7:30 előtt még alszik a család
    if (totalMinutes < 7 * 60 + 30) return false;

    // 4. Szigorú lezárás napnyugta előtt (1-2 órával előbb STOP, hogy ne maradjon szirup éjszakára)
    // Átlagos tavaszi/nyári naplemente: ~19:45 (1185 perc)
    final int estimatedSunsetMinutes = 19 * 60 + 45;
    final int cutoffMinutes =
        estimatedSunsetMinutes - feedingStopBeforeSunsetMinutes;

    if (totalMinutes >= cutoffMinutes) {
      return false; // Napnyugta előtt 1-2 órával leállítva!
    }

    return true;
  }

  bool get hasFeeder => boxes.any(
    (b) =>
        b.type == 'feeder' ||
        b.type == 'roof_feeder' ||
        b.name.toLowerCase().contains('etető') ||
        b.name.toLowerCase().contains('eteto'),
  );

  bool get hasHoneySuper => boxes.any(
    (b) =>
        b.type == 'honey' ||
        b.type == '9' ||
        b.name.toLowerCase().contains('méz') ||
        b.name.toLowerCase().contains('mez'),
  );

  /// Nyúlós költésrothadás / Hans-protokoll miatti szigorú hatósági zárlat.
  /// SZIGORÚ SZABÁLY: A TELJES TORONY (minden fiók, keret, mézkészlet, aljdeszka, etető)
  /// KARANTÉN ZÁRLAT ALATT ÁLL: semmi nem vihető át belőle másik kaptárba vagy a feldolgozóba!
  bool get isQuarantined =>
      reportedDiseases.contains('nyulos') ||
      protocol?.toLowerCase() == 'hans' ||
      familyFunction.toLowerCase() == 'hans' ||
      (status == 'flashing_red' &&
          familyFunction.toLowerCase().contains('hans')) ||
      boxes.any((b) => b.isQuarantined);

  bool get isTowerQuarantined => isQuarantined;

  bool get hasActivePollenTrap => boxes.any(
    (b) =>
        (b.type == 'pollen_trap' ||
            b.type == '11' ||
            b.name.toLowerCase().contains('pollen') ||
            b.name.toLowerCase().contains('virágpor')) &&
        b.isActive,
  );
  BoxElement? get feederBox => boxes.cast<BoxElement?>().firstWhere(
    (b) =>
        b != null &&
        (b.type == 'feeder' ||
            b.type == 'roof_feeder' ||
            b.name.toLowerCase().contains('etető')),
    orElse: () => null,
  );

  HiveData({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    required this.temp,
    required this.humidity,
    this.extTemp = 20.0,
    this.extHumidity = 50.0,
    required this.weight,
    required this.batteryVoltage,
    required this.zcr,
    this.syrupLiters = 0.0,
    this.swarmIndex = 0.0,
    this.dailyVarroaDrop = 0.0,
    this.queen,
    EvaluationData? evaluation,
    this.familyFunction = 'gyujto_mez',
    required this.boxes,
    this.serverConnection = '',
    this.protocol,
    this.entranceHeading = 180.0,
    this.feedingMode = 'off',
    this.feedingMaxLiters = 1.0,
    this.feedingIntervalHours = 6,
    this.feedingIntervalDays = 1,
    this.feedingStopBeforeSunsetMinutes = 90,
    this.feedingPortionLiters = 0.2,
    this.feederLevelPercent = 45.0,
    this.feederCalibEmptyMm = 200,
    this.feederCalibFullMm = 30,
    this.feederRawDistanceMm = 120,
    String feederStatus = 'green',
    this.pairedTankId = 'ABC tartály',
    this.isAutoPaired = false,
    this.isQueuedForRefill = false,
    this.sztojRemainingSeconds = 0,
    this.feederStatusMessage,
    this.queenReplacementState,
    this.queenIntroducedAt,
    this.lockedUntil,
    this.lockReason,
    this.isAcousticSentinelActive = false,
    this.acousticSampleIntervalMinutes = 60,
    this.lastStrengthenedAt,
    int this._strengtheningCount = 0,
    this.weightAtStrengthening,
    bool this._hasRelapsedAfterStrengthening = false,
    this.relapseReason,
    bool this._isApiaryRekorder = false,
    List<String>? reportedDiseases,
    DateTime? updatedAt,
    DateTime? towerUpdatedAt,
  }) : _customFeederStatus = feederStatus,
       reportedDiseases = reportedDiseases != null
           ? List<String>.from(reportedDiseases)
           : <String>[],
       updatedAt = updatedAt ?? DateTime.now().toUtc(),
       towerUpdatedAt = towerUpdatedAt ?? DateTime.now().toUtc(),
       evaluation = evaluation ?? EvaluationData();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveData && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  String get tempStatus {
    if (temp >= 32.0 && temp <= 36.0) return 'green';
    if ((temp >= 28.0 && temp < 32.0) || (temp > 36.0 && temp <= 37.5)) {
      return 'yellow';
    }
    if (temp > 39.0 || temp < 15.0) return 'flashing_red';
    return 'red';
  }

  String get extTempStatus {
    if (extTemp >= 12.0 && extTemp <= 30.0) return 'green';
    if ((extTemp >= 5.0 && extTemp < 12.0) ||
        (extTemp > 30.0 && extTemp <= 35.0)) {
      return 'yellow';
    }
    if (extTemp < -5.0 || extTemp > 38.0) return 'flashing_red';
    return 'red';
  }

  String get weightStatus {
    if (weight >= 30.0) return 'green';
    if (weight >= 20.0) return 'yellow';
    if (weight < 12.0) return 'flashing_red';
    return 'red';
  }

  bool get isMicHardwareOk => zcr > 0;

  String get micHardwareStatus => isMicHardwareOk ? 'OK' : 'HIBA';

  // A család akusztikai állapota a méhzúgás frekvenciája alapján:
  String get acousticColonyStatus {
    if (zcr <= 0) return 'red'; // Hardverhiba / nincs jel
    if (zcr >= 3000.0 && zcr <= 4200.0)
      return 'green'; // Nyugodt, egészséges méhzúgás
    if (zcr > 4200.0 && zcr <= 4700.0)
      return 'yellow'; // Emelkedett zúgás: rajzáskészültség / anyaprobléma
    if (zcr > 4700.0)
      return 'flashing_red'; // Heves méhzúgás: akut rajzás vagy pánik
    return 'yellow'; // < 3000 Hz: kórosan halk / lelassult család
  }

  String get micStatus => acousticColonyStatus;

  String get signalStatus {
    final lower = serverConnection.toLowerCase();
    if (lower.contains('ok') ||
        lower.contains('párosítva') ||
        lower.contains('supabase')) {
      return 'green';
    }
    if (lower.contains('gyenge')) return 'yellow';
    if (lower.contains('kritikus') || lower.contains('hiba')) {
      return 'flashing_red';
    }
    return 'red';
  }

  String get batteryStatus {
    if (batteryVoltage >= 3.8) return 'green';
    if (batteryVoltage >= 3.55) return 'yellow';
    if (batteryVoltage < 3.4) return 'flashing_red';
    return 'red';
  }

  String get varroaStatus {
    if (dailyVarroaDrop >= 5.0) return 'red';
    if (dailyVarroaDrop >= 2.0) return 'yellow';
    return 'green';
  }

  String get nestCalculatedStatus {
    if (status == 'flashing_red' || protocol == 'hans') return 'flashing_red';
    final statuses = [
      tempStatus,
      weightStatus,
      micStatus,
      signalStatus,
      batteryStatus,
      varroaStatus,
      if (queen?.needsReplacement == true) 'yellow',
      if (boxes.any((b) => b.isVarroaCheckDue)) 'yellow',
    ];
    if (statuses.contains('flashing_red')) return 'flashing_red';
    if (statuses.contains('red')) return 'red';
    if (statuses.contains('yellow')) return 'yellow';
    return 'green';
  }

  String get worstStatus {
    if (isQuarantined) return 'flashing_red'; // Teljes torony karantén (Nyúlós költésrothadás / Hans)
    if (isQueenReplacementActive)
      return 'red'; // Anyacsere esetén azonnali sürgős piros kaptár
    if (reportedDiseases.contains('varroa') ||
        reportedDiseases.contains('alanyassag') ||
        reportedDiseases.contains('nozema') ||
        reportedDiseases.contains('kovi') ||
        reportedDiseases.contains('kronikus_benulas') ||
        reportedDiseases.contains('szeptikemia')) {
      return 'red';
    }
    if (isLocked && acousticColonyStatus != 'green') {
      // Kirágós lakat alatt azonnali riasztás, ha az akusztikai monitor rendellenes zúgást észlel
      return acousticColonyStatus == 'flashing_red' ? 'flashing_red' : 'red';
    }
    if (status == 'flashing_red' || protocol == 'hans') return 'flashing_red';
    if (status == 'purple' || swarmIndex >= 70.0) return 'purple';
    if (status == 'red') return 'red';
    if (reportedDiseases.contains('enyhe') ||
        reportedDiseases.contains('tomlos') ||
        reportedDiseases.contains('legcsoatka') ||
        reportedDiseases.contains('dwv') ||
        boxes.any((b) => b.type == 'pollen_trap' && b.isActive)) {
      return 'orange';
    }

    final statuses = [
      status,
      nestCalculatedStatus,
      extTempStatus,
      if (isRelapsedAfterStrengthening) 'orange',
      if (isWeakOrSick || reportedDiseases.isNotEmpty) 'yellow',
      for (var box in boxes) box.status,
    ];
    if (statuses.contains('flashing_red')) return 'flashing_red';
    if (statuses.contains('red')) return 'red';
    if (statuses.contains('orange')) return 'orange';
    if (statuses.contains('yellow')) return 'yellow';
    return 'green';
  }

  int get positiveEvaluationCount {
    int plusCount = 0;
    final ev = evaluation;
    for (final val in [
      ev.gathering,
      ev.temperament,
      ev.hygiene,
      ev.pollenCollection,
      ev.building,
      ev.diseaseResistance,
      ev.miteResistance,
      ev.reproduction,
      ev.winterSurvival,
    ]) {
      if (val.contains('+')) plusCount++;
    }
    return plusCount;
  }

  /// Egyedi jogosultság a Rekorder címre (még a telephelyi top-rangsorolás előtt)
  bool get isRekorderEligible {
    if (isFreshlyStrengthened || isRelapsedAfterStrengthening) return false;
    if (isQuarantined || reportedDiseases.isNotEmpty) return false;
    if (isLocked || isQueenReplacementActive) return false;
    if (evaluation.notes.toLowerCase().contains('tiszta lap')) return false;
    if (status != 'green' && status != 'optimal') return false;
    if (worstStatus != 'green') return false;
    if (isWeakOrSick) return false;
    if (queen?.needsReplacement == true) return false;
    if (dailyVarroaDrop >= 2.0) return false;
    if (swarmIndex >= 40.0) return false;
    if (temp < 33.0 || temp > 36.5) return false;
    if (weight < 30.0) return false;
    if (_negativeEvaluationCount > 0) return false;
    if (!evaluation.gathering.contains('+')) return false;
    return positiveEvaluationCount >= 3;
  }

  /// Folyamatosan kiemelkedően teljesítő (Rekorder) család:
  /// Csak az egyedileg hibátlan, kifejezetten '+' gyűjtési/tenyészbírálatú, nem frissen erősített,
  /// ÉS a telephely átlagát súlyban is felülmúló legelső (max. top 20%) család kaphatja meg!
  bool get isTopPerformer => isRekorderEligible && isApiaryRekorder;

  /// Rosszul teljesítő (Poor Performer) család:
  /// A kaptár sarkába piros lefelé nyíl (🔻) kerül (kivéve ha erősítés után visszaesett, mert akkor felkiáltójel ❗ jelenik meg)
  bool get isPoorPerformer {
    if (isRelapsedAfterStrengthening) return true;
    if (isQuarantined || reportedDiseases.isNotEmpty) return true;
    if (isWeakOrSick) return true;
    if (status == 'red' || status == 'flashing_red') return true;
    if (worstStatus == 'red' || worstStatus == 'flashing_red') return true;
    if (familyFunction.toLowerCase().contains('selejt') ||
        familyFunction.toLowerCase().contains('hans')) {
      return true;
    }
    if (dailyVarroaDrop >= 3.0) return true;
    if (weight > 0 && weight < 20.0) return true;
    if (temp > 0 && temp < 32.0) return true;
    if (queen?.needsReplacement == true) return true;

    // Értékelési szempontok negatívjai
    int minusCount = 0;
    final ev = evaluation;
    for (var val in [
      ev.gathering,
      ev.temperament,
      ev.hygiene,
      ev.pollenCollection,
      ev.building,
      ev.diseaseResistance,
      ev.miteResistance,
      ev.reproduction,
      ev.winterSurvival,
    ]) {
      if (val.contains('-')) minusCount++;
    }
    return minusCount >= 2;
  }

  // --- GYENGE / BETEG CSALÁD DETEKTÁLÁSA (BŐVÍTÉS ÉS MEGCSAPOLÁS VÉDELEM) ---
  static bool _containsWeakKeyword(String text) {
    final t = text.toLowerCase();
    return t.contains('beteg') ||
        t.contains('gyenge') ||
        t.contains('gyengélked') ||
        t.contains('gyengelked') ||
        t.contains('selejt') ||
        t.contains('felszámol') ||
        t.contains('felszamol') ||
        t.contains('karantén') ||
        t.contains('karanten') ||
        t.contains('mentés') ||
        t.contains('mentes') ||
        t.contains('szezon végén') ||
        t.contains('szezon vegen') ||
        t.contains('hans') ||
        t.contains('anyacsere') ||
        t.contains('anyátlan') ||
        t.contains('anyatlan') ||
        t.contains('álanyás') ||
        t.contains('alanyas') ||
        t.contains('atkás') ||
        t.contains('atkas') ||
        t.contains('nozém') ||
        t.contains('nozem') ||
        t.contains('pótcsalád') ||
        t.contains('potcsalad');
  }

  int get _negativeEvaluationCount {
    int minusCount = 0;
    final ev = evaluation;
    for (final val in [
      ev.gathering,
      ev.temperament,
      ev.hygiene,
      ev.pollenCollection,
      ev.building,
      ev.diseaseResistance,
      ev.miteResistance,
      ev.reproduction,
      ev.winterSurvival,
    ]) {
      if (val.contains('-')) minusCount++;
    }
    return minusCount;
  }

  bool get isWeakOrSick {
    if (isRelapsedAfterStrengthening) return true;
    if (isQuarantined || reportedDiseases.isNotEmpty) return true;

    // 1. Státuszkódok (Piros, Villogó piros, Narancs, Sárga gyenge állapot)
    if (status == 'red' ||
        status == 'flashing_red' ||
        status == 'orange' ||
        status == 'yellow') {
      return true;
    }
    if (nestCalculatedStatus == 'red' ||
        nestCalculatedStatus == 'flashing_red' ||
        nestCalculatedStatus == 'orange' ||
        nestCalculatedStatus == 'yellow') {
      return true;
    }

    // 2. Mentési / megsemmisítési protokoll és anyaprobléma
    if (protocol == 'hans' ||
        protocol?.toLowerCase().contains('hans') == true) {
      return true;
    }
    if (isQueenReplacementActive ||
        queen?.needsReplacement == true ||
        queen?.isAlive == false) {
      return true;
    }

    // 3. Kaptár neve, családfunkció és értékelési megjegyzések (ékezettel és anélkül is)
    if (_containsWeakKeyword(name) ||
        _containsWeakKeyword(familyFunction) ||
        _containsWeakKeyword(evaluation.notes)) {
      return true;
    }

    // 4. Kedvezőtlen egyedi elbírálás (legalább 2 negatív tulajdonság)
    if (_negativeEvaluationCount >= 2) return true;

    // 5. Szenzormérések és biológiai paraméterek
    if (dailyVarroaDrop >= 3.0) return true;
    if (temp > 0.0 && temp < 32.0) return true;
    if (weight > 0.0 && weight < 20.0) return true;

    // 6. Család toronyszerkezete: ha nincs valódi fészekfiókja
    final broodBoxes = boxes.where(
      (b) => b.type == 'brood_box' || b.type == 'nest',
    );
    if (broodBoxes.isEmpty) return true;

    return false;
  }

  String get weakOrSickReason {
    final reasons = <String>[];
    if (isRelapsedAfterStrengthening) {
      reasons.add(
        relapseReason != null && relapseReason!.isNotEmpty
            ? '❗ Felerősítés után ismét legyengült ($relapseReason) – tartós probléma gyanúja!'
            : '❗ Felerősítés után ismét legyengült a többi családhoz képest – tartós probléma gyanúja!',
      );
    }
    if (reportedDiseases.isNotEmpty) {
      final names = reportedDiseases
          .map((id) => kHiveDiseaseLabels[id] ?? id)
          .join(', ');
      reasons.add('Lejelentett betegség: $names');
    }
    if (status == 'flashing_red' || nestCalculatedStatus == 'flashing_red') {
      reasons.add('Kritikus riasztás / vészhelyzet');
    } else if (status == 'red' || nestCalculatedStatus == 'red') {
      reasons.add('Veszélyeztetett állapot (piros riasztás)');
    } else if (status == 'orange' || nestCalculatedStatus == 'orange') {
      reasons.add('Narancs (gyengült / kezelést igénylő) státusz');
    } else if (status == 'yellow' || nestCalculatedStatus == 'yellow') {
      reasons.add('Sárga (gyenge / beavatkozást igénylő) státusz');
    }
    if (protocol == 'hans' ||
        protocol?.toLowerCase().contains('hans') == true ||
        familyFunction.toLowerCase() == 'hans') {
      reasons.add(
        'Hans-protokoll: Azonnali teljes megsemmisítés / elpusztítás!',
      );
    }
    if (isQueenReplacementActive ||
        queen?.needsReplacement == true ||
        queen?.isAlive == false) {
      reasons.add('Anyaprobléma / anyacsere folyamatban');
    }
    if (familyFunction.toLowerCase().contains('selejt')) {
      reasons.add(
        'Selejt család (Szezon végén más családok felerősítésére használható)',
      );
    }
    final nm = name.toLowerCase();
    if (nm.contains('beteg') ||
        nm.contains('gyenge') ||
        nm.contains('pótcsalád') ||
        nm.contains('potcsalad')) {
      reasons.add('Megnevezés: Gyenge család');
    } else if (nm.contains('felszámol') || nm.contains('felszamol')) {
      reasons.add('Megnevezés: Felszámolás alatt álló család');
    }
    final fn = familyFunction.toLowerCase();
    if (fn.contains('beteg')) {
      reasons.add('Gyenge kondíciójú család');
    } else if (fn.contains('gyenge')) {
      reasons.add('Gyenge termelőképességű család');
    } else if (fn.contains('felszámol') ||
        fn.contains('felszamol') ||
        fn.contains('szezon végén') ||
        fn.contains('szezon vegen')) {
      reasons.add('Felszámolás alatt áll');
    }
    final evNotes = evaluation.notes.toLowerCase();
    if (_containsWeakKeyword(evNotes)) {
      reasons.add('Értékelési megjegyzés: Gyenge család');
    }
    if (_negativeEvaluationCount >= 2) {
      reasons.add(
        'Kedvezőtlen egyedi elbírálás ($_negativeEvaluationCount negatív jegy)',
      );
    }
    if (dailyVarroaDrop >= 3.0) {
      reasons.add(
        'Megnövekedett atkahullás (${dailyVarroaDrop.toStringAsFixed(1)} db/nap)',
      );
    }
    if (temp > 0.0 && temp < 32.0) {
      reasons.add(
        'Alacsony fészekhőmérséklet (${temp.toStringAsFixed(1)} °C, fiasítás kihűlés veszélye)',
      );
    }
    if (weight > 0.0 && weight < 20.0) {
      reasons.add(
        'Alacsony kaptársúly (${weight.toStringAsFixed(1)} kg, éhezés veszély)',
      );
    }
    final broodBoxes = boxes.where(
      (b) => b.type == 'brood_box' || b.type == 'nest',
    );
    if (broodBoxes.isEmpty) {
      reasons.add('Hiányzó fészekfiók (nem termelőképes család)');
    }
    if (reasons.isEmpty) {
      return 'Gyenge vagy veszélyeztetett állapot.';
    }
    return reasons.join(', ');
  }

  /// Értelmezhető, konkrét egészségi / állapot leírás (kerüli az általános "beteg/gyenge" kifejezést)
  String get specificHealthDescription {
    if (isQuarantined) {
      return '⚠️ TELJES TORONY KARANTÉN (Nyúlós költésrothadás / Hans-protokoll)! Szigorúan tilos bármilyen elemet átvinni máshova!';
    }
    if (isRelapsedAfterStrengthening) {
      final detail = (relapseReason != null && relapseReason!.isNotEmpty)
          ? ' ($relapseReason)'
          : '';
      return '❗ Visszaesett család: felerősítés után ismét legyengült a többihez képest$detail – nem egyszeri lemaradás, rejtett hiba (pl. anyaprobléma / betegség) gyanúja!';
    }
    if (reportedDiseases.isNotEmpty) {
      final names = reportedDiseases
          .map((id) => kHiveDiseaseLabels[id] ?? id)
          .join(', ');
      return 'Lejelentett betegség: $names';
    }
    if (protocol == 'hans' ||
        protocol?.toLowerCase().contains('hans') == true ||
        familyFunction.toLowerCase() == 'hans') {
      return 'Hans-protokoll: Azonnali teljes megsemmisítés / elpusztítás!';
    }
    if (familyFunction.toLowerCase().contains('selejt')) {
      return 'Selejt család (Szezon végén felerősítésre használható)';
    }
    if (dailyVarroaDrop >= 3.0) {
      return 'Magas atkafertőzöttség: Varroatózis (${dailyVarroaDrop.toStringAsFixed(1)} db/nap)';
    }
    if (temp > 0.0 && temp < 32.0) {
      return 'Fészek-kihűlés veszélye (${temp.toStringAsFixed(1)} °C)';
    }
    if (weight > 0.0 && weight < 20.0) {
      return 'Éhezésveszély (${weight.toStringAsFixed(1)} kg élelem)';
    }
    if (queen?.needsReplacement == true) {
      return 'Anyaprobléma: Anyacsere esedékes';
    }
    if (boxes.any((b) => b.isVarroaCheckDue)) {
      return 'Atkaellenőrzés esedékes (aljdeszka leolvasás)';
    }
    final fn = familyFunction.toLowerCase();
    if (fn.contains('karanten')) {
      return 'Karantén alatt álló család';
    }
    if (fn.contains('felszamol')) {
      return 'Felszámolás alatt álló család';
    }
    final evNotes = evaluation.notes.trim();
    if (evNotes.isNotEmpty &&
        !evNotes.toLowerCase().contains('beteg / gyenge') &&
        !evNotes.toLowerCase().contains('beteg/gyenge')) {
      return evNotes;
    }
    return 'Gyenge család (fejlődési lemaradás / kis népesség)';
  }
}

class StationData {
  final String id;
  final String name;
  LatLng location;
  final double temp;
  final double humidity;
  final double pressure;
  final double uvIndex;
  final double lightLux;
  final double windSpeed;
  final String windDirection;
  final double rainAmount;
  final double batteryVoltage;
  String status; // 'green': Supabase kapcsolat OK, 'red': Nincs kapcsolat

  bool get isOnline => status == 'green';

  StationData({
    required this.id,
    required this.name,
    required this.location,
    required this.temp,
    required this.humidity,
    required this.pressure,
    required this.uvIndex,
    required this.lightLux,
    required this.windSpeed,
    required this.windDirection,
    required this.rainAmount,
    required this.batteryVoltage,
    this.status = 'green',
  });
}

class WatererData {
  final String id;
  final String name;
  LatLng location;
  double waterLevel; // Vízszint % (0.0 - 100.0)
  double waterTemp; // Vízhőmérséklet (°C)
  final double batteryVoltage;
  bool isInterlocked; // Vészleállítás / kézi vagy automata reteszelés
  String? emergencyStopReason;
  String _customStatus;

  String get status {
    if (isInterlocked || _customStatus == 'blinking_red') {
      return 'blinking_red';
    }
    // Fagyveszély: 1.0 °C vagy alatti vízhőmérséklet esetén azonnali vészleállítás és fagyvédelmi jelzés
    if (waterTemp <= 1.0) {
      return 'blinking_red';
    }
    // Kritikus feszültség: 3.3V alatt lemerült akku vészjelzés
    if (batteryVoltage < 3.3) {
      return 'blinking_red';
    }
    if (_customStatus == 'orange') return 'orange';
    if (waterLevel <= 5.0) return 'red'; // Kiszáradt / üres itató
    if (waterLevel < 25.0)
      return 'orange'; // Alacsony szint / utántöltést igényel
    if (waterLevel < 50.0) return 'yellow'; // Közepes szint
    return 'green'; // Optimális szint
  }

  set status(String val) => _customStatus = val;

  WatererData({
    required this.id,
    required this.name,
    required this.location,
    required this.waterLevel,
    required this.waterTemp,
    required this.batteryVoltage,
    String status = 'green',
    this.isInterlocked = false,
    this.emergencyStopReason,
  }) : _customStatus = status;
}

class SyrupPumpData {
  final String id;
  final String name;
  LatLng location;
  double totalPumpedLiters;
  String lastOperationStatus;
  bool isPumpInterlocked; // Villogó piros esetén a szivattyú indítása szigorúan TILTVA
  String? emergencyStopReason;
  List<String> pairedHiveNames;
  double tankLevelPercent; // Valós idejű szenzoros szintmérés (%)
  double tankCapacityLiters; // Tartály névleges összkapacitása (L)
  String _customStatus;

  String get status {
    if (isPumpInterlocked || _customStatus == 'blinking_red') {
      return 'blinking_red';
    }
    if (_customStatus == 'orange' &&
        (lastOperationStatus.contains('SZTOJ') ||
            lastOperationStatus.contains('Adagolás'))) {
      return 'orange';
    }
    if (tankLevelPercent <= 5.0) return 'red';
    if (tankLevelPercent < 20.0) return 'orange';
    if (tankLevelPercent < 50.0) return 'yellow';
    return 'green';
  }

  set status(String val) => _customStatus = val;

  SyrupPumpData({
    required this.id,
    required this.name,
    required this.location,
    required this.totalPumpedLiters,
    required this.lastOperationStatus,
    String status = 'green',
    this.isPumpInterlocked = false,
    this.emergencyStopReason,
    List<String>? pairedHiveNames,
    this.tankLevelPercent = 88.0,
    this.tankCapacityLiters = 100.0,
  }) : _customStatus = status,
       pairedHiveNames = pairedHiveNames ?? [];
}

// ============================================================================
// CSALÁDFUNKCIÓ ↔ FIÓK / ZUBEHÖR (KELLÉK) KOMPATIBILITÁSI SZABÁLYRENDSZER
// ============================================================================

class FamilyFunctionBoxMismatch {
  final String functionLabel;
  final String elementLabel;
  final String badgeText;
  final String primaryMessage;
  final String explanation;

  const FamilyFunctionBoxMismatch({
    required this.functionLabel,
    required this.elementLabel,
    required this.badgeText,
    required this.primaryMessage,
    required this.explanation,
  });
}

/// Normalizált családfunkció kategória:
/// 'honey' | 'pollen' | 'propolis' | 'nurse' | 'breeder' | 'drone_breeder' | 'donor' | 'reserve' | 'cull' | 'hans' | 'other'
String normalizeHiveFamilyFunctionCategory(String rawFunc) {
  final f = _normalizeBoxToken(rawFunc);
  if (f.isEmpty ||
      f == 'mez' ||
      f == 'gyujto_mez' ||
      f.contains('meztermel') ||
      f.contains('gyujto')) {
    return 'honey';
  }
  if (f.contains('hans')) return 'hans';
  if (f.contains('pollen') || f.contains('viragpor')) return 'pollen';
  if (f.contains('propolisz')) return 'propolis';
  if (f.contains('dajka') ||
      f.contains('starter') ||
      f.contains('pempo') ||
      f.contains('anyanevel')) {
    return 'nurse';
  }
  if (f.contains('apacsalad') || f.contains('herenevel')) {
    return 'drone_breeder';
  }
  if (f.contains('donor')) return 'donor';
  if (f.contains('torzs') || f == 'anya' || f.contains('anyacsalad')) {
    return 'breeder';
  }
  if (f.contains('tartalek') || f == 'raj' || f.contains('szaporulat')) {
    return 'reserve';
  }
  if (f.contains('selejt') ||
      f.contains('felszamol') ||
      f.contains('egyesit')) {
    return 'cull';
  }
  return 'other';
}

String getHiveFamilyFunctionLabel(String rawFunc) {
  switch (normalizeHiveFamilyFunctionCategory(rawFunc)) {
    case 'honey':
      return 'Méztermelés';
    case 'pollen':
      return 'Virágporgyűjtés';
    case 'propolis':
      return 'Propolisztermelés';
    case 'nurse':
      return 'Dajkacsalád / Anyanevelés';
    case 'breeder':
      return 'Törzscsalád (Tenyészanyag)';
    case 'drone_breeder':
      return 'Apacsalád (Herenevelés)';
    case 'donor':
      return 'Donor család';
    case 'reserve':
      return 'Tartalék / Raj';
    case 'cull':
      return 'Selejt család';
    case 'hans':
      return 'Hans-protokoll (Zárlat)';
    default:
      return rawFunc.trim().isNotEmpty ? rawFunc.trim() : 'Egyedi feladat';
  }
}

String canonicalizeHiveElementType(String rawType, {String rawName = ''}) {
  final t = _normalizeBoxToken(rawType);
  final n = _normalizeBoxToken(rawName);
  if (t == 'bottom' || t == '15' || t.contains('alj') || n.contains('alj')) {
    return 'bottom';
  }
  if (t == 'escapement' ||
      t == '13' ||
      t.contains('szoktet') ||
      n.contains('szoktet')) {
    return 'escapement';
  }
  if (t == 'feeder' ||
      t == 'roof_feeder' ||
      t == 'tetoeteto' ||
      t == '10' ||
      t.contains('etet') ||
      n.contains('etet')) {
    return 'feeder';
  }
  if (t == 'pollen_trap' ||
      t == '11' ||
      t.contains('pollen') ||
      t.contains('viragpor') ||
      n.contains('pollen') ||
      n.contains('viragpor')) {
    return 'pollen_trap';
  }
  if (t == 'queen_excluder' ||
      t.contains('anyaracs') ||
      t.contains('excluder') ||
      n.contains('anyaracs') ||
      n.contains('excluder')) {
    return 'queen_excluder';
  }
  if (t == 'vent' || t == '12' || t.contains('szelloz') || n.contains('szelloz')) {
    return 'vent';
  }
  if (t == 'treatment_strip' || t.contains('strip') || t.contains('kezel')) {
    return 'treatment_strip';
  }
  if (t == 'roof' ||
      t == 'dekli' ||
      t == 'fedo' ||
      n == 'teto' ||
      n.contains('dekli') ||
      (t.contains('teto') && !t.contains('szoktet') && !t.contains('etet')) ||
      (n.contains('teto') && !n.contains('szoktet') && !n.contains('etet'))) {
    return 'roof';
  }
  if (t == 'comb_builder' || t.contains('lepepit') || n.contains('lepepit')) {
    return 'comb_builder';
  }
  if (t == 'demaree' ||
      t.contains('szaporit') ||
      n.contains('szaporit') ||
      n.contains('demaree')) {
    return 'demaree';
  }
  if (t == 'brood_box' ||
      t == 'broodbox' ||
      t == 'nest' ||
      t == '8' ||
      t.contains('feszek') ||
      n.contains('feszek')) {
    return 'brood_box';
  }
  if (t == 'honey' || t == '9' || t.contains('mez') || n.contains('mez')) {
    return 'honey';
  }
  return t;
}

String _defaultElementDisplayName(String canonicalType, String fallback) {
  switch (canonicalType) {
    case 'honey':
      return 'Méztéri fiók';
    case 'brood_box':
      return 'Plusz fészekfiók';
    case 'comb_builder':
      return 'Lépépítő fiók';
    case 'demaree':
      return 'Szaporító (Demaree) fiók';
    case 'feeder':
      return 'Tetőetető';
    case 'escapement':
      return 'Méhszöktető';
    case 'queen_excluder':
      return 'Anyarács';
    case 'pollen_trap':
      return 'Virágporgyűjtő';
    default:
      return fallback.trim().isNotEmpty ? fallback.trim() : canonicalType;
  }
}

/// Ellenőrzi, hogy a felhelyezendő / aktiválandó fiók vagy kellék (zubehör) összeillik-e
/// a család aktuális feladatával (`familyFunction`). Ha nem illik össze, részletes
/// méhészeti figyelmeztetést ad vissza; ha megfelelő, `null`-t ad vissza.
FamilyFunctionBoxMismatch? evaluateFamilyFunctionBoxMismatch({
  required HiveData hive,
  required String boxType,
  String boxName = '',
  String? overrideFamilyFunction,
  bool ignoreExistingBroodCheck = false,
}) {
  final String rawFn = overrideFamilyFunction ?? hive.familyFunction;
  final String fnCat = normalizeHiveFamilyFunctionCategory(rawFn);
  final String fnLabel = getHiveFamilyFunctionLabel(rawFn);
  final String elemType = canonicalizeHiveElementType(
    boxType,
    rawName: boxName,
  );
  final String elemLabel = boxName.trim().isNotEmpty
      ? boxName.trim()
      : _defaultElementDisplayName(elemType, boxType);

  // Alapelemek (aljdeszka, tető, szellőző, kezelőcsík) minden családon megengedettek
  if (elemType == 'bottom' ||
      elemType == 'roof' ||
      elemType == 'vent' ||
      elemType == 'treatment_strip') {
    return null;
  }

  // Az első (alap) fészekfiók minden családnak létszükséglete
  if (elemType == 'brood_box') {
    final bool hasBroodAlready =
        ignoreExistingBroodCheck ||
        hive.boxes.any(
          (b) => canonicalizeHiveElementType(b.type, rawName: b.name) == 'brood_box',
        );
    if (!hasBroodAlready) return null;
    if (fnCat == 'cull') {
      return FamilyFunctionBoxMismatch(
        functionLabel: fnLabel,
        elementLabel: elemLabel,
        badgeText: 'Család feladata: $fnLabel • Elem: $elemLabel',
        primaryMessage:
            'Selejtezésre kijelölt család fészkét nem javasolt plusz fészekfiókkal bővíteni!',
        explanation:
            'A selejt család feladata a felszámolás / más családok felerősítése. A fészek bővítése széthúzza a népet és megnehezíti az egyesítést.',
      );
    }
    return null;
  }

  // 1. MÉZTÉRI FIÓK: kizárólag méztermelő családra való!
  if (elemType == 'honey') {
    if (fnCat == 'honey') return null;

    String explanation;
    switch (fnCat) {
      case 'pollen':
        explanation =
            'A virágporgyűjtő családon a pollenrács lelassítja a forgalmat és visszafogja a nektárbehordást. A méztér üresen maradhat és feleslegesen hűti a fészket.';
        break;
      case 'propolis':
        explanation =
            'A propolisztermelő család feladata a propoliszrács beépítése, nem az áruméz gyűjtése. A méztéri fiók elvonja a méheket a propoliszgyűjtéstől.';
        break;
      case 'nurse':
        explanation =
            'A dajka- / anyanevelő családot sűrített fészekben, folyamatos serkentő etetés mellett kell tartani az anyabölcsők bőséges pempőzéséhez. A méztér lehűti a fészket, elvonja a dajkaméheket, és a serkentő szirup is bekerülne a lépekbe!';
        break;
      case 'breeder':
      case 'drone_breeder':
      case 'donor':
        explanation =
            'A(z) $fnLabel feladata a tenyészanyag, fias keretek vagy életképes herék biztosítása, nem pedig az áruméz-termelés. A méztéri terhelés kimeríti a családot.';
        break;
      case 'reserve':
        explanation =
            'A tartalék / fejlődő raj feladata a saját fészek kiépítése és megerősödése. A korán felrakott méztér lehűti a fiasítást és megtöri a fejlődést.';
        break;
      case 'cull':
        explanation =
            'A selejt család felszámolásra vagy más családok erősítésére vár, nem méztermelésre.';
        break;
      default:
        explanation =
            'Ennek a családnak "$fnLabel" a beállított feladata, nem a méztermelés, ezért a méztéri fiók nem illeszkedik a technológiához.';
    }

    return FamilyFunctionBoxMismatch(
      functionLabel: fnLabel,
      elementLabel: elemLabel,
      badgeText: 'Nem méztermelő család ($fnLabel) • Elem: $elemLabel',
      primaryMessage:
          'Ennek a családnak nem a méztermelés a feladata ($fnLabel) – méztéri fiók felhelyezése nem javasolt!',
      explanation: explanation,
    );
  }

  // 2. MÉHSZÖKTETŐ (ZUBEHÖR): kizárólag méztermelő család mézelvételéhez való!
  if (elemType == 'escapement') {
    if (fnCat == 'honey') return null;
    return FamilyFunctionBoxMismatch(
      functionLabel: fnLabel,
      elementLabel: elemLabel,
      badgeText: 'Család feladata: $fnLabel • Kellék: Méhszöktető',
      primaryMessage:
          'Ennek a családnak nem a méztermelés a feladata ($fnLabel) – a méhszöktető nem ide való!',
      explanation:
          'A méhszöktető a pergetendő méztéri fiókok méhtelenítésére szolgál. Nem méztermelő családon feleslegesen elzárja a méhek útját a kaptártérben.',
    );
  }

  // 3. ANYARÁCS (ZUBEHÖR): méztermelésnél és anyás dajkacsaládnál indokolt; másutt (különösen apacsaládnál!) hibás!
  if (elemType == 'queen_excluder') {
    if (fnCat == 'honey' || fnCat == 'nurse' || fnCat == 'breeder') {
      return null;
    }
    if (fnCat == 'drone_breeder') {
      return FamilyFunctionBoxMismatch(
        functionLabel: fnLabel,
        elementLabel: elemLabel,
        badgeText: 'Apacsalád (Herenevelés) • Kellék: Anyarács',
        primaryMessage:
            'Apacsaládra tilos anyarácsot helyezni – a herék beszorulnak és elpusztulnak a rácsban!',
        explanation:
            'Az apacsalád feladata az erős, párzóképes herék nevelése és szabad kirepülése. Az anyarács nyílásain a herék nem férnek át, tömegesen fennakadnak és elzárják a rácsot!',
      );
    }
    return FamilyFunctionBoxMismatch(
      functionLabel: fnLabel,
      elementLabel: elemLabel,
      badgeText: 'Család feladata: $fnLabel • Kellék: Anyarács',
      primaryMessage:
          'A(z) "$fnLabel" feladathoz nem szükséges anyarács!',
      explanation:
          'Méztér vagy anyás bölcsődajkálás nélkül az anyarács feleslegesen kopasztja a méhek szárnyát és lassítja a közlekedést a kaptárban.',
    );
  }

  // 4. VIRÁGPORGYŰJTŐ (ZUBEHÖR): csak virágporgyűjtő feladatú családon célszerű!
  if (elemType == 'pollen_trap') {
    if (fnCat == 'pollen') return null;

    String explanation;
    if (fnCat == 'honey') {
      explanation =
          'Ennek a családnak a méztermelés a feladata! A pollengyűjtő rács lefékezi a hordó méhek kijárását és érezhetően csökkenti a mézhozamot.';
    } else if (fnCat == 'nurse' ||
        fnCat == 'breeder' ||
        fnCat == 'drone_breeder' ||
        fnCat == 'donor') {
      explanation =
          'A(z) $fnLabel számára létfontosságú a zavartalan, bőséges virágpor-ellátás (méhpempő-termelés, intenzív fiasítás és herenevelés). A fehérje elvonása súlyos minőségromlást okoz!';
    } else {
      explanation =
          'Ennek a családnak "$fnLabel" a feladata, nem a virágportermelés. A pollengyűjtő elvonja a fejlődéshez szükséges fehérjét és akadályozza a kijárást.';
    }

    return FamilyFunctionBoxMismatch(
      functionLabel: fnLabel,
      elementLabel: elemLabel,
      badgeText: 'Család feladata: $fnLabel • Kellék: Virágporgyűjtő',
      primaryMessage:
          'Ennek a családnak nem a virágporgyűjtés a feladata ($fnLabel)!',
      explanation: explanation,
    );
  }

  // 5. TETŐETETŐ (ZUBEHÖR): méztermelő, propoliszos és selejt családon nem javasolt!
  if (elemType == 'feeder') {
    if (fnCat == 'honey') {
      return FamilyFunctionBoxMismatch(
        functionLabel: fnLabel,
        elementLabel: elemLabel,
        badgeText: 'Család feladata: Méztermelés • Kellék: Tetőetető',
        primaryMessage:
            'Méztermelő családra tetőetető felhelyezése nem javasolt!',
        explanation:
            'Méztermelés feladatnál a cukorszirup-etetés veszélyezteti az áruméz tisztaságát (bekeveredés / hamisítás kockázata). Serkentő etetés előtt állítsd át a család feladatát és vedd le a méztereket!',
      );
    }
    if (fnCat == 'propolis') {
      return FamilyFunctionBoxMismatch(
        functionLabel: fnLabel,
        elementLabel: elemLabel,
        badgeText: 'Család feladata: Propolisztermelés • Kellék: Tetőetető',
        primaryMessage:
            'Propolisztermelő családon a tetőetető rontja a propolisz tisztaságát!',
        explanation:
            'Szirupetetés hatására a méhek viasztermelésbe kezdenek, és tiszta propolisz helyett viasszal építik be a propoliszrácsot.',
      );
    }
    if (fnCat == 'cull') {
      return FamilyFunctionBoxMismatch(
        functionLabel: fnLabel,
        elementLabel: elemLabel,
        badgeText: 'Család feladata: Selejt család • Kellék: Tetőetető',
        primaryMessage:
            'Selejtezésre kijelölt családra nem javasolt külön tetőetetőt tenni!',
        explanation:
            'A selejt család felszámolásra / egyesítésre vár; a szirupkészletet érdemesebb a megtartandó termelő és tartalék családoknak adni.',
      );
    }
    return null;
  }

  // 6. LÉPÉPÍTŐ FIÓK: dajkacsaládon és selejt családon nem megfelelő!
  if (elemType == 'comb_builder') {
    if (fnCat == 'nurse') {
      return FamilyFunctionBoxMismatch(
        functionLabel: fnLabel,
        elementLabel: elemLabel,
        badgeText: 'Család feladata: $fnLabel • Elem: Lépépítő fiók',
        primaryMessage:
            'Dajka- / anyanevelő családra nem javasolt lépépítő fiókot helyezni!',
        explanation:
            'A dajkacsalád fiatal méheinek minden energiáját a méhpempő termelésére és az anyabölcsők gondozására kell fordítaniuk, nem pedig egy egész fióknyi műlép kiépítésére.',
      );
    }
    if (fnCat == 'cull') {
      return FamilyFunctionBoxMismatch(
        functionLabel: fnLabel,
        elementLabel: elemLabel,
        badgeText: 'Család feladata: Selejt család • Elem: Lépépítő fiók',
        primaryMessage:
            'Selejt családdal nem célszerű új lépépítő fiókot építtetni!',
        explanation:
            'A selejtezésre kijelölt család építőereje gyenge vagy egyenetlen (sok sejthiba / hereépítmény keletkezhet).',
      );
    }
    return null;
  }

  // 7. SZAPORÍTÓ (DEMAREE) FIÓK: selejt, tartalék és dajkacsaládon nem megfelelő!
  if (elemType == 'demaree') {
    if (fnCat == 'cull') {
      return FamilyFunctionBoxMismatch(
        functionLabel: fnLabel,
        elementLabel: elemLabel,
        badgeText: 'Család feladata: Selejt család • Elem: Szaporító (Demaree)',
        primaryMessage:
            'Selejt családról nem szabad szaporítani (Demaree fiók nem javasolt)!',
        explanation:
            'A selejtezésre kijelölt család gyenge vagy kedvezőtlen tulajdonságait tilos szaporítással továbbörökíteni az állományban.',
      );
    }
    if (fnCat == 'reserve') {
      return FamilyFunctionBoxMismatch(
        functionLabel: fnLabel,
        elementLabel: elemLabel,
        badgeText: 'Család feladata: $fnLabel • Elem: Szaporító (Demaree)',
        primaryMessage:
            'Tartalék / fejlődő rajra Demaree szaporító fiók még nem való!',
        explanation:
            'A tartalék család feladata a saját megerősödése; a fészek kettéosztása (Demaree) csak erős, kifejlett családokon alkalmazható biztonságosan.',
      );
    }
    if (fnCat == 'nurse') {
      return FamilyFunctionBoxMismatch(
        functionLabel: fnLabel,
        elementLabel: elemLabel,
        badgeText: 'Család feladata: $fnLabel • Elem: Szaporító (Demaree)',
        primaryMessage:
            'Aktív dajkacsaládon a Demaree-fiók megbontja a dajkanépességet!',
        explanation:
            'Az anyabölcsők sikeres neveléséhez koncentrált, tömör dajkanépességre van szükség, nem megosztott fészekre.',
      );
    }
    return null;
  }

  return null;
}

/// Megkeresi a kaptártornyon MÁR FENN LÉVŐ olyan fiókokat / aktív kellékeket,
/// amelyek ütköznek egy újonnan kiválasztott családfunkcióval (`targetFamilyFunction`).
List<FamilyFunctionBoxMismatch> findExistingTowerMismatchesForFunction(
  HiveData hive,
  String targetFamilyFunction,
) {
  final List<FamilyFunctionBoxMismatch> mismatches = [];
  final Set<String> seenElemTypes = {};
  bool seenFirstBrood = false;

  for (final box in hive.boxes) {
    final String elemType = canonicalizeHiveElementType(
      box.type,
      rawName: box.name,
    );
    if (elemType == 'brood_box' && !seenFirstBrood) {
      seenFirstBrood = true;
      continue;
    }
    // Inaktív alj-pollengyűjtő ház (kihúzott ráccsal) és kikapcsolt etető ne riasszon funkcióváltáskor
    if (elemType == 'pollen_trap' && !box.isActive) continue;
    if (elemType == 'feeder' && hive.feedingMode == 'off') continue;
    if (seenElemTypes.contains(elemType)) continue;

    final mismatch = evaluateFamilyFunctionBoxMismatch(
      hive: hive,
      boxType: box.type,
      boxName: box.name,
      overrideFamilyFunction: targetFamilyFunction,
      ignoreExistingBroodCheck: elemType == 'brood_box',
    );
    if (mismatch != null) {
      seenElemTypes.add(elemType);
      mismatches.add(mismatch);
    }
  }
  return mismatches;
}

// ============================================================================
// IRODAI ELŐZMÉNYEK & KAPTÁRNAPLÓ MODELL (FIÓKOK, ZUBEHÖR, KEZELÉS, OSZTÁLYOZÁS)
// ============================================================================

class HistoryLogEntry {
  int? dbId;
  final String localId;
  final String monitorMac;
  final String eventType;
  final String description;
  DateTime createdAt;
  final Map<String, dynamic>? metadata;

  HistoryLogEntry({
    this.dbId,
    required this.localId,
    required this.monitorMac,
    required this.eventType,
    required this.description,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': dbId,
    'local_id': localId,
    'monitor_mac': monitorMac,
    'event_type': eventType,
    'description': description,
    'created_at': createdAt.toUtc().toIso8601String(),
    'metadata': metadata,
  };

  factory HistoryLogEntry.fromJson(Map<String, dynamic> json) {
    final int? parsedId = (json['id'] as num?)?.toInt();
    Map<String, dynamic>? parsedMeta;
    final dynamic rawMeta = json['metadata'];
    if (rawMeta is Map) {
      parsedMeta = Map<String, dynamic>.from(rawMeta);
    } else if (rawMeta is String && rawMeta.trim().startsWith('{')) {
      try {
        final dec = jsonDecode(rawMeta);
        if (dec is Map) parsedMeta = Map<String, dynamic>.from(dec);
      } catch (_) {}
    }
    final DateTime parsedTime =
        DateTime.tryParse(
          (json['created_at'] ?? json['timestamp'] ?? '').toString(),
        )?.toLocal() ??
        DateTime.now();
    final String mac = (json['monitor_mac'] ?? 'SYSTEM').toString();
    final String ev = (json['event_type'] ?? 'esemeny').toString();

    return HistoryLogEntry(
      dbId: parsedId,
      localId:
          (json['local_id'] ??
                  (parsedId != null
                      ? 'DB_$parsedId'
                      : '${mac}_${ev}_${parsedTime.millisecondsSinceEpoch}'))
              .toString(),
      monitorMac: mac,
      eventType: ev,
      description: (json['description'] ?? '').toString(),
      createdAt: parsedTime,
      metadata: parsedMeta,
    );
  }

  /// Automatikus ESP32 / SIM7000G szenzormérés (`public.hive_meters` sor) átalakítása időrendi naplóelemmé
  factory HistoryLogEntry.fromHiveMeterRow(Map<String, dynamic> row) {
    final int? meterId = (row['id'] as num?)?.toInt();
    final String mac =
        (row['monitor_mac'] ?? row['mac_address'] ?? 'HIVE_01').toString();
    final DateTime ts =
        DateTime.tryParse(
          (row['created_at'] ?? row['measured_at'] ?? row['timestamp'] ?? '')
              .toString(),
        )?.toLocal() ??
        DateTime.now();

    final double? temp =
        (row['inner_temp'] as num?)?.toDouble() ??
        (row['temp'] as num?)?.toDouble();
    final double? hum = (row['humidity'] as num?)?.toDouble();
    final double? noise =
        (row['noise'] as num?)?.toDouble() ?? (row['zcr'] as num?)?.toDouble();
    final double? weight = (row['weight'] as num?)?.toDouble();
    final double? battery = (row['battery_voltage'] as num?)?.toDouble();

    final List<String> parts = [];
    if (temp != null) parts.add('Fészekhő: ${temp.toStringAsFixed(1)} °C');
    if (hum != null) parts.add('Pára: ${hum.toStringAsFixed(0)}%');
    if (weight != null) parts.add('Súly: ${weight.toStringAsFixed(2)} kg');
    if (noise != null) parts.add('Zúgás: ${noise.toStringAsFixed(0)} Hz');
    if (battery != null) parts.add('Akku: ${battery.toStringAsFixed(2)} V');

    return HistoryLogEntry(
      dbId: meterId,
      localId:
          'METER_${meterId ?? "${mac}_${ts.millisecondsSinceEpoch}"}',
      monitorMac: mac,
      eventType: 'automata_meres',
      description: parts.isNotEmpty
          ? 'Automata szenzormérés – ${parts.join(" • ")}'
          : 'Automata szenzormérés rögzítve.',
      createdAt: ts,
      metadata: {
        'source': 'hive_meters',
        if (temp != null) 'inner_temp': temp,
        if (hum != null) 'humidity': hum,
        if (weight != null) 'weight': weight,
        if (noise != null) 'noise': noise,
        if (battery != null) 'battery_voltage': battery,
      },
    );
  }

  bool get isAutoTelemetry =>
      eventType == 'automata_meres' || metadata?['source'] == 'hive_meters';

  bool _mentionsAccessoryInText(String text) {
    final norm = _normalizeBoxToken(text);
    return norm.contains('tetoeteto') ||
        norm.contains('eteto') ||
        norm.contains('pollengyujto') ||
        norm.contains('viragporgyujto') ||
        norm.contains('viragpor') ||
        norm.contains('szokteto') ||
        norm.contains('mehszokteto') ||
        norm.contains('anyaracs') ||
        norm.contains('szellozo') ||
        norm.contains('aljdeszka') ||
        norm.contains('kezelolap') ||
        norm.contains('dekli') ||
        (norm.contains('teto') &&
            !norm.contains('szokteto') &&
            !norm.contains('eteto'));
  }

  bool _isFrameBoxTowerEvent() {
    final meta = metadata;
    if (meta != null) {
      final String metaType =
          (meta['body_function'] ?? meta['type'] ?? meta['box_type'] ?? '')
              .toString();
      final String metaName =
          (meta['name'] ?? meta['box_name'] ?? meta['element_label'] ?? '')
              .toString();
      if (metaType.isNotEmpty || metaName.isNotEmpty) {
        return isFrameBoxType(metaType, name: metaName);
      }
    }
    if (_mentionsAccessoryInText(description)) {
      return false;
    }
    return true;
  }

  /// Fő kategória az Irodai History szűrőkhöz:
  /// 'boxes' | 'zubehor' | 'treatments' | 'classification' | 'telemetry' | 'other'
  String get mainCategory {
    if (isAutoTelemetry) return 'telemetry';
    final ev = _normalizeBoxToken(eventType);
    final descNorm = _normalizeBoxToken(description);

    // 1. Kifejezett Zubehör (kellék) események
    if (ev == 'pollengyujto' ||
        ev == 'atkaellenorzes' ||
        ev == 'szoktetes') {
      return 'zubehor';
    }

    // 2. Torony bővítés / csökkentés / átrendezés / felülbírálás -> Fiók vs Zubehör szétválasztása!
    if (ev == 'torony_bovites' ||
        ev == 'torony_csokkentes' ||
        ev == 'torony_atrendezes' ||
        ev == 'torony_szabvanyositas' ||
        ev == 'nem_megfelelo_elem_felulbiralas' ||
        ev == 'elem_cimke_regisztracio') {
      return _isFrameBoxTowerEvent() ? 'boxes' : 'zubehor';
    }

    // Szöktetés kész -> méztéri fiókok elvétele a toronyból
    if (ev == 'pergetes' &&
        descNorm.contains('szoktetes kesz') &&
        descNorm.contains('fiok')) {
      return 'boxes';
    }

    // 3. Osztályozás, funkció, tenyészbírálat és anyakezelés
    if (ev.contains('statusz') ||
        ev.contains('funkcio') ||
        ev.contains('biralat') ||
        ev == 'visszaeses_erosites_utan' ||
        ev.contains('anya') ||
        ev.contains('lakat') ||
        ev == 'uj_kaptar' ||
        ev == 'kaptar_konfig') {
      return 'classification';
    }

    // 4. Kezelések, felerősítés, etetés, egészségügy, vizsgálatok
    if (ev.contains('kezeles') ||
        ev.contains('atkairt') ||
        ev.contains('oxalsav') ||
        ev.contains('hangyasav') ||
        ev.contains('felerosites') ||
        ev == 'donor_megcsapolas' ||
        ev.contains('etetes') ||
        ev.contains('szirup') ||
        ev.contains('itato') ||
        ev == 'atkaszamlalas' ||
        ev == 'keret_ai_elemzes' ||
        ev == 'hans_protokoll' ||
        ev == 'betegseg_jelentes' ||
        ev.startsWith('feladat_')) {
      return 'treatments';
    }

    return 'other';
  }

  /// Részletes művelet-irány (+ felrakás / - levétel / be-ki kapcsolás / stb.)
  String get actionKind {
    if (isAutoTelemetry) return 'telemetry';
    final ev = _normalizeBoxToken(eventType);
    final descNorm = _normalizeBoxToken(description);

    if (ev == 'torony_bovites' || ev == 'elem_cimke_regisztracio') {
      return 'added';
    }
    if (ev == 'torony_csokkentes' ||
        (ev == 'pergetes' && descNorm.contains('szoktetes kesz'))) {
      return 'removed';
    }
    if (ev == 'torony_atrendezes' || ev == 'torony_szabvanyositas') {
      return 'reordered';
    }
    if (ev == 'pollengyujto' || ev == 'atkaellenorzes') {
      if (descNorm.contains('kikapcsolva') || descNorm.contains('kihuzva')) {
        return 'active_off';
      }
      return 'active_on';
    }
    if (ev == 'szoktetes') return 'active_on';
    if (ev == 'nem_megfelelo_elem_felulbiralas' ||
        ev == 'torony_funkcio_elteres' ||
        ev == 'visszaeses_erosites_utan' ||
        ev == 'hans_protokoll' ||
        ev == 'szirup_veszleallitas' ||
        ev == 'itato_veszleallitas') {
      return 'warning';
    }
    if (ev == 'felerosites' || ev == 'donor_megcsapolas') {
      return 'strengthening';
    }
    if (ev.contains('etetes') || ev.contains('szirup')) {
      return 'feeding';
    }
    if (ev.contains('biralat')) return 'evaluation';
    if (ev.contains('statusz')) return 'status';
    if (ev.contains('funkcio')) return 'function';
    if (ev.contains('anya') || ev.contains('lakat')) return 'queen';
    if (mainCategory == 'treatments') return 'treatment';
    if (ev == 'pergetes' || ev == 'hordo_merlegeles' || ev == 'kiszereles') {
      return 'harvest';
    }
    return 'system';
  }

  bool get isAddedAction => actionKind == 'added' || actionKind == 'active_on';
  bool get isRemovedAction =>
      actionKind == 'removed' || actionKind == 'active_off';

  String get actionBadgeLabel {
    final cat = mainCategory;
    switch (actionKind) {
      case 'added':
        return cat == 'boxes' ? '+ FIÓK FELRAKVA' : '+ ZUBEHÖR FELRAKVA';
      case 'removed':
        return cat == 'boxes' ? '− FIÓK LEVÉVE' : '− ZUBEHÖR LEVÉVE';
      case 'reordered':
        return 'TORONY ÁTRENDEZÉS';
      case 'active_on':
        return 'ZUBEHÖR AKTÍV';
      case 'active_off':
        return 'ZUBEHÖR KIKAPCS.';
      case 'warning':
        return 'FIGYELMEZTETÉS';
      case 'strengthening':
        return 'NÉPESSÉG ERŐSÍTÉS';
      case 'feeding':
        return 'ETETÉS / SZIRUP';
      case 'treatment':
        return 'KEZELÉS / VIZSGÁLAT';
      case 'evaluation':
        return 'TENYÉSZBÍRÁLAT';
      case 'status':
        return 'STÁTUSZ OSZTÁLYOZÁS';
      case 'function':
        return 'CSALÁDFUNKCIÓ';
      case 'queen':
        return 'MÉHANYA / LAKAT';
      case 'telemetry':
        return 'AUTOMATA MÉRÉS';
      case 'harvest':
        return 'PERGETÉS / MÉZ';
      default:
        return eventType.toUpperCase();
    }
  }
}

// ============================================================================
// IDŐJÁRÁS-ÁLLOMÁS IDŐSOROS MÉRÉSI PONT (ÓRÁNKÉNTI / NAPI / HETI HISTORY-HOZ)
// ============================================================================

class WeatherLogPoint {
  final int? dbId;
  final String stationId;
  final DateTime timestamp;
  final double tempC;
  final double humidityPct;
  final double pressureHpa;
  final double windSpeedMs;
  final String windDirection;
  final double rainMm;
  final double uvIndex;
  final double lightLux;
  final double batteryVoltage;
  final bool isSimulated;

  const WeatherLogPoint({
    this.dbId,
    this.stationId = 'WEATHER_01',
    required this.timestamp,
    required this.tempC,
    required this.humidityPct,
    required this.pressureHpa,
    required this.windSpeedMs,
    required this.windDirection,
    this.rainMm = 0.0,
    this.uvIndex = 0.0,
    this.lightLux = 0.0,
    this.batteryVoltage = 4.10,
    this.isSimulated = false,
  });

  static String compassLabelFromDeg(double deg) {
    final d = ((deg % 360) + 360) % 360;
    if (d >= 337.5 || d < 22.5) return 'É';
    if (d < 67.5) return 'ÉK';
    if (d < 112.5) return 'K';
    if (d < 157.5) return 'DK';
    if (d < 202.5) return 'D';
    if (d < 247.5) return 'DNy';
    if (d < 292.5) return 'Ny';
    return 'ÉNy';
  }

  /// Méhek röpködésére / hordásra alkalmas óra-e:
  /// Nappali fény, legalább 12 °C, csapadékmentes (< 0.2 mm), mérsékelt szél (< 7.5 m/s)
  bool get isGoodBeeFlightHour {
    final bool isDaylight =
        lightLux >= 1500 || (timestamp.hour >= 7 && timestamp.hour <= 19);
    return isDaylight &&
        tempC >= 12.0 &&
        rainMm < 0.2 &&
        windSpeedMs < 7.5;
  }

  Map<String, dynamic> toJson() => {
    'id': dbId,
    'station_id': stationId,
    'created_at': timestamp.toUtc().toIso8601String(),
    'temp_c': tempC,
    'humidity_pct': humidityPct,
    'pressure_hpa': pressureHpa,
    'wind_speed_ms': windSpeedMs,
    'wind_direction': windDirection,
    'rain_mm': rainMm,
    'uv_index': uvIndex,
    'light_lux': lightLux,
    'battery_voltage': batteryVoltage,
  };

  factory WeatherLogPoint.fromJson(Map<String, dynamic> json) {
    final double? dirDeg = (json['wind_direction_deg'] as num?)?.toDouble();
    final String dirText =
        (json['wind_direction'] != null &&
            json['wind_direction'].toString().trim().isNotEmpty)
        ? json['wind_direction'].toString().trim()
        : (dirDeg != null ? compassLabelFromDeg(dirDeg) : 'ÉNy');

    return WeatherLogPoint(
      dbId: (json['id'] as num?)?.toInt(),
      stationId: (json['station_id'] ?? 'WEATHER_01').toString(),
      timestamp:
          DateTime.tryParse(
            (json['created_at'] ?? json['timestamp'] ?? '').toString(),
          )?.toLocal() ??
          DateTime.now(),
      tempC:
          (json['temp_c'] as num?)?.toDouble() ??
          (json['temp'] as num?)?.toDouble() ??
          20.0,
      humidityPct:
          (json['humidity_pct'] as num?)?.toDouble() ??
          (json['humidity'] as num?)?.toDouble() ??
          55.0,
      pressureHpa:
          (json['pressure_hpa'] as num?)?.toDouble() ??
          (json['pressure'] as num?)?.toDouble() ??
          1013.0,
      windSpeedMs:
          (json['wind_speed_ms'] as num?)?.toDouble() ??
          (json['wind_speed'] as num?)?.toDouble() ??
          2.5,
      windDirection: dirText,
      rainMm:
          (json['rain_mm'] as num?)?.toDouble() ??
          (json['rain_amount'] as num?)?.toDouble() ??
          0.0,
      uvIndex: (json['uv_index'] as num?)?.toDouble() ?? 0.0,
      lightLux: (json['light_lux'] as num?)?.toDouble() ?? 0.0,
      batteryVoltage: (json['battery_voltage'] as num?)?.toDouble() ?? 4.10,
      isSimulated: false,
    );
  }
}

