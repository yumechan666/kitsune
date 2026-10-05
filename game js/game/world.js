import { ENEMY_STATS } from "./level.js";

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const overlaps = (a, b) => a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
const distanceSq = (a, b) => (a.x - b.x) ** 2 + (a.y - b.y) ** 2;

function playerRect(player) {
  return { x: player.x - player.w / 2, y: player.y - player.h, w: player.w, h: player.h };
}

function enemyRect(enemy) {
  return { x: enemy.x - enemy.w / 2, y: enemy.y - enemy.h, w: enemy.w, h: enemy.h };
}

export function createWorld({ level, mode, config, onEvent }) {
  const player = {
    x: 120, y: 466, w: 34, h: 70, vx: 0, vy: 0, facing: 1,
    grounded: true, coyote: 0.1, wallSide: 0, tails: 3, spirit: 0,
    spiritTime: 0, invulnerable: 0, dashTime: 0, dashCooldown: 0,
    fireCooldown: 0, chargeTime: 0, charging: false, ofudaCooldown: 0,
    action: "spawn", actionTime: 0.55, hitCount: 0, maxTails: 3,
  };
  const enemies = level.enemies.map((source, index) => {
    const stats = ENEMY_STATS[source.type];
    return {
      ...source, id: `${source.type}-${index}`, startX: source.x, w: stats.w, h: stats.h,
      hp: source.hp || stats.hp, maxHp: source.hp || stats.hp, state: "idle", stateTime: 0,
      cooldown: 0.7 + (index % 3) * 0.45, alive: true, deathTime: 0, facing: -1, phase: 0,
    };
  });
  const pickups = level.pickups.map((value, index) => ({ ...value, id: index, alive: true, phase: index * 1.7 }));
  const shots = [];
  const enemyShots = [];
  const ofudas = [];
  const effects = [];
  const puzzles = (level.puzzles || []).map((value) => ({ ...value, solved: false, hinted: false }));
  let clone = null;
  let checkpointX = 120;
  let checkpointIndex = -1;
  let score = 0;
  let elapsed = 0;
  let completeTimer = -1;
  let shake = 0;
  let flash = 0;
  let combo = 0;
  let comboTimer = 0;
  let paused = false;
  let feralCombo = 0;

  function emit(type, data = {}) {
    onEvent({ type, ...data });
  }

  function addEffect(anim, x, y, duration = 0.4, scale = 0.18, facing = 1) {
    effects.push({ anim, x, y, duration, ttl: duration, scale, facing });
  }

  function spawnShot(charged) {
    const direction = player.facing;
    const damage = charged ? 4 : 1;
    const speed = charged ? 720 : 610;
    shots.push({ x: player.x + direction * 34, y: player.y - 42, vx: direction * speed, damage, charged, ttl: 1.7, delay: 0, pierce: charged ? 5 : 1 });
    for (let i = 1; i < player.tails; i += 1) {
      shots.push({
        x: player.x - direction * (5 + i * 2), y: player.y - 28 - (i % 3) * 10,
        vx: direction * (speed * 0.92), damage: charged ? 0.55 : 0.28, charged: false,
        tail: true, ttl: 1.7, delay: i * 0.045, pierce: 1,
      });
    }
    player.action = charged ? "charged_release" : "shoot";
    player.actionTime = charged ? 0.34 : 0.2;
    player.fireCooldown = charged ? 0.35 : 0.16;
    emit("sound", { name: charged ? "charge" : "shot" });
    if (charged) { shake = Math.max(shake, 6); flash = 0.12; }
  }

  function feralStrike() {
    if (player.fireCooldown > 0) return;
    const attacks = player.grounded ? ["claw_combo", "pounce", "rising_slash"] : ["claw_combo", "landing_smash"];
    player.action = attacks[feralCombo % attacks.length];
    feralCombo += 1;
    player.actionTime = 0.38;
    player.fireCooldown = 0.42;
    addEffect("claw_arc", player.x + player.facing * 58, player.y - 35, 0.34, 0.26, player.facing);
    for (const foe of enemies) {
      if (!foe.alive) continue;
      const ahead = (foe.x - player.x) * player.facing;
      if (ahead > -20 && ahead < 135 && Math.abs(foe.y - player.y) < 105) damageEnemy(foe, 6);
    }
    emit("sound", { name: "charge" });
    shake = Math.max(shake, 5);
  }

  function plantOfuda() {
    if (player.ofudaCooldown > 0 || player.spiritTime > 0) return;
    ofudas.push({ x: player.x + player.facing * 24, y: player.y - 45, vx: player.facing * 230, vy: -190, stuck: false, ttl: 7 });
    player.ofudaCooldown = 3;
    player.action = "ofuda_throw";
    player.actionTime = 0.32;
    emit("sound", { name: "ofuda" });
  }

  function doDash() {
    if (player.dashCooldown > 0) return;
    player.dashTime = 0.22;
    player.dashCooldown = 0.72;
    player.invulnerable = Math.max(player.invulnerable, 0.28);
    player.vx = player.facing * (player.spiritTime > 0 ? 920 : 760);
    player.vy = 0;
    clone = { x: player.x, y: player.y, ttl: 1.65, facing: player.facing };
    addEffect("dash_trail", player.x, player.y - 15, 0.34, 0.28, -player.facing);
    emit("sound", { name: "dash" });
  }

  function activateSpirit() {
    if (player.spirit < 100 || player.spiritTime > 0) return;
    player.spirit = 0;
    player.spiritTime = 8;
    player.invulnerable = Math.max(player.invulnerable, 0.65);
    player.action = "spirit_transform";
    player.actionTime = 0.7;
    addEffect("transform_burst", player.x, player.y - 25, 0.72, 0.42);
    shake = 10;
    flash = 0.35;
    emit("sound", { name: "transform" });
    emit("haptic", { strength: "heavy" });
  }

  function damagePlayer(sourceX) {
    if (player.invulnerable > 0 || player.dashTime > 0 || player.action === "defeat") return;
    if (player.spiritTime > 0) {
      player.invulnerable = 0.45;
      player.action = "feral_hit";
      player.actionTime = 0.3;
      shake = Math.max(shake, 4);
      emit("sound", { name: "hit" });
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
    emit("sound", { name: "damage" });
    emit("haptic", { strength: "medium" });
    if (player.tails <= 0) window.setTimeout(respawn, 720);
  }

  function respawn() {
    player.x = checkpointX;
    player.y = 466;
    player.vx = 0;
    player.vy = 0;
    player.tails = 3;
    player.invulnerable = 1.2;
    player.action = "checkpoint_revive";
    player.actionTime = 0.65;
    score = Math.max(0, score - 350);
    emit("toast", { text: "Spirit tails restored" });
  }

  function damageEnemy(foe, amount) {
    if (!foe.alive) return;
    foe.hp = Math.max(0, foe.hp - amount);
    foe.state = "hit";
    foe.stateTime = 0.2;
    addEffect("hit_sparks", foe.x, foe.y - foe.h * 0.55, 0.25, foe.boss ? 0.23 : 0.14);
    emit("sound", { name: "hit" });
    if (foe.hp > 0) return;
    foe.alive = false;
    foe.deathTime = 0;
    score += ENEMY_STATS[foe.type].score + combo * 25;
    combo += 1;
    comboTimer = 3;
    player.spirit = clamp(player.spirit + (foe.boss ? 55 : 18), 0, 100);
    addEffect("robot_explosion", foe.x, foe.y - foe.h / 2, foe.boss ? 0.75 : 0.48, foe.boss ? 0.38 : 0.22);
    if (foe.boss) {
      completeTimer = 1.8;
      player.spirit = 100;
      shake = 14;
      flash = 0.4;
      emit("sound", { name: "boss" });
    }
  }

  function resolvePlayerCollisions(dt) {
    player.wallSide = 0;
    player.x += player.vx * dt;
    let rect = playerRect(player);
    for (const platform of level.platforms) {
      if (!overlaps(rect, platform)) continue;
      if (player.vx > 0) { player.x = platform.x - player.w / 2; player.wallSide = 1; }
      else if (player.vx < 0) { player.x = platform.x + platform.w + player.w / 2; player.wallSide = -1; }
      player.vx = 0;
      rect = playerRect(player);
    }
    for (const puzzle of puzzles) {
      if (puzzle.solved) continue;
      const gate = { x: puzzle.x + 150, y: 185, w: 46, h: 281 };
      if (!overlaps(rect, gate)) continue;
      if (player.vx > 0) { player.x = gate.x - player.w / 2; player.wallSide = 1; }
      else if (player.vx < 0) { player.x = gate.x + gate.w + player.w / 2; player.wallSide = -1; }
      player.vx = 0;
      rect = playerRect(player);
    }

    const oldY = player.y;
    player.y += player.vy * dt;
    player.grounded = false;
    rect = playerRect(player);
    for (const platform of level.platforms) {
      if (!overlaps(rect, platform)) continue;
      if (player.vy >= 0 && oldY <= platform.y + 8) {
        player.y = platform.y;
        player.vy = 0;
        player.grounded = true;
      } else if (player.vy < 0 && oldY - player.h >= platform.y + platform.h - 8) {
        player.y = platform.y + platform.h + player.h;
        player.vy = 0;
      }
      rect = playerRect(player);
    }
  }

  function solvePuzzle(puzzle) {
    if (!puzzle || puzzle.solved) return;
    puzzle.solved = true;
    score += 900 + level.id * 80;
    player.spirit = Math.min(100, player.spirit + 22);
    addEffect("transform_burst", puzzle.x, 360, 0.55, 0.24);
    shake = Math.max(shake, 7);
    emit("sound", { name: "pickup", amount: 1.4 });
    emit("toast", { text: `District seal ${puzzle.id + 1} released` });
  }

  function spawnEnemyAttack(foe) {
    const stats = ENEMY_STATS[foe.type];
    const targetX = clone?.ttl > 0 ? clone.x : player.x;
    const targetY = clone?.ttl > 0 ? clone.y - 35 : player.y - 38;
    const dx = targetX - foe.x;
    const dy = targetY - (foe.y - foe.h * 0.55);
    const speed = stats.projectileSpeed || 290;
    if (stats.melee) {
      if (Math.abs(dx) < 115) damagePlayer(foe.x);
      shake = Math.max(shake, 5);
      return;
    }
    const count = (stats.shotCount || 1) + (foe.boss && foe.hp < foe.maxHp * 0.45 ? 2 : 0);
    for (let i = 0; i < count; i += 1) {
      const spread = (i - (count - 1) / 2) * 0.16;
      const angle = Math.atan2(dy, dx) + spread;
      enemyShots.push({
        x: foe.x, y: foe.y - foe.h * 0.55, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
        ttl: 4, homing: Boolean(stats.homing), type: stats.homing ? "homing_missile" : foe.miniBoss ? "lantern_bomb" : "kasa_bolt",
      });
    }
  }

  function updateEnemy(foe, dt) {
    if (!foe.alive) { foe.deathTime += dt; return; }
    if (Math.abs(foe.x - player.x) > 1050 && !foe.boss) return;
    const stats = ENEMY_STATS[foe.type];
    foe.cooldown -= dt * config.enemyAggression;
    foe.stateTime -= dt;
    foe.facing = player.x < foe.x ? -1 : 1;
    if (stats.flying) foe.y += Math.sin(elapsed * 2.4 + foe.startX) * 12 * dt;

    if (foe.state === "telegraph") {
      if (foe.stateTime <= 0) {
        foe.state = "attack";
        foe.stateTime = foe.boss ? 0.72 : 0.45;
        spawnEnemyAttack(foe);
      }
      return;
    }
    if (foe.state === "attack" || foe.state === "hit") {
      if (foe.stateTime <= 0) foe.state = "idle";
      return;
    }

    const dx = player.x - foe.x;
    if (foe.cooldown <= 0 && Math.abs(dx) < (foe.boss ? 720 : 560)) {
      foe.state = "telegraph";
      foe.stateTime = stats.telegraphTime || (foe.boss ? 0.55 : 0.32);
      foe.cooldown = ((stats.attackDelay || 1.8) + Math.random() * 0.55) / config.enemyAggression;
      return;
    }

    if (!stats.flying && !stats.stationary && Math.abs(dx) > (foe.boss ? 210 : 150)) {
      foe.x += Math.sign(dx) * (stats.speed || 58) * dt;
      foe.x = clamp(foe.x, foe.startX - (foe.boss ? 280 : 90), foe.startX + (foe.boss ? 150 : 90));
      foe.state = "move";
    } else foe.state = "idle";

    if (overlaps(playerRect(player), enemyRect(foe))) damagePlayer(foe.x);
  }

  function updateProjectiles(dt) {
    for (const shot of shots) {
      if (shot.delay > 0) { shot.delay -= dt; continue; }
      shot.x += shot.vx * dt;
      shot.ttl -= dt;
      const box = { x: shot.x - (shot.charged ? 28 : 11), y: shot.y - 10, w: shot.charged ? 56 : 22, h: 20 };
      for (const puzzle of puzzles) {
        if (puzzle.solved || !["shoot", "charge"].includes(puzzle.action)) continue;
        const target = { x: puzzle.x - 28, y: 300, w: 56, h: 86 };
        if (overlaps(box, target) && (puzzle.action !== "charge" || shot.charged)) {
          solvePuzzle(puzzle);
          shot.ttl = 0;
        }
      }
      for (const foe of enemies) {
        if (!foe.alive || !overlaps(box, enemyRect(foe))) continue;
        damageEnemy(foe, shot.damage);
        shot.pierce -= 1;
        if (shot.pierce <= 0) { shot.ttl = 0; break; }
      }
    }
    for (const projectile of enemyShots) {
      if (projectile.homing) {
        const target = clone?.ttl > 0 ? clone : player;
        const angle = Math.atan2((target.y - 35) - projectile.y, target.x - projectile.x);
        projectile.vx += Math.cos(angle) * 110 * dt;
        projectile.vy += Math.sin(angle) * 110 * dt;
        const speed = Math.hypot(projectile.vx, projectile.vy);
        if (speed > 330) { projectile.vx *= 330 / speed; projectile.vy *= 330 / speed; }
      }
      projectile.x += projectile.vx * dt;
      projectile.y += projectile.vy * dt;
      projectile.ttl -= dt;
      if (clone?.ttl > 0 && Math.hypot(projectile.x - clone.x, projectile.y - (clone.y - 35)) < 32) {
        projectile.ttl = 0;
        addEffect("hit_sparks", clone.x, clone.y - 35, 0.28, 0.14);
      } else if (overlaps({ x: projectile.x - 9, y: projectile.y - 9, w: 18, h: 18 }, playerRect(player))) {
        projectile.ttl = 0;
        damagePlayer(projectile.x);
      }
    }
    for (const mine of ofudas) {
      mine.ttl -= dt;
      if (!mine.stuck) {
        mine.vy += 760 * dt;
        mine.x += mine.vx * dt;
        mine.y += mine.vy * dt;
        if (mine.y >= 454) { mine.y = 454; mine.vx = 0; mine.vy = 0; mine.stuck = true; }
      }
      const target = enemies.find((foe) => foe.alive && distanceSq(mine, foe) < 95 ** 2);
      if (target || mine.ttl <= 0) {
        mine.ttl = -1;
        addEffect("ofuda_explosion", mine.x, mine.y, 0.5, 0.25);
        for (const foe of enemies) if (foe.alive && distanceSq(mine, foe) < 125 ** 2) damageEnemy(foe, 5);
        for (const puzzle of puzzles) if (!puzzle.solved && puzzle.action === "ofuda" && Math.abs(mine.x - puzzle.x) < 135) solvePuzzle(puzzle);
        shake = Math.max(shake, 7);
        emit("sound", { name: "ofuda" });
      }
    }
    for (let i = shots.length - 1; i >= 0; i -= 1) if (shots[i].ttl <= 0) shots.splice(i, 1);
    for (let i = enemyShots.length - 1; i >= 0; i -= 1) if (enemyShots[i].ttl <= 0) enemyShots.splice(i, 1);
    for (let i = ofudas.length - 1; i >= 0; i -= 1) if (ofudas[i].ttl < 0) ofudas.splice(i, 1);
  }

  function updatePickups() {
    const rect = playerRect(player);
    for (const item of pickups) {
      if (!item.alive) continue;
      const box = { x: item.x - 22, y: item.y - 22, w: 44, h: 44 };
      if (!overlaps(rect, box)) continue;
      item.alive = false;
      if (item.type === "tail") {
        player.tails = Math.min(9, player.tails + 1);
        player.maxTails = Math.max(player.maxTails, player.tails);
        player.action = "tail_gain";
        player.actionTime = 0.48;
        addEffect("tail_pickup_fx", player.x, player.y - 40, 0.55, 0.27);
        emit("toast", { text: `Tail ${player.tails}/9` });
        emit("sound", { name: "pickup", amount: 1.25 });
      } else {
        player.spirit = Math.min(100, player.spirit + 28);
        addEffect("spirit_shard_fx", item.x, item.y, 0.42, 0.2);
        emit("sound", { name: "pickup", amount: 1 });
      }
      score += item.type === "tail" ? 500 : 180;
    }
  }

  function update(dt, input) {
    if (paused) return;
    elapsed += dt;
    shake = Math.max(0, shake - dt * 22);
    flash = Math.max(0, flash - dt * 1.8);
    comboTimer -= dt;
    if (comboTimer <= 0) combo = 0;
    if (clone) { clone.ttl -= dt; if (clone.ttl <= 0) clone = null; }
    for (const effect of effects) effect.ttl -= dt;
    for (let i = effects.length - 1; i >= 0; i -= 1) if (effects[i].ttl <= 0) effects.splice(i, 1);

    player.invulnerable = Math.max(0, player.invulnerable - dt);
    player.dashCooldown = Math.max(0, player.dashCooldown - dt);
    player.fireCooldown = Math.max(0, player.fireCooldown - dt);
    player.ofudaCooldown = Math.max(0, player.ofudaCooldown - dt);
    player.actionTime = Math.max(0, player.actionTime - dt);
    if (player.spiritTime > 0) {
      player.spiritTime = Math.max(0, player.spiritTime - dt);
      if (player.spiritTime === 0) { player.action = "spirit_return"; player.actionTime = 0.55; }
    }

    if (input.consume("spirit")) activateSpirit();
    if (input.consume("dash")) doDash();
    if (input.consume("ofuda")) plantOfuda();
    if (input.consume("fire")) {
      if (player.spiritTime > 0) feralStrike();
      else { player.charging = true; player.chargeTime = 0; }
    }
    if (player.charging && input.held.fire) player.chargeTime = Math.min(1.4, player.chargeTime + dt);
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
        emit("sound", { name: "jump" });
      } else if (player.wallSide) {
        player.vx = -player.wallSide * 360;
        player.vy = -510;
        player.facing = -player.wallSide;
        player.action = "wall_jump";
        player.actionTime = 0.28;
        emit("sound", { name: "jump" });
      }
    }

    const move = (input.held.right ? 1 : 0) - (input.held.left ? 1 : 0);
    if (move) player.facing = move;
    if (player.dashTime > 0) {
      player.dashTime -= dt;
      player.vx = player.facing * (player.spiritTime > 0 ? 920 : 760);
    } else {
      const speed = config.playerSpeed * (player.spiritTime > 0 ? 1.42 : 1);
      const acceleration = player.grounded ? 1800 : 1150;
      player.vx += clamp(move * speed - player.vx, -acceleration * dt, acceleration * dt);
      if (!move && player.grounded) player.vx *= Math.pow(0.0008, dt);
      let gravity = 1420;
      if (input.held.jump && player.vy > 0 && player.spiritTime <= 0) gravity = 330;
      player.vy += gravity * dt;
      if (input.held.jump && player.vy > 0) player.vy = Math.min(player.vy, 150);
      if (level.wind && !player.grounded) player.vx += level.wind * dt;
    }
    player.coyote = player.grounded ? 0.11 : Math.max(0, player.coyote - dt);
    const wasGrounded = player.grounded;
    resolvePlayerCollisions(dt);
    if (!wasGrounded && player.grounded && player.actionTime <= 0) {
      player.action = player.spiritTime > 0 ? "landing_smash" : "land";
      player.actionTime = 0.28;
    }
    if (player.wallSide && !player.grounded && player.vy > 0 && ((player.wallSide === 1 && input.held.right) || (player.wallSide === -1 && input.held.left))) {
      player.vy = Math.min(player.vy, 95);
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

    for (const hazard of level.hazards) {
      if (overlaps(playerRect(player), hazard) && player.spiritTime <= 0) damagePlayer(hazard.x + hazard.w / 2);
    }
    const nextCheckpoint = level.checkpoints?.[checkpointIndex + 1];
    if (nextCheckpoint != null && player.x >= nextCheckpoint) {
      checkpointIndex += 1;
      checkpointX = nextCheckpoint;
      player.tails = Math.max(3, player.tails);
      emit("toast", { text: "Checkpoint purified" });
      emit("sound", { name: "pickup", amount: 1.35 });
    }

    for (const puzzle of puzzles) {
      if (puzzle.solved) continue;
      const near = Math.abs(player.x - puzzle.x) < 145;
      if (!puzzle.hinted && Math.abs(player.x - puzzle.x) < 360) {
        puzzle.hinted = true;
        emit("toast", { text: puzzle.hint });
      }
      if (!near) continue;
      if (puzzle.action === "dash" && player.dashTime > 0) solvePuzzle(puzzle);
      else if (puzzle.action === "spirit" && player.spiritTime > 0) solvePuzzle(puzzle);
      else if (puzzle.action === "glide" && !player.grounded && input.held.jump && player.vy > 0) solvePuzzle(puzzle);
      else if (puzzle.action === "clone" && clone?.ttl > 0 && Math.abs(clone.x - puzzle.x) < 170) solvePuzzle(puzzle);
    }

    for (const foe of enemies) updateEnemy(foe, dt);
    updateProjectiles(dt);
    updatePickups();
    if (completeTimer > 0) {
      completeTimer -= dt;
      if (completeTimer <= 0) {
        completeTimer = -1;
        emit("complete", { score, elapsed, hitCount: player.hitCount, maxTails: player.maxTails, mode });
      }
    }
    input.resetEdges();
  }

  function currentPlayerAnimation(input) {
    if (player.actionTime > 0 && player.action) return player.action;
    if (player.spiritTime > 0) {
      if (!player.grounded) return "feral_leap";
      return Math.abs(player.vx) > 35 ? "feral_run" : "feral_idle";
    }
    if (player.dashTime > 0) return player.grounded ? "dash" : "air_dash";
    if (player.charging) return "charge";
    if (!player.grounded && player.wallSide && player.vy > 0) return "wall_slide";
    if (!player.grounded && input?.held.jump && player.vy > 0) return "tail_glide";
    if (!player.grounded) return player.vy < 0 ? "jump_up" : "fall";
    return Math.abs(player.vx) > 35 ? "run" : "idle";
  }

  function enemyAnimation(foe) {
    const stats = ENEMY_STATS[foe.type];
    if (!foe.alive) return stats.defeat;
    if (foe.state === "hit") return stats.hit || stats.idle;
    if (foe.state === "attack") {
      return stats.attack;
    }
    if (foe.state === "telegraph") return stats.telegraph || stats.attack;
    if (foe.state === "move") return stats.move;
    return stats.idle;
  }

  function render(renderer, time, input) {
    renderer.begin(level, cameraX(renderer.viewWidth), time, shake * config.effectsIntensity, flash * config.effectsIntensity);
    for (const platform of level.platforms) renderer.drawPlatform(level.tiles, platform);
    for (const hazard of level.hazards) {
      const count = Math.ceil(hazard.w / 42);
      for (let i = 0; i < count; i += 1) renderer.drawStatic("roof_spike", hazard.x + i * 42, hazard.y - 20, 46, 44);
    }
    for (let i = 0; i < (level.checkpoints || [level.checkpoint]).length; i += 1) {
      const x = (level.checkpoints || [level.checkpoint])[i];
      renderer.drawStatic("checkpoint_lantern", x - 30, 388, 60, 78, i <= checkpointIndex ? 1 : 0.62);
    }

    for (const puzzle of puzzles) {
      const prefix = `s${level.id}_`;
      renderer.drawStatic(`${prefix}rune`, puzzle.x - 48, 416, 96, 48, puzzle.solved ? 0.5 : 1);
      renderer.drawStatic(`${prefix}target`, puzzle.x - 34, 300, 68, 82, puzzle.solved ? 0.38 : 1);
      renderer.drawStatic(`${prefix}beacon`, puzzle.x + 92, 332, 64, 134, puzzle.solved ? 0.45 : 1);
      if (!puzzle.solved) renderer.drawStatic(`${prefix}gate`, puzzle.x + 132, 170, 84, 296, 0.9);
      else renderer.drawStatic(`${prefix}reward`, puzzle.x + 145, 330, 52, 60, 0.65);
    }

    for (const item of pickups) {
      if (!item.alive) continue;
      const bob = Math.sin(time * 3 + item.phase) * 6;
      renderer.drawStatic(item.type === "tail" ? "tail_pickup" : "spirit_shard", item.x - 24, item.y - 24 + bob, 48, 48);
    }
    for (const mine of ofudas) renderer.drawStatic("ofuda_mine", mine.x - 16, mine.y - 30, 32, 34);
    if (clone) renderer.drawAnchored("shadow_clone", clone.x, clone.y, 0.19, clone.facing, time, 10, clamp(clone.ttl / 1.2, 0.15, 0.7));

    for (const foe of enemies) {
      if (!foe.alive && foe.deathTime > 0.62) continue;
      const stats = ENEMY_STATS[foe.type];
      const anim = enemyAnimation(foe);
      const scale = stats.spriteH / 360;
      const progress = !foe.alive ? clamp(foe.deathTime / 0.58, 0, 0.999) : null;
      renderer.drawAnchored(anim, foe.x, foe.y, scale, foe.facing, time + foe.startX * 0.002, foe.boss ? 8 : 10, 1, progress);
      if (foe.boss && foe.alive) {
        const ctx = renderer.ctx;
        ctx.fillStyle = "rgba(5,8,25,.82)";
        ctx.fillRect(foe.x - 82, foe.y - foe.h - 24, 164, 9);
        ctx.fillStyle = level.id >= 8 ? "#ff4fd8" : "#49e8ff";
        ctx.fillRect(foe.x - 79, foe.y - foe.h - 21, 158 * (foe.hp / foe.maxHp), 3);
      }
    }

    for (const shot of shots) {
      if (shot.delay > 0) continue;
      renderer.drawAnchored(shot.charged ? "charged_shot" : shot.tail ? "tail_volley" : "kitsunebi", shot.x, shot.y, shot.charged ? 0.18 : shot.tail ? 0.075 : 0.09, Math.sign(shot.vx), time, 14);
    }
    for (const projectile of enemyShots) renderer.drawStatic(projectile.type, projectile.x - 14, projectile.y - 14, 28, 28);
    for (const effect of effects) {
      const progress = 1 - effect.ttl / effect.duration;
      renderer.drawAnchored(effect.anim, effect.x, effect.y, effect.scale, effect.facing, time, 12, clamp(effect.ttl / 0.12, 0, 1), progress);
    }

    const playerAnim = currentPlayerAnimation(input);
    const playerScale = player.spiritTime > 0 && !playerAnim.includes("transform") ? 0.26 : 0.215;
    const progress = player.actionTime > 0 && ["spawn", "land", "tail_gain", "damage", "defeat", "checkpoint_revive", "spirit_transform", "spirit_return", "shoot", "charged_release", "ofuda_throw", "claw_combo", "wall_jump"].includes(playerAnim)
      ? clamp(1 - player.actionTime / (playerAnim === "defeat" ? 0.78 : playerAnim.includes("spirit") ? 0.7 : 0.48), 0, 0.999)
      : null;
    const blink = player.invulnerable > 0 && Math.floor(player.invulnerable * 15) % 2 === 0 ? 0.38 : 1;
    renderer.drawAnchored(playerAnim, player.x, player.y, playerScale, player.facing, time, 11, blink, progress);
  }

  function cameraX(viewWidth) {
    const lookAhead = player.facing * Math.min(120, Math.abs(player.vx) * 0.16);
    return clamp(player.x - viewWidth * 0.45 + lookAhead, 0, Math.max(0, level.length - viewWidth));
  }

  function snapshot() {
    const boss = enemies.find((foe) => foe.boss && foe.alive);
    return {
      tails: player.tails,
      spirit: player.spirit,
      spiritActive: player.spiritTime,
      ofudaReady: 1 - player.ofudaCooldown / 3,
      progress: clamp(player.x / level.length, 0, 1),
      puzzles: puzzles.filter((value) => value.solved).length,
      score,
      combo,
      time: elapsed,
      boss: boss ? { name: ENEMY_STATS[boss.type].name.toUpperCase(), hp: boss.hp / boss.maxHp } : null,
    };
  }

  return {
    player,
    update,
    render,
    snapshot,
    setPaused(value) { paused = value; },
  };
}
