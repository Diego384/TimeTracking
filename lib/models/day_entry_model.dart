class DayEntryModel {
  final DateTime date;
  double oreServiziMemofast;
  double orePrivatiPulmino;
  double oreSostituzioni;
  double oreFerie;
  double oreMalattia;
  double oreLegge104;
  String nota;

  DayEntryModel({
    required this.date,
    this.oreServiziMemofast = 0,
    this.orePrivatiPulmino = 0,
    this.oreSostituzioni = 0,
    this.oreFerie = 0,
    this.oreMalattia = 0,
    this.oreLegge104 = 0,
    this.nota = '',
  });

  String get key =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  double get totalOre =>
      oreServiziMemofast + orePrivatiPulmino + oreSostituzioni;

  // -1.0 = giornata intera ferie; 1.0 = giornata malattia
  bool get hasAssenza =>
      oreFerie != 0 || oreMalattia > 0 || oreLegge104 > 0;

  bool get hasData => totalOre > 0 || hasAssenza || nota.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'date': key,
        'oreServiziMemofast': oreServiziMemofast,
        'orePrivatiPulmino': orePrivatiPulmino,
        'oreSostituzioni': oreSostituzioni,
        'oreFerie': oreFerie,
        'oreMalattia': oreMalattia,
        'oreLegge104': oreLegge104,
        'nota': nota,
      };

  factory DayEntryModel.fromMap(Map<dynamic, dynamic> map, DateTime date) =>
      DayEntryModel(
        date: date,
        oreServiziMemofast: (map['oreServiziMemofast'] as num).toDouble(),
        orePrivatiPulmino: (map['orePrivatiPulmino'] as num).toDouble(),
        oreSostituzioni: (map['oreSostituzioni'] as num).toDouble(),
        oreFerie: (map['oreFerie'] as num?)?.toDouble() ?? 0,
        oreMalattia: (map['oreMalattia'] as num?)?.toDouble() ?? 0,
        oreLegge104: (map['oreLegge104'] as num?)?.toDouble() ?? 0,
        nota: (map['nota'] as String?) ?? '',
      );

  DayEntryModel copyWith({
    double? oreServiziMemofast,
    double? orePrivatiPulmino,
    double? oreSostituzioni,
    double? oreFerie,
    double? oreMalattia,
    double? oreLegge104,
    String? nota,
  }) =>
      DayEntryModel(
        date: date,
        oreServiziMemofast: oreServiziMemofast ?? this.oreServiziMemofast,
        orePrivatiPulmino: orePrivatiPulmino ?? this.orePrivatiPulmino,
        oreSostituzioni: oreSostituzioni ?? this.oreSostituzioni,
        oreFerie: oreFerie ?? this.oreFerie,
        oreMalattia: oreMalattia ?? this.oreMalattia,
        oreLegge104: oreLegge104 ?? this.oreLegge104,
        nota: nota ?? this.nota,
      );
}
