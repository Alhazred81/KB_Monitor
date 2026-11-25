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
    this.gathering = '+',
    this.temperament = '+',
    this.hygiene = '+',
    this.consumption = '+',
    this.pollenCollection = '+',
    this.building = '+',
    this.propolis = '+',
    this.swarming = '+',
    this.robbing = '+',
    this.diseaseResistance = '+',
    this.miteResistance = '+',
    this.reproduction = '+',
    this.winterSurvival = '+',
    this.notes = '',
  });
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
  DateTime updatedAt; // Utolsó módosítás időbélyege (UTC) a Last-Write-Wins szinkronhoz
  bool isQuarantined; // Nyúlós költésrothadás / Hans-protokoll zárlat

  BoxElement({
    this.dbId,
    required this.name,
    required this.code,
    this.secondaryCode,
    required this.type,
    this.size = 'dadant',
    this.status = 'green',
    this.isActive = false,
    this.isQuarantined = false,
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
    isQuarantined: json['isQuarantined'] as bool? ??
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
  if (t == 'pollen_trap' || n.contains('pollen') || n.contains('virágpor')) return 10;
  if (t == 'brood_box' || t == 'nest' || n.contains('fészek') || n.contains('feszek')) return 20;
  if (t == 'comb_builder' || n.contains('lépépít') || n.contains('lepepit')) return 22;
  if (t == 'queen_excluder' || n.contains('anyarács') || n.contains('anyaracs')) return 24;
  if (t == 'escapement' || n.contains('szöktet') || n.contains('szoktet')) return 25; // Alapértelmezetten a fészek felett / méztér alatt
  if (t == 'honey' || n.contains('méz') || n.contains('mez')) return 30;
  if (t == 'demaree' || n.contains('szaporít') || n.contains('szaporit') || n.contains('demaree')) return 35;
  if (t == 'vent' || n.contains('szellőz') || n.contains('szelloz')) return 50;
  if (t == 'feeder' || t == 'roof_feeder' || n.contains('etető') || n.contains('eteto')) return 60; // Közvetlenül a tető alatt
  if (t == 'roof' ||
      ((n.contains('tető') || n.contains('teto')) &&
          !n.contains('szöktet') &&
          !n.contains('szoktet') &&
          !n.contains('etet')) ||
      n.contains('fedő') ||
      n.contains('dekli')) return 70; // Legfelül
  return 35;
}

bool isBottomBox(BoxElement b) {
  final t = b.type.toLowerCase();
  final n = b.name.toLowerCase();
  return t == 'bottom' || t == '15' || n.contains('alj');
}

bool isRoofBox(BoxElement b) {
  final t = b.type.toLowerCase();
  final n = b.name.toLowerCase();
  if (t == 'feeder' || t == 'roof_feeder' || t == '10' || n.contains('etet')) {
    return false;
  }
  // Szigorú védelem: A "szöktető" szó tartalmazza a "tető" szórészletet, de nem tető!
  if (t == 'escapement' || t == '13' || n.contains('szöktet') || n.contains('szoktet')) {
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
  return t == 'feeder' ||
      t == 'roof_feeder' ||
      t == '10' ||
      n.contains('etet');
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
  final String id;
  final String hiveId;
  final String category;
  final String title;
  final String description;
  final DateTime scheduledDate;
  bool isCompleted;

  ScheduledTask({
    required this.id,
    required this.hiveId,
    required this.category,
    required this.title,
    required this.description,
    required this.scheduledDate,
    this.isCompleted = false,
  });
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
  double feedingMaxLiters; // Egyszerre kiadható maximum mennyiség vagy napi max keret
  int feedingIntervalHours; // Időzített serkentés időköz órában (1, 2, 3, 4, max 6 óra)
  int feedingIntervalDays; // Visszafelé kompatibilitáshoz
  int feedingStopBeforeSunsetMinutes; // Napnyugta előtt hány perccel álljon le (60, 90, 120 perc)
  double feedingPortionLiters; // Mikro-adag mérete smart módban (pl. 0.15 - 0.3 L)
  double feederLevelPercent; // Ultrahangos/nyomás alapú szintmérés (0 - 100%)
  int feederCalibEmptyMm; // Üres tartály távolsága a szenzortól mm-ben (0%)
  int feederCalibFullMm; // Tele tartály távolsága a szenzortól mm-ben (100%)
  int feederRawDistanceMm; // Aktuális mért ultrahang távolság mm-ben
  String _customFeederStatus;
  String get feederStatus {
    if (_customFeederStatus == 'blinking_red') return 'blinking_red';
    if (_customFeederStatus == 'orange' && (isQueuedForRefill || sztojRemainingSeconds > 0)) {
      return 'orange';
    }
    if (feederLevelPercent <= 5.0) return 'red';
    if (feederLevelPercent < 20.0) return 'orange';
    if (feederLevelPercent < 50.0) return 'yellow';
    return 'green';
  }
  set feederStatus(String val) => _customFeederStatus = val;
  String? pairedTankId; // Automatikusan vagy kézzel párosított sziruptartály (pl. 'ABC tartály')
  bool isAutoPaired; // A szerver automatikusan összelőtte-e szintemelkedés alapján
  bool isQueuedForRefill; // Utántöltési kérelem aktív vagy sorban áll
  int sztojRemainingSeconds; // SZTOJ esetén hátralevő várakozási idő másodpercben
  String? feederStatusMessage; // Részletes állapot vagy hibaüzenet

  // --- ANYACSERE & LAKAT MEZŐK ---
  String? queenReplacementState; // null / 'none', 'needs_replacement', 'queen_removed', 'introduced_cage', 'introduced_chewout'
  DateTime? queenIntroducedAt; // Anyabehelyezés időpontja (3 napos vizsgálathoz)
  DateTime? lockedUntil; // Zárolás lejárati ideje (kirágós anyabeadás esetén kb. 2 hét)
  String? lockReason; // Zárolás oka (pl. 'Új anya kirágósra adva')
  bool isAcousticSentinelActive; // Fokozott akusztikai felügyelet (kirágós lakat alatt sűrített hallgatózás)
  int acousticSampleIntervalMinutes; // Mintavételezési időköz (alapesetben 60 perc, lakat alatt 15 perc)

  void resetEvaluation({String? newQueenId, String? reason}) {
    evaluation = EvaluationData(
      gathering: '+',
      temperament: '+',
      hygiene: '+',
      consumption: '+',
      pollenCollection: '+',
      building: '+',
      propolis: '+',
      swarming: '+',
      robbing: '+',
      diseaseResistance: '+',
      miteResistance: '+',
      reproduction: '+',
      winterSurvival: '+',
      notes: reason ?? 'Tiszta lap - új anya (${newQueenId ?? queen?.id ?? ""})',
    );
  }

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

  /// Van-e a toronyban bármilyen extra fiók (méztér, szöktető, etető, stb.)
  /// Szigorú méhészeti szabály: Családot kizárólag akkor vizsgálunk vagy kezelünk,
  /// ha nincs fenn egyetlen extra fiók sem!
  bool get hasExtraBoxes {
    return boxes.any((b) {
      if (isRoofBox(b) || isBottomBox(b) || isPollenBox(b)) return false;
      final t = b.type.toLowerCase();
      final n = b.name.toLowerCase();
      final bool isBrood = t == 'brood_box' ||
          t == 'broodbox' ||
          t == 'nest' ||
          t == '8' ||
          n.contains('fészek') ||
          n.contains('feszek');
      return !isBrood;
    });
  }

  String get lockedUntilFormatted {
    if (lockedUntil == null) return '';
    return '${lockedUntil!.year}.${lockedUntil!.month.toString().padLeft(2, '0')}.${lockedUntil!.day.toString().padLeft(2, '0')}';
  }

  double calculateLevelFromDistance(int distanceMm) {
    if (feederCalibEmptyMm <= feederCalibFullMm) return 0.0;
    double pct = ((feederCalibEmptyMm - distanceMm) /
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
    final int cutoffMinutes = estimatedSunsetMinutes - feedingStopBeforeSunsetMinutes;

    if (totalMinutes >= cutoffMinutes) {
      return false; // Napnyugta előtt 1-2 órával leállítva!
    }

    return true;
  }

  bool get hasFeeder => boxes.any((b) =>
      b.type == 'feeder' ||
      b.type == 'roof_feeder' ||
      b.name.toLowerCase().contains('etető') ||
      b.name.toLowerCase().contains('eteto'));

  bool get hasHoneySuper => boxes.any((b) =>
      b.type == 'honey' ||
      b.type == '9' ||
      b.name.toLowerCase().contains('méz') ||
      b.name.toLowerCase().contains('mez'));

  /// Nyúlós költésrothadás / Hans-protokoll miatti szigorú hatósági zárlat.
  /// SZIGORÚ SZABÁLY: A TELJES TORONY (minden fiók, keret, mézkészlet, aljdeszka, etető)
  /// KARANTÉN ZÁRLAT ALATT ÁLL: semmi nem vihető át belőle másik kaptárba vagy a feldolgozóba!
  bool get isQuarantined =>
      reportedDiseases.contains('nyulos') ||
      protocol?.toLowerCase() == 'hans' ||
      familyFunction.toLowerCase() == 'hans' ||
      (status == 'flashing_red' && familyFunction.toLowerCase().contains('hans')) ||
      boxes.any((b) => b.isQuarantined);

  bool get isTowerQuarantined => isQuarantined;

  bool get hasActivePollenTrap => boxes.any((b) =>
      (b.type == 'pollen_trap' ||
          b.type == '11' ||
          b.name.toLowerCase().contains('pollen') ||
          b.name.toLowerCase().contains('virágpor')) &&
      b.isActive);
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
    List<String>? reportedDiseases,
    DateTime? updatedAt,
    DateTime? towerUpdatedAt,
  })  : _customFeederStatus = feederStatus,
        reportedDiseases = reportedDiseases != null ? List<String>.from(reportedDiseases) : <String>[],
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
    if (zcr >= 3000.0 && zcr <= 4200.0) return 'green'; // Nyugodt, egészséges méhzúgás
    if (zcr > 4200.0 && zcr <= 4700.0) return 'yellow'; // Emelkedett zúgás: rajzáskészültség / anyaprobléma
    if (zcr > 4700.0) return 'flashing_red'; // Heves méhzúgás: akut rajzás vagy pánik
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
    if (isQueenReplacementActive) return 'red'; // Anyacsere esetén azonnali sürgős piros kaptár
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
      if (isWeakOrSick || reportedDiseases.isNotEmpty) 'yellow',
      for (var box in boxes) box.status,
    ];
    if (statuses.contains('flashing_red')) return 'flashing_red';
    if (statuses.contains('red')) return 'red';
    if (statuses.contains('orange')) return 'orange';
    if (statuses.contains('yellow')) return 'yellow';
    return 'green';
  }

  /// Folyamatosan jól teljesítő (Top Performer) család:
  /// A kaptár sarkába aranysárga csillag (⭐) kerül
  bool get isTopPerformer {
    if (isQuarantined || reportedDiseases.isNotEmpty) return false;
    if (status != 'green' && status != 'optimal') return false;
    if (worstStatus != 'green') return false;
    if (isWeakOrSick) return false;
    if (queen?.needsReplacement == true) return false;
    if (dailyVarroaDrop >= 2.0) return false;
    if (swarmIndex >= 40.0) return false;
    if (temp < 33.0 || temp > 36.5) return false;
    if (weight < 25.0) return false;

    // Értékelési szempontok összegzése
    int plusCount = 0;
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
      if (val.contains('+')) plusCount++;
      if (val.contains('-')) minusCount++;
    }

    if (minusCount > 0) return false;
    return plusCount >= 4;
  }

  /// Rosszul teljesítő (Poor Performer) család:
  /// A kaptár sarkába piros lefelé nyíl (🔻) kerül
  bool get isPoorPerformer {
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
    final broodBoxes =
        boxes.where((b) => b.type == 'brood_box' || b.type == 'nest');
    if (broodBoxes.isEmpty) return true;

    return false;
  }

  String get weakOrSickReason {
    final reasons = <String>[];
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
      reasons.add('Hans-protokoll: Azonnali teljes megsemmisítés / elpusztítás!');
    }
    if (isQueenReplacementActive ||
        queen?.needsReplacement == true ||
        queen?.isAlive == false) {
      reasons.add('Anyaprobléma / anyacsere folyamatban');
    }
    if (familyFunction.toLowerCase().contains('selejt')) {
      reasons.add('Selejt család (Szezon végén más családok felerősítésére használható)');
    }
    final nm = name.toLowerCase();
    if (nm.contains('beteg') || nm.contains('gyenge') || nm.contains('pótcsalád') || nm.contains('potcsalad')) {
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
      reasons.add('Kedvezőtlen egyedi elbírálás ($_negativeEvaluationCount negatív jegy)');
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
    final broodBoxes =
        boxes.where((b) => b.type == 'brood_box' || b.type == 'nest');
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
  final LatLng location;
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
  final LatLng location;
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
    if (waterLevel < 25.0) return 'orange'; // Alacsony szint / utántöltést igényel
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
  final LatLng location;
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
    if (_customStatus == 'orange' && (lastOperationStatus.contains('SZTOJ') || lastOperationStatus.contains('Adagolás'))) {
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
  })  : _customStatus = status,
        pairedHiveNames = pairedHiveNames ?? [];
}
