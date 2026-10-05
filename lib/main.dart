import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import 'package:kitsune/game/audio.dart';
import 'package:kitsune/game/game.dart';
import 'package:kitsune/game/world.dart' as wmod;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitsunebi: Ninefold Neon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF49E8FF)),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final KitsuneGame game;

  @override
  void initState() {
    super.initState();
    game = KitsuneGame(
      wmod.GameConfig(
        playerSpeed: 280,
        enemyAggression: 1,
        effectsIntensity: 1,
        musicVolume: 0.16,
      ),
      AudioManager(0.16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: game)),
          Positioned.fill(child: HudOverlay(game)),
          Positioned.fill(child: TouchControls(game)),
          Positioned.fill(child: OverlayPanel(game)),
        ],
      ),
    );
  }
}

class HudOverlay extends StatelessWidget {
  final KitsuneGame game;
  const HudOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HudState>(
      valueListenable: game.hud,
      builder: (context, hud, _) {
        return Stack(
          children: [
            IgnorePointer(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          _Tails(tails: hud.tails),
                          const SizedBox(width: 12),
                          _SpiritMeter(spirit: hud.spirit, active: hud.spiritActive),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(hud.stageName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                              Text(hud.score.round().toString(),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.pause, size: 26, color: Colors.transparent),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _ProgressBar(value: hud.progress),
                    ),
                    if (hud.bossName != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        child: _BossBar(name: hud.bossName!, value: hud.bossHp),
                      ),
                    const Spacer(),
                    ValueListenableBuilder<String?>(
                      valueListenable: game.toastMsg,
                      builder: (context, toast, _) => AnimatedOpacity(
                        opacity: toast != null ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: toast != null
                            ? Container(
                                margin: const EdgeInsets.only(bottom: 120),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(toast, style: const TextStyle(fontSize: 16)),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => game.togglePause(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.pause, size: 26),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tails extends StatelessWidget {
  final int tails;
  const _Tails({required this.tails});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(9, (i) {
        final lit = i < tails;
        return Container(
          width: 10,
          height: 18,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: lit ? const Color(0xFFFF7FD8) : Colors.white12,
            borderRadius: BorderRadius.circular(5),
            boxShadow: lit
                ? const [BoxShadow(color: Color(0xFFFF7FD8), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }
}

class _SpiritMeter extends StatelessWidget {
  final double spirit;
  final bool active;
  const _SpiritMeter({required this.spirit, required this.active});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("狐", style: TextStyle(color: Color(0xFF49E8FF))),
        const SizedBox(height: 4),
        Container(
          width: 90,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: spirit / 100,
            child: Container(
              decoration: BoxDecoration(
                color: active ? const Color(0xFF9CFF6B) : const Color(0xFF49E8FF),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: active ? const Color(0xFF9CFF6B) : const Color(0xFF49E8FF),
                    blurRadius: 10,
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF49E8FF),
            borderRadius: BorderRadius.circular(4),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Container(
          height: 9,
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF4FD8),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TouchControls extends StatelessWidget {
  final KitsuneGame game;
  const TouchControls(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MenuOverlay?>(
      valueListenable: game.overlay,
      builder: (context, overlay, _) {
        if (overlay != null) return const SizedBox.shrink();
        Widget hold(String action, String label, {IconData? icon}) => GestureDetector(
              onTapDown: (_) => game.input.set(action, true),
              onTapUp: (_) => game.input.set(action, false),
              onTapCancel: () => game.input.set(action, false),
              child: Container(
                width: 58,
                height: 58,
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(child: icon != null ? Icon(icon) : Text(label, style: const TextStyle(fontSize: 20))),
              ),
            );
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    hold("left", "‹"),
                    hold("right", "›"),
                  ],
                ),
                Row(
                  children: [
                    hold("ofuda", "札"),
                    hold("dash", "幻"),
                    hold("jump", "", icon: Icons.arrow_upward),
                    hold("fire", "火"),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OverlayPanel extends StatelessWidget {
  final KitsuneGame game;
  const OverlayPanel(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MenuOverlay?>(
      valueListenable: game.overlay,
      builder: (context, overlay, _) {
        if (overlay == null) return const SizedBox.shrink();
        return Container(
          color: Colors.black87,
          child: Center(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F2A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF49E8FF).withAlpha(120)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(overlay.kicker.toUpperCase(),
                      style: const TextStyle(letterSpacing: 2, color: Color(0xFF49E8FF))),
                  const SizedBox(height: 8),
                  Text(overlay.title,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Text(overlay.copy, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 22),
                  ...overlay.actions.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: a.secondary ? Colors.white12 : const Color(0xFF49E8FF),
                              foregroundColor: a.secondary ? Colors.white : Colors.black,
                            ),
                            onPressed: () => game.handleMenuAction(a.action),
                            child: Text(a.label),
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
