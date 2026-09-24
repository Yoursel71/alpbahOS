// SİBER ÖĞÜTÜCÜ: sonsuz dalga modu. 8×8 neon sütunlu ızgara; her dalgadan önce sütunlar yeni bir
// desene göre yükselip alçalır. Dalgalar gittikçe büyür, ölünce koşu biter ve ulaşılan dalga kaydedilir.
import * as THREE from 'three';
import { boxGeo } from '../level.js';
import { room } from './common.js';

const N = 8, CELL = 4, HALF = (N * CELL) / 2; // alan: x,z ∈ [-16, 16]
const DEPTH = 14;

// Yükselip alçalan sütun. Kapı arayüzünü taklit eder (update/reset/setInstant), böylece
// Level.update ve bölüm sıfırlama onu kendiliğinden yönetir.
class Pillar {
  constructor(L, x0, z0, x1, z1) {
    this.box = [x0, -DEPTH, z0, x1, 0, z1];
    this.mesh = new THREE.Mesh(boxGeo(x0, -DEPTH, z0, x1, 0, z1, 4), L.mats.neon);
    L.scene.add(this.mesh);
    this.solid = L.world.add(x0, -DEPTH, z0, x1, 0, z1, 'static');
    this.h = 0;
    this.target = 0;
    this.apply();
  }
  apply() {
    this.mesh.position.y = this.h;
    this.solid.minY = -DEPTH + this.h;
    this.solid.maxY = this.h;
  }
  update(dt) {
    if (this.h === this.target) return;
    const s = 5 * dt;
    this.h = this.target > this.h ? Math.min(this.target, this.h + s) : Math.max(this.target, this.h - s);
    this.apply();
  }
  reset() { this.setInstant(0); }
  setInstant(h) { this.h = this.target = typeof h === 'number' ? h : 0; this.apply(); }
  open() {}
  close() {}
  center() { return new THREE.Vector3((this.box[0] + this.box[3]) / 2, this.h, (this.box[2] + this.box[5]) / 2); }
}

// Desenler: (i, j, dalga) → yükseklik
const PATTERNS = [
  () => 0,
  (i, j) => (i === 0 || j === 0 || i === N - 1 || j === N - 1 ? 3 : 0),
  (i, j) => ((i + j) % 2 ? 1.5 : 0),
  (i, j) => Math.max(0, 3 - Math.max(Math.abs(i - 3.5), Math.abs(j - 3.5))) * 1.2,
  (i, j, w) => ((i * 7 + j * 13 + w * 5) % 5 === 0 ? 4 : (i * 3 + j * 5 + w) % 7 === 0 ? 2 : 0),
  (i, j) => (i === 2 || i === 5 ? 2.5 : 0),
  (i, j) => (Math.abs(i - 3.5) + Math.abs(j - 3.5) < 2.5 ? 0 : (i + j) % 3 === 0 ? 3 : 0.8),
];

// Dalga bütçesi: düşman türü → maliyet ve açıldığı dalga
const ROSTER = [
  { t: 'filth', c: 1, from: 1 },
  { t: 'stray', c: 1.5, from: 1 },
  { t: 'drone', c: 1.5, from: 2, fly: true },
  { t: 'schism', c: 2, from: 3 },
  { t: 'streetcleaner', c: 2.5, from: 4 },
  { t: 'maliciousface', c: 5, from: 6, fly: true, max: 2 },
  { t: 'swordsmachine', c: 8, from: 8, max: 1 },
  { t: 'hideousmass', c: 10, from: 11, max: 1 },
  { t: 'cerberus', c: 8, from: 13, max: 1 },
  { t: 'v2', c: 12, from: 16, max: 1 },
];

export function buildCyberGrind(L) {
  L.theme = {
    fog: 0x06040e, fogNear: 30, fogFar: 130,
    skyTop: [0.0, 0.0, 0.03], skyHor: [0.06, 0.02, 0.14], skyCloud: [0.12, 0.02, 0.22], skyGlow: [0.55, 0.08, 0.7],
    hemiSky: 0xb8c8ff, hemiGround: 0x301040, hemi: 2.2, ambient: 0x404070, sun: 0xa8b8ff,
  };
  L.endless = true;
  L.noBase = true;
  L.spawn = { pos: [0, 0.1, 27], yaw: 0, pitch: -0.05, checkpoint: [0, 0, 27] };
  L.menuCam = { target: [0, 2, 0], radius: 20, height: 9 };
  L.decor = [['drone', [-4, 5, -4], 0.4], ['streetcleaner', [4, 0, 2], -0.5], ['v2', [0, 0, -6], 0]];

  // ===== Hazırlık odası (x -6..6, z 17..33) =====
  room(L, -6, 17, 6, 33, { h: 8, mat: 'neonWall', floor: 'neon', ceil: 'neonWall', skip: ['n'] });
  L.shop(4.4, 0, 27, -Math.PI / 2);
  L.hint([-5, 0, 18, 5, 3, 32], 'SİBER ÖĞÜTÜCÜ: bitmeyen dalgalar. Her dalga öncekinden zor. Öldüğünde koşu biter — ulaştığın dalga kaydedilir.', 9);

  // ===== Izgara (x -16..16, z -16..16) =====
  room(L, -HALF, -HALF, HALF, HALF, { h: 26, mat: 'neonWall', floor: null, gaps: { s: [-4, 4, 8] } });
  L.box(-HALF - 1, -DEPTH - 2, -HALF - 1, HALF + 1, -DEPTH, HALF + 1, 'neonWall');
  L.door('dIn', -4, 0, 16.2, 4, 8, 16.8, { open: true });
  const pillars = [];
  for (let i = 0; i < N; i++) {
    for (let j = 0; j < N; j++) {
      const x0 = -HALF + i * CELL, z0 = -HALF + j * CELL;
      const p = new Pillar(L, x0, z0, x0 + CELL, z0 + CELL);
      p.i = i; p.j = j;
      L.doors[`cg_${i}_${j}`] = p;
      pillars.push(p);
    }
  }
  L.cg = { pillars };
  // köşe ışıkları
  for (const [x, z] of [[-HALF + 1, -HALF + 1], [HALF - 1, -HALF + 1], [-HALF + 1, HALF - 1], [HALF - 1, HALF - 1]]) {
    L.lamps.push({ pos: new THREE.Vector3(x, 10, z), color: 0xc040ff, power: 1.3 });
  }
  const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: L.T.glow, color: 0x40e0ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  glow.position.set(0, 24, 0);
  glow.scale.set(40, 40, 1);
  L.scene.add(glow);
  L.animated.push((t) => { glow.material.opacity = 0.35 + Math.sin(t * 1.5) * 0.1; });

  const pillarAt = (x, z) => {
    const i = Math.floor((x + HALF) / CELL), j = Math.floor((z + HALF) / CELL);
    return i >= 0 && j >= 0 && i < N && j < N ? pillars[i * N + j] : null;
  };

  // Sonsuz arena: dalgaları genWave üretir
  L.arena({
    id: 'cg', name: 'SİBER ÖĞÜTÜCÜ',
    trigger: [-HALF, 0, 8, HALF, 6, 15.5],
    lock: ['dIn'], exits: [],
    endless: true,
    waves: [],
    genWave: (w, g) => genWave(w, g, pillars, pillarAt),
    onWave: (g, w) => {
      g.cgWave = w + 1;
      g.hud.titleCard(`<div class="tc-layer">SİBER ÖĞÜTÜCÜ</div><div class="tc-name">DALGA ${w + 1}</div>`, 1.8);
      g.hud.cgWave && g.hud.cgWave(w + 1);
    },
    onStart: (g) => { g.cgWave = 0; },
  });
  L.finalize();
}

// Dalga üret: önce sütunları yeni desene taşı, sonra bütçeye göre düşman seç ve yerleştir
function genWave(w, g, pillars, pillarAt) {
  const n = w + 1;
  const p = g.player;
  const pat = n === 1 ? PATTERNS[0] : PATTERNS[(n * 3 + 1) % PATTERNS.length];
  const pc = pillarAt(p.pos.x, p.pos.z);
  for (const pl of pillars) {
    // oyuncunun altındaki ve komşu sütunlar oynamaz (sıkışmasın)
    if (pc && Math.abs(pl.i - pc.i) <= 1 && Math.abs(pl.j - pc.j) <= 1) continue;
    pl.target = pat(pl.i, pl.j, n);
  }
  if (n > 1) {
    const heal = Math.min(p.maxHp - p.hard - p.hp, 40);
    if (heal > 0) p.heal(heal);
    g.hud.message(`DALGA ${n - 1} TEMİZ${heal > 0 ? `  +${Math.round(heal)} CAN` : ''}`, 1.6, 'cp');
    g.bonusP = (g.bonusP || 0) + 150 * (n - 1);
  }
  let budget = 2 + n * 1.7;
  const list = [];
  const count = {};
  const pool = ROSTER.filter((r) => n >= r.from);
  let guard = 0;
  while (budget > 0.9 && list.length < 14 && guard++ < 60) {
    const r = pool[Math.floor(Math.random() * pool.length)];
    if (r.c > budget + 0.5 || (r.max && (count[r.t] || 0) >= r.max)) continue;
    count[r.t] = (count[r.t] || 0) + 1;
    budget -= r.c;
    // oyuncudan uzak rastgele hücre; sütunun hedef yüksekliğinin üstünde doğar
    let cell = null;
    for (let k = 0; k < 20; k++) {
      const c = pillars[Math.floor(Math.random() * pillars.length)];
      const cx = -HALF + (c.i + 0.5) * CELL, cz = -HALF + (c.j + 0.5) * CELL;
      if (Math.hypot(cx - p.pos.x, cz - p.pos.z) > 11) { cell = c; break; }
    }
    if (!cell) cell = pillars[0];
    const x = -HALF + (cell.i + 0.5) * CELL, z = -HALF + (cell.j + 0.5) * CELL;
    list.push({ t: r.t, p: [x, cell.target + (r.fly ? 5 : 0.05), z] });
  }
  return list;
}
