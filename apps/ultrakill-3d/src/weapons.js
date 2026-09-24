// Silahlar ve görünür silah modelleri (viewmodel):
// Revolver (Piercer / Marksman), Shotgun (Core Eject / Pump Charge), Railcannon,
// ve Feedbacker kolu (yumruk + parry).
import * as THREE from 'three';
import { clamp, damp, rand } from './util.js';
import { Coin, Projectile } from './projectiles.js';
import { settings } from './settings.js';

export const WEAPONS = [
  { id: 'revolver', name: 'REVOLVER', key: '1', variants: [{ id: 'piercer', name: 'PIERCER', color: 0x3aa0ff }, { id: 'marksman', name: 'MARKSMAN', color: 0x3ee06a }] },
  { id: 'shotgun', name: 'SHOTGUN', key: '2', variants: [{ id: 'core', name: 'CORE EJECT', color: 0x3aa0ff }, { id: 'pump', name: 'PUMP CHARGE', color: 0x3ee06a }] },
  { id: 'rail', name: 'RAILCANNON', key: '3', variants: [{ id: 'electric', name: 'ELECTRIC', color: 0x3aeaff }] },
];

const RAIL_TIME = 12;
const COIN_TIME = 2.2;

function box(w, h, d, mat, x = 0, y = 0, z = 0, parent = null) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  m.position.set(x, y, z);
  if (parent) parent.add(m);
  return m;
}

function cylZ(r1, r2, len, mat, x, y, z, parent, seg = 10) {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(r1, r2, len, seg), mat);
  m.rotation.x = Math.PI / 2;
  m.position.set(x, y, z);
  if (parent) parent.add(m);
  return m;
}

const easeOut = (t) => 1 - Math.pow(1 - clamp(t, 0, 1), 3);

export class Weapons {
  constructor(game) {
    this.game = game;
    const T = game.tex;
    this.scene = new THREE.Scene();
    this.cam = new THREE.PerspectiveCamera(60, 1, 0.01, 20);
    this.scene.add(new THREE.HemisphereLight(0xffe8d8, 0x402020, 2.2));
    const dl = new THREE.DirectionalLight(0xffd0b0, 2.2);
    dl.position.set(-1, 2, 1);
    this.scene.add(dl);
    this.flashLightVM = new THREE.PointLight(0xffc070, 0, 3, 1);
    this.flashLightVM.position.set(0.25, -0.1, -0.9);
    this.scene.add(this.flashLightVM);

    this.M = {
      gun: new THREE.MeshLambertMaterial({ map: T.metal, color: 0x9aa0ae }),
      dark: new THREE.MeshLambertMaterial({ color: 0x2a2c33 }),
      grip: new THREE.MeshLambertMaterial({ map: T.rock, color: 0x9a7a6a }),
      arm: new THREE.MeshLambertMaterial({ map: T.machine, color: 0xa0a8b8 }),
      blue: new THREE.MeshLambertMaterial({ map: T.metal, color: 0x4a8cff, emissive: 0x08204a }),
    };
    this.accents = [new THREE.MeshBasicMaterial({ color: 0x3aa0ff }), new THREE.MeshBasicMaterial({ color: 0x3aa0ff }), new THREE.MeshBasicMaterial({ color: 0x3aeaff })];
    this.coilMat = new THREE.MeshBasicMaterial({ color: 0x3aeaff });
    this.meterMat = new THREE.MeshBasicMaterial({ color: 0x3aeaff });

    this.models = [this.buildRevolver(), this.buildShotgun(), this.buildRail()];
    for (const m of this.models) this.scene.add(m.group);
    this.arm = this.buildArm();
    this.scene.add(this.arm);

    this.flash = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.star, color: 0xffe0a0, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, depthTest: false }));
    this.flash.visible = false;
    this.scene.add(this.flash);

    this.reset();
  }

  reset() {
    this.cur = 0;
    this.last = 1;
    this.variant = [0, 0, 0];
    this.switchT = 1;
    this.switchTime = -10;
    this.cd = [0, 0, 0];
    this.pierceCharge = 0;
    this.pierceReady = false;
    this.coinCharges = 4;
    this.coreCharge = 0;
    this.pumps = 0;
    this.pumpAnim = 1;
    this.railCharge = 1;
    this.railWasReady = true;
    this.punchT = 1;
    this.punchCd = 0;
    this.recoil = 0;
    this.swayX = 0;
    this.swayY = 0;
    this.flashT = 0;
    this.drumAngle = 0;
    this.drumTarget = 0;
    for (const c of this.coins || []) c.kill();
    this.coins = [];
    this.updateAccents();
  }

  resize(aspect) {
    this.cam.aspect = aspect;
    this.cam.updateProjectionMatrix();
  }

  // ---- Modeller ----
  buildRevolver() {
    const M = this.M, A = this.accents[0];
    const g = new THREE.Group();
    const gun = new THREE.Group();
    g.add(gun);
    box(0.07, 0.1, 0.26, M.gun, 0, 0.02, -0.06, gun);
    cylZ(0.024, 0.024, 0.34, M.dark, 0, 0.052, -0.34, gun);
    box(0.028, 0.02, 0.34, M.gun, 0, 0.08, -0.34, gun);
    box(0.012, 0.028, 0.02, M.dark, 0, 0.098, -0.5, gun);
    const drum = new THREE.Group();
    drum.position.set(0, 0.02, -0.075);
    gun.add(drum);
    cylZ(0.056, 0.056, 0.12, M.gun, 0, 0, 0, drum, 6);
    for (let k = 0; k < 3; k++) {
      const s = box(0.02, 0.012, 0.125, A, 0, 0, 0, drum);
      const a = (k / 3) * Math.PI * 2;
      s.position.set(Math.cos(a) * 0.052, Math.sin(a) * 0.052, 0);
      s.rotation.z = a;
    }
    const hammer = box(0.024, 0.05, 0.04, M.dark, 0, 0.085, 0.07, gun);
    hammer.rotation.x = -0.4;
    const grip = box(0.058, 0.17, 0.085, M.grip, 0, -0.085, 0.09, gun);
    grip.rotation.x = -0.3;
    box(0.012, 0.05, 0.07, M.dark, 0, -0.04, 0, gun);
    box(0.074, 0.024, 0.13, A, 0, 0.035, -0.07, gun);
    const muzzle = new THREE.Object3D();
    muzzle.position.set(0, 0.052, -0.53);
    gun.add(muzzle);
    const fore = box(0.1, 0.1, 0.36, M.arm, 0.01, -0.14, 0.3, g);
    fore.rotation.x = -0.35;
    box(0.09, 0.09, 0.12, M.arm, 0, -0.07, 0.09, g);
    g.position.set(0.27, -0.27, -0.55);
    return { group: g, gun, muzzle, drum, hammer, base: new THREE.Vector3(0.27, -0.27, -0.55), ry: 0.04 };
  }

  buildShotgun() {
    const M = this.M, A = this.accents[1];
    const g = new THREE.Group();
    const gun = new THREE.Group();
    g.add(gun);
    box(0.1, 0.12, 0.34, M.gun, 0, 0, -0.05, gun);
    cylZ(0.033, 0.033, 0.62, M.dark, 0, 0.035, -0.52, gun);
    cylZ(0.026, 0.026, 0.46, M.dark, 0, -0.03, -0.45, gun);
    const pump = box(0.085, 0.075, 0.2, M.grip, 0, -0.03, -0.4, gun);
    const stock = box(0.075, 0.11, 0.32, M.grip, 0, -0.05, 0.26, gun);
    stock.rotation.x = 0.12;
    const core = box(0.104, 0.05, 0.12, A, 0, 0.01, -0.02, gun);
    box(0.02, 0.012, 0.5, A, 0, 0.058, -0.45, gun);
    const muzzle = new THREE.Object3D();
    muzzle.position.set(0, 0.035, -0.84);
    gun.add(muzzle);
    const fore = box(0.1, 0.1, 0.36, M.arm, 0.02, -0.15, 0.32, g);
    fore.rotation.x = -0.3;
    g.position.set(0.28, -0.32, -0.62);
    return { group: g, gun, muzzle, pump, core, base: new THREE.Vector3(0.28, -0.32, -0.62), ry: 0.05 };
  }

  buildRail() {
    const M = this.M, A = this.accents[2];
    const g = new THREE.Group();
    const gun = new THREE.Group();
    g.add(gun);
    box(0.15, 0.15, 0.5, M.gun, 0, 0, -0.15, gun);
    box(0.12, 0.14, 0.16, M.dark, 0, 0.01, 0.17, gun);
    const meter = box(0.03, 0.022, 0.13, this.meterMat, 0, 0.09, 0.17, gun);
    for (const [x, y] of [[0, 0.095], [-0.085, -0.045], [0.085, -0.045]]) box(0.022, 0.022, 0.74, M.dark, x, y, -0.52, gun);
    const coils = [];
    for (const z of [-0.34, -0.5, -0.66]) {
      const c = new THREE.Mesh(new THREE.TorusGeometry(0.1, 0.02, 6, 14), this.coilMat);
      c.position.set(0, 0.01, z);
      gun.add(c);
      coils.push(c);
    }
    box(0.155, 0.02, 0.3, A, 0, -0.07, -0.12, gun);
    const muzzle = new THREE.Object3D();
    muzzle.position.set(0, 0.01, -0.9);
    gun.add(muzzle);
    const fore = box(0.1, 0.1, 0.36, M.arm, 0.03, -0.16, 0.34, g);
    fore.rotation.x = -0.3;
    g.position.set(0.3, -0.33, -0.66);
    return { group: g, gun, muzzle, coils, meter, base: new THREE.Vector3(0.3, -0.33, -0.66), ry: 0.05 };
  }

  buildArm() {
    const M = this.M;
    const g = new THREE.Group();
    box(0.12, 0.12, 0.44, M.blue, 0, 0, 0.14, g);
    box(0.13, 0.13, 0.05, M.dark, 0, 0, -0.08, g);
    box(0.15, 0.14, 0.15, M.blue, 0, 0, -0.17, g);
    box(0.155, 0.03, 0.03, new THREE.MeshBasicMaterial({ color: 0x8fd0ff }), 0, 0.04, -0.245, g);
    box(0.04, 0.05, 0.1, M.blue, 0.085, -0.01, -0.14, g);
    g.visible = false;
    return g;
  }

  updateAccents() {
    for (let i = 0; i < 3; i++) {
      const v = WEAPONS[i].variants[this.variant[i]];
      this.accents[i].color.setHex(v.color);
    }
  }

  get curId() { return WEAPONS[this.cur].id; }
  get varId() { return WEAPONS[this.cur].variants[this.variant[this.cur]].id; }

  select(i) {
    const game = this.game;
    if (i === this.cur) {
      const n = WEAPONS[i].variants.length;
      if (n > 1) {
        this.variant[i] = (this.variant[i] + 1) % n;
        this.switchT = 0.35;
        this.cancelCharges();
        this.updateAccents();
        game.audio.play('uiClick');
        game.hud.weaponChanged();
      }
      return;
    }
    this.last = this.cur;
    this.cur = i;
    this.switchT = 0;
    this.switchTime = game.time;
    this.cancelCharges();
    game.audio.play('uiClick');
    game.hud.weaponChanged();
  }

  cancelCharges() {
    this.pierceCharge = 0;
    this.pierceReady = false;
    this.coreCharge = 0;
  }

  // ---- Nişan / namlu ----
  aim() {
    const game = this.game;
    const p = game.player;
    const o = p.eyePos(), d = p.aimDir();
    // Mobil nişan yardımı: nişangâha çok yakın düşmana hafifçe kilitlen
    if (game.touch && game.touch.active && settings.aimAssist) {
      let best = null, bestA = 0.075;
      for (const e of game.enemies) {
        if (e.dead || e.state === 'spawn') continue;
        for (const pt of [e.headPos(), e.center()]) {
          const to = pt.clone().sub(o);
          const dist = to.length();
          if (dist > 70) continue;
          const a = Math.acos(Math.min(1, to.dot(d) / dist));
          if (a < bestA && game.world.lineOfSight(o, pt)) { bestA = a; best = to.normalize(); }
        }
      }
      if (best) return { o, d: best };
    }
    return { o, d };
  }

  muzzleWorld() {
    const m = this.models[this.cur];
    this.scene.updateMatrixWorld(true);
    const v = m.muzzle.getWorldPosition(new THREE.Vector3());
    v.project(this.cam);
    const cam = this.game.camera;
    const w = new THREE.Vector3(v.x, v.y, 0.5).unproject(cam);
    const dir = w.sub(cam.position).normalize();
    return cam.position.clone().addScaledVector(dir, 0.9);
  }

  kick(k) {
    this.recoil = Math.min(3, this.recoil + k);
    this.flashT = 0.05;
  }

  quickdrawCheck() {
    if (this.game.time - this.switchTime < 0.35) {
      this.game.style.add('QUICKDRAW', 40, this.curId);
      this.switchTime = -10;
    }
  }

  // ---- Güncelleme ----
  update(dt, input) {
    const game = this.game;
    const p = game.player;
    for (let i = 0; i < 3; i++) this.cd[i] = Math.max(0, this.cd[i] - dt);
    this.punchCd = Math.max(0, this.punchCd - dt);
    this.coinCharges = Math.min(4, this.coinCharges + dt / COIN_TIME);
    this.railCharge = Math.min(1, this.railCharge + dt / RAIL_TIME);
    if (this.railCharge >= 1 && !this.railWasReady) { this.railWasReady = true; game.audio.play('railReady'); }
    this.pumpAnim = Math.min(1, this.pumpAnim + dt / 0.55);

    for (let i = this.coins.length - 1; i >= 0; i--) {
      this.coins[i].update(dt);
      if (!this.coins[i].alive) this.coins.splice(i, 1);
    }

    const canAct = !p.dead && !p.frozen && game.state === 'playing';
    if (canAct) {
      if (input.pressed('w1')) this.select(0);
      if (input.pressed('w2')) this.select(1);
      if (input.pressed('w3')) this.select(2);
      if (input.pressed('lastWeapon')) this.select(this.last);
      if (input.wheel) this.select((this.cur + (input.wheel > 0 ? 1 : 2)) % 3);
      if (input.pressed('punch')) this.punch();
      if (this.switchT >= 0.8) this.fireLogic(dt, input);
    }
    this.animate(dt, input);
  }

  fireLogic(dt, input) {
    const game = this.game;
    const v = this.varId;
    if (this.cur === 0) {
      if (v === 'piercer') {
        if (input.is('alt') && this.cd[0] <= 0) {
          this.pierceCharge = Math.min(1, this.pierceCharge + dt / 0.55);
          if (this.pierceCharge >= 1 && !this.pierceReady) { this.pierceReady = true; game.audio.play('chargeReady'); }
          if (Math.random() < dt * 30) game.audio.play('charge', null, { t: this.pierceCharge });
        } else if (this.pierceCharge > 0) {
          if (this.pierceCharge >= 1) this.firePiercer();
          this.pierceCharge = 0;
          this.pierceReady = false;
        }
        if (input.is('fire') && this.cd[0] <= 0 && this.pierceCharge <= 0) this.fireRevolver();
      } else {
        if (input.pressed('alt')) {
          if (this.coinCharges >= 1) this.tossCoin();
          else game.audio.play('empty');
        }
        if (input.is('fire') && this.cd[0] <= 0) this.fireRevolver();
      }
    } else if (this.cur === 1) {
      if (v === 'core') {
        if (input.is('alt') && this.cd[1] <= 0) this.coreCharge = Math.min(1, this.coreCharge + dt / 0.5);
        else if (this.coreCharge > 0) { this.launchCore(this.coreCharge); this.coreCharge = 0; }
        if (input.is('fire') && this.cd[1] <= 0 && this.coreCharge <= 0) this.fireShotgun(0);
      } else {
        if (input.pressed('alt') && this.cd[1] <= 0) {
          this.pumps++;
          this.cd[1] = 0.22;
          this.pumpAnim = 0.4;
          game.audio.play('pump', null, { n: this.pumps });
          if (this.pumps >= 3) game.audio.play('overpump');
        }
        if (input.is('fire') && this.cd[1] <= 0) {
          if (this.pumps >= 3) this.overpump();
          else this.fireShotgun(this.pumps);
          this.pumps = 0;
        }
      }
    } else if (this.cur === 2) {
      if (input.pressed('fire')) {
        if (this.railCharge >= 1) this.fireRail();
        else game.audio.play('empty');
      }
    }
  }

  // ---- Revolver ----
  fireRevolver() {
    const game = this.game;
    this.cd[0] = 0.36;
    this.kick(0.8);
    this.drumTarget += Math.PI / 3;
    game.audio.play('revolver');
    const { o, d } = this.aim();
    const r = game.hitscan(o, d, 400, { coins: true, cores: true });
    const h = r.hits[0];
    let end = r.end;
    if (h) {
      end = h.point;
      if (h.coin) {
        this.ricochet(h.coin, 0);
      } else if (h.core) {
        h.core.boosted = true;
        h.core.explodeCore();
        h.core.remove();
        game.style.add('CORE SNIPE', 80, 'revolver');
      } else {
        h.enemy.hit({ dmg: 1, part: h.part, point: h.point, dir: d, weapon: 'revolver', knock: 3 });
        this.quickdrawCheck();
      }
    } else if (r.world) {
      game.fx.sparkDir(end, new THREE.Vector3(r.world.nx, r.world.ny, r.world.nz), 6, 6, 0xffd080, 0.25, 0.04, 0.7);
    }
    game.fx.tracer(this.muzzleWorld(), end, 0xfff0b0, 0.035, 0.09);
    game.flashLight(game.camera.position, 0xffc070, 3, 10, 0.05);
  }

  firePiercer() {
    const game = this.game;
    this.cd[0] = 0.5;
    this.kick(1.6);
    this.drumTarget += Math.PI / 3;
    game.audio.play('piercer');
    game.shake(0.2);
    const { o, d } = this.aim();
    const r = game.hitscan(o, d, 400, { coins: true, cores: true });
    let end = r.end;
    for (const h of r.hits) {
      if (h.coin) { this.ricochet(h.coin, 1); end = h.point; break; }
      if (h.core) { h.core.boosted = true; h.core.explodeCore(); h.core.remove(); game.style.add('CORE SNIPE', 80, 'revolver'); end = h.point; break; }
      h.enemy.hit({ dmg: 2.5, part: h.part, point: h.point, dir: d, weapon: 'revolver', knock: 8, headMult: 1.5 });
      this.quickdrawCheck();
    }
    const from = this.muzzleWorld();
    game.fx.tracer(from, end, 0x9fd8ff, 0.14, 0.3);
    game.fx.tracer(from, end, 0xffffff, 0.05, 0.2);
    game.flashLight(game.camera.position, 0x80c0ff, 5, 14, 0.1);
  }

  tossCoin() {
    const game = this.game;
    const p = game.player;
    this.coinCharges -= 1;
    const f = p.aimDir();
    const pos = p.eyePos().addScaledVector(f, 0.6);
    pos.y -= 0.1;
    const vel = f.clone().multiplyScalar(13).add(new THREE.Vector3(0, 8.5, 0)).addScaledVector(p.vel, 0.6);
    this.coins.push(new Coin(game, pos, vel));
    game.audio.play('coin');
    this.recoil = Math.min(3, this.recoil + 0.3);
  }

  ricochet(coin, chain) {
    const game = this.game;
    coin.kill();
    const cp = coin.pos.clone();
    game.audio.play('ricochet', cp);
    game.fx.sparkBurst(cp, 12, 8, 0xffd24a, 0.3, 0.05);
    game.fx.sprite(cp, 0xffe080, 1.6, 0.18, 'star', 1.8);
    let best = null, bd = 1e9;
    for (const c of this.coins) {
      if (!c.alive || c === coin) continue;
      const dd = c.pos.distanceTo(cp);
      if (dd < 70 && dd < bd && game.world.lineOfSight(cp, c.pos)) { best = c; bd = dd; }
    }
    if (best && chain < 10) {
      game.fx.tracer(cp, best.pos, 0xffd24a, 0.06, 0.28);
      this.ricochet(best, chain + 1);
      return;
    }
    let target = null, aimPt = null, part = 'body';
    bd = 1e9;
    for (const e of game.enemies) {
      if (e.dead || e.state === 'spawn') continue;
      const head = e.headPos();
      const dd = cp.distanceTo(head);
      if (dd > 100 || dd >= bd) continue;
      if (game.world.lineOfSight(cp, head)) { target = e; bd = dd; aimPt = head.clone(); part = 'head'; }
      else {
        const c = e.center();
        if (game.world.lineOfSight(cp, c)) { target = e; bd = dd; aimPt = c; part = 'body'; }
      }
    }
    if (target) {
      game.fx.tracer(cp, aimPt, 0xffd24a, 0.075, 0.32);
      const dir = aimPt.clone().sub(cp).normalize();
      game.style.add('RICOSHOT', 90 + chain * 40, 'revolver', { count: chain > 0 ? chain + 1 : 0 });
      target.hit({ dmg: 1.5 + chain, part, point: aimPt, dir, weapon: 'revolver', knock: 6, headMult: 2 });
      game.hitstop(0.04);
    } else {
      const dir = new THREE.Vector3(rand(-1, 1), rand(-0.3, 0.6), rand(-1, 1)).normalize();
      const hit = game.world.raycast(cp.x, cp.y, cp.z, dir.x, dir.y, dir.z, 40);
      const end = hit ? new THREE.Vector3(hit.x, hit.y, hit.z) : cp.clone().addScaledVector(dir, 40);
      game.fx.tracer(cp, end, 0xffd24a, 0.05, 0.2);
    }
  }

  // ---- Shotgun ----
  fireShotgun(pumps) {
    const game = this.game;
    this.cd[1] = 0.95;
    this.kick(1.5 + pumps * 0.4);
    this.pumpAnim = 0;
    game.audio.play('shotgun');
    game.shake(0.18 + pumps * 0.08);
    const { o, d } = this.aim();
    const right = new THREE.Vector3().crossVectors(d, new THREE.Vector3(0, 1, 0)).normalize();
    if (right.lengthSq() < 0.1) right.set(1, 0, 0);
    const up = new THREE.Vector3().crossVectors(right, d).normalize();
    const n = 12;
    const spread = 0.085 * (1 + pumps * 0.6);
    const pd = 0.32 * (1 + pumps * 0.5);
    const acc = new Map();
    const from = this.muzzleWorld();
    for (let k = 0; k < n; k++) {
      const a = Math.random() * Math.PI * 2, rr = Math.sqrt(Math.random()) * spread;
      const dir = d.clone().addScaledVector(right, Math.cos(a) * rr).addScaledVector(up, Math.sin(a) * rr).normalize();
      const r = game.hitscan(o, dir, 120, { cores: true });
      const h = r.hits[0];
      let end = r.end;
      if (h) {
        end = h.point;
        if (h.core) {
          h.core.boosted = true; h.core.explodeCore(); h.core.remove();
        } else {
          let e = acc.get(h.enemy);
          if (!e) { e = { dmg: 0, head: 0, n: 0, point: h.point }; acc.set(h.enemy, e); }
          e.dmg += pd * (h.part === 'head' ? 1.5 : 1);
          if (h.part === 'head') e.head++;
          e.n++;
        }
      } else if (r.world && k % 3 === 0) {
        game.fx.sparkDir(end, new THREE.Vector3(r.world.nx, r.world.ny, r.world.nz), 3, 5, 0xffd080, 0.2, 0.04, 0.8);
      }
      if (k % 2 === 0) game.fx.tracer(from, end, 0xffe0a0, 0.03, 0.07);
    }
    for (const [e, a] of acc) {
      e.hit({ dmg: a.dmg, part: a.head >= Math.max(2, a.n * 0.5) ? 'head' : 'body', headMult: 1, point: a.point, dir: d, weapon: 'shotgun', knock: 3 + a.n * 1.3 });
    }
    if (acc.size) this.quickdrawCheck();
    game.flashLight(game.camera.position, 0xffb060, 5, 12, 0.07);
  }

  launchCore(charge) {
    const game = this.game;
    const p = game.player;
    this.cd[1] = 0.9;
    this.kick(1.1);
    this.pumpAnim = 0;
    const d = p.aimDir();
    const pos = p.eyePos().addScaledVector(d, 0.8);
    pos.y -= 0.12;
    const vel = d.clone().multiplyScalar(18 + 26 * charge).add(new THREE.Vector3(0, 2 + 2 * charge, 0)).addScaledVector(p.vel, 0.3);
    const proj = new Projectile(game, { kind: 'core', pos, vel, radius: 0.22, damage: 0, owner: 'player', parryable: false, gravity: 20, life: 3, color: 0x3aa0ff });
    game.addProjectile(proj);
    game.audio.play('coreLaunch');
  }

  overpump() {
    const game = this.game;
    const p = game.player;
    this.cd[1] = 1.2;
    this.kick(2.5);
    this.pumpAnim = 0;
    game.audio.play('shotgun');
    const pos = p.eyePos().addScaledVector(p.aimDir(), 1.2);
    game.explode(pos, 7, 6, { owner: 'player', playerDmg: 35, knock: 22, weapon: 'shotgun' });
  }

  // ---- Railcannon ----
  fireRail() {
    const game = this.game;
    const p = game.player;
    this.railCharge = 0;
    this.railWasReady = false;
    this.cd[2] = 0.8;
    this.kick(3);
    game.audio.play('rail');
    game.shake(0.8);
    const { o, d } = this.aim();
    const r = game.hitscan(o, d, 500, {});
    for (const h of r.hits) {
      if (!h.enemy) continue;
      h.enemy.hit({ dmg: 8, part: h.part, point: h.point, dir: d, weapon: 'rail', knock: 25, headMult: 1.5 });
    }
    if (r.hits.length) this.quickdrawCheck();
    const from = this.muzzleWorld();
    const end = r.end;
    game.fx.tracer(from, end, 0x40e8ff, 0.4, 0.6);
    game.fx.tracer(from, end, 0xffffff, 0.12, 0.45);
    const len = from.distanceTo(end);
    const step = new THREE.Vector3().subVectors(end, from).normalize();
    for (let t = 1; t < len; t += 2.5) game.fx.sparkBurst(from.clone().addScaledVector(step, t), 2, 3, 0x60f0ff, 0.5, 0.06, 0);
    if (r.world) game.fx.sparkBurst(end, 30, 12, 0x80f8ff, 0.6, 0.08);
    game.flashLight(end, 0x60e8ff, 10, 20, 0.15);
    game.flashLight(game.camera.position, 0x60e8ff, 6, 12, 0.1);
    p.vel.addScaledVector(d, -7);
  }

  // ---- Feedbacker ----
  punch() {
    if (this.punchCd > 0) return;
    const game = this.game;
    this.punchCd = 0.4;
    this.punchT = 0;
    game.audio.play('punch');
    if (!game.tryParry()) game.meleePunch();
  }

  // ---- Animasyon ----
  animate(dt, input) {
    const game = this.game;
    const p = game.player;
    this.switchT = Math.min(1, this.switchT + dt / 0.22);
    const sw = 1 - easeOut(this.switchT);
    this.recoil = damp(this.recoil, 0, 11, dt);
    this.swayX = damp(this.swayX, clamp(-input.mdx * 0.0009, -0.06, 0.06), 9, dt);
    this.swayY = damp(this.swayY, clamp(input.mdy * 0.0009, -0.06, 0.06), 9, dt);
    const bt = p.bobT, ba = p.bob;
    const bx = Math.sin(bt * 0.95) * 0.014 * ba;
    const by = -Math.abs(Math.cos(bt * 0.95)) * 0.016 * ba;
    const airY = clamp(-p.vel.y * 0.0012, -0.03, 0.03);
    const slide = p.sliding ? 1 : 0;
    this.slideK = damp(this.slideK || 0, slide, 10, dt);

    for (let i = 0; i < 3; i++) this.models[i].group.visible = i === this.cur;
    const m = this.models[this.cur];
    const shake = new THREE.Vector3();
    if (this.cur === 0 && this.pierceCharge > 0) shake.set(rand(-1, 1), rand(-1, 1), 0).multiplyScalar(0.004 * this.pierceCharge);
    const coreLift = this.cur === 1 ? this.coreCharge : 0;
    m.group.position.set(
      m.base.x + bx + this.swayX + shake.x - this.slideK * 0.04,
      m.base.y + by + this.swayY - sw * 0.45 + airY + shake.y - this.recoil * 0.015 - this.slideK * 0.02,
      m.base.z + this.recoil * 0.08
    );
    m.group.rotation.set(this.recoil * 0.3 + sw * 0.9 + this.swayY * 1.5 + coreLift * 0.3, m.ry + this.swayX * 1.5, -p.tilt * 1.2 + this.slideK * 0.25);

    // silaha özel
    if (this.cur === 0) {
      this.drumAngle = damp(this.drumAngle, this.drumTarget, 18, dt);
      m.drum.rotation.z = this.drumAngle;
      m.hammer.rotation.x = -0.4 - Math.min(1, this.recoil) * 0.5;
      const v = WEAPONS[0].variants[this.variant[0]];
      const glow = this.pierceCharge > 0 ? 1 + this.pierceCharge * 2 : 1;
      this.accents[0].color.setHex(v.color).multiplyScalar(glow);
    } else if (this.cur === 1) {
      const t = this.pumpAnim;
      const k = t < 0.6 ? Math.sin((t / 0.6) * Math.PI) : 0;
      m.pump.position.z = -0.4 + k * 0.12;
      const v = WEAPONS[1].variants[this.variant[1]];
      const hot = this.varId === 'pump' ? this.pumps / 3 : this.coreCharge;
      this.accents[1].color.setHex(this.varId === 'pump' && this.pumps >= 3 ? (Math.sin(game.time * 40) > 0 ? 0xff2010 : 0xffc020) : v.color).multiplyScalar(1 + hot * 1.5);
      if (this.varId === 'pump' && this.pumps >= 3) m.group.position.x += rand(-0.004, 0.004);
    } else {
      const c = this.railCharge;
      this.coilMat.color.setRGB(0.05 + 0.2 * c, 0.2 + 0.7 * c, 0.3 + 0.7 * c);
      if (c >= 1) this.coilMat.color.multiplyScalar(1 + Math.sin(game.time * 8) * 0.3);
      for (let i = 0; i < m.coils.length; i++) m.coils[i].rotation.z += dt * (1 + c * 6) * (i % 2 ? 1 : -1);
      m.meter.scale.z = Math.max(0.05, c);
      m.meter.position.z = 0.17 - (1 - c) * 0.065;
    }

    // yumruk kolu
    this.punchT += dt;
    const pt = this.punchT;
    if (pt < 0.32) {
      const k = pt < 0.07 ? easeOut(pt / 0.07) : 1 - easeOut((pt - 0.07) / 0.25);
      this.arm.visible = true;
      this.arm.position.set(-0.42 + 0.3 * k, -0.52 + 0.34 * k, -0.25 - 0.5 * k);
      this.arm.rotation.set(0.25 - 0.25 * k, 0.35 - 0.3 * k, 0);
    } else this.arm.visible = false;

    // namlu alevi
    this.flashT -= dt;
    if (this.flashT > 0) {
      this.scene.updateMatrixWorld(true);
      m.muzzle.getWorldPosition(this.flash.position);
      this.flash.visible = true;
      const s = this.cur === 2 ? 0.6 : this.cur === 1 ? 0.45 : 0.3;
      this.flash.scale.setScalar(s * rand(0.8, 1.2));
      this.flash.material.rotation = rand(0, Math.PI);
      this.flash.material.color.setHex(this.cur === 2 ? 0x80f0ff : this.cur === 0 && this.varId === 'piercer' && this.recoil > 1.2 ? 0x9fd8ff : 0xffe0a0);
      this.flashLightVM.intensity = 4;
    } else {
      this.flash.visible = false;
      this.flashLightVM.intensity = 0;
    }
  }

  hudInfo() {
    const W = WEAPONS[this.cur];
    const v = W.variants[this.variant[this.cur]];
    return {
      cur: this.cur,
      name: W.name,
      variant: v.name,
      color: '#' + v.color.toString(16).padStart(6, '0'),
      varId: v.id,
      coins: this.coinCharges,
      rail: this.railCharge,
      pumps: this.pumps,
      pierce: this.pierceCharge,
      core: this.coreCharge,
    };
  }
}
