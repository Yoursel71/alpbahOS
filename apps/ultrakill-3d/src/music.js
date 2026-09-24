// Prosedürel müzik: sakin (keşif) ve savaş katmanları arasında geçiş yapan
// breakcore/endüstriyel döngü. Stil rütbesi yükseldikçe lead katmanı açılır.
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
    const mk = () => { const g = ctx.createGain(); g.gain.value = 0; g.connect(a.musicIn); return g; };
    this.L = { drums: mk(), bass: mk(), pad: mk(), lead: mk(), beat: mk() };
    // lead için eko
    this.delay = ctx.createDelay(1.0);
    this.delay.delayTime.value = 0.265;
    this.fb = ctx.createGain();
    this.fb.gain.value = 0.32;
    this.delay.connect(this.fb);
    this.fb.connect(this.delay);
    this.delay.connect(this.L.lead);
    this.next = ctx.currentTime + 0.1;
    this.started = true;
    this.timer = setInterval(() => this.tick(), 25);
    return true;
  }

  setMode(mode) {
    if (!this.ensure()) { this.mode = mode; return; }
    this.mode = mode;
    const t = this.ctx.currentTime;
    const V = {
      off: { drums: 0, bass: 0, pad: 0, lead: 0, beat: 0 },
      menu: { drums: 0, bass: 0.0, pad: 0.35, lead: 0, beat: 0.6 },
      calm: { drums: 0.0, bass: 0.0, pad: 0.4, lead: 0, beat: 0.55 },
      combat: { drums: 0.75, bass: 0.55, pad: 0.22, lead: 0, beat: 0 },
      boss: { drums: 0.85, bass: 0.65, pad: 0.2, lead: 0.35, beat: 0 },
    }[mode] || {};
    for (const k of Object.keys(this.L)) {
      this.L[k].gain.cancelScheduledValues(t);
      this.L[k].gain.setTargetAtTime(V[k] || 0, t, mode === 'combat' || mode === 'boss' ? 0.08 : 0.8);
    }
    this.updateLead();
  }

  setStyleRank(r) {
    if (r === this.styleRank) return;
    this.styleRank = r;
    this.updateLead();
  }

  updateLead() {
    if (!this.started) return;
    const t = this.ctx.currentTime;
    let v = 0;
    if (this.mode === 'combat') v = this.styleRank >= 3 ? 0.18 + (this.styleRank - 3) * 0.05 : 0;
    if (this.mode === 'boss') v = 0.3 + this.styleRank * 0.02;
    this.L.lead.gain.setTargetAtTime(v, t, 0.3);
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

    if (s === 0) {
      this.kickVar = Math.floor(Math.random() * KICKS.length);
      this.snareVar = Math.floor(Math.random() * SNARES.length);
      this.pad(t, chord, sd * 16);
    }

    // Sakin nabız (menu/calm)
    if (s === 0 || s === 3 || (this.mode === 'calm' && (s === 8 || s === 11))) this.kick(t, 0.5, this.L.beat);
    if (this.mode === 'calm' && (s === 4 || s === 12)) this.hat(t, 0.08, true, this.L.beat);
    if (s === 0 && bar % 2 === 0) this.sub(t, root - 12, sd * 32, this.L.beat);

    // Savaş davulları
    const fill = bar === 3 && s >= 12;
    if (KICKS[this.kickVar][s]) this.kick(t, 1, this.L.drums);
    if (fill) {
      this.snare(t, 0.5 + (s - 12) * 0.15, this.L.drums);
      this.snare(t + sd / 2, 0.4 + (s - 12) * 0.12, this.L.drums);
    } else if (SNARES[this.snareVar][s]) this.snare(t, s === 4 || s === 12 ? 0.9 : 0.45, this.L.drums);
    if (s % 2 === 0) this.hat(t, s % 4 === 2 ? 0.22 : 0.12, s % 8 === 6, this.L.drums);
    else if (Math.random() < 0.35) this.hat(t, 0.06, false, this.L.drums);

    // Bas
    if (BASS_GATE[s]) {
      const n = root + (s % 4 === 3 ? 12 : 0) + (s === 14 ? 7 : 0);
      this.bass(t, n, sd * 0.9, this.L.bass);
    }

    // Lead arpej
    const arp = [0, 1, 2, 1, 2, 0, 2, 1];
    if (s % 2 === 0 || this.mode === 'boss') {
      const note = chord[arp[(step >> (this.mode === 'boss' ? 0 : 1)) % arp.length]] + 12;
      this.lead(t, note, sd * 0.8);
    }
  }

  // ---- enstrümanlar ----
  kick(t, vol, dest) {
    const ctx = this.ctx;
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.frequency.setValueAtTime(160, t);
    o.frequency.exponentialRampToValueAtTime(42, t + 0.11);
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.32);
    o.connect(g); g.connect(dest);
    o.start(t); o.stop(t + 0.35);
  }

  snare(t, vol, dest) {
    const ctx = this.ctx;
    const src = ctx.createBufferSource();
    src.buffer = this.audio.noiseBuf;
    const f = ctx.createBiquadFilter();
    f.type = 'bandpass'; f.frequency.value = 1900; f.Q.value = 0.7;
    const g = ctx.createGain();
    g.gain.setValueAtTime(vol * 0.55, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.17);
    src.connect(f); f.connect(g); g.connect(dest);
    src.start(t, Math.random(), 0.2);
    const o = ctx.createOscillator();
    o.type = 'triangle';
    o.frequency.setValueAtTime(190, t);
    o.frequency.exponentialRampToValueAtTime(140, t + 0.08);
    const g2 = ctx.createGain();
    g2.gain.setValueAtTime(vol * 0.4, t);
    g2.gain.exponentialRampToValueAtTime(0.001, t + 0.1);
    o.connect(g2); g2.connect(dest);
    o.start(t); o.stop(t + 0.12);
  }

  hat(t, vol, open, dest) {
    const ctx = this.ctx;
    const src = ctx.createBufferSource();
    src.buffer = this.audio.noiseBuf;
    const f = ctx.createBiquadFilter();
    f.type = 'highpass'; f.frequency.value = 7500;
    const g = ctx.createGain();
    const d = open ? 0.14 : 0.035;
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + d);
    src.connect(f); f.connect(g); g.connect(dest);
    src.start(t, Math.random(), d + 0.02);
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

  pad(t, notes, dur) {
    const ctx = this.ctx;
    const f = ctx.createBiquadFilter();
    f.type = 'lowpass'; f.frequency.value = 850; f.Q.value = 0.5;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(0.09, t + dur * 0.3);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur * 1.05);
    f.connect(g); g.connect(this.L.pad);
    for (const n of notes) {
      for (const det of [-9, 9]) {
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
