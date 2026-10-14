class Platform {
  final double x;
  final double y;
  final double w;
  final double h;
  final String kind;
  Platform(this.x, this.y, this.w, this.h, this.kind);
}

class Hazard {
  final double x;
  final double y;
  final double w;
  final double h;
  Hazard(num x, num y, num w, num h)
    : x = x.toDouble(),
      y = y.toDouble(),
      w = w.toDouble(),
      h = h.toDouble();
}

class EnemySpawn {
  final String type;
  final double x;
  final double y;
  final Map<String, dynamic> extra;
  EnemySpawn(this.type, this.x, this.y, this.extra);
}

class Pickup {
  final String type;
  final double x;
  final double y;
  bool alive = true;
  double phase = 0;
  Pickup(this.type, this.x, this.y);
}

class Puzzle {
  final int id;
  final double x;
  final String action;
  final String hint;
  bool solved = false;
  bool hinted = false;
  Puzzle(this.id, this.x, this.action, this.hint);
}

class Level {
  final int id;
  final String name;
  final String subtitle;
  final String bossName;
  final String skinName;
  final double length;
  final String backdrop;
  final String tiles;
  final double checkpoint;
  final List<double> checkpoints;
  final List<Puzzle> puzzles;
  final double wind;
  final List<Platform> platforms;
  final List<EnemySpawn> enemies;
  final List<Pickup> pickups;
  final List<Hazard> hazards;

  Level({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.bossName,
    required this.skinName,
    required this.length,
    required this.backdrop,
    required this.tiles,
    required this.checkpoint,
    required this.checkpoints,
    required this.puzzles,
    required this.wind,
    required this.platforms,
    required this.enemies,
    required this.pickups,
    required this.hazards,
  });
}

class EnemyStat {
  final String name;
  final double hp;
  final double w;
  final double h;
  final double spriteH;
  final double score;
  final String idle;
  final String move;
  final String attack;
  final String hit;
  final String defeat;
  final double speed;
  final double attackDelay;
  final double projectileSpeed;
  final bool flying;
  final int shotCount;
  final bool homing;
  final double? telegraphTime;
  final bool melee;
  final bool boss;

  EnemyStat({
    required this.name,
    required num hp,
    required num w,
    required num h,
    required num spriteH,
    required num score,
    required this.idle,
    required this.move,
    required this.attack,
    required this.hit,
    required this.defeat,
    required num speed,
    required num attackDelay,
    required num projectileSpeed,
    this.flying = false,
    this.shotCount = 1,
    this.homing = false,
    num? telegraphTime,
    this.melee = false,
    this.boss = false,
  }) : hp = hp.toDouble(),
       w = w.toDouble(),
       h = h.toDouble(),
       spriteH = spriteH.toDouble(),
       score = score.toDouble(),
       speed = speed.toDouble(),
       attackDelay = attackDelay.toDouble(),
       projectileSpeed = projectileSpeed.toDouble(),
       telegraphTime = telegraphTime?.toDouble();
}

Platform floor(num x, num w, [num y = 466, num h = 130]) => Platform(
  x.toDouble(),
  y.toDouble(),
  w.toDouble(),
  h.toDouble(),
  "platform",
);
Platform ledge(num x, num y, [num w = 190, num h = 44]) => Platform(
  x.toDouble(),
  y.toDouble(),
  w.toDouble(),
  h.toDouble(),
  "platform",
);
Platform wall(num x, num y, [num w = 58, num h = 185]) => Platform(
  x.toDouble(),
  y.toDouble(),
  w.toDouble(),
  h.toDouble(),
  "platform",
);
EnemySpawn enemy(
  String type,
  num x, [
  num y = 466,
  Map<String, dynamic> extra = const {},
]) => EnemySpawn(type, x.toDouble(), y.toDouble(), Map.from(extra));
Pickup pickup(String type, num x, num y) =>
    Pickup(type, x.toDouble(), y.toDouble());

const STAGE_DEFS = [
  ["TORII MARKET", "Rainline shrine bazaar", "Gate Ox"],
  ["LANTERN TOWER", "The thousand-light ascent", "Kumo Mother"],
  ["SKY PAGODA", "Thunder above the neon city", "Raijin-0"],
  ["MIRROR CANAL", "Reflections that fight back", "Mizuchi"],
  ["DATA BAMBOO", "The encoded sacred grove", "Tengu Shogun"],
  ["MOON RAIL", "Last train through the clouds", "Moon Locomotive"],
  ["INARI VAULT", "The shrine beneath the ice", "Nine-Ice Guardian"],
  ["CRIMSON FOUNDRY", "Spirit steel and living flame", "Furnace Giant"],
  ["SPIRIT RIFT", "A city broken between worlds", "Thousand-Eye Wall"],
  ["CELESTIAL SHRINE", "The sun engine awakens", "Amaterasu Engine"],
];

const SKIN_NAMES = [
  "Akari · Dawn Miko",
  "Ren · Storm Ronin",
  "Sora · Mirror Ninja",
  "Haru · Bamboo Tengu",
  "Yuna · Moon Conductor",
  "Kaito · Frost Warden",
  "Mei · Forge Dancer",
  "Shin · Void Hunter",
  "Amaya · Star Priestess",
  "Rei · Eclipse Prince",
];

const PUZZLE_ACTIONS = [
  ["shoot", "dash", "charge"],
  ["shoot", "ofuda", "shoot"],
  ["dash", "dash", "spirit"],
  ["clone", "charge", "clone"],
  ["glide", "ofuda", "charge"],
  ["shoot", "dash", "shoot"],
  ["ofuda", "ofuda", "spirit"],
  ["charge", "charge", "ofuda"],
  ["clone", "spirit", "clone"],
  ["shoot", "dash", "ofuda", "spirit"],
];

const PUZZLE_HINTS = {
  "shoot": "Strike the shrine target with foxfire",
  "dash": "Blink through the sealed beacon",
  "charge": "Break the core with a charged shot",
  "ofuda": "Ignite the seal with an ofuda mine",
  "spirit": "Awaken Spirit Mode beside the rune",
  "clone": "Leave an illusion clone on the twin plate",
  "glide": "Glide through the wind rune",
};

Level buildStage(int index) {
  final number = index + 1;
  final id = number.toString().padLeft(2, "0");
  final length = 25800 + index * 540;
  final platforms = <Platform>[];
  final hazards = <Hazard>[];
  final enemies = <EnemySpawn>[];
  final pickups = <Pickup>[];
  const segment = 900;
  final segmentCount = ((length - 1150) / segment).ceil();

  for (int i = 0; i < segmentCount; i += 1) {
    final x = i * segment.toDouble();
    final floorWidth = 750 + ((i + index) % 2) * 35;
    platforms.add(floor(x, floorWidth.toDouble()));
    hazards.add(Hazard(x + floorWidth, 452, segment - floorWidth, 24));
    platforms.add(
      ledge(x + 390, 350 - ((i + index) % 3) * 42, 190 + (i % 2) * 35),
    );
    if (i % 3 == 1) {
      platforms.add(
        wall(x + 700, 280 - (index % 2) * 25, 58, 186 + (index % 3) * 22),
      );
    }
    enemies.add(enemy("s${number}_common", x + 520, 466));
    if (i % 2 == 1) {
      enemies.add(enemy("s${number}_rare", x + 700, 305 - (i % 3) * 25));
    }
    if (i > 0 && i % 3 == 0) {
      enemies.add(enemy("s${number}_common", x + 250, 466));
    }
    if (i % 2 == 0) pickups.add(pickup("spirit", x + 470, 295 - (i % 3) * 28));
    if (i == 2 || i == 6) pickups.add(pickup("tail", x + 610, 260));
  }

  final arenaX = length - 1150;
  platforms.add(floor(arenaX.toDouble(), 1250));
  platforms.add(ledge(arenaX + 210, 330, 210));
  platforms.add(ledge(arenaX + 710, 300, 190));
  final miniX = ((length * 0.52) / segment).floor() * segment + 520;
  // A lantern every third segment, placed on solid floor just past the first
  // enemy (the spiked gap starts around x+750), plus the original milestones.
  final checkpoints = <double>{
    for (var i = 2; i < segmentCount; i += 3)
      if (i * segment + 600.0 < length - 1150) i * segment + 600.0,
    for (final ratio in [0.27, 0.54, 0.8])
      ((length * ratio) / segment).floor() * segment + 180.0,
  }.toList()..sort();
  final puzzles = <Puzzle>[];
  final ratios = PUZZLE_ACTIONS[index].length == 4
      ? [0.18, 0.4, 0.62, 0.82]
      : [0.24, 0.5, 0.76];
  for (int p = 0; p < PUZZLE_ACTIONS[index].length; p += 1) {
    final action = PUZZLE_ACTIONS[index][p];
    final px = ((length * ratios[p]) / segment).floor() * segment + 610;
    puzzles.add(Puzzle(p, px.toDouble(), action, PUZZLE_HINTS[action]!));
  }
  enemies.add(
    enemy("s${number}_mini", miniX.toDouble(), 466, {
      "hp": 24 + index * 3,
      "miniBoss": true,
    }),
  );
  enemies.add(
    enemy("s${number}_boss", (length - 470).toDouble(), 466, {
      "hp": 52 + index * 8,
      "boss": true,
    }),
  );

  return Level(
    id: number,
    name: STAGE_DEFS[index][0],
    subtitle: STAGE_DEFS[index][1],
    bossName: STAGE_DEFS[index][2],
    skinName: SKIN_NAMES[index],
    length: length.toDouble(),
    backdrop: "WORLD_${id.toString().padLeft(2, "0")}",
    tiles: "STAGE${(index % 3) + 1}_TILES",
    checkpoint: checkpoints[0].toDouble(),
    checkpoints: checkpoints.map((e) => e.toDouble()).toList(),
    puzzles: puzzles,
    wind: (index == 2 || index == 5 || index == 9) ? 18 + index * 2 : 0,
    platforms: platforms,
    enemies: enemies,
    pickups: pickups,
    hazards: hazards,
  );
}

final LEVELS = List<Level>.generate(10, (index) => buildStage(index));

final ENEMY_STATS = <String, EnemyStat>{};

void _buildEnemyStats() {
  for (int stage = 1; stage <= 10; stage += 1) {
    final difficulty = 1 + (stage - 1) * 0.12;
    final p = stage.toString().padLeft(2, '0');
    ENEMY_STATS["s${stage}_common"] = EnemyStat(
      name: "Stage $stage Common",
      hp: (4 * difficulty).round(),
      w: 45,
      h: 55,
      spriteH: 66,
      score: 180 + stage * 25,
      idle: "s${p}_common_move",
      move: "s${p}_common_move",
      attack: "s${p}_common_attack",
      hit: "s${p}_common_move",
      defeat: "s${p}_common_move",
      speed: 58 + stage * 2,
      attackDelay: 1.9,
      projectileSpeed: 285 + stage * 5,
    );
    ENEMY_STATS["s${stage}_rare"] = EnemyStat(
      name: "Stage $stage Rare",
      hp: (7 * difficulty).round(),
      w: 52,
      h: 62,
      spriteH: 76,
      score: 420 + stage * 45,
      idle: "s${p}_rare_move",
      move: "s${p}_rare_move",
      attack: "s${p}_rare_attack",
      hit: "s${p}_rare_move",
      defeat: "s${p}_rare_move",
      speed: 72 + stage * 2,
      attackDelay: 1.55,
      projectileSpeed: 330 + stage * 6,
      flying: stage % 3 == 0 || stage == 4 || stage == 8,
      shotCount: stage >= 7 ? 3 : 2,
      homing: stage == 3 || stage == 9,
    );
    ENEMY_STATS["s${stage}_mini"] = EnemyStat(
      name: "Stage $stage Miniboss",
      hp: 24 + stage * 3,
      w: 82,
      h: 88,
      spriteH: 108,
      score: 1800 + stage * 180,
      idle: "s${p}_mini_move",
      move: "s${p}_mini_move",
      attack: "s${p}_mini_attack",
      hit: "s${p}_mini_move",
      defeat: "s${p}_mini_move",
      speed: 56,
      attackDelay: 1.25,
      projectileSpeed: 350,
      shotCount: 3,
      telegraphTime: 0.48,
    );
    ENEMY_STATS["s${stage}_boss"] = EnemyStat(
      name: STAGE_DEFS[stage - 1][2],
      hp: 52 + (stage - 1) * 8,
      w: 108,
      h: 118,
      spriteH: 142,
      score: 5000 + stage * 650,
      idle: "s${p}_boss_move",
      move: "s${p}_boss_move",
      attack: "s${p}_boss_attack",
      hit: "s${p}_boss_move",
      defeat: "s${p}_boss_move",
      speed: 44 + stage,
      attackDelay: 1.05,
      projectileSpeed: 380 + stage * 6,
      shotCount: 3 + (stage / 4).floor(),
      telegraphTime: 0.58,
      boss: true,
    );
  }
}

void initEnemyStats() {
  if (ENEMY_STATS.isEmpty) _buildEnemyStats();
}
