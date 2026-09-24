// PRELUDE testi: 5 bölüm (0-1 → 0-5), dükkân ve P ekonomisi, Malicious Face, Cerberus,
// çift boss çubuğu, nişan mıknatısı, uzun parry menzili, bölüm geçişinde sahne temizliği.
// Kullanım: CHROME=/yol/chrome node tests/levels.mjs
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
  };
});

// 1) Bölüm seçimi: yeni kayıtta yalnız 0-1 açık
const sel = await page.evaluate(() => {
  const g = window.__uk; g.onSplashClick();
  const cards = [...document.querySelectorAll('.lv-card')];
  return { n: cards.length, locked: cards.filter((c) => c.classList.contains('locked')).length, start: document.querySelector('[data-act="start"]').textContent };
});
check('bölüm seçimi: 5 bölüm, yalnız 0-1 açık', sel.n === 5 && sel.locked === 4 && /0-1/.test(sel.start), JSON.stringify(sel));

// 2) Her bölüm: iniş, arenalar, sıkışan düşman yok, çıkış → sonuç ekranı ve kilit açma
for (let li = 0; li < 5; li++) {
  const r = await page.evaluate((li) => {
    const { g, step, place } = window.T;
    g.startLevel(li); g.god = true;
    const p = g.player;
    step(240);
    const out = { id: g.levelDef.id, grounded: p.grounded, armed: g.weapons.armed, owned: g.weapons.owned.filter(Boolean).length, shops: g.level.shops.length, stuck: [], arenas: [] };
    for (const a of g.level.arenas) {
      const b = a.trigger;
      place((b[0] + b[3]) / 2, b[1] + 0.1, (b[2] + b[5]) / 2);
      step(5);
      let guard = 0;
      while (a.state === 'active' && guard++ < 40) {
        step(90);
        for (const e of a.enemies) if (!e.dead && !e.flying && g.world.overlapBody(e)) out.stuck.push(e.type);
        for (const e of [...a.enemies]) { if (e.dormant) e.wake(); e.invuln = false; if (!e.dead) e.hit({ dmg: 999, part: 'body', point: e.center(), weapon: 'revolver' }); }
        step(30);
      }
      step(150);
      out.arenas.push(a.state + ':' + a.exits.map((id) => g.level.doors[id].target).join(''));
    }
    // çıkış: kapak (hatch) ya da kapı (0-5)
    const L = g.level;
    if (L.doors.hatch) {
      L.doors.hatch.open(); step(120);
      const hb = L.doors.hatch.box; place((hb[0] + hb[3]) / 2, -6, (hb[2] + hb[5]) / 2);
    } else place(0, 0.5, -120.5);
    for (let i = 0; i < 200 && g.state === 'playing'; i++) step(1);
    out.state = g.state;
    out.unlocked = window.__ukProgress ? window.__ukProgress.unlocked : null;
    out.hasNext = !!document.querySelector('#scr-results [data-act="next"]') || !g.lastResults.hasNext;
    out.p = g.lastResults ? g.lastResults.pointsEarned : 0;
    return out;
  }, li);
  const ok = r.grounded && (li === 0 ? !r.armed : r.armed && r.owned >= 1) && r.shops >= 1 && r.stuck.length === 0 && r.arenas.every((x) => x.startsWith('cleared')) && r.state === 'results' && r.hasNext && r.p > 0;
  check(`bölüm ${r.id}: iniş, arenalar temizlendi, çıkış → sonuç, P kazanıldı`, ok, JSON.stringify(r));
}
const unl = await page.evaluate(() => { const g = window.__uk; g.toMenu(); g.ui.showPanel('play'); return { locked: document.querySelectorAll('.lv-card.locked').length }; });
check('tüm bölümler bitince kilitler açıldı', unl.locked === 0, JSON.stringify(unl));

// 3) P ekonomisi: checkpoint'te kasaya girer, ölünce yatırılmamış P kaybolur
const eco = await page.evaluate(() => {
  const { g, step } = window.T;
  g.startLevel(1); g.god = false; step(200);
  const bank0 = g.bankPoints() * 0 + window.__ukPoints();
  g.style.add('TEST', 500); const un1 = g.unbankedP;
  g.setCheckpoint(new g.player.pos.constructor(0, 0, 5), 0);
  const bank1 = window.__ukPoints(); const un2 = g.unbankedP;
  g.style.add('TEST', 300);
  g.damagePlayer(999, null, true);
  const un3 = g.unbankedP; const bank2 = window.__ukPoints();
  step(80); g.input.pressedSet.add('KeyR'); step(1);
  return { bank0, un1, bank1, un2, un3, bank2, state: g.state };
});
check('P: stil → P, checkpoint kasaya yatırır, ölüm yatırılmamışı siler', eco.un1 >= 500 && eco.bank1 - eco.bank0 >= 500 && eco.un2 === 0 && eco.un3 === 0 && eco.bank2 === eco.bank1 && eco.state === 'playing', JSON.stringify(eco));

// 4) Dükkân: terminal önünde B, önkoşul, satın alma, varyant döngüsü
const shop = await page.evaluate(() => {
  const { g, step, place } = window.T;
  window.__ukSetPoints(10000);
  const sh = g.level.shops[0];
  place(sh.pos.x, sh.pos.y, sh.pos.z); step(3);
  const near = !!g.nearShop;
  g.input.pressedSet.add('KeyB'); step(1);
  const opened = g.state === 'shop' && !document.getElementById('scr-shop').classList.contains('hidden');
  const needFail = g.buy('shotgun.pump') === false;
  const b1 = g.buy('shotgun'); const b2 = g.buy('shotgun.pump');
  const pts = window.__ukPoints();
  const w = g.weapons;
  const vo = w.varOwned[1].slice();
  g.closeShop();
  w.select(1); step(20); const v0 = w.varId; w.select(1); step(5); const v1 = w.varId; w.select(1); step(5); const v2 = w.varId;
  return { near, opened, needFail, b1, b2, pts, vo, v0, v1, v2, state: g.state };
});
check('dükkân: yakınlık + B ile açılır, önkoşul, satın alma, P düşer', shop.near && shop.opened && shop.needFail && shop.b1 && shop.b2 && shop.pts === 6000 && shop.state === 'playing', JSON.stringify(shop));
check('dükkân: yalnız alınan varyantlar arasında döner (CORE ↔ PUMP, SAW yok)', shop.vo.join() === 'true,true,false' && shop.v0 === 'core' && shop.v1 === 'pump' && shop.v2 === 'core', JSON.stringify(shop));

// 5) Malicious Face: küre yağmuru, ışın (dash ile kaçılır), düşünce patlar
const mf = await page.evaluate(() => {
  const { g, step, place } = window.T;
  g.startLevel(2); g.god = false; step(200);
  place(0, 0, -10); step(3);
  g.god = true;
  const e = g.spawnEnemy('maliciousface', [0, 6, -26], null);
  step(60);
  e.setState('volleyWind'); let orbs = 0;
  for (let i = 0; i < 120; i++) { step(1); orbs = Math.max(orbs, g.projectiles.filter((x) => x.source === e).length); }
  for (const x of g.projectiles) x.remove();
  g.god = false; g.player.hp = 100; g.player.hard = 0; place(0, 0, -10);
  e.setState('beamWind'); e.aimPt.set(0, 1, -10);
  for (let i = 0; i < 150 && e.state !== 'hover'; i++) { g.player.vel.set(0, 0, 0); step(1); }
  const hit = 100 - g.player.hp;
  g.player.hp = 100;
  e.setState('beamWind'); e.aimPt.set(0, 1, -10);
  for (let i = 0; i < 150 && e.state !== 'hover'; i++) { g.player.iframes = 1; g.player.vel.set(0, 0, 0); step(1); }
  const dodge = 100 - g.player.hp;
  g.god = true;
  e.hit({ dmg: 12, part: 'head', point: e.center(), weapon: 'revolver' });
  const falling = g.corpses.includes(e);
  for (let i = 0; i < 260 && g.corpses.includes(e); i++) step(1);
  return { orbs, hit: Math.round(hit), dodge: Math.round(dodge), falling, crashed: !g.corpses.includes(e) && !e.root.parent };
});
check('Malicious Face: küre yağmuru', mf.orbs >= 5, JSON.stringify(mf));
check('Malicious Face: ışın vurur, dash (hasarsızlık) ile kaçılır', mf.hit >= 20 && mf.dodge === 0, JSON.stringify(mf));
check('Malicious Face: öldürülünce düşer ve yere çarpınca patlar', mf.falling && mf.crashed, JSON.stringify(mf));

// 6) Çift Swordsmachine: boss çubuğu toplam can
const dbl = await page.evaluate(() => {
  const { g, step, place } = window.T;
  g.god = true;
  const a = g.level.arenas.find((x) => x.id === 'boss');
  const b = a.trigger; place((b[0] + b[3]) / 2, 0.1, (b[2] + b[5]) / 2); step(200);
  const [s1, s2] = a.bossList;
  s1.hit({ dmg: 10, part: 'body', point: s1.center(), weapon: 'revolver' }); step(2);
  return { n: a.bossList.length, active: g.hud.bossActive, name: document.querySelector('.bb-name').textContent, frac: +g.hud.bossFrac.toFixed(3), expect: +((s1.hp + s2.hp) / (s1.maxHp + s2.maxHp)).toFixed(3) };
});
check('0-3: iki Swordsmachine, tek boss çubuğunda toplam can', dbl.n === 2 && dbl.active && /×2/.test(dbl.name) && Math.abs(dbl.frac - dbl.expect) < 0.01, JSON.stringify(dbl));

// 7) Cerberus: uyuyan heykel, uyanma, sarsıntı dalgası, parry, ikizin uyanması ve öfkesi
const cb = await page.evaluate(() => {
  const { g, step, place, look } = window.T;
  g.startLevel(4); g.god = false; step(200);
  const cs = g.enemies.filter((e) => e.type === 'cerberus');
  const dormant = cs.length === 2 && cs.every((c) => c.dormant);
  const hp0 = cs[0].hp; cs[0].hit({ dmg: 5, part: 'body', point: cs[0].center(), weapon: 'revolver' });
  const invuln = cs[0].hp === hp0;
  place(0, 0, -47); step(3);
  const a = g.level.arenas[0];
  step(140);
  const awake = a.state === 'active' && a.enemies.filter((c) => !c.dormant).length === 1;
  const c1 = a.enemies.find((c) => !c.dormant), c2 = a.enemies.find((c) => c.dormant);
  // sarsıntı: yerdeysen vurur
  c1.setState('recover'); c1.atkCd = 99;
  place(c1.pos.x, 0, c1.pos.z + 8); g.player.hp = 100; step(2);
  c1.stomp(); for (let i = 0; i < 60; i++) { c1.atkCd = 99; step(1); }
  const grounded = Math.round(100 - g.player.hp);
  // havadaysan geçer
  g.player.hp = 100; place(c1.pos.x, 3.2, c1.pos.z + 3.5); c1.stomp(); step(2);
  for (let i = 0; i < 40; i++) { c1.atkCd = 99; step(1); }
  const airborne = Math.round(100 - g.player.hp);
  // hücum savuşturma
  g.god = true; g.player.hp = 100;
  place(c1.pos.x, 0, c1.pos.z + 5); step(2); look(c1.pos.x, c1.pos.y + 2, c1.pos.z);
  c1.setState('tackleWind');
  for (let i = 0; i < 60 && !c1.parryable; i++) step(1);
  const pb = g.stats.parries; look(c1.pos.x, c1.pos.y + 2, c1.pos.z);
  const parried = g.tryParry() && c1.state === 'stagger' && g.stats.parries === pb + 1;
  // ikiz: yarı canda uyanır, biri ölünce öteki öfkelenir
  c1.hit({ dmg: c1.hp - c1.maxHp * 0.45, part: 'body', point: c1.center(), weapon: 'revolver' });
  const partnerWoke = !c2.dormant;
  c1.hit({ dmg: 999, part: 'body', point: c1.center(), weapon: 'revolver' });
  step(2);
  return { dormant, invuln, awake, grounded, airborne, parried, partnerWoke, enraged: !!c2.enraged, bar: g.hud.bossActive };
});
check('Cerberus: uyuyan heykeller hasar almaz, arena başlayınca biri uyanır', cb.dormant && cb.invuln && cb.awake, JSON.stringify(cb));
check('Cerberus: sarsıntı dalgası yerde vurur, zıplayınca geçer', cb.grounded >= 10 && cb.airborne === 0, JSON.stringify(cb));
check('Cerberus: parlayan hücum PARRY ile bozulur', cb.parried, JSON.stringify(cb));
check('Cerberus: ikiz yarı canda uyanır, biri ölünce öteki öfkelenir', cb.partnerWoke && cb.enraged && cb.bar, JSON.stringify(cb));

// 8) Nişan mıknatısı (dokunmatik, güçlü): ateş basılıyken bakış düşmana kayar
const mag = await page.evaluate(() => {
  const { g, step, place } = window.T;
  const S = window.__ukSettings;
  const prev = [S.touchMode, S.aimAssist];
  S.touchMode = 'on'; g.applySettings();
  g.startLevel(1); g.god = true; step(200);
  place(0, 0, 8); step(2);
  const run = (level) => {
    S.aimAssist = level;
    for (const e of g.enemies) e.removeSilently(); g.enemies = [];
    const e = g.spawnEnemy('schism', [1.8, 0, -2], null); step(40); e.state = 'idle'; e.invuln = true;
    e.pos.set(1.8, 0, -2); e.vel.set(0, 0, 0); step(2);
    const p = g.player; p.yaw = 0; p.pitch = -0.05;
    const ang = () => { const c = e.center(), o = p.eyePos(), d = p.aimDir(); const v = c.sub(o).normalize(); return Math.acos(Math.min(1, v.dot(d))); };
    const a0 = ang();
    g.input.down.add('Mouse0'); step(30); g.input.down.delete('Mouse0');
    return [a0, ang()];
  };
  const strong = run(2), off = run(0);
  S.touchMode = prev[0]; S.aimAssist = prev[1]; g.applySettings();
  return { strong: strong.map((v) => +v.toFixed(3)), off: off.map((v) => +v.toFixed(3)) };
});
check('nişan mıknatısı: güçlüde bakış düşmana kayar, kapalıyken kaymaz', mag.strong[1] < mag.strong[0] * 0.4 && Math.abs(mag.off[1] - mag.off[0]) < 0.02, JSON.stringify(mag));

// 9) Uzun parry kolu: 6.2 m'deki küre savuşturulur
const pr = await page.evaluate(() => {
  const { g, step, place } = window.T;
  g.god = true; place(0, 0, 8); step(2);
  const p = g.player; p.yaw = 0; p.pitch = 0;
  const o = p.eyePos();
  const Proj = window.__ukProjectile;
  const orb = g.addProjectile(new Proj(g, { pos: o.clone().add(new o.constructor(0, 0, -6.2)), vel: new o.constructor(0, 0, 20), radius: 0.35, damage: 10 }));
  g.weapons.punchCd = 0; g.weapons.punch();
  return { owner: orb.owner, parried: orb.parried };
});
check('uzun parry kolu: 6.2 m uzaktaki küre savuşturuldu', pr.parried && pr.owner === 'player', JSON.stringify(pr));

// 10) Bölüm geçişi: eski bölüm sahneden ve fizikten tamamen kalkar
const mem = await page.evaluate(() => {
  const { g, step } = window.T;
  g.startLevel(0); step(30); const a = g.scene.children.length, sa = g.world.solids.length;
  g.startLevel(3); step(30); g.startLevel(0); step(30);
  return { a, b: g.scene.children.length, sa, sb: g.world.solids.length };
});
check('bölüm geçişi sızdırmaz (sahne ve katı sayısı aynı kalır)', Math.abs(mem.b - mem.a) <= 12 && mem.sa === mem.sb, JSON.stringify(mem));

check('sayfa hatası yok', errors.length === 0, errors.slice(0, 3).join(' | '));
await browser.close();
console.log(`\n${results.filter(Boolean).length}/${results.length} PRELUDE kontrolü geçti.`);
process.exit(results.every(Boolean) ? 0 : 1);
