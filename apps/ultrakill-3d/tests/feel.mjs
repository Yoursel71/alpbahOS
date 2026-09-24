// "Oyun hissi" testi: üsten düşerek başlama, bölüm sonunda düşerken sonuç ekranı, özel parry
// (animasyon, halka, ses, "PARRY!" yazısı yok), ölüm ekranında çığlık atan kafatası, ekrana kan ve
// hasar yönü, boss parçalanma sekansı, Cerberus nerfi, Sawblade modeli, nişan yardımı (yapışma,
// takip, hedef işareti), namlu alevi konisi, düşman yakın saldırı izi, yeni ses tanımları.
// Kullanım: CHROME=/yol/chrome node tests/feel.mjs
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

await page.waitForFunction(() => !window.__uk.audio.pendingDefs || window.__uk.audio.pendingDefs.length === 0, null, { timeout: 30000 });

// 1) Üsten iniş: havadaki üste doğ, alarm → kapak açılır → bölüme düş; Siber Öğütücü'de üs yok
const base = await page.evaluate(() => {
  const { g, step } = window.T;
  g.startLevel(5);
  const p = g.player, h = g.level.doors.baseHatch;
  const start = { y: +p.pos.y.toFixed(1), hatch: !!h, closed: h && h.t === 0 };
  step(20); const still = p.pos.y > 29 && p.grounded;
  step(40); const opened = h.t > 0.95 && p.pos.y < 29.5;
  let f = 0; for (; f < 300 && !p.grounded; f++) step(1);
  g.startLevel(9); step(5);
  return { ...start, still, opened, landFrames: 60 + f, landedY: +p.pos.y.toFixed(2), cgBase: !!g.level.doors.baseHatch };
});
check('üs: kapağın üstünde doğ, alarmdan sonra kapak açılır, bölüme düşüp in', base.hatch && base.closed && base.y === 30 && base.still && base.opened && base.landedY < 0.5 && base.landFrames < 200, JSON.stringify(base));
check('Siber Öğütücü\'de üs yok (yerde başlar)', !base.cgBase, JSON.stringify(base));

// 2) Bölüm sonu: sonuç ekranı düşüş sahnesinin üstünde açılır; menüye dönünce düşüş biter
const fall = await page.evaluate(() => {
  const { g, step } = window.T;
  g.startLevel(5); g.god = true; step(150);
  g.levelComplete();
  const cam0 = g.camera.rotation.y;
  for (let i = 0; i < 30; i++) g.step(1 / 60, false);
  const r = { active: g.fall.active, state: g.state, cls: document.getElementById('scr-results').classList.contains('falling'), camTurn: +(g.camera.rotation.y - cam0).toFixed(2), pitch: +g.camera.rotation.x.toFixed(2) };
  g.toMenu(); step(2);
  r.after = g.fall.active; r.clsAfter = document.getElementById('scr-results').classList.contains('falling');
  return r;
});
check('bölüm sonu: düşerken sonuç ekranı (aşağı bakan dönen kamera), menüde biter', fall.active && fall.state === 'results' && fall.cls && fall.pitch < -1 && fall.camTurn !== 0 && !fall.after && !fall.clsAfter, JSON.stringify(fall));

// 3) Parry: özel kol animasyonu + şok halkası + FOV vuruşu; ekranda "PARRY!" yazısı yok
const par = await page.evaluate(() => {
  const { g, step, place, clear } = window.T;
  g.startLevel(1); g.god = true; step(240); clear();
  place(0, 0, 8); step(2);
  const p = g.player; p.yaw = 0; p.pitch = 0;
  const o = p.eyePos(); const Proj = window.__ukProjectile;
  g.addProjectile(new Proj(g, { pos: o.clone().add(new o.constructor(0, 0, -3)), vel: new o.constructor(0, 0, 20), radius: 0.35, damage: 10 }));
  g.weapons.punchCd = 0; g.weapons.punch(); step(3);
  const A = g.weapons.arms;
  return { act: A.act && A.act.type, ring: A.ring.visible, fov: +p.fovKick.toFixed(1), burst: document.getElementById('parryburst').classList.contains('go'), cue: !!document.getElementById('parrycue'), parries: g.stats.parries };
});
check('parry: özel animasyon, şok halkası, FOV vuruşu, ışın patlaması; "PARRY!" yazısı yok', par.act === 'parry' && par.ring && par.fov < -5 && par.burst && !par.cue && par.parries >= 1, JSON.stringify(par));

// 4) Hasar: ekrana kan, saldırı yönü göstergesi, kamera darbesi
const hurt = await page.evaluate(() => {
  const { g, step, place, clear } = window.T;
  clear(); g.god = false; place(0, 0, 8); step(2);
  const p = g.player; p.yaw = 0; p.hp = 100; p.iframes = 0;
  g.damagePlayer(20, new p.pos.constructor(4, 1, 8));
  step(1);
  const dirs = [...document.querySelectorAll('#dmgdir i.on')].map((e) => e.style.transform);
  return { splats: (g.hud.splats || []).length, dirs, roll: +(g.hurtRoll || 0).toFixed(3) };
});
check('hasar: ekrana kan lekeleri, sağdan gelen darbe için yön göstergesi ve kamera yuvarlanması', hurt.splats >= 2 && hurt.dirs.length === 1 && /rotate\(1\.[45]/.test(hurt.dirs[0]) && hurt.roll > 0, JSON.stringify(hurt));

// 5) Ölüm ekranı: kafatası belirir ve çığlık atar
const skull = await page.evaluate(async () => {
  const { g } = window.T;
  g.god = false; g.damagePlayer(999, null, true);
  let shown = false, scream = false;
  for (let i = 0; i < 900 && !shown; i++) { g.step(1 / 60, false); const s = document.querySelector('.ds-skull'); shown = !s.classList.contains('hidden'); scream = s.classList.contains('scream'); }
  const jaw = !!document.querySelector('.ds-skull .sk-jaw rect');
  g.respawn(); g.step(1 / 60, false);
  return { shown, scream, jaw, hidden: document.querySelector('.ds-skull').classList.contains('hidden') || document.getElementById('deathscreen').classList.contains('hidden') };
});
check('ölüm ekranı: çenesi ayrı kafatası belirir ve çığlık atar, yeniden doğunca gider', skull.shown && skull.scream && skull.jaw && skull.hidden, JSON.stringify(skull));

// 6) Boss parçalanma: ağır çekim, parça parça kopma, sonunda patlama ve sahneden kalkma
const boss = await page.evaluate(() => {
  const { g, step, place, clear } = window.T;
  g.god = true; clear(); place(0, 0, 10); step(2);
  const b = g.spawnEnemy('swordsmachine', [0, 0, 0], null); step(80); b.state = 'idle';
  const meshes0 = b.deathMeshes;
  b.hit({ dmg: 60, part: 'body', point: b.center(), weapon: 'revolver' });
  const seq = b.bossDeathT !== undefined, slow = g.slowT > 0.5, inCorpses = g.corpses.includes(b);
  const n0 = b.deathMeshes.length;
  let popped = 0;
  for (let i = 0; i < 110; i++) { step(1); popped = n0 - b.deathMeshes.length; }
  const midVisible = !!b.root.parent;
  for (let i = 0; i < 400 && b.root.parent; i++) step(1);
  return { seq, slow, inCorpses, n0, popped, midVisible, removed: !b.root.parent, gone: !g.corpses.includes(b), meshes0: meshes0 === undefined };
});
check('boss ölümü: ağır çekim, titreyerek parça parça kopar, sonunda patlar ve kalkar', boss.seq && boss.slow && boss.inCorpses && boss.popped >= 2 && boss.midVisible && boss.removed && boss.gone, JSON.stringify(boss));

// 7) Cerberus nerfi: küre daha yavaş ve az hasarlı; ikizler arasında ortak küre beklemesi
const cer = await page.evaluate(() => {
  const { g, step, place, clear } = window.T;
  g.startLevel(4); g.god = true; step(240); clear();
  place(0, 0, -47); step(2);
  const a = g.spawnEnemy('cerberus', [-8, 0.6, -70], null), b = g.spawnEnemy('cerberus', [8, 0.6, -70], null);
  step(80);
  a.throwOrb();
  const pr = g.projectiles.find((x) => x.source === a);
  const out = { dmg: +pr.damage.toFixed(1), speed: +pr.vel.length().toFixed(1) };
  // şans hep "küre" çıksın: ilki küre hazırlar, ikizi hemen ardından hazırlayamaz
  const R = Math.random; Math.random = () => 0.1;
  for (const e of [a, b]) { e.setState('chase'); e.canSee = true; e.atkCd = 0; e.seeT = 9; }
  g.cerbOrbT = -99;
  a.think(1 / 60); b.think(1 / 60);
  out.a = a.state; out.b = b.state;
  Math.random = R;
  return out;
});
check('Cerberus nerfi: küre ≤ 20 hasar ve daha yavaş; ikizler aynı anda küre hazırlayamaz', cer.dmg <= 20 && cer.speed <= 20 && cer.a === 'orbWind' && cer.b !== 'orbWind', JSON.stringify(cer));

// 8) Sawblade: kırmızı varyantta namlular yerine dönen dişli testere fırlatıcı; mermi dişli disk
const saw = await page.evaluate(() => {
  const { g, step, clear } = window.T;
  clear(); window.__ukSettings.allWeapons = true; g.weapons.giveAll();
  const w = g.weapons; w.select(2); w.variant[2] = 2; w.updateAccents(); step(40);
  const m = w.models[2];
  const a0 = m.saw.rotation.x; step(5);
  const r = { rig: m.sawRig.visible, barrels: m.barrels.visible, spin: m.saw.rotation.x !== a0 };
  w.fireSawblade(); step(1);
  const pr = g.projectiles.find((x) => x.kind === 'saw');
  r.proj = !!pr && pr.mesh.children.length >= 12;
  r.reload = !m.saw.visible;
  w.variant[2] = 0; step(2); r.back = m.barrels.visible && !m.sawRig.visible;
  window.__ukSettings.allWeapons = false;
  return r;
});
check('Sawblade: testere fırlatıcı modeli, dönen testere, dişli disk mermi; diğer varyantta namlular', saw.rig && !saw.barrels && saw.spin && saw.proj && saw.reload && saw.back, JSON.stringify(saw));

// 9) Nişan yardımı: hedefe yapışır, koşan düşmanı takip eder, hedef işareti görünür
const aim = await page.evaluate(() => {
  const { g, step, place, clear } = window.T;
  const S = window.__ukSettings;
  const prev = [S.touchMode, S.aimAssist];
  S.touchMode = 'on'; g.applySettings();
  g.startLevel(1); g.god = true; step(240); clear();
  place(0, 0, 8); step(2);
  const run = (lvl) => {
    S.aimAssist = lvl; clear();
    const e = g.spawnEnemy('schism', [0.6, 0, -2], null); step(40); e.state = 'idle'; e.invuln = true;
    e.pos.set(0.6, 0, -2); step(2);
    const p = g.player; p.yaw = 0; p.pitch = -0.05; step(3);
    // düşman yana kayar (koşuyor gibi): 2 sn boyunca x += 3 m/s, ateş basılı değil
    const ang = () => { const c = g.aimPoint(e), o = p.eyePos(), d = p.aimDir(); const v = c.sub(o).normalize(); return Math.acos(Math.min(1, v.dot(d))); };
    for (let i = 0; i < 60; i++) { e.pos.x += 3 / 60; step(1); }
    const lock = !document.getElementById('lockmark').classList.contains('hidden');
    return { target: g.aimTarget === e, a: +ang().toFixed(3), lock, fr: +g.aimFriction.toFixed(2) };
  };
  const strong = run(2), off = run(0);
  S.touchMode = prev[0]; S.aimAssist = prev[1]; g.applySettings();
  return { strong, off };
});
check('nişan yardımı: koşan hedefi takip eder, işaret görünür, yakında yavaşlar; kapalıyken yok', aim.strong.target && aim.strong.a < 0.12 && aim.strong.lock && aim.strong.fr < 1 && aim.off.a > 0.2 && !aim.off.lock, JSON.stringify(aim));

// 10) Silah ve düşman efektleri, yeni ses tanımları
const fx = await page.evaluate(() => {
  const { g, step, place, clear } = window.T;
  clear(); g.startLevel(1); g.god = true; step(240); clear(); place(0, 0, 8);
  const w = g.weapons; w.select(1); step(40); w.cd[1] = 0; w.fireShotgun(0); step(1);
  const cone = w.flashCone.visible, kick = (g.camKick || 0) > 0;
  const e = g.spawnEnemy('filth', [0, 0, 6.5], null); step(50);
  const n0 = g.fx.slashes.length; e.meleeHit(2.9, 20, 0.25); const slash = g.fx.slashes.length > n0;
  const snd = ['parry', 'parryRing', 'skullScream', 'dashWhoosh', 'hitTick', 'meleeWhoosh', 'bossDeath'].filter((k) => !g.audio.bank.has(k));
  return { cone, kick, slash, missing: snd };
});
check('efektler: namlu alevi konisi, kamera tepmesi, düşman saldırı kavisi; yeni sesler bankada', fx.cone && fx.kick && fx.slash && fx.missing.length === 0, JSON.stringify(fx));

check('sayfa hatası yok', errors.length === 0, errors.slice(0, 3).join(' | '));
await browser.close();
console.log(`\n${results.filter(Boolean).length}/${results.length} oyun hissi kontrolü geçti.`);
process.exit(results.every(Boolean) ? 0 : 1);
