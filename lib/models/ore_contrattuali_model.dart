class OreContrattualiModel {
  final double lunedi;
  final double martedi;
  final double mercoledi;
  final double giovedi;
  final double venerdi;
  final double sabato;
  final double domenica;
  final DateTime? updatedAt;

  const OreContrattualiModel({
    this.lunedi = 0,
    this.martedi = 0,
    this.mercoledi = 0,
    this.giovedi = 0,
    this.venerdi = 0,
    this.sabato = 0,
    this.domenica = 0,
    this.updatedAt,
  });

  double get totaleSettimana =>
      lunedi + martedi + mercoledi + giovedi + venerdi + sabato + domenica;

  /// Restituisce le ore contratte per il giorno della settimana (1=lun … 7=dom)
  double orePerWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:    return lunedi;
      case DateTime.tuesday:   return martedi;
      case DateTime.wednesday: return mercoledi;
      case DateTime.thursday:  return giovedi;
      case DateTime.friday:    return venerdi;
      case DateTime.saturday:  return sabato;
      case DateTime.sunday:    return domenica;
      default:                 return 0;
    }
  }

  Map<String, dynamic> toMap() => {
        'lunedi':    lunedi,
        'martedi':   martedi,
        'mercoledi': mercoledi,
        'giovedi':   giovedi,
        'venerdi':   venerdi,
        'sabato':    sabato,
        'domenica':  domenica,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory OreContrattualiModel.fromMap(Map<dynamic, dynamic> map) =>
      OreContrattualiModel(
        lunedi:    (map['lunedi']    as num?)?.toDouble() ?? 0,
        martedi:   (map['martedi']   as num?)?.toDouble() ?? 0,
        mercoledi: (map['mercoledi'] as num?)?.toDouble() ?? 0,
        giovedi:   (map['giovedi']   as num?)?.toDouble() ?? 0,
        venerdi:   (map['venerdi']   as num?)?.toDouble() ?? 0,
        sabato:    (map['sabato']    as num?)?.toDouble() ?? 0,
        domenica:  (map['domenica']  as num?)?.toDouble() ?? 0,
        updatedAt: map['updatedAt'] != null
            ? DateTime.tryParse(map['updatedAt'] as String)
            : null,
      );

  factory OreContrattualiModel.fromJson(Map<String, dynamic> json) =>
      OreContrattualiModel(
        lunedi:    (json['lunedi']    as num?)?.toDouble() ?? 0,
        martedi:   (json['martedi']   as num?)?.toDouble() ?? 0,
        mercoledi: (json['mercoledi'] as num?)?.toDouble() ?? 0,
        giovedi:   (json['giovedi']   as num?)?.toDouble() ?? 0,
        venerdi:   (json['venerdi']   as num?)?.toDouble() ?? 0,
        sabato:    (json['sabato']    as num?)?.toDouble() ?? 0,
        domenica:  (json['domenica']  as num?)?.toDouble() ?? 0,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );
}
