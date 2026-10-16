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
  String gathering; // Hordási kedv: '--', '-', '+', '++'
  String temperament; // Vérmérséklet: '--', '-', '+', '++'
  String hygiene; // Higiénia / Ellenállás: '--', '-', '+', '++'
  String consumption; // Takarmányigény ("zabagép"): '--', '-', '+', '++'
  String notes; // Gyors megjegyzés

  EvaluationData({
    this.gathering = '+',
    this.temperament = '+',
    this.hygiene = '+',
    this.consumption = '+',
    this.notes = '',
  });
}

class BoxElement {
  String name;
  String code; // Elsődleges azonosító (pl. QR kód)
  String? secondaryCode; // Másodlagos azonosító (pl. NFC tag)
  String type; // 'nest', 'honey', 'feeder', 'escapement', 'vent', 'pollen_trap', 'roof'
  String size; // 'dadant', 'fel_dadant', 'nb', 'hunor', 'fel_nb'
  String status; // 'green', 'yellow', 'red', 'flashing_red'

  BoxElement({
    required this.name,
    required this.code,
    this.secondaryCode,
    required this.type,
    this.size = 'dadant',
    this.status = 'green',
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
    this.queen,
    EvaluationData? evaluation,
    this.familyFunction = 'gyujto_mez',
    required this.boxes,
    required this.serverConnection,
    this.protocol,
  }) : evaluation = evaluation ?? EvaluationData();

  String get tempStatus {
    if (temp >= 32.0 && temp <= 36.0) return 'green';
    if ((temp >= 28.0 && temp < 32.0) || (temp > 36.0 && temp <= 37.5))
      return 'yellow';
    if (temp > 39.0 || temp < 15.0) return 'flashing_red';
    return 'red';
  }

  String get extTempStatus {
    if (extTemp >= 12.0 && extTemp <= 30.0) return 'green';
    if ((extTemp >= 5.0 && extTemp < 12.0) ||
        (extTemp > 30.0 && extTemp <= 35.0))
      return 'yellow';
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
    if (lower.contains('ok') || lower.contains('párosítva')) return 'green';
    if (lower.contains('gyenge')) return 'yellow';
    if (lower.contains('kritikus') || lower.contains('hiba'))
      return 'flashing_red';
    return 'red';
  }

  String get batteryStatus {
    if (batteryVoltage >= 3.8) return 'green';
    if (batteryVoltage >= 3.55) return 'yellow';
    if (batteryVoltage < 3.4) return 'flashing_red';
    return 'red';
  }

  String get nestCalculatedStatus {
    if (status == 'flashing_red' || protocol == 'hans') return 'flashing_red';
    final statuses = [
      tempStatus,
      weightStatus,
      micStatus,
      signalStatus,
      batteryStatus,
      if (queen?.needsReplacement == true) 'yellow',
    ];
    if (statuses.contains('flashing_red')) return 'flashing_red';
    if (statuses.contains('red')) return 'red';
    if (statuses.contains('yellow')) return 'yellow';
    return 'green';
  }

  String get worstStatus {
    if (status == 'flashing_red' || protocol == 'hans') return 'flashing_red';
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
