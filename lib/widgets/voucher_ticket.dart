import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/buyer_colors.dart';

/// The website's voucher ticket (components/voucher-ticket): a coloured stub with FREE SHIPPING / 10% OFF / ₱50 OFF,
/// the headline, min. spend, where it works, when it ends (red in the last 3 days), how much is used up, and — at
/// checkout — why it can't be used (greyed) or what it saves on this order.
/// [v] is ApiJson::voucher or a checkout option; [trailing] is the Claim button / Claimed / Used / a radio.
class VoucherTicket extends StatelessWidget {
  final Map v;
  final Widget? trailing;
  final bool muted;
  final String? kind;
  final String? where;
  final String? reason;
  final num? saving;
  const VoucherTicket(this.v, {super.key, this.trailing, this.muted = false, this.kind, this.where, this.reason, this.saving});

  static final _whole = NumberFormat('#,##0', 'en_US');
  static final _cents = NumberFormat('#,##0.00', 'en_US');

  static String _num(dynamic n) {
    final d = n is num ? n.toDouble() : double.tryParse('$n') ?? 0;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  static num _n(dynamic n) => n is num ? n : num.tryParse('${n ?? ''}') ?? 0;

  static String _peso(dynamic n) => '₱${_whole.format(_n(n))}';

  /// ISO from most pages; "Nov 05, 2026 6:00 PM" from the checkout's voucher options.
  static DateTime? _date(dynamic s) {
    final t = '${s ?? ''}'.trim();
    if (t.isEmpty) return null;
    final iso = DateTime.tryParse(t);
    if (iso != null) return iso.toLocal();
    try {
      return DateFormat('MMM dd, y h:mm a', 'en_US').parseLoose(t);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final k = kind ?? '${v['scope'] ?? 'platform'}';
    final ship = k == 'shipping';
    final percent = v['type'] == 'percent';
    final value = _n(v['value']);
    final (big, small) = ship ? ('FREE', 'SHIPPING') : (percent ? ('${_num(value)}%', 'OFF') : (_peso(value), 'OFF'));
    final headline = ship
        ? 'Free shipping${value > 0 ? ' up to ${_peso(value)}' : ''}'
        : percent
            ? '${_num(value)}% off${v['max'] != null ? ' · capped at ${_peso(v['max'])}' : ''}'
            : '${_peso(value)} off';
    final tone = switch (k) {
      'shipping' => const Color(0xFF0F9F8A),
      'seller' => const Color(0xFFFA4E1C),
      _ => const Color(0xFFE0431A),
    };
    final end = _date(v['ends_at']);
    final now = DateTime.now();
    final urgent = end != null && end.isAfter(now) && end.difference(now).inHours < 72;
    final endText = end == null
        ? 'No expiry'
        : end.isBefore(now)
            ? 'Expired'
            : urgent
                ? 'Ends in ${end.difference(now).inHours >= 24 ? '${end.difference(now).inDays} day(s)' : '${end.difference(now).inHours} hour(s)'}'
                : 'Valid till ${DateFormat('MMM d, y').format(end)}';
    final minSpend = _n(v['min_spend']);
    final usedPct = v['used_pct'] is num ? (v['used_pct'] as num).toInt() : null;
    final why = reason ?? (v['reason'] is String ? v['reason'] as String : null);
    final grey = muted || (why != null && why.isNotEmpty);
    final place = where ?? (v['where'] as String?);
    final name = (v['name'] ?? '').toString();

    return Opacity(
      opacity: grey ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 92,
              color: grey ? const Color(0xFF6B90AA) : tone,
              padding: const EdgeInsets.all(8),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (ship) const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 20),
                Text(big, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: ship ? 17 : 22, height: 1)),
                const SizedBox(height: 2),
                Text(small, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.8)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(headline, style: TextStyle(fontWeight: FontWeight.w800, color: grey ? c.muted : c.text)),
                  Text([minSpend > 0 ? 'Min. spend ${_peso(minSpend)}' : 'No min. spend', if (place != null) place].join(' · '),
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
                  if (name.isNotEmpty && name != headline) Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.muted)),
                  Text(endText, style: TextStyle(fontSize: 11.5, color: urgent ? const Color(0xFFDC2626) : c.muted, fontWeight: urgent ? FontWeight.w600 : FontWeight.normal)),
                  if (usedPct != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: usedPct.clamp(4, 100) / 100, minHeight: 4, backgroundColor: c.border, color: tone),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('$usedPct% used', style: TextStyle(fontSize: 10.5, color: c.muted)),
                    ]),
                  ],
                  if (why != null && why.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('${why[0].toUpperCase()}${why.substring(1).replaceFirst(RegExp(r'\.+$'), '')}.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
                    )
                  else if (saving != null && saving! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('Saves ₱${_cents.format(saving)} on this order',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                    ),
                ]),
              ),
            ),
            if (trailing != null) Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: trailing)),
          ]),
        ),
      ),
    );
  }
}
