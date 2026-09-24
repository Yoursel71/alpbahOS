// 1-3 "KUTSAL KALINTILAR SALONU": altın süslü beyaz mermer salonlar. Heykeller galerisinde
// karışık dalgalar, ardından kalıntı salonunda mini boss HIDEOUS MASS. Çıkış: yerdeki kapak.
import * as THREE from 'three';
import { room, pillar, spires, floorWithHoles, LIMBO } from './common.js';

export function buildLevel13(L) {
  L.theme = {
    ...LIMBO,
    fog: 0xc8c0b0, fogNear: 34, fogFar: 160,
    hemiSky: 0xfff4e0, hemiGround: 0x6a6048, hemi: 2.2, ambient: 0x8a8070,
  };
  L.spawn = { pos: [0, 24, 14], yaw: 0, checkpoint: [0, 0, 14] };
  L.menuCam = { target: [0, 3, -94], radius: 17, height: 6 };
  L.decor = [['hideousmass', [0, 0, -96], 0]];

  // ===== Giriş revakı (x -8..8, z 0..22) =====
  room(L, -8, 0, 8, 22, { h: 10, mat: 'marble', floor: 'tiles', skip: ['n'] });
  L.shop(6.4, 0, 12, -Math.PI / 2);
  for (const z of [4, 18]) { L.statue(-6, 0, z, 1, 'gold'); }
  L.hint([-7, 0, 1, 7, 3, 21], '1-3: KUTSAL KALINTILAR SALONU. Salonların sonunda kocaman bir şey kıpırdıyor.', 7);

  // ===== ARENA A: Heykeller galerisi (x -20..20, z -46..-1) =====
  room(L, -20, -46, 20, -1, { h: 16, mat: 'marble', floor: 'tiles', ceil: 'castle', gaps: { s: [-4, 4, 8], n: [-4, 4, 8] } });
  L.door('dA_in', -4, 0, -0.8, 4, 8, -0.2, { open: true });
  L.door('dA_out', -4, 0, -46.8, 4, 8, -46.2, { open: false });
  for (const z of [-10, -22, -34]) {
    L.statue(-15, 0, z, 1.4, 'marble');
    L.statue(15, 0, z, 1.4, 'marble');
    pillar(L, -9, z - 5, 16, 1, 'marble');
    pillar(L, 9, z - 5, 16, 1, 'marble');
  }
  L.box(-5, 0, -28, 5, 2, -18, 'castle');
  L.stairsZ(-2, 2, -14, -18, 0, 2, 4, 'gold');
  L.box(-2, 2, -24, 2, 2.4, -22, 'gold');
  L.chain(0, 15.9, -12, 7);
  L.chain(0, 15.9, -38, 7);
  for (const [x, z] of [[-18, -3], [18, -3], [-18, -44], [18, -44]]) L.brazier(x, 0, z);
  // gizli 1: platformdaki altın kaidenin üstü
  L.secret(0, 3.6, -23);
  L.arena({
    id: 'a1', name: 'HEYKELLER GALERİSİ',
    trigger: [-20, 0, -8, 20, 6, -2],
    lock: ['dA_in'], exits: ['dA_out'],
    waves: [
      [{ t: 'stray', p: [-12, 0, -40] }, { t: 'stray', p: [12, 0, -40] }, { t: 'streetcleaner', p: [3, 2, -26] }, { t: 'filth', p: [-6, 0, -42] }, { t: 'filth', p: [6, 0, -42] }],
      [{ t: 'drone', p: [-10, 9, -30] }, { t: 'drone', p: [10, 9, -30] }, { t: 'drone', p: [0, 11, -40] }, { t: 'schism', p: [-14, 0, -42] }, { t: 'schism', p: [14, 0, -42] }],
      [{ t: 'maliciousface', p: [0, 10, -36] }, { t: 'streetcleaner', p: [-14, 0, -40] }, { t: 'streetcleaner', p: [14, 0, -40] }],
    ],
  });

  // ===== Koridor: altın köprü (x -5..5, z -70..-47) =====
  L.box(-6, 0, -70, -5, 10, -47, 'marble');
  L.box(5, 0, -70, 6, 10, -47, 'marble');
  L.box(-5, 10, -70, 5, 11, -47, 'castle');
  floorWithHoles(L, -5, -70, 5, -47, [[-5, -62, 5, -55]], { mat: 'tiles' });
  L.box(-5, -12, -62, 5, -10, -55, 'meat');
  L.box(-6, -12, -62, -5, 0, -55, 'marble');
  L.box(5, -12, -62, 6, 0, -55, 'marble');
  L.box(-5, -12, -63, 5, 0, -62, 'marble');
  L.box(-5, -12, -55, 5, 0, -54, 'marble');
  L.hurt([-5, -14, -62, 5, -1.5, -55], 25, 'pit');
  L.box(-0.8, -0.4, -62, 0.8, 0, -55, 'gold');
  L.hint([-5, 0, -52, 5, 4, -48], 'Dar altın kiriş. Düşersen et yığınına...', 5);
  L.checkpoint([-5, 0, -70, 5, 4, -64], [0, 0, -67], 0);
  L.shop(-3.4, 0, -68, Math.PI / 2);

  // ===== BOSS: Kalıntı salonu (x -24..24, z -118..-71) =====
  room(L, -24, -118, 24, -71, { h: 22, mat: 'marble', floor: null, gaps: { s: [-4, 4, 8] } });
  floorWithHoles(L, -25, -119, 25, -70, [[-3, -114, 3, -108]], { mat: 'tiles' });
  L.exitHatch('hatch', -3, -114, 3, -108);
  L.door('dC_in', -4, 0, -70.8, 4, 8, -70.2, { open: true });
  for (const [x, z] of [[-16, -80], [16, -80], [-16, -104], [16, -104]]) pillar(L, x, z, 22, 1.4, 'marble');
  L.box(-24, 0, -96, -20, 5, -86, 'castle');
  L.box(20, 0, -96, 24, 5, -86, 'castle');
  L.box(-10, 0, -98, -7, 2, -95, 'gold');
  L.box(7, 0, -84, 10, 2, -81, 'gold');
  L.sigil(0, 0, -94, 16);
  for (const [x, z] of [[-22, -73], [22, -73], [-22, -116], [22, -116]]) L.brazier(x, 0, z);
  L.lamps.push({ pos: new THREE.Vector3(0, 12, -94), color: 0xffe0b0, power: 1.2 });
  L.secret(-22, 6.4, -91);
  L.arena({
    id: 'boss', name: 'HIDEOUS MASS',
    bossSub: 'KUTSAL KALINTI',
    trigger: [-24, 0, -78, 24, 8, -72],
    lock: ['dC_in'], exits: [],
    boss: true,
    waves: [[{ t: 'hideousmass', p: [0, 0, -96] }, { t: 'drone', p: [-12, 8, -104] }, { t: 'drone', p: [12, 8, -104] }]],
    onStart: (g) => g.hud.hint('HIDEOUS MASS: yukarı fırlattığı küreler düştüğü yerde patlar — hareket et! Zıpkını PARRY yap. Yakınsan kuyruğunu vurur: ZIPLA.', 11),
    onClear: (g) => g.onBossDefeated('KALINTI TEMİZLENDİ', () => {
      L.doors.hatch.open();
      g.hud.hint('Çıkış açıldı — ortadaki DELİĞE atla!', 8);
    }),
  });

  spires(L, [[-70, 10, 60, 7], [70, -30, 70, 8], [-80, -100, 80, 8], [75, -130, 60, 7], [0, -190, 90, 9]]);
  L.finalize();
}
