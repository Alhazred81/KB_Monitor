import 'package:latlong2/latlong.dart';

class QueenData {
  final String id;
  final String origin;
  final String vintage;
  final bool isAlive;
  bool needsReplacement;

  QueenData({
    required this.id,
    required this.origin,
    required this.vintage,
    this.isAlive = true,
    this.needsReplacement = false,
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

  BoxElement({
    this.dbId,
    required this.name,
    required this.code,
    this.secondaryCode,
    required this.type,
    this.size = 'dadant',
    this.status = 'green',
    this.isActive = false,
    this.statusUpdatedAt,
    this.positionIndex,
  });

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
}

int getBoxRank(BoxElement b) {
  final t = b.type.toLowerCase();
  final n = b.name.toLowerCase();

  // Sorrend a kaptártoronyban alulról felfelé (0 = aljdeszka, 70 = tető)
  if (t == 'bottom' || n.contains('alj')) return 0;
  if (t == 'pollen_trap' || n.contains('pollen') || n.contains('virágpor')) return 10;
  if (t == 'brood_box' || t == 'nest' || n.contains('fészek') || n.contains('feszek')) return 20;
  if (t == 'honey' || n.contains('méz') || n.contains('mez')) return 30;
  if (t == 'escapement' || n.contains('szöktet') || n.contains('szoktet')) return 40;
  if (t == 'vent' || n.contains('szellőz') || n.contains('szelloz')) return 50;
  if (t == 'feeder' || t == 'roof_feeder' || n.contains('etető') || n.contains('eteto')) return 60; // Közvetlenül a tető alatt
  if (t == 'roof' || n.contains('tető') || n.contains('teto') || n.contains('fedő') || n.contains('dekli')) return 70; // Legfelül
  return 35;
}

void sortHiveBoxes(List<BoxElement> boxes) {
  // Szigorú szabály: egy kaptárban kizárólag egyetlen tető és egyetlen aljdeszka lehet
  bool seenRoof = false;
  bool seenBottom = false;
  boxes.removeWhere((b) {
    final t = b.type.toLowerCase();
    final n = b.name.toLowerCase();
    final isRoof = t == 'roof' ||
        n.contains('tető') ||
        n.contains('teto') ||
        n.contains('fedő') ||
        n.contains('dekli');
    final isBottom = t == 'bottom' || n.contains('alj');
    if (isRoof) {
      if (seenRoof) return true;
      seenRoof = true;
    }
    if (isBottom) {
      if (seenBottom) return true;
      seenBottom = true;
    }
    return false;
  });
  // Ha a fiókoknak van manuálisan beállított sorrendje (positionIndex), azt tiszteletben tartjuk,
  // de a tető (roof) mindig a legfelső (utolsó), az aljdeszka (bottom) mindig a legalsó (első) elem marad.
  final hasExplicitPositions = boxes.any((b) => b.positionIndex != null);
  if (hasExplicitPositions) {
    boxes.sort((a, b) {
      if (a.type == 'bottom') return -1;
      if (b.type == 'bottom') return 1;
      if (a.type == 'roof') return 1;
      if (b.type == 'roof') return -1;

      final posA = a.positionIndex ?? getBoxRank(a);
      final posB = b.positionIndex ?? getBoxRank(b);
      return posA.compareTo(posB);
    });
  } else {
    boxes.sort((a, b) => getBoxRank(a).compareTo(getBoxRank(b)));
  }

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
      b.name.toLowerCase().contains('méz') ||
      b.name.toLowerCase().contains('mez'));
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
    required this.extTemp,
    required this.extHumidity,
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
    required this.serverConnection,
    this.protocol,
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
  }) : evaluation = evaluation ?? EvaluationData();

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
    if (status == 'flashing_red' || protocol == 'hans') return 'flashing_red';
    if (status == 'purple' || swarmIndex >= 70.0) return 'purple';
    if (status == 'red') return 'red';
    if (boxes.any((b) => b.type == 'pollen_trap' && b.isActive)) {
      return 'orange';
    }

    final statuses = [
      status,
      nestCalculatedStatus,
      extTempStatus,
      if (isWeakOrSick) 'yellow',
      for (var box in boxes) box.status,
    ];
    if (statuses.contains('flashing_red')) return 'flashing_red';
    if (statuses.contains('red')) return 'red';
    if (statuses.contains('orange')) return 'orange';
    if (statuses.contains('yellow')) return 'yellow';
    return 'green';
  }

  // --- GYENGE / BETEG CSALÁD DETEKTÁLÁSA (MEGCSAPOLÁS VÉDELEM) ---
  bool get isWeakOrSick {
    // 1. Státuszkódok (Piros, Villogó piros, Sárga gyenge állapot)
    if (status == 'red' || status == 'flashing_red' || status == 'yellow') {
      return true;
    }
    if (nestCalculatedStatus == 'red' ||
        nestCalculatedStatus == 'flashing_red' ||
        nestCalculatedStatus == 'yellow') {
      return true;
    }

    // 2. Mentési protokoll
    if (protocol == 'hans' ||
        protocol?.toLowerCase().contains('hans') == true) {
      return true;
    }

    // 3. Kaptár neve / száma (ha tartalmazza a "beteg", "gyenge", "felszámol" szavakat)
    final nm = name.toLowerCase();
    if (nm.contains('beteg') ||
        nm.contains('gyenge') ||
        nm.contains('felszamol') ||
        nm.contains('karanten') ||
        nm.contains('mentes')) {
      return true;
    }

    // 4. Családfunkció
    final fn = familyFunction.toLowerCase();
    if (fn.contains('felszamol') ||
        fn.contains('beteg') ||
        fn.contains('gyenge') ||
        fn.contains('mentes') ||
        fn.contains('karanten') ||
        fn.contains('szezon végén') ||
        fn.contains('hans')) {
      return true;
    }

    // 5. Értékelési megjegyzések
    final evNotes = evaluation.notes.toLowerCase();
    if (evNotes.contains('beteg') ||
        evNotes.contains('gyenge') ||
        evNotes.contains('felszamol') ||
        evNotes.contains('karanten')) {
      return true;
    }

    // 6. Szenzormérések és biológiai paraméterek
    if (dailyVarroaDrop >= 3.0) return true;
    if (temp > 0.0 && temp < 32.0) return true;
    if (weight > 0.0 && weight < 20.0) return true;

    // 7. Család toronyszerkezete: ha nincs valódi fészekfiókja
    final broodBoxes =
        boxes.where((b) => b.type == 'brood_box' || b.type == 'nest');
    if (broodBoxes.isEmpty) return true;

    return false;
  }

  String get weakOrSickReason {
    final reasons = <String>[];
    if (status == 'flashing_red' || nestCalculatedStatus == 'flashing_red') {
      reasons.add('Kritikus riasztás / vészhelyzet');
    } else if (status == 'red' || nestCalculatedStatus == 'red') {
      reasons.add('Veszélyeztetett állapot (piros riasztás)');
    } else if (status == 'yellow' || nestCalculatedStatus == 'yellow') {
      reasons.add('Sárga (gyenge / beavatkozást igénylő) státusz');
    }
    if (protocol == 'hans' ||
        protocol?.toLowerCase().contains('hans') == true ||
        familyFunction.toLowerCase() == 'hans') {
      reasons.add('Hans-protokoll: Azonnali teljes megsemmisítés / elpusztítás!');
    }
    if (familyFunction.toLowerCase().contains('selejt')) {
      reasons.add('Selejt család (Szezon végén más családok felerősítésére használható)');
    }
    final nm = name.toLowerCase();
    if (nm.contains('beteg')) {
      reasons.add('Megnevezés: Gyenge család');
    } else if (nm.contains('gyenge')) {
      reasons.add('Megnevezés: Gyenge család');
    } else if (nm.contains('felszamol')) {
      reasons.add('Megnevezés: Felszámolás alatt álló család');
    }
    final fn = familyFunction.toLowerCase();
    if (fn.contains('beteg')) {
      reasons.add('Gyenge kondíciójú család');
    } else if (fn.contains('gyenge')) {
      reasons.add('Gyenge termelőképességű család');
    } else if (fn.contains('felszamol') || fn.contains('szezon végén')) {
      reasons.add('Felszámolás alatt áll');
    }
    final evNotes = evaluation.notes.toLowerCase();
    if (evNotes.contains('beteg') || evNotes.contains('gyenge')) {
      reasons.add('Értékelési megjegyzés: Gyenge család');
    }
    if (dailyVarroaDrop >= 3.0) {
      reasons.add(
        'Megnövekedett atkahullás (${dailyVarroaDrop.toStringAsFixed(1)} db/nap)',
      );
    }
    if (temp > 0.0 && temp < 32.0) {
      reasons.add(
        'Alacsony fészakhőmérséklet (${temp.toStringAsFixed(1)} °C, fiasítás kihűlés veszélye)',
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
  double waterLevel;
  double waterTemp;
  final double batteryVoltage;
  final String status;

  WatererData({
    required this.id,
    required this.name,
    required this.location,
    required this.waterLevel,
    required this.waterTemp,
    required this.batteryVoltage,
    this.status = 'green',
  });
}

class SyrupPumpData {
  final String id;
  final String name;
  final LatLng location;
  double totalPumpedLiters;
  String lastOperationStatus;
  final String status;

  SyrupPumpData({
    required this.id,
    required this.name,
    required this.location,
    required this.totalPumpedLiters,
    required this.lastOperationStatus,
    this.status = 'green',
  });
}
