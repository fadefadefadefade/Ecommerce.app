import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';

export '../../widgets/buyer_kit.dart';

/// Small pieces shared by the seller screens (the web's seller panel look).

int asInt(dynamic v) => asNum(v).toInt();

List<Map<String, dynamic>> asList(dynamic v) => v is List ? v.map((e) => asMap(e)).toList() : <Map<String, dynamic>>[];

/// A colored label like the web's status badges.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, {super.key, this.color = kOrange});

  static Color forState(String? s) => switch ((s ?? '').toLowerCase()) {
        'ongoing' || 'active' || 'approved' || 'completed' || 'paid' || 'live' => const Color(0xFF15803D),
        'upcoming' || 'pending' || 'review' || 'requested' || 'new' => const Color(0xFFB45309),
        'ended' || 'off' || 'used up' || 'sold out' || 'inactive' || 'draft' || 'archived' => const Color(0xFF6B7280),
        'rejected' || 'cancelled' || 'failed' || 'out_of_stock' => const Color(0xFFDC2626),
        _ => const Color(0xFF2563EB),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.1)),
    );
  }
}

/// A figure tile (dashboard, reports, earnings).
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;
  const StatTile({super.key, required this.label, required this.value, required this.icon, this.color = kOrange, this.hint});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border), boxShadow: Alvy.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary))),
        ]),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: Alvy.display(size: 21, color: c.text, weight: FontWeight.w900)),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.muted)),
        ],
      ]),
    );
  }
}

/// Two tiles per row.
class StatGrid extends StatelessWidget {
  final List<Widget> tiles;
  const StatGrid(this.tiles, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });
  }
}

Future<bool> confirmAction(BuildContext context, String title, String message, {String confirm = 'Confirm', bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? const Color(0xFFDC2626) : kOrange),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Runs an action, shows the web's message, and returns the answer.
Future<ApiResponse> runAction(BuildContext context, Future<ApiResponse> Function() call) async {
  final r = await call();
  if (context.mounted) showResult(context, r);
  return r;
}

/// A text field in the web form's style, showing the server's error for [field].
class FormInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final String? error;
  final TextInputType? keyboard;
  final int maxLines;
  final int? maxLength;
  final bool obscure;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;
  final String? prefix;

  const FormInput(this.controller, this.label,
      {super.key,
      this.hint,
      this.helper,
      this.error,
      this.keyboard,
      this.maxLines = 1,
      this.maxLength,
      this.obscure = false,
      this.readOnly = false,
      this.onTap,
      this.suffix,
      this.prefix});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: obscure ? 1 : maxLines,
        maxLength: maxLength,
        inputFormatters: keyboard == TextInputType.phone ? phoneFormatters : null,
        obscureText: obscure,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 3,
          errorText: error,
          errorMaxLines: 3,
          prefixText: prefix,
          suffixIcon: suffix,
          isDense: true,
        ),
      ),
    );
  }
}

/// A primary button that shows a spinner while [busy].
class BusyButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  const BusyButton(this.label, {super.key, required this.busy, required this.onPressed, this.color = kOrange, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), boxShadow: busy || onPressed == null || color != kOrange ? null : Alvy.buttonShadow),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon ?? Icons.check, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Picks a date and time; returns it as the web's "Y-m-d H:i".
Future<String?> pickDateTime(BuildContext context, {String? initial, bool future = true}) async {
  final now = DateTime.now();
  final start = DateTime.tryParse((initial ?? '').replaceFirst(' ', 'T')) ?? now.add(const Duration(hours: 1));
  final date = await showDatePicker(
    context: context,
    initialDate: start.isBefore(now) && future ? now : start,
    firstDate: future ? DateTime(now.year, now.month, now.day) : DateTime(2020),
    lastDate: now.add(const Duration(days: 730)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
  if (time == null) return null;
  final d = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// An empty list message.
class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyNote(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: kOrange),
        ),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.bc.textSecondary, height: 1.45)),
      ]),
    );
  }
}

/// The panel screens' app bar: the website's navy header (theme/app_theme.dart).
PreferredSizeWidget sellerBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
      title: Text(title),
      actions: actions,
      bottom: bottom,
    );
