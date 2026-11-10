import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../theme/buyer_colors.dart';

const kOrange = Color(0xFFFA4E1C);

/// Philippine mobile numbers are 11 digits (09XXXXXXXXX), as on the website.
const kPhoneLength = 11;
final phoneFormatters = <TextInputFormatter>[_PhMobileFormatter()];

/// Digits only (a "+" only in front): 11 digits for 09XXXXXXXXX, 13 characters for +639XXXXXXXXX.
class _PhMobileFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    final plus = raw.startsWith('+');
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    digits = digits.substring(0, digits.length > (plus ? 12 : kPhoneLength) ? (plus ? 12 : kPhoneLength) : digits.length);
    final text = plus ? '+$digits' : digits;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// A number saved as +639XXXXXXXXX, shown the 11-digit way (09XXXXXXXXX).
String localPhone(dynamic v) => '${v ?? ''}'.replaceFirstMapped(RegExp(r'^\+?63(9\d{9})$'), (m) => '0${m[1]}');

double asNum(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// A JSON object as a map. PHP sends an empty associative array as [] instead of {}, so a list
/// (or null) here means "empty".
Map<String, dynamic> asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

final _peso = NumberFormat('#,##0.00', 'en_US');
final _pesoWhole = NumberFormat('#,##0', 'en_US');

/// ₱1,234.50 (as on the website).
String peso(dynamic v) => '₱${_peso.format(asNum(v))}';
String pesoWhole(dynamic v) => '₱${_pesoWhole.format(asNum(v))}';

String formatDate(String? iso, [String pattern = 'MMM d, yyyy']) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return d == null ? '' : DateFormat(pattern).format(d);
}

String formatDateTime(String? iso) => formatDate(iso, 'MMM d, yyyy · h:mm a');

/// Shows the website's message for an action: green for success, red for an error.
void showResult(BuildContext context, ApiResponse r, {String? success}) {
  final text = r.ok ? (success ?? r.body['message'] as String? ?? '') : r.message;
  if (text.isEmpty || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    backgroundColor: r.ok ? (r.body['warning'] == true ? const Color(0xFFB45309) : const Color(0xFF15803D)) : const Color(0xFFDC2626),
  ));
}

void showError(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_outline, color: Colors.white, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message)),
    ]),
    backgroundColor: const Color(0xFFDC2626),
  ));
}

/// "Remove …?" before taking something out of the cart or the wishlist. True when the buyer confirms.
Future<bool> confirmRemoval(BuildContext context, {required String title, required String message}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 30),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// A loading / error / content switch used by the buyer screens.
class LoadState extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget child;

  const LoadState({super.key, required this.loading, required this.error, required this.onRetry, required this.child});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: kOrange));
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, size: 34, color: kOrange),
            ),
            const SizedBox(height: 14),
            Text(error!, textAlign: TextAlign.center, style: TextStyle(color: context.bc.textSecondary, height: 1.45)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Try again')),
          ]),
        ),
      );
    }
    return child;
  }
}

/// The design's card: white, 16 rounded, a soft warm shadow (a hairline in dark mode, where shadows don't show).
BoxDecoration cardBox(BuildContext context, {double radius = 16, Color? color}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: color ?? context.bc.surface,
    borderRadius: BorderRadius.circular(radius),
    border: dark ? Border.all(color: context.bc.border) : null,
    boxShadow: dark ? null : const [BoxShadow(color: Color(0x0F2A1A10), blurRadius: 14, offset: Offset(0, 3))],
  );
}

/// A section heading: a bold title with a short orange bar under it, and an optional link on the right.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? badge;
  final EdgeInsetsGeometry padding;
  const SectionTitle(this.title, {super.key, this.action, this.onAction, this.badge, this.padding = const EdgeInsets.fromLTRB(16, 24, 12, 12)});

  @override
  Widget build(BuildContext context) {
    final action = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: padding,
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w700, color: context.bc.text, letterSpacing: -0.2)),
          const SizedBox(height: 4),
          Container(width: 32, height: 3, decoration: BoxDecoration(color: action, borderRadius: BorderRadius.circular(2))),
        ]),
        if (badge != null) ...[const SizedBox(width: 10), badge!],
        const Spacer(),
        if (this.action != null && onAction != null)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(this.action!, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: action)),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward, size: 16, color: action),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Section card in the design's style: a white rounded card, an optional title row.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const SectionCard({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(16), this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardBox(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
            child: Row(children: [
              Expanded(child: Text(title!, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: context.bc.text))),
              if (trailing != null) trailing!,
            ]),
          ),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

/// A filter pill (the design's tabs: "All Dispatches (4)", "Pickups (2)"…): solid orange when chosen, beige otherwise.
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const FilterPill(this.label, {super.key, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final action = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? action : context.bc.subtle,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(label,
              style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: selected ? Colors.white : context.bc.text)),
        ),
      ),
    );
  }
}

/// Star row (1–5).
class Stars extends StatelessWidget {
  final double rating;
  final double size;
  const Stars(this.rating, {super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(i <= rating.round() ? Icons.star : Icons.star_border, size: size, color: const Color(0xFFF59E0B)),
    ]);
  }
}

/// Quantity: − [number] +. The number can be typed (large orders); it is kept between 1 and [max]
/// (stock and the buyer's limit) and reported when typing ends (done / leaving the box), so a cart line
/// isn't saved on every key.
class QuantityStepper extends StatefulWidget {
  final int value;
  final int max;
  final ValueChanged<int>? onChanged;   // null: disabled
  final double height;
  const QuantityStepper({super.key, required this.value, required this.max, required this.onChanged, this.height = 38});

  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  late final _text = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(QuantityStepper old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _text.text != '${widget.value}') _text.text = '${widget.value}';
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final max = widget.max < 1 ? 1 : widget.max;
    final typed = int.tryParse(_text.text.trim());
    var n = typed ?? widget.value;
    if (n < 1) n = 1;
    if (n > max) {
      n = max;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Only $max can be ordered — set to $max.')));
      }
    }
    _text.text = '$n';
    if (n != widget.value) widget.onChanged?.call(n);
  }

  void _step(int d) {
    final n = (widget.value + d).clamp(1, widget.max < 1 ? 1 : widget.max);
    _text.text = '$n';
    if (n != widget.value) widget.onChanged?.call(n);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final on = widget.onChanged != null;
    Widget btn(IconData icon, VoidCallback? tap) => Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: tap,
            child: SizedBox(
              width: widget.height,
              height: widget.height,
              child: Icon(icon, size: 17, color: tap == null ? c.muted.withValues(alpha: .5) : c.text),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, on && widget.value > 1 ? () => _step(-1) : null),
        SizedBox(
          width: 52,
          height: widget.height,
          child: TextField(
            controller: _text,
            focusNode: _focus,
            enabled: on,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.text),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kOrange, width: 1.5)),
            ),
            onSubmitted: (_) => _commit(),
            onTapOutside: (_) => _focus.unfocus(),
          ),
        ),
        btn(Icons.add, on && widget.value < widget.max ? () => _step(1) : null),
      ]),
    );
  }
}
