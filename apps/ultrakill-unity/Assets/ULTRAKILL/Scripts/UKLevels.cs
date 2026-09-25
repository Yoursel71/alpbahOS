// Bölüm düzenleri: web sürümündeki levels/l*.js dosyalarından birebir çevrildi (koordinatlar web
// koordinatlarıdır; UKLevel z eksenini kendisi çevirir). Siber Öğütücü (sonsuz mod) elle yazıldı.
// A(...) dizi, E(tür, konum) doğacak düşman tanımıdır.
using System;
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public static class UKLevels
    {
        static float[] A(params float[] v) => v;
        static float[][] AA(params float[][] v) => v;
        static string[] A(params string[] v) => v;
        static UKSpawn[] A(params UKSpawn[] v) => v;
        static UKSpawn[][] AA(params UKSpawn[][] v) => v;
        static UKSpawn E(string t, float[] p, bool dormant = false) => new UKSpawn { t = t, p = p, dormant = dormant };

        // 0-1 "ATEŞİN İÇİNE": silahsız iniş, tutorial kanadı (atılma zıplaması, kayma, duvar sıçraması,
        // çakış sıçrayışı), Revolver sunağı, 3 arena, parry eğitmeni, 2 dükkân, boss Swordsmachine.

        public static void L01(UKLevel L)
        {
            L.startArmed = false;
            L.AddDecor("filth", -4, 0, -6, 0.4f);
            L.AddDecor("filth", 5, 0, -9, -0.3f);
            L.AddDecor("filth", -7, 0, 1, 1.2f);
            L.AddDecor("schism", 2, 0, -12, 0.1f);
            L.AddDecor("stray", 0, 3, 13.5f, Mathf.PI);
            L.MenuCam( target: A(0, 2.2f, -3), radius: 15, height: 5.5f );

            // ===================== TUTORIAL KANADI (güney, z 17..117) =====================
            // T0 — İniş odası (x -7..7, z 100..116): gökten düşülür, silahsız başlanır
            L.Box(-8, -2, 99, 8, 0, 117, "tiles");
            L.Box(-8, 0, 99, -7, 14, 117, "stone");
            L.Box(7, 0, 99, 8, 14, 117, "stone");
            L.Box(-8, 0, 116, 8, 14, 117, "stone");
            L.Box(-8, 0, 99, -3, 14, 100, "stone");
            L.Box(3, 0, 99, 8, 14, 100, "stone");
            L.Box(-3, 6, 99, 3, 14, 100, "stone");
            L.Brazier(-5, 0, 113);
            L.Brazier(5, 0, 113);
            L.Sigil(0, 0, 108, 8);
            L.Chain(-6.8f, 13, 106, 6);
            L.Chain(6.8f, 13, 110, 5);
            L.Skulls(-5, 0, 103, 5);
            L.Hint(A(-7, 0, 100, 7, 3, 116), "[WASD] yürü · [BOŞLUK] zıpla · fareyle bak. Silahın yok — önce hareketi öğren. Kuzeydeki kapıdan ilerle.", 9);

            // T1 — Atılma boşluğu (z 76..99, boşluk z 81..94)
            L.Box(-4, -16, 94, 4, 0, 99, "tiles");
            L.Box(-4, -16, 76, 4, 0, 81, "tiles");
            L.Box(-4, -16, 81, -3, 0, 94, "rock");
            L.Box(3, -16, 81, 4, 0, 94, "rock");
            L.Box(-3, -18, 81, 3, -14, 94, "rock");
            L.LavaPlane(-3, 81, 3, 94, -13.5f);
            L.HurtZone(A(-3, -16, 81, 3, -12, 94), 0, "pit");
            L.Box(-4, 0, 76, -3, 8, 99, "stone");
            L.Box(3, 0, 76, 4, 8, 99, "stone");
            L.Box(-4, 8, 76, 4, 9, 99, "rock");
            L.Torch(-2.75f, 5, 96);
            L.Torch(2.75f, 5, 79);
            L.Hint(A(-3, 0, 95, 3, 5, 98.5f), "Boşluk normal zıplamak için fazla geniş! [SHIFT] ile ATIL, atılırken [BOŞLUK] → ATILMA ZIPLAMASI. Atılırken hasar da almazsın.", 10);

            // T2 — Kayma koridoru (z 58..76)
            L.Box(-4, -2, 58, 4, 0, 76, "tiles");
            L.Box(-4, 0, 58, -3, 6, 76, "stone");
            L.Box(3, 0, 58, 4, 6, 76, "stone");
            L.Box(-4, 6, 58, 4, 7, 76, "metal");
            L.Box(-3, 1.1f, 66, 3, 6, 68, "metal");
            L.Box(-3, 1.1f, 65.8f, 3, 1.4f, 68.2f, "door",  solid: false, texScale: 6 );
            L.Torch(-2.75f, 4, 72);
            L.Hint(A(-3, 0, 72, 3, 5, 75), "Alçak engel! Koşarken [C] basılı tut → KAY. Kayarken hızını korursun; kayarken zıplamak uzağa fırlatır.", 9);

            // T3 — Duvar sıçrama kuyusu (x -2.5..2.5, z 44..58), çıkış çıkıntısı y=7
            L.Box(-3.5f, -2, 43, 3.5f, 0, 58, "tiles");
            L.Box(-3.5f, 0, 44, -2.5f, 14, 58, "stone");
            L.Box(2.5f, 0, 44, 3.5f, 14, 58, "stone");
            L.Box(-2.5f, 0, 44, 2.5f, 7, 48, "stone");
            L.Box(-2.5f, 0, 52, -0.8f, 2, 54.5f, "metal");
            L.Box(-3.5f, 0, 43, 3.5f, 7, 44, "stone");
            L.Box(-3.5f, 12.5f, 43, 3.5f, 14, 44, "stone");
            L.Torch(-2.25f, 9, 50);
            L.Torch(2.25f, 9, 55);
            L.Hint(A(-2.5f, 0, 55, 2.5f, 5, 57.5f), "DUVAR SIÇRAMASI: havadayken duvara doğru [BOŞLUK] (yere değmeden 3 kez). İki duvar arasında sekerek yukarıdaki çıkıntıya tırman!", 11);

            // T4 — Çakma odası (x -6..6, z 26..43); kuzey çıkıntısı y=6.5
            L.Box(-7, -2, 25, 7, 0, 44, "tiles");
            L.Box(-7, 0, 25, -6, 14, 44, "stone");
            L.Box(6, 0, 25, 7, 14, 44, "stone");
            L.Box(-7, 0, 43, -3.5f, 14, 44, "stone");
            L.Box(3.5f, 0, 43, 7, 14, 44, "stone");
            L.Box(-6, 0, 26, 6, 6.5f, 30, "stone");
            L.Box(-7, 0, 25, -3, 14, 26, "stone");
            L.Box(3, 0, 25, 7, 14, 26, "stone");
            L.Box(-3, 12, 25, 3, 14, 26, "stone");
            L.Sigil(0, 0, 36, 5);
            L.Brazier(-4.5f, 0, 40.5f);
            L.Brazier(4.5f, 0, 40.5f);
            L.Hint(A(-6, 0, 30.5f, 6, 4, 42.5f), "Çıkıntı çok yüksek! Yüksekten düşerken [C] → YERE ÇAK. Yere çarptığın an [BOŞLUK] → ÇAKIŞ SIÇRAYIŞI. Tekrar denemek için duvar sıçramasıyla yüksel.", 12);

            // T5 — Revolver sunağı (üst kat y=6.5, z 21..26; merdivenle y=3'e iner, kapı arenaya açılır)
            L.Box(-8, 1, 16, 8, 3, 21, "tiles");
            L.Box(-8, 4.5f, 21, 8, 6.5f, 26, "tiles");
            L.StairsZ(-3, 3, 17, 21, 3, 6.5f, 7, "metal");
            L.Box(-8, 0, 16, -7, 14, 26, "stone");
            L.Box(7, 0, 16, 8, 14, 26, "stone");
            L.Box(-7, 6.5f, 21, -3, 7.5f, 21.4f, "metal",  solid: false );
            L.Box(3, 6.5f, 21, 7, 7.5f, 21.4f, "metal",  solid: false );
            L.Brazier(-5.5f, 6.5f, 24.5f);
            L.Brazier(5.5f, 6.5f, 24.5f);
            L.Altar(0, 6.5f, 23.4f, 0, (g) => g.Schedule(2.4f, () => {
                g.hud.Hint("REVOLVER: [SOL TIK] ateş · [SAĞ TIK] basılı tut → PIERCER şarjlı delici atış. [1]'e tekrar bas: MARKSMAN (bozuk para at, paraya ateş et → RICOSHOT). Kafadan vuruş 2x hasar.", 12);
                g.SetCheckpoint(UKLevel.P(0, 6.5f, 22), 0);
                L.doors["dT"].Open();
            }), (g) => g.ApplyLoadout());

            // ===== ARENA 1: Düşüş odası (x -16..16, z -16..16) =====
            L.Box(-17, -2, -17, 17, 0, 17, "tiles");
            L.Box(-17, 0, 16, -3, 14, 17, "stone");
            L.Box(3, 0, 16, 17, 14, 17, "stone");
            L.Box(-3, 0, 16, 3, 3, 17, "stone");
            L.Box(-3, 9, 16, 3, 14, 17, "stone");
            L.Door("dT", -3, 3, 16.2f, 3, 9, 16.8f,  open: false );
            L.Box(16, 0, -17, 17, 14, 17, "stone");
            L.Box(-17, 0, -17, -16, 14, 17, "stone");
            L.Box(-17, 0, -17, -3, 14, -16, "stone");
            L.Box(3, 0, -17, 17, 14, -16, "stone");
            L.Box(-3, 6, -17, 3, 14, -16, "stone");
            L.Door("d1", -3, 0, -16.8f, 3, 6, -16.2f,  open: false );
            // güney çıkıntı ve merdiven
            L.Box(-16, 0, 11, 16, 3, 16, "stone");
            L.StairsZ(-2, 2, 7.4f, 11, 0, 3, 6, "metal");
            // sütunlar
            foreach (var _q1 in AA(A(-9, -9), A(9, -9), A(-9, 3), A(9, 3))) { var x = _q1[0]; var z = _q1[1];
                L.Box(x - 1, 0, z - 1, x + 1, 9, z + 1, "stone");
                L.Box(x - 1.3f, 9, z - 1.3f, x + 1.3f, 9.4f, z + 1.3f, "metal");
                L.Box(x - 1.3f, 0, z - 1.3f, x + 1.3f, 0.4f, z + 1.3f, "metal");
            }
            L.Box(-5, 0, -3, -2, 1.2f, -1.5f, "metal");
            L.Box(2, 0, 1, 5, 1.2f, 2.5f, "metal");
            L.Brazier(-14, 0, -14);
            L.Brazier(14, 0, -14);
            L.Brazier(-14, 3, 14);
            L.Brazier(14, 3, 14);
            L.Sigil(0, 0, -2, 12);
            L.Chain(-15.8f, 13, -6, 5);
            L.Chain(15.8f, 13, -2, 6);
            L.Chain(-15.8f, 13, 6, 4);
            L.Skulls(-13, 0, 8, 6);
            L.Skulls(12, 0, -2, 4);

            L.Arena(
                id: "a1",
                name: "ARENA 1",
                trigger: A(-16, 0, -16, 16, 2.5f, 11),
                locks: A("dT"),
                exits: A("d1"),
                waves: AA(
                    A(E("filth", A(-8, 0, -13)), E("filth", A(8, 0, -13)), E("filth", A(0, 0, -14))),
                    A(E("filth", A(-13, 0, 0)), E("filth", A(13, 0, 0)), E("filth", A(-6, 0, -13)), E("filth", A(6, 0, -13)), E("stray", A(0, 3, 13.5f)))
                ),
                onStart: (g) => g.hud.Hint("Arena kilitlendi! Tüm düşmanları öldür — kapılar ancak alan temizlenince açılır. Havadaki düşmanı vurmak: +AIRSHOT", 8)
            );

            // ===== KORİDOR 1 (x -3..3, z -40..-17) =====
            L.Box(-4, -16, -24, 4, 0, -17, "tiles");
            L.Box(-4, -16, -41, 4, 0, -30, "tiles");
            L.Box(-4, -16, -30, -3, 0, -24, "rock");
            L.Box(3, -16, -30, 4, 0, -24, "rock");
            L.Box(-3, -18, -30, 3, -14, -24, "rock");
            L.LavaPlane(-3, -30, 3, -24, -13.5f);
            L.HurtZone(A(-3, -16, -30, 3, -12, -24), 30, "pit");
            // duvarlar (batı duvarında gizli oda açıklığı)
            L.Box(-4, 0, -34, -3, 7, -17, "stone");
            L.Box(-4, 0, -41, -3, 7, -37, "stone");
            L.Box(-4, 0, -37, -3, 3.5f, -34, "stone");
            L.Box(3, 0, -35, 4, 7, -17, "stone");
            L.Box(3, 0, -41, 4, 7, -39, "stone");
            // Parry eğitmeni kafesi (doğu nişi, parmaklıklar yalnız oyuncuyu durdurur)
            L.Box(4, -2, -40, 8, 0, -34, "tiles");
            L.Box(7, 0, -40, 8, 7, -34, "stone");
            L.Box(4, 0, -40, 8, 7, -39, "stone");
            L.Box(4, 0, -35, 8, 7, -34, "stone");
            L.Box(3, 7, -40, 8, 8, -34, "rock");
            foreach (var z in A(-38.6f, -37.8f, -37.0f, -36.2f, -35.4f)) { L.Box(3.35f, 0, z - 0.07f, 3.5f, 7, z + 0.07f, "metal",  playerOnly: true, texScale: 1 ); }
            L.Box(3.3f, 6.6f, -39, 3.55f, 7, -35, "metal",  solid: false );
            L.Torch(6.75f, 4.5f, -37);
            L.Trainer( p: A(5.6f, 0, -37), door: "d2in" );
            L.Hint(A(-3, 0, -32, 3, 5, -30), "PARRY EĞİTİMİ: Eğitmenin attığı küre sana çarpmadan hemen önce [F] ile yumrukla. Nişangâhı eğitmene çevir — küre geri seker, onu vurunca kapı açılır.", 12);
            L.Box(-4, 7, -41, 4, 8, -17, "rock");
            L.Torch(-2.75f, 4.5f, -20);
            L.Torch(2.75f, 4.5f, -36);
            // Gizli oda 1 (duvar sıçramasıyla)
            L.Box(-10, 1.5f, -39, -3.9f, 3.5f, -32, "stone");
            L.Box(-10, 7, -39, -3.9f, 8, -32, "stone");
            L.Box(-10, 3.5f, -39, -9, 7, -32, "stone");
            L.Box(-9, 3.5f, -39, -3.9f, 7, -38, "stone");
            L.Box(-9, 3.5f, -33, -3.9f, 7, -32, "stone");
            L.Skulls(-8, 3.5f, -36.8f, 3);
            L.Secret(-6.8f, 4.7f, -35.5f);

            // İlk dükkân (batı duvarı, ekran doğuya bakar)
            L.Shop(-2.25f, 0, -20.2f, Mathf.PI / 2);
            L.Hint(A(-3, 0, -21.5f, 3, 5, -18), "DÜKKÂN! Kazandığın STİL puanı P olarak birikir. Terminalin önünde [B] (mobilde DÜKKÂN butonu) ile yeni silah, varyant ve kol satın al.", 10);
            L.Hint(A(-3, 0, -23.5f, 3, 5, -22), "Boşluğu geç: koşarak zıpla ya da ATILIRKEN ZIPLA [SHIFT → BOŞLUK] ile uzağa fırla.", 7);
            L.Hint(A(-3, 0, -33, 3, 5, -31), "Havadayken duvara doğru [BOŞLUK]: DUVAR SIÇRAMASI (yere değmeden 3 kez).", 7);
            L.Checkpoint(A(-3, 0, -39.5f, 3, 4, -36.5f), A(0, 0, -38), 0);

            // ===== ARENA 2: Sütunlu salon (x -20..20, z -80..-41) =====
            L.Box(-21, -2, -81, 21, 0, -40, "tiles");
            L.Box(-21, 0, -81, -20, 14, -40, "stone");
            L.Box(20, 0, -81, 21, 14, -40, "stone");
            L.Box(-21, 0, -41, -3, 14, -40, "stone");
            L.Box(3, 0, -41, 21, 14, -40, "stone");
            L.Box(-3, 6, -41, 3, 14, -40, "stone");
            L.Door("d2in", -3, 0, -40.8f, 3, 6, -40.2f,  open: false );
            L.Box(-21, 0, -81, -3, 14, -80, "stone");
            L.Box(3, 0, -81, 21, 14, -80, "stone");
            L.Box(-3, 6, -81, 3, 14, -80, "stone");
            L.Door("d2out", -3, 0, -80.8f, 3, 6, -80.2f,  open: false );
            // balkonlar
            L.Box(-20, 0, -75, -13, 4, -46, "stone");
            L.Box(13, 0, -75, 20, 4, -46, "stone");
            L.Box(-13.4f, 4, -75, -13, 5, -54, "metal");
            L.Box(13, 4, -64, 13.4f, 5, -46, "metal");
            L.StairsX(-52, -48, -9, -13, 0, 4, 8, "metal");
            L.StairsX(-70, -66, 9, 13, 0, 4, 8, "metal");
            // orta platform
            L.Box(-5, 0, -64, 5, 2, -56, "metal");
            L.Sigil(0, 2, -60, 7);
            foreach (var _q2 in AA(A(-6, -50), A(6, -50), A(-6, -72), A(6, -72))) { var x = _q2[0]; var z = _q2[1];
                L.Box(x - 1, 0, z - 1, x + 1, 10, z + 1, "stone");
                L.Box(x - 1.3f, 10, z - 1.3f, x + 1.3f, 10.4f, z + 1.3f, "metal");
            }
            L.Brazier(-17, 0, -78);
            L.Brazier(17, 0, -78);
            L.Brazier(-16.5f, 4, -47.5f);
            L.Brazier(16.5f, 4, -73.5f);
            L.Chain(-19.8f, 13, -60, 7);
            L.Chain(19.8f, 13, -56, 5);
            L.Skulls(-17, 4, -70, 4);
            L.Skulls(16, 4, -52, 5);

            L.Arena(
                id: "a2",
                name: "ARENA 2",
                trigger: A(-20, 0, -45, 20, 6, -42),
                locks: A("d2in"),
                exits: A("d2out"),
                waves: AA(
                    A(E("stray", A(-16.5f, 4, -60)), E("stray", A(16.5f, 4, -58)), E("filth", A(0, 0, -70)), E("filth", A(-6, 0, -77)), E("filth", A(6, 0, -77))),
                    A(E("stray", A(-16.5f, 4, -70)), E("stray", A(16.5f, 4, -50)), E("stray", A(0, 2, -60)), E("filth", A(-12, 0, -78)), E("filth", A(12, 0, -78)), E("filth", A(0, 0, -77)), E("filth", A(9, 0, -64)))
                ),
                onStart: (g) => g.hud.Hint("PARLAYAN (mavi yıldızlı) yakın saldırılar da [F] ile savuşturulur. PARRY canını tamamen doldurur!", 9)
            );

            // ===== KORİDOR 2 (x -3..3, z -100..-81) =====
            L.Box(-4, -2, -100, 4, 0, -80, "tiles");
            L.Box(-4, 6, -100, 4, 7, -80, "metal");
            L.Box(-4, 0, -100, -3, 6, -80, "stone");
            L.Box(3, 0, -85, 4, 6, -80, "stone");
            L.Box(3, 0, -100, 4, 6, -87, "stone");
            L.Box(3, 1.0f, -87, 4, 6, -85, "stone");
            // kayarak geçilen engel
            L.Box(-3, 1.1f, -92, 3, 6, -90, "metal");
            L.Box(-3, 1.1f, -92.2f, 3, 1.4f, -89.8f, "door",  solid: false, texScale: 6 );
            // Gizli oda 2 (kayarak girilen havalandırma)
            L.Box(4, -2, -89, 11, 0, -83, "tiles");
            L.Box(4, 0, -88, 6, 1, -87, "metal");
            L.Box(4, 0, -85, 6, 1, -84, "metal");
            L.Box(4, 1, -88, 6, 5, -84, "metal");
            L.Box(6, 0, -89, 11, 5, -88, "stone");
            L.Box(6, 0, -84, 11, 5, -83, "stone");
            L.Box(10, 0, -88, 11, 5, -84, "stone");
            L.Box(6, 5, -88, 10, 6, -84, "stone");
            L.Secret(8.5f, 1.3f, -86);
            L.Torch(-2.75f, 4, -84);
            L.Torch(-2.75f, 4, -96);
            L.Hint(A(-3, 0, -84, 3, 5, -82), "Yerdeyken [C]: KAY — alçak engellerin altından geç. Havadayken [C]: YERE ÇAK; çakıştan hemen sonra [BOŞLUK] = YÜKSEK SIÇRAYIŞ.", 9);
            L.Checkpoint(A(-3, 0, -99, 3, 4, -96), A(0, 0, -97.5f), 0);
            // Pusu: koridorun sonunda üç Filth yerden çıkar
            L.ExtraEnemies( trigger: A(-3, 0, -96, 3, 4, -93), list: A(E("filth", A(-2, 0, -99.3f)), E("filth", A(2, 0, -99.3f)), E("filth", A(0, 0, -99.5f))) );

            // ===== ARENA 3: Lav havuzu (x -26..26, z -150..-101) =====
            L.Box(-27, -2, -116, 27, 0, -100, "tiles");
            L.Box(-27, -2, -151, 27, 0, -134, "tiles");
            L.Box(-27, -2, -134, -10, 0, -116, "tiles");
            L.Box(10, -2, -134, 27, 0, -116, "tiles");
            L.Box(-10, -3, -134, 10, -1.5f, -116, "rock");
            L.LavaPlane(-10, -134, 10, -116, -1.0f);
            L.HurtZone(A(-10, -1.6f, -134, 10, -0.8f, -116), 22, "lava");
            L.Box(-2.5f, -1.5f, -127.5f, 2.5f, 1, -122.5f, "stone");
            L.Box(-27, 0, -151, -26, 16, -100, "flesh");
            L.Box(26, 0, -151, 27, 16, -100, "flesh");
            L.Box(-27, 0, -101, -3, 16, -100, "flesh");
            L.Box(3, 0, -101, 27, 16, -100, "flesh");
            L.Box(-3, 6, -101, 3, 16, -100, "stone");
            L.Door("d3in", -3, 0, -100.8f, 3, 6, -100.2f,  open: true );
            L.Box(-27, 0, -151, -3, 16, -150, "flesh");
            L.Box(3, 0, -151, 27, 16, -150, "flesh");
            L.Box(-3, 6, -151, 3, 16, -150, "stone");
            L.Door("d3out", -3, 0, -150.8f, 3, 6, -150.2f,  open: false );
            // batı balkonu + merdiven
            L.Box(-26, 0, -140, -20, 5, -110, "stone");
            L.StairsX(-126, -122, -15, -20, 0, 5, 10, "metal");
            // kuzeydoğu balkonu + parkur sütunları (gizli 3)
            L.Box(20, 0, -150, 26, 5, -142, "stone");
            L.StairsX(-150, -147, 15.5f, 20, 0, 5, 10, "metal");
            L.Box(15.5f, 0, -145.5f, 17, 6.5f, -144, "stone");
            L.Box(12, 0, -141.5f, 13.5f, 8, -140, "stone");
            L.Box(15, 0, -137.5f, 16.5f, 9.5f, -136, "stone");
            L.Secret(15.75f, 10.5f, -136.75f);
            foreach (var _q3 in AA(A(-13, -113), A(13, -113), A(-13, -137), A(13, -137))) { var x = _q3[0]; var z = _q3[1];
                L.Box(x - 1, 0, z - 1, x + 1, 12, z + 1, "stone");
                L.Box(x - 1.3f, 12, z - 1.3f, x + 1.3f, 12.4f, z + 1.3f, "metal");
            }
            L.Brazier(-23, 5, -112);
            L.Brazier(23, 5, -148);
            L.Brazier(-24, 0, -103);
            L.Brazier(24, 0, -103);
            L.Brazier(-24, 0, -148);
            L.Chain(-25.8f, 15, -125, 8);
            L.Chain(25.8f, 15, -120, 9);
            L.Chain(25.8f, 15, -130, 6);
            L.Skulls(-6, 1, -125, 2);
            L.Skulls(22, 0, -106, 6);

            L.Arena(
                id: "a3",
                name: "ARENA 3",
                trigger: A(-26, 0, -106, 26, 8, -103),
                locks: A("d3in"),
                exits: A("d3out"),
                waves: AA(
                    A(E("schism", A(0, 0, -142)), E("filth", A(-18, 0, -146)), E("filth", A(18, 0, -120)), E("filth", A(-15, 0, -120))),
                    A(E("schism", A(-18, 0, -146)), E("stray", A(-23, 5, -130)), E("stray", A(-23, 5, -118)), E("filth", A(15, 0, -120)), E("filth", A(0, 0, -145)), E("filth", A(18, 0, -110))),
                    A(E("schism", A(-12, 0, -146)), E("schism", A(9, 0, -146)), E("stray", A(23, 5, -146)), E("stray", A(-23, 5, -125)), E("filth", A(-8, 0, -110)), E("filth", A(8, 0, -110)))
                ),
                onStart: (g) => g.hud.Hint("Düşmanlara YAKIN dövüş: saçılan KAN seni iyileştirir. Lav havuzuna dikkat!", 8)
            );

            // ===== KORİDOR 3 (x -3..3, z -170..-151) =====
            // CEPHANELİK (koridor 3 genişletildi: x -8..8)
            L.Box(-9, -2, -171, 9, 0, -150, "tiles");
            L.Box(-9, 8, -170, 9, 9, -151, "metal");
            L.Box(-9, 0, -170, -8, 8, -151, "metal");
            L.Box(8, 0, -170, 9, 8, -151, "metal");
            L.Torch(-7.75f, 5, -154);
            L.Torch(7.75f, 5, -154);
            L.Torch(-7.75f, 5, -166);
            L.Torch(7.75f, 5, -166);
            L.Sigil(0, 0, -160, 6);
            L.Hint(A(-8, 0, -155, 8, 5, -152), "CEPHANELİK. Boss'tan önce dükkândan donan! STİL: çeşitli oyna — aynı silahı sürekli kullanırsan TAZELİK düşer. [1]-[5] silahlar, aynı tuş: varyant.", 9);
            L.Shop(0, 0, -163.4f, 0);
            L.Checkpoint(A(-8, 0, -168.5f, 8, 4, -166), A(0, 0, -167), 0);

            // ===== BOSS ARENASI (x -22..22, z -215..-171) =====
            L.Box(-23, 0, -171, -3, 18, -170, "stone");
            L.Box(3, 0, -171, 23, 18, -170, "stone");
            L.Box(-3, 6, -171, 3, 18, -170, "stone");
            L.Door("d4in", -3, 0, -170.8f, 3, 6, -170.2f,  open: true );
            L.Box(-23, 0, -216, -22, 18, -170, "metal");
            L.Box(22, 0, -216, 23, 18, -170, "metal");
            L.Box(-23, 0, -216, 23, 18, -215, "metal");
            foreach (var sx in A(-1, 1)) {
                L.Box(sx * 22, 0, -215, sx * 17, 18, -211, "stone");
                L.Box(sx * 22, 0, -211, sx * 19.5f, 18, -208, "stone");
                L.Box(sx * 22, 0, -175, sx * 17, 18, -171, "stone");
                L.Box(sx * 22, 0, -178, sx * 19.5f, 18, -175, "stone");
            }
            L.Box(-23, -2, -216, 23, 0, -196, "tiles");
            L.Box(-23, -2, -190, 23, 0, -170, "tiles");
            L.Box(-23, -2, -196, -3, 0, -190, "tiles");
            L.Box(3, -2, -196, 23, 0, -190, "tiles");
            L.Door("hatch", -3, -2, -196, 3, 0, -190,  open: false, dir: "down", travel: 26, mat: "metal" );
            L.Box(-4, -32, -197, -3, -2, -189, "rock");
            L.Box(3, -32, -197, 4, -2, -189, "rock");
            L.Box(-3, -32, -197, 3, -2, -196, "rock");
            L.Box(-3, -32, -190, 3, -2, -189, "rock");
            L.Box(-3, -34, -196, 3, -32, -190, "rock");
            L.LavaPlane(-3, -196, 3, -190, -31.5f);
            foreach (var _q4 in AA(A(-12, -182), A(9, -182), A(-12, -205), A(9, -205))) { var x0 = _q4[0]; var z0 = _q4[1]; L.Box(x0, 0, z0, x0 + 3, 1.5f, z0 + 3, "metal"); }
            foreach (var x in A(-16, 16)) {
                L.Box(x - 1, 0, -194, x + 1, 10, -192, "stone");
                L.Box(x - 1.3f, 10, -194.3f, x + 1.3f, 10.4f, -191.7f, "metal");
            }
            L.Brazier(-17, 0, -205);
            L.Brazier(17, 0, -205);
            L.Brazier(-17, 0, -181);
            L.Brazier(17, 0, -181);
            L.Sigil(0, 0, -206, 11);
            L.Chain(-21.8f, 17, -185, 10);
            L.Chain(21.8f, 17, -200, 9);
            L.Chain(-21.8f, 17, -200, 7);
            L.Skulls(-19, 0, -190, 6);
            L.Skulls(19, 0, -196, 6);

            L.Arena(
                id: "boss",
                name: "SWORDSMACHINE",
                trigger: A(-22, 0, -177, 22, 8, -173),
                locks: A("d4in"),
                exits: null,
                boss: true,
                bossSub: "ARAF'IN BEKÇİSİ",
                waves: AA(A(E("swordsmachine", A(0, 0, -205)))),
                onClear: (g) => g.OnBossDefeated("SWORDSMACHINE YOK EDİLDİ", () => {
                    L.doors["hatch"].Open();
                    g.hud.Hint("Çıkış açıldı — arenanın ortasındaki DELİĞE atla!", 10);
                })
            );
            L.Trigger(A(-3, -24, -196, 3, -4, -190), () => L.game.LevelComplete());

            // Uzak manzara: dev kayalık kuleler
            var spires = AA(A(-70, 10, 70, 6), A(65, -20, 55, 5), A(-80, -70, 90, 8), A(75, -95, 60, 6), A(-65, -140, 75, 5), A(80, -170, 95, 9), A(-85, -210, 65, 7), A(40, -270, 80, 8), A(-30, -280, 60, 6), A(0, 80, 70, 7), A(55, 60, 45, 5));
            foreach (var _q5 in spires) { var x = _q5[0]; var z = _q5[1]; var h = _q5[2]; var w = _q5[3]; L.Spire(x, z, h, w); }

            L.FinishBuild();
        }

        // 0-2 "KIYMA MAKİNESİ": et ve öğütücülerle dolu mezbaha. Öğütücü çukurlu kasap salonu,
        // kayarak geçilen koridor + dükkân, iki katlı kıyma çukuru arenası, çıkış deliği.

        public static void L02(UKLevel L)
        {
            L.Theme_(
                fog: 0x2a0410, fogNear: 26, fogFar: 130,
                skyTop: A(0.03f, 0.0f, 0.02f), skyHor: A(0.28f, 0.02f, 0.07f), skyCloud: A(0.22f, 0.02f, 0.06f), skyGlow: A(0.4f, 0.03f, 0.1f),
                hemiSky: 0xff9aa8, hemiGround: 0x3a0a18, hemi: 1.8f, ambient: 0x5a2838, sun: 0xff7a90
            );
            L.SetSpawn( pos: A(0, 30, 10), yaw: 0, checkpoint: A(0, 0, 10) );
            L.MenuCam( target: A(0, 2, -32), radius: 13, height: 6 );
            L.AddDecor("filth", -7, 0, -22, 0.5f);
            L.AddDecor("filth", 8, 0, -40, -0.4f);
            L.AddDecor("schism", -9, 0, -44, 0.3f);
            L.AddDecor("stray", 15, 4, -30, -1.2f);
            L.AddDecor("filth", 6, 0, -22, -0.6f);

            // ===== Giriş odası (x -8..8, z 0..16), gökten düşülür =====
            L.Room(-8, 0, 8, 16,  h: 12, mat: "meat", gaps: UKLevel.MakeGaps(n: A(-3, 3, 6)) );
            L.Box(-8, 11.4f, 11, 8, 12, 12, "metal",  solid: false );
            L.MeatHook(-4, 11.4f, 11.5f, 2.5f);
            L.MeatHook(3, 11.4f, 11.5f, 3.5f);
            L.Brazier(-6, 0, 14);
            L.Brazier(6, 0, 14);
            L.Sigil(0, 0, 9, 7);
            L.Skulls(5, 0, 3, 5);
            L.Shop(-6.4f, 0, 6, Mathf.PI / 2);
            L.Hint(A(-7, 0, 1, 7, 3, 15), "0-2: KIYMA MAKİNESİ. Yeşil terminal DÜKKÂN — stil puanın (P) ile silah al. Sonra kuzeye ilerle.", 8);

            // ===== Koridor 1 (x -3..3, z -14..0) + öğütücü çukuru (z -9..-4) =====
            L.Box(-4, -2, -4, 4, 0, -1, "tiles");
            L.Box(-4, -2, -13, 4, 0, -9, "tiles");
            L.Pit(-3, -9, 3, -4,  depth: 8, dmg: 20 );
            L.Grinder(0, -3.2f, -6.5f, 6, "x", 0.8f);
            L.Box(-4, 0, -14, -3, 7, 0, "meat");
            L.Box(3, 0, -14, 4, 7, 0, "meat");
            L.Box(-4, 7, -14, 4, 8, 0, "rock");
            L.Torch(-2.75f, 4.5f, -2);
            L.Torch(2.75f, 4.5f, -12);
            L.Hint(A(-3, 0, -3, 3, 4, -0.5f), "Öğütücüye düşme! Koşarak zıpla.", 5);

            // ===== ARENA A: Kasap salonu (x -18..18, z -50..-14), ortada öğütücü çukuru =====
            L.Room(-18, -50, 18, -14,  h: 14, mat: "meat", floor: null, gaps: UKLevel.MakeGaps(s: A(-3, 3, 6), n: A(-3, 3, 6)) );
            L.FloorWithHoles(-19, -51, 19, -13, AA(A(-4, -36, 4, -28)));
            L.Pit(-4, -36, 4, -28,  depth: 9, dmg: 25 );
            L.Grinder(0, -3.4f, -32, 8, "x", 1.0f);
            L.Door("dA_in", -3, 0, -13.8f, 3, 6, -13.2f,  open: true );
            L.Door("dA_out", -3, 0, -50.8f, 3, 6, -50.2f,  open: false );
            foreach (var _q1 in AA(A(-10, -22), A(10, -22), A(-10, -42), A(10, -42))) { var x = _q1[0]; var z = _q1[1]; L.Pillar(x, z, 14, 1, "stone"); }
            // balkonlar
            L.Box(-18, 0, -46, -12, 4, -18, "stone");
            L.Box(12, 0, -46, 18, 4, -18, "stone");
            L.Box(-12.4f, 4, -46, -12, 5, -33, "metal");
            L.Box(12, 4, -30, 12.4f, 5, -18, "metal");
            L.StairsX(-30, -26, -8, -12, 0, 4, 8, "metal");
            L.StairsX(-40, -36, 8, 12, 0, 4, 8, "metal");
            // kirişler ve asılı etler
            foreach (var z in A(-20, -32, -44)) { L.Box(-18, 13.4f, z - 0.4f, 18, 14, z + 0.4f, "metal",  solid: false ); }
            foreach (var _q2 in AA(A(-6, -20, 3), A(5, -20, 4), A(-14, -32, 5), A(8, -32, 3), A(-3, -44, 4), A(13, -44, 5))) { var x = _q2[0]; var z = _q2[1]; var n = _q2[2]; L.MeatHook(x, 13.4f, z, n); }
            // gizli 1: kuzeydoğu köşesinde yüksek çıkıntı (balkondan köşede duvar sıçraması)
            L.Box(14, 8, -50, 18, 8.5f, -47, "stone");
            L.Secret(16, 9.4f, -48.6f);
            L.Brazier(-16, 0, -48);
            L.Brazier(16, 0, -16);
            L.Brazier(-15, 4, -20);
            L.Brazier(15, 4, -44);
            L.Sigil(0, 0, -21, 6);
            L.Skulls(-6, 0, -48, 5);
            L.Skulls(7, 0, -16, 4);

            L.Arena(
                id: "a1", name: "KASAP SALONU",
                trigger: A(-18, 0, -20, 18, 6, -15),
                locks: A("dA_in"), exits: A("dA_out"),
                waves: AA(
                    A(E("filth", A(-8, 0, -45)), E("filth", A(8, 0, -45)), E("filth", A(-6, 0, -47)), E("filth", A(6, 0, -47)), E("filth", A(0, 0, -46)), E("filth", A(-8, 0, -38)), E("stray", A(-15, 4, -30)), E("stray", A(15, 4, -34))),
                    A(E("filth", A(-10, 0, -18)), E("filth", A(10, 0, -18)), E("filth", A(-8, 0, -47)), E("filth", A(8, 0, -47)), E("schism", A(0, 0, -45)), E("stray", A(-15, 4, -40)), E("stray", A(15, 4, -22))),
                    A(E("filth", A(-7, 0, -40)), E("filth", A(7, 0, -40)), E("filth", A(-6, 0, -18)), E("filth", A(6, 0, -18)), E("filth", A(-2, 0, -47)), E("filth", A(2, 0, -47)), E("schism", A(-9, 0, -48)), E("schism", A(9, 0, -48)))
                ),
                onStart: (g) => g.hud.Hint("KIYMA MAKİNESİ: düşmanları ortadaki öğütücüye at! Yumruk ve patlamalar geri iter.", 8)
            );

            // ===== Koridor 2 (x -3..3, z -70..-51): kayma engeli, dükkân nişi, gizli havalandırma =====
            L.Box(-4, -2, -71, 4, 0, -50, "tiles");
            L.Box(-4, 0, -71, -3, 7, -63, "meat");
            L.Box(-4, 0, -59, -3, 7, -51, "meat");
            L.Box(-4, 0, -63, -3, 5, -59, "meat");
            L.Box(3, 0, -71, 4, 7, -67, "meat");
            L.Box(3, 0, -61, 4, 7, -51, "meat");
            L.Box(3, 6, -67, 4, 7, -61, "meat");
            L.Box(-4, 7, -71, 4, 8, -51, "rock");
            L.Box(-3, 1.1f, -57, 3, 7, -55, "metal");
            L.Box(-3, 1.1f, -57.2f, 3, 1.4f, -54.8f, "door",  solid: false, texScale: 6 );
            L.Hint(A(-3, 0, -54, 3, 4, -52), "Alçak engel — koşarken [C] ile KAY.", 5);
            // dükkân nişi (doğu)
            L.Box(4, -2, -67, 9, 0, -61, "tiles");
            L.Box(8, 0, -67, 9, 6, -61, "meat");
            L.Box(4, 0, -68, 9, 6, -67, "meat");
            L.Box(4, 0, -61, 9, 6, -60, "meat");
            L.Box(4, 6, -68, 9, 7, -60, "rock");
            L.Shop(7.2f, 0, -64, -Mathf.PI / 2);
            L.Checkpoint(A(-3, 0, -69, 3, 4, -62), A(0, 0, -66), 0);
            // gizli 2: batı duvarında yüksek havalandırma (duvar sıçramasıyla)
            L.Box(-9, 4, -64, -4, 5, -58, "metal");
            L.Box(-9, 7, -64, -4, 8, -58, "metal");
            L.Box(-10, 4, -64, -9, 8, -58, "metal");
            L.Box(-9, 5, -64, -4, 7, -63, "metal");
            L.Box(-9, 5, -59, -4, 7, -58, "metal");
            L.Secret(-7.5f, 5.8f, -61);
            L.Torch(-2.75f, 4.5f, -68);

            // ===== ARENA B: Kıyma çukuru (x -22..22, z -120..-71) =====
            L.Room(-22, -120, 22, -71,  h: 16, mat: "meat", floor: null, gaps: UKLevel.MakeGaps(s: A(-3, 3, 6), n: A(-3, 3, 6)) );
            L.FloorWithHoles(-23, -121, 23, -70, AA(A(-8, -106, 8, -86)));
            L.Pit(-8, -106, 8, -86,  depth: 10, dmg: 25 );
            L.Grinder(-3.5f, -3.5f, -96, 18, "z", 1.1f);
            L.Grinder(3.5f, -3.5f, -96, 18, "z", 1.1f);
            L.Box(-4, -1, -100, -1, 0, -97, "metal");
            L.Box(1, -1, -95, 4, 0, -92, "metal");
            L.Door("dB_in", -3, 0, -70.8f, 3, 6, -70.2f,  open: true );
            L.Door("dB_out", -3, 0, -120.8f, 3, 6, -120.2f,  open: false );
            // yüksek yollar
            L.Box(-22, 0, -115, -17, 5, -76, "stone");
            L.Box(17, 0, -115, 22, 5, -76, "stone");
            L.Box(-17.4f, 5, -115, -17, 6, -82, "metal");
            L.Box(17, 5, -115, 17.4f, 6, -82, "metal");
            L.StairsZ(-22, -17, -71.5f, -76, 0, 5, 8, "metal");
            L.StairsZ(17, 22, -71.5f, -76, 0, 5, 8, "metal");
            foreach (var _q3 in AA(A(-13, -80), A(13, -80), A(-13, -113), A(13, -113))) { var x = _q3[0]; var z = _q3[1]; L.Pillar(x, z, 16, 1, "stone"); }
            foreach (var _q4 in AA(A(-12, -90, 4), A(12, -100, 5), A(0, -80, 3), A(0, -112, 4))) { var x = _q4[0]; var z = _q4[1]; var n = _q4[2]; L.MeatHook(x, 15.4f, z, n); }
            L.Box(-22, 15.4f, -90.4f, 22, 16, -89.6f, "metal",  solid: false );
            L.Box(-22, 15.4f, -100.4f, 22, 16, -99.6f, "metal",  solid: false );
            L.Box(-22, 15.4f, -80.4f, 22, 16, -79.6f, "metal",  solid: false );
            L.Box(-22, 15.4f, -112.4f, 22, 16, -111.6f, "metal",  solid: false );
            L.Brazier(-20, 5, -112);
            L.Brazier(20, 5, -80);
            L.Brazier(-20, 0, -118);
            L.Brazier(20, 0, -118);
            L.Skulls(-18, 0, -74, 6);
            L.Skulls(19, 5, -100, 4);

            L.Arena(
                id: "a2", name: "KIYMA ÇUKURU",
                trigger: A(-22, 0, -76, 22, 6, -72),
                locks: A("dB_in"), exits: A("dB_out"),
                waves: AA(
                    A(E("schism", A(-12, 0, -110)), E("schism", A(12, 0, -110)), E("filth", A(-15, 0, -90)), E("filth", A(15, 0, -90)), E("filth", A(-15, 0, -116)), E("filth", A(15, 0, -116))),
                    A(E("stray", A(-19.5f, 5, -100)), E("stray", A(19.5f, 5, -100)), E("stray", A(-19.5f, 5, -86)), E("stray", A(19.5f, 5, -86)), E("filth", A(0, 0, -112)), E("filth", A(-12, 0, -82)), E("filth", A(12, 0, -82)), E("filth", A(0, 0, -116))),
                    A(E("schism", A(-14, 0, -100)), E("schism", A(14, 0, -100)), E("stray", A(-19.5f, 5, -110)), E("stray", A(19.5f, 5, -110)), E("filth", A(-10, 0, -116)), E("filth", A(10, 0, -116)), E("filth", A(-15, 0, -84)), E("filth", A(15, 0, -84)), E("filth", A(0, 0, -116)), E("filth", A(-4, 0, -112)))
                ),
                onStart: (g) => g.hud.Hint("Yüksek yollardaki Stray'lere dikkat. Çukurun üstündeki platformlar kısa yol!", 8),
                onClear: (g) => g.Schedule(1.5f, () => g.hud.Hint("Kuzey kapısı açıldı — çıkış deliğine atla!", 7))
            );

            // ===== Çıkış odası (x -6..6, z -134..-121) =====
            L.Room(-6, -134, 6, -121,  h: 10, mat: "meat", floor: null, skip: A("s") );
            L.FloorWithHoles(-7, -135, 7, -121, AA(A(-3, -130, 3, -124)));
            L.ExitHatch("hatch", -3, -130, 3, -124);
            L.Trigger(A(-6, 0, -123, 6, 5, -121), () => L.doors["hatch"].Open());
            L.Brazier(-4.5f, 0, -132.5f);
            L.Brazier(4.5f, 0, -132.5f);
            L.Sigil(0, 0, -127, 8);

            L.Spires(AA(A(-60, 0, 60, 6), A(60, -30, 70, 7), A(-70, -80, 80, 8), A(70, -110, 55, 6), A(-50, -150, 65, 7), A(40, -170, 75, 8), A(0, 60, 60, 6)));
            L.FinishBuild();
        }

        // 0-3 "ÇİFTE BELA": tozlu harabeler. Açık avluda ilk Malicious Face, lav nehri geçişi,
        // yanık tapınak (iki Malicious Face), son dükkân ve iki Swordsmachine ile boss dövüşü.

        public static void L03(UKLevel L)
        {
            L.Theme_(
                fog: 0x3a1a08, fogNear: 34, fogFar: 170,
                skyTop: A(0.08f, 0.02f, 0.0f), skyHor: A(0.48f, 0.2f, 0.06f), skyCloud: A(0.36f, 0.15f, 0.04f), skyGlow: A(0.62f, 0.26f, 0.05f),
                hemiSky: 0xffc088, hemiGround: 0x4a2410, hemi: 1.9f, ambient: 0x6a4028, sun: 0xffb070
            );
            L.SetSpawn( pos: A(0, 30, 14), yaw: 0, checkpoint: A(0, 0, 14) );
            L.MenuCam( target: A(0, 3, -24), radius: 16, height: 7 );
            L.AddDecor("maliciousface", 0, 8, -30, 0);
            L.AddDecor("filth", -8, 0, -12, 0.4f);
            L.AddDecor("schism", 4, 2, -22, -0.2f);
            L.AddDecor("stray", -14, 0, -36, 0.8f);

            // ===== Giriş avlusu (x -10..10, z 0..20) =====
            L.Room(-10, 0, 10, 20,  h: 8, mat: "ruin", floor: null, skip: A("n") );
            L.Box(-11, -2, 0, 11, 0, 21, "tiles");
            L.Shop(8.4f, 0, 8, -Mathf.PI / 2);
            foreach (var _q1 in AA(A(-7, 16, 5), A(-7, 4, 3.5f), A(3, 17, 6))) { var x = _q1[0]; var z = _q1[1]; var h = _q1[2]; L.Pillar(x, z, h, 0.7f, "ruin"); }
            L.Brazier(-7.5f, 0, 10);
            L.Brazier(7.5f, 0, 16);
            L.Skulls(-3, 0, 18, 5);
            L.Hint(A(-9, 0, 1, 9, 3, 19), "0-3: ÇİFTE BELA. Dükkân burada. İleride yeni bir düşman seni bekliyor.", 7);

            // ===== ARENA A: Avlu (x -24..24, z -44..-1), üstü açık =====
            L.Room(-24, -44, 24, -1,  h: 10, mat: "ruin", floor: "tiles", gaps: UKLevel.MakeGaps(s: A(-4, 4, 8), n: A(-4, 4, 8)) );
            L.Door("dA_in", -4, 0, -0.8f, 4, 8, -0.2f,  open: true );
            L.Door("dA_out", -4, 0, -44.8f, 4, 8, -44.2f,  open: false );
            L.Box(-6, 0, -28, 6, 2, -16, "ruin");
            L.StairsZ(-2, 2, -12, -16, 0, 2, 4, "ruin");
            L.StairsZ(-2, 2, -32, -28, 0, 2, 4, "ruin");
            L.Sigil(0, 2, -22, 8);
            foreach (var _q2 in AA(A(-16, -8, 7), A(16, -8, 9), A(-16, -22, 5), A(16, -22, 10), A(-16, -36, 8), A(16, -36, 6))) { var x = _q2[0]; var z = _q2[1]; var h = _q2[2]; L.Pillar(x, z, h, 1, "ruin"); }
            L.Box(-10, 0, -39, -2, 1.5f, -37.5f, "ruin"); // devrilmiş sütun
            // gizli 1: doğu duvarına yaslı sütunun tepesi (köşede duvar sıçraması)
            L.Pillar(23, -12, 7, 1, "ruin");
            L.Secret(23, 8.4f, -12);
            L.Brazier(-22, 0, -42);
            L.Brazier(22, 0, -42);
            L.Brazier(-22, 0, -3);
            L.Brazier(22, 0, -3);
            L.Skulls(-20, 0, -26, 5);
            L.Skulls(19, 0, -18, 4);

            L.Arena(
                id: "a1", name: "AVLU",
                trigger: A(-24, 0, -8, 24, 6, -2),
                locks: A("dA_in"), exits: A("dA_out"),
                waves: AA(
                    A(E("maliciousface", A(0, 8, -34)), E("filth", A(-14, 0, -30)), E("filth", A(14, 0, -30)), E("filth", A(-10, 0, -42)), E("filth", A(10, 0, -42))),
                    A(E("stray", A(-18, 0, -40)), E("stray", A(18, 0, -40)), E("schism", A(0, 2, -22)), E("filth", A(-20, 0, -12)), E("filth", A(20, 0, -12)), E("filth", A(-6, 0, -42)), E("filth", A(6, 0, -42)))
                ),
                onWave: (g, w, a) => {
                    if (w == 0) g.hud.Title("YENİ DÜŞMAN", "MALICIOUS FACE", 2.6f);
                },
                onStart: (g) => g.hud.Hint("MALICIOUS FACE: gözlerine nişan al (zayıf nokta). Kırmızı ışın kilitlenince beyazlar — o an [SHIFT] ile ATIL! Turuncu küreleri PARRY yap.", 11)
            );

            // ===== Koridor 1: lav nehri (x -4..4, z -64..-45) =====
            L.Box(-5, -3, -64, -4, 8, -45, "ruin");
            L.Box(4, -3, -64, 5, 8, -45, "ruin");
            L.Box(-4, -2, -49, 4, 0, -45, "tiles");
            L.Box(-4, -2, -64, 4, 0, -60, "tiles");
            L.Box(-4, -3, -60, 4, -1.5f, -49, "rock");
            L.LavaPlane(-4, -60, 4, -49, -1.0f);
            L.HurtZone(A(-4, -1.6f, -60, 4, -0.8f, -49), 22, "lava");
            L.Box(-2, -1.5f, -52.5f, 0.5f, 0.5f, -50.5f, "rock");
            L.Box(0, -1.5f, -56, 2.5f, 0.8f, -54, "rock");
            L.Box(-2.5f, -1.5f, -59.5f, 0, 0.5f, -57.5f, "rock");
            L.Torch(-3.75f, 5, -47);
            L.Torch(3.75f, 5, -62);
            L.Hint(A(-4, 0, -49, 4, 4, -45.5f), "Lav nehri — taşlardan atla.", 5);
            L.Checkpoint(A(-4, 0, -64, 4, 4, -61), A(0, 0, -62.5f), 0);

            // ===== ARENA B: Yanık tapınak (x -20..20, z -104..-65) =====
            L.Room(-20, -104, 20, -65,  h: 18, mat: "ruin", ceil: "rock", gaps: UKLevel.MakeGaps(s: A(-4, 4, 8), n: A(-4, 4, 8)) );
            L.Door("dB_in", -4, 0, -64.8f, 4, 8, -64.2f,  open: true );
            L.Door("dB_out", -4, 0, -104.8f, 4, 8, -104.2f,  open: false );
            L.Box(-20, 0, -100, -14, 6, -70, "ruin");
            L.Box(14, 0, -100, 20, 6, -70, "ruin");
            L.StairsX(-74, -70, -10, -14, 0, 6, 10, "metal");
            L.StairsX(-100, -96, 10, 14, 0, 6, 10, "metal");
            L.Box(-14.4f, 6, -100, -14, 7, -76, "metal");
            L.Box(14, 6, -94, 14.4f, 7, -70, "metal");
            foreach (var _q3 in AA(A(-8, -75), A(8, -75), A(-8, -95), A(8, -95))) { var x = _q3[0]; var z = _q3[1]; L.Pillar(x, z, 18, 1, "ruin"); }
            L.Statue(-12, 0, -101.5f, 1.4f);
            L.Statue(12, 0, -101.5f, 1.4f);
            L.Sigil(0, 0, -86, 10);
            L.Brazier(-18, 6, -72);
            L.Brazier(18, 6, -98);
            L.Brazier(-18, 0, -103);
            L.Brazier(18, 0, -103);
            L.Chain(-19.8f, 17, -85, 9);
            L.Chain(19.8f, 17, -80, 8);

            L.Arena(
                id: "a2", name: "YANIK TAPINAK",
                trigger: A(-20, 0, -70, 20, 6, -66),
                locks: A("dB_in"), exits: A("dB_out"),
                waves: AA(
                    A(E("schism", A(-10, 0, -98)), E("schism", A(10, 0, -98)), E("stray", A(-17, 6, -85)), E("stray", A(17, 6, -85)), E("stray", A(0, 0, -100))),
                    A(E("maliciousface", A(-8, 9, -88)), E("maliciousface", A(8, 9, -88)), E("filth", A(-16, 0, -102)), E("filth", A(16, 0, -102)), E("filth", A(-4, 0, -102)), E("filth", A(4, 0, -102)))
                ),
                onStart: (g) => g.hud.Hint("Sütunları siper al. Galerilerden ateş eden Stray'leri önce indir.", 7)
            );

            // ===== Koridor 2 + dükkân nişi (x -4..4, z -118..-105) =====
            L.Box(-4, -2, -118, 4, 0, -105, "tiles");
            L.Box(-5, 0, -118, -4, 8, -114, "ruin");
            L.Box(-5, 0, -108, -4, 8, -105, "ruin");
            L.Box(-5, 6, -114, -4, 8, -108, "ruin");
            L.Box(4, 0, -118, 5, 8, -105, "ruin");
            L.Box(-5, 8, -118, 5, 9, -105, "rock");
            L.Box(-10, -2, -114, -4, 0, -108, "tiles");
            L.Box(-11, 0, -114, -10, 6, -108, "ruin");
            L.Box(-11, 0, -115, -5, 6, -114, "ruin");
            L.Box(-11, 0, -108, -5, 6, -107, "ruin");
            L.Box(-11, 6, -115, -5, 7, -107, "rock");
            L.Shop(-8.8f, 0, -111, Mathf.PI / 2);
            L.Torch(3.75f, 5, -111);
            L.Checkpoint(A(-4, 0, -117, 4, 4, -113), A(0, 0, -115), 0);
            L.Hint(A(-4, 0, -110, 4, 4, -106), "Son dükkân. İleride İKİ Swordsmachine var — donan!", 7);

            // ===== BOSS: Çifte bela (x -22..22, z -164..-119) =====
            L.Room(-22, -164, 22, -119,  h: 16, mat: "ruin", floor: null, gaps: UKLevel.MakeGaps(s: A(-4, 4, 8)) );
            L.FloorWithHoles(-23, -165, 23, -118, AA(A(-3, -144, 3, -138)));
            L.ExitHatch("hatch", -3, -144, 3, -138);
            L.Door("dC_in", -4, 0, -118.8f, 4, 8, -118.2f,  open: true );
            foreach (var _q4 in AA(A(-12, -128), A(12, -128), A(-12, -156), A(12, -156))) { var x = _q4[0]; var z = _q4[1]; L.Pillar(x, z, 16, 1.2f, "ruin"); }
            L.Box(-9, 0, -136, -6, 1.5f, -133, "metal");
            L.Box(6, 0, -149, 9, 1.5f, -146, "metal");
            L.Sigil(0, 0, -150, 12);
            L.Brazier(-20, 0, -162);
            L.Brazier(20, 0, -162);
            L.Brazier(-20, 0, -121);
            L.Brazier(20, 0, -121);
            L.Skulls(-18, 0, -140, 6);
            L.Skulls(18, 0, -132, 6);

            L.Arena(
                id: "boss", name: "SWORDSMACHINE ×2",
                bossSub: "ÇİFTE BELA",
                trigger: A(-22, 0, -126, 22, 8, -121),
                locks: A("dC_in"), exits: null,
                boss: true,
                waves: AA(A(E("swordsmachine", A(-8, 0, -156)), E("swordsmachine", A(8, 0, -156)))),
                onClear: (g) => g.OnBossDefeated("İKİ MAKİNE DE HURDA", () => {
                    L.doors["hatch"].Open();
                    g.hud.Hint("Çıkış açıldı — ortadaki DELİĞE atla!", 8);
                })
            );

            L.Spires(AA(A(-70, 10, 70, 7), A(70, -20, 60, 6), A(-80, -80, 90, 8), A(75, -110, 70, 7), A(-60, -170, 80, 8), A(50, -200, 65, 6), A(0, 70, 60, 7)));
            L.FinishBuild();
        }

        // 0-4 "TEK MAKİNELİK ORDU": kül rengi bir kolezyum. Sığınakta dükkân, ardından altı dalgalı tek
        // bir büyük meydan savaşı (Malicious Face'ler ve bir Swordsmachine dahil), sonra çıkış deliği.

        public static void L04(UKLevel L)
        {
            L.Theme_(
                fog: 0x241c1c, fogNear: 30, fogFar: 150,
                skyTop: A(0.02f, 0.02f, 0.03f), skyHor: A(0.24f, 0.11f, 0.08f), skyCloud: A(0.2f, 0.11f, 0.08f), skyGlow: A(0.38f, 0.13f, 0.06f),
                hemiSky: 0xffb098, hemiGround: 0x302020, hemi: 1.8f, ambient: 0x504040, sun: 0xffa080
            );
            L.SetSpawn( pos: A(0, 30, 7), yaw: 0, checkpoint: A(0, 0, 7) );
            L.MenuCam( target: A(0, 3, -42), radius: 18, height: 8 );
            L.AddDecor("swordsmachine", 0, 3, -42, 0);
            L.AddDecor("filth", -8, 0, -30, 0.5f);
            L.AddDecor("filth", 9, 0, -52, -0.6f);
            L.AddDecor("maliciousface", -12, 9, -56, 0.4f);
            L.AddDecor("schism", 12, 0, -32, -0.8f);

            // ===== Sığınak (x -6..6, z 0..14) — güney duvarında kayarak girilen gizli oda =====
            L.Room(-6, 0, 6, 14,  h: 14, mat: "ash", gaps: UKLevel.MakeGaps(n: A(-3, 3, 6), s: A(-1, 1, 1.1f)) );
            L.Shop(-4.9f, 0, 5, Mathf.PI / 2);
            L.Brazier(4.5f, 0, 12.5f);
            L.Brazier(-4.5f, 0, 12.5f);
            L.Sigil(0, 0, 7, 6);
            L.Box(-2, -2, 15, 2, 0, 19, "tiles");
            L.Box(-3, 0, 15, -2, 3, 20, "ash");
            L.Box(2, 0, 15, 3, 3, 20, "ash");
            L.Box(-3, 0, 19, 3, 3, 20, "ash");
            L.Box(-3, 3, 15, 3, 4, 20, "ash");
            L.Secret(0, 1, 17.5f);
            L.Hint(A(-5, 0, 1, 5, 3, 13), "0-4: TEK MAKİNELİK ORDU. İleride altı dalgalı tek bir meydan savaşı var. Dükkândan donan, sonra kuzeye.", 8);

            // ===== Geçit (x -3..3, z -13..-1) =====
            L.Box(-4, -2, -13, 4, 0, -1, "tiles");
            L.Box(-4, 0, -13, -3, 7, -1, "ash");
            L.Box(3, 0, -13, 4, 7, -1, "ash");
            L.Box(-4, 7, -13, 4, 8, -1, "rock");
            L.Torch(-2.75f, 4.5f, -7);
            L.Torch(2.75f, 4.5f, -7);
            L.Checkpoint(A(-3, 0, -10, 3, 4, -4), A(0, 0, -7), 0);

            // ===== KOLEZYUM (x -28..28, z -72..-14) =====
            L.Room(-28, -72, 28, -14,  h: 16, mat: "ash", gaps: UKLevel.MakeGaps(s: A(-3, 3, 6), n: A(-3, 3, 6)) );
            L.Door("dA_in", -3, 0, -13.8f, 3, 6, -13.2f,  open: true );
            L.Door("dA_out", -3, 0, -72.8f, 3, 6, -72.2f,  open: false );
            // dört köşede lav havuzu (zemin üstünde sığ lav: bas, zıpla)
            foreach (var _q1 in AA(A(-24, -68), A(16, -68), A(-24, -25), A(16, -25))) { var x0 = _q1[0]; var z0 = _q1[1];
                L.LavaPlane(x0, z0, x0 + 8, z0 + 8, 0.06f);
                L.HurtZone(A(x0, -0.5f, z0, x0 + 8, 0.6f, z0 + 8), 20, "lava");
            }
            // orta platform + merdivenler
            L.Box(-5, 0, -47, 5, 3, -37, "metal");
            L.StairsZ(-2, 2, -33, -37, 0, 3, 6, "metal");
            L.StairsZ(-2, 2, -51, -47, 0, 3, 6, "metal");
            L.Sigil(0, 3, -42, 8);
            // yan yürüyüş yolları
            L.Box(-28, 0, -60, -22, 5, -30, "ash");
            L.Box(22, 0, -60, 28, 5, -30, "ash");
            L.StairsX(-34, -30, -18, -22, 0, 5, 8, "metal");
            L.StairsX(-32, -28, 18, 22, 0, 5, 8, "metal");
            L.Box(-22.4f, 5, -60, -22, 6, -36, "metal");
            L.Box(22, 5, -60, 22.4f, 6, -34, "metal");
            foreach (var _q2 in AA(A(-14, -21), A(14, -21), A(-14, -63), A(14, -63), A(-18, -42), A(18, -42))) { var x = _q2[0]; var z = _q2[1]; L.Pillar(x, z, 16, 1, "ash"); }
            // gizli 2: yürüyüş yolunun ucundaki yüksek sütun (çakış sıçrayışıyla)
            L.Box(-28, 0, -68, -22, 5, -60, "ash");
            L.Pillar(-24.5f, -64, 9, 1, "ash");
            L.Secret(-24.5f, 10.4f, -64);
            L.Brazier(-26, 5, -32);
            L.Brazier(26, 5, -58);
            L.Brazier(-8, 0, -70);
            L.Brazier(8, 0, -70);
            L.Chain(-27.8f, 15, -45, 9);
            L.Chain(27.8f, 15, -40, 8);
            L.Skulls(-6, 0, -16, 6);
            L.Skulls(6, 3, -44, 3);

                L.Arena(
                id: "army", name: "KOLEZYUM",
                trigger: A(-27, 0, -20, 27, 6, -15),
                locks: A("dA_in"), exits: A("dA_out"),
                waves: AA(
                    A(E("filth", A(-10, 0, -30)), E("filth", A(10, 0, -30)), E("filth", A(-10, 0, -54)), E("filth", A(10, 0, -54)), E("filth", A(0, 3, -42)), E("filth", A(-12, 0, -66)), E("filth", A(12, 0, -66)), E("filth", A(0, 0, -66))),
                    A(E("stray", A(-25, 5, -45)), E("stray", A(25, 5, -45)), E("stray", A(-25, 5, -35)), E("stray", A(25, 5, -55)), E("schism", A(-8, 0, -64)), E("schism", A(8, 0, -64))),
                    A(E("maliciousface", A(-12, 9, -56)), E("maliciousface", A(12, 9, -56)), E("filth", A(-16, 0, -40)), E("filth", A(16, 0, -40)), E("filth", A(-6, 0, -60)), E("filth", A(6, 0, -60))),
                    A(E("schism", A(-12, 0, -50)), E("schism", A(12, 0, -50)), E("schism", A(0, 0, -64)), E("stray", A(-25, 5, -52)), E("stray", A(25, 5, -38)), E("stray", A(0, 3, -42))),
                    A(E("swordsmachine", A(0, 0, -64)), E("filth", A(-16, 0, -28)), E("filth", A(15, 0, -27)), E("filth", A(-18, 0, -56)), E("filth", A(18, 0, -56))),
                    A(E("maliciousface", A(-14, 9, -34)), E("maliciousface", A(14, 9, -50)), E("schism", A(-10, 0, -64)), E("schism", A(10, 0, -64)), E("stray", A(-25, 5, -40)), E("stray", A(25, 5, -48)), E("stray", A(-8, 0, -30)), E("stray", A(8, 0, -30)), E("filth", A(-4, 3, -42)), E("filth", A(4, 3, -42)), E("filth", A(-20, 0, -46)), E("filth", A(20, 0, -46)))
                ),
                onStart: (g) => g.hud.Hint("MEYDAN SAVAŞI: 6 dalga, arada nefes yok. Hareket etmeyi bırakma, köşelerdeki lava dikkat!", 8),
                onWave: (g, w, a) => g.hud.Message($"DALGA {w + 1} / 6", 1.4f, w == 5 ? "big" : ""),
                onClear: (g) => { g.hud.Message("ORDU DAĞITILDI", 2.2f, "big"); g.Schedule(1.5f, () => g.hud.Hint("Kuzey kapısı açıldı — çıkış deliğine atla!", 7)); }
            );

            // ===== Çıkış odası (x -6..6, z -86..-73) =====
            L.Room(-6, -86, 6, -73,  h: 10, mat: "ash", floor: null, skip: A("s") );
            L.FloorWithHoles(-7, -87, 7, -73, AA(A(-3, -82, 3, -76)));
            L.ExitHatch("hatch", -3, -82, 3, -76);
            L.Trigger(A(-6, 0, -75, 6, 5, -73), () => L.doors["hatch"].Open());
            L.Brazier(-4.5f, 0, -84.5f);
            L.Brazier(4.5f, 0, -84.5f);

            L.Spires(AA(A(-70, 0, 75, 7), A(70, -20, 65, 6), A(-80, -70, 85, 8), A(80, -80, 70, 7), A(-50, -130, 70, 7), A(40, -140, 80, 8), A(0, 60, 60, 6)));
            L.FinishBuild();
        }

        // 0-5 "CERBERUS": soğuk mermer salonlar. Heykellerle çevrili uzun koridor ve dükkân, ardından
        // kaidelerinde uyuyan iki Cerberus heykelinin beklediği kapı salonu. İkisi de ölünce Cehennemin
        // kapısı açılır: PRELUDE biter.

        public static void L05(UKLevel L)
        {
            L.Theme_(
                fog: 0x1a2030, fogNear: 26, fogFar: 135,
                skyTop: A(0.0f, 0.0f, 0.02f), skyHor: A(0.08f, 0.1f, 0.18f), skyCloud: A(0.1f, 0.12f, 0.2f), skyGlow: A(0.32f, 0.12f, 0.05f),
                hemiSky: 0xc8d4ff, hemiGround: 0x302838, hemi: 2.6f, ambient: 0x5a5a7a, sun: 0xb8c4ff
            );
            L.SetSpawn( pos: A(0, 30, -4), yaw: 0, checkpoint: A(0, 0, -4) );
            L.MenuCam( target: A(0, 3, -78), radius: 16, height: 6 );
            L.AddDecor("cerberus", -8, 0.6f, -80, 0, true);
            L.AddDecor("cerberus", 8, 0.6f, -80, 0, true);

            // ===== Heykeller koridoru (x -6..6, z -40..0) =====
            L.Room(-6, -40, 6, 0,  h: 12, mat: "marble", floor: null, gaps: UKLevel.MakeGaps(w: A(-27, -25, 1.1f)), skip: A("n") );
            L.Box(-7, -2, -40, 7, 0, 1, "tiles");
            L.Shop(-4.9f, 0, -4, Mathf.PI / 2);
            foreach (var z in A(-12, -22, -32)) {
                L.Statue(-4.4f, 0, z, 1.1f);
                L.Statue(4.4f, 0, z, 1.1f);
            }
            L.Torch(-5.75f, 6, -7);
            L.Torch(5.75f, 6, -17);
            L.Torch(-5.75f, 6, -27);
            L.Torch(5.75f, 6, -37);
            L.Sigil(0, 0, -20, 6);
            L.Hint(A(-5, 0, -9, 5, 3, -1), "0-5: CERBERUS. Heykeller kıpırdamıyor... şimdilik. Son dükkân burada.", 7);
            L.Checkpoint(A(-4, 0, -39, 4, 4, -35), A(0, 0, -37), 0);
            // gizli: batı duvarının dibinden kayarak girilen oda
            L.Box(-12, -2, -28, -7, 0, -24, "tiles");
            L.Box(-13, 0, -29, -7, 3, -28, "marble");
            L.Box(-13, 0, -24, -7, 3, -23, "marble");
            L.Box(-13, 0, -28, -12, 3, -24, "marble");
            L.Box(-13, 3, -29, -7, 4, -23, "marble");
            L.Secret(-10, 1, -26);

            // ===== KAPI SALONU (x -26..26, z -104..-41) =====
            L.Room(-26, -104, 26, -41,  h: 22, mat: "marble", gaps: UKLevel.MakeGaps(s: A(-4, 4, 8), n: A(-6, 6, 12)), skip: A("s") );
            L.Box(-27, 0, -41, -4, 22, -40, "marble");
            L.Box(4, 0, -41, 27, 22, -40, "marble");
            L.Box(-4, 8, -41, 4, 22, -40, "marble");
            L.Door("dB_in", -4, 0, -40.8f, 4, 8, -40.2f,  open: true );
            L.Door("gate", -6, 0, -104.8f, 6, 12, -104.2f,  open: false );
            foreach (var z in A(-50, -62, -74, -86, -98)) {
                L.Pillar(-18, z, 22, 1.2f, "marble");
                L.Pillar(18, z, 22, 1.2f, "marble");
            }
            // kaideler
            L.Box(-9.5f, 0, -81.5f, -6.5f, 0.6f, -78.5f, "marble");
            L.Box(6.5f, 0, -81.5f, 9.5f, 0.6f, -78.5f, "marble");
            L.Sigil(0, 0, -72, 16);
            L.Box(-10, 0, -60, -7, 1.6f, -57, "marble");
            L.Box(7, 0, -92, 10, 1.6f, -89, "marble");
            L.Brazier(-24, 0, -43);
            L.Brazier(24, 0, -43);
            L.Brazier(-24, 0, -102);
            L.Brazier(24, 0, -102);
            L.Brazier(-12, 0, -80);
            L.Brazier(12, 0, -80);
            L.Chain(-25.8f, 21, -60, 12);
            L.Chain(25.8f, 21, -85, 12);

            L.Arena(
                id: "boss", name: "CERBERUS",
                bossSub: "KAPININ BEKÇİLERİ",
                trigger: A(-26, 0, -50, 26, 8, -44),
                locks: A("dB_in"), exits: A("gate"),
                boss: true,
                prespawn: true,
                waves: AA(A(E("cerberus", A(-8, 0.6f, -80), true), E("cerberus", A(8, 0.6f, -80), true))),
                onWave: (g, w, a) =>
                {
                    var c1 = a.enemies.Count > 0 ? a.enemies[0] : null;
                    var c2 = a.enemies.Count > 1 ? a.enemies[1] : null;
                    if (c1 && c2) { c1.partner = c2; c2.partner = c1; }
                    g.Schedule(1.4f, () => { if (c1 is UKCerberus cb && !cb.dead) cb.Wake(); });
                },
                onStart: (g) => g.hud.Hint("CERBERUS: yere vurduğunda halka dalga gelir — ZIPLA! Parlayarak hücum ettiğinde PARRY yap. Büyük küreyi geri yolla. Biri yarı cana inince diğeri uyanır.", 12),
                onClear: (g) => g.OnBossDefeated("KAPININ BEKÇİLERİ DÜŞTÜ", () => {
                    g.hud.Hint("Cehennemin kapısı açıldı. İçeri gir.", 8);
                })
            );

            // ===== Cehennemin kapısı (x -8..8, z -124..-105) =====
            L.Room(-8, -124, 8, -105,  h: 14, mat: "marble", floor: null, skip: A("s") );
            L.Box(-9, -2, -125, 9, 0, -105, "tiles");
            L.Box(-5, 0, -122, -4, 10, -121, "gold");
            L.Box(4, 0, -122, 5, 10, -121, "gold");
            L.Box(-5, 10, -122, 5, 11, -121, "gold");
            L.PortalVisual(0, 5, -121.6f, 8, 10, 0xff3010, 0xff5020);
            L.Lamp_( pos: UKLevel.P(0, 5, -118), color: 0xff4010, power: 1.6f );
            L.Sigil(0, 0, -114, 10);
            L.Trigger(A(-4, 0, -122, 4, 10, -119), () => L.game.LevelComplete());

            L.Spires(AA(A(-70, 0, 70, 7), A(70, -30, 80, 8), A(-80, -90, 90, 9), A(75, -120, 70, 7), A(0, -170, 100, 10), A(0, 60, 60, 6)));
            L.FinishBuild();
        }

        // 1-1 "GÜNDOĞUMUNUN KALBİ": ARAF'ın çimenli kale bahçeleri. Kale avlusunda ilk Drone'lar,
        // hendek üstündeki dar köprü, kule salonunda karışık dalgalar ve altın çıkış kapısı.

        public static void L11(UKLevel L)
        {
            L.SetLimbo();
            L.SetSpawn( pos: A(0, 30, 16), yaw: 0, checkpoint: A(0, 0, 16) );
            L.MenuCam( target: A(0, 4, -22), radius: 18, height: 7 );
            L.AddDecor("drone", 0, 7, -24, 0);
            L.AddDecor("drone", -6, 5, -18, 0.3f);
            L.AddDecor("stray", 8, 0, -28, -0.4f);
            L.AddDecor("filth", -9, 0, -14, 0.5f);

            // ===== Giriş bahçesi (x -10..10, z 0..24) =====
            L.Room(-10, 0, 10, 24,  h: 8, mat: "castle", floor: "grass", skip: A("n") );
            L.Shop(8.4f, 0, 10, -Mathf.PI / 2);
            L.Tree(-6, 18, 5);
            L.Tree(-6, 6, 4);
            L.Tree(4, 20, 6);
            L.Statue(0, 0, 3, 1.1f, "castle");
            L.Hint(A(-9, 0, 1, 9, 3, 23), "KATMAN 1: ARAF. Güneşli bahçeler aldatmasın. Dükkân sağda.", 7);

            // ===== ARENA A: Kale avlusu (x -22..22, z -42..-1) =====
            L.Room(-22, -42, 22, -1,  h: 12, mat: "castle", floor: "grass", gaps: UKLevel.MakeGaps(s: A(-4, 4, 8), n: A(-4, 4, 8)) );
            L.Door("dA_in", -4, 0, -0.8f, 4, 8, -0.2f,  open: true );
            L.Door("dA_out", -4, 0, -42.8f, 4, 8, -42.2f,  open: false );
            // ortada çeşme
            L.Box(-4, 0, -25, 4, 1.2f, -17, "castleDark");
            L.Box(-1, 1.2f, -22, 1, 4.5f, -20, "castle");
            L.Box(-2, 4.5f, -23, 2, 5, -19, "gold");
            // yan teraslar ve merdivenler
            L.Box(-22, 0, -36, -15, 3, -8, "castle");
            L.StairsX(-14, -10, -11, -15, 0, 3, 5, "castleDark");
            L.Box(15, 0, -36, 22, 3, -8, "castle");
            L.StairsX(-36, -32, 11, 15, 0, 3, 5, "castleDark");
            foreach (var _q1 in AA(A(-20, -3), A(20, -3), A(-20, -40), A(20, -40))) { var x = _q1[0]; var z = _q1[1]; L.Pillar(x, z, 16, 1.4f, "castle"); }
            foreach (var _q2 in AA(A(-9, -32), A(9, -12))) { var x = _q2[0]; var z = _q2[1]; L.Tree(x, z, 5); }
            // gizli 1: güneydoğu kulesinin tepesi (terastan duvar sıçraması)
            L.Secret(20, 17.6f, -40);
            L.Arena(
                id: "a1", name: "KALE AVLUSU",
                trigger: A(-22, 0, -8, 22, 6, -2),
                locks: A("dA_in"), exits: A("dA_out"),
                waves: AA(
                    A(E("filth", A(-12, 0, -30)), E("filth", A(12, 0, -30)), E("filth", A(-6, 0, -38)), E("filth", A(6, 0, -38)), E("stray", A(-18, 3, -24)), E("stray", A(18, 3, -24))),
                    A(E("drone", A(-13, 7, -26)), E("drone", A(10, 6, -30)), E("drone", A(0, 8, -36)), E("filth", A(-8, 0, -12)), E("filth", A(14, 0, -14))),
                    A(E("schism", A(0, 0, -36)), E("stray", A(-18, 3, -30)), E("stray", A(18, 3, -30)), E("drone", A(-8, 7, -16)), E("drone", A(8, 7, -16)))
                ),
                onWave: (g, w, a) => {
                    if (w == 1) {
                        g.hud.Title("YENİ DÜŞMAN", "DRONE", 2.6f);
                        g.hud.Hint("DRONE: göz parlayınca iki mavi küre atar (PARRY yapılabilir). Vurulunca sana doğru DÜŞER — [F] ile yumrukla geri yolla!", 10);
                    }
                }
            );

            // ===== Hendek köprüsü (x -6..6, z -66..-43) =====
            L.Box(-7, 0, -66, -6, 8, -43, "castle");
            L.Box(6, 0, -66, 7, 8, -43, "castle");
            L.Box(-6, -2, -47, 6, 0, -43, "castleDark");
            L.Box(-6, -2, -66, 6, 0, -61, "castleDark");
            L.Pit(-6, -61, 6, -47,  depth: 12, mat: "castle", bottom: "grass" );
            L.Box(-1.5f, -1, -55, 1.5f, 0, -47, "castleDark");
            L.Box(-1.5f, -1, -61, 1.5f, 0, -57, "castleDark"); // 2 m'lik boşluk: zıpla
            L.Hint(A(-6, 0, -47, 6, 4, -43), "Köprü kırık — zıpla ya da atıl.", 5);
            L.Checkpoint(A(-6, 0, -66, 6, 4, -62), A(0, 0, -64), 0);

            // ===== ARENA B: Kule salonu (x -18..18, z -104..-67) =====
            L.Room(-18, -104, 18, -67,  h: 18, mat: "castle", floor: "tiles", gaps: UKLevel.MakeGaps(s: A(-4, 4, 8), n: A(-4, 4, 8), w: A(-84, -80, 9, 6)) );
            L.Door("dB_in", -4, 0, -66.8f, 4, 8, -66.2f,  open: true );
            L.Door("dB_out", -4, 0, -104.8f, 4, 8, -104.2f,  open: false );
            // balkonlar
            L.Box(-18, 5, -100, -12, 6, -72, "castleDark");
            L.Box(12, 5, -100, 18, 6, -72, "castleDark");
            L.StairsX(-76, -72, -8, -12, 0, 5, 8, "castle");
            L.StairsX(-100, -96, 8, 12, 0, 5, 8, "castle");
            foreach (var _q3 in AA(A(-6, -78), A(6, -78), A(-6, -94), A(6, -94))) { var x = _q3[0]; var z = _q3[1]; L.Pillar(x, z, 18, 1, "castle"); }
            L.Box(-3, 0, -88, 3, 1, -84, "gold");
            L.Chain(-17.8f, 17, -86, 8);
            L.Chain(17.8f, 17, -80, 8);
            // gizli 2: batı balkonunun duvarındaki niş
            L.Box(-23, 5, -85, -19, 6, -79, "castleDark");
            L.Box(-24, 5, -85, -23, 10, -79, "castle");
            L.Box(-23, 9, -85, -19, 10, -79, "castle");
            L.Box(-23, 6, -85, -19, 9, -84, "castle");
            L.Box(-23, 6, -80, -19, 9, -79, "castle");
            L.Secret(-20.2f, 6.4f, -82);
            L.Arena(
                id: "a2", name: "KULE SALONU",
                trigger: A(-18, 0, -73, 18, 6, -68),
                locks: A("dB_in"), exits: A("dB_out"),
                waves: AA(
                    A(E("drone", A(-8, 8, -92)), E("drone", A(8, 8, -92)), E("drone", A(0, 10, -98)), E("drone", A(0, 8, -80)), E("stray", A(-15, 6, -90)), E("stray", A(15, 6, -90))),
                    A(E("schism", A(-10, 0, -100)), E("schism", A(10, 0, -90)), E("filth", A(-4, 0, -100)), E("filth", A(4, 0, -100)), E("filth", A(-14, 0, -86)), E("filth", A(14, 0, -86))),
                    A(E("maliciousface", A(0, 10, -94)), E("drone", A(-10, 9, -84)), E("drone", A(10, 9, -84)), E("stray", A(-15, 6, -76)), E("stray", A(15, 6, -76)))
                ),
                onStart: (g) => g.hud.Hint("Balkonlardaki Stray'leri ve havadaki Drone'ları önce indir.", 7)
            );

            // ===== Çıkış: altın kapı (x -6..6, z -122..-105) =====
            L.Room(-6, -122, 6, -105,  h: 12, mat: "castle", floor: "grass", skip: A("s") );
            L.Box(-4.5f, 0, -120.5f, -3.5f, 10, -119.5f, "gold");
            L.Box(3.5f, 0, -120.5f, 4.5f, 10, -119.5f, "gold");
            L.Box(-4.5f, 10, -120.5f, 4.5f, 11, -119.5f, "gold");
            L.Portal(0, -120,  color: 0xffe0a0, glowColor: 0xffd070, w: 7, h: 10 );

            L.Spires(AA(A(-70, 10, 60, 7), A(70, -30, 70, 8), A(-80, -90, 80, 8), A(75, -120, 60, 7), A(0, -180, 90, 9), A(0, 70, 50, 6)));
            L.FinishBuild();
        }

        // 1-2 "YANAN DÜNYA": yanmakta olan ARAF köyü. Köy meydanında ilk Streetcleaner'lar, yıkık
        // sokakta tuzaklı geçiş, yanık kilisede Swordsmachine eşliğinde son saldırı.

        public static void L12(UKLevel L)
        {
            L.SetLimbo();
            L.Theme_(
                fog: 0x9a8a80, fogNear: 30, fogFar: 170,
                skyTop: A(0.22f, 0.26f, 0.4f), skyHor: A(0.78f, 0.55f, 0.38f), skyCloud: A(0.35f, 0.3f, 0.3f), skyGlow: A(1.0f, 0.45f, 0.15f),
                hemiSky: 0xffe8d8, hemiGround: 0x5a4a38, hemi: 2.1f, ambient: 0x7a6a60, sun: 0xffd0a0
            );
            L.SetSpawn( pos: A(0, 30, 22), yaw: 0, checkpoint: A(0, 0, 22) );
            L.MenuCam( target: A(0, 3, -22), radius: 17, height: 6 );
            L.AddDecor("streetcleaner", -4, 0, -20, 0.3f);
            L.AddDecor("streetcleaner", 5, 0, -24, -0.3f);
            L.AddDecor("drone", 0, 7, -30, 0);

            // ===== Köy yolu (x -8..8, z 0..32) =====
            L.Room(-8, 0, 8, 32,  h: 7, mat: "castleDark", floor: "grass", skip: A("n") );
            L.Shop(-6.4f, 0, 20, Mathf.PI / 2);
            L.Tree(5, 26, 4);
            L.Tree(5, 8, 5);
            L.Fire(-5, 0, 6, 1.6f);
            L.Hint(A(-7, 0, 1, 7, 3, 31), "1-2: YANAN DÜNYA. Köy yanıyor. Alev taşıyanlara yaklaşma.", 7);

            // ===== ARENA A: Köy meydanı (x -26..26, z -48..-1), üstü açık =====
            L.Room(-26, -48, 26, -1,  h: 9, mat: "castleDark", floor: "grass", gaps: UKLevel.MakeGaps(s: A(-4, 4, 7), n: A(-4, 4, 7)) );
            L.Door("dA_in", -4, 0, -0.8f, 4, 7, -0.2f,  open: true );
            L.Door("dA_out", -4, 0, -48.8f, 4, 7, -48.2f,  open: false );
            L.House(-22, -14, -14, -6,  door: "e", burning: true );
            L.House(14, -16, 22, -8,  door: "w", burning: true );
            L.House(-22, -40, -14, -30,  door: "e", h: 6, burning: true );
            L.House(14, -42, 22, -32,  door: "w" );
            // kuyu ve devrik araba
            L.Box(-2, 0, -26, 2, 1.2f, -22, "castle");
            L.Box(6, 0, -30, 10, 1.4f, -28, "ruin");
            L.Box(-10, 0, -20, -7, 1.6f, -16, "ruin");
            L.Tree(0, -40, 6);
            L.Fire(8, 1.4f, -29, 1.4f);
            L.Brazier(-24, 0, -3);
            L.Brazier(24, 0, -3);
            // gizli 1: yanmayan evin çatısı (arabanın üstünden zıpla + duvar sıçraması)
            L.Secret(18, 6.6f, -37);
            L.Arena(
                id: "a1", name: "KÖY MEYDANI",
                trigger: A(-26, 0, -8, 26, 6, -2),
                locks: A("dA_in"), exits: A("dA_out"),
                waves: AA(
                    A(E("filth", A(-10, 0, -36)), E("filth", A(10, 0, -36)), E("filth", A(-4, 0, -44)), E("filth", A(4, 0, -44)), E("drone", A(0, 7, -34))),
                    A(E("streetcleaner", A(-8, 0, -44)), E("streetcleaner", A(8, 0, -44)), E("stray", A(-18, 0, -24)), E("stray", A(18, 0, -24))),
                    A(E("streetcleaner", A(-18, 0, -44)), E("streetcleaner", A(18, 0, -26)), E("drone", A(-10, 7, -30)), E("drone", A(10, 7, -30)), E("schism", A(0, 0, -44)))
                ),
                onWave: (g, w, a) => {
                    if (w == 1) {
                        g.hud.Title("YENİ DÜŞMAN", "STREETCLEANER", 2.6f);
                        g.hud.Hint("STREETCLEANER: yakından alev püskürtür, nişan alınca yana kaçar. SIRTINDAKİ TANKA vur — patlar! Uzak dur, atılarak kaç.", 11);
                    }
                }
            );

            // ===== Yıkık sokak (x -5..5, z -80..-49): yanan kirişler =====
            L.Box(-6, 0, -80, -5, 9, -49, "castleDark");
            L.Box(5, 0, -80, 6, 9, -78, "castleDark");
            L.Box(5, 0, -72, 6, 9, -49, "castleDark");
            L.Box(5, 6, -78, 6, 9, -72, "castleDark");
            L.Box(-5, -2, -80, 5, 0, -49, "grass");
            L.Box(-5, 0, -58, -1, 2.4f, -57, "ruin");
            L.Box(1, 0, -64, 5, 2.4f, -63, "ruin");
            L.Box(-5, 0, -71, -0.5f, 2.4f, -70, "ruin");
            L.Fire(-3, 2.4f, -57.5f, 1.2f);
            L.Fire(3, 2.4f, -63.5f, 1.2f);
            L.Fire(-2.7f, 2.4f, -70.5f, 1.2f);
            L.HurtZone(A(-5, 0, -58, -1, 2.6f, -57), 12, "lava");
            L.HurtZone(A(1, 0, -64, 5, 2.6f, -63), 12, "lava");
            L.HurtZone(A(-5, 0, -71, -0.5f, 2.6f, -70), 12, "lava");
            L.ExtraEnemies( trigger: A(-5, 0, -60, 5, 4, -56), list: A(E("drone", A(0, 6, -74)), E("drone", A(-3, 7, -76))) );
            L.Hint(A(-5, 0, -54, 5, 4, -50), "Yanan kirişlerin üstünden atla — ateşe basma.", 5);
            L.Box(-5, 9, -80, 5, 10, -49, "ruin");
            L.Checkpoint(A(-5, 0, -80, 5, 4, -76), A(0, 0, -78), 0);
            // dükkân nişi
            L.Box(5, -2, -78, 10, 0, -72, "grass");
            L.Box(10, 0, -78, 11, 6, -72, "castleDark");
            L.Box(5, 0, -79, 11, 6, -78, "castleDark");
            L.Box(5, 0, -72, 11, 6, -71, "castleDark");
            L.Box(5, 6, -79, 11, 7, -71, "ruin");
            L.Shop(9.2f, 0, -75, -Mathf.PI / 2);

            // ===== ARENA B: Yanık kilise (x -18..18, z -122..-81) =====
            L.Room(-18, -122, 18, -81,  h: 20, mat: "castle", floor: "tiles", gaps: UKLevel.MakeGaps(s: A(-4, 4, 8), n: A(-3, 3, 7)) );
            L.Door("dB_in", -4, 0, -80.8f, 4, 8, -80.2f,  open: true );
            L.Box(-18, 0, -118, -10, 4, -110, "castleDark");
            L.Box(10, 0, -118, 18, 4, -110, "castleDark");
            L.StairsZ(-14, -10, -106, -110, 0, 4, 6, "castle");
            L.StairsZ(10, 14, -106, -110, 0, 4, 6, "castle");
            foreach (var z in A(-90, -100)) { L.Pillar(-9, z, 20, 1, "castle"); L.Pillar(9, z, 20, 1, "castle"); }
            // sıralar (siper)
            foreach (var z in A(-88, -94, -100)) { L.Box(-7, 0, z, -2, 1.1f, z + 1, "ruin"); L.Box(2, 0, z, 7, 1.1f, z + 1, "ruin"); }
            L.Box(-3, 0, -120, 3, 1.5f, -116, "gold"); // sunak
            L.Fire(-14, 4, -114, 2);
            L.Fire(14, 4, -114, 2);
            L.Lamp_( pos: UKLevel.P(0, 8, -110), color: 0xff8a40, power: 1.4f );
            // çıkış: sunağın arkasındaki kapı
            L.Door("dB_out", -3, 0, -122.8f, 3, 7, -122.2f,  open: false );
            L.Arena(
                id: "a2", name: "YANIK KİLİSE",
                trigger: A(-18, 0, -87, 18, 6, -82),
                locks: A("dB_in"), exits: A("dB_out"),
                waves: AA(
                    A(E("streetcleaner", A(-14, 4, -114)), E("streetcleaner", A(14, 4, -114)), E("drone", A(0, 10, -110)), E("drone", A(-8, 9, -104)), E("drone", A(8, 9, -104))),
                    A(E("swordsmachine", A(0, 0, -114)), E("streetcleaner", A(-12, 0, -96)), E("streetcleaner", A(12, 0, -96)))
                ),
                onWave: (g, w, a) => { if (w == 1) g.hud.Message("SWORDSMACHINE GERİ DÖNDÜ", 2, "big"); },
                onStart: (g) => g.hud.Hint("Sıraları siper al. Streetcleaner tanklarına vur.", 7)
            );

            // ===== Çıkış (x -5..5, z -140..-123) =====
            L.Room(-5, -140, 5, -123,  h: 10, mat: "castle", floor: "grass", skip: A("s") );
            L.Portal(0, -138,  color: 0xffc080, glowColor: 0xffa050, w: 7, h: 9 );

            L.Spires(AA(A(-70, 10, 60, 7), A(70, -30, 70, 8), A(-80, -100, 80, 8), A(75, -130, 60, 7), A(0, -200, 90, 9)));
            L.FinishBuild();
        }

        // 1-3 "KUTSAL KALINTILAR SALONU": altın süslü beyaz mermer salonlar. Heykeller galerisinde
        // karışık dalgalar, ardından kalıntı salonunda mini boss HIDEOUS MASS. Çıkış: yerdeki kapak.

        public static void L13(UKLevel L)
        {
            L.SetLimbo();
            L.Theme_(
                fog: 0xc8c0b0, fogNear: 34, fogFar: 160,
                hemiSky: 0xfff4e0, hemiGround: 0x6a6048, hemi: 2.2f, ambient: 0x8a8070
            );
            L.SetSpawn( pos: A(0, 24, 14), yaw: 0, checkpoint: A(0, 0, 14) );
            L.MenuCam( target: A(0, 3, -94), radius: 17, height: 6 );
            L.AddDecor("hideousmass", 0, 0, -96, 0);

            // ===== Giriş revakı (x -8..8, z 0..22) =====
            L.Room(-8, 0, 8, 22,  h: 10, mat: "marble", floor: "tiles", skip: A("n") );
            L.Shop(6.4f, 0, 12, -Mathf.PI / 2);
            foreach (var z in A(4, 18)) { L.Statue(-6, 0, z, 1, "gold"); }
            L.Hint(A(-7, 0, 1, 7, 3, 21), "1-3: KUTSAL KALINTILAR SALONU. Salonların sonunda kocaman bir şey kıpırdıyor.", 7);

            // ===== ARENA A: Heykeller galerisi (x -20..20, z -46..-1) =====
            L.Room(-20, -46, 20, -1,  h: 16, mat: "marble", floor: "tiles", ceil: "castle", gaps: UKLevel.MakeGaps(s: A(-4, 4, 8), n: A(-4, 4, 8)) );
            L.Door("dA_in", -4, 0, -0.8f, 4, 8, -0.2f,  open: true );
            L.Door("dA_out", -4, 0, -46.8f, 4, 8, -46.2f,  open: false );
            foreach (var z in A(-10, -22, -34)) {
                L.Statue(-15, 0, z, 1.4f, "marble");
                L.Statue(15, 0, z, 1.4f, "marble");
                L.Pillar(-9, z - 5, 16, 1, "marble");
                L.Pillar(9, z - 5, 16, 1, "marble");
            }
            L.Box(-5, 0, -28, 5, 2, -18, "castle");
            L.StairsZ(-2, 2, -14, -18, 0, 2, 4, "gold");
            L.Box(-2, 2, -24, 2, 2.4f, -22, "gold");
            L.Chain(0, 15.9f, -12, 7);
            L.Chain(0, 15.9f, -38, 7);
            foreach (var _q1 in AA(A(-18, -3), A(18, -3), A(-18, -44), A(18, -44))) { var x = _q1[0]; var z = _q1[1]; L.Brazier(x, 0, z); }
            // gizli 1: platformdaki altın kaidenin üstü
            L.Secret(0, 3.6f, -23);
            L.Arena(
                id: "a1", name: "HEYKELLER GALERİSİ",
                trigger: A(-20, 0, -8, 20, 6, -2),
                locks: A("dA_in"), exits: A("dA_out"),
                waves: AA(
                    A(E("stray", A(-12, 0, -40)), E("stray", A(12, 0, -40)), E("streetcleaner", A(3, 2, -26)), E("filth", A(-6, 0, -42)), E("filth", A(6, 0, -42))),
                    A(E("drone", A(-10, 9, -30)), E("drone", A(10, 9, -30)), E("drone", A(0, 11, -40)), E("schism", A(-14, 0, -42)), E("schism", A(14, 0, -42))),
                    A(E("maliciousface", A(0, 10, -36)), E("streetcleaner", A(-14, 0, -40)), E("streetcleaner", A(14, 0, -40)))
                )
            );

            // ===== Koridor: altın köprü (x -5..5, z -70..-47) =====
            L.Box(-6, 0, -70, -5, 10, -47, "marble");
            L.Box(5, 0, -70, 6, 10, -47, "marble");
            L.Box(-5, 10, -70, 5, 11, -47, "castle");
            L.FloorWithHoles(-5, -70, 5, -47, AA(A(-5, -62, 5, -55)),  mat: "tiles" );
            L.Box(-5, -12, -62, 5, -10, -55, "meat");
            L.Box(-6, -12, -62, -5, 0, -55, "marble");
            L.Box(5, -12, -62, 6, 0, -55, "marble");
            L.Box(-5, -12, -63, 5, 0, -62, "marble");
            L.Box(-5, -12, -55, 5, 0, -54, "marble");
            L.HurtZone(A(-5, -14, -62, 5, -1.5f, -55), 25, "pit");
            L.Box(-0.8f, -0.4f, -62, 0.8f, 0, -55, "gold");
            L.Hint(A(-5, 0, -52, 5, 4, -48), "Dar altın kiriş. Düşersen et yığınına...", 5);
            L.Checkpoint(A(-5, 0, -70, 5, 4, -64), A(0, 0, -67), 0);
            L.Shop(-3.4f, 0, -68, Mathf.PI / 2);

            // ===== BOSS: Kalıntı salonu (x -24..24, z -118..-71) =====
            L.Room(-24, -118, 24, -71,  h: 22, mat: "marble", floor: null, gaps: UKLevel.MakeGaps(s: A(-4, 4, 8)) );
            L.FloorWithHoles(-25, -119, 25, -70, AA(A(-3, -114, 3, -108)),  mat: "tiles" );
            L.ExitHatch("hatch", -3, -114, 3, -108);
            L.Door("dC_in", -4, 0, -70.8f, 4, 8, -70.2f,  open: true );
            foreach (var _q2 in AA(A(-16, -80), A(16, -80), A(-16, -104), A(16, -104))) { var x = _q2[0]; var z = _q2[1]; L.Pillar(x, z, 22, 1.4f, "marble"); }
            L.Box(-24, 0, -96, -20, 5, -86, "castle");
            L.Box(20, 0, -96, 24, 5, -86, "castle");
            L.Box(-10, 0, -98, -7, 2, -95, "gold");
            L.Box(7, 0, -84, 10, 2, -81, "gold");
            L.Sigil(0, 0, -94, 16);
            foreach (var _q3 in AA(A(-22, -73), A(22, -73), A(-22, -116), A(22, -116))) { var x = _q3[0]; var z = _q3[1]; L.Brazier(x, 0, z); }
            L.Lamp_( pos: UKLevel.P(0, 12, -94), color: 0xffe0b0, power: 1.2f );
            L.Secret(-22, 6.4f, -91);
            L.Arena(
                id: "boss", name: "HIDEOUS MASS",
                bossSub: "KUTSAL KALINTI",
                trigger: A(-24, 0, -78, 24, 8, -72),
                locks: A("dC_in"), exits: null,
                boss: true,
                waves: AA(A(E("hideousmass", A(0, 0, -96)), E("drone", A(-12, 8, -104)), E("drone", A(12, 8, -104)))),
                onStart: (g) => g.hud.Hint("HIDEOUS MASS: yukarı fırlattığı küreler düştüğü yerde patlar — hareket et! Zıpkını PARRY yap. Yakınsan kuyruğunu vurur: ZIPLA.", 11),
                onClear: (g) => g.OnBossDefeated("KALINTI TEMİZLENDİ", () => {
                    L.doors["hatch"].Open();
                    g.hud.Hint("Çıkış açıldı — ortadaki DELİĞE atla!", 8);
                })
            );

            L.Spires(AA(A(-70, 10, 60, 7), A(70, -30, 70, 8), A(-80, -100, 80, 8), A(75, -130, 60, 7), A(0, -190, 90, 9)));
            L.FinishBuild();
        }

        // 1-4 "AY IŞIĞI": ay ışığında sessiz bir kale bahçesi ve yuvarlak düello meydanı. Boss: V2.
        // V2 yenilince kolunu koparırsın: KNUCKLEBLASTER bedava, V2 oynanabilir karakter olur.

        public static void L14(UKLevel L)
        {
            L.SetLimbo();
            L.Theme_(
                fog: 0x141a30, fogNear: 30, fogFar: 150,
                skyTop: A(0.0f, 0.01f, 0.04f), skyHor: A(0.06f, 0.08f, 0.18f), skyCloud: A(0.12f, 0.14f, 0.22f), skyGlow: A(0.35f, 0.4f, 0.6f),
                hemiSky: 0xb8c8ff, hemiGround: 0x283048, hemi: 2.4f, ambient: 0x505a80, sun: 0xc8d4ff
            );
            L.SetSpawn( pos: A(0, 24, 16), yaw: 0, checkpoint: A(0, 0, 16) );
            L.MenuCam( target: A(0, 3, -48), radius: 16, height: 6 );
            L.AddDecor("v2", 0, 0, -50, 0);

            L.Moon(-60, 90, -160);

            // ===== Ay bahçesi (x -9..9, z 0..24) =====
            L.Room(-9, 0, 9, 24,  h: 7, mat: "castle", floor: "grass", skip: A("n") );
            L.Shop(-7.4f, 0, 12, Mathf.PI / 2);
            L.Tree(5, 20, 5);
            L.Tree(5, 5, 4);
            L.Torch(8.75f, 4, 12);
            L.Hint(A(-8, 0, 1, 8, 3, 23), "1-4: AY IŞIĞI. Ileride seni bir makine bekliyor. Senin gibi bir makine.", 8);

            // ===== Merdivenli geçit (x -4..4, z -24..-1) =====
            L.Box(-5, 0, -24, -4, 9, -1, "castle");
            L.Box(4, 0, -24, 5, 9, -1, "castle");
            L.Box(-5, -2, -1, 5, 0, 0, "grass");
            L.Box(-4, -2, -4, 4, 0, -1, "castleDark");
            L.Box(-10, 0, -1, -4, 9, 0, "castle");
            L.Box(4, 0, -1, 10, 9, 0, "castle");
            L.StairsZ(-4, 4, -4, -14, 0, 3, 8, "castleDark");
            L.Box(-4, 0, -24, 4, 3, -14, "castleDark");
            L.Torch(-3.75f, 6, -10);
            L.Torch(3.75f, 6, -20);
            L.Checkpoint(A(-4, 3, -22, 4, 7, -17), A(0, 3, -20), 0);
            L.Hint(A(-4, 3, -22, 4, 7, -17), "Son dükkân bahçedeydi. Hazırsan ilerle.", 5);

            // ===== BOSS: Düello meydanı (x -26..26, z -76..-25), üstü açık =====
            L.Room(-26, -76, 26, -25,  h: 14, mat: "castle", floor: null, gaps: UKLevel.MakeGaps(s: A(-4, 4, 10, 3), n: A(-4, 4, 10, 3)) );
            L.Box(-27, -2, -77, 27, 3, -24, "tiles");
            // köşelerde sekizgen hissi veren kütleler ve alçak siperler
            foreach (var _q1 in AA(A(-22, -29), A(22, -29), A(-22, -72), A(22, -72))) { var x = _q1[0]; var z = _q1[1]; L.Box(x - 4, 3, z - 4, x + 4, 13, z + 4, "castle"); }
            foreach (var _q2 in AA(A(-11, -40), A(11, -40), A(-11, -62), A(11, -62))) { var x = _q2[0]; var z = _q2[1]; L.Pillar(x, z, 6, 1, "castle", 3); }
            L.Box(-4, 3, -53, 4, 4.2f, -49, "castleDark");
            L.Box(-18, 3, -52, -15, 5.2f, -48, "castleDark");
            L.Box(15, 3, -52, 18, 5.2f, -48, "castleDark");
            L.Sigil(0, 3, -51, 18);
            foreach (var _q3 in AA(A(-17, -31), A(17, -31), A(-17, -70), A(17, -70))) { var x = _q3[0]; var z = _q3[1]; L.Brazier(x, 3, z); }
            L.Door("dB_in", -4, 3, -24.8f, 4, 10, -24.2f,  open: true );
            L.Door("gate", -4, 3, -76.8f, 4, 10, -76.2f,  open: false );
            L.Arena(
                id: "boss", name: "V2",
                bossSub: "SENİ İZLİYORDU",
                trigger: A(-26, 3, -32, 26, 9, -26),
                locks: A("dB_in"), exits: A("gate"),
                boss: true,
                waves: AA(A(E("v2", A(0, 3, -64)))),
                onStart: (g) => g.hud.Hint("V2: KIRMIZI ÇİZGİ = revolver nişanı; kalınlaşınca kilitlenir → ATIL. Yumruğu parlayınca PARRY yap. Uzakta kalma, yakında pompalı var.", 12),
                onClear: (g) => g.OnBossDefeated("V2 DEVRE DIŞI", () =>
                {
                    bool first = !g.progress.Has("arm.knuckle");
                    g.progress.shop.Add("arm.knuckle");
                    bool newChar = !g.progress.v2Unlocked;
                    g.progress.v2Unlocked = true;
                    g.progress.Save();
                    g.weapons.GiveArm("knuckle");
                    g.hud.Title("V2'NİN KOLUNU KOPARDIN", "KNUCKLEBLASTER", 4.5f, newChar ? "YENİ KARAKTER AÇILDI: V2 (menü → OYNA)" : null);
                    if (first) g.hud.Hint("KNUCKLEBLASTER artık senin: [G] ile kol değiştir. Ağır yumruk, basılı tut → şok dalgası.", 9);
                })
            );

            // ===== Çıkış (x -5..5, z -94..-77) =====
            L.Room(-5, -94, 5, -77,  y: 3, h: 10, mat: "castle", floor: "tiles", skip: A("s") );
            L.Portal(0, -92,  y: 3, color: 0xa0c0ff, glowColor: 0x80a0ff, w: 7, h: 9 );

            L.Spires(AA(A(-70, 10, 60, 7), A(70, -30, 70, 8), A(-80, -100, 80, 8), A(75, -130, 60, 7), A(0, -190, 90, 9)));
            L.FinishBuild();
        }

        // ================================================================ SİBER ÖĞÜTÜCÜ
        // Sonsuz dalga modu: 8×8 neon sütunlu ızgara; her dalgadan önce sütunlar yeni desene göre
        // yükselip alçalır. Dalgalar büyür; ölünce koşu biter ve ulaşılan dalga kaydedilir.
        const int CG_N = 8;
        const float CG_CELL = 4, CG_HALF = CG_N * CG_CELL / 2, CG_DEPTH = 14;

        static readonly Func<int, int, int, float>[] PATTERNS =
        {
            (i, j, w) => 0,
            (i, j, w) => i == 0 || j == 0 || i == CG_N - 1 || j == CG_N - 1 ? 3 : 0,
            (i, j, w) => (i + j) % 2 != 0 ? 1.5f : 0,
            (i, j, w) => Mathf.Max(0, 3 - Mathf.Max(Mathf.Abs(i - 3.5f), Mathf.Abs(j - 3.5f))) * 1.2f,
            (i, j, w) => (i * 7 + j * 13 + w * 5) % 5 == 0 ? 4 : (i * 3 + j * 5 + w) % 7 == 0 ? 2 : 0,
            (i, j, w) => i == 2 || i == 5 ? 2.5f : 0,
            (i, j, w) => Mathf.Abs(i - 3.5f) + Mathf.Abs(j - 3.5f) < 2.5f ? 0 : (i + j) % 3 == 0 ? 3 : 0.8f,
        };

        struct Roster { public string t; public float c; public int from, max; public bool fly; }
        static readonly Roster[] ROSTER =
        {
            new Roster { t = "filth", c = 1, from = 1 },
            new Roster { t = "stray", c = 1.5f, from = 1 },
            new Roster { t = "drone", c = 1.5f, from = 2, fly = true },
            new Roster { t = "schism", c = 2, from = 3 },
            new Roster { t = "streetcleaner", c = 2.5f, from = 4 },
            new Roster { t = "maliciousface", c = 5, from = 6, fly = true, max = 2 },
            new Roster { t = "swordsmachine", c = 8, from = 8, max = 1 },
            new Roster { t = "hideousmass", c = 10, from = 11, max = 1 },
            new Roster { t = "cerberus", c = 8, from = 13, max = 1 },
            new Roster { t = "v2", c = 12, from = 16, max = 1 },
        };

        public static void CyberGrind(UKLevel L)
        {
            L.Theme_(fog: 0x06040e, fogNear: 30, fogFar: 130,
                skyTop: A(0.0f, 0.0f, 0.03f), skyHor: A(0.06f, 0.02f, 0.14f), skyCloud: A(0.12f, 0.02f, 0.22f), skyGlow: A(0.55f, 0.08f, 0.7f),
                hemiSky: 0xb8c8ff, hemiGround: 0x301040, hemi: 2.2f, ambient: 0x404070, sun: 0xa8b8ff);
            L.endless = true;
            L.noBase = true;
            L.SetSpawn(pos: A(0, 0.1f, 27), yaw: 0, checkpoint: A(0, 0, 27), pitch: -0.05f);
            L.MenuCam(target: A(0, 2, 0), radius: 20, height: 9);
            L.AddDecor("drone", -4, 5, -4, 0.4f);
            L.AddDecor("streetcleaner", 4, 0, 2, -0.5f);
            L.AddDecor("v2", 0, 0, -6, 0);

            // ===== Hazırlık odası (x -6..6, z 17..33) =====
            L.Room(-6, 17, 6, 33, h: 8, mat: "neonWall", floor: "neon", ceil: "neonWall", skip: A("n"));
            L.Shop(4.4f, 0, 27, -Mathf.PI / 2);
            L.Hint(A(-5, 0, 18, 5, 3, 32), "SİBER ÖĞÜTÜCÜ: bitmeyen dalgalar. Her dalga öncekinden zor. Öldüğünde koşu biter — ulaştığın dalga kaydedilir.", 9);

            // ===== Izgara (x -16..16, z -16..16) =====
            L.Room(-CG_HALF, -CG_HALF, CG_HALF, CG_HALF, h: 26, mat: "neonWall", floor: null, gaps: UKLevel.MakeGaps(s: A(-4, 4, 8)));
            L.Box(-CG_HALF - 1, -CG_DEPTH - 2, -CG_HALF - 1, CG_HALF + 1, -CG_DEPTH, CG_HALF + 1, "neonWall");
            L.Door("dIn", -4, 0, 16.2f, 4, 8, 16.8f, open: true);
            for (int i = 0; i < CG_N; i++)
                for (int j = 0; j < CG_N; j++)
                {
                    float x0 = -CG_HALF + i * CG_CELL, z0 = -CG_HALF + j * CG_CELL;
                    L.AddCgPillar(x0, z0, x0 + CG_CELL, z0 + CG_CELL, CG_DEPTH, i, j);
                }
            foreach (var q in AA(A(-CG_HALF + 1, -CG_HALF + 1), A(CG_HALF - 1, -CG_HALF + 1), A(-CG_HALF + 1, CG_HALF - 1), A(CG_HALF - 1, CG_HALF - 1)))
                L.Lamp_(UKLevel.P(q[0], 10, q[1]), 0xc040ff, 1.3f);
            L.GlowSprite(0, 24, 0, 40, 0x40e0ff);

            L.Arena(
                id: "cg", name: "SİBER ÖĞÜTÜCÜ",
                trigger: A(-CG_HALF, 0, 8, CG_HALF, 6, 15.5f),
                locks: A("dIn"), exits: null, waves: null,
                endless: true,
                genWave: (w, g) => CgWave(L, w, g),
                onWave: (g, w, a) =>
                {
                    g.cgWave = w + 1;
                    g.hud.Title("SİBER ÖĞÜTÜCÜ", "DALGA " + (w + 1), 1.8f);
                },
                onStart: (g) => { g.cgWave = 0; });
            L.FinishBuild();
        }

        static UKLevel.CgPillar PillarAt(UKLevel L, float x, float z)
        {
            int i = Mathf.FloorToInt((x + CG_HALF) / CG_CELL), j = Mathf.FloorToInt((z + CG_HALF) / CG_CELL);
            return i >= 0 && j >= 0 && i < CG_N && j < CG_N ? L.cgPillars[i * CG_N + j] : null;
        }

        // Dalga üret: önce sütunları yeni desene taşı, sonra bütçeye göre düşman seç ve yerleştir
        static UKSpawn[] CgWave(UKLevel L, int w, UKGame g)
        {
            int n = w + 1;
            var p = g.player;
            var pat = n == 1 ? PATTERNS[0] : PATTERNS[(n * 3 + 1) % PATTERNS.Length];
            float px = p.transform.position.x, pz = -p.transform.position.z;
            var pc = PillarAt(L, px, pz);
            foreach (var pl in L.cgPillars)
            {
                // oyuncunun altındaki ve komşu sütunlar oynamaz (sıkışmasın)
                if (pc != null && Mathf.Abs(pl.i - pc.i) <= 1 && Mathf.Abs(pl.j - pc.j) <= 1) continue;
                pl.target = pat(pl.i, pl.j, n);
            }
            if (n > 1)
            {
                float heal = Mathf.Min(p.maxHp - p.hard - p.hp, 40);
                if (heal > 0) p.Heal(heal);
                g.hud.Message("DALGA " + (n - 1) + " TEMİZ" + (heal > 0 ? "  +" + Mathf.RoundToInt(heal) + " CAN" : ""), 1.6f, "cp");
                g.bonusP += 150 * (n - 1);
            }
            float budget = 2 + n * 1.7f;
            var list = new List<UKSpawn>();
            var count = new Dictionary<string, int>();
            var pool = new List<Roster>();
            foreach (var r in ROSTER) if (n >= r.from) pool.Add(r);
            int guard = 0;
            while (budget > 0.9f && list.Count < 14 && guard++ < 60)
            {
                var r = pool[UnityEngine.Random.Range(0, pool.Count)];
                count.TryGetValue(r.t, out int cn);
                if (r.c > budget + 0.5f || (r.max > 0 && cn >= r.max)) continue;
                count[r.t] = cn + 1;
                budget -= r.c;
                // oyuncudan uzak rastgele hücre; sütunun hedef yüksekliğinin üstünde doğar
                UKLevel.CgPillar cell = null;
                for (int k = 0; k < 20; k++)
                {
                    var c = L.cgPillars[UnityEngine.Random.Range(0, L.cgPillars.Count)];
                    float cx = -CG_HALF + (c.i + 0.5f) * CG_CELL, cz = -CG_HALF + (c.j + 0.5f) * CG_CELL;
                    if (Mathf.Sqrt((cx - px) * (cx - px) + (cz - pz) * (cz - pz)) > 11) { cell = c; break; }
                }
                if (cell == null) cell = L.cgPillars[0];
                float x = -CG_HALF + (cell.i + 0.5f) * CG_CELL, z = -CG_HALF + (cell.j + 0.5f) * CG_CELL;
                list.Add(E(r.t, A(x, cell.target + (r.fly ? 5 : 0.05f), z)));
            }
            return list.ToArray();
        }
    }
}
