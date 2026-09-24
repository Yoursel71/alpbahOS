// Bölüm düzenleri için ortak yardımcılar: kapı boşluklu duvarlar ve odalar.
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
