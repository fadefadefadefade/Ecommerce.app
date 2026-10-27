import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The web's printable waybill (seller.orders.waybill) as a PDF: tracking no. with a barcode, order, weight,
/// payment, buyer, seller pickup address, contents and the COD amount.
class WaybillPdf {
  static final _money = NumberFormat('#,##0.00', 'en_US');

  static String _peso(dynamic v) => '₱${_money.format(v is num ? v : num.tryParse('$v') ?? 0)}';

  static String _kg(dynamic v) {
    final n = v is num ? v : num.tryParse('${v ?? 0}') ?? 0;
    return '${n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')} kg';
  }

  /// [w] is the `waybill` object from GET /seller/orders/{id}/waybill.
  static Future<Uint8List> build(Map<String, dynamic> w) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    final seller = Map<String, dynamic>.from(w['seller'] as Map? ?? {});
    final buyer = Map<String, dynamic>.from(w['buyer'] as Map? ?? {});
    final items = [for (final i in (w['items'] as List? ?? [])) Map<String, dynamic>.from(i as Map)];

    pw.Widget label(String t) => pw.Text(t.toUpperCase(), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700, letterSpacing: 0.5));
    pw.Widget strong(String t, {double size = 11}) => pw.Text(t, style: pw.TextStyle(font: bold, fontSize: size));
    pw.Widget row(List<pw.Widget> children, {bool last = false}) => pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: last ? null : const pw.Border(bottom: pw.BorderSide(width: 1.5))),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
        );

    final doc = pw.Document(title: 'Waybill ${w['tracking'] ?? ''}', author: 'ALVY');
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a6.copyWith(marginLeft: 14, marginRight: 14, marginTop: 14, marginBottom: 14),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (_) => pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          row([
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                label('ALVY waybill · tracking no.'),
                strong('${w['tracking'] ?? ''}', size: 15),
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: '${w['tracking'] ?? ''}', height: 34, drawText: false),
              ]),
            ),
            pw.SizedBox(width: 10),
            pw.SizedBox(
              width: 90,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                label('Order'),
                strong('${w['order_number'] ?? ''}'),
                pw.SizedBox(height: 4),
                label('Weight'),
                strong(_kg(w['weight_kg'])),
                pw.SizedBox(height: 4),
                label('Payment'),
                strong('${w['payment_method'] ?? ''}'),
              ]),
            ),
          ]),
          row([
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                label('Deliver to (buyer)'),
                strong('${buyer['name'] ?? ''}'),
                pw.Text('${buyer['phone'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('${buyer['address'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
              ]),
            ),
          ]),
          row([
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                label('Pick up from (seller)'),
                strong('${seller['name'] ?? ''}'),
                pw.Text('${seller['phone'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('${seller['address'] ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
              ]),
            ),
          ]),
          row([
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                label('Contents'),
                for (final i in items)
                  pw.Row(children: [
                    pw.Expanded(
                      child: pw.Text('${i['title']}${i['variation'] != null ? ' (${i['variation']})' : ''}', style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Text('× ${i['quantity']}', style: const pw.TextStyle(fontSize: 10)),
                  ]),
              ]),
            ),
          ]),
          row(last: true, [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                label('Collect on delivery (COD)'),
                strong(w['cod'] != null ? _peso(w['cod']) : '₱0.00 — already paid', size: 16),
              ]),
            ),
            if ((w['buyer_note'] ?? '').toString().isNotEmpty)
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  label('Buyer note'),
                  pw.Text('${w['buyer_note']}', style: const pw.TextStyle(fontSize: 10)),
                ]),
              ),
          ]),
        ]),
      ),
    ));
    return doc.save();
  }
}
