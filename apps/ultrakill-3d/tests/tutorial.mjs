// Tutorial parkur testi: bir "bot" gerçek girişlerle (tuş basışları) her engeli geçmeye çalışır.
// Atılma zıplaması (geniş boşluk), kayma (alçak engel), duvar sıçraması (kuyu), çakış sıçrayışı
// (yüksek çıkıntı), parry eğitmeni ve intro/ölüm ekranı aşamaları.
import { chromium } from 'playwright-core';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const browser = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
const results = [];
const check = (name, ok, info = '') => { results.push(ok); console.log(`${ok ? 'GEÇTİ ' : 'KALDI '} ${name}${info ? ' — ' + info : ''}`); };
await page.goto(pathToFileURL(join(root, 'dist/ultrakill-3d.html')).href);
await page.waitForTimeout(1000);

// Bot yardımcıları sayfaya enjekte edilir
await page.evaluate(() => {
  const g = window.__uk;
  window.bot = {
    g,
    place(x, y, z, yaw = 0) { const p = g.player; p.pos.set(x, y, z); p.vel.set(0, 0, 0); p.yaw = yaw; p.pitch = 0; p.grounded = false; p.coyote = 0; p.dashT = 0; p.slamming = false; p.stamina = 3; for (let i = 0; i < 20; i++) g.step(1 / 60, false); },
    hold(code, on) { if (on) { if (!g.input.down.has(code)) g.input.pressedSet.add(code); g.input.down.add(code); } else g.input.down.delete(code); },
    tap(code) { g.input.pressedSet.add(code); g.input.down.add(code); },
    release(code) { g.input.down.delete(code); },
    step(n = 1) { for (let i = 0; i < n; i++) g.step(1 / 60, false); },
    releaseAll() { g.input.down.clear(); },
  };
});

// Oyunu başlat (intro ile)
await page.evaluate(() => { const g = window.__uk; g.audio.init(); g.startIntro(); });
const intro = await page.evaluate(() => {
  const g = window.__uk; const phases = new Set();
  for (let i = 0; i < 1200 && g.ui.introPhase !== 'done'; i++) { g.step(0.05, false); phases.add(g.ui.introPhase); }
  return { phases: [...phases], big: document.querySelectorAll('.intro-big .big-line').length, lines: document.querySelectorAll('#scr-intro .term .tl').length };
});
check('intro: terminal → büyük yazılar → devam istemi', intro.phases.includes('boot') && intro.phases.includes('big') && intro.big === 3 && intro.lines >= 12, JSON.stringify(intro));
await page.evaluate(() => { window.__uk.ui.introClick(); window.bot.step(180); });
check('bölüm tutorial odasında başladı', await page.evaluate(() => window.__uk.state === 'playing' && window.__uk.player.pos.z > 99 && window.__uk.player.grounded));

// 1) Atılma zıplaması: z=95.5'ten koş, kenarda atıl + zıpla, z<81'e in
const dj = await page.evaluate(() => {
  const b = window.bot, p = b.g.player;
  b.place(0, 0, 97, 0);
  b.hold('KeyW', true);
  for (let i = 0; i < 200 && p.pos.z > 94.8; i++) b.step();
  b.tap('ShiftLeft'); b.step(2); b.tap('Space'); b.step(1);
  b.release('ShiftLeft'); b.release('Space');
  for (let i = 0; i < 120 && !(p.grounded && p.pos.z < 94); i++) b.step();
  b.releaseAll(); b.step(5);
  return { z: +p.pos.z.toFixed(2), y: +p.pos.y.toFixed(2), grounded: p.grounded };
});
check('atılma zıplamasıyla boşluk geçildi', dj.grounded && dj.z < 81 && dj.y > -0.1, JSON.stringify(dj));
const plain = await page.evaluate(() => {
  const b = window.bot, p = b.g.player;
  b.place(0, 0, 97, 0);
  b.hold('KeyW', true);
  for (let i = 0; i < 200 && p.pos.z > 94.3; i++) b.step();
  b.tap('Space'); b.step(1); b.release('Space');
  for (let i = 0; i < 150 && !p.grounded; i++) b.step();
  b.releaseAll(); b.step(5);
  return { z: +p.pos.z.toFixed(2), respawned: p.pos.z > 93 };
});
check('normal zıplama boşluğu geçemez (ders zorunlu)', plain.respawned, JSON.stringify(plain));

// 2) Kayma: alçak engelin altından geç
const sl = await page.evaluate(() => {
  const b = window.bot, p = b.g.player;
  b.place(0, 0, 74, 0);
  b.hold('KeyW', true); b.step(15);
  b.hold('KeyC', true);
  for (let i = 0; i < 90 && p.pos.z > 64; i++) b.step();
  b.releaseAll(); b.step(20);
  const passed = p.pos.z < 65.5;
  // kaymadan geçilemez
  b.place(0, 0, 70, 0); b.hold('KeyW', true); b.step(90); b.releaseAll();
  return { passed, blockedZ: +p.pos.z.toFixed(2) };
});
check('kayarak alçak engel geçildi', sl.passed, JSON.stringify(sl));
check('ayakta engel geçilemez', sl.blockedZ > 67.5);

// 3) Duvar sıçraması: kuyuda iki duvar arasında sekip y=7 çıkıntısına çık
const wj = await page.evaluate(() => {
  const b = window.bot, p = b.g.player, w = b.g.world;
  b.place(0, 0, 50.5, 0);
  let side = 1, maxY = 0, walljumps = 0;
  b.tap('Space'); b.step(1); b.release('Space');
  for (let i = 0; i < 600; i++) {
    b.hold('KeyW', p.pos.y > 6.8);
    b.hold(side > 0 ? 'KeyD' : 'KeyA', true);
    b.hold(side > 0 ? 'KeyA' : 'KeyD', false);
    const wall = w.wallCheck(p, 0.38);
    if (!p.grounded && wall && p.vel.y < 4 && p.wallJumps > 0) {
      b.tap('Space'); b.step(1); b.release('Space'); walljumps++; side = -side; continue;
    }
    if (p.grounded && p.pos.y < 1) { b.tap('Space'); b.step(1); b.release('Space'); continue; }
    b.step(1);
    maxY = Math.max(maxY, p.pos.y);
    if (p.grounded && p.pos.y > 6.9) break;
  }
  b.releaseAll(); b.step(5);
  return { y: +p.pos.y.toFixed(2), z: +p.pos.z.toFixed(2), maxY: +maxY.toFixed(2), walljumps, grounded: p.grounded };
});
check('duvar sıçramasıyla kuyudan çıkıldı (çıkıntıya ya da sonraki odaya geçti)', wj.maxY > 7 && wj.walljumps >= 1 && wj.z < 48, JSON.stringify(wj));

// 4) Çakış sıçrayışı: çıkıntıdan çakma odasına düş, yere çak, hemen zıpla → y=6.5 çıkıntısı
const sj = await page.evaluate(() => {
  const b = window.bot, p = b.g.player;
  b.place(0, 7, 44.6, 0);
  b.hold('KeyW', true); b.step(20);
  b.release('KeyW');
  for (let i = 0; i < 60 && p.pos.y > 5; i++) b.step();
  b.tap('KeyC'); b.step(1); b.release('KeyC');
  for (let i = 0; i < 60 && !p.grounded; i++) b.step();
  const slamLand = p.slamLandT < 0.1;
  b.tap('Space'); b.step(1); b.release('Space');
  const vy = p.vel.y;
  b.hold('KeyW', true);
  for (let i = 0; i < 180; i++) { b.step(); if (p.grounded && p.pos.y > 6) break; }
  b.releaseAll(); b.step(5);
  return { slamLand, vy: +vy.toFixed(1), y: +p.pos.y.toFixed(2), z: +p.pos.z.toFixed(2) };
});
check('çakış sıçrayışıyla yüksek çıkıntıya çıkıldı', sj.slamLand && sj.vy > 20 && sj.y > 6.4 && sj.z < 30.5, JSON.stringify(sj));

// 5) Parry eğitmeni: küreyi yumrukla, eğitmen ölür, arena 2 kapısı açılır
const tr = await page.evaluate(() => {
  const b = window.bot, g = b.g, p = g.player;
  g.god = true;
  b.place(0, 0, -36.5, 0);
  const t = g.enemies.find((e) => e.type === 'trainer');
  const closed = g.level.doors.d2in.target === 0;
  let parried = false;
  for (let i = 0; i < 900 && !t.dead; i++) {
    const c = t.center(); const eye = p.eyePos();
    p.yaw = Math.atan2(-(c.x - eye.x), -(c.z - eye.z)); p.pitch = Math.atan2(c.y - eye.y, Math.hypot(c.x - eye.x, c.z - eye.z));
    const orb = g.projectiles.find((x) => x.owner === 'enemy' && !x.dead && x.pos.distanceTo(eye) < 2.6);
    if (orb && g.weapons.punchCd <= 0) { g.weapons.punch(); parried = true; }
    b.step();
  }
  b.step(90);
  return { closed, parried, dead: t.dead, door: +g.level.doors.d2in.t.toFixed(2), kills: g.stats.kills };
});
check('parry eğitmeni: küre savuşturuldu, eğitmen öldü, kapı açıldı', tr.closed && tr.parried && tr.dead && tr.door > 0.5 && tr.kills === 0, JSON.stringify(tr));

// 6) Ölüm ekranı aşamaları
const ds = await page.evaluate(() => {
  const g = window.__uk; g.god = false;
  g.damagePlayer(999, null, true);
  const stages = new Set();
  for (let i = 0; i < 300; i++) { g.step(1 / 60, false); stages.add(g.hud.deathStage); }
  const title = !document.querySelector('#deathscreen .ds-title').classList.contains('hidden');
  const lines = document.querySelectorAll('#deathscreen .ds-term .tl').length;
  const gray = g.renderer.postMat.uniforms.uGray.value;
  g.input.pressedSet.add('KeyR'); g.step(1 / 60, false);
  return { stages: [...stages], title, lines, gray: +gray.toFixed(2), state: g.state, postReset: g.renderer.postMat.uniforms.uGray.value };
});
check('ölüm ekranı: karartma → terminal → ÖLDÜN → istem → yeniden doğuş', ds.stages.includes(3) && ds.title && ds.lines === 5 && ds.gray > 0.5 && ds.state === 'playing' && ds.postReset === 0, JSON.stringify(ds));

check('sayfa hatası yok', errors.length === 0, errors.join(' | '));
await browser.close();
console.log(`\n${results.filter(Boolean).length}/${results.length} tutorial kontrolü geçti.`);
process.exit(results.every(Boolean) ? 0 : 1);
