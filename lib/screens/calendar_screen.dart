import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import '../providers/entries_provider.dart';
import '../providers/operator_provider.dart';
import '../models/day_entry_model.dart';
import '../services/excel_service.dart';
import 'day_entry_screen.dart';
import 'monthly_summary_screen.dart';
import 'setup_screen.dart';
import 'list_calendar_view.dart';
import 'comune_services_view.dart';
import '../providers/comune_services_provider.dart';
import '../services/sync_service.dart';
import 'ore_contrattuali_screen.dart';
import 'files_screen.dart';

enum CalendarViewMode {
  mensile,
  settimanale,
  listaMensile,
  listaSettimanale,
  serviziComuni,
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarViewMode _viewMode = CalendarViewMode.listaMensile;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  // ── Helpers ──────────────────────────────────────────────────────

  List<DateTime> get _monthDays {
    final days =
        DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    return List.generate(
        days, (i) => DateTime(_focusedDay.year, _focusedDay.month, i + 1));
  }

  List<DateTime> get _weekDays {
    final monday =
        _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  bool get _isMonthlyNav =>
      _viewMode == CalendarViewMode.listaMensile ||
      _viewMode == CalendarViewMode.serviziComuni;

  void _prevPeriod() {
    setState(() {
      if (_isMonthlyNav) {
        _focusedDay = DateTime(
            _focusedDay.month == 1
                ? _focusedDay.year - 1
                : _focusedDay.year,
            _focusedDay.month == 1 ? 12 : _focusedDay.month - 1,
            1);
      } else {
        _focusedDay = _focusedDay.subtract(const Duration(days: 7));
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      if (_isMonthlyNav) {
        _focusedDay = DateTime(
            _focusedDay.month == 12
                ? _focusedDay.year + 1
                : _focusedDay.year,
            _focusedDay.month == 12 ? 1 : _focusedDay.month + 1,
            1);
      } else {
        _focusedDay = _focusedDay.add(const Duration(days: 7));
      }
    });
  }

  String get _listNavLabel {
    if (_isMonthlyNav) {
      return DateFormat('MMMM yyyy', 'it_IT')
          .format(_focusedDay)
          .toUpperCase();
    }
    final days = _weekDays;
    final start = DateFormat('d MMM', 'it_IT').format(days.first);
    final end =
        DateFormat('d MMM yyyy', 'it_IT').format(days.last).toUpperCase();
    return '$start – $end'.toUpperCase();
  }

  // ── Day entry ─────────────────────────────────────────────────────

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DayEntryScreen(date: selectedDay)),
    );
  }

  // ── Report ────────────────────────────────────────────────────────

  Future<void> _sendReport({
    required int year,
    required int month,
    required String recipientEmail,
  }) async {
    final operator = ref.read(operatorProvider);
    final entries = ref.read(entriesProvider);
    final comuneServices = ref.read(comuneServicesProvider);
    if (operator == null) return;
    final monthName =
        DateFormat('MMMM yyyy', 'it_IT').format(DateTime(year, month));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Generazione report in corso…'),
      ]),
      duration: Duration(seconds: 10),
    ));
    try {
      final file = await ExcelService().generateReport(
          operator: operator, year: year, month: month,
          entries: entries, comuneServices: comuneServices);
      final email = Email(
        subject:
            'Report Ore – ${operator.fullName} – ${monthName.toUpperCase()}',
        body:
            'In allegato il report mensile ore di ${operator.fullName} per il mese di $monthName.\n\nCooperativa: ${operator.cooperative}',
        recipients: [recipientEmail],
        attachmentPaths: [file.path],
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Report inviato con successo!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Sync web ──────────────────────────────────────────────────────

  Future<void> _showSyncDialog() async {
    final operator = ref.read(operatorProvider);
    if (operator == null) return;

    if (operator.serverUrl.isEmpty || operator.apiKey.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.cloud_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Sync non configurato'),
          ]),
          content: const Text(
              'Configura URL server e API Key nel profilo per sincronizzare i dati.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetupScreen()));
              },
              child: const Text('Vai al profilo'),
            ),
          ],
        ),
      );
      return;
    }

    int selYear = _focusedDay.year;
    int selMonth = _focusedDay.month;
    final emailCtrl = TextEditingController(text: operator.email);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          final label = DateFormat('MMMM yyyy', 'it_IT')
              .format(DateTime(selYear, selMonth))
              .toUpperCase();
          return AlertDialog(
            title: const Row(children: [
              Icon(Icons.send, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Text('Sincronizza / Invia Report'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Mese di riferimento:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setDs(() {
                        if (selMonth == 1) { selMonth = 12; selYear--; }
                        else { selMonth--; }
                      }),
                    ),
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1565C0))),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setDs(() {
                        if (selMonth == 12) { selMonth = 1; selYear++; }
                        else { selMonth++; }
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Server: ${operator.serverUrl}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email destinatario report',
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: Color(0xFF1565C0)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla')),
              OutlinedButton.icon(
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Invia Report'),
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty) return;
                  Navigator.pop(ctx);
                  await _sendReport(
                      year: selYear, month: selMonth, recipientEmail: email);
                },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Sincronizza'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _doSync(year: selYear, month: selMonth);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _doSync({required int year, required int month}) async {
    final operator = ref.read(operatorProvider);
    final entries = ref.read(entriesProvider);
    final comuneServices = ref.read(comuneServicesProvider);
    if (operator == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Sincronizzazione in corso…'),
      ]),
      duration: Duration(seconds: 30),
    ));

    try {
      final msg = await SyncService.syncMonth(
        operator: operator,
        year: year,
        month: month,
        allEntries: entries,
        allComuneServices: comuneServices,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ $msg'),
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
    }
  }

  // ── Day color ─────────────────────────────────────────────────────

  Color _dayColor(DayEntryModel? entry) {
    if (entry == null || !entry.hasData) return Colors.transparent;
    if (entry.oreMalattia > 0) return Colors.red.shade300;
    if (entry.oreLegge104 > 0) return Colors.purple.shade300;
    if (entry.oreFerie > 0) return Colors.orange.shade300;
    return Colors.green.shade400;
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final operator = ref.watch(operatorProvider);
    final entries = ref.watch(entriesProvider);
    final isListMode = _viewMode == CalendarViewMode.listaMensile ||
        _viewMode == CalendarViewMode.listaSettimanale;
    final isServiziMode = _viewMode == CalendarViewMode.serviziComuni;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(operator?.fullName ?? 'Registro Ore',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            if (operator != null)
              Text(operator.cooperative,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            tooltip: 'Sincronizza / Invia report',
            onPressed: _showSyncDialog,
          ),
          IconButton(
            icon: const Icon(Icons.event_note_outlined),
            tooltip: 'Ore contrattuali',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => OreContrattualiScreen(
                  initialYear: _focusedDay.year, initialMonth: _focusedDay.month),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Riepilogo mensile',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MonthlySummaryScreen(
                  year: _focusedDay.year, month: _focusedDay.month),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Documenti',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FilesScreen())),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'profilo') {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetupScreen()));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'profilo',
                child: Row(children: [
                  Icon(Icons.person, color: Colors.black87),
                  SizedBox(width: 8),
                  Text('Modifica profilo'),
                ]),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: _buildModeToggle(),
        ),
      ),
      body: isServiziMode
          ? Column(children: [
              _buildListNavBar(),
              Expanded(
                child: ComuneServicesView(
                  key: ValueKey(
                      'servizi-${_focusedDay.year}-${_focusedDay.month}'),
                  year: _focusedDay.year,
                  month: _focusedDay.month,
                ),
              ),
            ])
          : isListMode
              ? Column(children: [
                  _buildListNavBar(),
                  _buildTotalsBar(entries),
                  Expanded(
                    child: ListCalendarView(
                      key: ValueKey(
                          '${_viewMode.name}-${_focusedDay.year}-${_focusedDay.month}-${_focusedDay.day}'),
                      days: _viewMode == CalendarViewMode.listaMensile
                          ? _monthDays
                          : _weekDays,
                      isWeekly:
                          _viewMode == CalendarViewMode.listaSettimanale,
                    ),
                  ),
                ])
              : _buildCalendarBody(entries),
    );
  }

  // ── Toggle 4 modalità ────────────────────────────────────────────

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                  child: _modeChip(
                CalendarViewMode.listaMensile,
                Icons.table_rows,
                'Griglia Mese',
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _modeChip(
                CalendarViewMode.listaSettimanale,
                Icons.view_list,
                'Griglia Sett.',
              )),
            ],
          ),
          const SizedBox(height: 6),
          _modeChip(
            CalendarViewMode.serviziComuni,
            Icons.location_city,
            'Servizi Comuni',
          ),
        ],
      ),
    );
  }

  Widget _modeChip(CalendarViewMode mode, IconData icon, String label) {
    final isActive = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = mode;
          if (mode == CalendarViewMode.mensile) {
            _calendarFormat = CalendarFormat.month;
          } else if (mode == CalendarViewMode.settimanale) {
            _calendarFormat = CalendarFormat.week;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14,
                color:
                    isActive ? const Color(0xFF1565C0) : Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF1565C0) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nav bar lista ─────────────────────────────────────────────────

  Widget _buildListNavBar() {
    return Container(
      color: const Color(0xFF1565C0).withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF1565C0)),
            onPressed: _prevPeriod,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Text(
            _listNavLabel,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1565C0)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF1565C0)),
            onPressed: _nextPeriod,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Barra totali griglia ──────────────────────────────────────────

  Widget _buildTotalsBar(Map<String, DayEntryModel> entries) {
    final days = _viewMode == CalendarViewMode.listaMensile
        ? _monthDays
        : _weekDays;

    double memo = 0, priv = 0, sost = 0;
    for (final day in days) {
      final k =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final e = entries[k];
      memo += e?.oreServiziMemofast ?? 0;
      priv += e?.orePrivatiPulmino  ?? 0;
      sost += e?.oreSostituzioni    ?? 0;
    }
    final tot = memo + priv + sost;

    String f(double v) =>
        v % 1 == 0 ? '${v.toInt()} h' : '${v.toStringAsFixed(1)} h';

    return Container(
      color: const Color(0xFF0D3C7A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _totChip('TOTALE', f(tot), Colors.white),
          _totChip('Memofast', f(memo), Colors.lightBlueAccent),
          _totChip('Privati', f(priv), Colors.cyanAccent),
          _totChip('Sost.', f(sost), const Color(0xFFADC6FF)),
        ],
      ),
    );
  }

  Widget _totChip(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  // ── Corpo calendario (mensile/settimanale) ─────────────────────────

  Widget _buildCalendarBody(Map<String, DayEntryModel> entries) {
    return SingleChildScrollView(
      child: Column(
      children: [
        TableCalendar(
          locale: 'it_IT',
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: _calendarFormat,
          startingDayOfWeek: StartingDayOfWeek.monday,
          onDaySelected: _onDaySelected,
          onFormatChanged: (f) => setState(() => _calendarFormat = f),
          onPageChanged: (d) => setState(() => _focusedDay = d),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, _) {
              final k =
                  '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final entry = entries[k];
              return _DayCell(
                  day: day, bgColor: _dayColor(entry), entry: entry);
            },
            todayBuilder: (context, day, _) {
              final k =
                  '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final entry = entries[k];
              return _DayCell(
                  day: day,
                  bgColor: _dayColor(entry),
                  entry: entry,
                  isToday: true);
            },
            selectedBuilder: (context, day, _) {
              final k =
                  '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
              final entry = entries[k];
              return _DayCell(
                  day: day,
                  bgColor: _dayColor(entry),
                  entry: entry,
                  isSelected: true);
            },
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextFormatter: (date, locale) =>
                DateFormat('MMMM yyyy', 'it_IT').format(date).toUpperCase(),
            titleTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1565C0)),
            leftChevronIcon:
                const Icon(Icons.chevron_left, color: Color(0xFF1565C0)),
            rightChevronIcon:
                const Icon(Icons.chevron_right, color: Color(0xFF1565C0)),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF1565C0)),
            weekendStyle:
                TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
          ),
          calendarStyle:
              const CalendarStyle(outsideDaysVisible: false),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legend(Colors.green.shade400, 'Ore lavorate'),
              _legend(Colors.orange.shade300, 'Ferie'),
              _legend(Colors.red.shade300, 'Malattia'),
              _legend(Colors.purple.shade300, 'L.104'),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _MonthStats(
            year: _focusedDay.year,
            month: _focusedDay.month,
            entries: entries,
          ),
        ),
      ],
    ));
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ── DayCell ───────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime day;
  final Color bgColor;
  final DayEntryModel? entry;
  final bool isToday;
  final bool isSelected;

  const _DayCell({
    required this.day,
    required this.bgColor,
    this.entry,
    this.isToday = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasOre = entry != null && entry!.totalOre > 0;
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF1565C0)
            : isToday
                ? const Color(0xFF1565C0).withValues(alpha: 0.15)
                : bgColor == Colors.transparent
                    ? Colors.transparent
                    : bgColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: isToday && !isSelected
            ? Border.all(color: const Color(0xFF1565C0), width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
          if (hasOre)
            Text(
              '${entry!.totalOre.toStringAsFixed(entry!.totalOre % 1 == 0 ? 0 : 1)}h',
              style: TextStyle(
                fontSize: 9,
                color: isSelected
                    ? Colors.white70
                    : const Color(0xFF1565C0),
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

// ── MonthStats ────────────────────────────────────────────────────────

class _MonthStats extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, DayEntryModel> entries;

  const _MonthStats(
      {required this.year, required this.month, required this.entries});

  @override
  Widget build(BuildContext context) {
    final me = entries.values
        .where((e) => e.date.year == year && e.date.month == month)
        .toList();
    final totalOre = me.fold<double>(0, (s, e) => s + e.totalOre);
    final ferie =
        me.fold<double>(0, (s, e) => s + e.oreFerie);
    final malattia =
        me.fold<double>(0, (s, e) => s + e.oreMalattia);
    final leg104 =
        me.fold<double>(0, (s, e) => s + e.oreLegge104);
    final mName =
        DateFormat('MMMM yyyy', 'it_IT').format(DateTime(year, month));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Riepilogo ${mName.toUpperCase()}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF1565C0))),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _chip(Icons.access_time,
                '${totalOre.toStringAsFixed(1)}h', 'Tot. ore', Colors.blue),
            _chip(Icons.beach_access, '${ferie.toStringAsFixed(1)}h', 'Ferie', Colors.orange),
            _chip(Icons.local_hospital, '${malattia.toStringAsFixed(1)}h', 'Malattia',
                Colors.red),
            _chip(Icons.accessibility, '${leg104.toStringAsFixed(1)}h', 'L.104', Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String value, String label, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      Text(label,
          style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }
}
