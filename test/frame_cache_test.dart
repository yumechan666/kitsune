// Regenerates assets/json/auto_frames.json, the precomputed frame layout that
// keeps the game from measuring sprite pixels while loading. Run it after
// adding or changing sprite sheets:
//   flutter test test/frame_cache_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitsune/game/atlas.dart';

void main() {
  testWidgets('regenerate frame cache', (tester) async {
    await tester.runAsync(() async {
      final lib = AssetLibrary()..useFrameCache = false;
      await lib.loadManifest();
      final keys = lib.manifest.entries
          .where((e) => e.value.contains("transparent") || e.value.contains("tiles"))
          .map((e) => e.key)
          .toList();
      // Small batches keep only a few decoded sheets in memory at a time.
      for (var i = 0; i < keys.length; i += 6) {
        final batch = keys.sublist(i, (i + 6).clamp(0, keys.length));
        await lib.loadKeys(batch);
        lib.images.removeWhere((key, _) => batch.contains(key));
      }
      final cache = lib.exportFrameCache();
      File(AssetLibrary.frameCachePath).writeAsStringSync(jsonEncode(cache));
      final frames = (cache["frames"] as Map).length;
      final tiles = (cache["tiles"] as Map).length;
      expect(frames, greaterThan(0));
      // ignore: avoid_print
      print("auto_frames.json: $frames sheets, $tiles tile sets");
    });
  });
}
