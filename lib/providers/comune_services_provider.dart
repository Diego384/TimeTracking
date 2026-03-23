import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/comune_services_model.dart';

final comuneServicesProvider = StateNotifierProvider<
    ComuneServicesNotifier, Map<String, ComuneServicesModel>>(
  (ref) => ComuneServicesNotifier(),
);

class ComuneServicesNotifier
    extends StateNotifier<Map<String, ComuneServicesModel>> {
  ComuneServicesNotifier() : super({}) {
    _loadAll();
  }

  void _loadAll() {
    final box = Hive.box('comune_services');
    final map = <String, ComuneServicesModel>{};
    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw != null) {
          final m = ComuneServicesModel.fromMap(
              Map<dynamic, dynamic>.from(raw as Map));
          map[m.key] = m;
        }
      } catch (_) {}
    }
    state = map;
  }

  Future<void> saveEntry(ComuneServicesModel model) async {
    final box = Hive.box('comune_services');
    await box.put(model.key, model.toMap());
    state = {...state, model.key: model};
  }

  ComuneServicesModel getOrCreate(int year, int month, String comune) {
    final key =
        '$year-${month.toString().padLeft(2, '0')}-$comune';
    return state[key] ??
        ComuneServicesModel(year: year, month: month, comune: comune);
  }

  Map<String, ComuneServicesModel> getMonthEntries(int year, int month) {
    return Map.fromEntries(state.entries
        .where((e) => e.value.year == year && e.value.month == month));
  }
}
