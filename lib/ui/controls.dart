import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:kitsune/game/game.dart';
import 'package:kitsune/game/input.dart';
import 'package:kitsune/ui/palette.dart';

class TouchControls extends StatelessWidget {
  final KitsuneGame game;
  const TouchControls(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MenuOverlay?>(
      valueListenable: game.overlay,
      builder: (context, overlay, _) {
        if (overlay != null) return const SizedBox.shrink();
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // The controls are drawn for a 540-unit-tall play field. On a
              // short landscape phone they shrink with the screen height so
              // they cover less of the level; transforms keep touch areas in
              // step with what is drawn.
              final scale = (box.maxHeight / 640).clamp(0.5, 0.85).toDouble();
              return Opacity(
                opacity: 0.72,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      width: 280,
                      height: 240,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.bottomLeft,
                        child: Joystick(input: game.input),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.bottomRight,
                        child: _ActionPad(game: game),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class Joystick extends StatefulWidget {
  final InputState input;
  const Joystick({super.key, required this.input});

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  static const double radius = 56;
  static const double deadZone = 0.28;
  static const Offset rest = Offset(96, 136);

  int? _pointer;
  Offset _center = rest;
  Offset _knob = Offset.zero;

  void _apply(Offset delta) {
    final clamped = delta.distance > radius
        ? delta / delta.distance * radius
        : delta;
    final x = clamped.dx / radius;
    widget.input.set("left", x < -deadZone);
    widget.input.set("right", x > deadZone);
    setState(() => _knob = clamped);
  }

  void _release() {
    _pointer = null;
    widget.input.set("left", false);
    widget.input.set("right", false);
    if (mounted) {
      setState(() {
        _center = rest;
        _knob = Offset.zero;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Listener only sees pointer-up events that land on the joystick itself. A
    // finger lifted elsewhere would otherwise leave the character walking.
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
  }

  void _onGlobalPointer(PointerEvent event) {
    if (_pointer == null || event.pointer != _pointer) return;
    if (event is PointerUpEvent || event is PointerCancelEvent) _release();
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    if (_pointer != null) {
      widget.input.set("left", false);
      widget.input.set("right", false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _pointer != null;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        _center = e.localPosition;
        _apply(Offset.zero);
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer) _apply(e.localPosition - _center);
      },
      onPointerUp: (e) {
        if (e.pointer == _pointer) _release();
      },
      onPointerCancel: (e) {
        if (e.pointer == _pointer) _release();
      },
      child: CustomPaint(
        painter: _JoystickPainter(
          center: _center,
          knob: _knob,
          radius: radius,
          active: active,
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset center;
  final Offset knob;
  final double radius;
  final bool active;
  _JoystickPainter({
    required this.center,
    required this.knob,
    required this.radius,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x4D78C2FF),
          Color(active ? 0xCC0A1535 : 0x990A1535),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 14));
    canvas.drawCircle(center, radius + 14, base);
    canvas.drawCircle(
      center,
      radius + 14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color(active ? 0xFFBDFAFF : 0x75C2E9FF),
    );
    final arrow = Paint()..color = const Color(0x99C9E7FF);
    for (final dir in [-1.0, 1.0]) {
      final tip = center + Offset(dir * (radius + 4), 0);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - dir * 9, tip.dy - 7)
          ..lineTo(tip.dx - dir * 9, tip.dy + 7)
          ..close(),
        arrow,
      );
    }
    final k = center + knob;
    if (active) {
      canvas.drawCircle(
        k,
        34,
        Paint()
          ..color = const Color(0x5549E8FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    canvas.drawCircle(
      k,
      28,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFE9FCFF), Color(0xFF6FD8FF), Color(0xFF2D5FC4)],
          stops: [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: k, radius: 28)),
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.center != center || old.knob != knob || old.active != active;
}

class _ActionPad extends StatelessWidget {
  final KitsuneGame game;
  const _ActionPad({required this.game});

  @override
  Widget build(BuildContext context) {
    final input = game.input;
    return SizedBox(
      width: 236,
      height: 228,
      child: ValueListenableBuilder<HudState>(
        valueListenable: game.hud,
        builder: (context, hud, _) {
          final spiritReady = hud.spirit >= 100 && !hud.spiritActive;
          return Stack(
            children: [
              Positioned(
                right: 0,
                bottom: 0,
                child: ActionButton(
                  input: input,
                  action: "fire",
                  label: "Tembak",
                  icon: Icons.local_fire_department_rounded,
                  size: 84,
                  accent: hud.spiritActive ? Neon.feral : Neon.cyan,
                  primary: true,
                ),
              ),
              Positioned(
                right: 94,
                bottom: 0,
                child: ActionButton(
                  input: input,
                  action: "jump",
                  label: "Lompat",
                  icon: Icons.keyboard_double_arrow_up_rounded,
                  size: 66,
                ),
              ),
              Positioned(
                right: 80,
                bottom: 80,
                child: ActionButton(
                  input: input,
                  action: "dash",
                  label: "Lesat",
                  icon: Icons.bolt_rounded,
                  size: 60,
                ),
              ),
              Positioned(
                right: 4,
                bottom: 96,
                child: ActionButton(
                  input: input,
                  action: "ofuda",
                  label: "Jimat",
                  icon: Icons.style_rounded,
                  size: 60,
                  cooldown: hud.ofudaReady,
                  enabled: !hud.spiritActive,
                ),
              ),
              Positioned(
                right: 150,
                bottom: 150,
                child: ActionButton(
                  input: input,
                  action: "spirit",
                  label: "Roh",
                  icon: Icons.auto_awesome_rounded,
                  size: 56,
                  accent: hud.spiritActive ? Neon.feral : Neon.borderBright,
                  cooldown: hud.spiritActive ? 1 : hud.spirit / 100,
                  glow: spiritReady,
                  enabled: spiritReady,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ActionButton extends StatefulWidget {
  final InputState input;
  final String action;
  final String label;
  final IconData icon;
  final double size;
  final Color accent;
  final bool primary;
  final double cooldown;
  final bool glow;
  final bool enabled;

  const ActionButton({
    super.key,
    required this.input,
    required this.action,
    required this.label,
    required this.icon,
    required this.size,
    this.accent = Neon.cyan,
    this.primary = false,
    this.cooldown = 1,
    this.glow = false,
    this.enabled = true,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  final Set<int> _pointers = {};

  void _down(PointerDownEvent e) {
    _pointers.add(e.pointer);
    widget.input.set(widget.action, true);
    setState(() {});
  }

  void _up(PointerEvent e) {
    if (!_pointers.remove(e.pointer) || _pointers.isNotEmpty) return;
    widget.input.set(widget.action, false);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
  }

  void _onGlobalPointer(PointerEvent event) {
    if (!_pointers.contains(event.pointer)) return;
    if (event is PointerUpEvent || event is PointerCancelEvent) _up(event);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    if (_pointers.isNotEmpty) widget.input.set(widget.action, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final held = _pointers.isNotEmpty;
    final dim = !widget.enabled || widget.cooldown < 1;
    final accent = widget.accent;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedScale(
        scale: held ? 0.9 : 1,
        duration: const Duration(milliseconds: 70),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ButtonRingPainter(
              progress: widget.cooldown.clamp(0.0, 1.0),
              color: accent,
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.45),
                  colors: held
                      ? [accent.withAlpha(200), const Color(0xE6133F6F)]
                      : widget.primary
                      ? const [Color(0x7391F8FF), Color(0xCC133F6F)]
                      : const [Color(0x4D78C2FF), Color(0xB80A1535)],
                  stops: const [0, 0.68],
                ),
                boxShadow: [
                  if (widget.glow || held)
                    BoxShadow(color: accent.withAlpha(150), blurRadius: 18),
                  const BoxShadow(
                    color: Color(0x3D000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Opacity(
                opacity: dim ? 0.55 : 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      color: const Color(0xFFE5F7FF),
                      size: widget.size * 0.36,
                    ),
                    Text(
                      widget.label.toUpperCase(),
                      style: TextStyle(
                        color: const Color(0xFFE5F7FF),
                        fontSize: widget.size > 70 ? 11 : 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ButtonRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(1.5);
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x75C2E9FF),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      ring,
      -1.5708,
      6.28318 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ButtonRingPainter old) =>
      old.progress != progress || old.color != color;
}
