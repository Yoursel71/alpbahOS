// Uygulama simgesini (eski tip + uyarlanabilir katmanlar) Chromium ile çizip res/ altına PNG yazar.
// Kullanım: CHROME=/yol/chrome node android/make_icons.mjs   (ultrakill-3d kökünden)
import { chromium } from 'playwright-core';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const font = (f) => `data:font/woff2;base64,${readFileSync(join(here, 'assets-src/fonts', f)).toString('base64')}`;
const css = `
@font-face { font-family: Anton; src: url(${font('anton-400-latin.woff2')}) format('woff2'); }
@font-face { font-family: Chakra; font-weight: 700; src: url(${font('chakra-petch-700-latin.woff2')}) format('woff2'); }
html, body { margin: 0; background: transparent; }
.box { position: relative; width: 432px; height: 432px; overflow: hidden; }
.bg { position: absolute; inset: 0;
  background:
    linear-gradient(118deg, transparent 0 57%, rgba(255, 40, 40, 0.28) 57% 60%, transparent 60% 66%, rgba(255, 40, 40, 0.16) 66% 67.5%, transparent 67.5%),
    radial-gradient(circle at 50% 42%, #5a0a0e 0%, #26060a 46%, #0b0508 78%); }
.bg::after { content: ''; position: absolute; inset: 0;
  background: repeating-linear-gradient(0deg, rgba(0, 0, 0, 0.18) 0 2px, transparent 2px 5px); }
.fg { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.t1 { font: 64px/0.9 Anton; color: #f3ede6; letter-spacing: 3px; transform: skewX(-8deg); text-shadow: 0 4px 0 #000; }
.t2 { font: 104px/0.86 Anton; color: #ff2436; letter-spacing: 2px; transform: skewX(-8deg);
  text-shadow: 0 5px 0 #000, 0 0 22px rgba(255, 30, 50, 0.55); }
.t3 { margin-top: 8px; font: 700 30px/1 Chakra; color: #0b0508; background: #3aa8ff; padding: 3px 12px 1px; transform: skewX(-8deg);
  letter-spacing: 3px; box-shadow: 0 4px 0 #000; }
.round { border-radius: 22%; }
`;
const html = (layer) => `<!doctype html><style>${css}</style><div class="box ${layer === 'full' ? 'round' : ''}">
  ${layer !== 'fg' ? '<div class="bg"></div>' : ''}
  ${layer !== 'bg' ? `<div class="fg" ${layer === 'full' ? 'style="transform:scale(1.28)"' : ''}><div class="t1">ULTRA</div><div class="t2">KILL</div><div class="t3">3D</div></div>` : ''}
</div>`;

const browser = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await browser.newPage({ viewport: { width: 432, height: 432 } });
const shot = async (layer, size) => {
  await page.setViewportSize({ width: 432, height: 432 });
  await page.setContent(html(layer));
  await page.evaluate(() => document.fonts.ready);
  const buf = await page.locator('.box').screenshot({ omitBackground: true });
  if (size === 432) return buf;
  // küçült: tarayıcıda yeniden örnekle
  const url = `data:image/png;base64,${buf.toString('base64')}`;
  await page.setViewportSize({ width: size, height: size });
  await page.setContent(`<style>html,body{margin:0;background:transparent}</style><img src="${url}" style="width:${size}px;height:${size}px;display:block">`);
  await page.waitForFunction(() => document.images[0].complete);
  return page.locator('img').screenshot({ omitBackground: true });
};
const out = (p, b) => { mkdirSync(dirname(join(here, p)), { recursive: true }); writeFileSync(join(here, p), b); console.log('yazıldı', p); };

out('res/mipmap-xxxhdpi/ic_launcher_bg.png', await shot('bg', 432));
out('res/mipmap-xxxhdpi/ic_launcher_fg.png', await shot('fg', 432));
for (const [d, s] of [['mdpi', 48], ['hdpi', 72], ['xhdpi', 96], ['xxhdpi', 144], ['xxxhdpi', 192]]) {
  out(`res/mipmap-${d}/ic_launcher.png`, await shot('full', s));
}
await browser.close();
