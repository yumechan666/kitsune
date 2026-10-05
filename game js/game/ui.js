export function createUI(shell) {
  const tailRow = shell.querySelector("[data-ui='tails']");
  const score = shell.querySelector("[data-ui='score']");
  const stage = shell.querySelector("[data-ui='stage']");
  const spiritFill = shell.querySelector("[data-ui='spirit-fill']");
  const spiritButton = shell.querySelector("[data-action='spirit']");
  const ofudaFill = shell.querySelector("[data-ui='ofuda-fill']");
  const progressFill = shell.querySelector("[data-ui='progress-fill']");
  const boss = shell.querySelector("[data-ui='boss']");
  const bossName = shell.querySelector("[data-ui='boss-name']");
  const bossFill = shell.querySelector("[data-ui='boss-fill']");
  const overlay = shell.querySelector("[data-ui='overlay']");
  const overlayKicker = shell.querySelector("[data-ui='overlay-kicker']");
  const overlayTitle = shell.querySelector("[data-ui='overlay-title']");
  const overlayCopy = shell.querySelector("[data-ui='overlay-copy']");
  const overlayActions = shell.querySelector("[data-ui='overlay-actions']");
  const toastNode = shell.querySelector("[data-ui='toast']");
  let toastTimer;
  let lastTails = -1;

  function setActions(actions) {
    overlayActions.replaceChildren(...actions.map(({ label, action, secondary = false }) => {
      const button = document.createElement("button");
      button.className = `menu-btn${secondary ? " menu-btn--secondary" : ""}`;
      button.dataset.menu = action;
      button.innerHTML = `<span class="control-label">${label}</span>`;
      return button;
    }));
  }

  return {
    render(snapshot, levelName) {
      if (snapshot.tails !== lastTails) {
        tailRow.replaceChildren(...Array.from({ length: 9 }, (_, index) => {
          const pip = document.createElement("i");
          pip.className = `tail-pip${index < snapshot.tails ? " is-lit" : ""}`;
          return pip;
        }));
        lastTails = snapshot.tails;
      }
      score.textContent = Math.floor(snapshot.score).toLocaleString("en-US");
      stage.textContent = levelName;
      spiritFill.style.transform = `scaleX(${snapshot.spirit / 100})`;
      spiritButton.classList.toggle("is-ready", snapshot.spirit >= 100);
      spiritButton.classList.toggle("is-active", snapshot.spiritActive > 0);
      ofudaFill.style.transform = `scaleY(${snapshot.ofudaReady})`;
      progressFill.style.transform = `scaleX(${snapshot.progress})`;
      boss.hidden = !snapshot.boss;
      if (snapshot.boss) {
        bossName.textContent = snapshot.boss.name;
        bossFill.style.transform = `scaleX(${snapshot.boss.hp})`;
      }
    },
    showOverlay({ kicker = "", title, copy = "", actions = [] }) {
      overlay.hidden = false;
      overlayKicker.textContent = kicker;
      overlayTitle.textContent = title;
      overlayCopy.innerHTML = copy;
      setActions(actions);
    },
    hideOverlay() { overlay.hidden = true; },
    toast(text) {
      window.clearTimeout(toastTimer);
      toastNode.textContent = text;
      toastNode.classList.add("is-visible");
      toastTimer = window.setTimeout(() => toastNode.classList.remove("is-visible"), 1500);
    },
    setLoading(progress) {
      overlayCopy.textContent = `Awakening spirit fire… ${Math.round(progress * 100)}%`;
    },
    destroy() { window.clearTimeout(toastTimer); },
  };
}
