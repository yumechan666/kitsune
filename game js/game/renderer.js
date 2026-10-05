function animationFrame(library, name, time, fps = 10, progress = null) {
  const animation = library.animations[name];
  if (!animation) return null;
  const count = animation.frames.length;
  const index = progress == null
    ? Math.floor(time * fps) % count
    : Math.min(count - 1, Math.floor(progress * count));
  return { image: animation.image, frame: animation.frames[index] };
}

export function drawAnchored(ctx, library, name, x, y, scale, facing = 1, time = 0, fps = 10, alpha = 1, progress = null) {
  const entry = animationFrame(library, name, time, fps, progress);
  if (!entry) return;
  const frame = entry.frame;
  const crop = frame.content || frame.source;
  const anchor = frame.anchor || { x: frame.source.x + frame.source.w / 2, y: frame.source.y + frame.source.h };
  const dx = -(anchor.x - crop.x) * scale;
  const dy = -(anchor.y - crop.y) * scale;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.translate(x, y);
  ctx.scale(facing, 1);
  ctx.drawImage(entry.image, crop.x, crop.y, crop.w, crop.h, dx, dy, crop.w * scale, crop.h * scale);
  ctx.restore();
}

export function drawStaticFrame(ctx, library, name, x, y, w, h, alpha = 1) {
  const entry = library.frames[name];
  if (!entry) return;
  const crop = entry.frame.content || entry.frame.source;
  const scale = Math.min(w / crop.w, h / crop.h);
  const dw = crop.w * scale;
  const dh = crop.h * scale;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.drawImage(entry.image, crop.x, crop.y, crop.w, crop.h, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh);
  ctx.restore();
}

export function createRenderer(canvas, library) {
  const ctx = canvas.getContext("2d", { alpha: false });
  let width = 1;
  let height = 1;
  let dpr = 1;
  let worldWidth = 600;
  const observer = new ResizeObserver(resize);

  function resize() {
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    width = rect.width;
    height = rect.height;
    worldWidth = Math.max(600, Math.min(960, (width / height) * 540));
  }
  observer.observe(canvas);
  resize();

  function worldTransform(cameraX, shakeX = 0, shakeY = 0) {
    const scale = height / 540;
    const offsetX = (width - worldWidth * scale) / 2;
    ctx.setTransform(scale * dpr, 0, 0, scale * dpr, (offsetX + shakeX) * dpr, shakeY * dpr);
    ctx.translate(-cameraX, 0);
    return scale;
  }

  function drawBackdrop(key, cameraX, flash = 0) {
    const image = library.images[key];
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const scale = Math.max(width / image.width, height / image.height);
    const drawW = image.width * scale;
    const drawH = image.height * scale;
    const parallax = (cameraX * 0.12) % drawW;
    const start = -parallax - drawW;
    for (let i = 0; i < 4; i += 1) {
      const x = start + i * drawW;
      if (i % 2 === 0) ctx.drawImage(image, x, (height - drawH) / 2, drawW, drawH);
      else {
        ctx.save();
        ctx.translate(x + drawW, 0);
        ctx.scale(-1, 1);
        ctx.drawImage(image, 0, (height - drawH) / 2, drawW, drawH);
        ctx.restore();
      }
    }
    const wash = ctx.createLinearGradient(0, 0, 0, height);
    wash.addColorStop(0, "rgba(5,9,35,.12)");
    wash.addColorStop(0.65, "rgba(4,8,28,.04)");
    wash.addColorStop(1, "rgba(8,18,48,.08)");
    ctx.fillStyle = wash;
    ctx.fillRect(0, 0, width, height);
    if (flash > 0) {
      ctx.fillStyle = `rgba(170,220,255,${flash})`;
      ctx.fillRect(0, 0, width, height);
    }
  }

  function drawPlatform(tileKey, platform) {
    const sheet = library.sheets[tileKey];
    const image = library.images[tileKey];
    const frame = sheet?.frames?.find((value) => value.name === "center");
    if (!frame || !image) return;
    const crop = frame.content || frame.source;
    ctx.save();
    ctx.beginPath();
    ctx.rect(platform.x, platform.y, platform.w, platform.h);
    ctx.clip();
    ctx.drawImage(image, crop.x, crop.y, crop.w, crop.h, platform.x, platform.y - 4, platform.w, platform.h + 8);
    ctx.restore();
  }

  function drawRain(cameraX, time, stage) {
    ctx.save();
    ctx.strokeStyle = stage % 3 === 2 ? "rgba(170,210,255,.28)" : "rgba(110,190,255,.18)";
    ctx.lineWidth = 1;
    for (let i = 0; i < 52; i += 1) {
      const x = cameraX + ((i * 137 + time * (stage % 3 === 2 ? 420 : 250)) % (worldWidth + 80)) - 40;
      const y = ((i * 83 + time * 310) % 590) - 30;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x - 7, y + 18);
      ctx.stroke();
    }
    ctx.restore();
  }

  return {
    ctx,
    get viewWidth() { return worldWidth; },
    get cssWidth() { return width; },
    get cssHeight() { return height; },
    begin(level, cameraX, time, shake = 0, flash = 0) {
      drawBackdrop(level.backdrop, cameraX, flash);
      const sx = shake ? (Math.random() - 0.5) * shake : 0;
      const sy = shake ? (Math.random() - 0.5) * shake : 0;
      worldTransform(cameraX, sx, sy);
      drawRain(cameraX, time, level.id - 1);
    },
    drawPlatform,
    drawAnchored: (...args) => drawAnchored(ctx, library, ...args),
    drawStatic: (...args) => drawStaticFrame(ctx, library, ...args),
    screenFade(alpha, color = "#050817") {
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.fillStyle = color;
      ctx.globalAlpha = alpha;
      ctx.fillRect(0, 0, width, height);
      ctx.globalAlpha = 1;
    },
    destroy() { observer.disconnect(); },
  };
}
