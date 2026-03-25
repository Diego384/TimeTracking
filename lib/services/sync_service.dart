import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/operator_model.dart';
import '../models/day_entry_model.dart';
import '../models/comune_services_model.dart';
import '../models/ore_contrattuali_model.dart';

class SyncService {
  static Future<String> syncMonth({
    required OperatorModel operator,
    required int year,
    required int month,
    required Map<String, DayEntryModel> allEntries,
    required Map<String, ComuneServicesModel> allComuneServices,
  }) async {
    final baseUrl = operator.serverUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    if (baseUrl.isEmpty) throw Exception('URL server non configurato');
    if (operator.apiKey.isEmpty) throw Exception('API Key non configurata');

    // Filtra solo il mese richiesto
    final monthEntries = allEntries.values
        .where((e) => e.date.year == year && e.date.month == month)
        .map((e) => {
              'date': e.key,
              'ore_memofast': e.oreServiziMemofast,
              'ore_pulmino': e.orePrivatiPulmino,
              'ore_sostituzioni': e.oreSostituzioni,
              'ore_ferie': e.oreFerie,
              'ore_malattia': e.oreMalattia,
              'ore_legge104': e.oreLegge104,
              'nota': e.nota,
            })
        .toList();

    final monthComuni = allComuneServices.values
        .where((c) => c.year == year && c.month == month)
        .map((c) => {
              'comune': c.comune,
              'adi': c.adi,
              'ada': c.ada,
              'adh': c.adh,
              'adm': c.adm,
              'asia': c.asia,
              'asia_istituti': c.asiaIstituti,
              'cpf': c.cpf,
            })
        .toList();

    final body = jsonEncode({
      'operator': {
        'name': operator.name,
        'surname': operator.surname,
        'cooperative': operator.cooperative,
        'email': operator.email,
      },
      'year': year,
      'month': month,
      'day_entries': monthEntries,
      'comune_services': monthComuni,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/sync'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': operator.apiKey,
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final synced = data['synced_entries'] ?? 0;
      final comuni = data['synced_comuni'] ?? 0;
      return 'Sincronizzati $synced giorni e $comuni comuni';
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Errore ${response.statusCode}');
    }
  }

  static Future<OreContrattualiModel> fetchOreContrattuali({
    required OperatorModel operator,
  }) async {
    final baseUrl = operator.serverUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    if (baseUrl.isEmpty) throw Exception('URL server non configurato');
    if (operator.apiKey.isEmpty) throw Exception('API Key non configurata');

    final response = await http.get(
      Uri.parse('$baseUrl/api/contract-hours'),
      headers: {'X-API-Key': operator.apiKey},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return OreContrattualiModel.fromJson(data);
    } else {
      String detail;
      try {
        final data = jsonDecode(response.body);
        detail = data['detail'] ?? 'Errore HTTP ${response.statusCode}';
      } catch (_) {
        detail = 'Errore HTTP ${response.statusCode}';
      }
      throw Exception(detail);
    }
  }
}
