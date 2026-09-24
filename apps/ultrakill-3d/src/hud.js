// Oyun içi arayüz (DOM): can/stamina/silah paneli, stil ölçeri, boss barı,
// ipuçları, mesajlar, isabet işareti, hasar/parry parlamaları, istatistikler.
import { RANKS } from './style.js';
import { fmtTime, clamp } from './util.js';
import { settings } from './settings.js';
import { Typer, drawNoise } from './typer.js';

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

export class HUD {
  constructor(game, root) {
    this.game = game;
    const el = document.createElement('div');
    el.id = 'hud';
    el.className = 'hidden';
    el.innerHTML = `
      <div id="dmgvig"></div>
      <div id="flash"></div>
      <div id="parrypulse"></div>
      <div id="crosshair"><i class="ch l"></i><i class="ch r"></i><i class="ch t"></i><i class="ch b"></i><div id="hitmark"><i></i><i></i><i></i><i></i></div>
        <div class="ch-hp"><i></i></div><div class="ch-st"><i></i></div></div>
      <div id="hud-bl" class="panel">
        <div class="hp-row"><div class="hp-bar"><i class="hp-hard"></i><i class="hp-fill"></i><i class="hp-heal"></i></div><div class="hp-num">100</div></div>
        <div class="stam-row"><div class="stam"><i></i></div><div class="stam"><i></i></div><div class="stam"><i></i></div></div>
        <div class="wpn-row">
          <div class="wpn-icon"></div>
          <div class="wpn-text"><div class="wpn-name">REVOLVER</div><div class="wpn-var">PIERCER</div></div>
        </div>
        <div class="wpn-extra"></div>
        <div class="wpn-slots"><span>1</span><span>2</span><span>3</span><span>4</span><span>5</span><em class="arm-ind"></em><em class="hook-ind">E</em></div>
      </div>
      <div id="hud-style" class="panel hidden">
        <div class="st-head"><div class="st-rank">D</div><div class="st-name">DESTRUCTIVE</div></div>
        <div class="st-bar"><i></i></div>
        <div class="st-fresh"><span class="fr-name">FRESH</span><div class="fr-bar"><i></i></div></div>
        <ul class="st-list"></ul>
      </div>
      <div id="bossbar" class="hidden"><div class="bb-name"></div><div class="bb-bar"><i class="bb-lag"></i><i class="bb-fill"></i></div></div>
      <div id="hint" class="hidden"></div>
      <div id="msg"></div>
      <div id="stats" class="panel hidden"></div>
      <div id="titlecard" class="hidden"></div>
      <div id="deathscreen" class="hidden">
        <canvas class="ds-noise" width="160" height="90"></canvas>
        <div class="ds-term"></div>
        <div class="ds-title hidden" data-text="ÖLDÜN">ÖLDÜN</div>
        <div class="ds-sub hidden"></div>
      </div>
      <div id="fps" class="hidden"></div>
      <div id="lockhint" class="hidden">Fare kilidi yok — bakmak için fareyi hareket ettir ya da <b>ok tuşlarını</b> kullan</div>
    `;
    root.appendChild(el);
    this.el = el;
    const q = (s) => el.querySelector(s);
    this.$ = {
      hpFill: q('.hp-fill'), hpHard: q('.hp-hard'), hpHeal: q('.hp-heal'), hpNum: q('.hp-num'),
      stam: [...el.querySelectorAll('.stam i')],
      wName: q('.wpn-name'), wVar: q('.wpn-var'), wExtra: q('.wpn-extra'), wIcon: q('.wpn-icon'), slots: [...el.querySelectorAll('.wpn-slots span')],
      style: q('#hud-style'), rank: q('.st-rank'), rankName: q('.st-name'), stBar: q('.st-bar i'), frName: q('.fr-name'), frBar: q('.fr-bar i'), list: q('.st-list'),
      boss: q('#bossbar'), bName: q('.bb-name'), bFill: q('.bb-fill'), bLag: q('.bb-lag'),
      hint: q('#hint'), msg: q('#msg'), stats: q('#stats'), flash: q('#flash'), vig: q('#dmgvig'),
      hit: q('#hitmark'), title: q('#titlecard'), death: q('#deathscreen'), fps: q('#fps'), lockhint: q('#lockhint'),
      chHp: q('.ch-hp i'), chSt: q('.ch-st i'), cross: q('#crosshair'), armInd: q('.arm-ind'), hookInd: q('.hook-ind'), pulse: q('#parrypulse'),
    };
    this.hintT = 0;
    this.msgT = 0;
    this.flashT = 0;
    this.flashDur = 1;
    this.vigT = 0;
    this.hitT = 0;
    this.titleT = 0;
    this.bossT = 0;
    this.bossLag = 1;
    this.bossFrac = 1;
    this.bonusEls = new Map();
    this.cache = {};
    this.lastHp = 100;
    this.healGlow = 0;
    this.rankPulseT = 0;
  }

  show(on) {
    this.el.classList.toggle('hidden', !on);
  }

  set(key, el, prop, val) {
    if (this.cache[key] === val) return;
    this.cache[key] = val;
    if (prop === 'text') el.textContent = val;
    else if (prop === 'html') el.innerHTML = val;
    else if (prop === 'width') el.style.width = val;
    else if (prop === 'color') el.style.color = val;
    else if (prop === 'bg') el.style.background = val;
  }

  hint(text, dur = 7) {
    if (this.game.touch && this.game.touch.active) {
      const map = { 'SHIFT': 'ATIL', 'BOŞLUK': 'ZIPLA', 'C': 'KAY', 'F': 'YUMRUK', 'SOL TIK': 'ATEŞ', 'SAĞ TIK': 'ALT', 'WASD': 'JOYSTICK', 'SHIFT → BOŞLUK': 'ATIL → ZIPLA' };
      text = text.replace(/\[([^\]]+)\]/g, (m, k) => (map[k] ? `[${map[k]}]` : m));
    }
    this.$.hint.innerHTML = esc(text).replace(/\[([^\]]+)\]/g, '<b>[$1]</b>');
    this.$.hint.classList.remove('hidden');
    this.hintT = dur;
  }

  message(text, dur = 1.5, cls = '') {
    this.$.msg.textContent = text;
    this.$.msg.className = 'show ' + cls;
    this.msgT = dur;
  }

  flash(color, dur = 0.25) {
    this.$.flash.style.background = color;
    this.flashT = dur;
    this.flashDur = dur;
    this.$.flash.style.opacity = 1;
  }

  damage(dmg) {
    this.vigT = Math.min(1, 0.4 + dmg / 40);
  }

  hitmarker(kill) {
    this.hitT = 0.15;
    this.$.hit.classList.toggle('kill', !!kill);
  }

  parryPulse() {
    const el = this.$.pulse;
    el.classList.remove('go');
    void el.offsetWidth;
    el.classList.add('go');
  }

  rankPulse() {
    this.rankPulseT = 0.3;
  }

  wallJumps() {}

  weaponChanged() {
    this.cache.wName = null;
  }

  boss(name, frac = 1, enraged = false) {
    if (!name) {
      this.$.boss.classList.add('hidden');
      this.bossActive = false;
      return;
    }
    this.bossActive = true;
    this.$.boss.classList.remove('hidden');
    this.$.boss.classList.toggle('enraged', !!enraged);
    this.set('bName', this.$.bName, 'text', name);
    this.bossFrac = clamp(frac, 0, 1);
  }

  titleCard(html, dur = 4) {
    this.$.title.innerHTML = html;
    this.$.title.classList.remove('hidden');
    this.$.title.classList.remove('out');
    void this.$.title.offsetWidth;
    this.$.title.classList.add('in');
    this.titleT = dur;
  }

  // Ölüm ekranı: kırmızı parlama → karartma + statik → terminal yazıları → ÖLDÜN → devam istemi
  death(on, n = 1) {
    const el = this.$.death;
    el.classList.toggle('hidden', !on);
    this.deathOn = on;
    if (!on) { if (this.deathTyper) this.deathTyper = null; return; }
    el.classList.remove('dark');
    el.querySelector('.ds-title').classList.add('hidden');
    const sub = el.querySelector('.ds-sub');
    sub.classList.add('hidden');
    const touch = this.game.touch && this.game.touch.active;
    sub.innerHTML = `<div class="blink">${touch ? 'DOKUN' : '<b>[R]</b> ya da TIKLA'} — SON CHECKPOINT'E DÖN</div><div class="ds-count">ölüm #${n}</div>`;
    this.deathT = 0;
    this.deathStage = 0;
    this.deathTyper = new Typer(el.querySelector('.ds-term'), [
      { a: '> KRİTİK HASAR TESPİT EDİLDİ', cls: 'bad', cps: 110 },
      { a: '> KAN REZERVİ ............. ', b: '0%', cls: 'bad', cps: 140, sound: 'glitch' },
      { a: '> MOTOR İŞLEVLERİ ......... ', b: '[ÇÖKTÜ]', cls: 'bad', cps: 140 },
      { a: '> SİLAH SİSTEMLERİ ........ ', b: '[ÇEVRİMDIŞI]', cls: 'bad', cps: 140 },
      { a: '> V1 DEVRE DIŞI', cls: 'red', cps: 60, pause: 0.25 },
    ], { audio: this.game.audio });
  }

  updateDeath(realDt) {
    if (!this.deathOn) return;
    const el = this.$.death;
    this.deathT += realDt;
    if (this.deathT > 0.55 && this.deathStage === 0) { this.deathStage = 1; el.classList.add('dark'); }
    if (this.deathStage >= 1) {
      drawNoise(el.querySelector('.ds-noise'), 0.9);
      if (this.deathTyper && this.deathTyper.update(realDt) && this.deathStage === 1) {
        this.deathStage = 2;
        this.deathT2 = 0;
        el.querySelector('.ds-title').classList.remove('hidden');
        this.game.audio.play('bigText');
        this.game.shake(0.4);
      }
    }
    if (this.deathStage === 2) {
      this.deathT2 += realDt;
      if (this.deathT2 > 0.45) { this.deathStage = 3; el.querySelector('.ds-sub').classList.remove('hidden'); }
    }
  }

  lockHint(on, permanent = true) {
    if (on) {
      this.$.lockhint.innerHTML = permanent
        ? 'Fare kilidi kullanılamıyor — bakmak için fareyi hareket ettir ya da <b>ok tuşlarını</b> kullan'
        : 'Fareyi kilitlemek için oyun ekranına <b>tıkla</b>';
    }
    this.$.lockhint.classList.toggle('hidden', !on);
  }

  hideTitle() {
    this.titleT = 0;
    this.$.title.classList.add('hidden');
  }

  stats(on) {
    const g = this.game;
    this.$.stats.classList.toggle('hidden', !on);
    if (!on) return;
    const s = g.stats;
    this.$.stats.innerHTML = `
      <div class="row"><span>SÜRE</span><b>${fmtTime(s.time)}</b></div>
      <div class="row"><span>ÖLDÜRME</span><b>${s.kills} / ${g.totalEnemies}</b></div>
      <div class="row"><span>STİL</span><b>${Math.round(g.style.total)}</b></div>
      <div class="row"><span>GİZLİ</span><b>${s.secrets} / ${g.level.secrets.length}</b></div>
      <div class="row"><span>PARRY</span><b>${s.parries}</b></div>
      <div class="row"><span>YENİDEN DOĞUŞ</span><b>${s.restarts}</b></div>`;
  }

  reset() {
    this.boss(null);
    this.$.hint.classList.add('hidden');
    this.$.msg.className = '';
    this.$.title.classList.add('hidden');
    this.death(false);
    this.$.flash.style.opacity = 0;
    this.$.vig.style.opacity = 0;
    for (const [, el] of this.bonusEls) el.remove();
    this.bonusEls.clear();
    this.cache = {};
    this.hintT = this.msgT = this.titleT = 0;
  }

  update(dt, realDt) {
    const g = this.game;
    const p = g.player;
    const $ = this.$;
    // Can
    const hp = Math.max(0, p.hp);
    if (hp > this.lastHp + 0.5) this.healGlow = 0.4;
    this.lastHp = hp;
    this.healGlow = Math.max(0, this.healGlow - realDt);
    this.set('hp', $.hpFill, 'width', hp.toFixed(1) + '%');
    this.set('hard', $.hpHard, 'width', Math.min(100, hp + p.hard).toFixed(1) + '%');
    this.set('hpNum', $.hpNum, 'text', String(Math.ceil(hp)));
    $.hpHeal.style.opacity = this.healGlow > 0 ? this.healGlow * 2 : 0;
    $.hpHeal.style.width = hp.toFixed(1) + '%';
    this.set('chHp', $.chHp, 'width', hp.toFixed(0) + '%');
    // Stamina
    for (let i = 0; i < 3; i++) {
      const v = clamp(p.stamina - i, 0, 1);
      const w = (v * 100).toFixed(0) + '%';
      this.set('st' + i, $.stam[i], 'width', w);
      $.stam[i].parentElement.classList.toggle('full', v >= 1);
    }
    this.set('chSt', $.chSt, 'width', ((p.stamina / 3) * 100).toFixed(0) + '%');
    // Silah
    const w = g.weapons.hudInfo();
    const key = w.name + w.variant + w.owned.join() + w.arm + w.hook;
    if (this.cache.wName !== key) {
      this.cache.wName = key;
      $.wName.textContent = w.name;
      $.wVar.textContent = w.variant;
      $.wVar.style.color = w.color;
      $.wIcon.style.background = w.color;
      $.wIcon.dataset.w = w.cur;
      $.slots.forEach((s, i) => { s.classList.toggle('on', i === w.cur); s.classList.toggle('none', !w.owned[i]); });
      $.armInd.textContent = w.arm;
      $.armInd.style.color = w.armColor;
      $.hookInd.classList.toggle('none', !w.hook);
    }
    let extra = '';
    const bar = (v, cls = '') => `<span class="bar ${cls}"><i style="width:${(Math.max(0, Math.min(1, v)) * 100).toFixed(0)}%"></i></span>`;
    const pips = (n, max) => Array.from({ length: max }, (_, i) => (i < Math.floor(n) ? '●' : '○')).join(' ');
    const touch = this.game.touch && this.game.touch.active;
    if (w.cur < 0) extra = touch ? 'SİLAH YOK · [YUMRUK]' : 'SİLAH YOK · [SOL TIK]/[F] YUMRUK';
    else if (w.varId === 'marksman') extra = 'PARA ' + pips(w.coins, 4);
    else if (w.varId === 'sharpshooter') extra = 'SEKME ' + pips(w.sharp, 3) + ' ' + bar(w.pierce);
    else if (w.cur === 0) extra = 'ŞARJ ' + bar(w.pierce);
    else if (w.varId === 'pump') extra = 'POMPA ' + [0, 1, 2].map((i) => (i < w.pumps ? (w.pumps >= 3 ? '<b class="hot">▮</b>' : '▮') : '▯')).join('');
    else if (w.varId === 'saw') extra = w.sawOut ? 'TESTERE <b class="hot">UÇUŞTA</b>' : 'TESTERE HAZIR';
    else if (w.cur === 1) extra = 'ÇEKİRDEK ' + bar(w.core);
    else if (w.varId === 'overheat') extra = 'ISI ' + bar(w.heat, w.heat >= 1 ? 'hot' : '');
    else if (w.cur === 2) extra = 'MIKNATIS ' + pips(w.magnets, 3);
    else if (w.cur === 3) extra = 'ŞARJ ' + bar(w.rail, 'rail ' + (w.rail >= 1 ? 'ready' : ''));
    else if (w.varId === 'freeze') extra = 'DONDURMA ' + bar(w.freeze);
    else if (w.varId === 'cannon') extra = 'GÜLLE ' + bar(w.cannon);
    else extra = 'YAKIT ' + bar(w.fuel, 'hot');
    this.set('wExtra', $.wExtra, 'html', extra);

    // Stil
    const st = g.style;
    const visible = st.active || st.rank > 0 || st.bonuses.length > 0;
    if (this.cache.stVis !== visible) { this.cache.stVis = visible; $.style.classList.toggle('hidden', !visible); }
    if (visible) {
      const R = RANKS[st.rank];
      this.set('rank', $.rank, 'text', R.letter === 'ULTRAKILL' ? 'U' : R.letter);
      this.set('rankName', $.rankName, 'text', R.name);
      this.set('rankCol', $.rank, 'color', R.color);
      $.rank.classList.toggle('ultra', st.rank === 7);
      this.set('rankNameCol', $.rankName, 'color', R.color);
      this.set('stBar', $.stBar, 'width', clamp((st.meter / R.cap) * 100, 0, 100).toFixed(1) + '%');
      this.set('stBarCol', $.stBar, 'bg', R.color);
      const fr = st.freshness(g.weapons.curId);
      this.set('frName', $.frName, 'text', fr.name);
      this.set('frCol', $.frName, 'color', fr.color);
      this.set('frBar', $.frBar, 'width', ((st.fresh[g.weapons.curId] ?? 1) * 100).toFixed(0) + '%');
      this.set('frBarCol', $.frBar, 'bg', fr.color);
      this.rankPulseT = Math.max(0, this.rankPulseT - realDt);
      $.rank.style.transform = `scale(${1 + this.rankPulseT * 1.2})`;
      // bonus listesi
      const live = new Set();
      for (const b of st.bonuses) {
        live.add(b.id);
        let li = this.bonusEls.get(b.id);
        if (!li) {
          li = document.createElement('li');
          $.list.prepend(li);
          this.bonusEls.set(b.id, li);
          b.dirty = true;
        }
        if (b.dirty) {
          b.dirty = false;
          li.textContent = '+ ' + b.name + (b.count > 1 ? ' x' + b.count : '');
          li.style.color = b.color;
          li.classList.remove('pop');
          void li.offsetWidth;
          li.classList.add('pop');
        }
        const age = g.time - b.t;
        li.style.opacity = age > 2.6 ? Math.max(0, (3.2 - age) / 0.6) : 1;
      }
      for (const [id, li] of this.bonusEls) if (!live.has(id)) { li.remove(); this.bonusEls.delete(id); }
    }

    // Boss barı
    if (this.bossActive) {
      this.bossLag = this.bossLag > this.bossFrac ? Math.max(this.bossFrac, this.bossLag - realDt * 0.4) : this.bossFrac;
      $.bFill.style.width = (this.bossFrac * 100).toFixed(1) + '%';
      $.bLag.style.width = (this.bossLag * 100).toFixed(1) + '%';
    }

    // zamanlayıcılar
    if (this.hintT > 0) { this.hintT -= realDt; if (this.hintT <= 0) $.hint.classList.add('hidden'); }
    if (this.msgT > 0) { this.msgT -= realDt; if (this.msgT <= 0) $.msg.className = ''; }
    if (this.flashT > 0) { this.flashT -= realDt; $.flash.style.opacity = Math.max(0, this.flashT / this.flashDur); } else $.flash.style.opacity = 0;
    this.vigT = Math.max(0, this.vigT - realDt * 1.5);
    const low = hp < 30 && !p.dead ? 0.25 + Math.sin(g.time * 6) * 0.1 : 0;
    $.vig.style.opacity = Math.max(this.vigT, low);
    if (this.hitT > 0) { this.hitT -= realDt; $.hit.style.opacity = 1; } else $.hit.style.opacity = 0;
    if (this.titleT > 0) {
      this.titleT -= realDt;
      if (this.titleT <= 0.6 && !$.title.classList.contains('out')) $.title.classList.add('out');
      if (this.titleT <= 0) $.title.classList.add('hidden');
    }
    $.cross.classList.toggle('parry', g.parryHintT > 0);
    this.updateDeath(realDt);
    if (settings.showFps) {
      $.fps.classList.remove('hidden');
      this.set('fps', $.fps, 'text', g.fps + ' FPS');
    } else $.fps.classList.add('hidden');
  }
}
