import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/buyer_kit.dart' show cardBox;
export '../../../widgets/order_progress.dart';

// Small shared pieces for the buyer account screens (orders, security, etc.).

double toNum(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

String peso(dynamic v) => '₱${NumberFormat('#,##0.00').format(toNum(v))}';

DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String formatDate(dynamic v) {
  final d = parseDate(v);
  return d == null ? '—' : DateFormat('MMM d, y · h:mm a').format(d);
}

String timeAgo(dynamic v) {
  final d = parseDate(v);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d, y').format(d);
}

Color orderStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'delivered':
    case 'completed':
      return const Color(0xFF15803D);
    case 'shipped':
    case 'in_transit':
    case 'out_for_delivery':
      return Alvy.slate;
    case 'processing':
      return Alvy.orangeDark;
    case 'cancelled':
    case 'failed':
    case 'returned':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFFB45309);
  }
}

class OrderStatusBadge extends StatelessWidget {
  final String status;
  const OrderStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    final label = status.isEmpty ? '—' : status[0].toUpperCase() + status.substring(1).replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// White (or dark) rounded card with an optional title.
class AccountCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AccountCard({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Container(
      width: double.infinity,
      decoration: cardBox(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(title!, style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700, color: c.text)),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

PreferredSizeWidget accountAppBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) {
  return AppBar(
    title: Text(title),
    actions: actions,
    bottom: bottom,
  );
}

class AccountEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const AccountEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: Alvy.orange),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

void showAccountSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF059669),
    ));
}

String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

/// The design's settings row: an icon in a soft square, a title and a muted line, then a trailing widget.
class AccountRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool navy;

  const AccountRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.navy = false});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: navy ? Alvy.slateSoft : Alvy.orangeSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 21, color: navy ? Alvy.slate : Alvy.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
            ]),
          ),
          trailing ?? (onTap != null ? Icon(Icons.chevron_right, color: c.muted) : const SizedBox()),
        ]),
      ),
    );
  }
}
