const KEY_MAP = {
  KeyA: "left", ArrowLeft: "left", KeyD: "right", ArrowRight: "right",
  Space: "jump", KeyJ: "fire", KeyK: "dash", KeyL: "ofuda", KeyI: "spirit",
};

export function createInput(shell) {
  const held = { left: false, right: false, jump: false, fire: false, dash: false, ofuda: false, spirit: false };
  const pressed = new Set();
  const released = new Set();
  const pointers = new Map();

  const set = (action, value) => {
    if (value && !held[action]) pressed.add(action);
    if (!value && held[action]) released.add(action);
    held[action] = value;
  };

  const onKeyDown = (event) => {
    const action = KEY_MAP[event.code];
    if (!action) return;
    event.preventDefault();
    set(action, true);
  };
  const onKeyUp = (event) => {
    const action = KEY_MAP[event.code];
    if (!action) return;
    event.preventDefault();
    set(action, false);
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

  window.addEventListener("keydown", onKeyDown, { passive: false });
  window.addEventListener("keyup", onKeyUp, { passive: false });
  shell.addEventListener("pointerdown", onPointerDown, { passive: false });
  shell.addEventListener("pointerup", onPointerEnd);
  shell.addEventListener("pointercancel", onPointerEnd);

  return {
    held,
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
      shell.removeEventListener("pointerdown", onPointerDown);
      shell.removeEventListener("pointerup", onPointerEnd);
      shell.removeEventListener("pointercancel", onPointerEnd);
    },
  };
}
