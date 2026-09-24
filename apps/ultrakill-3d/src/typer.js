// Terminal daktilo efekti: satırları harf harf yazar, durum etiketleri (ör. [TAMAM]) ve
// ilerleme çubukları gösterir. Intro ve ölüm ekranı ortak kullanır.
const esc = (s) => String(s).replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

export class Typer {
  // lines: [{ a, b?, cls?, cps?, pause?, sound?, bar?, barDur? }]
  constructor(el, lines, opts = {}) {
    this.el = el;
    this.lines = lines;
    this.audio = opts.audio || null;
    this.i = 0;
    this.c = 0;
    this.t = 0;
    this.barT = -1;
    this.done = lines.length === 0;
    el.innerHTML = '';
  }

  update(dt, fast = false) {
    if (this.done) return true;
    this.t += dt * (fast ? 14 : 1);
    let guard = 0;
    while (this.t > 0 && !this.done && guard++ < 400) {
      const L = this.lines[this.i];
      const a = L.a || '', b = L.b || '';
      const text = a + b;
      if (this.c === 0 && this.barT < 0) {
        this.div = document.createElement('div');
        this.div.className = 'tl ' + (L.cls || '');
        this.el.appendChild(this.div);
        this.el.scrollTop = this.el.scrollHeight;
      }
      if (this.c < text.length) {
        this.c++;
        const shown = text.slice(0, this.c);
        if (this.c <= a.length) this.div.innerHTML = esc(shown) + '<span class="cur">█</span>';
        else this.div.innerHTML = esc(a) + `<span class="st">${esc(shown.slice(a.length))}</span>`;
        this.t -= 1 / (L.cps || 85);
        if (this.audio && this.c % 3 === 0) this.audio.play('type', null, { force: true });
        if (b && this.c === text.length && this.audio) this.audio.play(L.sound || 'beep', null, { force: true });
        continue;
      }
      if (L.bar) {
        // ilerleme çubuğu
        if (this.barT < 0) this.barT = 0;
        const need = L.barDur || 0.8;
        const step = Math.min(this.t, need - this.barT);
        this.barT += step;
        this.t -= step;
        const k = Math.min(1, this.barT / need);
        const n = 20, f = Math.round(k * n);
        this.div.innerHTML = esc(a) + `<span class="bar">[${'█'.repeat(f)}${'&nbsp;'.repeat(n - f)}]</span> <span class="st">${Math.round(k * 100)}%</span>`;
        if (this.barT < need) break;
        this.barT = -1;
      } else if (this.div && this.c === text.length) {
        this.div.innerHTML = this.div.innerHTML.replace('<span class="cur">█</span>', '');
      }
      this.i++;
      this.c = 0;
      this.t -= L.pause ?? (text.length ? 0.14 : 0.08);
      if (this.i >= this.lines.length) this.done = true;
    }
    return this.done;
  }

  finish() {
    while (!this.done) this.update(10, true);
  }
}

// Ekran karlanması (statik gürültü) — küçük bir tuvale çizilir, CSS ile büyütülür
export function drawNoise(canvas, amount = 1) {
  const ctx = canvas.getContext('2d');
  const w = canvas.width, h = canvas.height;
  const img = ctx.createImageData(w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const v = Math.random() * 255 * amount;
    d[i] = d[i + 1] = d[i + 2] = v;
    d[i + 3] = 255;
  }
  // yatay bozulma çizgileri
  if (Math.random() < 0.3) {
    const y = Math.floor(Math.random() * h);
    for (let x = 0; x < w; x++) { const k = (y * w + x) * 4; d[k] = d[k + 1] = d[k + 2] = 255; }
  }
  ctx.putImageData(img, 0, 0);
}
