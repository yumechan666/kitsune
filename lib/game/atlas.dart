import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class Frame {
  final String name;
  final Rect source;
  final Rect content;
  final Offset anchor;
  Frame(this.name, this.source, this.content, this.anchor);

  factory Frame.fromJson(Map<String, dynamic> json) {
    final src = _rect(json["source"]);
    final content = json["content"] != null ? _rect(json["content"]) : src;
    final anchorJson = json["anchor"];
    final anchor = anchorJson != null
        ? Offset(anchorJson["x"].toDouble(), anchorJson["y"].toDouble())
        : Offset(src.left + src.width / 2, src.top + src.height);
    return Frame(json["name"] as String, src, content, anchor);
  }
}

Rect _rect(dynamic json) {
  final m = json as Map<String, dynamic>;
  return Rect.fromLTWH(
    m["x"].toDouble(),
    m["y"].toDouble(),
    m["w"].toDouble(),
    m["h"].toDouble(),
  );
}

class Atlas {
  final List<Frame> framesList;
  final Map<String, Frame> frames;
  final Map<String, List<Frame>> animations;
  Atlas(this.framesList, this.frames, this.animations);
}

class AnimEntry {
  final ui.Image? image;
  final List<Frame> frames;
  final String key;
  AnimEntry(this.image, this.frames, this.key);
}

class FrameEntry {
  final ui.Image? image;
  final Frame frame;
  final String key;
  FrameEntry(this.image, this.frame, this.key);
}

const PLAYER_ANIMATIONS = [
  "idle", "run", "jump_up", "fall", "land", "spawn", "tail_gain", "checkpoint_revive",
  "dash", "wall_slide", "wall_jump", "tail_glide", "shoot", "charge", "charged_release",
  "ofuda_throw", "recoil_hit", "damage", "defeat", "air_dash", "spirit_transform",
  "feral_idle", "feral_run", "feral_leap", "spirit_return", "claw_combo", "pounce",
  "rising_slash", "landing_smash", "feral_hit", "kitsunebi", "charged_shot",
  "ofuda_explosion", "dash_trail", "shadow_clone", "tail_volley", "transform_burst", "claw_arc",
];

class AssetLibrary {
  final Map<String, ui.Image?> images = {};
  final Map<String, Atlas> sheets = {};
  final Map<String, AnimEntry> animations = {};
  final Map<String, FrameEntry> frames = {};
  int stage = -1;

  Map<String, String> manifest = {};
  final Set<String> _reportedIssues = {};

  void _reportOnce(String id, String message, {Object? error, StackTrace? stackTrace}) {
    if (!_reportedIssues.add(id)) return;
    developer.log(
      message,
      name: 'kitsune.assets',
      level: error == null ? 900 : 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> loadManifest() async {
    final text = await rootBundle.loadString("assets/asset_manifest.json");
    manifest = (json.decode(text) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));
  }

  String _baseName(String key) {
    final rel = manifest[key] ?? "";
    final file = rel.split("/").last;
    return file.replaceAll(RegExp(r"\.webp(\?.*)?$"), "");
  }

  Future<void> loadKey(String key) async {
    if (images.containsKey(key)) return;
    images[key] = null; // mark as attempted so we don't retry.

    final base = _baseName(key);
    if (base.isEmpty) {
      _reportOnce('manifest:$key', 'No asset manifest entry for key "$key".');
      return;
    }

    final imagePath = "assets/images/$base.webp";
    final jsonPath = "assets/json/$base.frames.json";

    try {
      final data = await rootBundle.load(imagePath);
      final bytes = data.buffer.asUint8List();
      final completer = Completer<ui.Image?>();
      ui.decodeImageFromList(bytes, (result) => completer.complete(result));
      images[key] = await completer.future;
    } catch (error, stackTrace) {
      images[key] = null;
      _reportOnce(
        'image:$key',
        'Failed to load image for "$key" from "$imagePath".',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final image = images[key];
    if (image == null) return;
    final isSheet = base.contains("transparent") || base.contains("tiles");
    if (!isSheet) return;

    var parsed = false;
    try {
      final text = await rootBundle.loadString(jsonPath);
      final data = json.decode(text) as Map<String, dynamic>;
      final atlas = _parseAtlas(data);
      sheets[key] = atlas;
      for (final frame in atlas.framesList) {
        frames[frame.name] = FrameEntry(image, frame, key);
      }
      for (final entry in atlas.animations.entries) {
        animations[entry.key] = AnimEntry(image, entry.value, key);
      }
      parsed = true;
    } catch (error, stackTrace) {
      // Many bundled sheets currently have no matching sidecar. Keep the image
      // usable with a best-effort grid, but make the missing/invalid metadata
      // visible in the Flutter debug console.
      _reportOnce(
        'frames:$key',
        'Could not load atlas metadata for "$key" from "$jsonPath"; '
        'generating fallback frames from the image.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!parsed) _autoGenerate(key, base, image);
  }

  int _stageOf(String base) {
    final match = RegExp(r"(\d+)").firstMatch(base);
    return match != null ? int.parse(match.group(1)!) : 1;
  }

  void _autoGenerate(String key, String base, ui.Image image) {
    final normalizedBase = base.toUpperCase();
    const cols = 5;
    final frameW = image.width / cols;
    final rows = (frameW > 0 ? (image.height / frameW).round() : 1).clamp(1, 64);
    final frameH = image.height / rows;
    final framesList = <Frame>[];
    final frameMap = <String, Frame>{};
    var index = 0;
    for (var r = 0; r < rows; r += 1) {
      for (var c = 0; c < cols; c += 1) {
        final x = c * frameW;
        final y = r * frameH;
        final rect = Rect.fromLTWH(x, y, frameW, frameH);
        final name = "f$index";
        final f = Frame(name, rect, rect, Offset(frameW / 2, frameH));
        framesList.add(f);
        frameMap[name] = f;
        index += 1;
      }
    }
    final all = framesList;

    void addAnim(String name) => animations[name] = AnimEntry(image, all, key);
    void addFrame(String name, [int i = 0]) {
      final f = all[i % all.length];
      frames[name] = FrameEntry(image, f, key);
    }

    // Asset manifest keys are uppercase, but the filenames it points to are
    // lowercase. Match against a normalized filename so fallback atlases get
    // the same logical names the game renderer asks for.
    if (normalizedBase.contains("TILES")) {
      // The tile sheet has no sidecar metadata, so expose the whole image as a
      // single repeating "center" frame that the renderer stretches across each
      // platform. Without this the renderer falls back to the purple box.
      final center = Frame(
        "center",
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset(image.width / 2, image.height.toDouble()),
      );
      framesList.add(center);
      frameMap["center"] = center;
    } else if (normalizedBase.contains("ENEMIES")) {
      final stage = _stageOf(base);
      for (final k in const ["common_move", "common_attack", "rare_move", "rare_attack", "mini_move", "mini_attack"]) {
        addAnim("s${stage}_$k");
      }
    } else if (normalizedBase.contains("BOSSES")) {
      final stage = _stageOf(base);
      addAnim("s${stage}_boss_move");
      addAnim("s${stage}_boss_attack");
    } else if (normalizedBase.contains("PUZZLE")) {
      final stage = _stageOf(base);
      const names = ["beacon", "gate", "reward", "rune", "target"];
      for (var i = 0; i < names.length; i += 1) {
        final name = "s${stage}_${names[i]}";
        addFrame(name, i);
        animations[name] = AnimEntry(image, [all[i % all.length]], key);
      }
    } else if (normalizedBase.contains("OBJECT_ATLAS")) {
      const names = [
        "checkpoint_lantern", "roof_spike", "ofuda_mine",
        "tail_pickup", "spirit_shard",
      ];
      for (var i = 0; i < names.length; i += 1) {
        addFrame(names[i], i);
      }
    } else if (normalizedBase.contains("FX_SHEET")) {
      const animNames = [
        "kitsunebi", "charged_shot", "ofuda_explosion", "dash_trail",
        "shadow_clone", "tail_volley", "transform_burst", "claw_arc",
        "hit_sparks", "robot_explosion", "tail_pickup_fx", "spirit_shard_fx",
        "kasa_bolt", "lantern_bomb", "homing_missile",
      ];
      for (final k in animNames) {
        addAnim(k);
      }
      // Enemy projectiles are drawn with drawStatic, so they also need a
      // single-frame entry in the frames map.
      const staticNames = [
        "kasa_bolt", "lantern_bomb", "homing_missile",
        "hit_sparks", "robot_explosion", "tail_pickup_fx", "spirit_shard_fx",
      ];
      for (var i = 0; i < staticNames.length; i += 1) {
        addFrame(staticNames[i], i + 3);
      }
    }

    final isSkin = normalizedBase.contains("AKARI") || RegExp(r"SKIN_\d+_").hasMatch(normalizedBase);
    final isPrimarySkinSheet = normalizedBase.contains("BASE_A") || normalizedBase.contains("MASTER");
    if (isSkin && isPrimarySkinSheet) {
      for (final name in PLAYER_ANIMATIONS) addAnim(name);
    }

    sheets[key] = Atlas(framesList, frameMap, {});
  }

  Atlas _parseAtlas(Map<String, dynamic> json) {
    final frameList = (json["frames"] as List)
        .map((e) => Frame.fromJson(e as Map<String, dynamic>))
        .toList();
    final animMap = <String, List<Frame>>{};
    if (json["animations"] is List) {
      for (final a in json["animations"] as List) {
        final am = a as Map<String, dynamic>;
        animMap[am["name"] as String] =
            (am["frames"] as List).map((e) => Frame.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    final frameMap = {for (final f in frameList) f.name: f};
    return Atlas(frameList, frameMap, animMap);
  }

  void addCompactSkinAliases() {
    void alias(String name, String fallback) {
      if (!animations.containsKey(name) && animations.containsKey(fallback)) {
        animations[name] = animations[fallback]!;
      }
    }

    for (final name in ["jump_up", "fall", "dash", "wall_slide", "wall_jump", "tail_glide", "air_dash"]) {
      alias(name, "run");
    }
    for (final name in ["land", "spawn", "tail_gain", "checkpoint_revive", "recoil_hit", "damage", "defeat"]) {
      alias(name, "idle");
    }
    for (final name in ["shoot", "charge", "charged_release", "ofuda_throw"]) {
      alias(name, "attack_master");
    }
    for (final name in [
      "spirit_transform", "feral_idle", "feral_run", "feral_leap", "spirit_return",
      "claw_combo", "pounce", "rising_slash", "landing_smash", "feral_hit"
    ]) {
      alias(name, "feral_master");
    }
    alias("charged_shot", "kitsunebi");
    alias("ofuda_explosion", "transform_burst");
    alias("shadow_clone", "transform_burst");
    alias("tail_volley", "kitsunebi");
  }

  Future<void> loadKeys(List<String> keys) async {
    for (final key in keys) {
      await loadKey(key);
    }
  }
}

const CORE_KEYS = [
  "STAGE1_TILES", "STAGE2_TILES", "STAGE3_TILES",
  "OBJECT_ATLAS", "FX_SHEET_C",
];

List<String> fullSkinKeys(String id) => [
  "${id}_BASE_A", "${id}_BASE_B", "${id}_MOBILITY", "${id}_COMBAT", "${id}_STATE",
  "${id}_FERAL_A", "${id}_FERAL_B", "${id}_FERAL_C", "${id}_FX_A", "${id}_FX_B",
];

List<String> skinKeys(int index) {
  if (index == 0) {
    return [
      "AKARI_BASE_A", "AKARI_BASE_B", "AKARI_MOBILITY", "AKARI_COMBAT", "AKARI_STATE",
      "AKARI_FERAL_A", "AKARI_FERAL_B", "AKARI_FERAL_C", "FX_SHEET_A", "FX_SHEET_B",
    ];
  }
  final id = "SKIN_${(index + 1).toString().padLeft(2, "0")}";
  return index <= 3 ? fullSkinKeys(id) : ["${id}_MASTER", "${id}_FX"];
}

List<String> stageKeys(int index) {
  final id = (index + 1).toString().padLeft(2, "0");
  return ["WORLD_$id", "WORLD_${id}_ENEMIES", "WORLD_${id}_BOSSES", "WORLD_${id}_PUZZLE", ...skinKeys(index)];
}

Future<AssetLibrary> preloadGameAssets(AssetLibrary library) async {
  final keys = [...CORE_KEYS, ...stageKeys(0)];
  await library.loadKeys(keys);
  library.stage = 0;
  return library;
}

Future<void> loadStageAssets(AssetLibrary library, int index) async {
  if (library.stage == index) return;
  await library.loadKeys(stageKeys(index));
  library.addCompactSkinAliases();
  library.stage = index;
}
