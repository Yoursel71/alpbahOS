// Ses motoru: tüm efektler başlangıçta JS içinde DSP ile (osilatör, gürültü, biquad filtre,
// doyum, zarf) örnek dizilerine işlenir ve AudioBuffer olarak saklanır. Oynatırken rastgele
// perde, uzaklık zayıflaması, stereo konum, uzakta boğukluk ve ortak bir yankı (convolver)
// uygulanır. Harici ses dosyası yoktur.
import { settings } from './settings.js';
import { clamp } from './util.js';

const TAU = Math.PI * 2;
const rnd = () => Math.random() * 2 - 1;
const sat = (x) => Math.tanh(x);

function wave(type, ph) {
  const p = ph - Math.floor(ph);
  if (type === 'sine') return Math.sin(TAU * p);
  if (type === 'saw') return 2 * p - 1;
  if (type === 'square') return p < 0.5 ? 1 : -1;
  return 4 * Math.abs(p - 0.5) - 1; // tri
}

// RBJ biquad
class BQ {
  constructor(sr, type, f, q = 0.707) {
    this.sr = sr; this.type = type; this.q = q;
    this.x1 = this.x2 = this.y1 = this.y2 = 0;
    this.set(f);
  }
  set(f) {
    f = Math.max(20, Math.min(f, this.sr * 0.45));
    const w = (TAU * f) / this.sr, cs = Math.cos(w), sn = Math.sin(w), a = sn / (2 * this.q);
    let b0, b1, b2;
    const a0 = 1 + a, a1 = -2 * cs, a2 = 1 - a;
    if (this.type === 'lp') { b0 = (1 - cs) / 2; b1 = 1 - cs; b2 = (1 - cs) / 2; }
    else if (this.type === 'hp') { b0 = (1 + cs) / 2; b1 = -(1 + cs); b2 = (1 + cs) / 2; }
    else { b0 = a; b1 = 0; b2 = -a; }
    this.b0 = b0 / a0; this.b1 = b1 / a0; this.b2 = b2 / a0; this.a1 = a1 / a0; this.a2 = a2 / a0;
  }
  run(x) {
    const y = this.b0 * x + this.b1 * this.x1 + this.b2 * this.x2 - this.a1 * this.y1 - this.a2 * this.y2;
    this.x2 = this.x1; this.x1 = x; this.y2 = this.y1; this.y1 = y;
    return y;
  }
}

class Osc {
  constructor(sr, type = 'sine') { this.sr = sr; this.type = type; this.ph = Math.random(); }
  run(f) { this.ph += f / this.sr; return wave(this.type, this.ph); }
}

// ---------------------------------------------------------------- ses tanımları
// Her tanım (sr) → Float32Array döndürür. Çıktı sonradan normalize edilir.
function mk(sr, dur, fn) {
  const n = Math.ceil(dur * sr);
  const o = new Float32Array(n);
  fn(o, n, sr);
  return o;
}

const DEFS = {
  revolver: (sr) => mk(sr, 0.7, (o, n) => {
    const lp = new BQ(sr, 'lp', 7000, 0.8), bp = new BQ(sr, 'bp', 1100, 0.9), bp2 = new BQ(sr, 'bp', 2600, 3), th = new Osc(sr);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      let v = t < 0.0025 ? z * 1.4 : 0;
      v += lp.run(z) * Math.exp(-t / 0.03) * 1.1;
      v += th.run(48 + 170 * Math.exp(-t / 0.018)) * Math.exp(-t / 0.08) * 1.1;
      v += bp.run(z) * Math.exp(-t / 0.18) * 0.5;
      if (t > 0.1 && t < 0.13) v += bp2.run(z) * Math.exp(-(t - 0.1) / 0.006) * 0.5; // horoz sesi
      o[i] = sat(v * 1.6);
    }
  }),
  piercer: (sr) => mk(sr, 1.1, (o, n) => {
    const lp = new BQ(sr, 'lp', 9000, 0.7), s = new Osc(sr, 'saw'), th = new Osc(sr), r1 = new Osc(sr), r2 = new Osc(sr), bp = new BQ(sr, 'bp', 900, 1);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      lp.set(9000 * Math.exp(-t / 0.15) + 300);
      let v = lp.run(z) * Math.exp(-t / 0.12) * 1.2;
      v += s.run(2600 * Math.exp(-t / 0.08) + 90) * Math.exp(-t / 0.2) * 0.5;
      v += th.run(40 + 140 * Math.exp(-t / 0.03)) * Math.exp(-t / 0.18) * 1.3;
      v += (r1.run(2310) * 0.5 + r2.run(3140) * 0.35) * Math.exp(-t / 0.35) * 0.35;
      v += bp.run(z) * Math.exp(-t / 0.4) * 0.4;
      o[i] = sat(v * 1.8);
    }
  }),
  chargeLoop: (sr) => mk(sr, 0.6, (o, n) => {
    const a = new Osc(sr), b = new Osc(sr, 'saw'), lp = new BQ(sr, 'lp', 1800, 2);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const f = 300 + (t / 0.6) * 900;
      const v = a.run(f * (1 + 0.02 * Math.sin(TAU * 30 * t))) * 0.6 + lp.run(b.run(f * 0.5)) * 0.3;
      o[i] = v * Math.min(1, t / 0.05) * 0.8;
    }
  }),
  chargeReady: (sr) => mk(sr, 0.5, (o, n) => {
    const a = new Osc(sr), b = new Osc(sr), c = new Osc(sr, 'tri');
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      o[i] = (a.run(1760) * 0.5 + b.run(2640) * 0.35 + c.run(3520) * 0.2) * Math.exp(-t / 0.14) * Math.min(1, t / 0.004);
    }
  }),
  coin: (sr) => mk(sr, 0.35, (o, n) => {
    const a = new Osc(sr), b = new Osc(sr), hp = new BQ(sr, 'hp', 5000);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const trem = 0.6 + 0.4 * Math.sin(TAU * 38 * t);
      o[i] = (a.run(2400 + 800 * t) * 0.6 + b.run(3800) * 0.25) * Math.exp(-t / 0.12) * trem + hp.run(rnd()) * Math.exp(-t / 0.01) * 0.5;
    }
  }),
  ricochet: (sr) => mk(sr, 0.9, (o, n) => {
    const a = new Osc(sr), b = new Osc(sr), c = new Osc(sr), hp = new BQ(sr, 'hp', 4000);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const f = 3300 - 900 * (1 - Math.exp(-t / 0.3));
      o[i] = (a.run(f) * 0.55 + b.run(f * 1.46) * 0.3 + c.run(f * 2.1) * 0.12) * Math.exp(-t / 0.28) + hp.run(rnd()) * Math.exp(-t / 0.008) * 0.8;
    }
  }),
  shotgun: (sr) => mk(sr, 1.0, (o, n) => {
    const lp = new BQ(sr, 'lp', 4000, 0.7), th = new Osc(sr), bp = new BQ(sr, 'bp', 700, 0.8), lp2 = new BQ(sr, 'lp', 300, 0.7);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      lp.set(200 + 5000 * Math.exp(-t / 0.08));
      let v = t < 0.004 ? z * 1.5 : 0;
      v += lp.run(z) * Math.exp(-t / 0.16) * 1.6;
      v += th.run(34 + 110 * Math.exp(-t / 0.04)) * Math.exp(-t / 0.22) * 1.6;
      v += bp.run(z) * Math.exp(-t / 0.3) * 0.5;
      v += lp2.run(z) * Math.exp(-t / 0.5) * 0.8;
      o[i] = sat(v * 2.0);
    }
  }),
  pump: (sr) => mk(sr, 0.42, (o, n) => {
    const b1 = new BQ(sr, 'bp', 1900, 4), b2 = new BQ(sr, 'bp', 1200, 5), b3 = new BQ(sr, 'bp', 3200, 3);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      let v = 0;
      if (t < 0.06) v += (b1.run(z) + b3.run(z) * 0.6) * Math.exp(-t / 0.012) * 2.2;
      if (t > 0.2) { const u = t - 0.2; v += (b2.run(z) + b3.run(z) * 0.4) * Math.exp(-u / 0.015) * 2.4; }
      o[i] = sat(v);
    }
  }),
  shell: (sr) => mk(sr, 0.25, (o, n) => {
    const a = new Osc(sr), b = new Osc(sr);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      o[i] = (a.run(3900) * 0.5 + b.run(6200) * 0.3) * Math.exp(-t / 0.05);
    }
  }),
  overpump: (sr) => mk(sr, 0.8, (o, n) => {
    const s = new Osc(sr, 'saw'), lp = new BQ(sr, 'lp', 900, 4);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      lp.set(300 + 3000 * (t / 0.8));
      o[i] = sat(lp.run(s.run(80 + 360 * (t / 0.8) + 20 * Math.sin(TAU * 12 * t))) * 3) * Math.min(1, t / 0.05) * Math.exp(-Math.max(0, t - 0.6) / 0.08);
    }
  }),
  coreLaunch: (sr) => mk(sr, 0.45, (o, n) => {
    const th = new Osc(sr), lp = new BQ(sr, 'lp', 1400, 0.8);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      o[i] = sat((th.run(70 + 220 * Math.exp(-t / 0.05)) * Math.exp(-t / 0.12) * 1.2 + lp.run(rnd()) * Math.exp(-t / 0.08)) * 1.4);
    }
  }),
  explosion: (sr) => mk(sr, 2.0, (o, n) => {
    const lp = new BQ(sr, 'lp', 4000, 0.7), lp2 = new BQ(sr, 'lp', 180, 0.8), th = new Osc(sr), hp = new BQ(sr, 'hp', 2500);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      lp.set(90 + 5500 * Math.exp(-t / 0.18));
      let v = t < 0.006 ? z * 1.6 : 0;
      v += lp.run(z) * Math.exp(-t / 0.45) * 1.8;
      v += th.run(24 + 70 * Math.exp(-t / 0.1)) * Math.exp(-t / 0.5) * 1.8;
      v += lp2.run(z) * Math.exp(-t / 0.9) * 2.2;
      if (Math.random() < 0.004 * Math.exp(-t / 0.4)) v += hp.run(rnd()) * 3;
      else v += hp.run(0) * 0.5;
      o[i] = sat(v * 1.8);
    }
  }),
  rail: (sr) => mk(sr, 1.6, (o, n) => {
    const sq = new Osc(sr, 'square'), th = new Osc(sr), lp = new BQ(sr, 'lp', 9000), hp = new BQ(sr, 'hp', 3000), s2 = new Osc(sr, 'saw');
    let gate = 1;
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      if (i % 220 === 0) gate = Math.random() < 0.6 ? 1 : 0.2;
      lp.set(200 + 9000 * Math.exp(-t / 0.25));
      let v = sq.run(1900 * Math.exp(-t / 0.12) + 55) * Math.exp(-t / 0.35) * 0.7;
      v += lp.run(z) * Math.exp(-t / 0.3) * 1.4;
      v += th.run(20 + 80 * Math.exp(-t / 0.08)) * Math.exp(-t / 0.7) * 1.8;
      v += hp.run(z) * gate * Math.exp(-t / 0.6) * 0.6;
      v += s2.run(4200 - 1500 * t) * Math.exp(-t / 0.15) * 0.12;
      o[i] = sat(v * 2.2);
    }
  }),
  railReady: (sr) => mk(sr, 0.7, (o, n) => {
    const a = new Osc(sr), b = new Osc(sr, 'tri');
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const f = t < 0.12 ? 660 : t < 0.24 ? 990 : 1320;
      o[i] = (a.run(f) * 0.6 + b.run(f * 2) * 0.2) * Math.exp(-((t % 0.12) / 0.08)) * (t < 0.5 ? 1 : Math.exp(-(t - 0.5) / 0.05));
    }
  }),
  empty: (sr) => mk(sr, 0.08, (o, n) => {
    const bp = new BQ(sr, 'bp', 2500, 5);
    for (let i = 0; i < n; i++) { const t = i / sr; o[i] = bp.run(rnd()) * Math.exp(-t / 0.01) * 3; }
  }),
  punch: (sr) => mk(sr, 0.3, (o, n) => {
    const bp = new BQ(sr, 'bp', 600, 1.4);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      bp.set(500 + 3500 * (t / 0.3));
      o[i] = bp.run(rnd()) * Math.sin(Math.PI * Math.min(1, t / 0.3)) * 1.5;
    }
  }),
  punchHit: (sr) => mk(sr, 0.4, (o, n) => {
    const th = new Osc(sr), lp = new BQ(sr, 'lp', 1500), bp = new BQ(sr, 'bp', 400, 1.5);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      o[i] = sat((th.run(45 + 120 * Math.exp(-t / 0.03)) * Math.exp(-t / 0.1) * 1.4 + lp.run(z) * Math.exp(-t / 0.04) * 1.2 + bp.run(z) * Math.exp(-t / 0.12) * 0.6) * 1.6);
    }
  }),
  parry: (sr) => mk(sr, 2.2, (o, n) => {
    const base = 620;
    const ratios = [1, 2.76, 5.4, 8.93, 1.5];
    const amps = [0.5, 0.35, 0.22, 0.12, 0.25];
    const taus = [1.1, 0.7, 0.4, 0.25, 0.9];
    const oscs = ratios.map(() => new Osc(sr));
    const th = new Osc(sr), hp = new BQ(sr, 'hp', 3000);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      let v = 0;
      for (let k = 0; k < oscs.length; k++) v += oscs[k].run(base * ratios[k]) * amps[k] * Math.exp(-t / taus[k]);
      v += th.run(30 + 120 * Math.exp(-t / 0.05)) * Math.exp(-t / 0.35) * 1.4;
      v += hp.run(rnd()) * Math.exp(-t / 0.03) * 0.9;
      o[i] = sat(v * 1.3);
    }
  }),
  dash: (sr) => mk(sr, 0.35, (o, n) => {
    const bp = new BQ(sr, 'bp', 400, 1.6), lp = new BQ(sr, 'lp', 300);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      bp.set(400 + 4000 * (t / 0.35));
      o[i] = (bp.run(z) * 1.6 + lp.run(z) * 0.4) * Math.sin(Math.PI * Math.min(1, t / 0.35)) ** 0.6;
    }
  }),
  jump: (sr) => mk(sr, 0.18, (o, n) => {
    const bp = new BQ(sr, 'bp', 700, 2), s = new Osc(sr, 'square'), lp = new BQ(sr, 'lp', 1200);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      bp.set(600 + 1800 * (t / 0.18));
      o[i] = bp.run(rnd()) * Math.exp(-t / 0.06) * 1.2 + lp.run(s.run(180 + 400 * t)) * Math.exp(-t / 0.04) * 0.2;
    }
  }),
  walljump: (sr) => mk(sr, 0.3, (o, n) => {
    const bp = new BQ(sr, 'bp', 2400, 3), bp2 = new BQ(sr, 'bp', 900, 1.5);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      o[i] = bp.run(z) * Math.exp(-t / 0.02) * 1.5 + bp2.run(z) * Math.exp(-t / 0.09) * 0.8;
    }
  }),
  land: (sr) => mk(sr, 0.25, (o, n) => {
    const lp = new BQ(sr, 'lp', 500), th = new Osc(sr), bp = new BQ(sr, 'bp', 1800, 4);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      o[i] = lp.run(z) * Math.exp(-t / 0.05) * 1.3 + th.run(60 + 60 * Math.exp(-t / 0.02)) * Math.exp(-t / 0.06) + bp.run(z) * Math.exp(-t / 0.01) * 0.6;
    }
  }),
  step: (sr) => mk(sr, 0.12, (o, n) => {
    const f = 1200 + Math.random() * 900;
    const bp = new BQ(sr, 'bp', f, 5), bp2 = new BQ(sr, 'bp', f * 1.7, 6), th = new Osc(sr);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      o[i] = (bp.run(z) + bp2.run(z) * 0.5) * Math.exp(-t / 0.012) * 2.2 + th.run(110) * Math.exp(-t / 0.02) * 0.3;
    }
  }),
  slideLoop: (sr) => mk(sr, 1.0, (o, n) => {
    const bp = new BQ(sr, 'bp', 900, 1.2), bp2 = new BQ(sr, 'bp', 3200, 2);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      const m = 0.75 + 0.25 * Math.sin(TAU * 7 * t) * Math.sin(TAU * 3 * t);
      o[i] = (bp.run(z) * 0.9 + bp2.run(z) * 0.4 * (Math.random() < 0.02 ? 3 : 1)) * m;
    }
    // uçları yumuşat (döngü tıklamasını önle)
    const f = Math.floor(sr * 0.02);
    for (let i = 0; i < f; i++) { const k = i / f; o[i] *= k; o[n - 1 - i] *= k; }
  }),
  slamStart: (sr) => mk(sr, 0.4, (o, n) => {
    const bp = new BQ(sr, 'bp', 3000, 1.2);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      bp.set(3000 - 2500 * (t / 0.4));
      o[i] = bp.run(rnd()) * Math.min(1, t / 0.05) * 1.3;
    }
  }),
  slam: (sr) => mk(sr, 1.1, (o, n) => {
    const lp = new BQ(sr, 'lp', 2000), th = new Osc(sr), bp = new BQ(sr, 'bp', 1400, 3), lp2 = new BQ(sr, 'lp', 150);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      lp.set(100 + 3000 * Math.exp(-t / 0.08));
      let v = lp.run(z) * Math.exp(-t / 0.25) * 1.6;
      v += th.run(28 + 90 * Math.exp(-t / 0.05)) * Math.exp(-t / 0.3) * 1.8;
      v += bp.run(z) * Math.exp(-t / 0.05) * 0.8;
      v += lp2.run(z) * Math.exp(-t / 0.5) * 1.5;
      o[i] = sat(v * 1.8);
    }
  }),
  hurt: (sr) => mk(sr, 0.45, (o, n) => {
    const lp = new BQ(sr, 'lp', 1200), s = new Osc(sr, 'saw'), hp = new BQ(sr, 'hp', 2000);
    let hold = 0;
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      if (i % 40 === 0) hold = rnd();
      o[i] = sat((lp.run(z) * 1.2 + s.run(140 - 80 * t) * 0.5 + hp.run(hold) * 0.6) * Math.exp(-t / 0.12) * 2.5);
    }
  }),
  heal: (sr) => mk(sr, 0.2, (o, n) => {
    const a = new Osc(sr);
    for (let i = 0; i < n; i++) { const t = i / sr; o[i] = a.run(700 + 900 * t) * Math.exp(-t / 0.05) * 0.4; }
  }),
  enemyHit: (sr) => mk(sr, 0.3, (o, n) => {
    const bp = new BQ(sr, 'bp', 500, 1.5), lp = new BQ(sr, 'lp', 600);
    const f0 = 350 + Math.random() * 300;
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      bp.set(f0 * (1 + 1.5 * Math.exp(-t / 0.03)));
      o[i] = sat((bp.run(z) * 1.6 + lp.run(z) * 0.8) * Math.exp(-t / 0.07) * 2);
    }
  }),
  headshot: (sr) => mk(sr, 0.45, (o, n) => {
    const bp = new BQ(sr, 'bp', 700, 1.2), hp = new BQ(sr, 'hp', 3000), lp = new BQ(sr, 'lp', 400);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      bp.set(300 + 1600 * Math.exp(-t / 0.05));
      o[i] = sat((hp.run(z) * Math.exp(-t / 0.006) * 1.5 + bp.run(z) * Math.exp(-t / 0.1) * 1.5 + lp.run(z) * Math.exp(-t / 0.15)) * 2);
    }
  }),
  gore: (sr) => mk(sr, 1.0, (o, n) => {
    const lp = new BQ(sr, 'lp', 1400), bp = new BQ(sr, 'bp', 350, 2), th = new Osc(sr), lp2 = new BQ(sr, 'lp', 2500);
    const bursts = Array.from({ length: 6 }, () => ({ t: Math.random() * 0.45, d: 0.03 + Math.random() * 0.06, f: 400 + Math.random() * 900 }));
    const bps = bursts.map((b) => new BQ(sr, 'bp', b.f, 2));
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      lp.set(150 + 1800 * Math.exp(-t / 0.1));
      let v = lp.run(z) * Math.exp(-t / 0.25) * 1.8;
      v += bp.run(z) * Math.exp(-t / 0.18) * 1.2;
      v += th.run(40 + 90 * Math.exp(-t / 0.04)) * Math.exp(-t / 0.15) * 1.3;
      for (let k = 0; k < bursts.length; k++) {
        const b = bursts[k];
        if (t > b.t && t < b.t + b.d * 4) v += bps[k].run(z) * Math.exp(-(t - b.t) / b.d) * 1.4;
      }
      v += lp2.run(z) * Math.exp(-t / 0.5) * 0.25;
      o[i] = sat(v * 1.7);
    }
  }),
  filthGrowl: (sr) => mk(sr, 0.7, (o, n) => {
    const s = new Osc(sr, 'saw'), f1 = new BQ(sr, 'bp', 520, 4), f2 = new BQ(sr, 'bp', 1400, 5), lp = new BQ(sr, 'lp', 2500);
    const f0 = 85 + Math.random() * 30;
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const x = s.run(f0 * (1 + 0.06 * Math.sin(TAU * 13 * t)) * (1 - 0.3 * t)) + rnd() * 0.3;
      o[i] = sat((f1.run(x) * 1.5 + f2.run(x)) * 3) * lp.run(1) * Math.min(1, t / 0.05) * Math.exp(-t / 0.3);
    }
  }),
  screech: (sr) => mk(sr, 0.6, (o, n) => {
    const s = new Osc(sr, 'saw'), f1 = new BQ(sr, 'bp', 900, 5), f2 = new BQ(sr, 'bp', 2400, 6);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const x = s.run(260 - 120 * t + 20 * Math.sin(TAU * 25 * t)) + rnd() * 0.4;
      o[i] = sat((f1.run(x) + f2.run(x) * 0.8) * 4) * Math.min(1, t / 0.03) * Math.exp(-t / 0.22);
    }
  }),
  windup: (sr) => mk(sr, 0.6, (o, n) => {
    const s = new Osc(sr, 'saw'), lp = new BQ(sr, 'lp', 800, 3);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      lp.set(300 + 2500 * (t / 0.6));
      o[i] = lp.run(s.run(120 + 380 * (t / 0.6))) * Math.min(1, t / 0.1) * 0.9;
    }
  }),
  glint: (sr) => mk(sr, 0.7, (o, n) => {
    const a = new Osc(sr), b = new Osc(sr), c = new Osc(sr);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const f = 2900 + 900 * Math.min(1, t / 0.05);
      o[i] = (a.run(f) * 0.5 + b.run(f * 1.5) * 0.3 + c.run(f * 2.02) * 0.15) * Math.exp(-t / 0.18) * Math.min(1, t / 0.003);
    }
  }),
  orbCharge: (sr) => mk(sr, 1.0, (o, n) => {
    const a = new Osc(sr), b = new Osc(sr, 'tri');
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const f = 180 + 700 * t;
      o[i] = (a.run(f) * 0.5 + b.run(f * 2.01) * 0.3) * Math.min(1, t / 0.3) * (0.7 + 0.3 * Math.sin(TAU * 18 * t));
    }
  }),
  orbThrow: (sr) => mk(sr, 0.45, (o, n) => {
    const bp = new BQ(sr, 'bp', 500, 2), a = new Osc(sr);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      bp.set(400 + 2000 * (t / 0.45));
      o[i] = bp.run(rnd()) * Math.sin(Math.PI * t / 0.45) * 1.4 + a.run(600 - 400 * t) * Math.exp(-t / 0.15) * 0.3;
    }
  }),
  schismShot: (sr) => mk(sr, 0.25, (o, n) => {
    const s = new Osc(sr, 'square'), lp = new BQ(sr, 'lp', 2500), bp = new BQ(sr, 'bp', 1600, 3);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      o[i] = lp.run(s.run(1200 * Math.exp(-t / 0.05) + 200)) * Math.exp(-t / 0.08) * 0.6 + bp.run(rnd()) * Math.exp(-t / 0.03);
    }
  }),
  projHit: (sr) => mk(sr, 0.4, (o, n) => {
    const lp = new BQ(sr, 'lp', 2000), hp = new BQ(sr, 'hp', 2500);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      lp.set(200 + 2500 * Math.exp(-t / 0.05));
      o[i] = sat((lp.run(z) * Math.exp(-t / 0.12) * 1.5 + hp.run(z) * (Math.random() < 0.05 ? 1 : 0.1) * Math.exp(-t / 0.15)) * 1.6);
    }
  }),
  swing: (sr) => mk(sr, 0.45, (o, n) => {
    const bp = new BQ(sr, 'bp', 3000, 1.5), s = new Osc(sr, 'saw'), lp = new BQ(sr, 'lp', 700);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      bp.set(3200 - 2500 * (t / 0.45));
      o[i] = bp.run(rnd()) * Math.sin(Math.PI * t / 0.45) * 1.6 + sat(lp.run(s.run(75)) * 3) * Math.sin(Math.PI * t / 0.45) * 0.3;
    }
  }),
  chainsaw: (sr) => mk(sr, 0.8, (o, n) => {
    const s = new Osc(sr, 'saw'), s2 = new Osc(sr, 'square'), bp = new BQ(sr, 'bp', 1200, 1);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const f = 55 + 40 * Math.min(1, t / 0.2);
      const am = 0.6 + 0.4 * Math.sign(Math.sin(TAU * 28 * t));
      o[i] = sat((s.run(f) + s2.run(f * 1.01) * 0.5 + bp.run(rnd()) * 0.4) * am * 2.5) * Math.min(1, t / 0.03) * Math.exp(-Math.max(0, t - 0.5) / 0.1);
    }
  }),
  bossRoar: (sr) => mk(sr, 1.8, (o, n) => {
    const s = new Osc(sr, 'saw'), m = new Osc(sr), f1 = new BQ(sr, 'bp', 600, 3), f2 = new BQ(sr, 'bp', 1100, 4), lp = new BQ(sr, 'lp', 3000);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const f = 62 * (1 + 0.15 * m.run(31)) * (1 - 0.2 * t / 1.8);
      const x = s.run(f) + rnd() * 0.3;
      o[i] = sat((f1.run(x) * 1.4 + f2.run(x) + lp.run(x) * 0.6) * 3) * Math.min(1, t / 0.1) * Math.exp(-Math.max(0, t - 1.2) / 0.2);
    }
  }),
  bossShotgun: (sr) => DEFS.shotgun(sr),
  spawn: (sr) => mk(sr, 0.9, (o, n) => {
    const a = new Osc(sr), b = new Osc(sr), bp = new BQ(sr, 'bp', 3000, 2);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const env = t < 0.6 ? (t / 0.6) ** 2 : Math.exp(-(t - 0.6) / 0.06);
      o[i] = (a.run(220 + 900 * t) * 0.3 + b.run(1650 + 1200 * t) * 0.15 + bp.run(rnd()) * 0.8) * env;
    }
  }),
  door: (sr) => mk(sr, 1.6, (o, n) => {
    const lp = new BQ(sr, 'lp', 250, 1), s = new Osc(sr, 'saw'), lp2 = new BQ(sr, 'lp', 300), hp = new BQ(sr, 'hp', 4000);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      const env = Math.min(1, t / 0.1) * Math.exp(-Math.max(0, t - 1.2) / 0.1);
      o[i] = sat((lp.run(z) * 2.5 + lp2.run(s.run(48 + 4 * Math.sin(TAU * 3 * t))) * 0.8 + hp.run(z) * 0.08 * Math.exp(-t / 0.3)) * env * 1.6);
    }
  }),
  doorSlam: (sr) => mk(sr, 0.9, (o, n) => {
    const lp = new BQ(sr, 'lp', 900), th = new Osc(sr), a = new Osc(sr), b = new Osc(sr);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      o[i] = sat((lp.run(z) * Math.exp(-t / 0.08) * 1.8 + th.run(35 + 60 * Math.exp(-t / 0.05)) * Math.exp(-t / 0.2) * 1.6 + (a.run(420) + b.run(1170) * 0.6) * Math.exp(-t / 0.25) * 0.25) * 1.6);
    }
  }),
  secret: (sr) => mk(sr, 1.4, (o, n) => {
    const notes = [784, 988, 1175, 1568, 1976];
    const oscs = notes.map(() => new Osc(sr, 'tri'));
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      let v = 0;
      for (let k = 0; k < notes.length; k++) { const s = k * 0.08; if (t > s) v += oscs[k].run(notes[k]) * Math.exp(-(t - s) / 0.5) * 0.3; }
      o[i] = v;
    }
  }),
  checkpoint: (sr) => mk(sr, 0.5, (o, n) => {
    const a = new Osc(sr, 'square'), lp = new BQ(sr, 'lp', 2500);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const f = t < 0.12 ? 523 : 784;
      o[i] = lp.run(a.run(f)) * (t < 0.12 ? 1 : Math.exp(-(t - 0.12) / 0.12)) * 0.5;
    }
  }),
  rankUp: (sr) => mk(sr, 0.3, (o, n) => {
    const a = new Osc(sr, 'square'), lp = new BQ(sr, 'lp', 3000);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const f = t < 0.07 ? 660 : 990;
      o[i] = lp.run(a.run(f)) * Math.exp(-(t % 0.07) / 0.05) * 0.5 * (t < 0.25 ? 1 : 0.3);
    }
  }),
  pickup: (sr) => mk(sr, 1.6, (o, n) => {
    const notes = [262, 330, 392, 523, 659];
    const oscs = notes.map(() => new Osc(sr, 'saw'));
    const lp = new BQ(sr, 'lp', 1500, 1.5), bp = new BQ(sr, 'bp', 2500, 4);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      let v = 0;
      for (let k = 0; k < notes.length; k++) v += oscs[k].run(notes[k] * (1 + 0.003 * Math.sin(TAU * 5 * t + k))) * 0.2;
      lp.set(400 + 3000 * Math.min(1, t / 0.4));
      v = lp.run(v) * Math.min(1, t / 0.05) * Math.exp(-Math.max(0, t - 0.6) / 0.35);
      if (t < 0.05) v += bp.run(rnd()) * Math.exp(-t / 0.008) * 2;
      if (t > 0.18 && t < 0.25) v += bp.run(rnd()) * Math.exp(-(t - 0.18) / 0.008) * 2;
      o[i] = sat(v * 1.5);
    }
  }),
  uiHover: (sr) => mk(sr, 0.05, (o, n) => {
    const a = new Osc(sr, 'square');
    for (let i = 0; i < n; i++) { const t = i / sr; o[i] = a.run(1400) * Math.exp(-t / 0.012) * 0.4; }
  }),
  uiClick: (sr) => mk(sr, 0.12, (o, n) => {
    const a = new Osc(sr, 'square'), lp = new BQ(sr, 'lp', 3500);
    for (let i = 0; i < n; i++) { const t = i / sr; o[i] = lp.run(a.run(600 + 600 * (t / 0.12))) * Math.exp(-t / 0.035) * 0.6; }
  }),
  type: (sr) => mk(sr, 0.03, (o, n) => {
    const bp = new BQ(sr, 'bp', 2500 + Math.random() * 1500, 4);
    for (let i = 0; i < n; i++) { const t = i / sr; o[i] = bp.run(rnd()) * Math.exp(-t / 0.005) * 2.5; }
  }),
  beep: (sr) => mk(sr, 0.12, (o, n) => {
    const a = new Osc(sr, 'square'), lp = new BQ(sr, 'lp', 2500);
    for (let i = 0; i < n; i++) { const t = i / sr; o[i] = lp.run(a.run(880)) * (t < 0.09 ? 0.5 : 0); }
  }),
  bigText: (sr) => mk(sr, 2.2, (o, n) => {
    const lp = new BQ(sr, 'lp', 3000), th = new Osc(sr), lp2 = new BQ(sr, 'lp', 120), s = new Osc(sr, 'saw'), lp3 = new BQ(sr, 'lp', 400);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      lp.set(80 + 3000 * Math.exp(-t / 0.06));
      let v = lp.run(z) * Math.exp(-t / 0.4) * 1.5;
      v += th.run(22 + 60 * Math.exp(-t / 0.08)) * Math.exp(-t / 0.8) * 2;
      v += lp2.run(z) * Math.exp(-t / 1.2) * 2;
      v += lp3.run(s.run(41)) * Math.exp(-t / 1.0) * 0.4;
      o[i] = sat(v * 1.6);
    }
  }),
  death: (sr) => mk(sr, 2.6, (o, n) => {
    const a = new Osc(sr, 'saw'), lp = new BQ(sr, 'lp', 2000), hp = new BQ(sr, 'hp', 1500), th = new Osc(sr);
    let hold = 0;
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      if (i % Math.floor(20 + t * 200) === 0) hold = rnd();
      lp.set(100 + 2500 * Math.exp(-t / 0.6));
      let v = lp.run(a.run(320 * Math.exp(-t / 0.7) + 25)) * Math.exp(-t / 1.2) * 1.2;
      v += hp.run(hold) * Math.exp(-t / 0.8) * 0.5;
      v += th.run(30 + 80 * Math.exp(-t / 0.05)) * Math.exp(-t / 0.4) * 1.5;
      v += z * 0.08 * Math.exp(-t / 1.5);
      o[i] = sat(v * 1.8);
    }
  }),
  glitch: (sr) => mk(sr, 0.35, (o, n) => {
    const a = new Osc(sr, 'square');
    let hold = 0, f = 400;
    for (let i = 0; i < n; i++) {
      if (i % 600 === 0) { hold = rnd(); f = 200 + Math.random() * 2000; }
      o[i] = (a.run(f) * 0.4 + hold * 0.5) * (Math.random() < 0.9 ? 1 : 0);
    }
  }),
  rankStamp: (sr) => mk(sr, 0.6, (o, n) => {
    const lp = new BQ(sr, 'lp', 1500), th = new Osc(sr);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      o[i] = sat((lp.run(rnd()) * Math.exp(-t / 0.06) * 1.6 + th.run(38 + 90 * Math.exp(-t / 0.03)) * Math.exp(-t / 0.2) * 1.6) * 1.5);
    }
  }),
  tick: (sr) => mk(sr, 0.03, (o, n) => {
    const a = new Osc(sr, 'square');
    for (let i = 0; i < n; i++) { const t = i / sr; o[i] = a.run(1800) * Math.exp(-t / 0.006) * 0.4; }
  }),
  pRank: (sr) => mk(sr, 2.0, (o, n) => {
    const notes = [523, 659, 784, 1047, 1319];
    const oscs = notes.map(() => new Osc(sr, 'tri'));
    const o2 = notes.map(() => new Osc(sr, 'saw'));
    const lp = new BQ(sr, 'lp', 3000);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      let v = 0;
      for (let k = 0; k < notes.length; k++) { const s = k * 0.09; if (t > s) v += (oscs[k].run(notes[k]) + lp.run(o2[k].run(notes[k] / 2)) * 0.3) * Math.exp(-(t - s) / 0.8) * 0.22; }
      o[i] = v;
    }
  }),
  lava: (sr) => mk(sr, 0.5, (o, n) => {
    const hp = new BQ(sr, 'hp', 3000), lp = new BQ(sr, 'lp', 600);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      o[i] = (hp.run(z) * (Math.random() < 0.15 ? 1.5 : 0.3) + lp.run(z) * 1.2) * Math.exp(-t / 0.18);
    }
  }),
};

// Varyantlı sesler (her çalışta farklı örnek)
const VARIANTS = { step: 4, enemyHit: 3, gore: 3, type: 3, filthGrowl: 3 };
// Temel seviyeler ve yankı gönderimi
const MIX = {
  revolver: [0.55, 0.25], piercer: [0.7, 0.35], chargeLoop: [0.25, 0.1], chargeReady: [0.35, 0.2], coin: [0.35, 0.2], ricochet: [0.5, 0.4],
  shotgun: [0.8, 0.3], pump: [0.45, 0.15], shell: [0.12, 0.1], overpump: [0.35, 0.2], coreLaunch: [0.5, 0.2], explosion: [0.95, 0.45],
  rail: [0.85, 0.5], railReady: [0.3, 0.2], empty: [0.3, 0.05], punch: [0.35, 0.1], punchHit: [0.6, 0.2], parry: [0.9, 0.6],
  dash: [0.4, 0.15], jump: [0.25, 0.05], walljump: [0.35, 0.1], land: [0.35, 0.05], step: [0.16, 0.03], slideLoop: [0.18, 0.05],
  slamStart: [0.35, 0.1], slam: [0.8, 0.35], hurt: [0.6, 0.1], heal: [0.12, 0.05], enemyHit: [0.45, 0.15], headshot: [0.6, 0.2],
  gore: [0.75, 0.3], filthGrowl: [0.35, 0.2], screech: [0.35, 0.2], windup: [0.3, 0.15], glint: [0.45, 0.4], orbCharge: [0.22, 0.15],
  orbThrow: [0.4, 0.2], schismShot: [0.3, 0.15], projHit: [0.4, 0.2], swing: [0.6, 0.25], chainsaw: [0.4, 0.2], bossRoar: [0.8, 0.5],
  bossShotgun: [0.75, 0.3], spawn: [0.35, 0.35], door: [0.5, 0.3], doorSlam: [0.7, 0.4], secret: [0.35, 0.4], checkpoint: [0.3, 0.2],
  rankUp: [0.2, 0.1], pickup: [0.55, 0.5], uiHover: [0.12, 0], uiClick: [0.22, 0.05], type: [0.18, 0.02], beep: [0.2, 0.05],
  bigText: [0.9, 0.6], death: [0.7, 0.4], glitch: [0.25, 0.1], rankStamp: [0.55, 0.3], tick: [0.12, 0], pRank: [0.45, 0.4], lava: [0.45, 0.1],
};
// Eski adlar → yeni
const ALIAS = { charge: null, bossShotgun: 'bossShotgun' };

function makeImpulse(ctx, sec = 2.4, decay = 0.55) {
  const sr = ctx.sampleRate, n = Math.floor(sr * sec);
  const buf = ctx.createBuffer(2, n, sr);
  for (let ch = 0; ch < 2; ch++) {
    const d = buf.getChannelData(ch);
    const lp = new BQ(sr, 'lp', 5000, 0.5);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      lp.set(5000 * Math.exp(-t / 0.8) + 400);
      let v = lp.run(rnd()) * Math.exp(-t / decay);
      // erken yansımalar
      if (i === Math.floor(sr * (0.011 + ch * 0.004)) || i === Math.floor(sr * (0.023 + ch * 0.006)) || i === Math.floor(sr * 0.037)) v += 0.6;
      d[i] = v * (t < 0.002 ? t / 0.002 : 1);
    }
  }
  return buf;
}

export class Audio {
  constructor() {
    this.ctx = null;
    this.ready = false;
    this.listener = { x: 0, y: 0, z: 0, rx: 1, rz: 0 };
    this.loops = new Map();
    this.bank = new Map();
    this.lastPlay = new Map();
  }

  init() {
    if (this.ctx) {
      if (this.ctx.state === 'suspended') this.ctx.resume();
      return;
    }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    const ctx = new AC({ latencyHint: 'interactive' });
    this.ctx = ctx;
    this.master = ctx.createGain();
    this.comp = ctx.createDynamicsCompressor();
    this.comp.threshold.value = -12;
    this.comp.knee.value = 8;
    this.comp.ratio.value = 5;
    this.comp.attack.value = 0.002;
    this.comp.release.value = 0.2;
    this.master.connect(this.comp);
    this.comp.connect(ctx.destination);
    // SFX zinciri: sfxBus → sfxFilter (ölümde boğma) → master
    this.sfxBus = ctx.createGain();
    this.sfxFilter = ctx.createBiquadFilter();
    this.sfxFilter.type = 'lowpass';
    this.sfxFilter.frequency.value = 20000;
    this.sfxBus.connect(this.sfxFilter);
    this.sfxFilter.connect(this.master);
    // Yankı
    this.verb = ctx.createConvolver();
    this.verb.buffer = makeImpulse(ctx);
    this.verbSend = ctx.createGain();
    this.verbReturn = ctx.createGain();
    this.verbReturn.gain.value = 0.55;
    this.verbSend.connect(this.verb);
    this.verb.connect(this.verbReturn);
    this.verbReturn.connect(this.sfxFilter);
    // Müzik
    this.musicBus = ctx.createGain();
    this.musicBus.connect(this.master);
    this.musicFilter = ctx.createBiquadFilter();
    this.musicFilter.type = 'lowpass';
    this.musicFilter.frequency.value = 20000;
    this.musicIn = ctx.createGain();
    this.musicIn.connect(this.musicFilter);
    this.musicFilter.connect(this.musicBus);
    this.musicVerb = ctx.createGain();
    this.musicVerb.gain.value = 1;
    this.musicVerb.connect(this.verbSend);

    const len = ctx.sampleRate * 2.5;
    this.noiseBuf = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = this.noiseBuf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    this.distCurve = makeDistCurve(40);
    this.softCurve = makeDistCurve(8);
    this.buildBank();
    this.ready = true;
    this.applyVolumes();
  }

  // Önce arayüz/temel sesler hemen, kalanlar küçük parçalar halinde arka planda üretilir
  buildBank(sync = false) {
    const first = ['uiClick', 'uiHover', 'type', 'beep', 'glitch'];
    this.pendingDefs = [...first, ...Object.keys(DEFS).filter((n) => !first.includes(n))];
    const step = () => {
      const t0 = performance.now();
      while (this.pendingDefs.length && (sync || performance.now() - t0 < 12)) this.renderDef(this.pendingDefs.shift());
      if (this.pendingDefs.length) setTimeout(step, 0);
    };
    for (let i = 0; i < first.length; i++) this.renderDef(this.pendingDefs.shift());
    step();
  }

  renderDef(name) {
    const sr = this.ctx.sampleRate;
    {
      const nv = VARIANTS[name] || 1;
      const list = [];
      for (let v = 0; v < nv; v++) {
        const data = DEFS[name](sr);
        let peak = 0;
        for (let i = 0; i < data.length; i++) peak = Math.max(peak, Math.abs(data[i]));
        const k = peak > 0 ? 0.95 / peak : 1;
        const b = this.ctx.createBuffer(1, data.length, sr);
        const ch = b.getChannelData(0);
        for (let i = 0; i < data.length; i++) ch[i] = data[i] * k;
        list.push(b);
      }
      this.bank.set(name, list);
    }
  }

  get bankReady() { return !this.pendingDefs || this.pendingDefs.length === 0; }

  applyVolumes() {
    if (!this.ready) return;
    this.master.gain.value = settings.master;
    this.sfxBus.gain.value = settings.sfx;
    this.musicBus.gain.value = settings.music;
  }

  setListener(pos, yaw) {
    this.listener.x = pos.x;
    this.listener.y = pos.y;
    this.listener.z = pos.z;
    this.listener.rx = Math.cos(yaw);
    this.listener.rz = -Math.sin(yaw);
  }

  muffle(amount) {
    if (!this.ready) return;
    const f = amount > 0 ? 400 + (1 - amount) * 8000 : 20000;
    this.musicFilter.frequency.setTargetAtTime(f, this.ctx.currentTime, 0.05);
    this.sfxFilter.frequency.setTargetAtTime(amount > 0 ? 1200 + (1 - amount) * 12000 : 20000, this.ctx.currentTime, 0.05);
  }

  spatial(pos, range = 40) {
    if (!pos) return { g: 1, pan: 0, d: 0 };
    const L = this.listener;
    const dx = pos.x - L.x, dy = pos.y - L.y, dz = pos.z - L.z;
    const d = Math.sqrt(dx * dx + dy * dy + dz * dz);
    const g = clamp(1 / (1 + (d * d) / (range * range) * 5), 0, 1);
    const pan = d > 0.01 ? clamp((dx * L.rx + dz * L.rz) / d, -1, 1) * 0.75 : 0;
    return { g, pan, d };
  }

  // name: bankadaki ses; extra: {vol, rate, range, verb, delay}
  play(name, pos = null, extra = {}) {
    if (!this.ready) return;
    const list = this.bank.get(name);
    if (!list) return;
    const { g, pan, d } = this.spatial(pos, extra.range || 40);
    if (g < 0.01) return;
    // aynı sesin aynı karede üst üste binmesini sınırla
    const now = this.ctx.currentTime;
    const last = this.lastPlay.get(name) || 0;
    if (now - last < 0.025 && !extra.force) return;
    this.lastPlay.set(name, now);
    const [base, verbAmt] = MIX[name] || [0.5, 0.2];
    const ctx = this.ctx;
    const src = ctx.createBufferSource();
    src.buffer = list[Math.floor(Math.random() * list.length)];
    src.playbackRate.value = (extra.rate || 1) * (extra.exactRate ? 1 : 1 + (Math.random() - 0.5) * 0.08);
    const gain = ctx.createGain();
    gain.gain.value = base * g * (extra.vol ?? 1);
    let node = src;
    if (d > 18) {
      const f = ctx.createBiquadFilter();
      f.type = 'lowpass';
      f.frequency.value = clamp(14000 - (d - 18) * 280, 1200, 14000);
      node.connect(f);
      node = f;
    }
    node.connect(gain);
    const p = ctx.createStereoPanner();
    p.pan.value = pan;
    gain.connect(p);
    p.connect(this.sfxBus);
    const va = (extra.verb ?? verbAmt) * (0.6 + Math.min(1, d / 30) * 0.8);
    if (va > 0.01) {
      const s = ctx.createGain();
      s.gain.value = va;
      p.connect(s);
      s.connect(this.verbSend);
    }
    src.start(now + (extra.delay || 0));
    return src;
  }

  // Sürekli ses (kayma gibi): başlat/durdur
  loop(name, on, opts = {}) {
    if (!this.ready) return;
    const cur = this.loops.get(name);
    const ctx = this.ctx;
    if (on && !cur) {
      const list = this.bank.get(opts.buffer || 'slideLoop');
      if (!list) return;
      const src = ctx.createBufferSource();
      src.buffer = list[0];
      src.loop = true;
      const g = ctx.createGain();
      g.gain.value = 0.0001;
      g.gain.setTargetAtTime(opts.vol || 0.2, ctx.currentTime, 0.03);
      src.connect(g);
      g.connect(this.sfxBus);
      src.start();
      this.loops.set(name, { src, g });
    } else if (!on && cur) {
      cur.g.gain.setTargetAtTime(0.0001, ctx.currentTime, 0.04);
      cur.src.stop(ctx.currentTime + 0.3);
      this.loops.delete(name);
    }
  }

  stopAllLoops() {
    for (const k of [...this.loops.keys()]) this.loop(k, false);
  }
}

function makeDistCurve(k) {
  const n = 1024;
  const c = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const x = (i * 2) / n - 1;
    c[i] = ((3 + k) * x * 20 * (Math.PI / 180)) / (Math.PI + k * Math.abs(x));
  }
  return c;
}

export { BQ, Osc, mk, rnd, sat };
