const kComuni = [
  'Massa',
  'Sorrento',
  "Sant'Agnello",
  'Piano',
  'Meta',
  'Vico',
];

const kServizi = ['ADI', 'ADA', 'ADH', 'ADM', 'ASIA', 'ASIA Ist.', 'CPF'];

class ComuneServicesModel {
  final int year;
  final int month;
  final String comune;
  double adi;
  double ada;
  double adh;
  double adm;
  double asia;
  double asiaIstituti;
  double cpf;

  ComuneServicesModel({
    required this.year,
    required this.month,
    required this.comune,
    this.adi = 0,
    this.ada = 0,
    this.adh = 0,
    this.adm = 0,
    this.asia = 0,
    this.asiaIstituti = 0,
    this.cpf = 0,
  });

  String get key =>
      '$year-${month.toString().padLeft(2, '0')}-$comune';

  double get totaleComune =>
      adi + ada + adh + adm + asia + asiaIstituti + cpf;

  Map<String, dynamic> toMap() => {
        'year': year,
        'month': month,
        'comune': comune,
        'adi': adi,
        'ada': ada,
        'adh': adh,
        'adm': adm,
        'asia': asia,
        'asiaIstituti': asiaIstituti,
        'cpf': cpf,
      };

  factory ComuneServicesModel.fromMap(Map<dynamic, dynamic> map) =>
      ComuneServicesModel(
        year: map['year'] as int,
        month: map['month'] as int,
        comune: map['comune'] as String,
        adi: (map['adi'] as num?)?.toDouble() ?? 0,
        ada: (map['ada'] as num?)?.toDouble() ?? 0,
        adh: (map['adh'] as num?)?.toDouble() ?? 0,
        adm: (map['adm'] as num?)?.toDouble() ?? 0,
        asia: (map['asia'] as num?)?.toDouble() ?? 0,
        asiaIstituti: (map['asiaIstituti'] as num?)?.toDouble() ?? 0,
        cpf: (map['cpf'] as num?)?.toDouble() ?? 0,
      );

  ComuneServicesModel copyWith({
    double? adi,
    double? ada,
    double? adh,
    double? adm,
    double? asia,
    double? asiaIstituti,
    double? cpf,
  }) =>
      ComuneServicesModel(
        year: year,
        month: month,
        comune: comune,
        adi: adi ?? this.adi,
        ada: ada ?? this.ada,
        adh: adh ?? this.adh,
        adm: adm ?? this.adm,
        asia: asia ?? this.asia,
        asiaIstituti: asiaIstituti ?? this.asiaIstituti,
        cpf: cpf ?? this.cpf,
      );
}
