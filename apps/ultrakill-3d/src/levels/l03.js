// 0-3 "ÇİFTE BELA": tozlu harabeler. Açık avluda ilk Malicious Face, lav nehri geçişi,
// yanık tapınak (iki Malicious Face), son dükkân ve iki Swordsmachine ile boss dövüşü.
import { room, floorWithHoles, pillar, spires } from './common.js';

export function buildLevel03(L) {
  L.theme = {
    ...L.theme,
    fog: 0x3a1a08, fogNear: 34, fogFar: 170,
    skyTop: [0.08, 0.02, 0.0], skyHor: [0.48, 0.2, 0.06], skyCloud: [0.36, 0.15, 0.04], skyGlow: [0.62, 0.26, 0.05],
    hemiSky: 0xffc088, hemiGround: 0x4a2410, hemi: 1.9, ambient: 0x6a4028, sun: 0xffb070,
  };
  L.spawn = { pos: [0, 30, 14], yaw: 0, checkpoint: [0, 0, 14] };
  L.menuCam = { target: [0, 3, -24], radius: 16, height: 7 };
  L.decor = [['maliciousface', [0, 8, -30], 0], ['filth', [-8, 0, -12], 0.4], ['schism', [4, 2, -22], -0.2], ['stray', [-14, 0, -36], 0.8]];

  // ===== Giriş avlusu (x -10..10, z 0..20) =====
  room(L, -10, 0, 10, 20, { h: 8, mat: 'ruin', floor: null, skip: ['n'] });
  L.box(-11, -2, 0, 11, 0, 21, 'tiles');
  L.shop(8.4, 0, 8, -Math.PI / 2);
  for (const [x, z, h] of [[-7, 16, 5], [-7, 4, 3.5], [3, 17, 6]]) pillar(L, x, z, h, 0.7, 'ruin');
  L.brazier(-7.5, 0, 10);
  L.brazier(7.5, 0, 16);
  L.skulls(-3, 0, 18, 5);
  L.hint([-9, 0, 1, 9, 3, 19], '0-3: ÇİFTE BELA. Dükkân burada. İleride yeni bir düşman seni bekliyor.', 7);

  // ===== ARENA A: Avlu (x -24..24, z -44..-1), üstü açık =====
  room(L, -24, -44, 24, -1, { h: 10, mat: 'ruin', floor: 'tiles', gaps: { s: [-4, 4, 8], n: [-4, 4, 8] } });
  L.door('dA_in', -4, 0, -0.8, 4, 8, -0.2, { open: true });
  L.door('dA_out', -4, 0, -44.8, 4, 8, -44.2, { open: false });
  L.box(-6, 0, -28, 6, 2, -16, 'ruin');
  L.stairsZ(-2, 2, -12, -16, 0, 2, 4, 'ruin');
  L.stairsZ(-2, 2, -32, -28, 0, 2, 4, 'ruin');
  L.sigil(0, 2, -22, 8);
  for (const [x, z, h] of [[-16, -8, 7], [16, -8, 9], [-16, -22, 5], [16, -22, 10], [-16, -36, 8], [16, -36, 6]]) pillar(L, x, z, h, 1, 'ruin');
  L.box(-10, 0, -39, -2, 1.5, -37.5, 'ruin'); // devrilmiş sütun
  // gizli 1: doğu duvarına yaslı sütunun tepesi (köşede duvar sıçraması)
  pillar(L, 23, -12, 7, 1, 'ruin');
  L.secret(23, 8.4, -12);
  L.brazier(-22, 0, -42);
  L.brazier(22, 0, -42);
  L.brazier(-22, 0, -3);
  L.brazier(22, 0, -3);
  L.skulls(-20, 0, -26, 5);
  L.skulls(19, 0, -18, 4);

  L.arena({
    id: 'a1', name: 'AVLU',
    trigger: [-24, 0, -8, 24, 6, -2],
    lock: ['dA_in'], exits: ['dA_out'],
    waves: [
      [{ t: 'maliciousface', p: [0, 8, -34] }, { t: 'filth', p: [-14, 0, -30] }, { t: 'filth', p: [14, 0, -30] }, { t: 'filth', p: [-10, 0, -42] }, { t: 'filth', p: [10, 0, -42] }],
      [{ t: 'stray', p: [-18, 0, -40] }, { t: 'stray', p: [18, 0, -40] }, { t: 'schism', p: [0, 2, -22] }, { t: 'filth', p: [-20, 0, -12] }, { t: 'filth', p: [20, 0, -12] }, { t: 'filth', p: [-6, 0, -42] }, { t: 'filth', p: [6, 0, -42] }],
    ],
    onWave: (g, w) => {
      if (w === 0) g.hud.titleCard('<div class="tc-layer">YENİ DÜŞMAN</div><div class="tc-name">MALICIOUS FACE</div>', 2.6);
    },
    onStart: (g) => g.hud.hint('MALICIOUS FACE: gözlerine nişan al (zayıf nokta). Kırmızı ışın kilitlenince beyazlar — o an [SHIFT] ile ATIL! Turuncu küreleri PARRY yap.', 11),
  });

  // ===== Koridor 1: lav nehri (x -4..4, z -64..-45) =====
  L.box(-5, -3, -64, -4, 8, -45, 'ruin');
  L.box(4, -3, -64, 5, 8, -45, 'ruin');
  L.box(-4, -2, -49, 4, 0, -45, 'tiles');
  L.box(-4, -2, -64, 4, 0, -60, 'tiles');
  L.box(-4, -3, -60, 4, -1.5, -49, 'rock');
  L.lavaPlane(-4, -60, 4, -49, -1.0);
  L.hurt([-4, -1.6, -60, 4, -0.8, -49], 22, 'lava');
  L.box(-2, -1.5, -52.5, 0.5, 0.5, -50.5, 'rock');
  L.box(0, -1.5, -56, 2.5, 0.8, -54, 'rock');
  L.box(-2.5, -1.5, -59.5, 0, 0.5, -57.5, 'rock');
  L.torch(-3.75, 5, -47);
  L.torch(3.75, 5, -62);
  L.hint([-4, 0, -49, 4, 4, -45.5], 'Lav nehri — taşlardan atla.', 5);
  L.checkpoint([-4, 0, -64, 4, 4, -61], [0, 0, -62.5], 0);

  // ===== ARENA B: Yanık tapınak (x -20..20, z -104..-65) =====
  room(L, -20, -104, 20, -65, { h: 18, mat: 'ruin', ceil: 'rock', gaps: { s: [-4, 4, 8], n: [-4, 4, 8] } });
  L.door('dB_in', -4, 0, -64.8, 4, 8, -64.2, { open: true });
  L.door('dB_out', -4, 0, -104.8, 4, 8, -104.2, { open: false });
  L.box(-20, 0, -100, -14, 6, -70, 'ruin');
  L.box(14, 0, -100, 20, 6, -70, 'ruin');
  L.stairsX(-74, -70, -10, -14, 0, 6, 10, 'metal');
  L.stairsX(-100, -96, 10, 14, 0, 6, 10, 'metal');
  L.box(-14.4, 6, -100, -14, 7, -76, 'metal');
  L.box(14, 6, -94, 14.4, 7, -70, 'metal');
  for (const [x, z] of [[-8, -75], [8, -75], [-8, -95], [8, -95]]) pillar(L, x, z, 18, 1, 'ruin');
  L.statue(-12, 0, -101.5, 1.4);
  L.statue(12, 0, -101.5, 1.4);
  L.sigil(0, 0, -86, 10);
  L.brazier(-18, 6, -72);
  L.brazier(18, 6, -98);
  L.brazier(-18, 0, -103);
  L.brazier(18, 0, -103);
  L.chain(-19.8, 17, -85, 9);
  L.chain(19.8, 17, -80, 8);

  L.arena({
    id: 'a2', name: 'YANIK TAPINAK',
    trigger: [-20, 0, -70, 20, 6, -66],
    lock: ['dB_in'], exits: ['dB_out'],
    waves: [
      [{ t: 'schism', p: [-10, 0, -98] }, { t: 'schism', p: [10, 0, -98] }, { t: 'stray', p: [-17, 6, -85] }, { t: 'stray', p: [17, 6, -85] }, { t: 'stray', p: [0, 0, -100] }],
      [{ t: 'maliciousface', p: [-8, 9, -88] }, { t: 'maliciousface', p: [8, 9, -88] }, { t: 'filth', p: [-16, 0, -102] }, { t: 'filth', p: [16, 0, -102] }, { t: 'filth', p: [-4, 0, -102] }, { t: 'filth', p: [4, 0, -102] }],
    ],
    onStart: (g) => g.hud.hint('Sütunları siper al. Galerilerden ateş eden Stray\'leri önce indir.', 7),
  });

  // ===== Koridor 2 + dükkân nişi (x -4..4, z -118..-105) =====
  L.box(-4, -2, -118, 4, 0, -105, 'tiles');
  L.box(-5, 0, -118, -4, 8, -114, 'ruin');
  L.box(-5, 0, -108, -4, 8, -105, 'ruin');
  L.box(-5, 6, -114, -4, 8, -108, 'ruin');
  L.box(4, 0, -118, 5, 8, -105, 'ruin');
  L.box(-5, 8, -118, 5, 9, -105, 'rock');
  L.box(-10, -2, -114, -4, 0, -108, 'tiles');
  L.box(-11, 0, -114, -10, 6, -108, 'ruin');
  L.box(-11, 0, -115, -5, 6, -114, 'ruin');
  L.box(-11, 0, -108, -5, 6, -107, 'ruin');
  L.box(-11, 6, -115, -5, 7, -107, 'rock');
  L.shop(-8.8, 0, -111, Math.PI / 2);
  L.torch(3.75, 5, -111);
  L.checkpoint([-4, 0, -117, 4, 4, -113], [0, 0, -115], 0);
  L.hint([-4, 0, -110, 4, 4, -106], 'Son dükkân. İleride İKİ Swordsmachine var — donan!', 7);

  // ===== BOSS: Çifte bela (x -22..22, z -164..-119) =====
  room(L, -22, -164, 22, -119, { h: 16, mat: 'ruin', floor: null, gaps: { s: [-4, 4, 8] } });
  floorWithHoles(L, -23, -165, 23, -118, [[-3, -144, 3, -138]]);
  L.exitHatch('hatch', -3, -144, 3, -138);
  L.door('dC_in', -4, 0, -118.8, 4, 8, -118.2, { open: true });
  for (const [x, z] of [[-12, -128], [12, -128], [-12, -156], [12, -156]]) pillar(L, x, z, 16, 1.2, 'ruin');
  L.box(-9, 0, -136, -6, 1.5, -133, 'metal');
  L.box(6, 0, -149, 9, 1.5, -146, 'metal');
  L.sigil(0, 0, -150, 12);
  L.brazier(-20, 0, -162);
  L.brazier(20, 0, -162);
  L.brazier(-20, 0, -121);
  L.brazier(20, 0, -121);
  L.skulls(-18, 0, -140, 6);
  L.skulls(18, 0, -132, 6);

  L.arena({
    id: 'boss', name: 'SWORDSMACHINE ×2',
    bossSub: 'ÇİFTE BELA',
    trigger: [-22, 0, -126, 22, 8, -121],
    lock: ['dC_in'], exits: [],
    boss: true,
    waves: [[{ t: 'swordsmachine', p: [-8, 0, -156] }, { t: 'swordsmachine', p: [8, 0, -156] }]],
    onClear: (g) => g.onBossDefeated('İKİ MAKİNE DE HURDA', () => {
      L.doors.hatch.open();
      g.hud.hint('Çıkış açıldı — ortadaki DELİĞE atla!', 8);
    }),
  });

  spires(L, [[-70, 10, 70, 7], [70, -20, 60, 6], [-80, -80, 90, 8], [75, -110, 70, 7], [-60, -170, 80, 8], [50, -200, 65, 6], [0, 70, 60, 7]]);
  L.finalize();
}
