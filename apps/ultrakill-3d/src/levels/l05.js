// 0-5 "CERBERUS": soğuk mermer salonlar. Heykellerle çevrili uzun koridor ve dükkân, ardından
// kaidelerinde uyuyan iki Cerberus heykelinin beklediği kapı salonu. İkisi de ölünce Cehennemin
// kapısı açılır: PRELUDE biter.
import * as THREE from 'three';
import { room, pillar, spires } from './common.js';

export function buildLevel05(L) {
  L.theme = {
    ...L.theme,
    fog: 0x1a2030, fogNear: 26, fogFar: 135,
    skyTop: [0.0, 0.0, 0.02], skyHor: [0.08, 0.1, 0.18], skyCloud: [0.1, 0.12, 0.2], skyGlow: [0.32, 0.12, 0.05],
    hemiSky: 0xc8d4ff, hemiGround: 0x302838, hemi: 2.6, ambient: 0x5a5a7a, sun: 0xb8c4ff,
  };
  L.spawn = { pos: [0, 30, -4], yaw: 0, checkpoint: [0, 0, -4] };
  L.menuCam = { target: [0, 3, -78], radius: 16, height: 6 };
  L.decor = [['cerberus', [-8, 0.6, -80], 0, { dormant: true }], ['cerberus', [8, 0.6, -80], 0, { dormant: true }]];

  // ===== Heykeller koridoru (x -6..6, z -40..0) =====
  room(L, -6, -40, 6, 0, { h: 12, mat: 'marble', floor: null, gaps: { w: [-27, -25, 1.1] }, skip: ['n'] });
  L.box(-7, -2, -40, 7, 0, 1, 'tiles');
  L.shop(-4.9, 0, -4, Math.PI / 2);
  for (const z of [-12, -22, -32]) {
    L.statue(-4.4, 0, z, 1.1);
    L.statue(4.4, 0, z, 1.1);
  }
  L.torch(-5.75, 6, -7);
  L.torch(5.75, 6, -17);
  L.torch(-5.75, 6, -27);
  L.torch(5.75, 6, -37);
  L.sigil(0, 0, -20, 6);
  L.hint([-5, 0, -9, 5, 3, -1], '0-5: CERBERUS. Heykeller kıpırdamıyor... şimdilik. Son dükkân burada.', 7);
  L.checkpoint([-4, 0, -39, 4, 4, -35], [0, 0, -37], 0);
  // gizli: batı duvarının dibinden kayarak girilen oda
  L.box(-12, -2, -28, -7, 0, -24, 'tiles');
  L.box(-13, 0, -29, -7, 3, -28, 'marble');
  L.box(-13, 0, -24, -7, 3, -23, 'marble');
  L.box(-13, 0, -28, -12, 3, -24, 'marble');
  L.box(-13, 3, -29, -7, 4, -23, 'marble');
  L.secret(-10, 1, -26);

  // ===== KAPI SALONU (x -26..26, z -104..-41) =====
  room(L, -26, -104, 26, -41, { h: 22, mat: 'marble', gaps: { s: [-4, 4, 8], n: [-6, 6, 12] }, skip: ['s'] });
  L.box(-27, 0, -41, -4, 22, -40, 'marble');
  L.box(4, 0, -41, 27, 22, -40, 'marble');
  L.box(-4, 8, -41, 4, 22, -40, 'marble');
  L.door('dB_in', -4, 0, -40.8, 4, 8, -40.2, { open: true });
  L.door('gate', -6, 0, -104.8, 6, 12, -104.2, { open: false });
  for (const z of [-50, -62, -74, -86, -98]) {
    pillar(L, -18, z, 22, 1.2, 'marble');
    pillar(L, 18, z, 22, 1.2, 'marble');
  }
  // kaideler
  L.box(-9.5, 0, -81.5, -6.5, 0.6, -78.5, 'marble');
  L.box(6.5, 0, -81.5, 9.5, 0.6, -78.5, 'marble');
  L.sigil(0, 0, -72, 16);
  L.box(-10, 0, -60, -7, 1.6, -57, 'marble');
  L.box(7, 0, -92, 10, 1.6, -89, 'marble');
  L.brazier(-24, 0, -43);
  L.brazier(24, 0, -43);
  L.brazier(-24, 0, -102);
  L.brazier(24, 0, -102);
  L.brazier(-12, 0, -80);
  L.brazier(12, 0, -80);
  L.chain(-25.8, 21, -60, 12);
  L.chain(25.8, 21, -85, 12);

  L.arena({
    id: 'boss', name: 'CERBERUS',
    bossSub: 'KAPININ BEKÇİLERİ',
    trigger: [-26, 0, -50, 26, 8, -44],
    lock: ['dB_in'], exits: ['gate'],
    boss: true,
    prespawn: true,
    waves: [[{ t: 'cerberus', p: [-8, 0.6, -80], opts: { dormant: true } }, { t: 'cerberus', p: [8, 0.6, -80], opts: { dormant: true } }]],
    onWave: (g, w, a) => {
      const [c1, c2] = a.enemies;
      if (c1 && c2) { c1.partner = c2; c2.partner = c1; }
      g.schedule(1.4, () => { if (c1 && !c1.dead) c1.wake(); });
    },
    onStart: (g) => g.hud.hint('CERBERUS: yere vurduğunda halka dalga gelir — ZIPLA! Parlayarak hücum ettiğinde PARRY yap. Büyük küreyi geri yolla. Biri yarı cana inince diğeri uyanır.', 12),
    onClear: (g) => g.onBossDefeated('KAPININ BEKÇİLERİ DÜŞTÜ', () => {
      g.hud.hint('Cehennemin kapısı açıldı. İçeri gir.', 8);
    }),
  });

  // ===== Cehennemin kapısı (x -8..8, z -124..-105) =====
  room(L, -8, -124, 8, -105, { h: 14, mat: 'marble', floor: null, skip: ['s'] });
  L.box(-9, -2, -125, 9, 0, -105, 'tiles');
  L.box(-5, 0, -122, -4, 10, -121, 'gold');
  L.box(4, 0, -122, 5, 10, -121, 'gold');
  L.box(-5, 10, -122, 5, 11, -121, 'gold');
  const portal = new THREE.Mesh(new THREE.PlaneGeometry(8, 10), new THREE.MeshBasicMaterial({ color: 0xff3010, transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  portal.position.set(0, 5, -121.6);
  L.scene.add(portal);
  const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: L.T.glow, color: 0xff5020, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  glow.position.set(0, 5, -120.5);
  glow.scale.set(14, 16, 1);
  L.scene.add(glow);
  L.animated.push((t) => { portal.material.opacity = 0.7 + Math.sin(t * 3) * 0.15; glow.material.rotation = t * 0.3; });
  L.lamps.push({ pos: new THREE.Vector3(0, 5, -118), color: 0xff4010, power: 1.6 });
  L.sigil(0, 0, -114, 10);
  L.trigger([-4, 0, -122, 4, 10, -119], () => L.game.levelComplete());

  spires(L, [[-70, 0, 70, 7], [70, -30, 80, 8], [-80, -90, 90, 9], [75, -120, 70, 7], [0, -170, 100, 10], [0, 60, 60, 6]]);
  L.finalize();
}
