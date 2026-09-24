// Dokunmatik (mobil) kontroller — rekabetçi yerleşim:
//  • Sol: kayan yürüme joystick'i + sol el ATEŞ butonu (sağ başparmak nişan alırken ateş)
//  • Sağ: büyük ATEŞ (basılıyken sürükleyerek de bakılır), öne çıkan PARRY, ALT, ZIPLA, ATIL,
//    KAY/ÇAK, KANCA, KOL; ekranın geri kalanında sürükleyerek bakış
//  • Üst şerit: 1-5 silah, istatistik, tam ekran, duraklat
//  • Düzen editörü: butonlar sürüklenip yerleştirilir, konumlar kaydedilir
import { settings, saveSettings } from './settings.js';

const JOY_R = 56;

// x, y: ekrana göre merkez (0..1); s: çap (px)
export const BUTTONS = [
  { id: 'fire', code: 'Mouse0', label: 'ATEŞ', x: 0.885, y: 0.74, s: 96, cls: 't-fire', look: true },
  { id: 'fireL', code: 'Mouse0', label: 'ATEŞ', x: 0.3, y: 0.52, s: 64, cls: 't-fire t-left', look: false },
  { id: 'parry', code: 'KeyF', label: 'PARRY', x: 0.745, y: 0.6, s: 76, cls: 't-parry' },
  { id: 'alt', code: 'Mouse2', label: 'ALT', x: 0.765, y: 0.86, s: 60, cls: '' },
  { id: 'jump', code: 'Space', label: 'ZIPLA', x: 0.915, y: 0.45, s: 70, cls: '' },
  { id: 'dash', code: 'ShiftLeft', label: 'ATIL', x: 0.815, y: 0.4, s: 62, cls: 't-blue' },
  { id: 'slide', code: 'KeyC', label: 'KAY', x: 0.645, y: 0.82, s: 58, cls: '' },
  { id: 'hook', code: 'KeyE', label: 'KANCA', x: 0.7, y: 0.26, s: 54, cls: 't-green', needs: 'hook' },
  { id: 'arm', code: 'KeyG', label: 'KOL', x: 0.795, y: 0.22, s: 48, cls: 't-red', needs: 'arm2' },
  { id: 'shop', code: 'KeyB', label: 'DÜKKÂN', x: 0.5, y: 0.7, s: 84, cls: 't-shop', needs: 'shop' },
];
const JOY_DEFAULT = { x: 0.13, y: 0.72 };

export function touchDevice() {
  try {
    return (window.matchMedia && window.matchMedia('(pointer: coarse)').matches) || navigator.maxTouchPoints > 0 || 'ontouchstart' in window;
  } catch (e) {
    return false;
  }
}

export class TouchControls {
  constructor(game, root) {
    this.game = game;
    this.input = game.input;
    this.detected = touchDevice();
    const el = document.createElement('div');
    el.id = 'touch';
    el.className = 'hidden';
    el.innerHTML = `
      <div class="t-look"></div>
      <div class="t-joyzone"><div class="t-joy"><div class="t-knob"></div></div></div>
      ${BUTTONS.map((b) => `<button class="t-btn ${b.cls}" data-id="${b.id}" data-code="${b.code}" aria-label="${b.label}"><span>${b.label}</span></button>`).join('')}
      <div class="t-top">
        ${[1, 2, 3, 4, 5].map((n) => `<button class="t-sm" data-code="Digit${n}" aria-label="Silah ${n}">${n}</button>`).join('')}
        <button class="t-sm t-stats" data-code="Tab" aria-label="İstatistik">≡</button>
        <button class="t-sm t-full" aria-label="Tam ekran">⛶</button>
        <button class="t-sm t-pause" aria-label="Duraklat">II</button>
      </div>
      <div class="t-rotate hidden">Daha iyi oynamak için telefonu <b>yatay</b> çevir</div>
      <div class="t-edit hidden">
        <div class="t-edit-msg">Butonları sürükleyerek yerleştir</div>
        <button class="btn" data-act="reset">SIFIRLA</button>
        <button class="btn" data-act="save">KAYDET</button>
      </div>
    `;
    root.appendChild(el);
    this.el = el;
    this.joy = el.querySelector('.t-joy');
    this.knob = el.querySelector('.t-knob');
    this.zone = el.querySelector('.t-joyzone');
    this.rotate = el.querySelector('.t-rotate');
    this.btnEls = new Map([...el.querySelectorAll('.t-btn')].map((b) => [b.dataset.id, b]));
    this.pointers = new Map();
    this.visible = false;
    this.editing = false;
    this.layoutKey = '';

    const opts = { passive: false };
    el.querySelector('.t-look').addEventListener('pointerdown', (e) => this.start(e, { role: 'look' }), opts);
    this.zone.addEventListener('pointerdown', (e) => {
      if (this.editing) return;
      const r = this.zone.getBoundingClientRect();
      this.joyOrigin = { x: e.clientX, y: e.clientY };
      this.joy.style.left = e.clientX - r.left + 'px';
      this.joy.style.top = e.clientY - r.top + 'px';
      this.joy.classList.add('on');
      this.start(e, { role: 'joy' });
      this.moveJoy(e.clientX, e.clientY);
    }, opts);
    for (const b of el.querySelectorAll('.t-btn, .t-sm[data-code]')) {
      b.addEventListener('pointerdown', (e) => {
        if (this.editing) {
          if (b.dataset.id) this.start(e, { role: 'drag', el: b, id: b.dataset.id });
          return;
        }
        const code = b.dataset.code;
        this.start(e, { role: 'btn', code, el: b, look: b.dataset.id === 'fire' });
        b.classList.add('down');
        this.input.virtualDown(code);
      }, opts);
    }
    el.querySelector('.t-pause').addEventListener('pointerdown', (e) => { e.preventDefault(); if (!this.editing) this.game.pause(); });
    el.querySelector('.t-full').addEventListener('pointerdown', (e) => { e.preventDefault(); this.toggleFullscreen(); });
    el.querySelector('[data-act="reset"]').addEventListener('click', () => { settings.touchLayout = null; this.layoutKey = ''; this.layout(); });
    el.querySelector('[data-act="save"]').addEventListener('click', () => this.endEdit());

    window.addEventListener('pointermove', (e) => this.move(e), opts);
    window.addEventListener('pointerup', (e) => this.end(e));
    window.addEventListener('pointercancel', (e) => this.end(e));
    el.addEventListener('touchstart', (e) => { if (e.cancelable && !e.target.closest('.t-edit')) e.preventDefault(); }, opts);
    el.addEventListener('contextmenu', (e) => e.preventDefault());
    window.addEventListener('resize', () => { this.layoutKey = ''; });
  }

  get active() {
    const m = settings.touchMode || 'auto';
    return m === 'on' || (m === 'auto' && this.detected);
  }

  // Buton konumlarını ekran boyutuna göre yerleştir
  layout() {
    const W = window.innerWidth, H = window.innerHeight;
    const sc = settings.touchScale || 1;
    const key = `${W}x${H}:${sc}:${JSON.stringify(settings.touchLayout)}`;
    if (key === this.layoutKey) return;
    this.layoutKey = key;
    const L = settings.touchLayout || {};
    for (const b of BUTTONS) {
      const el = this.btnEls.get(b.id);
      const p = L[b.id] || [b.x, b.y];
      const s = b.s * sc;
      el.style.width = el.style.height = s + 'px';
      el.style.left = (p[0] * W - s / 2) + 'px';
      el.style.top = (p[1] * H - s / 2) + 'px';
      el.style.fontSize = Math.max(12, s * 0.2) + 'px';
    }
    const jp = L.joy || [JOY_DEFAULT.x, JOY_DEFAULT.y];
    this.joyDefault = jp;
  }

  editLayout() {
    this.editing = true;
    this.layoutKey = '';
    this.el.classList.remove('hidden');
    this.el.classList.add('editing');
    document.getElementById('app')?.classList.add('t-editing');
    this.el.querySelector('.t-edit').classList.remove('hidden');
    for (const [, b] of this.btnEls) b.classList.remove('hide');
    this.layout();
  }

  endEdit() {
    this.editing = false;
    this.el.classList.remove('editing');
    document.getElementById('app')?.classList.remove('t-editing');
    this.el.querySelector('.t-edit').classList.add('hidden');
    saveSettings();
    this.visible = null; // update() görünürlüğü yeniden hesaplasın
    this.el.classList.toggle('hidden', !(this.active && this.game.state === 'playing'));
    if (this.onEditDone) { const f = this.onEditDone; this.onEditDone = null; f(); }
  }

  start(e, info) {
    e.preventDefault();
    this.input.markTouch();
    info.x = e.clientX;
    info.y = e.clientY;
    this.pointers.set(e.pointerId, info);
  }

  move(e) {
    const p = this.pointers.get(e.pointerId);
    if (!p) return;
    e.preventDefault();
    const dx = e.clientX - p.x, dy = e.clientY - p.y;
    p.x = e.clientX;
    p.y = e.clientY;
    if (p.role === 'drag') {
      const L = settings.touchLayout || (settings.touchLayout = {});
      L[p.id] = [Math.max(0.03, Math.min(0.97, e.clientX / window.innerWidth)), Math.max(0.12, Math.min(0.97, e.clientY / window.innerHeight))];
      this.layoutKey = '';
      this.layout();
    } else if (p.role === 'joy') this.moveJoy(e.clientX, e.clientY);
    else if (p.role === 'look' || p.look) {
      // ivmeli bakış: hızlı sürüklemede biraz daha fazla döner (180° dönüşler kolaylaşır)
      const k = 2.4 * (settings.touchSens || 1);
      const accel = 1 + Math.min(1.2, Math.hypot(dx, dy) / 40) * 0.5;
      this.input.mdx += dx * k * accel;
      this.input.mdy += dy * k * accel;
    }
  }

  moveJoy(x, y) {
    let dx = x - this.joyOrigin.x, dy = y - this.joyOrigin.y;
    const d = Math.hypot(dx, dy);
    if (d > JOY_R) { dx = (dx / d) * JOY_R; dy = (dy / d) * JOY_R; }
    this.knob.style.transform = `translate(${dx}px, ${dy}px)`;
    this.input.axisX = dx / JOY_R;
    this.input.axisY = dy / JOY_R;
  }

  end(e) {
    const p = this.pointers.get(e.pointerId);
    if (!p) return;
    this.pointers.delete(e.pointerId);
    if (p.role === 'joy') {
      this.input.axisX = 0;
      this.input.axisY = 0;
      this.knob.style.transform = '';
      this.joy.classList.remove('on');
      this.placeJoyDefault();
    } else if (p.role === 'btn') {
      p.el.classList.remove('down');
      // aynı koda bağlı başka bir parmak hâlâ basılıysa bırakma (iki ATEŞ butonu)
      let still = false;
      for (const [, q] of this.pointers) if (q.role === 'btn' && q.code === p.code) still = true;
      if (!still) this.input.virtualUp(p.code);
    }
  }

  placeJoyDefault() {
    const r = this.zone.getBoundingClientRect();
    const jp = this.joyDefault || [JOY_DEFAULT.x, JOY_DEFAULT.y];
    this.joy.style.left = (jp[0] * window.innerWidth - r.left) + 'px';
    this.joy.style.top = (jp[1] * window.innerHeight - r.top) + 'px';
  }

  releaseAll() {
    for (const [id] of this.pointers) this.end({ pointerId: id });
    this.input.axisX = 0;
    this.input.axisY = 0;
  }

  toggleFullscreen() {
    const d = document;
    try {
      if (d.fullscreenElement || d.webkitFullscreenElement) {
        (d.exitFullscreen || d.webkitExitFullscreen).call(d);
      } else {
        const t = document.getElementById('app');
        const req = t.requestFullscreen || t.webkitRequestFullscreen;
        if (req) {
          const r = req.call(t, { navigationUI: 'hide' });
          if (r && r.then) r.then(() => { try { screen.orientation.lock('landscape').catch(() => {}); } catch (err) { /* desteklenmiyor */ } }).catch(() => {});
        }
      }
    } catch (err) { /* tam ekran desteklenmiyor */ }
  }

  update() {
    const app = document.getElementById('app');
    app.classList.toggle('touch', this.active);
    if (this.editing) return;
    const on = this.active && this.game.state === 'playing';
    if (on !== this.visible) {
      this.visible = on;
      this.el.classList.toggle('hidden', !on);
      if (!on) this.releaseAll();
      else { this.layoutKey = ''; }
    }
    if (!on) return;
    this.layout();
    if (!this.joy.classList.contains('on')) this.placeJoyDefault();
    this.el.style.setProperty('--t-alpha', settings.touchOpacity ?? 0.85);
    const w = this.game.weapons;
    this.rotate.classList.toggle('hidden', !(window.innerHeight > window.innerWidth));
    this.el.querySelectorAll('.t-top [data-code^="Digit"]').forEach((b, i) => {
      b.classList.toggle('cur', i === w.cur);
      b.classList.toggle('none', !w.owned[i]);
    });
    this.btnEls.get('hook').classList.toggle('hide', !w.hookOwned);
    this.btnEls.get('arm').classList.toggle('hide', !w.armsOwned[1]);
    this.btnEls.get('shop').classList.toggle('hide', !this.game.nearShop);
    const setLabel = (id, txt) => { const s = this.btnEls.get(id).firstChild; if (s.textContent !== txt) s.textContent = txt; };
    setLabel('fire', w.armed ? 'ATEŞ' : 'YUMRUK');
    setLabel('fireL', w.armed ? 'ATEŞ' : 'YUMRUK');
    const v = w.varId;
    const ALT = { piercer: 'ŞARJ', marksman: 'PARA', sharpshooter: 'SEKME', core: 'ÇEKİRDEK', pump: 'POMPA', saw: 'TESTERE', attractor: 'MIKNATIS', overheat: 'ISI', sawblade: 'MIKNATIS', freeze: 'DONDUR', cannon: 'GÜLLE', fire: 'ALEV' };
    setLabel('alt', ALT[v] || 'ALT');
    setLabel('slide', this.game.player.grounded ? 'KAY' : 'ÇAK');
    setLabel('parry', w.armId === 'knuckle' ? 'YUMRUK' : 'PARRY');
    this.btnEls.get('parry').classList.toggle('t-red', w.armId === 'knuckle');
    this.btnEls.get('parry').classList.toggle('ready', w.punchCd <= 0 && this.game.parryHintT > 0);
  }
}
