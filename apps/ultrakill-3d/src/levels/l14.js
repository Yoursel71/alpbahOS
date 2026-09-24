// 1-4 "AY IŞIĞI": ay ışığında sessiz bir kale bahçesi ve yuvarlak düello meydanı. Boss: V2.
// V2 yenilince kolunu koparırsın: KNUCKLEBLASTER bedava, V2 oynanabilir karakter olur.
import * as THREE from 'three';
import { room, pillar, spires, tree, portal, LIMBO } from './common.js';
import { progress, saveProgress } from '../settings.js';

export function buildLevel14(L) {
  L.theme = {
    ...LIMBO,
    fog: 0x141a30, fogNear: 30, fogFar: 150,
    skyTop: [0.0, 0.01, 0.04], skyHor: [0.06, 0.08, 0.18], skyCloud: [0.12, 0.14, 0.22], skyGlow: [0.35, 0.4, 0.6],
    hemiSky: 0xb8c8ff, hemiGround: 0x283048, hemi: 2.4, ambient: 0x505a80, sun: 0xc8d4ff,
  };
  L.spawn = { pos: [0, 24, 16], yaw: 0, checkpoint: [0, 0, 16] };
  L.menuCam = { target: [0, 3, -48], radius: 16, height: 6 };
  L.decor = [['v2', [0, 0, -50], 0]];

  // ay: gökyüzünde parlayan disk
  const moon = new THREE.Sprite(new THREE.SpriteMaterial({ map: L.T.glow, color: 0xdde6ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
  moon.position.set(-60, 90, -160);
  moon.scale.set(60, 60, 1);
  L.scene.add(moon);
  const disc = new THREE.Mesh(new THREE.CircleGeometry(9, 24), new THREE.MeshBasicMaterial({ color: 0xf4f6ff, fog: false }));
  disc.position.set(-60, 90, -162);
  disc.lookAt(0, 0, 0);
  L.scene.add(disc);

  // ===== Ay bahçesi (x -9..9, z 0..24) =====
  room(L, -9, 0, 9, 24, { h: 7, mat: 'castle', floor: 'grass', skip: ['n'] });
  L.shop(-7.4, 0, 12, Math.PI / 2);
  tree(L, 5, 20, 5);
  tree(L, 5, 5, 4);
  L.torch(8.75, 4, 12);
  L.hint([-8, 0, 1, 8, 3, 23], '1-4: AY IŞIĞI. Ileride seni bir makine bekliyor. Senin gibi bir makine.', 8);

  // ===== Merdivenli geçit (x -4..4, z -24..-1) =====
  L.box(-5, 0, -24, -4, 9, -1, 'castle');
  L.box(4, 0, -24, 5, 9, -1, 'castle');
  L.box(-5, -2, -1, 5, 0, 0, 'grass');
  L.box(-4, -2, -4, 4, 0, -1, 'castleDark');
  L.box(-10, 0, -1, -4, 9, 0, 'castle');
  L.box(4, 0, -1, 10, 9, 0, 'castle');
  L.stairsZ(-4, 4, -4, -14, 0, 3, 8, 'castleDark');
  L.box(-4, 0, -24, 4, 3, -14, 'castleDark');
  L.torch(-3.75, 6, -10);
  L.torch(3.75, 6, -20);
  L.checkpoint([-4, 3, -22, 4, 7, -17], [0, 3, -20], 0);
  L.hint([-4, 3, -22, 4, 7, -17], 'Son dükkân bahçedeydi. Hazırsan ilerle.', 5);

  // ===== BOSS: Düello meydanı (x -26..26, z -76..-25), üstü açık =====
  room(L, -26, -76, 26, -25, { h: 14, mat: 'castle', floor: null, gaps: { s: [-4, 4, 10, 3], n: [-4, 4, 10, 3] } });
  L.box(-27, -2, -77, 27, 3, -24, 'tiles');
  // köşelerde sekizgen hissi veren kütleler ve alçak siperler
  for (const [x, z] of [[-22, -29], [22, -29], [-22, -72], [22, -72]]) L.box(x - 4, 3, z - 4, x + 4, 13, z + 4, 'castle');
  for (const [x, z] of [[-11, -40], [11, -40], [-11, -62], [11, -62]]) pillar(L, x, z, 6, 1, 'castle', 3);
  L.box(-4, 3, -53, 4, 4.2, -49, 'castleDark');
  L.box(-18, 3, -52, -15, 5.2, -48, 'castleDark');
  L.box(15, 3, -52, 18, 5.2, -48, 'castleDark');
  L.sigil(0, 3, -51, 18);
  for (const [x, z] of [[-17, -31], [17, -31], [-17, -70], [17, -70]]) L.brazier(x, 3, z);
  L.door('dB_in', -4, 3, -24.8, 4, 10, -24.2, { open: true });
  L.door('gate', -4, 3, -76.8, 4, 10, -76.2, { open: false });
  L.arena({
    id: 'boss', name: 'V2',
    bossSub: 'SENİ İZLİYORDU',
    trigger: [-26, 3, -32, 26, 9, -26],
    lock: ['dB_in'], exits: ['gate'],
    boss: true,
    waves: [[{ t: 'v2', p: [0, 3, -64] }]],
    onStart: (g) => g.hud.hint('V2: KIRMIZI ÇİZGİ = revolver nişanı; kalınlaşınca kilitlenir → ATIL. Yumruğu parlayınca PARRY yap. Uzakta kalma, yakında pompalı var.', 12),
    onClear: (g) => g.onBossDefeated('V2 DEVRE DIŞI', () => {
      const first = !progress.shop['arm.knuckle'];
      progress.shop['arm.knuckle'] = true;
      const newChar = !progress.v2Unlocked;
      progress.v2Unlocked = true;
      saveProgress();
      g.weapons.giveArm('knuckle');
      g.hud.titleCard(`<div class="tc-layer">V2'NİN KOLUNU KOPARDIN</div><div class="tc-name tc-weapon">KNUCKLEBLASTER</div>${newChar ? '<div class="tc-layer small">YENİ KARAKTER AÇILDI: V2 (menü → OYNA)</div>' : ''}`, 4.5);
      if (first) g.hud.hint('KNUCKLEBLASTER artık senin: [G] ile kol değiştir. Ağır yumruk, basılı tut → şok dalgası.', 9);
    }),
  });

  // ===== Çıkış (x -5..5, z -94..-77) =====
  room(L, -5, -94, 5, -77, { y: 3, h: 10, mat: 'castle', floor: 'tiles', skip: ['s'] });
  portal(L, 0, -92, { y: 3, color: 0xa0c0ff, glowColor: 0x80a0ff, w: 7, h: 9 });

  spires(L, [[-70, 10, 60, 7], [70, -30, 70, 8], [-80, -100, 80, 8], [75, -130, 60, 7], [0, -190, 90, 9]]);
  L.finalize();
}
