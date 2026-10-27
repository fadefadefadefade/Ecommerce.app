import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/buyer_colors.dart';
import 'buyer_kit.dart';

/// The website's Shipment tracking card (shipment/_tracking): tracking and waybill numbers, where the parcel is,
/// the 5-step progress, the hubs on its route, every recorded update (newest first) and the steps still to come.
class ShipmentTrackingCard extends StatefulWidget {
  final Map<String, dynamic> tracking;
  const ShipmentTrackingCard(this.tracking, {super.key});
  @override
  State<ShipmentTrackingCard> createState() => _ShipmentTrackingCardState();
}

class _ShipmentTrackingCardState extends State<ShipmentTrackingCard> {
  static const _shown = 5;
  bool _older = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tracking;
    final c = context.bc;
    final delivered = t['delivered'] == true;
    final trouble = t['trouble'] == true;
    final reached = asNum(t['reached']).toInt();
    final milestones = (t['milestones'] as List? ?? const []).map((e) => '$e').toList();
    final events = (t['events'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final hubs = (t['hubs'] as List? ?? const []).map((e) => '$e').toList();
    final expected = (t['expected'] as List? ?? const []).map((e) => '$e').toList();
    final visible = _older ? events : events.take(_shown).toList();
    final pillBg = delivered ? const Color(0xFFECFDF5) : (trouble ? const Color(0xFFFEF2F2) : const Color(0xFFFFF1EE));
    final pillFg = delivered ? const Color(0xFF047857) : (trouble ? const Color(0xFFB91C1C) : const Color(0xFFD93D0E));

    return SectionCard(
      title: 'Shipment tracking',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (t['tracking_number'] != null)
                Row(children: [
                  Flexible(child: Text('Tracking no. ${t['tracking_number']}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600))),
                  TextButton(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 28)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '${t['tracking_number']}'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tracking number copied.')));
                    },
                    child: const Text('Copy', style: TextStyle(color: kOrange, fontSize: 12)),
                  ),
                ]),
              if (t['waybill_number'] != null) Text('Waybill ${t['waybill_number']}', style: TextStyle(fontSize: 12, color: c.muted, fontFamily: 'monospace')),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(20)),
            child: Text('${t['status']}', style: TextStyle(color: pillFg, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ]),
        if (t['location'] != null && '${t['location']}' != '—')
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('Now: ${t['location']}', style: TextStyle(fontSize: 12.5, color: c.textSecondary))),
        if (t['under_review'] == true)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Our team is checking an issue with this shipment.', style: TextStyle(fontSize: 12, color: Color(0xFFB45309))),
          ),
        const SizedBox(height: 12),
        // Progress (0 ordered … 4 delivered)
        Row(children: [
          for (var i = 0; i < milestones.length; i++)
            Expanded(
              child: Column(children: [
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= reached ? (trouble && i == reached ? const Color(0xFFDC2626) : kOrange) : const Color(0xFFE6EDF2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(milestones[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: i <= reached ? c.text : c.muted, fontWeight: i == reached ? FontWeight.w700 : FontWeight.normal)),
              ]),
            ),
        ]),
        if (hubs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Route: ${['Seller', ...hubs, 'You'].join(' → ')}', style: TextStyle(fontSize: 12, color: c.muted)),
        ],
        const SizedBox(height: 12),
        if (events.isEmpty) Text('No updates yet.', style: TextStyle(color: c.muted)),
        for (var i = 0; i < visible.length; i++) _event(visible[i], latest: i == 0, line: i < visible.length - 1 || expected.isNotEmpty),
        if (events.length > _shown)
          TextButton(
            onPressed: () => setState(() => _older = !_older),
            child: Text(_older ? 'Show fewer updates' : 'Show ${events.length - _shown} older update(s)', style: const TextStyle(color: kOrange)),
          ),
        for (final step in expected)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE6EDF2), width: 2))),
              const SizedBox(width: 10),
              Text('$step (expected)', style: TextStyle(fontSize: 13, color: c.muted)),
            ]),
          ),
      ]),
    );
  }

  Widget _event(Map<String, dynamic> e, {required bool latest, required bool line}) {
    final c = context.bc;
    final warn = e['warning'] == true;
    final color = warn ? const Color(0xFFDC2626) : (latest ? (e['type'] == 'delivered' ? const Color(0xFF059669) : kOrange) : const Color(0xFFE6EDF2));
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(margin: const EdgeInsets.only(top: 4), width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          if (line) Expanded(child: Container(width: 1, color: const Color(0xFFE6EDF2))),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: '${e['label']}', style: TextStyle(fontWeight: latest ? FontWeight.w700 : FontWeight.w500, color: latest ? c.text : c.textSecondary)),
                if (latest) const TextSpan(text: '  Latest', style: TextStyle(fontSize: 10, color: kOrange, fontWeight: FontWeight.w700)),
              ])),
              if (e['note'] != null && '${e['note']}'.isNotEmpty) Text('${e['note']}', style: TextStyle(fontSize: 12, color: c.muted)),
              Text(formatDateTime(e['at']), style: TextStyle(fontSize: 11.5, color: c.muted)),
            ]),
          ),
        ),
      ]),
    );
  }
}
