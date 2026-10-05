const STAGE_NOTES = [
  [220, 277, 330, 415, 330, 277, 247, 330],
  [196, 247, 294, 370, 294, 330, 247, 220],
  [165, 220, 262, 330, 392, 330, 262, 220],
];

export function createAudio(sdk, initialVolume = 0.16) {
  let managed;
  let context;
  let master;
  let timer;
  let step = 0;
  let stage = 0;
  let volume = initialVolume;
  let disposed = false;

  const ready = sdk.audio.getContext().then((value) => {
    managed = value;
    context = value.context;
    master = context.createGain();
    master.gain.value = volume;
    master.connect(context.destination);
  }).catch(() => {});

  function tone(freq, duration = 0.08, type = "sine", gainValue = 0.16, slide = 1) {
    if (!context || context.state !== "running" || !master) return;
    const now = context.currentTime;
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(freq, now);
    oscillator.frequency.exponentialRampToValueAtTime(Math.max(24, freq * slide), now + duration);
    gain.gain.setValueAtTime(gainValue, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
    oscillator.connect(gain).connect(master);
    oscillator.start(now);
    oscillator.stop(now + duration + 0.02);
  }

  function noise(duration = 0.09, gainValue = 0.12) {
    if (!context || context.state !== "running" || !master) return;
    const count = Math.ceil(context.sampleRate * duration);
    const buffer = context.createBuffer(1, count, context.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < count; i += 1) data[i] = (Math.random() * 2 - 1) * (1 - i / count);
    const source = context.createBufferSource();
    const filter = context.createBiquadFilter();
    const gain = context.createGain();
    filter.type = "bandpass";
    filter.frequency.value = 1800;
    gain.gain.value = gainValue;
    source.buffer = buffer;
    source.connect(filter).connect(gain).connect(master);
    source.start();
  }

  function startMusic() {
    if (timer || disposed) return;
    timer = window.setInterval(() => {
      const notes = STAGE_NOTES[stage] || STAGE_NOTES[0];
      const note = notes[step % notes.length];
      tone(note, 0.2, "triangle", 0.045, 0.998);
      if (step % 2 === 0) tone(note / 2, 0.11, "sine", 0.035, 0.8);
      if (step % 4 === 0) noise(0.035, 0.025);
      step += 1;
    }, stage === 2 ? 180 : 220);
  }

  return {
    async unlock() {
      await ready;
      if (!managed) return;
      await managed.unlock().catch(() => {});
      startMusic();
    },
    setStage(index) {
      stage = Math.abs(index) % STAGE_NOTES.length;
      step = 0;
    },
    setVolume(value) {
      volume = value;
      if (master) master.gain.value = volume;
    },
    sfx(name, amount = 1) {
      if (name === "shot") tone(720, 0.07, "triangle", 0.1 * amount, 1.35);
      else if (name === "charge") { tone(180, 0.3, "sawtooth", 0.13, 4); noise(0.16, 0.05); }
      else if (name === "dash") { noise(0.12, 0.1); tone(900, 0.1, "sine", 0.07, 0.35); }
      else if (name === "ofuda") { noise(0.16, 0.11); tone(260, 0.2, "square", 0.08, 0.45); }
      else if (name === "hit") { noise(0.06, 0.11); tone(150, 0.06, "square", 0.07, 0.7); }
      else if (name === "damage") { tone(620, 0.28, "triangle", 0.13, 0.2); noise(0.12, 0.06); }
      else if (name === "transform") { tone(90, 0.7, "sawtooth", 0.13, 6); tone(440, 0.8, "sine", 0.1, 1.5); }
      else if (name === "pickup") tone(560 * amount, 0.12, "sine", 0.1, 1.7);
      else if (name === "jump") tone(280, 0.08, "triangle", 0.07, 1.5);
      else if (name === "boss") { tone(72, 0.5, "sawtooth", 0.12, 0.65); noise(0.2, 0.07); }
    },
    destroy() {
      disposed = true;
      if (timer) window.clearInterval(timer);
      timer = undefined;
      managed?.dispose?.().catch?.(() => {});
    },
  };
}
