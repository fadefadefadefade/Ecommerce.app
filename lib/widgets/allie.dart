import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AllieMood { idle, thinking, happy, sad }

/// ALLIE, ALVY's assistant: the same face and motions as the website (partials/assistant-avatar and assistant-widget).
/// She blinks, her heart beats, her bow wiggles, she looks around and tilts; thinking moves her eyes, happy gives her
/// squinty eyes, a grin and a hop. [animate] false draws her still (chat rows). Honours the phone's "remove animations".
class AllieAvatar extends StatefulWidget {
  final double size;
  final AllieMood mood;
  final bool animate;

  /// A little hop when she first appears.
  final bool hello;

  /// Shaking (held over the ×).
  final bool tremble;
  const AllieAvatar({super.key, this.size = 56, this.mood = AllieMood.idle, this.animate = true, this.hello = false, this.tremble = false});

  @override
  State<AllieAvatar> createState() => _AllieAvatarState();
}

class _AllieAvatarState extends State<AllieAvatar> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  Ticker? _ticker;
  double _hopFrom = -10;

  @override
  void initState() {
    super.initState();
    if (widget.hello) _hopFrom = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (run && _ticker == null) {
      _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)..start();
    } else if (!run && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  @override
  void didUpdateWidget(AllieAvatar old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood && widget.mood == AllieMood.happy) _hopFrom = _time.value;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _AlliePainter(_time, widget.mood, _hopFrom, widget.tremble),
        ),
      );
}

/// The floating ALLIE button (bobs gently, like the website's launcher).
class AllieLauncher extends StatefulWidget {
  final VoidCallback onPressed;
  final AllieMood mood;
  final bool tremble;

  /// False while she is being dragged.
  final bool bob;
  const AllieLauncher({super.key, required this.onPressed, this.mood = AllieMood.idle, this.tremble = false, this.bob = true});
  @override
  State<AllieLauncher> createState() => _AllieLauncherState();
}

class _AllieLauncherState extends State<AllieLauncher> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBob();
  }

  @override
  void didUpdateWidget(AllieLauncher old) {
    super.didUpdateWidget(old);
    _syncBob();
  }

  void _syncBob() {
    if (!widget.bob || MediaQuery.disableAnimationsOf(context)) {
      _bob.stop();
    } else if (!_bob.isAnimating) {
      _bob.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _bob,
        builder: (_, child) => Transform.translate(offset: Offset(0, -5 * Curves.easeInOut.transform(_bob.value)), child: child),
        child: FloatingActionButton(
          heroTag: null,
          tooltip: 'ALLIE',
          backgroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: widget.onPressed,
          child: AllieAvatar(size: 46, hello: true, mood: widget.mood, tremble: widget.tremble),
        ),
      );
}

/// ALLIE floating over the buyer's pages, like the website: drag her anywhere and she snaps to the nearest side;
/// drop her on the × (or tap her small ×) to hide her; the tab on the screen's edge brings her back.
/// Her place and whether she is hidden are remembered on this phone.
class AllieFloating extends StatefulWidget {
  final VoidCallback onOpen;
  const AllieFloating({super.key, required this.onOpen});
  @override
  State<AllieFloating> createState() => _AllieFloatingState();
}

class _AllieFloatingState extends State<AllieFloating> {
  static const _posKey = 'allie-position';
  static const _hiddenKey = 'allie-hidden';
  static const _size = 64.0;
  static const _edge = 16.0;

  String? _side;   // left / right; null: her usual place, bottom right
  double? _y;      // how far down the screen, 0–1
  bool _ready = false;
  bool _hidden = false;
  bool _leaving = false;
  bool _snap = false;
  bool _over = false;
  bool _hearts = false;
  int _shown = 0;
  Offset? _drag;
  AllieMood _mood = AllieMood.idle;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = (prefs.getString(_posKey) ?? '').split(':');
      if (saved.length == 2 && (saved[0] == 'left' || saved[0] == 'right')) {
        _side = saved[0];
        _y = double.tryParse(saved[1]);
      }
      _hidden = prefs.getBool(_hiddenKey) ?? false;
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_side != null && _y != null) await prefs.setString(_posKey, '$_side:$_y');
      await prefs.setBool(_hiddenKey, _hidden);
    } catch (_) {}
  }

  void _later(int ms, VoidCallback then) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(then);
    });
  }

  /// She is sad to go: a sad face, then she shrinks away.
  void _hide() {
    if (_leaving || _hidden) return;
    void done() {
      _leaving = false;
      _hidden = true;
      _over = false;
      _mood = AllieMood.idle;
      _save();
    }

    if (MediaQuery.disableAnimationsOf(context)) return setState(done);
    setState(() {
      _leaving = true;
      _mood = AllieMood.sad;
    });
    _later(650, done);
  }

  /// She comes back happy, with a few hearts.
  void _show() {
    setState(() {
      _hidden = false;
      _shown++;
      _mood = AllieMood.happy;
      _hearts = true;
    });
    _save();
    _later(1400, () {
      _mood = AllieMood.idle;
      _hearts = false;
    });
  }

  void _dragUpdate(Offset delta, double w, double h) {
    final next = _drag! + delta;
    final at = Offset(next.dx.clamp(0.0, w - _size), next.dy.clamp(0.0, h - _size));
    final centre = at + const Offset(_size / 2, _size / 2);
    final over = (centre - Offset(w / 2, h - 50)).distance < 64;
    setState(() {
      _drag = at;
      _over = over;
      _mood = over ? AllieMood.sad : AllieMood.idle;
    });
  }

  void _dragEnd(double w, double h) {
    final at = _drag;
    if (at == null) return;
    if (_over) {
      setState(() => _drag = null);
      return _hide();
    }
    setState(() {
      _side = at.dx + _size / 2 < w / 2 ? 'left' : 'right';
      _y = at.dy / h;
      _drag = null;
      _snap = true;
      _mood = AllieMood.idle;
    });
    _save();
    _later(320, () => _snap = false);
  }

  void _dragCancel() => setState(() {
        _drag = null;
        _over = false;
        _snap = true;
        _mood = AllieMood.idle;
      });

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final minTop = MediaQuery.paddingOf(context).top + 8;
      final maxTop = math.max(minTop, h - _size - _edge);
      final onLeft = _side == 'left';
      final rest = Offset(onLeft ? _edge : w - _size - _edge, _y == null ? maxTop : (_y! * h).clamp(minTop, maxTop));
      final at = _drag ?? rest;
      final held = _drag != null;
      return Stack(children: [
        if (held) _dropTarget(w, h),
        if (_hidden)
          Positioned(top: rest.dy + 10, left: onLeft ? 0 : null, right: onLeft ? null : 0, child: _peek(onLeft))
        else
          AnimatedPositioned(
            left: at.dx,
            top: at.dy,
            width: _size,
            height: _size,
            duration: _snap ? const Duration(milliseconds: 280) : Duration.zero,
            curve: Curves.easeOutBack,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_shown),
              tween: Tween(begin: _shown > 0 ? 0 : 1, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              builder: (_, s, c) => Transform.scale(scale: s, child: c),
              child: AnimatedScale(
                scale: _leaving ? 0 : (held ? 1.1 : 1),
                duration: Duration(milliseconds: _leaving ? 600 : 120),
                curve: _leaving ? Curves.easeInBack : Curves.easeOut,
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                  GestureDetector(
                    onPanStart: (_) => setState(() {
                      _timer?.cancel();
                      _drag = at;
                      _snap = false;
                    }),
                    onPanUpdate: (d) => _dragUpdate(d.delta, w, h),
                    onPanEnd: (_) => _dragEnd(w, h),
                    onPanCancel: _dragCancel,
                    child: AllieLauncher(onPressed: widget.onOpen, mood: _mood, tremble: _over, bob: !held && !_leaving),
                  ),
                  if (!held && !_leaving)
                    Positioned(
                      top: -4,
                      left: onLeft ? null : -4,
                      right: onLeft ? -4 : null,
                      child: Semantics(
                        button: true,
                        label: 'Hide ALLIE',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _hide,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF002B4D),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_hearts)
                    for (final (i, dx) in const [-20.0, -6.0, 8.0, 22.0].indexed) _FloatingHeart(dx: dx, rise: 44.0 + i * 8),
                ]),
              ),
            ),
          ),
      ]);
    });
  }

  Widget _dropTarget(double w, double h) => Positioned(
        left: 0,
        right: 0,
        bottom: 12,
        child: IgnorePointer(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedScale(
              scale: _over ? 1.22 : 1,
              duration: const Duration(milliseconds: 150),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _over ? const Color(0xFFDC2626) : const Color(0xD1002B4D),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Drop to hide',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, shadows: [Shadow(color: Color(0x80000000), blurRadius: 3)])),
          ]),
        ),
      );

  /// Her tab on the edge while hidden: a bit sad, waiting to be brought back.
  Widget _peek(bool onLeft) => Semantics(
        button: true,
        label: 'Show ALLIE',
        child: Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: const Color(0x73002B4D),
          borderRadius: BorderRadius.horizontal(
            left: onLeft ? Radius.zero : const Radius.circular(99),
            right: onLeft ? const Radius.circular(99) : Radius.zero,
          ),
          child: InkWell(
            onTap: _show,
            borderRadius: BorderRadius.horizontal(
              left: onLeft ? Radius.zero : const Radius.circular(99),
              right: onLeft ? const Radius.circular(99) : Radius.zero,
            ),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: AllieAvatar(size: 34, mood: AllieMood.sad),
            ),
          ),
        ),
      );
}

class _FloatingHeart extends StatelessWidget {
  final double dx;
  final double rise;
  const _FloatingHeart({required this.dx, required this.rise});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1300),
          curve: Curves.easeOut,
          child: const Icon(Icons.favorite, size: 14, color: Color(0xFFFF5C8A)),
          builder: (_, v, c) => Transform.translate(
            offset: Offset(dx * v, -rise * v),
            child: Opacity(opacity: v < .15 ? v / .15 : 1 - ((v - .15) / .85), child: c),
          ),
        ),
      );
}

/// The three bouncing dots while ALLIE writes.
class AllieTypingDots extends StatefulWidget {
  final Color color;
  const AllieTypingDots({super.key, required this.color});
  @override
  State<AllieTypingDots> createState() => _AllieTypingDotsState();
}

class _AllieTypingDotsState extends State<AllieTypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Builder(builder: (_) {
              final p = (_c.value - i * 0.15) % 1;
              final up = p < 0.8 ? math.sin(p / 0.8 * math.pi) : 0.0;
              return Transform.translate(
                offset: Offset(0, -3 * up),
                child: Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.3 + 0.7 * up), shape: BoxShape.circle),
                ),
              );
            }),
        ]),
      );
}

const _ink = Color(0xFF1D2733);
const _navy = Color(0xFF002B4D);

class _AlliePainter extends CustomPainter {
  final ValueNotifier<double> time;
  final AllieMood mood;
  final double hopFrom;
  final bool tremble;
  _AlliePainter(this.time, this.mood, this.hopFrom, this.tremble) : super(repaint: time);

  /// Keyframes: [at] are 0–1 stops of the loop, [v] the values, eased between stops.
  static double _kf(double p, List<double> at, List<double> v) {
    for (var i = 0; i < at.length - 1; i++) {
      if (p <= at[i + 1]) {
        final f = (p - at[i]) / (at[i + 1] - at[i]);
        return v[i] + (v[i + 1] - v[i]) * Curves.easeInOut.transform(f.clamp(0.0, 1.0));
      }
    }
    return v.last;
  }

  static double _loop(double t, double period) => (t % period) / period;

  Paint _fill(Color c) => Paint()..color = c..isAntiAlias = true;
  Paint _line(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final thinking = mood == AllieMood.thinking;
    final happy = mood == AllieMood.happy;
    final sad = mood == AllieMood.sad;
    canvas.save();
    canvas.scale(size.width / 64);
    if (tremble) canvas.translate(math.sin(t / .32 * 2 * math.pi), 0);

    // Whole body: a hop (hello / happy), else her tilt.
    final hopT = t - hopFrom;
    if (hopT >= 0 && hopT < 0.9) canvas.translate(0, -5 * math.sin(hopT / 0.9 * math.pi));
    final tilt = thinking
        ? 6 * math.sin(_loop(t, 1.6) * 2 * math.pi)
        : sad
            ? _kf(_loop(t, 2.4), const [0, .5, 1], const [0, -3, 0])
            : _kf(_loop(t, 9), const [0, .8, .85, .91, .96, 1], const [0, 0, -9, 6, -2, 0]);
    canvas.translate(32, 37);
    canvas.rotate(tilt * math.pi / 180);
    canvas.translate(-32, -37);

    // Heart antenna.
    canvas.drawLine(const Offset(32, 17), const Offset(32, 11.5), _line(_navy, 2.2));
    final beat = _kf(_loop(t, 2.6), const [0, .1, .2, .3, .4, 1], const [1, 1.28, .96, 1.18, 1, 1]);
    canvas.save();
    canvas.translate(32, 8);
    if (sad) {
      canvas.rotate(-24 * math.pi / 180);
      canvas.scale(.82);
    } else {
      canvas.scale(beat);
    }
    canvas.translate(-32, -8);
    canvas.drawPath(
      Path()
        ..moveTo(32, 11.8)
        ..cubicTo(27.4, 8.6, 26.2, 5.2, 28.5, 3.6)
        ..cubicTo(30.1, 2.5, 31.5, 3.4, 32, 4.6)
        ..cubicTo(32.5, 3.4, 33.9, 2.5, 35.5, 3.6)
        ..cubicTo(37.8, 5.2, 36.6, 8.6, 32, 11.8)
        ..close(),
      _fill(const Color(0xFFFF5C8A)),
    );
    canvas.restore();

    // Headphones.
    for (final x in const [4.5, 52.5]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 30, 7, 13), const Radius.circular(3.5)), _fill(_navy));
    }

    // Head with its shine.
    const headRect = Rect.fromLTWH(9, 15, 46, 44);
    final head = RRect.fromRectAndRadius(headRect, const Radius.circular(21));
    canvas.drawRRect(
      head,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF9A6B), Color(0xFFFA4E1C)]).createShader(headRect),
    );
    canvas.drawRRect(
      head,
      Paint()
        ..shader = const RadialGradient(center: Alignment(-.36, -.56), radius: .6, colors: [Color(0x73FFFFFF), Color(0x00FFFFFF)]).createShader(headRect),
    );

    // Little bow.
    canvas.save();
    canvas.translate(46, 17);
    canvas.rotate(18 * math.pi / 180);
    canvas.rotate(_kf(_loop(t, 3.6), const [0, .7, .78, .86, .93, 1], const [0, 0, -14, 12, -6, 0]) * math.pi / 180);
    final bow = _fill(const Color(0xFFFF7AA8));
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(-6, -3.6)..quadraticBezierTo(-7.2, 0, -6, 3.6)..close(), bow);
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(6, -3.6)..quadraticBezierTo(7.2, 0, 6, 3.6)..close(), bow);
    canvas.drawCircle(Offset.zero, 1.9, _fill(const Color(0xFFFF4F86)));
    canvas.restore();

    // Face.
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14.5, 23, 35, 29), const Radius.circular(14)), _fill(const Color(0xFFFFF7F2)));

    if (happy) {
      final squint = _line(_ink, 2.4);
      canvas.drawPath(Path()..moveTo(20.8, 35.6)..quadraticBezierTo(25, 29.6, 29.2, 35.6), squint);
      canvas.drawPath(Path()..moveTo(34.8, 35.6)..quadraticBezierTo(39, 29.6, 43.2, 35.6), squint);
    } else {
      // Eyes: they blink, and look around.
      final p = _loop(t, 4.5);
      final blink = p < .92 ? 1.0 : (p < .95 ? 1 - .9 * (p - .92) / .03 : .1 + .9 * ((p - .95) / .05).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(32, 33);
      canvas.scale(1, blink);
      canvas.translate(-32, -33);
      final lookP = _loop(t, thinking ? 1.6 : 7);
      final lx = thinking
          ? _kf(lookP, const [0, .3, .65, 1], const [0, -1.8, 1.8, 0])
          : _kf(lookP, const [0, .3, .36, .46, .52, .58, .62, 1], const [0, 0, -1.6, -1.6, 1.6, 1.6, 0, 0]);
      final ly = thinking ? -1.2 : _kf(lookP, const [0, .3, .36, .46, .52, .58, .62, 1], const [0, 0, .4, .4, -.4, -.4, 0, 0]);
      canvas.save();
      canvas.translate(sad ? 0 : lx, sad ? 1.3 : ly);
      final dark = _fill(_ink);
      final white = _fill(Colors.white);
      canvas.drawOval(Rect.fromCenter(center: const Offset(25, 34), width: 8.2, height: 10), dark);
      canvas.drawOval(Rect.fromCenter(center: const Offset(39, 34), width: 8.2, height: 10), dark);
      canvas.drawCircle(const Offset(26.5, 32.1), 1.55, white);
      canvas.drawCircle(const Offset(40.5, 32.1), 1.55, white);
      canvas.drawCircle(const Offset(23.9, 36), .75, white);
      canvas.drawCircle(const Offset(37.9, 36), .75, white);
      canvas.restore();
      final lash = _line(_ink, 1.1);
      canvas.drawLine(const Offset(21.4, 30.6), const Offset(19.8, 29.4), lash);
      canvas.drawLine(const Offset(22.4, 29.5), const Offset(21.4, 27.9), lash);
      canvas.drawLine(const Offset(42.6, 30.6), const Offset(44.2, 29.4), lash);
      canvas.drawLine(const Offset(41.6, 29.5), const Offset(42.6, 27.9), lash);
      canvas.restore();
    }

    // Rosy cheeks.
    final cheek = _fill(const Color(0xCCFF8FA3));
    canvas.drawOval(Rect.fromCenter(center: const Offset(19.6, 41.6), width: 6.6, height: 4.2), cheek);
    canvas.drawOval(Rect.fromCenter(center: const Offset(44.4, 41.6), width: 6.6, height: 4.2), cheek);

    // Mouth: her little smile, the big one, or (sad) worried brows, a frown and a tear.
    if (sad) {
      final brow = _line(_ink, 1.7);
      canvas.drawPath(Path()..moveTo(20.6, 27.6)..quadraticBezierTo(24.4, 27.6, 28, 25.4), brow);
      canvas.drawPath(Path()..moveTo(43.4, 27.6)..quadraticBezierTo(39.6, 27.6, 36, 25.4), brow);
      canvas.drawPath(Path()..moveTo(28.4, 45.4)..quadraticBezierTo(32, 41.8, 35.6, 45.4), _line(_ink, 1.9));
      final p = _loop(t, 1.6);
      final tearY = _kf(p, const [0, .2, .75, 1], const [-2, 0, 5, 7]);
      final tearA = _kf(p, const [0, .2, .75, 1], const [0, 1, 1, 0]);
      canvas.save();
      canvas.translate(0, tearY);
      canvas.drawPath(
        Path()
          ..moveTo(21.4, 39.4)
          ..quadraticBezierTo(19.6, 42.6, 21.4, 43.8)
          ..quadraticBezierTo(23.2, 42.6, 21.4, 39.4)
          ..close(),
        _fill(const Color(0xFF7CC4FF).withValues(alpha: tearA)),
      );
      canvas.restore();
    } else if (happy) {
      canvas.drawPath(
        Path()
          ..moveTo(27.6, 41.2)
          ..quadraticBezierTo(32, 41.8, 36.4, 41.2)
          ..quadraticBezierTo(36, 46.6, 32, 46.8)
          ..quadraticBezierTo(28, 46.6, 27.6, 41.2)
          ..close(),
        _fill(_ink),
      );
      canvas.drawPath(
        Path()
          ..moveTo(29.6, 45.2)
          ..quadraticBezierTo(32, 43.9, 34.4, 45.2)
          ..quadraticBezierTo(33.4, 46.6, 32, 46.6)
          ..quadraticBezierTo(30.6, 46.6, 29.6, 45.2)
          ..close(),
        _fill(const Color(0xFFFF7A90)),
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(28.6, 42)
          ..quadraticBezierTo(30.3, 44.6, 32, 42)
          ..quadraticBezierTo(33.7, 44.6, 35.4, 42),
        _line(_ink, 1.9),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AlliePainter old) => old.mood != mood || old.hopFrom != hopFrom || old.tremble != tremble;
}
