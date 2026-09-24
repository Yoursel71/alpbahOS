// 0-4 "TEK MAKİNELİK ORDU": kül rengi bir kolezyum. Sığınakta dükkân, ardından altı dalgalı tek
// bir büyük meydan savaşı (Malicious Face'ler ve bir Swordsmachine dahil), sonra çıkış deliği.
import { room, floorWithHoles, pillar, spires } from './common.js';

export function buildLevel04(L) {
  L.theme = {
    ...L.theme,
    fog: 0x241c1c, fogNear: 30, fogFar: 150,
    skyTop: [0.02, 0.02, 0.03], skyHor: [0.24, 0.11, 0.08], skyCloud: [0.2, 0.11, 0.08], skyGlow: [0.38, 0.13, 0.06],
    hemiSky: 0xffb098, hemiGround: 0x302020, hemi: 1.8, ambient: 0x504040, sun: 0xffa080,
  };
  L.spawn = { pos: [0, 30, 7], yaw: 0, checkpoint: [0, 0, 7] };
  L.menuCam = { target: [0, 3, -42], radius: 18, height: 8 };
  L.decor = [['swordsmachine', [0, 3, -42], 0], ['filth', [-8, 0, -30], 0.5], ['filth', [9, 0, -52], -0.6], ['maliciousface', [-12, 9, -56], 0.4], ['schism', [12, 0, -32], -0.8]];

  // ===== Sığınak (x -6..6, z 0..14) — güney duvarında kayarak girilen gizli oda =====
  room(L, -6, 0, 6, 14, { h: 14, mat: 'ash', gaps: { n: [-3, 3, 6], s: [-1, 1, 1.1] } });
  L.shop(-4.9, 0, 5, Math.PI / 2);
  L.brazier(4.5, 0, 12.5);
  L.brazier(-4.5, 0, 12.5);
  L.sigil(0, 0, 7, 6);
  L.box(-2, -2, 15, 2, 0, 19, 'tiles');
  L.box(-3, 0, 15, -2, 3, 20, 'ash');
  L.box(2, 0, 15, 3, 3, 20, 'ash');
  L.box(-3, 0, 19, 3, 3, 20, 'ash');
  L.box(-3, 3, 15, 3, 4, 20, 'ash');
  L.secret(0, 1, 17.5);
  L.hint([-5, 0, 1, 5, 3, 13], '0-4: TEK MAKİNELİK ORDU. İleride altı dalgalı tek bir meydan savaşı var. Dükkândan donan, sonra kuzeye.', 8);

  // ===== Geçit (x -3..3, z -13..-1) =====
  L.box(-4, -2, -13, 4, 0, -1, 'tiles');
  L.box(-4, 0, -13, -3, 7, -1, 'ash');
  L.box(3, 0, -13, 4, 7, -1, 'ash');
  L.box(-4, 7, -13, 4, 8, -1, 'rock');
  L.torch(-2.75, 4.5, -7);
  L.torch(2.75, 4.5, -7);
  L.checkpoint([-3, 0, -10, 3, 4, -4], [0, 0, -7], 0);

  // ===== KOLEZYUM (x -28..28, z -72..-14) =====
  room(L, -28, -72, 28, -14, { h: 16, mat: 'ash', gaps: { s: [-3, 3, 6], n: [-3, 3, 6] } });
  L.door('dA_in', -3, 0, -13.8, 3, 6, -13.2, { open: true });
  L.door('dA_out', -3, 0, -72.8, 3, 6, -72.2, { open: false });
  // dört köşede lav havuzu (zemin üstünde sığ lav: bas, zıpla)
  for (const [x0, z0] of [[-24, -68], [16, -68], [-24, -25], [16, -25]]) {
    L.lavaPlane(x0, z0, x0 + 8, z0 + 8, 0.06);
    L.hurt([x0, -0.5, z0, x0 + 8, 0.6, z0 + 8], 20, 'lava');
  }
  // orta platform + merdivenler
  L.box(-5, 0, -47, 5, 3, -37, 'metal');
  L.stairsZ(-2, 2, -33, -37, 0, 3, 6, 'metal');
  L.stairsZ(-2, 2, -51, -47, 0, 3, 6, 'metal');
  L.sigil(0, 3, -42, 8);
  // yan yürüyüş yolları
  L.box(-28, 0, -60, -22, 5, -30, 'ash');
  L.box(22, 0, -60, 28, 5, -30, 'ash');
  L.stairsX(-34, -30, -18, -22, 0, 5, 8, 'metal');
  L.stairsX(-32, -28, 18, 22, 0, 5, 8, 'metal');
  L.box(-22.4, 5, -60, -22, 6, -36, 'metal');
  L.box(22, 5, -60, 22.4, 6, -34, 'metal');
  for (const [x, z] of [[-14, -21], [14, -21], [-14, -63], [14, -63], [-18, -42], [18, -42]]) pillar(L, x, z, 16, 1, 'ash');
  // gizli 2: yürüyüş yolunun ucundaki yüksek sütun (çakış sıçrayışıyla)
  L.box(-28, 0, -68, -22, 5, -60, 'ash');
  pillar(L, -24.5, -64, 9, 1, 'ash');
  L.secret(-24.5, 10.4, -64);
  L.brazier(-26, 5, -32);
  L.brazier(26, 5, -58);
  L.brazier(-8, 0, -70);
  L.brazier(8, 0, -70);
  L.chain(-27.8, 15, -45, 9);
  L.chain(27.8, 15, -40, 8);
  L.skulls(-6, 0, -16, 6);
  L.skulls(6, 3, -44, 3);

  const P = (t, x, y, z) => ({ t, p: [x, y, z] });
  L.arena({
    id: 'army', name: 'KOLEZYUM',
    trigger: [-27, 0, -20, 27, 6, -15],
    lock: ['dA_in'], exits: ['dA_out'],
    waves: [
      [P('filth', -10, 0, -30), P('filth', 10, 0, -30), P('filth', -10, 0, -54), P('filth', 10, 0, -54), P('filth', 0, 3, -42), P('filth', -12, 0, -66), P('filth', 12, 0, -66), P('filth', 0, 0, -66)],
      [P('stray', -25, 5, -45), P('stray', 25, 5, -45), P('stray', -25, 5, -35), P('stray', 25, 5, -55), P('schism', -8, 0, -64), P('schism', 8, 0, -64)],
      [P('maliciousface', -12, 9, -56), P('maliciousface', 12, 9, -56), P('filth', -16, 0, -40), P('filth', 16, 0, -40), P('filth', -6, 0, -60), P('filth', 6, 0, -60)],
      [P('schism', -12, 0, -50), P('schism', 12, 0, -50), P('schism', 0, 0, -64), P('stray', -25, 5, -52), P('stray', 25, 5, -38), P('stray', 0, 3, -42)],
      [P('swordsmachine', 0, 0, -64), P('filth', -16, 0, -28), P('filth', 15, 0, -27), P('filth', -18, 0, -56), P('filth', 18, 0, -56)],
      [P('maliciousface', -14, 9, -34), P('maliciousface', 14, 9, -50), P('schism', -10, 0, -64), P('schism', 10, 0, -64), P('stray', -25, 5, -40), P('stray', 25, 5, -48), P('stray', -8, 0, -30), P('stray', 8, 0, -30), P('filth', -4, 3, -42), P('filth', 4, 3, -42), P('filth', -20, 0, -46), P('filth', 20, 0, -46)],
    ],
    onStart: (g) => g.hud.hint('MEYDAN SAVAŞI: 6 dalga, arada nefes yok. Hareket etmeyi bırakma, köşelerdeki lava dikkat!', 8),
    onWave: (g, w) => g.hud.message(`DALGA ${w + 1} / 6`, 1.4, w === 5 ? 'big' : ''),
    onClear: (g) => { g.hud.message('ORDU DAĞITILDI', 2.2, 'big'); g.schedule(1.5, () => g.hud.hint('Kuzey kapısı açıldı — çıkış deliğine atla!', 7)); },
  });

  // ===== Çıkış odası (x -6..6, z -86..-73) =====
  room(L, -6, -86, 6, -73, { h: 10, mat: 'ash', floor: null, skip: ['s'] });
  floorWithHoles(L, -7, -87, 7, -73, [[-3, -82, 3, -76]]);
  L.exitHatch('hatch', -3, -82, 3, -76);
  L.trigger([-6, 0, -75, 6, 5, -73], () => L.doors.hatch.open());
  L.brazier(-4.5, 0, -84.5);
  L.brazier(4.5, 0, -84.5);

  spires(L, [[-70, 0, 75, 7], [70, -20, 65, 6], [-80, -70, 85, 8], [80, -80, 70, 7], [-50, -130, 70, 7], [40, -140, 80, 8], [0, 60, 60, 6]]);
  L.finalize();
}
