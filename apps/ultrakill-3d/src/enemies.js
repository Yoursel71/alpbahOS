// Düşmanlar: Filth, Stray, Schism ve boss Swordsmachine.
// Modeller eklem hiyerarşisiyle kutulardan kurulur; animasyonlar prosedüreldir.
import * as THREE from 'three';
import { psx } from './render.js';
import { clamp, rand, chance, wrapAngle, yawTo, damp } from './util.js';
import { difficulty } from './settings.js';
import { Projectile } from './projectiles.js';

const G = 35;
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

export function buildHumanoid(o) {
  const { skin, dark, hunch = 0.3, torsoW = 0.42, torsoH = 0.55, torsoD = 0.26, headS = 0.3, armL = 1, legL = 1, scale = 1 } = o;
  const root = new THREE.Group();
  const J = {};
  const meshes = [];
  const thigh = 0.42 * legL, shin = 0.43 * legL;
  const hipY = thigh + shin + 0.06;
  J.hips = joint(root, 0, hipY, 0);
  J.pelvis = limb(J.hips, torsoW * 0.8, 0.2, torsoD * 0.85, skin, 0, meshes);
  J.spine = joint(J.hips, 0, 0.06, 0);
  J.spine.rotation.x = -hunch;
  J.torso = limb(J.spine, torsoW, torsoH, torsoD, skin, torsoH / 2, meshes);
  J.neck = joint(J.spine, 0, torsoH, 0);
  J.neck.rotation.x = hunch * 0.8;
  J.head = joint(J.neck, 0, 0.02, 0);
  J.headMesh = limb(J.head, headS, headS * 1.1, headS, skin, headS * 0.55, meshes);
  for (const side of [-1, 1]) {
    const s = side < 0 ? 'L' : 'R';
    const sh = (J['sh' + s] = joint(J.spine, side * (torsoW / 2 + 0.07), torsoH - 0.07, 0));
    J['upper' + s] = limb(sh, 0.11, 0.36 * armL, 0.11, skin, undefined, meshes);
    const el = (J['el' + s] = joint(sh, 0, -0.36 * armL, 0));
    J['fore' + s] = limb(el, 0.095, 0.34 * armL, 0.095, skin, undefined, meshes);
    const ha = (J['ha' + s] = joint(el, 0, -0.34 * armL, 0));
    J['hand' + s] = limb(ha, 0.11, 0.13, 0.11, dark, -0.05, meshes);
    const hip = (J['hip' + s] = joint(J.hips, side * torsoW * 0.26, -0.04, 0));
    limb(hip, 0.14, thigh, 0.14, skin, undefined, meshes);
    const kn = (J['kn' + s] = joint(hip, 0, -thigh, 0));
    limb(kn, 0.12, shin, 0.12, skin, undefined, meshes);
    const ft = (J['ft' + s] = joint(kn, 0, -shin, 0));
    const foot = limb(ft, 0.13, 0.07, 0.24, dark, 0, meshes);
    foot.position.z = -0.05;
  }
  root.scale.setScalar(scale);
  return { root, J, meshes, hipY, dims: { thigh, shin, torsoH, headS, torsoW, armL } };
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
    this.root = new THREE.Group();
    this.init(opts);
    this.hp = this.maxHp;
    this.root.position.copy(this.pos);
    this.root.rotation.y = this.yaw;
    game.scene.add(this.root);
    if (!this.decor) game.fx.spawnFX(this.pos, this.h);
    else { this.state = 'idle'; }
  }

  mat(map, color) {
    const m = psx(new THREE.MeshLambertMaterial({ map, color, emissive: 0x000000 }));
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
    // kaba küre testi
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
      // Kafa küreleri öncelikli: eşit mesafede kafayı seç
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

  // Oyuncuya yakın dövüş vuruşu
  meleeHit(range, dmg, arc = 0.2) {
    const i = this.playerInfo();
    if (i.dist > range || Math.abs(i.dy + 0.5) > 2.6) return false;
    const f = this.forward();
    if (f.x * i.dx + f.z * i.dz < arc) return false;
    return this.game.damagePlayer(dmg * difficulty().dmg, this.center(), false, this);
  }

  glint(pos) {
    const game = this.game;
    const s = game.fx.sprite(pos || this.headPos(), 0x9fe0ff, 2.2, 0.35, 'star', 1.6);
    s.material.depthTest = false;
    game.audio.play('glint', pos || this.pos);
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
      this.root.scale.set(1, 0.2 + 0.8 * k, 1);
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
    this.root.position.copy(this.pos);
    this.root.rotation.y = this.yaw;
    this.animate(dt);
    this.updateFlash();
    this.updateSpheres();
  }

  setState(s) {
    this.state = s;
    this.st = 0;
    if (s !== 'windup' && s !== 'attack') this.setParryable(false);
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
    this.grounded = grounded;
    if (grounded) this.vel.y = 0;
    const kd = Math.exp(-dt * (grounded ? 7 : 1.5));
    this.knock.x *= kd;
    this.knock.z *= kd;
    // tehlikeler
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
      const k = 0.35 + Math.sin(this.time * 40) * 0.2;
      r = Math.max(r, 0.15 * k); g = Math.max(g, 0.45 * k); b = Math.max(b, 0.9 * k);
    }
    if (this.enraged) r = Math.max(r, 0.35 + Math.sin(this.time * 10) * 0.1);
    // hafif öz aydınlatma: karanlık arenalarda siluet okunur kalsın
    const base = this.baseGlow ?? 0.1;
    r = Math.max(r, base); g = Math.max(g, base * 0.85); b = Math.max(b, base * 0.8);
    for (const m of this.mats) m.emissive.setRGB(r, g, b);
  }

  hit(info) {
    if (this.dead) return;
    const game = this.game;
    let dmg = info.dmg;
    if (info.part === 'head') dmg *= info.headMult ?? 2;
    if (this.invuln) {
      game.fx.sparkBurst(info.point || this.center(), 6, 6, 0xffffff, 0.2, 0.05);
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
    const pt = info.point || this.center();
    game.fx.bloodBurst(pt, Math.min(45, 6 + Math.round(dmg * 10)), 5 + Math.min(dmg, 4) * 2, info.dir || null);
    if (!info.noHeal) game.bloodHeal(pt, dmg);
    const w = info.weapon;
    const fw = w === 'revolver' || w === 'shotgun' || w === 'rail' ? w : null;
    game.style.addRaw(Math.min(dmg, 6) * 18, fw);
    if (!this.grounded && this.state !== 'spawn' && !this.flying && w !== 'lava') game.style.add('AIRSHOT', 35, fw);
    game.audio.play(info.part === 'head' ? 'headshot' : 'enemyHit', pt);
    game.hud.hitmarker(this.hp <= 0);
    if (this.hp <= 0) this.die(info, wasFull, dmg);
    else this.onHurt(info, dmg);
  }

  onHurt() {}

  die(info, wasFull = false, dmg = 0) {
    if (this.dead) return;
    this.dead = true;
    this.parryable = false;
    const game = this.game;
    const w = info.weapon;
    const fw = w === 'revolver' || w === 'shotgun' || w === 'rail' ? w : null;
    for (const m of this.mats) m.emissive.setRGB(0, 0, 0);
    const c = this.center();
    const dir = info.dir ? info.dir.clone() : new THREE.Vector3();
    const force = info.explosion ? 12 : 4 + Math.min(info.knock || 0, 20) * 0.4;
    this.root.updateMatrixWorld(true);
    const meshes = [];
    this.root.traverseVisible((o) => { if (o.isMesh && !o.userData.noGib) meshes.push(o); });
    for (const m of meshes) {
      const v = new THREE.Vector3(rand(-1, 1), rand(0.3, 1.4), rand(-1, 1)).multiplyScalar(force * rand(0.4, 1)).addScaledVector(dir, force * 0.8);
      game.fx.gibFromMesh(m, v);
    }
    const gore = this.big ? 10 : 4;
    for (let i = 0; i < gore; i++) {
      game.fx.gibChunk(c.clone().add(new THREE.Vector3(rand(-0.3, 0.3), rand(-0.3, 0.3), rand(-0.3, 0.3))), new THREE.Vector3(rand(-6, 6), rand(3, 9), rand(-6, 6)), rand(0.08, 0.2), game.goreMat);
    }
    game.fx.bloodBurst(c, this.big ? 90 : 45, this.big ? 14 : 10, null, true);
    game.scene.remove(this.root);
    if (!info.silent) {
      game.audio.play('gore', c);
      if (!info.noHeal) game.bloodHeal(c, this.big ? 3 : 1.5);
      game.style.add(this.big ? 'BIG KILL' : null, this.killPts, fw);
      if (info.part === 'head' && w !== 'lava') game.style.add(this.big ? 'BIG HEADSHOT' : 'HEADSHOT', this.big ? 120 : 60, fw);
      if (info.explosion) game.style.add('FRIED', 60, fw);
      if (wasFull && this.big && dmg >= this.maxHp) game.style.add('INSTAKILL', 100, fw);
      if (w === 'punch') game.style.add('SPLATTERED', 60, null);
      game.style.onKill(fw, this);
    }
    game.onEnemyKilled(this, info);
  }

  // Oyuncu yakın saldırıyı savuşturdu
  parried(dir) {
    this.parryable = false;
    this.stun = this.parryStun || 0.9;
    this.hit({ dmg: this.parryDmg || 4, part: 'body', point: this.center(), dir, knock: 16, weapon: 'parry' });
    if (!this.dead && this.state !== 'enrage') this.setState('stagger');
  }

  removeSilently() {
    if (this.dead) return;
    this.dead = true;
    this.game.scene.remove(this.root);
  }

  // yardımcı: eklemi hedef açıya yumuşak döndür
  rot(j, x, y = 0, z = 0) {
    const k = this.k;
    j.rotation.x += (x - j.rotation.x) * k;
    j.rotation.y += (y - j.rotation.y) * k;
    j.rotation.z += (z - j.rotation.z) * k;
  }

  walkPose(H, amt, armSwing = 1, armBase = 0, dt) {
    const s = Math.sin(this.walkPhase), c = Math.cos(this.walkPhase);
    const J = H.J;
    this.rot(J.hipL, s * 0.75 * amt);
    this.rot(J.hipR, -s * 0.75 * amt);
    this.rot(J.knL, -Math.max(0, c) * 1.2 * amt);
    this.rot(J.knR, -Math.max(0, -c) * 1.2 * amt);
    this.rot(J.shL, armBase - s * 0.6 * amt * armSwing, 0, -0.08);
    this.rot(J.shR, armBase + s * 0.6 * amt * armSwing, 0, 0.08);
    this.rot(J.elL, 0.35 + 0.3 * amt);
    this.rot(J.elR, 0.35 + 0.3 * amt);
    J.hips.position.y = H.hipY + Math.abs(c) * 0.06 * amt - 0.03 * amt;
  }

  airPose(H) {
    const J = H.J;
    this.rot(J.hipL, 0.9);
    this.rot(J.hipR, 0.4);
    this.rot(J.knL, -1.3);
    this.rot(J.knR, -0.9);
  }
}

// ---------------------------------------------------------------------------
// FILTH: kambur, hızlı yakın dövüşçü. Zıplar, ısırır.
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
    const skin = this.mat(T.skin, 0xd0c4b0);
    const dark = this.mat(T.skin, 0x4a3a34);
    this.H = buildHumanoid({ skin, dark, hunch: 0.6, torsoW: 0.4, torsoH: 0.5, headS: 0.3, armL: 1.3, legL: 0.95 });
    const J = this.H.J;
    // ağız ve göz çukurları
    const black = new THREE.MeshBasicMaterial({ color: 0x100404 });
    const mouth = new THREE.Mesh(bgeo(0.2, 0.12, 0.02), black);
    mouth.position.set(0, 0.1, -0.155);
    mouth.userData.noGib = true;
    J.head.add(mouth);
    this.jaw = joint(J.head, 0, 0.05, -0.02);
    limb(this.jaw, 0.24, 0.06, 0.26, dark, -0.03);
    for (const x of [-0.07, 0.07]) {
      const e = new THREE.Mesh(bgeo(0.06, 0.05, 0.02), black);
      e.position.set(x, 0.22, -0.155);
      e.userData.noGib = true;
      J.head.add(e);
    }
    this.root.add(this.H.root);
    this.humanoidSpheres(this.H, 1);
  }

  think(dt) {
    const i = this.playerInfo();
    const aggro = difficulty().aggro;
    this.jumpCd -= dt;
    this.atkCd -= dt;
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
        }
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
        if (this.st > 0.4) { this.setState('recover'); }
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
    if (this.state === 'windup') {
      this.rot(J.spine, -0.25);
      this.rot(J.shL, 2.7, 0, -0.3);
      this.rot(J.shR, 2.7, 0, 0.3);
      this.rot(J.elL, 0.6);
      this.rot(J.elR, 0.6);
      this.rot(J.hipL, 0.3); this.rot(J.hipR, -0.3);
      this.rot(J.knL, -0.5); this.rot(J.knR, -0.4);
      jawOpen = 0.6;
    } else if (this.state === 'attack') {
      this.rot(J.spine, -1.0);
      this.rot(J.shL, 0.5, 0, -0.1);
      this.rot(J.shR, 0.5, 0, 0.1);
      this.rot(J.elL, 0.2);
      this.rot(J.elR, 0.2);
      jawOpen = 0.8;
    } else if (this.state === 'idle') {
      const b = Math.sin(this.time * 2) * 0.05;
      this.rot(J.spine, -0.6 + b);
      this.walkPose(H, 0, 0, 0.3);
      this.rot(J.neck, 0.5 + Math.sin(this.time * 0.7) * 0.2, Math.sin(this.time * 0.5) * 0.4);
    } else {
      this.rot(J.spine, -0.6 - amt * 0.15);
      this.walkPose(H, amt, 1.2, 0.5 + amt * 0.3);
      if (!this.grounded && this.state !== 'spawn') this.airPose(H);
      jawOpen = 0.2 + Math.abs(Math.sin(this.time * 6)) * 0.15;
    }
    if (this.state === 'stagger') { this.rot(J.spine, 0.2); this.rot(J.shL, -0.4); this.rot(J.shR, -0.4); }
    this.jaw.rotation.x = -jawOpen;
  }
}

// ---------------------------------------------------------------------------
// STRAY: mesafeyi koruyup parlayan küre fırlatır (küre savuşturulabilir).
export class Stray extends Enemy {
  init() {
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
    const skin = this.mat(T.skin, 0xa89c8c);
    const dark = this.mat(T.skin, 0x3a2c2a);
    this.H = buildHumanoid({ skin, dark, hunch: 0.22, torsoW: 0.36, torsoH: 0.58, headS: 0.27, armL: 1.08, legL: 1.1, scale: 1.05 });
    const J = this.H.J;
    const black = new THREE.MeshBasicMaterial({ color: 0x100404 });
    for (const x of [-0.065, 0.065]) {
      const e = new THREE.Mesh(bgeo(0.05, 0.04, 0.02), new THREE.MeshBasicMaterial({ color: 0xffb040 }));
      e.position.set(x, 0.2, -0.14);
      e.userData.noGib = true;
      J.head.add(e);
    }
    const mouth = new THREE.Mesh(bgeo(0.14, 0.05, 0.02), black);
    mouth.position.set(0, 0.08, -0.14);
    mouth.userData.noGib = true;
    J.head.add(mouth);
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

  throwOrb() {
    const game = this.game;
    const p = game.player;
    const from = new THREE.Vector3();
    this.orb.getWorldPosition(from);
    const speed = 27 * difficulty().speed;
    const target = new THREE.Vector3(p.pos.x, p.pos.y + p.h * 0.6, p.pos.z);
    const t = from.distanceTo(target) / speed;
    target.addScaledVector(p.vel, t * 0.4);
    const dir = target.sub(from).normalize();
    game.addProjectile(new Projectile(game, { pos: from, vel: dir.multiplyScalar(speed), radius: 0.35, damage: 25 * difficulty().dmg, color: 0xff8a20, source: this }));
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
      this.rot(J.spine, -0.05, 0.35);
      this.rot(J.shR, -2.5, 0, 0.3);
      this.rot(J.elR, 0.9);
      this.rot(J.shL, 0.6, 0, -0.4);
    } else if (this.state === 'throw') {
      this.rot(J.spine, -0.45, -0.3);
      this.rot(J.shR, 1.5, 0, 0.1);
      this.rot(J.elR, 0.1);
      this.rot(J.shL, -0.3);
    } else {
      this.rot(J.spine, -0.22, 0);
      this.walkPose(H, amt, 0.8, 0.1);
      if (!this.grounded && this.state !== 'spawn') this.airPose(H);
      this.rot(J.neck, 0.18, Math.sin(this.time * 1.3) * 0.2);
    }
    if (this.state === 'stagger') this.rot(J.spine, 0.3);
  }
}

// ---------------------------------------------------------------------------
// SCHISM: bıçak kollu, yatay/dikey mermi dizisi ateşler; yakında savurma yapar.
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
    const skin = this.mat(T.skin, 0x8c8478);
    const dark = this.mat(T.skin, 0x3a2a26);
    this.H = buildHumanoid({ skin, dark, hunch: 0.16, torsoW: 0.54, torsoH: 0.64, torsoD: 0.32, headS: 0.3, armL: 1.12, legL: 1.1, scale: 1.2 });
    const J = this.H.J;
    J.foreL.visible = false;
    J.handL.visible = false;
    const bladeMat = this.mat(T.bone, 0xd8d0c0);
    const blade = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.13, 1.35, 5), bladeMat);
    blade.position.y = -0.67;
    J.elL.add(blade);
    this.tip = joint(J.elL, 0, -1.35, 0);
    const tipGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0xffd040, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    tipGlow.scale.setScalar(0.5);
    this.tipGlow = tipGlow;
    this.tip.add(tipGlow);
    // omuz dikenleri
    for (const x of [-0.2, 0, 0.2]) {
      const sp = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.28, 4), dark);
      sp.position.set(x, 0.66, 0.12);
      sp.rotation.x = 0.5;
      J.spine.add(sp);
    }
    const black = new THREE.MeshBasicMaterial({ color: 0x100404 });
    for (const x of [-0.07, 0.07]) {
      const e = new THREE.Mesh(bgeo(0.06, 0.04, 0.02), new THREE.MeshBasicMaterial({ color: 0xffe060 }));
      e.position.set(x, 0.21, -0.155);
      e.userData.noGib = true;
      J.head.add(e);
    }
    const mouth = new THREE.Mesh(bgeo(0.16, 0.06, 0.02), black);
    mouth.position.set(0, 0.08, -0.155);
    mouth.userData.noGib = true;
    J.head.add(mouth);
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
        if (this.st >= dur) { this.state = 'attack'; this.st = 0; this.hitDone = false; }
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
    game.audio.play('schismShot', from);
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
    } else {
      this.rot(J.spine, -0.16, 0);
      this.walkPose(H, amt, 0.6, 0.05);
      this.rot(J.shL, 0.5 - Math.sin(this.walkPhase) * 0.3 * amt, 0, -0.15);
      this.rot(J.elL, 0.4);
    }
    if (this.state === 'stagger') this.rot(J.spine, 0.35);
  }
}

// ---------------------------------------------------------------------------
// SWORDSMACHINE (boss): kılıç kombosu (son vuruş savuşturulabilir), kılıç fırlatma,
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
    const metal = this.mat(T.machine, 0x9aa0aa);
    const dark = this.mat(T.machine, 0x3a3c42);
    const H = (this.H = buildHumanoid({ skin: metal, dark, hunch: 0.1, torsoW: 0.58, torsoH: 0.64, torsoD: 0.34, headS: 0.3, armL: 1.08, legL: 1.08, scale: 1.32 }));
    const J = H.J;
    const orange = new THREE.MeshBasicMaterial({ color: 0xffa020 });
    this.visorMat = orange;
    const visor = new THREE.Mesh(bgeo(0.26, 0.06, 0.02), orange);
    visor.position.set(0, 0.2, -0.16);
    visor.userData.noGib = true;
    J.head.add(visor);
    const core = new THREE.Mesh(bgeo(0.16, 0.16, 0.04), orange);
    core.position.set(0, 0.42, -0.18);
    core.userData.noGib = true;
    J.spine.add(core);
    for (const side of ['L', 'R']) {
      const pad = new THREE.Mesh(bgeo(0.24, 0.13, 0.3), dark);
      pad.position.set(0, 0.03, 0);
      J['sh' + side].add(pad);
    }
    // kılıç (zincirli testere kılıcı)
    const sword = new THREE.Group();
    const bladeMat = this.mat(T.metal, 0xc8ccd4);
    const hilt = new THREE.Mesh(bgeo(0.06, 0.22, 0.06), dark);
    hilt.position.y = -0.06;
    const guard = new THREE.Mesh(bgeo(0.28, 0.05, 0.1), dark);
    guard.position.y = -0.18;
    const blade = new THREE.Mesh(bgeo(0.05, 1.35, 0.2), bladeMat);
    blade.position.y = -0.88;
    const edge = new THREE.Mesh(bgeo(0.055, 1.3, 0.025), orange);
    edge.position.set(0, -0.88, -0.11);
    sword.add(hilt, guard, blade, edge);
    for (let k = 0; k < 9; k++) {
      const tooth = new THREE.Mesh(bgeo(0.03, 0.06, 0.05), dark);
      tooth.position.set(0, -0.3 - k * 0.14, -0.13);
      tooth.userData.noGib = true;
      sword.add(tooth);
    }
    sword.rotation.x = Math.PI / 2;
    J.haR.add(sword);
    this.sword = sword;
    // pompalı tüfek (sol elde, kullanırken görünür)
    const gun = new THREE.Group();
    const gb = new THREE.Mesh(bgeo(0.12, 0.62, 0.14), dark);
    gb.position.y = -0.28;
    const gbar = new THREE.Mesh(bgeo(0.07, 0.3, 0.07), metal);
    gbar.position.set(0, -0.62, -0.02);
    gun.add(gb, gbar);
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
          if (i.dist < 4.5 && this.hasSword) { this.combo = 0; this.setState('swingWind'); }
          else if (i.dist > 11 && this.hasSword && chance(0.45)) { this.setState('throwWind'); this.game.audio.play('windup', this.pos); }
          else if (chance(0.5) || !this.hasSword) { this.setState('gunWind'); this.gun.visible = true; this.game.audio.play('windup', this.pos); }
          else if (this.hasSword) { this.setState('dash'); }
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
          if (this.meleeHit(4.3, 25, 0.15)) { this.hitDone = true; this.game.fx.bloodBurst(this.game.player.eyePos(), 10, 6); }
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
    this.game.hud.boss(this.name, this.hp / this.maxHp, this.enraged);
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
    game.flashLight(from, 0xffb040, 8, 18, 0.08);
    game.audio.play('bossShotgun', from);
  }

  parried(dir) {
    super.parried(dir);
    if (!this.dead) this.game.audio.play('bossRoar', this.pos, { vol: 0.5 });
  }

  die(info, wasFull, dmg) {
    this.game.hud.boss(null);
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

export const ENEMY_TYPES = { filth: Filth, stray: Stray, schism: Schism, swordsmachine: Swordsmachine };
