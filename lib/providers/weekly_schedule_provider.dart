import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/weekly_schedule_model.dart';

final weeklySchedulesProvider =
    StateNotifierProvider<WeeklySchedulesNotifier, List<WeeklyScheduleModel>>(
        (ref) => WeeklySchedulesNotifier());

class WeeklySchedulesNotifier
    extends StateNotifier<List<WeeklyScheduleModel>> {
  WeeklySchedulesNotifier() : super([]) {
    _load();
  }

  void _load() {
    final box = Hive.box('weekly_schedules');
    final list = <WeeklyScheduleModel>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        try {
          list.add(WeeklyScheduleModel.fromMap(data as Map));
        } catch (_) {}
      }
    }
    list.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    state = list;
  }

  Future<void> save(WeeklyScheduleModel schedule) async {
    final box = Hive.box('weekly_schedules');
    final key = schedule.weekStart.toIso8601String().substring(0, 10);
    await box.put(key, schedule.toMap());
    _load();
  }

  Future<void> delete(DateTime weekStart) async {
    final box = Hive.box('weekly_schedules');
    final key = weekStart.toIso8601String().substring(0, 10);
    await box.delete(key);
    _load();
  }

  WeeklyScheduleModel? getByWeekStart(DateTime weekStart) {
    final key =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    try {
      return state.firstWhere(
        (s) =>
            '${s.weekStart.year}-${s.weekStart.month.toString().padLeft(2, '0')}-${s.weekStart.day.toString().padLeft(2, '0')}' ==
            key,
      );
    } catch (_) {
      return null;
    }
  }
}
