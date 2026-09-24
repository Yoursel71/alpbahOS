// 0-1 "ATEŞİN İÇİNE": silahsız iniş, tutorial kanadı (atılma zıplaması, kayma, duvar sıçraması,
// çakış sıçrayışı), Revolver sunağı, 3 arena, parry eğitmeni, 2 dükkân, boss Swordsmachine.
import * as THREE from 'three';

export function buildLevel01(L) {
  L.startArmed = false;
  L.decor = [['filth', [-4, 0, -6], 0.4], ['filth', [5, 0, -9], -0.3], ['filth', [-7, 0, 1], 1.2], ['schism', [2, 0, -12], 0.1], ['stray', [0, 3, 13.5], Math.PI]];
  L.menuCam = { target: [0, 2.2, -3], radius: 15, height: 5.5 };

  // ===================== TUTORIAL KANADI (güney, z 17..117) =====================
  // T0 — İniş odası (x -7..7, z 100..116): gökten düşülür, silahsız başlanır
  L.box(-8, -2, 99, 8, 0, 117, 'tiles');
  L.box(-8, 0, 99, -7, 14, 117, 'stone');
  L.box(7, 0, 99, 8, 14, 117, 'stone');
  L.box(-8, 0, 116, 8, 14, 117, 'stone');
  L.box(-8, 0, 99, -3, 14, 100, 'stone');
  L.box(3, 0, 99, 8, 14, 100, 'stone');
  L.box(-3, 6, 99, 3, 14, 100, 'stone');
  L.brazier(-5, 0, 113);
  L.brazier(5, 0, 113);
  L.sigil(0, 0, 108, 8);
  L.chain(-6.8, 13, 106, 6);
  L.chain(6.8, 13, 110, 5);
  L.skulls(-5, 0, 103, 5);
  L.hint([-7, 0, 100, 7, 3, 116], '[WASD] yürü · [BOŞLUK] zıpla · fareyle bak. Silahın yok — önce hareketi öğren. Kuzeydeki kapıdan ilerle.', 9);

  // T1 — Atılma boşluğu (z 76..99, boşluk z 81..94)
  L.box(-4, -16, 94, 4, 0, 99, 'tiles');
  L.box(-4, -16, 76, 4, 0, 81, 'tiles');
  L.box(-4, -16, 81, -3, 0, 94, 'rock');
  L.box(3, -16, 81, 4, 0, 94, 'rock');
  L.box(-3, -18, 81, 3, -14, 94, 'rock');
  L.lavaPlane(-3, 81, 3, 94, -13.5);
  L.hurt([-3, -16, 81, 3, -12, 94], 0, 'pit');
  L.box(-4, 0, 76, -3, 8, 99, 'stone');
  L.box(3, 0, 76, 4, 8, 99, 'stone');
  L.box(-4, 8, 76, 4, 9, 99, 'rock');
  L.torch(-2.75, 5, 96);
  L.torch(2.75, 5, 79);
  L.hint([-3, 0, 95, 3, 5, 98.5], 'Boşluk normal zıplamak için fazla geniş! [SHIFT] ile ATIL, atılırken [BOŞLUK] → ATILMA ZIPLAMASI. Atılırken hasar da almazsın.', 10);

  // T2 — Kayma koridoru (z 58..76)
  L.box(-4, -2, 58, 4, 0, 76, 'tiles');
  L.box(-4, 0, 58, -3, 6, 76, 'stone');
  L.box(3, 0, 58, 4, 6, 76, 'stone');
  L.box(-4, 6, 58, 4, 7, 76, 'metal');
  L.box(-3, 1.1, 66, 3, 6, 68, 'metal');
  L.box(-3, 1.1, 65.8, 3, 1.4, 68.2, 'door', { solid: false, texScale: 6 });
  L.torch(-2.75, 4, 72);
  L.hint([-3, 0, 72, 3, 5, 75], 'Alçak engel! Koşarken [C] basılı tut → KAY. Kayarken hızını korursun; kayarken zıplamak uzağa fırlatır.', 9);

  // T3 — Duvar sıçrama kuyusu (x -2.5..2.5, z 44..58), çıkış çıkıntısı y=7
  L.box(-3.5, -2, 43, 3.5, 0, 58, 'tiles');
  L.box(-3.5, 0, 44, -2.5, 14, 58, 'stone');
  L.box(2.5, 0, 44, 3.5, 14, 58, 'stone');
  L.box(-2.5, 0, 44, 2.5, 7, 48, 'stone');
  L.box(-2.5, 0, 52, -0.8, 2, 54.5, 'metal');
  L.box(-3.5, 0, 43, 3.5, 7, 44, 'stone');
  L.box(-3.5, 12.5, 43, 3.5, 14, 44, 'stone');
  L.torch(-2.25, 9, 50);
  L.torch(2.25, 9, 55);
  L.hint([-2.5, 0, 55, 2.5, 5, 57.5], 'DUVAR SIÇRAMASI: havadayken duvara doğru [BOŞLUK] (yere değmeden 3 kez). İki duvar arasında sekerek yukarıdaki çıkıntıya tırman!', 11);

  // T4 — Çakma odası (x -6..6, z 26..43); kuzey çıkıntısı y=6.5
  L.box(-7, -2, 25, 7, 0, 44, 'tiles');
  L.box(-7, 0, 25, -6, 14, 44, 'stone');
  L.box(6, 0, 25, 7, 14, 44, 'stone');
  L.box(-7, 0, 43, -3.5, 14, 44, 'stone');
  L.box(3.5, 0, 43, 7, 14, 44, 'stone');
  L.box(-6, 0, 26, 6, 6.5, 30, 'stone');
  L.box(-7, 0, 25, -3, 14, 26, 'stone');
  L.box(3, 0, 25, 7, 14, 26, 'stone');
  L.box(-3, 12, 25, 3, 14, 26, 'stone');
  L.sigil(0, 0, 36, 5);
  L.brazier(-4.5, 0, 40.5);
  L.brazier(4.5, 0, 40.5);
  L.hint([-6, 0, 30.5, 6, 4, 42.5], 'Çıkıntı çok yüksek! Yüksekten düşerken [C] → YERE ÇAK. Yere çarptığın an [BOŞLUK] → ÇAKIŞ SIÇRAYIŞI. Tekrar denemek için duvar sıçramasıyla yüksel.', 12);

  // T5 — Revolver sunağı (üst kat y=6.5, z 21..26; merdivenle y=3'e iner, kapı arenaya açılır)
  L.box(-8, 1, 16, 8, 3, 21, 'tiles');
  L.box(-8, 4.5, 21, 8, 6.5, 26, 'tiles');
  L.stairsZ(-3, 3, 17, 21, 3, 6.5, 7, 'metal');
  L.box(-8, 0, 16, -7, 14, 26, 'stone');
  L.box(7, 0, 16, 8, 14, 26, 'stone');
  L.box(-7, 6.5, 21, -3, 7.5, 21.4, 'metal', { solid: false });
  L.box(3, 6.5, 21, 7, 7.5, 21.4, 'metal', { solid: false });
  L.brazier(-5.5, 6.5, 24.5);
  L.brazier(5.5, 6.5, 24.5);
  L.altar(0, 6.5, 23.4, 0, (g) => g.schedule(2.4, () => {
    g.hud.hint('REVOLVER: [SOL TIK] ateş · [SAĞ TIK] basılı tut → PIERCER şarjlı delici atış. [1]\'e tekrar bas: MARKSMAN (bozuk para at, paraya ateş et → RICOSHOT). Kafadan vuruş 2x hasar.', 12);
    g.setCheckpoint(new THREE.Vector3(0, 6.5, 22), 0);
    L.doors.dT.open();
  }, (g) => g.applyLoadout()));

  // ===== ARENA 1: Düşüş odası (x -16..16, z -16..16) =====
  L.box(-17, -2, -17, 17, 0, 17, 'tiles');
  L.box(-17, 0, 16, -3, 14, 17, 'stone');
  L.box(3, 0, 16, 17, 14, 17, 'stone');
  L.box(-3, 0, 16, 3, 3, 17, 'stone');
  L.box(-3, 9, 16, 3, 14, 17, 'stone');
  L.door('dT', -3, 3, 16.2, 3, 9, 16.8, { open: false });
  L.box(16, 0, -17, 17, 14, 17, 'stone');
  L.box(-17, 0, -17, -16, 14, 17, 'stone');
  L.box(-17, 0, -17, -3, 14, -16, 'stone');
  L.box(3, 0, -17, 17, 14, -16, 'stone');
  L.box(-3, 6, -17, 3, 14, -16, 'stone');
  L.door('d1', -3, 0, -16.8, 3, 6, -16.2, { open: false });
  // güney çıkıntı ve merdiven
  L.box(-16, 0, 11, 16, 3, 16, 'stone');
  L.stairsZ(-2, 2, 7.4, 11, 0, 3, 6, 'metal');
  // sütunlar
  for (const [x, z] of [[-9, -9], [9, -9], [-9, 3], [9, 3]]) {
    L.box(x - 1, 0, z - 1, x + 1, 9, z + 1, 'stone');
    L.box(x - 1.3, 9, z - 1.3, x + 1.3, 9.4, z + 1.3, 'metal');
    L.box(x - 1.3, 0, z - 1.3, x + 1.3, 0.4, z + 1.3, 'metal');
  }
  L.box(-5, 0, -3, -2, 1.2, -1.5, 'metal');
  L.box(2, 0, 1, 5, 1.2, 2.5, 'metal');
  L.brazier(-14, 0, -14);
  L.brazier(14, 0, -14);
  L.brazier(-14, 3, 14);
  L.brazier(14, 3, 14);
  L.sigil(0, 0, -2, 12);
  L.chain(-15.8, 13, -6, 5);
  L.chain(15.8, 13, -2, 6);
  L.chain(-15.8, 13, 6, 4);
  L.skulls(-13, 0, 8, 6);
  L.skulls(12, 0, -2, 4);

  L.arena({
    id: 'a1',
    name: 'ARENA 1',
    trigger: [-16, 0, -16, 16, 2.5, 11],
    lock: ['dT'],
    exits: ['d1'],
    waves: [
      [{ t: 'filth', p: [-8, 0, -13] }, { t: 'filth', p: [8, 0, -13] }, { t: 'filth', p: [0, 0, -14] }],
      [{ t: 'filth', p: [-13, 0, 0] }, { t: 'filth', p: [13, 0, 0] }, { t: 'filth', p: [-6, 0, -13] }, { t: 'filth', p: [6, 0, -13] }, { t: 'stray', p: [0, 3, 13.5] }],
    ],
    onStart: (g) => g.hud.hint('Arena kilitlendi! Tüm düşmanları öldür — kapılar ancak alan temizlenince açılır. Havadaki düşmanı vurmak: +AIRSHOT', 8),
  });

  // ===== KORİDOR 1 (x -3..3, z -40..-17) =====
  L.box(-4, -16, -24, 4, 0, -17, 'tiles');
  L.box(-4, -16, -41, 4, 0, -30, 'tiles');
  L.box(-4, -16, -30, -3, 0, -24, 'rock');
  L.box(3, -16, -30, 4, 0, -24, 'rock');
  L.box(-3, -18, -30, 3, -14, -24, 'rock');
  L.lavaPlane(-3, -30, 3, -24, -13.5);
  L.hurt([-3, -16, -30, 3, -12, -24], 30, 'pit');
  // duvarlar (batı duvarında gizli oda açıklığı)
  L.box(-4, 0, -34, -3, 7, -17, 'stone');
  L.box(-4, 0, -41, -3, 7, -37, 'stone');
  L.box(-4, 0, -37, -3, 3.5, -34, 'stone');
  L.box(3, 0, -35, 4, 7, -17, 'stone');
  L.box(3, 0, -41, 4, 7, -39, 'stone');
  // Parry eğitmeni kafesi (doğu nişi, parmaklıklar yalnız oyuncuyu durdurur)
  L.box(4, -2, -40, 8, 0, -34, 'tiles');
  L.box(7, 0, -40, 8, 7, -34, 'stone');
  L.box(4, 0, -40, 8, 7, -39, 'stone');
  L.box(4, 0, -35, 8, 7, -34, 'stone');
  L.box(3, 7, -40, 8, 8, -34, 'rock');
  for (const z of [-38.6, -37.8, -37.0, -36.2, -35.4]) L.box(3.35, 0, z - 0.07, 3.5, 7, z + 0.07, 'metal', { playerOnly: true, texScale: 1 });
  L.box(3.3, 6.6, -39, 3.55, 7, -35, 'metal', { solid: false });
  L.torch(6.75, 4.5, -37);
  L.trainers.push({ p: [5.6, 0, -37], door: 'd2in' });
  L.hint([-3, 0, -32, 3, 5, -30], 'PARRY EĞİTİMİ: Eğitmenin attığı küre sana çarpmadan hemen önce [F] ile yumrukla. Nişangâhı eğitmene çevir — küre geri seker, onu vurunca kapı açılır.', 12);
  L.box(-4, 7, -41, 4, 8, -17, 'rock');
  L.torch(-2.75, 4.5, -20);
  L.torch(2.75, 4.5, -36);
  // Gizli oda 1 (duvar sıçramasıyla)
  L.box(-10, 1.5, -39, -3.9, 3.5, -32, 'stone');
  L.box(-10, 7, -39, -3.9, 8, -32, 'stone');
  L.box(-10, 3.5, -39, -9, 7, -32, 'stone');
  L.box(-9, 3.5, -39, -3.9, 7, -38, 'stone');
  L.box(-9, 3.5, -33, -3.9, 7, -32, 'stone');
  L.skulls(-8, 3.5, -36.8, 3);
  L.secret(-6.8, 4.7, -35.5);

  // İlk dükkân (batı duvarı, ekran doğuya bakar)
  L.shop(-2.25, 0, -20.2, Math.PI / 2);
  L.hint([-3, 0, -21.5, 3, 5, -18], 'DÜKKÂN! Kazandığın STİL puanı P olarak birikir. Terminalin önünde [B] (mobilde DÜKKÂN butonu) ile yeni silah, varyant ve kol satın al.', 10);
  L.hint([-3, 0, -23.5, 3, 5, -22], 'Boşluğu geç: koşarak zıpla ya da ATILIRKEN ZIPLA [SHIFT → BOŞLUK] ile uzağa fırla.', 7);
  L.hint([-3, 0, -33, 3, 5, -31], 'Havadayken duvara doğru [BOŞLUK]: DUVAR SIÇRAMASI (yere değmeden 3 kez).', 7);
  L.checkpoint([-3, 0, -39.5, 3, 4, -36.5], [0, 0, -38], 0);

  // ===== ARENA 2: Sütunlu salon (x -20..20, z -80..-41) =====
  L.box(-21, -2, -81, 21, 0, -40, 'tiles');
  L.box(-21, 0, -81, -20, 14, -40, 'stone');
  L.box(20, 0, -81, 21, 14, -40, 'stone');
  L.box(-21, 0, -41, -3, 14, -40, 'stone');
  L.box(3, 0, -41, 21, 14, -40, 'stone');
  L.box(-3, 6, -41, 3, 14, -40, 'stone');
  L.door('d2in', -3, 0, -40.8, 3, 6, -40.2, { open: false });
  L.box(-21, 0, -81, -3, 14, -80, 'stone');
  L.box(3, 0, -81, 21, 14, -80, 'stone');
  L.box(-3, 6, -81, 3, 14, -80, 'stone');
  L.door('d2out', -3, 0, -80.8, 3, 6, -80.2, { open: false });
  // balkonlar
  L.box(-20, 0, -75, -13, 4, -46, 'stone');
  L.box(13, 0, -75, 20, 4, -46, 'stone');
  L.box(-13.4, 4, -75, -13, 5, -54, 'metal');
  L.box(13, 4, -64, 13.4, 5, -46, 'metal');
  L.stairsX(-52, -48, -9, -13, 0, 4, 8, 'metal');
  L.stairsX(-70, -66, 9, 13, 0, 4, 8, 'metal');
  // orta platform
  L.box(-5, 0, -64, 5, 2, -56, 'metal');
  L.sigil(0, 2, -60, 7);
  for (const [x, z] of [[-6, -50], [6, -50], [-6, -72], [6, -72]]) {
    L.box(x - 1, 0, z - 1, x + 1, 10, z + 1, 'stone');
    L.box(x - 1.3, 10, z - 1.3, x + 1.3, 10.4, z + 1.3, 'metal');
  }
  L.brazier(-17, 0, -78);
  L.brazier(17, 0, -78);
  L.brazier(-16.5, 4, -47.5);
  L.brazier(16.5, 4, -73.5);
  L.chain(-19.8, 13, -60, 7);
  L.chain(19.8, 13, -56, 5);
  L.skulls(-17, 4, -70, 4);
  L.skulls(16, 4, -52, 5);

  L.arena({
    id: 'a2',
    name: 'ARENA 2',
    trigger: [-20, 0, -45, 20, 6, -42],
    lock: ['d2in'],
    exits: ['d2out'],
    waves: [
      [{ t: 'stray', p: [-16.5, 4, -60] }, { t: 'stray', p: [16.5, 4, -58] }, { t: 'filth', p: [0, 0, -70] }, { t: 'filth', p: [-6, 0, -77] }, { t: 'filth', p: [6, 0, -77] }],
      [{ t: 'stray', p: [-16.5, 4, -70] }, { t: 'stray', p: [16.5, 4, -50] }, { t: 'stray', p: [0, 2, -60] }, { t: 'filth', p: [-12, 0, -78] }, { t: 'filth', p: [12, 0, -78] }, { t: 'filth', p: [0, 0, -77] }, { t: 'filth', p: [9, 0, -64] }],
    ],
    onStart: (g) => g.hud.hint('PARLAYAN (mavi yıldızlı) yakın saldırılar da [F] ile savuşturulur. PARRY canını tamamen doldurur!', 9),
  });

  // ===== KORİDOR 2 (x -3..3, z -100..-81) =====
  L.box(-4, -2, -100, 4, 0, -80, 'tiles');
  L.box(-4, 6, -100, 4, 7, -80, 'metal');
  L.box(-4, 0, -100, -3, 6, -80, 'stone');
  L.box(3, 0, -85, 4, 6, -80, 'stone');
  L.box(3, 0, -100, 4, 6, -87, 'stone');
  L.box(3, 1.0, -87, 4, 6, -85, 'stone');
  // kayarak geçilen engel
  L.box(-3, 1.1, -92, 3, 6, -90, 'metal');
  L.box(-3, 1.1, -92.2, 3, 1.4, -89.8, 'door', { solid: false, texScale: 6 });
  // Gizli oda 2 (kayarak girilen havalandırma)
  L.box(4, -2, -89, 11, 0, -83, 'tiles');
  L.box(4, 0, -88, 6, 1, -87, 'metal');
  L.box(4, 0, -85, 6, 1, -84, 'metal');
  L.box(4, 1, -88, 6, 5, -84, 'metal');
  L.box(6, 0, -89, 11, 5, -88, 'stone');
  L.box(6, 0, -84, 11, 5, -83, 'stone');
  L.box(10, 0, -88, 11, 5, -84, 'stone');
  L.box(6, 5, -88, 10, 6, -84, 'stone');
  L.secret(8.5, 1.3, -86);
  L.torch(-2.75, 4, -84);
  L.torch(-2.75, 4, -96);
  L.hint([-3, 0, -84, 3, 5, -82], 'Yerdeyken [C]: KAY — alçak engellerin altından geç. Havadayken [C]: YERE ÇAK; çakıştan hemen sonra [BOŞLUK] = YÜKSEK SIÇRAYIŞ.', 9);
  L.checkpoint([-3, 0, -99, 3, 4, -96], [0, 0, -97.5], 0);
  // Pusu: koridorun sonunda üç Filth yerden çıkar
  L.extraEnemies.push({ trigger: [-3, 0, -96, 3, 4, -93], list: [{ t: 'filth', p: [-2, 0, -99.3] }, { t: 'filth', p: [2, 0, -99.3] }, { t: 'filth', p: [0, 0, -99.5] }] });

  // ===== ARENA 3: Lav havuzu (x -26..26, z -150..-101) =====
  L.box(-27, -2, -116, 27, 0, -100, 'tiles');
  L.box(-27, -2, -151, 27, 0, -134, 'tiles');
  L.box(-27, -2, -134, -10, 0, -116, 'tiles');
  L.box(10, -2, -134, 27, 0, -116, 'tiles');
  L.box(-10, -3, -134, 10, -1.5, -116, 'rock');
  L.lavaPlane(-10, -134, 10, -116, -1.0);
  L.hurt([-10, -1.6, -134, 10, -0.8, -116], 22, 'lava');
  L.box(-2.5, -1.5, -127.5, 2.5, 1, -122.5, 'stone');
  L.box(-27, 0, -151, -26, 16, -100, 'flesh');
  L.box(26, 0, -151, 27, 16, -100, 'flesh');
  L.box(-27, 0, -101, -3, 16, -100, 'flesh');
  L.box(3, 0, -101, 27, 16, -100, 'flesh');
  L.box(-3, 6, -101, 3, 16, -100, 'stone');
  L.door('d3in', -3, 0, -100.8, 3, 6, -100.2, { open: true });
  L.box(-27, 0, -151, -3, 16, -150, 'flesh');
  L.box(3, 0, -151, 27, 16, -150, 'flesh');
  L.box(-3, 6, -151, 3, 16, -150, 'stone');
  L.door('d3out', -3, 0, -150.8, 3, 6, -150.2, { open: false });
  // batı balkonu + merdiven
  L.box(-26, 0, -140, -20, 5, -110, 'stone');
  L.stairsX(-126, -122, -15, -20, 0, 5, 10, 'metal');
  // kuzeydoğu balkonu + parkur sütunları (gizli 3)
  L.box(20, 0, -150, 26, 5, -142, 'stone');
  L.stairsX(-150, -147, 15.5, 20, 0, 5, 10, 'metal');
  L.box(15.5, 0, -145.5, 17, 6.5, -144, 'stone');
  L.box(12, 0, -141.5, 13.5, 8, -140, 'stone');
  L.box(15, 0, -137.5, 16.5, 9.5, -136, 'stone');
  L.secret(15.75, 10.5, -136.75);
  for (const [x, z] of [[-13, -113], [13, -113], [-13, -137], [13, -137]]) {
    L.box(x - 1, 0, z - 1, x + 1, 12, z + 1, 'stone');
    L.box(x - 1.3, 12, z - 1.3, x + 1.3, 12.4, z + 1.3, 'metal');
  }
  L.brazier(-23, 5, -112);
  L.brazier(23, 5, -148);
  L.brazier(-24, 0, -103);
  L.brazier(24, 0, -103);
  L.brazier(-24, 0, -148);
  L.chain(-25.8, 15, -125, 8);
  L.chain(25.8, 15, -120, 9);
  L.chain(25.8, 15, -130, 6);
  L.skulls(-6, 1, -125, 2);
  L.skulls(22, 0, -106, 6);

  L.arena({
    id: 'a3',
    name: 'ARENA 3',
    trigger: [-26, 0, -106, 26, 8, -103],
    lock: ['d3in'],
    exits: ['d3out'],
    waves: [
      [{ t: 'schism', p: [0, 0, -142] }, { t: 'filth', p: [-18, 0, -146] }, { t: 'filth', p: [18, 0, -120] }, { t: 'filth', p: [-15, 0, -120] }],
      [{ t: 'schism', p: [-18, 0, -146] }, { t: 'stray', p: [-23, 5, -130] }, { t: 'stray', p: [-23, 5, -118] }, { t: 'filth', p: [15, 0, -120] }, { t: 'filth', p: [0, 0, -145] }, { t: 'filth', p: [18, 0, -110] }],
      [{ t: 'schism', p: [-12, 0, -146] }, { t: 'schism', p: [9, 0, -146] }, { t: 'stray', p: [23, 5, -146] }, { t: 'stray', p: [-23, 5, -125] }, { t: 'filth', p: [-8, 0, -110] }, { t: 'filth', p: [8, 0, -110] }],
    ],
    onStart: (g) => g.hud.hint('Düşmanlara YAKIN dövüş: saçılan KAN seni iyileştirir. Lav havuzuna dikkat!', 8),
  });

  // ===== KORİDOR 3 (x -3..3, z -170..-151) =====
  // CEPHANELİK (koridor 3 genişletildi: x -8..8)
  L.box(-9, -2, -171, 9, 0, -150, 'tiles');
  L.box(-9, 8, -170, 9, 9, -151, 'metal');
  L.box(-9, 0, -170, -8, 8, -151, 'metal');
  L.box(8, 0, -170, 9, 8, -151, 'metal');
  L.torch(-7.75, 5, -154);
  L.torch(7.75, 5, -154);
  L.torch(-7.75, 5, -166);
  L.torch(7.75, 5, -166);
  L.sigil(0, 0, -160, 6);
  L.hint([-8, 0, -155, 8, 5, -152], 'CEPHANELİK. Boss\'tan önce dükkândan donan! STİL: çeşitli oyna — aynı silahı sürekli kullanırsan TAZELİK düşer. [1]-[5] silahlar, aynı tuş: varyant.', 9);
  L.shop(0, 0, -163.4, 0);
  L.checkpoint([-8, 0, -168.5, 8, 4, -166], [0, 0, -167], 0);

  // ===== BOSS ARENASI (x -22..22, z -215..-171) =====
  L.box(-23, 0, -171, -3, 18, -170, 'stone');
  L.box(3, 0, -171, 23, 18, -170, 'stone');
  L.box(-3, 6, -171, 3, 18, -170, 'stone');
  L.door('d4in', -3, 0, -170.8, 3, 6, -170.2, { open: true });
  L.box(-23, 0, -216, -22, 18, -170, 'metal');
  L.box(22, 0, -216, 23, 18, -170, 'metal');
  L.box(-23, 0, -216, 23, 18, -215, 'metal');
  for (const sx of [-1, 1]) {
    L.box(sx * 22, 0, -215, sx * 17, 18, -211, 'stone');
    L.box(sx * 22, 0, -211, sx * 19.5, 18, -208, 'stone');
    L.box(sx * 22, 0, -175, sx * 17, 18, -171, 'stone');
    L.box(sx * 22, 0, -178, sx * 19.5, 18, -175, 'stone');
  }
  L.box(-23, -2, -216, 23, 0, -196, 'tiles');
  L.box(-23, -2, -190, 23, 0, -170, 'tiles');
  L.box(-23, -2, -196, -3, 0, -190, 'tiles');
  L.box(3, -2, -196, 23, 0, -190, 'tiles');
  L.door('hatch', -3, -2, -196, 3, 0, -190, { open: false, dir: 'down', travel: 26, mat: 'metal' });
  L.box(-4, -32, -197, -3, -2, -189, 'rock');
  L.box(3, -32, -197, 4, -2, -189, 'rock');
  L.box(-3, -32, -197, 3, -2, -196, 'rock');
  L.box(-3, -32, -190, 3, -2, -189, 'rock');
  L.box(-3, -34, -196, 3, -32, -190, 'rock');
  L.lavaPlane(-3, -196, 3, -190, -31.5);
  for (const [x0, z0] of [[-12, -182], [9, -182], [-12, -205], [9, -205]]) L.box(x0, 0, z0, x0 + 3, 1.5, z0 + 3, 'metal');
  for (const x of [-16, 16]) {
    L.box(x - 1, 0, -194, x + 1, 10, -192, 'stone');
    L.box(x - 1.3, 10, -194.3, x + 1.3, 10.4, -191.7, 'metal');
  }
  L.brazier(-17, 0, -205);
  L.brazier(17, 0, -205);
  L.brazier(-17, 0, -181);
  L.brazier(17, 0, -181);
  L.sigil(0, 0, -206, 11);
  L.chain(-21.8, 17, -185, 10);
  L.chain(21.8, 17, -200, 9);
  L.chain(-21.8, 17, -200, 7);
  L.skulls(-19, 0, -190, 6);
  L.skulls(19, 0, -196, 6);

  L.arena({
    id: 'boss',
    name: 'SWORDSMACHINE',
    trigger: [-22, 0, -177, 22, 8, -173],
    lock: ['d4in'],
    exits: [],
    boss: true,
    bossSub: 'ARAF\'IN BEKÇİSİ',
    waves: [[{ t: 'swordsmachine', p: [0, 0, -205] }]],
    onClear: (g) => g.onBossDefeated('SWORDSMACHINE YOK EDİLDİ', () => {
      L.doors.hatch.open();
      g.hud.hint('Çıkış açıldı — arenanın ortasındaki DELİĞE atla!', 10);
    }),
  });
  L.trigger([-3, -24, -196, 3, -4, -190], () => L.game.levelComplete());

  // Uzak manzara: dev kayalık kuleler
  const spires = [[-70, 10, 70, 6], [65, -20, 55, 5], [-80, -70, 90, 8], [75, -95, 60, 6], [-65, -140, 75, 5], [80, -170, 95, 9], [-85, -210, 65, 7], [40, -270, 80, 8], [-30, -280, 60, 6], [0, 80, 70, 7], [55, 60, 45, 5]];
  for (const [x, z, h, w] of spires) L.spire(x, z, h, w);

  L.finalize();
}
