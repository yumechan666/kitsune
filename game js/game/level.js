const floor = (x, w, y = 466, h = 130) => ({ x, y, w, h, kind: "platform" });
const ledge = (x, y, w, h = 44) => ({ x, y, w, h, kind: "platform" });
const wall = (x, y, w = 58, h = 185) => ({ x, y, w, h, kind: "platform" });
const enemy = (type, x, y = 466, extra = {}) => ({ type, x, y, ...extra });
const pickup = (type, x, y) => ({ type, x, y });

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
  "Akari · Dawn Miko", "Ren · Storm Ronin", "Sora · Mirror Ninja", "Haru · Bamboo Tengu",
  "Yuna · Moon Conductor", "Kaito · Frost Warden", "Mei · Forge Dancer", "Shin · Void Hunter",
  "Amaya · Star Priestess", "Rei · Eclipse Prince",
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
  shoot: "Strike the shrine target with foxfire",
  dash: "Blink through the sealed beacon",
  charge: "Break the core with a charged shot",
  ofuda: "Ignite the seal with an ofuda mine",
  spirit: "Awaken Spirit Mode beside the rune",
  clone: "Leave an illusion clone on the twin plate",
  glide: "Glide through the wind rune",
};

function buildStage(index) {
  const number = index + 1;
  const id = String(number).padStart(2, "0");
  const length = 25800 + index * 540;
  const platforms = [];
  const hazards = [];
  const enemies = [];
  const pickups = [];
  const segment = 900;
  const segmentCount = Math.ceil((length - 1150) / segment);

  for (let i = 0; i < segmentCount; i += 1) {
    const x = i * segment;
    const floorWidth = 750 + ((i + index) % 2) * 35;
    platforms.push(floor(x, floorWidth));
    hazards.push({ x: x + floorWidth, y: 452, w: segment - floorWidth, h: 24 });
    platforms.push(ledge(x + 390, 350 - ((i + index) % 3) * 42, 190 + (i % 2) * 35));
    if (i % 3 === 1) platforms.push(wall(x + 700, 280 - (index % 2) * 25, 58, 186 + (index % 3) * 22));

    enemies.push(enemy(`s${number}_common`, x + 520, 466));
    if (i % 2 === 1) enemies.push(enemy(`s${number}_rare`, x + 700, 305 - (i % 3) * 25));
    if (i > 0 && i % 3 === 0) enemies.push(enemy(`s${number}_common`, x + 250, 466));
    if (i % 2 === 0) pickups.push(pickup("spirit", x + 470, 295 - (i % 3) * 28));
    if (i === 2 || i === 6) pickups.push(pickup("tail", x + 610, 260));
  }

  const arenaX = length - 1150;
  platforms.push(floor(arenaX, 1250));
  platforms.push(ledge(arenaX + 210, 330, 210), ledge(arenaX + 710, 300, 190));
  const miniX = Math.floor((length * 0.52) / segment) * segment + 520;
  const checkpoints = [0.27, 0.54, 0.8].map((ratio) => Math.floor((length * ratio) / segment) * segment + 180);
  const puzzles = PUZZLE_ACTIONS[index].map((action, puzzleIndex) => {
    const ratios = PUZZLE_ACTIONS[index].length === 4 ? [0.18, 0.4, 0.62, 0.82] : [0.24, 0.5, 0.76];
    const x = Math.floor((length * ratios[puzzleIndex]) / segment) * segment + 610;
    return { id: puzzleIndex, x, action, hint: PUZZLE_HINTS[action] };
  });
  enemies.push(enemy(`s${number}_mini`, miniX, 466, { hp: 24 + index * 3, miniBoss: true }));
  enemies.push(enemy(`s${number}_boss`, length - 470, 466, { hp: 52 + index * 8, boss: true }));

  return {
    id: number,
    name: STAGE_DEFS[index][0],
    subtitle: STAGE_DEFS[index][1],
    bossName: STAGE_DEFS[index][2],
    skinName: SKIN_NAMES[index],
    length,
    backdrop: `WORLD_${id}`,
    tiles: `STAGE${(index % 3) + 1}_TILES`,
    checkpoint: checkpoints[0],
    checkpoints,
    puzzles,
    wind: index === 2 || index === 5 || index === 9 ? 18 + index * 2 : 0,
    platforms,
    enemies,
    pickups,
    hazards,
  };
}

export const LEVELS = Array.from({ length: 10 }, (_, index) => buildStage(index));

export const ENEMY_STATS = {};
for (let stage = 1; stage <= 10; stage += 1) {
  const difficulty = 1 + (stage - 1) * 0.12;
  ENEMY_STATS[`s${stage}_common`] = {
    name: `Stage ${stage} Common`, hp: Math.round(4 * difficulty), w: 45, h: 55, spriteH: 66,
    score: 180 + stage * 25, idle: `s${stage}_common_move`, move: `s${stage}_common_move`,
    attack: `s${stage}_common_attack`, hit: `s${stage}_common_move`, defeat: `s${stage}_common_move`,
    speed: 58 + stage * 2, attackDelay: 1.9, projectileSpeed: 285 + stage * 5,
  };
  ENEMY_STATS[`s${stage}_rare`] = {
    name: `Stage ${stage} Rare`, hp: Math.round(7 * difficulty), w: 52, h: 62, spriteH: 76,
    score: 420 + stage * 45, idle: `s${stage}_rare_move`, move: `s${stage}_rare_move`,
    attack: `s${stage}_rare_attack`, hit: `s${stage}_rare_move`, defeat: `s${stage}_rare_move`,
    speed: 72 + stage * 2, attackDelay: 1.55, projectileSpeed: 330 + stage * 6,
    flying: stage % 3 === 0 || stage === 4 || stage === 8, shotCount: stage >= 7 ? 3 : 2, homing: stage === 3 || stage === 9,
  };
  ENEMY_STATS[`s${stage}_mini`] = {
    name: `Stage ${stage} Miniboss`, hp: 24 + stage * 3, w: 82, h: 88, spriteH: 108,
    score: 1800 + stage * 180, idle: `s${stage}_mini_move`, move: `s${stage}_mini_move`,
    attack: `s${stage}_mini_attack`, hit: `s${stage}_mini_move`, defeat: `s${stage}_mini_move`,
    speed: 56, attackDelay: 1.25, projectileSpeed: 350, shotCount: 3, telegraphTime: 0.48,
  };
  ENEMY_STATS[`s${stage}_boss`] = {
    name: STAGE_DEFS[stage - 1][2], hp: 52 + (stage - 1) * 8, w: 108, h: 118, spriteH: 142,
    score: 5000 + stage * 650, idle: `s${stage}_boss_move`, move: `s${stage}_boss_move`,
    attack: `s${stage}_boss_attack`, hit: `s${stage}_boss_move`, defeat: `s${stage}_boss_move`,
    speed: 44 + stage, attackDelay: 1.05, projectileSpeed: 380 + stage * 6, shotCount: 3 + Math.floor(stage / 4),
    telegraphTime: 0.58, boss: true,
  };
}
