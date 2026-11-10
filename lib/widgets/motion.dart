import 'package:flutter/material.dart';

// The app's few small animations. All of them step aside when the phone's "remove animations" is on.

/// A soft fade and rise when [value] changes (the page of a bottom tab). The child stays mounted, so tabs keep their state.
class TabFade extends StatefulWidget {
  final Object value;
  final Widget child;
  const TabFade({super.key, required this.value, required this.child});
  @override
  State<TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _rise = Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(_curve);

  @override
  void didUpdateWidget(TabFade old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !MediaQuery.disableAnimationsOf(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _curve, child: SlideTransition(position: _rise, child: widget.child));
}

/// Shrinks a touch while pressed. Taps still go to the child.
class PressScale extends StatefulWidget {
  final Widget child;
  const PressScale({super.key, required this.child});
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down && !MediaQuery.disableAnimationsOf(context) ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// A quick pop when [value] changes (the wishlist heart, the cart count).
class PopOnChange extends StatefulWidget {
  final Object? value;
  final Widget child;
  const PopOnChange({super.key, required this.value, required this.child});
  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280), value: 1);
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 55),
  ]).animate(_c);

  @override
  void didUpdateWidget(PopOnChange old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !MediaQuery.disableAnimationsOf(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}

/// Fades and rises once when it first appears (a new chat bubble).
class RiseIn extends StatelessWidget {
  final bool enabled;
  final Widget child;
  const RiseIn({super.key, this.enabled = true, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      child: child,
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: c)),
    );
  }
}
