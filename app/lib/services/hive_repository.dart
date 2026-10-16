import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../hive_model.dart';

class HiveRepository extends ChangeNotifier {
  static final HiveRepository instance = HiveRepository._internal();
  HiveRepository._internal();

  final List<QueenData> _queens = [
    QueenData(
      id: 'QUEEN_2026_01',
      origin: 'Saját nevelés',
      vintage: '2026 (Fehér)',
    ),
    QueenData(
      id: 'QUEEN_2024_08',
      origin: 'Saját nevelés (Krajnai)',
      vintage: '2024 (Zöld)',
    ),
    QueenData(
      id: 'QUEEN_2023_14',
      origin: 'Vásárolt',
      vintage: '2023 (Piros)',
      needsReplacement: true,
    ),
    QueenData(
      id: 'QUEEN_2025_03',
      origin: 'Saját anyanevelés',
      vintage: '2025 (Kék)',
    ),
    QueenData(
      id: 'QUEEN_2025_02',
      origin: 'Vásárolt (Buckfast)',
      vintage: '2025 (Kék)',
    ),
  ];

  final List<HiveData> _hives = [
    // 1. ZÖLD: Minden szenzor és fiók rendben (Dadant)
    HiveData(
      id: 'HIVE_01',
      name: '1. Család (Termelő)',
      location: const LatLng(37.422500, -122.084500),
      status: 'green',
      temp: 34.5,
      humidity: 62.0,
      extTemp: 22.4,
      extHumidity: 54.0,
      weight: 42.5,
      batteryVoltage: 4.12,
      zcr: 3820.0,
      queen: QueenData(
        id: 'QUEEN_2026_01',
        origin: 'Saját nevelés',
        vintage: '2026 (Fehér)',
      ),
      familyFunction: 'gyujto_mez',
      boxes: [
        BoxElement(
          name: 'Fészekfiók',
          code: 'BOX_01_A',
          secondaryCode: 'NFC_9988',
          type: 'nest',
          size: 'dadant',
          status: 'green',
        ),
        BoxElement(
          name: 'Méztér',
          code: 'BOX_01_B',
          type: 'honey',
          size: 'fel_dadant',
          status: 'green',
        ),
        BoxElement(
          name: 'Etető',
          code: 'BOX_01_C',
          type: 'feeder',
          size: 'etetö',
          status: 'green',
        ),
      ],
      serverConnection: 'Wi-Fi / ESP-NOW OK (-62 dBm)',
    ),

    // 2. SÁRGA: Fészek rendben, de a felső Hunor méztér megtelt (NB rendszer)
    HiveData(
      id: 'HIVE_02',
      name: '2. Család (Pergetésre vár)',
      location: const LatLng(37.422350, -122.084200),
      status: 'yellow',
      temp: 34.8,
      humidity: 58.0,
      extTemp: 22.4,
      extHumidity: 54.0,
      weight: 56.2,
      batteryVoltage: 3.98,
      zcr: 3650.0,
      queen: QueenData(
        id: 'QUEEN_2024_08',
        origin: 'Saját nevelés (Krajnai)',
        vintage: '2024 (Zöld)',
      ),
      familyFunction: 'gyujto_mez',
      boxes: [
        BoxElement(
          name: 'Fészekfiók',
          code: 'BOX_02_A',
          type: 'nest',
          size: 'nb',
          status: 'green',
        ),
        BoxElement(
          name: 'Méztér',
          code: 'BOX_02_B',
          type: 'honey',
          size: 'hunor',
          status: 'green',
        ),
        BoxElement(
          name: 'Méztér',
          code: 'BOX_02_C',
          type: 'honey',
          size: 'hunor',
          status: 'yellow',
        ),
        BoxElement(
          name: 'Tető',
          code: 'BOX_02_D',
          type: 'roof',
          size: 'roof',
          status: 'green',
        ),
      ],
      serverConnection: 'Wi-Fi / ESP-NOW OK (-68 dBm)',
    ),

    // 3. SÁRGA: Anyacsere esedékes + alacsonyabb súly és gyenge térerő
    HiveData(
      id: 'HIVE_03',
      name: '3. Család (Anyacsere + Etetés)',
      location: const LatLng(37.422150, -122.084650),
      status: 'yellow',
      temp: 31.2,
      humidity: 64.0,
      extTemp: 22.1,
      extHumidity: 55.0,
      weight: 24.5,
      batteryVoltage: 3.85,
      zcr: 4350.0,
      queen: QueenData(
        id: 'QUEEN_2023_14',
        origin: 'Vásárolt',
        vintage: '2023 (Piros)',
        needsReplacement: true,
      ),
      familyFunction: 'szaporitas_anya',
      boxes: [
        BoxElement(
          name: 'Fészekfiók',
          code: 'BOX_03_A',
          type: 'nest',
          size: 'dadant',
          status: 'yellow',
        ),
        BoxElement(
          name: 'Etető',
          code: 'BOX_03_B',
          type: 'feeder',
          size: 'feeder',
          status: 'green',
        ),
        BoxElement(
          name: 'Szellőző',
          code: 'BOX_03_C',
          type: 'vent',
          size: 'vent',
          status: 'green',
        ),
      ],
      serverConnection: 'Gyenge jel (-86 dBm)',
      protocol: 'grumpy',
    ),

    // 4. PIROS: Magas fészekhőmérséklet, merülő akku és magas akusztikai frekvencia
    HiveData(
      id: 'HIVE_04',
      name: '4. Család (Túlmelegedés / Akku)',
      location: const LatLng(37.422600, -122.083600),
      status: 'red',
      temp: 38.2,
      humidity: 45.0,
      extTemp: 23.0,
      extHumidity: 50.0,
      weight: 33.0,
      batteryVoltage: 3.45,
      zcr: 4850.0,
      queen: QueenData(
        id: 'QUEEN_2025_03',
        origin: 'Saját anyanevelés',
        vintage: '2025 (Kék)',
      ),
      familyFunction: 'gyujto_viragpor',
      boxes: [
        BoxElement(
          name: 'Fészekfiók',
          code: 'BOX_04_A',
          type: 'nest',
          size: 'nb',
          status: 'red',
        ),
        BoxElement(
          name: 'Pollengyűjtő',
          code: 'BOX_04_B',
          type: 'pollen_trap',
          size: 'pollen_trap',
          status: 'green',
        ),
        BoxElement(
          name: 'Méztér',
          code: 'BOX_04_C',
          type: 'honey',
          size: 'fel_nb',
          status: 'green',
        ),
      ],
      serverConnection: 'Wi-Fi / ESP-NOW OK (-71 dBm)',
    ),

    // 5. VILLOGÓ PIROS: Hans-protokoll (Fertőzés / Karantén)
    HiveData(
      id: 'HIVE_05',
      name: '5. Család (Vészhelyzet!)',
      location: const LatLng(37.422700, -122.083900),
      status: 'flashing_red',
      temp: 40.2,
      humidity: 28.0,
      extTemp: 24.1,
      extHumidity: 48.0,
      weight: 64.0,
      batteryVoltage: 3.31,
      zcr: 5100.0,
      queen: QueenData(
        id: 'QUEEN_2025_02',
        origin: 'Vásárolt (Buckfast)',
        vintage: '2025 (Kék)',
      ),
      familyFunction: 'hans',
      boxes: [
        BoxElement(
          name: 'Fészekfiók',
          code: 'BOX_05_A',
          type: 'nest',
          size: 'dadant',
          status: 'flashing_red',
        ),
        BoxElement(
          name: 'Szöktető',
          code: 'BOX_05_B',
          type: 'escapement',
          size: 'szokteto',
          status: 'flashing_red',
        ),
        BoxElement(
          name: 'Méztér',
          code: 'BOX_05_C',
          type: 'honey',
          size: 'fel_dadant',
          status: 'flashing_red',
        ),
      ],
      serverConnection: 'Kritikus - Utolsó jel: 4 perce',
      protocol: 'hans',
    ),
  ];

  List<HiveData> get hives => _hives;
  List<QueenData> get queens => _queens;

  // Keresés elsődleges vagy másodlagos (NFC/QR) kód alapján
  dynamic findElementByCode(String scannedCode) {
    final cleanCode = scannedCode.trim();
    for (var hive in _hives) {
      if (hive.id == cleanCode) return hive;
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
    notifyListeners();
  }

  void addHive(HiveData hive) {
    _hives.add(hive);
    notifyListeners();
  }

  void addBoxToHive(HiveData hive, BoxElement box) {
    hive.boxes.add(box);
    notifyListeners();
  }

  void updateHive(HiveData hive) {
    notifyListeners();
  }
}
