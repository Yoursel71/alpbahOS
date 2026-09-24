// WebAudio ile tamamen sentezlenen ses efektleri. Harici ses dosyası yok.
import { settings } from './settings.js';
import { rand, clamp } from './util.js';

export class Audio {
  constructor() {
    this.ctx = null;
    this.ready = false;
    this.listener = { x: 0, y: 0, z: 0, rx: 1, rz: 0 };
    this.loops = new Map();
  }

  init() {
    if (this.ctx) {
      if (this.ctx.state === 'suspended') this.ctx.resume();
      return;
    }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    const ctx = new AC();
    this.ctx = ctx;
    this.master = ctx.createGain();
    this.comp = ctx.createDynamicsCompressor();
    this.comp.threshold.value = -14;
    this.comp.knee.value = 10;
    this.comp.ratio.value = 6;
    this.comp.attack.value = 0.003;
    this.comp.release.value = 0.15;
    this.master.connect(this.comp);
    this.comp.connect(ctx.destination);
    this.sfxBus = ctx.createGain();
    this.musicBus = ctx.createGain();
    this.sfxBus.connect(this.master);
    this.musicBus.connect(this.master);
    // Duck (hitstop/ölüm anında müziği boğmak için)
    this.musicFilter = ctx.createBiquadFilter();
    this.musicFilter.type = 'lowpass';
    this.musicFilter.frequency.value = 20000;
    this.musicIn = ctx.createGain();
    this.musicIn.connect(this.musicFilter);
    this.musicFilter.connect(this.musicBus);

    const len = ctx.sampleRate * 2.5;
    this.noiseBuf = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = this.noiseBuf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    this.distCurve = makeDistCurve(40);
    this.softCurve = makeDistCurve(8);
    this.ready = true;
    this.applyVolumes();
  }

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
  }

  // Konumlu ses için kazanç/pan
  spatial(pos, range = 40) {
    if (!pos) return { g: 1, pan: 0 };
    const L = this.listener;
    const dx = pos.x - L.x, dy = pos.y - L.y, dz = pos.z - L.z;
    const d = Math.sqrt(dx * dx + dy * dy + dz * dz);
    const g = clamp(1 / (1 + (d * d) / (range * range) * 6), 0, 1);
    const pan = d > 0.01 ? clamp((dx * L.rx + dz * L.rz) / d, -1, 1) * 0.8 : 0;
    return { g, pan };
  }

  out(pan, bus) {
    const p = this.ctx.createStereoPanner();
    p.pan.value = pan || 0;
    p.connect(bus || this.sfxBus);
    return p;
  }

  tone({ type = 'sine', f0 = 440, f1 = null, dur = 0.2, vol = 0.3, attack = 0.002, delay = 0, pan = 0, curve = 'exp', dist = false, bus = null, filter = null }) {
    if (!this.ready) return;
    const ctx = this.ctx;
    const t = ctx.currentTime + delay;
    const o = ctx.createOscillator();
    o.type = type;
    o.frequency.setValueAtTime(f0, t);
    if (f1 !== null) {
      if (curve === 'exp') o.frequency.exponentialRampToValueAtTime(Math.max(1, f1), t + dur);
      else o.frequency.linearRampToValueAtTime(f1, t + dur);
    }
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0002, vol), t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    let node = o;
    if (dist) {
      const ws = ctx.createWaveShaper();
      ws.curve = this.distCurve;
      node.connect(ws);
      node = ws;
    }
    if (filter) {
      const f = ctx.createBiquadFilter();
      f.type = filter.type || 'lowpass';
      f.frequency.value = filter.f || 2000;
      f.Q.value = filter.q || 0.7;
      node.connect(f);
      node = f;
    }
    node.connect(g);
    g.connect(this.out(pan, bus));
    o.start(t);
    o.stop(t + dur + 0.05);
  }

  noise({ dur = 0.2, vol = 0.3, type = 'lowpass', f0 = 2000, f1 = null, q = 0.8, attack = 0.002, delay = 0, pan = 0, bus = null, dist = false, rate = 1 }) {
    if (!this.ready) return;
    const ctx = this.ctx;
    const t = ctx.currentTime + delay;
    const src = ctx.createBufferSource();
    src.buffer = this.noiseBuf;
    src.playbackRate.value = rate;
    const f = ctx.createBiquadFilter();
    f.type = type;
    f.frequency.setValueAtTime(f0, t);
    if (f1 !== null) f.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
    f.Q.value = q;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0002, vol), t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f);
    let node = f;
    if (dist) {
      const ws = ctx.createWaveShaper();
      ws.curve = this.distCurve;
      f.connect(ws);
      node = ws;
    }
    node.connect(g);
    g.connect(this.out(pan, bus));
    const off = Math.random() * 0.5;
    src.start(t, off, dur + 0.05);
  }

  // Sürekli ses (kayma gibi): başlat/durdur
  loop(name, on, opts = {}) {
    if (!this.ready) return;
    const ctx = this.ctx;
    const cur = this.loops.get(name);
    if (on && !cur) {
      const src = ctx.createBufferSource();
      src.buffer = this.noiseBuf;
      src.loop = true;
      const f = ctx.createBiquadFilter();
      f.type = opts.type || 'bandpass';
      f.frequency.value = opts.f || 900;
      f.Q.value = opts.q || 1.2;
      const g = ctx.createGain();
      g.gain.value = 0.0001;
      g.gain.setTargetAtTime(opts.vol || 0.12, ctx.currentTime, 0.03);
      src.connect(f); f.connect(g); g.connect(this.sfxBus);
      src.start();
      this.loops.set(name, { src, g, f });
    } else if (!on && cur) {
      cur.g.gain.setTargetAtTime(0.0001, ctx.currentTime, 0.04);
      cur.src.stop(ctx.currentTime + 0.3);
      this.loops.delete(name);
    }
  }

  stopAllLoops() {
    for (const k of [...this.loops.keys()]) this.loop(k, false);
  }

  // ---- Oyun sesleri ----
  play(name, pos = null, extra = {}) {
    if (!this.ready) return;
    const { g, pan } = this.spatial(pos, extra.range || 40);
    if (g < 0.01) return;
    const v = g * (extra.vol || 1);
    const fn = SFX[name];
    if (fn) fn(this, v, pan, extra);
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

const SFX = {
  revolver(a, v, pan) {
    a.noise({ dur: 0.18, vol: 0.55 * v, type: 'highpass', f0: 900, pan });
    a.noise({ dur: 0.09, vol: 0.5 * v, type: 'lowpass', f0: 3000, f1: 400, pan });
    a.tone({ type: 'sine', f0: 170, f1: 45, dur: 0.14, vol: 0.6 * v, pan });
    a.tone({ type: 'square', f0: 2400, f1: 1200, dur: 0.03, vol: 0.08 * v, pan });
  },
  piercer(a, v, pan) {
    a.noise({ dur: 0.35, vol: 0.6 * v, type: 'lowpass', f0: 6000, f1: 200, pan });
    a.tone({ type: 'sawtooth', f0: 1800, f1: 120, dur: 0.35, vol: 0.25 * v, pan, dist: true });
    a.tone({ type: 'sine', f0: 120, f1: 35, dur: 0.3, vol: 0.7 * v, pan });
  },
  charge(a, v, pan, e) {
    a.tone({ type: 'sine', f0: 300 + (e.t || 0) * 900, f1: 320 + (e.t || 0) * 900, dur: 0.06, vol: 0.05 * v, pan });
  },
  chargeReady(a, v, pan) {
    a.tone({ type: 'triangle', f0: 1400, f1: 1500, dur: 0.12, vol: 0.18 * v, pan });
    a.tone({ type: 'triangle', f0: 2100, f1: 2200, dur: 0.12, vol: 0.1 * v, pan, delay: 0.04 });
  },
  coin(a, v, pan) {
    a.tone({ type: 'triangle', f0: 1800, f1: 2600, dur: 0.12, vol: 0.18 * v, pan });
    a.noise({ dur: 0.05, vol: 0.1 * v, type: 'highpass', f0: 4000, pan });
  },
  ricochet(a, v, pan) {
    a.tone({ type: 'sine', f0: 3200, f1: 3150, dur: 0.35, vol: 0.28 * v, pan });
    a.tone({ type: 'sine', f0: 4800, f1: 4700, dur: 0.25, vol: 0.12 * v, pan });
    a.tone({ type: 'sawtooth', f0: 2600, f1: 900, dur: 0.22, vol: 0.08 * v, pan, delay: 0.02 });
  },
  shotgun(a, v, pan) {
    a.noise({ dur: 0.4, vol: 0.8 * v, type: 'lowpass', f0: 4500, f1: 300, pan });
    a.noise({ dur: 0.12, vol: 0.4 * v, type: 'highpass', f0: 2000, pan });
    a.tone({ type: 'sine', f0: 110, f1: 32, dur: 0.3, vol: 0.9 * v, pan });
    // pompalama
    a.noise({ dur: 0.05, vol: 0.25 * v, type: 'bandpass', f0: 1800, q: 3, delay: 0.38, pan });
    a.noise({ dur: 0.06, vol: 0.3 * v, type: 'bandpass', f0: 1200, q: 3, delay: 0.52, pan });
  },
  pump(a, v, pan, e) {
    const k = e.n || 1;
    a.noise({ dur: 0.06, vol: 0.3 * v, type: 'bandpass', f0: 1400 + k * 300, q: 3, pan });
    a.tone({ type: 'square', f0: 200 + k * 120, f1: 260 + k * 150, dur: 0.1, vol: 0.08 * v, pan });
  },
  overpump(a, v, pan) {
    a.tone({ type: 'sawtooth', f0: 90, f1: 400, dur: 0.6, vol: 0.2 * v, pan, dist: true });
  },
  coreLaunch(a, v, pan) {
    a.noise({ dur: 0.2, vol: 0.4 * v, type: 'lowpass', f0: 1500, f1: 300, pan });
    a.tone({ type: 'sine', f0: 300, f1: 90, dur: 0.2, vol: 0.4 * v, pan });
  },
  explosion(a, v, pan) {
    a.noise({ dur: 1.1, vol: 0.9 * v, type: 'lowpass', f0: 2500, f1: 80, pan, dist: true });
    a.tone({ type: 'sine', f0: 90, f1: 25, dur: 0.8, vol: 1.0 * v, pan });
    a.noise({ dur: 0.15, vol: 0.5 * v, type: 'highpass', f0: 3000, pan });
  },
  rail(a, v, pan) {
    a.tone({ type: 'square', f0: 2200, f1: 60, dur: 0.7, vol: 0.28 * v, pan, dist: true });
    a.noise({ dur: 0.9, vol: 0.8 * v, type: 'lowpass', f0: 8000, f1: 100, pan });
    a.tone({ type: 'sine', f0: 70, f1: 20, dur: 1.0, vol: 1.0 * v, pan });
    a.tone({ type: 'sawtooth', f0: 4000, f1: 3000, dur: 0.3, vol: 0.08 * v, pan });
  },
  railReady(a, v, pan) {
    a.tone({ type: 'sine', f0: 600, f1: 1200, dur: 0.25, vol: 0.2 * v, pan });
    a.tone({ type: 'sine', f0: 900, f1: 1800, dur: 0.25, vol: 0.12 * v, pan, delay: 0.1 });
  },
  empty(a, v, pan) {
    a.tone({ type: 'square', f0: 900, f1: 700, dur: 0.04, vol: 0.06 * v, pan });
  },
  punch(a, v, pan) {
    a.noise({ dur: 0.12, vol: 0.35 * v, type: 'bandpass', f0: 700, f1: 2500, q: 1.2, pan });
  },
  punchHit(a, v, pan) {
    a.noise({ dur: 0.15, vol: 0.6 * v, type: 'lowpass', f0: 1200, f1: 200, pan });
    a.tone({ type: 'sine', f0: 140, f1: 50, dur: 0.15, vol: 0.7 * v, pan });
  },
  parry(a, v, pan) {
    a.tone({ type: 'sine', f0: 880, dur: 0.9, vol: 0.35 * v, pan });
    a.tone({ type: 'sine', f0: 1320, dur: 0.7, vol: 0.25 * v, pan });
    a.tone({ type: 'sine', f0: 1760, dur: 0.6, vol: 0.2 * v, pan });
    a.tone({ type: 'triangle', f0: 3520, f1: 3400, dur: 0.4, vol: 0.12 * v, pan });
    a.tone({ type: 'sine', f0: 90, f1: 30, dur: 0.5, vol: 1.0 * v, pan });
    a.noise({ dur: 0.3, vol: 0.6 * v, type: 'highpass', f0: 2500, pan });
  },
  dash(a, v, pan) {
    a.noise({ dur: 0.25, vol: 0.45 * v, type: 'bandpass', f0: 600, f1: 3500, q: 1.5, pan });
  },
  jump(a, v, pan) {
    a.noise({ dur: 0.1, vol: 0.18 * v, type: 'bandpass', f0: 500, f1: 1500, q: 2, pan });
    a.tone({ type: 'square', f0: 220, f1: 330, dur: 0.06, vol: 0.04 * v, pan });
  },
  walljump(a, v, pan) {
    a.noise({ dur: 0.1, vol: 0.3 * v, type: 'bandpass', f0: 900, f1: 2200, q: 2, pan });
    a.tone({ type: 'square', f0: 300, f1: 500, dur: 0.07, vol: 0.06 * v, pan });
  },
  land(a, v, pan) {
    a.noise({ dur: 0.1, vol: 0.2 * v, type: 'lowpass', f0: 600, pan });
  },
  step(a, v, pan) {
    a.noise({ dur: 0.05, vol: 0.12 * v, type: 'bandpass', f0: rand(900, 1300), q: 2, pan });
    a.tone({ type: 'square', f0: rand(140, 170), f1: 90, dur: 0.04, vol: 0.03 * v, pan });
  },
  slamStart(a, v, pan) {
    a.noise({ dur: 0.3, vol: 0.3 * v, type: 'bandpass', f0: 2000, f1: 400, q: 1, pan });
  },
  slam(a, v, pan) {
    a.noise({ dur: 0.5, vol: 0.9 * v, type: 'lowpass', f0: 1200, f1: 60, pan, dist: true });
    a.tone({ type: 'sine', f0: 80, f1: 25, dur: 0.45, vol: 1.0 * v, pan });
  },
  hurt(a, v, pan) {
    a.noise({ dur: 0.25, vol: 0.5 * v, type: 'lowpass', f0: 900, f1: 150, pan, dist: true });
    a.tone({ type: 'sawtooth', f0: 160, f1: 60, dur: 0.2, vol: 0.2 * v, pan, dist: true });
  },
  heal(a, v, pan) {
    a.tone({ type: 'sine', f0: 700, f1: 900, dur: 0.1, vol: 0.05 * v, pan });
  },
  enemyHit(a, v, pan) {
    a.noise({ dur: 0.12, vol: 0.35 * v, type: 'bandpass', f0: rand(400, 700), f1: 200, q: 1.5, pan });
  },
  headshot(a, v, pan) {
    a.noise({ dur: 0.16, vol: 0.5 * v, type: 'bandpass', f0: 1500, f1: 300, q: 1, pan });
    a.tone({ type: 'square', f0: 1200, f1: 600, dur: 0.06, vol: 0.06 * v, pan });
  },
  gore(a, v, pan) {
    a.noise({ dur: 0.45, vol: 0.7 * v, type: 'lowpass', f0: 1400, f1: 120, pan, dist: true, rate: 0.6 });
    a.noise({ dur: 0.25, vol: 0.4 * v, type: 'bandpass', f0: 500, q: 2, pan, delay: 0.05 });
    a.tone({ type: 'sine', f0: 120, f1: 40, dur: 0.25, vol: 0.5 * v, pan });
  },
  filthGrowl(a, v, pan) {
    a.tone({ type: 'sawtooth', f0: rand(90, 120), f1: rand(60, 80), dur: 0.4, vol: 0.12 * v, pan, dist: true, filter: { f: 700 } });
  },
  windup(a, v, pan) {
    a.tone({ type: 'sawtooth', f0: 200, f1: 700, dur: 0.4, vol: 0.12 * v, pan, filter: { f: 1500 } });
  },
  glint(a, v, pan) {
    a.tone({ type: 'sine', f0: 2600, f1: 3400, dur: 0.18, vol: 0.2 * v, pan });
    a.tone({ type: 'triangle', f0: 5200, f1: 5000, dur: 0.12, vol: 0.08 * v, pan, delay: 0.03 });
  },
  orbThrow(a, v, pan) {
    a.noise({ dur: 0.3, vol: 0.3 * v, type: 'bandpass', f0: 400, f1: 1500, q: 2, pan });
    a.tone({ type: 'sine', f0: 500, f1: 250, dur: 0.3, vol: 0.12 * v, pan });
  },
  orbCharge(a, v, pan) {
    a.tone({ type: 'sine', f0: 200, f1: 800, dur: 0.8, vol: 0.1 * v, pan, curve: 'lin' });
  },
  schismShot(a, v, pan) {
    a.tone({ type: 'square', f0: 900, f1: 300, dur: 0.1, vol: 0.08 * v, pan });
    a.noise({ dur: 0.08, vol: 0.15 * v, type: 'bandpass', f0: 1200, q: 2, pan });
  },
  projHit(a, v, pan) {
    a.noise({ dur: 0.15, vol: 0.25 * v, type: 'lowpass', f0: 1800, f1: 300, pan });
  },
  swing(a, v, pan) {
    a.noise({ dur: 0.22, vol: 0.4 * v, type: 'bandpass', f0: 3000, f1: 700, q: 1.5, pan });
    a.tone({ type: 'sawtooth', f0: 90, f1: 70, dur: 0.25, vol: 0.12 * v, pan, dist: true });
  },
  chainsaw(a, v, pan) {
    a.tone({ type: 'sawtooth', f0: 70, f1: 90, dur: 0.5, vol: 0.12 * v, pan, dist: true, filter: { f: 1800 } });
  },
  bossRoar(a, v, pan) {
    a.tone({ type: 'sawtooth', f0: 70, f1: 45, dur: 1.4, vol: 0.4 * v, pan, dist: true });
    a.tone({ type: 'square', f0: 140, f1: 95, dur: 1.3, vol: 0.15 * v, pan, dist: true, filter: { f: 1200 } });
    a.noise({ dur: 1.2, vol: 0.4 * v, type: 'bandpass', f0: 600, f1: 300, q: 1, pan });
  },
  bossShotgun(a, v, pan) {
    a.noise({ dur: 0.45, vol: 0.8 * v, type: 'lowpass', f0: 3500, f1: 200, pan });
    a.tone({ type: 'sine', f0: 100, f1: 30, dur: 0.3, vol: 0.8 * v, pan });
  },
  spawn(a, v, pan) {
    a.tone({ type: 'sine', f0: 200, f1: 1200, dur: 0.5, vol: 0.12 * v, pan });
    a.noise({ dur: 0.5, vol: 0.2 * v, type: 'bandpass', f0: 3000, f1: 800, q: 2, pan });
  },
  door(a, v, pan) {
    a.noise({ dur: 1.2, vol: 0.45 * v, type: 'lowpass', f0: 300, f1: 120, pan, dist: true });
    a.tone({ type: 'sawtooth', f0: 55, f1: 50, dur: 1.2, vol: 0.12 * v, pan, filter: { f: 300 } });
  },
  doorSlam(a, v, pan) {
    a.noise({ dur: 0.4, vol: 0.8 * v, type: 'lowpass', f0: 800, f1: 80, pan, dist: true });
    a.tone({ type: 'sine', f0: 60, f1: 30, dur: 0.4, vol: 0.9 * v, pan });
  },
  secret(a, v) {
    [0, 0.08, 0.16, 0.24].forEach((d, i) => a.tone({ type: 'triangle', f0: [784, 988, 1175, 1568][i], dur: 0.4, vol: 0.14 * v, delay: d }));
  },
  checkpoint(a, v) {
    a.tone({ type: 'square', f0: 440, dur: 0.1, vol: 0.08 * v, filter: { f: 2000 } });
    a.tone({ type: 'square', f0: 660, dur: 0.18, vol: 0.08 * v, delay: 0.1, filter: { f: 2000 } });
  },
  rankUp(a, v, pan, e) {
    const base = 440 * Math.pow(2, (e.rank || 0) / 6);
    a.tone({ type: 'square', f0: base, dur: 0.08, vol: 0.06 * v, filter: { f: 3000 } });
    a.tone({ type: 'square', f0: base * 1.5, dur: 0.12, vol: 0.06 * v, delay: 0.06, filter: { f: 3000 } });
  },
  uiHover(a, v) {
    a.tone({ type: 'square', f0: 1200, dur: 0.03, vol: 0.03 * v, filter: { f: 3000 } });
  },
  uiClick(a, v) {
    a.tone({ type: 'square', f0: 600, f1: 900, dur: 0.06, vol: 0.07 * v, filter: { f: 3000 } });
  },
  type(a, v) {
    a.noise({ dur: 0.02, vol: 0.06 * v, type: 'bandpass', f0: 3000, q: 4 });
  },
  death(a, v) {
    a.tone({ type: 'sawtooth', f0: 220, f1: 30, dur: 1.8, vol: 0.3 * v, dist: true });
    a.noise({ dur: 1.5, vol: 0.5 * v, type: 'lowpass', f0: 2000, f1: 60 });
  },
  rankStamp(a, v) {
    a.noise({ dur: 0.3, vol: 0.6 * v, type: 'lowpass', f0: 1500, f1: 100 });
    a.tone({ type: 'sine', f0: 120, f1: 40, dur: 0.3, vol: 0.8 * v });
  },
  tick(a, v) {
    a.tone({ type: 'square', f0: 1800, dur: 0.02, vol: 0.04 * v, filter: { f: 4000 } });
  },
  pRank(a, v) {
    [0, 0.1, 0.2, 0.3, 0.45].forEach((d, i) => a.tone({ type: 'triangle', f0: [523, 659, 784, 1047, 1568][i], dur: 0.6, vol: 0.14 * v, delay: d }));
  },
  lava(a, v, pan) {
    a.noise({ dur: 0.3, vol: 0.4 * v, type: 'lowpass', f0: 800, f1: 200, pan });
    a.tone({ type: 'sine', f0: 200, f1: 80, dur: 0.2, vol: 0.2 * v, pan });
  },
};
