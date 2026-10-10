import 'package:flutter/material.dart';

/// Dialog that asks for a reason. Returns the trimmed text, or null if dismissed.
///
/// The text controller lives in the dialog's own State, so it is disposed only
/// after the closing animation — disposing it right after `showDialog` returns
/// crashes the still-animating TextField ("TextEditingController was used after
/// being disposed").
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  String? message,
  String hint = 'Reason',
  String confirmLabel = 'Submit',
  String cancelLabel = 'Cancel',
  Color confirmColor = const Color(0xFFC62828),
  bool required = true,
  int maxLength = 500,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      message: message,
      hint: hint,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      confirmColor: confirmColor,
      required: required,
      maxLength: maxLength,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;
  final bool required;
  final int maxLength;

  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmColor,
    required this.required,
    required this.maxLength,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    final canSubmit = !widget.required || text.isNotEmpty;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            maxLines: 3,
            minLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: widget.hint, border: const OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.cancelLabel)),
        ElevatedButton(
          onPressed: canSubmit ? () => Navigator.pop(context, text) : null,
          style: ElevatedButton.styleFrom(backgroundColor: widget.confirmColor, foregroundColor: Colors.white),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
