import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
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
  "idle",
  "run",
  "jump_up",
  "fall",
  "land",
  "spawn",
  "tail_gain",
  "checkpoint_revive",
  "dash",
  "wall_slide",
  "wall_jump",
  "tail_glide",
  "shoot",
  "charge",
  "charged_release",
  "ofuda_throw",
  "recoil_hit",
  "damage",
  "defeat",
  "air_dash",
  "spirit_transform",
  "feral_idle",
  "feral_run",
  "feral_leap",
  "spirit_return",
  "claw_combo",
  "pounce",
  "rising_slash",
  "landing_smash",
  "feral_hit",
  "kitsunebi",
  "charged_shot",
  "ofuda_explosion",
  "dash_trail",
  "shadow_clone",
  "tail_volley",
  "transform_burst",
  "claw_arc",
];

class AssetLibrary {
  final Map<String, ui.Image?> images = {};
  final Map<String, Atlas> sheets = {};
  final Map<String, AnimEntry> animations = {};
  final Map<String, FrameEntry> frames = {};
  int stage = -1;
  int skin = 0;

  Map<String, String> manifest = {};
  final Set<String> _reportedIssues = {};

  void _reportOnce(
    String id,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_reportedIssues.add(id)) return;
    developer.log(
      message,
      name: 'kitsune.assets',
      level: error == null ? 900 : 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Precomputed frame layout per sheet file: [left, top, right, bottom,
  // anchorX, anchorY] for each frame, and [left, top, right, bottom] for tile
  // crops. Regenerate with test/frame_cache_test.dart after changing art.
  static const String frameCachePath = "assets/json/auto_frames.json";
  final Map<String, List<List<double>>> _frameCache = {};
  final Map<String, List<double>> _tileCache = {};
  final Set<String> _analyzed = {};
  final Map<String, Future<ui.Image?>> _decoding = {};
  // Off when regenerating the cache, so every sheet is measured again.
  bool useFrameCache = true;

  Future<void> loadManifest() async {
    final text = await rootBundle.loadString("assets/asset_manifest.json");
    manifest = (json.decode(text) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as String),
    );
    try {
      final cache =
          json.decode(await rootBundle.loadString(frameCachePath))
              as Map<String, dynamic>;
      List<double> nums(dynamic list) => [
        for (final n in list as List) (n as num).toDouble(),
      ];
      (cache["frames"] as Map<String, dynamic>).forEach((base, frames) {
        _frameCache[base] = [for (final f in frames as List) nums(f)];
      });
      (cache["tiles"] as Map<String, dynamic>).forEach((base, crop) {
        _tileCache[base] = nums(crop);
      });
    } catch (error) {
      _reportOnce(
        'frame-cache',
        'No precomputed frame cache; frames will be measured while loading.',
        error: error,
      );
    }
  }

  // Frame layouts this library had to measure itself, in the cache file format.
  Map<String, dynamic> exportFrameCache() {
    final frames = <String, dynamic>{};
    final tiles = <String, dynamic>{};
    for (final entry in sheets.entries) {
      final base = _baseName(entry.key);
      if (!_analyzed.contains(base)) continue;
      final atlas = entry.value;
      final center = atlas.frames["center"];
      if (center != null) {
        final r = center.content;
        tiles[base] = [r.left, r.top, r.right, r.bottom];
        continue;
      }
      frames[base] = [
        for (final f in atlas.framesList)
          [
            f.content.left,
            f.content.top,
            f.content.right,
            f.content.bottom,
            f.anchor.dx,
            f.anchor.dy,
          ],
      ];
    }
    return {"frames": frames, "tiles": tiles};
  }

  // Decoding is the other slow step; it runs for many sheets in parallel and
  // the result is picked up by loadKey.
  Future<ui.Image?> _decode(String key) {
    return _decoding.putIfAbsent(key, () async {
      final base = _baseName(key);
      if (base.isEmpty) return null;
      final imagePath = "assets/images/$base.webp";
      try {
        final data = await rootBundle.load(imagePath);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      } catch (error, stackTrace) {
        _reportOnce(
          'image:$key',
          'Failed to load image for "$key" from "$imagePath".',
          error: error,
          stackTrace: stackTrace,
        );
        return null;
      }
    });
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

    final jsonPath = "assets/json/$base.frames.json";

    images[key] = await _decode(key);
    // Only needed until the image is stored; a later reload decodes again.
    _decoding.remove(key);

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
        // Also register the first frame so drawStatic can find named items.
        if (entry.value.isNotEmpty && !frames.containsKey(entry.key)) {
          frames[entry.key] = FrameEntry(image, entry.value.first, key);
        }
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
    if (!parsed) await _autoGenerate(key, base, image);
  }

  int _stageOf(String base) {
    final match = RegExp(r"(\d+)").firstMatch(base);
    return match != null ? int.parse(match.group(1)!) : 1;
  }

  // Sheets without sidecar metadata are 5 columns wide and hold one animation
  // per row, in a fixed order per sheet type (see _rowNamesFor).
  Future<void> _autoGenerate(String key, String base, ui.Image image) async {
    final normalizedBase = base.toUpperCase();
    const cols = 5;
    final frameW = image.width / cols;
    final rows = (frameW > 0 ? (image.height / frameW).round() : 1).clamp(
      1,
      64,
    );
    final frameH = image.height / rows;
    final framesList = <Frame>[];
    final frameMap = <String, Frame>{};

    final isTiles = normalizedBase.contains("TILES");
    final rowNames = isTiles ? const <String>[] : _rowNamesFor(normalizedBase);
    // Characters stand on their feet: anchor each frame on the lowest opaque
    // pixel so the sprite touches the ground the physics stands on. Effects
    // keep the cell's bottom centre, which is what their draw calls expect.
    final footAnchored = !isTiles && _isCharacterSheet(normalizedBase);
    final isEnemySheet =
        normalizedBase.contains("ENEMIES") || normalizedBase.contains("BOSSES");

    // Reading pixels is the slow part of loading, so the results are shipped
    // precomputed in auto_frames.json and only recomputed for unknown sheets.
    final cached = useFrameCache ? _frameCache[base] : null;
    final useCache =
        footAnchored && cached != null && cached.length == rows * cols;
    final needPixels = (footAnchored && !useCache) ||
        (isTiles && !(useFrameCache && _tileCache.containsKey(base)));
    final pixels = needPixels ? await _readPixels(key, image) : null;
    if (needPixels && pixels != null) _analyzed.add(base);

    for (var r = 0; r < rows; r += 1) {
      final rowCells = <Rect>[
        for (var c = 0; c < cols; c += 1)
          Rect.fromLTWH(c * frameW, r * frameH, frameW, frameH),
      ];
      if (useCache) {
        for (var c = 0; c < cols; c += 1) {
          final v = cached[r * cols + c];
          final f = Frame(
            "f${r * cols + c}",
            rowCells[c],
            Rect.fromLTRB(v[0], v[1], v[2], v[3]),
            Offset(v[4], v[5]),
          );
          framesList.add(f);
          frameMap[f.name] = f;
        }
        continue;
      }
      final bodies = footAnchored && pixels != null
          ? [for (final cell in rowCells) _bodyRect(pixels, image.width, cell)]
          : rowCells;
      final anchors = footAnchored && pixels != null
          ? _footAnchors(pixels, image.width, rowCells, bodies)
          : [for (final cell in rowCells) Offset(cell.center.dx, cell.bottom)];
      for (var c = 0; c < cols; c += 1) {
        final name = "f${r * cols + c}";
        // Nothing of a character belongs below its soles; whatever is there is
        // glow or spill from the next row and would show through the floor.
        // Enemy attack art (beams, arcs) floats beside the body inside the
        // cell, so enemies keep the full cell width.
        final content = footAnchored
            ? Rect.fromLTRB(
                isEnemySheet ? rowCells[c].left : bodies[c].left,
                bodies[c].top,
                isEnemySheet ? rowCells[c].right : bodies[c].right,
                min(bodies[c].bottom, anchors[c].dy + 2),
              )
            : bodies[c];
        final f = Frame(name, rowCells[c], content, anchors[c]);
        framesList.add(f);
        frameMap[name] = f;
      }
    }
    final all = framesList;

    List<Frame> rowFrames(int r) =>
        all.sublist(r * cols, min((r + 1) * cols, all.length));
    void addRowAnim(String name, int r) {
      if (r * cols >= all.length) return;
      animations[name] = AnimEntry(image, rowFrames(r), key);
    }

    void addAnim(String name) => animations[name] = AnimEntry(image, all, key);
    void addFrame(String name, [int i = 0]) {
      final f = all[i % all.length];
      frames[name] = FrameEntry(image, f, key);
    }

    for (var r = 0; r < rowNames.length; r += 1) {
      addRowAnim(rowNames[r], r);
    }

    // Asset manifest keys are uppercase, but the filenames it points to are
    // lowercase. Match against a normalized filename so fallback atlases get
    // the same logical names the game renderer asks for.
    if (isTiles) {
      // The tile art has empty space above and below the roof. Cropping to the
      // opaque part makes the drawn roof top line up with the platform top
      // that the player's feet collide with.
      final known = useFrameCache ? _tileCache[base] : null;
      final bounds = known != null
          ? Rect.fromLTRB(known[0], known[1], known[2], known[3])
          : pixels != null
          ? _opaqueBounds(pixels, image.width, image.height)
          : null;
      final crop =
          bounds ??
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final center = Frame(
        "center",
        crop,
        crop,
        Offset(crop.center.dx, crop.bottom),
      );
      framesList.add(center);
      frameMap["center"] = center;
    } else if (normalizedBase.contains("PUZZLE")) {
      final stage = _stageOf(base);
      final p = stage.toString().padLeft(2, '0');
      const names = ["beacon", "gate", "reward", "rune", "target"];
      for (var i = 0; i < names.length; i += 1) {
        final name = "s${p}_${names[i]}";
        addFrame(name, i);
        animations[name] = AnimEntry(image, [all[i % all.length]], key);
      }
    } else if (normalizedBase.contains("OBJECT_ATLAS")) {
      const names = [
        "checkpoint_lantern",
        "roof_spike",
        "ofuda_mine",
        "tail_pickup",
        "spirit_shard",
      ];
      for (var i = 0; i < names.length; i += 1) {
        addFrame(names[i], i);
        animations[names[i]] = AnimEntry(image, [all[i % all.length]], key);
      }
    } else if (normalizedBase.contains("FX_SHEET_C")) {
      // Core fallbacks for player effects a skin may not provide; skin sheets
      // loaded afterwards replace them with their own rows.
      for (final k in const [
        "kitsunebi",
        "charged_shot",
        "ofuda_explosion",
        "shadow_clone",
        "tail_volley",
        "transform_burst",
        "claw_arc",
      ]) {
        addRowAnim(k, 0);
      }
      addRowAnim("dash_trail", 2);
      addRowAnim("hit_sparks", 0);
      addRowAnim("robot_explosion", 1);
      addRowAnim("tail_pickup_fx", 2);
      addRowAnim("spirit_shard_fx", 3);
      for (final k in const ["kasa_bolt", "lantern_bomb", "homing_missile"]) {
        addAnim(k);
      }
      // Projectiles and FX also need frames entries for drawStatic lookups.
      const staticNames = [
        "kasa_bolt",
        "lantern_bomb",
        "homing_missile",
        "hit_sparks",
        "robot_explosion",
        "tail_pickup_fx",
        "spirit_shard_fx",
      ];
      for (var i = 0; i < staticNames.length; i += 1) {
        addFrame(staticNames[i], i + 3);
      }
    }

    sheets[key] = Atlas(framesList, frameMap, {});
  }

  // Row order of each generated sheet. Full skins split PLAYER_ANIMATIONS over
  // ten sheets in order, four rows each, except FERAL_C which has two.
  static const List<String> _skinSheetOrder = [
    "BASE_A",
    "BASE_B",
    "MOBILITY",
    "COMBAT",
    "STATE",
    "FERAL_A",
    "FERAL_B",
    "FERAL_C",
    "FX_A",
    "FX_B",
  ];
  static const List<int> _skinSheetRows = [4, 4, 4, 4, 4, 4, 4, 2, 4, 4];

  List<String> _rowNamesFor(String normalizedBase) {
    final name = normalizedBase.replaceAll("-TRANSPARENT", "");
    final p = _stageOf(name).toString().padLeft(2, '0');
    if (name.contains("ENEMIES")) {
      return [
        "s${p}_common_move",
        "s${p}_common_attack",
        "s${p}_rare_move",
        "s${p}_rare_attack",
      ];
    }
    if (name.contains("BOSSES")) {
      return [
        "s${p}_mini_move",
        "s${p}_mini_attack",
        "s${p}_boss_move",
        "s${p}_boss_attack",
      ];
    }
    final isSkin = name.startsWith("AKARI_") || name.startsWith("SKIN_");
    if (name.endsWith("_MASTER")) {
      return const ["idle", "run", "attack_master", "feral_master"];
    }
    if (isSkin && name.endsWith("_FX")) {
      return const ["kitsunebi", "charged_shot", "transform_burst", "claw_arc"];
    }
    // The default skin's effects live in FX_SHEET_A / FX_SHEET_B.
    final part = name == "FX_SHEET_A"
        ? "FX_A"
        : name == "FX_SHEET_B"
        ? "FX_B"
        : isSkin
        ? _skinSheetOrder.firstWhere(
            (s) => name.endsWith("_$s"),
            orElse: () => "",
          )
        : "";
    final index = _skinSheetOrder.indexOf(part);
    if (index < 0) return const [];
    var start = 0;
    for (var i = 0; i < index; i += 1) {
      start += _skinSheetRows[i];
    }
    final end = min(start + _skinSheetRows[index], PLAYER_ANIMATIONS.length);
    return PLAYER_ANIMATIONS.sublist(start, end);
  }

  bool _isCharacterSheet(String normalizedBase) {
    final name = normalizedBase.replaceAll("-TRANSPARENT", "");
    if (name.contains("ENEMIES") || name.contains("BOSSES")) return true;
    final isSkin = name.startsWith("AKARI_") || name.startsWith("SKIN_");
    return isSkin && !name.contains("_FX");
  }

  Future<Uint8List?> _readPixels(String key, ui.Image image) async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data?.buffer.asUint8List();
    } catch (error, stackTrace) {
      _reportOnce(
        'pixels:$key',
        'Could not read pixels of "$key"; using cell-based anchors.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // Glow and particles are semi-transparent; only solid pixels count as body.
  static const int _solidAlpha = 200;

  // Feet anchors for one animation row. Y is each frame's lowest solid pixel,
  // so every frame touches the ground. X is the row's median foot centre, so
  // the character does not slide sideways between frames or flip off-centre.
  // Only pixels inside each frame's body rect count, so spill from a
  // neighbouring cell can never become the "feet".
  List<Offset> _footAnchors(
    Uint8List px,
    int imageWidth,
    List<Rect> cells,
    List<Rect> bodies,
  ) {
    final bottoms = <double>[];
    final footXs = <double>[];
    for (var i = 0; i < cells.length; i += 1) {
      final cell = cells[i];
      final body = bodies[i];
      final left = body.left.floor();
      final right = min(body.right.ceil(), imageWidth);
      final top = body.top.floor();
      final bottom = body.bottom.ceil() - 1;
      int? lowest;
      for (var y = bottom; y >= top && lowest == null; y -= 1) {
        final row = y * imageWidth;
        for (var x = left; x < right; x += 1) {
          if (px[(row + x) * 4 + 3] >= _solidAlpha) {
            lowest = y;
            break;
          }
        }
      }
      if (lowest == null) {
        bottoms.add(body.bottom);
        footXs.add(double.nan);
        continue;
      }
      bottoms.add(lowest + 1.0);
      // Average solid x over a thin band just above the lowest pixel.
      final band = max(4, (cell.height * 0.05).round());
      var sum = 0.0;
      var count = 0;
      for (var y = lowest; y > lowest - band && y >= top; y -= 1) {
        final row = y * imageWidth;
        for (var x = left; x < right; x += 1) {
          if (px[(row + x) * 4 + 3] >= _solidAlpha) {
            sum += x;
            count += 1;
          }
        }
      }
      footXs.add(count > 0 ? sum / count - cell.left : double.nan);
    }
    final known = footXs.where((v) => !v.isNaN).toList()..sort();
    final footX = known.isEmpty
        ? cells.first.width / 2
        : known[known.length ~/ 2];
    return [
      for (var i = 0; i < cells.length; i += 1)
        Offset(cells[i].left + footX, bottoms[i]),
    ];
  }

  // Neighbouring frames often spill a few pixels into a cell (a sword arc, a
  // tail tip). Keep only the block of rows and columns connected to the body,
  // treating gaps of a few pixels as still connected.
  Rect _bodyRect(Uint8List px, int imageWidth, Rect cell) {
    const step = 2;
    const maxGap = 5;
    const visibleAlpha = 24;
    final left = cell.left.floor();
    final right = min(cell.right.floor(), imageWidth);
    final top = cell.top.floor();
    final bottom = cell.bottom.floor();
    final rowCount = (bottom - top + step - 1) ~/ step;
    final colCount = (right - left + step - 1) ~/ step;

    final rowsUsed = List<bool>.filled(rowCount, false);
    for (var i = 0; i < rowCount; i += 1) {
      final row = (top + i * step) * imageWidth;
      for (var x = left; x < right; x += step) {
        if (px[(row + x) * 4 + 3] >= visibleAlpha) {
          rowsUsed[i] = true;
          break;
        }
      }
    }
    // The body is the tallest block of used rows; spill is a short block.
    var rowLo = 0, rowHi = -1;
    for (var i = 0; i < rowCount; i += 1) {
      if (!rowsUsed[i] || (i >= rowLo && i <= rowHi)) continue;
      final (lo, hi) = _span(rowsUsed, i, maxGap);
      if (hi - lo > rowHi - rowLo) {
        rowLo = lo;
        rowHi = hi;
      }
    }
    if (rowHi < 0) return cell;

    final colWeight = List<int>.filled(colCount, 0);
    for (var i = rowLo; i <= rowHi; i += 1) {
      final row = (top + i * step) * imageWidth;
      for (var j = 0; j < colCount; j += 1) {
        if (px[(row + left + j * step) * 4 + 3] >= visibleAlpha) {
          colWeight[j] += 1;
        }
      }
    }
    var seed = 0;
    for (var j = 0; j < colCount; j += 1) {
      if (colWeight[j] > colWeight[seed]) seed = j;
    }
    final (colLo, colHi) = _span(
      [for (final w in colWeight) w > 0],
      seed,
      maxGap,
    );

    return Rect.fromLTRB(
      (left + colLo * step).toDouble(),
      (top + rowLo * step).toDouble(),
      min(right, left + (colHi + 1) * step).toDouble(),
      min(bottom, top + (rowHi + 1) * step).toDouble(),
    );
  }

  (int, int) _span(List<bool> used, int seed, int maxGap) {
    var lo = seed, hi = seed, miss = 0;
    for (var i = seed - 1; i >= 0; i -= 1) {
      if (used[i]) {
        lo = i;
        miss = 0;
      } else if (++miss > maxGap) {
        break;
      }
    }
    miss = 0;
    for (var i = seed + 1; i < used.length; i += 1) {
      if (used[i]) {
        hi = i;
        miss = 0;
      } else if (++miss > maxGap) {
        break;
      }
    }
    return (lo, hi);
  }

  Rect? _opaqueBounds(Uint8List px, int width, int height) {
    var minX = width, minY = height, maxX = -1, maxY = -1;
    for (var y = 0; y < height; y += 1) {
      final row = y * width;
      for (var x = 0; x < width; x += 1) {
        if (px[(row + x) * 4 + 3] < _solidAlpha) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < 0) return null;
    return Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      maxX + 1.0,
      maxY + 1.0,
    );
  }

  Atlas _parseAtlas(Map<String, dynamic> json) {
    final frameList = (json["frames"] as List)
        .map((e) => Frame.fromJson(e as Map<String, dynamic>))
        .toList();
    final animMap = <String, List<Frame>>{};
    if (json["animations"] is List) {
      for (final a in json["animations"] as List) {
        final am = a as Map<String, dynamic>;
        animMap[am["name"] as String] = (am["frames"] as List)
            .map((e) => Frame.fromJson(e as Map<String, dynamic>))
            .toList();
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

    for (final name in [
      "jump_up",
      "fall",
      "dash",
      "wall_slide",
      "wall_jump",
      "tail_glide",
      "air_dash",
    ]) {
      alias(name, "run");
    }
    for (final name in [
      "land",
      "spawn",
      "tail_gain",
      "checkpoint_revive",
      "recoil_hit",
      "damage",
      "defeat",
    ]) {
      alias(name, "idle");
    }
    for (final name in ["shoot", "charge", "charged_release", "ofuda_throw"]) {
      alias(name, "attack_master");
    }
    for (final name in [
      "spirit_transform",
      "feral_idle",
      "feral_run",
      "feral_leap",
      "spirit_return",
      "claw_combo",
      "pounce",
      "rising_slash",
      "landing_smash",
      "feral_hit",
    ]) {
      alias(name, "feral_master");
    }
    alias("charged_shot", "kitsunebi");
    alias("ofuda_explosion", "transform_burst");
    alias("shadow_clone", "transform_burst");
    alias("tail_volley", "kitsunebi");
  }

  Future<void> loadKeys(List<String> keys) async {
    // Decode everything at once, then register sheets in order: later sheets
    // (a skin's own effects) must still override earlier fallbacks.
    await Future.wait([
      for (final key in keys)
        if (!images.containsKey(key)) _decode(key),
    ]);
    for (final key in keys) {
      await loadKey(key);
    }
  }
}

const CORE_KEYS = [
  "STAGE1_TILES",
  "STAGE2_TILES",
  "STAGE3_TILES",
  "OBJECT_ATLAS",
  "FX_SHEET_C",
];

List<String> fullSkinKeys(String id) => [
  "${id}_BASE_A",
  "${id}_BASE_B",
  "${id}_MOBILITY",
  "${id}_COMBAT",
  "${id}_STATE",
  "${id}_FERAL_A",
  "${id}_FERAL_B",
  "${id}_FERAL_C",
  "${id}_FX_A",
  "${id}_FX_B",
];

List<String> skinKeys(int index) {
  if (index == 0) {
    return [
      "AKARI_BASE_A",
      "AKARI_BASE_B",
      "AKARI_MOBILITY",
      "AKARI_COMBAT",
      "AKARI_STATE",
      "AKARI_FERAL_A",
      "AKARI_FERAL_B",
      "AKARI_FERAL_C",
      "FX_SHEET_A",
      "FX_SHEET_B",
    ];
  }
  final id = "SKIN_${(index + 1).toString().padLeft(2, "0")}";
  return index <= 3 ? fullSkinKeys(id) : ["${id}_MASTER", "${id}_FX"];
}

List<String> stageKeys(int index) {
  final id = (index + 1).toString().padLeft(2, "0");
  return [
    "WORLD_$id",
    "WORLD_${id}_ENEMIES",
    "WORLD_${id}_BOSSES",
    "WORLD_${id}_PUZZLE",
    ...skinKeys(index),
  ];
}

Future<AssetLibrary> preloadGameAssets(AssetLibrary library) async {
  final keys = [...CORE_KEYS, ...stageKeys(0)];
  await library.loadKeys(keys);
  // stageKeys(0) includes the default skin, so its aliases must exist up front.
  library.addCompactSkinAliases();
  library.stage = 0;
  return library;
}

bool _isSkinKey(String key) =>
    key.startsWith("AKARI_") ||
    key.startsWith("SKIN_") ||
    key == "FX_SHEET_A" ||
    key == "FX_SHEET_B";

Future<void> loadSkinAssets(AssetLibrary library, int skin) async {
  // Only drop what the previous skin registered; core sheets such as FX_SHEET_C
  // also provide some player-named animations and must keep them.
  library.animations.removeWhere((_, entry) => _isSkinKey(entry.key));
  library.frames.removeWhere((_, entry) => _isSkinKey(entry.key));
  library.sheets.removeWhere((key, _) => _isSkinKey(key));
  library.images.removeWhere((key, _) => _isSkinKey(key));
  await library.loadKeys(skinKeys(skin));
  library.addCompactSkinAliases();
  library.skin = skin;
}

Future<void> loadStageAssets(
  AssetLibrary library,
  int index, {
  int? skin,
}) async {
  if (library.stage != index) {
    for (var stage = 0; stage < 10; stage += 1) {
      if (stage == index) continue;
      final id = (stage + 1).toString().padLeft(2, "0");
      final keys = {
        "WORLD_$id",
        "WORLD_${id}_ENEMIES",
        "WORLD_${id}_BOSSES",
        "WORLD_${id}_PUZZLE",
      };
      library.images.removeWhere((key, _) => keys.contains(key));
      library.sheets.removeWhere((key, _) => keys.contains(key));
      library.animations.removeWhere((name, _) => name.startsWith("s${id}_"));
      library.frames.removeWhere((name, _) => name.startsWith("s${id}_"));
    }
    await library.loadKeys(stageKeys(index).take(4).toList());
    library.stage = index;
  }
  final wantedSkin = skin ?? index;
  if (wantedSkin != library.skin) await loadSkinAssets(library, wantedSkin);
}
