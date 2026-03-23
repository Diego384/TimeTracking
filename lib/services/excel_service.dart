import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/day_entry_model.dart';
import '../models/operator_model.dart';
import '../models/comune_services_model.dart';

class ExcelService {
  // Colori AARRGGBB
  static const _blu        = 'FF1565C0';
  static const _bluScuro   = 'FF0D3C7A';
  static const _giallo     = 'FFFFD700';
  static const _verde      = 'FF2E7D32';
  static const _arancio    = 'FFE65100';
  static const _rosso      = 'FFB71C1C';
  static const _viola      = 'FF4A148C';
  static const _bianco     = 'FFFFFFFF';
  static const _nero       = 'FF000000';
  static const _grigioChiaro = 'FFF0F0F0';
  static const _grigioRiga   = 'FFD8D8D8';
  static const _grigioHeader = 'FFD0D0D0';
  static const _bordo        = 'FF9E9E9E';
  static const _bordoScuro   = 'FF424242';

  Future<File> generateReport({
    required OperatorModel operator,
    required int year,
    required int month,
    required Map<String, DayEntryModel> entries,
    required Map<String, ComuneServicesModel> comuneServices,
  }) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Report');
    final sheet = excel['Report'];

    final monthName =
        DateFormat('MMMM yyyy', 'it_IT').format(DateTime(year, month));
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    // ── Bordi helper ──────────────────────────────────────────────
    Border thinBorder(String colorHex) => Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString(colorHex));

    Border medBorder(String colorHex) => Border(
        borderStyle: BorderStyle.Medium,
        borderColorHex: ExcelColor.fromHexString(colorHex));

    // ── Helper stile ──────────────────────────────────────────────
    CellStyle makeStyle({
      String bg = 'FFFFFFFF',
      String fg = 'FF000000',
      bool bold = false,
      bool italic = false,
      HorizontalAlign align = HorizontalAlign.Center,
      VerticalAlign vAlign = VerticalAlign.Center,
      bool thickBorder = false,
      bool borders = true,
    }) {
      final b =
          thickBorder ? medBorder(_bordoScuro) : thinBorder(_bordo);
      final noBorder = Border();
      return CellStyle(
        backgroundColorHex: ExcelColor.fromHexString(bg),
        fontColorHex: ExcelColor.fromHexString(fg),
        bold: bold,
        italic: italic,
        horizontalAlign: align,
        verticalAlign: vAlign,
        textWrapping: TextWrapping.WrapText,
        leftBorder:   borders ? b : noBorder,
        rightBorder:  borders ? b : noBorder,
        topBorder:    borders ? b : noBorder,
        bottomBorder: borders ? b : noBorder,
      );
    }

    void setCell(String addr, dynamic value, CellStyle? style) {
      final cell = sheet.cell(CellIndex.indexByString(addr));
      if (value is String) {
        cell.value = TextCellValue(value);
      } else if (value is double) {
        cell.value = DoubleCellValue(value);
      } else if (value is int) {
        cell.value = IntCellValue(value);
      }
      if (style != null) cell.cellStyle = style;
    }

    void mergeAndSet(
        String from, String to, dynamic value, CellStyle? style) {
      sheet.merge(
          CellIndex.indexByString(from), CellIndex.indexByString(to));
      setCell(from, value, style);
    }

    // ── Larghezza colonne (7 colonne: A-G) ───────────────────────
    sheet.setColumnWidth(0, 10);  // A - GIORNO
    sheet.setColumnWidth(1, 22);  // B - Memofast
    sheet.setColumnWidth(2, 24);  // C - Pulmino/Doposcuola
    sheet.setColumnWidth(3, 20);  // D - Sostituzioni
    sheet.setColumnWidth(4, 12);  // E - Ferie
    sheet.setColumnWidth(5, 14);  // F - Malattia
    sheet.setColumnWidth(6, 12);  // G - Legge 104

    // ── Riga 1: Titolo cooperativa ────────────────────────────────
    sheet.setRowHeight(0, 32);
    mergeAndSet(
      'A1', 'G1',
      'Cooperativa Sociale Oltre i sogni a r.l. ONLUS',
      makeStyle(
          bg: _blu, fg: _bianco, bold: true, italic: true,
          thickBorder: true),
    );

    // ── Riga 2: Nome operatore ────────────────────────────────────
    sheet.setRowHeight(1, 22);
    setCell('A2', 'NOME E COGNOME OPERATORE',
        makeStyle(bg: _grigioHeader, fg: _nero,
            align: HorizontalAlign.Left, bold: true));
    mergeAndSet('B2', 'G2', operator.fullName,
        makeStyle(bg: _grigioHeader, fg: _nero,
            align: HorizontalAlign.Left));

    // ── Riga 3: Mese ─────────────────────────────────────────────
    sheet.setRowHeight(2, 22);
    setCell('A3', 'MESE DI RIFERIMENTO',
        makeStyle(bg: _grigioHeader, fg: _nero,
            align: HorizontalAlign.Left, bold: true));
    mergeAndSet('B3', 'G3', monthName.toUpperCase(),
        makeStyle(bg: _grigioHeader, fg: _nero,
            align: HorizontalAlign.Left));

    // ── Riga 4: Ambito ────────────────────────────────────────────
    sheet.setRowHeight(3, 22);
    mergeAndSet(
      'A4', 'G4',
      'Servizi Ambito Na3 – Penisola',
      makeStyle(bg: _blu, fg: _bianco, bold: true, italic: true,
          thickBorder: true),
    );

    // ── Riga 5: Intestazioni colonne ──────────────────────────────
    sheet.setRowHeight(4, 44);
    final colHeaders = [
      ('A5', 'GIORNO'),
      ('B5', 'ORE SERVIZI\nMEMOFAST'),
      ('C5', 'ORE\nPRIVATI'),
      ('D5', 'ORE\nSOSTITUZIONI'),
      ('E5', 'ORE\nFERIE'),
      ('F5', 'ORE\nMALATTIA'),
      ('G5', 'ORE\nLEGGE 104'),
    ];
    for (final (addr, label) in colHeaders) {
      setCell(addr, label,
          makeStyle(
              bg: _bluScuro, fg: _bianco, bold: true,
              thickBorder: true));
    }

    // ── Righe giorni (da riga 6) ──────────────────────────────────
    double totMemofast    = 0;
    double totPulmino     = 0;
    double totSost        = 0;
    double totFerieOre    = 0;
    int    totFerieGiorni = 0;
    double totMalattia    = 0;
    double totLeg104      = 0;

    for (int day = 1; day <= 31; day++) {
      final excelRow = day + 5;
      final rowIdx   = day + 4;
      sheet.setRowHeight(rowIdx, 18);

      final rowBg = day > daysInMonth
          ? _grigioRiga
          : (day % 2 == 0 ? _grigioChiaro : _bianco);

      setCell('A$excelRow', day,
          makeStyle(bg: rowBg, align: HorizontalAlign.Center));

      if (day > daysInMonth) {
        for (final col in ['B', 'C', 'D', 'E', 'F', 'G']) {
          setCell('$col$excelRow', '', makeStyle(bg: _grigioRiga));
        }
        continue;
      }

      final key =
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final entry = entries[key];
      final dataStyle =
          makeStyle(bg: rowBg, align: HorizontalAlign.Center);
      final emptyStyle = makeStyle(bg: rowBg);

      if (entry != null && entry.hasData) {
        final memo = entry.oreServiziMemofast;
        final pulm = entry.orePrivatiPulmino;
        final sost = entry.oreSostituzioni;
        final fer  = entry.oreFerie;
        final mal  = entry.oreMalattia;
        final l104 = entry.oreLegge104;

        setCell('B$excelRow', memo > 0 ? memo : '',
            memo > 0 ? dataStyle : emptyStyle);
        setCell('C$excelRow', pulm > 0 ? pulm : '',
            pulm > 0 ? dataStyle : emptyStyle);
        setCell('D$excelRow', sost > 0 ? sost : '',
            sost > 0 ? dataStyle : emptyStyle);
        final ferVal = fer == -1.0 ? 'G' : (fer > 0 ? fer : '');
        setCell('E$excelRow', ferVal,
            fer != 0
                ? makeStyle(
                    bg: rowBg, fg: _arancio,
                    bold: true, align: HorizontalAlign.Center)
                : emptyStyle);
        setCell('F$excelRow', mal  > 0 ? mal  : '',
            mal  > 0
                ? makeStyle(
                    bg: rowBg, fg: _rosso,
                    bold: true, align: HorizontalAlign.Center)
                : emptyStyle);
        setCell('G$excelRow', l104 > 0 ? l104 : '',
            l104 > 0
                ? makeStyle(
                    bg: rowBg, fg: _viola,
                    bold: true, align: HorizontalAlign.Center)
                : emptyStyle);

        totMemofast += memo;
        totPulmino  += pulm;
        totSost     += sost;
        if (fer == -1.0) { totFerieGiorni++; } else { totFerieOre += fer; }
        totMalattia += mal;
        totLeg104   += l104;
      } else {
        for (final col in ['B', 'C', 'D', 'E', 'F', 'G']) {
          setCell('$col$excelRow', '', emptyStyle);
        }
      }
    }

    // ── Riga TOTALE ORE ───────────────────────────────────────────
    const totRow = 37;
    sheet.setRowHeight(36, 22);
    setCell('A$totRow', 'TOTALE ORE',
        makeStyle(bg: _giallo, fg: _nero, bold: true,
            align: HorizontalAlign.Left, thickBorder: true));
    setCell('B$totRow', totMemofast > 0 ? totMemofast : '',
        makeStyle(bg: _giallo, fg: _nero, bold: true, thickBorder: true));
    setCell('C$totRow', totPulmino > 0 ? totPulmino : '',
        makeStyle(bg: _giallo, fg: _nero, bold: true, thickBorder: true));
    setCell('D$totRow', totSost > 0 ? totSost : '',
        makeStyle(bg: _giallo, fg: _nero, bold: true, thickBorder: true));
    final totFerieLabel = totFerieGiorni > 0 && totFerieOre > 0
        ? '${totFerieGiorni}G+${totFerieOre.toInt()}'
        : totFerieGiorni > 0 ? '${totFerieGiorni}G'
        : totFerieOre > 0 ? totFerieOre : '';
    setCell('E$totRow', totFerieLabel,
        makeStyle(bg: _giallo, fg: _arancio, bold: true, thickBorder: true));
    setCell('F$totRow', totMalattia > 0 ? totMalattia : '',
        makeStyle(bg: _giallo, fg: _rosso, bold: true, thickBorder: true));
    setCell('G$totRow', totLeg104 > 0 ? totLeg104 : '',
        makeStyle(bg: _giallo, fg: _viola, bold: true, thickBorder: true));

    // ── Riga TOTALE COMPLESSIVO MESE ──────────────────────────────
    const compRow = 38;
    sheet.setRowHeight(37, 22);
    mergeAndSet('A$compRow', 'D$compRow', 'TOTALE COMPLESSIVO MESE',
        makeStyle(bg: _verde, fg: _bianco, bold: true, thickBorder: true));
    final totale = totMemofast + totPulmino + totSost;
    mergeAndSet('E$compRow', 'G$compRow', totale > 0 ? totale : '',
        makeStyle(bg: _verde, fg: _bianco, bold: true, thickBorder: true));

    // ── Riga LEGENDA ──────────────────────────────────────────────
    sheet.setRowHeight(38, 18);
    mergeAndSet('A39', 'G39',
        'LEGGENDA:   Colonna E = Ore Ferie   |   Colonna F = Ore Malattia   |   Colonna G = Ore Legge 104',
        makeStyle(bg: _blu, fg: _bianco, italic: true,
            align: HorizontalAlign.Left));

    // ── Foglio 2: Servizi per Comune ─────────────────────────────
    final sheet2 = excel['Servizi Comuni'];

    void setCell2(String addr, dynamic value, CellStyle? style) {
      final cell = sheet2.cell(CellIndex.indexByString(addr));
      if (value is String) {
        cell.value = TextCellValue(value);
      } else if (value is double) {
        cell.value = DoubleCellValue(value);
      } else if (value is int) {
        cell.value = IntCellValue(value);
      }
      if (style != null) cell.cellStyle = style;
    }

    void mergeAndSet2(String from, String to, dynamic value, CellStyle? style) {
      sheet2.merge(CellIndex.indexByString(from), CellIndex.indexByString(to));
      setCell2(from, value, style);
    }

    // Larghezze colonne foglio 2
    sheet2.setColumnWidth(0, 16);  // A - COMUNE
    sheet2.setColumnWidth(1, 10);  // B - ADI
    sheet2.setColumnWidth(2, 10);  // C - ADA
    sheet2.setColumnWidth(3, 10);  // D - ADH
    sheet2.setColumnWidth(4, 10);  // E - ADM
    sheet2.setColumnWidth(5, 10);  // F - ASIA
    sheet2.setColumnWidth(6, 14);  // G - ASIA Ist.
    sheet2.setColumnWidth(7, 10);  // H - CPF
    sheet2.setColumnWidth(8, 14);  // I - TOTALE COMUNE

    // Riga 1: Titolo
    sheet2.setRowHeight(0, 30);
    mergeAndSet2('A1', 'I1',
        'DETTAGLIO SERVIZI PER COMUNE – Na3 PENISOLA',
        makeStyle(bg: _bluScuro, fg: _bianco, bold: true, thickBorder: true));

    // Riga 2: Nome operatore
    sheet2.setRowHeight(1, 20);
    setCell2('A2', 'NOME E COGNOME OPERATORE',
        makeStyle(bg: _grigioHeader, fg: _nero, align: HorizontalAlign.Left, bold: true));
    mergeAndSet2('B2', 'I2', operator.fullName,
        makeStyle(bg: _grigioHeader, fg: _nero, align: HorizontalAlign.Left));

    // Riga 3: Mese
    sheet2.setRowHeight(2, 20);
    setCell2('A3', 'MESE DI RIFERIMENTO',
        makeStyle(bg: _grigioHeader, fg: _nero, align: HorizontalAlign.Left, bold: true));
    mergeAndSet2('B3', 'I3', monthName.toUpperCase(),
        makeStyle(bg: _grigioHeader, fg: _nero, align: HorizontalAlign.Left));

    // Riga 4: Ambito
    sheet2.setRowHeight(3, 20);
    mergeAndSet2('A4', 'I4', 'Servizi Ambito Na3 – Penisola',
        makeStyle(bg: _blu, fg: _bianco, bold: true, italic: true));

    // Riga 5: Intestazioni
    sheet2.setRowHeight(4, 36);
    const colHeaders2 = [
      ('A5', 'COMUNE'), ('B5', 'ADI'), ('C5', 'ADA'), ('D5', 'ADH'),
      ('E5', 'ADM'), ('F5', 'ASIA'), ('G5', 'ASIA\nIstituti\nSuperiori'),
      ('H5', 'CPF'), ('I5', 'TOTALE\nCOMUNE'),
    ];
    for (final (addr, label) in colHeaders2) {
      setCell2(addr, label,
          makeStyle(bg: _bluScuro, fg: _bianco, bold: true, thickBorder: true));
    }

    // Righe comuni
    double tot2Adi = 0, tot2Ada = 0, tot2Adh = 0, tot2Adm = 0;
    double tot2Asia = 0, tot2AsiaI = 0, tot2Cpf = 0;

    for (int i = 0; i < kComuni.length; i++) {
      final comune = kComuni[i];
      final excelRow = i + 6;
      final rowBg = i % 2 == 0 ? _grigioChiaro : _bianco;
      sheet2.setRowHeight(i + 5, 18);

      final key2 =
          '$year-${month.toString().padLeft(2, '0')}-$comune';
      final m = comuneServices[key2];

      final adi  = m?.adi          ?? 0;
      final ada  = m?.ada          ?? 0;
      final adh  = m?.adh          ?? 0;
      final adm  = m?.adm          ?? 0;
      final asia = m?.asia         ?? 0;
      final asiaI = m?.asiaIstituti ?? 0;
      final cpf  = m?.cpf          ?? 0;
      final totC = adi + ada + adh + adm + asia + asiaI + cpf;

      setCell2('A$excelRow', comune,
          makeStyle(bg: rowBg, align: HorizontalAlign.Left));
      setCell2('B$excelRow', adi  > 0 ? adi  : '', makeStyle(bg: rowBg));
      setCell2('C$excelRow', ada  > 0 ? ada  : '', makeStyle(bg: rowBg));
      setCell2('D$excelRow', adh  > 0 ? adh  : '', makeStyle(bg: rowBg));
      setCell2('E$excelRow', adm  > 0 ? adm  : '', makeStyle(bg: rowBg));
      setCell2('F$excelRow', asia > 0 ? asia : '', makeStyle(bg: rowBg));
      setCell2('G$excelRow', asiaI > 0 ? asiaI : '', makeStyle(bg: rowBg));
      setCell2('H$excelRow', cpf  > 0 ? cpf  : '', makeStyle(bg: rowBg));
      setCell2('I$excelRow', totC > 0 ? totC : '',
          makeStyle(bg: _giallo, fg: _nero, bold: true));

      tot2Adi  += adi;
      tot2Ada  += ada;
      tot2Adh  += adh;
      tot2Adm  += adm;
      tot2Asia += asia;
      tot2AsiaI += asiaI;
      tot2Cpf  += cpf;
    }

    // Riga TOTALE SERVIZIO
    final totRow2 = kComuni.length + 6;
    sheet2.setRowHeight(kComuni.length + 5, 22);
    setCell2('A$totRow2', 'TOTALE SERVIZIO',
        makeStyle(bg: _giallo, fg: _nero, bold: true, align: HorizontalAlign.Left, thickBorder: true));
    for (final (col, val) in [
      ('B', tot2Adi), ('C', tot2Ada), ('D', tot2Adh), ('E', tot2Adm),
      ('F', tot2Asia), ('G', tot2AsiaI), ('H', tot2Cpf),
    ]) {
      setCell2('$col$totRow2', val > 0 ? val : '',
          makeStyle(bg: _giallo, fg: _nero, bold: true, thickBorder: true));
    }
    final totServizio = tot2Adi + tot2Ada + tot2Adh + tot2Adm +
        tot2Asia + tot2AsiaI + tot2Cpf;
    setCell2('I$totRow2', totServizio > 0 ? totServizio : '',
        makeStyle(bg: _giallo, fg: _nero, bold: true, thickBorder: true));

    // Riga TOTALE COMPLESSIVO
    final compRow2 = totRow2 + 1;
    sheet2.setRowHeight(totRow2, 22);
    mergeAndSet2('A$compRow2', 'H$compRow2', 'TOTALE COMPLESSIVO MESE',
        makeStyle(bg: _verde, fg: _bianco, bold: true, thickBorder: true));
    setCell2('I$compRow2', totServizio > 0 ? totServizio : '',
        makeStyle(bg: _verde, fg: _bianco, bold: true, thickBorder: true));

    // Riga sede operativa (footer)
    final footRow = compRow2 + 1;
    sheet2.setRowHeight(footRow - 1, 16);
    mergeAndSet2('A$footRow', 'I$footRow',
        'sede operativa: Corso Italia, 165 – 80065 Sant\'Agnello NA  |  tel: 081/16558132  |  e-mail: info@oltreisogni.org  |  P.IVA: 04018761215',
        makeStyle(fg: 'FF757575', italic: true, align: HorizontalAlign.Center, borders: false));

    // ── Salva su file temporaneo ──────────────────────────────────
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Errore nella generazione del file Excel');
    }

    final dir = await getTemporaryDirectory();
    final fileName =
        'Report_Ore_${operator.surname}_${monthName.replaceAll(' ', '_')}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }
}

class DateUtils {
  static int getDaysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}
