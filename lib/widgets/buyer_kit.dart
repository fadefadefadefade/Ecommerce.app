import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../theme/buyer_colors.dart';

const kOrange = Color(0xFFfa4e1c);

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
              decoration: const BoxDecoration(color: Color(0xFFFFF1EE), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_outlined, size: 36, color: kOrange),
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

/// Section card in the website's style.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const SectionCard({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(14), this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.bc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.bc.border),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
            child: Row(children: [
              Container(width: 3, height: 15, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(2))),
              Expanded(child: Text(title!, style: GoogleFonts.nunito(fontSize: 15.5, fontWeight: FontWeight.w800, color: context.bc.text))),
              if (trailing != null) trailing!,
            ]),
          ),
        Padding(padding: padding, child: child),
      ]),
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
