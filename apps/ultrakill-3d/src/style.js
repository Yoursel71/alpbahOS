// Stil ölçeri: D → ULTRAKILL rütbeleri, bonus listesi, silah tazeliği, çoklu öldürme.
export const RANKS = [
  { letter: 'D', name: 'DESTRUCTIVE', color: '#4aa3ff', cap: 260, decay: 14 },
  { letter: 'C', name: 'CHAOTIC', color: '#3ee06a', cap: 320, decay: 20 },
  { letter: 'B', name: 'BRUTAL', color: '#ffd21f', cap: 380, decay: 27 },
  { letter: 'A', name: 'ANARCHIC', color: '#ff8a1f', cap: 440, decay: 34 },
  { letter: 'S', name: 'SUPREME', color: '#ff3a24', cap: 500, decay: 42 },
  { letter: 'SS', name: 'SSADISTIC', color: '#ff3a24', cap: 560, decay: 50 },
  { letter: 'SSS', name: 'SSSHITSTORM', color: '#ff3a24', cap: 620, decay: 58 },
  { letter: 'ULTRAKILL', name: 'ULTRAKILL', color: '#ffd24a', cap: 700, decay: 66 },
];

export const FRESHNESS = [
  { min: 0.75, name: 'FRESH', mult: 1.5, color: '#3ee06a' },
  { min: 0.5, name: 'USED', mult: 1.0, color: '#ffd21f' },
  { min: 0.25, name: 'STALE', mult: 0.5, color: '#ff8a1f' },
  { min: -1, name: 'DULL', mult: 0.2, color: '#ff3a24' },
];

export const BONUS_COLORS = {
  'PARRY': '#3ee06a',
  'RICOSHOT': '#ffae2a',
  'FRIED': '#ff8a1f',
  'BIG KILL': '#ff5a4a',
  'INSTAKILL': '#ff5a4a',
  'ARSENAL': '#4aa3ff',
  'QUICKDRAW': '#4aa3ff',
  'ENRAGED': '#ff3a24',
  'INTERRUPTION': '#3ee06a',
  'PROJECTILE BOOST': '#3ee06a',
  'CORE SNIPE': '#ffae2a',
  'BIG HEADSHOT': '#ffffff',
};

export class Style {
  constructor(game) {
    this.game = game;
    this.reset(true);
  }

  reset(full = false) {
    this.rank = 0;
    this.meter = 0;
    if (full) this.total = 0;
    this.bonuses = [];
    this.fresh = { revolver: 1, shotgun: 1, rail: 1 };
    this.lastKillT = -10;
    this.combo = 0;
    this.comboEntry = null;
    this.frozen = false;
    this.killWeapons = [];
    this.active = false;
  }

  freshness(w) {
    const f = this.fresh[w] ?? 1;
    for (const fr of FRESHNESS) if (f >= fr.min) return fr;
    return FRESHNESS[FRESHNESS.length - 1];
  }

  add(name, pts, weapon = null, opts = {}) {
    if (this.frozen) return;
    let mult = 1;
    if (weapon && this.fresh[weapon] !== undefined) {
      mult = this.freshness(weapon).mult;
      this.fresh[weapon] = Math.max(0, this.fresh[weapon] - pts / 1400);
    }
    const gained = Math.round(pts * mult);
    this.meter += gained;
    this.total += gained;
    this.active = true;
    if (name) this.pushBonus(name, opts.count || 0);
    this.checkRank();
  }

  // Sadece puan (hasar vb.), liste satırı yok
  addRaw(pts, weapon = null) {
    this.add(null, pts, weapon);
  }

  pushBonus(name, count) {
    const now = this.game.time;
    const last = this.bonuses[this.bonuses.length - 1];
    const color = BONUS_COLORS[name] || '#ffffff';
    if (last && last.name === name && now - last.t < 1.2 && !count) {
      last.count = (last.count || 1) + 1;
      last.t = now;
      last.dirty = true;
      return last;
    }
    const b = { name, color, t: now, count: count || 0, dirty: true, id: Math.random() };
    this.bonuses.push(b);
    if (this.bonuses.length > 7) this.bonuses.shift();
    return b;
  }

  checkRank() {
    while (this.rank < RANKS.length - 1 && this.meter >= RANKS[this.rank].cap) {
      this.meter -= RANKS[this.rank].cap;
      this.rank++;
      this.game.audio.play('rankUp', null, { rank: this.rank });
      this.game.hud.rankPulse();
    }
    if (this.rank === RANKS.length - 1) this.meter = Math.min(this.meter, RANKS[this.rank].cap);
  }

  onKill(weapon, enemy) {
    const now = this.game.time;
    if (now - this.lastKillT < 0.45) this.combo++;
    else this.combo = 1;
    this.lastKillT = now;
    if (this.combo === 2) this.add('DOUBLE KILL', 60);
    else if (this.combo === 3) this.add('TRIPLE KILL', 110);
    else if (this.combo >= 4) this.add('MULTIKILL', 160, null, { count: this.combo });
    // ARSENAL: kısa sürede 3 farklı silahla öldürme
    if (weapon) {
      this.killWeapons.push({ w: weapon, t: now });
      this.killWeapons = this.killWeapons.filter((k) => now - k.t < 6);
      const set = new Set(this.killWeapons.map((k) => k.w));
      if (set.size >= 3) {
        this.add('ARSENAL', 150);
        this.killWeapons = [];
      }
    }
  }

  onDamageTaken(dmg) {
    if (this.frozen) return;
    this.meter -= dmg * 7;
    while (this.meter < 0 && this.rank > 0) {
      this.rank--;
      this.meter += RANKS[this.rank].cap * 0.6;
    }
    if (this.meter < 0) this.meter = 0;
  }

  update(dt, currentWeapon) {
    if (this.frozen) return;
    for (const w of Object.keys(this.fresh)) {
      if (w !== currentWeapon) this.fresh[w] = Math.min(1, this.fresh[w] + dt * 0.06);
    }
    if (!this.active) return;
    this.meter -= RANKS[this.rank].decay * dt;
    if (this.meter < 0) {
      if (this.rank > 0) {
        this.rank--;
        this.meter = RANKS[this.rank].cap * 0.7;
      } else {
        this.meter = 0;
        if (this.game.time - (this.bonuses[this.bonuses.length - 1]?.t ?? -99) > 3) this.active = false;
      }
    }
    const now = this.game.time;
    this.bonuses = this.bonuses.filter((b) => now - b.t < 3.2);
  }
}
