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
import 'package:kitsune/game/save_data.dart';
import 'package:kitsune/game/world.dart' as wmod;

class HudState {
  final int tails;
  final double spirit;
  final bool spiritActive;
  final double ofudaReady;
  final double progress;
  final double score;
  final String stageName;
  final String? bossName;
  final double bossHp;

  // Values are quantized so the notifier only fires when the HUD visibly changes.
  HudState({
    required this.tails,
    required double spirit,
    required this.spiritActive,
    double ofudaReady = 1,
    required double progress,
    required double score,
    required this.stageName,
    this.bossName,
    double bossHp = 0,
  }) : spirit = spirit.roundToDouble(),
       ofudaReady = (ofudaReady.clamp(0.0, 1.0) * 20).round() / 20,
       progress = (progress * 300).round() / 300,
       score = score.roundToDouble(),
       bossHp = (bossHp * 200).round() / 200;

  @override
  bool operator ==(Object other) =>
      other is HudState &&
      other.tails == tails &&
      other.spirit == spirit &&
      other.spiritActive == spiritActive &&
      other.ofudaReady == ofudaReady &&
      other.progress == progress &&
      other.score == score &&
      other.stageName == stageName &&
      other.bossName == bossName &&
      other.bossHp == bossHp;

  @override
  int get hashCode => Object.hash(
    tails,
    spirit,
    spiritActive,
    ofudaReady,
    progress,
    score,
    stageName,
    bossName,
    bossHp,
  );
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
  // Prints player position, state and any unexpected jump to the console.
  static const bool positionLogging = false;

  final wmod.GameConfig config;
  final AudioManager audio;
  final InputState input = InputState();
  final AssetLibrary library = AssetLibrary();

  late final Renderer renderer;
  wmod.World? gameWorld;

  String mode = "campaign";
  int stageIndex = 0;
  bool playing = false;
  bool playerPaused = false;
  bool destroyed = false;

  double bestScore = 0;
  bool unlockedRush = false;
  double runScore = 0;
  wmod.Carry? carry;

  // Null = follow the stage's own skin, like the JS game.
  int? skinOverride;

  double gameTime = 0;

  // A run that can be continued from the main menu. Only the start of the
  // saved stage is kept, so the player re-enters it with the carried tails.
  RunSave? savedRun;
  bool _inRun = false;
  bool _saveLoaded = false;
  double _autosaveIn = 5;
  bool tutorialSeen = false;
  int volumeLevel = 0;
  final ValueNotifier<int> volumeNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> tutorialOpen = ValueNotifier<bool>(false);
  bool _pausedForTutorial = false;

  final hud = ValueNotifier<HudState>(
    HudState(
      tails: 9,
      spirit: 0,
      spiritActive: false,
      progress: 0,
      score: 0,
      stageName: "TORII TRANSIT",
    ),
  );
  final overlay = ValueNotifier<MenuOverlay?>(null);
  final toastMsg = ValueNotifier<String?>(null);
  // Flips to true once assets are loaded; the launch splash waits for it.
  final assetsReady = ValueNotifier<bool>(false);
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
    await _restoreSave();
    await createStage(0);
    showStartOverlay();
    if (!tutorialSeen) openTutorial();
    assetsReady.value = true;
  }

  Future<void> _restoreSave() async {
    final save = await SaveData.load();
    bestScore = save.bestScore;
    unlockedRush = save.unlockedRush;
    tutorialSeen = save.tutorialSeen;
    volumeLevel = save.volumeLevel;
    volumeNotifier.value = volumeLevel;
    savedRun = save.run;
    audio.setLevel(volumeLevel);
    _saveLoaded = true;
  }

  // Records the stage the player is in right now, with the tails and spirit
  // they have at this moment, so a sudden exit keeps the progress.
  void _snapshotLiveRun() {
    final world = gameWorld;
    if (!_inRun || world == null || !(playing || playerPaused)) return;
    savedRun = RunSave(
      mode: mode,
      stageIndex: stageIndex,
      runScore: runScore,
      carryTails: world.player.tails.clamp(1, 9),
      carrySpirit: world.player.spirit,
    );
  }

  Future<void> persist() {
    // Writing before the saved data is read would overwrite it with defaults.
    if (!_saveLoaded) return Future.value();
    _snapshotLiveRun();
    return SaveData(
      bestScore: bestScore,
      unlockedRush: unlockedRush,
      tutorialSeen: tutorialSeen,
      volumeLevel: volumeLevel,
      run: savedRun,
    ).write();
  }

  void _rememberRun(int index, {wmod.Carry? entering}) {
    if (!_inRun) return;
    savedRun = RunSave(
      mode: mode,
      stageIndex: index,
      runScore: runScore,
      carryTails: entering?.tails,
      carrySpirit: entering?.spirit,
    );
  }

  void showStartOverlay() {
    final run = savedRun;
    final actions = [
      if (run != null) ActionButton("Lanjutkan", "continue"),
      ActionButton(run != null ? "Mulai Baru" : "Mulai Misi", "campaign", run != null),
      ActionButton("Pilih Tema", "themes", true),
      if (unlockedRush) ActionButton("Spirit Rush", "rush", true),
      ActionButton("Reset Progres", "reset", true),
    ];
    overlay.value = MenuOverlay(
      "TEN YOKAI DISTRICTS",
      "Kitsune Neon Exorcist",
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
      showLoadingOverlay(
        "STAGE ${index + 1} / ${LEVELS.length}",
        LEVELS[index].name,
        "Calling this district's yokai…",
      );
    }
    await loadStageAssets(library, index, skin: skinOverride);
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
    _rememberRun(index, entering: inherited);
    if (_inRun) persist();
    showToast("${level.skinName} · ${level.subtitle}");
  }

  void eventHandler(String type, Map<String, dynamic> data) {
    if (type == "sound") {
      audio.sfx(
        data["name"] as String,
        (data["amount"] as num?)?.toDouble() ?? 1,
      );
    } else if (type == "toast") {
      showToast(data["text"] as String);
    } else if (type == "complete") {
      finishStage(data);
    } else if (type == "log") {
      // Prefixed so it can be filtered: adb logcat | findstr KITSUNE
      if (positionLogging) debugPrint("[KITSUNE] stage=${stageIndex + 1} ${data["text"]}");
    }
  }

  Future<void> beginRun(String nextMode, [int startStage = 0]) async {
    mode = nextMode;
    stageIndex = startStage;
    runScore = 0;
    carry = null;
    _inRun = true;
    input.resetEdges();
    await createStage(startStage);
    playing = true;
    playerPaused = false;
    overlay.value = null;
    await audio.unlock();
    audio.resumeBgm();
  }

  // Same formula as the JS game: tails and speed reward, hits and time cost.
  String stageRank({
    required double score,
    required int maxTails,
    required int hitCount,
    required double elapsed,
  }) {
    final value = score + maxTails * 220 - hitCount * 180 - elapsed * 8;
    if (value > 14000) return "S";
    if (value > 9000) return "A";
    if (value > 5200) return "B";
    return "C";
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    if (state != AppLifecycleState.resumed) {
      input.releaseAll();
      // Leaving the app can end the process without another chance to save.
      persist();
    }
  }

  @override
  void onDispose() {
    destroyed = true;
    persist();
    _toastTimer?.cancel();
    audio.destroy();
    super.onDispose();
  }

  void finishStage(Map<String, dynamic> result) {
    audio.sfx("win");
    playing = false;
    runScore += (result["score"] as num).toDouble();
    carry = wmod.Carry(
      tails: gameWorld!.player.tails,
      spirit: gameWorld!.player.spirit,
    );
    final maxTails = (result["maxTails"] as num).toInt();
    final hitCount = (result["hitCount"] as num).toInt();
    final elapsed = (result["elapsed"] as num).toDouble();

    if (stageIndex < LEVELS.length - 1) {
      // Save the next stage as the resume point, so a crash after this
      // completion still continues from the following stage.
      _rememberRun(stageIndex + 1, entering: carry);
      persist();
    }

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
      _inRun = false;
      savedRun = null;
      persist();
      overlay.value = MenuOverlay(
        mode == "rush" ? "SPIRIT RUSH COMPLETE" : "AMATERASU ENGINE SEALED",
        "Rank ${stageRank(score: runScore, maxTails: maxTails, hitCount: hitCount, elapsed: elapsed)}",
        "${runScore.round()} points\n${elapsed.floor() ~/ 60}:${(elapsed.floor() % 60).toString().padLeft(2, "0")} · $maxTails/9 tails · $hitCount hits",
        [
          ActionButton("Main Lagi", "campaign"),
          ActionButton("Spirit Rush", "rush", true),
        ],
      );
    } else {
      overlay.value = MenuOverlay(
        "STAGE ${stageIndex + 1} / ${LEVELS.length} COMPLETE",
        "Rank ${stageRank(score: (result["score"] as num).toDouble(), maxTails: maxTails, hitCount: hitCount, elapsed: elapsed)}",
        "${(result["score"] as num).round()} points\n$maxTails/9 tails · $hitCount hits",
        [ActionButton("Stage Berikutnya", "next")],
      );
    }
  }

  void handleMenuAction(String action) {
    audio.sfx("click");
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
        playerPaused = false;
        playing = true;
        gameWorld?.setPaused(false);
        audio.resumeBgm();
        overlay.value = null;
        break;
      case "restart":
        createStage(stageIndex, carry).then((_) {
          playerPaused = false;
          playing = true;
          overlay.value = null;
        });
        break;
      case "quit":
        _snapshotLiveRun();
        playing = false;
        playerPaused = false;
        gameWorld?.setPaused(false);
        audio.pauseBgm();
        _inRun = false;
        persist();
        showStartOverlay();
        break;
      case "continue":
        continueRun();
        break;
      case "reset":
        overlay.value = MenuOverlay(
          "HAPUS PROGRES?",
          "Yakin?",
          "Run yang tersimpan, skor terbaik, dan Spirit Rush akan dihapus. Pengaturan suara dan tutorial tetap disimpan.",
          [
            ActionButton("Ya, Hapus", "reset_confirm"),
            ActionButton("Batal", "start_menu", true),
          ],
        );
        break;
      case "reset_confirm":
        resetProgress();
        showStartOverlay();
        break;
      case "start_menu":
        showStartOverlay();
        break;
      case "themes":
        // Every district is open from the start.
        overlay.value = MenuOverlay(
          "PILIH TEMA",
          "10 Distrik",
          "Semua tema terbuka. Pilih distrik untuk memulai misi dari sana.",
          [
            for (var i = 0; i < LEVELS.length; i += 1)
              ActionButton(
                "${i + 1}. ${LEVELS[i].name}",
                "theme_$i",
                i != stageIndex,
              ),
            ActionButton("Kembali", "start_menu", true),
          ],
        );
        break;
      default:
        if (action.startsWith("theme_")) {
          final index = int.tryParse(action.substring(6));
          if (index != null && index >= 0 && index < LEVELS.length) {
            beginRun("campaign", index);
          }
        }
    }
  }

  Future<void> continueRun() async {
    final run = savedRun;
    if (run == null) return;
    mode = run.mode;
    runScore = run.runScore;
    // Every fresh launch starts with full tails; only the stage is kept.
    carry = wmod.Carry(tails: 9, spirit: run.carrySpirit ?? 0);
    _inRun = true;
    input.resetEdges();
    await createStage(run.stageIndex, carry);
    playing = true;
    playerPaused = false;
    overlay.value = null;
    await audio.unlock();
    audio.resumeBgm();
  }

  void resetProgress() {
    bestScore = 0;
    unlockedRush = false;
    savedRun = null;
    _inRun = false;
    persist();
    showToast("Progres dihapus");
  }

  void cycleVolume() {
    volumeLevel = (volumeLevel + 1) % AudioManager.levelMultipliers.length;
    volumeNotifier.value = volumeLevel;
    audio.setLevel(volumeLevel);
    showToast(const ["Volume penuh", "Volume sedang", "Suara mati"][volumeLevel]);
    persist();
  }

  // Shown automatically on the first launch and from the HUD "?" button. Opening
  // it during a stage pauses the game without showing the pause menu.
  void openTutorial() {
    if (tutorialOpen.value) return;
    if (gameWorld != null && playing && !playerPaused) {
      _pausedForTutorial = true;
      playerPaused = true;
      playing = false;
      gameWorld?.setPaused(true);
      audio.pauseBgm();
    }
    tutorialOpen.value = true;
  }

  void closeTutorial() {
    if (!tutorialOpen.value) return;
    tutorialOpen.value = false;
    if (!tutorialSeen) {
      tutorialSeen = true;
      persist();
    }
    if (_pausedForTutorial) {
      _pausedForTutorial = false;
      playerPaused = false;
      playing = true;
      gameWorld?.setPaused(false);
      audio.resumeBgm();
    }
  }

  void togglePause() {
    if (gameWorld == null || !playing) return;
    playerPaused = !playerPaused;
    playing = !playerPaused;
    gameWorld?.setPaused(playerPaused);
    if (!playerPaused) {
      audio.resumeBgm();
      audio.sfx("resume");
      overlay.value = null;
    }
    if (playerPaused) {
      audio.pauseBgm();
      audio.sfx("pause");
      overlay.value = MenuOverlay(
        LEVELS[stageIndex].name,
        "Jeda",
        "Api roh menunggumu.",
        [
          ActionButton("Lanjutkan", "resume"),
          ActionButton("Ulangi Stage", "restart", true),
          ActionButton("Kembali ke Menu", "quit", true),
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

  int get currentSkinIndex => library.skin;

  Future<void> setSkin(int index) async {
    if (index == library.skin || index < 0 || index >= SKIN_NAMES.length) return;
    skinOverride = index;
    await loadSkinAssets(library, index);
    audio.sfx("skin_change");
    showToast(SKIN_NAMES[index]);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (tutorialOpen.value) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.escape)) {
        closeTutorial();
      }
      return KeyEventResult.handled;
    }
    final menu = overlay.value;
    if (menu != null &&
        event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      if (menu.actions.isNotEmpty) handleMenuAction(menu.actions.first.action);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent || event is KeyUpEvent) {
      input.onKeyEvent(event);
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      togglePause();
    }
    return KeyEventResult.handled;
  }

  @override
  void update(double dt) {
    super.update(dt);
    gameTime += dt;
    if (gameWorld != null && playing && !playerPaused) {
      // Same clamp as the JS loop so a hitch can't teleport the player.
      gameWorld!.update(dt.clamp(0.001, 0.033), input);
      _autosaveIn -= dt;
      if (_autosaveIn <= 0) {
        _autosaveIn = 5;
        unawaited(persist());
      }
    }
    if (gameWorld != null) {
      final s = gameWorld!.snapshot();
      hud.value = HudState(
        tails: s.tails,
        spirit: s.spirit,
        spiritActive: s.spiritActive > 0,
        ofudaReady: s.ofudaReady,
        progress: s.progress,
        score: s.score,
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
    }
  }
}
