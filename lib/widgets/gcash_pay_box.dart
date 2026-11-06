import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'buyer_kit.dart';
import 'net_image.dart';

/// GCash paid to ALVY, as on the website: ALVY's QR, the exact amount to send (its centavos mark the payment),
/// the receipt screenshot and its 13-number Ref No. Used at checkout and to upload the right receipt after a
/// rejection (order page).
class GcashPayBox extends StatelessWidget {
  final Map<String, dynamic> account; // qr_url, name, number
  final num? amount;
  final num? ordersTotal; // the orders' total, when the amount is a few centavos less
  final String? receipt; // local path of the chosen screenshot
  final ValueChanged<String> onReceipt;
  final TextEditingController reference;
  final String? referenceError;
  final int stores;

  const GcashPayBox({
    super.key,
    required this.account,
    required this.amount,
    required this.receipt,
    required this.onReceipt,
    required this.reference,
    this.ordersTotal,
    this.referenceError,
    this.stores = 1,
  });

  static const blue = Color(0xFF0B2A5B);

  Future<void> _pick(BuildContext context) async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
      if (x != null) onReceipt(x.path);
    } on PlatformException {
      if (context.mounted) showError(context, 'Photo access is off for ALVY. Allow it in Settings › Apps › ALVY › Permissions.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = '${account['qr_url'] ?? ''}';
    final number = '${account['number'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF5F9FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 24, height: 24, alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF007DFE), borderRadius: BorderRadius.circular(6)),
            child: const Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          const Text('Pay ALVY with GCash', style: TextStyle(fontWeight: FontWeight.w800, color: blue)),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (qr.isNotEmpty)
            GestureDetector(
              onTap: () => showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: NetImage(qr, fit: BoxFit.contain)))),
              child: Container(
                width: 120, height: 120, padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBFDBFE))),
                child: NetImage(qr, fit: BoxFit.contain),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Scan the QR in your GCash app and send exactly', style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
              Text(amount == null ? '—' : peso(amount!), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: blue)),
              SelectableText('to ${account['name'] ?? 'ALVY'}${number.isNotEmpty ? ' · $number' : ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF3B5B8C))),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          'Send this exact amount, centavos included: they mark your payment so ALVY finds it fast.'
          '${ordersTotal != null && amount != null && ordersTotal! > amount! ? ' ALVY covers the centavos below your total (${peso(ordersTotal!)}).' : ''}'
          '${stores > 1 ? ' One payment for all $stores stores, shipping included.' : ''}',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF3B5B8C)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _pick(context),
          icon: Icon(receipt == null ? Icons.upload_file : Icons.check_circle, color: receipt == null ? kOrange : const Color(0xFF15803D)),
          label: Text(receipt == null ? 'Attach the GCash receipt screenshot *' : 'Receipt attached · change'),
        ),
        if (receipt != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(receipt!), height: 140, fit: BoxFit.contain)),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: reference,
          keyboardType: TextInputType.number,
          // Numbers only: letters and spaces never get in.
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: 'GCash Ref No. *', isDense: true, border: const OutlineInputBorder(), counterText: '',
            hintText: '13 numbers, e.g. 1012345678901', errorText: referenceError,
            helperText: 'The 13 numbers of the "Ref No." on your receipt',
          ),
        ),
      ]),
    );
  }

  /// The checks the server makes too, so the buyer hears about them before sending.
  static String? problem(String? receipt, String reference) {
    if (receipt == null) return 'Attach the screenshot of your GCash receipt.';
    if (reference.length != 13) return 'The GCash Ref No. has 13 numbers. Copy it from your receipt.';
    return null;
  }
}
