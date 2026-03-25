import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ore_contrattuali_model.dart';

final oreContrattualiProvider =
    StateNotifierProvider<OreContrattualiNotifier, OreContrattualiModel?>((ref) {
  return OreContrattualiNotifier();
});

class OreContrattualiNotifier extends StateNotifier<OreContrattualiModel?> {
  OreContrattualiNotifier() : super(null) {
    _load();
  }

  void _load() {
    final box = Hive.box('ore_contrattuali');
    final mapData = box.get('schedule');
    if (mapData != null) {
      state = OreContrattualiModel.fromMap(mapData as Map<dynamic, dynamic>);
    }
  }

  Future<void> save(OreContrattualiModel model) async {
    final box = Hive.box('ore_contrattuali');
    await box.put('schedule', model.toMap());
    state = model;
  }
}
