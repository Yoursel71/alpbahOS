// V1'in görünür kolları ve bacağı (viewmodel): parmaklı Feedbacker / Knuckleblaster / Whiplash
// elleri ve eylem animasyonları — yumruk, para fırlatma, kanca atma, duvar sıçraması, yere çakma,
// atılma, kayarken ayak. Silahlar da yay (spring) tabanlı geri tepme / iniş / çekme hareketi kullanır.
import * as THREE from 'three';
import { clamp } from './util.js';

const easeOut = (t) => 1 - Math.pow(1 - clamp(t, 0, 1), 3);
const easeIn = (t) => { t = clamp(t, 0, 1); return t * t; };
const lerpPose = (a, b, k) => a.map((v, i) => v + (b[i] - v) * k);

function box(w, h, d, mat, x, y, z, parent) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  m.position.set(x, y, z);
  parent.add(m);
  return m;
}

// Sönümlü yay: x → 0'a döner, v hız
export class Spring {
  constructor(k = 170, c = 15) { this.k = k; this.c = c; this.x = 0; this.v = 0; }
  kick(v) { this.v += v; }
  update(dt) {
    const steps = dt > 0.02 ? 2 : 1;
    const h = dt / steps;
    for (let i = 0; i < steps; i++) {
      this.v += (-this.k * this.x - this.c * this.v) * h;
      this.x += this.v * h;
    }
    return this.x;
  }
}

// Parmaklı el. Kol -z yönüne uzanır; bilek orijinde, ön kol +z'de. Sol el; sağ el için scale.x = -1.
// kind: 'feedbacker' | 'knuckle' | 'whiplash' | 'plain'
export function buildArm(M, kind) {
  const g = new THREE.Group();
  const knuckle = kind === 'knuckle';
  const whip = kind === 'whiplash';
  const plain = kind === 'plain';
  const main = knuckle ? M.red : whip ? M.green : plain ? M.armLight : M.blue;
  const dark = M.armDark;
  const glowMat = new THREE.MeshBasicMaterial({ color: knuckle ? 0xffa040 : whip ? 0xb8ff80 : plain ? 0x9aa6c0 : 0x8fd0ff });
  const s = knuckle ? 1.2 : 1;
  // ön kol: renkli zırh + açık metal arka parça + üst plaka + parlayan şeritler
  box(0.12 * s, 0.115 * s, 0.26, main, 0, 0, 0.17, g);
  box(0.105 * s, 0.1 * s, 0.26, M.armLight, 0, -0.005, 0.42, g);
  box(0.135 * s, 0.04, 0.14, dark, 0, 0.062 * s, 0.14, g);
  if (!plain) {
    box(0.016, 0.02, 0.2, glowMat, 0.062 * s, 0.025, 0.17, g);
    box(0.016, 0.02, 0.2, glowMat, -0.062 * s, 0.025, 0.17, g);
  }
  if (knuckle) {
    // pistonlar ve şarjör
    for (const x of [-0.045, 0.045]) {
      const c = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.2, 6), M.black);
      c.rotation.x = Math.PI / 2;
      c.position.set(x, 0.095, 0.16);
      g.add(c);
    }
    box(0.09, 0.05, 0.08, glowMat, 0, 0.1, 0.3, g);
  }
  if (whip) {
    const hook = new THREE.Mesh(new THREE.ConeGeometry(0.032, 0.11, 5), M.black);
    hook.rotation.x = -Math.PI / 2;
    hook.position.set(0, 0.075, -0.02);
    g.add(hook);
    box(0.05, 0.03, 0.18, glowMat, 0, 0.075, 0.14, g);
  }
  // bilek ve avuç
  box(0.125 * s, 0.1 * s, 0.07, dark, 0, 0, 0, g);
  const palm = box(0.13 * s, 0.055 * s, 0.12 * s, main, 0, 0, -0.095 * s, g);
  palm.userData.palm = true;
  if (knuckle) box(0.15, 0.05, 0.05, M.black, 0, 0.045, -0.15 * s, g); // muşta
  // parmaklar: 2 eklemli, kıvrılabilir
  const fingers = [];
  for (let i = 0; i < 4; i++) {
    const x = (-0.045 + i * 0.03) * s;
    const p1 = new THREE.Group();
    p1.position.set(x, 0, -0.155 * s);
    g.add(p1);
    box(0.024 * s, 0.028 * s, 0.052 * s, main, 0, 0, -0.025 * s, p1);
    const p2 = new THREE.Group();
    p2.position.set(0, 0, -0.052 * s);
    p1.add(p2);
    box(0.022 * s, 0.025 * s, 0.042 * s, dark, 0, 0, -0.02 * s, p2);
    fingers.push([p1, p2]);
  }
  // başparmak (sol elde avuç aşağıyken sağ tarafta)
  const t1 = new THREE.Group();
  t1.position.set(0.07 * s, -0.005, -0.075 * s);
  t1.rotation.y = -0.7;
  g.add(t1);
  box(0.024 * s, 0.026 * s, 0.065 * s, main, 0, 0, -0.032 * s, t1);
  g.userData = { fingers, thumb: t1, glowMat, glowBase: glowMat.color.getHex() };
  g.visible = false;
  return g;
}

// Parmak kıvrımı: 0 açık el, 1 yumruk
export function setCurl(model, c, thumb = c) {
  const { fingers, thumb: t1 } = model.userData;
  for (let i = 0; i < fingers.length; i++) {
    const [p1, p2] = fingers[i];
    const ci = clamp(c + (i - 1.5) * 0.04, 0, 1);
    p1.rotation.x = -ci * 1.45;
    p2.rotation.x = -ci * 1.7;
  }
  t1.rotation.x = -thumb * 0.9;
  t1.rotation.z = thumb * 0.6;
}

// Sol kol pozları: [x, y, z, rx, ry, rz]. ry < 0 → ön kol sol-geriye, ekranın sol altına uzanır.
const OFF = [-0.5, -0.5, -0.22, 0.5, -0.6, 0.1];
const COCK = [-0.4, -0.34, -0.3, 0.45, -0.75, 0.25];
const HIT = [-0.1, -0.13, -0.76, 0.26, -0.36, 0.12];
const COIN = [-0.2, -0.16, -0.58, 0.15, -0.35, 1.05];
const REACH = [-0.16, -0.17, -0.72, 0.24, -0.38, 0.1];
const PUSH = [-0.36, -0.12, -0.5, 0.55, -0.25, -1.35];
const GUARD = [-0.26, -0.2, -0.5, 0.35, -0.5, 0.3];
const DOWN = [-0.18, -0.32, -0.55, 0.9, -0.4, 0.2];
const SWING = [-0.3, -0.22, -0.46, 0.3, -0.95, 0.5];

// Kayarken görünen V1 bacağı/ayağı
function buildLeg(M) {
  const g = new THREE.Group();
  box(0.12, 0.12, 0.5, M.armLight, 0, 0, 0.1, g); // kaval
  box(0.1, 0.03, 0.3, M.blue, 0, 0.065, 0.1, g);
  box(0.14, 0.09, 0.22, M.armDark, 0, -0.03, -0.24, g); // ayak
  box(0.14, 0.03, 0.06, M.black, 0, -0.07, -0.34, g);
  g.visible = false;
  return g;
}

export class ViewArms {
  constructor(weapons) {
    this.w = weapons;
    this.game = weapons.game;
    const M = weapons.M;
    M.green = M.green || new THREE.MeshLambertMaterial({ map: this.game.tex.metal, color: 0x6ad84a, emissive: 0x0e2a08 });
    this.models = { feedbacker: buildArm(M, 'feedbacker'), knuckle: buildArm(M, 'knuckle'), whiplash: buildArm(M, 'whiplash') };
    for (const k in this.models) weapons.scene.add(this.models[k]);
    this.leg = buildLeg(M);
    weapons.scene.add(this.leg);
    // tek seferlik para modeli (fırlatmadan önce başparmakta)
    this.coinMesh = new THREE.Mesh(new THREE.CylinderGeometry(0.036, 0.036, 0.01, 12), new THREE.MeshBasicMaterial({ color: 0xffd24a }));
    this.coinMesh.visible = false;
    weapons.scene.add(this.coinMesh);
    this.act = null; // { type, t, dur, side }
    // parry şok halkası (görünür kol sahnesinde, yumruğun önünde)
    this.ring = new THREE.Mesh(new THREE.RingGeometry(0.1, 0.13, 32), new THREE.MeshBasicMaterial({ color: 0xbfe8ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, depthTest: false }));
    this.ring.visible = false;
    this.ringT = 1;
    weapons.scene.add(this.ring);
    this.flare = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.game.tex.star, color: 0xffffff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, depthTest: false }));
    this.flare.visible = false;
    weapons.scene.add(this.flare);
    this.glow = 0;
    this.legK = 0;
  }

  // Eylem başlat: 'punch' | 'coin' | 'hook' | 'wall' | 'slam' | 'slamHit' | 'dash'
  play(type, opts = {}) {
    const dur = { punch: 0.42, coin: 0.36, hook: 0.3, wall: 0.3, slam: 9, slamHit: 0.3, dash: 0.24, parry: 0.62 }[type];
    // yumruk/parry her şeyi keser; diğerleri onları kesmez
    if (this.act && (this.act.type === 'punch' || this.act.type === 'parry') && type !== 'punch' && type !== 'parry' && this.act.t < this.act.dur) return;
    if (type === 'parry') { this.ring.visible = true; this.ringT = 0; }
    this.act = { type, t: 0, dur, ...opts };
  }

  parryFlash() { this.glow = 1; }

  // Karakter görünümü: V2 → kırmızı Feedbacker ve turuncu şeritler
  setSkin(ch) {
    const M = this.w.M;
    const v2 = ch === 'v2';
    M.blue.color.setHex(v2 ? 0xd8402a : 0x4a8cff);
    M.blue.emissive.setHex(v2 ? 0x3a0a04 : 0x0a2250);
    const fb = this.models.feedbacker.userData;
    fb.glowBase = v2 ? 0xffb060 : 0x8fd0ff;
    fb.glowMat.color.setHex(fb.glowBase);
  }

  armModel() {
    const w = this.w;
    if (this.act && this.act.type === 'hook') return this.models.whiplash;
    return w.armId === 'knuckle' ? this.models.knuckle : this.models.feedbacker;
  }

  update(dt) {
    const w = this.w;
    const p = this.game.player;
    for (const k in this.models) this.models[k].visible = false;
    this.coinMesh.visible = false;
    this.glow = Math.max(0, this.glow - dt * 2.2);
    // parry halkası: yumruğun önünden büyüyerek söner
    if (this.ring.visible) {
      this.ringT += dt;
      const k = this.ringT / 0.4;
      if (k >= 1) { this.ring.visible = false; this.flare.visible = false; }
      else {
        const s = 0.6 + k * 5;
        this.ring.position.set(-0.04, -0.08, -0.95);
        this.ring.scale.setScalar(s);
        this.ring.material.opacity = (1 - k) * 0.9;
        this.flare.visible = true;
        this.flare.position.set(-0.05, -0.1, -0.9);
        this.flare.scale.setScalar(0.5 + (1 - k) * 0.9);
        this.flare.material.opacity = 1 - k;
        this.flare.material.rotation = k * 2;
      }
    }
    // kayarken ayak
    this.legK += ((p.sliding ? 1 : 0) - this.legK) * Math.min(1, dt * 14);
    this.leg.visible = this.legK > 0.03;
    if (this.leg.visible) {
      const k = easeOut(this.legK);
      const sh = Math.sin(this.game.time * 60) * 0.004;
      this.leg.position.set(0.02, -0.64 + 0.36 * k + sh, -0.56);
      this.leg.rotation.set(0.5, -0.2, 0.22);
      if (p.sliding && Math.random() < dt * 40) {
        const f = new THREE.Vector3(-Math.sin(p.yaw), 0, -Math.cos(p.yaw));
        this.game.fx.sparkDir(p.pos.clone().addScaledVector(f, 0.6).add(new THREE.Vector3(0, 0.05, 0)), f.clone().negate().setY(0.4), 2, 5, 0xffc060, 0.25, 0.04, 1);
      }
    }
    // sol kol eylemleri
    const a = this.act;
    if (!a) return;
    a.t += dt;
    if (a.type === 'slam' && !p.slamming) { this.play('slamHit'); return; }
    if (a.t >= a.dur) { this.act = null; return; }
    const m = this.armModel();
    m.visible = true;
    const t = a.t;
    // pozlar: [x, y, z, rx, ry, rz]; sol kol ekranın sol altından gelir (ry < 0 → ön kol sola-geriye)
    let P = OFF, curl = 1;
    switch (a.type) {
      case 'parry': {
        // hızlı ileri itiş + aşırı uzanma, parlayan yumruk titrer, sonra yavaşça çekilir
        const SUPER = [-0.04, -0.08, -0.86, 0.12, -0.22, 0.05];
        if (t < 0.04) P = lerpPose(OFF, SUPER, easeOut(t / 0.04));
        else if (t < 0.3) { P = SUPER.slice(); const j = 0.012 * (1 - (t - 0.04) / 0.26); P[0] += (Math.random() - 0.5) * j; P[1] += (Math.random() - 0.5) * j; P[5] += Math.sin(t * 60) * 0.05; }
        else P = lerpPose(SUPER, OFF, easeIn((t - 0.3) / 0.32));
        break;
      }
      case 'punch': {
        // geri çek → vur → tut → geri dön
        if (t < 0.05) P = lerpPose(OFF, COCK, easeOut(t / 0.05));
        else if (t < 0.11) P = lerpPose(COCK, HIT, easeOut((t - 0.05) / 0.06));
        else if (t < 0.17) P = HIT;
        else P = lerpPose(HIT, OFF, easeIn((t - 0.17) / 0.25));
        break;
      }
      case 'coin': {
        // başparmak yukarıda yumruk görüş alanına kalkar, başparmakla parayı fırlatır
        const up = t < 0.1 ? easeOut(t / 0.1) : t < 0.2 ? 1 : 1 - easeIn((t - 0.2) / 0.16);
        P = lerpPose(OFF, COIN, up);
        curl = 0.85;
        const flick = t < 0.1 ? 0.9 : t < 0.14 ? 0.9 - 1.6 * ((t - 0.1) / 0.04) : -0.7;
        setCurl(m, curl, flick);
        break;
      }
      case 'hook': {
        // açık el ileri uzanır; kanca dönene kadar tutulur
        const k = t < 0.08 ? easeOut(t / 0.08) : 1;
        P = lerpPose(OFF, REACH, k);
        if (w.hook && w.hook.phase !== 'out') P[2] += 0.08;
        curl = w.hook ? 0.15 : 0.55;
        if (w.hook) a.t = Math.min(a.t, 0.1);
        break;
      }
      case 'wall': {
        // avuç sol taraftaki duvara bastırır, parmaklar yukarı
        const k = t < 0.06 ? easeOut(t / 0.06) : 1 - easeIn((t - 0.06) / 0.24);
        P = lerpPose(OFF, PUSH, k);
        curl = 0.05;
        break;
      }
      case 'slam': {
        // düşerken yumruk hazır
        P = lerpPose(OFF, GUARD, easeOut(Math.min(1, t / 0.12)));
        a.t = Math.min(a.t, 1);
        break;
      }
      case 'slamHit': {
        P = t < 0.05 ? lerpPose(GUARD, DOWN, easeOut(t / 0.05)) : lerpPose(DOWN, OFF, easeIn((t - 0.05) / 0.25));
        break;
      }
      case 'dash': {
        // açık el geriye savrulur
        P = lerpPose(OFF, SWING, Math.sin(clamp(t / a.dur, 0, 1) * Math.PI));
        curl = 0.35;
        break;
      }
    }
    const [x, y, z, rx, ry, rz] = P;
    if (a.type !== 'coin') setCurl(m, curl);
    const bob = this.game.player.bob * Math.sin(this.game.player.bobT * 0.95) * 0.01;
    m.position.set(x, y + bob, z);
    m.rotation.set(rx, ry, rz);
    if (a.type === 'coin' && t < 0.11) {
      this.coinMesh.visible = true;
      m.updateMatrixWorld(true);
      m.userData.thumb.localToWorld(this.coinMesh.position.set(0, 0.028, -0.06));
      this.coinMesh.rotation.set(0.3, 0, rz);
    }
    // parry parlaması
    const gm = m.userData.glowMat;
    gm.color.setHex(m.userData.glowBase);
    if (this.glow > 0) gm.color.lerp(new THREE.Color(0xffffff), this.glow);
  }
}
