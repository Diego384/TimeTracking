import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/operator_model.dart';

final operatorProvider =
    StateNotifierProvider<OperatorNotifier, OperatorModel?>((ref) {
  return OperatorNotifier();
});

class OperatorNotifier extends StateNotifier<OperatorModel?> {
  OperatorNotifier() : super(null) {
    _load();
  }

  void _load() {
    final box = Hive.box('operator');
    final name = box.get('name') as String?;
    if (name != null) {
      state = OperatorModel(
        name: name,
        surname: box.get('surname') as String? ?? '',
        cooperative: box.get('cooperative') as String? ?? '',
        email: box.get('email') as String? ?? '',
        serverUrl: box.get('serverUrl') as String? ?? '',
        apiKey: box.get('apiKey') as String? ?? '',
      );
    }
  }

  Future<void> save(OperatorModel operator) async {
    final box = Hive.box('operator');
    await box.put('name', operator.name);
    await box.put('surname', operator.surname);
    await box.put('cooperative', operator.cooperative);
    await box.put('email', operator.email);
    await box.put('serverUrl', operator.serverUrl);
    await box.put('apiKey', operator.apiKey);
    state = operator;
  }
}
