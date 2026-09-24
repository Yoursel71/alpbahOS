// KATMAN 1 (ARAF) ve "en büyük güncelleme" testi: 1-1 → 1-4, yeni düşmanlar (Drone, Streetcleaner,
// Hideous Mass, V2), Siber Öğütücü (sonsuz dalga), oynanabilir V2, Slab Revolver / Jackhammer,
// parry ve para yardımı, yeni kol animasyonları, ASCII görünümün yalnız menü/introda olması.
// Kullanım: CHROME=/yol/chrome node tests/araf.mjs
import { chromium } from 'playwright-core';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const browser = await chromium.launch({
  executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'],
});
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
const results = [];
const check = (name, ok, info = '') => { results.push(ok); console.log(`${ok ? 'GEÇTİ ' : 'KALDI '} ${name}${info ? ' — ' + info : ''}`); };
await page.goto(pathToFileURL(join(root, 'dist/ultrakill-3d.html')).href);
await page.waitForTimeout(1000);
await page.evaluate(() => {
  const g = window.__uk;
  g.audio.init();
  window.T = {
    g,
    step(n = 1) { for (let i = 0; i < n; i++) g.step(1 / 60, false); },
    look(x, y, z) { const p = g.player, e = p.eyePos(); const dx = x - e.x, dy = y - e.y, dz = z - e.z; p.yaw = Math.atan2(-dx, -dz); p.pitch = Math.atan2(dy, Math.hypot(dx, dz)); },
    place(x, y, z) { const p = g.player; p.pos.set(x, y, z); p.vel.set(0, 0, 0); p.lastSafe && p.lastSafe.set(x, y, z); },
    clear() { for (const e of g.enemies) e.removeSilently(); g.enemies = []; for (const pr of g.projectiles) pr.remove(); g.projectiles = []; },
  };
});

// 1) Menü: katman başlıkları, Siber Öğütücü kartı, karakter seçimi; ASCII yalnız menüde
const menu = await page.evaluate(() => {
  const g = window.__uk; g.onSplashClick();
  g.step(1 / 60, false);
  const ascMenu = g.renderer.postMat.uniforms.uAscii.value;
  const layers = [...document.querySelectorAll('.lv-layer')].map((e) => e.textContent);
  const cg = !!document.querySelector('.lv-card.endless');
  const v2 = document.querySelector('.btn.char[data-c="v2"]');
  g.startLevel(0); g.step(1 / 60, false);
  const ascPlay = g.renderer.postMat.uniforms.uAscii.value;
  return { layers, cg, v2Locked: !!v2 && v2.disabled, ascMenu, ascPlay };
});
check('menü: 3 katman başlığı, Siber Öğütücü kartı, V2 kilitli karakter', menu.layers.length === 3 && menu.cg && menu.v2Locked, JSON.stringify(menu));
check('ASCII terminal görünümü yalnız menüde, oyun içinde kapalı', menu.ascMenu > 0 && menu.ascPlay === 0, JSON.stringify(menu));

// 2) ARAF bölümleri: iniş, doğma noktaları, arenalar, çıkış → sonuç
await page.evaluate(() => { window.__ukProgress.unlocked = 6; });
const EXITS = { 5: [0, 0.1, -119], 6: [0, 0.1, -137], 8: [0, 3.1, -91] };
for (let li = 5; li <= 8; li++) {
  const r = await page.evaluate(([li, ex]) => {
    const { g, step, place } = window.T;
    g.startLevel(li); g.god = true;
    step(240);
    const p = g.player;
    const out = { id: g.levelDef.id, grounded: p.grounded, bad: [], stuck: [], arenas: [] };
    for (const a of g.level.arenas) for (const w of a.waves) for (const s of w) {
      const [x, y, z] = s.p;
      if (g.world.overlapBox(x - 0.35, y + 0.1, z - 0.35, x + 0.35, y + 1.6, z + 0.35)) out.bad.push(`${s.t}@${s.p}`);
    }
    for (const a of g.level.arenas) {
      const b = a.trigger;
      place((b[0] + b[3]) / 2, b[1] + 0.1, (b[2] + b[5]) / 2);
      step(5);
      let guard = 0;
      while (a.state === 'active' && guard++ < 40) {
        step(90);
        for (const e of a.enemies) if (!e.dead && !e.flying && g.world.overlapBody(e)) out.stuck.push(e.type);
        for (const e of [...a.enemies]) if (!e.dead) e.hit({ dmg: 999, part: 'body', point: e.center(), weapon: 'revolver' });
        step(30);
      }
      step(160);
      out.arenas.push(a.state + ':' + a.exits.map((id) => g.level.doors[id].target).join(''));
    }
    const L = g.level;
    if (L.doors.hatch) { L.doors.hatch.open(); step(120); const hb = L.doors.hatch.box; place((hb[0] + hb[3]) / 2, -6, (hb[2] + hb[5]) / 2); } else place(...ex);
    for (let i = 0; i < 200 && g.state === 'playing'; i++) step(1);
    out.state = g.state;
    out.p = g.lastResults ? g.lastResults.pointsEarned : 0;
    out.v2 = !!window.__ukProgress.v2Unlocked;
    out.knuckle = !!window.__ukProgress.shop['arm.knuckle'];
    out.finale = g.lastResults && g.lastResults.finale;
    return out;
  }, [li, EXITS[li] || [0, 0, 0]]);
  const ok = r.grounded && r.bad.length === 0 && r.stuck.length === 0 && r.arenas.every((x) => x.startsWith('cleared')) && r.state === 'results' && r.p > 0 && (li !== 8 || (r.v2 && r.knuckle && /KATMAN 1/.test(r.finale)));
  check(`bölüm ${r.id}: iniş, doğma noktaları, arenalar, çıkış → sonuç${li === 8 ? ', V2 açıldı + Knuckleblaster' : ''}`, ok, JSON.stringify(r));
}

// 3) Drone: iki küre atar; ölünce oyuncuya düşer, yumrukla geri yollanır ve patlar
const dr = await page.evaluate(() => {
  const { g, step, place, look, clear } = window.T;
  g.startLevel(5); g.god = true; step(200); clear();
  place(0, 0, 14); step(2);
  const e = g.spawnEnemy('drone', [0, 4, 2], null); step(60);
  e.atkCd = 0; e.canSee = true; e.setState('charge');
  let orbs = 0;
  for (let i = 0; i < 90; i++) { step(1); orbs = Math.max(orbs, g.projectiles.filter((x) => x.source === e).length); }
  clear();
  const d = g.spawnEnemy('drone', [0, 3, 8], null); step(50);
  const victim = g.spawnEnemy('filth', [0, 0, -2], null); step(50); victim.state = 'idle'; victim.decor = true;
  d.pos.set(0, 3, 10); d.vel.set(0, 0, 0); step(1);
  d.hit({ dmg: 5, part: 'body', point: d.center(), weapon: 'revolver' });
  const body = g.projectiles.find((x) => x.kind === 'drone');
  let near = false;
  for (let i = 0; i < 60 && body && !body.dead; i++) {
    step(1);
    if (body.pos.distanceTo(g.player.eyePos()) < 5) { near = true; break; }
  }
  look(victim.pos.x, victim.pos.y + 1, victim.pos.z);
  const pb = g.stats.droneParries || 0;
  g.weapons.punchCd = 0; g.weapons.punch(); step(1);
  const parried = body && body.owner === 'player' && (g.stats.droneParries || 0) === pb + 1;
  for (let i = 0; i < 120 && body && !body.dead; i++) step(1);
  return { orbs, falling: !!body, near, parried, boom: body && body.dead, victimDead: victim.dead };
});
check('Drone: göz parlayınca iki küre atar', dr.orbs >= 2, JSON.stringify(dr));
check('Drone: ölünce oyuncuya düşer, YUMRUKLA geri yollanır, patlayıp düşmanı öldürür', dr.falling && dr.near && dr.parried && dr.boom && dr.victimDead, JSON.stringify(dr));

// 4) Streetcleaner: yakında alev yakar, uzakta yakmaz; nişan alınca kaçar; tank vurulunca patlar
const sc = await page.evaluate(() => {
  const { g, step, place, look, clear } = window.T;
  clear(); g.god = false;
  place(0, 0, 14); step(2);
  const e = g.spawnEnemy('streetcleaner', [0, 0, 9.5], null); step(50);
  const p = g.player; p.hp = 100; p.hard = 0;
  const hold = () => { e.pos.set(0, 0, 9.5); e.vel.set(0, 0, 0); };
  e.yaw = 0; e.setState('flame');
  for (let i = 0; i < 90; i++) { hold(); e.yaw = Math.PI; p.iframes = 0; step(1); }
  const burned = Math.round(100 - p.hp);
  p.hp = 100; place(0, 0, 25); step(2);
  e.setState('flame');
  for (let i = 0; i < 60; i++) { hold(); e.yaw = Math.PI; p.iframes = 0; step(1); }
  const far = Math.round(100 - p.hp);
  g.god = true;
  // nişan: tam üstüne bakınca yana kaçar
  e.setState('chase'); e.dodgeCd = 0; place(0, 0, 22); step(1);
  look(e.pos.x, e.pos.y + 1, e.pos.z); e.grounded = true;
  const x0 = e.pos.x; let dodged = false;
  for (let i = 0; i < 30; i++) { look(e.center().x, e.center().y, e.center().z); step(1); if (e.state === 'dodge') dodged = true; }
  const moved = +Math.abs(e.pos.x - x0).toFixed(2);
  const t0 = g.stats.tanks || 0;
  e.hit({ dmg: 2, part: 'head', point: e.center(), weapon: 'revolver' });
  step(2);
  return { burned, far, dodged, moved, dead: e.dead, tanks: (g.stats.tanks || 0) - t0 };
});
check('Streetcleaner: yakında alev yakar, menzil dışında yakmaz', sc.burned >= 15 && sc.far === 0, JSON.stringify(sc));
check('Streetcleaner: nişan alınca yana kaçar, sırt tankı vurulunca patlar', sc.dodged && sc.moved > 0.5 && sc.dead && sc.tanks === 1, JSON.stringify(sc));

// 5) Hideous Mass: havan küreleri (patlayan), zıpkın, kuyruk dalgası, yarı canda öfke
const hm = await page.evaluate(() => {
  const { g, step, place, clear } = window.T;
  clear(); g.god = true;
  const noProj = () => { for (const pr of g.projectiles) pr.remove(); g.projectiles = []; };
  place(0, 0, 18); step(2);
  const e = g.spawnEnemy('hideousmass', [0, 0, 2], null); step(80);
  e.setState('mortarWind'); let mortars = 0, explosive = 0;
  for (let i = 0; i < 120; i++) { step(1); const l = g.projectiles.filter((x) => x.source === e); mortars = Math.max(mortars, l.length); explosive = Math.max(explosive, l.filter((x) => x.explosive).length); }
  noProj();
  e.setState('harpoonWind'); let harpoon = false;
  for (let i = 0; i < 90; i++) { step(1); if (g.projectiles.some((x) => x.source === e && !x.explosive)) harpoon = true; }
  noProj();
  const sh0 = g.shocks.length; e.setState('tailWind'); let shock = false;
  for (let i = 0; i < 80; i++) { step(1); if (g.shocks.length > sh0) shock = true; }
  e.hit({ dmg: e.maxHp * 0.55, part: 'body', point: e.center(), weapon: 'revolver' });
  e.setState('crawl'); step(2);
  return { mortars, explosive, harpoon, shock, enraged: !!e.enraged };
});
check('Hideous Mass: patlayan havan küreleri, zıpkın, kuyruk dalgası, öfke', hm.mortars >= 3 && hm.explosive >= 3 && hm.harpoon && hm.shock && hm.enraged, JSON.stringify(hm));

// 6) V2: nişan çizgisi → atış vurur; parlayan yumruk hücumu PARRY ile bozulur
const v2 = await page.evaluate(() => {
  const { g, step, place, look, clear } = window.T;
  clear(); g.god = false;
  place(0, 0, 21); step(2);
  const e = g.spawnEnemy('v2', [0, 0, 6], null); step(60);
  const hold = () => { e.pos.set(0, 0, 6); e.vel.set(0, 0, 0); };
  const p = g.player; p.hp = 100; p.hard = 0;
  e.setState('aim'); let laser = false;
  for (let i = 0; i < 80 && e.state === 'aim'; i++) { hold(); p.vel.set(0, 0, 0); p.iframes = 0; step(1); if (e.laser.visible) laser = true; }
  for (let i = 0; i < 20; i++) { p.vel.set(0, 0, 0); step(1); }
  const shot = Math.round(100 - p.hp);
  g.god = true; p.hp = 100;
  place(0, 0, 11); step(2); hold();
  e.dashCd = 0; e.setState('dashWind');
  for (let i = 0; i < 60 && !e.parryable; i++) { hold(); step(1); }
  look(e.pos.x, e.pos.y + 1.2, e.pos.z);
  const pb = g.stats.parries;
  const parried = e.parryable && g.tryParry() && e.state === 'stagger' && g.stats.parries === pb + 1;
  return { laser, shot, parried, boss: !!e.boss };
});
check('V2: kırmızı nişan çizgisi, kilitli atış hareketsiz oyuncuyu vurur', v2.laser && v2.shot >= 10, JSON.stringify(v2));
check('V2: parlayan Knuckleblaster hücumu PARRY ile bozulur', v2.parried && v2.boss, JSON.stringify(v2));

// 7) Siber Öğütücü: dalgalar büyür, sütunlar oynar, ölünce koşu biter, en iyi dalga kaydedilir
const cg = await page.evaluate(() => {
  const { g, step, place } = window.T;
  g.startLevel(9); g.god = true; step(120);
  place(0, 0, 12); step(40);
  const a = g.level.arenas[0];
  const waves = [], moved = new Set();
  for (let k = 0; k < 6; k++) {
    for (let i = 0; i < 300 && !(a.enemies.length && a.enemies.every((e) => e.state !== 'spawn')); i++) step(1);
    waves.push(a.enemies.length);
    for (const pl of g.level.cg.pillars) if (pl.target > 0) moved.add(pl.target);
    for (const e of [...a.enemies]) if (!e.dead) e.hit({ dmg: 999, part: 'body', point: e.center(), weapon: 'revolver' });
    step(20);
  }
  const reached = g.cgWave;
  g.god = false; g.damagePlayer(999, null, true); step(90);
  const dead = g.state;
  g.input.pressedSet.add('KeyR'); step(1);
  const rec = window.__ukProgress.levels.CG;
  return { waves, reached, heights: moved.size, dead, state: g.state, res: g.lastResults && g.lastResults.endless, best: rec && rec.wave, title: document.querySelector('.res-title') && document.querySelector('.res-title').textContent };
});
check('Siber Öğütücü: dalgalar büyür, sütun deseni değişir', cg.reached >= 6 && cg.waves[5] >= cg.waves[0] && cg.heights >= 2, JSON.stringify(cg));
check('Siber Öğütücü: ölüm → koşu biter, sonuç ekranı ve en iyi dalga kaydı', cg.dead === 'dead' && cg.state === 'results' && cg.res && cg.best >= 6 && /KOŞU BİTTİ/.test(cg.title), JSON.stringify(cg));

// 8) Oynanabilir V2: 85 can, daha hızlı, kırmızı kol; kilitliyken V1'e düşer
const ch = await page.evaluate(() => {
  const { g, step } = window.T;
  const S = window.__ukSettings, P = window.__ukProgress;
  S.character = 'v2';
  g.startLevel(1); step(30);
  const p = g.player;
  const a = { ch: p.character, hp: p.maxHp, run: +p.run.toFixed(2), skin: g.weapons.M.blue.color.getHexString(), cls: document.getElementById('app').classList.contains('char-v2') };
  P.v2Unlocked = false; g.startLevel(1); step(5);
  const b = { ch: p.character, hp: p.maxHp, skin: g.weapons.M.blue.color.getHexString() };
  P.v2Unlocked = true; S.character = 'v1'; g.startLevel(1); step(5);
  return { a, b };
});
check('oynanabilir V2: 85 can, %12 hız, kırmızı kol; kilitliyken V1', ch.a.ch === 'v2' && ch.a.hp === 85 && ch.a.run > 15 && ch.a.skin !== '4a8cff' && ch.a.cls && ch.b.ch === 'v1' && ch.b.hp === 100 && ch.b.skin === '4a8cff', JSON.stringify(ch));

// 9) Alternatif silahlar: Slab Revolver ve Jackhammer (dükkân, KULLAN/ÇIKAR, güç, zıplama)
const alt = await page.evaluate(() => {
  const { g, step, place, clear } = window.T;
  g.startLevel(3); g.god = true; step(200); clear();
  window.__ukSetPoints(50000);
  const w = g.weapons;
  const out = { buyShot: g.buy('shotgun'), buyNeed: g.buy('alt.revolver'), buyJack: g.buy('alt.shotgun') };
  out.alt = w.alt.slice(0, 2);
  out.name = w.hudInfo ? w.hudInfo().name : null;
  const c = g.level.spawn.checkpoint, p = g.player;
  const shoot = (wi, dist) => {
    clear(); place(c[0], 0, c[2]); p.yaw = 0; p.pitch = 0; w.select(wi); step(40);
    const e = g.spawnEnemy('schism', [c[0], 0, c[2] - dist], null); step(50); e.state = 'idle'; e.decor = true; e.pos.set(c[0], 0, c[2] - dist); step(2);
    const hp0 = e.hp; w.cd[wi] = 0; p.pitch = -0.08;
    if (wi === 0) w.fireRevolver(); else w.fireShotgun(0);
    step(1);
    return +(hp0 - e.hp).toFixed(2);
  };
  out.slab = shoot(0, 6); out.slabCd = +w.cd[0].toFixed(2);
  out.jackNear = shoot(1, 4); out.jackFar = shoot(1, 12);
  clear(); place(c[0], 1.5, c[2]); p.grounded = false; p.pitch = -1.3; w.cd[1] = 0; w.fireShotgun(0); out.jumpVy = +p.vel.y.toFixed(1);
  g.toggleAlt('alt.revolver'); out.off = w.alt[0]; out.offCd = (w.cd[0] = 0, w.select(0), step(40), w.fireRevolver(), +w.cd[0].toFixed(2));
  g.toggleAlt('alt.revolver');
  g.openShop(); out.toggleBtns = document.querySelectorAll('[data-alt]').length; g.closeShop();
  return out;
});
check('Slab Revolver: dükkândan alınır, daha güçlü ve yavaş; ÇIKAR ile normal revolver', alt.buyNeed && alt.alt[0] && alt.slab >= 1.6 && alt.slabCd >= 0.55 && alt.off === false && alt.offCd < 0.4 && alt.toggleBtns === 2, JSON.stringify(alt));
check('Jackhammer: yakına dev darbe, uzağa etkisiz, havada yere ateşle → zıplama', alt.buyJack && alt.alt[1] && alt.jackNear >= 2.5 && alt.jackFar === 0 && alt.jumpVy >= 12, JSON.stringify(alt));

// 10) Parry yardımı: yaklaşan küre ağır çekim + işaret; para yardımı: atış paraya yönelir
const as = await page.evaluate(() => {
  const { g, step, place, clear } = window.T;
  const S = window.__ukSettings;
  g.startLevel(1); g.god = true; step(200); clear();
  place(0, 0, 8); step(2);
  const p = g.player; p.yaw = 0; p.pitch = 0;
  const Proj = window.__ukProjectile;
  const run = (lvl) => {
    S.parryAssist = lvl; clear();
    const o = p.eyePos();
    g.addProjectile(new Proj(g, { pos: o.clone().add(new o.constructor(0, 0, -12)), vel: new o.constructor(0, 0, 22), radius: 0.35, damage: 10 }));
    let slow = 0, cue = false;
    for (let i = 0; i < 40; i++) { step(1); slow = Math.max(slow, g.slowT || 0); }
    cue = !!document.getElementById('parrycue');
    return { slow: +slow.toFixed(2), cue };
  };
  const strong = run(2), off = run(0);
  S.parryAssist = 1;
  // para: hafif sapmış nişan
  const coin = (lvl) => {
    S.coinAssist = lvl; clear(); g.weapons.coins.forEach((c) => c.kill()); g.weapons.coins = [];
    g.buy('revolver.marksman'); g.weapons.variant[0] = 1; g.weapons.select(0); step(40);
    p.yaw = 0; p.pitch = 0.05; g.weapons.coinCharges = 4; g.weapons.tossCoin(); step(22);
    const c = g.weapons.coins[0];
    const o = p.eyePos(); const v = c.pos.clone().sub(o).normalize();
    // nişanı paradan ~0.17 rad saptır
    p.yaw = Math.atan2(-v.x, -v.z) + 0.17; p.pitch = Math.asin(v.y);
    const hit0 = c.hits || 0; const alive0 = c.alive;
    g.weapons.cd[0] = 0; g.weapons.fireRevolver(); step(1);
    return { hit: !c.alive || (c.hits || 0) > hit0 || c.ricocheted === true, alive0 };
  };
  window.__ukSetPoints(99999);
  const cs = coin(2), c0 = coin(0);
  S.coinAssist = 1;
  return { strong, off, cs, c0 };
});
check('parry yardımı (güçlü): yaklaşan kürede ağır çekim, ekranda "PARRY!" yazısı yok; kapalıyken ağır çekim yok', as.strong.slow > 0 && !as.strong.cue && as.off.slow === 0, JSON.stringify(as));
check('para yardımı: güçlüde sapmış atış paraya yönelir, kapalıyken ıskalar', as.cs.hit && !as.c0.hit, JSON.stringify(as));

// 11) Kol animasyonları: yumruk, para, duvar, kayma bacağı
const arms = await page.evaluate(() => {
  const { g, step, clear } = window.T;
  clear();
  const A = g.weapons.arms;
  g.weapons.punchCd = 0; g.weapons.punch(); step(6);
  const punch = A.act && A.act.type === 'punch' && A.models.feedbacker.visible;
  step(40);
  g.weapons.onMove('wall', { left: true }); step(3);
  const wall = A.act && A.act.type === 'wall';
  step(40);
  A.play('coin'); step(2);
  const coin = A.coinMesh.visible;
  step(40);
  g.input.down.add('KeyW'); g.input.down.add('KeyC'); step(14);
  const leg = A.leg.visible && g.player.sliding;
  g.input.down.delete('KeyW'); g.input.down.delete('KeyC'); step(30);
  return { punch, wall, coin, leg };
});
check('kollar: yumruk, duvar sıçraması eli, para fırlatma, kayarken bacak', arms.punch && arms.wall && arms.coin && arms.leg, JSON.stringify(arms));

check('sayfa hatası yok', errors.length === 0, errors.slice(0, 3).join(' | '));
await browser.close();
console.log(`\n${results.filter(Boolean).length}/${results.length} ARAF / güncelleme kontrolü geçti.`);
process.exit(results.every(Boolean) ? 0 : 1);
