const KEY_MAP = {
  KeyA: "left", ArrowLeft: "left", KeyD: "right", ArrowRight: "right",
  Space: "jump", KeyJ: "fire", KeyK: "dash", KeyL: "ofuda", KeyI: "spirit",
};
const STICK_DEAD_ZONE = 0.28;

export function createInput(shell) {
  const held = { left: false, right: false, jump: false, fire: false, dash: false, ofuda: false, spirit: false };
  const pressed = new Set();
  const released = new Set();
  const pointers = new Map();
  // Keyboard and joystick both drive left/right, so track them separately and combine.
  const keyDirection = { left: false, right: false };
  const stick = { pointer: null, left: false, right: false, centerX: 0, radius: 1 };
  const stickEl = shell.querySelector("[data-stick]");
  const knobEl = stickEl?.querySelector(".move-stick-knob");

  const set = (action, value) => {
    if (value && !held[action]) pressed.add(action);
    if (!value && held[action]) released.add(action);
    held[action] = value;
  };
  const refreshDirection = () => {
    set("left", keyDirection.left || stick.left);
    set("right", keyDirection.right || stick.right);
  };

  const onKeyDown = (event) => {
    const action = KEY_MAP[event.code];
    if (!action) return;
    event.preventDefault();
    if (action === "left" || action === "right") {
      keyDirection[action] = true;
      refreshDirection();
    } else set(action, true);
  };
  const onKeyUp = (event) => {
    const action = KEY_MAP[event.code];
    if (!action) return;
    event.preventDefault();
    if (action === "left" || action === "right") {
      keyDirection[action] = false;
      refreshDirection();
    } else set(action, false);
  };

  const onPointerDown = (event) => {
    const control = event.target.closest("[data-action]");
    if (!control) return;
    event.preventDefault();
    control.setPointerCapture?.(event.pointerId);
    const action = control.dataset.action;
    pointers.set(event.pointerId, action);
    set(action, true);
    control.classList.add("is-held");
  };
  const onPointerEnd = (event) => {
    const action = pointers.get(event.pointerId);
    if (!action) return;
    pointers.delete(event.pointerId);
    set(action, false);
    shell.querySelector(`[data-action="${action}"]`)?.classList.remove("is-held");
  };

  const applyStick = (clientX) => {
    const offset = Math.max(-stick.radius, Math.min(stick.radius, clientX - stick.centerX));
    const x = offset / stick.radius;
    stick.left = x < -STICK_DEAD_ZONE;
    stick.right = x > STICK_DEAD_ZONE;
    knobEl?.style.setProperty("transform", `translate(calc(-50% + ${offset}px), -50%)`);
    refreshDirection();
  };
  const releaseStick = (pointerId) => {
    if (stick.pointer === null) return;
    if (pointerId !== undefined && pointerId !== stick.pointer) return;
    stick.pointer = null;
    stick.left = false;
    stick.right = false;
    knobEl?.style.removeProperty("transform");
    refreshDirection();
  };
  const onStickDown = (event) => {
    if (stick.pointer !== null) return;
    event.preventDefault();
    const rect = stickEl.getBoundingClientRect();
    stick.pointer = event.pointerId;
    stick.centerX = rect.left + rect.width / 2;
    stick.radius = rect.width / 2;
    stickEl.setPointerCapture?.(event.pointerId);
    applyStick(event.clientX);
  };
  const onStickMove = (event) => {
    if (event.pointerId === stick.pointer) applyStick(event.clientX);
  };
  const onWindowPointerEnd = (event) => {
    onPointerEnd(event);
    releaseStick(event.pointerId);
  };

  // keyup/pointerup never arrive once the page loses focus, so a direction would stay held.
  const releaseAll = () => {
    keyDirection.left = false;
    keyDirection.right = false;
    releaseStick();
    for (const action of Object.keys(held)) set(action, false);
    pointers.clear();
    shell.querySelectorAll(".is-held").forEach((el) => el.classList.remove("is-held"));
  };
  const onVisibility = () => { if (document.hidden) releaseAll(); };

  window.addEventListener("keydown", onKeyDown, { passive: false });
  window.addEventListener("keyup", onKeyUp, { passive: false });
  window.addEventListener("blur", releaseAll);
  window.addEventListener("pointerup", onWindowPointerEnd);
  window.addEventListener("pointercancel", onWindowPointerEnd);
  document.addEventListener("visibilitychange", onVisibility);
  shell.addEventListener("pointerdown", onPointerDown, { passive: false });
  stickEl?.addEventListener("pointerdown", onStickDown, { passive: false });
  stickEl?.addEventListener("pointermove", onStickMove);
  stickEl?.addEventListener("lostpointercapture", (event) => releaseStick(event.pointerId));

  return {
    held,
    releaseAll,
    consume(action) {
      if (!pressed.has(action)) return false;
      pressed.delete(action);
      return true;
    },
    consumeRelease(action) {
      if (!released.has(action)) return false;
      released.delete(action);
      return true;
    },
    resetEdges() {
      pressed.clear();
      released.clear();
    },
    destroy() {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
      window.removeEventListener("blur", releaseAll);
      window.removeEventListener("pointerup", onWindowPointerEnd);
      window.removeEventListener("pointercancel", onWindowPointerEnd);
      document.removeEventListener("visibilitychange", onVisibility);
      shell.removeEventListener("pointerdown", onPointerDown);
      stickEl?.removeEventListener("pointerdown", onStickDown);
      stickEl?.removeEventListener("pointermove", onStickMove);
    },
  };
}
