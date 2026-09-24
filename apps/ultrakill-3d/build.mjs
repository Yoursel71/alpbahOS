// Tek dosyalık oynanabilir HTML üretir: dist/ultrakill-3d.html
// Kullanım: npm install && npm run build
//   node build.mjs --fragment <yol>  → <html>/<head>/<body> sarmalayıcısız gövde parçası da yazar
import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const result = await build({
  entryPoints: [join(root, 'src/main.js')],
  bundle: true,
  minify: true,
  format: 'iife',
  target: ['es2020'],
  write: false,
  legalComments: 'none',
  banner: { js: '/*! ULTRAKILL 3D hayran yapımı (alpbahOS). İçerir: three.js — Copyright © 2010-2026 three.js authors — MIT License (https://github.com/mrdoob/three.js/blob/dev/LICENSE) */' },
});
const js = result.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');
const css = readFileSync(join(root, 'src/styles.css'), 'utf8');
const html = readFileSync(join(root, 'src/index.html'), 'utf8')
  .replace('/*__CSS__*/', () => css)
  .replace('/*__JS__*/', () => js);
mkdirSync(join(root, 'dist'), { recursive: true });
writeFileSync(join(root, 'dist/ultrakill-3d.html'), html);
console.log(`dist/ultrakill-3d.html yazıldı (${(html.length / 1024).toFixed(0)} KB)`);

const fi = process.argv.indexOf('--fragment');
if (fi > 0 && process.argv[fi + 1]) {
  const cut = (a, b) => html.slice(html.indexOf(a) + a.length, html.indexOf(b));
  const frag = cut('<!--ART-HEAD-START-->', '<!--ART-HEAD-END-->') + cut('<!--ART-BODY-START-->', '<!--ART-BODY-END-->');
  writeFileSync(process.argv[fi + 1], frag);
  console.log(`parça yazıldı: ${process.argv[fi + 1]} (${(frag.length / 1024).toFixed(0)} KB)`);
}
