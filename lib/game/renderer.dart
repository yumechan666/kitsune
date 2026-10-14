import 'dart:math';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:kitsune/game/atlas.dart';
import 'package:kitsune/game/levels.dart';

class Renderer {
  final AssetLibrary library;
  double width = 1;
  double height = 1;
  double worldWidth = 600;
  ui.Canvas? canvas;

  // When an animation with this name is drawn, debugTrackInfo receives the
  // frame that was picked and where the sprite was placed (for position logs).
  String? debugTrackName;
  String? debugTrackInfo;
  final Set<String> _reportedMissingFrames = {};
  final Random _rng = Random();
  final ui.Paint _sprite = ui.Paint()..filterQuality = ui.FilterQuality.medium;

  ui.Paint _spritePaint(double alpha) =>
      _sprite..color = ui.Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
  final Set<String> _reportedErrors = {};

  Renderer(this.library);

  void _reportErrorOnce(String id, Object error, StackTrace stackTrace) {
    if (!_reportedErrors.add(id)) return;
    developer.log(
      'Render draw failed for "$id": $error',
      name: 'kitsune.renderer',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _safe(String id, void Function() fn) {
    try {
      fn();
    } catch (error, stackTrace) {
      _reportErrorOnce(id, error, stackTrace);
    }
  }

  double get viewWidth => worldWidth;

  void resize(double w, double h) {
    if (w <= 0 || h <= 0) return;
    width = w;
    height = h;
    // Keep the world viewport at the screen's aspect ratio. A 600-unit
    // minimum crops the player off-screen on portrait phones because the
    // renderer scales the world to the full screen height.
    // Landscape phones reach about 2.2:1, so the cap must allow ~1200 units.
    worldWidth = min(1400, max(1, (width / height) * 540));
  }

  void begin(
    Level level,
    double cameraX,
    double time,
    double shake,
    double flash,
  ) {
    final c = canvas;
    if (c == null) return;
    c.save();
    _drawBackdrop(level.backdrop, cameraX, flash);
    c.restore();

    c.save();
    final scale = height / 540;
    final offsetX = (width - worldWidth * scale) / 2;
    final sx = shake != 0 ? (_rng.nextDouble() - 0.5) * shake : 0.0;
    final sy = shake != 0 ? (_rng.nextDouble() - 0.5) * shake : 0.0;
    c.translate(offsetX + sx, sy);
    c.scale(scale, scale);
    c.translate(-cameraX, 0);
    _drawRain(cameraX, time, level.id - 1);
  }

  void end() {
    canvas?.restore();
  }

  void _drawBackdrop(String key, double cameraX, double flash) {
    final c = canvas;
    if (c == null) return;
    final image = library.images[key];
    if (image == null) {
      c.drawRect(
        ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint()
          ..shader = ui.Gradient.linear(
            const ui.Offset(0, 0),
            ui.Offset(0, height),
            [const ui.Color(0xFF0a1230), const ui.Color(0xFF050817)],
          ),
      );
      if (flash > 0) {
        c.drawRect(
          ui.Rect.fromLTWH(0, 0, width, height),
          ui.Paint()
            ..color = const ui.Color(
              0xFFAADCFF,
            ).withAlpha((flash * 255).round()),
        );
      }
      return;
    }
    final scale = max(width / image.width, height / image.height);
    final drawW = image.width * scale;
    final drawH = image.height * scale;
    final parallax = (cameraX * 0.12) % drawW;
    final start = -parallax - drawW;
    for (int i = 0; i < 4; i += 1) {
      final x = start + i * drawW;
      if (i % 2 == 0) {
        c.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          ui.Rect.fromLTWH(x, (height - drawH) / 2, drawW, drawH),
          _spritePaint(1),
        );
      } else {
        c.save();
        c.translate(x + drawW, 0);
        c.scale(-1, 1);
        c.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          ui.Rect.fromLTWH(0, (height - drawH) / 2, drawW, drawH),
          _spritePaint(1),
        );
        c.restore();
      }
    }
    c.drawRect(
      ui.Rect.fromLTWH(0, 0, width, height),
      ui.Paint()
        ..shader = ui.Gradient.linear(
          const ui.Offset(0, 0),
          ui.Offset(0, height),
          [
            const ui.Color(0x1F050923),
            const ui.Color(0x0A04081C),
            const ui.Color(0x14081230),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
    if (flash > 0) {
      c.drawRect(
        ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint()
          ..color = const ui.Color(0xFFAADCFF).withAlpha((flash * 255).round()),
      );
    }
  }

  void _drawRain(double cameraX, double time, int stage) {
    final c = canvas;
    if (c == null) return;
    final paint = ui.Paint()
      ..strokeWidth = 1
      ..color = stage % 3 == 2
          ? const ui.Color(0x47AAD2FF)
          : const ui.Color(0x2E6EBEFF);
    for (int i = 0; i < 52; i += 1) {
      final x =
          cameraX +
          ((i * 137 + time * (stage % 3 == 2 ? 420 : 250)) %
              (worldWidth + 80)) -
          40;
      final y = ((i * 83 + time * 310) % 590) - 30;
      c.drawLine(ui.Offset(x, y), ui.Offset(x - 7, y + 18), paint);
    }
  }

  void drawPlatform(String tileKey, Platform platform) {
    final c = canvas;
    if (c == null) return;
    final sheet = library.sheets[tileKey];
    final image = library.images[tileKey];
    final frame = sheet?.frames["center"];
    if (sheet == null || image == null || frame == null) {
      _reportMissingOnce(
        "platform:$tileKey",
        'No usable "center" tile frame for "$tileKey"; drawing the fallback platform.',
      );
      _safe("platform_fallback:$tileKey", () {
        c.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(platform.x, platform.y, platform.w, platform.h),
            const ui.Radius.circular(8),
          ),
          ui.Paint()..color = const ui.Color(0xFF33244F),
        );
        c.drawRect(
          ui.Rect.fromLTWH(platform.x, platform.y, platform.w, 7),
          ui.Paint()..color = const ui.Color(0xFF6A4A9A),
        );
      });
      return;
    }
    final crop = frame.content;
    _safe("platform:$tileKey", () {
      c.save();
      c.clipRect(
        ui.Rect.fromLTWH(platform.x, platform.y, platform.w, platform.h),
      );
      // The tile frame is cropped to the visible roof, so its top edge sits
      // exactly on platform.y where the player's feet land.
      c.drawImageRect(
        image,
        crop,
        ui.Rect.fromLTWH(platform.x, platform.y, platform.w, platform.h),
        _spritePaint(1),
      );
      c.restore();
    });
  }

  void drawStatic(
    String name,
    double x,
    double y,
    double w,
    double h, [
    double alpha = 1,
  ]) {
    final c = canvas;
    if (c == null) return;
    final entry = library.frames[name];
    final image = entry?.image;
    if (entry == null || image == null) {
      _reportMissingOnce(
        "static:$name",
        'No atlas frame named "$name" was loaded; drawing a placeholder.',
      );
      _safe("static_fallback:$name", () {
        c.drawRect(
          ui.Rect.fromLTWH(x, y, w, h),
          ui.Paint()
            ..color = const ui.Color(
              0xFF3B4C8C,
            ).withAlpha((alpha * 255).round()),
        );
      });
      return;
    }
    final crop = entry.frame.content;
    _safe("static:$name", () {
      final s = min(w / crop.width, h / crop.height);
      final dw = crop.width * s;
      final dh = crop.height * s;
      c.drawImageRect(
        image,
        crop,
        ui.Rect.fromLTWH(x + (w - dw) / 2, y + (h - dh) / 2, dw, dh),
        _spritePaint(alpha),
      );
    });
  }

  void drawAnchored(
    String name,
    double x,
    double y,
    double scale,
    int facing,
    double time, [
    int fps = 10,
    double alpha = 1,
    double? progress,
    double fallbackW = 40,
    double fallbackH = 56,
    ui.Color? fallbackColor,
  ]) {
    final c = canvas;
    if (c == null) return;
    final entry = library.animations[name];
    final image = entry?.image;
    if (entry == null || image == null) {
      _reportMissingOnce(
        "animation:$name",
        'No animation named "$name" was loaded; drawing a placeholder.',
      );
      _safe("animation_fallback:$name", () {
        _drawBox(
          c,
          x,
          y,
          fallbackW,
          fallbackH,
          scale,
          facing,
          fallbackColor ?? const ui.Color(0xFFFF66CC),
          alpha,
        );
      });
      return;
    }
    final count = entry.frames.length;
    if (count == 0) return;
    final index = progress == null
        ? (time * fps).floor() % count
        : min(count - 1, (progress * count).floor());
    final frame = entry.frames[index];
    final crop = frame.content;
    final anchor = frame.anchor;
    final dx = -(anchor.dx - crop.left) * scale;
    final dy = -(anchor.dy - crop.top) * scale;
    if (name == debugTrackName) {
      debugTrackInfo =
          "frame=$index/$count "
          "crop=(${crop.left.round()},${crop.top.round()} "
          "${crop.width.round()}x${crop.height.round()}) "
          "offset=(${dx.toStringAsFixed(1)},${dy.toStringAsFixed(1)})";
    }
    _safe("animation:$name", () {
      c.save();
      c.translate(x, y);
      c.scale(facing.toDouble(), 1);
      c.drawImageRect(
        image,
        crop,
        ui.Rect.fromLTWH(dx, dy, crop.width * scale, crop.height * scale),
        _spritePaint(alpha),
      );
      c.restore();
    });
  }

  void _reportMissingOnce(String id, String message) {
    if (!_reportedMissingFrames.add(id)) return;
    developer.log(message, name: 'kitsune.renderer', level: 900);
  }

  void _drawBox(
    ui.Canvas c,
    double x,
    double y,
    double w,
    double h,
    double scale,
    int facing,
    ui.Color color,
    double alpha,
  ) {
    final pw = w * scale;
    final ph = h * scale;
    c.save();
    c.translate(x, y);
    c.scale(facing.toDouble(), 1);
    c.drawRect(
      ui.Rect.fromLTWH(-pw / 2, -ph, pw, ph),
      ui.Paint()..color = color.withAlpha((alpha * 255).round()),
    );
    c.drawRect(
      ui.Rect.fromLTWH(-pw / 2, -ph, pw, 4),
      ui.Paint()..color = color.withAlpha(((alpha * 0.6) * 255).round()),
    );
    c.restore();
  }
}
