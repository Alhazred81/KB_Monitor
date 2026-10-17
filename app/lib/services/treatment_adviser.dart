import '../hive_model.dart';

class TreatmentAdviser {
  // Hangyasavas kezelés ellenőrzése az időjárás-állomás adatai alapján
  static Map<String, dynamic> checkFormicAcidConditions(
    StationData weatherStation,
  ) {
    final double temp = weatherStation.temp;
    final double rain = weatherStation.rainAmount;
    final double humidity = weatherStation.humidity;

    if (temp > 25.0) {
      return {
        'recommended': false,
        'title': 'Hangyasavas kezelés nem javasolt (Túl meleg)',
        'reason':
            'Az időjárás-állomás jelenleg ${temp.toStringAsFixed(1)} °C-ot mér. 25 °C felett a túl gyors párolgás anyavesztést és fiasításégést okozhat.',
      };
    }
    if (temp < 12.0) {
      return {
        'recommended': false,
        'title': 'Hangyasavas kezelés nem javasolt (Túl hűvös)',
        'reason':
            'Az időjárás-állomás ${temp.toStringAsFixed(1)} °C-ot mér. 12 °C alatt a párolgás nem elégséges.',
      };
    }
    if (rain > 0.0 || humidity > 85.0) {
      return {
        'recommended': false,
        'title': 'Hangyasavas kezelés nem javasolt (Csapadék / Magas pára)',
        'reason':
            'Eső (${rain.toStringAsFixed(1)} mm) vagy túl magas páratartalom (${humidity.toStringAsFixed(0)}%) rontja a hatásfokot.',
      };
    }

    return {
      'recommended': true,
      'title': 'Ideális ablak hangyasavas kezeléshez',
      'reason':
          'Hőmérséklet: ${temp.toStringAsFixed(1)} °C, Pára: ${humidity.toStringAsFixed(0)}%, Csapadék: 0 mm.',
    };
  }

  // 1. Petés Anyanevelési Mesterterv (Zsidei Barnabás táblázata alapján)
  static List<ScheduledTask> generatePetesMasterPlan(
    String hiveId,
    DateTime startDate,
  ) {
    final steps = [
      {
        'offset': 0,
        'title': 'Erősít és Lebölcsőz (1. kör)',
        'desc': 'Dajkacsalád előkészítése, bölcsők lerombolása.',
      },
      {
        'offset': 1,
        'title': 'Tenyészlép be',
        'desc': 'Tenyészlép behelyezése a tenyészcsaládba.',
      },
      {
        'offset': 2,
        'title': 'Tenyészlép ki',
        'desc': 'Tenyészlép kivétele petézés után.',
      },
      {
        'offset': 3,
        'title': 'Erősít, Lebölcsőz (2. kör) és Álcáz',
        'desc': 'Sejtek előkészítése / csíkozás a petés neveléshez.',
      },
      {
        'offset': 4,
        'title': 'Áthelyez',
        'desc': 'Előkészített petés anyag áthelyezése a dajkacsaládba.',
      },
      {
        'offset': 14,
        'title': 'Zárkáz',
        'desc': 'Fedett anyabölcsők kalitkázása.',
      },
      {'offset': 16, 'title': 'Kelés', 'desc': 'Méhanyák kelése.'},
      {
        'offset': 17,
        'title': 'Telepít, kihelyez',
        'desc': 'Pároztatók betelepítése és kihelyezése.',
      },
      {
        'offset': 19,
        'title': 'Kihord (kibocsát)',
        'desc': 'Pároztatók kijáróinak megnyitása este.',
      },
      {
        'offset': 28,
        'title': 'Petézés ellenőrzése',
        'desc': 'Fiatal anyák petézésének vizsgálata.',
      },
      {
        'offset': 29,
        'title': 'Szállítás / Felhasználás',
        'desc': 'Petéző anyák elvitele.',
      },
    ];

    return steps.map((s) {
      final offset = s['offset'] as int;
      return ScheduledTask(
        id: 'PETES_${hiveId}_${startDate.millisecondsSinceEpoch}_$offset',
        hiveId: hiveId,
        category: 'anyaneveles_petes',
        title: s['title'] as String,
        description: s['desc'] as String,
        scheduledDate: startDate.add(Duration(days: offset)),
      );
    }).toList();
  }

  // 2. Álcás Anyanevelési Mesterterv (Zsidei Barnabás táblázata alapján)
  static List<ScheduledTask> generateAlcasMasterPlan(
    String hiveId,
    DateTime startDate,
  ) {
    final steps = [
      {
        'offset': 0,
        'title': 'Erősít és Bölcsőz (1. kör)',
        'desc': 'Dajkacsalád erősítése és bölcsőzés.',
      },
      {
        'offset': 2,
        'title': 'Tenyészlép be',
        'desc': 'Tenyészlép behelyezése a tenyészanyához.',
      },
      {
        'offset': 3,
        'title': 'Tenyészlép ki, Erősít és Bölcsőz (2. kör)',
        'desc': 'Tenyészlép kivétele és dajkacsalád ellenőrzése.',
      },
      {
        'offset': 6,
        'title': 'Álcáz',
        'desc': 'Fiatal lárvák átlárvázása a bölcsőalapokba.',
      },
      {'offset': 9, 'title': 'Zárkáz', 'desc': 'Bölcsők zárkázása.'},
      {'offset': 18, 'title': 'Kelés', 'desc': 'Méhanyák kelése.'},
      {
        'offset': 19,
        'title': 'Telepít, kihelyez',
        'desc': 'Pároztatók telepítése.',
      },
      {
        'offset': 22,
        'title': 'Kihord (kibocsát)',
        'desc': 'Pároztatók kibocsátása.',
      },
      {
        'offset': 24,
        'title': 'Ráanyásít',
        'desc': 'Szükség szerinti pótlás / ráanyásítás.',
      },
      {
        'offset': 30,
        'title': 'Petézés ellenőrzése',
        'desc': 'Petéző anyák ellenőrzése.',
      },
      {'offset': 31, 'title': 'Szállítás', 'desc': 'Anyák szállítása.'},
    ];

    return steps.map((s) {
      final offset = s['offset'] as int;
      return ScheduledTask(
        id: 'ALCAS_${hiveId}_${startDate.millisecondsSinceEpoch}_$offset',
        hiveId: hiveId,
        category: 'anyaneveles_alcas',
        title: s['title'] as String,
        description: s['desc'] as String,
        scheduledDate: startDate.add(Duration(days: offset)),
      );
    }).toList();
  }

  // 3. Anyásítás: "Grumpy cat - do not touch" protokoll
  static List<ScheduledTask> generateGrumpyCatProtocol(
    String hiveId,
    DateTime startDate,
  ) {
    return [
      ScheduledTask(
        id: 'GC_${hiveId}_0',
        hiveId: hiveId,
        category: 'grumpy_cat',
        title: 'Anyátlanítás + Új anya zárt zárkában',
        description: 'Öreg anya elvétele, bölcsők lerombolása, új anya behelyezése zárt zárkában.',
        scheduledDate: startDate,
      ),
      ScheduledTask(
        id: 'GC_${hiveId}_1',
        hiveId: hiveId,
        category: 'grumpy_cat',
        title: 'GRUMPY CAT - DO NOT TOUCH!',
        description: 'Tilos a kaptárt felnyitni vagy zavarni! A család még agresszív lehet a zárkával.',
        scheduledDate: startDate.add(const Duration(days: 1)),
      ),
      ScheduledTask(
        id: 'GC_${hiveId}_3',
        hiveId: hiveId,
        category: 'grumpy_cat',
        title: 'Zárka megnyitása (Cukorlepény szabaddá tétele)',
        description: 'Ha a méhek békésen csüngenek a zárkán, a kijáratot szabaddá tesszük, hogy kirágják.',
        scheduledDate: startDate.add(const Duration(days: 3)),
      ),
      ScheduledTask(
        id: 'GC_${hiveId}_8',
        hiveId: hiveId,
        category: 'grumpy_cat',
        title: 'Petézés ellenőrzése',
        description: 'Friss peték keresése a fészekben.',
        scheduledDate: startDate.add(const Duration(days: 8)),
      ),
    ];
  }

  // 4. Oxálsavas kezelés (Egyszeri vagy 21-24 napos sorozatkezelés)
  static List<ScheduledTask> generateOxalicPlan(
    String hiveId,
    DateTime startDate, {
    required bool isSeries,
  }) {
    if (!isSeries) {
      return [
        ScheduledTask(
          id: 'OX_SINGLE_${hiveId}_${startDate.millisecondsSinceEpoch}',
          hiveId: hiveId,
          category: 'oxalsav',
          title: 'Oxálsavas egyszeri kezelés',
          description:
              'Fiasításmentes időszaki egyszeri csurgatás vagy szublimálás.',
          scheduledDate: startDate,
        ),
      ];
    }

    // 21-24 napos sorozatkezelés (4 naponta, 6 alkalommal = 20-24 nap lefedettség a fedett fiasítás ciklusa alatt)
    final List<ScheduledTask> series = [];
    for (int i = 0; i < 6; i++) {
      final int dayOffset = i * 4;
      series.add(
        ScheduledTask(
          id: 'OX_SER_${hiveId}_$i',
          hiveId: hiveId,
          category: 'oxalsav',
          title: 'Oxálsav szublimálás (${i + 1}/6. alkalom - $dayOffset. nap)',
          description: 'Sorozatkezelés a kelő fiasítással kiszabaduló atkák ellen (21-24 napos ciklus).',
          scheduledDate: startDate.add(Duration(days: dayOffset)),
        ),
      );
    }
    return series;
  }

  // 5. Heréskeret (Kiépítés, fedés 9. nap, kivágás 21-23. nap között)
  static List<ScheduledTask> generateDroneFramePlan(
    String hiveId,
    DateTime insertDate,
  ) {
    return [
      ScheduledTask(
        id: 'DRONE_${hiveId}_0',
        hiveId: hiveId,
        category: 'hereskeret',
        title: 'Heréskeret behelyezése',
        description: 'Üres építtető keret behelyezése a fészek szélére.',
        scheduledDate: insertDate,
      ),
      ScheduledTask(
        id: 'DRONE_${hiveId}_4',
        hiveId: hiveId,
        category: 'hereskeret',
        title: 'Heréskeret kiépítés és petézés ellenőrzése',
        description:
            'Várhatóan kiépítve (3-5 nap), az anya megkezdi a petézést.',
        scheduledDate: insertDate.add(const Duration(days: 4)),
      ),
      ScheduledTask(
        id: 'DRONE_${hiveId}_13',
        hiveId: hiveId,
        category: 'hereskeret',
        title: 'Heresejtek fedése',
        description:
            'A petézéstől számított 9. napon a sejtek lefedésre kerülnek.',
        scheduledDate: insertDate.add(const Duration(days: 13)),
      ),
      ScheduledTask(
        id: 'DRONE_${hiveId}_25',
        hiveId: hiveId,
        category: 'hereskeret',
        title: 'KRITIKUS: Fedett heréskeret kivágása!',
        description: 'A petézéstől számított 21-23. nap: a keretet ki kell vágni a 24. napi kelés előtt!',
        scheduledDate: insertDate.add(const Duration(days: 25)),
      ),
    ];
  }
}
