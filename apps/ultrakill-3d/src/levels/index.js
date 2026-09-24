// Bölüm kaydı: PRELUDE (0-x), KATMAN 1 ARAF (1-x) ve sonsuz Siber Öğütücü. Her bölüm: kimlik, ad, açıklama, sıralama eşikleri ve meydan okuma.
import { buildLevel01 } from './l01.js';
import { buildLevel02 } from './l02.js';
import { buildLevel03 } from './l03.js';
import { buildLevel04 } from './l04.js';
import { buildLevel05 } from './l05.js';
import { buildLevel11 } from './l11.js';
import { buildLevel12 } from './l12.js';
import { buildLevel13 } from './l13.js';
import { buildLevel14 } from './l14.js';
import { buildCyberGrind } from './cg.js';

const LAYER = 'PRELUDE: İLK KAN';
const LIMBO = 'KATMAN 1: ARAF';

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
    finale: 'PRELUDE TAMAMLANDI — CEHENNEMİN KAPILARI AÇILDI. SIRADA ARAF.',
  },
  {
    id: '1-1', name: 'GÜNDOĞUMUNUN KALBİ', layer: LIMBO, build: buildLevel11,
    desc: 'Güneşli kale bahçeleri, kırık hendek köprüsü ve kule salonu. Yeni düşman: DRONE.',
    thresh: { time: [230, 320, 410, 520], style: [8000, 5600, 3600, 1800] },
    challenge: { text: (r) => `Bir DRONE'u yumrukla geri yolla (${r.droneParries || 0})`, check: (r) => (r.droneParries || 0) >= 1 },
  },
  {
    id: '1-2', name: 'YANAN DÜNYA', layer: LIMBO, build: buildLevel12,
    desc: 'Yanan köy, alevli kirişler ve yıkık kilise. Yeni düşman: STREETCLEANER.',
    thresh: { time: [240, 330, 420, 540], style: [8500, 6000, 3800, 1900] },
    challenge: { text: (r) => `3 Streetcleaner tankını patlat (${r.tanks || 0})`, check: (r) => (r.tanks || 0) >= 3 },
  },
  {
    id: '1-3', name: 'KUTSAL KALINTILAR SALONU', layer: LIMBO, build: buildLevel13,
    desc: 'Beyaz mermer, altın kiriş ve heykeller galerisi. Mini boss: HIDEOUS MASS.',
    thresh: { time: [220, 310, 400, 500], style: [8000, 5600, 3600, 1800] },
    challenge: { text: (r) => `150'den az hasar al (${Math.round(r.damage)})`, check: (r) => r.damage < 150 },
  },
  {
    id: '1-4', name: 'AY IŞIĞI', layer: LIMBO, build: buildLevel14,
    desc: 'Ay ışığında düello: kendin gibi bir makine. Boss: V2. Kazan → Knuckleblaster ve oynanabilir V2.',
    thresh: { time: [120, 180, 250, 340], style: [6500, 4500, 3000, 1500] },
    challenge: { text: (r) => `V2'nin yumruğunu PARRY yap (${r.parries})`, check: (r) => r.parries >= 1 },
    finale: 'KATMAN 1 TAMAMLANDI — V2 ARTIK OYNANABİLİR KARAKTER.',
  },
  {
    id: 'CG', name: 'SİBER ÖĞÜTÜCÜ', layer: 'SİBER ÖĞÜTÜCÜ', build: buildCyberGrind, endless: true,
    desc: 'Sonsuz dalga modu: neon ızgarada yükselen sütunlar, her dalga daha zor. En yüksek dalgayı kovala. (0-1 bitince açılır)',
    thresh: { time: [0, 0, 0, 0], style: [0, 0, 0, 0] },
    challenge: { text: (r) => `10. dalgaya ulaş (${r.wave || 0})`, check: (r) => (r.wave || 0) >= 10 },
  },
];

// Hikâye bölümleri (sonsuz mod hariç) — kilit açma sırası
export const STORY_COUNT = LEVELS.filter((l) => !l.endless).length;
export const LAYERS = [...new Set(LEVELS.map((l) => l.layer))];
