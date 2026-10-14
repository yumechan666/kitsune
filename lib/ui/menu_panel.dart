import 'package:flutter/material.dart';

import 'package:kitsune/game/game.dart';
import 'package:kitsune/ui/palette.dart';

class OverlayPanel extends StatelessWidget {
  final KitsuneGame game;
  const OverlayPanel(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MenuOverlay?>(
      valueListenable: game.overlay,
      builder: (context, overlay, _) {
        if (overlay == null) return const SizedBox.shrink();
        return ColoredBox(
          color: const Color(0xC7020512),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: 440,
                  padding: const EdgeInsets.fromLTRB(28, 26, 28, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xF20A1438), Color(0xF2050A1F)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Neon.border),
                    boxShadow: const [
                      BoxShadow(color: Color(0x5549E8FF), blurRadius: 36),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        overlay.kicker.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: Neon.label.copyWith(
                          color: Neon.cyan,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [Color(0xFFF7FFFF), Color(0xFF8BEFFF)],
                        ).createShader(r),
                        child: Text(
                          overlay.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        overlay.copy,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFC6DDF2),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      if (overlay.actions.isEmpty) ...[
                        const SizedBox(height: 18),
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Neon.cyan,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      for (final a in overlay.actions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MenuButton(
                            label: a.label,
                            secondary: a.secondary,
                            onTap: () => game.handleMenuAction(a.action),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final bool secondary;
  final VoidCallback onTap;
  const _MenuButton({
    required this.label,
    required this.secondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: secondary
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF3E78FF), Color(0xFF49E8FF)],
                ),
          color: secondary ? const Color(0x1AFFFFFF) : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: secondary ? Neon.border : const Color(0x99BDFAFF),
          ),
          boxShadow: secondary
              ? null
              : const [BoxShadow(color: Color(0x6649E8FF), blurRadius: 16)],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Center(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: secondary ? Neon.text : const Color(0xFF041024),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
