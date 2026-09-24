// 1-2 "YANAN DÜNYA": yanmakta olan ARAF köyü. Köy meydanında ilk Streetcleaner'lar, yıkık
// sokakta tuzaklı geçiş, yanık kilisede Swordsmachine eşliğinde son saldırı.
import * as THREE from 'three';
import { room, pillar, spires, tree, house, portal, LIMBO } from './common.js';

export function buildLevel12(L) {
  L.theme = {
    ...LIMBO,
    fog: 0x9a8a80, fogNear: 30, fogFar: 170,
    skyTop: [0.22, 0.26, 0.4], skyHor: [0.78, 0.55, 0.38], skyCloud: [0.35, 0.3, 0.3], skyGlow: [1.0, 0.45, 0.15],
    hemiSky: 0xffe8d8, hemiGround: 0x5a4a38, hemi: 2.1, ambient: 0x7a6a60, sun: 0xffd0a0,
  };
  L.spawn = { pos: [0, 30, 22], yaw: 0, checkpoint: [0, 0, 22] };
  L.menuCam = { target: [0, 3, -22], radius: 17, height: 6 };
  L.decor = [['streetcleaner', [-4, 0, -20], 0.3], ['streetcleaner', [5, 0, -24], -0.3], ['drone', [0, 7, -30], 0]];

  // ===== Köy yolu (x -8..8, z 0..32) =====
  room(L, -8, 0, 8, 32, { h: 7, mat: 'castleDark', floor: 'grass', skip: ['n'] });
  L.shop(-6.4, 0, 20, Math.PI / 2);
  tree(L, 5, 26, 4);
  tree(L, 5, 8, 5);
  L.fire(-5, 0, 6, 1.6);
  L.hint([-7, 0, 1, 7, 3, 31], '1-2: YANAN DÜNYA. Köy yanıyor. Alev taşıyanlara yaklaşma.', 7);

  // ===== ARENA A: Köy meydanı (x -26..26, z -48..-1), üstü açık =====
  room(L, -26, -48, 26, -1, { h: 9, mat: 'castleDark', floor: 'grass', gaps: { s: [-4, 4, 7], n: [-4, 4, 7] } });
  L.door('dA_in', -4, 0, -0.8, 4, 7, -0.2, { open: true });
  L.door('dA_out', -4, 0, -48.8, 4, 7, -48.2, { open: false });
  house(L, -22, -14, -14, -6, { door: 'e', burning: true });
  house(L, 14, -16, 22, -8, { door: 'w', burning: true });
  house(L, -22, -40, -14, -30, { door: 'e', h: 6, burning: true });
  house(L, 14, -42, 22, -32, { door: 'w' });
  // kuyu ve devrik araba
  L.box(-2, 0, -26, 2, 1.2, -22, 'castle');
  L.box(6, 0, -30, 10, 1.4, -28, 'ruin');
  L.box(-10, 0, -20, -7, 1.6, -16, 'ruin');
  tree(L, 0, -40, 6);
  L.fire(8, 1.4, -29, 1.4);
  L.brazier(-24, 0, -3);
  L.brazier(24, 0, -3);
  // gizli 1: yanmayan evin çatısı (arabanın üstünden zıpla + duvar sıçraması)
  L.secret(18, 6.6, -37);
  L.arena({
    id: 'a1', name: 'KÖY MEYDANI',
    trigger: [-26, 0, -8, 26, 6, -2],
    lock: ['dA_in'], exits: ['dA_out'],
    waves: [
      [{ t: 'filth', p: [-10, 0, -36] }, { t: 'filth', p: [10, 0, -36] }, { t: 'filth', p: [-4, 0, -44] }, { t: 'filth', p: [4, 0, -44] }, { t: 'drone', p: [0, 7, -34] }],
      [{ t: 'streetcleaner', p: [-8, 0, -44] }, { t: 'streetcleaner', p: [8, 0, -44] }, { t: 'stray', p: [-18, 0, -24] }, { t: 'stray', p: [18, 0, -24] }],
      [{ t: 'streetcleaner', p: [-18, 0, -44] }, { t: 'streetcleaner', p: [18, 0, -26] }, { t: 'drone', p: [-10, 7, -30] }, { t: 'drone', p: [10, 7, -30] }, { t: 'schism', p: [0, 0, -44] }],
    ],
    onWave: (g, w) => {
      if (w === 1) {
        g.hud.titleCard('<div class="tc-layer">YENİ DÜŞMAN</div><div class="tc-name">STREETCLEANER</div>', 2.6);
        g.hud.hint('STREETCLEANER: yakından alev püskürtür, nişan alınca yana kaçar. SIRTINDAKİ TANKA vur — patlar! Uzak dur, atılarak kaç.', 11);
      }
    },
  });

  // ===== Yıkık sokak (x -5..5, z -80..-49): yanan kirişler =====
  L.box(-6, 0, -80, -5, 9, -49, 'castleDark');
  L.box(5, 0, -80, 6, 9, -78, 'castleDark');
  L.box(5, 0, -72, 6, 9, -49, 'castleDark');
  L.box(5, 6, -78, 6, 9, -72, 'castleDark');
  L.box(-5, -2, -80, 5, 0, -49, 'grass');
  L.box(-5, 0, -58, -1, 2.4, -57, 'ruin');
  L.box(1, 0, -64, 5, 2.4, -63, 'ruin');
  L.box(-5, 0, -71, -0.5, 2.4, -70, 'ruin');
  L.fire(-3, 2.4, -57.5, 1.2);
  L.fire(3, 2.4, -63.5, 1.2);
  L.fire(-2.7, 2.4, -70.5, 1.2);
  L.hurt([-5, 0, -58, -1, 2.6, -57], 12, 'lava');
  L.hurt([1, 0, -64, 5, 2.6, -63], 12, 'lava');
  L.hurt([-5, 0, -71, -0.5, 2.6, -70], 12, 'lava');
  L.extraEnemies.push({ trigger: [-5, 0, -60, 5, 4, -56], list: [{ t: 'drone', p: [0, 6, -74] }, { t: 'drone', p: [-3, 7, -76] }] });
  L.hint([-5, 0, -54, 5, 4, -50], 'Yanan kirişlerin üstünden atla — ateşe basma.', 5);
  L.box(-5, 9, -80, 5, 10, -49, 'ruin');
  L.checkpoint([-5, 0, -80, 5, 4, -76], [0, 0, -78], 0);
  // dükkân nişi
  L.box(5, -2, -78, 10, 0, -72, 'grass');
  L.box(10, 0, -78, 11, 6, -72, 'castleDark');
  L.box(5, 0, -79, 11, 6, -78, 'castleDark');
  L.box(5, 0, -72, 11, 6, -71, 'castleDark');
  L.box(5, 6, -79, 11, 7, -71, 'ruin');
  L.shop(9.2, 0, -75, -Math.PI / 2);

  // ===== ARENA B: Yanık kilise (x -18..18, z -122..-81) =====
  room(L, -18, -122, 18, -81, { h: 20, mat: 'castle', floor: 'tiles', gaps: { s: [-4, 4, 8], n: [-3, 3, 7] } });
  L.door('dB_in', -4, 0, -80.8, 4, 8, -80.2, { open: true });
  L.box(-18, 0, -118, -10, 4, -110, 'castleDark');
  L.box(10, 0, -118, 18, 4, -110, 'castleDark');
  L.stairsZ(-14, -10, -106, -110, 0, 4, 6, 'castle');
  L.stairsZ(10, 14, -106, -110, 0, 4, 6, 'castle');
  for (const z of [-90, -100]) { pillar(L, -9, z, 20, 1, 'castle'); pillar(L, 9, z, 20, 1, 'castle'); }
  // sıralar (siper)
  for (const z of [-88, -94, -100]) { L.box(-7, 0, z, -2, 1.1, z + 1, 'ruin'); L.box(2, 0, z, 7, 1.1, z + 1, 'ruin'); }
  L.box(-3, 0, -120, 3, 1.5, -116, 'gold'); // sunak
  L.fire(-14, 4, -114, 2);
  L.fire(14, 4, -114, 2);
  L.lamps.push({ pos: new THREE.Vector3(0, 8, -110), color: 0xff8a40, power: 1.4 });
  // çıkış: sunağın arkasındaki kapı
  L.door('dB_out', -3, 0, -122.8, 3, 7, -122.2, { open: false });
  L.arena({
    id: 'a2', name: 'YANIK KİLİSE',
    trigger: [-18, 0, -87, 18, 6, -82],
    lock: ['dB_in'], exits: ['dB_out'],
    waves: [
      [{ t: 'streetcleaner', p: [-14, 4, -114] }, { t: 'streetcleaner', p: [14, 4, -114] }, { t: 'drone', p: [0, 10, -110] }, { t: 'drone', p: [-8, 9, -104] }, { t: 'drone', p: [8, 9, -104] }],
      [{ t: 'swordsmachine', p: [0, 0, -114] }, { t: 'streetcleaner', p: [-12, 0, -96] }, { t: 'streetcleaner', p: [12, 0, -96] }],
    ],
    onWave: (g, w) => { if (w === 1) g.hud.message('SWORDSMACHINE GERİ DÖNDÜ', 2, 'big'); },
    onStart: (g) => g.hud.hint('Sıraları siper al. Streetcleaner tanklarına vur.', 7),
  });

  // ===== Çıkış (x -5..5, z -140..-123) =====
  room(L, -5, -140, 5, -123, { h: 10, mat: 'castle', floor: 'grass', skip: ['s'] });
  portal(L, 0, -138, { color: 0xffc080, glowColor: 0xffa050, w: 7, h: 9 });

  spires(L, [[-70, 10, 60, 7], [70, -30, 70, 8], [-80, -100, 80, 8], [75, -130, 60, 7], [0, -200, 90, 9]]);
  L.finalize();
}

