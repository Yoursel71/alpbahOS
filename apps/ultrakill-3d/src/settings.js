// Ayarlar ve kalıcı ilerleme (localStorage erişilemezse sessizce varsayılana döner)
const SETTINGS_KEY = 'uk3d.settings.v1';
const PROGRESS_KEY = 'uk3d.progress.v1';

export const DIFFICULTIES = [
  { id: 'harmless', name: 'ZARARSIZ', desc: 'Düşmanlar çok az hasar verir, yavaş saldırır.', dmg: 0.3, speed: 0.75, aggro: 0.6 },
  { id: 'lenient', name: 'HOŞGÖRÜLÜ', desc: 'Öğrenmek için rahat bir tempo.', dmg: 0.6, speed: 0.88, aggro: 0.8 },
  { id: 'standard', name: 'STANDART', desc: 'Oyunun tasarlandığı gibi.', dmg: 1, speed: 1, aggro: 1 },
  { id: 'violent', name: 'ŞİDDETLİ', desc: 'Daha hızlı, daha acımasız.', dmg: 1.4, speed: 1.15, aggro: 1.3 },
];

export const settings = {
  sens: 1.0,
  fov: 100,
  resScale: 0.5,
  colorCompress: true,
  vertexJitter: true,
  shake: 1.0,
  tilt: true,
  invertY: false,
  master: 0.8,
  music: 0.55,
  sfx: 0.9,
  difficulty: 2,
  showFps: false,
  skipIntro: false,
  touchMode: 'auto', // 'auto' | 'on' | 'off'
  touchSens: 1.0,
  aimAssist: true,
};

export const progress = {
  bestRank: null, // 'D'..'S' | 'P'
  bestTime: null,
  bestStyle: 0,
  introSeen: false,
};

export function loadSettings() {
  try {
    const s = JSON.parse(localStorage.getItem(SETTINGS_KEY) || 'null');
    if (s && typeof s === 'object') for (const k of Object.keys(settings)) if (k in s) settings[k] = s[k];
  } catch (e) { /* depolama yok */ }
  try {
    const p = JSON.parse(localStorage.getItem(PROGRESS_KEY) || 'null');
    if (p && typeof p === 'object') Object.assign(progress, p);
  } catch (e) { /* depolama yok */ }
}

export function saveSettings() {
  try { localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings)); } catch (e) { /* yok say */ }
}

export function saveProgress() {
  try { localStorage.setItem(PROGRESS_KEY, JSON.stringify(progress)); } catch (e) { /* yok say */ }
}

export function difficulty() {
  return DIFFICULTIES[settings.difficulty] || DIFFICULTIES[2];
}
