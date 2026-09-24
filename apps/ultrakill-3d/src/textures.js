// Prosedürel piksel dokular (tamamı kodla üretilir; harici görsel yok)
import * as THREE from 'three';
import { mulberry32 } from './util.js';

function makeNoise(seed) {
  const rng = mulberry32(seed);
  const tbl = new Float32Array(65536);
  for (let i = 0; i < tbl.length; i++) tbl[i] = rng();
  return (x, y, p) => {
    const x0 = Math.floor(x), y0 = Math.floor(y);
    const fx = x - x0, fy = y - y0;
    const sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
    const X0 = ((x0 % p) + p) % p, X1 = (X0 + 1) % p;
    const Y0 = ((y0 % p) + p) % p, Y1 = (Y0 + 1) % p;
    const o = p * 97;
    const v = (i, j) => tbl[((j + o) * 256 + i + o) & 65535];
    const a = v(X0, Y0) + (v(X1, Y0) - v(X0, Y0)) * sx;
    const b = v(X0, Y1) + (v(X1, Y1) - v(X0, Y1)) * sx;
    return a + (b - a) * sy;
  };
}

function fbm(n, u, v, base = 4, oct = 4) {
  let a = 0.5, s = 0, norm = 0, p = base;
  for (let o = 0; o < oct; o++) {
    s += a * n(u * p, v * p, p);
    norm += a;
    a *= 0.5;
    p *= 2;
  }
  return s / norm;
}

const hex = (h) => [(h >> 16) & 255, (h >> 8) & 255, h & 255];
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const mul = (a, k) => [a[0] * k, a[1] * k, a[2] * k];

function toTex(canvas, { repeat = true, nearest = true, srgb = true } = {}) {
  const t = new THREE.CanvasTexture(canvas);
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.magFilter = nearest ? THREE.NearestFilter : THREE.LinearFilter;
  t.minFilter = nearest ? THREE.NearestMipmapLinearFilter : THREE.LinearMipmapLinearFilter;
  t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  return t;
}

function pixTex(size, fn, opts = {}) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const ctx = c.getContext('2d');
  const img = ctx.createImageData(size, size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const col = fn(x, y, size);
      const i = (y * size + x) * 4;
      img.data[i] = Math.max(0, Math.min(255, col[0]));
      img.data[i + 1] = Math.max(0, Math.min(255, col[1]));
      img.data[i + 2] = Math.max(0, Math.min(255, col[2]));
      img.data[i + 3] = col.length > 3 ? Math.max(0, Math.min(255, col[3])) : 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  if (opts.post) opts.post(ctx, size);
  return toTex(c, opts);
}

function hash2(x, y, s = 0) {
  let h = (x * 374761393 + y * 668265263 + s * 982451653) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

export function buildTextures() {
  const n1 = makeNoise(11), n2 = makeNoise(23), n3 = makeNoise(37);
  const T = {};

  T.stone = pixTex(64, (x, y) => {
    const row = Math.floor(y / 8);
    const off = (row % 2) * 8;
    const bx = Math.floor((x + off) / 16);
    const shade = hash2(bx & 3, row & 7, 1);
    const n = fbm(n1, x / 64, y / 64, 4, 4);
    let c = mix(hex(0x3e302b), hex(0x6e5d52), n * 0.7 + shade * 0.35);
    if (y % 8 === 0 || (x + off) % 16 === 0) c = mul(c, 0.45);
    else if (y % 8 === 1 || (x + off) % 16 === 1) c = mul(c, 1.15);
    if (fbm(n2, x / 64, y / 64, 8, 2) > 0.7) c = mul(c, 0.7);
    return c;
  });

  T.tiles = pixTex(64, (x, y) => {
    const tx = Math.floor(x / 16), ty = Math.floor(y / 16);
    const shade = hash2(tx, ty, 2);
    const n = fbm(n2, x / 64, y / 64, 4, 4);
    let c = mix(hex(0x2e2624), hex(0x5a4c46), n * 0.8 + shade * 0.25);
    if (x % 16 === 0 || y % 16 === 0) c = mul(c, 0.4);
    else if (x % 16 === 1 || y % 16 === 1) c = mul(c, 1.2);
    const stain = fbm(n3, x / 64, y / 64, 4, 3);
    if (stain > 0.62) c = mix(c, hex(0x4a0a06), (stain - 0.62) * 2.2);
    return c;
  });

  T.metal = pixTex(64, (x, y) => {
    const n = fbm(n3, x / 64, y / 64, 4, 3);
    const streak = n1(x / 3, y / 24, 64 / 3) * 0.15;
    let c = mix(hex(0x3c4048), hex(0x6a707a), n * 0.6 + streak);
    if (x % 32 === 0 || y % 32 === 0) c = mul(c, 0.5);
    if (x % 32 === 1 || y % 32 === 1) c = mul(c, 1.25);
    const rx = x % 32, ry = y % 32;
    if ((rx === 4 || rx === 27) && (ry === 4 || ry === 27)) c = hex(0xa0a6b0);
    if ((rx === 5 || rx === 28) && (ry === 5 || ry === 28)) c = hex(0x202228);
    return c;
  });

  T.rock = pixTex(64, (x, y) => {
    const n = fbm(n1, x / 64, y / 64, 4, 5);
    let c = mix(hex(0x2a0f0b), hex(0x6a2c1c), n);
    const r = Math.abs(fbm(n3, x / 64, y / 64, 4, 3) - 0.5);
    if (r < 0.025) c = mul(c, 0.35);
    return c;
  });

  T.flesh = pixTex(64, (x, y) => {
    const n = fbm(n2, x / 64, y / 64, 4, 4);
    let c = mix(hex(0x3c0508), hex(0x8e1c1a), n);
    const r = Math.abs(fbm(n1, x / 64, y / 64, 4, 3) - 0.5);
    if (r < 0.03) c = mix(c, hex(0x24030a), 0.7);
    if (n > 0.7) c = mix(c, hex(0xc04030), (n - 0.7) * 2);
    return c;
  });

  T.lava = pixTex(64, (x, y) => {
    const n = fbm(n3, x / 64, y / 64, 4, 4);
    let c = mix(hex(0xc02000), hex(0xffd050), n);
    if (n < 0.38) c = mix(hex(0x300400), c, n / 0.38);
    return c;
  });

  T.door = pixTex(64, (x, y) => {
    const n = fbm(n3, x / 64, y / 64, 4, 3);
    let c = mix(hex(0x2c2e34), hex(0x585d66), n * 0.7);
    if (x === 31 || x === 32) c = hex(0x121316);
    if (y >= 50 && y < 60) c = (x + y) % 16 < 8 ? hex(0xd8a010) : hex(0x161412);
    if (y === 49 || y === 60) c = hex(0x101010);
    if (y < 4) c = hex(0x3a0a08);
    if (x % 16 === 8 && y > 6 && y < 46) c = mul(c, 0.6);
    return c;
  });

  T.skin = pixTex(64, (x, y) => {
    const n = fbm(n1, x / 64, y / 64, 8, 4);
    let c = mix(hex(0x6e6254), hex(0xb8a88e), n);
    const b = fbm(n2, x / 64, y / 64, 4, 3);
    if (b > 0.6) c = mix(c, hex(0x5a2a22), (b - 0.6) * 2);
    return c;
  });

  // Nötr (açık) deri ve kumaş: düşman renkleri malzeme rengiyle verilir
  T.skinW = pixTex(64, (x, y) => {
    const n = fbm(n1, x / 64, y / 64, 8, 4);
    let c = mix(hex(0x9a9a9a), hex(0xffffff), n);
    const b = fbm(n2, x / 64, y / 64, 4, 3);
    if (b > 0.62) c = mix(c, hex(0x7a2020), (b - 0.62) * 2.2);
    const v = Math.abs(fbm(n3, x / 64, y / 64, 4, 3) - 0.5);
    if (v < 0.02) c = mul(c, 0.7);
    return c;
  });

  T.clothW = pixTex(64, (x, y) => {
    const n = fbm(n2, x / 64, y / 64, 8, 3);
    let c = mix(hex(0x8a8a8a), hex(0xf0f0f0), n);
    if ((x + y) % 4 === 0) c = mul(c, 0.85);
    if (x % 4 === 0) c = mul(c, 0.9);
    if (fbm(n3, x / 64, y / 64, 4, 2) > 0.66) c = mul(c, 0.55);
    return c;
  });

  T.machine = pixTex(64, (x, y) => {
    const n = fbm(n2, x / 64, y / 64, 4, 3);
    let c = mix(hex(0x2a2c30), hex(0x55595f), n * 0.8);
    if (x % 16 === 0 || y % 21 === 0) c = mul(c, 0.55);
    if ((x + y * 3) % 23 === 0) c = mul(c, 1.3);
    return c;
  });

  T.bone = pixTex(64, (x, y) => {
    const n = fbm(n3, x / 64, y / 64, 8, 3);
    return mix(hex(0x8a7e68), hex(0xd6ccb0), n);
  });

  T.blood = pixTex(64, (x, y, s) => {
    const cx = x - s / 2, cy = y - s / 2;
    const ang = Math.atan2(cy, cx);
    const r = Math.sqrt(cx * cx + cy * cy) / (s / 2);
    const edge = 0.55 + fbm(n1, (ang / (Math.PI * 2)) + 0.5, 0.5, 8, 2) * 0.45;
    let a = r < edge ? 1 : 0;
    // damlacıklar
    const dx = Math.floor(x / 4), dy = Math.floor(y / 4);
    if (!a && hash2(dx, dy, 9) > 0.94 && r < 1) a = 1;
    const shade = fbm(n2, x / 64, y / 64, 4, 3);
    const c = mix(hex(0x3a0000), hex(0x8a0a06), shade);
    return [c[0], c[1], c[2], a * 235];
  }, { repeat: false });

  T.hole = pixTex(32, (x, y, s) => {
    const cx = x - s / 2 + 0.5, cy = y - s / 2 + 0.5;
    const r = Math.hypot(cx, cy) / (s / 2);
    const jag = 0.55 + hash2(Math.floor(Math.atan2(cy, cx) * 3), 1, 5) * 0.25;
    if (r < 0.28) return [8, 6, 6, 255];
    if (r < jag) return [30, 24, 22, 200];
    if (r < jag + 0.12) return [70, 60, 55, 110];
    return [0, 0, 0, 0];
  }, { repeat: false });

  T.glow = (() => {
    const c = document.createElement('canvas');
    c.width = c.height = 64;
    const g = c.getContext('2d');
    const grd = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    grd.addColorStop(0, 'rgba(255,255,255,1)');
    grd.addColorStop(0.25, 'rgba(255,255,255,0.8)');
    grd.addColorStop(0.6, 'rgba(255,255,255,0.2)');
    grd.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = grd;
    g.fillRect(0, 0, 64, 64);
    return toTex(c, { repeat: false, nearest: false });
  })();

  T.star = pixTex(64, (x, y, s) => {
    const cx = (x - s / 2 + 0.5) / (s / 2), cy = (y - s / 2 + 0.5) / (s / 2);
    const ax = Math.abs(cx), ay = Math.abs(cy);
    const cross = Math.max(Math.exp(-ay * 22) * (1 - ax), Math.exp(-ax * 22) * (1 - ay));
    const diag = Math.exp(-Math.abs(ax - ay) * 16) * Math.max(0, 1 - Math.hypot(cx, cy) * 1.6) * 0.5;
    const core = Math.max(0, 1 - Math.hypot(cx, cy) * 3);
    const a = Math.min(1, cross + diag + core);
    return [255, 255, 255, a * 255];
  }, { repeat: false, nearest: false });

  T.sigil = (() => {
    const c = document.createElement('canvas');
    c.width = c.height = 128;
    const g = c.getContext('2d');
    g.strokeStyle = 'rgba(255,40,20,0.95)';
    g.lineWidth = 3;
    g.beginPath(); g.arc(64, 64, 58, 0, Math.PI * 2); g.stroke();
    g.lineWidth = 2;
    g.beginPath(); g.arc(64, 64, 48, 0, Math.PI * 2); g.stroke();
    const pts = 7;
    g.beginPath();
    for (let i = 0; i <= pts; i++) {
      const k = (i * 3) % pts;
      const a = (k / pts) * Math.PI * 2 - Math.PI / 2;
      const px = 64 + Math.cos(a) * 48, py = 64 + Math.sin(a) * 48;
      if (i === 0) g.moveTo(px, py); else g.lineTo(px, py);
    }
    g.stroke();
    for (let i = 0; i < 14; i++) {
      const a = (i / 14) * Math.PI * 2;
      g.fillStyle = 'rgba(255,60,30,0.9)';
      g.fillRect(64 + Math.cos(a) * 53 - 2, 64 + Math.sin(a) * 53 - 2, 4, 4);
    }
    g.beginPath(); g.arc(64, 64, 10, 0, Math.PI * 2); g.stroke();
    return toTex(c, { repeat: false, nearest: true });
  })();

  T.grate = pixTex(32, (x, y) => {
    const bar = x % 8 < 2 || y % 8 < 2;
    const c = mix(hex(0x2a2c30), hex(0x5a5e66), hash2(x, y, 4) * 0.4 + (bar ? 0.4 : 0));
    return [c[0], c[1], c[2], bar ? 255 : 0];
  });

  // ARAF: çimen, kireçtaşı kale tuğlası; Siber Öğütücü: neon ızgara
  T.grass = pixTex(64, (x, y) => {
    const n = fbm(n2, x / 64, y / 64, 4, 4);
    let c = mix(hex(0x2e5a1c), hex(0x6aa83a), n);
    const b = hash2(x, y, 7);
    if (b > 0.86) c = mul(c, 1.25);
    else if (b < 0.1) c = mul(c, 0.75);
    if (fbm(n3, x / 64, y / 64, 6, 2) > 0.68) c = mix(c, hex(0x7a6a3a), 0.35);
    return c;
  });

  T.limestone = pixTex(64, (x, y) => {
    const row = Math.floor(y / 16);
    const off = (row % 2) * 16;
    const bx = Math.floor((x + off) / 32);
    const shade = hash2(bx & 3, row & 3, 5);
    const n = fbm(n1, x / 64, y / 64, 4, 4);
    let c = mix(hex(0xb0a898), hex(0xe8e2d4), n * 0.6 + shade * 0.4);
    if (y % 16 === 0 || (x + off) % 32 === 0) c = mul(c, 0.6);
    else if (y % 16 === 1 || (x + off) % 32 === 1) c = mul(c, 1.08);
    if (fbm(n2, x / 64, y / 64, 8, 2) > 0.72) c = mix(c, hex(0x6a7a4a), 0.3);
    return c;
  });

  T.grid = pixTex(64, (x, y) => {
    const e = x % 32 === 0 || y % 32 === 0 || x % 32 === 31 || y % 32 === 31;
    const f = x % 32 === 1 || y % 32 === 1 || x % 32 === 30 || y % 32 === 30;
    if (e) return hex(0x40f0ff);
    if (f) return hex(0x1a6a90);
    const n = fbm(n3, x / 64, y / 64, 4, 2);
    return mix(hex(0x060a14), hex(0x0e1428), n);
  });

  return T;
}
