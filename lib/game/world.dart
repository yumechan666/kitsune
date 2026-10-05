import 'dart:math';
import 'dart:ui';

import 'package:kitsune/game/input.dart';
import 'package:kitsune/game/levels.dart';
import 'package:kitsune/game/renderer.dart';

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
  int tails = 3;
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
  int maxTails = 3;
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
  Shot(this.x, this.y, this.vx, this.damage, this.charged, this.ttl, this.delay, this.pierce, this.tail);
}

class EnemyShot {
  double x, y, vx, vy, ttl;
  bool homing;
  String type;
  EnemyShot(this.x, this.y, this.vx, this.vy, this.ttl, this.homing, this.type);
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
  Effect(this.anim, this.x, this.y, this.ttl, this.duration, this.scale, this.facing);
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
bool overlaps(rx, ry, rw, rh, ox, oy, ow, oh) =>
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
  final List<Ofuda> ofudas = [];
  final List<Effect> effects = [];
  Clone? clone;

  double shake = 0;
  double flash = 0;
  double comboTimer = 0;
  int combo = 0;
  double elapsed = 0;
  double score = 0;
  int checkpointIndex = 0;
  double checkpointX = 120;
  double completeTimer = 0;
  bool paused = false;

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
      enemies.add(Foe(
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
      ));
    }
    checkpointX = level.checkpoint;
    for (int i = 0; i < level.pickups.length; i += 1) {
      level.pickups[i].phase = i * 1.7;
    }
  }

  void emit(String type, Map<String, dynamic> data) => onEvent(type, data);

  void addEffect(String anim, double x, double y, double duration, double scale, [int facing = 1]) {
    effects.add(Effect(anim, x, y, duration, duration, scale, facing.toDouble()));
  }

  void spawnShot(bool charged) {
    final direction = player.facing;
    final damage = charged ? 4.0 : 1.0;
    final speed = charged ? 720.0 : 610.0;
    shots.add(Shot(player.x + direction * 34, player.y - 42, direction * speed, damage, charged, 1.7, 0.0, charged ? 5 : 1, false));
    for (int i = 1; i < player.tails; i += 1) {
      shots.add(Shot(
        player.x - direction * (5 + i * 2),
        player.y - 28 - (i % 3) * 10,
        direction * (speed * 0.92),
        charged ? 0.55 : 0.28,
        false,
        1.7,
        i * 0.045,
        1,
        true,
      ));
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
    addEffect("claw_arc", player.x + player.facing * 58, player.y - 35, 0.34, 0.26, player.facing);
    for (final foe in enemies) {
      if (!foe.alive) continue;
      final ahead = (foe.x - player.x) * player.facing;
      if (ahead > -20 && ahead < 135 && (foe.y - player.y).abs() < 105) damageEnemy(foe, 6);
    }
    emit("sound", {"name": "charge"});
    shake = max(shake, 5);
  }

  int feralCombo = 0;

  void plantOfuda() {
    if (player.ofudaCooldown > 0 || player.spiritTime > 0) return;
    ofudas.add(Ofuda(player.x + player.facing * 24, player.y - 45, player.facing * 230, -190, false, 7));
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
    addEffect("dash_trail", player.x, player.y - 15, 0.34, 0.28, -player.facing);
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
    if (player.invulnerable > 0 || player.dashTime > 0 || player.action == "defeat") return;
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
    emit("sound", {"name": "damage"});
    emit("haptic", {"strength": "medium"});
    if (player.tails <= 0) Future.delayed(const Duration(milliseconds: 720), () => respawn());
  }

  void respawn() {
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
  }

  void damageEnemy(Foe foe, double amount) {
    if (!foe.alive) return;
    foe.hp -= amount;
    foe.state = "hit";
    foe.stateTime = 0.2;
    addEffect("hit_sparks", foe.x, foe.y - foe.stat.h * 0.55, 0.25, foe.boss ? 0.23 : 0.14);
    emit("sound", {"name": "hit"});
    if (foe.hp > 0) return;
    foe.alive = false;
    foe.deathTime = 0;
    score += ENEMY_STATS[foe.type]!.score + combo * 25;
    combo += 1;
    comboTimer = 3;
    player.spirit = clamp(player.spirit + (foe.boss ? 55 : 18), 0, 100);
    addEffect("robot_explosion", foe.x, foe.y - foe.stat.h / 2, foe.boss ? 0.75 : 0.48, foe.boss ? 0.38 : 0.22);
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
      if (!overlaps(rect.x, rect.y, rect.w, rect.h, platform.x, platform.y, platform.w, platform.h)) continue;
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
      if (!overlaps(rect.x, rect.y, rect.w, rect.h, platform.x, platform.y, platform.w, platform.h)) continue;
      if (player.vy >= 0 && oldY <= platform.y + 8) {
        player.y = platform.y;
        player.vy = 0;
        player.grounded = true;
      } else if (player.vy < 0 && oldY - player.h >= platform.y + platform.h - 8) {
        player.y = platform.y + platform.h + player.h;
        player.vy = 0;
      }
      rect = _playerRect();
    }
  }

  _Rect _playerRect() => _Rect(player.x - player.w / 2, player.y - player.h, player.w, player.h);
  _Rect _enemyRect(Foe foe) => _Rect(foe.x - foe.stat.w / 2, foe.y - foe.stat.h, foe.stat.w, foe.stat.h);

  void solvePuzzle(Puzzle puzzle) {
    if (puzzle.solved) return;
    puzzle.solved = true;
    score += 900 + level.id * 80;
    player.spirit = min(100, player.spirit + 22);
    addEffect("transform_burst", puzzle.x, 360, 0.55, 0.24);
    shake = max(shake, 7);
    emit("sound", {"name": "pickup", "amount": 1.4});
    emit("toast", {"text": "District seal ${puzzle.id + 1} released"});
  }

  void spawnEnemyAttack(Foe foe) {
    final stats = foe.stat;
    final targetX = clone != null && clone!.ttl > 0 ? clone!.x : player.x;
    final targetY = clone != null && clone!.ttl > 0 ? clone!.y - 35 : player.y - 38;
    final dx = targetX - foe.x;
    final dy = targetY - (foe.y - foe.stat.h * 0.55);
    final speed = stats.projectileSpeed;
    if (stats.melee) {
      if (dx.abs() < 115) damagePlayer(foe.x);
      shake = max(shake, 5);
      return;
    }
    final count = (stats.shotCount) + (foe.boss && foe.hp < foe.maxHp * 0.45 ? 2 : 0);
    for (int i = 0; i < count; i += 1) {
      final spread = (i - (count - 1) / 2) * 0.16;
      final angle = atan2(dy, dx) + spread;
      enemyShots.add(EnemyShot(
        foe.x,
        foe.y - foe.stat.h * 0.55,
        cos(angle) * speed,
        sin(angle) * speed,
        4,
        stats.homing,
        stats.homing ? "homing_missile" : foe.miniBoss ? "lantern_bomb" : "kasa_bolt",
      ));
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
      if (foe.stateTime <= 0) {
        foe.state = "attack";
        foe.stateTime = foe.boss ? 0.72 : 0.45;
        spawnEnemyAttack(foe);
      }
      return;
    }
    if (foe.state == "attack" || foe.state == "hit") {
      if (foe.stateTime <= 0) foe.state = "idle";
      return;
    }

    final dx = player.x - foe.x;
    if (foe.cooldown <= 0 && dx.abs() < (foe.boss ? 720 : 560)) {
      foe.state = "telegraph";
      foe.stateTime = stats.telegraphTime ?? (foe.boss ? 0.55 : 0.32);
      foe.cooldown = ((stats.attackDelay) + Random().nextDouble() * 0.55) / config.enemyAggression;
      return;
    }

    if (!stats.flying && !(stats.melee) && dx.abs() > (foe.boss ? 210 : 150)) {
      foe.x += dx.sign * (stats.speed) * dt;
      foe.x = clamp(foe.x, foe.startX - (foe.boss ? 280 : 90), foe.startX + (foe.boss ? 150 : 90));
      foe.state = "move";
    } else {
      foe.state = "idle";
    }

    final pr = _playerRect();
    final er = _enemyRect(foe);
    if (overlaps(pr.x, pr.y, pr.w, pr.h, er.x, er.y, er.w, er.h)) damagePlayer(foe.x);
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
        if (puzzle.solved || !["shoot", "charge"].contains(puzzle.action)) continue;
        final tx = puzzle.x - 28;
        final ty = 300;
        final tw = 56;
        final th = 86;
        if (overlaps(bx, by, bw, bh, tx, ty, tw, th) && (puzzle.action != "charge" || shot.charged)) {
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
    for (final p in enemyShots) {
      if (p.homing) {
        final tx = clone != null && clone!.ttl > 0 ? clone!.x : player.x;
        final ty = clone != null && clone!.ttl > 0 ? clone!.y - 35 : player.y - 38;
        final angle = atan2(ty - p.y, tx - p.x);
        p.vx += cos(angle) * 110 * dt;
        p.vy += sin(angle) * 110 * dt;
        final s = sqrt(p.vx * p.vx + p.vy * p.vy);
        if (s > 330) {
          p.vx *= 330 / s;
          p.vy *= 330 / s;
        }
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.ttl -= dt;
      if (clone != null && clone!.ttl > 0 && distanceSq(p.x, p.y, clone!.x, clone!.y - 35) < 32 * 32) {
        p.ttl = 0;
        addEffect("hit_sparks", clone!.x, clone!.y - 35, 0.28, 0.14);
      } else if (overlaps(p.x - 9, p.y - 9, 18, 18, _playerRect().x, _playerRect().y, _playerRect().w, _playerRect().h)) {
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
      final target = enemies.firstWhere(
        (foe) => foe.alive && distanceSq(mine.x, mine.y, foe.x, foe.y) < 95 * 95,
        orElse: () => Foe(type: "", x: 0, y: 0, cooldown: 0, startX: 0, hp: 0, maxHp: 0, boss: false, miniBoss: false, stat: ENEMY_STATS.values.first),
      );
      final hasTarget = target.type.isNotEmpty && target.alive;
      if (hasTarget || mine.ttl <= 0) {
        mine.ttl = -1;
        addEffect("ofuda_explosion", mine.x, mine.y, 0.5, 0.25);
        for (final foe in enemies) {
          if (foe.alive && distanceSq(mine.x, mine.y, foe.x, foe.y) < 125 * 125) damageEnemy(foe, 5);
        }
        for (final puzzle in level.puzzles) {
          if (!puzzle.solved && puzzle.action == "ofuda" && (mine.x - puzzle.x).abs() < 135) solvePuzzle(puzzle);
        }
        shake = max(shake, 7);
        emit("sound", {"name": "ofuda"});
      }
    }
    shots.removeWhere((s) => s.ttl <= 0);
    enemyShots.removeWhere((s) => s.ttl <= 0);
    ofudas.removeWhere((s) => s.ttl < 0);
  }

  void updatePickups() {
    final rect = _playerRect();
    for (final item in level.pickups) {
      if (!item.alive) continue;
      if (!overlaps(rect.x, rect.y, rect.w, rect.h, item.x - 22, item.y - 22, 44, 44)) continue;
      item.alive = false;
      if (item.type == "tail") {
        player.tails = min(9, player.tails + 1);
        player.maxTails = max(player.maxTails, player.tails);
        player.action = "tail_gain";
        player.actionTime = 0.48;
        addEffect("tail_pickup_fx", player.x, player.y - 40, 0.55, 0.27);
        emit("toast", {"text": "Tail ${player.tails}/9"});
        emit("sound", {"name": "pickup", "amount": 1.25});
      } else {
        player.spirit = min(100, player.spirit + 28);
        addEffect("spirit_shard_fx", item.x, item.y, 0.42, 0.2);
        emit("sound", {"name": "pickup", "amount": 1});
      }
      score += item.type == "tail" ? 500 : 180;
    }
  }

  void update(double dt, InputState input) {
    if (paused) return;
    elapsed += dt;
    shake = max(0, shake - dt * 22);
    flash = max(0, flash - dt * 1.8);
    comboTimer -= dt;
    if (comboTimer <= 0) combo = 0;
    if (clone != null) {
      clone!.ttl -= dt;
      if (clone!.ttl <= 0) clone = null;
    }
    for (final effect in effects) effect.ttl -= dt;
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

    if (input.consume("spirit")) activateSpirit();
    if (input.consume("dash")) doDash();
    if (input.consume("ofuda")) plantOfuda();
    if (input.consume("fire")) {
      if (player.spiritTime > 0) {
        feralStrike();
      } else {
        player.charging = true;
        player.chargeTime = 0;
      }
    }
    if (player.charging && input.held["fire"]!) player.chargeTime = min(1.4, player.chargeTime + dt);
    if (player.charging && input.consumeRelease("fire")) {
      if (player.fireCooldown <= 0) spawnShot(player.chargeTime >= 0.62);
      player.charging = false;
      player.chargeTime = 0;
    }

    if (input.consume("jump")) {
      if (player.grounded || player.coyote > 0) {
        player.vy = player.spiritTime > 0 ? -610 : -535;
        player.grounded = false;
        player.coyote = 0;
        emit("sound", {"name": "jump"});
      } else if (player.wallSide != 0) {
        player.vx = -player.wallSide * 360;
        player.vy = -510;
        player.facing = -player.wallSide;
        player.action = "wall_jump";
        player.actionTime = 0.28;
        emit("sound", {"name": "jump"});
      }
    }

    final move = (input.held["right"]! ? 1 : 0) - (input.held["left"]! ? 1 : 0);
    if (move != 0) player.facing = move;
    if (player.dashTime > 0) {
      player.dashTime -= dt;
      player.vx = player.facing * (player.spiritTime > 0 ? 920 : 760);
    } else {
      final speed = config.playerSpeed * (player.spiritTime > 0 ? 1.42 : 1);
      final acceleration = player.grounded ? 1800 : 1150;
      player.vx += clamp(move * speed - player.vx, -acceleration * dt, acceleration * dt);
      if (move == 0 && player.grounded) player.vx *= pow(0.0008, dt);
      var gravity = 1420;
      if (input.held["jump"]! && player.vy > 0 && player.spiritTime <= 0) gravity = 330;
      player.vy += gravity * dt;
      if (input.held["jump"]! && player.vy > 0) player.vy = min(player.vy, 150);
      if (level.wind != 0 && !player.grounded) player.vx += level.wind * dt;
    }
    player.coyote = player.grounded ? 0.11 : max(0, player.coyote - dt);
    final wasGrounded = player.grounded;
    resolvePlayerCollisions(dt);
    if (!wasGrounded && player.grounded && player.actionTime <= 0) {
      player.action = player.spiritTime > 0 ? "landing_smash" : "land";
      player.actionTime = 0.28;
    }
    if (player.wallSide != 0 && !player.grounded && player.vy > 0 &&
        ((player.wallSide == 1 && input.held["right"]!) || (player.wallSide == -1 && input.held["left"]!))) {
      player.vy = min(player.vy, 95);
    }
    player.x = clamp(player.x, 20, level.length - 20);
    if (player.y > 610) {
      damagePlayer(player.x + 1);
      if (player.tails > 0) {
        player.x = checkpointX;
        player.y = 410;
        player.vx = 0;
        player.vy = 0;
      }
    }

    for (final hazard in level.hazards) {
      if (overlaps(_playerRect().x, _playerRect().y, _playerRect().w, _playerRect().h, hazard.x, hazard.y, hazard.w, hazard.h) &&
          player.spiritTime <= 0) {
        damagePlayer(hazard.x + hazard.w / 2);
      }
    }
    final nextCheckpoint = checkpointIndex + 1 < level.checkpoints.length ? level.checkpoints[checkpointIndex + 1] : null;
    if (nextCheckpoint != null && player.x >= nextCheckpoint) {
      checkpointIndex += 1;
      checkpointX = nextCheckpoint;
      player.tails = max(3, player.tails);
      emit("toast", {"text": "Checkpoint purified"});
      emit("sound", {"name": "pickup", "amount": 1.35});
    }

    for (final puzzle in level.puzzles) {
      if (puzzle.solved) continue;
      final near = (player.x - puzzle.x).abs() < 145;
      if (!puzzle.hinted && (player.x - puzzle.x).abs() < 360) {
        puzzle.hinted = true;
        emit("toast", {"text": puzzle.hint});
      }
      if (!near) continue;
      if (puzzle.action == "dash" && player.dashTime > 0) solvePuzzle(puzzle);
      else if (puzzle.action == "spirit" && player.spiritTime > 0) solvePuzzle(puzzle);
      else if (puzzle.action == "glide" && !player.grounded && input.held["jump"]! && player.vy > 0) solvePuzzle(puzzle);
      else if (puzzle.action == "clone" && clone != null && clone!.ttl > 0 && (clone!.x - puzzle.x).abs() < 170) solvePuzzle(puzzle);
    }

    for (final foe in enemies) updateEnemy(foe, dt);
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
    if (!player.grounded && player.wallSide != 0 && player.vy > 0) return "wall_slide";
    if (!player.grounded && input != null && input.held["jump"]! && player.vy > 0) return "tail_glide";
    if (!player.grounded) return player.vy < 0 ? "jump_up" : "fall";
    return player.vx.abs() > 35 ? "run" : "idle";
  }

  String enemyAnimation(Foe foe) {
    final stats = foe.stat;
    if (!foe.alive) return stats.defeat;
    if (foe.state == "hit") return stats.hit;
    if (foe.state == "attack") return stats.attack;
    if (foe.state == "telegraph") return stats.telegraphTime != null ? stats.attack : stats.attack;
    if (foe.state == "move") return stats.move;
    return stats.idle;
  }

  void render(Renderer renderer, double time, InputState input) {
    renderer.begin(level, cameraX(renderer.viewWidth), time, shake * config.effectsIntensity, flash * config.effectsIntensity);
    for (final platform in level.platforms) renderer.drawPlatform(level.tiles, platform);
    for (final hazard in level.hazards) {
      final count = (hazard.w / 42).ceil();
      for (int i = 0; i < count; i += 1) {
        renderer.drawStatic("roof_spike", hazard.x + i * 42, hazard.y - 20, 46, 44);
      }
    }
    final cpList = level.checkpoints;
    for (int i = 0; i < cpList.length; i += 1) {
      renderer.drawStatic("checkpoint_lantern", cpList[i] - 30, 388, 60, 78, i <= checkpointIndex ? 1 : 0.62);
    }

    for (final puzzle in level.puzzles) {
      final prefix = "s${level.id}_";
      renderer.drawStatic("${prefix}rune", puzzle.x - 48, 416, 96, 48, puzzle.solved ? 0.5 : 1);
      renderer.drawStatic("${prefix}target", puzzle.x - 34, 300, 68, 82, puzzle.solved ? 0.38 : 1);
      renderer.drawStatic("${prefix}beacon", puzzle.x + 92, 332, 64, 134, puzzle.solved ? 0.45 : 1);
      if (!puzzle.solved) {
        renderer.drawStatic("${prefix}gate", puzzle.x + 132, 170, 84, 296, 0.9);
      } else {
        renderer.drawStatic("${prefix}reward", puzzle.x + 145, 330, 52, 60, 0.65);
      }
    }

    for (final item in level.pickups) {
      if (!item.alive) continue;
      final bob = sin(time * 3 + item.phase) * 6;
      renderer.drawStatic(item.type == "tail" ? "tail_pickup" : "spirit_shard", item.x - 24, item.y - 24 + bob, 48, 48);
    }
    for (final mine in ofudas) renderer.drawStatic("ofuda_mine", mine.x - 16, mine.y - 30, 32, 34);
    if (clone != null) renderer.drawAnchored("shadow_clone", clone!.x, clone!.y, 0.19, clone!.facing, time, 10, 1, clamp(clone!.ttl / 1.2, 0.15, 0.7), 40, 56, const Color(0xFF9A6CFF));

    for (final foe in enemies) {
      if (!foe.alive && foe.deathTime > 0.62) continue;
      final stats = foe.stat;
      final anim = enemyAnimation(foe);
      final scale = stats.spriteH / 360;
      final progress = !foe.alive ? clamp(foe.deathTime / 0.58, 0, 0.999) : 0.0;
      renderer.drawAnchored(anim, foe.x, foe.y, scale, foe.facing, time + foe.startX * 0.002, foe.boss ? 8 : 10, 1, foe.alive ? null : progress,
          stats.w, stats.spriteH, foe.boss ? const Color(0xFFFF4FD8) : const Color(0xFFE85A5A));
      if (foe.boss && foe.alive) {
        final c = renderer.canvas;
        if (c != null) {
          c.drawRect(Rect.fromLTWH(foe.x - 82, foe.y - foe.stat.h - 24, 164, 9), Paint()..color = const Color(0xD2050819));
          c.drawRect(
            Rect.fromLTWH(foe.x - 79, foe.y - foe.stat.h - 21, 158 * (foe.hp / foe.maxHp), 3),
            Paint()..color = level.id >= 8 ? const Color(0xFFFF4FD8) : const Color(0xFF49E8FF),
          );
        }
      }
    }

    for (final shot in shots) {
      if (shot.delay > 0) continue;
      renderer.drawAnchored(
        shot.charged ? "charged_shot" : shot.tail ? "tail_volley" : "kitsunebi",
        shot.x,
        shot.y,
        shot.charged ? 0.18 : shot.tail ? 0.075 : 0.09,
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
    for (final p in enemyShots) renderer.drawStatic(p.type, p.x - 14, p.y - 14, 28, 28);
    for (final effect in effects) {
      renderer.drawAnchored(effect.anim, effect.x, effect.y, effect.scale, effect.facing.toInt(), time, 12, clamp(effect.ttl / 0.12, 0, 1), 1 - effect.ttl / effect.duration, 24, 24, const Color(0xFFFFAA33));
    }

    final playerAnim = currentPlayerAnimation(input);
    final playerScale = player.spiritTime > 0 && !playerAnim.contains("transform") ? 0.26 : 0.215;
    final progress = player.actionTime > 0 &&
            [
              "spawn", "land", "tail_gain", "damage", "defeat", "checkpoint_revive",
              "spirit_transform", "spirit_return", "shoot", "charged_release", "ofuda_throw",
              "claw_combo", "wall_jump"
            ].contains(playerAnim)
        ? clamp(1 - player.actionTime / (playerAnim == "defeat" ? 0.78 : playerAnim.contains("spirit") ? 0.7 : 0.48), 0, 0.999)
        : 0.0;
    final blink = player.invulnerable > 0 && (player.invulnerable * 15).floor() % 2 == 0 ? 0.38 : 1.0;
    renderer.drawAnchored(playerAnim, player.x, player.y, playerScale, player.facing, time, 11, blink, progress, player.w, player.h, const Color(0xFFFF7AC0));
  }

  double cameraX(double viewWidth) {
    final lookAhead = player.facing * min(120, (player.vx.abs() * 0.16));
    return clamp(player.x - viewWidth * 0.45 + lookAhead, 0, max(0, level.length - viewWidth));
  }

  Snapshot snapshot() {
    final boss = enemies.firstWhere((foe) => foe.boss && foe.alive, orElse: () => Foe(type: "", x: 0, y: 0, cooldown: 0, startX: 0, hp: 0, maxHp: 1, boss: false, miniBoss: false, stat: ENEMY_STATS.values.first));
    return Snapshot(
      tails: player.tails,
      spirit: player.spirit,
      spiritActive: player.spiritTime,
      ofudaReady: 1 - player.ofudaCooldown / 3,
      progress: clamp(player.x / level.length, 0, 1),
      puzzlesSolved: level.puzzles.where((p) => p.solved).length,
      score: score,
      combo: combo,
      time: elapsed,
      bossName: boss.boss ? boss.stat.name.toUpperCase() : null,
      bossHp: boss.boss ? boss.hp / boss.maxHp : 0,
    );
  }

  void setPaused(bool value) => paused = value;
}

class _Rect {
  final double x, y, w, h;
  _Rect(this.x, this.y, this.w, this.h);
}
