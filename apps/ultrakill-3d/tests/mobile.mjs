// Mobil test: dokunmatik cihaz emülasyonu (yatay telefon), joystick ile yürüme, sağa sürükleyerek
// bakma, butonlarla ateş/zıplama/atılma/yumruk ve silah değiştirme.
import { chromium } from 'playwright-core';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'tests/out');
mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const ctx = await browser.newContext({ viewport: { width: 844, height: 390 }, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
const cdp = await ctx.newCDPSession(page);
const results = [];
const check = (name, ok, info = '') => { results.push(ok); console.log(`${ok ? 'GEÇTİ ' : 'KALDI '} ${name}${info ? ' — ' + info : ''}`); };
const touch = (type, points) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: points.map(([x, y, id]) => ({ x, y, id, radiusX: 4, radiusY: 4, force: 1 })) });
const sim = (n) => page.evaluate((n) => { const g = window.__uk; for (let i = 0; i < n; i++) g.step(1 / 60, false); }, n);
const center = (sel) => page.evaluate((sel) => { const r = document.querySelector(sel).getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; }, sel);

await page.goto(pathToFileURL(join(root, 'dist/ultrakill-3d.html')).href);
await page.waitForTimeout(1200);
await page.touchscreen.tap(422, 195);
await page.waitForTimeout(400);
check('dokunmatik algılandı', await page.evaluate(() => window.__uk.touch.active && window.__uk.input.touchMode));
check('dokunuşla menüye geçildi', await page.evaluate(() => window.__uk.state === 'menu'));
await page.screenshot({ path: join(out, 'm01-menu.png') });
await page.evaluate(() => { const g = window.__uk; g.startLevel(); g.god = true; for (let i = 0; i < 240; i++) g.step(1 / 60, false); for (const e of g.enemies) e.removeSilently(); g.enemies = []; g.level.arenas[0].state = 'cleared'; g.player.pos.set(0, 0, 8); g.player.yaw = 0; g.step(1 / 60); });
await page.waitForTimeout(300);
check('dokunmatik katman görünür', await page.evaluate(() => !document.getElementById('touch').classList.contains('hidden')));

// Joystick: sol altta dokun ve yukarı it
const z0 = await page.evaluate(() => window.__uk.player.pos.z);
await touch('touchStart', [[110, 300, 1]]);
await touch('touchMove', [[110, 230, 1]]);
const axis = await page.evaluate(() => [window.__uk.input.axisX, window.__uk.input.axisY]);
await sim(40);
const z1 = await page.evaluate(() => window.__uk.player.pos.z);
await page.screenshot({ path: join(out, 'm02-joystick.png') });
check('joystick ekseni', axis[1] < -0.9, JSON.stringify(axis));
check('joystick ile ileri yürüme', z0 - z1 > 4, (z0 - z1).toFixed(2));
// Aynı anda ikinci parmakla sağda bakış
const yaw0 = await page.evaluate(() => window.__uk.player.yaw);
await touch('touchMove', [[110, 230, 1], [600, 200, 2]]);
await touch('touchMove', [[110, 230, 1], [660, 200, 2]]);
await sim(1);
const yaw1 = await page.evaluate(() => window.__uk.player.yaw);
check('çoklu dokunuş: yürürken sağa sürükleyerek bakış', yaw1 < yaw0 - 0.1, (yaw1 - yaw0).toFixed(3));
await touch('touchEnd', []);
await sim(2);
check('parmak kalkınca joystick sıfırlandı', await page.evaluate(() => window.__uk.input.axisX === 0 && window.__uk.input.axisY === 0));

// Zıpla butonu
const [jx, jy] = await center('.t-jump');
await touch('touchStart', [[jx, jy, 3]]);
await sim(1);
const vy = await page.evaluate(() => window.__uk.player.vel.y);
await touch('touchEnd', []);
check('ZIPLA butonu', vy > 10, vy.toFixed(1));
await sim(90);
// Atıl
const [dx, dy] = await center('.t-dash');
await touch('touchStart', [[dx, dy, 4]]);
await sim(1);
const dash = await page.evaluate(() => window.__uk.player.dashT > 0);
await touch('touchEnd', []);
check('ATIL butonu', dash);
await sim(30);
// Ateş: düşman koy, nişan yardımıyla vur
await page.evaluate(() => { const g = window.__uk, p = g.player; p.pos.set(0, 0, 8); p.vel.set(0, 0, 0); p.yaw = 0.04; p.pitch = -0.02; const e = g.spawnEnemy('stray', [0, 0, -4], null); e.state = 'idle'; e.decor = true; for (let i = 0; i < 50; i++) g.step(1 / 60, false); });
const [fx, fy] = await center('.t-fire');
const hp0 = await page.evaluate(() => window.__uk.enemies[0].hp);
await touch('touchStart', [[fx, fy, 5]]);
await sim(2);
await touch('touchEnd', []);
const hp1 = await page.evaluate(() => (window.__uk.enemies[0] ? window.__uk.enemies[0].hp : -1));
check('ATEŞ butonu + nişan yardımı isabet', hp1 < hp0, `${hp0} → ${hp1}`);
await page.evaluate(() => { const g = window.__uk; g.step(1 / 60); });
await page.waitForTimeout(200);
await page.screenshot({ path: join(out, 'm03-fire.png') });
// Silah butonu 2 → shotgun, tekrar → varyant
const [w2x, w2y] = await center('.t-top [data-code="Digit2"]');
await touch('touchStart', [[w2x, w2y, 6]]); await sim(1); await touch('touchEnd', []); await sim(20);
const wsel = await page.evaluate(() => window.__uk.weapons.cur);
await touch('touchStart', [[w2x, w2y, 7]]); await sim(1); await touch('touchEnd', []); await sim(5);
const wvar = await page.evaluate(() => window.__uk.weapons.varId);
check('silah butonu ve varyant değişimi', wsel === 1 && wvar === 'pump', `${wsel} ${wvar}`);
// Yumruk
const [px, py] = await center('.t-punch');
await touch('touchStart', [[px, py, 8]]); await sim(1);
const punch = await page.evaluate(() => window.__uk.weapons.punchT < 0.1);
await touch('touchEnd', []);
check('YUMRUK butonu', punch);
// Duraklat
const [qx, qy] = await center('.t-pause');
await touch('touchStart', [[qx, qy, 9]]); await touch('touchEnd', []);
await page.waitForTimeout(200);
check('duraklat butonu', await page.evaluate(() => window.__uk.state === 'paused'));
await page.screenshot({ path: join(out, 'm04-pause.png') });
await page.evaluate(() => window.__uk.resume());
await page.waitForTimeout(200);
check('taklit fare tıklaması istemsiz ateş etmedi', await page.evaluate(() => !window.__uk.input.down.has('Mouse0')));
check('sayfa hatası yok', errors.length === 0, errors.join(' | '));
await browser.close();
console.log(`\n${results.filter(Boolean).length}/${results.length} mobil kontrol geçti.`);
process.exit(results.every(Boolean) ? 0 : 1);
