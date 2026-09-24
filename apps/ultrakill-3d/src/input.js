// Klavye/fare girişi ve pointer lock yönetimi.
// Ctrl yerine C kullanılır: tarayıcıda Ctrl+W sekmeyi kapatabilir.
export const KEYS = {
  forward: ['KeyW'],
  back: ['KeyS'],
  left: ['KeyA'],
  right: ['KeyD'],
  jump: ['Space'],
  dash: ['ShiftLeft', 'ShiftRight'],
  slide: ['KeyC'],
  punch: ['KeyF'],
  fire: ['Mouse0'],
  alt: ['Mouse2'],
  w1: ['Digit1'],
  w2: ['Digit2'],
  w3: ['Digit3'],
  lastWeapon: ['KeyQ'],
  restart: ['KeyR'],
  stats: ['Tab'],
  lookUp: ['ArrowUp'],
  lookDown: ['ArrowDown'],
  lookLeft: ['ArrowLeft'],
  lookRight: ['ArrowRight'],
};

const PREVENT = new Set(['Space', 'Tab', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'KeyC', 'KeyF', 'KeyQ', 'KeyR', 'Digit1', 'Digit2', 'Digit3', 'ShiftLeft', 'ShiftRight']);

export class Input {
  constructor(canvas) {
    this.canvas = canvas;
    this.down = new Set();
    this.pressedSet = new Set();
    this.releasedSet = new Set();
    this.mdx = 0;
    this.mdy = 0;
    this.wheel = 0;
    this.axisX = 0; // dokunmatik joystick (-1..1)
    this.axisY = 0;
    this.touchMode = false;
    this.lastTouch = -1e9;
    this.locked = false;
    this.lockFailed = false;
    this.everLocked = false;
    this.wantLock = false; // oyun sırasında kilit istenir
    this.gameActive = false;
    this.onLockChange = null;
    this.anyKeyHandlers = [];

    window.addEventListener('keydown', (e) => {
      if (this.gameActive && (PREVENT.has(e.code) || e.ctrlKey)) e.preventDefault();
      if (e.repeat) return;
      this.down.add(e.code);
      this.pressedSet.add(e.code);
      for (const h of this.anyKeyHandlers) h(e);
    });
    window.addEventListener('keyup', (e) => {
      this.down.delete(e.code);
      this.releasedSet.add(e.code);
    });
    window.addEventListener('blur', () => {
      this.down.clear();
    });
    window.addEventListener('touchstart', () => this.markTouch(), { passive: true, capture: true });
    canvas.addEventListener('mousedown', (e) => {
      if (this.fromTouch()) return;
      if (this.gameActive && !this.locked && this.wantLock && !this.lockFailed) this.requestLock();
    });
    window.addEventListener('mousedown', (e) => {
      if (this.fromTouch()) return;
      const code = 'Mouse' + e.button;
      this.down.add(code);
      this.pressedSet.add(code);
    });
    window.addEventListener('mouseup', (e) => {
      if (this.fromTouch()) return;
      const code = 'Mouse' + e.button;
      this.down.delete(code);
      this.releasedSet.add(code);
    });
    window.addEventListener('contextmenu', (e) => { if (this.gameActive) e.preventDefault(); });
    window.addEventListener('mousemove', (e) => {
      if (!this.gameActive || this.touchMode || this.fromTouch()) return;
      if (this.locked || this.lockFailed) {
        // Tarayıcı bazen kilit anında devasa sıçramalar üretir; kırp.
        const mx = Math.max(-300, Math.min(300, e.movementX || 0));
        const my = Math.max(-300, Math.min(300, e.movementY || 0));
        this.mdx += mx;
        this.mdy += my;
      }
    });
    window.addEventListener('wheel', (e) => {
      if (this.gameActive) this.wheel += Math.sign(e.deltaY);
    }, { passive: true });
    document.addEventListener('pointerlockchange', () => {
      this.locked = document.pointerLockElement === this.canvas;
      if (this.locked) this.everLocked = true;
      if (this.onLockChange) this.onLockChange(this.locked);
    });
    document.addEventListener('pointerlockerror', () => this.lockError());
  }

  // Kilit hiç alınamıyorsa (ör. izin verilmeyen çerçeve) serbest fare moduna geç;
  // daha önce alınmışsa geçici hata sayılır ve bir sonraki tıklamada tekrar denenir.
  lockError() {
    if (!this.everLocked) this.lockFailed = true;
    if (this.onLockChange) this.onLockChange(false, true);
  }

  markTouch() {
    this.lastTouch = performance.now();
  }

  // Dokunmatik ekranın ürettiği taklit fare olaylarını ayıkla
  fromTouch() {
    return performance.now() - this.lastTouch < 900;
  }

  virtualDown(code) {
    if (!this.down.has(code)) this.pressedSet.add(code);
    this.down.add(code);
  }

  virtualUp(code) {
    this.down.delete(code);
    this.releasedSet.add(code);
  }

  requestLock() {
    if (this.lockFailed || this.locked || this.touchMode) return;
    try {
      const p = this.canvas.requestPointerLock({ unadjustedMovement: true });
      if (p && p.catch) {
        p.catch(() => {
          try {
            const p2 = this.canvas.requestPointerLock();
            if (p2 && p2.catch) p2.catch(() => this.lockError());
          } catch (err) { this.lockError(); }
        });
      }
    } catch (e) {
      this.lockError();
    }
  }

  exitLock() {
    if (document.pointerLockElement) document.exitPointerLock();
  }

  is(action) {
    const codes = KEYS[action];
    for (const c of codes) if (this.down.has(c)) return true;
    return false;
  }

  pressed(action) {
    const codes = KEYS[action];
    for (const c of codes) if (this.pressedSet.has(c)) return true;
    return false;
  }

  released(action) {
    const codes = KEYS[action];
    for (const c of codes) if (this.releasedSet.has(c)) return true;
    return false;
  }

  endFrame() {
    this.pressedSet.clear();
    this.releasedSet.clear();
    this.mdx = 0;
    this.mdy = 0;
    this.wheel = 0;
  }
}
