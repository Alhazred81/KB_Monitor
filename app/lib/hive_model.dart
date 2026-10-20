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
  String name;
  String code; // QR-kód
  String? secondaryCode; // NFC azonosító
  String type; // 'brood_box', 'honey', 'feeder', 'escapement', 'vent', 'pollen_trap', 'bottom', 'roof'
  String size; // 'hunor', 'nb_rakodo', 'nb_fekvo', 'fel_nb', 'lang_deep', 'lang_med', 'lang_shal', 'dadant', 'fel_dadant'
  String status; // 'green', 'yellow', 'red', 'flashing_red'
  bool isActive; // Aljdeszka bent/kint, vagy pollengyűjtő be/ki
  DateTime? statusUpdatedAt;

  BoxElement({
    required this.name,
    required this.code,
    this.secondaryCode,
    required this.type,
    this.size = 'hunor',
    this.status = 'green',
    this.isActive = false,
    this.statusUpdatedAt,
  });

  bool get isVarroaCheckDue {
    if (type != 'bottom' || !isActive || statusUpdatedAt == null) {
      return false;
    }
    return DateTime.now().difference(statusUpdatedAt!).inDays >= 3;
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

  String get micStatus {
    if (zcr >= 3000.0 && zcr <= 4200.0) return 'green';
    if (zcr > 4200.0 && zcr <= 4700.0) return 'yellow';
    if (zcr > 5000.0) return 'flashing_red';
    return 'red';
  }

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
    if (boxes.any((b) => b.type == 'pollen_trap' && b.isActive)) {
      return 'orange';
    }

    final statuses = [
      nestCalculatedStatus,
      extTempStatus,
      for (var box in boxes) box.status,
    ];
    if (statuses.contains('flashing_red')) return 'flashing_red';
    if (statuses.contains('red')) return 'red';
    if (statuses.contains('yellow')) return 'yellow';
    return 'green';
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
  final String status;

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
