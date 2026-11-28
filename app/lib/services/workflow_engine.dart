import '../hive_model.dart';

/// Adatbázisban (`public.workflow_templates`) tárolt folyamat-sablon.
class WorkflowTemplate {
  final String code;
  String name;
  String category; // 'anyasitas' | 'anyaneveles' | 'atkairtas' | 'tartozek_idozito' | 'egyeb'
  String mode; // 'sequential' | 'schedule_plan' | 'timer_rule'
  String description;
  bool isActive;
  int sortOrder;

  WorkflowTemplate({
    required this.code,
    required this.name,
    this.category = 'kezeles',
    this.mode = 'schedule_plan',
    this.description = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory WorkflowTemplate.fromJson(Map<String, dynamic> json) {
    return WorkflowTemplate(
      code: (json['code'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      category: (json['category'] ?? 'kezeles').toString().trim(),
      mode: (json['mode'] ?? 'schedule_plan').toString().trim(),
      description: (json['description'] ?? '').toString(),
      isActive: (json['is_active'] as bool?) ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'category': category,
    'mode': mode,
    'description': description,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}

/// Adatbázisban (`public.workflow_steps`) tárolt folyamat-lépés és időzítési szabály.
class WorkflowStepDef {
  int? dbId;
  final String workflowCode;
  int stepOrder;
  String stepKey;
  String title;
  String description;
  String buttonLabel;
  int delayHours;
  int? preferredHour;
  bool autoCompleteOnStart;
  int lockHours;
  int? acousticIntervalMin;
  String? statusEffect;
  String? urgencyOverride;

  WorkflowStepDef({
    this.dbId,
    required this.workflowCode,
    required this.stepOrder,
    required this.stepKey,
    required this.title,
    this.description = '',
    this.buttonLabel = 'Feladat készre jelentése',
    this.delayHours = 0,
    this.preferredHour,
    this.autoCompleteOnStart = false,
    this.lockHours = 0,
    this.acousticIntervalMin,
    this.statusEffect,
    this.urgencyOverride,
  });

  String get formattedDelayLabel {
    if (delayHours <= 0) return 'Azonnal (0. nap)';
    if (delayHours % 24 == 0) {
      final int days = delayHours ~/ 24;
      return '$days nap ($delayHours óra)';
    }
    if (delayHours > 24) {
      final int d = delayHours ~/ 24;
      final int remH = delayHours % 24;
      return '$d nap $remH óra ($delayHours óra)';
    }
    return '$delayHours óra';
  }

  DateTime computeDueDate(DateTime referenceTime) {
    final DateTime raw = referenceTime.add(Duration(hours: delayHours));
    if (preferredHour != null && delayHours >= 24) {
      return DateTime(
        raw.year,
        raw.month,
        raw.day,
        preferredHour!.clamp(0, 23),
        0,
      );
    }
    return raw;
  }

  factory WorkflowStepDef.fromJson(Map<String, dynamic> json) {
    return WorkflowStepDef(
      dbId: (json['id'] as num?)?.toInt(),
      workflowCode: (json['workflow_code'] ?? '').toString().trim(),
      stepOrder: (json['step_order'] as num?)?.toInt() ?? 1,
      stepKey: (json['step_key'] ?? 'step_1').toString().trim(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      buttonLabel: (json['button_label'] ?? '').toString(),
      delayHours: (json['delay_hours'] as num?)?.toInt() ?? 0,
      preferredHour: (json['preferred_hour'] as num?)?.toInt(),
      autoCompleteOnStart: (json['auto_complete_on_start'] as bool?) ?? false,
      lockHours: (json['lock_hours'] as num?)?.toInt() ?? 0,
      acousticIntervalMin: (json['acoustic_interval_min'] as num?)?.toInt(),
      statusEffect: json['status_effect']?.toString(),
      urgencyOverride: json['urgency_override']?.toString(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) => {
    if (includeId && dbId != null) 'id': dbId,
    'workflow_code': workflowCode,
    'step_order': stepOrder,
    'step_key': stepKey,
    'title': title,
    'description': description,
    'button_label': buttonLabel,
    'delay_hours': delayHours,
    'preferred_hour': preferredHour,
    'auto_complete_on_start': autoCompleteOnStart,
    'lock_hours': lockHours,
    'acoustic_interval_min': acousticIntervalMin,
    'status_effect': statusEffect,
    'urgency_override': urgencyOverride,
  };
}

/// Egy adott kaptár aktív szekvenciális folyamat-állapota (`public.hive_workflows`).
class HiveWorkflowState {
  int? dbId;
  final String monitorMac;
  final String workflowCode;
  int currentStepOrder;
  String stepKey;
  DateTime startedAt;
  DateTime stepStartedAt;
  DateTime? dueAt;
  bool isCompleted;
  Map<String, dynamic> metadata;

  HiveWorkflowState({
    this.dbId,
    required this.monitorMac,
    required this.workflowCode,
    required this.currentStepOrder,
    required this.stepKey,
    DateTime? startedAt,
    DateTime? stepStartedAt,
    this.dueAt,
    this.isCompleted = false,
    Map<String, dynamic>? metadata,
  }) : startedAt = startedAt ?? DateTime.now(),
       stepStartedAt = stepStartedAt ?? DateTime.now(),
       metadata = metadata ?? <String, dynamic>{};

  factory HiveWorkflowState.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedMeta = <String, dynamic>{};
    if (json['metadata'] is Map) {
      parsedMeta = Map<String, dynamic>.from(json['metadata'] as Map);
    }
    return HiveWorkflowState(
      dbId: (json['id'] as num?)?.toInt(),
      monitorMac: (json['monitor_mac'] ?? '').toString().trim(),
      workflowCode: (json['workflow_code'] ?? '').toString().trim(),
      currentStepOrder: (json['current_step_order'] as num?)?.toInt() ?? 1,
      stepKey: (json['step_key'] ?? '').toString().trim(),
      startedAt:
          DateTime.tryParse((json['started_at'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      stepStartedAt:
          DateTime.tryParse(
            (json['step_started_at'] ?? '').toString(),
          )?.toLocal() ??
          DateTime.now(),
      dueAt: json['due_at'] != null
          ? DateTime.tryParse(json['due_at'].toString())?.toLocal()
          : null,
      isCompleted: (json['is_completed'] as bool?) ?? false,
      metadata: parsedMeta,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) => {
    if (includeId && dbId != null) 'id': dbId,
    'monitor_mac': monitorMac,
    'workflow_code': workflowCode,
    'current_step_order': currentStepOrder,
    'step_key': stepKey,
    'started_at': startedAt.toUtc().toIso8601String(),
    'step_started_at': stepStartedAt.toUtc().toIso8601String(),
    'due_at': dueAt?.toUtc().toIso8601String(),
    'is_completed': isCompleted,
    'metadata': metadata,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

/// Beépített alapértelmezett folyamat-definíciók (offline / első indítási tartalék,
/// amely szinkronkor automatikusan frissül a Supabase `workflow_templates` és `workflow_steps` táblákból).
class DefaultBeeWorkflows {
  static List<WorkflowTemplate> createDefaultTemplates() => [
    WorkflowTemplate(
      code: 'anyasitas',
      name: 'Anyacsere & Szoktatós/Kirágós Anyásítás',
      category: 'anyasitas',
      mode: 'sequential',
      description:
          'Lépésről lépésre vezérelt anyacsere: régi anya elvétele -> zárt kalitkás szoktatás -> kirágósra nyitás + nyugalmi lakat -> petézés ellenőrzése.',
      sortOrder: 10,
    ),
    WorkflowTemplate(
      code: 'alcas_mesterterv',
      name: 'Álcás Anyanevelési Mesterterv (Átlárvázás)',
      category: 'anyaneveles',
      mode: 'schedule_plan',
      description:
          'Klasszikus 1 napos álcás (átlárvázásos) anyanevelési ütemterv: dajka előkészítés, álcázás, elfogadás, fedés, zárkázás, kelés, pároztatás és petézés kontroll.',
      sortOrder: 20,
    ),
    WorkflowTemplate(
      code: 'petes_mesterterv',
      name: 'Petés Anyanevelési Mesterterv',
      category: 'anyaneveles',
      mode: 'schedule_plan',
      description:
          'Zsidei-féle petés anyanevelési ütemterv a tenyészlép behelyezésétől a pároztatók ellenőrzéséig.',
      sortOrder: 30,
    ),
    WorkflowTemplate(
      code: 'grumpy_cat',
      name: 'Grumpy Cat – Zárt/Kirágós Anyásítási Protokoll',
      category: 'anyasitas',
      mode: 'schedule_plan',
      description: 'Fokozott nyugalmú anyásítási ütemterv (0., 1., 3., 8. nap).',
      sortOrder: 40,
    ),
    WorkflowTemplate(
      code: 'oxalsav_sorozat',
      name: 'Oxálsavas Sorozatszublimálás (Fiasításos ciklus)',
      category: 'atkairtas',
      mode: 'schedule_plan',
      description:
          'Fedett fiasítás melletti sorozatszublimálás (alapból 4 naponta, 6 alkalommal).',
      sortOrder: 50,
    ),
    WorkflowTemplate(
      code: 'oxalsav_egyszeri',
      name: 'Oxálsavas Egyszeri Kezelés',
      category: 'atkairtas',
      mode: 'schedule_plan',
      description:
          'Fiasításmentes időszaki egyszeri oxálsavas szublimálás vagy csurgatás.',
      sortOrder: 60,
    ),
    WorkflowTemplate(
      code: 'hangyasav',
      name: 'Hangyasavas Atkairtó Kezelés & Kontroll',
      category: 'atkairtas',
      mode: 'schedule_plan',
      description:
          'Hangyasavas párologtatás indítása és 7 napos hatásfok / anya kontroll.',
      sortOrder: 70,
    ),
    WorkflowTemplate(
      code: 'tarto_hordozo',
      name: 'Tartós Hordozós Atkairtó Csík (6 hét)',
      category: 'atkairtas',
      mode: 'schedule_plan',
      description:
          'Tartós hordozós csíkok behelyezése és kötelező eltávolítása 42 nap (6 hét) után.',
      sortOrder: 80,
    ),
    WorkflowTemplate(
      code: 'hereskeret',
      name: 'Heréskeret Biológiai Atkagyérítés',
      category: 'atkairtas',
      mode: 'schedule_plan',
      description:
          'Építtető keret behelyezése, petézés, fedés és kritikus kivágás a herék kelése előtt.',
      sortOrder: 90,
    ),
    WorkflowTemplate(
      code: 'felerosites_mesterterv',
      name: 'Selejt Család Hasznosítása / Felerősítés',
      category: 'egyeb',
      mode: 'schedule_plan',
      description:
          'Fias keretek és dajkaméhek átcsoportosítása gyengébb családok erősítéséhez.',
      sortOrder: 100,
    ),
    WorkflowTemplate(
      code: 'szoktetes_24h',
      name: 'Méhszöktető Leürítési Időzítő',
      category: 'tartozek_idozito',
      mode: 'timer_rule',
      description:
          'Méhszöktető behelyezése utáni visszaszámlálás a mézterek elvételéig (alapból 24 óra).',
      sortOrder: 110,
    ),
    WorkflowTemplate(
      code: 'varroa_aljdeszka',
      name: 'Atkavizsgáló Aljdeszka Kontroll Időzítő',
      category: 'tartozek_idozito',
      mode: 'timer_rule',
      description:
          'Betolt aljdeszka leolvasási ideje (alapból 72 óra = 3 nap).',
      sortOrder: 120,
    ),
    WorkflowTemplate(
      code: 'pollengyujto_urites',
      name: 'Virágporgyűjtő Tálca Ürítési Időzítő',
      category: 'tartozek_idozito',
      mode: 'timer_rule',
      description:
          'Aktív virágporgyűjtő ürítési gyakorisága (alapból 24 óra).',
      sortOrder: 130,
    ),
  ];

  static List<WorkflowStepDef> createDefaultSteps() => [
    // 1. ANYACSERE & ANYÁSÍTÁS
    WorkflowStepDef(
      workflowCode: 'anyasitas',
      stepOrder: 1,
      stepKey: 'needs_replacement',
      title: 'Régi méhanya eltávolítása',
      description:
          'A család anyacserére lett kijelölve. Keresd meg és távolítsd el a régi anyát!',
      buttonLabel: 'Anya eltávolítva',
      delayHours: 0,
      statusEffect: 'red',
      urgencyOverride: 'red',
    ),
    WorkflowStepDef(
      workflowCode: 'anyasitas',
      stepOrder: 2,
      stepKey: 'queen_removed',
      title: 'Új méhanya beadása zárt kalitkában (Szoktatós)',
      description:
          'A család anyátlan. Válassz vagy regisztrálj új anyát, és helyezd be zárt szoktató kalitkában!',
      buttonLabel: 'Új anya kiválasztása & beadása',
      delayHours: 0,
      statusEffect: 'red',
      urgencyOverride: 'red',
    ),
    WorkflowStepDef(
      workflowCode: 'anyasitas',
      stepOrder: 3,
      stepKey: 'introduced_cage',
      title: 'Anyakalitka kirágósra állítása',
      description:
          'A szoktatási idő letelt. Nyisd meg a cukorlepényes kirágónyílást a kalitkán, hogy a méhek békésen kiszabadítsák az új anyát!',
      buttonLabel: 'Anyakalitka átállítása kirágósra',
      delayHours: 72,
      preferredHour: 10,
      statusEffect: 'green',
    ),
    WorkflowStepDef(
      workflowCode: 'anyasitas',
      stepOrder: 4,
      stepKey: 'introduced_chewout',
      title: 'Anyásítás vizsgálata: Petézés & Fiasítás',
      description:
          'Lejárt a nyugalmi lakat időszak. Vizsgáld meg az új anya elfogadását, a friss petéket és az összefüggő fiasításképet!',
      buttonLabel: 'Anyásítás sikeres (Folyamat lezárása)',
      delayHours: 336,
      preferredHour: 10,
      lockHours: 336,
      acousticIntervalMin: 15,
      statusEffect: 'green',
    ),

    // 2. ÁLCÁS ANYANEVELÉSI MESTERTERV (ÁTLÁRVÁZÁS)
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 1,
      stepKey: 'alcas_0',
      title: 'Dajkacsalád erősítése és bölcsőzés (1. kör)',
      description:
          'Dajkacsalád előkészítése sűrített fészekkel, esetleges vad bölcsők lerombolása, serkentés indítása.',
      delayHours: 0,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 2,
      stepKey: 'alcas_2',
      title: 'Tenyészlép behelyezése a tenyészanyához',
      description:
          'Tiszta, világos épített lép behelyezése a törzs-/tenyészcsalád fészkébe az egykorú petézéshez.',
      delayHours: 48,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 3,
      stepKey: 'alcas_3',
      title: 'Tenyészlép ellenőrzése & Dajka 2. lebölcsőzése',
      description:
          'Petézés ellenőrzése a tenyészlépen, a dajkacsalád ismételt átvizsgálása.',
      delayHours: 72,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 4,
      stepKey: 'alcas_6',
      title: 'Álcázás (Átlárvázás bölcsőalapokba)',
      description:
          'A frissen kelt (1 napos, pempőben úszó) álcák átlárvázása a tenyészkeret bölcsőalapjaiba és beadása a dajkacsaládba.',
      buttonLabel: 'Álcázás elvégezve',
      delayHours: 144,
      preferredHour: 9,
      urgencyOverride: 'flashing_orange',
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 5,
      stepKey: 'alcas_7',
      title: 'Elfogadás ellenőrzése',
      description:
          'A meghúzott és pempőzött anyabölcsők darabszámának ellenőrzése.',
      delayHours: 168,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 6,
      stepKey: 'alcas_11',
      title: 'Anyabölcsők fedése',
      description:
          'Az álcázástól számított 5. napon a dajkaméhek lefedik az anyabölcsőket (innentől rázkódástól óvni!).',
      delayHours: 264,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 7,
      stepKey: 'alcas_16',
      title: 'Érett anyabölcsők zárkázása!',
      description:
          'Álcázástól számított 10. nap (kelés előtt 1-2 nappal): a fedett anyabölcsők kalitkázása kísérőméhekkel és élelemmel.',
      buttonLabel: 'Zárkázás kész',
      delayHours: 384,
      preferredHour: 9,
      urgencyOverride: 'flashing_orange',
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 8,
      stepKey: 'alcas_18',
      title: 'Méhanyák kelése',
      description:
          'Fiatal párzatlan méhanyák kelése a zárkákban, testi épség ellenőrzése.',
      delayHours: 432,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 9,
      stepKey: 'alcas_19',
      title: 'Pároztatók betelepítése és hűvösre tétele',
      description:
          'Pároztató kis-kaptárak betelepítése fiatal néppel és a kikelt anyákkal.',
      delayHours: 456,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 10,
      stepKey: 'alcas_22',
      title: 'Pároztatók kihelyezése és esti kibocsátása',
      description:
          'Pároztatók kihelyezése és a kijárók megnyitása napnyugtakor.',
      delayHours: 528,
      preferredHour: 18,
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 11,
      stepKey: 'alcas_30',
      title: 'Párzás és petézés ellenőrzése',
      description:
          'A megtermékenyült fiatal anyák petézésének és fiasításképének vizsgálata a pároztatókban.',
      delayHours: 720,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'alcas_mesterterv',
      stepOrder: 12,
      stepKey: 'alcas_31',
      title: 'Petéző anyák felhasználása / szállítása',
      description:
          'A bepetézett anyák zárkázása, jelölése és beadása a termelő családokba.',
      delayHours: 744,
      preferredHour: 9,
    ),

    // 3. PETÉS ANYANEVELÉSI MESTERTERV
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 1,
      stepKey: 'petes_0',
      title: 'Erősít és Lebölcsőz (1. kör)',
      description: 'Dajkacsalád előkészítése, bölcsők lerombolása.',
      delayHours: 0,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 2,
      stepKey: 'petes_1',
      title: 'Tenyészlép be',
      description: 'Tenyészlép behelyezése a tenyészcsaládba.',
      delayHours: 24,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 3,
      stepKey: 'petes_2',
      title: 'Tenyészlép ki',
      description: 'Tenyészlép kivétele petézés után.',
      delayHours: 48,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 4,
      stepKey: 'petes_3',
      title: 'Erősít, Lebölcsőz (2. kör) és Előkészít',
      description: 'Sejtek előkészítése / csíkozás a petés neveléshez.',
      delayHours: 72,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 5,
      stepKey: 'petes_4',
      title: 'Petés anyag áthelyezése a dajkacsaládba',
      description: 'Előkészített petés keret beadása a dajkacsaládba.',
      delayHours: 96,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 6,
      stepKey: 'petes_14',
      title: 'Fedett anyabölcsők zárkázása',
      description: 'Érett anyabölcsők kalitkázása kelés előtt.',
      delayHours: 336,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 7,
      stepKey: 'petes_16',
      title: 'Méhanyák kelése',
      description: 'Fiatal méhanyák kelése.',
      delayHours: 384,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 8,
      stepKey: 'petes_17',
      title: 'Pároztatók betelepítése',
      description: 'Pároztatók betelepítése és pincézése.',
      delayHours: 408,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 9,
      stepKey: 'petes_19',
      title: 'Pároztatók esti kibocsátása',
      description: 'Kijárók megnyitása este.',
      delayHours: 456,
      preferredHour: 18,
    ),
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 10,
      stepKey: 'petes_28',
      title: 'Petézés ellenőrzése',
      description: 'Fiatal anyák petézésének vizsgálata.',
      delayHours: 672,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'petes_mesterterv',
      stepOrder: 11,
      stepKey: 'petes_29',
      title: 'Szállítás / Felhasználás',
      description: 'Petéző anyák felhasználása.',
      delayHours: 696,
      preferredHour: 9,
    ),

    // 4. GRUMPY CAT
    WorkflowStepDef(
      workflowCode: 'grumpy_cat',
      stepOrder: 1,
      stepKey: 'gc_0',
      title: 'Anyátlanítás + Új anya zárt zárkában',
      description:
          'Öreg anya elvétele, bölcsők lerombolása, új anya behelyezése zárt zárkában.',
      delayHours: 0,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'grumpy_cat',
      stepOrder: 2,
      stepKey: 'gc_1',
      title: 'GRUMPY CAT – NE NYÚLJ HOZZÁ!',
      description: 'Tilos a kaptárt felnyitni vagy zavarni!',
      delayHours: 24,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'grumpy_cat',
      stepOrder: 3,
      stepKey: 'gc_3',
      title: 'Zárka megnyitása (Cukorlepény szabaddá tétele)',
      description:
          'Ha a méhek békésen csüngenek a zárkán, a kirágónyílás megnyitása.',
      delayHours: 72,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'grumpy_cat',
      stepOrder: 4,
      stepKey: 'gc_8',
      title: 'Petézés ellenőrzése',
      description: 'Friss peték keresése a fészekben.',
      delayHours: 192,
      preferredHour: 10,
    ),

    // 5. OXÁLSAV SOROZAT
    for (int i = 0; i < 6; i++)
      WorkflowStepDef(
        workflowCode: 'oxalsav_sorozat',
        stepOrder: i + 1,
        stepKey: 'ox_ser_${i + 1}',
        title: 'Oxálsavas szublimálás (${i + 1}/6. alkalom)',
        description:
            'Sorozatkezelés a kelő fiasítással kiszabaduló atkák ellen.',
        buttonLabel: 'Szublimálás kész',
        delayHours: i * 96,
        preferredHour: 9,
      ),

    // 6. EGYÉB KEZELÉSEK
    WorkflowStepDef(
      workflowCode: 'oxalsav_egyszeri',
      stepOrder: 1,
      stepKey: 'ox_1',
      title: 'Oxálsavas egyszeri kezelés',
      description: 'Fiasításmentes időszaki egyszeri szublimálás vagy csurgatás.',
      buttonLabel: 'Kezelés kész',
      delayHours: 0,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'hangyasav',
      stepOrder: 1,
      stepKey: 'formic_0',
      title: 'Hangyasavas kezelés indítása',
      description:
          'Hangyasavas párologtatás elindítva az időjárási ablak figyelembevételével.',
      buttonLabel: 'Elindítva',
      delayHours: 0,
      preferredHour: 9,
      autoCompleteOnStart: true,
    ),
    WorkflowStepDef(
      workflowCode: 'hangyasav',
      stepOrder: 2,
      stepKey: 'formic_7',
      title: 'Hangyasavas kezelés kontroll & atkahullás ellenőrzése',
      description:
          'Párolgás ütemének, méhanya meglétének és lehullott atkák számának ellenőrzése.',
      buttonLabel: 'Kontroll kész',
      delayHours: 168,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'tarto_hordozo',
      stepOrder: 1,
      stepKey: 'strip_0',
      title: 'Tartós hordozós atkairtó csík behelyezése',
      description: 'Hordozócsíkok behelyezése a fészekbe.',
      buttonLabel: 'Behelyezve',
      delayHours: 0,
      preferredHour: 9,
      autoCompleteOnStart: true,
    ),
    WorkflowStepDef(
      workflowCode: 'tarto_hordozo',
      stepOrder: 2,
      stepKey: 'strip_42',
      title: 'Tartós hordozós csíkok eltávolítása (6 hét)',
      description:
          'A kezelési ciklus lejárt: a csíkokat el kell távolítani a rezisztencia megelőzésére!',
      buttonLabel: 'Csíkok eltávolítva',
      delayHours: 1008,
      preferredHour: 10,
      urgencyOverride: 'flashing_orange',
    ),
    WorkflowStepDef(
      workflowCode: 'hereskeret',
      stepOrder: 1,
      stepKey: 'drone_0',
      title: 'Heréskeret behelyezése',
      description: 'Üres építtető keret behelyezése a fészek szélére.',
      delayHours: 0,
      preferredHour: 9,
    ),
    WorkflowStepDef(
      workflowCode: 'hereskeret',
      stepOrder: 2,
      stepKey: 'drone_4',
      title: 'Heréskeret kiépítés és petézés ellenőrzése',
      description: 'Kiépítés és petézés megindulásának ellenőrzése.',
      delayHours: 96,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'hereskeret',
      stepOrder: 3,
      stepKey: 'drone_13',
      title: 'Heresejtek fedése',
      description: 'A petézéstől számított 9. napon a sejtek lefedésre kerülnek.',
      delayHours: 312,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'hereskeret',
      stepOrder: 4,
      stepKey: 'drone_24',
      title: 'KRITIKUS: Fedett heréskeret kivágása!',
      description:
          'A fedett heréskeretet a 24. napi kelés előtt kötelező kivágni!',
      buttonLabel: 'Heréskeret kivágva',
      delayHours: 576,
      preferredHour: 9,
      urgencyOverride: 'flashing_red',
    ),
    WorkflowStepDef(
      workflowCode: 'felerosites_mesterterv',
      stepOrder: 1,
      stepKey: 'str_1',
      title: 'Selejt család hasznosítása (felerősítés / egyesítés)',
      description:
          'Fedett fias keretek vagy dajkaméhek átcsoportosítása gyengébb családok felerősítéséhez.',
      delayHours: 24,
      preferredHour: 10,
    ),

    // 7. TARTOZÉK IDŐZÍTŐK
    WorkflowStepDef(
      workflowCode: 'szoktetes_24h',
      stepOrder: 1,
      stepKey: 'escapement_timer',
      title: 'Leszöktetett fiókok elvétele',
      description:
          'A méhszöktető behelyezése utáni maximális időtartam a mézterek elvételéig.',
      buttonLabel: 'Szöktetés kész',
      delayHours: 24,
    ),
    WorkflowStepDef(
      workflowCode: 'varroa_aljdeszka',
      stepOrder: 1,
      stepKey: 'bottom_board_timer',
      title: 'Aljdeszka Varroa ellenőrzés & tisztítás',
      description: 'Atkavizsgáló tálca leolvasási ciklusa betolás után.',
      buttonLabel: 'Élőképes Atkaszámláló indítása',
      delayHours: 72,
      preferredHour: 10,
    ),
    WorkflowStepDef(
      workflowCode: 'pollengyujto_urites',
      stepOrder: 1,
      stepKey: 'pollen_trap_timer',
      title: 'Virágporgyűjtő fiók ürítése',
      description: 'Aktív virágporgyűjtő tálca ürítési ciklusa.',
      buttonLabel: 'Ürítve',
      delayHours: 24,
      preferredHour: 17,
    ),
  ];

  static List<ScheduledTask> generateScheduledTasks({
    required String hiveId,
    required WorkflowTemplate template,
    required List<WorkflowStepDef> steps,
    required DateTime startDate,
  }) {
    final sorted = List<WorkflowStepDef>.from(steps)
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    final int batchTs = startDate.millisecondsSinceEpoch;
    return sorted.map((s) {
      final DateTime due = s.computeDueDate(startDate);
      return ScheduledTask(
        id: 'WF_${template.code}_${hiveId}_${batchTs}_${s.stepOrder}',
        hiveId: hiveId,
        category: template.category,
        title: s.title,
        description: s.description,
        scheduledDate: due,
        isCompleted: s.autoCompleteOnStart,
      );
    }).toList();
  }
}
