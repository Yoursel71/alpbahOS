// Bölüm düzenleri için ortak yardımcılar: kapı boşluklu duvarlar ve odalar.
import * as THREE from 'three';
// Kenarlar: n = z0 tarafı (en küçük z, ilerleme yönü), s = z1 tarafı, w = x0 tarafı, e = x1 tarafı.
// Boşluk (gap): [a, b, üst = 6, alt = 0] — duvar boyunca a..b aralığı, alt..üst yüksekliği açık.

function wallAlongX(L, x0, x1, za, zb, y, h, mat, gap) {
  if (!gap) { L.box(x0 - 1, y, za, x1 + 1, y + h, zb, mat); return; }
  const [g0, g1, top = 6, bottom = 0] = gap;
  L.box(x0 - 1, y, za, g0, y + h, zb, mat);
  L.box(g1, y, za, x1 + 1, y + h, zb, mat);
  if (top < h) L.box(g0, y + top, za, g1, y + h, zb, mat);
  if (bottom > 0) L.box(g0, y, za, g1, y + bottom, zb, mat);
}

function wallAlongZ(L, xa, xb, z0, z1, y, h, mat, gap) {
  if (!gap) { L.box(xa, y, z0, xb, y + h, z1, mat); return; }
  const [g0, g1, top = 6, bottom = 0] = gap;
  L.box(xa, y, z0, xb, y + h, g0, mat);
  L.box(xa, y, g1, xb, y + h, z1, mat);
  if (top < h) L.box(xa, y + top, g0, xb, y + h, g1, mat);
  if (bottom > 0) L.box(xa, y, g0, xb, y + bottom, g1, mat);
}

// Dört duvarlı oda. floor: malzeme ya da null (zemin elle, ör. çukurlu), ceil: tavan malzemesi.
// skip: çizilmeyecek kenarlar (komşu odayla ortak duvar iki kez çizilmesin diye).
export function room(L, x0, z0, x1, z1, { y = 0, h = 12, mat = 'stone', floor = 'tiles', ceil = null, gaps = {}, skip = [] } = {}) {
  if (floor) L.box(x0 - 1, y - 2, z0 - 1, x1 + 1, y, z1 + 1, floor);
  if (ceil) L.box(x0 - 1, y + h, z0 - 1, x1 + 1, y + h + 1, z1 + 1, ceil);
  if (!skip.includes('n')) wallAlongX(L, x0, x1, z0 - 1, z0, y, h, mat, gaps.n);
  if (!skip.includes('s')) wallAlongX(L, x0, x1, z1, z1 + 1, y, h, mat, gaps.s);
  if (!skip.includes('w')) wallAlongZ(L, x0 - 1, x0, z0, z1, y, h, mat, gaps.w);
  if (!skip.includes('e')) wallAlongZ(L, x1, x1 + 1, z0, z1, y, h, mat, gaps.e);
}

// Zemin: dikdörtgen alan, içinde delikler (çukurlar) bırakarak parçalara böler.
// holes: [[hx0, hz0, hx1, hz1], ...] — delikler z yönünde üst üste binmemeli.
export function floorWithHoles(L, x0, z0, x1, z1, holes, { y = 0, mat = 'tiles' } = {}) {
  const hs = [...holes].sort((a, b) => a[1] - b[1]);
  let z = z0;
  for (const [hx0, hz0, hx1, hz1] of hs) {
    if (hz0 > z) L.box(x0, y - 2, z, x1, y, hz0, mat);
    if (hx0 > x0) L.box(x0, y - 2, hz0, hx0, y, hz1, mat);
    if (hx1 < x1) L.box(hx1, y - 2, hz0, x1, y, hz1, mat);
    z = hz1;
  }
  if (z < z1) L.box(x0, y - 2, z, x1, y, z1, mat);
}

// Çukur: dört yan duvar + taban; kind 'pit' → düşen oyuncu son güvenli yere döner, düşman ölür.
export function pit(L, x0, z0, x1, z1, { depth = 10, dmg = 25, mat = 'rock', bottom = 'meat' } = {}) {
  L.box(x0 - 1, -depth, z0 - 1, x0, 0, z1 + 1, mat);
  L.box(x1, -depth, z0 - 1, x1 + 1, 0, z1 + 1, mat);
  L.box(x0, -depth, z0 - 1, x1, 0, z0, mat);
  L.box(x0, -depth, z1, x1, 0, z1 + 1, mat);
  L.box(x0, -depth - 2, z0, x1, -depth, z1, bottom);
  L.hurt([x0, -depth - 4, z0, x1, -1.5, z1], dmg, 'pit');
}

// Sütun: gövde + başlık + taban
export function pillar(L, x, z, h = 12, w = 1, mat = 'stone', y = 0) {
  L.box(x - w, y, z - w, x + w, y + h, z + w, mat);
  L.box(x - w - 0.3, y + h, z - w - 0.3, x + w + 0.3, y + h + 0.4, z + w + 0.3, 'metal');
  L.box(x - w - 0.3, y, z - w - 0.3, x + w + 0.3, y + 0.4, z + w + 0.3, 'metal');
}

export function spires(L, list) {
  for (const [x, z, h, w] of list) L.spire(x, z, h, w);
}

// ARAF (Limbo) teması: mavi gökyüzü, beyaz bulutlar, yumuşak gün ışığı
export const LIMBO = {
  fog: 0xa8b8d0, fogNear: 40, fogFar: 210,
  skyTop: [0.16, 0.32, 0.66], skyHor: [0.7, 0.78, 0.9], skyCloud: [0.55, 0.55, 0.58], skyGlow: [0.9, 0.72, 0.4],
  hemiSky: 0xf4f8ff, hemiGround: 0x5a6a48, hemi: 2.3, ambient: 0x7a8090, sun: 0xfff2d8,
};

// Ağaç: gövde + iki katlı yaprak kütlesi (katı gövde, yapraklar geçilebilir değil)
export function tree(L, x, z, h = 5, y = 0) {
  L.box(x - 0.35, y, z - 0.35, x + 0.35, y + h, z + 0.35, 'ruin');
  L.box(x - 1.8, y + h - 0.6, z - 1.8, x + 1.8, y + h + 1.4, z + 1.8, 'grass', { texScale: 2 });
  L.box(x - 1.1, y + h + 1.4, z - 1.1, x + 1.1, y + h + 2.4, z + 1.1, 'grass', { texScale: 2 });
}

// Basit ev: dört duvar, kapı boşluğu ve düz çatı (yanarken üstünde ateş)
export function house(L, x0, z0, x1, z1, { h = 5, mat = 'castleDark', door = 's', burning = false } = {}) {
  const cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
  const gaps = {};
  if (door === 's' || door === 'n') gaps[door] = [cx - 1.2, cx + 1.2, 3];
  else gaps[door] = [cz - 1.2, cz + 1.2, 3];
  room(L, x0, z0, x1, z1, { h, mat, floor: null, gaps });
  L.box(x0 - 1.4, h, z0 - 1.4, x1 + 1.4, h + 0.6, z1 + 1.4, 'ruin');
  if (burning) {
    L.fire(cx - (x1 - x0) * 0.25, h + 0.6, cz, 2.6);
    L.fire(cx + (x1 - x0) * 0.2, h + 0.6, cz + 0.6, 2);
    L.lamps.push({ pos: new THREE.Vector3(cx, h + 2, cz), color: 0xff7a30, power: 1.2 });
    L.animated.push((t) => { if (Math.random() < 0.12) L.game.fx.smoke(new THREE.Vector3(cx + Math.sin(t * 3) * 1.5, h + 2.5, cz), 1, 0x3a3230, 1.4, 2.2, 3); });
  }
}

// Bölüm çıkışı: parlayan kapı + girince bölüm biter
export function portal(L, x, z, { y = 0, color = 0xff3010, glowColor = 0xff5020, w = 8, h = 10 } = {}) {
  const pm = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  pm.position.set(x, y + h / 2, z);
  L.scene.add(pm);
  const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: L.T.glow, color: glowColor, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  glow.position.set(x, y + h / 2, z + 1.1);
  glow.scale.set(w * 1.7, h * 1.6, 1);
  L.scene.add(glow);
  L.animated.push((t) => { pm.material.opacity = 0.7 + Math.sin(t * 3) * 0.15; glow.material.rotation = t * 0.3; });
  L.lamps.push({ pos: new THREE.Vector3(x, y + h / 2, z + 3), color: glowColor, power: 1.6 });
  L.trigger([x - w / 2, y, z - 0.5, x + w / 2, y + h, z + 2.5], () => L.game.levelComplete());
}
