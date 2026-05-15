import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weekly_schedule_model.dart';
import '../models/operator_model.dart';
import '../providers/weekly_schedule_provider.dart';
import '../providers/operator_provider.dart';
import '../services/sync_service.dart';

const _kBlue = Color(0xFF1565C0);

DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

String _formatOre(double ore) {
  if (ore <= 0) return '0 h';
  final h = ore.floor();
  final m = ((ore - h) * 60).round();
  if (m == 0) return '$h h';
  return '$h h ${m}min';
}

String _formatOreShort(double ore) {
  if (ore <= 0) return '0';
  final s = ore.toStringAsFixed(2);
  // remove trailing zeros after decimal
  if (ore % 1 == 0) return ore.toInt().toString();
  // Italian comma style
  final parts = s.split('.');
  final dec = parts[1].replaceAll(RegExp(r'0+$'), '');
  return '${parts[0]},${dec.isEmpty ? '0' : dec}';
}

const List<String> _dayNames = [
  '', // index 0 unused
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
];

class WeeklyScheduleScreen extends ConsumerStatefulWidget {
  final DateTime? initialWeekStart;

  const WeeklyScheduleScreen({super.key, this.initialWeekStart});

  @override
  ConsumerState<WeeklyScheduleScreen> createState() =>
      _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends ConsumerState<WeeklyScheduleScreen> {
  late DateTime _weekStart;
  late List<WeeklyScheduleEntry> _entries;
  late TextEditingController _periodoCtrl;
  bool _isSaving = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(widget.initialWeekStart ?? DateTime.now());
    _periodoCtrl = TextEditingController();
    _entries = [];
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeek());
  }

  @override
  void dispose() {
    _periodoCtrl.dispose();
    super.dispose();
  }

  void _loadWeek() {
    final notifier = ref.read(weeklySchedulesProvider.notifier);
    final saved = notifier.getByWeekStart(_weekStart);
    if (saved != null) {
      setState(() {
        _entries = List.from(saved.entries);
        _periodoCtrl.text = saved.periodoRiferimento;
      });
    } else {
      setState(() {
        _entries = [];
        _periodoCtrl.text = '';
      });
      // Try fetching from server
      final operator = ref.read(operatorProvider);
      if (operator != null &&
          operator.serverUrl.isNotEmpty &&
          operator.apiKey.isNotEmpty) {
        _fetchFromServer(operator);
      }
    }
  }

  Future<void> _fetchFromServer(OperatorModel operator) async {
    try {
      final remote = await SyncService.fetchWeeklySchedule(
          operator: operator, weekStart: _weekStart);
      if (mounted) {
        setState(() {
          _entries = List.from(remote.entries);
          _periodoCtrl.text = remote.periodoRiferimento;
        });
      }
    } catch (_) {
      // silently ignore - no server data
    }
  }

  Future<void> _saveLocal() async {
    setState(() => _isSaving = true);
    try {
      final schedule = WeeklyScheduleModel(
        weekStart: _weekStart,
        periodoRiferimento: _periodoCtrl.text.trim(),
        entries: List.from(_entries),
      );
      await ref.read(weeklySchedulesProvider.notifier).save(schedule);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Griglia salvata localmente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore salvataggio: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncToServer() async {
    final operator = ref.read(operatorProvider);
    if (operator == null) return;

    if (operator.serverUrl.isEmpty || operator.apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Configura URL server e API Key nel profilo'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // Save locally first
    await _saveLocal();

    setState(() => _isSyncing = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Sincronizzazione in corso…'),
        ]),
        duration: Duration(seconds: 30),
      ));
    }

    try {
      final schedule = WeeklyScheduleModel(
        weekStart: _weekStart,
        periodoRiferimento: _periodoCtrl.text.trim(),
        entries: List.from(_entries),
      );
      await SyncService.syncWeeklySchedule(
          operator: operator, schedule: schedule);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Griglia sincronizzata con il server'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore sync: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeek());
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeek());
  }

  void _addRow(int dayOfWeek) {
    final existing = _entries.where((e) => e.dayOfWeek == dayOfWeek).toList();
    final nextIndex = existing.isEmpty
        ? 0
        : existing.map((e) => e.rowIndex).reduce((a, b) => a > b ? a : b) + 1;
    _showRowEditor(
      WeeklyScheduleEntry(dayOfWeek: dayOfWeek, rowIndex: nextIndex),
      isNew: true,
    );
  }

  void _editRow(WeeklyScheduleEntry entry) {
    _showRowEditor(entry, isNew: false);
  }

  void _deleteRow(WeeklyScheduleEntry entry) {
    setState(() {
      _entries.removeWhere((e) =>
          e.dayOfWeek == entry.dayOfWeek && e.rowIndex == entry.rowIndex);
      // Re-index remaining rows for that day
      final dayEntries = _entries
          .where((e) => e.dayOfWeek == entry.dayOfWeek)
          .toList()
        ..sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
      for (var i = 0; i < dayEntries.length; i++) {
        dayEntries[i].rowIndex = i;
      }
    });
  }

  Future<void> _showRowEditor(WeeklyScheduleEntry entry,
      {required bool isNew}) async {
    String oraInizio = entry.oraInizio;
    String oraFine = entry.oraFine;
    double ore = entry.ore;
    final utenteCtrl = TextEditingController(text: entry.utenteAssistito);
    final servizioCtrl = TextEditingController(text: entry.servizio);
    final comuneCtrl = TextEditingController(text: entry.comune);

    String calcOre(String inizio, String fine) {
      try {
        if (inizio.isEmpty || fine.isEmpty) return '0';
        final pi = inizio.split(':');
        final pf = fine.split(':');
        final i =
            Duration(hours: int.parse(pi[0]), minutes: int.parse(pi[1]));
        final f =
            Duration(hours: int.parse(pf[0]), minutes: int.parse(pf[1]));
        final diff = f - i;
        final v = diff.inMinutes / 60.0;
        return v <= 0 ? '0' : _formatOreShort(v);
      } catch (_) {
        return '0';
      }
    }

    Future<String?> pickTime(
        BuildContext ctx, String current, String label) async {
      TimeOfDay? initial;
      if (current.isNotEmpty) {
        final parts = current.split(':');
        initial = TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      final picked = await showTimePicker(
        context: ctx,
        initialTime: initial ?? TimeOfDay.now(),
        helpText: label,
        builder: (ctx2, child) {
          return MediaQuery(
            data: MediaQuery.of(ctx2)
                .copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );
      if (picked == null) return null;
      return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: _kBlue),
                      const SizedBox(width: 8),
                      Text(
                        '${isNew ? 'Nuova riga' : 'Modifica riga'} — ${_dayNames[entry.dayOfWeek]}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _kBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Time row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await pickTime(
                                ctx, oraInizio, 'Ora Inizio');
                            if (t != null) {
                              setBS(() {
                                oraInizio = t;
                                ore = double.tryParse(calcOre(
                                        oraInizio, oraFine)
                                    .replaceAll(',', '.')) ??
                                    0;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Ora Inizio',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.access_time,
                                  color: _kBlue, size: 18),
                            ),
                            child: Text(
                              oraInizio.isEmpty ? '--:--' : oraInizio,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: oraInizio.isEmpty
                                      ? Colors.grey
                                      : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await pickTime(
                                ctx, oraFine, 'Ora Fine');
                            if (t != null) {
                              setBS(() {
                                oraFine = t;
                                ore = double.tryParse(calcOre(
                                        oraInizio, oraFine)
                                    .replaceAll(',', '.')) ??
                                    0;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Ora Fine',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.access_time_filled,
                                  color: _kBlue, size: 18),
                            ),
                            child: Text(
                              oraFine.isEmpty ? '--:--' : oraFine,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: oraFine.isEmpty
                                      ? Colors.grey
                                      : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          border: Border.all(color: Colors.amber.shade700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${calcOre(oraInizio, oraFine)} h',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800,
                                  fontSize: 14),
                            ),
                            Text('ORE',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.amber.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: utenteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Utente / Assistito',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.person_outline,
                          color: _kBlue, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: servizioCtrl,
                    decoration: InputDecoration(
                      labelText: 'Servizio',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.work_outline,
                          color: _kBlue, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comuneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Comune',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.location_city_outlined,
                          color: _kBlue, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annulla'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Salva riga'),
                        style: FilledButton.styleFrom(
                            backgroundColor: _kBlue),
                        onPressed: () {
                          final updated = entry.copyWith(
                            oraInizio: oraInizio,
                            oraFine: oraFine,
                            ore: ore,
                            utenteAssistito: utenteCtrl.text.trim(),
                            servizio: servizioCtrl.text.trim(),
                            comune: comuneCtrl.text.trim(),
                          );
                          updated.calcolaOre();
                          setState(() {
                            if (isNew) {
                              _entries.add(updated);
                            } else {
                              final idx = _entries.indexWhere((e) =>
                                  e.dayOfWeek == entry.dayOfWeek &&
                                  e.rowIndex == entry.rowIndex);
                              if (idx >= 0) {
                                _entries[idx] = updated;
                              }
                            }
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _weekLabel() {
    final end = _weekStart.add(const Duration(days: 5)); // Sat
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return 'Settimana dal ${fmt(_weekStart)} al ${fmt(end)} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final operator = ref.watch(operatorProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Griglia Oraria',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (operator != null)
              Text(operator.fullName,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Salva',
              onPressed: _isSaving ? null : _saveLocal,
            ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Salva e sincronizza',
            onPressed: _isSyncing ? null : _syncToServer,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekNavBar(),
          _buildPeriodoField(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  for (int day = 1; day <= 6; day++) _buildDaySection(day),
                  _buildTotaleSettimana(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavBar() {
    return Container(
      color: _kBlue.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: _kBlue),
            onPressed: _prevWeek,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Text(
            _weekLabel(),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _kBlue),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: _kBlue),
            onPressed: _nextWeek,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodoField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _periodoCtrl,
        decoration: InputDecoration(
          labelText: 'Periodo di riferimento',
          hintText: 'es. Marzo 2026',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon:
              const Icon(Icons.calendar_today_outlined, color: _kBlue, size: 18),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildDaySection(int dayOfWeek) {
    final dayEntries = _entries
        .where((e) => e.dayOfWeek == dayOfWeek)
        .toList()
      ..sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
    final totaleGiorno = dayEntries.fold<double>(0, (s, e) => s + e.ore);
    final dayDate = _weekStart.add(Duration(days: dayOfWeek - 1));

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _kBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_dayNames[dayOfWeek]}  ${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: totaleGiorno > 0
                        ? Colors.amber.shade700
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatOre(totaleGiorno),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Column headers
          if (dayEntries.isNotEmpty)
            Container(
              color: _kBlue.withValues(alpha: 0.06),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: const Row(
                children: [
                  _ColHeader('INIZIO', flex: 2),
                  _ColHeader('FINE', flex: 2),
                  _ColHeader('ORE', flex: 2),
                  _ColHeader('UTENTE/ASSISTITO', flex: 4),
                  _ColHeader('SERVIZIO', flex: 3),
                  _ColHeader('COMUNE', flex: 3),
                  SizedBox(width: 32),
                ],
              ),
            ),
          // Rows
          ...dayEntries.asMap().entries.map((kv) {
            final e = kv.value;
            return _buildEntryRow(e, kv.key.isEven);
          }),
          // Add button
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: TextButton.icon(
              onPressed: () => _addRow(dayOfWeek),
              icon: const Icon(Icons.add, size: 18, color: _kBlue),
              label: const Text('Aggiungi riga',
                  style: TextStyle(color: _kBlue, fontSize: 12)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(WeeklyScheduleEntry entry, bool isEven) {
    return Dismissible(
      key: ValueKey('${entry.dayOfWeek}-${entry.rowIndex}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _deleteRow(entry),
      child: InkWell(
        onTap: () => _editRow(entry),
        child: Container(
          color: isEven ? Colors.white : Colors.grey.shade50,
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _RowCell(entry.oraInizio.isEmpty ? '—' : entry.oraInizio,
                  flex: 2),
              _RowCell(entry.oraFine.isEmpty ? '—' : entry.oraFine,
                  flex: 2),
              _RowCell(
                  entry.ore > 0
                      ? '${_formatOreShort(entry.ore)} h'
                      : '—',
                  flex: 2,
                  bold: true,
                  color: Colors.amber.shade800),
              _RowCell(entry.utenteAssistito.isEmpty
                  ? '—'
                  : entry.utenteAssistito, flex: 4),
              _RowCell(
                  entry.servizio.isEmpty ? '—' : entry.servizio,
                  flex: 3),
              _RowCell(entry.comune.isEmpty ? '—' : entry.comune,
                  flex: 3),
              SizedBox(
                width: 32,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  onPressed: () => _deleteRow(entry),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotaleSettimana() {
    final tot = _entries.fold<double>(0, (s, e) => s + e.ore);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('TOTALE SETTIMANA',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatOre(tot),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String label;
  final int flex;

  const _ColHeader(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0)),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _RowCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final Color? color;

  const _RowCell(this.text,
      {required this.flex, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
