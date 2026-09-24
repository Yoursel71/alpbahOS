// Dokunmatik (mobil) kontroller: solda kayan yürüme joystick'i, sağda sürükleyerek bakış,
// aksiyon butonları (ateş, alternatif ateş, zıpla, atıl, kay/çak, yumruk), silah seçimi,
// duraklatma ve tam ekran. Butonlar klavye/fare kodlarını taklit eder; oyun mantığı aynı kalır.
import { settings } from './settings.js';

const JOY_R = 56;

const BUTTONS = [
  { code: 'Mouse0', cls: 't-fire', label: 'ATEŞ', look: true },
  { code: 'Mouse2', cls: 't-alt', label: 'ALT' },
  { code: 'Space', cls: 't-jump', label: 'ZIPLA' },
  { code: 'ShiftLeft', cls: 't-dash', label: 'ATIL' },
  { code: 'KeyC', cls: 't-slide', label: 'KAY' },
  { code: 'KeyF', cls: 't-punch', label: 'YUMRUK' },
];

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
      ${BUTTONS.map((b) => `<button class="t-btn ${b.cls}" data-code="${b.code}" aria-label="${b.label}"><span>${b.label}</span></button>`).join('')}
      <div class="t-top">
        <button class="t-sm" data-code="Digit1" aria-label="Silah 1">1</button>
        <button class="t-sm" data-code="Digit2" aria-label="Silah 2">2</button>
        <button class="t-sm" data-code="Digit3" aria-label="Silah 3">3</button>
        <button class="t-sm t-stats" data-code="Tab" aria-label="İstatistik">≡</button>
        <button class="t-sm t-full" aria-label="Tam ekran">⛶</button>
        <button class="t-sm t-pause" aria-label="Duraklat">II</button>
      </div>
      <div class="t-rotate hidden">Daha iyi oynamak için telefonu <b>yatay</b> çevir</div>
    `;
    root.appendChild(el);
    this.el = el;
    this.joy = el.querySelector('.t-joy');
    this.knob = el.querySelector('.t-knob');
    this.rotate = el.querySelector('.t-rotate');
    this.pointers = new Map(); // pointerId → {role, code?, x, y}
    this.visible = false;

    const look = el.querySelector('.t-look');
    const zone = el.querySelector('.t-joyzone');
    const opts = { passive: false };

    // Bakış bölgesi
    look.addEventListener('pointerdown', (e) => this.start(e, { role: 'look' }), opts);
    // Joystick
    zone.addEventListener('pointerdown', (e) => {
      const r = zone.getBoundingClientRect();
      this.joyOrigin = { x: e.clientX, y: e.clientY };
      this.joy.style.left = e.clientX - r.left + 'px';
      this.joy.style.top = e.clientY - r.top + 'px';
      this.joy.classList.add('on');
      this.start(e, { role: 'joy' });
      this.moveJoy(e.clientX, e.clientY);
    }, opts);
    // Butonlar
    for (const b of el.querySelectorAll('.t-btn, .t-sm[data-code]')) {
      b.addEventListener('pointerdown', (e) => {
        const code = b.dataset.code;
        this.start(e, { role: 'btn', code, el: b, look: b.classList.contains('t-fire') });
        b.classList.add('down');
        this.input.virtualDown(code);
      }, opts);
    }
    el.querySelector('.t-pause').addEventListener('pointerdown', (e) => { e.preventDefault(); this.game.pause(); });
    el.querySelector('.t-full').addEventListener('pointerdown', (e) => { e.preventDefault(); this.toggleFullscreen(); });

    window.addEventListener('pointermove', (e) => this.move(e), opts);
    window.addEventListener('pointerup', (e) => this.end(e));
    window.addEventListener('pointercancel', (e) => this.end(e));
    // Dokunmatik sonrası taklit fare olaylarını ve çift dokunma yakınlaştırmasını engelle
    el.addEventListener('touchstart', (e) => { if (e.cancelable) e.preventDefault(); }, opts);
    el.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  get active() {
    const m = settings.touchMode || 'auto';
    return m === 'on' || (m === 'auto' && this.detected);
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
    if (p.role === 'joy') this.moveJoy(e.clientX, e.clientY);
    else if (p.role === 'look' || p.look) {
      const k = 2.4 * (settings.touchSens || 1);
      this.input.mdx += dx * k;
      this.input.mdy += dy * k;
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
      this.joy.style.left = '';
      this.joy.style.top = '';
    } else if (p.role === 'btn') {
      p.el.classList.remove('down');
      this.input.virtualUp(p.code);
    }
  }

  releaseAll() {
    for (const [id, p] of this.pointers) this.end({ pointerId: id });
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
    const on = this.active && this.game.state === 'playing';
    if (on !== this.visible) {
      this.visible = on;
      this.el.classList.toggle('hidden', !on);
      document.getElementById('app').classList.toggle('touch', this.active);
      if (!on) this.releaseAll();
    }
    document.getElementById('app').classList.toggle('touch', this.active);
    if (on) {
      const portrait = window.innerHeight > window.innerWidth;
      this.rotate.classList.toggle('hidden', !portrait);
      const cur = this.game.weapons.cur;
      const btns = this.el.querySelectorAll('.t-top [data-code^="Digit"]');
      btns.forEach((b, i) => b.classList.toggle('cur', i === cur));
      const alt = this.el.querySelector('.t-alt span');
      const v = this.game.weapons.varId;
      const label = v === 'piercer' ? 'ŞARJ' : v === 'marksman' ? 'PARA' : v === 'core' ? 'ÇEKİRDEK' : v === 'pump' ? 'POMPA' : 'ALT';
      if (alt.textContent !== label) alt.textContent = label;
      const slide = this.el.querySelector('.t-slide span');
      const sl = this.game.player.grounded ? 'KAY' : 'ÇAK';
      if (slide.textContent !== sl) slide.textContent = sl;
    }
  }
}
