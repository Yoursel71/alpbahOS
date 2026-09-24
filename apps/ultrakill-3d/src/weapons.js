// Silahlar ve görünür silah modelleri (viewmodel). ULTRAKILL'deki gibi her silahın üç
// varyantı (mavi/yeşil/kırmızı) vardır; aynı sayı tuşuna tekrar basınca varyant değişir.
//   1 Revolver:        Piercer / Marksman / Sharpshooter
//   2 Shotgun:         Core Eject / Pump Charge / Sawed-On
//   3 Nailgun:         Attractor / Overheat / Sawblade
//   4 Railcannon:      Electric / Screwdriver / Malicious
//   5 Rocket Launcher: Freezeframe / S.R.S. Cannon / Firestarter
// Kollar: Feedbacker (parry) / Knuckleblaster (G ile değişir), Whiplash kancası (E).
import * as THREE from 'three';
import { clamp, damp, rand } from './util.js';
import { Coin, Projectile } from './projectiles.js';
import { settings } from './settings.js';
import { ViewArms, Spring, buildArm, setCurl } from './arms.js';

const BLUE = 0x3aa0ff, GREEN = 0x3ee06a, RED = 0xff3a2a;
export const WEAPONS = [
  { id: 'revolver', name: 'REVOLVER', variants: [{ id: 'piercer', name: 'PIERCER', color: BLUE }, { id: 'marksman', name: 'MARKSMAN', color: GREEN }, { id: 'sharpshooter', name: 'SHARPSHOOTER', color: RED }] },
  { id: 'shotgun', name: 'SHOTGUN', variants: [{ id: 'core', name: 'CORE EJECT', color: BLUE }, { id: 'pump', name: 'PUMP CHARGE', color: GREEN }, { id: 'saw', name: 'SAWED-ON', color: RED }] },
  { id: 'nailgun', name: 'NAILGUN', variants: [{ id: 'attractor', name: 'ATTRACTOR', color: BLUE }, { id: 'overheat', name: 'OVERHEAT', color: GREEN }, { id: 'sawblade', name: 'SAWBLADE', color: RED }] },
  { id: 'rail', name: 'RAILCANNON', variants: [{ id: 'electric', name: 'ELECTRIC', color: BLUE }, { id: 'screwdriver', name: 'SCREWDRIVER', color: GREEN }, { id: 'malicious', name: 'MALICIOUS', color: RED }] },
  { id: 'rocket', name: 'ROCKET LAUNCHER', variants: [{ id: 'freeze', name: 'FREEZEFRAME', color: BLUE }, { id: 'cannon', name: 'S.R.S. CANNON', color: GREEN }, { id: 'fire', name: 'FIRESTARTER', color: RED }] },
];
export const ARMS = [
  { id: 'feedbacker', name: 'FEEDBACKER', color: BLUE },
  { id: 'knuckle', name: 'KNUCKLEBLASTER', color: RED },
];
export const WEAPON_IDS = WEAPONS.map((w) => w.id);

const RAIL_TIME = 12;
const COIN_TIME = 2.2;
const N = WEAPONS.length;

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
const easeInOut = (t) => { t = clamp(t, 0, 1); return t * t * (3 - 2 * t); };

export class Weapons {
  constructor(game) {
    this.game = game;
    const T = game.tex;
    this.scene = new THREE.Scene();
    this.cam = new THREE.PerspectiveCamera(58, 1, 0.01, 20);
    this.scene.add(new THREE.HemisphereLight(0xffe8d8, 0x401818, 2.0));
    const dl = new THREE.DirectionalLight(0xffd6b8, 2.4);
    dl.position.set(-1, 2, 1.2);
    this.scene.add(dl);
    const rim = new THREE.DirectionalLight(0xff5a30, 1.2);
    rim.position.set(1.5, 0.3, -1);
    this.scene.add(rim);
    this.flashLightVM = new THREE.PointLight(0xffc070, 0, 3, 1);
    this.flashLightVM.position.set(0.25, -0.1, -0.9);
    this.scene.add(this.flashLightVM);

    this.M = {
      gun: new THREE.MeshLambertMaterial({ map: T.metal, color: 0xa8aebb }),
      dark: new THREE.MeshLambertMaterial({ map: T.machine, color: 0x3a3d46 }),
      black: new THREE.MeshLambertMaterial({ color: 0x141418 }),
      grip: new THREE.MeshLambertMaterial({ map: T.rock, color: 0xb08a70 }),
      arm: new THREE.MeshLambertMaterial({ map: T.machine, color: 0xb8c0d0 }),
      armDark: new THREE.MeshLambertMaterial({ map: T.machine, color: 0x5a606c }),
      armLight: new THREE.MeshLambertMaterial({ map: T.metal, color: 0xc4ccda, emissive: 0x14161c }),
      blue: new THREE.MeshLambertMaterial({ map: T.metal, color: 0x4a8cff, emissive: 0x0a2250 }),
      red: new THREE.MeshLambertMaterial({ map: T.metal, color: 0xe03a2a, emissive: 0x3a0806 }),
      brass: new THREE.MeshLambertMaterial({ color: 0xd8a040, emissive: 0x302010 }),
      rocketRed: new THREE.MeshLambertMaterial({ color: 0xd02020, emissive: 0x200404 }),
    };
    this.accents = WEAPONS.map(() => new THREE.MeshBasicMaterial({ color: BLUE }));
    this.coilMat = new THREE.MeshBasicMaterial({ color: 0x3aeaff });
    this.meterMat = new THREE.MeshBasicMaterial({ color: 0x3aeaff });
    this.heatMat = new THREE.MeshBasicMaterial({ color: 0x401008 });

    this.models = [this.buildRevolver(), this.buildShotgun(), this.buildNailgun(), this.buildRail(), this.buildRocket()];
    for (const m of this.models) this.scene.add(m.group);
    // görünür sol kol (parmaklı eller) ve eylem animasyonları
    this.arms = new ViewArms(this);
    this.armModels = [this.arms.models.feedbacker, this.arms.models.knuckle];
    this.hookHand = this.arms.models.whiplash;
    this.fist = this.buildIdleFist();
    this.scene.add(this.fist);
    // silah hareket yayları: geri tepme (z), iniş/zıplama (y), dönüş (x)
    this.sprZ = new Spring(210, 17);
    this.sprY = new Spring(150, 13);
    this.sprR = new Spring(190, 15);
    this.idleT = 0;
    this.inspectT = 0;

    this.flashes = [];
    for (let i = 0; i < 2; i++) {
      const f = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.star, color: 0xffe0a0, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, depthTest: false }));
      f.visible = false;
      this.scene.add(f);
      this.flashes.push(f);
    }
    this.flashGlow = new THREE.Sprite(new THREE.SpriteMaterial({ map: T.glow, color: 0xffb060, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, depthTest: false }));
    this.flashGlow.visible = false;
    this.scene.add(this.flashGlow);

    // Whiplash halatı (dünya sahnesinde)
    const lg = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(), new THREE.Vector3()]);
    this.rope = new THREE.Line(lg, new THREE.LineBasicMaterial({ color: 0x9adf5a }));
    this.rope.frustumCulled = false;
    this.rope.visible = false;
    game.scene.add(this.rope);
    this.hookMesh = new THREE.Mesh(new THREE.ConeGeometry(0.12, 0.3, 5).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0xc8f0a0 }));
    this.hookMesh.visible = false;
    game.scene.add(this.hookMesh);

    this.owned = new Array(N).fill(false);
    this.varOwned = WEAPONS.map((w) => w.variants.map(() => false));
    this.armsOwned = [true, false];
    this.hookOwned = false;
    this.reset();
  }

  reset(keepOwned = false) {
    if (!keepOwned) {
      this.owned = new Array(N).fill(false);
      this.varOwned = WEAPONS.map((w) => w.variants.map(() => false));
      this.armsOwned = [true, false];
      this.hookOwned = false;
      this.variant = new Array(N).fill(0);
      this.arm = 0;
    }
    if (!this.variant) this.variant = new Array(N).fill(0);
    this.cur = this.owned.indexOf(true);
    this.last = this.cur;
    this.switchT = 1;
    this.switchTime = -10;
    this.equipSpin = 0;
    this.cd = new Array(N).fill(0);
    this.pierceCharge = 0;
    this.pierceReady = false;
    this.sharpCharge = 0;
    this.sharpCharges = 3;
    this.coinCharges = 4;
    this.coreCharge = 0;
    this.corePopT = 1;
    this.pumps = 0;
    this.pumpAnim = 1;
    this.sawOut = false;
    this.heat = 0;
    this.heatBurst = 0;
    this.nailT = 0;
    this.barrelSpin = 0;
    this.barrelAngle = 0;
    this.magnetCharges = 3;
    this.railCharge = 1;
    this.railWasReady = true;
    this.railHeat = 0;
    this.freezeEnergy = 1;
    this.freezeActive = false;
    this.cannonCharge = 0;
    this.cannonCd = 0;
    this.fuel = 1;
    this.flaming = false;
    this.rocketLoadT = 1;
    this.punchT = 1;
    this.punchCd = 0;
    this.parryBuffer = 0;
    this.blastHold = 0;
    this.blastCd = 0;
    this.hook = null;
    this.hookCd = 0;
    this.recoil = 0;
    this.recoilRot = 0;
    this.swayX = 0;
    this.swayY = 0;
    this.flashT = 0;
    this.drumAngle = 0;
    this.drumTarget = 0;
    this.hammerT = 1;
    this.coinFlick = 1;
    this.lastShotgunHit = null;
    for (const c of this.coins || []) c.kill();
    this.coins = [];
    for (const m of this.magnets || []) m.remove();
    this.magnets = [];
    if (this.game.audio) { this.game.audio.loop('pierce', false); this.game.audio.loop('flame', false); }
    if (this.rope) { this.rope.visible = false; this.hookMesh.visible = false; }
    this.updateAccents();
  }

  get armed() { return this.cur >= 0; }

  give(i) {
    const first = !this.owned[i];
    this.owned[i] = true;
    if (!this.varOwned[i].some(Boolean)) this.varOwned[i][0] = true;
    if (!this.varOwned[i][this.variant[i]]) this.variant[i] = this.varOwned[i].indexOf(true);
    this.last = this.cur;
    this.cur = i;
    this.switchT = 0;
    this.equipSpin = i === 0 ? 1 : 0;
    this.switchTime = this.game.time;
    this.cancelCharges();
    this.game.hud.weaponChanged();
    return first;
  }

  giveArm(id) {
    if (id === 'hook') { const f = !this.hookOwned; this.hookOwned = true; return f; }
    const i = ARMS.findIndex((a) => a.id === id);
    const first = !this.armsOwned[i];
    this.armsOwned[i] = true;
    this.arm = i;
    this.game.hud.weaponChanged();
    return first;
  }

  // Dükkân sahipliğini uygula: owned = { 'shotgun': true, 'shotgun.pump': true, 'arm.knuckle': true, ... }
  // Revolver (Piercer) her zaman vardır. Seçili silah korunur.
  applyLoadout(owned) {
    for (let i = 0; i < N; i++) {
      const W = WEAPONS[i];
      const base = i === 0 || !!owned[W.id];
      this.owned[i] = base;
      this.varOwned[i] = W.variants.map((v, k) => base && (k === 0 || !!owned[W.id + '.' + v.id]));
      if (!this.varOwned[i][this.variant[i]]) this.variant[i] = 0;
    }
    this.armsOwned = [true, !!owned['arm.knuckle']];
    if (!this.armsOwned[this.arm]) this.arm = 0;
    this.hookOwned = !!owned['arm.hook'];
    if (this.cur < 0 || !this.owned[this.cur]) { this.cur = 0; this.switchT = 0; this.equipSpin = 1; this.switchTime = this.game.time; }
    this.updateAccents();
    this.game.hud.weaponChanged();
  }

  giveAll() {
    for (let i = 0; i < N; i++) { this.owned[i] = true; this.varOwned[i] = WEAPONS[i].variants.map(() => true); }
    this.armsOwned = [true, true];
    this.hookOwned = true;
    if (this.cur < 0) this.cur = 0;
    this.game.hud.weaponChanged();
  }

  resize(aspect) {
    this.cam.aspect = aspect;
    this.cam.updateProjectionMatrix();
  }

  // ---------------------------------------------------------------- modeller
  buildHand(parent, gx, gy, gz, tilt = -0.28) {
    const M = this.M;
    const hand = new THREE.Group();
    hand.position.set(gx, gy, gz);
    hand.rotation.x = tilt;
    parent.add(hand);
    box(0.1, 0.1, 0.1, M.arm, 0.006, -0.02, 0.02, hand);
    for (let k = 0; k < 4; k++) box(0.028, 0.03, 0.05, M.armDark, -0.046, 0.02 - k * 0.034, -0.035, hand).rotation.y = 0.2;
    box(0.03, 0.03, 0.07, M.armDark, 0.05, 0.035, -0.02, hand).rotation.z = -0.3;
    const fore = new THREE.Group();
    fore.position.set(0.01, -0.06, 0.1);
    fore.rotation.x = -0.1;
    hand.add(fore);
    box(0.11, 0.11, 0.34, M.arm, 0, 0, 0.17, fore);
    box(0.125, 0.04, 0.12, M.armDark, 0, 0.05, 0.08, fore);
    box(0.125, 0.04, 0.12, M.armDark, 0, 0.05, 0.24, fore);
    cylZ(0.06, 0.06, 0.03, M.black, 0, 0, 0.005, fore, 8);
    return hand;
  }

  buildRevolver() {
    const M = this.M, A = this.accents[0];
    const g = new THREE.Group();
    const gun = new THREE.Group();
    g.add(gun);
    box(0.075, 0.085, 0.2, M.gun, 0, 0, -0.03, gun);
    box(0.05, 0.026, 0.25, M.gun, 0, 0.058, -0.1, gun);
    cylZ(0.026, 0.026, 0.3, M.dark, 0, 0.042, -0.32, gun, 12);
    cylZ(0.032, 0.032, 0.035, M.gun, 0, 0.042, -0.46, gun, 12);
    cylZ(0.011, 0.011, 0.07, M.black, 0, 0.042, -0.478, gun, 8);
    cylZ(0.013, 0.013, 0.2, M.gun, 0, 0.006, -0.28, gun, 8);
    box(0.012, 0.035, 0.03, M.dark, 0, 0.08, -0.44, gun);
    box(0.012, 0.02, 0.02, M.dark, -0.016, 0.078, 0.02, gun);
    box(0.012, 0.02, 0.02, M.dark, 0.016, 0.078, 0.02, gun);
    box(0.078, 0.02, 0.14, A, 0, 0.022, -0.02, gun);
    const drum = new THREE.Group();
    drum.position.set(0, 0.022, -0.1);
    gun.add(drum);
    cylZ(0.06, 0.06, 0.13, M.gun, 0, 0, 0, drum, 8);
    for (let k = 0; k < 6; k++) {
      const a = (k / 6) * Math.PI * 2;
      cylZ(0.014, 0.014, 0.135, M.black, Math.cos(a) * 0.036, Math.sin(a) * 0.036, 0, drum, 6);
      const fl = box(0.014, 0.012, 0.11, A, Math.cos(a + 0.52) * 0.058, Math.sin(a + 0.52) * 0.058, 0, drum);
      fl.rotation.z = a + 0.52;
    }
    const hammer = new THREE.Group();
    hammer.position.set(0, 0.05, 0.06);
    gun.add(hammer);
    box(0.022, 0.055, 0.03, M.dark, 0, 0.025, 0, hammer).rotation.x = -0.3;
    const guard = new THREE.Mesh(new THREE.TorusGeometry(0.032, 0.006, 4, 10, Math.PI), M.dark);
    guard.rotation.set(0, Math.PI / 2, Math.PI);
    guard.position.set(0, -0.045, 0.0);
    gun.add(guard);
    box(0.01, 0.035, 0.012, M.black, 0, -0.05, 0.005, gun).rotation.x = 0.3;
    box(0.062, 0.18, 0.082, M.grip, 0, -0.1, 0.08, gun).rotation.x = -0.28;
    box(0.066, 0.12, 0.05, M.dark, 0, -0.1, 0.08, gun).rotation.x = -0.28;
    box(0.068, 0.03, 0.03, A, 0, -0.07, 0.07, gun).rotation.x = -0.28;
    const muzzle = new THREE.Object3D();
    muzzle.position.set(0, 0.042, -0.5);
    gun.add(muzzle);
    this.buildHand(gun, 0.0, -0.1, 0.1);
    g.position.set(0.25, -0.26, -0.52);
    return { group: g, gun, muzzle, drum, hammer, base: new THREE.Vector3(0.25, -0.26, -0.52), ry: 0.05 };
  }

  buildShotgun() {
    const M = this.M, A = this.accents[1];
    const g = new THREE.Group();
    const gun = new THREE.Group();
    g.add(gun);
    box(0.1, 0.13, 0.32, M.gun, 0, 0, -0.02, gun);
    box(0.104, 0.025, 0.3, M.dark, 0, 0.07, -0.02, gun);
    cylZ(0.035, 0.035, 0.62, M.dark, 0, 0.038, -0.49, gun, 12);
    cylZ(0.042, 0.042, 0.06, M.gun, 0, 0.038, -0.8, gun, 8);
    cylZ(0.015, 0.015, 0.1, M.black, 0, 0.038, -0.81, gun, 8);
    cylZ(0.026, 0.026, 0.44, M.dark, 0, -0.03, -0.42, gun, 10);
    const pump = new THREE.Group();
    pump.position.set(0, -0.03, -0.4);
    gun.add(pump);
    box(0.09, 0.08, 0.22, M.grip, 0, 0, 0, pump);
    for (let k = 0; k < 5; k++) box(0.094, 0.01, 0.012, M.dark, 0, -0.02, -0.08 + k * 0.04, pump);
    const stock = new THREE.Group();
    stock.position.set(0, -0.04, 0.14);
    gun.add(stock);
    box(0.072, 0.11, 0.3, M.grip, 0, -0.02, 0.14, stock).rotation.x = 0.14;
    box(0.075, 0.13, 0.03, M.black, 0, -0.05, 0.29, stock);
    box(0.004, 0.035, 0.1, M.black, 0.052, 0.025, -0.03, gun);
    const coreCell = cylZ(0.03, 0.03, 0.1, A, -0.058, 0.0, -0.02, gun, 8);
    // Sawed-On: namlu altında testere
    const saw = new THREE.Group();
    saw.position.set(0, -0.09, -0.5);
    gun.add(saw);
    box(0.02, 0.05, 0.36, M.gun, 0, 0, 0, saw);
    for (let k = 0; k < 7; k++) box(0.024, 0.02, 0.02, A, 0, -0.035, -0.15 + k * 0.05, saw);
    box(0.02, 0.012, 0.52, A, 0, 0.088, -0.42, gun);
    box(0.104, 0.03, 0.08, A, 0, -0.035, 0.06, gun);
    const muzzle = new THREE.Object3D();
    muzzle.position.set(0, 0.038, -0.86);
    gun.add(muzzle);
    const eject = new THREE.Object3D();
    eject.position.set(0.06, 0.03, -0.03);
    gun.add(eject);
    this.buildHand(gun, 0.0, -0.1, 0.1, -0.2);
    g.position.set(0.27, -0.3, -0.6);
    return { group: g, gun, muzzle, pump, coreCell, saw, eject, base: new THREE.Vector3(0.27, -0.3, -0.6), ry: 0.05 };
  }

  buildNailgun() {
    const M = this.M, A = this.accents[2];
    const g = new THREE.Group();
    const gun = new THREE.Group();
    g.add(gun);
    box(0.12, 0.13, 0.34, M.gun, 0, 0, -0.05, gun);
    box(0.13, 0.05, 0.2, M.dark, 0, -0.07, -0.02, gun);
    const barrels = new THREE.Group();
    barrels.position.set(0, 0.01, -0.36);
    gun.add(barrels);
    for (let k = 0; k < 4; k++) {
      const a = (k / 4) * Math.PI * 2;
      cylZ(0.016, 0.016, 0.34, M.dark, Math.cos(a) * 0.035, Math.sin(a) * 0.035, 0, barrels, 6);
    }
    cylZ(0.055, 0.055, 0.03, M.gun, 0, 0, 0.14, barrels, 8);
    cylZ(0.055, 0.055, 0.03, M.gun, 0, 0, -0.14, barrels, 8);
    const drum = cylZ(0.07, 0.07, 0.1, M.gun, 0, 0.1, -0.02, gun, 10);
    drum.rotation.set(0, 0, Math.PI / 2);
    const heat = [];
    for (let k = 0; k < 3; k++) heat.push(box(0.125, 0.012, 0.03, this.heatMat, 0, 0.03, -0.12 + k * 0.05, gun));
    box(0.124, 0.02, 0.2, A, 0, -0.03, -0.05, gun);
    box(0.06, 0.16, 0.08, M.grip, 0, -0.12, 0.08, gun).rotation.x = -0.25;
    const muzzle = new THREE.Object3D();
    muzzle.position.set(0, 0.01, -0.55);
    gun.add(muzzle);
    this.buildHand(gun, 0, -0.1, 0.1);
    g.position.set(0.26, -0.29, -0.58);
    return { group: g, gun, muzzle, barrels, heat, base: new THREE.Vector3(0.26, -0.29, -0.58), ry: 0.05 };
  }

  buildRail() {
    const M = this.M, A = this.accents[3];
    const g = new THREE.Group();
    const gun = new THREE.Group();
    g.add(gun);
    box(0.16, 0.16, 0.46, M.gun, 0, 0, -0.14, gun);
    box(0.13, 0.15, 0.18, M.dark, 0, 0.005, 0.16, gun);
    box(0.19, 0.06, 0.22, M.dark, 0, -0.06, -0.3, gun);
    const meter = box(0.03, 0.022, 0.14, this.meterMat, 0, 0.092, 0.16, gun);
    cylZ(0.04, 0.04, 0.2, this.meterMat, 0, 0.1, -0.05, gun, 8);
    for (const [x, y] of [[0, 0.1], [-0.09, -0.05], [0.09, -0.05]]) box(0.024, 0.024, 0.78, M.dark, x, y, -0.54, gun);
    const coils = [];
    for (const z of [-0.36, -0.52, -0.68]) {
      const c = new THREE.Mesh(new THREE.TorusGeometry(0.11, 0.022, 6, 14), this.coilMat);
      c.position.set(0, 0.015, z);
      gun.add(c);
      coils.push(c);
    }
    box(0.165, 0.02, 0.3, A, 0, -0.08, -0.1, gun);
    const muzzle = new THREE.Object3D();
    muzzle.position.set(0, 0.015, -0.95);
    gun.add(muzzle);
    this.buildHand(gun, 0.0, -0.12, 0.14, -0.2);
    g.position.set(0.28, -0.32, -0.64);
    return { group: g, gun, muzzle, coils, meter, base: new THREE.Vector3(0.28, -0.32, -0.64), ry: 0.05 };
  }

  buildRocket() {
    const M = this.M, A = this.accents[4];
    const g = new THREE.Group();
    const gun = new THREE.Group();
    g.add(gun);
    cylZ(0.085, 0.085, 0.72, M.gun, 0, 0.03, -0.22, gun, 10); // tüp
    cylZ(0.1, 0.085, 0.08, M.dark, 0, 0.03, 0.16, gun, 10); // arka ağız
    cylZ(0.095, 0.095, 0.05, M.dark, 0, 0.03, -0.56, gun, 10);
    cylZ(0.06, 0.06, 0.02, M.black, 0, 0.03, -0.59, gun, 10);
    box(0.03, 0.05, 0.12, M.dark, 0, 0.13, -0.2, gun); // nişangâh
    box(0.07, 0.16, 0.08, M.grip, 0, -0.1, 0.02, gun).rotation.x = -0.2;
    box(0.06, 0.12, 0.07, M.grip, 0, -0.08, -0.3, gun).rotation.x = -0.1;
    for (const z of [-0.45, -0.05]) cylZ(0.089, 0.089, 0.03, A, 0, 0.03, z, gun, 10);
    const nose = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.14, 8).rotateX(-Math.PI / 2), M.rocketRed);
    nose.position.set(0, 0.03, -0.6);
    gun.add(nose);
    const ball = new THREE.Mesh(new THREE.IcosahedronGeometry(0.07, 1), M.black);
    ball.position.set(0, 0.03, -0.58);
    ball.visible = false;
    gun.add(ball);
    const muzzle = new THREE.Object3D();
    muzzle.position.set(0, 0.03, -0.66);
    gun.add(muzzle);
    this.buildHand(gun, 0, -0.1, 0.06, -0.2);
    g.position.set(0.28, -0.3, -0.6);
    return { group: g, gun, muzzle, nose, ball, base: new THREE.Vector3(0.28, -0.3, -0.6), ry: 0.05 };
  }

  buildFeedbacker() {
    const M = this.M;
    const g = new THREE.Group();
    box(0.12, 0.12, 0.44, M.blue, 0, 0, 0.14, g);
    box(0.09, 0.09, 0.45, M.armDark, 0, -0.02, 0.5, g); // uzatılmış ön kol
    box(0.135, 0.05, 0.14, M.armDark, 0, 0.05, 0.2, g);
    box(0.13, 0.13, 0.05, M.black, 0, 0, -0.08, g);
    box(0.15, 0.14, 0.15, M.blue, 0, 0, -0.17, g);
    for (let k = 0; k < 4; k++) box(0.03, 0.03, 0.03, M.armDark, -0.052 + k * 0.035, 0.04, -0.25, g);
    box(0.155, 0.03, 0.03, new THREE.MeshBasicMaterial({ color: 0x8fd0ff }), 0, 0.075, -0.2, g);
    box(0.04, 0.05, 0.1, M.blue, 0.085, -0.01, -0.14, g);
    g.visible = false;
    return g;
  }

  buildKnuckle() {
    const M = this.M;
    const g = new THREE.Group();
    box(0.15, 0.15, 0.46, M.red, 0, 0, 0.14, g);
    box(0.11, 0.11, 0.45, M.black, 0, -0.02, 0.5, g); // uzatılmış ön kol
    box(0.17, 0.08, 0.2, M.black, 0, 0.07, 0.18, g);
    box(0.21, 0.2, 0.2, M.red, 0, 0, -0.18, g);
    for (let k = 0; k < 4; k++) box(0.045, 0.05, 0.05, M.black, -0.075 + k * 0.05, 0.06, -0.3, g);
    const glow = new THREE.MeshBasicMaterial({ color: 0xffa040 });
    for (const x of [-0.06, 0.06]) cylZ(0.025, 0.025, 0.06, glow, x, -0.05, -0.29, g, 6);
    box(0.08, 0.06, 0.12, M.black, 0.12, 0, -0.1, g);
    g.visible = false;
    return g;
  }

  buildHookHand() {
    const M = this.M;
    const g = new THREE.Group();
    box(0.1, 0.1, 0.36, M.armDark, 0, 0, 0.12, g);
    box(0.12, 0.12, 0.12, new THREE.MeshLambertMaterial({ color: 0x5aa03a, emissive: 0x102a08 }), 0, 0, -0.1, g);
    g.visible = false;
    g.position.set(-0.3, -0.35, -0.5);
    return g;
  }

  // silahsızken görünen sağ el (sol elin aynası, yumruk)
  buildIdleFist() {
    const g = buildArm(this.M, 'plain');
    g.scale.x = -1;
    setCurl(g, 1);
    g.rotation.set(0.42, 0.5, -0.15);
    return g;
  }

  updateAccents() {
    for (let i = 0; i < N; i++) this.accents[i].color.setHex(WEAPONS[i].variants[this.variant[i]].color);
  }

  get curId() { return this.cur >= 0 ? WEAPONS[this.cur].id : 'fist'; }
  get varId() { return this.cur >= 0 ? WEAPONS[this.cur].variants[this.variant[this.cur]].id : 'fist'; }
  get armId() { return ARMS[this.arm].id; }

  select(i) {
    const game = this.game;
    if (i < 0 || i >= N || !this.owned[i]) return;
    this.sprR.kick(-2.2);
    this.idleT = 0;
    if (i === this.cur) {
      const nv = WEAPONS[i].variants.length;
      let v = this.variant[i];
      for (let k = 1; k <= nv; k++) { const c = (this.variant[i] + k) % nv; if (this.varOwned[i][c]) { v = c; break; } }
      if (v === this.variant[i]) return; // tek varyant: değişecek bir şey yok
      this.variant[i] = v;
      this.switchT = 0.3;
      this.equipSpin = i === 0 ? 1 : 0;
      this.cancelCharges();
      this.updateAccents();
      game.audio.play('uiClick');
      game.hud.weaponChanged();
      game.hud.message(WEAPONS[i].variants[this.variant[i]].name, 0.9, 'weapon');
      return;
    }
    this.last = this.cur;
    this.cur = i;
    this.switchT = 0;
    this.equipSpin = i === 0 ? 1 : 0;
    this.switchTime = game.time;
    this.cancelCharges();
    game.audio.play('uiClick');
    game.hud.weaponChanged();
  }

  switchArm() {
    const next = (this.arm + 1) % ARMS.length;
    if (!this.armsOwned[next]) return;
    this.arm = next;
    this.game.audio.play('uiClick');
    this.game.hud.message(ARMS[next].name, 0.9, 'weapon');
    this.game.hud.weaponChanged();
  }

  nextOwned(dir) {
    for (let k = 1; k <= N; k++) {
      const i = (((this.cur + dir * k) % N) + N) % N;
      if (this.owned[i]) return i;
    }
    return this.cur;
  }

  cancelCharges() {
    this.pierceCharge = 0;
    this.pierceReady = false;
    this.sharpCharge = 0;
    this.coreCharge = 0;
    this.cannonCharge = 0;
    this.freezeActive = false;
    this.flaming = false;
    this.game.audio.loop('pierce', false);
    this.game.audio.loop('flame', false);
  }

  // ---------------------------------------------------------------- nişan / namlu
  aim() {
    const game = this.game;
    const p = game.player;
    const o = p.eyePos(), d = p.aimDir();
    if (game.touch && game.touch.active && settings.aimAssist) {
      const best = this.assistDir(o, d, settings.aimAssist >= 2 ? 0.1 : 0.075);
      if (best) return { o, d: best };
    }
    return { o, d };
  }

  // Para yardımı: nişangâhın yakınındaki havadaki paraya yönel (KAPALI/HAFİF/GÜÇLÜ)
  coinAssistDir(o, d) {
    const lvl = settings.coinAssist | 0;
    if (!lvl || !this.coins.length) return null;
    const maxA = lvl >= 2 ? 0.24 : 0.1;
    let best = null, bestA = maxA;
    for (const c of this.coins) {
      if (!c.alive || c.age < 0.06) continue;
      const to = c.pos.clone().sub(o);
      const dist = to.length();
      if (dist > 60) continue;
      const a = Math.acos(Math.min(1, to.dot(d) / dist));
      if (a < bestA && this.game.world.lineOfSight(o, c.pos)) { bestA = a; best = to.normalize(); }
    }
    return best;
  }

  // Nişan yönüne en yakın görünür düşman noktası (açı sınırı içinde)
  assistDir(o, d, maxA, onlyEnemy = null) {
    const game = this.game;
    let best = null, bestA = maxA;
    for (const e of game.enemies) {
      if (e.dead || e.state === 'spawn' || (onlyEnemy && e !== onlyEnemy)) continue;
      for (const pt of [e.headPos(), e.center()]) {
        const to = pt.clone().sub(o);
        const dist = to.length();
        if (dist > 80) continue;
        const a = Math.acos(Math.min(1, to.dot(d) / dist));
        if (a < bestA && game.world.lineOfSight(o, pt)) { bestA = a; best = to.normalize(); }
      }
    }
    return best;
  }

  vmToWorld(obj, depth = 0.9) {
    this.scene.updateMatrixWorld(true);
    const v = obj.getWorldPosition(new THREE.Vector3());
    v.project(this.cam);
    const cam = this.game.camera;
    const w = new THREE.Vector3(v.x, v.y, 0.5).unproject(cam);
    const dir = w.sub(cam.position).normalize();
    return cam.position.clone().addScaledVector(dir, depth);
  }

  muzzleWorld() {
    if (this.cur < 0) return this.game.camera.position.clone();
    return this.vmToWorld(this.models[this.cur].muzzle);
  }

  kick(k, rot = 1) {
    this.recoil = Math.min(3, this.recoil + k);
    this.recoilRot = Math.min(3, this.recoilRot + k * rot);
    this.sprZ.kick(k * 0.9);
    this.sprR.kick(k * rot * 2.2);
    this.idleT = 0;
    this.inspectT = 0;
    this.flashT = 0.055;
    this.haptic(Math.min(40, 8 + k * 10));
  }

  // Oyuncu hareket olayları → kol/silah animasyonu
  onMove(ev, info = {}) {
    if (ev === 'land') this.sprY.kick(-Math.min(3.2, (info.fall || 0) * 0.05));
    else if (ev === 'jump') this.sprY.kick(0.9);
    else if (ev === 'dash') { this.arms.play('dash'); this.sprR.kick(0.8); }
    else if (ev === 'slam') this.arms.play('slam');
    else if (ev === 'wall') { if (info.left) this.arms.play('wall'); this.sprY.kick(1.2); }
  }

  haptic(ms) {
    if (!this.game.touch || !this.game.touch.active) return;
    try { if (navigator.vibrate) navigator.vibrate(ms); } catch (e) { /* desteklenmiyor */ }
  }

  quickdrawCheck() {
    if (this.game.time - this.switchTime < 0.35) {
      this.game.style.add('QUICKDRAW', 40, this.curId);
      this.switchTime = -10;
    }
  }

  impact(r, big = false) {
    const game = this.game;
    if (!r.world) return;
    const w = r.world;
    const n = new THREE.Vector3(w.nx, w.ny, w.nz);
    const p = new THREE.Vector3(w.x, w.y, w.z);
    game.fx.sparkDir(p, n, big ? 10 : 5, big ? 9 : 6, 0xffd080, 0.25, 0.04, 0.7);
    game.fx.bulletHole(w.x, w.y, w.z, w.nx, w.ny, w.nz, big ? 0.3 : 0.16);
    game.fx.smoke(p.clone().addScaledVector(n, 0.1), big ? 3 : 1, 0x9a8c80, big ? 0.7 : 0.4, 0.7, 0.8);
  }

  ejectCasing(red = false) {
    const game = this.game;
    const m = this.models[this.cur];
    const from = m.eject ? this.vmToWorld(m.eject, 0.55) : this.vmToWorld(m.muzzle, 0.55);
    const right = new THREE.Vector3(1, 0, 0).applyQuaternion(game.camera.quaternion);
    const vel = right.multiplyScalar(rand(2.5, 4)).add(new THREE.Vector3(0, rand(2, 3.5), 0)).add(game.player.vel.clone().multiplyScalar(0.8));
    game.fx.casing(from, vel, red);
  }

  // ---------------------------------------------------------------- güncelleme
  update(dt, input) {
    const game = this.game;
    const p = game.player;
    for (let i = 0; i < N; i++) this.cd[i] = Math.max(0, this.cd[i] - dt);
    this.punchCd = Math.max(0, this.punchCd - dt);
    this.blastCd = Math.max(0, this.blastCd - dt);
    this.hookCd = Math.max(0, this.hookCd - dt);
    this.cannonCd = Math.max(0, this.cannonCd - dt);
    this.coinCharges = Math.min(4, this.coinCharges + dt / COIN_TIME);
    this.sharpCharges = Math.min(3, this.sharpCharges + dt / 2.5);
    this.magnetCharges = Math.min(3, this.magnetCharges + dt / 3);
    this.railCharge = Math.min(1, this.railCharge + dt / RAIL_TIME);
    this.railHeat = Math.max(0, this.railHeat - dt * 0.6);
    if (!this.freezeActive) this.freezeEnergy = Math.min(1, this.freezeEnergy + dt * 0.15);
    if (!this.flaming) this.fuel = Math.min(1, this.fuel + dt * 0.2);
    if (this.heatBurst <= 0) this.heat = Math.max(0, this.heat - dt * 0.08);
    this.barrelSpin = damp(this.barrelSpin, 0, 3, dt);
    this.rocketLoadT = Math.min(1, this.rocketLoadT + dt / 0.8);
    if (this.owned[3] && this.railCharge >= 1 && !this.railWasReady) { this.railWasReady = true; game.audio.play('railReady'); }
    this.pumpAnim = Math.min(1, this.pumpAnim + dt / 0.6);
    this.corePopT = Math.min(1, this.corePopT + dt / 0.9);
    this.hammerT = Math.min(1, this.hammerT + dt / 0.25);
    this.coinFlick = Math.min(1, this.coinFlick + dt / 0.3);

    for (let i = this.coins.length - 1; i >= 0; i--) {
      this.coins[i].update(dt);
      if (!this.coins[i].alive) this.coins.splice(i, 1);
    }
    this.magnets = this.magnets.filter((m) => !m.dead);

    // Parry tamponu: yumruktan kısa süre sonra gelen mermiler de savuşturulur
    if (this.parryBuffer > 0) {
      this.parryBuffer -= dt;
      if (game.tryParry(true)) this.parryBuffer = 0;
    }

    const canAct = !p.dead && !p.frozen && game.state === 'playing';
    if (canAct) {
      for (let i = 0; i < N; i++) if (input.pressed('w' + (i + 1))) this.select(i);
      if (input.pressed('lastWeapon') && this.last >= 0) this.select(this.last);
      if (input.wheel && this.armed) this.select(this.nextOwned(input.wheel > 0 ? 1 : -1));
      if (input.pressed('arm')) this.switchArm();
      if (input.pressed('hook')) this.throwHook();
      this.armLogic(dt, input);
      if (!this.armed) {
        if (input.pressed('fire')) this.punch();
      } else if (this.switchT >= 0.8) this.fireLogic(dt, input);
    } else if (this.flaming) { this.flaming = false; game.audio.loop('flame', false); }
    this.updateHook(dt);
    this.animate(dt, input);
  }

  armLogic(dt, input) {
    if (this.armId === 'knuckle') {
      // basılı tut → şok dalgası
      if (input.is('punch')) {
        this.blastHold += dt;
        if (this.blastHold > 0.35 && this.blastCd <= 0) { this.blast(); this.blastHold = -10; }
      } else this.blastHold = 0;
      if (input.pressed('punch')) this.punch();
    } else if (input.pressed('punch')) this.punch();
  }

  fireLogic(dt, input) {
    const game = this.game;
    const v = this.varId;
    const c = this.cur;
    if (c === 0) {
      if (v === 'piercer') {
        if (input.is('alt') && this.cd[0] <= 0) {
          if (this.pierceCharge === 0) game.audio.loop('pierce', true, { buffer: 'chargeLoop', vol: 0.25 });
          this.pierceCharge = Math.min(1, this.pierceCharge + dt / 0.55);
          if (this.pierceCharge >= 1 && !this.pierceReady) { this.pierceReady = true; game.audio.play('chargeReady'); game.audio.loop('pierce', false); }
        } else if (this.pierceCharge > 0) {
          game.audio.loop('pierce', false);
          if (this.pierceCharge >= 1) this.firePiercer();
          this.pierceCharge = 0;
          this.pierceReady = false;
        }
        if (input.is('fire') && this.cd[0] <= 0 && this.pierceCharge <= 0) this.fireRevolver();
      } else if (v === 'marksman') {
        if (input.pressed('alt')) {
          if (this.coinCharges >= 1) this.tossCoin();
          else game.audio.play('empty');
        }
        if (input.is('fire') && this.cd[0] <= 0) this.fireRevolver();
      } else {
        // Sharpshooter: basılı tut, bırakınca duvarlardan seken ışın
        if (input.is('alt') && this.cd[0] <= 0 && this.sharpCharges >= 1) {
          if (this.sharpCharge === 0) game.audio.loop('pierce', true, { buffer: 'chargeLoop', vol: 0.2 });
          this.sharpCharge = Math.min(1, this.sharpCharge + dt / 0.4);
        } else if (this.sharpCharge > 0) {
          game.audio.loop('pierce', false);
          if (this.sharpCharge >= 1) this.fireSharpshooter();
          this.sharpCharge = 0;
        }
        if (input.is('fire') && this.cd[0] <= 0 && this.sharpCharge <= 0) this.fireRevolver();
      }
    } else if (c === 1) {
      if (v === 'core') {
        if (input.is('alt') && this.cd[1] <= 0) this.coreCharge = Math.min(1, this.coreCharge + dt / 0.5);
        else if (this.coreCharge > 0) { this.launchCore(this.coreCharge); this.coreCharge = 0; }
        if (input.is('fire') && this.cd[1] <= 0 && this.coreCharge <= 0) this.fireShotgun(0);
      } else if (v === 'pump') {
        if (input.pressed('alt') && this.cd[1] <= 0) {
          this.pumps++;
          this.cd[1] = 0.24;
          this.pumpAnim = 0.35;
          game.audio.play('pump', null, { rate: 1.2 + this.pumps * 0.1 });
          if (this.pumps >= 3) game.audio.play('overpump');
        }
        if (input.is('fire') && this.cd[1] <= 0) {
          if (this.pumps >= 3) this.overpump();
          else this.fireShotgun(this.pumps);
          this.pumps = 0;
        }
      } else {
        if (input.pressed('alt') && !this.sawOut) this.throwSaw();
        if (input.is('fire') && this.cd[1] <= 0) this.fireShotgun(0);
      }
    } else if (c === 2) {
      this.nailLogic(dt, input, v);
    } else if (c === 3) {
      if (input.pressed('fire')) {
        if (this.railCharge >= 1) this.fireRail(v);
        else game.audio.play('empty');
      }
    } else if (c === 4) {
      this.rocketLogic(dt, input, v);
    }
  }

  // ---------------------------------------------------------------- revolver
  fireRevolver() {
    const game = this.game;
    this.cd[0] = 0.36;
    this.kick(0.8, 1.2);
    this.drumTarget += Math.PI / 3;
    this.hammerT = 0;
    game.audio.play('revolver');
    const { o, d: d0 } = this.aim();
    const d = this.coinAssistDir(o, this.game.player.aimDir()) || d0;
    const r = game.hitscan(o, d, 400, { coins: true, cores: true });
    const h = r.hits[0];
    let end = r.end;
    if (h) {
      end = h.point;
      if (h.coin) this.ricochet(h.coin, 0);
      else if (h.core) {
        h.core.boosted = true; h.core.explode(); h.core.remove();
        game.style.add('CORE SNIPE', 80, 'revolver');
      } else {
        h.enemy.hit({ dmg: 1, part: h.part, point: h.point, dir: d, weapon: 'revolver', knock: 3 });
        this.quickdrawCheck();
      }
    } else this.impact(r);
    const from = this.muzzleWorld();
    game.fx.tracer(from, end, 0xfff0b0, 0.035, 0.09);
    game.fx.tracer(from, from.clone().lerp(end, Math.min(1, 3 / Math.max(1, from.distanceTo(end)))), 0xffffff, 0.06, 0.05);
    game.fx.smoke(from, 1, 0xb0a090, 0.25, 0.4, 0.5);
    game.flashLight(game.camera.position, 0xffc070, 3, 10, 0.05);
  }

  firePiercer() {
    const game = this.game;
    this.cd[0] = 0.5;
    this.kick(1.7, 1.6);
    this.drumTarget += Math.PI / 3;
    this.hammerT = 0;
    game.audio.play('piercer');
    game.shake(0.25);
    const { o, d: d0 } = this.aim();
    const d = this.coinAssistDir(o, this.game.player.aimDir()) || d0;
    const r = game.hitscan(o, d, 400, { coins: true, cores: true });
    let end = r.end;
    let stopped = false;
    for (const h of r.hits) {
      if (h.coin) { this.ricochet(h.coin, 1); end = h.point; stopped = true; break; }
      if (h.core) { h.core.boosted = true; h.core.explode(); h.core.remove(); game.style.add('CORE SNIPE', 80, 'revolver'); end = h.point; stopped = true; break; }
      h.enemy.hit({ dmg: 2.5, part: h.part, point: h.point, dir: d, weapon: 'revolver', knock: 8, headMult: 1.5 });
      this.quickdrawCheck();
    }
    if (!stopped) this.impact(r, true);
    const from = this.muzzleWorld();
    game.fx.tracer(from, end, 0x6fc0ff, 0.16, 0.35);
    game.fx.tracer(from, end, 0xffffff, 0.05, 0.22);
    game.fx.lightning(from, end, 0x9fd8ff, 0.025, 0.2, 10, 0.12);
    game.flashLight(game.camera.position, 0x80c0ff, 5, 14, 0.1);
  }

  // Sharpshooter: duvarlardan 3 kez seken, düşmanları delen ışın
  fireSharpshooter() {
    const game = this.game;
    this.sharpCharges -= 1;
    this.cd[0] = 0.5;
    this.kick(1.6, 1.4);
    this.drumTarget += Math.PI;
    this.hammerT = 0;
    game.audio.play('piercer', null, { rate: 1.25, exactRate: true });
    game.shake(0.2);
    let { o, d } = this.aim();
    let from = this.muzzleWorld();
    const hitSet = new Set();
    for (let bounce = 0; bounce < 4; bounce++) {
      const r = game.hitscan(o, d, 200, {});
      for (const h of r.hits) {
        if (!h.enemy || hitSet.has(h.enemy)) continue;
        hitSet.add(h.enemy);
        h.enemy.hit({ dmg: 2 + bounce * 0.5, part: h.part, point: h.point, dir: d, weapon: 'revolver', knock: 6, headMult: 1.5 });
        if (bounce > 0) game.style.add('RICOSHOT', 70, 'revolver', { count: bounce + 1 });
      }
      game.fx.tracer(from, r.end, 0xff6a4a, 0.1, 0.35);
      game.fx.tracer(from, r.end, 0xffffff, 0.035, 0.25);
      if (!r.world) break;
      const n = new THREE.Vector3(r.world.nx, r.world.ny, r.world.nz);
      game.fx.sparkDir(r.end, n, 8, 7, 0xff8a60, 0.3, 0.05, 0.6);
      // yansı + yakınlarda düşman varsa hafifçe ona yönel
      d = d.clone().addScaledVector(n, -2 * d.dot(n)).normalize();
      o = r.end.clone().addScaledVector(n, 0.05);
      const assist = this.assistDir(o, d, 0.35);
      if (assist) d = assist;
      from = o.clone();
    }
    game.flashLight(game.camera.position, 0xff6040, 5, 14, 0.1);
  }

  tossCoin() {
    const game = this.game;
    const p = game.player;
    this.coinCharges -= 1;
    this.coinFlick = 0;
    const f = p.aimDir();
    const pos = p.eyePos().addScaledVector(f, 0.6);
    pos.y -= 0.1;
    const vel = f.clone().multiplyScalar(13).add(new THREE.Vector3(0, 8.5, 0)).addScaledVector(p.vel, 0.6);
    this.coins.push(new Coin(game, pos, vel));
    this.arms.play('coin');
    game.audio.play('coin');
  }

  ricochet(coin, chain) {
    const game = this.game;
    coin.kill();
    const cp = coin.pos.clone();
    game.audio.play('ricochet', cp, { rate: 1 + chain * 0.08, exactRate: true });
    game.fx.sparkBurst(cp, 14, 9, 0xffd24a, 0.35, 0.05);
    game.fx.sprite(cp, 0xffe080, 1.8, 0.2, 'star', 1.8);
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
      if (e.dead || e.state === 'spawn' || e.type === 'trainer') continue;
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
      game.fx.tracer(cp, aimPt, 0xffd24a, 0.08, 0.34);
      game.fx.tracer(cp, aimPt, 0xffffff, 0.025, 0.2);
      const dir = aimPt.clone().sub(cp).normalize();
      game.style.add('RICOSHOT', 90 + chain * 40, 'revolver', { count: chain > 0 ? chain + 1 : 0 });
      target.hit({ dmg: 1.5 + chain, part, point: aimPt, dir, weapon: 'revolver', knock: 6, headMult: 2 });
      game.hitstop(0.045);
    } else {
      const dir = new THREE.Vector3(rand(-1, 1), rand(-0.3, 0.6), rand(-1, 1)).normalize();
      const hit = game.world.raycast(cp.x, cp.y, cp.z, dir.x, dir.y, dir.z, 40);
      const end = hit ? new THREE.Vector3(hit.x, hit.y, hit.z) : cp.clone().addScaledVector(dir, 40);
      game.fx.tracer(cp, end, 0xffd24a, 0.05, 0.2);
    }
  }

  // ---------------------------------------------------------------- shotgun
  fireShotgun(pumps) {
    const game = this.game;
    this.cd[1] = 0.95;
    this.kick(1.6 + pumps * 0.4, 1.4);
    this.pumpAnim = 0;
    game.audio.play('shotgun', null, { rate: 1 - pumps * 0.06, exactRate: pumps > 0 });
    game.audio.play('pump', null, { delay: 0.33 });
    game.shake(0.2 + pumps * 0.08);
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
        if (h.core) { h.core.boosted = true; h.core.explode(); h.core.remove(); }
        else {
          let e = acc.get(h.enemy);
          if (!e) { e = { dmg: 0, head: 0, n: 0, point: h.point, t: h.t }; acc.set(h.enemy, e); }
          e.dmg += pd * (h.part === 'head' ? 1.5 : 1);
          if (h.part === 'head') e.head++;
          e.n++;
        }
      } else if (r.world) {
        if (k % 2 === 0) game.fx.bulletHole(r.world.x, r.world.y, r.world.z, r.world.nx, r.world.ny, r.world.nz, 0.12);
        if (k % 3 === 0) game.fx.sparkDir(end, new THREE.Vector3(r.world.nx, r.world.ny, r.world.nz), 3, 5, 0xffd080, 0.2, 0.04, 0.8);
      }
      game.fx.tracer(from, end, 0xffe0a0, 0.028, 0.07);
    }
    for (const [e, a] of acc) {
      // yakın mesafe isabeti: hemen ardından yumruk = SHOTGUN PARRY
      if (a.t < 4.5) this.lastShotgunHit = { enemy: e, time: game.time };
      e.hit({ dmg: a.dmg, part: a.head >= Math.max(2, a.n * 0.5) ? 'head' : 'body', headMult: 1, point: a.point, dir: d, weapon: 'shotgun', knock: 3 + a.n * 1.3, pellets: a.n });
    }
    if (acc.size) this.quickdrawCheck();
    game.fx.smoke(from, 3, 0xa09080, 0.5, 0.7, 0.6);
    game.flashLight(game.camera.position, 0xffb060, 5, 12, 0.07);
    this.pendingCasing = 0.36;
  }

  launchCore(charge) {
    const game = this.game;
    const p = game.player;
    this.cd[1] = 0.9;
    this.kick(1.1, 0.6);
    this.pumpAnim = 0;
    this.corePopT = 0;
    const d = p.aimDir();
    const pos = p.eyePos().addScaledVector(d, 0.8);
    pos.y -= 0.12;
    const vel = d.clone().multiplyScalar(18 + 26 * charge).add(new THREE.Vector3(0, 2 + 2 * charge, 0)).addScaledVector(p.vel, 0.3);
    game.addProjectile(new Projectile(game, { kind: 'core', pos, vel, radius: 0.22, damage: 0, parryable: false, gravity: 20, life: 3, color: 0x3aa0ff }));
    game.audio.play('coreLaunch');
    game.audio.play('pump', null, { delay: 0.3 });
  }

  overpump() {
    const game = this.game;
    const p = game.player;
    this.cd[1] = 1.2;
    this.kick(2.8, 2);
    this.pumpAnim = 0;
    game.audio.play('shotgun');
    const pos = p.eyePos().addScaledVector(p.aimDir(), 1.2);
    game.explode(pos, 7, 6, { owner: 'player', playerDmg: 35, knock: 22, weapon: 'shotgun' });
  }

  // Sawed-On: zincirli testereyi fırlat (gider, biçer, geri gelir)
  throwSaw() {
    const game = this.game;
    const p = game.player;
    this.sawOut = true;
    this.kick(0.8, 0.5);
    const d = p.aimDir();
    const g = new THREE.Group();
    const blade = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.04, 0.16), new THREE.MeshLambertMaterial({ color: 0xd8dce4 }));
    const teeth = new THREE.Mesh(new THREE.BoxGeometry(0.54, 0.05, 0.04), new THREE.MeshBasicMaterial({ color: 0xff3a2a }));
    teeth.position.z = 0.09;
    g.add(blade, teeth);
    game.addProjectile(new Projectile(game, { kind: 'chainsaw', mesh: g, pos: p.eyePos().addScaledVector(d, 0.8), vel: d.clone().multiplyScalar(38), damage: 0.4, parryable: false, life: 6 }));
    game.audio.play('chainsaw');
    game.audio.play('swing');
  }

  sawReturned() {
    this.sawOut = false;
    this.game.audio.play('pump', null, { rate: 1.3 });
  }

  // ---------------------------------------------------------------- nailgun
  nailLogic(dt, input, v) {
    const game = this.game;
    this.nailT -= dt;
    if (this.heatBurst > 0) {
      // Overheat: kızgın çivi yağmuru
      this.heatBurst -= dt;
      this.heat = Math.max(0, this.heatBurst / 1.2);
      if (this.nailT <= 0) { this.fireNail(true, 0.035); this.nailT = 0.035; }
      return;
    }
    if (input.is('fire') && this.nailT <= 0) {
      if (v === 'sawblade') { this.fireSawblade(); this.nailT = 0.3; }
      else { this.fireNail(false); this.nailT = 0.075; }
      if (v === 'overheat') this.heat = Math.min(1, this.heat + 0.03);
    }
    if (input.pressed('alt')) {
      if (v === 'overheat') {
        if (this.heat >= 1) { this.heatBurst = 1.2; game.audio.play('overpump', null, { rate: 1.6 }); game.style.add(null, 0); }
        else game.audio.play('empty');
      } else if (this.magnetCharges >= 1) this.throwMagnet();
      else game.audio.play('empty');
    }
  }

  fireNail(heated, spreadOverride) {
    const game = this.game;
    const { o, d } = this.aim();
    const sp = spreadOverride ?? 0.03;
    const dir = d.clone().add(new THREE.Vector3(rand(-sp, sp), rand(-sp, sp), rand(-sp, sp))).normalize();
    const from = this.muzzleWorld();
    game.addProjectile(new Projectile(game, { kind: 'nail', pos: from, vel: dir.multiplyScalar(95), radius: 0.12, damage: heated ? 0.3 : 0.14, gravity: 2.5, life: 1.6, heated }));
    this.recoil = Math.min(3, this.recoil + 0.12);
    this.flashT = 0.03;
    this.barrelSpin = 1;
    game.audio.play('schismShot', null, { rate: heated ? 1.6 : 2.1, exactRate: true, vol: 0.55 });
  }

  fireSawblade() {
    const game = this.game;
    const { d } = this.aim();
    const from = this.muzzleWorld();
    game.addProjectile(new Projectile(game, { kind: 'saw', pos: from, vel: d.clone().multiplyScalar(55), radius: 0.28, damage: 0.55, gravity: 1, life: 3, bounces: 3 }));
    this.kick(0.35, 0.4);
    this.barrelSpin = 1;
    game.audio.play('chainsaw', null, { rate: 1.6, vol: 0.5 });
  }

  throwMagnet() {
    const game = this.game;
    const p = game.player;
    this.magnetCharges -= 1;
    const d = p.aimDir();
    const m = new Projectile(game, { kind: 'magnet', pos: p.eyePos().addScaledVector(d, 0.7), vel: d.clone().multiplyScalar(26).add(new THREE.Vector3(0, 4, 0)), life: 8, parryable: false });
    game.addProjectile(m);
    this.magnets.push(m);
    if (this.magnets.length > 3) this.magnets.shift().remove();
    game.audio.play('coin', null, { rate: 0.6, exactRate: true });
  }

  // ---------------------------------------------------------------- railcannon
  fireRail(v) {
    const game = this.game;
    const p = game.player;
    this.railCharge = 0;
    this.railWasReady = false;
    this.railHeat = 1;
    this.cd[3] = 0.8;
    this.kick(3, 1.2);
    game.audio.play('rail', null, { rate: v === 'malicious' ? 0.8 : v === 'screwdriver' ? 1.15 : 1, exactRate: true });
    game.shake(0.85);
    this.haptic(80);
    const { o, d } = this.aim();
    const r = game.hitscan(o, d, 500, {});
    const from = this.muzzleWorld();
    const col = v === 'malicious' ? 0xff4a2a : v === 'screwdriver' ? 0x5aff7a : 0x40e8ff;
    let end = r.end;
    if (v === 'screwdriver') {
      const h = r.hits.find((x) => x.enemy);
      if (h) {
        end = h.point;
        h.enemy.hit({ dmg: 2, part: h.part, point: h.point, dir: d, weapon: 'rail', knock: 6 });
        h.enemy.drill = 3;
        game.style.add('DRILLED', 60, 'rail');
      }
    } else {
      for (const h of r.hits) {
        if (!h.enemy) continue;
        h.enemy.hit({ dmg: v === 'malicious' ? 5 : 8, part: h.part, point: h.point, dir: d, weapon: 'rail', knock: 25, headMult: 1.5 });
      }
    }
    if (r.hits.length) this.quickdrawCheck();
    game.fx.tracer(from, end, col, 0.45, 0.7);
    game.fx.tracer(from, end, 0xffffff, 0.14, 0.5);
    for (let k = 0; k < 3; k++) game.fx.lightning(from, end, col, 0.03, 0.35, 14, 0.45);
    if (v === 'malicious') game.explode(end, 8, 5, { owner: 'player', playerDmg: 35, knock: 24, weapon: 'rail' });
    else if (r.world) {
      game.fx.sparkBurst(end, 30, 12, col, 0.6, 0.08);
      game.fx.bulletHole(r.world.x, r.world.y, r.world.z, r.world.nx, r.world.ny, r.world.nz, 0.6);
      game.fx.smoke(end, 5, 0x8098a0, 0.8, 1, 1);
    }
    game.flashLight(end, col, 10, 20, 0.15);
    game.flashLight(game.camera.position, col, 6, 12, 0.1);
    p.vel.addScaledVector(d, -7);
  }

  // ---------------------------------------------------------------- rocket launcher
  rocketLogic(dt, input, v) {
    const game = this.game;
    if (input.is('fire') && this.cd[4] <= 0) this.fireRocket();
    if (v === 'freeze') {
      const want = input.is('alt') && this.freezeEnergy > 0.02;
      if (want !== this.freezeActive) {
        this.freezeActive = want;
        game.audio.play(want ? 'chargeReady' : 'uiClick', null, { rate: 0.6, exactRate: true });
      }
      if (this.freezeActive) this.freezeEnergy = Math.max(0, this.freezeEnergy - dt * 0.3);
    } else if (v === 'cannon') {
      if (input.is('alt') && this.cannonCd <= 0) this.cannonCharge = Math.min(1, this.cannonCharge + dt / 0.8);
      else if (this.cannonCharge > 0) { this.fireCannonball(this.cannonCharge); this.cannonCharge = 0; }
    } else {
      const want = input.is('alt') && this.fuel > 0.02;
      if (want !== this.flaming) { this.flaming = want; game.audio.loop('flame', want, { buffer: 'slideLoop', vol: 0.35 }); }
      if (this.flaming) { this.fuel = Math.max(0, this.fuel - dt * 0.35); this.flame(dt); }
    }
  }

  fireRocket() {
    const game = this.game;
    this.cd[4] = 0.85;
    this.rocketLoadT = 0;
    this.kick(1.4, 0.8);
    const { d } = this.aim();
    const from = this.muzzleWorld();
    game.addProjectile(new Projectile(game, { kind: 'rocket', pos: from, vel: d.clone().multiplyScalar(42), radius: 0.18, parryable: false, life: 5 }));
    game.audio.play('coreLaunch', null, { rate: 0.8, exactRate: true });
    game.audio.play('dash', null, { vol: 0.6 });
    game.fx.smoke(from, 4, 0x8a8480, 0.6, 0.8, 0.4);
  }

  fireCannonball(charge) {
    const game = this.game;
    this.cannonCd = 4;
    this.kick(2.4, 1.4);
    const { d } = this.aim();
    const from = this.muzzleWorld();
    game.addProjectile(new Projectile(game, { kind: 'cannonball', pos: from, vel: d.clone().multiplyScalar(25 + 30 * charge).add(new THREE.Vector3(0, 2, 0)), radius: 0.4, damage: 4 + 3 * charge, gravity: 16, parryable: false, life: 4 }));
    game.audio.play('shotgun', null, { rate: 0.6, exactRate: true });
    game.shake(0.4);
  }

  // Firestarter: kısa menzilli alev (düşmanları tutuşturur)
  flame(dt) {
    const game = this.game;
    const { o, d } = this.aim();
    const from = this.muzzleWorld();
    game.fx.sparkDir(from, d, 3, 16, Math.random() < 0.5 ? 0xff7a20 : 0xffc040, 0.35, 0.12, 0.25);
    for (const e of game.enemies) {
      if (e.dead || e.state === 'spawn') continue;
      const to = e.center().sub(o);
      const dist = to.length();
      if (dist > 7.5) continue;
      if (to.normalize().dot(d) < 0.8) continue;
      e.burn = Math.max(e.burn || 0, 3);
      e.flameTick = (e.flameTick || 0) - dt;
      if (e.flameTick <= 0) {
        e.flameTick = 0.2;
        e.hit({ dmg: 0.25, part: 'body', point: e.center(), dir: d, weapon: 'rocket', knock: 1, quiet: true, noHeal: false });
      }
    }
  }

  // ---------------------------------------------------------------- kollar
  punch() {
    if (this.punchCd > 0) return;
    const game = this.game;
    const knuckle = this.armId === 'knuckle';
    this.punchCd = knuckle ? 0.7 : 0.4;
    this.punchT = 0;
    this.arms.play('punch');
    this.sprY.kick(-0.6);
    game.audio.play('punch', null, { rate: knuckle ? 0.7 : 1, exactRate: true });
    if (game.tryParry()) return;
    this.parryBuffer = [0.18, 0.26, 0.34][settings.parryAssist | 0] ?? 0.18; // erken basılan yumruk da yakalasın (yardımla daha uzun)
    game.meleePunch(knuckle);
  }

  // Knuckleblaster şok dalgası
  blast() {
    const game = this.game;
    const p = game.player;
    this.blastCd = 3;
    this.punchT = 0;
    const pos = p.eyePos().addScaledVector(p.aimDir(), 1);
    game.fx.shell(pos, 0xff6a3a, 6, 0.4);
    game.fx.ring(p.pos.clone(), 0xff6a3a, 7, 0.5);
    game.audio.play('explosion', null, { rate: 1.3, exactRate: true, vol: 0.7 });
    game.shake(0.5);
    for (const e of game.enemies) {
      if (e.dead) continue;
      const c = e.center();
      const dist = c.distanceTo(pos);
      if (dist > 6 + e.r) continue;
      const dir = c.clone().sub(pos).setY(0.6).normalize();
      e.hit({ dmg: 1.2, part: 'body', point: c, dir, weapon: 'punch', knock: 30 });
    }
    for (const pr of game.projectiles) if (!pr.dead && pr.owner === 'enemy' && pr.pos.distanceTo(pos) < 6) { pr.remove(); game.fx.sparkBurst(pr.pos, 6, 5, 0xff8a60, 0.3, 0.05); }
  }

  // Whiplash: kanca at — hafif düşmanı çek, ağır düşmana kendini çek
  throwHook() {
    if (!this.hookOwned || this.hook || this.hookCd > 0) return;
    const game = this.game;
    const p = game.player;
    const d = p.aimDir();
    const o = p.eyePos();
    this.hook = { phase: 'out', pos: o.clone().addScaledVector(d, 0.5), vel: d.clone().multiplyScalar(90), t: 0, target: null };
    this.arms.play('hook');
    game.audio.play('walljump', null, { rate: 0.7, exactRate: true });
  }

  updateHook(dt) {
    const h = this.hook;
    const game = this.game;
    const p = game.player;
    if (!h) { this.rope.visible = false; this.hookMesh.visible = false; return; }
    h.t += dt;
    const hand = this.vmToWorld(this.hookHand, 0.6);
    if (h.phase === 'out') {
      const sp = h.vel.length(), inv = 1 / sp;
      const prev = h.pos.clone();
      const w = game.world.raycast(h.pos.x, h.pos.y, h.pos.z, h.vel.x * inv, h.vel.y * inv, h.vel.z * inv, sp * dt);
      h.pos.addScaledVector(h.vel, dt);
      for (const e of game.enemies) {
        if (e.dead || e.type === 'trainer') continue;
        if (e.segmentHit(prev, h.pos, 0.35)) { h.target = e; h.phase = 'pull'; h.t = 0; break; }
      }
      if (h.phase === 'out' && (w || h.t > 0.45)) h.phase = 'back';
      if (h.target) {
        game.audio.play('punchHit', h.pos, { vol: 0.7 });
        game.style.add('HOOKED', 30);
        if (h.target.big) game.hud.message('ÇEKİLİYOR', 0.5, 'weapon');
      }
    } else if (h.phase === 'pull') {
      const e = h.target;
      if (!e || e.dead || h.t > 0.9) { h.phase = 'back'; }
      else {
        h.pos.copy(e.center());
        const to = e.center().sub(p.eyePos());
        const dist = to.length();
        if (dist < 2.2) h.phase = 'back';
        else if (e.big) {
          // ağır düşman: oyuncuyu çek
          p.vel.copy(to.normalize().multiplyScalar(34));
          p.grounded = false;
          p.slamming = false;
        } else {
          // hafif düşman: oyuncuya çek
          e.vel.copy(to.normalize().multiplyScalar(-30));
          e.vel.y = Math.max(e.vel.y, 3);
          e.grounded = false;
        }
      }
    } else {
      const to = hand.clone().sub(h.pos);
      const d = to.length();
      if (d < 1) { this.hook = null; this.hookCd = 0.35; this.rope.visible = false; this.hookMesh.visible = false; return; }
      h.pos.addScaledVector(to.normalize(), Math.min(d, 110 * dt));
    }
    const pa = this.rope.geometry.attributes.position;
    pa.setXYZ(0, hand.x, hand.y, hand.z);
    pa.setXYZ(1, h.pos.x, h.pos.y, h.pos.z);
    pa.needsUpdate = true;
    this.rope.visible = true;
    this.hookMesh.visible = true;
    this.hookMesh.position.copy(h.pos);
    this.hookMesh.lookAt(hand);
  }

  // ---------------------------------------------------------------- animasyon
  animate(dt, input) {
    const game = this.game;
    const p = game.player;
    this.switchT = Math.min(1, this.switchT + dt / 0.3);
    const sw = 1 - easeOut(this.switchT);
    this.recoil = damp(this.recoil, 0, 12, dt);
    this.recoilRot = damp(this.recoilRot, 0, 9, dt);
    this.swayX = damp(this.swayX, clamp(-input.mdx * 0.0009, -0.06, 0.06), 9, dt);
    this.swayY = damp(this.swayY, clamp(input.mdy * 0.0009, -0.06, 0.06), 9, dt);
    const bt = p.bobT, ba = p.bob;
    const bx = Math.sin(bt * 0.95) * 0.014 * ba;
    const by = -Math.abs(Math.cos(bt * 0.95)) * 0.016 * ba;
    const breath = Math.sin(game.time * 1.6) * 0.004 * (1 - ba);
    const airY = clamp(-p.vel.y * 0.0012, -0.03, 0.03);
    this.slideK = damp(this.slideK || 0, p.sliding ? 1 : 0, 10, dt);

    const sz = this.sprZ.update(dt), sy = this.sprY.update(dt), sr = this.sprR.update(dt);
    // uzun süre boşta kalınca silahı inceleme
    const idle = !input.is('fire') && !input.is('alt') && Math.hypot(p.vel.x, p.vel.z) < 0.5 && p.grounded;
    this.idleT = idle ? this.idleT + dt : 0;
    if (this.idleT > 9 && this.armed && this.inspectT <= 0) { this.inspectT = 1.5; this.idleT = 0; if (this.cur === 0) this.equipSpin = 1; }
    this.inspectT = Math.max(0, this.inspectT - dt);
    const insp = this.inspectT > 0 ? Math.sin((1 - this.inspectT / 1.5) * Math.PI) : 0;
    for (let i = 0; i < N; i++) this.models[i].group.visible = i === this.cur;
    this.fist.visible = !this.armed && this.punchT > 0.3;
    if (!this.armed) this.fist.position.set(0.3 + bx + this.swayX, -0.3 + by + breath + this.swayY - this.slideK * 0.03 + sy * 0.05, -0.52 + sz * 0.04);

    if (this.armed) {
      const m = this.models[this.cur];
      const shake = new THREE.Vector3();
      const charging = (this.cur === 0 && (this.pierceCharge > 0 || this.sharpCharge > 0)) || (this.cur === 1 && this.varId === 'pump' && this.pumps >= 3) || (this.cur === 4 && this.cannonCharge > 0) || this.heatBurst > 0;
      if (charging) shake.set(rand(-1, 1), rand(-1, 1), 0).multiplyScalar(0.005);
      const lift = this.cur === 1 ? this.coreCharge : this.cur === 4 ? this.cannonCharge * 0.5 : 0;
      const coinDip = this.coinFlick < 1 ? Math.sin(this.coinFlick * Math.PI) : 0;
      m.group.position.set(
        m.base.x + bx + this.swayX + shake.x - this.slideK * 0.04 - insp * 0.08,
        m.base.y + by + breath + this.swayY - sw * 0.5 + airY + shake.y - this.recoil * 0.012 - this.slideK * 0.02 - coinDip * 0.05 + sy * 0.05 + insp * 0.06,
        m.base.z + this.recoil * 0.05 + sz * 0.06
      );
      if (this.equipSpin > 0) this.equipSpin = Math.max(0, this.equipSpin - dt / 0.38);
      const spin = this.equipSpin > 0 ? easeInOut(1 - this.equipSpin) * Math.PI * 2 : 0;
      m.group.rotation.set(this.recoilRot * 0.2 + sr * 0.07 + sw * 0.9 + this.swayY * 1.5 + lift * 0.35 - coinDip * 0.3 + insp * 0.25, m.ry + this.swayX * 1.5 + insp * 0.9, -p.tilt * 1.2 + this.slideK * 0.25 + insp * 0.3);
      m.gun.rotation.x = this.cur === 0 ? -spin : 0;
      m.gun.rotation.z = 0;

      if (this.cur === 0) {
        const ch = Math.max(this.pierceCharge, this.sharpCharge);
        if (ch > 0) this.drumTarget += dt * (4 + ch * 20);
        this.drumAngle = damp(this.drumAngle, this.drumTarget, 16, dt);
        m.drum.rotation.z = this.drumAngle;
        m.hammer.rotation.x = this.hammerT < 1 ? -0.6 * (1 - easeOut(this.hammerT)) : 0;
        this.accents[0].color.setHex(WEAPONS[0].variants[this.variant[0]].color).multiplyScalar(1 + ch * 2);
      } else if (this.cur === 1) {
        const t = this.pumpAnim;
        const k = t > 0.45 && t < 0.95 ? Math.sin(((t - 0.45) / 0.5) * Math.PI) : 0;
        m.pump.position.z = -0.4 + k * 0.13;
        m.gun.rotation.z = k * 0.12;
        if (this.pendingCasing !== undefined) {
          this.pendingCasing -= dt;
          if (this.pendingCasing <= 0) { this.ejectCasing(true); this.pendingCasing = undefined; }
        }
        m.coreCell.visible = this.varId !== 'core' || this.corePopT > 0.6;
        m.saw.visible = this.varId === 'saw' && !this.sawOut;
        const hot = this.varId === 'pump' ? this.pumps / 3 : this.coreCharge;
        const base = WEAPONS[1].variants[this.variant[1]].color;
        this.accents[1].color.setHex(this.varId === 'pump' && this.pumps >= 3 ? (Math.sin(game.time * 40) > 0 ? 0xff2010 : 0xffc020) : base).multiplyScalar(1 + hot * 1.5);
      } else if (this.cur === 2) {
        this.barrelAngle += dt * (2 + this.barrelSpin * 30);
        m.barrels.rotation.z = this.barrelAngle;
        const h = this.heat;
        this.heatMat.color.setRGB(0.25 + h * 0.75, 0.06 + h * 0.4, 0.03 + h * 0.1);
        if (this.heatBurst > 0) this.heatMat.color.setHex(Math.sin(game.time * 50) > 0 ? 0xffffff : 0xff8020);
      } else if (this.cur === 3) {
        const c = this.railCharge;
        const h = this.railHeat;
        const vc = new THREE.Color(WEAPONS[3].variants[this.variant[3]].color);
        this.coilMat.color.setRGB(vc.r * (0.1 + 0.9 * c) + h, vc.g * (0.1 + 0.9 * c) + h * 0.8, vc.b * (0.1 + 0.9 * c) + h * 0.6);
        if (c >= 1) this.coilMat.color.multiplyScalar(1 + Math.sin(game.time * 8) * 0.3);
        this.meterMat.color.copy(this.coilMat.color);
        for (let i = 0; i < m.coils.length; i++) m.coils[i].rotation.z += dt * (1 + c * 6 + h * 20) * (i % 2 ? 1 : -1);
        m.meter.scale.z = Math.max(0.05, c);
        m.meter.position.z = 0.16 - (1 - c) * 0.065;
        if (h > 0.2 && Math.random() < dt * 20) game.fx.smoke(this.vmToWorld(m.muzzle, 1.1), 1, 0x9ab0b8, 0.25, 0.6, 1.2);
      } else if (this.cur === 4) {
        m.nose.visible = this.rocketLoadT > 0.7 && this.varId !== 'cannon' || (this.varId === 'cannon' && this.rocketLoadT > 0.7 && this.cannonCharge <= 0);
        m.ball.visible = this.varId === 'cannon' && this.cannonCharge > 0;
        const base = WEAPONS[4].variants[this.variant[4]].color;
        this.accents[4].color.setHex(this.freezeActive ? 0xffffff : base);
      }
    }

    // sol kol eylemleri ve kayarken bacak (arms.js)
    this.punchT += dt;
    this.arms.update(dt);

    // namlu alevi
    this.flashT -= dt;
    if (this.flashT > 0 && this.armed) {
      const m = this.models[this.cur];
      this.scene.updateMatrixWorld(true);
      const mp = m.muzzle.getWorldPosition(new THREE.Vector3());
      const s = [0.34, 0.55, 0.25, 0.7, 0.5][this.cur];
      const col = this.cur === 3 ? WEAPONS[3].variants[this.variant[3]].color : this.cur === 0 && this.varId === 'piercer' && this.recoil > 1.2 ? 0x9fd8ff : 0xffe0a0;
      for (const f of this.flashes) {
        f.visible = true;
        f.position.copy(mp);
        f.scale.setScalar(s * rand(0.7, 1.3));
        f.material.rotation = rand(0, Math.PI);
        f.material.color.setHex(col);
      }
      this.flashGlow.visible = true;
      this.flashGlow.position.copy(mp);
      this.flashGlow.scale.setScalar(s * 2.2);
      this.flashGlow.material.color.setHex(col);
      this.flashLightVM.intensity = 5;
    } else {
      for (const f of this.flashes) f.visible = false;
      this.flashGlow.visible = false;
      this.flashLightVM.intensity = 0;
    }
  }

  hudInfo() {
    const arm = ARMS[this.arm];
    const common = { owned: this.owned, arm: arm.name, armColor: '#' + arm.color.toString(16).padStart(6, '0'), hook: this.hookOwned, armsOwned: this.armsOwned };
    if (!this.armed) return { ...common, cur: -1, name: 'YUMRUK', variant: arm.name, color: common.armColor, varId: 'fist' };
    const W = WEAPONS[this.cur];
    const v = W.variants[this.variant[this.cur]];
    return {
      ...common,
      cur: this.cur,
      name: W.name,
      variant: v.name,
      color: '#' + v.color.toString(16).padStart(6, '0'),
      varId: v.id,
      coins: this.coinCharges,
      sharp: this.sharpCharges,
      rail: this.railCharge,
      pumps: this.pumps,
      pierce: Math.max(this.pierceCharge, this.sharpCharge),
      core: this.coreCharge,
      heat: this.heat,
      magnets: this.magnetCharges,
      freeze: this.freezeEnergy,
      fuel: this.fuel,
      cannon: this.cannonCd > 0 ? 1 - this.cannonCd / 4 : 1,
      sawOut: this.sawOut,
    };
  }
}
