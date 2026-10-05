const CORE_KEYS = [
  "STAGE1_TILES", "STAGE2_TILES", "STAGE3_TILES",
  "OBJECT_ATLAS", "FX_SHEET_C",
];

const fullSkinKeys = (id) => [
  `${id}_BASE_A`, `${id}_BASE_B`, `${id}_MOBILITY`, `${id}_COMBAT`, `${id}_STATE`,
  `${id}_FERAL_A`, `${id}_FERAL_B`, `${id}_FERAL_C`, `${id}_FX_A`, `${id}_FX_B`,
];

const skinKeys = (index) => {
  if (index === 0) return [
    "AKARI_BASE_A", "AKARI_BASE_B", "AKARI_MOBILITY", "AKARI_COMBAT", "AKARI_STATE",
    "AKARI_FERAL_A", "AKARI_FERAL_B", "AKARI_FERAL_C", "FX_SHEET_A", "FX_SHEET_B",
  ];
  const id = `SKIN_${String(index + 1).padStart(2, "0")}`;
  return index <= 3 ? fullSkinKeys(id) : [`${id}_MASTER`, `${id}_FX`];
};

const stageKeys = (index) => {
  const id = String(index + 1).padStart(2, "0");
  return [`WORLD_${id}`, `WORLD_${id}_ENEMIES`, `WORLD_${id}_BOSSES`, `WORLD_${id}_PUZZLE`, ...skinKeys(index)];
};

const PLAYER_ANIMATIONS = [
  "idle", "run", "jump_up", "fall", "land", "spawn", "tail_gain", "checkpoint_revive",
  "dash", "wall_slide", "wall_jump", "tail_glide", "shoot", "charge", "charged_release",
  "ofuda_throw", "recoil_hit", "damage", "defeat", "air_dash", "spirit_transform",
  "feral_idle", "feral_run", "feral_leap", "spirit_return", "claw_combo", "pounce",
  "rising_slash", "landing_smash", "feral_hit", "kitsunebi", "charged_shot",
  "ofuda_explosion", "dash_trail", "shadow_clone", "tail_volley", "transform_burst", "claw_arc",
];

function addCompactSkinAliases(library) {
  const alias = (name, fallback) => {
    if (!library.animations[name] && library.animations[fallback]) library.animations[name] = library.animations[fallback];
  };
  for (const name of ["jump_up", "fall", "dash", "wall_slide", "wall_jump", "tail_glide", "air_dash"]) alias(name, "run");
  for (const name of ["land", "spawn", "tail_gain", "checkpoint_revive", "recoil_hit", "damage", "defeat"]) alias(name, "idle");
  for (const name of ["shoot", "charge", "charged_release", "ofuda_throw"]) alias(name, "attack_master");
  for (const name of ["spirit_transform", "feral_idle", "feral_run", "feral_leap", "spirit_return", "claw_combo", "pounce", "rising_slash", "landing_smash", "feral_hit"]) alias(name, "feral_master");
  alias("charged_shot", "kitsunebi");
  alias("ofuda_explosion", "transform_burst");
  alias("shadow_clone", "transform_burst");
  alias("tail_volley", "kitsunebi");
}

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.decoding = "async";
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`Failed to load ${url}`));
    image.src = url;
  });
}

function sidecarUrl(url) {
  return url.replace(/\.webp(?:\?.*)?$/, ".frames.json");
}

async function loadKeys(library, assets, keys, onProgress) {
  let done = 0;
  await Promise.all(keys.map(async (key) => {
    if (library.images[key]) {
      done += 1;
      onProgress(done / keys.length);
      return;
    }
    const url = assets?.get(key);
    if (!url) throw new Error(`Asset ${key} is unavailable`);
    const imagePromise = loadImage(url);
    const framePromise = /^WORLD_\d{2}$/.test(key)
      ? Promise.resolve(null)
      : fetch(sidecarUrl(url)).then((response) => {
          if (!response.ok) throw new Error(`Frame data for ${key} is unavailable`);
          return response.json();
        });
    const [image, sheet] = await Promise.all([imagePromise, framePromise]);
    library.images[key] = image;
    if (sheet) {
      library.sheets[key] = sheet;
      for (const frame of sheet.frames || []) library.frames[frame.name] = { image, frame, key };
      for (const animation of sheet.animations || []) {
        library.animations[animation.name] = { image, frames: animation.frames, key };
      }
    }
    done += 1;
    onProgress(done / keys.length);
  }));
}

export async function preloadGameAssets(assets, onProgress = () => {}) {
  const library = { images: {}, sheets: {}, animations: {}, frames: {}, stage: -1 };
  const keys = [...CORE_KEYS, ...stageKeys(0)];
  await loadKeys(library, assets, keys, onProgress);
  library.stage = 0;
  return library;
}

export async function loadStageAssets(library, assets, index, onProgress = () => {}) {
  if (library.stage === index) return;
  for (let stage = 0; stage < 10; stage += 1) {
    if (stage === index) continue;
    for (const key of stageKeys(stage)) {
      delete library.images[key];
      delete library.sheets[key];
    }
    const prefix = `s${stage + 1}_`;
    for (const name of Object.keys(library.animations)) if (name.startsWith(prefix)) delete library.animations[name];
    for (const name of Object.keys(library.frames)) if (name.startsWith(prefix)) delete library.frames[name];
  }
  for (const name of PLAYER_ANIMATIONS) delete library.animations[name];
  for (const [name, entry] of Object.entries(library.frames)) {
    if (entry.key.startsWith("AKARI_") || entry.key.startsWith("SKIN_") || entry.key === "FX_SHEET_A" || entry.key === "FX_SHEET_B") delete library.frames[name];
  }
  await loadKeys(library, assets, stageKeys(index), onProgress);
  addCompactSkinAliases(library);
  library.stage = index;
}
