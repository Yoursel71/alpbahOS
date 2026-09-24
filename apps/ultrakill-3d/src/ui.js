// Menüler: açılış, ana menü (bölüm/zorluk/ayarlar/kontroller/hakkında), intro terminali,
// duraklatma ve bölüm sonu sıralama ekranı.
import { settings, saveSettings, progress, saveProgress, DIFFICULTIES } from './settings.js';
import { fmtTime } from './util.js';

const RANK_COL = { D: '#4aa3ff', C: '#3ee06a', B: '#ffd21f', A: '#ff8a1f', S: '#ff3a24', P: '#ffd24a' };
const ORDER = ['D', 'C', 'B', 'A', 'S', 'P'];

export const THRESH = {
  time: [240, 330, 420, 540], // S, A, B, C (saniye)
  style: [6500, 4500, 3000, 1500],
  kills: [1, 0.9, 0.75, 0.5],
};

export function rankTime(t) {
  const th = THRESH.time;
  return t <= th[0] ? 'S' : t <= th[1] ? 'A' : t <= th[2] ? 'B' : t <= th[3] ? 'C' : 'D';
}
export function rankStyle(s) {
  const th = THRESH.style;
  return s >= th[0] ? 'S' : s >= th[1] ? 'A' : s >= th[2] ? 'B' : s >= th[3] ? 'C' : 'D';
}
export function rankKills(f) {
  const th = THRESH.kills;
  return f >= th[0] ? 'S' : f >= th[1] ? 'A' : f >= th[2] ? 'B' : f >= th[3] ? 'C' : 'D';
}

const INTRO_LINES = [
  ['ARAF-BIOS v0.1 .............................. ', '[HAZIR]'],
  ['BELLEK TARAMASI ............................. ', '640K TAMAM'],
  [''],
  ['BİRİM KİMLİĞİ: ', 'V1'],
  ['SINIF: SÜPER-MOBİL SAVAŞ MAKİNESİ'],
  ['DURUM: ', 'UYANIŞ'],
  [''],
  ['> ana güç kaynağı ........................... ', '[YOK]', 'bad'],
  ['> alternatif yakıt aranıyor ...'],
  ['> KAN ....................................... ', '[TESPİT EDİLDİ]', 'red'],
  ['> hareket sistemleri ........................ ', '[TAMAM]'],
  ['> silah sistemleri .......................... ', '[TAMAM]'],
  ['> geribesleme kolu (FEEDBACKER) ............. ', '[TAMAM]'],
  ['> hedef: CEHENNEM / KATMAN 0 — ARAF'],
  [''],
  ['İNSANLIK ÖLDÜ.', '', 'big'],
  ['KAN YAKITTIR.', '', 'big'],
  ['CEHENNEM DOLU.', '', 'big'],
];

export class UI {
  constructor(game, root) {
    this.game = game;
    this.root = root;
    const el = document.createElement('div');
    el.id = 'screens';
    el.innerHTML = `
      <div class="screen" id="scr-splash">
        <div class="logo"><span class="l1">ULTRAKILL</span><span class="l2">3D</span></div>
        <div class="sub">ARAF · HAYRAN YAPIMI</div>
        <div class="press blink">[ BAŞLAMAK İÇİN TIKLA / DOKUN ]</div>
        <div class="disclaimer">Resmî değildir. ULTRAKILL; Arsi "Hakita" Patala / New Blood Interactive'in oyunudur.<br>Bu proje tüm modelleri, sesleri ve müziği kodla üreten, ticari olmayan bir hayran çalışmasıdır.</div>
      </div>
      <div class="screen hidden" id="scr-menu">
        <div class="menu-left">
          <div class="logo small"><span class="l1">ULTRAKILL</span><span class="l2">3D</span></div>
          <div class="sub">ARAF · HAYRAN YAPIMI</div>
          <nav>
            <button class="btn" data-panel="play">OYNA</button>
            <button class="btn" data-panel="settings">AYARLAR</button>
            <button class="btn" data-panel="controls">KONTROLLER</button>
            <button class="btn" data-panel="about">HAKKINDA</button>
          </nav>
          <div class="ver">v0.1 · alpbahOS apps/ultrakill-3d</div>
        </div>
        <div class="menu-right"><div class="panel-box" id="menu-panel"></div></div>
      </div>
      <div class="screen hidden" id="scr-intro"><pre class="term"></pre><div class="term-cont hidden blink">[ DEVAM ETMEK İÇİN TIKLA / DOKUN ]</div><div class="term-skip">tıkla / dokun / boşluk: hızlandır</div></div>
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
    const best = progress.bestRank;
    p.innerHTML = `
      <h2>BÖLÜM SEÇ</h2>
      <div class="level-card sel">
        <div class="lc-thumb"><span>0-1</span></div>
        <div class="lc-info">
          <div class="lc-layer">KATMAN 0 · ARAF</div>
          <div class="lc-name">0-1: İLK KAN</div>
          <div class="lc-best">EN İYİ: <b style="color:${best ? RANK_COL[best] : '#888'}">${best || '—'}</b>${progress.bestTime ? ' · ' + fmtTime(progress.bestTime) : ''}</div>
          <div class="lc-desc">Filth, Stray, Schism ve Swordsmachine. 4 arena, 3 gizli küre.</div>
        </div>
      </div>
      <h3>ZORLUK</h3>
      <div class="diffs">${DIFFICULTIES.map((d, i) => `<button class="btn diff ${i === settings.difficulty ? 'on' : ''}" data-d="${i}">${d.name}</button>`).join('')}</div>
      <div class="diff-desc">${DIFFICULTIES[settings.difficulty].desc}</div>
      <label class="chk"><input type="checkbox" id="opt-skipintro" ${settings.skipIntro ? 'checked' : ''}> İntroyu atla</label>
      <button class="btn big start" data-act="start">BAŞLA</button>
    `;
    p.querySelectorAll('.diff').forEach((b) => b.addEventListener('click', () => {
      this.click();
      settings.difficulty = +b.dataset.d;
      saveSettings();
      this.renderPlay(p);
    }));
    p.querySelector('#opt-skipintro').addEventListener('change', (e) => { settings.skipIntro = e.target.checked; saveSettings(); });
    const st = p.querySelector('[data-act="start"]');
    st.addEventListener('mouseenter', () => this.game.audio.play('uiHover'));
    st.addEventListener('click', () => {
      this.click();
      if (settings.skipIntro) this.game.startLevel();
      else this.game.startIntro();
    });
  }

  renderSettings(p) {
    const S = settings;
    const slider = (key, label, min, max, step, fmt = (v) => v) => `
      <div class="set-row"><label>${label}</label><input type="range" data-k="${key}" min="${min}" max="${max}" step="${step}" value="${S[key]}"><span class="val" data-v="${key}">${fmt(S[key])}</span></div>`;
    const toggle = (key, label) => `<div class="set-row"><label>${label}</label><button class="btn tog ${S[key] ? 'on' : ''}" data-t="${key}">${S[key] ? 'AÇIK' : 'KAPALI'}</button></div>`;
    const pct = (v) => Math.round(v * 100) + '%';
    p.innerHTML = `
      <h2>AYARLAR</h2>
      <h3>KONTROL</h3>
      ${slider('sens', 'Fare hassasiyeti', 0.1, 4, 0.05, (v) => (+v).toFixed(2))}
      ${toggle('invertY', 'Y eksenini ters çevir')}
      <h3>GÖRÜNTÜ</h3>
      ${slider('fov', 'Görüş alanı (FOV)', 70, 120, 1)}
      ${slider('resScale', 'Çözünürlük ölçeği (piksel)', 0.25, 1, 0.05, pct)}
      ${toggle('colorCompress', 'Renk sıkıştırma (dither)')}
      ${toggle('vertexJitter', 'Köşe titremesi (PSX)')}
      ${slider('shake', 'Ekran sarsıntısı', 0, 1.5, 0.05, pct)}
      ${toggle('tilt', 'Kamera eğimi')}
      ${toggle('showFps', 'FPS göster')}
      <h3>DOKUNMATİK</h3>
      <div class="set-row"><label>Dokunmatik kontroller</label><button class="btn tog on" data-cycle="touchMode">${{ auto: 'OTOMATİK', on: 'AÇIK', off: 'KAPALI' }[S.touchMode || 'auto']}</button></div>
      ${slider('touchSens', 'Dokunmatik bakış hassasiyeti', 0.3, 3, 0.05, (v) => (+v).toFixed(2))}
      ${toggle('aimAssist', 'Nişan yardımı (yalnız dokunmatik)')}
      <h3>SES</h3>
      ${slider('master', 'Ana ses', 0, 1, 0.05, pct)}
      ${slider('music', 'Müzik', 0, 1, 0.05, pct)}
      ${slider('sfx', 'Efektler', 0, 1, 0.05, pct)}
    `;
    const cyc = p.querySelector('[data-cycle]');
    cyc.addEventListener('click', () => {
      this.click();
      const order = ['auto', 'on', 'off'];
      S.touchMode = order[(order.indexOf(S.touchMode || 'auto') + 1) % 3];
      cyc.textContent = { auto: 'OTOMATİK', on: 'AÇIK', off: 'KAPALI' }[S.touchMode];
      saveSettings();
      this.game.applySettings();
    });
    const fmts = { touchSens: (v) => (+v).toFixed(2), sens: (v) => (+v).toFixed(2), resScale: pct, shake: pct, master: pct, music: pct, sfx: pct, fov: (v) => v };
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
      ['1 2 3', 'Silah seç · aynı tuşa tekrar bas: varyant değiştir'],
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
      ['1 2 3 · ≡ · ⛶ · II', 'Silah (tekrar dokun: varyant) · istatistik · tam ekran · duraklat'],
    ];
    p.innerHTML = `<h2>KONTROLLER</h2><h3>KLAVYE + FARE</h3><table class="keys">${rows.map(([k, v]) => `<tr><td><kbd>${k}</kbd></td><td>${v}</td></tr>`).join('')}</table>
      <h3>DOKUNMATİK (MOBİL)</h3><table class="keys">${touchRows.map(([k, v]) => `<tr><td><kbd>${k}</kbd></td><td>${v}</td></tr>`).join('')}</table>
      <p class="note">İpucu: Marksman ile bozuk para at (sağ tık), sonra paraya ateş et → RICOSHOT! Birden çok para atarsan mermi paradan paraya seker.</p>
      <p class="note">Not: Tarayıcıda Ctrl+W sekmeyi kapatabileceği için kayma/çakma tuşu C'dir.</p>`;
  }

  renderAbout(p) {
    p.innerHTML = `<h2>HAKKINDA</h2>
      <p>ULTRAKILL'in ilk bölümüne (0-1) saygı duruşu olarak yapılmış, tarayıcıda çalışan 3D bir hayran oyunu. Tüm 3D modeller, dokular, sesler ve müzik çalışma anında kodla üretilir; orijinal oyundan hiçbir varlık kullanılmaz.</p>
      <p>Resmî değildir; New Blood Interactive veya Arsi "Hakita" Patala ile bir bağı yoktur. Orijinal oyunu destekleyin.</p>
      <h3>İÇERİK</h3>
      <ul class="about-list">
        <li>Menü, intro, bölüm başlığı ve bölüm sonu sıralaması (D–S, P)</li>
        <li>V1 hareketi: dash, kayma, yere çakma, duvar sıçraması</li>
        <li>Revolver (Piercer / Marksman + ricoshot), Shotgun (Core Eject / Pump Charge), Railcannon</li>
        <li>Feedbacker yumruk ve PARRY; kan ile iyileşme, sert hasar</li>
        <li>Stil ölçeri: DESTRUCTIVE → ULTRAKILL, tazelik, bonuslar</li>
        <li>Filth, Stray, Schism ve boss Swordsmachine</li>
        <li>3 gizli küre, checkpoint'ler, prosedürel müzik</li>
      </ul>
      <p class="note">Teknoloji: Three.js (MIT). Kaynak: alpbahOS/apps/ultrakill-3d</p>`;
  }

  // ---- intro ----
  startIntro() {
    this.show('intro');
    this.introPre = this.scr.intro.querySelector('.term');
    this.introCont = this.scr.intro.querySelector('.term-cont');
    this.introCont.classList.add('hidden');
    this.introPre.innerHTML = '';
    this.introLine = 0;
    this.introChar = 0;
    this.introT = 0;
    this.introDone = false;
    this.introFast = false;
    this.introActive = true;
  }

  introClick() {
    this.game.audio.init();
    if (!this.introDone) { this.introFast = true; return; }
    this.introActive = false;
    this.game.startLevel();
  }

  updateIntro(dt) {
    if (!this.introActive || this.introDone) return;
    this.introT += dt * (this.introFast ? 12 : 1);
    const game = this.game;
    while (this.introT > 0 && !this.introDone) {
      const L = INTRO_LINES[this.introLine];
      const text = (L[0] || '') + (L[1] || '');
      if (this.introChar === 0) {
        const div = document.createElement('div');
        div.className = 'tl ' + (L[2] || '');
        this.introPre.appendChild(div);
        this.curDiv = div;
      }
      if (this.introChar < text.length) {
        this.introChar++;
        const shown = text.slice(0, this.introChar);
        const a = L[0] || '';
        if (this.introChar <= a.length) this.curDiv.textContent = shown;
        else this.curDiv.innerHTML = escapeHtml(a) + `<span class="st">${escapeHtml(shown.slice(a.length))}</span>`;
        this.introT -= L[2] === 'big' ? 0.06 : 0.012;
        if (this.introChar % 3 === 0) game.audio.play('type');
      } else {
        this.introLine++;
        this.introChar = 0;
        this.introT -= L[2] === 'big' ? 0.7 : text.length ? 0.18 : 0.1;
        if (L[2] === 'big') { game.audio.play('rankStamp'); game.shake(0.1); }
        if (this.introLine >= INTRO_LINES.length) {
          this.introDone = true;
          this.introCont.classList.remove('hidden');
        }
      }
    }
  }

  // ---- sonuçlar ----
  showResults(r) {
    this.show('results');
    const box = this.scr.results.querySelector('.res-box');
    const dots = Array.from({ length: r.secretsTotal }, (_, i) => (i < r.secrets ? '<i class="sec on"></i>' : '<i class="sec"></i>')).join('');
    box.innerHTML = `
      <div class="res-title">0-1: İLK KAN <span>TAMAMLANDI</span></div>
      <div class="res-rows">
        <div class="res-row" data-i="0"><span>SÜRE</span><b data-count="time">00:00.000</b><i class="rk">${r.timeRank}</i></div>
        <div class="res-row" data-i="1"><span>ÖLDÜRME</span><b data-count="kills">0</b><i class="rk">${r.killRank}</i></div>
        <div class="res-row" data-i="2"><span>STİL</span><b data-count="style">0</b><i class="rk">${r.styleRank}</i></div>
        <div class="res-row" data-i="3"><span>GİZLİLER</span><b class="secs">${dots}</b><i class="rk none"></i></div>
        <div class="res-row challenge" data-i="4"><span>MEYDAN OKUMA</span><b>En az 5 PARRY yap (${r.parries})</b><i class="rk ${r.challenge ? 'ok' : 'no'}">${r.challenge ? '✔' : '✘'}</i></div>
      </div>
      <div class="res-final hidden"><span>TOPLAM SIRA</span><div class="rank-big" style="color:${RANK_COL[r.final]}">${r.final}</div>${r.final === 'P' ? '<div class="prank">MÜKEMMEL!</div>' : ''}</div>
      <div class="res-extra hidden">Zorluk: ${r.difficulty} · Yeniden doğuş: ${r.restarts} · Parry: ${r.parries} · Alınan hasar: ${Math.round(r.damage)}${r.newBest ? ' · <b>YENİ REKOR!</b>' : ''}</div>
      <div class="res-btns hidden"><button class="btn" data-act="retry">TEKRAR OYNA</button><button class="btn" data-act="menu">ANA MENÜ</button></div>
    `;
    box.querySelector('[data-act="retry"]').addEventListener('click', () => { this.click(); this.game.startLevel(); });
    box.querySelector('[data-act="menu"]').addEventListener('click', () => { this.click(); this.game.toMenu(); });
    box.querySelectorAll('.rk').forEach((e) => { if (RANK_COL[e.textContent]) e.style.color = RANK_COL[e.textContent]; });
    // sıralı açılış animasyonu
    const rows = [...box.querySelectorAll('.res-row')];
    rows.forEach((row) => row.classList.add('pending'));
    const audio = this.game.audio;
    const counters = { time: [r.time, (v) => fmtTime(v)], kills: [r.kills, (v) => `${Math.round(v)} / ${r.killsTotal}`], style: [r.style, (v) => String(Math.round(v))] };
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
          }, 500);
        }, 350);
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
        const dur = 700;
        const tick = () => {
          const k = Math.min(1, (performance.now() - t0) / dur);
          b.textContent = fmt(target * k);
          if (Math.random() < 0.5) audio.play('tick');
          if (k < 1) requestAnimationFrame(tick);
          else { rk.classList.remove('wait'); audio.play('rankStamp'); setTimeout(next, 250); }
        };
        tick();
      } else {
        rk.classList.remove('wait');
        audio.play('tick');
        setTimeout(next, 350);
      }
    };
    setTimeout(next, 600);
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
