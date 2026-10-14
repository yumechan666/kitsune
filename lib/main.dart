import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kitsune/game/audio.dart';
import 'package:kitsune/game/game.dart';
import 'package:kitsune/game/world.dart' as wmod;
import 'package:kitsune/ui/controls.dart';
import 'package:kitsune/ui/hud.dart';
import 'package:kitsune/ui/menu_panel.dart';
import 'package:kitsune/ui/splash.dart';
import 'package:kitsune/ui/tutorial_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The game is played sideways on phones; both landscape directions are
  // allowed so the phone can be turned either way.
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitsune Neon Exorcist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF49E8FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF06091B),
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
          Positioned.fill(child: RepaintBoundary(child: GameWidget(game: game))),
          Positioned.fill(child: RepaintBoundary(child: TouchControls(game))),
          Positioned.fill(child: RepaintBoundary(child: HudOverlay(game))),
          Positioned.fill(child: RepaintBoundary(child: OverlayPanel(game))),
          Positioned.fill(child: RepaintBoundary(child: TutorialPanel(game))),
          Positioned.fill(child: SplashOverlay(ready: game.assetsReady)),
        ],
      ),
    );
  }
}
