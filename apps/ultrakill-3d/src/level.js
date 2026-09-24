// Bölüm altyapısı: geometri yardımcıları, kapılar, tetikleyiciler, arenalar, checkpoint'ler,
// gizli küreler, dükkân terminalleri ve gökyüzü. Bölüm düzenleri src/levels/ altındadır.
import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { psx } from './render.js';
import { rand } from './util.js';

function boxGeo(x0, y0, z0, x1, y1, z1, texScale = 4) {
  const w = x1 - x0, h = y1 - y0, d = z1 - z0;
  const g = new THREE.BoxGeometry(w, h, d);
  g.translate((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
  const pos = g.attributes.position, nor = g.attributes.normal, uv = g.attributes.uv;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    const nx = Math.abs(nor.getX(i)), ny = Math.abs(nor.getY(i));
    let u, v;
    if (nx > 0.5) { u = z; v = y; } else if (ny > 0.5) { u = x; v = z; } else { u = x; v = y; }
    uv.setXY(i, u / texScale, v / texScale);
  }
  return g;
}

export class Door {
  constructor(level, id, x0, y0, z0, x1, y1, z1, { open = false, dir = 'up', travel = null, mat = 'door' } = {}) {
    this.level = level;
    this.id = id;
    this.box = [x0, y0, z0, x1, y1, z1];
    this.dir = dir;
    this.travel = travel ?? (y1 - y0);
    const geo = boxGeo(x0, y0, z0, x1, y1, z1, mat === 'door' ? Math.max(x1 - x0, z1 - z0) : 4);
    this.mesh = new THREE.Mesh(geo, level.mats[mat]);
    level.scene.add(this.mesh);
    this.solid = level.world.add(x0, y0, z0, x1, y1, z1, 'door');
    this.t = open ? 1 : 0;
    this.target = this.t;
    this.initialOpen = open;
    // Kilit ışığı (kırmızı: kilitli, yeşil: açık)
    if (mat === 'door') {
      const cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
      const thin = (x1 - x0) > (z1 - z0);
      this.lamp = new THREE.Mesh(new THREE.BoxGeometry(thin ? 1.2 : 0.3, 0.3, thin ? 0.3 : 1.2), new THREE.MeshBasicMaterial({ color: 0xff2010 }));
      this.lamp.position.set(cx, y1 + 0.5, cz);
      level.scene.add(this.lamp);
      // İki yüzde de görünsün diye biraz kalın
    }
    this.apply();
  }

  open(silent = false) {
    if (this.target === 1) return;
    this.target = 1;
    if (!silent) this.level.game.audio.play('door', this.center());
  }

  close(silent = false) {
    if (this.target === 0) return;
    this.target = 0;
    if (!silent) this.level.game.audio.play('doorSlam', this.center());
  }

  center() {
    const b = this.box;
    return new THREE.Vector3((b[0] + b[3]) / 2, (b[1] + b[4]) / 2, (b[2] + b[5]) / 2);
  }

  apply() {
    const off = this.t * this.travel * (this.dir === 'up' ? 1 : -1);
    this.mesh.position.y = off;
    const b = this.box;
    this.solid.minY = b[1] + off;
    this.solid.maxY = b[4] + off;
    this.solid.enabled = this.t < 0.97;
    if (this.lamp) this.lamp.material.color.setHex(this.target > 0.5 ? 0x20ff60 : 0xff2010);
  }

  update(dt) {
    if (this.t === this.target) return;
    const speed = this.target > this.t ? 0.9 : 3.0;
    if (this.target > this.t) this.t = Math.min(this.target, this.t + dt * speed);
    else this.t = Math.max(this.target, this.t - dt * speed);
    this.apply();
  }

  reset() {
    this.setInstant(this.initialOpen);
  }

  setInstant(open) {
    this.t = this.target = open ? 1 : 0;
    this.apply();
  }
}

// Bölüm teması: sis, gökyüzü ve ortam ışığı renkleri
export const DEFAULT_THEME = {
  fog: 0x2a0806, fogNear: 30, fogFar: 140,
  skyTop: [0.02, 0.0, 0.0], skyHor: [0.30, 0.05, 0.02], skyCloud: [0.25, 0.05, 0.01], skyGlow: [0.4, 0.08, 0.0],
  hemiSky: 0xffa888, hemiGround: 0x3a1410, hemi: 1.9, ambient: 0x5a3030, sun: 0xff9a70,
};

export class Level {
  constructor(game) {
    this.game = game;
    // Tüm bölüm nesneleri tek bir kök grupta: bölüm değişince toptan kaldırılır
    this.root = new THREE.Group();
    game.scene.add(this.root);
    this.scene = this.root;
    this.world = game.world;
    const T = game.tex;
    this.T = T;
    const lam = (map, color = 0xffffff) => psx(new THREE.MeshLambertMaterial({ map, color }));
    this.mats = {
      stone: lam(T.stone),
      tiles: lam(T.tiles),
      metal: lam(T.metal),
      rock: lam(T.rock),
      flesh: lam(T.flesh),
      door: lam(T.door),
      bone: lam(T.bone),
      dark: lam(T.rock, 0x553333),
      meat: lam(T.flesh, 0xffb0a8),
      ruin: lam(T.stone, 0xffc890),
      marble: lam(T.stone, 0xdcdcf0),
      ash: lam(T.rock, 0xa89c98),
      gold: lam(T.metal, 0xffc860),
      lava: psx(new THREE.MeshBasicMaterial({ map: T.lava, color: 0xffffff })),
      glow: new THREE.MeshBasicMaterial({ color: 0xff4020 }),
    };
    this.buckets = new Map();
    this.doors = {};
    this.triggers = [];
    this.arenas = [];
    this.secrets = [];
    this.hurtZones = [];
    this.lamps = [];
    this.fires = [];
    this.animated = [];
    this.extraEnemies = [];
    this.pickups = [];
    this.trainers = [];
    this.shops = [];
    this.spawn = { pos: [0, 40, 108], yaw: 0, checkpoint: [0, 0, 106] };
    this.killY = -40;
    this.totalEnemies = 0;
    this.lavaTex = T.lava;
    this.theme = { ...DEFAULT_THEME };
    this.decor = []; // menü arka planındaki poz veren düşmanlar: [tür, [x,y,z], yaw]
    this.menuCam = { target: [0, 2.2, -3], radius: 15, height: 5.5 };
    this.startArmed = true; // false: silahsız başla (0-1 tutorial)
  }

  dispose() {
    this.game.scene.remove(this.root);
    const mats = new Set();
    this.root.traverse((o) => {
      if (o.geometry) o.geometry.dispose();
      if (o.material) (Array.isArray(o.material) ? o.material : [o.material]).forEach((m) => mats.add(m));
    });
    for (const m of mats) m.dispose();
    for (const k in this.mats) this.mats[k].dispose();
  }

  box(x0, y0, z0, x1, y1, z1, mat = 'stone', { solid = true, visible = true, texScale = 4, playerOnly = false } = {}) {
    if (solid) { const so = this.world.add(x0, y0, z0, x1, y1, z1, 'static'); so.playerOnly = playerOnly; }
    if (visible) {
      if (!this.buckets.has(mat)) this.buckets.set(mat, []);
      this.buckets.get(mat).push(boxGeo(Math.min(x0, x1), Math.min(y0, y1), Math.min(z0, z1), Math.max(x0, x1), Math.max(y0, y1), Math.max(z0, z1), texScale));
    }
  }

  // Basamaklar (x ekseninde). xBottom→xTop yönünde yükselir.
  stairsX(z0, z1, xBottom, xTop, y0, y1, n, mat = 'stone') {
    const dir = Math.sign(xTop - xBottom);
    const dx = Math.abs(xTop - xBottom) / n;
    const dy = (y1 - y0) / n;
    for (let k = 1; k <= n; k++) {
      const xs = xBottom + dir * (k - 1) * dx;
      this.box(Math.min(xs, xTop), y0, z0, Math.max(xs, xTop), y0 + k * dy, z1, mat);
    }
  }

  stairsZ(x0, x1, zBottom, zTop, y0, y1, n, mat = 'stone') {
    const dir = Math.sign(zTop - zBottom);
    const dz = Math.abs(zTop - zBottom) / n;
    const dy = (y1 - y0) / n;
    for (let k = 1; k <= n; k++) {
      const zs = zBottom + dir * (k - 1) * dz;
      this.box(x0, y0, Math.min(zs, zTop), x1, y0 + k * dy, Math.max(zs, zTop), mat);
    }
  }

  door(id, x0, y0, z0, x1, y1, z1, opts) {
    const d = new Door(this, id, x0, y0, z0, x1, y1, z1, opts);
    this.doors[id] = d;
    return d;
  }

  trigger(box, fn, { once = true, id = null } = {}) {
    const t = { box, fn, once, fired: false, id };
    this.triggers.push(t);
    return t;
  }

  hint(box, text, dur = 7) {
    return this.trigger(box, () => this.game.hud.hint(text, dur));
  }

  checkpoint(box, spawn, yaw = 0) {
    return this.trigger(box, () => this.game.setCheckpoint(new THREE.Vector3(...spawn), yaw));
  }

  hurt(box, dps, kind = 'lava') {
    this.hurtZones.push({ box, dps, kind });
  }

  arena(def) {
    const a = { ...def, state: 'idle', wave: -1, enemies: [], delay: 0 };
    let n = 0;
    for (const w of def.waves) n += w.length;
    this.totalEnemies += n;
    a.trig = this.trigger(def.trigger, () => this.game.arenas.start(a), { once: true });
    this.arenas.push(a);
    return a;
  }

  secret(x, y, z) {
    const g = new THREE.Group();
    const core = new THREE.Mesh(new THREE.IcosahedronGeometry(0.35, 0), new THREE.MeshBasicMaterial({ color: 0xbfe6ff }));
    const shell = new THREE.Mesh(new THREE.IcosahedronGeometry(0.55, 0), new THREE.MeshBasicMaterial({ color: 0x4aa8ff, wireframe: true }));
    g.add(core, shell);
    const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.T.glow, color: 0x60b0ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    glow.scale.setScalar(2.5);
    g.add(glow);
    g.position.set(x, y, z);
    this.scene.add(g);
    const s = { group: g, core, shell, pos: new THREE.Vector3(x, y, z), taken: false, baseY: y };
    this.secrets.push(s);
    this.lamps.push({ pos: new THREE.Vector3(x, y, z), color: 0x4aa8ff, power: 0.6, secret: s });
    return s;
  }

  // Mangal: kaide + alev + ışık çapası
  brazier(x, y, z) {
    this.box(x - 0.45, y, z - 0.45, x + 0.45, y + 1.1, z + 0.45, 'metal', { solid: true });
    this.box(x - 0.6, y + 1.1, z - 0.6, x + 0.6, y + 1.35, z + 0.6, 'dark', { solid: true });
    this.fire(x, y + 1.35, z, 1.4);
    this.lamps.push({ pos: new THREE.Vector3(x, y + 2.2, z), color: 0xff7a30, power: 1 });
  }

  // Duvar meşalesi
  torch(x, y, z) {
    this.box(x - 0.15, y - 0.4, z - 0.15, x + 0.15, y, z + 0.15, 'metal', { solid: false });
    this.fire(x, y, z, 0.8);
    this.lamps.push({ pos: new THREE.Vector3(x, y + 0.5, z), color: 0xff8a40, power: 0.8 });
  }

  fire(x, y, z, size) {
    const mat = new THREE.SpriteMaterial({ map: this.T.glow, color: 0xff7020, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
    const s1 = new THREE.Sprite(mat);
    s1.position.set(x, y + size * 0.4, z);
    s1.scale.set(size, size * 1.4, 1);
    const s2 = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.T.glow, color: 0xffd060, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    s2.position.set(x, y + size * 0.25, z);
    s2.scale.set(size * 0.5, size * 0.8, 1);
    this.scene.add(s1, s2);
    this.fires.push({ s1, s2, size, phase: rand(0, 10), y });
  }

  chain(x, yTop, z, len) {
    for (let i = 0; i < len; i += 0.35) {
      const alt = Math.floor(i / 0.35) % 2 === 0;
      this.box(x - (alt ? 0.06 : 0.12), yTop - i - 0.3, z - (alt ? 0.12 : 0.06), x + (alt ? 0.06 : 0.12), yTop - i, z + (alt ? 0.12 : 0.06), 'metal', { solid: false, texScale: 1 });
    }
  }

  skulls(x, y, z, n = 5) {
    for (let i = 0; i < n; i++) {
      const sx = x + rand(-0.8, 0.8), sz = z + rand(-0.8, 0.8), sy = y + (i > 3 ? 0.35 : 0);
      this.box(sx - 0.18, sy, sz - 0.2, sx + 0.18, sy + 0.32, sz + 0.2, 'bone', { solid: false, texScale: 1 });
      this.box(sx - 0.1, sy + 0.08, sz - 0.21, sx - 0.02, sy + 0.18, sz - 0.19, 'dark', { solid: false, texScale: 1 });
      this.box(sx + 0.02, sy + 0.08, sz - 0.21, sx + 0.1, sy + 0.18, sz - 0.19, 'dark', { solid: false, texScale: 1 });
    }
  }

  sigil(x, y, z, size) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(size, size), new THREE.MeshBasicMaterial({ map: this.T.sigil, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, color: 0xff5030 }));
    m.rotation.x = -Math.PI / 2;
    m.position.set(x, y + 0.03, z);
    this.scene.add(m);
    this.animated.push((t) => { m.material.opacity = 0.55 + Math.sin(t * 2) * 0.2; m.rotation.z = t * 0.05; });
  }

  lavaPlane(x0, z0, x1, z1, y) {
    const w = x1 - x0, d = z1 - z0;
    const geo = new THREE.PlaneGeometry(w, d, Math.max(1, Math.floor(w / 2)), Math.max(1, Math.floor(d / 2)));
    const uv = geo.attributes.uv;
    for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * w / 6, uv.getY(i) * d / 6);
    const m = new THREE.Mesh(geo, this.mats.lava);
    m.rotation.x = -Math.PI / 2;
    m.position.set((x0 + x1) / 2, y, (z0 + z1) / 2);
    this.scene.add(m);
    this.lamps.push({ pos: new THREE.Vector3((x0 + x1) / 2, y + 2, (z0 + z1) / 2), color: 0xff5010, power: 1.4 });
    return m;
  }

  // Kıyma makinesi öğütücüsü: çukurda dönen dişli silindir (görsel; hasar için ayrıca hurt())
  grinder(x, y, z, len, axis = 'x', r = 0.9) {
    const g = new THREE.Group();
    const body = new THREE.Mesh(new THREE.CylinderGeometry(r, r, len, 10), this.mats.metal);
    g.add(body);
    for (let k = 0; k < Math.floor(len / 0.7); k++) {
      for (let j = 0; j < 6; j++) {
        const a = (j / 6) * Math.PI * 2 + k * 0.5;
        const tooth = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.5, 4), this.mats.bone);
        tooth.position.set(Math.cos(a) * (r + 0.2), -len / 2 + 0.35 + k * 0.7, Math.sin(a) * (r + 0.2));
        tooth.rotation.z = -Math.PI / 2;
        tooth.rotation.y = -a;
        g.add(tooth);
      }
    }
    if (axis === 'x') g.rotation.z = Math.PI / 2; else g.rotation.x = Math.PI / 2;
    const spin = new THREE.Group();
    spin.add(g);
    spin.position.set(x, y, z);
    this.scene.add(spin);
    const dir = this.grinders = (this.grinders || 0) + 1;
    this.animated.push((t) => { if (axis === 'x') spin.rotation.x = t * (dir % 2 ? 3 : -3); else spin.rotation.z = t * (dir % 2 ? 3 : -3); });
    return spin;
  }

  // Asılı et parçası (zincir + gövde)
  meatHook(x, yTop, z, len = 3) {
    this.chain(x, yTop, z, len);
    this.box(x - 0.35, yTop - len - 1.6, z - 0.25, x + 0.35, yTop - len, z + 0.25, 'meat', { solid: false, texScale: 1.5 });
    this.box(x - 0.08, yTop - len - 0.1, z - 0.08, x + 0.08, yTop - len + 0.2, z + 0.08, 'metal', { solid: false, texScale: 1 });
  }

  // Heykel (dekor): kaide + gövde
  statue(x, y, z, s = 1, mat = 'marble') {
    this.box(x - 0.9 * s, y, z - 0.9 * s, x + 0.9 * s, y + 0.8 * s, z + 0.9 * s, 'dark');
    this.box(x - 0.35 * s, y + 0.8 * s, z - 0.25 * s, x + 0.35 * s, y + 2.4 * s, z + 0.25 * s, mat, { texScale: 2 });
    this.box(x - 0.55 * s, y + 2.4 * s, z - 0.3 * s, x + 0.55 * s, y + 3.1 * s, z + 0.3 * s, mat, { texScale: 2 });
    this.box(x - 0.2 * s, y + 3.1 * s, z - 0.2 * s, x + 0.2 * s, y + 3.6 * s, z + 0.2 * s, mat, { texScale: 2 });
  }

  // Çıkış deliği: zeminde açılan kapak + aşağıda lav; düşünce bölüm biter
  exitHatch(id, x0, z0, x1, z1, y = 0) {
    this.door(id, x0, y - 2, z0, x1, y, z1, { open: false, dir: 'down', travel: 26, mat: 'metal' });
    this.box(x0 - 1, y - 32, z0 - 1, x0, y - 2, z1 + 1, 'rock');
    this.box(x1, y - 32, z0 - 1, x1 + 1, y - 2, z1 + 1, 'rock');
    this.box(x0, y - 32, z0 - 1, x1, y - 2, z0, 'rock');
    this.box(x0, y - 32, z1, x1, y - 2, z1 + 1, 'rock');
    this.box(x0, y - 34, z0, x1, y - 32, z1, 'rock');
    this.lavaPlane(x0, z0, x1, z1, y - 31.5);
    this.trigger([x0, y - 24, z0, x1, y - 4, z1], () => this.game.levelComplete());
  }

  spire(x, z, h, w) {
    this.box(x - w, -30, z - w, x + w, h, z + w, 'rock', { solid: false, texScale: 8 });
    this.box(x - w * 0.6, h, z - w * 0.6, x + w * 0.6, h + w * 3, z + w * 0.6, 'rock', { solid: false, texScale: 8 });
  }

  // Dükkân terminali: yeşil ekranlı dikili taş. yaw: ekranın baktığı yön (0 → +z)
  shop(x, y, z, yaw = 0) {
    const g = new THREE.Group();
    g.position.set(x, y, z);
    g.rotation.y = yaw;
    const body = new THREE.Mesh(new THREE.BoxGeometry(1.7, 2.9, 0.7), this.mats.metal);
    body.position.y = 1.45;
    const cap = new THREE.Mesh(new THREE.BoxGeometry(1.95, 0.25, 0.9), this.mats.dark);
    cap.position.y = 3.0;
    const base = new THREE.Mesh(new THREE.BoxGeometry(2.1, 0.3, 1.1), this.mats.dark);
    base.position.y = 0.15;
    const cv = document.createElement('canvas');
    cv.width = 128; cv.height = 160;
    const c = cv.getContext('2d');
    c.fillStyle = '#021a08'; c.fillRect(0, 0, 128, 160);
    c.fillStyle = '#39ff6a'; c.textAlign = 'center';
    c.font = 'bold 22px monospace'; c.fillText('DÜKKÂN', 64, 40);
    c.font = '14px monospace'; c.fillText('SİLAH · VARYANT', 64, 66); c.fillText('KOL · KANCA', 64, 86);
    c.fillText('— P İLE ÖDE —', 64, 112);
    c.font = 'bold 16px monospace'; c.fillText('[B] / DOKUN', 64, 142);
    for (let yy = 0; yy < 160; yy += 3) { c.fillStyle = 'rgba(0,0,0,0.25)'; c.fillRect(0, yy, 128, 1); }
    const tex = new THREE.CanvasTexture(cv);
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.magFilter = THREE.NearestFilter;
    const screen = new THREE.Mesh(new THREE.PlaneGeometry(1.3, 1.62), new THREE.MeshBasicMaterial({ map: tex }));
    screen.position.set(0, 1.75, 0.36);
    const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.T.glow, color: 0x39ff6a, transparent: true, opacity: 0.35, blending: THREE.AdditiveBlending, depthWrite: false }));
    glow.position.set(0, 1.75, 0.6);
    glow.scale.set(2.4, 2.6, 1);
    g.add(body, cap, base, screen, glow);
    this.scene.add(g);
    // çarpışma: dönüşe göre eksen hizalı kutu
    const along = Math.abs(Math.sin(yaw)) > 0.5;
    const hw = along ? 0.35 : 0.85, hd = along ? 0.85 : 0.35;
    this.world.add(x - hw, y, z - hd, x + hw, y + 3.1, z + hd, 'static');
    const front = new THREE.Vector3(x + Math.sin(yaw) * 1.3, y, z + Math.cos(yaw) * 1.3);
    const sh = { pos: front, group: g, screen: tex, glow };
    this.shops.push(sh);
    this.lamps.push({ pos: new THREE.Vector3(x + Math.sin(yaw) * 1.2, y + 2.2, z + Math.cos(yaw) * 1.2), color: 0x39ff6a, power: 0.9 });
    this.animated.push((t) => { glow.material.opacity = 0.3 + Math.sin(t * 3) * 0.08; });
    return sh;
  }

  // Silah sunağı: kaide + dönen silah modeli + ışık
  // weapon: silah numarası (0-4) ya da 'knuckle' / 'hook'
  // onTake: yalnız ilk alışta, onGive: her alışta hemen çağrılır
  altar(x, y, z, weapon, onTake, onGive = null) {
    this.box(x - 0.8, y, z - 0.8, x + 0.8, y + 0.9, z + 0.8, 'metal');
    this.box(x - 1.0, y + 0.9, z - 1.0, x + 1.0, y + 1.1, z + 1.0, 'dark');
    const COLORS = { 0: 0x3aa0ff, 1: 0xff8a30, 2: 0x9adf5a, 3: 0x3aeaff, 4: 0xff3a2a, knuckle: 0xff5030, hook: 0x9adf5a };
    const colors = COLORS;
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.9, 0.05, 6, 24), new THREE.MeshBasicMaterial({ color: colors[weapon] }));
    ring.rotation.x = Math.PI / 2;
    ring.position.set(x, y + 1.15, z);
    this.scene.add(ring);
    const holder = new THREE.Group();
    holder.position.set(x, y + 2.0, z);
    this.scene.add(holder);
    const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.T.glow, color: colors[weapon], transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    glow.scale.setScalar(3);
    holder.add(glow);
    const pk = { weapon, pos: new THREE.Vector3(x, y + 1.6, z), holder, ring, glow, taken: false, onTake, onGive, baseY: y + 2.0 };
    this.pickups.push(pk);
    this.lamps.push({ pos: new THREE.Vector3(x, y + 2.8, z), color: colors[weapon], power: 1.1, pickup: pk });
    return pk;
  }

  finalize() {
    for (const [mat, geos] of this.buckets) {
      const merged = mergeGeometries(geos, false);
      const mesh = new THREE.Mesh(merged, this.mats[mat]);
      mesh.matrixAutoUpdate = false;
      this.scene.add(mesh);
      for (const g of geos) g.dispose();
    }
    this.buckets.clear();
    this.buildSky();
  }

  buildSky() {
    const geo = new THREE.SphereGeometry(500, 32, 16);
    const mat = new THREE.ShaderMaterial({
      side: THREE.BackSide,
      depthWrite: false,
      fog: false,
      uniforms: {
        uTime: { value: 0 },
        uTop: { value: new THREE.Vector3(...this.theme.skyTop) },
        uHor: { value: new THREE.Vector3(...this.theme.skyHor) },
        uCloud: { value: new THREE.Vector3(...this.theme.skyCloud) },
        uGlow: { value: new THREE.Vector3(...this.theme.skyGlow) },
      },
      vertexShader: `varying vec3 vDir; void main(){ vDir = normalize(position); vec4 p = projectionMatrix * modelViewMatrix * vec4(position,1.0); gl_Position = p.xyww; }`,
      fragmentShader: `varying vec3 vDir; uniform float uTime; uniform vec3 uTop, uHor, uCloud, uGlow;
        float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
        float n(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(h(i),h(i+vec2(1,0)),f.x), mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x), f.y); }
        void main(){
          float y = vDir.y;
          vec3 c = mix(uHor, uTop, smoothstep(-0.05, 0.55, y));
          float a = atan(vDir.z, vDir.x);
          float cl = n(vec2(a * 6.0 + uTime * 0.02, y * 10.0)) * n(vec2(a * 13.0 - uTime * 0.03, y * 22.0));
          c += uCloud * cl * smoothstep(0.5, 0.0, abs(y - 0.12));
          c += uGlow * pow(max(0.0, 1.0 - abs(y + 0.02) * 6.0), 3.0);
          gl_FragColor = vec4(c, 1.0);
        }`,
    });
    this.sky = new THREE.Mesh(geo, mat);
    this.sky.renderOrder = -1;
    this.sky.frustumCulled = false;
    this.scene.add(this.sky);
  }

  update(dt, t, camPos) {
    for (const id in this.doors) this.doors[id].update(dt);
    for (const f of this.fires) {
      const k = 0.85 + Math.sin(t * 13 + f.phase) * 0.08 + Math.sin(t * 29 + f.phase * 2) * 0.07;
      f.s1.scale.set(f.size * k, f.size * 1.4 * (2 - k), 1);
      f.s1.position.y = f.y + f.size * 0.4 + Math.sin(t * 7 + f.phase) * 0.04;
      f.s2.scale.set(f.size * 0.5 * k, f.size * 0.8 * k, 1);
    }
    for (const s of this.secrets) {
      if (s.taken) continue;
      s.group.position.y = s.baseY + Math.sin(t * 2) * 0.15;
      s.core.rotation.y += dt * 1.5;
      s.shell.rotation.y -= dt * 0.8;
      s.shell.rotation.x += dt * 0.5;
    }
    for (const pk of this.pickups) {
      if (pk.taken) continue;
      pk.holder.position.y = pk.baseY + Math.sin(t * 2) * 0.12;
      pk.holder.rotation.y = t * 1.3;
      pk.ring.rotation.z = t * 0.6;
    }
    for (const fn of this.animated) fn(t);
    this.lavaTex.offset.set(t * 0.03, t * 0.02);
    if (this.sky) {
      this.sky.material.uniforms.uTime.value = t;
      this.sky.position.copy(camPos);
    }
  }

  resetTriggers() {
    for (const t of this.triggers) t.fired = false;
  }
}
