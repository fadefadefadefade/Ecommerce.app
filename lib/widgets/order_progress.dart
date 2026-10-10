import 'package:flutter/material.dart';
import '../theme/buyer_colors.dart';

// Order progress (Pending → Processing → Shipped to Warehouse → Delivering →
// Delivered), shared by the buyer's and the seller's order screens. The API
// sends the current step as `stage` (plus `stage_label`).

/// Progress steps (API `stage` keys), in order.
const orderStages = <String, String>{
  'pending': 'Pending',
  'processing': 'Processing',
  'warehouse': 'Shipped to Warehouse',
  'delivering': 'Delivering',
  'delivered': 'Delivered',
};

Color stageColor(String stage) {
  switch (stage) {
    case 'processing':
      return const Color(0xFF6A1B9A);
    case 'warehouse':
      return const Color(0xFF1565C0);
    case 'delivering':
      return const Color(0xFF00838F);
    case 'delivered':
      return const Color(0xFF2E7D32);
    case 'cancelled':
      return const Color(0xFFC62828);
    default:
      return const Color(0xFFEF6C00);
  }
}

IconData stageIcon(String stage) {
  switch (stage) {
    case 'processing':
      return Icons.inventory_2_outlined;
    case 'warehouse':
      return Icons.warehouse_outlined;
    case 'delivering':
      return Icons.local_shipping_outlined;
    case 'delivered':
      return Icons.check_circle_outline;
    case 'cancelled':
      return Icons.cancel_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

String stageText(String stage, [String? label]) =>
    label ?? orderStages[stage] ?? (stage == 'cancelled' ? 'Cancelled' : stage);

/// Badge for an order's progress step.
class StageBadge extends StatelessWidget {
  final String stage;
  final String? label;
  const StageBadge(this.stage, {super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final color = stageColor(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        stageText(stage, label),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Compact 5-segment progress bar for order cards.
class OrderProgressBar extends StatelessWidget {
  final String stage;
  const OrderProgressBar({super.key, required this.stage});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final keys = orderStages.keys.toList();
    final current = keys.indexOf(stage);
    final cancelled = stage == 'cancelled';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < keys.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: cancelled
                        ? stageColor('cancelled').withValues(alpha: 0.25)
                        : i <= current
                            ? stageColor(keys[current])
                            : c.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(stageIcon(stage), size: 14, color: stageColor(stage)),
            const SizedBox(width: 4),
            Text(
              cancelled ? 'Cancelled' : '${current + 1}/${keys.length} · ${stageText(stage)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stageColor(stage)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vertical tracker: a dot per step with connecting lines; the current step
/// shows its [hints] text. Not shown for cancelled orders.
class OrderProgressTimeline extends StatelessWidget {
  final String stage;
  final Map<String, String> hints;

  const OrderProgressTimeline({super.key, required this.stage, this.hints = const {}});

  @override
  Widget build(BuildContext context) {
    final keys = orderStages.keys.toList();
    final current = keys.indexOf(stage);
    return Column(
      children: [for (var i = 0; i < keys.length; i++) _step(context, keys, i, current)],
    );
  }

  Widget _step(BuildContext context, List<String> keys, int index, int current) {
    final c = context.bc;
    final key = keys[index];
    final last = index == keys.length - 1;
    final done = index <= current;
    final isCurrent = index == current;
    final color = done ? stageColor(key) : c.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: done ? color : c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    index < current ? Icons.check : stageIcon(key),
                    size: 16,
                    color: done ? Colors.white : c.muted,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: index < current ? stageColor(keys[index + 1]) : c.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 5, bottom: last ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderStages[key]!,
                    style: TextStyle(
                      color: done ? c.text : c.muted,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  if (isCurrent && (hints[key] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(hints[key]!, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
