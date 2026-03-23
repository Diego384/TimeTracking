class OperatorModel {
  final String name;
  final String surname;
  final String cooperative;
  final String email;
  final String serverUrl;
  final String apiKey;

  OperatorModel({
    required this.name,
    required this.surname,
    required this.cooperative,
    this.email = '',
    this.serverUrl = '',
    this.apiKey = '',
  });

  String get fullName => '$name $surname';
}
