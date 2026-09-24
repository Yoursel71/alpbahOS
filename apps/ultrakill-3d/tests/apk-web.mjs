// APK içeriği testi: android/build/assets/www (python3 android/build_apk.py çıktısı), MainActivity'nin
// yaptığı gibi https://appassets.androidplatform.net/ kökeninden sunulur; başka her istek engellenir.
// Yerel köprü (UKNative) taklit edilir. Java/WebView tarafı burada çalışmaz — yalnız gerçek cihazda.
import { chromium } from 'playwright-core';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const www = join(root, 'android/build/assets/www');
if (!existsSync(join(www, 'index.html'))) { console.error('önce: python3 android/build_apk.py'); process.exit(2); }
const ORIGIN = 'https://appassets.androidplatform.net/';
const MIME = { '.html': 'text/html', '.css': 'text/css', '.woff2': 'font/woff2', '.txt': 'text/plain' };

const browser = await chromium.launch({
  executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'],
});
const ctx = await browser.newContext({ viewport: { width: 844, height: 390 }, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
const page = await ctx.newPage();
const errors = [];
const external = [];
page.on('pageerror', (e) => errors.push(e.message));
await page.route('**/*', (route) => {
  const url = route.request().url();
  if (!url.startsWith(ORIGIN)) { external.push(url); return route.abort(); }
  const path = decodeURIComponent(new URL(url).pathname.slice(1)) || 'index.html';
  const file = join(www, path);
  if (path.includes('..') || !existsSync(file)) return route.fulfill({ status: 404, body: '' });
  return route.fulfill({ status: 200, contentType: MIME[extname(file)] || 'application/octet-stream', body: readFileSync(file) });
});
await page.addInitScript(() => {
  window.__native = { vib: [], back: [] };
  window.UKNative = {
    vibrate: (p) => window.__native.vib.push(p),
    back: (r) => window.__native.back.push(r),
  };
});

const results = [];
const check = (name, ok, info = '') => { results.push(ok); console.log(`${ok ? 'GEÇTİ ' : 'KALDI '} ${name}${info ? ' — ' + info : ''}`); };

await page.goto(ORIGIN + 'index.html');
await page.waitForFunction(() => window.__uk && document.fonts.status === 'loaded', null, { timeout: 20000 });
await page.waitForTimeout(500);

const base = await page.evaluate(async () => {
  // yazı tipi dosyaları tembel yüklenir: her ağırlığı açıkça yükle, İ/ş/ğ (latin-ext) dahil
  const load = async (f) => (await document.fonts.load(f, 'İşğ ABC')).length > 0 && document.fonts.check(f, 'İşğ ABC');
  return {
    native: document.documentElement.classList.contains('uk-native'),
    anton: await load('20px Anton'),
    chakra: (await load('400 20px "Chakra Petch"')) && (await load('600 20px "Chakra Petch"')) && (await load('700 20px "Chakra Petch"')),
    vt: await load('20px VT323'),
  };
});
check('köprü etkin (uk-native)', base.native);
check('yazı tipleri APK içinden yüklendi (Anton, Chakra Petch, VT323)', base.anton && base.chakra && base.vt, JSON.stringify(base));
check('dış ağ isteği yok', external.length === 0, external.slice(0, 3).join(' '));

const menuBack = await page.evaluate(() => window.__ukNativeBack());
check('menüde GERİ → çıkış iste', menuBack === 'exit', menuBack);

const play = await page.evaluate(() => {
  const g = window.__uk; g.audio.init(); g.startLevel();
  for (let i = 0; i < 120; i++) g.step(1 / 60, false);
  g.step(1 / 60, true);
  const full = document.querySelector('#touch .t-full');
  return { state: g.state, touch: g.touch.active, fullHidden: !full || getComputedStyle(full).display === 'none', fsErr: false };
});
check('dokunmatik modda bölüm başladı, tam ekran butonu gizli', play.state === 'playing' && play.touch && play.fullHidden, JSON.stringify(play));
await page.screenshot({ path: join(root, 'tests/out/apk-play.png') });

const flow = await page.evaluate(async () => {
  const g = window.__uk; const r = {};
  r.b1 = window.__ukNativeBack(); r.s1 = g.state;           // oynarken → duraklat
  g.pauseTime = 0;
  r.b2 = window.__ukNativeBack(); r.s2 = g.state;           // duraklatılmışken → devam
  navigator.vibrate([12, 30, 12]); navigator.vibrate(25);
  g.haptic && g.haptic(20);
  r.vib = window.__native.vib.slice();
  window.__ukNativeLifecycle(false);
  r.s3 = g.state; await new Promise((res) => setTimeout(res, 150)); r.ctx3 = g.audio.ctx && g.audio.ctx.state;
  window.__ukNativeLifecycle(true);
  await new Promise((res) => setTimeout(res, 150)); r.ctx4 = g.audio.ctx && g.audio.ctx.state;
  g.touch.editLayout(); r.b5 = window.__ukNativeBack(); r.edit = g.touch.editing;
  return r;
});
check('GERİ: oynarken duraklatır, duraklatılmışken devam ettirir', flow.b1 === 'ok' && flow.s1 === 'paused' && flow.b2 === 'ok' && flow.s2 === 'playing', JSON.stringify(flow));
check('titreşim yerel köprüye gider', flow.vib.includes('12,30,12') && flow.vib.includes('25'), JSON.stringify(flow.vib));
check('arka plana geçince duraklar ve ses askıya alınır, dönünce ses açılır', flow.s3 === 'paused' && flow.ctx3 === 'suspended' && flow.ctx4 === 'running', `${flow.s3} ${flow.ctx3} → ${flow.ctx4}`);
check('buton düzenleyicide GERİ düzenlemeyi kapatır', flow.b5 === 'ok' && flow.edit === false);

check('sayfa hatası yok', errors.length === 0, errors.join(' | '));
await browser.close();
console.log(`\n${results.filter(Boolean).length}/${results.length} APK içerik kontrolü geçti.`);
process.exit(results.every(Boolean) ? 0 : 1);
