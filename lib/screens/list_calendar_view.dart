import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart' show isSameDay;
import '../models/day_entry_model.dart';
import '../providers/entries_provider.dart';

class ListCalendarView extends ConsumerStatefulWidget {
  final List<DateTime> days;
  final bool isWeekly;

  const ListCalendarView({
    super.key,
    required this.days,
    this.isWeekly = false,
  });

  @override
  ConsumerState<ListCalendarView> createState() => _ListCalendarViewState();
}

class _ListCalendarViewState extends ConsumerState<ListCalendarView> {
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(ListCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days.isEmpty ||
        widget.days.isEmpty ||
        oldWidget.days.first != widget.days.first ||
        oldWidget.days.last != widget.days.last) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _initControllers() {
    final entries = ref.read(entriesProvider);
    for (final day in widget.days) {
      final k = _dayKey(day);
      final entry = entries[k];
      _ctrls['${k}_m'] =
          TextEditingController(text: _fmt(entry?.oreServiziMemofast ?? 0));
      _ctrls['${k}_p'] =
          TextEditingController(text: _fmt(entry?.orePrivatiPulmino ?? 0));
      _ctrls['${k}_s'] =
          TextEditingController(text: _fmt(entry?.oreSostituzioni ?? 0));
      for (final suffix in ['_m', '_p', '_s']) {
        final fn = FocusNode();
        fn.addListener(() {
          if (!fn.hasFocus) _saveDay(day);
        });
        _focusNodes['$k$suffix'] = fn;
      }
    }
  }

  void _disposeControllers() {
    for (final c in _ctrls.values) { c.dispose(); }
    for (final f in _focusNodes.values) { f.dispose(); }
    _ctrls.clear();
    _focusNodes.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmt(double v) =>
      v == 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  double _parse(String s) =>
      s.trim().isEmpty ? 0 : double.tryParse(s.replaceAll(',', '.')) ?? 0;

  void _saveDay(DateTime day) {
    final k = _dayKey(day);
    final memo = _parse(_ctrls['${k}_m']?.text ?? '');
    final pulm = _parse(_ctrls['${k}_p']?.text ?? '');
    final sost = _parse(_ctrls['${k}_s']?.text ?? '');
    final existing = ref.read(entriesProvider)[k];
    final entry = DayEntryModel(
      date: day,
      oreServiziMemofast: memo,
      orePrivatiPulmino: pulm,
      oreSostituzioni: sost,
      oreFerie:    existing?.oreFerie    ?? 0,
      oreMalattia: existing?.oreMalattia ?? 0,
      oreLegge104: existing?.oreLegge104 ?? 0,
      nota:        existing?.nota        ?? '',
    );
    if (entry.hasData || existing != null) {
      ref.read(entriesProvider.notifier).saveEntry(entry);
    }
  }

  void _showNotaDialog(BuildContext context, DateTime day) {
    final k = _dayKey(day);
    final existing = ref.read(entriesProvider)[k];
    final ctrl = TextEditingController(text: existing?.nota ?? '');
    final dateLabel = DateFormat('EEE d MMMM', 'it_IT').format(day);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.notes, color: Color(0xFF1565C0), size: 20),
          const SizedBox(width: 8),
          Text(dateLabel,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          maxLength: 500,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Inserisci nota…',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF1565C0), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.dispose();
            },
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final nota = ctrl.text.trim();
              final memo = _parse(_ctrls['${k}_m']?.text ?? '');
              final pulm = _parse(_ctrls['${k}_p']?.text ?? '');
              final sost = _parse(_ctrls['${k}_s']?.text ?? '');
              final entry = DayEntryModel(
                date: day,
                oreServiziMemofast: memo,
                orePrivatiPulmino: pulm,
                oreSostituzioni: sost,
                oreFerie:    existing?.oreFerie    ?? 0,
                oreMalattia: existing?.oreMalattia ?? 0,
                oreLegge104: existing?.oreLegge104 ?? 0,
                nota:        nota,
              );
              ref.read(entriesProvider.notifier).saveEntry(entry);
              Navigator.pop(ctx);
              ctrl.dispose();
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0)),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _showAssenzaDialog(BuildContext context, DateTime day) {
    final k = _dayKey(day);
    final existing = ref.read(entriesProvider)[k];
    final oreFerie = existing?.oreFerie ?? 0;
    final fCtrl = TextEditingController(
        text: oreFerie == -1.0 ? '' : _fmt(oreFerie));
    final lCtrl = TextEditingController(text: _fmt(existing?.oreLegge104 ?? 0));
    bool ferieGiornata = oreFerie == -1.0;
    bool malattiaGiornata = (existing?.oreMalattia ?? 0) > 0;
    final dateLabel = DateFormat('EEE d MMMM', 'it_IT').format(day);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(dateLabel,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ferie – giornata intera o ore specifiche
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: ferieGiornata ? Colors.orange.shade50 : Colors.grey.shade100,
                  border: Border.all(
                      color: ferieGiornata
                          ? Colors.orange.shade300
                          : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.beach_access,
                            color: ferieGiornata
                                ? Colors.orange
                                : Colors.grey.shade500,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Ferie – Giornata intera',
                              style: TextStyle(
                                  color: ferieGiornata
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade600,
                                  fontSize: 13)),
                        ),
                        Switch(
                          value: ferieGiornata,
                          onChanged: (v) => setStateDialog(() {
                            ferieGiornata = v;
                            if (v) fCtrl.clear();
                          }),
                          activeThumbColor: Colors.orange,
                        ),
                      ],
                    ),
                    if (!ferieGiornata) ...[
                      const SizedBox(height: 8),
                      _dialogOreField(
                          'Ore Ferie', fCtrl, Colors.orange, Icons.schedule),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Malattia – giornata intera (switch)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: malattiaGiornata ? Colors.red.shade50 : Colors.grey.shade100,
                  border: Border.all(
                      color: malattiaGiornata
                          ? Colors.red.shade300
                          : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_hospital,
                        color: malattiaGiornata
                            ? Colors.red.shade400
                            : Colors.grey.shade500,
                        size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Malattia – Giornata intera',
                          style: TextStyle(
                              color: malattiaGiornata
                                  ? Colors.red.shade700
                                  : Colors.grey.shade600,
                              fontSize: 13)),
                    ),
                    Switch(
                      value: malattiaGiornata,
                      onChanged: (v) =>
                          setStateDialog(() => malattiaGiornata = v),
                      activeThumbColor: Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _dialogOreField(
                  'Ore Legge 104', lCtrl, Colors.purple, Icons.accessibility),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                fCtrl.dispose();
                lCtrl.dispose();
              },
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final memo = _parse(_ctrls['${k}_m']?.text ?? '');
                final pulm = _parse(_ctrls['${k}_p']?.text ?? '');
                final sost = _parse(_ctrls['${k}_s']?.text ?? '');
                final entry = DayEntryModel(
                  date: day,
                  oreServiziMemofast: memo,
                  orePrivatiPulmino: pulm,
                  oreSostituzioni: sost,
                  oreFerie: ferieGiornata ? -1.0 : _parse(fCtrl.text),
                  oreMalattia: malattiaGiornata ? 1.0 : 0.0,
                  oreLegge104: _parse(lCtrl.text),
                  nota: existing?.nota ?? '',
                );
                ref.read(entriesProvider.notifier).saveEntry(entry);
                Navigator.pop(ctx);
                fCtrl.dispose();
                lCtrl.dispose();
              },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0)),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogOreField(
      String label, TextEditingController ctrl, Color color, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        suffixText: 'h',
        prefixIcon: Icon(icon, color: color, size: 20),
        labelStyle: TextStyle(color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 2),
        ),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesProvider);
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.separated(
            itemCount: widget.days.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
            itemBuilder: (context, i) =>
                _buildDayRow(widget.days[i], entries),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    const hStyle = TextStyle(
        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10);
    return Container(
      color: const Color(0xFF0D3C7A),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: widget.isWeekly ? 72 : 58,
            child: const Text('GIORNO',
                textAlign: TextAlign.center, style: hStyle),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('MEMO\nFAST',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.lightBlueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10)),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text('PRIVATI',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10)),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text('SOSTI-\nTUZ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFFADC6FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 10)),
          ),
          const SizedBox(width: 4),
          const SizedBox(
            width: 52,
            child: Text('ASSENZA\n(ore)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10)),
          ),
          const SizedBox(width: 4),
          const SizedBox(
            width: 32,
            child: Text('NOTE',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(DateTime day, Map<String, DayEntryModel> entries) {
    final k = _dayKey(day);
    final entry = entries[k];
    final isWeekend = day.weekday >= DateTime.saturday;
    final isToday = isSameDay(day, DateTime.now());

    final dayLabel = widget.isWeekly
        ? DateFormat('EEE\nd MMM', 'it_IT').format(day)
        : DateFormat('EEE d', 'it_IT').format(day);

    Color rowBg = Colors.white;
    if (isToday) rowBg = const Color(0xFFE3F2FD);
    if (isWeekend && !isToday) rowBg = const Color(0xFFFFF8F8);
    if (!isToday && !isWeekend && day.day % 2 == 0) {
      rowBg = const Color(0xFFF8F8F8);
    }

    final rowHeight = widget.isWeekly ? 64.0 : 52.0;

    return Container(
      color: rowBg,
      height: rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Giorno
          SizedBox(
            width: widget.isWeekly ? 72 : 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: widget.isWeekly ? 12 : 11,
                    color: isToday
                        ? const Color(0xFF1565C0)
                        : isWeekend
                            ? Colors.red.shade600
                            : Colors.black87,
                  ),
                ),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 20,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: _oreField('${k}_m', day, const Color(0xFF1565C0))),
          const SizedBox(width: 4),
          Expanded(child: _oreField('${k}_p', day, Colors.teal.shade700)),
          const SizedBox(width: 4),
          Expanded(child: _oreField('${k}_s', day, Colors.indigo.shade700)),
          const SizedBox(width: 4),
          SizedBox(
            width: 52,
            child: _assenzaButton(day, entry),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            child: _notaButton(day, entry),
          ),
        ],
      ),
    );
  }

  Widget _oreField(String ctrlKey, DateTime day, Color color) {
    return TextField(
      controller: _ctrls[ctrlKey],
      focusNode: _focusNodes[ctrlKey],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
      ],
      onChanged: (_) => _saveDay(day),
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: 13, color: color, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: color, width: 2),
        ),
        hintText: '0',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
        suffixText: 'h',
        suffixStyle:
            TextStyle(color: Colors.grey.shade400, fontSize: 9),
        isDense: true,
      ),
    );
  }

  Widget _assenzaButton(DateTime day, DayEntryModel? entry) {
    final f  = entry?.oreFerie    ?? 0;
    final ma = entry?.oreMalattia ?? 0;
    final l  = entry?.oreLegge104 ?? 0;
    final hasAbs = f != 0 || ma > 0 || l > 0;

    final parts = <String>[];
    if (f == -1.0) { parts.add('F:G'); }
    else if (f > 0) { parts.add('F:${_fmt(f)}h'); }
    if (ma > 0) parts.add('M:G');
    if (l  > 0) parts.add('104:${_fmt(l)}');
    final label = hasAbs ? parts.join('\n') : '–';

    return GestureDetector(
      onTap: () => _showAssenzaDialog(context, day),
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: hasAbs ? Colors.orange.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: hasAbs
                  ? Colors.orange.shade400
                  : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 9,
              color: hasAbs
                  ? Colors.orange.shade800
                  : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _notaButton(DateTime day, DayEntryModel? entry) {
    final hasNota = (entry?.nota ?? '').isNotEmpty;
    return GestureDetector(
      onTap: () => _showNotaDialog(context, day),
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: hasNota ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: hasNota
                  ? Colors.blue.shade400
                  : Colors.grey.shade300),
        ),
        child: Center(
          child: Icon(
            hasNota ? Icons.notes : Icons.note_add_outlined,
            size: 16,
            color: hasNota
                ? Colors.blue.shade700
                : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
