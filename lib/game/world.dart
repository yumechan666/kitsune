import 'dart:math';
import 'dart:ui';

import 'package:kitsune/game/input.dart';
import 'package:kitsune/game/levels.dart';
import 'package:kitsune/game/renderer.dart';

// Horizontal margin trimmed from each end of a spike strip before it can hurt.
const double _hazardInset = 12;

// Forgiving jump timing: a press this long before landing still jumps, and
// the ground jump stays available this long after running off a ledge.
const double _jumpBufferTime = 0.15;
const double _coyoteTime = 0.14;

const Map<String, bool> _noInput = {
  "left": false,
  "right": false,
  "jump": false,
  "fire": false,
  "dash": false,
  "ofuda": false,
  "spirit": false,
};

class GameConfig {
  double playerSpeed;
  double enemyAggression;
  double effectsIntensity;
  double musicVolume;
  GameConfig({
    required this.playerSpeed,
    required this.enemyAggression,
    required this.effectsIntensity,
    required this.musicVolume,
  });
}

class Player {
  double x = 120;
  double y = 466;
  double vx = 0;
  double vy = 0;
  int facing = 1;
  bool grounded = true;
  double coyote = 0.11;
  // Extra jumps left in the air; refilled on the ground and on walls.
  int airJumps = 1;
  // A jump press is remembered briefly so it still fires on landing.
  double jumpBuffer = 0;
  int tails = 9;
  double spirit = 0;
  double spiritTime = 0;
  double invulnerable = 0;
  double dashTime = 0;
  double dashCooldown = 0;
  double fireCooldown = 0;
  double ofudaCooldown = 0;
  String action = "spawn";
  double actionTime = 0.55;
  bool charging = false;
  double chargeTime = 0;
  int hitCount = 0;
  int maxTails = 9;
  double w = 34;
  double h = 70;
  int wallSide = 0;
}

class Foe {
  final String type;
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  bool alive = true;
  String state = "idle";
  double stateTime = 0;
  double cooldown;
  int facing = 1;
  final double startX;
  double deathTime = 0;
  double hp;
  final double maxHp;
  final bool boss;
  final bool miniBoss;
  final EnemyStat stat;

  // Attack state: the pattern and aim are chosen when the wind-up starts and
  // stay fixed, so the warning line shows exactly where the attack will go.
  double stateDuration = 0;
  String pattern = "bolt";
  double aimX = 0;
  double aimY = 0;
  int attackCount = 0;
  bool slashLanded = false;

  Foe({
    required this.type,
    required this.x,
    required this.y,
    required this.cooldown,
    required this.startX,
    required this.hp,
    required this.maxHp,
    required this.boss,
    required this.miniBoss,
    required this.stat,
  });
}

class Shot {
  double x, y, vx;
  double damage;
  bool charged;
  double ttl;
  double delay;
  int pierce;
  bool tail;
  Shot(
    this.x,
    this.y,
    this.vx,
    this.damage,
    this.charged,
    this.ttl,
    this.delay,
    this.pierce,
    this.tail,
  );
}

class EnemyShot {
  double x, y, vx, vy, ttl;
  bool homing;
  String type;
  final double gravity;
  final bool bomb;
  final Color color;
  final double radius;
  final List<Offset> trail = [];
  double age = 0;
  EnemyShot(
    this.x,
    this.y,
    this.vx,
    this.vy,
    this.ttl,
    this.homing,
    this.type, {
    this.gravity = 0,
    this.bomb = false,
    this.color = const Color(0xFF49E8FF),
    this.radius = 9,
  });
}

// A melee swing drawn as a glowing arc in front of the attacker.
class Slash {
  final double x, y, radius, duration;
  final int facing;
  final Color color;
  double ttl;
  Slash(this.x, this.y, this.radius, this.facing, this.color, this.duration)
    : ttl = duration;
}

// An expanding shockwave ring (bomb impacts, boss bursts).
class Blast {
  final double x, y, radius, duration;
  final Color color;
  double ttl;
  Blast(this.x, this.y, this.radius, this.color, this.duration) : ttl = duration;
}

class Ofuda {
  double x, y, vx, vy;
  bool stuck;
  double ttl;
  Ofuda(this.x, this.y, this.vx, this.vy, this.stuck, this.ttl);
}

class Effect {
  String anim;
  double x, y, ttl, duration, scale, facing;
  Effect(
    this.anim,
    this.x,
    this.y,
    this.ttl,
    this.duration,
    this.scale,
    this.facing,
  );
}

class Clone {
  double x, y, ttl;
  int facing;
  Clone(this.x, this.y, this.ttl, this.facing);
}

class Carry {
  final int tails;
  final double spirit;
  Carry({required this.tails, required this.spirit});
}

class Snapshot {
  final int tails;
  final double spirit;
  final double spiritActive;
  final double ofudaReady;
  final double progress;
  final int puzzlesSolved;
  final double score;
  final int combo;
  final double time;
  final String? bossName;
  final double bossHp;
  Snapshot({
    required this.tails,
    required this.spirit,
    required this.spiritActive,
    required this.ofudaReady,
    required this.progress,
    required this.puzzlesSolved,
    required this.score,
    required this.combo,
    required this.time,
    this.bossName,
    this.bossHp = 0,
  });
}

double clamp(double value, double lo, double hi) => min(max(value, lo), hi);
bool overlaps(num rx, num ry, num rw, num rh, num ox, num oy, num ow, num oh) =>
    rx < ox + ow && rx + rw > ox && ry < oy + oh && ry + rh > oy;
double distanceSq(double ax, double ay, double bx, double by) =>
    (ax - bx) * (ax - bx) + (ay - by) * (ay - by);

class World {
  final Level level;
  final String mode;
  final GameConfig config;
  final void Function(String type, Map<String, dynamic> data) onEvent;

  late Player player;
  final List<Foe> enemies = [];
  final List<Shot> shots = [];
  final List<EnemyShot> enemyShots = [];
  final List<Slash> slashes = [];
  final List<Blast> blasts = [];
  final List<Ofuda> ofudas = [];
  final List<Effect> effects = [];
  Clone? clone;

  double shake = 0;
  double flash = 0;
  double comboTimer = 0;
  int combo = 0;
  double elapsed = 0;
  double score = 0;
  int checkpointIndex = -1;
  double checkpointX = 120;
  double completeTimer = 0;
  bool paused = false;
  final Random _random = Random();

  // Seconds until a downed player is revived at the last checkpoint. Counted in
  // game time, so pausing or restarting cannot fire a stale respawn.
  double respawnTimer = 0;

  // Set once the player gets near the boss; drives its health bar.
  bool bossRevealed = false;

  // Last spot where the player stood well inside a floor; pit falls return here.
  double safeX = 120;
  double safeY = 466;

  // True when the feet rest on a platform with room to spare on both sides, so
  // the saved spot is never right at an edge the player could slip off again.
  bool _standsWellInsideFloor() {
    for (final platform in level.platforms) {
      if ((player.y - platform.y).abs() > 1) continue;
      if (player.x > platform.x + 40 && player.x < platform.x + platform.w - 40) {
        return true;
      }
    }
    return false;
  }

  // Diagnostics for tracking position jumps; see _log and the "log" event.
  double _lastPosLog = -1;
  double lastCameraX = 0;
  String lastPlayerAnim = "";
  double _playerAnimStart = 0;
  String? lastPlayerFrameInfo;

  void _log(String text) {
    emit("log", {"text": "t=${elapsed.toStringAsFixed(2)} $text"});
  }

  World({
    required this.level,
    required this.mode,
    required this.config,
    required this.onEvent,
  }) {
    player = Player();
    for (final source in level.enemies) {
      final stat = ENEMY_STATS[source.type]!;
      final hp = (source.extra["hp"] as num?)?.toDouble() ?? stat.hp.toDouble();
      enemies.add(
        Foe(
          type: source.type,
          x: source.x,
          y: source.y,
          cooldown: stat.attackDelay,
          startX: source.x,
          hp: hp,
          maxHp: hp,
          boss: source.extra["boss"] == true,
          miniBoss: source.extra["miniBoss"] == true,
          stat: stat,
        ),
      );
    }
    for (int i = 0; i < level.pickups.length; i += 1) {
      level.pickups[i].phase = i * 1.7;
    }
  }

  void emit(String type, Map<String, dynamic> data) => onEvent(type, data);

  void addEffect(
    String anim,
    double x,
    double y,
    double duration,
    double scale, [
    int facing = 1,
  ]) {
    effects.add(
      Effect(anim, x, y, duration, duration, scale, facing.toDouble()),
    );
  }

  void spawnShot(bool charged) {
    final direction = player.facing;
    final damage = charged ? 4.0 : 1.0;
    final speed = charged ? 720.0 : 610.0;
    shots.add(
      Shot(
        player.x + direction * 34,
        player.y - 42,
        direction * speed,
        damage,
        charged,
        1.7,
        0.0,
        charged ? 5 : 1,
        false,
      ),
    );
    for (int i = 1; i < player.tails; i += 1) {
      shots.add(
        Shot(
          player.x - direction * (5 + i * 2),
          player.y - 28 - (i % 3) * 10,
          direction * (speed * 0.92),
          charged ? 0.55 : 0.28,
          false,
          1.7,
          i * 0.045,
          1,
          true,
        ),
      );
    }
    player.action = charged ? "charged_release" : "shoot";
    player.actionTime = charged ? 0.34 : 0.2;
    player.fireCooldown = charged ? 0.35 : 0.16;
    emit("sound", {"name": charged ? "charge" : "shot"});
    if (charged) {
      shake = max(shake, 6);
      flash = 0.12;
    }
  }

  void feralStrike() {
    if (player.fireCooldown > 0) return;
    final attacks = player.grounded
        ? ["claw_combo", "pounce", "rising_slash"]
        : ["claw_combo", "landing_smash"];
    player.action = attacks[feralCombo % attacks.length];
    feralCombo += 1;
    player.actionTime = 0.38;
    player.fireCooldown = 0.42;
    addEffect(
      "claw_arc",
      player.x + player.facing * 58,
      player.y - 35,
      0.34,
      0.26,
      player.facing,
    );
    for (final foe in enemies) {
      if (!foe.alive) continue;
      final ahead = (foe.x - player.x) * player.facing;
      if (ahead > -20 && ahead < 135 && (foe.y - player.y).abs() < 105) {
        damageEnemy(foe, 6);
      }
    }
    emit("sound", {"name": "claw"});
    shake = max(shake, 5);
  }

  int feralCombo = 0;

  void plantOfuda() {
    if (player.ofudaCooldown > 0 || player.spiritTime > 0) return;
    ofudas.add(
      Ofuda(
        player.x + player.facing * 24,
        player.y - 45,
        player.facing * 230,
        -190,
        false,
        7,
      ),
    );
    player.ofudaCooldown = 3;
    player.action = "ofuda_throw";
    player.actionTime = 0.32;
    emit("sound", {"name": "ofuda"});
  }

  void doDash() {
    if (player.dashCooldown > 0) return;
    player.dashTime = 0.22;
    player.dashCooldown = 0.72;
    player.invulnerable = max(player.invulnerable, 0.28);
    player.vx = player.facing * (player.spiritTime > 0 ? 920 : 760);
    player.vy = 0;
    clone = Clone(player.x, player.y, 1.65, player.facing);
    addEffect(
      "dash_trail",
      player.x,
      player.y - 15,
      0.34,
      0.28,
      -player.facing,
    );
    emit("sound", {"name": "dash"});
  }

  void activateSpirit() {
    if (player.spirit < 100 || player.spiritTime > 0) return;
    player.spirit = 0;
    player.spiritTime = 8;
    player.invulnerable = max(player.invulnerable, 0.65);
    player.action = "spirit_transform";
    player.actionTime = 0.7;
    addEffect("transform_burst", player.x, player.y - 25, 0.72, 0.42);
    shake = 10;
    flash = 0.35;
    emit("sound", {"name": "transform"});
    emit("haptic", {"strength": "heavy"});
  }

  void damagePlayer(double sourceX) {
    // respawnTimer covers the whole time the player is down. Checking the
    // action name alone failed because any other action overwrote "defeat",
    // which let tails go negative and scheduled several respawns.
    if (player.invulnerable > 0 || player.dashTime > 0 || respawnTimer > 0) {
      return;
    }
    if (player.spiritTime > 0) {
      player.invulnerable = 0.45;
      player.action = "feral_hit";
      player.actionTime = 0.3;
      shake = max(shake, 4);
      emit("sound", {"name": "hit"});
      return;
    }
    player.tails -= 1;
    player.hitCount += 1;
    player.invulnerable = 1.15;
    player.vx = player.x < sourceX ? -310 : 310;
    player.vy = -280;
    player.action = player.tails <= 0 ? "defeat" : "damage";
    player.actionTime = player.tails <= 0 ? 0.78 : 0.42;
    combo = 0;
    addEffect("hit_sparks", player.x, player.y - 38, 0.32, 0.19);
    shake = 8;
    flash = 0.2;
    emit("sound", {"name": player.tails <= 0 ? "defeat" : "damage"});
    emit("haptic", {"strength": "medium"});
    _log(
      "DAMAGE tails=${player.tails} source=${sourceX.toStringAsFixed(0)} "
      "at=(${player.x.toStringAsFixed(0)},${player.y.toStringAsFixed(0)})",
    );
    if (player.tails <= 0) respawnTimer = 0.72;
  }

  void respawn() {
    _log(
      "RESPAWN from=(${player.x.toStringAsFixed(0)},${player.y.toStringAsFixed(0)}) "
      "to=(${checkpointX.toStringAsFixed(0)},466)",
    );
    respawnTimer = 0;
    player.charging = false;
    player.chargeTime = 0;
    player.dashTime = 0;
    player.x = checkpointX;
    player.y = 466;
    player.vx = 0;
    player.vy = 0;
    player.tails = 3;
    player.invulnerable = 1.2;
    player.action = "checkpoint_revive";
    player.actionTime = 0.65;
    score = max(0, score - 350);
    emit("toast", {"text": "Spirit tails restored"});
    emit("sound", {"name": "respawn"});
  }

  void damageEnemy(Foe foe, double amount) {
    if (!foe.alive) return;
    foe.hp -= amount;
    foe.state = "hit";
    foe.stateTime = 0.2;
    addEffect(
      "hit_sparks",
      foe.x,
      foe.y - foe.stat.h * 0.55,
      0.25,
      foe.boss ? 0.23 : 0.14,
    );
    emit("sound", {"name": "hit"});
    if (foe.hp > 0) return;
    foe.alive = false;
    emit("sound", {"name": "enemy_defeat"});
    foe.deathTime = 0;
    score += ENEMY_STATS[foe.type]!.score + combo * 25;
    combo += 1;
    comboTimer = 3;
    player.spirit = clamp(player.spirit + (foe.boss ? 55 : 18), 0, 100);
    addEffect(
      "robot_explosion",
      foe.x,
      foe.y - foe.stat.h / 2,
      foe.boss ? 0.75 : 0.48,
      foe.boss ? 0.38 : 0.22,
    );
    if (foe.boss) {
      completeTimer = 1.8;
      player.spirit = 100;
      shake = 14;
      flash = 0.4;
      emit("sound", {"name": "boss"});
    }
  }

  void resolvePlayerCollisions(double dt) {
    player.wallSide = 0;
    player.x += player.vx * dt;
    var rect = _playerRect();
    for (final platform in level.platforms) {
      if (!overlaps(
        rect.x,
        rect.y,
        rect.w,
        rect.h,
        platform.x,
        platform.y,
        platform.w,
        platform.h,
      )) {
        continue;
      }
      if (player.vx > 0) {
        player.x = platform.x - player.w / 2;
        player.wallSide = 1;
      } else if (player.vx < 0) {
        player.x = platform.x + platform.w + player.w / 2;
        player.wallSide = -1;
      }
      player.vx = 0;
      rect = _playerRect();
    }
    for (final puzzle in level.puzzles) {
      if (puzzle.solved) continue;
      final gx = puzzle.x + 150;
      final gy = 185;
      final gw = 46;
      final gh = 281;
      if (!overlaps(rect.x, rect.y, rect.w, rect.h, gx, gy, gw, gh)) continue;
      if (player.vx > 0) {
        player.x = gx - player.w / 2;
        player.wallSide = 1;
      } else if (player.vx < 0) {
        player.x = gx + gw + player.w / 2;
        player.wallSide = -1;
      }
      player.vx = 0;
      rect = _playerRect();
    }

    final oldY = player.y;
    player.y += player.vy * dt;
    player.grounded = false;
    rect = _playerRect();
    for (final platform in level.platforms) {
      if (!overlaps(
        rect.x,
        rect.y,
        rect.w,
        rect.h,
        platform.x,
        platform.y,
        platform.w,
        platform.h,
      )) {
        continue;
      }
      if (player.vy >= 0 && oldY <= platform.y + 8) {
        player.y = platform.y;
        player.vy = 0;
        player.grounded = true;
      } else if (player.vy < 0 &&
          oldY - player.h >= platform.y + platform.h - 8) {
        player.y = platform.y + platform.h + player.h;
        player.vy = 0;
      }
      rect = _playerRect();
    }
  }

  _Rect _playerRect() =>
      _Rect(player.x - player.w / 2, player.y - player.h, player.w, player.h);
  _Rect _enemyRect(Foe foe) =>
      _Rect(foe.x - foe.stat.w / 2, foe.y - foe.stat.h, foe.stat.w, foe.stat.h);

  void solvePuzzle(Puzzle puzzle) {
    if (puzzle.solved) return;
    puzzle.solved = true;
    score += 900 + level.id * 80;
    player.spirit = min(100, player.spirit + 22);
    addEffect("transform_burst", puzzle.x, 360, 0.55, 0.24);
    shake = max(shake, 7);
    emit("sound", {"name": "puzzle"});
    emit("toast", {"text": "District seal ${puzzle.id + 1} released"});
  }

  // Where projectiles leave the body: chest height, a little in front.
  Offset _muzzle(Foe foe) =>
      Offset(foe.x + foe.facing * foe.stat.w * 0.35, foe.y - foe.stat.h * 0.55);

  // Picks the attack and locks its aim at the start of the wind-up.
  void _beginTelegraph(Foe foe) {
    final stats = foe.stat;
    final decoy = clone != null && clone!.ttl > 0;
    foe.aimX = decoy ? clone!.x : player.x;
    foe.aimY = decoy ? clone!.y - 35 : player.y - 38;
    foe.attackCount += 1;
    final close = (foe.aimX - foe.x).abs() < 170;
    if (stats.melee || (!stats.flying && !foe.boss && !foe.miniBoss && close)) {
      foe.pattern = "slash";
    } else if (foe.boss && foe.attackCount % 3 == 0) {
      foe.pattern = "nova";
    } else if (foe.miniBoss && foe.attackCount.isEven) {
      foe.pattern = "bomb";
    } else {
      foe.pattern = "bolt";
    }
    foe.state = "telegraph";
    var wind = stats.telegraphTime ?? (foe.boss ? 0.55 : 0.32);
    if (foe.pattern == "nova") wind *= 1.5;
    if (foe.pattern == "slash") wind = max(wind, 0.36);
    foe.stateTime = wind;
    foe.stateDuration = wind;
    foe.facing = foe.aimX < foe.x ? -1 : 1;
    if (foe.boss || foe.miniBoss) emit("sound", {"name": "enemy_charge"});
  }

  void spawnEnemyAttack(Foe foe) {
    final stats = foe.stat;
    final muzzle = _muzzle(foe);
    final speed = stats.projectileSpeed;
    final enraged = foe.boss && foe.hp < foe.maxHp * 0.45;
    switch (foe.pattern) {
      case "slash":
        foe.slashLanded = false;
        emit("sound", {"name": "enemy_slash"});
        return;
      case "nova":
        // An even ring of slower orbs, one aimed at the target; the spacing
        // leaves room to slip between them with a jump or dash.
        final count = enraged ? 16 : 12;
        final aim = atan2(foe.aimY - muzzle.dy, foe.aimX - muzzle.dx);
        for (var i = 0; i < count; i += 1) {
          final angle = aim + i * 2 * pi / count;
          enemyShots.add(
            EnemyShot(
              muzzle.dx,
              muzzle.dy,
              cos(angle) * speed * 0.62,
              sin(angle) * speed * 0.62,
              4,
              false,
              "nova_orb",
              color: const Color(0xFFFFC94F),
              radius: 11,
            ),
          );
        }
        blasts.add(Blast(muzzle.dx, muzzle.dy, 120, const Color(0xFFFFC94F), 0.45));
        shake = max(shake, 9);
        flash = max(flash, 0.12);
        emit("sound", {"name": "boss_nova"});
        return;
      case "bomb":
        // Lobbed lanterns that land around the target and burst on impact.
        const gravity = 900.0;
        const flight = 0.95;
        for (var i = -1; i <= 1; i += 1) {
          final landX = foe.aimX + i * 70;
          final dx = landX - muzzle.dx;
          final dy = (foe.aimY + 38) - muzzle.dy;
          enemyShots.add(
            EnemyShot(
              muzzle.dx,
              muzzle.dy,
              dx / flight,
              (dy - 0.5 * gravity * flight * flight) / flight,
              3,
              false,
              "lantern_bomb",
              gravity: gravity,
              bomb: true,
              color: const Color(0xFFFF9A3C),
              radius: 12,
            ),
          );
        }
        addEffect("hit_sparks", muzzle.dx, muzzle.dy + 20, 0.25, 0.16);
        emit("sound", {"name": "enemy_shot"});
        return;
      default:
        final count = stats.shotCount + (enraged ? 2 : 0);
        final base = atan2(foe.aimY - muzzle.dy, foe.aimX - muzzle.dx);
        final color = stats.homing
            ? const Color(0xFFFF4FD8)
            : foe.boss
            ? const Color(0xFFFF6A9A)
            : const Color(0xFF49E8FF);
        for (var i = 0; i < count; i += 1) {
          final angle = base + (i - (count - 1) / 2) * 0.16;
          enemyShots.add(
            EnemyShot(
              muzzle.dx,
              muzzle.dy,
              cos(angle) * speed,
              sin(angle) * speed,
              4,
              stats.homing,
              stats.homing ? "homing_missile" : "kasa_bolt",
              color: color,
              radius: foe.boss ? 11 : 9,
            ),
          );
        }
        addEffect("hit_sparks", muzzle.dx, muzzle.dy + 18, 0.2, foe.boss ? 0.2 : 0.13);
        if (foe.boss) shake = max(shake, 4);
        emit("sound", {"name": "enemy_shot"});
    }
  }

  bool _hitsGround(double x, double y) {
    for (final platform in level.platforms) {
      if (x >= platform.x &&
          x <= platform.x + platform.w &&
          y >= platform.y &&
          y <= platform.y + platform.h) {
        return true;
      }
    }
    return false;
  }

  void _explodeBomb(EnemyShot p) {
    p.ttl = 0;
    blasts.add(Blast(p.x, p.y, 78, p.color, 0.4));
    addEffect("robot_explosion", p.x, p.y + 10, 0.4, 0.2);
    shake = max(shake, 5);
    emit("sound", {"name": "bomb_explode"});
    final dx = player.x - p.x;
    final dy = (player.y - 35) - p.y;
    if (dx * dx + dy * dy < 70 * 70) damagePlayer(p.x);
  }

  // Ground enemies lunge at the locked target and hit once mid-swing.
  void _updateSlash(Foe foe, double dt) {
    final t = 1 - foe.stateTime / foe.stateDuration;
    if (t < 0.55) {
      foe.x = clamp(
        foe.x + foe.facing * 340 * dt,
        foe.startX - 140,
        foe.startX + 140,
      );
    }
    if (!foe.slashLanded && t >= 0.35) {
      foe.slashLanded = true;
      final cx = foe.x + foe.facing * foe.stat.w * 0.6;
      final cy = foe.y - foe.stat.h * 0.5;
      slashes.add(
        Slash(cx, cy, foe.stat.h * 0.95, foe.facing, const Color(0xFF7FF3FF), 0.26),
      );
      shake = max(shake, 4);
      final pr = _playerRect();
      final reach = foe.stat.w * 0.6 + foe.stat.h * 0.6;
      final front = foe.facing > 0
          ? Rect.fromLTWH(foe.x, foe.y - foe.stat.h - 10, reach, foe.stat.h + 10)
          : Rect.fromLTWH(foe.x - reach, foe.y - foe.stat.h - 10, reach, foe.stat.h + 10);
      if (overlaps(pr.x, pr.y, pr.w, pr.h, front.left, front.top, front.width, front.height)) {
        damagePlayer(foe.x);
      }
    }
  }

  void updateEnemy(Foe foe, double dt) {
    if (!foe.alive) {
      foe.deathTime += dt;
      return;
    }
    if ((foe.x - player.x).abs() > 1050 && !foe.boss) return;
    final stats = foe.stat;
    foe.cooldown -= dt * config.enemyAggression;
    foe.stateTime -= dt;
    foe.facing = player.x < foe.x ? -1 : 1;
    if (stats.flying) foe.y += sin(elapsed * 2.4 + foe.startX) * 12 * dt;

    if (foe.state == "telegraph") {
      // Keep facing the locked target, not the player's current position.
      foe.facing = foe.aimX < foe.x ? -1 : 1;
      if (foe.stateTime <= 0) {
        foe.state = "attack";
        foe.stateTime = foe.pattern == "slash"
            ? 0.42
            : foe.boss
            ? 0.72
            : 0.45;
        foe.stateDuration = foe.stateTime;
        spawnEnemyAttack(foe);
      }
      return;
    }
    if (foe.state == "attack") {
      foe.facing = foe.aimX < foe.x ? -1 : 1;
      if (foe.pattern == "slash") _updateSlash(foe, dt);
      if (foe.stateTime <= 0) foe.state = "idle";
      return;
    }
    if (foe.state == "hit") {
      if (foe.stateTime <= 0) foe.state = "idle";
      return;
    }

    final dx = player.x - foe.x;
    if (foe.cooldown <= 0 && dx.abs() < (foe.boss ? 720 : 560)) {
      _beginTelegraph(foe);
      foe.cooldown =
          ((stats.attackDelay) + _random.nextDouble() * 0.55) /
          config.enemyAggression;
      return;
    }

    if (!stats.flying && !(stats.melee) && dx.abs() > (foe.boss ? 210 : 150)) {
      foe.x += dx.sign * (stats.speed) * dt;
      foe.x = clamp(
        foe.x,
        foe.startX - (foe.boss ? 280 : 90),
        foe.startX + (foe.boss ? 150 : 90),
      );
      foe.state = "move";
    } else {
      foe.state = "idle";
    }

    final pr = _playerRect();
    final er = _enemyRect(foe);
    if (overlaps(pr.x, pr.y, pr.w, pr.h, er.x, er.y, er.w, er.h)) {
      damagePlayer(foe.x);
    }
  }

  void updateProjectiles(double dt) {
    for (final shot in shots) {
      if (shot.delay > 0) {
        shot.delay -= dt;
        continue;
      }
      shot.x += shot.vx * dt;
      shot.ttl -= dt;
      final bx = shot.x - (shot.charged ? 28 : 11);
      final by = shot.y - 10;
      final bw = shot.charged ? 56 : 22;
      final bh = 20;
      for (final puzzle in level.puzzles) {
        if (puzzle.solved || !["shoot", "charge"].contains(puzzle.action)) {
          continue;
        }
        final tx = puzzle.x - 28;
        final ty = 300;
        final tw = 56;
        final th = 86;
        if (overlaps(bx, by, bw, bh, tx, ty, tw, th) &&
            (puzzle.action != "charge" || shot.charged)) {
          solvePuzzle(puzzle);
          shot.ttl = 0;
        }
      }
      for (final foe in enemies) {
        if (!foe.alive) continue;
        final er = _enemyRect(foe);
        if (!overlaps(bx, by, bw, bh, er.x, er.y, er.w, er.h)) continue;
        damageEnemy(foe, shot.damage);
        shot.pierce -= 1;
        if (shot.pierce <= 0) {
          shot.ttl = 0;
          break;
        }
      }
    }
    final pr = _playerRect();
    for (final p in enemyShots) {
      if (p.homing) {
        final tx = clone != null && clone!.ttl > 0 ? clone!.x : player.x;
        final ty = clone != null && clone!.ttl > 0
            ? clone!.y - 35
            : player.y - 38;
        final angle = atan2(ty - p.y, tx - p.x);
        p.vx += cos(angle) * 110 * dt;
        p.vy += sin(angle) * 110 * dt;
        final s = sqrt(p.vx * p.vx + p.vy * p.vy);
        if (s > 330) {
          p.vx *= 330 / s;
          p.vy *= 330 / s;
        }
      }
      p.age += dt;
      p.trail.insert(0, Offset(p.x, p.y));
      if (p.trail.length > 7) p.trail.removeLast();
      p.vy += p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.ttl -= dt;
      if (p.bomb && p.vy > 0 && _hitsGround(p.x, p.y)) {
        _explodeBomb(p);
        continue;
      }
      if (p.y > 640) p.ttl = 0;
      if (clone != null &&
          clone!.ttl > 0 &&
          distanceSq(p.x, p.y, clone!.x, clone!.y - 35) < 32 * 32) {
        p.ttl = 0;
        addEffect("hit_sparks", clone!.x, clone!.y - 35, 0.28, 0.14);
      } else if (overlaps(
        p.x - 9,
        p.y - 9,
        18,
        18,
        pr.x,
        pr.y,
        pr.w,
        pr.h,
      )) {
        p.ttl = 0;
        damagePlayer(p.x);
      }
    }
    for (final mine in ofudas) {
      mine.ttl -= dt;
      if (!mine.stuck) {
        mine.vy += 760 * dt;
        mine.x += mine.vx * dt;
        mine.y += mine.vy * dt;
        if (mine.y >= 454) {
          mine.y = 454;
          mine.vx = 0;
          mine.vy = 0;
          mine.stuck = true;
        }
      }
      final hasTarget = enemies.any(
        (foe) =>
            foe.alive && distanceSq(mine.x, mine.y, foe.x, foe.y) < 95 * 95,
      );
      if (hasTarget || mine.ttl <= 0) {
        mine.ttl = -1;
        addEffect("ofuda_explosion", mine.x, mine.y, 0.5, 0.25);
        for (final foe in enemies) {
          if (foe.alive && distanceSq(mine.x, mine.y, foe.x, foe.y) < 125 * 125) {
            damageEnemy(foe, 5);
          }
        }
        for (final puzzle in level.puzzles) {
          if (!puzzle.solved &&
              puzzle.action == "ofuda" &&
              (mine.x - puzzle.x).abs() < 135) {
            solvePuzzle(puzzle);
          }
        }
        shake = max(shake, 7);
        emit("sound", {"name": "ofuda"});
      }
    }
    for (final s in slashes) {
      s.ttl -= dt;
    }
    for (final b in blasts) {
      b.ttl -= dt;
    }
    slashes.removeWhere((s) => s.ttl <= 0);
    blasts.removeWhere((b) => b.ttl <= 0);
    shots.removeWhere((s) => s.ttl <= 0);
    enemyShots.removeWhere((s) => s.ttl <= 0);
    ofudas.removeWhere((s) => s.ttl < 0);
  }

  void updatePickups() {
    final rect = _playerRect();
    for (final item in level.pickups) {
      if (!item.alive) continue;
      if (!overlaps(
        rect.x,
        rect.y,
        rect.w,
        rect.h,
        item.x - 22,
        item.y - 22,
        44,
        44,
      )) {
        continue;
      }
      item.alive = false;
      if (item.type == "tail") {
        player.tails = min(9, player.tails + 1);
        player.maxTails = max(player.maxTails, player.tails);
        player.action = "tail_gain";
        player.actionTime = 0.48;
        addEffect("tail_pickup_fx", player.x, player.y - 40, 0.55, 0.27);
        emit("toast", {"text": "Tail ${player.tails}/9"});
        emit("sound", {"name": "tail"});
      } else {
        player.spirit = min(100, player.spirit + 28);
        addEffect("spirit_shard_fx", item.x, item.y, 0.42, 0.2);
        emit("sound", {"name": "spirit"});
      }
      score += item.type == "tail" ? 500 : 180;
    }
  }

  void update(double dt, InputState input) {
    if (paused) return;
    elapsed += dt;
    final startX = player.x;
    final startY = player.y;
    final startVx = player.vx;
    final startVy = player.vy;
    var plannedTeleport = false;
    if (respawnTimer > 0) {
      respawnTimer -= dt;
      if (respawnTimer <= 0) {
        respawn();
        plannedTeleport = true;
      }
    }
    // A downed player keeps falling but ignores controls until revived.
    final locked = respawnTimer > 0;
    final held = locked ? _noInput : input.held;
    shake = max(0, shake - dt * 22);
    flash = max(0, flash - dt * 1.8);
    comboTimer -= dt;
    if (comboTimer <= 0) combo = 0;
    if (clone != null) {
      clone!.ttl -= dt;
      if (clone!.ttl <= 0) clone = null;
    }
    for (final effect in effects) {
      effect.ttl -= dt;
    }
    effects.removeWhere((e) => e.ttl <= 0);

    player.invulnerable = max(0, player.invulnerable - dt);
    player.dashCooldown = max(0, player.dashCooldown - dt);
    player.fireCooldown = max(0, player.fireCooldown - dt);
    player.ofudaCooldown = max(0, player.ofudaCooldown - dt);
    player.actionTime = max(0, player.actionTime - dt);
    if (player.spiritTime > 0) {
      player.spiritTime = max(0, player.spiritTime - dt);
      if (player.spiritTime == 0) {
        player.action = "spirit_return";
        player.actionTime = 0.55;
      }
    }

    if (!locked && input.consume("spirit")) activateSpirit();
    if (!locked && input.consume("dash")) doDash();
    if (!locked && input.consume("ofuda")) plantOfuda();
    if (!locked && input.consume("fire")) {
      if (player.spiritTime > 0) {
        feralStrike();
      } else {
        player.charging = true;
        player.chargeTime = 0;
      }
    }
    if (player.charging && held["fire"]!) {
      player.chargeTime = min(1.4, player.chargeTime + dt);
    }
    if (!locked && player.charging && input.consumeRelease("fire")) {
      if (player.fireCooldown <= 0) spawnShot(player.chargeTime >= 0.62);
      player.charging = false;
      player.chargeTime = 0;
    }

    if (!locked && input.consume("jump")) player.jumpBuffer = _jumpBufferTime;
    if (!locked && player.jumpBuffer > 0) {
      if (player.grounded || player.coyote > 0) {
        player.vy = player.spiritTime > 0 ? -610 : -535;
        player.grounded = false;
        player.coyote = 0;
        player.jumpBuffer = 0;
        // A landing pose would otherwise keep showing while rising.
        player.actionTime = 0;
        emit("sound", {"name": "jump"});
      } else if (player.wallSide != 0) {
        player.vx = -player.wallSide * 360;
        player.vy = -510;
        player.facing = -player.wallSide;
        player.action = "wall_jump";
        player.actionTime = 0.28;
        player.jumpBuffer = 0;
        emit("sound", {"name": "wall_jump"});
      } else if (player.airJumps > 0) {
        // Full-height second jump that also cancels any fall speed, so it
        // works the same whether pressed at the peak or late in a fall.
        player.airJumps -= 1;
        player.vy = player.spiritTime > 0 ? -580 : -520;
        player.jumpBuffer = 0;
        player.actionTime = 0;
        addEffect("tail_pickup_fx", player.x, player.y + 6, 0.3, 0.13);
        emit("sound", {"name": "double_jump"});
      }
    }
    player.jumpBuffer = max(0, player.jumpBuffer - dt);

    final move = (held["right"]! ? 1 : 0) - (held["left"]! ? 1 : 0);
    if (move != 0) player.facing = move;
    if (player.dashTime > 0) {
      player.dashTime -= dt;
      player.vx = player.facing * (player.spiritTime > 0 ? 920 : 760);
    } else {
      final speed = config.playerSpeed * (player.spiritTime > 0 ? 1.42 : 1);
      final acceleration = player.grounded ? 1800 : 1150;
      player.vx += clamp(
        move * speed - player.vx,
        -acceleration * dt,
        acceleration * dt,
      );
      if (move == 0 && player.grounded) player.vx *= pow(0.0008, dt);
      var gravity = 1420;
      if (held["jump"]! && player.vy > 0 && player.spiritTime <= 0) {
        gravity = 330;
      }
      player.vy += gravity * dt;
      if (held["jump"]! && player.vy > 0) player.vy = min(player.vy, 150);
      if (level.wind != 0 && !player.grounded) player.vx += level.wind * dt;
    }
    player.coyote = player.grounded ? _coyoteTime : max(0, player.coyote - dt);
    final wasGrounded = player.grounded;
    resolvePlayerCollisions(dt);
    if (player.grounded || player.wallSide != 0) player.airJumps = 1;
    if (!wasGrounded && player.grounded && player.actionTime <= 0) {
      player.action = player.spiritTime > 0 ? "landing_smash" : "land";
      player.actionTime = 0.28;
      emit("sound", {"name": "land"});
    }
    if (player.wallSide != 0 &&
        !player.grounded &&
        player.vy > 0 &&
        ((player.wallSide == 1 && held["right"]!) ||
            (player.wallSide == -1 && held["left"]!))) {
      player.vy = min(player.vy, 95);
    }
    player.x = clamp(player.x, 20, level.length - 20);
    if (player.grounded && !locked && _standsWellInsideFloor()) {
      safeX = player.x;
      safeY = player.y;
    }
    if (!locked && player.y > 610) {
      _log(
        "PIT_FALL at=(${player.x.toStringAsFixed(0)},${player.y.toStringAsFixed(0)}) "
        "tails=${player.tails} safe=(${safeX.toStringAsFixed(0)},${safeY.toStringAsFixed(0)})",
      );
      damagePlayer(player.x + 1);
      if (player.tails > 0) {
        // Back onto the last solid ground instead of all the way to the
        // checkpoint, which can be thousands of units behind.
        player.x = safeX;
        player.y = safeY;
        player.vx = 0;
        player.vy = 0;
        plannedTeleport = true;
      }
    }

    // Spikes only hurt when the body is clearly over them. Using the full strip
    // made the edge of every floor hurt and bounced the player back.
    if (!locked) {
      final hr = _playerRect();
      for (final hazard in level.hazards) {
        if (overlaps(
              hr.x,
              hr.y,
              hr.w,
              hr.h,
              hazard.x + _hazardInset,
              hazard.y,
              hazard.w - _hazardInset * 2,
              hazard.h,
            ) &&
            player.spiritTime <= 0) {
          _log(
            "HAZARD at=(${player.x.toStringAsFixed(0)},${player.y.toStringAsFixed(0)}) "
            "strip=${hazard.x.toStringAsFixed(0)}..${(hazard.x + hazard.w).toStringAsFixed(0)}",
          );
          damagePlayer(hazard.x + hazard.w / 2);
        }
      }
    }
    final nextCheckpoint = checkpointIndex + 1 < level.checkpoints.length
        ? level.checkpoints[checkpointIndex + 1]
        : null;
    if (!locked && nextCheckpoint != null && player.x >= nextCheckpoint) {
      checkpointIndex += 1;
      checkpointX = nextCheckpoint;
      _log("CHECKPOINT x=${checkpointX.toStringAsFixed(0)}");
      player.tails = max(3, player.tails);
      emit("toast", {"text": "Checkpoint purified"});
      emit("sound", {"name": "checkpoint"});
    }

    for (final puzzle in level.puzzles) {
      if (puzzle.solved) continue;
      final near = (player.x - puzzle.x).abs() < 145;
      if (!puzzle.hinted && (player.x - puzzle.x).abs() < 360) {
        puzzle.hinted = true;
        emit("toast", {"text": puzzle.hint});
      }
      if (!near) continue;
      if (puzzle.action == "dash" && player.dashTime > 0) {
        solvePuzzle(puzzle);
      } else if (puzzle.action == "spirit" && player.spiritTime > 0) {
        solvePuzzle(puzzle);
      } else if (puzzle.action == "glide" &&
          !player.grounded &&
          held["jump"]! &&
          player.vy > 0) {
        solvePuzzle(puzzle);
      } else if (puzzle.action == "clone" &&
          clone != null &&
          clone!.ttl > 0 &&
          (clone!.x - puzzle.x).abs() < 170) {
        solvePuzzle(puzzle);
      }
    }

    for (final foe in enemies) {
      if (foe.boss && foe.alive && player.x > foe.x - 900) bossRevealed = true;
      updateEnemy(foe, dt);
    }
    updateProjectiles(dt);
    updatePickups();
    if (completeTimer > 0) {
      completeTimer -= dt;
      if (completeTimer <= 0) {
        completeTimer = -1;
        emit("complete", {
          "score": score,
          "elapsed": elapsed,
          "hitCount": player.hitCount,
          "maxTails": player.maxTails,
          "mode": mode,
        });
      }
    }

    // Anything that moves further than speed*dt allows (plus a margin) and was
    // not a planned teleport is worth a log line.
    final allowX = max(startVx.abs(), player.vx.abs()) * dt + 40;
    final allowY = max(startVy.abs(), player.vy.abs()) * dt + 40;
    if (!plannedTeleport &&
        ((player.x - startX).abs() > allowX ||
            (player.y - startY).abs() > allowY)) {
      _log(
        "JUMP from=(${startX.toStringAsFixed(0)},${startY.toStringAsFixed(0)}) "
        "to=(${player.x.toStringAsFixed(0)},${player.y.toStringAsFixed(0)}) "
        "vx=${player.vx.toStringAsFixed(0)} vy=${player.vy.toStringAsFixed(0)} "
        "action=${player.action}",
      );
    }
    if (elapsed - _lastPosLog >= 0.5) {
      _lastPosLog = elapsed;
      _log(
        "POS x=${player.x.toStringAsFixed(1)} y=${player.y.toStringAsFixed(1)} "
        "vx=${player.vx.toStringAsFixed(0)} vy=${player.vy.toStringAsFixed(0)} "
        "grounded=${player.grounded} wall=${player.wallSide} tails=${player.tails} "
        "action=${player.action} inv=${player.invulnerable.toStringAsFixed(2)} "
        "dead=${respawnTimer > 0} cam=${lastCameraX.toStringAsFixed(0)} "
        "anim=$lastPlayerAnim ${lastPlayerFrameInfo ?? ''}",
      );
    }
    input.resetEdges();
  }

  String currentPlayerAnimation(InputState? input) {
    if (player.actionTime > 0 && player.action.isNotEmpty) return player.action;
    if (player.spiritTime > 0) {
      if (!player.grounded) return "feral_leap";
      return player.vx.abs() > 35 ? "feral_run" : "feral_idle";
    }
    if (player.dashTime > 0) return player.grounded ? "dash" : "air_dash";
    if (player.charging) return "charge";
    if (!player.grounded && player.wallSide != 0 && player.vy > 0) {
      return "wall_slide";
    }
    if (!player.grounded &&
        input != null &&
        input.held["jump"]! &&
        player.vy > 0) {
      return "tail_glide";
    }
    if (!player.grounded) return player.vy < 0 ? "jump_up" : "fall";
    return player.vx.abs() > 35 ? "run" : "idle";
  }

  String enemyAnimation(Foe foe) {
    final stats = foe.stat;
    if (!foe.alive) return stats.defeat;
    if (foe.state == "hit") return stats.hit;
    if (foe.state == "attack") return stats.attack;
    if (foe.state == "telegraph") return stats.attack;
    if (foe.state == "move") return stats.move;
    return stats.idle;
  }

  void render(Renderer renderer, double time, InputState input) {
    final camX = cameraX(renderer.viewWidth);
    lastCameraX = camX;
    renderer.begin(
      level,
      camX,
      time,
      shake * config.effectsIntensity,
      flash * config.effectsIntensity,
    );
    // Only draw what can be on screen; the level is ~26k units wide.
    final viewLeft = camX - 320;
    final viewRight = camX + renderer.viewWidth + 320;
    bool visible(double x, [double w = 0]) => x + w >= viewLeft && x <= viewRight;
    for (final platform in level.platforms) {
      if (visible(platform.x, platform.w)) {
        renderer.drawPlatform(level.tiles, platform);
      }
    }
    for (final hazard in level.hazards) {
      if (!visible(hazard.x, hazard.w)) continue;
      final count = (hazard.w / 42).ceil();
      for (int i = 0; i < count; i += 1) {
        renderer.drawStatic(
          "roof_spike",
          hazard.x + i * 42,
          hazard.y - 20,
          46,
          44,
        );
      }
    }
    final cpList = level.checkpoints;
    for (int i = 0; i < cpList.length; i += 1) {
      if (!visible(cpList[i])) continue;
      renderer.drawStatic(
        "checkpoint_lantern",
        cpList[i] - 30,
        388,
        60,
        78,
        i <= checkpointIndex ? 1 : 0.62,
      );
    }

    for (final puzzle in level.puzzles) {
      if (!visible(puzzle.x)) continue;
      final prefix = "s${level.id.toString().padLeft(2, '0')}_";
      renderer.drawStatic(
        "${prefix}rune",
        puzzle.x - 48,
        416,
        96,
        48,
        puzzle.solved ? 0.5 : 1,
      );
      renderer.drawStatic(
        "${prefix}target",
        puzzle.x - 34,
        300,
        68,
        82,
        puzzle.solved ? 0.38 : 1,
      );
      renderer.drawStatic(
        "${prefix}beacon",
        puzzle.x + 92,
        332,
        64,
        134,
        puzzle.solved ? 0.45 : 1,
      );
      if (!puzzle.solved) {
        renderer.drawStatic("${prefix}gate", puzzle.x + 132, 170, 84, 296, 0.9);
      } else {
        renderer.drawStatic(
          "${prefix}reward",
          puzzle.x + 145,
          330,
          52,
          60,
          0.65,
        );
      }
    }

    for (final item in level.pickups) {
      if (!item.alive || !visible(item.x)) continue;
      final bob = sin(time * 3 + item.phase) * 6;
      renderer.drawStatic(
        item.type == "tail" ? "tail_pickup" : "spirit_shard",
        item.x - 24,
        item.y - 24 + bob,
        48,
        48,
      );
    }
    for (final mine in ofudas) {
      renderer.drawStatic("ofuda_mine", mine.x - 16, mine.y - 30, 32, 34);
    }
    if (clone != null) {
      renderer.drawAnchored(
        "shadow_clone",
        clone!.x,
        clone!.y,
        0.19,
        clone!.facing,
        time,
        10,
        clamp(clone!.ttl / 1.2, 0.15, 0.7),
        null,
        40,
        56,
        const Color(0xFF9A6CFF),
      );
    }

    for (final foe in enemies) {
      if (!foe.alive && foe.deathTime > 0.62) continue;
      if (!visible(foe.x)) continue;
      final stats = foe.stat;
      final anim = enemyAnimation(foe);
      final scale = stats.spriteH / 360;
      // The attack row is played once: the first frames as the wind-up, the
      // rest as the strike, instead of looping on the clock.
      final phase = foe.stateDuration > 0
          ? clamp(1 - foe.stateTime / foe.stateDuration, 0, 1)
          : 0.0;
      final double? progress = !foe.alive
          ? clamp(foe.deathTime / 0.58, 0, 0.999)
          : foe.state == "telegraph"
          ? phase * 0.4
          : foe.state == "attack"
          ? min(0.999, 0.4 + phase * 0.6)
          : null;
      final tc = renderer.canvas;
      if (foe.alive && foe.state == "telegraph" && tc != null) {
        _drawTelegraph(tc, foe, time);
      }
      renderer.drawAnchored(
        anim,
        foe.x,
        foe.y,
        scale,
        // Enemy art is drawn facing left, so flip when the target is right.
        -foe.facing,
        time + foe.startX * 0.002,
        foe.boss ? 8 : 10,
        foe.alive ? 1 : 1 - clamp(foe.deathTime / 0.62, 0, 1),
        progress,
        stats.w,
        stats.spriteH,
        foe.boss ? const Color(0xFFFF4FD8) : const Color(0xFFE85A5A),
      );
      if (foe.boss && foe.alive && bossRevealed) {
        final c = renderer.canvas;
        if (c != null) {
          c.drawRect(
            Rect.fromLTWH(foe.x - 82, foe.y - foe.stat.h - 24, 164, 9),
            Paint()..color = const Color(0xD2050819),
          );
          c.drawRect(
            Rect.fromLTWH(
              foe.x - 79,
              foe.y - foe.stat.h - 21,
              158 * (foe.hp / foe.maxHp),
              3,
            ),
            Paint()
              ..color = level.id >= 8
                  ? const Color(0xFFFF4FD8)
                  : const Color(0xFF49E8FF),
          );
        }
      }
    }

    for (final shot in shots) {
      if (shot.delay > 0) continue;
      renderer.drawAnchored(
        shot.charged
            ? "charged_shot"
            : shot.tail
            ? "tail_volley"
            : "kitsunebi",
        shot.x,
        shot.y,
        shot.charged
            ? 0.18
            : shot.tail
            ? 0.075
            : 0.09,
        shot.vx.sign.toInt(),
        time,
        14,
        1,
        null,
        28,
        28,
        shot.charged ? const Color(0xFFFFD24F) : const Color(0xFF6FE3FF),
      );
    }
    final fx = renderer.canvas;
    if (fx != null) {
      for (final b in blasts) {
        _drawBlast(fx, b);
      }
      for (final p in enemyShots) {
        _drawEnemyShot(fx, p, time);
      }
      for (final s in slashes) {
        _drawSlash(fx, s);
      }
    }
    for (final effect in effects) {
      renderer.drawAnchored(
        effect.anim,
        effect.x,
        effect.y,
        effect.scale,
        effect.facing.toInt(),
        time,
        12,
        clamp(effect.ttl / 0.12, 0, 1),
        1 - effect.ttl / effect.duration,
        24,
        24,
        const Color(0xFFFFAA33),
      );
    }

    final playerAnim = currentPlayerAnimation(input);
    final playerScale =
        player.spiritTime > 0 && !playerAnim.contains("transform")
        ? 0.26
        : 0.215;
    final double? progress =
        player.actionTime > 0 &&
            [
              "spawn",
              "land",
              "tail_gain",
              "damage",
              "defeat",
              "checkpoint_revive",
              "spirit_transform",
              "spirit_return",
              "shoot",
              "charged_release",
              "ofuda_throw",
              "claw_combo",
              "wall_jump",
            ].contains(playerAnim)
        ? clamp(
            1 -
                player.actionTime /
                    (playerAnim == "defeat"
                        ? 0.78
                        : playerAnim.contains("spirit")
                        ? 0.7
                        : 0.48),
            0,
            0.999,
          )
        : null;
    final blink =
        player.invulnerable > 0 && (player.invulnerable * 15).floor() % 2 == 0
        ? 0.38
        : 1.0;
    // Start every looping animation on its first frame when it changes.
    if (playerAnim != lastPlayerAnim) _playerAnimStart = time;
    renderer.debugTrackName = playerAnim;
    renderer.debugTrackInfo = null;
    lastPlayerAnim = playerAnim;
    renderer.drawAnchored(
      playerAnim,
      player.x,
      player.y,
      playerScale,
      player.facing,
      time - _playerAnimStart,
      11,
      blink,
      progress,
      player.w,
      player.h,
      const Color(0xFFFF7AC0),
    );
    lastPlayerFrameInfo = renderer.debugTrackInfo;
    renderer.debugTrackName = null;
  }

  static const Color _warnColor = Color(0xFFFF4D6A);
  static const Color _white = Color(0xFFFFFFFF);

  Paint _glow(Color color, double alpha, double blur) => Paint()
    ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

  // Wind-up cue: "!" over the head and energy gathering at the muzzle. It shows
  // that an attack is coming but not where it will go.
  void _drawTelegraph(Canvas c, Foe foe, double time) {
    final p = clamp(1 - foe.stateTime / max(0.01, foe.stateDuration), 0, 1);
    final pulse = 0.5 + 0.5 * sin(time * 28);
    final muzzle = _muzzle(foe);
    final color = foe.pattern == "nova"
        ? const Color(0xFFFFC94F)
        : foe.pattern == "bomb"
        ? const Color(0xFFFF9A3C)
        : _warnColor;

    // Exclamation mark that pops in.
    final pop = min(1.0, p * 4);
    final hx = foe.x;
    final hy = foe.y - foe.stat.h - 20 - 6 * pop;
    c.drawCircle(Offset(hx, hy + 2), 13 * pop, _glow(color, 0.45, 8));
    final bar = Paint()..color = _white.withValues(alpha: pop);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(hx, hy - 2), width: 5 * pop, height: 13 * pop),
        const Radius.circular(3),
      ),
      bar,
    );
    c.drawCircle(Offset(hx, hy + 8 * pop), 2.6 * pop, bar);

    // Energy gathering at the muzzle.
    c.drawCircle(muzzle, 5 + 12 * p, _glow(color, 0.35 + 0.4 * pulse, 10));
    c.drawCircle(muzzle, 2 + 4 * p, Paint()..color = _white.withValues(alpha: 0.9));

    switch (foe.pattern) {
      case "nova":
        // Ring that collapses into the boss as it charges.
        c.drawCircle(
          muzzle,
          40 + 150 * (1 - p),
          Paint()
            ..color = color.withValues(alpha: 0.25 + 0.5 * p)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 + 5 * p,
        );
        break;
      case "slash":
        c.save();
        c.translate(foe.x, foe.y - foe.stat.h * 0.5);
        c.scale(foe.facing.toDouble(), 1);
        c.drawArc(
          Rect.fromCircle(center: Offset(foe.stat.w * 0.5, 0), radius: foe.stat.h * 0.9),
          -1.4,
          2.8,
          false,
          _glow(color, 0.3 + 0.5 * p * (0.6 + 0.4 * pulse), 4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 + 4 * p,
        );
        c.restore();
        break;
    }
  }

  void _drawEnemyShot(Canvas c, EnemyShot p, double time) {
    // Plain circles rather than blurred ones: blur filters are costly per
    // projectile per frame and were making gameplay stutter on phones.
    for (var i = p.trail.length - 1; i >= 0; i -= 1) {
      final f = 1 - i / p.trail.length;
      c.drawCircle(
        p.trail[i],
        p.radius * (0.35 + 0.55 * f),
        Paint()..color = p.color.withValues(alpha: 0.3 * f),
      );
    }
    final pos = Offset(p.x, p.y);
    final flicker = 0.85 + 0.15 * sin(time * 40 + p.age * 13);
    c.drawCircle(
      pos,
      p.radius * 1.9 * flicker,
      Paint()..color = p.color.withValues(alpha: 0.28),
    );
    if (p.homing) {
      c.save();
      c.translate(p.x, p.y);
      c.rotate(atan2(p.vy, p.vx));
      final body = Path()
        ..moveTo(p.radius * 1.4, 0)
        ..lineTo(-p.radius, -p.radius * 0.7)
        ..lineTo(-p.radius * 0.5, 0)
        ..lineTo(-p.radius, p.radius * 0.7)
        ..close();
      c.drawPath(body, Paint()..color = p.color);
      c.drawCircle(Offset.zero, p.radius * 0.35, Paint()..color = _white);
      c.restore();
    } else if (p.bomb) {
      c.drawCircle(pos, p.radius, Paint()..color = const Color(0xFF3A1A10));
      c.drawCircle(pos, p.radius * 0.72, Paint()..color = p.color);
      final spin = p.age * 9;
      c.drawCircle(
        pos + Offset(cos(spin), sin(spin)) * p.radius * 0.95,
        2.5,
        Paint()..color = _white,
      );
    } else {
      c.drawCircle(pos, p.radius * 0.95, Paint()..color = p.color);
      c.drawCircle(pos, p.radius * 0.5, Paint()..color = _white);
    }
  }

  void _drawSlash(Canvas c, Slash s) {
    final t = 1 - s.ttl / s.duration;
    final sweep = 2.7 * min(1.0, t * 2.2);
    final fade = 1 - t;
    c.save();
    c.translate(s.x, s.y);
    c.scale(s.facing.toDouble(), 1);
    final rect = Rect.fromCircle(center: Offset.zero, radius: s.radius * (0.85 + 0.2 * t));
    c.drawArc(
      rect,
      -1.75,
      sweep,
      false,
      _glow(s.color, 0.7 * fade, 9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18 * fade + 4,
    );
    c.drawArc(
      rect,
      -1.75,
      sweep,
      false,
      Paint()
        ..color = _white.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5 * fade + 1,
    );
    c.restore();
  }

  void _drawBlast(Canvas c, Blast b) {
    final t = 1 - b.ttl / b.duration;
    final r = b.radius * (1 - pow(1 - t, 3));
    final center = Offset(b.x, b.y);
    c.drawCircle(center, r, _glow(b.color, 0.25 * (1 - t), 14));
    c.drawCircle(
      center,
      r,
      Paint()
        ..color = b.color.withValues(alpha: 1 - t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9 * (1 - t) + 1,
    );
  }

  double cameraX(double viewWidth) {
    final lookAhead = player.facing * min(120, (player.vx.abs() * 0.16));
    return clamp(
      player.x - viewWidth * 0.45 + lookAhead,
      0,
      max(0, level.length - viewWidth),
    );
  }

  Snapshot snapshot() {
    Foe? boss;
    for (final foe in enemies) {
      if (foe.boss && foe.alive) {
        boss = foe;
        break;
      }
    }
    // The boss health bar stays hidden until the player has come close.
    if (boss != null && !bossRevealed) boss = null;
    var solved = 0;
    for (final p in level.puzzles) {
      if (p.solved) solved += 1;
    }
    return Snapshot(
      tails: player.tails,
      spirit: player.spirit,
      spiritActive: player.spiritTime,
      ofudaReady: 1 - player.ofudaCooldown / 3,
      progress: clamp(player.x / level.length, 0, 1),
      puzzlesSolved: solved,
      score: score,
      combo: combo,
      time: elapsed,
      bossName: boss?.stat.name.toUpperCase(),
      bossHp: boss == null ? 0 : boss.hp / boss.maxHp,
    );
  }

  void setPaused(bool value) => paused = value;
}

class _Rect {
  final double x, y, w, h;
  _Rect(this.x, this.y, this.w, this.h);
}
