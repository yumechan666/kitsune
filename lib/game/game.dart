import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kitsune/game/atlas.dart';
import 'package:kitsune/game/audio.dart';
import 'package:kitsune/game/input.dart';
import 'package:kitsune/game/levels.dart';
import 'package:kitsune/game/renderer.dart';
import 'package:kitsune/game/world.dart' as wmod;

class HudState {
  final int tails;
  final double spirit;
  final bool spiritActive;
  final double ofudaReady;
  final double progress;
  final int puzzles;
  final double score;
  final int combo;
  final String stageName;
  final String? bossName;
  final double bossHp;
  HudState({
    required this.tails,
    required this.spirit,
    required this.spiritActive,
    required this.ofudaReady,
    required this.progress,
    required this.puzzles,
    required this.score,
    required this.combo,
    required this.stageName,
    this.bossName,
    this.bossHp = 0,
  });
}

class ActionButton {
  final String label;
  final String action;
  final bool secondary;
  ActionButton(this.label, this.action, [this.secondary = false]);
}

class MenuOverlay {
  final String kicker;
  final String title;
  final String copy;
  final List<ActionButton> actions;
  MenuOverlay(this.kicker, this.title, this.copy, this.actions);
}

class KitsuneGame extends FlameGame with KeyboardEvents {
  final wmod.GameConfig config;
  final AudioManager audio;
  final InputState input = InputState();
  final AssetLibrary library = AssetLibrary();

  late final Renderer renderer;
  wmod.World? gameWorld;

  String mode = "campaign";
  int stageIndex = 0;
  bool playing = false;
  bool paused = false;
  bool destroyed = false;

  double bestScore = 0;
  bool unlockedRush = false;
  double runScore = 0;
  wmod.Carry? carry;

  double gameTime = 0;

  final hud = ValueNotifier<HudState>(HudState(
    tails: 3, spirit: 0, spiritActive: false, ofudaReady: 1, progress: 0,
    puzzles: 0, score: 0, combo: 0, stageName: "TORII TRANSIT",
  ));
  final overlay = ValueNotifier<MenuOverlay?>(null);
  final toastMsg = ValueNotifier<String?>(null);
  Timer? _toastTimer;

  KitsuneGame(this.config, this.audio) {
    renderer = Renderer(library);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    initEnemyStats();
    await library.loadManifest();
    await preloadGameAssets(library);
    await createStage(0);
    showStartOverlay();
  }

  void showStartOverlay() {
    final actions = [
      ActionButton("Start Mission", "campaign"),
      if (unlockedRush) ActionButton("Spirit Rush", "rush", true),
    ];
    overlay.value = MenuOverlay(
      "TEN YOKAI DISTRICTS",
      "Ninefold Neon",
      "Cross ten triple-length districts, solve unique ability seals, master ten "
      "alternating kitsune forms, and defeat the Amaterasu Engine."
      "${bestScore > 0 ? "\nBest ${bestScore.round()}" : ""}",
      actions,
    );
  }

  Future<void> createStage(int index, [wmod.Carry? inherited]) async {
    stageIndex = index;
    audio.setStage(index);
    if (library.stage != index) {
      showLoadingOverlay("STAGE ${index + 1} / ${LEVELS.length}", LEVELS[index].name,
          "Calling this district's yokai…");
      await loadStageAssets(library, index);
    }
    final level = LEVELS[index];
    gameWorld = wmod.World(
      level: level,
      mode: mode,
      config: config,
      onEvent: eventHandler,
    );
    if (inherited != null) {
      gameWorld!.player.tails = inherited.tails;
      gameWorld!.player.maxTails = inherited.tails;
      gameWorld!.player.spirit = inherited.spirit;
    }
    showToast("${level.skinName} · ${level.subtitle}");
  }

  void eventHandler(String type, Map<String, dynamic> data) {
    if (type == "sound") {
      audio.sfx(data["name"] as String, (data["amount"] as num?)?.toDouble() ?? 1);
    } else if (type == "toast") {
      showToast(data["text"] as String);
    } else if (type == "complete") {
      finishStage(data);
    }
  }

  Future<void> beginRun(String nextMode) async {
    mode = nextMode;
    stageIndex = 0;
    runScore = 0;
    carry = null;
    input.resetEdges();
    await createStage(0);
    playing = true;
    paused = false;
    overlay.value = null;
    await audio.unlock();
  }

  String stageRank(double value) {
    if (value > 14000) return "S";
    if (value > 9000) return "A";
    if (value > 5200) return "B";
    return "C";
  }

  void finishStage(Map<String, dynamic> result) {
    playing = false;
    runScore += (result["score"] as num).toDouble();
    carry = wmod.Carry(
      tails: gameWorld!.player.tails,
      spirit: gameWorld!.player.spirit,
    );
    final maxTails = (result["maxTails"] as num).toInt();
    final hitCount = (result["hitCount"] as num).toInt();
    final elapsed = (result["elapsed"] as num).toDouble();

    if (mode == "rush" && stageIndex < LEVELS.length - 1) {
      showToast("Stage ${stageIndex + 1} purified");
      Future.delayed(const Duration(milliseconds: 700), () async {
        if (destroyed) return;
        await createStage(stageIndex + 1, carry);
        playing = true;
        overlay.value = null;
      });
      return;
    }

    final finalStage = stageIndex == LEVELS.length - 1;
    if (finalStage) {
      unlockedRush = true;
      bestScore = max(bestScore, runScore);
      overlay.value = MenuOverlay(
        mode == "rush" ? "SPIRIT RUSH COMPLETE" : "AMATERASU ENGINE SEALED",
        "Rank ${stageRank(runScore)}",
        "${runScore.round()} points\n${elapsed.floor() ~/ 60}:${(elapsed.floor() % 60).toString().padLeft(2, "0")} · $maxTails/9 tails · $hitCount hits",
        [ActionButton("Play Again", "campaign"), ActionButton("Spirit Rush", "rush", true)],
      );
    } else {
      overlay.value = MenuOverlay(
        "STAGE ${stageIndex + 1} / ${LEVELS.length} COMPLETE",
        "Rank ${stageRank((result["score"] as num).toDouble())}",
        "${(result["score"] as num).round()} points\n$maxTails/9 tails · $hitCount hits",
        [ActionButton("Next Stage", "next")],
      );
    }
  }

  void handleMenuAction(String action) {
    switch (action) {
      case "campaign":
        beginRun("campaign");
        break;
      case "rush":
        beginRun("rush");
        break;
      case "next":
        createStage(stageIndex + 1, carry).then((_) {
          playing = true;
          overlay.value = null;
        });
        break;
      case "resume":
        paused = false;
        playing = true;
        gameWorld?.setPaused(false);
        overlay.value = null;
        break;
      case "restart":
        createStage(stageIndex, carry).then((_) {
          paused = false;
          playing = true;
          overlay.value = null;
        });
        break;
      case "quit":
        playing = false;
        paused = false;
        gameWorld?.setPaused(false);
        showStartOverlay();
        break;
    }
  }

  void togglePause() {
    if (gameWorld == null || !playing) return;
    paused = !paused;
    playing = !paused;
    gameWorld?.setPaused(paused);
    if (paused) {
      overlay.value = MenuOverlay(
        LEVELS[stageIndex].name,
        "Paused",
        "The spirit fire is waiting.",
        [
          ActionButton("Resume", "resume"),
          ActionButton("Restart Stage", "restart", true),
          ActionButton("Quit to Menu", "quit", true),
        ],
      );
    }
  }

  void showToast(String text) {
    toastMsg.value = text;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!destroyed) toastMsg.value = null;
    });
  }

  void showLoadingOverlay(String kicker, String title, String copy) {
    overlay.value = MenuOverlay(kicker, title, copy, const []);
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent || event is KeyUpEvent) {
      input.onKeyEvent(event);
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      togglePause();
    }
    return KeyEventResult.handled;
  }

  @override
  void update(double dt) {
    super.update(dt);
    gameTime += dt;
    if (gameWorld != null && playing && !paused) {
      gameWorld!.update(dt, input);
    }
    if (gameWorld != null) {
      final s = gameWorld!.snapshot();
      hud.value = HudState(
        tails: s.tails,
        spirit: s.spirit,
        spiritActive: s.spiritActive > 0,
        ofudaReady: s.ofudaReady,
        progress: s.progress,
        puzzles: s.puzzlesSolved,
        score: s.score,
        combo: s.combo,
        stageName: LEVELS[stageIndex].name,
        bossName: s.bossName,
        bossHp: s.bossHp,
      );
    }
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    renderer.canvas = canvas;
    renderer.resize(size.x, size.y);
    if (gameWorld != null) {
      try {
        gameWorld!.render(renderer, gameTime, input);
      } catch (error, stackTrace) {
        developer.log(
          'World render failed: $error',
          name: 'kitsune.game',
          level: 1000,
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        renderer.end();
      }

      // --- TEMP DEBUG: shows where the engine places the player ---
      final p = gameWorld!;
      final scale = size.y / 540;
      final worldWidth = renderer.worldWidth;
      final camX = p.cameraX(worldWidth);
      final offX = (size.x - worldWidth * scale) / 2;
      final sx = offX + scale * (p.player.x - camX);
      final sy = scale * p.player.y;
      canvas.drawCircle(
        ui.Offset(sx, sy),
        18,
        ui.Paint()..color = const ui.Color(0xFFFFFF00),
      );
      developer.log(
        'DBG player world=(${p.player.x.toStringAsFixed(1)},${p.player.y.toStringAsFixed(1)}) '
        'screen=(${sx.toStringAsFixed(1)},${sy.toStringAsFixed(1)}) size=(${size.x},${size.y}) '
        'scale=$scale worldWidth=$worldWidth camX=${camX.toStringAsFixed(1)}',
        name: 'kitsune.debug',
      );
      // --- end TEMP DEBUG ---
    }
  }
}
