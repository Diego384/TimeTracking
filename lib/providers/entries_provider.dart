import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/day_entry_model.dart';

final entriesProvider =
    StateNotifierProvider<EntriesNotifier, Map<String, DayEntryModel>>((ref) {
  return EntriesNotifier();
});

class EntriesNotifier extends StateNotifier<Map<String, DayEntryModel>> {
  EntriesNotifier() : super({}) {
    _loadAll();
  }

  void _loadAll() {
    final box = Hive.box('entries');
    final Map<String, DayEntryModel> entries = {};
    for (final key in box.keys) {
      final mapData = box.get(key);
      if (mapData != null) {
        final parts = (key as String).split('-');
        if (parts.length == 3) {
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          entries[key] =
              DayEntryModel.fromMap(mapData as Map<dynamic, dynamic>, date);
        }
      }
    }
    state = entries;
  }

  Future<void> saveEntry(DayEntryModel entry) async {
    final box = Hive.box('entries');
    await box.put(entry.key, entry.toMap());
    state = {...state, entry.key: entry};
  }

  DayEntryModel? getEntry(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return state[key];
  }

  Map<String, DayEntryModel> getMonthEntries(int year, int month) {
    return Map.fromEntries(
      state.entries.where(
          (e) => e.value.date.year == year && e.value.date.month == month),
    );
  }
}
