import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/comune_services_model.dart';
import '../providers/comune_services_provider.dart';

class ComuneServicesView extends ConsumerStatefulWidget {
  final int year;
  final int month;

  const ComuneServicesView(
      {super.key, required this.year, required this.month});

  @override
  ConsumerState<ComuneServicesView> createState() =>
      _ComuneServicesViewState();
}

class _ComuneServicesViewState extends ConsumerState<ComuneServicesView> {
  // key: "$comune_$field" => controller
  final Map<String, TextEditingController> _ctrls = {};

  // campi nell'ordine della griglia
  static const _fields = [
    'adi', 'ada', 'adh', 'adm', 'asia', 'asiaIstituti', 'cpf'
  ];
  static const _colLabels = [
    'ADI', 'ADA', 'ADH', 'ADM', 'ASIA', 'ASIA\nIst. Sup.', 'CPF'
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(ComuneServicesView old) {
    super.didUpdateWidget(old);
    if (old.year != widget.year || old.month != widget.month) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _initControllers() {
    for (final comune in kComuni) {
      final m = ref
          .read(comuneServicesProvider.notifier)
          .getOrCreate(widget.year, widget.month, comune);
      for (final field in _fields) {
        _ctrls['${comune}_$field'] =
            TextEditingController(text: _fmt(_getValue(m, field)));
      }
    }
  }

  void _disposeControllers() {
    for (final c in _ctrls.values) { c.dispose(); }
    _ctrls.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  String _fmt(double v) =>
      v == 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  double _parse(String s) =>
      s.trim().isEmpty ? 0 : double.tryParse(s.replaceAll(',', '.')) ?? 0;

  double _getValue(ComuneServicesModel m, String field) {
    switch (field) {
      case 'adi':         return m.adi;
      case 'ada':         return m.ada;
      case 'adh':         return m.adh;
      case 'adm':         return m.adm;
      case 'asia':        return m.asia;
      case 'asiaIstituti': return m.asiaIstituti;
      case 'cpf':         return m.cpf;
      default:            return 0;
    }
  }

  void _saveComune(String comune) {
    final existing = ref
        .read(comuneServicesProvider.notifier)
        .getOrCreate(widget.year, widget.month, comune);
    final updated = existing.copyWith(
      adi:          _parse(_ctrls['${comune}_adi']?.text ?? ''),
      ada:          _parse(_ctrls['${comune}_ada']?.text ?? ''),
      adh:          _parse(_ctrls['${comune}_adh']?.text ?? ''),
      adm:          _parse(_ctrls['${comune}_adm']?.text ?? ''),
      asia:         _parse(_ctrls['${comune}_asia']?.text ?? ''),
      asiaIstituti: _parse(_ctrls['${comune}_asiaIstituti']?.text ?? ''),
      cpf:          _parse(_ctrls['${comune}_cpf']?.text ?? ''),
    );
    ref.read(comuneServicesProvider.notifier).saveEntry(updated);
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(comuneServicesProvider);
    final monthLabel =
        DateFormat('MMMM yyyy', 'it_IT').format(DateTime(widget.year, widget.month));

    // Totali colonne
    final tots = <String, double>{};
    for (final field in _fields) { tots[field] = 0; }
    for (final comune in kComuni) {
      final key =
          '${widget.year}-${widget.month.toString().padLeft(2, '0')}-$comune';
      final m = services[key];
      if (m != null) {
        for (final field in _fields) {
          tots[field] = (tots[field] ?? 0) + _getValue(m, field);
        }
      }
    }
    final totaleServizio = tots.values.fold(0.0, (a, b) => a + b);

    return Column(
      children: [
        // Intestazione mese
        Container(
          color: const Color(0xFF0D3C7A),
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Servizi per Comune – ${monthLabel.toUpperCase()}',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),

        // Griglia scorrevole orizzontalmente
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              // larghezza: comune(100) + 7 col(58 ciascuna) + totale(70)
              width: 100 + 7 * 58.0 + 70,
              child: Column(
                children: [
                  _buildHeaderRow(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: kComuni.length + 2, // comuni + totale + complessivo
                      itemBuilder: (ctx, i) {
                        if (i < kComuni.length) {
                          return _buildComuneRow(kComuni[i], i.isEven);
                        } else if (i == kComuni.length) {
                          return _buildTotalsRow(tots, totaleServizio);
                        } else {
                          return _buildComplessivoRow(totaleServizio);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    const hStyle = TextStyle(
        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9);
    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: const Text('COMUNE',
                textAlign: TextAlign.center, style: hStyle),
          ),
          ...List.generate(_colLabels.length, (i) => SizedBox(
            width: 58,
            child: Text(_colLabels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: i < 4
                      ? Colors.lightBlueAccent
                      : i < 6
                          ? Colors.cyanAccent
                          : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                )),
          )),
          SizedBox(
            width: 70,
            child: const Text('TOTALE\nCOMUNE',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.yellowAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 9)),
          ),
        ],
      ),
    );
  }

  Widget _buildComuneRow(String comune, bool isEven) {
    final rowBg = isEven ? const Color(0xFFF0F0F0) : Colors.white;

    // Totale riga dal controller (reattivo)
    double rowTotal = 0;
    for (final field in _fields) {
      rowTotal += _parse(_ctrls['${comune}_$field']?.text ?? '');
    }

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Row(
        children: [
          // Nome comune
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                comune,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // Campi servizi
          ...List.generate(_fields.length, (i) {
            final field = _fields[i];
            final ctrlKey = '${comune}_$field';
            return SizedBox(
              width: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 3, vertical: 4),
                child: TextField(
                  controller: _ctrls[ctrlKey],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.,]'))
                  ],
                  onChanged: (_) {
                    _saveComune(comune);
                    setState(() {});
                  },
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: i < 4
                        ? const Color(0xFF1565C0)
                        : i < 6
                            ? Colors.teal.shade700
                            : Colors.indigo.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 2, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                          color: i < 4
                              ? const Color(0xFF1565C0)
                              : Colors.teal,
                          width: 1.5),
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 10),
                    isDense: true,
                  ),
                ),
              ),
            );
          }),
          // Totale riga
          SizedBox(
            width: 70,
            child: Container(
              height: double.infinity,
              color: const Color(0xFFFFF9C4),
              child: Center(
                child: Text(
                  rowTotal > 0 ? _fmt(rowTotal) : '0',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsRow(Map<String, double> tots, double totale) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF176),
        border: Border(
            top: BorderSide(color: Color(0xFF9E9E9E), width: 1.5),
            bottom: BorderSide(color: Color(0xFF9E9E9E))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('TOTALE\nSERVIZIO',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037))),
            ),
          ),
          ...List.generate(_fields.length, (i) => SizedBox(
            width: 58,
            child: Center(
              child: Text(
                _fmt(tots[_fields[i]] ?? 0),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037)),
              ),
            ),
          )),
          SizedBox(
            width: 70,
            child: Container(
              height: double.infinity,
              color: const Color(0xFFFFD700),
              child: Center(
                child: Text(
                  _fmt(totale),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplessivoRow(double totale) {
    return Container(
      color: const Color(0xFF2E7D32),
      height: 36,
      child: Row(
        children: [
          SizedBox(
            width: 100 + 7 * 58.0,
            child: const Center(
              child: Text('TOTALE COMPLESSIVO MESE',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          SizedBox(
            width: 70,
            child: Center(
              child: Text(
                _fmt(totale),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
