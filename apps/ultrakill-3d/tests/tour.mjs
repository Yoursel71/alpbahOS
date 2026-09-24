// Görsel tur: bölümdeki kilit noktaların ve düşman/silah modellerinin ekran görüntülerini alır.
import { chromium } from 'playwright-core';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'tests/out/tour');
mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('pageerror', (e) => console.log('pageerror', e.message));
await page.goto(pathToFileURL(join(root, 'dist/ultrakill-3d.html')).href);
await page.waitForTimeout(1200);
await page.evaluate(() => { const g = window.__uk; g.startLevel(); g.god = true; for (let i = 0; i < 240; i++) g.step(1 / 60, false); for (const e of g.enemies) e.removeSilently(); g.enemies = []; for (const a of g.level.arenas) a.state = 'cleared'; g.hud.reset(); });
const views = [
  ['a1-overview', [0, 3, 10], 0, -0.15],
  ['corridor1-pit', [0, 0, -19], 0, -0.25],
  ['secret1-alcove', [-2, 0, -35.5], Math.PI / 2, 0.35],
  ['arena2', [0, 0, -44], 0, 0.02],
  ['corridor2-slide', [0, 0, -83], 0, -0.05],
  ['arena3-lava', [0, 0, -104], 0, -0.08],
  ['arena3-parkour', [8, 0, -128], -0.6, 0.25],
  ['boss-arena', [0, 0, -174], 0, -0.02],
];
for (const [name, pos, yaw, pitch] of views) {
  await page.evaluate(([pos, yaw, pitch]) => { const g = window.__uk, p = g.player; p.pos.set(...pos); p.vel.set(0, 0, 0); p.yaw = yaw; p.pitch = pitch; for (let i = 0; i < 20; i++) g.step(1 / 60, false); g.hud.reset(); g.step(1 / 60, true); }, [pos, yaw, pitch]);
  await page.waitForTimeout(250);
  await page.screenshot({ path: join(out, name + '.png') });
}
// Düşman vitrini
await page.evaluate(() => {
  const g = window.__uk, p = g.player;
  p.pos.set(0, 0, 6); p.yaw = 0; p.pitch = 0.05;
  const list = [['filth', [-4.5, 0, 0]], ['stray', [-1.5, 0, 0]], ['schism', [1.7, 0, 0]], ['swordsmachine', [5.2, 0, -0.5]]];
  for (const [t, pos] of list) { const e = g.spawnEnemy(t, pos, null); e.state = 'idle'; e.decor = true; e.yaw = 0; }
  for (let i = 0; i < 60; i++) g.step(1 / 60, false);
  g.step(1 / 60, true);
});
await page.waitForTimeout(250);
await page.screenshot({ path: join(out, 'enemies.png') });
// saldırı pozları
await page.evaluate(() => {
  const g = window.__uk;
  const E = g.enemies;
  E[0].state = 'windup'; E[1].state = 'windup'; E[1].orb.visible = true; E[1].orb.scale.setScalar(1); E[2].state = 'wind'; E[2].mode = 'H'; E[3].state = 'swingWind'; E[3].combo = 0;
  for (const e of E) { e.decor = true; e.think = () => {}; }
  for (let i = 0; i < 40; i++) g.step(1 / 60, false);
  g.step(1 / 60, true);
});
await page.waitForTimeout(250);
await page.screenshot({ path: join(out, 'enemies-attack.png') });
// silahlar
for (const [i, name] of [[1, 'shotgun'], [2, 'rail']]) {
  await page.evaluate((i) => { const g = window.__uk; for (const e of g.enemies) e.removeSilently(); g.enemies = []; g.weapons.select(i); for (let k = 0; k < 30; k++) g.step(1 / 60, false); g.step(1 / 60, true); }, i);
  await page.waitForTimeout(200);
  await page.screenshot({ path: join(out, 'weapon-' + name + '.png') });
}
// patlama + parry efekti
await page.evaluate(() => {
  const g = window.__uk, p = g.player;
  g.weapons.select(0);
  for (let k = 0; k < 20; k++) g.step(1 / 60, false);
  g.explode(new p.pos.constructor(0, 1.5, -2), 5, 0, { visualOnly: true });
  g.weapons.punch();
  for (let k = 0; k < 6; k++) g.step(1 / 60, false);
  g.step(1 / 60, true);
});
await page.waitForTimeout(200);
await page.screenshot({ path: join(out, 'fx-explosion-punch.png') });
await browser.close();
console.log('tur tamamlandı:', out);
