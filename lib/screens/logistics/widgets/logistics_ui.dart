import 'package:flutter/material.dart';
import '../../../widgets/reason_dialog.dart';
import 'package:intl/intl.dart';
import '../../../models/logistics.dart';

class LogisticsColors {
  static const primary = Color(0xFFfa4e1c);
  static const background = Color(0xFFFBEEE8);
  static const text = Color(0xFF222222);
  static const muted = Color(0xFF8a7a70);
  static const line = Color(0xFFE6D9CF);
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const warning = Color(0xFFEF6C00);
  static const info = Color(0xFF1565C0);
}

String formatDate(DateTime? d) => d == null ? '—' : DateFormat('MMM d, y').format(d);
String formatDateTime(DateTime? d) => d == null ? '—' : DateFormat('MMM d, y h:mm a').format(d);

String timeAgo(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDate(d);
}

String humanize(String value) {
  if (value.isEmpty) return value;
  final s = value.replaceAll('_', ' ');
  return s[0].toUpperCase() + s.substring(1);
}

Color statusColor(String status) {
  switch (status) {
    case 'approved':
    case 'active':
    case 'delivered':
      return LogisticsColors.success;
    case 'rejected':
    case 'inactive':
    case 'failed':
    case 'returned':
    case 'pickup_rejected':
    case 'cancelled':
      return LogisticsColors.danger;
    case 'pending':
    case 'pending_pickup':
    case 'assigned':
      return LogisticsColors.warning;
    default:
      return LogisticsColors.info;
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const StatusBadge({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label ?? humanize(status),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = LogisticsColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: LogisticsColors.text,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: LogisticsColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LogisticsColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: LogisticsColors.text,
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const InfoRow({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: LogisticsColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              (value == null || value!.isEmpty) ? '—' : value!,
              style: const TextStyle(color: LogisticsColors.text, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 56, color: LogisticsColors.muted.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: LogisticsColors.muted)),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 56, color: LogisticsColors.danger),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: LogisticsColors.muted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: LogisticsColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class LogisticsSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;

  const LogisticsSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            controller.clear();
            onSubmitted('');
          },
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LogisticsColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LogisticsColors.line),
        ),
      ),
    );
  }
}

/// Horizontal row of choice chips used for status filters.
class FilterChips extends StatelessWidget {
  final Map<String, String> options; // value -> label ('' = all)
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: options.entries.map((e) {
          final isSelected = e.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.value),
              selected: isSelected,
              onSelected: (_) => onSelected(e.key),
              selectedColor: LogisticsColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : LogisticsColors.text,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              showCheckmark: false,
              side: const BorderSide(color: LogisticsColors.line),
            ),
          );
        }).toList(),
      ),
    );
  }
}

PreferredSizeWidget logisticsAppBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) {
  return AppBar(
    backgroundColor: LogisticsColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    actions: actions,
    bottom: bottom,
  );
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? LogisticsColors.danger : LogisticsColors.success,
    ));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? LogisticsColors.danger : LogisticsColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Confirmation dialog with an optional reason field. Returns null when cancelled.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String hint,
  String confirmLabel = 'Submit',
}) {
  // Reason is optional here; the dialog owns (and safely disposes) its controller.
  return showReasonDialog(
    context,
    title: title,
    hint: hint,
    confirmLabel: confirmLabel,
    confirmColor: LogisticsColors.danger,
    required: false,
  );
}

/// Infinite-scroll list over a paginated endpoint with pull-to-refresh.
/// Give it a new [key] whenever filters change to restart from page 1.
class PagedList<T> extends StatefulWidget {
  final Future<PagedResult<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item, VoidCallback reload) itemBuilder;
  final String emptyMessage;
  final Widget? header;

  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.emptyMessage = 'Nothing here yet.',
    this.header,
  });

  @override
  State<PagedList<T>> createState() => PagedListState<T>();
}

class PagedListState<T> extends State<PagedList<T>> {
  final _scroll = ScrollController();
  final List<T> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final result = await widget.fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.currentPage;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (widget.header != null) widget.header!,
    ];

    if (_error != null && _items.isEmpty) {
      children.add(ErrorState(message: _error!, onRetry: reload));
    } else if (_items.isEmpty && !_loading) {
      children.add(EmptyState(message: widget.emptyMessage));
    } else {
      for (final item in _items) {
        children.add(widget.itemBuilder(context, item, reload));
      }
    }

    if (_loading) {
      children.add(const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: LogisticsColors.primary)),
      ));
    }

    return RefreshIndicator(
      color: LogisticsColors.primary,
      onRefresh: reload,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: children,
      ),
    );
  }
}

/// White card used for list rows.
class ListCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const ListCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LogisticsColors.line),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class TrackingText extends StatelessWidget {
  final String text;
  const TrackingText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: LogisticsColors.text,
      ),
    );
  }
}
