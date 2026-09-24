// PRELUDE: İLK KAN — bölüm kaydı. Her bölüm: kimlik, ad, açıklama, sıralama eşikleri ve meydan okuma.
import { buildLevel01 } from './l01.js';
import { buildLevel02 } from './l02.js';
import { buildLevel03 } from './l03.js';
import { buildLevel04 } from './l04.js';
import { buildLevel05 } from './l05.js';

const LAYER = 'PRELUDE: İLK KAN';

export const LEVELS = [
  {
    id: '0-1', name: 'ATEŞİN İÇİNE', layer: LAYER, build: buildLevel01,
    desc: 'Silahsız iniş ve hareket eğitimi, Revolver, parry eğitmeni, ilk dükkân. Boss: Swordsmachine.',
    thresh: { time: [240, 330, 420, 540], style: [6500, 4500, 3000, 1500] },
    challenge: { text: (r) => `En az 5 PARRY yap (${r.parries})`, check: (r) => r.parries >= 5 },
  },
  {
    id: '0-2', name: 'KIYMA MAKİNESİ', layer: LAYER, build: buildLevel02,
    desc: 'Öğütücü çukurlu mezbaha. Düşmanları öğütücüye it! İki büyük arena, 2 gizli küre.',
    thresh: { time: [210, 300, 390, 480], style: [7000, 5000, 3200, 1600] },
    challenge: { text: (r) => `3 dakikanın altında bitir (${Math.floor(r.time / 60)}:${String(Math.floor(r.time % 60)).padStart(2, '0')})`, check: (r) => r.time < 180 },
  },
  {
    id: '0-3', name: 'ÇİFTE BELA', layer: LAYER, build: buildLevel03,
    desc: 'Harabeler ve ilk Malicious Face. Boss: aynı anda İKİ Swordsmachine.',
    thresh: { time: [200, 290, 380, 480], style: [7000, 5000, 3200, 1600] },
    challenge: { text: (r) => `100'den az hasar al (${Math.round(r.damage)})`, check: (r) => r.damage < 100 },
  },
  {
    id: '0-4', name: 'TEK MAKİNELİK ORDU', layer: LAYER, build: buildLevel04,
    desc: 'Kolezyumda altı dalgalı tek meydan savaşı. Malicious Face\'ler ve bir Swordsmachine.',
    thresh: { time: [240, 330, 420, 540], style: [9000, 6500, 4200, 2000] },
    challenge: { text: (r) => `Hiç ölmeden bitir (${r.restarts})`, check: (r) => r.restarts === 0 },
  },
  {
    id: '0-5', name: 'CERBERUS', layer: LAYER, build: buildLevel05,
    desc: 'Kapının bekçileri: uyanan iki taş heykel. PRELUDE\'un son bölümü.',
    thresh: { time: [150, 220, 300, 400], style: [6000, 4200, 2800, 1400] },
    challenge: { text: (r) => `En az 8 PARRY yap (${r.parries})`, check: (r) => r.parries >= 8 },
  },
];
