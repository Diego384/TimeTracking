import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/setup_screen.dart';
import 'screens/calendar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT', null);
  await Hive.initFlutter();
  await Hive.openBox('operator');
  await Hive.openBox('entries');
  await Hive.openBox('comune_services');
  runApp(const ProviderScope(child: TimeTrackingApp()));
}

class TimeTrackingApp extends StatelessWidget {
  const TimeTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Registro Ore – Oltre i Sogni',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const _HomeRouter(),
    );
  }
}

class _HomeRouter extends ConsumerWidget {
  const _HomeRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final box = Hive.box('operator');
    final hasOperator =
        box.get('name') != null && (box.get('name') as String).isNotEmpty;
    return hasOperator ? const CalendarScreen() : const SetupScreen();
  }
}
