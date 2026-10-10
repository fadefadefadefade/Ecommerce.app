import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Stock input: type a number or use − / + (hold to repeat).
/// Pass a [controller], or an [initialValue] with [onChanged].
class StockStepper extends StatefulWidget {
  final TextEditingController? controller;
  final int initialValue;
  final ValueChanged<int>? onChanged;
  final String? labelText;
  final String? suffixText;
  final FormFieldValidator<String>? validator;
  final int min;
  final int max;
  final bool dense;

  const StockStepper({
    super.key,
    this.controller,
    this.initialValue = 0,
    this.onChanged,
    this.labelText,
    this.suffixText,
    this.validator,
    this.min = 0,
    this.max = 99999,
    this.dense = false,
  });

  @override
  State<StockStepper> createState() => _StockStepperState();
}

class _StockStepperState extends State<StockStepper> {
  static const _primary = Color(0xFFfa4e1c);

  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: '${widget.initialValue}');
  Timer? _repeat;

  int get _value => int.tryParse(_controller.text) ?? widget.min;

  @override
  void dispose() {
    _repeat?.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _set(int v) {
    final next = v.clamp(widget.min, widget.max);
    _controller.value = TextEditingValue(
      text: '$next',
      selection: TextSelection.collapsed(offset: '$next'.length),
    );
    widget.onChanged?.call(next);
    setState(() {});
  }

  void _startRepeat(int delta) {
    _set(_value + delta);
    _repeat?.cancel();
    // Speeds up the longer the button is held.
    var ticks = 0;
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) {
      ticks++;
      if (ticks < 4) return; // short delay before repeating
      _set(_value + delta * (ticks > 30 ? 10 : 1));
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  Widget _button(IconData icon, int delta, bool enabled) {
    return GestureDetector(
      onTapDown: enabled ? (_) => _startRepeat(delta) : null,
      onTapUp: (_) => _stopRepeat(),
      onTapCancel: _stopRepeat,
      child: Container(
        width: widget.dense ? 36 : 44,
        alignment: Alignment.center,
        child: Icon(icon, size: widget.dense ? 18 : 22, color: enabled ? _primary : Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return TextFormField(
      controller: _controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
      style: const TextStyle(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixText: widget.suffixText,
        border: const OutlineInputBorder(),
        isDense: widget.dense,
        prefixIcon: _button(Icons.remove, -1, value > widget.min),
        suffixIcon: _button(Icons.add, 1, value < widget.max),
      ),
      validator: widget.validator,
      onChanged: (text) {
        final v = int.tryParse(text);
        if (v != null) widget.onChanged?.call(v.clamp(widget.min, widget.max));
        setState(() {});
      },
    );
  }
}
