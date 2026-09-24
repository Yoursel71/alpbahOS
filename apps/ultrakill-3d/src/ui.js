// Menüler: açılış, ana menü (bölüm/zorluk/ayarlar/kontroller/hakkında), intro terminali,
// duraklatma ve bölüm sonu sıralama ekranı.
import { settings, saveSettings, progress, saveProgress, DIFFICULTIES } from './settings.js';
import { fmtTime } from './util.js';
import { Typer, drawNoise } from './typer.js';
import { LEVELS, STORY_COUNT, LAYERS } from './levels/index.js';

const c0 = (list, id) => (list.find((c) => c.id === id) || list[0]).desc;
import { SHOP_ITEMS, SHOP_GROUPS } from './shop.js';

const RANK_COL = { D: '#4aa3ff', C: '#3ee06a', B: '#ffd21f', A: '#ff8a1f', S: '#ff3a24', P: '#ffd24a' };
const ORDER = ['D', 'C', 'B', 'A', 'S', 'P'];

export const THRESH = {
  time: [240, 330, 420, 540], // S, A, B, C (saniye)
  style: [6500, 4500, 3000, 1500],
  kills: [1, 0.9, 0.75, 0.5],
};

export function rankTime(t, th = THRESH.time) {
  return t <= th[0] ? 'S' : t <= th[1] ? 'A' : t <= th[2] ? 'B' : t <= th[3] ? 'C' : 'D';
}
export function rankStyle(s, th = THRESH.style) {
  return s >= th[0] ? 'S' : s >= th[1] ? 'A' : s >= th[2] ? 'B' : s >= th[3] ? 'C' : 'D';
}
export function rankKills(f) {
  const th = THRESH.kills;
  return f >= th[0] ? 'S' : f >= th[1] ? 'A' : f >= th[2] ? 'B' : f >= th[3] ? 'C' : 'D';
}

// Açılış terminali: V1 uyanır, güç kaynağı yok, yakıt olarak KAN bulunur
const INTRO_LINES = [
  { a: 'ARAF-BIOS v0.1 — (C) CEHENNEM DİNAMİK A.Ş.', cps: 160 },
  { a: 'BELLEK TARAMASI ............................ ', b: '640K TAMAM', cps: 180 },
  { a: '' },
  { a: 'BİRİM KİMLİĞİ: ', b: 'V1', cps: 70 },
  { a: 'SINIF: SÜPER-MOBİL SAVAŞ MAKİNESİ', cps: 90 },
  { a: 'DURUM: ', b: 'UYANIŞ', cps: 70, pause: 0.35 },
  { a: '' },
  { a: '> ana güç kaynağı .......................... ', b: '[YOK]', cls: 'bad', sound: 'glitch', cps: 120, pause: 0.35 },
  { a: '> alternatif yakıt aranıyor ', bar: true, barDur: 1.1, cps: 90 },
  { a: '> KAN ...................................... ', b: '[TESPİT EDİLDİ]', cls: 'red', cps: 120, pause: 0.3 },
  { a: '> yakıt dönüştürücü ', bar: true, barDur: 0.7, cps: 110 },
  { a: '> hareket sistemleri ....................... ', b: '[TAMAM]', cps: 140 },
  { a: '> silah sistemleri ......................... ', b: '[SİLAH YOK]', cls: 'bad', cps: 140 },
  { a: '> geribesleme kolu (FEEDBACKER) ............ ', b: '[TAMAM]', cps: 140 },
  { a: '> hedef: CEHENNEM / KATMAN 0 — ARAF', cps: 70, pause: 0.6 },
];
const INTRO_BIG = ['İNSANLIK ÖLDÜ.', 'KAN YAKITTIR.', 'CEHENNEM DOLU.'];

// Terminal menüsü için blok harfli ASCII logo (5 satır)
const FONT5 = {
  U: ['█   █', '█   █', '█   █', '█   █', ' ███ '],
  L: ['█    ', '█    ', '█    ', '█    ', '█████'],
  T: ['█████', '  █  ', '  █  ', '  █  ', '  █  '],
  R: ['████ ', '█   █', '████ ', '█  █ ', '█   █'],
  A: [' ███ ', '█   █', '█████', '█   █', '█   █'],
  K: ['█   █', '█  █ ', '███  ', '█  █ ', '█   █'],
  I: ['█████', '  █  ', '  █  ', '  █  ', '█████'],
};
export function asciiLogo(word = 'ULTRAKILL') {
  return [0, 1, 2, 3, 4].map((r) => [...word].map((ch) => FONT5[ch][r]).join(' ')).join('\n');
}
const BOOT_LOG = [
  ['[  0.000]', 'V1 BIOS v2.1 — CEHENNEM DİNAMİK A.Ş.'],
  ['[  0.021]', 'bellek taraması ............ 640K TAMAM'],
  ['[  0.087]', 'yakıt: KAN ................. <b>[TESPİT]</b>'],
  ['[  0.140]', 'hareket / silah sistemleri . <b>[TAMAM]</b>'],
  ['[  0.212]', 'hedef: CEHENNEM · PRELUDE / İLK KAN'],
];
const winBar = (title) => `<div class="tw-bar"><i></i><i></i><i></i><span>${title}</span></div>`;

export class UI {
  constructor(game, root) {
    this.game = game;
    this.root = root;
    const el = document.createElement('div');
    el.id = 'screens';
    el.innerHTML = `
      <div class="screen term-screen" id="scr-splash">
        ${winBar('v1@cehennem: ~ — bash')}
        <div class="sp-body">
          <pre class="ascii-logo" aria-label="ULTRAKILL 3D">${asciiLogo()}</pre>
          <div class="sp-tag"># 3D · PRELUDE · HAYRAN YAPIMI</div>
          <div class="boot-log">${BOOT_LOG.map(([t, x], i) => `<div class="bl" style="animation-delay:${0.15 + i * 0.22}s"><span class="ts">${t}</span> ${x}</div>`).join('')}</div>
          <div class="press"><span class="ps1">$</span> ./ultrakill3d --başlat <span class="cur">▌</span><div class="press-hint">[ BAŞLAMAK İÇİN TIKLA / DOKUN ]</div></div>
        </div>
        <div class="disclaimer">Resmî değildir. ULTRAKILL; Arsi "Hakita" Patala / New Blood Interactive'in oyunudur. Bu proje tüm modelleri, sesleri ve müziği kodla üreten, ticari olmayan bir hayran çalışmasıdır.</div>
      </div>
      <div class="screen hidden term-screen" id="scr-menu">
        ${winBar('v1@cehennem: ~/ultrakill3d — bash')}
        <div class="menu-left">
          <pre class="ascii-logo small" aria-label="ULTRAKILL 3D">${asciiLogo()}</pre>
          <div class="sub"># 3D · PRELUDE · HAYRAN YAPIMI</div>
          <nav>
            <button class="btn" data-panel="play"><span class="cmd">./oyna</span></button>
            <button class="btn" data-panel="settings"><span class="cmd">./ayarlar</span></button>
            <button class="btn" data-panel="controls"><span class="cmd">./kontroller</span></button>
            <button class="btn" data-panel="about"><span class="cmd">./hakkinda</span></button>
          </nav>
          <div class="ver">v2.0 · alpbahOS apps/ultrakill-3d</div>
        </div>
        <div class="menu-right"><div class="panel-box" id="menu-panel"></div></div>
      </div>
      <div class="screen hidden term-screen" id="scr-intro">${winBar('v1@cehennem: /dev/v1 — boot')}<canvas class="noise" width="160" height="90"></canvas><div class="crt"></div><pre class="term"></pre><div class="intro-big"></div><div class="term-cont hidden blink">[ DEVAM ETMEK İÇİN TIKLA / DOKUN ]</div><div class="term-skip">tıkla / dokun / boşluk: geç</div></div>
      <div class="screen hidden" id="scr-pause">
        <div class="pause-box">
          <h1>DURAKLATILDI</h1>
          <button class="btn" data-act="resume">DEVAM ET</button>
          <button class="btn" data-act="checkpoint">SON CHECKPOINT</button>
          <button class="btn" data-act="pause-settings">AYARLAR</button>
          <button class="btn" data-act="quit">ANA MENÜ</button>
          <div class="panel-box hidden" id="pause-panel"></div>
        </div>
      </div>
      <div class="screen hidden" id="scr-results"><div class="res-box"></div></div>
      <div class="screen hidden" id="scr-shop"><div class="shop-box"></div></div>
    `;
    root.appendChild(el);
    this.el = el;
    this.scr = {};
    for (const s of el.querySelectorAll('.screen')) this.scr[s.id.replace('scr-', '')] = s;
    this.panel = el.querySelector('#menu-panel');
    this.pausePanel = el.querySelector('#pause-panel');

    this.scr.splash.addEventListener('click', () => this.game.onSplashClick());
    el.querySelectorAll('[data-panel]').forEach((b) => b.addEventListener('click', () => { this.click(); this.showPanel(b.dataset.panel); }));
    el.querySelectorAll('.btn').forEach((b) => b.addEventListener('mouseenter', () => this.game.audio.play('uiHover')));
    el.querySelector('[data-act="resume"]').addEventListener('click', () => { this.click(); this.game.resume(); });
    el.querySelector('[data-act="checkpoint"]').addEventListener('click', () => { this.click(); this.game.respawn(true); });
    el.querySelector('[data-act="quit"]').addEventListener('click', () => { this.click(); this.game.toMenu(); });
    el.querySelector('[data-act="pause-settings"]').addEventListener('click', () => {
      this.click();
      const hidden = this.pausePanel.classList.toggle('hidden');
      if (!hidden) this.renderSettings(this.pausePanel);
    });
    this.scr.intro.addEventListener('click', () => this.introClick());
  }

  click() {
    this.game.audio.init();
    this.game.audio.play('uiClick');
  }

  show(name) {
    for (const k in this.scr) this.scr[k].classList.toggle('hidden', k !== name);
    if (name === 'pause') this.pausePanel.classList.add('hidden');
  }

  hideAll() {
    for (const k in this.scr) this.scr[k].classList.add('hidden');
  }

  showPanel(name) {
    const p = this.panel;
    this.scr.menu.querySelectorAll('[data-panel]').forEach((b) => b.classList.toggle('on', b.dataset.panel === name));
    if (name === 'play') this.renderPlay(p);
    else if (name === 'settings') this.renderSettings(p);
    else if (name === 'controls') this.renderControls(p);
    else this.renderAbout(p);
  }

  renderPlay(p) {
    const n = Math.min(STORY_COUNT, progress.unlocked || 1);
    const cgOpen = (progress.unlocked || 1) >= 2 || settings.allWeapons;
    const isLocked = (i) => (LEVELS[i].endless ? !cgOpen : i >= n);
    if (this.selLevel === undefined || this.selLevel >= LEVELS.length || isLocked(this.selLevel)) {
      this.selLevel = Math.min(n - 1, Math.max(0, this.game.levelIdx));
      if (isLocked(this.selLevel)) this.selLevel = n - 1;
    }
    const sel = this.selLevel;
    const card = (L, i) => {
      const rec = progress.levels[L.id];
      const locked = isLocked(i);
      const rk = rec ? rec.rank : null;
      const badge = locked ? '🔒' : L.endless ? (rec && rec.wave ? `#${rec.wave}` : '—') : rk || '—';
      return `<button class="lv-card ${i === sel ? 'sel' : ''} ${locked ? 'locked' : ''} ${L.endless ? 'endless' : ''}" data-l="${i}" ${locked ? 'disabled' : ''}>
        <span class="lv-id">${L.endless ? '∞' : L.id}</span>
        <span class="lv-name">${locked ? '— KİLİTLİ —' : L.name}</span>
        <span class="lv-rank" style="color:${rk && !L.endless ? RANK_COL[rk] : L.endless ? '#40f0ff' : '#555'}">${badge}</span>
      </button>`;
    };
    const cards = LAYERS.map((layer) => `<div class="lv-layer">${layer}</div><div class="lv-grid">${LEVELS.map((L, i) => (L.layer === layer ? card(L, i) : '')).join('')}</div>`).join('');
    const CHARS = [
      { id: 'v1', name: 'V1', desc: '100 can · 3 stamina · dengeli' },
      { id: 'v2', name: 'V2', desc: '85 can · %12 daha hızlı · hızlı stamina · kırmızı kol', locked: !progress.v2Unlocked },
    ];
    if (CHARS.find((c) => c.id === settings.character && c.locked)) settings.character = 'v1';
    const charRow = `<div class="char-row"><span class="char-lbl">KARAKTER</span>${CHARS.map((c) => `<button class="btn char ${settings.character === c.id ? 'on' : ''} ${c.locked ? 'locked' : ''}" data-c="${c.id}" ${c.locked ? 'disabled' : ''} title="${c.desc}">${c.locked ? '🔒 ' : ''}${c.name}</button>`).join('')}<span class="char-desc">${c0(CHARS, settings.character)}</span></div>`;
    const L = LEVELS[sel];
    const rec = progress.levels[L.id];
    const recTxt = L.endless ? (rec && rec.wave ? ` <span class="muted">· EN İYİ DALGA ${rec.wave}</span>` : '') : rec && rec.time ? ` <span class="muted">· EN İYİ ${rec.rank} ${fmtTime(rec.time)}</span>` : '';
    p.innerHTML = `
      <h2>BÖLÜMLER <span class="h2-pts">P ${(progress.points || 0).toLocaleString('tr-TR')}</span></h2>
      ${cards}
      <div class="lv-info"><b>${L.endless ? '∞' : L.id}: ${L.name}</b> — ${L.desc}${recTxt}</div>
      ${charRow}
      <div class="diffs">${DIFFICULTIES.map((d, i) => `<button class="btn diff ${i === settings.difficulty ? 'on' : ''}" data-d="${i}">${d.name}</button>`).join('')}</div>
      <div class="diff-desc">${DIFFICULTIES[settings.difficulty].desc}</div>
      <div class="start-bar"><button class="btn big start" data-act="start">BAŞLA ▶ ${L.endless ? '∞' : L.id}</button></div>
    `;
    p.querySelectorAll('.lv-card:not(.locked)').forEach((b) => b.addEventListener('click', () => {
      this.click();
      this.selLevel = +b.dataset.l;
      this.renderPlay(p);
    }));
    p.querySelectorAll('.char:not(.locked)').forEach((b) => b.addEventListener('click', () => {
      this.click();
      settings.character = b.dataset.c;
      saveSettings();
      this.renderPlay(p);
    }));
    p.querySelectorAll('.diff').forEach((b) => b.addEventListener('click', () => {
      this.click();
      settings.difficulty = +b.dataset.d;
      saveSettings();
      this.renderPlay(p);
    }));
    const st = p.querySelector('[data-act="start"]');
    st.addEventListener('mouseenter', () => this.game.audio.play('uiHover'));
    st.addEventListener('click', () => {
      this.click();
      // intro yalnız 0-1'den önce
      if (sel === 0 && !settings.skipIntro) { this.game.loadLevel(0); this.game.startIntro(); } else this.game.startLevel(sel);
    });
  }

  renderSettings(p) {
    const S = settings;
    const slider = (key, label, min, max, step, fmt = (v) => v) => `
      <div class="set-row"><label>${label}</label><input type="range" data-k="${key}" min="${min}" max="${max}" step="${step}" value="${S[key]}"><span class="val" data-v="${key}">${fmt(S[key])}</span></div>`;
    const toggle = (key, label) => `<div class="set-row"><label>${label}</label><button class="btn tog ${S[key] ? 'on' : ''}" data-t="${key}">${S[key] ? 'AÇIK' : 'KAPALI'}</button></div>`;
    const pct = (v) => Math.round(v * 100) + '%';
    const touch = this.game.touch.active;
    const LVL = [[0, 'KAPALI'], [1, 'HAFİF'], [2, 'GÜÇLÜ']];
    const CYC = { touchMode: [['auto', 'OTOMATİK'], ['on', 'AÇIK'], ['off', 'KAPALI']], aimAssist: LVL, parryAssist: LVL, coinAssist: LVL, termRender: [['ascii', 'ASCII RENKLİ'], ['mono', 'ASCII FOSFOR'], ['off', 'DÜZ 3D']] };
    const cycle = (key, label) => {
      const opt = CYC[key].find((o) => o[0] === S[key]) || CYC[key][0];
      return `<div class="set-row"><label>${label}</label><button class="btn tog on" data-cycle="${key}">${opt[1]}</button></div>`;
    };
    const touchBlock = `
      <h3>DOKUNMATİK</h3>
      ${cycle('aimAssist', 'Nişan yardımı (güçlü: ateş ederken düşmana kayar)')}
      ${slider('touchSens', 'Bakış hassasiyeti', 0.3, 3, 0.05, (v) => (+v).toFixed(2))}
      <div class="set-row"><label>Buton düzeni</label><button class="btn tog" data-act="edit-layout">SÜRÜKLE-YERLEŞTİR</button></div>
      ${slider('touchScale', 'Buton boyutu', 0.7, 1.5, 0.05, pct)}
      ${slider('touchOpacity', 'Buton saydamlığı', 0.25, 1, 0.05, pct)}
      ${cycle('touchMode', 'Dokunmatik kontroller')}`;
    p.innerHTML = `
      <h2>AYARLAR</h2>
      ${touch ? touchBlock : ''}
      <h3>KONTROL</h3>
      ${touch ? '' : slider('sens', 'Fare hassasiyeti', 0.1, 4, 0.05, (v) => (+v).toFixed(2))}
      ${toggle('invertY', 'Y eksenini ters çevir')}
      <h3>YARDIM</h3>
      ${cycle('parryAssist', 'Parry yardımı (ağır çekim + işaret, geniş pencere, güdümlü geri yollama)')}
      ${cycle('coinAssist', 'Para yardımı (atış paraya yönelir, para havada asılı kalır)')}
      <h3>OYUN</h3>
      ${toggle('skipIntro', 'İntroyu atla')}
      ${toggle('allWeapons', 'Test modu: tüm silahlar (dükkânsız)')}
      <h3>GÖRÜNTÜ</h3>
      ${cycle('termRender', 'Menü/intro arka planı (terminal)')}
      ${slider('fov', 'Görüş alanı (FOV)', 70, 120, 1)}
      ${slider('resScale', 'Çözünürlük ölçeği (piksel)', 0.25, 1, 0.05, pct)}
      ${toggle('colorCompress', 'Renk sıkıştırma (dither)')}
      ${toggle('vertexJitter', 'Köşe titremesi (PSX)')}
      ${slider('shake', 'Ekran sarsıntısı', 0, 1.5, 0.05, pct)}
      ${toggle('tilt', 'Kamera eğimi')}
      ${toggle('showFps', 'FPS göster')}
      ${touch ? '' : touchBlock}
      <h3>SES</h3>
      ${slider('master', 'Ana ses', 0, 1, 0.05, pct)}
      ${slider('music', 'Müzik', 0, 1, 0.05, pct)}
      ${slider('sfx', 'Efektler', 0, 1, 0.05, pct)}
    `;
    p.querySelector('[data-act="edit-layout"]').addEventListener('click', () => {
      this.click();
      const prev = Object.keys(this.scr).find((k) => !this.scr[k].classList.contains('hidden'));
      this.hideAll();
      this.game.touch.onEditDone = () => { if (prev) this.show(prev); if (prev === 'pause') { this.pausePanel.classList.remove('hidden'); this.renderSettings(this.pausePanel); } };
      this.game.touch.editLayout();
    });
    p.querySelectorAll('[data-cycle]').forEach((cyc) => cyc.addEventListener('click', () => {
      this.click();
      const key = cyc.dataset.cycle;
      const opts = CYC[key];
      const i = opts.findIndex((o) => o[0] === S[key]);
      const next = opts[(i + 1) % opts.length];
      S[key] = next[0];
      cyc.textContent = next[1];
      saveSettings();
      this.game.applySettings();
    }));
    const fmts = { touchScale: pct, touchOpacity: pct, touchSens: (v) => (+v).toFixed(2), sens: (v) => (+v).toFixed(2), resScale: pct, shake: pct, master: pct, music: pct, sfx: pct, fov: (v) => v };
    p.querySelectorAll('input[type=range]').forEach((r) => r.addEventListener('input', () => {
      const k = r.dataset.k;
      S[k] = +r.value;
      p.querySelector(`[data-v="${k}"]`).textContent = (fmts[k] || ((v) => v))(S[k]);
      saveSettings();
      this.game.applySettings();
    }));
    p.querySelectorAll('[data-t]').forEach((b) => b.addEventListener('click', () => {
      this.click();
      const k = b.dataset.t;
      S[k] = !S[k];
      b.classList.toggle('on', S[k]);
      b.textContent = S[k] ? 'AÇIK' : 'KAPALI';
      saveSettings();
      this.game.applySettings();
    }));
  }

  renderControls(p) {
    const rows = [
      ['W A S D', 'Hareket'],
      ['BOŞLUK', 'Zıpla · havada duvara doğru: duvar sıçraması (3 kez)'],
      ['SHIFT', 'Atıl (dash) — kısa süre hasar almazsın, 3 stamina'],
      ['C', 'Yerde: kay · havada: yere çak (slam)'],
      ['C → BOŞLUK', 'Çakıştan hemen sonra zıpla: yüksek sıçrayış'],
      ['SHIFT → BOŞLUK', 'Atılırken zıpla: uzun atlayış'],
      ['SOL TIK', 'Ateş'],
      ['SAĞ TIK', 'Alternatif ateş (şarj / bozuk para / çekirdek / pompa)'],
      ['F', 'Yumruk · PARRY: mermiyi ya da parlayan saldırıyı tam zamanında yumrukla'],
      ['1 2 3 4 5', 'Revolver · Shotgun · Nailgun · Railcannon · Rocket (aynı tuş: varyant)'],
      ['G', 'Kol değiştir: Feedbacker (parry) ↔ Knuckleblaster (ağır yumruk, basılı tut: şok dalgası)'],
      ['E', 'Whiplash kancası: hafif düşmanı çek / ağır düşmana atıl'],
      ['B', 'Dükkân (yeşil terminalin önündeyken): silah, varyant ve kol satın al'],
      ['Q / TEKERLEK', 'Son silah / silah değiştir'],
      ['TAB', 'Bölüm istatistikleri'],
      ['R', 'Ölünce checkpoint\'ten devam'],
      ['ESC', 'Duraklat'],
    ];
    const touchRows = [
      ['Sol joystick', 'Yürü (parmağını ekranın sol altında herhangi bir yere koy)'],
      ['Sağa sürükle', 'Etrafa bak (ATEŞ butonunu basılı tutarken de bakabilirsin)'],
      ['ATEŞ / ALT', 'Ateş / alternatif ateş (şarj, para, çekirdek, pompa)'],
      ['ZIPLA · ATIL · KAY', 'Zıpla, dash, yerde kay / havada yere çak'],
      ['YUMRUK', 'Yumruk ve PARRY'],
      ['1-5 · ≡ · ⛶ · II', 'Silah (tekrar dokun: varyant) · istatistik · tam ekran · duraklat'],
      ['DÜKKÂN', 'Yeşil terminalin önüne gelince çıkar'],
    ];
    p.innerHTML = `<h2>KONTROLLER</h2><h3>KLAVYE + FARE</h3><table class="keys">${rows.map(([k, v]) => `<tr><td><kbd>${k}</kbd></td><td>${v}</td></tr>`).join('')}</table>
      <h3>DOKUNMATİK (MOBİL)</h3><table class="keys">${touchRows.map(([k, v]) => `<tr><td><kbd>${k}</kbd></td><td>${v}</td></tr>`).join('')}</table>
      <p class="note">PARRY ipuçları: Yumruk erken basılsa da kısa süre geçerlidir. Geri gönderilen mermi nişangâhın yakınındaki düşmana yönelir. Yakından shotgun + hemen yumruk = SHOTGUN PARRY. Kendi roketini/çekirdeğini yumrukla → hızlanır. Havadaki bozuk parayı yumrukla → sekme.</p>
      <p class="note">Marksman ile bozuk para at (sağ tık), sonra paraya ateş et → RICOSHOT! Birden çok para atarsan mermi paradan paraya seker.</p>
      <p class="note">Not: Tarayıcıda Ctrl+W sekmeyi kapatabileceği için kayma/çakma tuşu C'dir.</p>`;
  }

  renderAbout(p) {
    p.innerHTML = `<h2>HAKKINDA</h2>
      <p>ULTRAKILL'in PRELUDE (0-1 → 0-5) ve 1. katman ARAF (1-1 → 1-4) bölümlerine saygı duruşu olarak yapılmış, tarayıcıda çalışan 3D bir hayran oyunu. Tüm 3D modeller, dokular, sesler ve müzik çalışma anında kodla üretilir; orijinal oyundan hiçbir varlık kullanılmaz.</p>
      <p>Resmî değildir; New Blood Interactive veya Arsi "Hakita" Patala ile bir bağı yoktur. Orijinal oyunu destekleyin.</p>
      <h3>İÇERİK</h3>
      <ul class="about-list">
        <li>PRELUDE: ATEŞİN İÇİNE, KIYMA MAKİNESİ, ÇİFTE BELA, TEK MAKİNELİK ORDU, CERBERUS</li>
        <li>ARAF: GÜNDOĞUMUNUN KALBİ, YANAN DÜNYA, KUTSAL KALINTILAR SALONU, AY IŞIĞI (boss V2)</li>
        <li>SİBER ÖĞÜTÜCÜ: neon ızgarada bitmeyen dalgalar, en yüksek dalga rekoru</li>
        <li>Karakterler: V1 ve (1-4'ü bitirince) oynanabilir V2</li>
        <li>Revolver ile başla; silahlar, varyantlar, kollar ve Slab Revolver / Jackhammer dükkândan P ile</li>
        <li>V1 hareketi: dash, kayma, yere çakma, duvar sıçraması; parmaklı kollar ve eylem animasyonları</li>
        <li>Feedbacker yumruk ve PARRY (isteğe bağlı parry/para yardımı); kan ile iyileşme, sert hasar</li>
        <li>Filth, Stray, Schism, Drone, Streetcleaner, Malicious Face, Hideous Mass, Swordsmachine, Cerberus, V2</li>
        <li>Stil ölçeri, bölüm sonu sıralaması (D–S, P), gizli küreler, meydan okumalar</li>
      </ul>
      <p class="note">Teknoloji: Three.js (MIT). Kaynak: alpbahOS/apps/ultrakill-3d</p>`;
  }

  // ---- intro ----
  // Aşamalar: 'boot' (terminal) → 'big' (üç büyük satır) → 'done' (devam istemi)
  startIntro() {
    this.show('intro');
    const scr = this.scr.intro;
    this.introPre = scr.querySelector('.term');
    this.introBig = scr.querySelector('.intro-big');
    this.introCont = scr.querySelector('.term-cont');
    this.introNoise = scr.querySelector('.noise');
    this.introCont.classList.add('hidden');
    this.introBig.innerHTML = '';
    this.introPre.classList.remove('gone');
    scr.classList.remove('crt-on');
    void scr.offsetWidth;
    scr.classList.add('crt-on');
    this.typer = new Typer(this.introPre, INTRO_LINES, { audio: this.game.audio });
    this.introPhase = 'boot';
    this.introT = -0.7; // CRT açılışı
    this.introFast = false;
    this.introActive = true;
    this.introDone = false;
    this.game.audio.play('glitch');
  }

  introClick() {
    this.game.audio.init();
    if (this.introPhase === 'boot') { this.typer.finish(); this.enterBig(); return; }
    if (this.introPhase === 'big') { this.finishBig(); return; }
    this.introActive = false;
    this.game.startLevel();
  }

  enterBig() {
    this.introPhase = 'big';
    this.introPre.classList.add('gone');
    this.bigIdx = 0;
    this.bigT = 0.5;
  }

  finishBig() {
    while (this.bigIdx < INTRO_BIG.length) this.addBigLine(true);
    this.introPhase = 'done';
    this.introDone = true;
    this.introCont.classList.remove('hidden');
  }

  addBigLine(silent = false) {
    const d = document.createElement('div');
    d.className = 'big-line';
    d.textContent = INTRO_BIG[this.bigIdx];
    d.dataset.text = INTRO_BIG[this.bigIdx];
    this.introBig.appendChild(d);
    this.bigIdx++;
    if (!silent) {
      this.game.audio.play('bigText');
      this.scr.intro.classList.remove('jolt');
      void this.scr.intro.offsetWidth;
      this.scr.intro.classList.add('jolt');
    }
  }

  updateIntro(dt) {
    if (!this.introActive) return;
    if (Math.random() < 0.6) drawNoise(this.introNoise, 0.6);
    this.introT += dt;
    if (this.introT < 0) return;
    if (this.introPhase === 'boot') {
      if (this.typer.update(dt, this.introFast)) { this.introT = 0; this.enterBig(); }
    } else if (this.introPhase === 'big') {
      this.bigT -= dt;
      if (this.bigT <= 0) {
        if (this.bigIdx < INTRO_BIG.length) { this.addBigLine(); this.bigT = 1.15; }
        else this.finishBig();
      }
    }
  }

  // ---- dükkân ----
  showShop() {
    this.show('shop');
    this.renderShop();
  }

  renderShop() {
    const box = this.scr.shop.querySelector('.shop-box');
    const pts = progress.points || 0;
    const test = settings.allWeapons;
    const groups = SHOP_GROUPS.map((G) => {
      const items = SHOP_ITEMS.filter((it) => it.group === G.id);
      const rows = [];
      if (G.id === 'revolver') rows.push(`<div class="sh-item owned"><i style="background:#3aa0ff"></i><span class="sh-name">PIERCER<small>temel · ücretsiz</small></span><b class="sh-tag">SENDE</b></div>`);
      for (const it of items) {
        const owned = test || !!progress.shop[it.id];
        const locked = !owned && it.needs && !progress.shop[it.needs];
        const cant = !owned && !locked && pts < it.price;
        const altOn = it.alt && !!(progress.alt && progress.alt[it.alt]);
        const tag = owned && it.alt ? `<button class="sh-buy sh-toggle ${altOn ? 'on' : ''}" data-alt="${it.id}">${altOn ? 'ÇIKAR' : 'KULLAN'}</button>` : owned ? '<b class="sh-tag">SENDE</b>' : locked ? `<b class="sh-tag lock">🔒 ÖNCE ${it.needs.toUpperCase()}</b>` : `<button class="sh-buy ${cant ? 'cant' : ''}" data-buy="${it.id}">${it.price.toLocaleString('tr-TR')} P</button>`;
        rows.push(`<div class="sh-item ${owned ? 'owned' : ''} ${locked ? 'locked' : ''}"><i style="background:${it.color}"></i><span class="sh-name">${it.name}<small>${it.sub}</small></span>${tag}</div>`);
      }
      return `<div class="sh-group"><div class="sh-gname">${G.name}</div>${rows.join('')}</div>`;
    }).join('');
    box.innerHTML = `
      <div class="sh-head"><span class="sh-title">DÜKKÂN</span><span class="sh-pts">P <b>${pts.toLocaleString('tr-TR')}</b></span><button class="btn sh-close" data-act="close">KAPAT ✕</button></div>
      ${test ? '<div class="sh-note">Test modu açık: tüm silahlar zaten sende.</div>' : '<div class="sh-note">Stil puanın P olarak birikir. Aldığın silah ve varyantlar kalıcıdır; aynı silah tuşuna tekrar basınca varyant değişir.</div>'}
      <div class="sh-grid">${groups}</div>
    `;
    box.querySelector('[data-act="close"]').addEventListener('click', () => { this.click(); this.game.closeShop(); });
    box.querySelectorAll('[data-alt]').forEach((b) => b.addEventListener('click', () => {
      this.click();
      if (this.game.toggleAlt(b.dataset.alt)) this.renderShop();
    }));
    box.querySelectorAll('[data-buy]').forEach((b) => b.addEventListener('click', () => {
      if (this.game.buy(b.dataset.buy)) this.renderShop();
      else { b.classList.remove('shake'); void b.offsetWidth; b.classList.add('shake'); }
    }));
  }

  // ---- sonuçlar ----
  showResults(r) {
    this.show('results');
    const box = this.scr.results.querySelector('.res-box');
    const dots = Array.from({ length: r.secretsTotal }, (_, i) => (i < r.secrets ? '<i class="sec on"></i>' : '<i class="sec"></i>')).join('');
    const rowsHtml = r.endless ? `
        <div class="res-row" data-i="0"><span>DALGA</span><b data-count="wave">0</b><i class="rk none"></i></div>
        <div class="res-row" data-i="1"><span>SÜRE</span><b data-count="time">00:00.000</b><i class="rk none"></i></div>
        <div class="res-row" data-i="2"><span>ÖLDÜRME</span><b data-count="kills">0</b><i class="rk none"></i></div>
        <div class="res-row" data-i="3"><span>STİL</span><b data-count="style">0</b><i class="rk none"></i></div>
        <div class="res-row challenge" data-i="4"><span>MEYDAN OKUMA</span><b>${r.challengeText}</b><i class="rk ${r.challenge ? 'ok' : 'no'}">${r.challenge ? '✔' : '✘'}</i></div>` : '';
    box.innerHTML = r.endless ? `
      <div class="res-title">${r.levelTitle} <span>KOŞU BİTTİ</span></div>
      <div class="res-rows">${rowsHtml}</div>
      <div class="res-final hidden"><span>SIRA</span><div class="rank-big" style="color:${RANK_COL[r.final]}">${r.final}</div></div>
      <div class="res-extra hidden"><span class="res-p">+${r.pointsEarned.toLocaleString('tr-TR')} P kazanıldı · Toplam P ${r.pointsTotal.toLocaleString('tr-TR')}</span><br>En iyi dalga: <b>${r.bestWave}</b> · Parry: ${r.parries} · Hasar: ${Math.round(r.damage)}${r.newBest ? ' · <b>YENİ REKOR!</b>' : ''}</div>
      <div class="res-btns hidden"><button class="btn big next" data-act="retry">TEKRAR DENE ▶</button><button class="btn" data-act="menu">ANA MENÜ</button></div>
    ` : `
      <div class="res-title">${r.levelTitle} <span>TAMAMLANDI</span></div>
      <div class="res-rows">
        <div class="res-row" data-i="0"><span>SÜRE</span><b data-count="time">00:00.000</b><i class="rk">${r.timeRank}</i></div>
        <div class="res-row" data-i="1"><span>ÖLDÜRME</span><b data-count="kills">0</b><i class="rk">${r.killRank}</i></div>
        <div class="res-row" data-i="2"><span>STİL</span><b data-count="style">0</b><i class="rk">${r.styleRank}</i></div>
        <div class="res-row" data-i="3"><span>GİZLİLER</span><b class="secs">${dots}</b><i class="rk none"></i></div>
        <div class="res-row challenge" data-i="4"><span>MEYDAN OKUMA</span><b>${r.challengeText}</b><i class="rk ${r.challenge ? 'ok' : 'no'}">${r.challenge ? '✔' : '✘'}</i></div>
      </div>
      <div class="res-final hidden"><span>TOPLAM SIRA</span><div class="rank-big" style="color:${RANK_COL[r.final]}">${r.final}</div>${r.final === 'P' ? '<div class="prank">MÜKEMMEL!</div>' : ''}</div>
      <div class="res-extra hidden"><span class="res-p">+${r.pointsEarned.toLocaleString('tr-TR')} P kazanıldı (sıra ödülü ${r.rankBonus.toLocaleString('tr-TR')}) · Toplam P ${r.pointsTotal.toLocaleString('tr-TR')}</span><br>Zorluk: ${r.difficulty} · Yeniden doğuş: ${r.restarts} · Parry: ${r.parries} · Hasar: ${Math.round(r.damage)}${r.newBest ? ' · <b>YENİ REKOR!</b>' : ''}${r.finale ? `<br><b>${r.finale}</b>` : ''}</div>
      <div class="res-btns hidden">${r.hasNext ? '<button class="btn big next" data-act="next">SONRAKİ BÖLÜM ▶</button>' : ''}<button class="btn" data-act="retry">TEKRAR</button><button class="btn" data-act="menu">ANA MENÜ</button></div>
    `;
    const nx = box.querySelector('[data-act="next"]');
    if (nx) nx.addEventListener('click', () => { this.click(); this.game.nextLevel(); });
    box.querySelector('[data-act="retry"]').addEventListener('click', () => { this.click(); this.game.startLevel(); });
    box.querySelector('[data-act="menu"]').addEventListener('click', () => { this.click(); this.game.toMenu(); });
    box.querySelectorAll('.rk').forEach((e) => { if (RANK_COL[e.textContent]) e.style.color = RANK_COL[e.textContent]; });
    // sıralı açılış animasyonu
    const rows = [...box.querySelectorAll('.res-row')];
    rows.forEach((row) => row.classList.add('pending'));
    const audio = this.game.audio;
    const counters = { time: [r.time, (v) => fmtTime(v)], kills: [r.kills, (v) => (r.endless ? String(Math.round(v)) : `${Math.round(v)} / ${r.killsTotal}`)], style: [r.style, (v) => String(Math.round(v))], wave: [r.wave || 0, (v) => String(Math.round(v))] };
    // dokunmatikte daha kısa; ekrana dokunmak animasyonu anında bitirir
    const touch = this.game.touch.active;
    let fast = false;
    const T = (ms) => (fast ? 0 : touch ? ms * 0.55 : ms);
    this.scr.results.onclick = (e) => { if (!e.target.closest('.btn')) fast = true; };
    let i = 0;
    const next = () => {
      if (i >= rows.length) {
        setTimeout(() => {
          box.querySelector('.res-final').classList.remove('hidden');
          audio.play(r.final === 'P' ? 'pRank' : 'rankStamp');
          this.game.shake(0.3);
          setTimeout(() => {
            box.querySelector('.res-extra').classList.remove('hidden');
            box.querySelector('.res-btns').classList.remove('hidden');
          }, T(500));
        }, T(350));
        return;
      }
      const row = rows[i++];
      row.classList.remove('pending');
      row.classList.add('shown');
      const b = row.querySelector('[data-count]');
      const rk = row.querySelector('.rk');
      rk.classList.add('wait');
      if (b) {
        const [target, fmt] = counters[b.dataset.count];
        const t0 = performance.now();
        const dur = T(700);
        const tick = () => {
          const k = fast || dur <= 0 ? 1 : Math.min(1, (performance.now() - t0) / dur);
          b.textContent = fmt(target * k);
          if (!fast && Math.random() < 0.5) audio.play('tick');
          if (k < 1) requestAnimationFrame(tick);
          else { rk.classList.remove('wait'); if (!fast) audio.play('rankStamp'); setTimeout(next, T(250)); }
        };
        tick();
      } else {
        rk.classList.remove('wait');
        if (!fast) audio.play('tick');
        setTimeout(next, T(350));
      }
    };
    setTimeout(next, T(600));
  }
}

function escapeHtml(s) {
  return s.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
}

export function finalRank(ranks, restarts) {
  const idx = ranks.map((r) => ORDER.indexOf(r));
  if (idx.every((v) => v === 4) && restarts === 0) return 'P';
  const avg = idx.reduce((a, b) => a + b, 0) / idx.length;
  return ORDER[Math.min(4, Math.round(avg))];
}

export function betterRank(a, b) {
  if (!a) return true;
  return ORDER.indexOf(b) > ORDER.indexOf(a);
}
