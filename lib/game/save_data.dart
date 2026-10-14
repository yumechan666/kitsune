import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

// Everything worth keeping between launches. The in-stage position is not
// saved; a resumed run starts the saved stage from its beginning with the
// tails and spirit the player carried into it.
class SaveData {
  static const String _key = "kitsune_save_v1";

  double bestScore;
  bool unlockedRush;
  bool tutorialSeen;
  int volumeLevel;
  RunSave? run;

  SaveData({
    this.bestScore = 0,
    this.unlockedRush = false,
    this.tutorialSeen = false,
    this.volumeLevel = 0,
    this.run,
  });

  Map<String, dynamic> toJson() => {
    "bestScore": bestScore,
    "unlockedRush": unlockedRush,
    "tutorialSeen": tutorialSeen,
    "volumeLevel": volumeLevel,
    "run": run?.toJson(),
  };

  factory SaveData.fromJson(Map<String, dynamic> json) {
    final runJson = json["run"];
    return SaveData(
      bestScore: (json["bestScore"] as num?)?.toDouble() ?? 0,
      unlockedRush: json["unlockedRush"] as bool? ?? false,
      tutorialSeen: json["tutorialSeen"] as bool? ?? false,
      volumeLevel: (json["volumeLevel"] as num?)?.toInt() ?? 0,
      run: runJson is Map<String, dynamic> ? RunSave.fromJson(runJson) : null,
    );
  }

  static Future<SaveData> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return SaveData();
      return SaveData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error, stackTrace) {
      developer.log(
        "Save data could not be read; starting fresh.",
        name: "kitsune.save",
        error: error,
        stackTrace: stackTrace,
      );
      return SaveData();
    }
  }

  Future<void> write() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (error, stackTrace) {
      developer.log(
        "Save data could not be written.",
        name: "kitsune.save",
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class RunSave {
  final String mode;
  final int stageIndex;
  final double runScore;
  final int? carryTails;
  final double? carrySpirit;

  RunSave({
    required this.mode,
    required this.stageIndex,
    required this.runScore,
    this.carryTails,
    this.carrySpirit,
  });

  Map<String, dynamic> toJson() => {
    "mode": mode,
    "stageIndex": stageIndex,
    "runScore": runScore,
    "carryTails": carryTails,
    "carrySpirit": carrySpirit,
  };

  factory RunSave.fromJson(Map<String, dynamic> json) => RunSave(
    mode: json["mode"] as String? ?? "campaign",
    stageIndex: (json["stageIndex"] as num?)?.toInt() ?? 0,
    runScore: (json["runScore"] as num?)?.toDouble() ?? 0,
    carryTails: (json["carryTails"] as num?)?.toInt(),
    carrySpirit: (json["carrySpirit"] as num?)?.toDouble(),
  );
}
