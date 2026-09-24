// Prosedürel müzik: sakin (keşif) ve savaş katmanları arasında geçiş yapan breakcore /
// endüstriyel döngü. Davullar DSP ile örneklenir; bas, distorsiyonlu gitar ve pad gerçek
// zamanlı çalınır. Stil rütbesi yükseldikçe gitar ve lead katmanları açılır.
import { BQ, Osc, mk, rnd, sat } from './audio.js';

const midi = (n) => 440 * Math.pow(2, (n - 69) / 12);

const PROGS = {
  main: {
    roots: [38, 34, 41, 36],
    chords: [[50, 53, 57], [46, 50, 53], [53, 57, 60], [48, 52, 55]],
  },
  boss: {
    roots: [40, 41, 40, 38],
    chords: [[52, 55, 59], [53, 57, 60], [52, 55, 59], [50, 53, 57]],
  },
};

const KICKS = [
  [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
  [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0],
  [1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0],
];
const SNARES = [
  [0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0],
  [0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0],
  [0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1],
];
const BASS_GATE = [1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1];
const GTR_GATE = [1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0];

const DRUMS = {
  kick: (sr) => mk(sr, 0.45, (o, n) => {
    const th = new Osc(sr), hp = new BQ(sr, 'hp', 2000);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      o[i] = sat((th.run(45 + 140 * Math.exp(-t / 0.035)) * Math.exp(-t / 0.2) * 1.4 + hp.run(rnd()) * Math.exp(-t / 0.004) * 0.8) * 1.8);
    }
  }),
  snare: (sr) => mk(sr, 0.35, (o, n) => {
    const bp = new BQ(sr, 'bp', 2200, 0.7), th = new Osc(sr, 'tri'), hp = new BQ(sr, 'hp', 800);
    for (let i = 0; i < n; i++) {
      const t = i / sr, z = rnd();
      o[i] = sat((bp.run(z) * Math.exp(-t / 0.09) * 1.4 + hp.run(z) * Math.exp(-t / 0.13) * 0.6 + th.run(180 * (1 + 0.6 * Math.exp(-t / 0.01))) * Math.exp(-t / 0.05) * 0.9) * 1.6);
    }
  }),
  hat: (sr) => mk(sr, 0.06, (o, n) => {
    const hp = new BQ(sr, 'hp', 8000), bp = new BQ(sr, 'bp', 10000, 2);
    for (let i = 0; i < n; i++) { const t = i / sr, z = rnd(); o[i] = (hp.run(z) + bp.run(z)) * Math.exp(-t / 0.012); }
  }),
  ohat: (sr) => mk(sr, 0.3, (o, n) => {
    const hp = new BQ(sr, 'hp', 7000), bp = new BQ(sr, 'bp', 9000, 2);
    for (let i = 0; i < n; i++) { const t = i / sr, z = rnd(); o[i] = (hp.run(z) + bp.run(z)) * Math.exp(-t / 0.09); }
  }),
  crash: (sr) => mk(sr, 1.6, (o, n) => {
    const hp = new BQ(sr, 'hp', 4000), bp = new BQ(sr, 'bp', 6000, 1);
    for (let i = 0; i < n; i++) { const t = i / sr, z = rnd(); o[i] = (hp.run(z) * 0.8 + bp.run(z) * 0.6) * Math.exp(-t / 0.45); }
  }),
};

export class Music {
  constructor(audio) {
    this.audio = audio;
    this.mode = 'off';
    this.started = false;
    this.styleRank = 0;
    this.step = 0;
    this.next = 0;
    this.timer = null;
    this.kickVar = 0;
    this.snareVar = 0;
  }

  ensure() {
    const a = this.audio;
    if (!a.ready) return false;
    if (this.started) return true;
    const ctx = a.ctx;
    this.ctx = ctx;
    const mk2 = (verb = 0) => {
      const g = ctx.createGain();
      g.gain.value = 0;
      g.connect(a.musicIn);
      if (verb) {
        const s = ctx.createGain();
        s.gain.value = verb;
        g.connect(s);
        s.connect(a.musicVerb);
      }
      return g;
    };
    this.L = { drums: mk2(0.08), bass: mk2(), pad: mk2(0.5), lead: mk2(0.3), beat: mk2(0.2), gtr: mk2(0.12) };
    // lead için eko
    this.delay = ctx.createDelay(1.0);
    this.delay.delayTime.value = 0.265;
    this.fb = ctx.createGain();
    this.fb.gain.value = 0.32;
    this.delay.connect(this.fb);
    this.fb.connect(this.delay);
    this.delay.connect(this.L.lead);
    // gitar zinciri: dağıtma → kabin filtresi
    this.gtrIn = ctx.createGain();
    const ws = ctx.createWaveShaper();
    ws.curve = a.distCurve;
    ws.oversample = '2x';
    const cabL = ctx.createBiquadFilter();
    cabL.type = 'lowpass'; cabL.frequency.value = 3200; cabL.Q.value = 0.9;
    const cabH = ctx.createBiquadFilter();
    cabH.type = 'highpass'; cabH.frequency.value = 90;
    const mid = ctx.createBiquadFilter();
    mid.type = 'peaking'; mid.frequency.value = 800; mid.gain.value = -5;
    this.gtrIn.connect(ws); ws.connect(cabH); cabH.connect(mid); mid.connect(cabL); cabL.connect(this.L.gtr);
    // davul örnekleri
    this.drums = {};
    for (const k of Object.keys(DRUMS)) {
      const data = DRUMS[k](ctx.sampleRate);
      const b = ctx.createBuffer(1, data.length, ctx.sampleRate);
      b.getChannelData(0).set(data);
      this.drums[k] = b;
    }
    this.next = ctx.currentTime + 0.1;
    this.started = true;
    this.timer = setInterval(() => this.tick(), 25);
    return true;
  }

  setMode(mode) {
    if (!this.ensure()) { this.mode = mode; return; }
    const prev = this.mode;
    this.mode = mode;
    const t = this.ctx.currentTime;
    const V = {
      off: { drums: 0, bass: 0, pad: 0, lead: 0, beat: 0, gtr: 0 },
      menu: { drums: 0, bass: 0, pad: 0.4, lead: 0, beat: 0.55, gtr: 0 },
      calm: { drums: 0, bass: 0, pad: 0.42, lead: 0, beat: 0.5, gtr: 0 },
      combat: { drums: 0.8, bass: 0.55, pad: 0.18, lead: 0, beat: 0, gtr: 0 },
      boss: { drums: 0.9, bass: 0.6, pad: 0.16, lead: 0.3, beat: 0, gtr: 0.32 },
    }[mode] || {};
    for (const k of Object.keys(this.L)) {
      this.L[k].gain.cancelScheduledValues(t);
      this.L[k].gain.setTargetAtTime(V[k] || 0, t, mode === 'combat' || mode === 'boss' ? 0.06 : 0.8);
    }
    if ((mode === 'combat' || mode === 'boss') && prev !== 'combat' && prev !== 'boss') {
      // savaşa girişte zil + bar başına hizalama
      this.crashNext = true;
      this.step = Math.ceil(this.step / 16) * 16;
    }
    this.updateLayers();
  }

  setStyleRank(r) {
    if (r === this.styleRank) return;
    this.styleRank = r;
    this.updateLayers();
  }

  updateLayers() {
    if (!this.started) return;
    const t = this.ctx.currentTime;
    let lead = 0, gtr = 0;
    if (this.mode === 'combat') {
      gtr = this.styleRank >= 2 ? 0.2 + (this.styleRank - 2) * 0.03 : 0;
      lead = this.styleRank >= 4 ? 0.16 + (this.styleRank - 4) * 0.04 : 0;
    }
    if (this.mode === 'boss') { lead = 0.28 + this.styleRank * 0.02; gtr = 0.3; }
    this.L.lead.gain.setTargetAtTime(lead, t, 0.3);
    this.L.gtr.gain.setTargetAtTime(gtr, t, 0.3);
  }

  stop() {
    this.setMode('off');
  }

  stepDur() {
    const bpm = this.mode === 'menu' ? 84 : this.mode === 'boss' ? 180 : 170;
    return 60 / bpm / 4;
  }

  tick() {
    if (!this.started) return;
    const ctx = this.ctx;
    if (ctx.state !== 'running') { this.next = ctx.currentTime + 0.05; return; }
    if (this.next < ctx.currentTime - 0.2) this.next = ctx.currentTime + 0.02;
    while (this.next < ctx.currentTime + 0.15) {
      if (this.mode !== 'off') this.playStep(this.step, this.next);
      this.next += this.stepDur();
      this.step++;
    }
  }

  playStep(step, t) {
    const s = step % 16;
    const bar = Math.floor(step / 16) % 4;
    const prog = this.mode === 'boss' ? PROGS.boss : PROGS.main;
    const root = prog.roots[bar];
    const chord = prog.chords[bar];
    const sd = this.stepDur();
    const combat = this.mode === 'combat' || this.mode === 'boss';

    if (s === 0) {
      this.kickVar = Math.floor(Math.random() * KICKS.length);
      this.snareVar = Math.floor(Math.random() * SNARES.length);
      this.pad(t, chord, sd * 16);
      if (combat && (this.crashNext || bar === 0)) { this.hit('crash', t, 0.5, this.L.drums); this.crashNext = false; }
    }

    // Sakin nabız (menü/keşif)
    if (s === 0 || s === 3 || (this.mode === 'calm' && (s === 8 || s === 11))) this.hit('kick', t, 0.55, this.L.beat, 0.8);
    if (this.mode === 'calm' && (s === 4 || s === 12)) this.hit('ohat', t, 0.08, this.L.beat);
    if (s === 0 && bar % 2 === 0) this.sub(t, root - 12, sd * 32, this.L.beat);

    // Savaş davulları
    if (combat) {
      const fill = bar === 3 && s >= 12;
      if (KICKS[this.kickVar][s]) this.hit('kick', t, 1, this.L.drums);
      if (fill) {
        this.hit('snare', t, 0.5 + (s - 12) * 0.14, this.L.drums, 1 + (s - 12) * 0.04);
        this.hit('snare', t + sd / 2, 0.4 + (s - 12) * 0.12, this.L.drums, 1.05 + (s - 12) * 0.04);
      } else if (SNARES[this.snareVar][s]) this.hit('snare', t, s === 4 || s === 12 ? 0.9 : 0.45, this.L.drums);
      if (s % 2 === 0) this.hit(s % 8 === 6 ? 'ohat' : 'hat', t, s % 4 === 2 ? 0.3 : 0.18, this.L.drums);
      else if (Math.random() < 0.35) this.hit('hat', t, 0.09, this.L.drums);

      if (BASS_GATE[s]) this.bass(t, root + (s % 4 === 3 ? 12 : 0) + (s === 14 ? 7 : 0), sd * 0.9, this.L.bass);
      if (GTR_GATE[s]) this.guitar(t, root, s % 8 === 0 ? sd * 1.8 : sd * 0.7, s % 8 === 0);

      const arp = [0, 1, 2, 1, 2, 0, 2, 1];
      if (s % 2 === 0 || this.mode === 'boss') {
        const note = chord[arp[(step >> (this.mode === 'boss' ? 0 : 1)) % arp.length]] + 12;
        this.lead(t, note, sd * 0.8);
      }
    }
  }

  // ---- enstrümanlar ----
  hit(name, t, vol, dest, rate = 1) {
    const ctx = this.ctx;
    const src = ctx.createBufferSource();
    src.buffer = this.drums[name];
    src.playbackRate.value = rate;
    const g = ctx.createGain();
    g.gain.value = vol;
    src.connect(g);
    g.connect(dest);
    src.start(t);
  }

  bass(t, n, dur, dest) {
    const ctx = this.ctx;
    const o = ctx.createOscillator();
    o.type = 'sawtooth';
    o.frequency.value = midi(n);
    const o2 = ctx.createOscillator();
    o2.type = 'square';
    o2.frequency.value = midi(n) * 0.5;
    const ws = ctx.createWaveShaper();
    ws.curve = this.audio.softCurve;
    const f = ctx.createBiquadFilter();
    f.type = 'lowpass';
    f.Q.value = 6;
    f.frequency.setValueAtTime(2200, t);
    f.frequency.exponentialRampToValueAtTime(260, t + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.28, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(ws); o2.connect(ws); ws.connect(f); f.connect(g); g.connect(dest);
    o.start(t); o2.start(t); o.stop(t + dur + 0.02); o2.stop(t + dur + 0.02);
  }

  // Distorsiyonlu güç akoru (kök + beşli + oktav)
  guitar(t, root, dur, accent) {
    const ctx = this.ctx;
    const g = ctx.createGain();
    g.gain.setValueAtTime(accent ? 0.22 : 0.16, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    g.connect(this.gtrIn);
    for (const [iv, det] of [[0, -6], [0, 7], [7, 3], [12, -4]]) {
      const o = ctx.createOscillator();
      o.type = 'sawtooth';
      o.frequency.value = midi(root + 12 + iv);
      o.detune.value = det;
      o.connect(g);
      o.start(t);
      o.stop(t + dur + 0.02);
    }
  }

  sub(t, n, dur, dest) {
    const ctx = this.ctx;
    const o = ctx.createOscillator();
    o.type = 'sine';
    o.frequency.value = midi(n);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.25, t + 0.4);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g); g.connect(dest);
    o.start(t); o.stop(t + dur + 0.05);
  }

  lead(t, n, dur) {
    const ctx = this.ctx;
    const o = ctx.createOscillator();
    o.type = 'square';
    o.frequency.value = midi(n);
    const f = ctx.createBiquadFilter();
    f.type = 'lowpass'; f.frequency.value = 2600;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.12, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(f); f.connect(g); g.connect(this.L.lead); g.connect(this.delay);
    o.start(t); o.stop(t + dur + 0.02);
  }

  // Koro benzeri pad: formant filtreli, hafif ayrışmış testereler
  pad(t, notes, dur) {
    const ctx = this.ctx;
    const f = ctx.createBiquadFilter();
    f.type = 'lowpass'; f.frequency.value = 900; f.Q.value = 0.6;
    const form = ctx.createBiquadFilter();
    form.type = 'peaking'; form.frequency.value = 700; form.gain.value = 6; form.Q.value = 2;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.09, t + dur * 0.3);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur * 1.05);
    f.connect(form); form.connect(g); g.connect(this.L.pad);
    for (const n of notes) {
      for (const det of [-11, 0, 11]) {
        const o = ctx.createOscillator();
        o.type = 'sawtooth';
        o.frequency.value = midi(n - 12);
        o.detune.value = det;
        o.connect(f);
        o.start(t); o.stop(t + dur * 1.1);
      }
    }
  }
}
