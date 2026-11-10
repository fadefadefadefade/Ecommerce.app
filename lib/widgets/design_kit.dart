import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/buyer_colors.dart';
import 'buyer_kit.dart' show cardBox;

// Pieces from the mobile design shared by the rider, linehaul and seller screens:
// the orange hero card, the segmented period switch, small figure cards, status tags.

/// The design's small status tag ("LIVE ROUTE ACTIVE"): a dot and caps on a soft orange pill.
Widget riderTag(String text, {bool live = true}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: live ? Alvy.orangeSoft : Alvy.slateSoft, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: live ? Alvy.orange : Alvy.slate),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: live ? Alvy.orangeDark : Alvy.slate)),
      ]),
    );

/// A small navy chip (the design's "Pre-Cleared", "Apt 4B").
Widget riderChip(String text, {bool soft = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: soft ? Alvy.slateSoft : Alvy.orangeSoft, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: soft ? Alvy.slate : Alvy.orangeDark)),
    );

String riderInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
}

/// The design's segmented period switch: a beige track with the chosen one on white.
Widget riderSegments(BuildContext context, Map<String, dynamic> options, String value, ValueChanged<String> onPick) {
  final c = context.bc;
  return Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      for (final e in options.entries)
        Expanded(
          child: GestureDetector(
            onTap: () => onPick(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: value == e.key ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: value == e.key ? const [BoxShadow(color: Color(0x142A1A10), blurRadius: 6, offset: Offset(0, 1))] : null,
              ),
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${e.value}', maxLines: 1,
                    style: TextStyle(fontWeight: value == e.key ? FontWeight.w700 : FontWeight.w500, color: value == e.key ? Alvy.orange : c.textSecondary)),
              ),
            ),
          ),
        ),
    ]),
  );
}

/// The design's orange hero card: a caps label, the big amount, and up to two figures in a darker box.
Widget riderHero(String label, String amount, List<(String, String)> parts, {IconData icon = Icons.payments_outlined, String? badge}) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Alvy.orange, Alvy.orangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: Alvy.buttonShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                Text(amount, style: Alvy.display(size: 30, color: Colors.white, weight: FontWeight.w800)),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                    child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Alvy.orangeDark)),
                  ),
              ]),
            ]),
          ),
          CircleAvatar(radius: 20, backgroundColor: Colors.white.withValues(alpha: 0.2), child: Icon(icon, color: Colors.white, size: 20)),
        ]),
        if (parts.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (l, v) in parts)
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    Text(v, style: Alvy.display(size: 16, color: Colors.white, weight: FontWeight.w800)),
                  ]),
                ),
            ]),
          ),
        ],
      ]),
    );

/// A small white figure card (the design's "Trips Today 12").
Widget riderFigure(BuildContext context, String label, String value, IconData icon, {String? hint}) {
  final c = context.bc;
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBox(context, radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600))),
          Icon(icon, size: 18, color: Alvy.slate),
        ]),
        const SizedBox(height: 6),
        Text(value, style: Alvy.display(size: 20, color: c.text, weight: FontWeight.w800)),
        if (hint != null) Text(hint, style: const TextStyle(fontSize: 11.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
