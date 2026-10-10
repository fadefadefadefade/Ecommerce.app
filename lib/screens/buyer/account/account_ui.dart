import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/buyer_colors.dart';
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
      return const Color(0xFF2E7D32);
    case 'shipped':
    case 'in_transit':
    case 'out_for_delivery':
      return const Color(0xFF1565C0);
    case 'processing':
      return const Color(0xFF6A1B9A);
    case 'cancelled':
    case 'failed':
    case 'returned':
      return const Color(0xFFC62828);
    default:
      return const Color(0xFFEF6C00);
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
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(title!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
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
    backgroundColor: BuyerPalette.primary,
    foregroundColor: Colors.white,
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
            Icon(icon, size: 64, color: c.muted),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.text)),
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
      backgroundColor: error ? const Color(0xFFC62828) : const Color(0xFF059669),
    ));
}

String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');
