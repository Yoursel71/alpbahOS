// Duman testi: dist/ultrakill-3d.html'i headless Chromium'da açar, menü → bölüm akışını
// ve temel oyun mantığını (hareket, silahlar, parry, stil, arena, boss, sonuç) otomatik sınar.
// Kullanım: CHROME=/yol/chrome node tests/smoke.mjs
import { chromium } from 'playwright-core';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'tests/out');
mkdirSync(out, { recursive: true });
const exe = process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';

const browser = await chromium.launch({
  executablePath: exe,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
// Yazı tipi (Google Fonts) isteği sandbox'ta sertifika hatası verebilir; oyun hatası sayılmaz.
page.on('console', (m) => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) errors.push('console: ' + m.text()); });

const results = [];
const check = (name, ok, info = '') => { results.push({ name, ok, info }); console.log(`${ok ? 'GEÇTİ ' : 'KALDI '} ${name}${info ? ' — ' + info : ''}`); };
const shot = (n) => page.screenshot({ path: join(out, n + '.png') });
const wait = (ms) => page.waitForTimeout(ms);
// Oyun saatini deterministik ilerlet (headless'ta rAF yavaş olabilir)
const sim = (sec, step = 1 / 60) => page.evaluate(([sec, step]) => { const g = window.__uk; for (let t = 0; t < sec; t += step) g.step(step, false); }, [sec, step]);

await page.goto(pathToFileURL(join(root, 'dist/ultrakill-3d.html')).href);
await wait(1500);
check('oyun nesnesi oluştu', await page.evaluate(() => !!window.__uk));
await shot('01-splash');

await page.mouse.click(640, 360);
await wait(600);
check('ana menü açıldı', await page.evaluate(() => window.__uk.state === 'menu'));
await shot('02-menu');

// İntro
await page.evaluate(() => window.__uk.startIntro());
await wait(2500);
await shot('03-intro');
const fpsMenu = await page.evaluate(() => window.__uk.fps);
console.log('menü/intro FPS (headless yazılım GL):', fpsMenu);
check('intro tamamlandı', await page.evaluate(() => {
  const g = window.__uk; g.ui.introFast = true;
  for (let i = 0; i < 800 && !g.ui.introDone; i++) g.step(0.05, false);
  return g.ui.introDone;
}));

// Bölümü başlat
await page.evaluate(() => { window.__uk.ui.introClick(); });
await wait(300);
check('bölüm başladı', await page.evaluate(() => window.__uk.state === 'playing'));
await sim(0.4);
await shot('04-falling');
await sim(3.0);
const landed = await page.evaluate(() => ({ y: window.__uk.player.pos.y, z: window.__uk.player.pos.z, g: window.__uk.player.grounded, armed: window.__uk.weapons.armed }));
check('oyuncu tutorial odasına silahsız indi', landed.g && Math.abs(landed.y) < 0.2 && landed.z > 99 && !landed.armed, JSON.stringify(landed));
check('parry eğitmeni kafeste bekliyor', await page.evaluate(() => window.__uk.enemies.some((e) => e.type === 'trainer')));
// Revolver sunağına git → silah alınır, arena kapısı açılır
const alt = await page.evaluate(() => {
  const g = window.__uk, p = g.player;
  p.pos.set(0, 6.5, 24.9); p.vel.set(0, 0, 0);
  for (let i = 0; i < 330; i++) g.step(1 / 60, false);
  return { armed: g.weapons.armed, cur: g.weapons.cur, door: g.level.doors.dT.t, cp: g.checkpoint.pos.z };
});
check('revolver sunaktan alındı, arena kapısı açıldı', alt.armed && alt.cur === 0 && alt.door > 0.9 && Math.abs(alt.cp - 22) < 0.1, JSON.stringify(alt));
// diğer silahları test için ver
await page.evaluate(() => { const g = window.__uk; g.weapons.giveAll(); g.weapons.select(0); g.player.pos.set(0, 0, 5); for (let i = 0; i < 30; i++) g.step(1 / 60, false); });
await sim(1.5);
const a1 = await page.evaluate(() => ({ state: window.__uk.level.arenas[0].state, n: window.__uk.enemies.filter((e) => e.type !== 'trainer').length, door: window.__uk.level.doors.dT.target }));
check('arena 1 başladı, tutorial kapısı kilitlendi, düşman doğdu', a1.state === 'active' && a1.n >= 3 && a1.door === 0, JSON.stringify(a1));
await shot('05-arena1');

// Hareket: dash, kayma, zıplama
const mv = await page.evaluate(() => {
  const g = window.__uk, p = g.player, inp = g.input;
  g.god = true;
  const x0 = p.pos.clone();
  inp.down.add('KeyW');
  for (let i = 0; i < 30; i++) g.step(1 / 60, false);
  const walked = p.pos.distanceTo(x0);
  inp.pressedSet.add('ShiftLeft');
  const s0 = p.stamina;
  g.step(1 / 60, false);
  const dashing = p.dashT > 0 && p.iframes > 0;
  for (let i = 0; i < 20; i++) g.step(1 / 60, false);
  inp.down.delete('KeyW');
  inp.pressedSet.add('Space');
  g.step(1 / 60, false);
  const jumpVel = p.vel.y;
  for (let i = 0; i < 90; i++) g.step(1 / 60, false);
  // kayma
  inp.down.add('KeyC'); inp.pressedSet.add('KeyC');
  g.step(1 / 60, false); g.step(1 / 60, false);
  const sliding = p.sliding && p.h < 1;
  inp.down.delete('KeyC');
  for (let i = 0; i < 10; i++) g.step(1 / 60, false);
  // yere çakma
  p.pos.set(0, 8, 4); p.vel.set(0, 0, 0); p.grounded = false; p.coyote = 0;
  g.step(1 / 60, false);
  inp.pressedSet.add('KeyC'); inp.down.add('KeyC');
  g.step(1 / 60, false);
  const slamming = p.slamming;
  inp.down.delete('KeyC');
  for (let i = 0; i < 30 && !p.grounded; i++) g.step(1 / 60, false);
  inp.pressedSet.add('Space');
  g.step(1 / 60, false);
  const slamJump = p.vel.y;
  return { walked, dashing, stamina: s0 - p.stamina, jumpVel, sliding, slamming, slamJump };
});
check('yürüme', mv.walked > 3, mv.walked.toFixed(2));
check('dash (i-frame)', mv.dashing, JSON.stringify(mv));
check('zıplama', mv.jumpVel > 10);
check('kayma', mv.sliding);
check('yere çakma + çakış sıçrayışı', mv.slamming && mv.slamJump > 17, 'vy=' + mv.slamJump.toFixed(1));

// Silahlar: revolver ile düşmanı vur
const aimAt = (e) => `
  { const eye = window.__uk.player.eyePos(); const c = ${e}.center();
  const dx = c.x - eye.x, dy = c.y - eye.y, dz = c.z - eye.z;
  window.__uk.player.yaw = Math.atan2(-dx, -dz); window.__uk.player.pitch = Math.atan2(dy, Math.hypot(dx, dz)); }`;
const shoot = await page.evaluate(`(() => {
  const g = window.__uk; const p = g.player;
  for (let i = 0; i < 60; i++) g.step(1/60, false);
  const e = g.enemies.find(x => !x.dead && x.state !== 'spawn' && x.type !== 'trainer');
  if (!e) return { err: 'düşman yok' };
  for (const x of g.enemies) if (x !== e) x.removeSilently();
  p.pos.set(e.pos.x, 0, e.pos.z + 6); p.vel.set(0,0,0);
  g.step(1/60, false);
  ${aimAt('e')}
  const hp0 = e.hp; const kills0 = g.stats.kills; const style0 = g.style.total;
  g.weapons.cd[0] = 0; g.weapons.switchT = 1;
  g.input.pressedSet.add('Mouse0'); g.input.down.add('Mouse0');
  g.step(1/60, false);
  g.input.down.delete('Mouse0');
  for (let i = 0; i < 10; i++) g.step(1/60, false);
  return { hit: e.hp < hp0 || e.dead, dead: e.dead, kills: g.stats.kills - kills0, style: g.style.total - style0, rank: g.style.rank };
})()`);
check('revolver isabet', shoot.hit, JSON.stringify(shoot));
check('öldürme sayıldı + stil puanı', shoot.kills >= 1 && shoot.style > 0);
await shot('06-shoot');

// Shotgun + railcannon
const guns = await page.evaluate(`(() => {
  const g = window.__uk, p = g.player, w = g.weapons;
  const r = {};
  w.select(1); for (let i = 0; i < 20; i++) g.step(1/60, false);
  let e = g.enemies.find(x => !x.dead && x.state !== 'spawn' && x.type !== 'trainer');
  if (!e) { e = g.spawnEnemy('schism', [-4, 0, -8], null); for (let i = 0; i < 50; i++) g.step(1/60, false); e.state = 'idle'; }
  if (e) {
    p.pos.set(e.pos.x, e.pos.y, e.pos.z + 3); g.step(1/60, false);
    ${aimAt('e')}
    const hp0 = e.hp; w.cd[1] = 0;
    g.input.pressedSet.add('Mouse0'); g.input.down.add('Mouse0'); g.step(1/60, false); g.input.down.delete('Mouse0');
    r.shotgun = e.dead || e.hp < hp0;
  }
  w.select(3); for (let i = 0; i < 20; i++) g.step(1/60, false);
  e = g.enemies.find(x => !x.dead && x.state !== 'spawn' && x.type !== 'trainer');
  if (!e) { e = g.spawnEnemy('schism', [4, 0, -8], null); for (let i = 0; i < 50; i++) g.step(1/60, false); e.state = 'idle'; }
  if (e) {
    const tc = new e.pos.constructor(-e.pos.x, 0, -2 - e.pos.z).normalize();
    p.pos.set(e.pos.x + tc.x * 7, e.pos.y, e.pos.z + tc.z * 7); g.step(1/60, false);
    ${aimAt('e')}
    w.railCharge = 1;
    const hp0 = e.hp;
    const hs = g.hitscan(p.eyePos(), p.aimDir(), 500, {});
    r.dbg = { type: e.type, st: e.state, epos: e.pos.toArray().map(v => +v.toFixed(2)), ppos: p.pos.toArray().map(v => +v.toFixed(2)), hits: hs.hits.length, world: hs.world && +hs.world.t.toFixed(2), hitstop: g.hitstopT, sw: w.switchT, cur: w.cur };
    g.input.pressedSet.add('Mouse0'); g.step(1/60, false);
    r.rail = e.dead || e.hp < hp0; r.railCharge = w.railCharge;
  }
  w.select(0);
  return r;
})()`);
check('shotgun isabet', guns.shotgun === true, JSON.stringify(guns));
check('railcannon isabet + şarj sıfırlandı', guns.rail === true && guns.railCharge < 0.1, JSON.stringify(guns));

// Nailgun + Rocket Launcher + üçüncü varyantlar
const more = await page.evaluate(`(() => {
  const g = window.__uk, p = g.player, w = g.weapons, inp = g.input;
  const r = {};
  // hedef dışındaki düşmanlar atışları kesmesin; bu sırada arena dalgası beklesin
  for (const a of g.level.arenas) if (a.state === 'active') a.delay = 1e9;
  const target = (z = -8) => {
    for (const x of g.enemies) if (!x.dead && x.type !== 'trainer') x.removeSilently();
    const e = g.spawnEnemy('schism', [0, 0, z], null); e.state = 'idle'; e.decor = true; e.yaw = 0; for (let i = 0; i < 5; i++) g.step(1/60, false); return e;
  };
  const face = (e, dist) => { const tc = new e.pos.constructor(-e.pos.x, 0, -2 - e.pos.z).normalize(); p.pos.set(e.pos.x + tc.x * dist, e.pos.y, e.pos.z + tc.z * dist); p.vel.set(0,0,0); g.step(1/60, false); ${aimAt('e')} };
  let e = target();
  if (e) {
    w.select(2); for (let i = 0; i < 20; i++) g.step(1/60, false);
    face(e, 6); const hp0 = e.hp;
    inp.down.add('Mouse0'); for (let i = 0; i < 30; i++) { ${aimAt('e')}; g.step(1/60, false); } inp.down.delete('Mouse0');
    r.nail = e.dead || e.hp < hp0;
  }
  e = target(-12.5);
  if (e) {
    w.select(4); for (let i = 0; i < 20; i++) g.step(1/60, false);
    face(e, 10); const hp0 = e.hp;
    for (let k = 0; k < 3 && !(e.dead || e.hp < hp0); k++) {
      w.cd[4] = 0; w.rocketLoadT = 1; ${aimAt('e')}
      inp.pressedSet.add('Mouse0'); inp.down.add('Mouse0'); g.step(1/60, false); inp.down.delete('Mouse0');
      for (let i = 0; i < 40; i++) g.step(1/60, false);
    }
    r.rocket = e.dead || e.hp < hp0;
  }
  // varyantlar sırayla: sharpshooter, sawed-on, sawblade, malicious, cannon
  w.cur = 4; w.variant[0] = 0; w.variant[1] = 0;
  w.select(0); w.select(0); w.select(0); r.v0 = w.varId;
  w.select(1); w.select(1); w.select(1); r.v1 = w.varId;
  r.all = w.owned.every(Boolean) && w.armsOwned.every(Boolean) && w.hookOwned;
  for (const x of g.enemies) if (x.decor) x.removeSilently();
  for (const a of g.level.arenas) if (a.state === 'active') a.delay = 0.3;
  return r;
})()`);
check('nailgun isabet', more.nail === true, JSON.stringify(more));
check('roket isabet (patlama)', more.rocket === true);
check('üçüncü varyantlar (SHARPSHOOTER, SAWED-ON) seçilebiliyor', more.v0 === 'sharpshooter' && more.v1 === 'saw');
check('tüm silahlar/kollar/kanca verildi', more.all === true);

// Parry: Stray küresini yumrukla geri gönder
const parry = await page.evaluate(`(() => {
  const g = window.__uk, p = g.player;
  const Proj = g.projectiles.constructor;
  // Test mermisi: oyuncuya doğru gelen küre
  const eye = p.eyePos();
  const fwd = p.aimDir();
  const pos = eye.clone().addScaledVector(fwd, 3);
  const P = window.__ukProjectile;
  const pr = new P(g, { pos, vel: fwd.clone().multiplyScalar(-20), radius: 0.35, damage: 25 });
  g.addProjectile(pr);
  p.hp = 40;
  const parries0 = g.stats.parries;
  g.weapons.punchCd = 0;
  g.input.pressedSet.add('KeyF');
  g.step(1/60, false);
  for (let i = 0; i < 20; i++) g.step(1/60, false);
  return { owner: pr.owner, parried: pr.parried, hp: p.hp, parries: g.stats.parries - parries0 };
})()`);
check('mermi parry (sahip değişti, can doldu)', parry.parried && parry.owner === 'player' && parry.hp >= 99, JSON.stringify(parry));

// Arena 1'i temizle → kapı açılmalı
const clear1 = await page.evaluate(() => {
  const g = window.__uk;
  for (let k = 0; k < 20; k++) {
    for (const e of g.enemies) if (!e.dead && e.state !== 'spawn' && e.type !== 'trainer') e.hit({ dmg: 99, part: 'body', point: e.center(), weapon: 'revolver' });
    for (let i = 0; i < 40; i++) g.step(1 / 60, false);
    if (g.level.arenas[0].state === 'cleared') break;
  }
  for (let i = 0; i < 90; i++) g.step(1 / 60, false);
  return { state: g.level.arenas[0].state, door: g.level.doors.d1.t, kills: g.stats.kills };
});
check('arena 1 temizlendi, kapı açıldı', clear1.state === 'cleared' && clear1.door > 0.9, JSON.stringify(clear1));

// Stil rütbesi: çok sayıda bonus → yüksek rütbe
const style = await page.evaluate(() => {
  const g = window.__uk;
  for (let i = 0; i < 12; i++) g.style.add('HEADSHOT', 200, 'revolver');
  g.step(1 / 60, false);
  return { rank: g.style.rank, fresh: g.style.freshness('revolver').name, bonuses: g.style.bonuses.length };
});
check('stil rütbesi yükseldi + tazelik düştü', style.rank >= 3 && style.fresh !== 'FRESH', JSON.stringify(style));
await shot('07-style');

// Koridor + checkpoint + gizli küre 1
const cp = await page.evaluate(() => {
  const g = window.__uk, p = g.player;
  p.pos.set(0, 0, -37.5); p.vel.set(0, 0, 0); p.yaw = 0;
  for (let i = 0; i < 10; i++) g.step(1 / 60, false);
  const cpz = g.checkpoint.pos.z;
  p.pos.set(-6.8, 3.6, -35.5);
  for (let i = 0; i < 10; i++) g.step(1 / 60, false);
  return { cpz, secrets: g.stats.secrets };
});
check('checkpoint alındı', Math.abs(cp.cpz + 38) < 0.1, JSON.stringify(cp));
check('gizli küre toplandı', cp.secrets === 1);

// Ölüm ve checkpoint'ten dönüş
const death = await page.evaluate(() => {
  const g = window.__uk, p = g.player;
  g.god = false;
  g.damagePlayer(500, null, true);
  const dead = g.state === 'dead';
  for (let i = 0; i < 75; i++) g.step(1 / 60, false);
  g.input.pressedSet.add('KeyR');
  g.step(1 / 60, false);
  return { dead, state: g.state, z: p.pos.z, restarts: g.stats.restarts, hp: p.hp };
});
check('ölüm ve checkpoint dönüşü', death.dead && death.state === 'playing' && Math.abs(death.z + 38) < 0.5 && death.hp === 100, JSON.stringify(death));
await page.evaluate(() => { window.__uk.god = true; });

// Arena 2 → Stray davranışı
const a2 = await page.evaluate(() => {
  const g = window.__uk, p = g.player;
  p.pos.set(0, 0, -43.5); p.vel.set(0, 0, 0);
  for (let i = 0; i < 180; i++) g.step(1 / 60, false);
  const strays = g.enemies.filter((e) => e.type === 'stray');
  // salonun ortasına geç: balkon korkulukları görüşü kesmesin
  p.pos.set(0, 2, -60); p.vel.set(0, 0, 0);
  let thrown = 0;
  for (let i = 0; i < 600 && !thrown; i++) { g.step(1 / 60, false); thrown = Math.max(thrown, g.projectiles.filter((x) => x.owner === 'enemy').length); }
  return { state: g.level.arenas[1].state, door: g.level.doors.d2in.target, strays: strays.length, thrown };
});
check('arena 2 kilitlendi, Stray doğdu', a2.state === 'active' && a2.door === 0 && a2.strays >= 2, JSON.stringify(a2));
check('Stray küre fırlattı', a2.thrown > 0);
await shot('08-arena2');

// Schism + melee parry
const sch = await page.evaluate(() => {
  const g = window.__uk, p = g.player;
  const e = g.spawnEnemy('schism', [0, 0, -60], null);
  // diğer düşmanlar bu sırada saldırmasın (en yakın parlayan saldırı onlarınki olmasın)
  for (const x of g.enemies) if (x !== e && !x.dead && x.state !== 'spawn') { x.stun = 6; x.setState('stagger'); }
  for (let i = 0; i < 60; i++) g.step(1 / 60, false);
  p.pos.set(0, 0, -57.6);
  e.atkCd = 99; e.meleeCd = 0;
  let parryable = false;
  for (let i = 0; i < 120 && !parryable; i++) { g.step(1 / 60, false); parryable = e.parryable; }
  const c = e.center(); const eye = p.eyePos();
  p.yaw = Math.atan2(-(c.x - eye.x), -(c.z - eye.z)); p.pitch = Math.atan2(c.y - eye.y, Math.hypot(c.x - eye.x, c.z - eye.z));
  const hp0 = e.hp;
  g.weapons.punchCd = 0; g.weapons.arm = 0; // Feedbacker
  for (const x of g.projectiles) if (x.owner === 'enemy') x.remove(); // yakındaki Stray küreleri parry'yi çalmasın
  g.input.pressedSet.add('KeyF');
  g.step(1 / 60, false);
  return { parryable, state: e.state, dmg: hp0 - e.hp, dead: e.dead };
});
check('Schism yakın saldırısı savuşturuldu', sch.parryable && (sch.state === 'stagger' || sch.dead) && sch.dmg > 0, JSON.stringify(sch));
await page.evaluate(() => { const g = window.__uk; for (const e of g.enemies) e.hit({ dmg: 99, part: 'body', point: e.center(), weapon: 'revolver' }); for (let i = 0; i < 10; i++) g.step(1 / 60, false); });

// Boss: doğrudan boss arenasına ışınlan
const boss = await page.evaluate(() => {
  const g = window.__uk, p = g.player;
  for (const a of g.level.arenas) if (a.id !== 'boss') { for (const e of a.enemies) e.removeSilently(); a.enemies = []; a.state = 'cleared'; }
  g.enemies = g.enemies.filter((e) => !e.dead);
  p.pos.set(0, 0, -175); p.vel.set(0, 0, 0);
  for (let i = 0; i < 240; i++) g.step(1 / 60, false);
  const b = g.enemies.find((e) => e.type === 'swordsmachine');
  const states = new Set();
  for (let i = 0; i < 600; i++) { g.step(1 / 60, false); if (b) states.add(b.state); }
  return { spawned: !!b, states: [...states], bossBar: !document.querySelector('#bossbar').classList.contains('hidden') };
});
check('Swordsmachine doğdu, boss barı görünüyor', boss.spawned && boss.bossBar, JSON.stringify(boss));
check('boss birden çok saldırı durumu kullandı', boss.states.length >= 3);
await shot('09-boss');

const bossKill = await page.evaluate(() => {
  const g = window.__uk, p = g.player;
  const b = g.enemies.find((e) => e.type === 'swordsmachine');
  b.hit({ dmg: 25, part: 'body', point: b.center(), weapon: 'rail' });
  for (let i = 0; i < 100; i++) g.step(1 / 60, false);
  const enraged = b.enraged || b.state === 'enrage';
  for (let i = 0; i < 60; i++) g.step(1 / 60, false);
  b.hit({ dmg: 99, part: 'head', point: b.center(), weapon: 'rail' });
  for (let i = 0; i < 200; i++) g.step(1 / 60, false);
  return { enraged, dead: b.dead, hatch: g.level.doors.hatch.target };
});
check('boss öfkelendi (2. faz) ve öldü, çıkış açıldı', bossKill.enraged && bossKill.dead && bossKill.hatch === 1, JSON.stringify(bossKill));

// Çıkış deliği → sonuç ekranı
const fin = await page.evaluate(() => {
  const g = window.__uk, p = g.player;
  for (let i = 0; i < 120; i++) g.step(1 / 60, false);
  p.pos.set(0, 1, -193); p.vel.set(0, 0, 0);
  for (let i = 0; i < 120 && g.state === 'playing'; i++) g.step(1 / 60, false);
  return { state: g.state, r: g.lastResults };
});
check('bölüm tamamlandı → sıralama ekranı', fin.state === 'results' && !!fin.r, JSON.stringify(fin.r));
await wait(5000);
await shot('10-results');

// Pause menüsü
await page.evaluate(() => { const g = window.__uk; g.startLevel(); for (let i = 0; i < 30; i++) g.step(1 / 60, false); g.pause(); });
await wait(300);
check('duraklatma menüsü', await page.evaluate(() => window.__uk.state === 'paused'));
await shot('11-pause');

check('konsol/sayfa hatası yok', errors.length === 0, errors.slice(0, 5).join(' | '));
await browser.close();
const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} kontrol geçti. Ekran görüntüleri: tests/out/`);
process.exit(failed.length ? 1 : 0);
