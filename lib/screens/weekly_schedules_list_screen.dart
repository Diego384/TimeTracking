import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weekly_schedule_model.dart';
import '../providers/weekly_schedule_provider.dart';
import 'weekly_schedule_screen.dart';

const _kBlue = Color(0xFF1565C0);

DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

String _formatOre(double ore) {
  if (ore <= 0) return '0 h';
  final h = ore.floor();
  final m = ((ore - h) * 60).round();
  if (m == 0) return '$h h';
  return '$h h ${m}min';
}

class WeeklySchedulesListScreen extends ConsumerWidget {
  const WeeklySchedulesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(weeklySchedulesProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'Griglie Orarie',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuova griglia'),
        onPressed: () => _createNew(context),
      ),
      body: schedules.isEmpty
          ? _buildEmpty(context)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: schedules.length,
              itemBuilder: (ctx, i) =>
                  _ScheduleCard(schedule: schedules[i]),
            ),
    );
  }

  void _createNew(BuildContext context) async {
    final monday = _mondayOf(DateTime.now());

    // Let user pick a Monday via date picker
    final picked = await showDatePicker(
      context: context,
      initialDate: monday,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Seleziona un giorno della settimana',
    );

    if (picked == null) return;
    final pickedMonday = _mondayOf(picked);

    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WeeklyScheduleScreen(initialWeekStart: pickedMonday),
    ));
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_on, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Nessuna griglia oraria',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text(
            'Premi il pulsante + per creare\nla prima griglia settimanale',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Crea griglia'),
            style: FilledButton.styleFrom(backgroundColor: _kBlue),
            onPressed: () => _createNew(context),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends ConsumerWidget {
  final WeeklyScheduleModel schedule;

  const _ScheduleCard({required this.schedule});

  String _weekLabel() {
    final start = schedule.weekStart;
    final end = start.add(const Duration(days: 5)); // Sat
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '${fmt(start)} – ${fmt(end)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tot = schedule.totaleSettimana;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              WeeklyScheduleScreen(initialWeekStart: schedule.weekStart),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.grid_on, color: _kBlue, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekLabel(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87),
                    ),
                    if (schedule.periodoRiferimento.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        schedule.periodoRiferimento,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${schedule.entries.length} voci  •  ${_formatOre(tot)}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tot > 0
                          ? Colors.amber.shade700
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatOre(tot),
                      style: TextStyle(
                          color:
                              tot > 0 ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: () =>
                        _confirmDelete(context, ref),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina griglia'),
        content: Text('Eliminare la griglia della settimana ${_weekLabel()}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(weeklySchedulesProvider.notifier)
                  .delete(schedule.weekStart);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}
