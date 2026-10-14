import 'package:flutter/material.dart';

import 'package:kitsune/game/game.dart';
import 'package:kitsune/ui/palette.dart';
import 'package:kitsune/ui/skin_picker.dart';

class HudOverlay extends StatelessWidget {
  final KitsuneGame game;
  const HudOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    // Everything sits flush against the top edge in a single compact band so
    // the theme name, score, spirit meter and progress bar never drift down
    // into the playfield.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: IgnorePointer(
                    child: ValueListenableBuilder<HudState>(
                      valueListenable: game.hud,
                      builder: (context, hud, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: _TailRow(tails: hud.tails),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IgnorePointer(
                  child: ValueListenableBuilder<HudState>(
                    valueListenable: game.hud,
                    builder: (context, hud, _) => _TopBar(hud: hud),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<int>(
                  valueListenable: game.volumeNotifier,
                  builder: (context, level, _) => _RoundButton(
                    icon: const [
                      Icons.volume_up_rounded,
                      Icons.volume_down_rounded,
                      Icons.volume_off_rounded,
                    ][level],
                    tooltip: "Volume",
                    onTap: game.cycleVolume,
                  ),
                ),
                const SizedBox(width: 8),
                _RoundButton(
                  icon: Icons.help_outline_rounded,
                  tooltip: "Tutorial",
                  onTap: game.openTutorial,
                ),
                const SizedBox(width: 8),
                _RoundButton(
                  icon: Icons.checkroom_rounded,
                  tooltip: "Ganti skin",
                  onTap: () => showSkinPicker(context, game),
                ),
                const SizedBox(width: 8),
                _RoundButton(
                  icon: Icons.pause_rounded,
                  tooltip: "Jeda",
                  onTap: game.togglePause,
                ),
              ],
            ),
            const SizedBox(height: 6),
            IgnorePointer(
              child: ValueListenableBuilder<HudState>(
                valueListenable: game.hud,
                builder: (context, hud, _) => Column(
                  children: [
                    _Bar(value: hud.progress, height: 3, gradient: Neon.meter),
                    if (hud.bossName != null) ...[
                      const SizedBox(height: 8),
                      _BossBar(name: hud.bossName!, value: hud.bossHp),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            IgnorePointer(child: _Toast(game.toastMsg)),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final HudState hud;
  const _TopBar({required this.hud});

  // Shares the top band with the tails and the round buttons. Scales down on
  // narrow phones instead of overflowing the row.
  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SpiritMeter(spirit: hud.spirit, active: hud.spiritActive),
          const SizedBox(width: 8),
          Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: Neon.panelBox(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hud.stageName, style: Neon.label),
              Text(
                hud.score.round().toString(),
                style: const TextStyle(
                  color: Neon.text,
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}

class _TailRow extends StatelessWidget {
  final int tails;
  const _TailRow({required this.tails});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: Neon.panelBox(radius: 999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(9, (i) {
          final lit = i < tails;
          return Container(
            width: 9,
            height: 16,
            margin: EdgeInsets.only(right: i == 8 ? 0 : 3),
            decoration: BoxDecoration(
              color: lit ? null : const Color(0xFF243153),
              gradient: lit ? Neon.tailLit : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(2),
                bottomLeft: Radius.circular(3),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: lit
                  ? const [BoxShadow(color: Color(0xD156E5FF), blurRadius: 8)]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

class _SpiritMeter extends StatelessWidget {
  final double spirit;
  final bool active;
  const _SpiritMeter({required this.spirit, required this.active});

  @override
  Widget build(BuildContext context) {
    final ready = spirit >= 100 && !active;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xD1135B7E) : Neon.panel,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(10),
          right: Radius.circular(20),
        ),
        border: Border.all(color: ready ? Neon.borderBright : Neon.border),
        boxShadow: ready
            ? const [BoxShadow(color: Color(0xA34BE4FF), blurRadius: 16)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            active ? "LIAR" : "ROH",
            style: Neon.label.copyWith(color: active ? Neon.feral : Neon.cyan),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: _Bar(
              value: spirit / 100,
              height: 7,
              gradient: active
                  ? const LinearGradient(colors: [Neon.feral, Colors.white])
                  : Neon.meter,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double height;
  final Gradient gradient;
  const _Bar({
    required this.value,
    required this.height,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Neon.track,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _BossBar extends StatelessWidget {
  final String name;
  final double value;
  const _BossBar({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFFF2E7FF),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: const Color(0xD609071B),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x6BFFC0F4)),
            ),
            child: _Bar(value: value, height: 6, gradient: Neon.boss),
          ),
        ],
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  final ValueNotifier<String?> message;
  const _Toast(this.message);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: message,
      builder: (context, text, _) => AnimatedSlide(
        offset: text == null ? const Offset(0, -0.4) : Offset.zero,
        duration: const Duration(milliseconds: 180),
        child: AnimatedOpacity(
          opacity: text == null ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: Neon.panelBox(radius: 999).copyWith(
              color: const Color(0xE0040A20),
              border: Border.all(color: const Color(0x6185E8FF)),
            ),
            child: Text(
              text ?? "",
              style: const TextStyle(
                color: Neon.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Neon.panel,
        shape: const CircleBorder(side: BorderSide(color: Neon.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: const Color(0xFFC9E7FF), size: 22),
          ),
        ),
      ),
    );
  }
}
