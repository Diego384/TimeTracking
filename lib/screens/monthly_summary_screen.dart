import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/day_entry_model.dart';
import '../providers/entries_provider.dart';
import '../providers/operator_provider.dart';

class MonthlySummaryScreen extends ConsumerWidget {
  final int year;
  final int month;

  const MonthlySummaryScreen(
      {super.key, required this.year, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider);
    final operator = ref.watch(operatorProvider);

    // Genera tutti i giorni del mese
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final allDays = List.generate(
        daysInMonth, (i) => DateTime(year, month, i + 1));

    // Mappa per lookup veloce
    final entryMap = <String, DayEntryModel>{};
    for (final e in entries.values) {
      if (e.date.year == year && e.date.month == month) {
        entryMap[
            '${e.date.year}-${e.date.month.toString().padLeft(2,'0')}-${e.date.day.toString().padLeft(2,'0')}'] = e;
      }
    }

    final monthEntries = entries.values
        .where((e) => e.date.year == year && e.date.month == month)
        .toList();

    final totalMemofast =
        monthEntries.fold<double>(0, (s, e) => s + e.oreServiziMemofast);
    final totalPulmino =
        monthEntries.fold<double>(0, (s, e) => s + e.orePrivatiPulmino);
    final totalSost =
        monthEntries.fold<double>(0, (s, e) => s + e.oreSostituzioni);
    final totalOre = totalMemofast + totalPulmino + totalSost;

    final totalFerieGiorni =
        monthEntries.where((e) => e.oreFerie == -1.0).length.toDouble();
    final totalFerieOre =
        monthEntries.fold<double>(0, (s, e) => e.oreFerie > 0 ? s + e.oreFerie : s);
    final totalMalattia =
        monthEntries.fold<double>(0, (s, e) => s + e.oreMalattia);
    final totalLeg104 =
        monthEntries.fold<double>(0, (s, e) => s + e.oreLegge104);

    final monthName =
        DateFormat('MMMM yyyy', 'it_IT').format(DateTime(year, month));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riepilogo ${monthName.toUpperCase()}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            if (operator != null)
              Text(operator.fullName,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: monthEntries.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nessun dato registrato per questo mese',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : Column(
              children: [
                // Card riepilogo totali
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Totale ore lavorative: ${_fmt(totalOre)} h',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _oreChip('Memofast', totalMemofast,
                              Colors.lightBlue.shade200),
                          _oreChip('Privati', totalPulmino,
                              Colors.cyan.shade200),
                          _oreChip(
                              'Sost.', totalSost, Colors.indigo.shade200),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(
                          color: Colors.white24, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ferieChip(totalFerieGiorni, totalFerieOre,
                              Colors.orange.shade300),
                          _absChip('Malattia', totalMalattia,
                              Colors.red.shade300, isGiorni: true),
                          _absChip('L.104', totalLeg104,
                              Colors.purple.shade300),
                        ],
                      ),
                    ],
                  ),
                ),
                // Intestazione lista
                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text('GIORNO',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey))),
                      Expanded(
                          child: Text('MEMO',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('PRIV.',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('SOST.',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('ASS.',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: allDays.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, i) {
                      final day = allDays[i];
                      final key =
                          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                      return _DayRow(
                          date: day, entry: entryMap[key]);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _oreChip(String label, double value, Color color) {
    return Column(
      children: [
        Text('${_fmt(value)} h',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _ferieChip(double giorni, double ore, Color color) {
    String text;
    if (giorni > 0 && ore > 0) {
      text = '${giorni.toInt()}g + ${_fmt(ore)}h  Ferie';
    } else if (giorni > 0) {
      text = '${giorni.toInt()} g  Ferie';
    } else {
      text = '${_fmt(ore)} h  Ferie';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _absChip(String label, double ore, Color color,
      {bool isGiorni = false}) {
    final value = isGiorni ? ore.toInt().toString() : _fmt(ore);
    final suffix = isGiorni ? 'g' : 'h';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$value $suffix  $label',
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DateTime date;
  final DayEntryModel? entry;
  const _DayRow({required this.date, required this.entry});

  String _fmtOre(double v) =>
      v == 0 ? '-' : (v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1));

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEE d', 'it_IT').format(date);
    final isWeekend = date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday;

    // Costruisce etichetta assenze
    final parts = <String>[];
    if (entry?.oreFerie == -1.0) { parts.add('F:G'); }
    else if ((entry?.oreFerie ?? 0) > 0) { parts.add('F:${_fmtOre(entry!.oreFerie)}h'); }
    if ((entry?.oreMalattia ?? 0) > 0) { parts.add('M:G'); }
    if ((entry?.oreLegge104 ?? 0) > 0) { parts.add('104:${_fmtOre(entry!.oreLegge104)}h'); }
    final absLabel = parts.join(' ');

    Color absColor = Colors.grey;
    if ((entry?.oreFerie    ?? 0) > 0) absColor = Colors.orange;
    if ((entry?.oreMalattia ?? 0) > 0) absColor = Colors.red;
    if ((entry?.oreLegge104 ?? 0) > 0) absColor = Colors.purple;
    if (parts.length > 1)              absColor = Colors.orange.shade700;

    final nota = entry?.nota ?? '';
    return Container(
      color: isWeekend ? Colors.grey.shade50 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    dayLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isWeekend
                          ? Colors.red.shade400
                          : Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(_fmtOre(entry?.oreServiziMemofast ?? 0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.blue)),
                ),
                Expanded(
                  child: Text(_fmtOre(entry?.orePrivatiPulmino ?? 0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.teal)),
                ),
                Expanded(
                  child: Text(_fmtOre(entry?.oreSostituzioni ?? 0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.indigo)),
                ),
                Expanded(
                  child: Text(
                    absLabel.isEmpty ? '-' : absLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color:
                            absLabel.isEmpty ? Colors.grey : absColor),
                  ),
                ),
                if (nota.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.notes,
                        size: 16, color: Color(0xFF1565C0)),
                  ),
              ],
            ),
          ),
          if (nota.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                nota,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}
