// 1-1 "GÜNDOĞUMUNUN KALBİ": ARAF'ın çimenli kale bahçeleri. Kale avlusunda ilk Drone'lar,
// hendek üstündeki dar köprü, kule salonunda karışık dalgalar ve altın çıkış kapısı.
import { room, pillar, spires, pit, tree, portal, LIMBO } from './common.js';

export function buildLevel11(L) {
  L.theme = { ...LIMBO };
  L.spawn = { pos: [0, 30, 16], yaw: 0, checkpoint: [0, 0, 16] };
  L.menuCam = { target: [0, 4, -22], radius: 18, height: 7 };
  L.decor = [['drone', [0, 7, -24], 0], ['drone', [-6, 5, -18], 0.3], ['stray', [8, 0, -28], -0.4], ['filth', [-9, 0, -14], 0.5]];

  // ===== Giriş bahçesi (x -10..10, z 0..24) =====
  room(L, -10, 0, 10, 24, { h: 8, mat: 'castle', floor: 'grass', skip: ['n'] });
  L.shop(8.4, 0, 10, -Math.PI / 2);
  tree(L, -6, 18, 5);
  tree(L, -6, 6, 4);
  tree(L, 4, 20, 6);
  L.statue(0, 0, 3, 1.1, 'castle');
  L.hint([-9, 0, 1, 9, 3, 23], 'KATMAN 1: ARAF. Güneşli bahçeler aldatmasın. Dükkân sağda.', 7);

  // ===== ARENA A: Kale avlusu (x -22..22, z -42..-1) =====
  room(L, -22, -42, 22, -1, { h: 12, mat: 'castle', floor: 'grass', gaps: { s: [-4, 4, 8], n: [-4, 4, 8] } });
  L.door('dA_in', -4, 0, -0.8, 4, 8, -0.2, { open: true });
  L.door('dA_out', -4, 0, -42.8, 4, 8, -42.2, { open: false });
  // ortada çeşme
  L.box(-4, 0, -25, 4, 1.2, -17, 'castleDark');
  L.box(-1, 1.2, -22, 1, 4.5, -20, 'castle');
  L.box(-2, 4.5, -23, 2, 5, -19, 'gold');
  // yan teraslar ve merdivenler
  L.box(-22, 0, -36, -15, 3, -8, 'castle');
  L.stairsX(-14, -10, -11, -15, 0, 3, 5, 'castleDark');
  L.box(15, 0, -36, 22, 3, -8, 'castle');
  L.stairsX(-36, -32, 11, 15, 0, 3, 5, 'castleDark');
  for (const [x, z] of [[-20, -3], [20, -3], [-20, -40], [20, -40]]) pillar(L, x, z, 16, 1.4, 'castle');
  for (const [x, z] of [[-9, -32], [9, -12]]) tree(L, x, z, 5);
  // gizli 1: güneydoğu kulesinin tepesi (terastan duvar sıçraması)
  L.secret(20, 17.6, -40);
  L.arena({
    id: 'a1', name: 'KALE AVLUSU',
    trigger: [-22, 0, -8, 22, 6, -2],
    lock: ['dA_in'], exits: ['dA_out'],
    waves: [
      [{ t: 'filth', p: [-12, 0, -30] }, { t: 'filth', p: [12, 0, -30] }, { t: 'filth', p: [-6, 0, -38] }, { t: 'filth', p: [6, 0, -38] }, { t: 'stray', p: [-18, 3, -24] }, { t: 'stray', p: [18, 3, -24] }],
      [{ t: 'drone', p: [-13, 7, -26] }, { t: 'drone', p: [10, 6, -30] }, { t: 'drone', p: [0, 8, -36] }, { t: 'filth', p: [-8, 0, -12] }, { t: 'filth', p: [14, 0, -14] }],
      [{ t: 'schism', p: [0, 0, -36] }, { t: 'stray', p: [-18, 3, -30] }, { t: 'stray', p: [18, 3, -30] }, { t: 'drone', p: [-8, 7, -16] }, { t: 'drone', p: [8, 7, -16] }],
    ],
    onWave: (g, w) => {
      if (w === 1) {
        g.hud.titleCard('<div class="tc-layer">YENİ DÜŞMAN</div><div class="tc-name">DRONE</div>', 2.6);
        g.hud.hint('DRONE: göz parlayınca iki mavi küre atar (PARRY yapılabilir). Vurulunca sana doğru DÜŞER — [F] ile yumrukla geri yolla!', 10);
      }
    },
  });

  // ===== Hendek köprüsü (x -6..6, z -66..-43) =====
  L.box(-7, 0, -66, -6, 8, -43, 'castle');
  L.box(6, 0, -66, 7, 8, -43, 'castle');
  L.box(-6, -2, -47, 6, 0, -43, 'castleDark');
  L.box(-6, -2, -66, 6, 0, -61, 'castleDark');
  pit(L, -6, -61, 6, -47, { depth: 12, mat: 'castle', bottom: 'grass' });
  L.box(-1.5, -1, -55, 1.5, 0, -47, 'castleDark');
  L.box(-1.5, -1, -61, 1.5, 0, -57, 'castleDark'); // 2 m'lik boşluk: zıpla
  L.hint([-6, 0, -47, 6, 4, -43], 'Köprü kırık — zıpla ya da atıl.', 5);
  L.checkpoint([-6, 0, -66, 6, 4, -62], [0, 0, -64], 0);

  // ===== ARENA B: Kule salonu (x -18..18, z -104..-67) =====
  room(L, -18, -104, 18, -67, { h: 18, mat: 'castle', floor: 'tiles', gaps: { s: [-4, 4, 8], n: [-4, 4, 8], w: [-84, -80, 9, 6] } });
  L.door('dB_in', -4, 0, -66.8, 4, 8, -66.2, { open: true });
  L.door('dB_out', -4, 0, -104.8, 4, 8, -104.2, { open: false });
  // balkonlar
  L.box(-18, 5, -100, -12, 6, -72, 'castleDark');
  L.box(12, 5, -100, 18, 6, -72, 'castleDark');
  L.stairsX(-76, -72, -8, -12, 0, 5, 8, 'castle');
  L.stairsX(-100, -96, 8, 12, 0, 5, 8, 'castle');
  for (const [x, z] of [[-6, -78], [6, -78], [-6, -94], [6, -94]]) pillar(L, x, z, 18, 1, 'castle');
  L.box(-3, 0, -88, 3, 1, -84, 'gold');
  L.chain(-17.8, 17, -86, 8);
  L.chain(17.8, 17, -80, 8);
  // gizli 2: batı balkonunun duvarındaki niş
  L.box(-23, 5, -85, -19, 6, -79, 'castleDark');
  L.box(-24, 5, -85, -23, 10, -79, 'castle');
  L.box(-23, 9, -85, -19, 10, -79, 'castle');
  L.box(-23, 6, -85, -19, 9, -84, 'castle');
  L.box(-23, 6, -80, -19, 9, -79, 'castle');
  L.secret(-20.2, 6.4, -82);
  L.arena({
    id: 'a2', name: 'KULE SALONU',
    trigger: [-18, 0, -73, 18, 6, -68],
    lock: ['dB_in'], exits: ['dB_out'],
    waves: [
      [{ t: 'drone', p: [-8, 8, -92] }, { t: 'drone', p: [8, 8, -92] }, { t: 'drone', p: [0, 10, -98] }, { t: 'drone', p: [0, 8, -80] }, { t: 'stray', p: [-15, 6, -90] }, { t: 'stray', p: [15, 6, -90] }],
      [{ t: 'schism', p: [-10, 0, -100] }, { t: 'schism', p: [10, 0, -90] }, { t: 'filth', p: [-4, 0, -100] }, { t: 'filth', p: [4, 0, -100] }, { t: 'filth', p: [-14, 0, -86] }, { t: 'filth', p: [14, 0, -86] }],
      [{ t: 'maliciousface', p: [0, 10, -94] }, { t: 'drone', p: [-10, 9, -84] }, { t: 'drone', p: [10, 9, -84] }, { t: 'stray', p: [-15, 6, -76] }, { t: 'stray', p: [15, 6, -76] }],
    ],
    onStart: (g) => g.hud.hint('Balkonlardaki Stray\'leri ve havadaki Drone\'ları önce indir.', 7),
  });

  // ===== Çıkış: altın kapı (x -6..6, z -122..-105) =====
  room(L, -6, -122, 6, -105, { h: 12, mat: 'castle', floor: 'grass', skip: ['s'] });
  L.box(-4.5, 0, -120.5, -3.5, 10, -119.5, 'gold');
  L.box(3.5, 0, -120.5, 4.5, 10, -119.5, 'gold');
  L.box(-4.5, 10, -120.5, 4.5, 11, -119.5, 'gold');
  portal(L, 0, -120, { color: 0xffe0a0, glowColor: 0xffd070, w: 7, h: 10 });

  spires(L, [[-70, 10, 60, 7], [70, -30, 70, 8], [-80, -90, 80, 8], [75, -120, 60, 7], [0, -180, 90, 9], [0, 70, 50, 6]]);
  L.finalize();
}
