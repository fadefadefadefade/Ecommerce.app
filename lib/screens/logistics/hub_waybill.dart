import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/logistics_api.dart';
import 'logistics_kit.dart';

/// The website's printable hub waybill (sc.waybill): one 4 × 6 in label per parcel with the waybill barcode, sort code,
/// hub and barangay, recipient, sender, the cash to collect, details and contents.
class HubWaybillPdf {
  static final _money = NumberFormat('#,##0.00', 'en_US');

  static String _kg(dynamic v) {
    if (v == null) return '—';
    final n = v is num ? v : num.tryParse('$v') ?? 0;
    return '${n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')} kg';
  }

  /// [labels] are the `waybills` rows from GET /logistics/waybills.
  static Future<Uint8List> build(List<Map<String, dynamic>> labels) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    pw.Widget label(String t) => pw.Text(t.toUpperCase(), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700, letterSpacing: 0.5));
    pw.Widget strong(String t, {double size = 10}) => pw.Text(t, style: pw.TextStyle(font: bold, fontSize: size));
    pw.Widget box(pw.Widget child, {bool last = false}) => pw.Container(
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(border: last ? null : const pw.Border(bottom: pw.BorderSide(width: 1.5))),
          child: child,
        );

    final doc = pw.Document(title: labels.length == 1 ? 'Waybill ${labels.first['waybill']}' : '${labels.length} waybills', author: 'ALVY');
    for (final w in labels) {
      final cod = w['cod'];
      final items = asList(w['items']);
      doc.addPage(pw.Page(
        pageFormat: const PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch, marginAll: 10),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            box(pw.Row(children: [
              pw.Expanded(child: strong('ALVY Express', size: 13)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(color: cod != null ? PdfColors.black : null, border: pw.Border.all()),
                child: pw.Text(cod != null ? 'COD' : 'PAID', style: pw.TextStyle(font: bold, fontSize: 10, color: cod != null ? PdfColors.white : PdfColors.black)),
              ),
            ])),
            box(pw.Column(children: [
              pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: '${w['waybill'] ?? ''}', height: 46, drawText: false),
              pw.SizedBox(height: 3),
              strong('${w['waybill'] ?? ''}', size: 14),
            ])),
            box(pw.Row(children: [
              pw.Expanded(child: strong('${w['sort_code'] ?? ''}', size: 20)),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('${w['hub']}', style: pw.TextStyle(font: bold, fontSize: 9)),
                pw.Text('${w['area']}', style: pw.TextStyle(font: bold, fontSize: 9)),
              ]),
            ])),
            box(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              label('Deliver to'),
              pw.Row(children: [strong('${w['receiver'] ?? '—'} '), pw.Text('${w['receiver_phone'] ?? ''}', style: const pw.TextStyle(fontSize: 9))]),
              pw.Text('${w['dropoff_address'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
            ])),
            box(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              label('From'),
              pw.Row(children: [strong('${w['sender'] ?? ''} ', size: 9), pw.Text('${w['sender_phone'] ?? ''}', style: const pw.TextStyle(fontSize: 8))]),
              pw.Text('${w['pickup_address'] ?? ''}', style: const pw.TextStyle(fontSize: 8)),
            ])),
            box(pw.Row(children: [
              pw.Expanded(child: label(cod != null ? 'Collect from buyer (COD)' : 'Payment')),
              strong(cod != null ? '₱${_money.format(cod is num ? cod : num.tryParse('$cod') ?? 0)}' : 'PAID — collect ₱0', size: 13),
            ])),
            box(pw.Wrap(spacing: 14, runSpacing: 3, children: [
              for (final (l, v) in [
                ('Order', '${w['order_number'] ?? '—'}'),
                ('Weight', _kg(w['weight_kg'])),
                ('Items', asInt(w['item_count']) > 0 ? '${w['item_count']}' : '—'),
                ('Ship date', w['ship_date'] != null ? formatDate(w['ship_date']) : '—'),
                ('Tracking', '${w['tracking'] ?? ''}'),
              ])
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [label(l), strong(v, size: 8.5)]),
            ])),
            pw.Expanded(
              child: box(last: true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                label('Contents'),
                if (items.isEmpty) pw.Text('${(w['notes'] ?? '').toString().isEmpty ? 'Parcel' : w['notes']}', style: const pw.TextStyle(fontSize: 8.5)),
                for (final i in items.take(4))
                  pw.Row(children: [
                    pw.Expanded(child: pw.Text('${i['title']}${i['variation'] != null ? ' (${i['variation']})' : ''}', maxLines: 1, style: const pw.TextStyle(fontSize: 8.5))),
                    pw.Text('× ${i['quantity']}', style: const pw.TextStyle(fontSize: 8.5)),
                  ]),
                if (items.length > 4) pw.Text('+ ${items.length - 4} more item(s)', style: const pw.TextStyle(fontSize: 8.5)),
              ])),
            ),
          ]),
        ),
      ));
    }
    return doc.save();
  }
}

/// Print (or share) the waybills of [ids] — one parcel, or "Print all" on a list.
Future<void> openWaybills(BuildContext context, List<int> ids) async {
  if (ids.isEmpty) return showError(context, 'No parcels to print.');
  final r = await LogisticsApi.waybills(ids);
  if (!context.mounted) return;
  if (!r.ok) return showError(context, r.message);
  final labels = asList(r.body['waybills']);
  Navigator.push(context, MaterialPageRoute(builder: (_) => _WaybillPreview(labels)));
}

class _WaybillPreview extends StatelessWidget {
  final List<Map<String, dynamic>> labels;
  const _WaybillPreview(this.labels);

  String get _name => labels.length == 1 ? 'Waybill-${labels.first['waybill']}' : 'Waybills-${labels.length}';

  @override
  Widget build(BuildContext context) {
    final pdf = HubWaybillPdf.build(labels);
    return Scaffold(
      appBar: sellerBar(labels.length == 1 ? 'Waybill · 4 × 6 in label' : '${labels.length} waybills · 4 × 6 in label'),
      body: PdfPreview(build: (_) => pdf, useActions: false, pdfFileName: '$_name.pdf'),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async => Printing.sharePdf(bytes: await pdf, filename: '$_name.pdf'),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share / Save PDF'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BusyButton('Print', busy: false, icon: Icons.print_outlined,
                  onPressed: () async => Printing.layoutPdf(onLayout: (_) => pdf, name: _name)),
            ),
          ]),
        ),
      ),
    );
  }
}
