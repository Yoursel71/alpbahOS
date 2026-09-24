// 0-2 "KIYMA MAKİNESİ": et ve öğütücülerle dolu mezbaha. Öğütücü çukurlu kasap salonu,
// kayarak geçilen koridor + dükkân, iki katlı kıyma çukuru arenası, çıkış deliği.
import { room, floorWithHoles, pit, pillar, spires } from './common.js';

export function buildLevel02(L) {
  L.theme = {
    ...L.theme,
    fog: 0x2a0410, fogNear: 26, fogFar: 130,
    skyTop: [0.03, 0.0, 0.02], skyHor: [0.28, 0.02, 0.07], skyCloud: [0.22, 0.02, 0.06], skyGlow: [0.4, 0.03, 0.1],
    hemiSky: 0xff9aa8, hemiGround: 0x3a0a18, hemi: 1.8, ambient: 0x5a2838, sun: 0xff7a90,
  };
  L.spawn = { pos: [0, 30, 10], yaw: 0, checkpoint: [0, 0, 10] };
  L.menuCam = { target: [0, 2, -32], radius: 13, height: 6 };
  L.decor = [['filth', [-7, 0, -22], 0.5], ['filth', [8, 0, -40], -0.4], ['schism', [-9, 0, -44], 0.3], ['stray', [15, 4, -30], -1.2], ['filth', [6, 0, -22], -0.6]];

  // ===== Giriş odası (x -8..8, z 0..16), gökten düşülür =====
  room(L, -8, 0, 8, 16, { h: 12, mat: 'meat', gaps: { n: [-3, 3, 6] } });
  L.box(-8, 11.4, 11, 8, 12, 12, 'metal', { solid: false });
  L.meatHook(-4, 11.4, 11.5, 2.5);
  L.meatHook(3, 11.4, 11.5, 3.5);
  L.brazier(-6, 0, 14);
  L.brazier(6, 0, 14);
  L.sigil(0, 0, 9, 7);
  L.skulls(5, 0, 3, 5);
  L.shop(-6.4, 0, 6, Math.PI / 2);
  L.hint([-7, 0, 1, 7, 3, 15], '0-2: KIYMA MAKİNESİ. Yeşil terminal DÜKKÂN — stil puanın (P) ile silah al. Sonra kuzeye ilerle.', 8);

  // ===== Koridor 1 (x -3..3, z -14..0) + öğütücü çukuru (z -9..-4) =====
  L.box(-4, -2, -4, 4, 0, -1, 'tiles');
  L.box(-4, -2, -13, 4, 0, -9, 'tiles');
  pit(L, -3, -9, 3, -4, { depth: 8, dmg: 20 });
  L.grinder(0, -3.2, -6.5, 6, 'x', 0.8);
  L.box(-4, 0, -14, -3, 7, 0, 'meat');
  L.box(3, 0, -14, 4, 7, 0, 'meat');
  L.box(-4, 7, -14, 4, 8, 0, 'rock');
  L.torch(-2.75, 4.5, -2);
  L.torch(2.75, 4.5, -12);
  L.hint([-3, 0, -3, 3, 4, -0.5], 'Öğütücüye düşme! Koşarak zıpla.', 5);

  // ===== ARENA A: Kasap salonu (x -18..18, z -50..-14), ortada öğütücü çukuru =====
  room(L, -18, -50, 18, -14, { h: 14, mat: 'meat', floor: null, gaps: { s: [-3, 3, 6], n: [-3, 3, 6] } });
  floorWithHoles(L, -19, -51, 19, -13, [[-4, -36, 4, -28]]);
  pit(L, -4, -36, 4, -28, { depth: 9, dmg: 25 });
  L.grinder(0, -3.4, -32, 8, 'x', 1.0);
  L.door('dA_in', -3, 0, -13.8, 3, 6, -13.2, { open: true });
  L.door('dA_out', -3, 0, -50.8, 3, 6, -50.2, { open: false });
  for (const [x, z] of [[-10, -22], [10, -22], [-10, -42], [10, -42]]) pillar(L, x, z, 14, 1, 'stone');
  // balkonlar
  L.box(-18, 0, -46, -12, 4, -18, 'stone');
  L.box(12, 0, -46, 18, 4, -18, 'stone');
  L.box(-12.4, 4, -46, -12, 5, -33, 'metal');
  L.box(12, 4, -30, 12.4, 5, -18, 'metal');
  L.stairsX(-30, -26, -8, -12, 0, 4, 8, 'metal');
  L.stairsX(-40, -36, 8, 12, 0, 4, 8, 'metal');
  // kirişler ve asılı etler
  for (const z of [-20, -32, -44]) L.box(-18, 13.4, z - 0.4, 18, 14, z + 0.4, 'metal', { solid: false });
  for (const [x, z, n] of [[-6, -20, 3], [5, -20, 4], [-14, -32, 5], [8, -32, 3], [-3, -44, 4], [13, -44, 5]]) L.meatHook(x, 13.4, z, n);
  // gizli 1: kuzeydoğu köşesinde yüksek çıkıntı (balkondan köşede duvar sıçraması)
  L.box(14, 8, -50, 18, 8.5, -47, 'stone');
  L.secret(16, 9.4, -48.6);
  L.brazier(-16, 0, -48);
  L.brazier(16, 0, -16);
  L.brazier(-15, 4, -20);
  L.brazier(15, 4, -44);
  L.sigil(0, 0, -21, 6);
  L.skulls(-6, 0, -48, 5);
  L.skulls(7, 0, -16, 4);

  L.arena({
    id: 'a1', name: 'KASAP SALONU',
    trigger: [-18, 0, -20, 18, 6, -15],
    lock: ['dA_in'], exits: ['dA_out'],
    waves: [
      [{ t: 'filth', p: [-8, 0, -45] }, { t: 'filth', p: [8, 0, -45] }, { t: 'filth', p: [-6, 0, -47] }, { t: 'filth', p: [6, 0, -47] }, { t: 'filth', p: [0, 0, -46] }, { t: 'filth', p: [-8, 0, -38] }, { t: 'stray', p: [-15, 4, -30] }, { t: 'stray', p: [15, 4, -34] }],
      [{ t: 'filth', p: [-10, 0, -18] }, { t: 'filth', p: [10, 0, -18] }, { t: 'filth', p: [-8, 0, -47] }, { t: 'filth', p: [8, 0, -47] }, { t: 'schism', p: [0, 0, -45] }, { t: 'stray', p: [-15, 4, -40] }, { t: 'stray', p: [15, 4, -22] }],
      [{ t: 'filth', p: [-7, 0, -40] }, { t: 'filth', p: [7, 0, -40] }, { t: 'filth', p: [-6, 0, -18] }, { t: 'filth', p: [6, 0, -18] }, { t: 'filth', p: [-2, 0, -47] }, { t: 'filth', p: [2, 0, -47] }, { t: 'schism', p: [-9, 0, -48] }, { t: 'schism', p: [9, 0, -48] }],
    ],
    onStart: (g) => g.hud.hint('KIYMA MAKİNESİ: düşmanları ortadaki öğütücüye at! Yumruk ve patlamalar geri iter.', 8),
  });

  // ===== Koridor 2 (x -3..3, z -70..-51): kayma engeli, dükkân nişi, gizli havalandırma =====
  L.box(-4, -2, -71, 4, 0, -50, 'tiles');
  L.box(-4, 0, -71, -3, 7, -63, 'meat');
  L.box(-4, 0, -59, -3, 7, -51, 'meat');
  L.box(-4, 0, -63, -3, 5, -59, 'meat');
  L.box(3, 0, -71, 4, 7, -67, 'meat');
  L.box(3, 0, -61, 4, 7, -51, 'meat');
  L.box(3, 6, -67, 4, 7, -61, 'meat');
  L.box(-4, 7, -71, 4, 8, -51, 'rock');
  L.box(-3, 1.1, -57, 3, 7, -55, 'metal');
  L.box(-3, 1.1, -57.2, 3, 1.4, -54.8, 'door', { solid: false, texScale: 6 });
  L.hint([-3, 0, -54, 3, 4, -52], 'Alçak engel — koşarken [C] ile KAY.', 5);
  // dükkân nişi (doğu)
  L.box(4, -2, -67, 9, 0, -61, 'tiles');
  L.box(8, 0, -67, 9, 6, -61, 'meat');
  L.box(4, 0, -68, 9, 6, -67, 'meat');
  L.box(4, 0, -61, 9, 6, -60, 'meat');
  L.box(4, 6, -68, 9, 7, -60, 'rock');
  L.shop(7.2, 0, -64, -Math.PI / 2);
  L.checkpoint([-3, 0, -69, 3, 4, -62], [0, 0, -66], 0);
  // gizli 2: batı duvarında yüksek havalandırma (duvar sıçramasıyla)
  L.box(-9, 4, -64, -4, 5, -58, 'metal');
  L.box(-9, 7, -64, -4, 8, -58, 'metal');
  L.box(-10, 4, -64, -9, 8, -58, 'metal');
  L.box(-9, 5, -64, -4, 7, -63, 'metal');
  L.box(-9, 5, -59, -4, 7, -58, 'metal');
  L.secret(-7.5, 5.8, -61);
  L.torch(-2.75, 4.5, -68);

  // ===== ARENA B: Kıyma çukuru (x -22..22, z -120..-71) =====
  room(L, -22, -120, 22, -71, { h: 16, mat: 'meat', floor: null, gaps: { s: [-3, 3, 6], n: [-3, 3, 6] } });
  floorWithHoles(L, -23, -121, 23, -70, [[-8, -106, 8, -86]]);
  pit(L, -8, -106, 8, -86, { depth: 10, dmg: 25 });
  L.grinder(-3.5, -3.5, -96, 18, 'z', 1.1);
  L.grinder(3.5, -3.5, -96, 18, 'z', 1.1);
  L.box(-4, -1, -100, -1, 0, -97, 'metal');
  L.box(1, -1, -95, 4, 0, -92, 'metal');
  L.door('dB_in', -3, 0, -70.8, 3, 6, -70.2, { open: true });
  L.door('dB_out', -3, 0, -120.8, 3, 6, -120.2, { open: false });
  // yüksek yollar
  L.box(-22, 0, -115, -17, 5, -76, 'stone');
  L.box(17, 0, -115, 22, 5, -76, 'stone');
  L.box(-17.4, 5, -115, -17, 6, -82, 'metal');
  L.box(17, 5, -115, 17.4, 6, -82, 'metal');
  L.stairsZ(-22, -17, -71.5, -76, 0, 5, 8, 'metal');
  L.stairsZ(17, 22, -71.5, -76, 0, 5, 8, 'metal');
  for (const [x, z] of [[-13, -80], [13, -80], [-13, -113], [13, -113]]) pillar(L, x, z, 16, 1, 'stone');
  for (const [x, z, n] of [[-12, -90, 4], [12, -100, 5], [0, -80, 3], [0, -112, 4]]) L.meatHook(x, 15.4, z, n);
  L.box(-22, 15.4, -90.4, 22, 16, -89.6, 'metal', { solid: false });
  L.box(-22, 15.4, -100.4, 22, 16, -99.6, 'metal', { solid: false });
  L.box(-22, 15.4, -80.4, 22, 16, -79.6, 'metal', { solid: false });
  L.box(-22, 15.4, -112.4, 22, 16, -111.6, 'metal', { solid: false });
  L.brazier(-20, 5, -112);
  L.brazier(20, 5, -80);
  L.brazier(-20, 0, -118);
  L.brazier(20, 0, -118);
  L.skulls(-18, 0, -74, 6);
  L.skulls(19, 5, -100, 4);

  L.arena({
    id: 'a2', name: 'KIYMA ÇUKURU',
    trigger: [-22, 0, -76, 22, 6, -72],
    lock: ['dB_in'], exits: ['dB_out'],
    waves: [
      [{ t: 'schism', p: [-12, 0, -110] }, { t: 'schism', p: [12, 0, -110] }, { t: 'filth', p: [-15, 0, -90] }, { t: 'filth', p: [15, 0, -90] }, { t: 'filth', p: [-15, 0, -116] }, { t: 'filth', p: [15, 0, -116] }],
      [{ t: 'stray', p: [-19.5, 5, -100] }, { t: 'stray', p: [19.5, 5, -100] }, { t: 'stray', p: [-19.5, 5, -86] }, { t: 'stray', p: [19.5, 5, -86] }, { t: 'filth', p: [0, 0, -112] }, { t: 'filth', p: [-12, 0, -82] }, { t: 'filth', p: [12, 0, -82] }, { t: 'filth', p: [0, 0, -116] }],
      [{ t: 'schism', p: [-14, 0, -100] }, { t: 'schism', p: [14, 0, -100] }, { t: 'stray', p: [-19.5, 5, -110] }, { t: 'stray', p: [19.5, 5, -110] }, { t: 'filth', p: [-10, 0, -116] }, { t: 'filth', p: [10, 0, -116] }, { t: 'filth', p: [-15, 0, -84] }, { t: 'filth', p: [15, 0, -84] }, { t: 'filth', p: [0, 0, -116] }, { t: 'filth', p: [-4, 0, -112] }],
    ],
    onStart: (g) => g.hud.hint('Yüksek yollardaki Stray\'lere dikkat. Çukurun üstündeki platformlar kısa yol!', 8),
    onClear: (g) => g.schedule(1.5, () => g.hud.hint('Kuzey kapısı açıldı — çıkış deliğine atla!', 7)),
  });

  // ===== Çıkış odası (x -6..6, z -134..-121) =====
  room(L, -6, -134, 6, -121, { h: 10, mat: 'meat', floor: null, skip: ['s'] });
  floorWithHoles(L, -7, -135, 7, -121, [[-3, -130, 3, -124]]);
  L.exitHatch('hatch', -3, -130, 3, -124);
  L.trigger([-6, 0, -123, 6, 5, -121], () => L.doors.hatch.open());
  L.brazier(-4.5, 0, -132.5);
  L.brazier(4.5, 0, -132.5);
  L.sigil(0, 0, -127, 8);

  spires(L, [[-60, 0, 60, 6], [60, -30, 70, 7], [-70, -80, 80, 8], [70, -110, 55, 6], [-50, -150, 65, 7], [40, -170, 75, 8], [0, 60, 60, 6]]);
  L.finalize();
}
