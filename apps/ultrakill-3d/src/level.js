// Bölüm 0-1 "İLK KAN": geometri, kapılar, tetikleyiciler, arenalar, checkpoint'ler,
// gizli küreler ve ipuçları.
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
    this.t = this.target = this.initialOpen ? 1 : 0;
    this.apply();
  }
}

export class Level {
  constructor(game) {
    this.game = game;
    this.scene = game.scene;
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
    this.killY = -40;
    this.totalEnemies = 0;
    this.lavaTex = T.lava;
  }

  box(x0, y0, z0, x1, y1, z1, mat = 'stone', { solid = true, visible = true, texScale = 4 } = {}) {
    if (solid) this.world.add(x0, y0, z0, x1, y1, z1, 'static');
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

  spire(x, z, h, w) {
    this.box(x - w, -30, z - w, x + w, h, z + w, 'rock', { solid: false, texScale: 8 });
    this.box(x - w * 0.6, h, z - w * 0.6, x + w * 0.6, h + w * 3, z + w * 0.6, 'rock', { solid: false, texScale: 8 });
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
      uniforms: { uTime: { value: 0 } },
      vertexShader: `varying vec3 vDir; void main(){ vDir = normalize(position); vec4 p = projectionMatrix * modelViewMatrix * vec4(position,1.0); gl_Position = p.xyww; }`,
      fragmentShader: `varying vec3 vDir; uniform float uTime;
        float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
        float n(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(h(i),h(i+vec2(1,0)),f.x), mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x), f.y); }
        void main(){
          float y = vDir.y;
          vec3 top = vec3(0.02, 0.0, 0.0);
          vec3 hor = vec3(0.30, 0.05, 0.02);
          vec3 c = mix(hor, top, smoothstep(-0.05, 0.55, y));
          float a = atan(vDir.z, vDir.x);
          float cl = n(vec2(a * 6.0 + uTime * 0.02, y * 10.0)) * n(vec2(a * 13.0 - uTime * 0.03, y * 22.0));
          c += vec3(0.25, 0.05, 0.01) * cl * smoothstep(0.5, 0.0, abs(y - 0.12));
          c += vec3(0.4, 0.08, 0.0) * pow(max(0.0, 1.0 - abs(y + 0.02) * 6.0), 3.0);
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

// ---------------------------------------------------------------------------
// 0-1 düzeni
// ---------------------------------------------------------------------------
export function buildLevel01(L) {
  // ===== ARENA 1: Düşüş odası (x -16..16, z -16..16) =====
  L.box(-17, -2, -17, 17, 0, 17, 'tiles');
  L.box(-17, 0, 16, 17, 14, 17, 'stone');
  L.box(16, 0, -17, 17, 14, 17, 'stone');
  L.box(-17, 0, -17, -16, 14, 17, 'stone');
  L.box(-17, 0, -17, -3, 14, -16, 'stone');
  L.box(3, 0, -17, 17, 14, -16, 'stone');
  L.box(-3, 6, -17, 3, 14, -16, 'stone');
  L.door('d1', -3, 0, -16.8, 3, 6, -16.2, { open: false });
  // güney çıkıntı ve merdiven
  L.box(-16, 0, 11, 16, 3, 16, 'stone');
  L.stairsZ(-2, 2, 7.4, 11, 0, 3, 6, 'metal');
  // sütunlar
  for (const [x, z] of [[-9, -9], [9, -9], [-9, 3], [9, 3]]) {
    L.box(x - 1, 0, z - 1, x + 1, 9, z + 1, 'stone');
    L.box(x - 1.3, 9, z - 1.3, x + 1.3, 9.4, z + 1.3, 'metal');
    L.box(x - 1.3, 0, z - 1.3, x + 1.3, 0.4, z + 1.3, 'metal');
  }
  L.box(-5, 0, -3, -2, 1.2, -1.5, 'metal');
  L.box(2, 0, 1, 5, 1.2, 2.5, 'metal');
  L.brazier(-14, 0, -14);
  L.brazier(14, 0, -14);
  L.brazier(-14, 3, 14);
  L.brazier(14, 3, 14);
  L.sigil(0, 0, -2, 12);
  L.chain(-15.8, 13, -6, 5);
  L.chain(15.8, 13, -2, 6);
  L.chain(-15.8, 13, 6, 4);
  L.skulls(-13, 0, 8, 6);
  L.skulls(12, 0, -2, 4);

  L.arena({
    id: 'a1',
    name: 'ARENA 1',
    trigger: [-16, 0, -16, 16, 2.5, 11],
    lock: [],
    exits: ['d1'],
    waves: [
      [{ t: 'filth', p: [-8, 0, -13] }, { t: 'filth', p: [8, 0, -13] }, { t: 'filth', p: [0, 0, -14] }],
      [{ t: 'filth', p: [-13, 0, 0] }, { t: 'filth', p: [13, 0, 0] }, { t: 'filth', p: [-6, 0, -13] }, { t: 'filth', p: [6, 0, -13] }, { t: 'stray', p: [0, 3, 13.5] }],
    ],
    onStart: (g) => g.hud.hint('[SOL TIK] ateş · [SAĞ TIK] alternatif ateş · [1][2][3] silah seç (tekrar bas: varyant) · [F] yumruk', 8),
  });

  // ===== KORİDOR 1 (x -3..3, z -40..-17) =====
  L.box(-4, -16, -24, 4, 0, -17, 'tiles');
  L.box(-4, -16, -41, 4, 0, -30, 'tiles');
  L.box(-4, -16, -30, -3, 0, -24, 'rock');
  L.box(3, -16, -30, 4, 0, -24, 'rock');
  L.box(-3, -18, -30, 3, -14, -24, 'rock');
  L.lavaPlane(-3, -30, 3, -24, -13.5);
  L.hurt([-3, -16, -30, 3, -12, -24], 30, 'pit');
  // duvarlar (batı duvarında gizli oda açıklığı)
  L.box(-4, 0, -34, -3, 7, -17, 'stone');
  L.box(-4, 0, -41, -3, 7, -37, 'stone');
  L.box(-4, 0, -37, -3, 3.5, -34, 'stone');
  L.box(3, 0, -41, 4, 7, -17, 'stone');
  L.box(-4, 7, -41, 4, 8, -17, 'rock');
  L.torch(-2.75, 4.5, -20);
  L.torch(2.75, 4.5, -36);
  // Gizli oda 1 (duvar sıçramasıyla)
  L.box(-10, 1.5, -39, -3.9, 3.5, -32, 'stone');
  L.box(-10, 7, -39, -3.9, 8, -32, 'stone');
  L.box(-10, 3.5, -39, -9, 7, -32, 'stone');
  L.box(-9, 3.5, -39, -3.9, 7, -38, 'stone');
  L.box(-9, 3.5, -33, -3.9, 7, -32, 'stone');
  L.skulls(-8, 3.5, -36.8, 3);
  L.secret(-6.8, 4.7, -35.5);

  L.hint([-3, 0, -21, 3, 5, -18], 'Boşluğu geç: koşarak zıpla ya da ATILIRKEN ZIPLA [SHIFT → BOŞLUK] ile uzağa fırla.', 7);
  L.hint([-3, 0, -33, 3, 5, -31], 'Havadayken duvara doğru [BOŞLUK]: DUVAR SIÇRAMASI (yere değmeden 3 kez).', 7);
  L.checkpoint([-3, 0, -39.5, 3, 4, -36.5], [0, 0, -38], 0);

  // ===== ARENA 2: Sütunlu salon (x -20..20, z -80..-41) =====
  L.box(-21, -2, -81, 21, 0, -40, 'tiles');
  L.box(-21, 0, -81, -20, 14, -40, 'stone');
  L.box(20, 0, -81, 21, 14, -40, 'stone');
  L.box(-21, 0, -41, -3, 14, -40, 'stone');
  L.box(3, 0, -41, 21, 14, -40, 'stone');
  L.box(-3, 6, -41, 3, 14, -40, 'stone');
  L.door('d2in', -3, 0, -40.8, 3, 6, -40.2, { open: true });
  L.box(-21, 0, -81, -3, 14, -80, 'stone');
  L.box(3, 0, -81, 21, 14, -80, 'stone');
  L.box(-3, 6, -81, 3, 14, -80, 'stone');
  L.door('d2out', -3, 0, -80.8, 3, 6, -80.2, { open: false });
  // balkonlar
  L.box(-20, 0, -75, -13, 4, -46, 'stone');
  L.box(13, 0, -75, 20, 4, -46, 'stone');
  L.box(-13.4, 4, -75, -13, 5, -54, 'metal');
  L.box(13, 4, -64, 13.4, 5, -46, 'metal');
  L.stairsX(-52, -48, -9, -13, 0, 4, 8, 'metal');
  L.stairsX(-70, -66, 9, 13, 0, 4, 8, 'metal');
  // orta platform
  L.box(-5, 0, -64, 5, 2, -56, 'metal');
  L.sigil(0, 2, -60, 7);
  for (const [x, z] of [[-6, -50], [6, -50], [-6, -72], [6, -72]]) {
    L.box(x - 1, 0, z - 1, x + 1, 10, z + 1, 'stone');
    L.box(x - 1.3, 10, z - 1.3, x + 1.3, 10.4, z + 1.3, 'metal');
  }
  L.brazier(-17, 0, -78);
  L.brazier(17, 0, -78);
  L.brazier(-16.5, 4, -47.5);
  L.brazier(16.5, 4, -73.5);
  L.chain(-19.8, 13, -60, 7);
  L.chain(19.8, 13, -56, 5);
  L.skulls(-17, 4, -70, 4);
  L.skulls(16, 4, -52, 5);

  L.arena({
    id: 'a2',
    name: 'ARENA 2',
    trigger: [-20, 0, -45, 20, 6, -42],
    lock: ['d2in'],
    exits: ['d2out'],
    waves: [
      [{ t: 'stray', p: [-16.5, 4, -60] }, { t: 'stray', p: [16.5, 4, -58] }, { t: 'filth', p: [0, 0, -70] }, { t: 'filth', p: [-6, 0, -77] }, { t: 'filth', p: [6, 0, -77] }],
      [{ t: 'stray', p: [-16.5, 4, -70] }, { t: 'stray', p: [16.5, 4, -50] }, { t: 'stray', p: [0, 2, -60] }, { t: 'filth', p: [-12, 0, -78] }, { t: 'filth', p: [12, 0, -78] }, { t: 'filth', p: [0, 0, -77] }, { t: 'filth', p: [9, 0, -64] }],
    ],
    onStart: (g) => g.hud.hint('[F] YUMRUK: Turuncu küreyi ya da PARLAYAN saldırıyı tam zamanında yumrukla → PARRY! Canını tamamen doldurur.', 9),
  });

  // ===== KORİDOR 2 (x -3..3, z -100..-81) =====
  L.box(-4, -2, -100, 4, 0, -80, 'tiles');
  L.box(-4, 6, -100, 4, 7, -80, 'metal');
  L.box(-4, 0, -100, -3, 6, -80, 'stone');
  L.box(3, 0, -85, 4, 6, -80, 'stone');
  L.box(3, 0, -100, 4, 6, -87, 'stone');
  L.box(3, 1.0, -87, 4, 6, -85, 'stone');
  // kayarak geçilen engel
  L.box(-3, 1.1, -92, 3, 6, -90, 'metal');
  L.box(-3, 1.1, -92.2, 3, 1.4, -89.8, 'door', { solid: false, texScale: 6 });
  // Gizli oda 2 (kayarak girilen havalandırma)
  L.box(4, -2, -89, 11, 0, -83, 'tiles');
  L.box(4, 0, -88, 6, 1, -87, 'metal');
  L.box(4, 0, -85, 6, 1, -84, 'metal');
  L.box(4, 1, -88, 6, 5, -84, 'metal');
  L.box(6, 0, -89, 11, 5, -88, 'stone');
  L.box(6, 0, -84, 11, 5, -83, 'stone');
  L.box(10, 0, -88, 11, 5, -84, 'stone');
  L.box(6, 5, -88, 10, 6, -84, 'stone');
  L.secret(8.5, 1.3, -86);
  L.torch(-2.75, 4, -84);
  L.torch(-2.75, 4, -96);
  L.hint([-3, 0, -84, 3, 5, -82], 'Yerdeyken [C]: KAY — alçak engellerin altından geç. Havadayken [C]: YERE ÇAK; çakıştan hemen sonra [BOŞLUK] = YÜKSEK SIÇRAYIŞ.', 9);
  L.checkpoint([-3, 0, -99, 3, 4, -96], [0, 0, -97.5], 0);
  L.extraEnemies.push({ trigger: [-3, 0, -89, 3, 4, -87.5], list: [{ t: 'filth', p: [-1.5, 0, -97] }, { t: 'filth', p: [1.5, 0, -98] }] });

  // ===== ARENA 3: Lav havuzu (x -26..26, z -150..-101) =====
  L.box(-27, -2, -116, 27, 0, -100, 'tiles');
  L.box(-27, -2, -151, 27, 0, -134, 'tiles');
  L.box(-27, -2, -134, -10, 0, -116, 'tiles');
  L.box(10, -2, -134, 27, 0, -116, 'tiles');
  L.box(-10, -3, -134, 10, -1.5, -116, 'rock');
  L.lavaPlane(-10, -134, 10, -116, -1.0);
  L.hurt([-10, -1.6, -134, 10, -0.8, -116], 22, 'lava');
  L.box(-2.5, -1.5, -127.5, 2.5, 1, -122.5, 'stone');
  L.box(-27, 0, -151, -26, 16, -100, 'flesh');
  L.box(26, 0, -151, 27, 16, -100, 'flesh');
  L.box(-27, 0, -101, -3, 16, -100, 'flesh');
  L.box(3, 0, -101, 27, 16, -100, 'flesh');
  L.box(-3, 6, -101, 3, 16, -100, 'stone');
  L.door('d3in', -3, 0, -100.8, 3, 6, -100.2, { open: true });
  L.box(-27, 0, -151, -3, 16, -150, 'flesh');
  L.box(3, 0, -151, 27, 16, -150, 'flesh');
  L.box(-3, 6, -151, 3, 16, -150, 'stone');
  L.door('d3out', -3, 0, -150.8, 3, 6, -150.2, { open: false });
  // batı balkonu + merdiven
  L.box(-26, 0, -140, -20, 5, -110, 'stone');
  L.stairsX(-126, -122, -15, -20, 0, 5, 10, 'metal');
  // kuzeydoğu balkonu + parkur sütunları (gizli 3)
  L.box(20, 0, -150, 26, 5, -142, 'stone');
  L.stairsX(-150, -147, 15.5, 20, 0, 5, 10, 'metal');
  L.box(15.5, 0, -145.5, 17, 6.5, -144, 'stone');
  L.box(12, 0, -141.5, 13.5, 8, -140, 'stone');
  L.box(15, 0, -137.5, 16.5, 9.5, -136, 'stone');
  L.secret(15.75, 10.5, -136.75);
  for (const [x, z] of [[-13, -113], [13, -113], [-13, -137], [13, -137]]) {
    L.box(x - 1, 0, z - 1, x + 1, 12, z + 1, 'stone');
    L.box(x - 1.3, 12, z - 1.3, x + 1.3, 12.4, z + 1.3, 'metal');
  }
  L.brazier(-23, 5, -112);
  L.brazier(23, 5, -148);
  L.brazier(-24, 0, -103);
  L.brazier(24, 0, -103);
  L.brazier(-24, 0, -148);
  L.chain(-25.8, 15, -125, 8);
  L.chain(25.8, 15, -120, 9);
  L.chain(25.8, 15, -130, 6);
  L.skulls(-6, 1, -125, 2);
  L.skulls(22, 0, -106, 6);

  L.arena({
    id: 'a3',
    name: 'ARENA 3',
    trigger: [-26, 0, -106, 26, 8, -103],
    lock: ['d3in'],
    exits: ['d3out'],
    waves: [
      [{ t: 'schism', p: [0, 0, -142] }, { t: 'filth', p: [-18, 0, -146] }, { t: 'filth', p: [18, 0, -120] }, { t: 'filth', p: [-15, 0, -120] }],
      [{ t: 'schism', p: [-18, 0, -146] }, { t: 'stray', p: [-23, 5, -130] }, { t: 'stray', p: [-23, 5, -118] }, { t: 'filth', p: [15, 0, -120] }, { t: 'filth', p: [0, 0, -145] }, { t: 'filth', p: [18, 0, -110] }],
      [{ t: 'schism', p: [-12, 0, -146] }, { t: 'schism', p: [9, 0, -146] }, { t: 'stray', p: [23, 5, -146] }, { t: 'stray', p: [-23, 5, -125] }, { t: 'filth', p: [-8, 0, -110] }, { t: 'filth', p: [8, 0, -110] }],
    ],
    onStart: (g) => g.hud.hint('Düşmanlara YAKIN dövüş: saçılan KAN seni iyileştirir. Lav havuzuna dikkat!', 8),
  });

  // ===== KORİDOR 3 (x -3..3, z -170..-151) =====
  L.box(-4, -2, -171, 4, 0, -150, 'tiles');
  L.box(-4, 7, -170, 4, 8, -151, 'rock');
  L.box(-4, 0, -170, -3, 7, -151, 'stone');
  L.box(3, 0, -170, 4, 7, -151, 'stone');
  L.torch(-2.75, 4.5, -160);
  L.torch(2.75, 4.5, -160);
  L.skulls(-2, 0, -156, 4);
  L.hint([-3, 0, -156, 3, 5, -153], 'STİL: çeşitli oyna! Aynı silahı sürekli kullanırsan TAZELİK düşer ve daha az puan alırsın.', 8);
  L.checkpoint([-3, 0, -168, 3, 4, -164], [0, 0, -166], 0);

  // ===== BOSS ARENASI (x -22..22, z -215..-171) =====
  L.box(-23, 0, -171, -3, 18, -170, 'stone');
  L.box(3, 0, -171, 23, 18, -170, 'stone');
  L.box(-3, 6, -171, 3, 18, -170, 'stone');
  L.door('d4in', -3, 0, -170.8, 3, 6, -170.2, { open: true });
  L.box(-23, 0, -216, -22, 18, -170, 'metal');
  L.box(22, 0, -216, 23, 18, -170, 'metal');
  L.box(-23, 0, -216, 23, 18, -215, 'metal');
  for (const sx of [-1, 1]) {
    L.box(sx * 22, 0, -215, sx * 17, 18, -211, 'stone');
    L.box(sx * 22, 0, -211, sx * 19.5, 18, -208, 'stone');
    L.box(sx * 22, 0, -175, sx * 17, 18, -171, 'stone');
    L.box(sx * 22, 0, -178, sx * 19.5, 18, -175, 'stone');
  }
  L.box(-23, -2, -216, 23, 0, -196, 'tiles');
  L.box(-23, -2, -190, 23, 0, -170, 'tiles');
  L.box(-23, -2, -196, -3, 0, -190, 'tiles');
  L.box(3, -2, -196, 23, 0, -190, 'tiles');
  L.door('hatch', -3, -2, -196, 3, 0, -190, { open: false, dir: 'down', travel: 26, mat: 'metal' });
  L.box(-4, -32, -197, -3, -2, -189, 'rock');
  L.box(3, -32, -197, 4, -2, -189, 'rock');
  L.box(-3, -32, -197, 3, -2, -196, 'rock');
  L.box(-3, -32, -190, 3, -2, -189, 'rock');
  L.box(-3, -34, -196, 3, -32, -190, 'rock');
  L.lavaPlane(-3, -196, 3, -190, -31.5);
  for (const [x0, z0] of [[-12, -182], [9, -182], [-12, -205], [9, -205]]) L.box(x0, 0, z0, x0 + 3, 1.5, z0 + 3, 'metal');
  for (const x of [-16, 16]) {
    L.box(x - 1, 0, -194, x + 1, 10, -192, 'stone');
    L.box(x - 1.3, 10, -194.3, x + 1.3, 10.4, -191.7, 'metal');
  }
  L.brazier(-17, 0, -205);
  L.brazier(17, 0, -205);
  L.brazier(-17, 0, -181);
  L.brazier(17, 0, -181);
  L.sigil(0, 0, -206, 11);
  L.chain(-21.8, 17, -185, 10);
  L.chain(21.8, 17, -200, 9);
  L.chain(-21.8, 17, -200, 7);
  L.skulls(-19, 0, -190, 6);
  L.skulls(19, 0, -196, 6);

  L.arena({
    id: 'boss',
    name: 'SWORDSMACHINE',
    trigger: [-22, 0, -177, 22, 8, -173],
    lock: ['d4in'],
    exits: [],
    boss: true,
    waves: [[{ t: 'swordsmachine', p: [0, 0, -205] }]],
    onClear: (g) => g.onBossDefeated(),
  });
  L.trigger([-3, -24, -196, 3, -4, -190], () => L.game.levelComplete());

  // Uzak manzara: dev kayalık kuleler
  const spires = [[-70, 10, 70, 6], [65, -20, 55, 5], [-80, -70, 90, 8], [75, -95, 60, 6], [-65, -140, 75, 5], [80, -170, 95, 9], [-85, -210, 65, 7], [40, -270, 80, 8], [-30, -280, 60, 6], [0, 80, 70, 7], [55, 60, 45, 5]];
  for (const [x, z, h, w] of spires) L.spire(x, z, h, w);

  L.finalize();
}
