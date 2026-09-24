// Dükkân kataloğu. Revolver (Piercer) ücretsizdir; geri kalan her şey stil puanından biriken
// P ile bölümlerdeki dükkân terminallerinden alınır. Sahiplik progress.shop'ta kalıcıdır.
import { WEAPONS } from './weapons.js';

const hex = (c) => '#' + c.toString(16).padStart(6, '0');

// w: silah indeksi, v: varyant indeksi (0 = temel silahın kendisi), arm: kol/kanca
const PRICES = {
  'revolver.marksman': 1500, 'revolver.sharpshooter': 3000,
  shotgun: 2000, 'shotgun.pump': 2000, 'shotgun.saw': 3000,
  nailgun: 3500, 'nailgun.overheat': 2500, 'nailgun.sawblade': 3000,
  rail: 5500, 'rail.screwdriver': 3500, 'rail.malicious': 4500,
  rocket: 6500, 'rocket.cannon': 3500, 'rocket.fire': 4000,
  'arm.knuckle': 3000, 'arm.hook': 2500,
};

export const SHOP_ITEMS = [];
WEAPONS.forEach((W, w) => {
  W.variants.forEach((V, v) => {
    const id = v === 0 ? W.id : `${W.id}.${V.id}`;
    if (w === 0 && v === 0) return; // Revolver ücretsiz
    SHOP_ITEMS.push({ id, w, v, group: W.id, name: v === 0 ? W.name : V.name, sub: v === 0 ? `${V.name} ile gelir` : W.name, color: hex(V.color), price: PRICES[id], needs: v === 0 || w === 0 ? null : W.id });
  });
});
SHOP_ITEMS.push({ id: 'arm.knuckle', arm: true, group: 'arms', name: 'KNUCKLEBLASTER', sub: 'Ağır yumruk · [G] ile değiştir', color: '#ff3a2a', price: PRICES['arm.knuckle'], needs: null });
SHOP_ITEMS.push({ id: 'arm.hook', arm: true, group: 'arms', name: 'WHIPLASH', sub: 'Kanca · [E]', color: '#3ee06a', price: PRICES['arm.hook'], needs: null });

export const SHOP_GROUPS = [
  { id: 'revolver', name: '1 · REVOLVER' },
  { id: 'shotgun', name: '2 · SHOTGUN' },
  { id: 'nailgun', name: '3 · NAILGUN' },
  { id: 'rail', name: '4 · RAILCANNON' },
  { id: 'rocket', name: '5 · ROCKET' },
  { id: 'arms', name: 'KOLLAR' },
];

// Satın alındığında gösterilen kısa kullanım ipucu
export const ITEM_HINTS = {
  'revolver.marksman': 'MARKSMAN: [SAĞ TIK] bozuk para at, paraya ateş et → RICOSHOT. Revolver tuşuna tekrar basınca varyant değişir.',
  'revolver.sharpshooter': 'SHARPSHOOTER: [SAĞ TIK] basılı tut → duvarlardan seken ışın.',
  shotgun: 'SHOTGUN: [SOL TIK] saçma · [SAĞ TIK] basılı tut → CORE EJECT bombası; bombaya ateş et → büyük patlama. Yakından vur + hemen yumrukla = SHOTGUN PARRY.',
  'shotgun.pump': 'PUMP CHARGE: [SAĞ TIK] ile pompala; 3. pompada patlar.',
  'shotgun.saw': 'SAWED-ON: [SAĞ TIK] zincirli testere fırlat, geri döner.',
  nailgun: 'NAILGUN: [SOL TIK] basılı tut → çivi yağmuru · [SAĞ TIK] mıknatıs at, çiviler ona kıvrılır.',
  'nailgun.overheat': 'OVERHEAT: [SAĞ TIK] ısınmış çivi patlaması → düşmanları yakar.',
  'nailgun.sawblade': 'SAWBLADE: duvarlardan seken testere diskleri.',
  rail: 'RAILCANNON: tek atış her şeyi deler, sonra uzun şarj. Boss\'a sakla!',
  'rail.screwdriver': 'SCREWDRIVER: düşmana saplanıp deler.',
  'rail.malicious': 'MALICIOUS: vurduğu yerde patlar.',
  rocket: 'ROCKET LAUNCHER: roket zıplaması! [SAĞ TIK] FREEZEFRAME ile roketleri dondur.',
  'rocket.cannon': 'S.R.S. CANNON: [SAĞ TIK] ağır gülle.',
  'rocket.fire': 'FIRESTARTER: [SAĞ TIK] alev püskürt, yanan düşmana roket = patlama.',
  'arm.knuckle': 'KNUCKLEBLASTER: [G] ile kol değiştir. Ağır yumruk; [F] basılı tut → şok dalgası. Mermi savuşturamaz!',
  'arm.hook': 'WHIPLASH: [E] kanca. Hafif düşmanı sana çeker, ağır düşmana seni çeker.',
};
