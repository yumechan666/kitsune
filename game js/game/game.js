import { loadStageAssets, preloadGameAssets } from "./assets.js";
import { createAudio } from "./audio.js";
import { createInput } from "./input.js";
import { LEVELS } from "./level.js";
import { createRenderer } from "./renderer.js";
import { createUI } from "./ui.js";
import { createWorld } from "./world.js";

function shellMarkup() {
  return `
    <section class="game-shell">
      <canvas class="game-surface" aria-label="Kitsunebi: Ninefold Neon"></canvas>
      <div class="game-vignette" aria-hidden="true"></div>
      <header class="game-hud">
        <div class="hud-cluster">
          <div class="tail-row" data-ui="tails" aria-label="Spirit tails"></div>
          <button class="spirit-meter" data-action="spirit" aria-label="Activate Spirit Mode">
            <span class="spirit-icon">狐</span><span class="meter-track"><i data-ui="spirit-fill"></i></span>
          </button>
        </div>
        <div class="hud-center">
          <span class="stage-chip" data-ui="stage">TORII TRANSIT</span>
          <span class="score-value" data-ui="score">0</span>
        </div>
        <button class="pause-btn" data-ui="pause" aria-label="Pause">Ⅱ</button>
      </header>
      <div class="stage-progress"><i data-ui="progress-fill"></i></div>
      <div class="boss-hud" data-ui="boss" hidden><span data-ui="boss-name"></span><b><i data-ui="boss-fill"></i></b></div>
      <div class="game-toast" data-ui="toast"></div>
      <div class="touch-controls" aria-label="Touch controls">
        <div class="move-stick" data-stick aria-label="Move joystick">
          <i class="move-stick-knob"></i>
        </div>
        <div class="action-pad">
          <button class="action-btn action-btn--ofuda" data-action="ofuda" aria-label="Ofuda"><span>札</span><i data-ui="ofuda-fill"></i></button>
          <button class="action-btn action-btn--dash" data-action="dash" aria-label="Dash">幻</button>
          <button class="action-btn action-btn--jump" data-action="jump" aria-label="Jump">↑</button>
          <button class="action-btn action-btn--fire" data-action="fire" aria-label="Fire">火</button>
        </div>
      </div>
      <div class="game-overlay" data-ui="overlay">
        <div class="overlay-panel">
          <span class="overlay-kicker" data-ui="overlay-kicker">NEON SHRINE CITY</span>
          <h1 data-ui="overlay-title">Kitsunebi</h1>
          <p data-ui="overlay-copy">Awakening spirit fire… 0%</p>
          <div class="overlay-actions" data-ui="overlay-actions"></div>
        </div>
      </div>
    </section>
  `;
}

function validSave(value) {
  return value && value.version === 1
    ? { unlockedRush: Boolean(value.unlockedRush), bestScore: Number(value.bestScore) || 0 }
    : { unlockedRush: false, bestScore: 0 };
}

export function createGame({ mount, sdk, ready, tweaks, assets }) {
  let cleanup = () => {};

  return {
    start() {
      const shell = document.createElement("section");
      shell.innerHTML = shellMarkup();
      const root = shell.firstElementChild;
      mount.replaceChildren(root);

      const ui = createUI(root);
      const input = createInput(root);
      const config = {
        playerSpeed: Number(tweaks.get("playerSpeed")),
        enemyAggression: Number(tweaks.get("enemyAggression")),
        effectsIntensity: Number(tweaks.get("effectsIntensity")),
        musicVolume: Number(tweaks.get("musicVolume")),
      };
      const audio = createAudio(sdk, config.musicVolume);
      const unsubscribers = [
        tweaks.subscribe("playerSpeed", (value) => { config.playerSpeed = Number(value); }),
        tweaks.subscribe("enemyAggression", (value) => { config.enemyAggression = Number(value); }),
        tweaks.subscribe("effectsIntensity", (value) => { config.effectsIntensity = Number(value); }),
        tweaks.subscribe("musicVolume", (value) => { config.musicVolume = Number(value); audio.setVolume(config.musicVolume); }),
      ];
      const canvas = root.querySelector("canvas");
      let renderer;
      let library;
      let world;
      let raf = 0;
      let lastTime = performance.now();
      let mode = "campaign";
      let stageIndex = 0;
      let playing = false;
      let paused = false;
      let destroyed = false;
      let save = { unlockedRush: false, bestScore: 0 };
      let runScore = 0;
      let carry = null;

      function haptic(strength) {
        try {
          if (!sdk.device.haptics.isSupported()) return;
          const pattern = strength === "heavy" ? [36, 28, 56] : 28;
          void sdk.device.haptics.vibrate(pattern).catch(() => {});
        } catch { /* Haptics are optional. */ }
      }

      function eventHandler(event) {
        if (event.type === "sound") audio.sfx(event.name, event.amount);
        else if (event.type === "haptic") haptic(event.strength);
        else if (event.type === "toast") ui.toast(event.text);
        else if (event.type === "complete") finishStage(event);
      }

      async function createStage(index, inherited = null) {
        stageIndex = index;
        audio.setStage(index);
        if (library.stage !== index) {
          ui.showOverlay({ kicker: `STAGE ${index + 1} / ${LEVELS.length}`, title: LEVELS[index].name, copy: "Calling this district's yokai…" });
          await loadStageAssets(library, assets, index, (progress) => ui.setLoading(progress));
        }
        world = createWorld({ level: LEVELS[index], mode, config, onEvent: eventHandler });
        if (inherited) {
          world.player.tails = inherited.tails;
          world.player.maxTails = inherited.tails;
          world.player.spirit = inherited.spirit;
        }
        ui.toast(`${LEVELS[index].skinName} · ${LEVELS[index].subtitle}`);
      }

      async function beginRun(nextMode) {
        mode = nextMode;
        stageIndex = 0;
        runScore = 0;
        carry = null;
        await createStage(0);
        playing = true;
        paused = false;
        ui.hideOverlay();
        void audio.unlock();
      }

      function stageRank(result) {
        const value = result.score + result.maxTails * 220 - result.hitCount * 180 - result.elapsed * 8;
        return value > 14000 ? "S" : value > 9000 ? "A" : value > 5200 ? "B" : "C";
      }

      function submitFinal(total) {
        const score = Math.max(0, Math.min(Number.MAX_SAFE_INTEGER, Math.floor(total)));
        save.bestScore = Math.max(save.bestScore, score);
        void sdk.gameState.save({ version: 1, ...save }).catch(() => {});
        void sdk.leaderboard.submit(score).catch(() => {});
      }

      function finishStage(result) {
        playing = false;
        runScore += result.score;
        carry = { tails: world.player.tails, spirit: world.player.spirit };
        if (mode === "rush" && stageIndex < LEVELS.length - 1) {
          ui.toast(`Stage ${stageIndex + 1} purified`);
          window.setTimeout(async () => {
            if (destroyed) return;
            await createStage(stageIndex + 1, carry);
            playing = true;
            ui.hideOverlay();
          }, 700);
          return;
        }
        const finalStage = stageIndex === LEVELS.length - 1;
        if (finalStage) {
          save.unlockedRush = true;
          submitFinal(runScore);
          ui.showOverlay({
            kicker: mode === "rush" ? "SPIRIT RUSH COMPLETE" : "AMATERASU ENGINE SEALED",
            title: `Rank ${stageRank({ ...result, score: runScore })}`,
            copy: `<strong>${runScore.toLocaleString("en-US")} points</strong><br>${Math.floor(result.elapsed / 60)}:${String(Math.floor(result.elapsed % 60)).padStart(2, "0")} · ${result.maxTails}/9 tails · ${result.hitCount} hits`,
            actions: [
              { label: "Play Again", action: "campaign" },
              { label: "Spirit Rush", action: "rush", secondary: true },
            ],
          });
        } else {
          ui.showOverlay({
            kicker: `STAGE ${stageIndex + 1} / ${LEVELS.length} COMPLETE`,
            title: `Rank ${stageRank(result)}`,
            copy: `<strong>${result.score.toLocaleString("en-US")} points</strong><br>${result.maxTails}/9 tails · ${result.hitCount} hits`,
            actions: [{ label: "Next Stage", action: "next" }],
          });
        }
      }

      function handleMenu(event) {
        const button = event.target.closest("[data-menu]");
        if (!button) return;
        const action = button.dataset.menu;
        if (action === "campaign") void beginRun("campaign");
        else if (action === "rush") void beginRun("rush");
        else if (action === "next") {
          void createStage(stageIndex + 1, carry).then(() => {
            playing = true;
            ui.hideOverlay();
          });
        } else if (action === "resume") {
          paused = false;
          playing = true;
          world?.setPaused(false);
          ui.hideOverlay();
        } else if (action === "restart") {
          void createStage(stageIndex, carry).then(() => {
            paused = false;
            playing = true;
            ui.hideOverlay();
          });
        }
        void audio.unlock();
      }

      function togglePause() {
        // Ignore the button during rush transitions, where the world is between stages.
        if (!world || (!playing && !paused)) return;
        paused = !paused;
        playing = !paused;
        world.setPaused(paused);
        if (!paused) ui.hideOverlay();
        if (paused) ui.showOverlay({
          kicker: LEVELS[stageIndex].name,
          title: "Paused",
          copy: "The spirit fire is waiting.",
          actions: [{ label: "Resume", action: "resume" }, { label: "Restart Stage", action: "restart", secondary: true }],
        });
      }

      root.addEventListener("click", handleMenu);
      root.querySelector("[data-ui='pause']").addEventListener("click", togglePause);
      const unlock = () => void audio.unlock();
      root.addEventListener("pointerdown", unlock, { capture: true, once: true });
      window.addEventListener("keydown", unlock, { capture: true, once: true });

      function loop(now) {
        if (destroyed) return;
        const dt = Math.min(0.033, Math.max(0.001, (now - lastTime) / 1000));
        lastTime = now;
        if (world && playing) world.update(dt, input);
        if (world && renderer) {
          world.render(renderer, now / 1000, input);
          ui.render(world.snapshot(), LEVELS[stageIndex].name);
        }
        raf = requestAnimationFrame(loop);
      }

      Promise.all([
        preloadGameAssets(assets, (progress) => ui.setLoading(progress)),
        sdk.gameState.load().then(validSave).catch(() => ({ unlockedRush: false, bestScore: 0 })),
      ]).then(([loadedLibrary, saved]) => {
        if (destroyed) return;
        library = loadedLibrary;
        save = saved;
        renderer = createRenderer(canvas, library);
        void createStage(0);
        ui.showOverlay({
          kicker: "TEN YOKAI DISTRICTS",
          title: "Ninefold Neon",
          copy: `Cross ten triple-length districts, solve unique ability seals, master ten alternating kitsune forms, and defeat the Amaterasu Engine.${save.bestScore ? `<br>Best ${save.bestScore.toLocaleString("en-US")}` : ""}`,
          actions: [
            { label: "Start Mission", action: "campaign" },
            ...(save.unlockedRush ? [{ label: "Spirit Rush", action: "rush", secondary: true }] : []),
          ],
        });
      }).catch((error) => {
        ui.showOverlay({
          kicker: "SPIRIT FIRE LOST",
          title: "Assets failed to load",
          copy: error instanceof Error ? error.message : "Please reload the game.",
          actions: [{ label: "Reload", action: "reload" }],
        });
        root.querySelector("[data-menu='reload']")?.addEventListener("click", () => window.location.reload());
      });

      raf = requestAnimationFrame(loop);
      cleanup = () => {
        destroyed = true;
        cancelAnimationFrame(raf);
        root.removeEventListener("click", handleMenu);
        input.destroy();
        ui.destroy();
        renderer?.destroy();
        audio.destroy();
        for (const unsubscribe of unsubscribers) unsubscribe?.();
        mount.replaceChildren();
      };
    },
    destroy() {
      cleanup();
      cleanup = () => {};
    },
    sdk,
    ready,
    tweaks,
    assets,
  };
}
