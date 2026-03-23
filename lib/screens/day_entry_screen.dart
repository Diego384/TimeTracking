import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/day_entry_model.dart';
import '../providers/entries_provider.dart';

class DayEntryScreen extends ConsumerStatefulWidget {
  final DateTime date;
  const DayEntryScreen({super.key, required this.date});

  @override
  ConsumerState<DayEntryScreen> createState() => _DayEntryScreenState();
}

class _DayEntryScreenState extends ConsumerState<DayEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memofastCtrl  = TextEditingController();
  final _pulminoCtrl   = TextEditingController();
  final _sostCtrl      = TextEditingController();
  final _ferieCtrl     = TextEditingController();
  final _legge104Ctrl  = TextEditingController();
  final _notaCtrl      = TextEditingController();
  bool _malattiaGiornata = false;
  bool _ferieGiornata = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  void _loadExisting() {
    final entry = ref.read(entriesProvider.notifier).getEntry(widget.date);
    if (entry != null) {
      _memofastCtrl.text  = _fmt(entry.oreServiziMemofast);
      _pulminoCtrl.text   = _fmt(entry.orePrivatiPulmino);
      _sostCtrl.text      = _fmt(entry.oreSostituzioni);
      _ferieGiornata      = entry.oreFerie == -1.0;
      if (!_ferieGiornata) _ferieCtrl.text = _fmt(entry.oreFerie);
      _malattiaGiornata   = entry.oreMalattia > 0;
      _legge104Ctrl.text  = _fmt(entry.oreLegge104);
      _notaCtrl.text      = entry.nota;
    }
  }

  String _fmt(double v) =>
      v == 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  double _parse(String s) =>
      s.trim().isEmpty ? 0 : double.tryParse(s.replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final entry = DayEntryModel(
      date: widget.date,
      oreServiziMemofast: _parse(_memofastCtrl.text),
      orePrivatiPulmino:  _parse(_pulminoCtrl.text),
      oreSostituzioni:    _parse(_sostCtrl.text),
      oreFerie:           _ferieGiornata ? -1.0 : _parse(_ferieCtrl.text),
      oreMalattia:        _malattiaGiornata ? 1.0 : 0.0,
      oreLegge104:        _parse(_legge104Ctrl.text),
      nota:               _notaCtrl.text.trim(),
    );
    await ref.read(entriesProvider.notifier).saveEntry(entry);
    setState(() => _isLoading = false);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _memofastCtrl.dispose();
    _pulminoCtrl.dispose();
    _sostCtrl.dispose();
    _ferieCtrl.dispose();
    _legge104Ctrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('EEEE d MMMM yyyy', 'it_IT').format(widget.date);
    final isWeekend = widget.date.weekday == DateTime.saturday ||
        widget.date.weekday == DateTime.sunday;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inserimento ore',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(dateLabel,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isWeekend)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text('Giorno festivo / weekend',
                          style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

              // ── Ore Lavorative ────────────────────────────────────
              _sectionTitle('Ore Lavorative', Icons.access_time),
              const SizedBox(height: 12),
              _oreField(
                  controller: _memofastCtrl,
                  label: 'Ore Servizi Memofast',
                  color: Colors.blue),
              const SizedBox(height: 12),
              _oreField(
                  controller: _pulminoCtrl,
                  label: 'Ore Privati',
                  color: Colors.teal),
              const SizedBox(height: 12),
              _oreField(
                  controller: _sostCtrl,
                  label: 'Ore Sostituzioni',
                  color: Colors.indigo),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              // ── Assenze / Permessi ────────────────────────────────
              _sectionTitle('Assenza / Permesso (ore)', Icons.event_busy),
              const SizedBox(height: 12),
              // Ferie – giornata intera o ore specifiche
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _ferieGiornata ? Colors.orange.shade50 : Colors.grey.shade50,
                  border: Border.all(
                      color: _ferieGiornata
                          ? Colors.orange.shade300
                          : Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.beach_access,
                            color: _ferieGiornata
                                ? Colors.orange
                                : Colors.grey.shade500),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ferie – Giornata intera',
                            style: TextStyle(
                                color: _ferieGiornata
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade600,
                                fontSize: 15),
                          ),
                        ),
                        Switch(
                          value: _ferieGiornata,
                          onChanged: (v) => setState(() {
                            _ferieGiornata = v;
                            if (v) _ferieCtrl.clear();
                          }),
                          activeThumbColor: Colors.orange,
                        ),
                      ],
                    ),
                    if (!_ferieGiornata) ...[
                      const SizedBox(height: 10),
                      _oreField(
                          controller: _ferieCtrl,
                          label: 'Ore Ferie',
                          color: Colors.orange,
                          icon: Icons.schedule),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Malattia – sempre giornata intera
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _malattiaGiornata ? Colors.red.shade50 : Colors.grey.shade50,
                  border: Border.all(
                      color: _malattiaGiornata
                          ? Colors.red.shade300
                          : Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_hospital,
                        color: _malattiaGiornata
                            ? Colors.red
                            : Colors.grey.shade500),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Malattia – Giornata intera',
                        style: TextStyle(
                            color: _malattiaGiornata
                                ? Colors.red.shade700
                                : Colors.grey.shade600,
                            fontSize: 15),
                      ),
                    ),
                    Switch(
                      value: _malattiaGiornata,
                      onChanged: (v) => setState(() => _malattiaGiornata = v),
                      activeThumbColor: Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _oreField(
                  controller: _legge104Ctrl,
                  label: 'Ore Legge 104',
                  color: Colors.purple,
                  icon: Icons.accessibility),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              // ── Note ──────────────────────────────────────────────
              _sectionTitle('Note giornata', Icons.notes),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notaCtrl,
                maxLines: 4,
                maxLength: 500,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Inserisci eventuali note per questa giornata…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF1565C0), width: 2),
                  ),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 16),

              // ── Totale ────────────────────────────────────────────
              _TotalRow(
                memofast:  _parse(_memofastCtrl.text),
                pulmino:   _parse(_pulminoCtrl.text),
                sost:      _parse(_sostCtrl.text),
                ferie:     _ferieGiornata ? -1.0 : _parse(_ferieCtrl.text),
                malattia:  _malattiaGiornata ? 1.0 : 0.0,
                legge104:  _parse(_legge104Ctrl.text),
              ),

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text('Salva giornata'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1565C0))),
      ],
    );
  }

  Widget _oreField({
    required TextEditingController controller,
    required String label,
    required Color color,
    IconData icon = Icons.schedule,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
      ],
      onChanged: (_) => setState(() {}),
      validator: (v) {
        if (v != null && v.isNotEmpty) {
          final val = double.tryParse(v.replaceAll(',', '.'));
          if (val == null) return 'Inserisci un numero valido';
          if (val < 0 || val > 24) return 'Valore tra 0 e 24';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        suffixText: 'h',
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        labelStyle: TextStyle(color: color),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final double memofast;
  final double pulmino;
  final double sost;
  final double ferie;
  final double malattia;
  final double legge104;

  const _TotalRow({
    required this.memofast,
    required this.pulmino,
    required this.sost,
    required this.ferie,
    required this.malattia,
    required this.legge104,
  });

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final totalLav = memofast + pulmino + sost;
    final hasAssenza = ferie != 0.0 || malattia > 0 || legge104 > 0;
    // Etichetta assenza
    final absParts = <String>[];
    if (ferie == -1.0) {
      absParts.add('Ferie: G');
    } else if (ferie > 0) {
      absParts.add('Ferie: ${_fmt(ferie)}h');
    }
    if (malattia > 0) { absParts.add('Malattia: G'); }
    if (legge104 > 0) { absParts.add('L.104: ${_fmt(legge104)}h'); }
    final absLabel = absParts.join('  ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ore lavorative',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${_fmt(totalLav)} h',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF1565C0))),
            ],
          ),
          if (hasAssenza) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Assenze',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(absLabel,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.orange.shade700)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
