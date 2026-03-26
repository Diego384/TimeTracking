import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/ore_contrattuali_model.dart';
import '../providers/ore_contrattuali_provider.dart';
import '../providers/operator_provider.dart';
import '../services/sync_service.dart';

// ── Festività nazionali italiane ─────────────────────────────────────────────

/// Calcola la data di Pasqua (algoritmo anonimo gregoriano).
DateTime _calcolaPasqua(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

/// Restituisce le festività italiane per l'anno dato.
/// Chiave: "YYYY-MM-DD", valore: nome della festività.
Map<String, String> festivitaItaliane(int year) {
  final pasqua = _calcolaPasqua(year);
  final pasquetta = pasqua.add(const Duration(days: 1));

  String k(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  return {
    '$year-01-01': 'Capodanno',
    '$year-01-06': 'Epifania',
    k(pasqua):     'Pasqua',
    k(pasquetta):  'Pasquetta',
    '$year-04-25': 'Liberazione',
    '$year-05-01': 'Festa del Lavoro',
    '$year-06-02': 'Rep. Italiana',
    '$year-08-15': 'Ferragosto',
    '$year-11-01': 'Ognissanti',
    '$year-12-08': 'Immacolata',
    '$year-12-25': 'Natale',
    '$year-12-26': 'S. Stefano',
  };
}

// ── Screen ───────────────────────────────────────────────────────────────────

class OreContrattualiScreen extends ConsumerStatefulWidget {
  final int initialYear;
  final int initialMonth;

  const OreContrattualiScreen({
    super.key,
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  ConsumerState<OreContrattualiScreen> createState() =>
      _OreContrattualiScreenState();
}

class _OreContrattualiScreenState extends ConsumerState<OreContrattualiScreen> {
  late int _year;
  late int _month;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  void _prevMonth() => setState(() {
        if (_month == 1) { _month = 12; _year--; } else { _month--; }
      });

  void _nextMonth() => setState(() {
        if (_month == 12) { _month = 1; _year++; } else { _month++; }
      });

  Future<void> _sync() async {
    final operator = ref.read(operatorProvider);
    if (operator == null) return;
    if (operator.serverUrl.isEmpty || operator.apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Configura URL server e API Key nel profilo'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final model = await SyncService.fetchOreContrattuali(operator: operator);
      await ref.read(oreContrattualiProvider.notifier).save(model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Ore contrattuali aggiornate'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  double _totaleDelMese(OreContrattualiModel schedule) {
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    double tot = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      tot += schedule.orePerWeekday(DateTime(_year, _month, d).weekday);
    }
    return tot;
  }

  double _totaleFestivita(
      OreContrattualiModel schedule, Map<String, String> festivita) {
    double tot = 0;
    for (final entry in festivita.entries) {
      final parts = entry.key.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      if (d.year == _year && d.month == _month) {
        tot += schedule.orePerWeekday(d.weekday);
      }
    }
    return tot;
  }

  @override
  Widget build(BuildContext context) {
    final operator = ref.watch(operatorProvider);
    final schedule = ref.watch(oreContrattualiProvider);
    final monthName =
        DateFormat('MMMM yyyy', 'it_IT').format(DateTime(_year, _month));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ore Contrattuali',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (operator != null)
              Text(operator.fullName,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_download_outlined),
            tooltip: 'Scarica dal server',
            onPressed: _isSyncing ? null : _sync,
          ),
        ],
      ),
      body: schedule == null
          ? _buildEmpty()
          : _buildContent(schedule, monthName),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_download_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Nessun dato disponibile.\nPremere il pulsante in alto per sincronizzare.',
            style: TextStyle(color: Colors.grey, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Sincronizza ora'),
            onPressed: _isSyncing ? null : _sync,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(OreContrattualiModel schedule, String monthName) {
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final allDays =
        List.generate(daysInMonth, (i) => DateTime(_year, _month, i + 1));
    final totMese = _totaleDelMese(schedule);
    final festivita = festivitaItaliane(_year);
    final totFestivita = _totaleFestivita(schedule, festivita);

    return Column(
      children: [
        // ── Schema settimanale ────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Schema settimanale',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _dayChip('Lun', schedule.lunedi),
                  _dayChip('Mar', schedule.martedi),
                  _dayChip('Mer', schedule.mercoledi),
                  _dayChip('Gio', schedule.giovedi),
                  _dayChip('Ven', schedule.venerdi),
                  _dayChip('Sab', schedule.sabato),
                  _dayChip('Dom', schedule.domenica),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),
              Text(
                'Totale settimana: ${_fmt(schedule.totaleSettimana)} h',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              if (schedule.updatedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Aggiornato il ${DateFormat('dd/MM/yyyy HH:mm').format(schedule.updatedAt!.toLocal())}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ],
          ),
        ),

        // ── Navigazione mese ─────────────────────────────────────────
        Container(
          color: const Color(0xFF1565C0).withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Color(0xFF1565C0)),
                onPressed: _prevMonth,
              ),
              Column(
                children: [
                  Text(
                    monthName.toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1565C0)),
                  ),
                  Text(
                    'Totale: ${_fmt(totMese)} h',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF1565C0)),
                  ),
                  if (totFestivita > 0)
                    Text(
                      'di cui festività: ${_fmt(totFestivita)} h',
                      style: TextStyle(
                          fontSize: 11, color: Colors.amber.shade700),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Color(0xFF1565C0)),
                onPressed: _nextMonth,
              ),
            ],
          ),
        ),

        // ── Intestazione colonne ──────────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('GIORNO',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text('FESTIVITÀ',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey),
                    textAlign: TextAlign.center),
              ),
              Expanded(
                child: Text('ORE',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0)),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Lista giorni del mese ─────────────────────────────────────
        Expanded(
          child: ListView.separated(
            itemCount: allDays.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, i) {
              final day = allDays[i];
              final key =
                  '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final ore = schedule.orePerWeekday(day.weekday);
              final nomeFesta = festivita[key];
              return _DayRow(date: day, ore: ore, nomeFesta: nomeFesta);
            },
          ),
        ),
      ],
    );
  }

  Widget _dayChip(String label, double ore) {
    final hasOre = ore > 0;
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          hasOre ? '${_fmt(ore)}h' : '-',
          style: TextStyle(
              color: hasOre ? Colors.lightBlue.shade200 : Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
      ],
    );
  }
}

// ── Row singolo giorno ────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final DateTime date;
  final double ore;
  final String? nomeFesta;

  const _DayRow({required this.date, required this.ore, this.nomeFesta});

  String _fmtOre(double v) =>
      v == 0 ? '-' : (v % 1 == 0 ? '${v.toInt()} h' : '${v.toStringAsFixed(1)} h');

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEE d', 'it_IT').format(date);
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final isFesta = nomeFesta != null;

    Color bgColor = Colors.transparent;
    if (isFesta) {
      bgColor = Colors.amber.shade50;
    } else if (isWeekend) {
      bgColor = Colors.grey.shade50;
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Giorno
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (isFesta)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.star, size: 13, color: Colors.amber.shade700),
                  ),
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isFesta
                        ? Colors.amber.shade800
                        : isWeekend
                            ? Colors.red.shade400
                            : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Nome festività
          Expanded(
            flex: 2,
            child: Text(
              nomeFesta ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade700,
              ),
            ),
          ),
          // Ore contrattuali
          Expanded(
            child: Text(
              _fmtOre(ore),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: ore > 0 ? FontWeight.w600 : FontWeight.normal,
                color: isFesta && ore > 0
                    ? Colors.amber.shade800
                    : ore > 0
                        ? const Color(0xFF1565C0)
                        : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
