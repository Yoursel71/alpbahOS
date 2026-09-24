// Düşmanlar: Filth, Stray, Schism, Malicious Face, boss Swordsmachine, boss Cerberus ve parry eğitmeni.
// Modeller eklem hiyerarşisiyle kutu/koni/silindirlerden kurulur; animasyonlar prosedüreldir.
// Ölümde: patlayıcı/ağır hasar → parçalanma, kafadan öldürme → kafa kopar + kan fıskiyesi,
// diğerleri → ceset olarak yığılır.
import * as THREE from 'three';
import { psx } from './render.js';
import { clamp, rand, chance, wrapAngle, yawTo } from './util.js';
import { difficulty } from './settings.js';
import { Projectile } from './projectiles.js';

const G = 35;
const FRESH_W = new Set(['revolver', 'shotgun', 'nailgun', 'rail', 'rocket']);
const _v1 = new THREE.Vector3();
const _v2 = new THREE.Vector3();
const _v3 = new THREE.Vector3();
const _d = new THREE.Vector3();

const GEO = new Map();
function bgeo(w, h, d) {
  const k = `${w.toFixed(3)},${h.toFixed(3)},${d.toFixed(3)}`;
  let g = GEO.get(k);
  if (!g) { g = new THREE.BoxGeometry(w, h, d); GEO.set(k, g); }
  return g;
}
function cgeo(r, h, seg = 5) {
  const k = `c${r.toFixed(3)},${h.toFixed(3)},${seg}`;
  let g = GEO.get(k);
  if (!g) { g = new THREE.ConeGeometry(r, h, seg); GEO.set(k, g); }
  return g;
}

function joint(parent, x, y, z) {
  const g = new THREE.Group();
  g.position.set(x, y, z);
  parent.add(g);
  return g;
}

function limb(parent, w, h, d, mat, y = -h / 2, list = null) {
  const m = new THREE.Mesh(bgeo(w, h, d), mat);
  m.position.y = y;
  parent.add(m);
  if (list) list.push(m);
  return m;
}

function part(parent, geo, mat, x, y, z, rx = 0, ry = 0, rz = 0, noGib = false) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  m.rotation.set(rx, ry, rz);
  if (noGib) m.userData.noGib = true;
  parent.add(m);
  return m;
}

export function buildHumanoid(o) {
  const { skin, dark, hunch = 0.3, torsoW = 0.42, torsoH = 0.55, torsoD = 0.26, headS = 0.3, armL = 1, legL = 1, scale = 1, taper = 0.85 } = o;
  const root = new THREE.Group();
  const J = {};
  const meshes = [];
  const thigh = 0.42 * legL, shin = 0.43 * legL;
  const hipY = thigh + shin + 0.06;
  J.hips = joint(root, 0, hipY, 0);
  J.pelvis = limb(J.hips, torsoW * 0.8, 0.2, torsoD * 0.85, skin, 0, meshes);
  J.spine = joint(J.hips, 0, 0.06, 0);
  J.spine.rotation.x = -hunch;
  // gövde: bel dar, göğüs geniş
  J.belly = limb(J.spine, torsoW * taper, torsoH * 0.45, torsoD * 0.9, skin, torsoH * 0.22, meshes);
  J.torso = limb(J.spine, torsoW, torsoH * 0.6, torsoD, skin, torsoH * 0.7, meshes);
  J.neck = joint(J.spine, 0, torsoH, 0);
  J.neck.rotation.x = hunch * 0.8;
  limb(J.neck, headS * 0.4, 0.08, headS * 0.4, skin, 0.02, meshes);
  J.head = joint(J.neck, 0, 0.05, 0);
  J.headMesh = limb(J.head, headS, headS * 1.1, headS, skin, headS * 0.55, meshes);
  for (const side of [-1, 1]) {
    const s = side < 0 ? 'L' : 'R';
    const sh = (J['sh' + s] = joint(J.spine, side * (torsoW / 2 + 0.07), torsoH - 0.07, 0));
    limb(sh, 0.15, 0.12, 0.15, skin, -0.02, meshes); // omuz başı
    J['upper' + s] = limb(sh, 0.11, 0.36 * armL, 0.11, skin, undefined, meshes);
    const el = (J['el' + s] = joint(sh, 0, -0.36 * armL, 0));
    J['fore' + s] = limb(el, 0.095, 0.34 * armL, 0.095, skin, undefined, meshes);
    const ha = (J['ha' + s] = joint(el, 0, -0.34 * armL, 0));
    J['hand' + s] = limb(ha, 0.11, 0.13, 0.11, dark, -0.05, meshes);
    const hip = (J['hip' + s] = joint(J.hips, side * torsoW * 0.26, -0.04, 0));
    limb(hip, 0.15, thigh, 0.15, skin, undefined, meshes);
    const kn = (J['kn' + s] = joint(hip, 0, -thigh, 0));
    limb(kn, 0.12, shin, 0.12, skin, undefined, meshes);
    const ft = (J['ft' + s] = joint(kn, 0, -shin, 0));
    const foot = limb(ft, 0.13, 0.07, 0.24, dark, 0, meshes);
    foot.position.z = -0.05;
  }
  root.scale.setScalar(scale);
  return { root, J, meshes, hipY, dims: { thigh, shin, torsoH, headS, torsoW, torsoD, armL } };
}

// Kaburga kemikleri (göğüs önünde)
function addRibs(J, d, bone, n = 4) {
  for (let k = 0; k < n; k++) {
    part(J.spine, bgeo(d.torsoW * (0.95 - k * 0.06), 0.03, 0.04), bone, 0, d.torsoH * (0.78 - k * 0.1), -d.torsoD / 2 - 0.01);
  }
  part(J.spine, bgeo(0.05, d.torsoH * 0.45, 0.04), bone, 0, d.torsoH * 0.65, -d.torsoD / 2 - 0.015); // göğüs kemiği
}

// Omurga çıkıntıları (sırtta)
function addVertebrae(J, d, bone, n = 5) {
  for (let k = 0; k < n; k++) {
    part(J.spine, bgeo(0.06, 0.05, 0.07), bone, 0, d.torsoH * (0.15 + k * 0.18), d.torsoD / 2 + 0.02, 0.3);
  }
}

// Diş sırası
function addTeeth(parent, y, z, w, bone, n = 5, up = true) {
  for (let k = 0; k < n; k++) {
    const x = (k / (n - 1) - 0.5) * w;
    part(parent, cgeo(0.018, 0.05, 4), bone, x, y, z, up ? Math.PI : 0, 0, 0, true);
  }
}

// Pençeler
function addClaws(ha, bone) {
  for (const x of [-0.035, 0, 0.035]) part(ha, cgeo(0.016, 0.12, 4), bone, x, -0.16, -0.02, Math.PI - 0.3, 0, 0);
}

// ---------------------------------------------------------------------------
export class Enemy {
  constructor(game, pos, opts = {}) {
    this.game = game;
    this.pos = pos.clone();
    this.vel = new THREE.Vector3();
    this.knock = new THREE.Vector3();
    this.yaw = opts.yaw ?? 0;
    this.isEnemy = true;
    this.dead = false;
    this.grounded = false;
    this.state = 'spawn';
    this.st = 0;
    this.flash = 0;
    this.parryable = false;
    this.parryGlinted = false;
    this.stun = 0;
    this.arena = opts.arena || null;
    this.decor = !!opts.decor;
    this.blocked = 0;
    this.seeT = 0;
    this.canSee = false;
    this.atkCd = rand(0.5, 1.2);
    this.walkPhase = rand(0, 6);
    this.knockMul = 1;
    this.big = false;
    this.killPts = 60;
    this.spawnDur = 0.6;
    this.time = 0;
    this.mats = [];
    this.hitSpheres = [];
    this.tint = rand(0.88, 1.08);
    this.hr = { x: 0, z: 0 }; // vurulma tepkisi
    this.lookYaw = 0;
    this.lookPitch = 0;
    this.root = new THREE.Group();
    this.root.rotation.order = 'YXZ';
    this.init(opts);
    this.hp = this.maxHp;
    this.root.position.copy(this.pos);
    this.root.rotation.y = this.yaw;
    game.scene.add(this.root);
    if (opts.instant) { this.state = this.firstState || 'chase'; } // önceden yerleştirilmiş (ör. heykel)
    else if (!this.decor) game.fx.spawnFX(this.pos, this.h);
    else { this.state = 'idle'; }
  }

  // glow: malzemenin kendi renginde hafif öz aydınlatma (karanlıkta renk kaybolmasın)
  mat(map, color, glow = 0.13) {
    const c = new THREE.Color(color).multiplyScalar(this.tint);
    const m = psx(new THREE.MeshLambertMaterial({ map, color: c, emissive: 0x000000 }));
    m.userData.glow = c.clone().multiplyScalar(glow);
    this.mats.push(m);
    return m;
  }

  addSphere(obj, off, r, kind) {
    this.hitSpheres.push({ obj, off: new THREE.Vector3(...off), r, kind, w: new THREE.Vector3() });
  }

  humanoidSpheres(H, scale) {
    const d = H.dims;
    this.addSphere(H.J.head, [0, d.headS * 0.55, 0], d.headS * 0.8 * scale, 'head');
    this.addSphere(H.J.spine, [0, d.torsoH * 0.55, 0], d.torsoW * 0.72 * scale, 'body');
    this.addSphere(H.J.hips, [0, 0, 0], d.torsoW * 0.55 * scale, 'body');
    this.addSphere(H.J.knL, [0, 0, 0], 0.17 * scale, 'limb');
    this.addSphere(H.J.knR, [0, 0, 0], 0.17 * scale, 'limb');
    this.addSphere(H.J.elL, [0, 0, 0], 0.15 * scale, 'limb');
    this.addSphere(H.J.elR, [0, 0, 0], 0.15 * scale, 'limb');
  }

  center(out = new THREE.Vector3()) {
    return out.set(this.pos.x, this.pos.y + this.h * 0.55, this.pos.z);
  }

  headPos(out = new THREE.Vector3()) {
    const s = this.hitSpheres.find((h) => h.kind === 'head');
    return s ? out.copy(s.w) : this.center(out);
  }

  updateSpheres() {
    this.root.updateMatrixWorld(true);
    for (const s of this.hitSpheres) s.w.copy(s.off).applyMatrix4(s.obj.matrixWorld);
  }

  raycast(o, d, maxT) {
    const cx = this.pos.x - o.x, cy = this.pos.y + this.h * 0.5 - o.y, cz = this.pos.z - o.z;
    const tc = cx * d.x + cy * d.y + cz * d.z;
    const br = this.h * 0.75 + 0.5;
    if (tc < -br) return null;
    const dd = cx * cx + cy * cy + cz * cz - tc * tc;
    if (dd > br * br) return null;
    let best = null;
    for (const s of this.hitSpheres) {
      const ox = o.x - s.w.x, oy = o.y - s.w.y, oz = o.z - s.w.z;
      const b = ox * d.x + oy * d.y + oz * d.z;
      const c = ox * ox + oy * oy + oz * oz - s.r * s.r;
      const disc = b * b - c;
      if (disc < 0) continue;
      const sq = Math.sqrt(disc);
      let t = -b - sq;
      if (t < 0) t = -b + sq;
      if (t < 0 || t > maxT) continue;
      const tt = s.kind === 'head' ? t - 0.05 : t;
      if (!best || tt < best.tt) best = { t, tt, part: s.kind, enemy: this, sphere: s };
    }
    if (best) best.point = new THREE.Vector3(o.x + d.x * best.t, o.y + d.y * best.t, o.z + d.z * best.t);
    return best;
  }

  segmentHit(a, b, pr) {
    _d.subVectors(b, a);
    const l2 = _d.lengthSq();
    let best = null;
    for (const s of this.hitSpheres) {
      let t = l2 > 0 ? _v1.subVectors(s.w, a).dot(_d) / l2 : 0;
      t = clamp(t, 0, 1);
      _v2.copy(a).addScaledVector(_d, t);
      const rr = s.r + pr;
      const d2 = _v2.distanceToSquared(s.w);
      if (d2 < rr * rr && (!best || t < best.t)) best = { t, part: s.kind, point: _v2.clone() };
    }
    return best;
  }

  playerInfo() {
    const p = this.game.player;
    const dx = p.pos.x - this.pos.x, dz = p.pos.z - this.pos.z;
    const dist = Math.hypot(dx, dz) || 0.0001;
    return { p, dx: dx / dist, dz: dz / dist, dist, dy: p.pos.y - this.pos.y };
  }

  faceYaw(target, rate, dt) {
    const diff = wrapAngle(target - this.yaw);
    this.yaw += diff * Math.min(1, rate * dt);
  }

  facePlayer(rate, dt) {
    const i = this.playerInfo();
    this.faceYaw(yawTo(i.dx, i.dz), rate, dt);
    return i;
  }

  forward(out = _v3) {
    return out.set(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
  }

  accelTo(tx, tz, accel, dt) {
    const dvx = tx - this.vel.x, dvz = tz - this.vel.z;
    const dl = Math.hypot(dvx, dvz);
    const step = accel * dt;
    if (dl <= step) { this.vel.x = tx; this.vel.z = tz; } else { this.vel.x += (dvx / dl) * step; this.vel.z += (dvz / dl) * step; }
  }

  groundAhead(dx, dz, dist = 1.2) {
    const x = this.pos.x + dx * dist, z = this.pos.z + dz * dist;
    return !!this.game.world.overlapBox(x - 0.2, this.pos.y - 1.5, z - 0.2, x + 0.2, this.pos.y - 0.02, z + 0.2, true);
  }

  meleeHit(range, dmg, arc = 0.2) {
    const i = this.playerInfo();
    if (i.dist > range || Math.abs(i.dy + 0.5) > 2.6) return false;
    const f = this.forward();
    if (f.x * i.dx + f.z * i.dz < arc) return false;
    const ok = this.game.damagePlayer(dmg * difficulty().dmg, this.center(), false, this);
    if (ok) this.game.fx.bloodBurst(this.game.player.eyePos().addScaledVector(this.forward(), 0.3), 8, 5);
    return ok;
  }

  glint(pos) {
    const game = this.game;
    const s = game.fx.sprite(pos || this.headPos(), 0x9fe0ff, 2.4, 0.38, 'star', 1.7);
    s.material.depthTest = false;
    game.audio.play('glint', pos || this.pos, { range: 60 });
  }

  setParryable(on, glintPos) {
    if (on && !this.parryable && !this.parryGlinted) {
      this.parryGlinted = true;
      this.glint(glintPos);
    }
    if (!on) this.parryGlinted = false;
    this.parryable = on;
  }

  update(dt) {
    if (this.dead) return;
    this.time += dt;
    this.st += dt;
    this.flash = Math.max(0, this.flash - dt * 6);
    if (this.state === 'spawn') {
      const k = clamp(this.st / this.spawnDur, 0, 1);
      this.root.scale.set(1 + (1 - k) * 0.6, 0.15 + 0.85 * k * k, 1 + (1 - k) * 0.6);
      this.flash = Math.max(this.flash, 1 - k);
      if (this.st >= this.spawnDur) {
        this.root.scale.set(1, 1, 1);
        this.setState(this.firstState || 'chase');
      }
    } else if (this.state === 'idle') {
      // dekor
    } else if (this.state === 'stagger') {
      this.accelTo(0, 0, 20, dt);
      if (this.st > this.stun) this.setState(this.firstState || 'chase');
    } else if (this.state === 'flinch') {
      this.accelTo(0, 0, 30, dt);
      if (this.st > 0.14) this.setState(this.resume || this.firstState || 'chase');
    } else if (!this.game.player.dead) {
      this.seeT -= dt;
      if (this.seeT <= 0) {
        this.seeT = 0.25;
        const p = this.game.player;
        this.canSee = this.game.world.lineOfSight(_v1.set(this.pos.x, this.pos.y + this.h * 0.85, this.pos.z), _v2.set(p.pos.x, p.pos.y + p.eye, p.pos.z));
      }
      this.think(dt);
    } else {
      this.accelTo(0, 0, 20, dt);
    }
    if (!this.decor) this.physics(dt);
    if (this.dead) return;
    this.dots(dt);
    if (this.dead) return;
    this.root.position.copy(this.pos);
    this.root.rotation.y = this.yaw;
    this.animate(dt);
    this.postAnimate(dt);
    this.updateFlash();
    this.updateSpheres();
  }

  // Süreli hasarlar: yanma (Firestarter/Overheat) ve matkap (Screwdriver)
  dots(dt) {
    const game = this.game;
    if (this.burn > 0) {
      this.burn -= dt;
      this.burnTick = (this.burnTick || 0) - dt;
      if (Math.random() < dt * 25) game.fx.sparkBurst(this.center().add(new THREE.Vector3(rand(-0.3, 0.3), rand(-0.6, 0.6), rand(-0.3, 0.3))), 1, 2, Math.random() < 0.5 ? 0xff7a20 : 0xffc040, 0.5, 0.1, -3);
      if (this.burnTick <= 0) {
        this.burnTick = 0.5;
        this.hit({ dmg: 0.2, part: 'body', point: this.center(), weapon: 'rocket', quiet: true, burning: true });
      }
    }
    if (this.drill > 0 && !this.dead) {
      this.drill -= dt;
      this.drillTick = (this.drillTick || 0) - dt;
      if (this.drillTick <= 0) {
        this.drillTick = 0.12;
        this.hit({ dmg: 0.2, part: 'body', point: this.center(), weapon: 'rail', quiet: true });
        game.fx.bloodBurst(this.center(), 3, 4);
      }
    }
  }

  // Ortak: kafa ile oyuncuyu takip, vurulma tepkisi
  postAnimate(dt) {
    const H = this.H;
    if (!H) return;
    const J = H.J;
    const p = this.game.player;
    let ty = 0, tp = 0;
    if (this.state !== 'idle' && this.state !== 'spawn' && !p.dead) {
      const dx = p.pos.x - this.pos.x, dz = p.pos.z - this.pos.z;
      ty = clamp(wrapAngle(yawTo(dx, dz) - this.yaw), -0.9, 0.9);
      const dy = p.pos.y + p.eye - (this.pos.y + this.h);
      tp = clamp(Math.atan2(dy, Math.hypot(dx, dz)), -0.5, 0.6);
    } else if (this.state === 'idle') {
      ty = Math.sin(this.time * 0.5) * 0.5;
    }
    const k = 1 - Math.exp(-8 * dt);
    this.lookYaw += (ty - this.lookYaw) * k;
    this.lookPitch += (tp - this.lookPitch) * k;
    this.hr.x *= Math.exp(-10 * dt);
    this.hr.z *= Math.exp(-10 * dt);
    J.head.rotation.y = this.lookYaw;
    J.head.rotation.x = this.lookPitch * 0.7 + this.hr.x * 0.8;
    J.head.rotation.z = this.hr.z;
    J.spine.rotation.x += this.hr.x * 0.15;
    J.spine.rotation.z = this.hr.z * 0.6;
  }

  setState(s) {
    this.state = s;
    this.st = 0;
    if (s !== 'windup' && s !== 'attack' && s !== 'pounce') this.setParryable(false);
  }

  physics(dt) {
    const world = this.game.world;
    if (!this.flying) this.vel.y -= G * dt;
    this.vel.y = Math.max(this.vel.y, -80);
    const kx = this.knock.x, kz = this.knock.z;
    const wasGrounded = this.grounded;
    const res = world.moveBody(this, (this.vel.x + kx) * dt, this.vel.y * dt, (this.vel.z + kz) * dt, wasGrounded ? 0.6 : 0);
    if (res.hitX || res.hitZ) {
      this.blocked += dt;
      if (res.hitX) { this.vel.x = 0; this.knock.x *= -0.3; }
      if (res.hitZ) { this.vel.z = 0; this.knock.z *= -0.3; }
    } else this.blocked = Math.max(0, this.blocked - dt * 2);
    if (res.ceil && this.vel.y > 0) this.vel.y = 0;
    let grounded = res.ground && this.vel.y <= 0;
    if (!grounded && wasGrounded && this.vel.y <= 0) {
      const oy = this.pos.y;
      const r2 = world.moveBody(this, 0, -0.5, 0);
      if (r2.ground) grounded = true; else this.pos.y = oy;
    }
    if (grounded && !wasGrounded && this.onLand) this.onLand();
    this.grounded = grounded;
    if (grounded) this.vel.y = 0;
    const kd = Math.exp(-dt * (grounded ? 7 : 1.5));
    this.knock.x *= kd;
    this.knock.z *= kd;
    const L = this.game.level;
    if (this.pos.y < L.killY) { this.die({ dmg: 99, weapon: null, silent: true }); return; }
    for (const z of L.hurtZones) {
      const b = z.box;
      if (this.pos.x > b[0] && this.pos.x < b[3] && this.pos.y + 0.1 > b[1] && this.pos.y + 0.1 < b[4] && this.pos.z > b[2] && this.pos.z < b[5]) {
        if (z.kind === 'pit') { this.die({ dmg: 99, weapon: null }); return; }
        this.lavaT = (this.lavaT || 0) - dt;
        if (this.lavaT <= 0) {
          this.lavaT = 0.4;
          this.vel.y = 12;
          this.hit({ dmg: this.maxHp * 0.25 + 0.3, weapon: 'lava', part: 'body', point: this.center(), noHeal: true });
        }
      }
    }
  }

  updateFlash() {
    const f = this.flash;
    let r = f, g = f, b = f;
    if (this.parryable) {
      const k = 0.2 + Math.sin(this.time * 40) * 0.12;
      r = Math.max(r, 0.1 * k); g = Math.max(g, 0.35 * k); b = Math.max(b, 0.8 * k);
    }
    if (this.enraged) r = Math.max(r, 0.35 + Math.sin(this.time * 10) * 0.1);
    for (const m of this.mats) {
      const gl = m.userData.glow;
      m.emissive.setRGB(Math.max(r, gl.r), Math.max(g, gl.g), Math.max(b, gl.b));
    }
  }

  hit(info) {
    if (this.dead) return;
    const game = this.game;
    let dmg = info.dmg;
    if (info.part === 'head') dmg *= info.headMult ?? 2;
    if (this.invuln || (this.onlyParry && !info.parried)) {
      game.fx.sparkBurst(info.point || this.center(), 6, 6, 0xffffff, 0.2, 0.05);
      game.audio.play('empty', info.point || this.center());
      return;
    }
    if (this.dmgMul) dmg *= this.dmgMul;
    const wasFull = this.hp >= this.maxHp - 0.001;
    this.hp -= dmg;
    this.flash = 1;
    if (info.dir && info.knock) {
      this.knock.x += info.dir.x * info.knock * this.knockMul;
      this.knock.z += info.dir.z * info.knock * this.knockMul;
      if (info.dir.y > 0.3 || info.explosion) this.vel.y = Math.max(this.vel.y, info.knock * 0.6 * this.knockMul);
    }
    // vurulma tepkisi: gövde darbenin yönünde sarsılır
    if (info.dir) {
      const f = this.forward();
      const into = f.x * info.dir.x + f.z * info.dir.z; // + arkadan
      const side = f.x * info.dir.z - f.z * info.dir.x;
      const k = Math.min(1, 0.35 + dmg * 0.3) / (this.big ? 2 : 1);
      this.hr.x += (into > 0 ? -1 : 1) * k * (info.part === 'head' ? 1.4 : 1);
      this.hr.z += side * k;
    }
    const pt = info.point || this.center();
    game.fx.bloodBurst(pt, Math.min(45, 6 + Math.round(dmg * 10)), 5 + Math.min(dmg, 4) * 2, info.dir || null);
    if (!info.noHeal) game.bloodHeal(pt, dmg);
    const w = info.weapon;
    const fw = FRESH_W.has(w) ? w : null;
    game.style.addRaw(Math.min(dmg, 6) * 18, fw);
    if (!this.grounded && this.state !== 'spawn' && !this.flying && w !== 'lava') game.style.add('AIRSHOT', 35, fw);
    if (!info.quiet || Math.random() < 0.25) game.audio.play(info.part === 'head' ? 'headshot' : 'enemyHit', pt);
    game.hud.hitmarker(this.hp <= 0);
    if (this.hp <= 0) this.die(info, wasFull, dmg);
    else {
      // küçük düşmanlar sert darbede kısa sendeler (saldırıyı böler)
      if (!this.big && !info.quiet && dmg >= 0.9 && this.state !== 'spawn' && this.state !== 'stagger' && this.state !== 'flinch' && this.H) {
        if (this.parryable) game.style.add('INTERRUPTION', 50, fw);
        this.resume = this.firstState || 'chase';
        this.setState('flinch');
      }
      this.onHurt(info, dmg);
    }
  }

  onHurt() {}

  // Ölüm biçimi: parçalanma / kafa kopması / yığılma
  deathMode(info, dmg) {
    if (this.boss || this.type === 'trainer') return 'gib';
    const w = info.weapon;
    if (info.explosion || w === 'rail' || w === 'lava' || info.dmg >= 99) return 'gib';
    if (dmg >= this.maxHp * 2.2 && !this.big) return 'gib';
    if (w === 'shotgun' && (info.pellets || 0) >= 7) return 'gib';
    if (info.part === 'head' && this.H) return 'decap';
    return 'collapse';
  }

  die(info, wasFull = false, dmg = 0) {
    if (this.dead) return;
    this.dead = true;
    this.parryable = false;
    const game = this.game;
    const w = info.weapon;
    const fw = FRESH_W.has(w) ? w : null;
    for (const m of this.mats) m.emissive.copy(m.userData.glow);
    const c = this.center();
    const dir = info.dir ? info.dir.clone() : new THREE.Vector3();
    const mode = this.deathMode(info, dmg);
    this.root.updateMatrixWorld(true);
    if (mode === 'gib') {
      const force = info.explosion ? 12 : 5 + Math.min(info.knock || 0, 20) * 0.4;
      const meshes = [];
      this.root.traverseVisible((o) => { if (o.isMesh && !o.userData.noGib) meshes.push(o); });
      for (const m of meshes) {
        const v = new THREE.Vector3(rand(-1, 1), rand(0.3, 1.4), rand(-1, 1)).multiplyScalar(force * rand(0.4, 1)).addScaledVector(dir, force * 0.8);
        game.fx.gibFromMesh(m, v);
      }
      const gore = this.big ? 12 : 6;
      for (let i = 0; i < gore; i++) {
        game.fx.gibChunk(c.clone().add(new THREE.Vector3(rand(-0.3, 0.3), rand(-0.3, 0.3), rand(-0.3, 0.3))), new THREE.Vector3(rand(-6, 6), rand(3, 9), rand(-6, 6)), rand(0.08, 0.2), game.goreMat);
      }
      game.fx.bloodBurst(c, this.big ? 110 : 60, this.big ? 15 : 11, null, true);
      game.scene.remove(this.root);
    } else {
      // Ceset: model sahnede kalır ve yığılır
      if (mode === 'decap') {
        const J = this.H.J;
        const headMeshes = [];
        J.head.traverseVisible((o) => { if (o.isMesh) headMeshes.push(o); });
        const v = dir.clone().multiplyScalar(6).add(new THREE.Vector3(rand(-1, 1), 5, rand(-1, 1)));
        for (const m of headMeshes) if (!m.userData.noGib) game.fx.gibFromMesh(m, v.clone().add(new THREE.Vector3(rand(-1, 1), rand(0, 1), rand(-1, 1))), 14);
        J.head.visible = false;
        game.fx.bloodBurst(this.headPos(), 40, 9, new THREE.Vector3(0, 1, 0), true);
        game.fx.fountain(J.neck, 1.6);
      } else game.fx.bloodBurst(c, 30, 8, dir, false);
      const f = this.forward();
      this.fallSign = f.x * dir.x + f.z * dir.z > 0 ? -1 : 1;
      this.corpseT = 0;
      this.corpseVel = new THREE.Vector3(dir.x, 0, dir.z).multiplyScalar(Math.min(8, 2 + (info.knock || 0) * 0.4));
      game.corpses.push(this);
    }
    if (!info.silent) {
      game.audio.play('gore', c);
      if (!info.noHeal) game.bloodHeal(c, this.big ? 3 : 1.5);
      game.style.add(this.big ? 'BIG KILL' : null, this.killPts, fw);
      if (info.part === 'head' && w !== 'lava') game.style.add(this.big ? 'BIG HEADSHOT' : 'HEADSHOT', this.big ? 120 : 60, fw);
      if (info.explosion) game.style.add('FRIED', 60, fw);
      if (wasFull && this.big && dmg >= this.maxHp) game.style.add('INSTAKILL', 100, fw);
      if (w === 'punch') game.style.add('SPLATTERED', 60, null);
      if (info.burning) game.style.add('BURNED', 50, 'rocket');
      game.style.onKill(fw, this);
    }
    game.onEnemyKilled(this, info);
  }

  // Ceset animasyonu: öne/arkaya devrilir, uzuvlar gevşer, sonra yere gömülüp kaybolur
  updateCorpse(dt) {
    this.corpseT += dt;
    const t = this.corpseT;
    const world = this.game.world;
    if (t < 0.7) {
      this.corpseVel.multiplyScalar(Math.exp(-dt * 4));
      this.vel.y -= G * dt;
      const r = world.moveBody(this, this.corpseVel.x * dt, this.vel.y * dt, this.corpseVel.z * dt);
      if (r.ground) this.vel.y = 0;
    }
    const k = Math.min(1, t / 0.55);
    const fall = k * k * (Math.PI / 2 - 0.08);
    this.root.position.copy(this.pos);
    this.root.rotation.x = this.fallSign * fall;
    if (this.H) {
      const J = this.H.J;
      const lk = 1 - Math.exp(-6 * dt);
      const lerp = (j, x, z = 0) => { j.rotation.x += (x - j.rotation.x) * lk; j.rotation.z += (z - j.rotation.z) * lk; };
      lerp(J.spine, 0.1 * this.fallSign);
      lerp(J.shL, this.fallSign > 0 ? 2.4 : -0.5, -0.5);
      lerp(J.shR, this.fallSign > 0 ? 2.1 : -0.3, 0.6);
      lerp(J.elL, 0.3); lerp(J.elR, 0.6);
      lerp(J.hipL, 0.4); lerp(J.hipR, -0.1);
      lerp(J.knL, -0.8); lerp(J.knR, -0.2);
    }
    if (t > 0.5 && t < 0.56 && !this.landed) {
      this.landed = true;
      this.game.fx.addDecal(this.pos.x, this.pos.y + 0.01, this.pos.z, 0, 1, 0, 2.2);
      this.game.audio.play('land', this.pos, { vol: 0.6 });
    }
    if (t > 7) this.root.position.y = this.pos.y - (t - 7) * 0.4;
    if (t > 9) { this.game.scene.remove(this.root); return false; }
    return true;
  }

  parried(dir) {
    this.parryable = false;
    this.stun = this.parryStun || 0.9;
    this.hit({ dmg: this.parryDmg || 4, part: 'body', point: this.center(), dir, knock: 16, weapon: 'parry' });
    if (!this.dead && this.state !== 'enrage') this.setState('stagger');
  }

  removeSilently() {
    if (this.dead && this.corpseT === undefined) return;
    this.dead = true;
    this.game.scene.remove(this.root);
  }

  rot(j, x, y = 0, z = 0) {
    const k = this.k;
    j.rotation.x += (x - j.rotation.x) * k;
    j.rotation.y += (y - j.rotation.y) * k;
    j.rotation.z += (z - j.rotation.z) * k;
  }

  walkPose(H, amt, armSwing = 1, armBase = 0) {
    const s = Math.sin(this.walkPhase), c = Math.cos(this.walkPhase);
    const J = H.J;
    this.rot(J.hipL, s * 0.75 * amt);
    this.rot(J.hipR, -s * 0.75 * amt);
    this.rot(J.knL, -Math.max(0, c) * 1.2 * amt - 0.05);
    this.rot(J.knR, -Math.max(0, -c) * 1.2 * amt - 0.05);
    this.rot(J.shL, armBase - s * 0.6 * amt * armSwing, 0, -0.08);
    this.rot(J.shR, armBase + s * 0.6 * amt * armSwing, 0, 0.08);
    this.rot(J.elL, 0.35 + 0.3 * amt);
    this.rot(J.elR, 0.35 + 0.3 * amt);
    J.hips.position.y = H.hipY + Math.abs(c) * 0.06 * amt - 0.03 * amt;
    J.hips.rotation.y = s * 0.12 * amt;
  }

  airPose(H) {
    const J = H.J;
    this.rot(J.hipL, 0.9);
    this.rot(J.hipR, 0.4);
    this.rot(J.knL, -1.3);
    this.rot(J.knR, -0.9);
  }

  breathe(H, amt = 0.04) {
    H.J.spine.rotation.x += Math.sin(this.time * 2.2) * amt * this.k;
  }
}

// ---------------------------------------------------------------------------
// FILTH: kambur, hızlı yakın dövüşçü. Koşar, sıçrayarak saldırır, ısırır.
export class Filth extends Enemy {
  init() {
    const T = this.game.tex;
    this.type = 'filth';
    this.name = 'FILTH';
    this.maxHp = 0.6;
    this.r = 0.4;
    this.h = 1.55;
    this.speed = 10.5 * difficulty().speed;
    this.killPts = 50;
    this.jumpCd = 0;
    this.pounceCd = rand(1, 3);
    const skin = this.mat(T.skinW, 0x9ec878);
    const dark = this.mat(T.skinW, 0x5a3a28);
    const bone = this.mat(T.bone, 0xfff0d0);
    const flesh = this.mat(T.flesh, 0xff5050, 0.25);
    this.H = buildHumanoid({ skin, dark, hunch: 0.62, torsoW: 0.42, torsoH: 0.52, torsoD: 0.3, headS: 0.3, armL: 1.35, legL: 0.95, taper: 0.7 });
    const J = this.H.J, d = this.H.dims;
    addRibs(J, d, bone, 4);
    addVertebrae(J, d, bone, 5);
    part(J.spine, bgeo(d.torsoW * 0.6, d.torsoH * 0.3, 0.02), flesh, 0, d.torsoH * 0.2, -d.torsoD * 0.45 - 0.005); // açık karın
    // kafatası: çukur gözler, burun deliği, dişli çene
    const black = new THREE.MeshBasicMaterial({ color: 0x100404 });
    const mouth = part(J.head, bgeo(0.22, 0.12, 0.02), black, 0, 0.1, -0.155, 0, 0, 0, true);
    mouth.userData.noGib = true;
    addTeeth(J.head, 0.14, -0.16, 0.18, bone, 6, true);
    this.jaw = joint(J.head, 0, 0.05, -0.02);
    limb(this.jaw, 0.24, 0.06, 0.26, dark, -0.03);
    addTeeth(this.jaw, -0.0, -0.14, 0.16, bone, 5, false);
    for (const x of [-0.075, 0.075]) part(J.head, bgeo(0.07, 0.06, 0.02), black, x, 0.22, -0.155, 0, 0, 0, true);
    part(J.head, bgeo(0.04, 0.04, 0.02), black, 0, 0.17, -0.158, 0, 0, 0, true);
    addClaws(J.haL, bone);
    addClaws(J.haR, bone);
    this.root.add(this.H.root);
    this.humanoidSpheres(this.H, 1);
  }

  onLand() {
    if (this.state === 'pounce') { this.setState('recover'); this.game.audio.play('land', this.pos, { vol: 0.5 }); }
  }

  think(dt) {
    const i = this.playerInfo();
    const aggro = difficulty().aggro;
    this.jumpCd -= dt;
    this.atkCd -= dt;
    this.pounceCd -= dt;
    switch (this.state) {
      case 'chase': {
        this.faceYaw(yawTo(i.dx, i.dz), 10, dt);
        const sp = i.dist > 1.8 ? this.speed : 0;
        if (this.grounded) this.accelTo(i.dx * sp, i.dz * sp, 60, dt);
        else this.accelTo(i.dx * sp, i.dz * sp, 12, dt);
        if (this.grounded && this.jumpCd <= 0 && ((i.dy > 2 && i.dist < 10) || this.blocked > 0.35)) {
          this.vel.y = 16.5;
          this.vel.x = i.dx * 9;
          this.vel.z = i.dz * 9;
          this.jumpCd = 1.4;
          this.blocked = 0;
        }
        if (i.dist < 2.9 && Math.abs(i.dy) < 2 && this.atkCd <= 0 && this.grounded) {
          this.setState('windup');
          this.game.audio.play('filthGrowl', this.pos);
        } else if (i.dist > 4.5 && i.dist < 8 && Math.abs(i.dy) < 1.5 && this.pounceCd <= 0 && this.grounded && this.canSee) {
          // sıçrayarak saldırı
          this.setState('pounceWind');
          this.game.audio.play('screech', this.pos);
        }
        break;
      }
      case 'pounceWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 14, dt);
        this.accelTo(0, 0, 40, dt);
        if (this.st > 0.3 / aggro) {
          this.state = 'pounce';
          this.st = 0;
          this.hitDone = false;
          const s = Math.min(16, i.dist * 1.9);
          this.vel.set(i.dx * s, 8.5, i.dz * s);
          this.grounded = false;
          this.pounceCd = rand(3, 5) / aggro;
          this.setParryable(true, this.headPos());
        }
        break;
      }
      case 'pounce': {
        if (this.st > 0.35) this.setParryable(false);
        if (!this.hitDone && i.dist < 1.8) {
          if (this.meleeHit(2.2, 18, -0.2)) this.hitDone = true;
        }
        if (this.st > 1.2) this.setState('recover');
        break;
      }
      case 'windup': {
        this.faceYaw(yawTo(i.dx, i.dz), 12, dt);
        this.accelTo(0, 0, 40, dt);
        const dur = 0.5 / aggro;
        if (this.st > dur - 0.24) this.setParryable(true);
        if (this.st >= dur) {
          this.state = 'attack';
          this.st = 0;
          this.hitDone = false;
          const f = this.forward();
          this.vel.x = f.x * 9;
          this.vel.z = f.z * 9;
        }
        break;
      }
      case 'attack': {
        if (this.st > 0.12) this.setParryable(false);
        if (!this.hitDone && this.st > 0.08) {
          if (this.meleeHit(2.9, 20, 0.25)) this.hitDone = true;
          if (this.st > 0.2) this.hitDone = true;
        }
        this.accelTo(0, 0, 25, dt);
        if (this.st > 0.4) this.setState('recover');
        break;
      }
      case 'recover': {
        this.accelTo(0, 0, 30, dt);
        if (this.st > 0.45 / aggro) { this.setState('chase'); this.atkCd = 0.5; }
        break;
      }
    }
  }

  animate(dt) {
    this.k = 1 - Math.exp(-18 * dt);
    const H = this.H, J = H.J;
    const hsp = Math.hypot(this.vel.x, this.vel.z);
    this.walkPhase += hsp * dt * 1.25;
    const amt = clamp(hsp / 8, 0, 1);
    let jawOpen = 0.1;
    if (this.state === 'windup' || this.state === 'pounceWind') {
      this.rot(J.spine, this.state === 'pounceWind' ? -0.9 : -0.25);
      this.rot(J.shL, 2.7, 0, -0.3);
      this.rot(J.shR, 2.7, 0, 0.3);
      this.rot(J.elL, 0.6);
      this.rot(J.elR, 0.6);
      this.rot(J.hipL, 0.5); this.rot(J.hipR, -0.2);
      this.rot(J.knL, -0.9); this.rot(J.knR, -0.7);
      jawOpen = 0.6;
    } else if (this.state === 'pounce') {
      this.rot(J.spine, -0.9);
      this.rot(J.shL, 1.8, 0, -0.5);
      this.rot(J.shR, 1.8, 0, 0.5);
      this.rot(J.elL, 0.1); this.rot(J.elR, 0.1);
      this.airPose(H);
      jawOpen = 0.9;
    } else if (this.state === 'attack') {
      this.rot(J.spine, -1.0);
      this.rot(J.shL, 0.5, 0, -0.1);
      this.rot(J.shR, 0.5, 0, 0.1);
      this.rot(J.elL, 0.2);
      this.rot(J.elR, 0.2);
      jawOpen = 0.8;
    } else if (this.state === 'idle') {
      this.rot(J.spine, -0.6);
      this.walkPose(H, 0, 0, 0.3);
      this.breathe(H, 0.05);
    } else if (this.state === 'flinch' || this.state === 'stagger') {
      this.rot(J.spine, 0.1);
      this.rot(J.shL, -0.4, 0, -0.5);
      this.rot(J.shR, -0.4, 0, 0.5);
      jawOpen = 0.7;
    } else {
      // koşu: gövde öne eğik, kollar sarkık ve sallanır
      this.rot(J.spine, -0.62 - amt * 0.25);
      this.walkPose(H, amt, 1.3, 0.5 + amt * 0.4);
      if (!this.grounded && this.state !== 'spawn') this.airPose(H);
      jawOpen = 0.25 + Math.abs(Math.sin(this.time * 6)) * 0.2;
    }
    this.jaw.rotation.x = -jawOpen;
  }
}

// ---------------------------------------------------------------------------
// STRAY: kukuletalı; mesafeyi koruyup parlayan küre fırlatır (küre savuşturulabilir).
export class Stray extends Enemy {
  init(opts = {}) {
    const T = this.game.tex;
    this.type = 'stray';
    this.name = 'STRAY';
    this.maxHp = 2;
    this.r = 0.4;
    this.h = 1.95;
    this.speed = 6.5 * difficulty().speed;
    this.killPts = 70;
    this.strafeDir = chance(0.5) ? 1 : -1;
    this.strafeT = rand(1, 2.5);
    this.atkCd = rand(1.0, 2.2);
    this.firstState = 'move';
    const skin = this.mat(T.skinW, opts.skinColor || 0xe0a882);
    const dark = this.mat(T.skinW, 0x4a2a1c);
    const cloth = this.mat(T.clothW, opts.clothColor || 0xd8581c);
    const band = this.mat(T.bone, 0xfff0c0);
    this.H = buildHumanoid({ skin, dark, hunch: 0.22, torsoW: 0.36, torsoH: 0.58, headS: 0.27, armL: 1.08, legL: 1.1, scale: 1.05, taper: 0.75 });
    const J = this.H.J, d = this.H.dims;
    // kukuleta ve pelerin
    part(J.head, cgeo(0.23, 0.42, 6), cloth, 0, 0.26, 0.03, -0.25);
    part(J.head, bgeo(0.3, 0.3, 0.06), cloth, 0, 0.15, 0.13);
    part(J.spine, bgeo(d.torsoW + 0.08, d.torsoH * 0.9, 0.04), cloth, 0, d.torsoH * 0.55, d.torsoD / 2 + 0.03);
    // bel paçavraları (yürürken sallanır)
    this.rags = [];
    for (const x of [-0.12, 0, 0.12]) {
      const rj = joint(J.hips, x, -0.05, -0.12);
      limb(rj, 0.1, 0.42, 0.02, cloth, -0.2);
      this.rags.push(rj);
    }
    // kol sargıları
    for (const s of ['L', 'R']) for (const y of [-0.1, -0.22]) part(J['el' + s], bgeo(0.11, 0.04, 0.11), band, 0, y, 0);
    const glowEye = new THREE.MeshBasicMaterial({ color: 0xffb040 });
    for (const x of [-0.065, 0.065]) part(J.head, bgeo(0.05, 0.035, 0.02), glowEye, x, 0.18, -0.14, 0, 0, 0, true);
    part(J.head, bgeo(0.14, 0.05, 0.02), new THREE.MeshBasicMaterial({ color: 0x100404 }), 0, 0.08, -0.14, 0, 0, 0, true);
    // el küresi
    this.orb = new THREE.Group();
    const core = new THREE.Mesh(new THREE.IcosahedronGeometry(0.16, 1), new THREE.MeshBasicMaterial({ color: 0xfff2c0 }));
    core.userData.noGib = true;
    const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0xff8a20, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    glow.scale.setScalar(1.2);
    this.orb.add(core, glow);
    this.orb.position.set(0, -0.14, 0);
    this.orb.visible = false;
    J.haR.add(this.orb);
    this.root.add(this.H.root);
    this.humanoidSpheres(this.H, 1.05);
  }

  think(dt) {
    const i = this.playerInfo();
    const aggro = difficulty().aggro;
    this.atkCd -= dt;
    switch (this.state) {
      case 'move': {
        this.faceYaw(yawTo(i.dx, i.dz), 8, dt);
        this.strafeT -= dt;
        if (this.strafeT <= 0) { this.strafeT = rand(1.2, 2.8); this.strafeDir *= -1; }
        let want = 0;
        if (i.dist > 26) want = 1;
        else if (i.dist < 11) want = -1;
        let tx = i.dx * want * this.speed + -i.dz * this.strafeDir * this.speed * 0.55;
        let tz = i.dz * want * this.speed + i.dx * this.strafeDir * this.speed * 0.55;
        const l = Math.hypot(tx, tz);
        if (l > 0.1 && this.grounded && !this.groundAhead(tx / l, tz / l)) {
          tx = 0; tz = 0;
          this.strafeDir *= -1;
        }
        if (this.blocked > 0.3) { this.strafeDir *= -1; this.blocked = 0; }
        this.accelTo(tx, tz, 30, dt);
        if (this.atkCd <= 0 && this.canSee && i.dist < 50) {
          this.setState('windup');
          this.game.audio.play('orbCharge', this.pos);
        }
        break;
      }
      case 'windup': {
        this.faceYaw(yawTo(i.dx, i.dz), 10, dt);
        this.accelTo(0, 0, 25, dt);
        const dur = 0.95 / aggro;
        this.orb.visible = true;
        this.orb.scale.setScalar(0.3 + 0.9 * clamp(this.st / dur, 0, 1));
        if (this.st >= dur) { this.state = 'throw'; this.st = 0; this.thrown = false; }
        break;
      }
      case 'throw': {
        if (!this.thrown && this.st > 0.1) {
          this.thrown = true;
          this.orb.visible = false;
          this.throwOrb();
        }
        if (this.st > 0.45) { this.setState('move'); this.atkCd = rand(1.9, 3.2) / aggro; }
        break;
      }
    }
  }

  onHurt() {
    this.orb.visible = false;
  }

  throwOrb(speedMul = 1, dmg = 25) {
    const game = this.game;
    const p = game.player;
    const from = new THREE.Vector3();
    this.orb.getWorldPosition(from);
    const speed = 27 * difficulty().speed * speedMul;
    const target = new THREE.Vector3(p.pos.x, p.pos.y + p.h * 0.6, p.pos.z);
    const t = from.distanceTo(target) / speed;
    target.addScaledVector(p.vel, t * 0.4);
    const dir = target.sub(from).normalize();
    game.addProjectile(new Projectile(game, { pos: from, vel: dir.multiplyScalar(speed), radius: 0.35, damage: dmg * difficulty().dmg, color: 0xff8a20, source: this }));
    game.audio.play('orbThrow', from);
  }

  animate(dt) {
    this.k = 1 - Math.exp(-16 * dt);
    const H = this.H, J = H.J;
    const hsp = Math.hypot(this.vel.x, this.vel.z);
    this.walkPhase += hsp * dt * 1.4;
    const amt = clamp(hsp / 6, 0, 1);
    if (this.state === 'windup') {
      this.walkPose(H, 0, 0, 0);
      this.rot(J.spine, -0.05, 0.4);
      this.rot(J.shR, -2.5, 0, 0.3);
      this.rot(J.elR, 0.9);
      this.rot(J.shL, 0.6, 0, -0.4);
    } else if (this.state === 'throw') {
      this.rot(J.spine, -0.45, -0.35);
      this.rot(J.shR, 1.5, 0, 0.1);
      this.rot(J.elR, 0.1);
      this.rot(J.shL, -0.3);
    } else if (this.state === 'flinch' || this.state === 'stagger') {
      this.rot(J.spine, 0.25);
      this.rot(J.shL, -0.3, 0, -0.4);
      this.rot(J.shR, -0.3, 0, 0.4);
    } else {
      this.rot(J.spine, -0.22, 0);
      this.walkPose(H, amt, 0.8, 0.1);
      if (!this.grounded && this.state !== 'spawn') this.airPose(H);
      this.breathe(H, 0.03);
    }
    // paçavralar hareketle savrulur
    for (let k = 0; k < this.rags.length; k++) {
      this.rags[k].rotation.x = 0.15 + amt * 0.5 + Math.sin(this.time * 7 + k) * 0.12;
    }
  }
}

// Parry eğitmeni: kafesteki hareketsiz Stray; yavaş küre fırlatır, yalnız savuşturulan
// kendi küresiyle ölür.
export class Trainer extends Stray {
  init() {
    super.init({ skinColor: 0xa8c0ff, clothColor: 0x2c50e0 });
    this.type = 'trainer';
    this.name = 'EĞİTMEN';
    this.maxHp = 1;
    this.onlyParry = true;
    this.noCount = true;
    this.killPts = 0;
    this.speed = 0;
    this.atkCd = 1.5;
  }

  think(dt) {
    const i = this.playerInfo();
    this.atkCd -= dt;
    this.faceYaw(yawTo(i.dx, i.dz), 8, dt);
    this.accelTo(0, 0, 30, dt);
    if (this.state === 'move' && this.atkCd <= 0 && this.canSee && i.dist < 22) {
      this.setState('windup');
      this.game.audio.play('orbCharge', this.pos);
    } else if (this.state === 'windup') {
      const dur = 1.1;
      this.orb.visible = true;
      this.orb.scale.setScalar(0.3 + 0.9 * clamp(this.st / dur, 0, 1));
      if (this.st >= dur) { this.state = 'throw'; this.st = 0; this.thrown = false; }
    } else if (this.state === 'throw') {
      if (!this.thrown && this.st > 0.1) { this.thrown = true; this.orb.visible = false; this.throwOrb(0.42, 6); }
      if (this.st > 0.45) { this.setState('move'); this.atkCd = 2.0; }
    }
  }
}

// ---------------------------------------------------------------------------
// SCHISM: dikenli taçlı, bıçak kollu; yatay/dikey mermi dizisi ateşler, yakında savurur.
export class Schism extends Enemy {
  init() {
    const T = this.game.tex;
    this.type = 'schism';
    this.name = 'SCHISM';
    this.maxHp = 6;
    this.r = 0.55;
    this.h = 2.3;
    this.speed = 4.6 * difficulty().speed;
    this.big = true;
    this.killPts = 130;
    this.knockMul = 0.55;
    this.firstState = 'move';
    this.strafeDir = 1;
    this.strafeT = 2;
    this.atkCd = rand(1.2, 2.0);
    this.meleeCd = 0;
    const skin = this.mat(T.skinW, 0xa08ae8);
    const dark = this.mat(T.skinW, 0x38225a);
    const bone = this.mat(T.bone, 0xfff0c0);
    const flesh = this.mat(T.flesh, 0xff4a8a, 0.25);
    this.H = buildHumanoid({ skin, dark, hunch: 0.16, torsoW: 0.56, torsoH: 0.66, torsoD: 0.34, headS: 0.3, armL: 1.12, legL: 1.1, scale: 1.2, taper: 0.8 });
    const J = this.H.J, d = this.H.dims;
    J.foreL.visible = false;
    J.handL.visible = false;
    const blade = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.14, 1.4, 5), bone);
    blade.position.y = -0.7;
    J.elL.add(blade);
    const runeMat = new THREE.MeshBasicMaterial({ color: 0xffd040 });
    for (let k = 0; k < 4; k++) part(J.elL, bgeo(0.03, 0.08, 0.03), runeMat, 0.06 - k * 0.005, -0.25 - k * 0.25, -0.05, 0, 0, 0, true);
    this.tip = joint(J.elL, 0, -1.4, 0);
    const tipGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0xffd040, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    tipGlow.scale.setScalar(0.5);
    this.tipGlow = tipGlow;
    this.tip.add(tipGlow);
    // omuz ve taç dikenleri
    for (const x of [-0.22, 0, 0.22]) part(J.spine, cgeo(0.06, 0.3, 4), dark, x, 0.68, 0.12, 0.5);
    for (let k = 0; k < 5; k++) {
      const a = (k / 4 - 0.5) * 1.6;
      part(J.head, cgeo(0.035, 0.2, 4), bone, Math.sin(a) * 0.13, 0.36, Math.cos(a) * 0.05, -0.2, 0, -a * 0.6);
    }
    // dikişli karın
    part(J.spine, bgeo(d.torsoW * 0.5, d.torsoH * 0.35, 0.02), flesh, 0, d.torsoH * 0.25, -d.torsoD / 2 - 0.005);
    for (let k = 0; k < 4; k++) part(J.spine, bgeo(0.16, 0.015, 0.03), dark, 0, d.torsoH * (0.14 + k * 0.07), -d.torsoD / 2 - 0.01);
    addVertebrae(J, d, bone, 4);
    const black = new THREE.MeshBasicMaterial({ color: 0x100404 });
    for (const x of [-0.07, 0.07]) part(J.head, bgeo(0.06, 0.04, 0.02), new THREE.MeshBasicMaterial({ color: 0xffe060 }), x, 0.21, -0.155, 0, 0, 0, true);
    part(J.head, bgeo(0.16, 0.06, 0.02), black, 0, 0.08, -0.155, 0, 0, 0, true);
    addTeeth(J.head, 0.11, -0.16, 0.14, bone, 5, true);
    this.root.add(this.H.root);
    this.humanoidSpheres(this.H, 1.2);
    this.addSphere(this.tip, [0, 0.5, 0], 0.18, 'limb');
  }

  think(dt) {
    const i = this.playerInfo();
    const aggro = difficulty().aggro;
    this.atkCd -= dt;
    this.meleeCd -= dt;
    switch (this.state) {
      case 'move': {
        this.faceYaw(yawTo(i.dx, i.dz), 6, dt);
        this.strafeT -= dt;
        if (this.strafeT <= 0) { this.strafeT = rand(1.5, 3); this.strafeDir *= -1; }
        let want = 0;
        if (i.dist > 17) want = 1;
        else if (i.dist < 7) want = -0.6;
        const tx = i.dx * want * this.speed - i.dz * this.strafeDir * this.speed * 0.4;
        const tz = i.dz * want * this.speed + i.dx * this.strafeDir * this.speed * 0.4;
        if (this.blocked > 0.4) { this.strafeDir *= -1; this.blocked = 0; }
        this.accelTo(tx, tz, 20, dt);
        if (i.dist < 3.4 && this.meleeCd <= 0 && Math.abs(i.dy) < 2) {
          this.setState('swipeWind');
          this.game.audio.play('windup', this.pos);
        } else if (this.atkCd <= 0 && this.canSee) {
          this.mode = chance(0.5) ? 'H' : 'V';
          this.setState('wind');
          this.game.audio.play('windup', this.pos);
          this.game.audio.play('filthGrowl', this.pos, { rate: 0.6, exactRate: true });
        }
        break;
      }
      case 'wind': {
        this.faceYaw(yawTo(i.dx, i.dz), 8, dt);
        this.accelTo(0, 0, 20, dt);
        if (this.st >= 0.8 / aggro) { this.state = 'fire'; this.st = 0; this.shots = 0; this.aimYaw = yawTo(i.dx, i.dz); }
        break;
      }
      case 'fire': {
        const n = this.mode === 'H' ? 9 : 7;
        const dur = this.mode === 'H' ? 0.55 : 0.42;
        while (this.shots < n && this.st >= (this.shots / (n - 1)) * dur) {
          this.fireShot(this.shots, n);
          this.shots++;
        }
        if (this.shots >= n && this.st > dur + 0.15) this.setState('recover');
        break;
      }
      case 'swipeWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 10, dt);
        this.accelTo(0, 0, 20, dt);
        const dur = 0.55 / aggro;
        if (this.st > dur - 0.26) this.setParryable(true, this.tip.getWorldPosition(new THREE.Vector3()));
        if (this.st >= dur) { this.state = 'attack'; this.st = 0; this.hitDone = false; this.game.audio.play('swing', this.pos); }
        break;
      }
      case 'attack': {
        if (this.st > 0.1) this.setParryable(false);
        if (!this.hitDone && this.st > 0.06) {
          if (this.meleeHit(3.6, 30, 0.1)) this.hitDone = true;
          if (this.st > 0.2) this.hitDone = true;
        }
        if (this.st > 0.4) { this.setState('recover'); this.meleeCd = 1.5; }
        break;
      }
      case 'recover': {
        this.accelTo(0, 0, 20, dt);
        if (this.st > 0.6 / aggro) { this.setState('move'); this.atkCd = rand(2.0, 3.2) / aggro; }
        break;
      }
    }
  }

  fireShot(idx, n) {
    const game = this.game;
    const p = game.player;
    const from = this.tip.getWorldPosition(new THREE.Vector3());
    const target = new THREE.Vector3(p.pos.x, p.pos.y + p.h * 0.5, p.pos.z);
    const base = target.clone().sub(from).normalize();
    const yaw = Math.atan2(base.x, base.z);
    const pitch = Math.asin(clamp(base.y, -1, 1));
    const k = idx / (n - 1);
    let dy = 0, dp = 0;
    if (this.mode === 'H') dy = (k - 0.5) * 1.1;
    else dp = (k - 0.35) * 0.65;
    const cp = Math.cos(pitch + dp);
    const dir = new THREE.Vector3(Math.sin(yaw + dy) * cp, Math.sin(pitch + dp), Math.cos(yaw + dy) * cp);
    const speed = 30 * difficulty().speed;
    game.addProjectile(new Projectile(game, { pos: from, vel: dir.multiplyScalar(speed), radius: 0.26, damage: 20 * difficulty().dmg, color: 0xffd040, source: this }));
    game.audio.play('schismShot', from, { force: true });
  }

  animate(dt) {
    this.k = 1 - Math.exp(-14 * dt);
    const H = this.H, J = H.J;
    const hsp = Math.hypot(this.vel.x, this.vel.z);
    this.walkPhase += hsp * dt * 1.2;
    const amt = clamp(hsp / 4.5, 0, 1);
    this.tipGlow.scale.setScalar(this.state === 'wind' || this.state === 'fire' ? 0.9 + Math.sin(this.time * 30) * 0.2 : 0.45);
    if (this.state === 'wind') {
      this.walkPose(H, 0);
      if (this.mode === 'H') { this.rot(J.spine, -0.1, 0.7); this.rot(J.shL, 1.5, 0, 0); }
      else { this.rot(J.spine, 0.05, 0.2); this.rot(J.shL, 1.2, 0, 0); }
      this.rot(J.elL, 0);
    } else if (this.state === 'fire') {
      const n = this.mode === 'H' ? 0.55 : 0.42;
      const k = clamp(this.st / n, 0, 1);
      if (this.mode === 'H') { this.rot(J.spine, -0.1, 0.55 - k * 1.1); this.rot(J.shL, 1.55); }
      else { this.rot(J.spine, 0.05, 0.2); this.rot(J.shL, 1.2 + k * 0.9); }
      this.rot(J.elL, 0);
    } else if (this.state === 'swipeWind') {
      this.rot(J.spine, 0.1, 0.6);
      this.rot(J.shL, -0.9, 0, -0.6);
      this.rot(J.elL, 0.2);
    } else if (this.state === 'attack') {
      this.rot(J.spine, -0.35, -0.6);
      this.rot(J.shL, 1.7, 0, 0.2);
      this.rot(J.elL, 0.1);
    } else if (this.state === 'stagger') {
      this.rot(J.spine, 0.35);
    } else {
      this.rot(J.spine, -0.16, 0);
      this.walkPose(H, amt, 0.6, 0.05);
      this.rot(J.shL, 0.5 - Math.sin(this.walkPhase) * 0.3 * amt, 0, -0.15);
      this.rot(J.elL, 0.4);
      this.breathe(H, 0.03);
    }
  }
}

// ---------------------------------------------------------------------------
// SWORDSMACHINE (boss): kılıç kombosu (son vuruş savuşturulabilir), bumerang kılıç,
// pompalı tüfek, atılma; yarı canda öfkelenir.
export class Swordsmachine extends Enemy {
  init() {
    const T = this.game.tex;
    this.type = 'swordsmachine';
    this.name = 'SWORDSMACHINE';
    this.maxHp = 40;
    this.r = 0.6;
    this.h = 2.55;
    this.baseSpeed = 9.5 * difficulty().speed;
    this.speed = this.baseSpeed;
    this.big = true;
    this.boss = true;
    this.killPts = 400;
    this.knockMul = 0.25;
    this.parryDmg = 5;
    this.parryStun = 1.6;
    this.firstState = 'chase';
    this.spawnDur = 0.9;
    this.hasSword = true;
    this.enraged = false;
    this.cdMul = 1;
    this.atkCd = 1.0;
    this.tint = 1;
    const metal = this.mat(T.machine, 0xc8d0dc);
    const dark = this.mat(T.machine, 0x3a3e4c);
    const plate = this.mat(T.metal, 0xffb420, 0.18);
    const H = (this.H = buildHumanoid({ skin: metal, dark, hunch: 0.1, torsoW: 0.58, torsoH: 0.64, torsoD: 0.34, headS: 0.3, armL: 1.08, legL: 1.08, scale: 1.32, taper: 0.7 }));
    const J = H.J, d = H.dims;
    const orange = new THREE.MeshBasicMaterial({ color: 0xffa020 });
    this.visorMat = orange;
    part(J.head, bgeo(0.28, 0.06, 0.02), orange, 0, 0.2, -0.16, 0, 0, 0, true);
    part(J.head, bgeo(0.32, 0.08, 0.34), plate, 0, 0.34, 0); // miğfer
    for (const x of [-0.12, 0.12]) part(J.head, cgeo(0.03, 0.22, 4), dark, x, 0.42, 0.08, -0.5, 0, x * 2); // boynuzlar
    part(J.spine, bgeo(0.18, 0.18, 0.04), orange, 0, 0.42, -0.18, 0, 0, 0, true); // çekirdek
    part(J.spine, bgeo(0.26, 0.24, 0.05), plate, -0.16, 0.5, -0.17, 0, 0.3, 0); // göğüs plakaları
    part(J.spine, bgeo(0.26, 0.24, 0.05), plate, 0.16, 0.5, -0.17, 0, -0.3, 0);
    for (let k = 0; k < 3; k++) part(J.spine, bgeo(d.torsoW * 0.7, 0.05, d.torsoD + 0.02), dark, 0, 0.08 + k * 0.08, 0); // karın segmentleri
    for (const x of [-0.14, 0.14]) {
      part(J.spine, new THREE.CylinderGeometry(0.05, 0.06, 0.4, 6), dark, x, 0.55, 0.22, 0.2); // egzoz boruları
    }
    this.exhaust = joint(J.spine, 0, 0.8, 0.26);
    for (const side of ['L', 'R']) {
      part(J['sh' + side], bgeo(0.26, 0.14, 0.32), plate, 0, 0.04, 0);
      part(J['kn' + side], bgeo(0.16, 0.14, 0.08), plate, 0, 0.02, -0.08); // diz plakası
    }
    // kılıç (zincirli testere kılıcı, dişleri akar)
    const sword = new THREE.Group();
    const bladeMat = this.mat(T.metal, 0xc8ccd4);
    part(sword, bgeo(0.06, 0.22, 0.06), dark, 0, -0.06, 0);
    part(sword, bgeo(0.3, 0.05, 0.1), dark, 0, -0.18, 0);
    part(sword, bgeo(0.05, 1.4, 0.2), bladeMat, 0, -0.9, 0);
    part(sword, bgeo(0.055, 1.35, 0.025), orange, 0, -0.9, -0.11, 0, 0, 0, false);
    this.teeth = [];
    for (let k = 0; k < 10; k++) {
      const tooth = part(sword, bgeo(0.035, 0.06, 0.05), dark, 0, -0.3 - k * 0.13, -0.135, 0, 0, 0, true);
      this.teeth.push(tooth);
    }
    sword.rotation.x = Math.PI / 2;
    J.haR.add(sword);
    this.sword = sword;
    // pompalı tüfek (sol elde, kullanırken görünür)
    const gun = new THREE.Group();
    part(gun, bgeo(0.12, 0.62, 0.14), dark, 0, -0.28, 0);
    part(gun, bgeo(0.07, 0.3, 0.07), metal, 0, -0.62, -0.02);
    part(gun, bgeo(0.13, 0.04, 0.15), orange, 0, -0.1, 0, 0, 0, 0, true);
    this.gunMuzzle = joint(gun, 0, -0.8, 0);
    J.haL.add(gun);
    gun.visible = false;
    this.gun = gun;
    this.root.add(H.root);
    this.humanoidSpheres(H, 1.32);
  }

  handWorld(out = new THREE.Vector3()) {
    return this.H.J.haR.getWorldPosition(out);
  }

  catchSword() {
    this.hasSword = true;
    this.sword.visible = true;
    this.game.audio.play('chainsaw', this.pos);
  }

  onHurt() {
    if (!this.enraged && this.hp < this.maxHp * 0.5 && this.state !== 'enrage') {
      this.setState('enrage');
      this.invuln = true;
      this.game.audio.play('bossRoar', this.pos);
      this.game.shake(0.5);
    }
  }

  think(dt) {
    const i = this.playerInfo();
    const aggro = difficulty().aggro;
    this.atkCd -= dt;
    const cd = this.cdMul / aggro;
    switch (this.state) {
      case 'chase': {
        this.faceYaw(yawTo(i.dx, i.dz), 8, dt);
        const sp = i.dist > 3 ? this.speed : 0;
        this.accelTo(i.dx * sp, i.dz * sp, 40, dt);
        if (this.atkCd <= 0) {
          if (i.dist < 4.5 && this.hasSword) { this.combo = 0; this.setState('swingWind'); this.game.audio.play('chainsaw', this.pos); }
          else if (i.dist > 11 && this.hasSword && chance(0.45)) { this.setState('throwWind'); this.game.audio.play('windup', this.pos); }
          else if (chance(0.5) || !this.hasSword) { this.setState('gunWind'); this.gun.visible = true; this.game.audio.play('windup', this.pos); }
          else if (this.hasSword) { this.setState('dash'); this.game.audio.play('dash', this.pos); }
          else this.atkCd = 0.3;
        }
        if (this.blocked > 0.5 && this.grounded) { this.vel.y = 14; this.blocked = 0; }
        break;
      }
      case 'dash': {
        this.faceYaw(yawTo(i.dx, i.dz), 10, dt);
        const s = 30 * difficulty().speed;
        this.vel.x = i.dx * s;
        this.vel.z = i.dz * s;
        if (Math.random() < dt * 40) this.game.fx.sparkBurst(this.pos.clone().add(new THREE.Vector3(0, 0.2, 0)), 1, 4, 0xffa030, 0.3, 0.06);
        if (i.dist < 3.6 || this.st > 0.45) { this.combo = 0; this.setState('swingWind'); }
        break;
      }
      case 'swingWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 9, dt);
        this.accelTo(0, 0, 30, dt);
        const last = this.combo === 2;
        const dur = (last ? 0.55 : 0.34) * cd;
        if (last && this.st > dur - 0.27) this.setParryable(true, this.handWorld());
        if (this.st >= dur) {
          this.state = 'swing'; this.st = 0; this.hitDone = false;
          const f = this.forward();
          this.vel.x = f.x * 10; this.vel.z = f.z * 10;
          this.game.audio.play('swing', this.pos);
        }
        break;
      }
      case 'swing': {
        if (this.st > 0.1) this.setParryable(false);
        this.accelTo(0, 0, 40, dt);
        if (!this.hitDone && this.st > 0.05) {
          if (this.meleeHit(4.3, 25, 0.15)) this.hitDone = true;
          if (this.st > 0.18) this.hitDone = true;
        }
        if (this.st > 0.28) {
          this.combo++;
          if (this.combo >= 3) { this.setState('recover'); this.atkCd = rand(0.8, 1.4) * cd; }
          else { this.state = 'swingWind'; this.st = 0; }
        }
        break;
      }
      case 'throwWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 9, dt);
        this.accelTo(0, 0, 30, dt);
        if (this.st >= 0.6 * cd) { this.throwSword(); this.setState('recoverShort'); }
        break;
      }
      case 'recoverShort': {
        this.accelTo(0, 0, 30, dt);
        if (this.st > 0.35) { this.setState('gunWind'); this.gun.visible = true; }
        break;
      }
      case 'gunWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 10, dt);
        this.accelTo(0, 0, 30, dt);
        if (this.st > 0.55 * cd - 0.2 && !this.gunGlint) { this.gunGlint = true; this.glint(this.gunMuzzle.getWorldPosition(new THREE.Vector3())); }
        if (this.st >= 0.55 * cd) { this.fireShotgun(); this.gunGlint = false; this.setState('gunRecover'); }
        break;
      }
      case 'gunRecover': {
        this.accelTo(0, 0, 30, dt);
        if (this.st > 0.5) {
          this.gun.visible = false;
          this.setState('chase');
          this.atkCd = rand(0.6, 1.2) * cd;
        }
        break;
      }
      case 'recover': {
        this.accelTo(0, 0, 30, dt);
        if (this.st > 0.7 * cd) this.setState('chase');
        break;
      }
      case 'enrage': {
        this.accelTo(0, 0, 30, dt);
        if (Math.random() < dt * 20) this.game.fx.sparkBurst(this.center(), 3, 8, 0xff4020, 0.4, 0.07);
        if (this.st > 1.3) {
          this.enraged = true;
          this.invuln = false;
          this.speed = this.baseSpeed * 1.3;
          this.cdMul = 0.7;
          this.visorMat.color.setHex(0xff2010);
          this.game.style.add('ENRAGED', 50);
          this.setState('chase');
        }
        break;
      }
    }
  }

  throwSword() {
    const game = this.game;
    const p = game.player;
    const from = this.handWorld();
    const target = new THREE.Vector3(p.pos.x, p.pos.y + 1.0, p.pos.z);
    const dir = target.sub(from).normalize();
    this.hasSword = false;
    this.sword.visible = false;
    const mesh = this.sword.clone();
    mesh.rotation.set(Math.PI / 2, 0, Math.PI / 2);
    const holder = new THREE.Group();
    holder.add(mesh);
    const proj = new Projectile(game, { kind: 'sword', mesh: holder, pos: from, vel: dir.multiplyScalar(32 * difficulty().speed), damage: 30 * difficulty().dmg, parryable: false, source: this, life: 8 });
    game.addProjectile(proj);
    game.audio.play('swing', from);
    game.audio.play('chainsaw', from);
  }

  fireShotgun() {
    const game = this.game;
    const p = game.player;
    const from = this.gunMuzzle.getWorldPosition(new THREE.Vector3());
    const target = new THREE.Vector3(p.pos.x, p.pos.y + p.h * 0.5, p.pos.z);
    const base = target.sub(from).normalize();
    for (let k = 0; k < 9; k++) {
      const d = base.clone().add(new THREE.Vector3(rand(-0.11, 0.11), rand(-0.06, 0.08), rand(-0.11, 0.11))).normalize();
      game.addProjectile(new Projectile(game, { kind: 'pellet', pos: from, vel: d.multiplyScalar(65), radius: 0.2, damage: 9 * difficulty().dmg, color: 0xffc040, parryable: true, source: this, life: 1.5 }));
    }
    game.fx.sprite(from, 0xffd080, 1.5, 0.08, 'glow', 2);
    game.fx.smoke(from, 3, 0x9a8a80, 0.6, 0.8, 0.6);
    game.flashLight(from, 0xffb040, 8, 18, 0.08);
    game.audio.play('bossShotgun', from);
  }

  parried(dir) {
    super.parried(dir);
    if (!this.dead) this.game.audio.play('bossRoar', this.pos, { vol: 0.5 });
  }

  die(info, wasFull, dmg) {
    this.gun.visible = false;
    super.die(info, wasFull, dmg);
    this.game.explode(this.center(), 4, 0, { owner: 'none', playerDmg: 0, visualOnly: true });
    this.game.hitstop(0.35);
  }

  animate(dt) {
    this.k = 1 - Math.exp(-16 * dt);
    const H = this.H, J = H.J;
    const hsp = Math.hypot(this.vel.x, this.vel.z);
    this.walkPhase += hsp * dt * 1.0;
    const amt = clamp(hsp / 9, 0, 1);
    const s = this.state;
    // zincirli testere dişleri akar (saldırıda hızlı)
    const saw = s === 'swing' || s === 'swingWind' || s === 'dash' ? 6 : 1.2;
    for (let k = 0; k < this.teeth.length; k++) this.teeth[k].position.y = -0.3 - (((k * 0.13 + this.time * saw) % 1.3 + 1.3) % 1.3);
    if (Math.random() < dt * (this.enraged ? 10 : 3)) this.game.fx.smoke(this.exhaust.getWorldPosition(new THREE.Vector3()), 1, this.enraged ? 0x602010 : 0x606060, 0.35, 0.8, 1.5);
    if (s === 'swingWind') {
      const alt = this.combo % 2 === 1;
      this.walkPose(H, 0);
      this.rot(J.spine, 0.1, alt ? -0.7 : 0.7);
      this.rot(J.shR, alt ? 1.2 : 2.9, 0, alt ? 1.3 : 0.2);
      this.rot(J.elR, 0.5);
      this.rot(J.shL, 0.4, 0, -0.3);
      this.rot(J.hipL, 0.4); this.rot(J.knL, -0.5); this.rot(J.hipR, -0.3);
    } else if (s === 'swing') {
      const alt = this.combo % 2 === 1;
      this.rot(J.spine, -0.4, alt ? 0.7 : -0.5);
      this.rot(J.shR, alt ? 1.3 : 0.5, 0, alt ? -0.9 : 0);
      this.rot(J.elR, 0.1);
    } else if (s === 'throwWind') {
      this.walkPose(H, 0);
      this.rot(J.spine, 0.1, 0.9);
      this.rot(J.shR, 2.6, 0, 0.8);
      this.rot(J.elR, 0.4);
    } else if (s === 'recoverShort') {
      this.rot(J.spine, -0.3, -0.5);
      this.rot(J.shR, 1.5, 0, -0.5);
    } else if (s === 'gunWind' || s === 'gunRecover') {
      this.walkPose(H, 0);
      this.rot(J.spine, 0, -0.35);
      this.rot(J.shL, 1.55 + (s === 'gunRecover' && this.st < 0.15 ? 0.5 : 0), 0.2, 0);
      this.rot(J.elL, 0);
      this.rot(J.shR, 0.3, 0, 0.2);
    } else if (s === 'enrage') {
      const sh = Math.sin(this.time * 50) * 0.05;
      this.rot(J.spine, 0.35 + sh, 0);
      this.rot(J.shL, 0.3, 0, -1.2);
      this.rot(J.shR, 0.3, 0, 1.2);
      this.rot(J.neck, -0.5);
    } else if (s === 'dash') {
      this.rot(J.spine, -0.6, 0);
      this.rot(J.shR, -0.6, 0, 0.3);
      this.rot(J.hipL, 0.9); this.rot(J.knL, -0.3); this.rot(J.hipR, -0.8); this.rot(J.knR, -1.0);
    } else if (s === 'stagger') {
      this.rot(J.spine, 0.5, 0.2);
      this.rot(J.shL, -0.3, 0, -0.9);
      this.rot(J.shR, -0.3, 0, 0.9);
      this.rot(J.neck, -0.4);
    } else if (s === 'spawn' || s === 'intro') {
      this.rot(J.spine, 0.1);
      this.rot(J.shR, 2.4, 0, 0.3);
      this.rot(J.elR, 0.8);
    } else {
      this.rot(J.spine, -0.12 - amt * 0.2, 0);
      this.walkPose(H, amt, 0.6, 0.15);
      this.rot(J.shR, 0.6 + Math.sin(this.walkPhase) * 0.3 * amt, 0, 0.2);
      this.rot(J.elR, 0.8);
      this.rot(J.neck, 0.1, 0);
      if (!this.grounded) this.airPose(H);
    }
  }
}

// ---------------------------------------------------------------------------
// Yer sarsıntısı dalgası (Cerberus): zeminde genişleyen halka; yerdeysen vurur, üstünden zıpla.
export class Shockwave {
  constructor(game, pos, o = {}) {
    this.game = game;
    this.pos = pos.clone();
    this.r = 0.6;
    this.speed = o.speed || 17;
    this.max = o.max || 24;
    this.dmg = o.dmg || 20;
    this.done = false;
    const col = o.color || 0xff8a30;
    this.ringMat = new THREE.MeshBasicMaterial({ color: col, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
    this.ring = new THREE.Mesh(new THREE.TorusGeometry(1, 0.1, 4, 48), this.ringMat);
    this.ring.rotation.x = Math.PI / 2;
    this.ring.position.set(pos.x, pos.y + 0.25, pos.z);
    this.wallMat = new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.3, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
    this.wall = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 0.8, 48, 1, true), this.wallMat);
    this.wall.position.set(pos.x, pos.y + 0.4, pos.z);
    game.scene.add(this.ring, this.wall);
  }

  update(dt) {
    if (this.done) return false;
    this.r += this.speed * dt;
    const r = this.r;
    this.ring.scale.set(r, r, 1);
    this.wall.scale.set(r, 1, r);
    const k = 1 - r / this.max;
    this.ringMat.opacity = Math.min(1, k * 2);
    this.wallMat.opacity = 0.3 * k;
    const p = this.game.player;
    if (!this.hitP && !p.dead) {
      const d = Math.hypot(p.pos.x - this.pos.x, p.pos.z - this.pos.z);
      if (Math.abs(d - r) < 0.9 && p.pos.y - this.pos.y < 0.85 && p.pos.y - this.pos.y > -1.5) {
        this.hitP = true;
        if (this.game.damagePlayer(this.dmg * difficulty().dmg, this.pos)) { p.vel.y = Math.max(p.vel.y, 9); p.grounded = false; }
      }
    }
    if (r >= this.max) { this.remove(); return false; }
    return true;
  }

  remove() {
    if (this.done) return;
    this.done = true;
    this.game.scene.remove(this.ring, this.wall);
    this.ring.geometry.dispose();
    this.wall.geometry.dispose();
    this.ringMat.dispose();
    this.wallMat.dispose();
  }
}

// ---------------------------------------------------------------------------
// MALICIOUS FACE: havada süzülen dev taş kafa. Ağzından küre yağmuru (savuşturulabilir) ve
// uzun işaretli, dash ile kaçılan ışın. Gözler zayıf nokta. Ölünce düşer ve yere çarpınca patlar.
export class MaliciousFace extends Enemy {
  init() {
    const T = this.game.tex;
    this.type = 'maliciousface';
    this.name = 'MALICIOUS FACE';
    this.maxHp = 10;
    this.r = 1.05;
    this.h = 2.2;
    this.flying = true;
    this.big = true;
    this.killPts = 280;
    this.knockMul = 0.1;
    this.firstState = 'hover';
    this.spawnDur = 0.9;
    this.speed = 4 * difficulty().speed;
    this.hoverY = this.pos.y;
    this.strafeDir = chance(0.5) ? 1 : -1;
    this.strafeT = rand(2, 4);
    this.atkCd = rand(1.4, 2.4);
    this.nextBeam = chance(0.5);
    this.jawOpen = 0;
    this.tint = 1;
    const stone = this.mat(T.stone, 0xc4b49e, 0.1);
    const dark = this.mat(T.rock, 0x4e3e34, 0.08);
    const bone = this.mat(T.bone, 0xf4e6c4, 0.12);
    const H = new THREE.Group();
    H.position.y = 1.1;
    this.root.add(H);
    this.head = H;
    part(H, bgeo(1.9, 1.45, 1.8), stone, 0, 0.18, 0.05);
    part(H, bgeo(1.55, 0.35, 1.45), stone, 0, 1.0, 0.12);
    part(H, bgeo(2.08, 0.3, 0.5), dark, 0, 0.46, -0.82);
    for (const x of [-0.82, 0.82]) part(H, bgeo(0.45, 0.62, 0.5), stone, x, -0.18, -0.74);
    part(H, bgeo(0.32, 0.5, 0.36), stone, 0, 0.02, -0.98, 0.25);
    const black = new THREE.MeshBasicMaterial({ color: 0x0a0204 });
    for (const x of [-0.46, 0.46]) part(H, bgeo(0.52, 0.3, 0.1), black, x, 0.2, -0.94, 0, 0, 0, true);
    this.eyeMat = new THREE.MeshBasicMaterial({ color: 0xff6a1a });
    for (const x of [-0.46, 0.46]) part(H, bgeo(0.22, 0.14, 0.06), this.eyeMat, x, 0.2, -0.99, 0, 0, 0, true);
    part(H, bgeo(1.35, 0.3, 0.1), black, 0, -0.52, -0.9, 0, 0, 0, true); // ağız boşluğu
    addTeeth(H, -0.42, -0.95, 1.2, bone, 8, true);
    this.jaw = joint(H, 0, -0.55, 0.2);
    part(this.jaw, bgeo(1.6, 0.42, 1.55), stone, 0, -0.22, -0.2);
    addTeeth(this.jaw, 0.02, -0.92, 1.15, bone, 7, false);
    this.mouth = joint(H, 0, -0.62, -1.05);
    this.mouthGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0xff7a20, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    this.mouthGlow.scale.setScalar(0.1);
    this.mouth.add(this.mouthGlow);
    for (const [x, rz] of [[-0.6, 0.5], [-0.2, 0.15], [0.25, -0.2], [0.65, -0.55]]) part(H, cgeo(0.14, 0.75, 5), dark, x, 1.45, 0.25, -0.35, 0, rz);
    this.crackMat = new THREE.MeshBasicMaterial({ color: 0xa0301a });
    part(H, bgeo(0.05, 0.75, 0.04), this.crackMat, -0.25, 0.72, -0.9, 0, 0, 0.45, true);
    part(H, bgeo(0.05, 0.5, 0.04), this.crackMat, 0.62, -0.1, -0.99, 0, 0, -0.3, true);
    part(H, bgeo(0.04, 0.6, 0.04), this.crackMat, 0.96, 0.4, -0.3, 0.2, 0, 0, true);
    this.rubble = [];
    for (let k = 0; k < 5; k++) {
      const m = part(this.root, bgeo(rand(0.2, 0.35), rand(0.18, 0.3), rand(0.2, 0.35)), dark, 0, 0, 0);
      this.rubble.push({ m, a: (k / 5) * Math.PI * 2, r: rand(1.5, 1.9), y: rand(0.3, 1.8), s: rand(0.6, 1.1) });
    }
    this.addSphere(H, [0, 0.12, 0.05], 1.15, 'body');
    this.addSphere(H, [0, 0.2, -0.92], 0.42, 'head');
    // ışın: işaret çizgisi ve asıl ışın (dünya sahnesinde)
    this.laserMat = new THREE.MeshBasicMaterial({ color: 0xff3020, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false });
    this.laser = new THREE.Mesh(new THREE.BoxGeometry(1, 1, 1).translate(0, 0, 0.5), this.laserMat);
    this.laser.visible = false;
    this.game.scene.add(this.laser);
    this.aimPt = new THREE.Vector3();
  }

  think(dt) {
    const i = this.playerInfo();
    const aggro = difficulty().aggro;
    const p = this.game.player;
    this.atkCd -= dt;
    const wantY = Math.max(this.hoverY, p.pos.y + 3) + Math.sin(this.time * 1.3) * 0.35;
    this.vel.y = clamp((wantY - this.pos.y) * 2, -6, 6);
    switch (this.state) {
      case 'hover': {
        this.faceYaw(yawTo(i.dx, i.dz), 3, dt);
        this.strafeT -= dt;
        if (this.strafeT <= 0) { this.strafeT = rand(2, 4); this.strafeDir *= -1; }
        const want = i.dist > 26 ? 1 : i.dist < 12 ? -1 : 0;
        const sp = this.speed;
        this.accelTo(i.dx * want * sp - i.dz * this.strafeDir * sp * 0.6, i.dz * want * sp + i.dx * this.strafeDir * sp * 0.6, 8, dt);
        if (this.blocked > 0.3) { this.strafeDir *= -1; this.blocked = 0; }
        if (this.atkCd <= 0 && this.canSee && i.dist < 70) {
          this.setState(this.nextBeam ? 'beamWind' : 'volleyWind');
          this.nextBeam = !this.nextBeam;
          this.game.audio.play(this.state === 'beamWind' ? 'windup' : 'orbCharge', this.pos, { rate: 0.6, exactRate: true, range: 80 });
          this.aimPt.set(p.pos.x, p.pos.y + p.h * 0.5, p.pos.z);
        }
        break;
      }
      case 'volleyWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 5, dt);
        this.accelTo(0, 0, 8, dt);
        const dur = 0.85 / aggro;
        this.jawOpen = clamp(this.st / dur, 0, 1);
        this.mouthGlow.scale.setScalar(0.3 + this.jawOpen * 1.6);
        if (this.st >= dur) { this.state = 'volley'; this.st = 0; this.shots = 0; }
        break;
      }
      case 'volley': {
        this.faceYaw(yawTo(i.dx, i.dz), 4, dt);
        const n = 7;
        while (this.shots < n && this.st >= this.shots * 0.07) { this.fireOrb(this.shots, n); this.shots++; }
        if (this.st > n * 0.07 + 0.35) { this.setState('hover'); this.atkCd = rand(2.2, 3.4) / aggro; }
        break;
      }
      case 'beamWind': {
        this.accelTo(0, 0, 8, dt);
        const dur = 1.45 / aggro;
        const lock = dur - 0.38;
        if (this.st < lock) {
          this.faceYaw(yawTo(i.dx, i.dz), 4, dt);
          _v1.set(p.pos.x, p.pos.y + p.h * 0.5, p.pos.z);
          this.aimPt.lerp(_v1, 1 - Math.exp(-dt * 3.2));
        } else if (!this.locked) {
          this.locked = true;
          this.game.audio.play('glint', this.pos, { range: 80 });
        }
        this.jawOpen = clamp(this.st / dur, 0, 1) * 0.7;
        this.mouthGlow.scale.setScalar(0.3 + this.st * 1.4);
        this.showLaser(this.st >= lock ? 0.09 : 0.035, this.st >= lock ? 0xffffff : 0xff3020, this.st >= lock ? 1 : 0.55 + Math.sin(this.time * 40) * 0.25);
        if (this.st >= dur) { this.locked = false; this.fireBeam(); this.state = 'beam'; this.st = 0; }
        break;
      }
      case 'beam': {
        this.accelTo(0, 0, 8, dt);
        const k = 1 - this.st / 0.35;
        if (k > 0) this.showLaser(0.9 * k + 0.1, 0xffa060, k);
        else this.laser.visible = false;
        if (this.st > 0.7) { this.setState('hover'); this.atkCd = rand(2.6, 4) / aggro; }
        break;
      }
    }
  }

  setState(s) {
    super.setState(s);
    if (s !== 'beamWind' && s !== 'beam' && this.laser) this.laser.visible = false;
    this.locked = false;
    if (s === 'hover') this.mouthGlow.scale.setScalar(0.1);
  }

  mouthWorld(out = new THREE.Vector3()) {
    this.root.updateMatrixWorld(true);
    return this.mouth.getWorldPosition(out);
  }

  showLaser(w, color, alpha) {
    const from = this.mouthWorld(_v2);
    const dir = _d.subVectors(this.aimPt, from).normalize();
    const hit = this.game.world.raycast(from.x, from.y, from.z, dir.x, dir.y, dir.z, 150);
    const len = hit ? hit.t : 150;
    this.laser.visible = true;
    this.laser.position.copy(from);
    this.laser.lookAt(_v3.copy(from).add(dir));
    this.laser.scale.set(w, w, len);
    this.laserMat.color.setHex(color);
    this.laserMat.opacity = alpha;
    this.beamDir = dir.clone();
    this.beamLen = len;
  }

  fireBeam() {
    const game = this.game;
    const from = this.mouthWorld(new THREE.Vector3());
    const dir = this.beamDir || _d.subVectors(this.aimPt, from).normalize().clone();
    const len = this.beamLen || 150;
    const end = from.clone().addScaledVector(dir, len);
    const p = game.player;
    const pc = _v1.set(p.pos.x, p.pos.y + p.h * 0.5, p.pos.z);
    const t = clamp(_v2.subVectors(pc, from).dot(dir), 0, len);
    const closest = _v3.copy(from).addScaledVector(dir, t);
    if (closest.distanceTo(pc) < 1.0) game.damagePlayer(32 * difficulty().dmg, from);
    game.explode(end, 2.5, 0, { visualOnly: true });
    game.fx.sparkBurst(from, 20, 10, 0xffc080, 0.4, 0.08);
    game.flashLight(from, 0xff8040, 10, 20, 0.2);
    game.audio.play('rail', from, { rate: 0.7, exactRate: true, range: 100 });
    game.shake(0.25);
  }

  fireOrb(k, n) {
    const game = this.game;
    const p = game.player;
    const from = this.mouthWorld(new THREE.Vector3());
    const target = new THREE.Vector3(p.pos.x, p.pos.y + p.h * 0.5, p.pos.z);
    const speed = 23 * difficulty().speed;
    target.addScaledVector(p.vel, (from.distanceTo(target) / speed) * 0.3);
    const dir = target.sub(from).normalize();
    const spread = (k / (n - 1) - 0.5) * 0.5;
    const c = Math.cos(spread), sn = Math.sin(spread);
    const d = new THREE.Vector3(dir.x * c - dir.z * sn, dir.y + rand(-0.03, 0.03), dir.x * sn + dir.z * c).normalize();
    game.addProjectile(new Projectile(game, { pos: from, vel: d.multiplyScalar(speed), radius: 0.4, damage: 14 * difficulty().dmg, color: 0xff6a1a, source: this }));
    if (k === 0) game.audio.play('orbThrow', from, { rate: 0.7, exactRate: true });
  }

  onHurt() {
    this.head.rotation.z = rand(-0.1, 0.1);
  }

  animate(dt) {
    const H = this.head;
    const k = 1 - Math.exp(-10 * dt);
    if (this.state !== 'volleyWind' && this.state !== 'volley' && this.state !== 'beamWind') this.jawOpen = Math.max(0, this.jawOpen - dt * 2);
    this.jaw.rotation.x += (-this.jawOpen * 0.55 - this.jaw.rotation.x) * k;
    this.hr.x *= Math.exp(-8 * dt);
    this.hr.z *= Math.exp(-8 * dt);
    H.rotation.x = Math.sin(this.time * 0.9) * 0.05 + this.hr.x * 0.4;
    H.rotation.z = Math.sin(this.time * 0.7) * 0.06 + this.hr.z * 0.4;
    H.position.y = 1.1 + Math.sin(this.time * 1.7) * 0.06;
    for (const r of this.rubble) {
      const a = r.a + this.time * r.s;
      r.m.position.set(Math.cos(a) * r.r, r.y + Math.sin(this.time * 2 + r.a) * 0.15, Math.sin(a) * r.r);
      r.m.rotation.set(this.time * r.s, this.time * r.s * 0.7, 0);
    }
    const heat = this.state === 'beamWind' || this.state === 'volleyWind' ? 1 : 0.4;
    this.eyeMat.color.setRGB(1, 0.35 + heat * 0.3, 0.1 * heat);
  }

  die(info, wasFull, dmg) {
    if (this.laser) this.laser.visible = false;
    this.mouthGlow.visible = false;
    this.eyeMat.color.setHex(0x301008);
    super.die(info, wasFull, dmg);
  }

  // Ceset: kafa dönerek düşer, yere çarpınca patlar ve parçalanır
  updateCorpse(dt) {
    this.corpseT += dt;
    const game = this.game;
    this.vel.y -= G * dt;
    const r = game.world.moveBody(this, this.corpseVel.x * dt, this.vel.y * dt, this.corpseVel.z * dt);
    this.root.position.copy(this.pos);
    this.head.rotation.x += dt * 2.4 * this.fallSign;
    this.head.rotation.z += dt * 1.2;
    if (Math.random() < dt * 25) game.fx.smoke(this.center(), 1, 0x6a5a50, 0.7, 0.8, 1);
    if (r.ground || this.corpseT > 3.5 || this.pos.y < game.level.killY) {
      const c = this.center();
      game.explode(c, 5, 2.5, { playerDmg: 20, knock: 18, weapon: 'explosion' });
      this.root.updateMatrixWorld(true);
      const meshes = [];
      this.root.traverseVisible((o) => { if (o.isMesh && !o.userData.noGib) meshes.push(o); });
      for (const m of meshes) game.fx.gibFromMesh(m, new THREE.Vector3(rand(-1, 1), rand(0.5, 1.5), rand(-1, 1)).multiplyScalar(9));
      game.scene.remove(this.root);
      this.disposeLaser();
      return false;
    }
    return true;
  }

  disposeLaser() {
    if (!this.laser) return;
    this.game.scene.remove(this.laser);
    this.laser.geometry.dispose();
    this.laserMat.dispose();
    this.laser = null;
  }

  removeSilently() {
    this.disposeLaser();
    super.removeSilently();
    if (this.corpseT !== undefined) this.game.scene.remove(this.root);
  }
}

// ---------------------------------------------------------------------------
// CERBERUS: canlanan dev taş heykel (boss). Büyük küre fırlatır, yere vurup sarsıntı dalgası
// yollar (üstünden zıpla), parlayarak hücum eder (savuşturulabilir). İkiz heykel: biri
// yarı cana inince diğeri uyanır, biri ölünce öteki öfkelenir.
export class Cerberus extends Enemy {
  init(opts = {}) {
    const T = this.game.tex;
    this.type = 'cerberus';
    this.name = 'CERBERUS';
    this.maxHp = 32;
    this.r = 0.9;
    this.h = 4.0;
    this.big = true;
    this.boss = true;
    this.killPts = 600;
    this.knockMul = 0.15;
    this.parryDmg = 6;
    this.parryStun = 1.4;
    this.spawnDur = 0.9;
    this.baseSpeed = 5.2 * difficulty().speed;
    this.speed = this.baseSpeed;
    this.cdMul = 1;
    this.atkCd = 1.2;
    this.tint = 1;
    this.dormant = !!opts.dormant;
    this.firstState = this.dormant ? 'dormant' : 'roar';
    this.invuln = this.dormant;
    const stone = this.mat(T.stone, 0xd0c8ba, 0.08);
    const dark = this.mat(T.rock, 0x5e554c, 0.06);
    const H = (this.H = buildHumanoid({ skin: stone, dark, hunch: 0.06, torsoW: 0.64, torsoH: 0.72, torsoD: 0.38, headS: 0.32, armL: 1.12, legL: 1.05, scale: 1.9, taper: 0.72 }));
    const J = H.J, d = H.dims;
    this.crackMat = new THREE.MeshBasicMaterial({ color: 0x2a1e18 });
    this.eyeMat = new THREE.MeshBasicMaterial({ color: 0x1a1412 });
    // miğfer ve defne tacı
    part(J.head, bgeo(0.36, 0.14, 0.38), dark, 0, 0.36, 0);
    for (let k = 0; k < 7; k++) {
      const a = (k / 6 - 0.5) * 2.4;
      part(J.head, cgeo(0.04, 0.2, 4), dark, Math.sin(a) * 0.18, 0.46, Math.cos(a) * 0.12, -0.25, 0, -a * 0.5);
    }
    for (const x of [-0.075, 0.075]) part(J.head, bgeo(0.07, 0.04, 0.02), this.eyeMat, x, 0.2, -0.165, 0, 0, 0, true);
    part(J.head, bgeo(0.2, 0.06, 0.02), dark, 0, 0.08, -0.165); // ağız
    // omuzluklar, göğüs zırhı, peştamal
    for (const side of ['L', 'R']) {
      part(J['sh' + side], bgeo(0.3, 0.16, 0.36), dark, 0, 0.06, 0);
      part(J['sh' + side], cgeo(0.06, 0.22, 4), dark, 0, 0.2, 0);
    }
    part(J.spine, bgeo(d.torsoW * 0.9, d.torsoH * 0.35, 0.05), dark, 0, d.torsoH * 0.72, -d.torsoD / 2 - 0.02);
    part(J.hips, bgeo(0.42, 0.5, 0.05), dark, 0, -0.3, -0.16);
    part(J.hips, bgeo(0.42, 0.45, 0.05), dark, 0, -0.28, 0.16);
    // parlayan çatlaklar (uyanınca turuncu)
    const cr = (parent, x, y, z, h, rz) => part(parent, bgeo(0.025, h, 0.02), this.crackMat, x, y, z, 0, 0, rz, true);
    cr(J.spine, -0.12, d.torsoH * 0.5, -d.torsoD / 2 - 0.05, 0.4, 0.4);
    cr(J.spine, 0.1, d.torsoH * 0.3, -d.torsoD / 2 - 0.02, 0.3, -0.5);
    cr(J.spine, 0.2, d.torsoH * 0.62, -d.torsoD / 2 - 0.05, 0.22, 0.2);
    for (const side of ['L', 'R']) {
      cr(J['upper' + side], 0, 0, -0.06, 0.25, 0.3);
      cr(J['el' + side], 0, -0.15, -0.05, 0.2, -0.3);
      cr(J['kn' + side], 0, -0.2, -0.065, 0.25, 0.2);
    }
    // küre (sağ el)
    this.orb = new THREE.Group();
    this.orbCoreMat = new THREE.MeshBasicMaterial({ color: 0x6a5a4a });
    const core = new THREE.Mesh(new THREE.IcosahedronGeometry(0.2, 1), this.orbCoreMat);
    core.userData.noGib = true;
    this.orbGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0xff8a20, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0 }));
    this.orbGlow.scale.setScalar(1.4);
    this.orb.add(core, this.orbGlow);
    this.orb.position.set(0, -0.2, -0.04);
    J.haR.add(this.orb);
    this.root.add(H.root);
    this.humanoidSpheres(H, 1.9);
    if (this.dormant) this.setAwake(false);
  }

  setAwake(on) {
    this.crackMat.color.setHex(on ? (this.enraged ? 0xff3010 : 0xff8a20) : 0x2a1e18);
    this.eyeMat.color.setHex(on ? (this.enraged ? 0xff2010 : 0xffc040) : 0x1a1412);
    this.orbCoreMat.color.setHex(on ? 0xfff0c0 : 0x6a5a4a);
    this.orbGlow.material.opacity = on ? 1 : 0;
  }

  wake() {
    if (!this.dormant || this.dead) return;
    this.dormant = false;
    this.invuln = false;
    this.setAwake(true);
    this.setState('roar');
    const game = this.game;
    game.audio.play('bossRoar', this.pos);
    game.shake(0.5);
    game.fx.sparkBurst(this.center(), 40, 8, 0xff9a40, 0.8, 0.08);
    game.fx.smoke(this.pos.clone().setY(this.pos.y + 1), 8, 0x9a8a7a, 1.2, 1.2, 1);
    game.hud.message('CERBERUS UYANDI', 1.6);
  }

  enrage() {
    if (this.enraged || this.dead) return;
    this.enraged = true;
    this.speed = this.baseSpeed * 1.3;
    this.cdMul = 0.65;
    this.setAwake(true);
    this.game.audio.play('bossRoar', this.pos, { rate: 0.8, exactRate: true });
    this.game.style.add('ENRAGED', 50);
  }

  onHurt() {
    const pa = this.partner;
    if (pa && pa.dormant && this.hp < this.maxHp * 0.55) pa.wake();
  }

  think(dt) {
    const i = this.playerInfo();
    const aggro = difficulty().aggro;
    const cd = this.cdMul / aggro;
    if (this.state !== 'dormant' && this.state !== 'roar') this.atkCd -= dt;
    switch (this.state) {
      case 'dormant':
        this.accelTo(0, 0, 30, dt);
        break;
      case 'roar':
        this.accelTo(0, 0, 30, dt);
        this.faceYaw(yawTo(i.dx, i.dz), 4, dt);
        if (this.st > 1.1) { this.firstState = 'chase'; this.setState('chase'); this.atkCd = 0.6; }
        break;
      case 'chase': {
        this.faceYaw(yawTo(i.dx, i.dz), 5, dt);
        const sp = i.dist > 5 ? this.speed : 0;
        this.accelTo(i.dx * sp, i.dz * sp, 25, dt);
        if (this.atkCd <= 0) {
          const r = Math.random();
          if (i.dist < 4.2) { this.setState('swipeWind'); this.game.audio.play('windup', this.pos); }
          else if (r < 0.4 && this.canSee) { this.setState('orbWind'); this.game.audio.play('orbCharge', this.pos, { rate: 0.7, exactRate: true }); }
          else if (r < 0.7) { this.setState('stompWind'); this.game.audio.play('slamStart', this.pos, { rate: 0.6, exactRate: true }); }
          else if (this.canSee && i.dist > 6) { this.setState('tackleWind'); this.game.audio.play('windup', this.pos, { rate: 0.7, exactRate: true }); }
          else { this.setState('stompWind'); this.game.audio.play('slamStart', this.pos, { rate: 0.6, exactRate: true }); }
        }
        break;
      }
      case 'orbWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 7, dt);
        this.accelTo(0, 0, 30, dt);
        const dur = 0.8 * cd;
        this.orbGlow.scale.setScalar(1.4 + (this.st / dur) * 2);
        if (this.st >= dur) { this.throwOrb(); this.orbGlow.scale.setScalar(1.4); this.state = 'recover'; this.st = 0; this.atkCd = rand(1.5, 2.5) * cd; }
        break;
      }
      case 'stompWind': {
        this.accelTo(0, 0, 30, dt);
        if (this.st >= 0.65 * cd) { this.stomp(); this.state = 'recover'; this.st = 0; this.atkCd = rand(1.4, 2.4) * cd; }
        break;
      }
      case 'tackleWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 6, dt);
        this.accelTo(0, 0, 30, dt);
        const dur = 0.7 * cd;
        this.setParryable(this.st > dur - 0.4, this.headPos());
        if (this.st >= dur) {
          this.tackleDir = new THREE.Vector3(i.dx, 0, i.dz);
          this.tackleHit = false;
          this.state = 'tackle';
          this.st = 0;
          this.game.audio.play('dash', this.pos, { rate: 0.6, exactRate: true });
        }
        break;
      }
      case 'tackle': {
        const sp = 28 * difficulty().speed;
        this.vel.x = this.tackleDir.x * sp;
        this.vel.z = this.tackleDir.z * sp;
        this.setParryable(this.st < 0.2, this.headPos());
        if (!this.tackleHit && i.dist < 1.9 && Math.abs(i.dy) < 2.5) {
          this.tackleHit = true;
          if (this.game.damagePlayer(25 * difficulty().dmg, this.pos)) {
            const p = this.game.player;
            p.vel.x += this.tackleDir.x * 18;
            p.vel.z += this.tackleDir.z * 18;
            p.vel.y = Math.max(p.vel.y, 8);
          }
        }
        if (Math.random() < dt * 30) this.game.fx.smoke(this.pos.clone().setY(this.pos.y + 0.2), 1, 0x8a7a6a, 0.6, 0.5, 0.5);
        if (this.blocked > 0.05 && this.st > 0.1) {
          // duvara çarptı: sersemler
          this.game.shake(0.4);
          this.game.audio.play('slam', this.pos, { vol: 0.8 });
          this.stun = 1.1;
          this.vel.set(0, 0, 0);
          this.setState('stagger');
          this.atkCd = rand(1, 1.8) * cd;
        } else if (this.st > 0.75) { this.state = 'recover'; this.st = 0; this.setParryable(false); this.atkCd = rand(1.2, 2) * cd; }
        break;
      }
      case 'swipeWind': {
        this.faceYaw(yawTo(i.dx, i.dz), 8, dt);
        this.accelTo(0, 0, 30, dt);
        const dur = 0.5 * cd;
        this.setParryable(this.st > dur - 0.3, this.H.J.haL.getWorldPosition(new THREE.Vector3()));
        if (this.st >= dur) {
          this.setParryable(false);
          this.game.audio.play('swing', this.pos, { rate: 0.7, exactRate: true });
          this.meleeHit(4.4, 22, 0.1);
          this.state = 'recover';
          this.st = 0;
          this.atkCd = rand(0.9, 1.6) * cd;
        }
        break;
      }
      case 'recover':
        this.accelTo(0, 0, 30, dt);
        if (this.st > 0.5) this.setState('chase');
        break;
    }
  }

  throwOrb() {
    const game = this.game;
    const p = game.player;
    const from = this.orb.getWorldPosition(new THREE.Vector3());
    const speed = 24 * difficulty().speed;
    const target = new THREE.Vector3(p.pos.x, p.pos.y + p.h * 0.5, p.pos.z);
    target.addScaledVector(p.vel, (from.distanceTo(target) / speed) * 0.35);
    const dir = target.sub(from).normalize();
    game.addProjectile(new Projectile(game, { pos: from, vel: dir.multiplyScalar(speed), radius: 0.6, damage: 25 * difficulty().dmg, color: 0xff7a20, source: this }));
    game.audio.play('orbThrow', from, { rate: 0.6, exactRate: true });
  }

  stomp() {
    const game = this.game;
    const pos = this.pos.clone();
    game.shocks.push(new Shockwave(game, pos, { dmg: 20, speed: 17, max: 24, color: this.enraged ? 0xff3a20 : 0xff8a30 }));
    game.fx.ring(pos.clone(), 0xffb060, 5, 0.4, 0.05);
    game.fx.smoke(pos.clone().setY(pos.y + 0.3), 10, 0x9a8a7a, 1.4, 1, 0.8);
    game.fx.sparkBurst(pos.clone().setY(pos.y + 0.3), 30, 10, 0xffc080, 0.5, 0.08);
    game.audio.play('slam', pos, { rate: 0.7, exactRate: true, range: 80 });
    game.shake(clamp(0.7 - pos.distanceTo(game.player.pos) / 40, 0.15, 0.6));
    const i = this.playerInfo();
    if (i.dist < 3.2 && Math.abs(i.dy) < 1.5) game.damagePlayer(18 * difficulty().dmg, pos);
  }

  parried(dir) {
    super.parried(dir);
    if (!this.dead) this.game.audio.play('bossRoar', this.pos, { vol: 0.5, rate: 1.2, exactRate: true });
  }

  die(info, wasFull, dmg) {
    const pa = this.partner;
    super.die(info, wasFull, dmg);
    this.game.explode(this.center(), 4, 0, { visualOnly: true });
    this.game.hitstop(0.3);
    if (pa && !pa.dead) {
      if (pa.dormant) pa.wake();
      pa.enrage();
    }
  }

  animate(dt) {
    this.k = 1 - Math.exp(-12 * dt);
    const H = this.H, J = H.J;
    const hsp = Math.hypot(this.vel.x, this.vel.z);
    this.walkPhase += hsp * dt * 0.9;
    const amt = clamp(hsp / 5, 0, 1);
    switch (this.state) {
      case 'dormant':
        this.walkPose(H, 0, 0, 0);
        this.rot(J.shR, -1.2, 0, 0.2);
        this.rot(J.elR, 1.4);
        this.rot(J.shL, 0.1, 0, -0.15);
        this.rot(J.spine, 0.02);
        break;
      case 'roar':
        this.rot(J.spine, -0.35);
        this.rot(J.shL, -2.6, 0, -0.5);
        this.rot(J.shR, -2.6, 0, 0.5);
        this.rot(J.elL, 0.3); this.rot(J.elR, 0.3);
        this.walkPose(H, 0, 0, 0);
        break;
      case 'orbWind':
        this.rot(J.spine, -0.15, 0.5);
        this.rot(J.shR, -2.7, 0, 0.3);
        this.rot(J.elR, 0.6);
        this.rot(J.shL, 0.6, 0, -0.4);
        break;
      case 'stompWind': {
        const k = clamp(this.st / 0.65, 0, 1);
        this.rot(J.hipR, 1.2 * k);
        this.rot(J.knR, -1.5 * k);
        this.rot(J.spine, -0.15 * k);
        this.rot(J.shL, -0.8 * k, 0, -0.6);
        this.rot(J.shR, -0.8 * k, 0, 0.6);
        break;
      }
      case 'tackleWind':
        this.rot(J.spine, 0.55);
        this.rot(J.shL, 0.9, 0, -0.5);
        this.rot(J.shR, 0.9, 0, 0.5);
        this.rot(J.hipL, 0.6); this.rot(J.knL, -1.0);
        this.rot(J.hipR, -0.3); this.rot(J.knR, -0.5);
        break;
      case 'tackle':
        this.rot(J.spine, 0.7);
        this.rot(J.shL, -1.6, 0, -0.2);
        this.rot(J.shR, -1.6, 0, 0.2);
        this.walkPhase += dt * 14;
        this.walkPose(H, 1, 0, -1.6);
        break;
      case 'swipeWind':
        this.rot(J.spine, -0.1, -0.7);
        this.rot(J.shL, -1.8, 0, -1.2);
        this.rot(J.elL, 0.4);
        break;
      case 'recover':
      case 'stagger':
      case 'flinch':
        this.rot(J.spine, 0.25, 0.3);
        this.rot(J.shL, 0.3, 0, -0.3);
        this.rot(J.shR, 0.3, 0, 0.3);
        this.walkPose(H, 0, 0, 0);
        break;
      default:
        this.rot(J.spine, 0.05);
        this.walkPose(H, amt, 0.6, 0.1);
        this.rot(J.shR, -1.0, 0, 0.2);
        this.rot(J.elR, 1.2);
        this.breathe(H, 0.02);
    }
  }
}

export const ENEMY_TYPES = { filth: Filth, stray: Stray, schism: Schism, swordsmachine: Swordsmachine, trainer: Trainer, maliciousface: MaliciousFace, cerberus: Cerberus };
