class WeeklyScheduleEntry {
  int? id;
  int dayOfWeek; // 1=Lun, 2=Mar, 3=Mer, 4=Gio, 5=Ven, 6=Sab
  int rowIndex;
  String oraInizio; // "08:30"
  String oraFine; // "13:00"
  double ore; // auto-calculated
  String utenteAssistito;
  String servizio;
  String comune;

  WeeklyScheduleEntry({
    this.id,
    required this.dayOfWeek,
    required this.rowIndex,
    this.oraInizio = '',
    this.oraFine = '',
    this.ore = 0,
    this.utenteAssistito = '',
    this.servizio = '',
    this.comune = '',
  });

  void calcolaOre() {
    try {
      if (oraInizio.isEmpty || oraFine.isEmpty) {
        ore = 0;
        return;
      }
      final pi = oraInizio.split(':');
      final pf = oraFine.split(':');
      final inizio =
          Duration(hours: int.parse(pi[0]), minutes: int.parse(pi[1]));
      final fine = Duration(hours: int.parse(pf[0]), minutes: int.parse(pf[1]));
      final diff = fine - inizio;
      ore = diff.inMinutes / 60.0;
      if (ore < 0) ore = 0;
    } catch (_) {
      ore = 0;
    }
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'day_of_week': dayOfWeek,
        'row_index': rowIndex,
        'ora_inizio': oraInizio,
        'ora_fine': oraFine,
        'ore': ore,
        'utente_assistito': utenteAssistito,
        'servizio': servizio,
        'comune': comune,
      };

  factory WeeklyScheduleEntry.fromJson(Map<String, dynamic> j) =>
      WeeklyScheduleEntry(
        id: j['id'] as int?,
        dayOfWeek: j['day_of_week'] as int,
        rowIndex: j['row_index'] as int,
        oraInizio: (j['ora_inizio'] as String?) ?? '',
        oraFine: (j['ora_fine'] as String?) ?? '',
        ore: ((j['ore'] as num?) ?? 0).toDouble(),
        utenteAssistito: (j['utente_assistito'] as String?) ?? '',
        servizio: (j['servizio'] as String?) ?? '',
        comune: (j['comune'] as String?) ?? '',
      );

  WeeklyScheduleEntry copyWith({
    int? id,
    int? dayOfWeek,
    int? rowIndex,
    String? oraInizio,
    String? oraFine,
    double? ore,
    String? utenteAssistito,
    String? servizio,
    String? comune,
  }) =>
      WeeklyScheduleEntry(
        id: id ?? this.id,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        rowIndex: rowIndex ?? this.rowIndex,
        oraInizio: oraInizio ?? this.oraInizio,
        oraFine: oraFine ?? this.oraFine,
        ore: ore ?? this.ore,
        utenteAssistito: utenteAssistito ?? this.utenteAssistito,
        servizio: servizio ?? this.servizio,
        comune: comune ?? this.comune,
      );
}

class WeeklyScheduleModel {
  final int? id;
  final DateTime weekStart; // always Monday
  String periodoRiferimento;
  final DateTime? updatedAt;
  List<WeeklyScheduleEntry> entries;

  WeeklyScheduleModel({
    this.id,
    required this.weekStart,
    this.periodoRiferimento = '',
    this.updatedAt,
    required this.entries,
  });

  double get totaleSettimana => entries.fold(0, (s, e) => s + e.ore);

  double totaleGiorno(int dayOfWeek) =>
      entries.where((e) => e.dayOfWeek == dayOfWeek).fold(0, (s, e) => s + e.ore);

  List<WeeklyScheduleEntry> entriesForDay(int dayOfWeek) {
    final list = entries.where((e) => e.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
    return list;
  }

  Map<String, dynamic> toJson() => {
        'week_start':
            '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}',
        'periodo_riferimento': periodoRiferimento,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory WeeklyScheduleModel.fromJson(Map<String, dynamic> j) {
    final ws = DateTime.parse(j['week_start'] as String);
    final entriesJson = j['entries'] as List<dynamic>? ?? [];
    return WeeklyScheduleModel(
      id: j['id'] as int?,
      weekStart: ws,
      periodoRiferimento: (j['periodo_riferimento'] as String?) ?? '',
      updatedAt: j['updated_at'] != null
          ? DateTime.parse(j['updated_at'] as String)
          : null,
      entries: entriesJson
          .map((e) =>
              WeeklyScheduleEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => toJson();

  factory WeeklyScheduleModel.fromMap(Map<dynamic, dynamic> m) =>
      WeeklyScheduleModel.fromJson(Map<String, dynamic>.from(m));
}
