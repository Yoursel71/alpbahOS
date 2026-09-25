// Kalıcı ilerleme (PlayerPrefs), dükkân kataloğu ve bölüm kaydı (web sürümüyle aynı: PRELUDE 0-1..0-5,
// KATMAN 1 ARAF 1-1..1-4 ve sonsuz SİBER ÖĞÜTÜCÜ). P: stil puanından biriken harcanabilir para.
using System;
using System.Collections.Generic;
using System.Globalization;
using UnityEngine;

namespace UK
{
    public class UKProgress
    {
        public class LevelRec { public string rank; public float time, style; public int wave; }

        public int points, unlocked = 1;
        public bool introSeen, v2Unlocked;
        public readonly HashSet<string> shop = new HashSet<string>();
        public readonly HashSet<string> altOn = new HashSet<string>();
        public readonly Dictionary<string, LevelRec> levels = new Dictionary<string, LevelRec>();

        const string KEY = "uk.progress.v2";
        static readonly CultureInfo IC = CultureInfo.InvariantCulture;

        public bool Has(string id) => shop.Contains(id);
        public bool AltOn(string weaponId) => altOn.Contains(weaponId);

        public static UKProgress Load()
        {
            var p = new UKProgress();
            string s = PlayerPrefs.GetString(KEY, "");
            if (string.IsNullOrEmpty(s)) return p;
            try
            {
                foreach (var line in s.Split('\n'))
                {
                    int eq = line.IndexOf('=');
                    if (eq <= 0) continue;
                    string k = line.Substring(0, eq), v = line.Substring(eq + 1);
                    switch (k)
                    {
                        case "points": p.points = Mathf.Max(0, int.Parse(v, IC)); break;
                        case "unlocked": p.unlocked = Mathf.Clamp(int.Parse(v, IC), 1, UKLevelDefs.STORY_COUNT); break;
                        case "intro": p.introSeen = v == "1"; break;
                        case "v2": p.v2Unlocked = v == "1"; break;
                        case "shop": foreach (var x in v.Split(',')) if (x.Length > 0) p.shop.Add(x); break;
                        case "alt": foreach (var x in v.Split(',')) if (x.Length > 0) p.altOn.Add(x); break;
                        case "levels":
                            foreach (var rec in v.Split(';'))
                            {
                                var f = rec.Split('|');
                                if (f.Length < 5) continue;
                                p.levels[f[0]] = new LevelRec { rank = f[1], time = float.Parse(f[2], IC), style = float.Parse(f[3], IC), wave = int.Parse(f[4], IC) };
                            }
                            break;
                    }
                }
            }
            catch (Exception e) { Debug.LogWarning("ULTRAKILL: ilerleme kaydı okunamadı, sıfırlandı. " + e.Message); return new UKProgress(); }
            return p;
        }

        public void Save()
        {
            var sb = new System.Text.StringBuilder();
            sb.Append("points=").Append(points.ToString(IC)).Append('\n');
            sb.Append("unlocked=").Append(unlocked.ToString(IC)).Append('\n');
            sb.Append("intro=").Append(introSeen ? "1" : "0").Append('\n');
            sb.Append("v2=").Append(v2Unlocked ? "1" : "0").Append('\n');
            sb.Append("shop=").Append(string.Join(",", shop)).Append('\n');
            sb.Append("alt=").Append(string.Join(",", altOn)).Append('\n');
            var recs = new List<string>();
            foreach (var kv in levels)
                recs.Add(kv.Key + "|" + kv.Value.rank + "|" + kv.Value.time.ToString(IC) + "|" + kv.Value.style.ToString(IC) + "|" + kv.Value.wave.ToString(IC));
            sb.Append("levels=").Append(string.Join(";", recs)).Append('\n');
            PlayerPrefs.SetString(KEY, sb.ToString());
            PlayerPrefs.Save();
        }

        public static void Wipe()
        {
            PlayerPrefs.DeleteKey(KEY);
            PlayerPrefs.Save();
        }

        // ------------------------------------------------------------ sıralama yardımcıları
        public const string ORDER = "DCBASP";
        public static string RankTime(float t, float[] th) => t <= th[0] ? "S" : t <= th[1] ? "A" : t <= th[2] ? "B" : t <= th[3] ? "C" : "D";
        public static string RankStyle(float s, float[] th) => s >= th[0] ? "S" : s >= th[1] ? "A" : s >= th[2] ? "B" : s >= th[3] ? "C" : "D";
        public static string RankKills(float f) => f >= 1 ? "S" : f >= 0.9f ? "A" : f >= 0.75f ? "B" : f >= 0.5f ? "C" : "D";

        public static string FinalRank(string[] ranks, int restarts)
        {
            bool allS = true;
            float sum = 0;
            foreach (var r in ranks) { int i = ORDER.IndexOf(r); sum += i; if (i != 4) allS = false; }
            if (allS && restarts == 0) return "P";
            return ORDER[Mathf.Min(4, Mathf.RoundToInt(sum / ranks.Length))].ToString();
        }

        public static bool Better(string oldRank, string newRank) => string.IsNullOrEmpty(oldRank) || ORDER.IndexOf(newRank) > ORDER.IndexOf(oldRank);
    }

    // ================================================================ dükkân
    public class UKShopItem
    {
        public string id, group, name, sub, needs, alt;
        public int w = -1, v;
        public bool arm;
        public Color color;
        public int price;
    }

    public static class UKShop
    {
        public static readonly List<UKShopItem> ITEMS = new List<UKShopItem>();
        public static readonly string[][] GROUPS =
        {
            new[] { "revolver", "1 · REVOLVER" }, new[] { "shotgun", "2 · SHOTGUN" }, new[] { "nailgun", "3 · NAILGUN" },
            new[] { "rail", "4 · RAILCANNON" }, new[] { "rocket", "5 · ROCKET" }, new[] { "arms", "KOLLAR" }, new[] { "alts", "ALTERNATİF SİLAHLAR" },
        };

        static readonly Dictionary<string, int> PRICES = new Dictionary<string, int>
        {
            { "revolver.marksman", 1500 }, { "revolver.sharpshooter", 3000 },
            { "shotgun", 2000 }, { "shotgun.pump", 2000 }, { "shotgun.saw", 3000 },
            { "nailgun", 3500 }, { "nailgun.overheat", 2500 }, { "nailgun.sawblade", 3000 },
            { "rail", 5500 }, { "rail.screwdriver", 3500 }, { "rail.malicious", 4500 },
            { "rocket", 6500 }, { "rocket.cannon", 3500 }, { "rocket.fire", 4000 },
            { "arm.knuckle", 3000 }, { "arm.hook", 2500 },
        };

        public static readonly Dictionary<string, string> HINTS = new Dictionary<string, string>
        {
            { "alt.revolver", "SLAB REVOLVER takıldı: yavaş ama ağır. Dükkândan ÇIKAR ile normal revolvere dönebilirsin." },
            { "alt.shotgun", "JACKHAMMER takıldı: yakına dev darbe. Havadayken yere ateş et → yüksek zıplama. Pompa şarjı gücü artırır." },
            { "revolver.marksman", "MARKSMAN: [SAĞ TIK] bozuk para at, paraya ateş et → RICOSHOT. Revolver tuşuna tekrar basınca varyant değişir." },
            { "revolver.sharpshooter", "SHARPSHOOTER: [SAĞ TIK] basılı tut → duvarlardan seken ışın." },
            { "shotgun", "SHOTGUN: [SOL TIK] saçma · [SAĞ TIK] basılı tut → CORE EJECT bombası; bombaya ateş et → büyük patlama. Yakından vur + hemen yumrukla = SHOTGUN PARRY." },
            { "shotgun.pump", "PUMP CHARGE: [SAĞ TIK] ile pompala; 3. pompada patlar." },
            { "shotgun.saw", "SAWED-ON: [SAĞ TIK] zincirli testere fırlat, geri döner." },
            { "nailgun", "NAILGUN: [SOL TIK] basılı tut → çivi yağmuru · [SAĞ TIK] mıknatıs at, çiviler ona kıvrılır." },
            { "nailgun.overheat", "OVERHEAT: [SAĞ TIK] ısınmış çivi patlaması → düşmanları yakar." },
            { "nailgun.sawblade", "SAWBLADE: duvarlardan seken testere diskleri." },
            { "rail", "RAILCANNON: tek atış her şeyi deler, sonra uzun şarj. Boss'a sakla!" },
            { "rail.screwdriver", "SCREWDRIVER: düşmana saplanıp deler." },
            { "rail.malicious", "MALICIOUS: vurduğu yerde patlar." },
            { "rocket", "ROCKET LAUNCHER: roket zıplaması! [SAĞ TIK] FREEZEFRAME ile roketleri dondur." },
            { "rocket.cannon", "S.R.S. CANNON: [SAĞ TIK] ağır gülle." },
            { "rocket.fire", "FIRESTARTER: [SAĞ TIK] alev püskürt, yanan düşmana roket = patlama." },
            { "arm.knuckle", "KNUCKLEBLASTER: [G] ile kol değiştir. Ağır yumruk; [F] basılı tut → şok dalgası. Mermi savuşturamaz!" },
            { "arm.hook", "WHIPLASH: [E] kanca. Hafif düşmanı sana çeker, ağır düşmana seni çeker." },
        };

        static UKShop()
        {
            var WS = UKWeapons.WEAPONS;
            for (int w = 0; w < WS.Length; w++)
                for (int v = 0; v < WS[w].variants.Length; v++)
                {
                    if (w == 0 && v == 0) continue; // Revolver (Piercer) ücretsiz
                    var V = WS[w].variants[v];
                    string id = v == 0 ? WS[w].id : WS[w].id + "." + V.id;
                    ITEMS.Add(new UKShopItem
                    {
                        id = id, w = w, v = v, group = WS[w].id, name = v == 0 ? WS[w].name : V.name,
                        sub = v == 0 ? V.name + " ile gelir" : WS[w].name, color = V.color,
                        price = PRICES.TryGetValue(id, out var pr) ? pr : 3000, needs = v == 0 || w == 0 ? null : WS[w].id,
                    });
                }
            ITEMS.Add(new UKShopItem { id = "arm.knuckle", arm = true, group = "arms", name = "KNUCKLEBLASTER", sub = "Ağır yumruk · [G] ile değiştir", color = new Color(1f, 0.23f, 0.16f), price = PRICES["arm.knuckle"] });
            ITEMS.Add(new UKShopItem { id = "arm.hook", arm = true, group = "arms", name = "WHIPLASH", sub = "Kanca · [E]", color = new Color(0.24f, 0.88f, 0.42f), price = PRICES["arm.hook"] });
            ITEMS.Add(new UKShopItem { id = "alt.revolver", alt = "revolver", w = 0, group = "alts", name = "SLAB REVOLVER", sub = "Ağır revolver: yavaş, %70 daha güçlü", color = new Color(1f, 0.6f, 0.25f), price = 4000 });
            ITEMS.Add(new UKShopItem { id = "alt.shotgun", alt = "shotgun", w = 1, group = "alts", name = "JACKHAMMER", sub = "Piston: kısa menzil dev darbe, yere ateşle → zıpla", color = new Color(1f, 0.75f, 0.25f), price = 5000, needs = "shotgun" });
        }

        public static UKShopItem Find(string id) => ITEMS.Find(x => x.id == id);
    }

    // ================================================================ bölüm kaydı
    public class UKResults
    {
        public bool endless, challenge, newBest, hasNext;
        public float time, style, damage;
        public int kills, killsTotal, secrets, secretsTotal, parries, restarts, droneParries, tanks, wave, bestWave, rankBonus, pointsEarned, pointsTotal;
        public string levelId, levelTitle, timeRank, killRank, styleRank, final, challengeText, finale, difficulty;
    }

    public class UKLevelDef
    {
        public string id, name, layer, desc, finale;
        public bool endless;
        public Action<UKLevel> build;
        public float[] time, style;
        public Func<UKResults, string> challengeText;
        public Func<UKResults, bool> challenge;
    }

    public static class UKLevelDefs
    {
        const string PRELUDE = "PRELUDE: İLK KAN", LIMBO = "KATMAN 1: ARAF";
        static string Clock(float t) => Mathf.FloorToInt(t / 60) + ":" + Mathf.FloorToInt(t % 60).ToString("00");

        public static readonly UKLevelDef[] LEVELS =
        {
            new UKLevelDef
            {
                id = "0-1", name = "ATEŞİN İÇİNE", layer = PRELUDE, build = UKLevels.L01,
                desc = "Silahsız iniş ve hareket eğitimi, Revolver, parry eğitmeni, ilk dükkân. Boss: Swordsmachine.",
                time = new float[] { 240, 330, 420, 540 }, style = new float[] { 6500, 4500, 3000, 1500 },
                challengeText = r => "En az 5 PARRY yap (" + r.parries + ")", challenge = r => r.parries >= 5,
            },
            new UKLevelDef
            {
                id = "0-2", name = "KIYMA MAKİNESİ", layer = PRELUDE, build = UKLevels.L02,
                desc = "Öğütücü çukurlu mezbaha. Düşmanları öğütücüye it! İki büyük arena, 2 gizli küre.",
                time = new float[] { 210, 300, 390, 480 }, style = new float[] { 7000, 5000, 3200, 1600 },
                challengeText = r => "3 dakikanın altında bitir (" + Clock(r.time) + ")", challenge = r => r.time < 180,
            },
            new UKLevelDef
            {
                id = "0-3", name = "ÇİFTE BELA", layer = PRELUDE, build = UKLevels.L03,
                desc = "Harabeler ve ilk Malicious Face. Boss: aynı anda İKİ Swordsmachine.",
                time = new float[] { 200, 290, 380, 480 }, style = new float[] { 7000, 5000, 3200, 1600 },
                challengeText = r => "100'den az hasar al (" + Mathf.RoundToInt(r.damage) + ")", challenge = r => r.damage < 100,
            },
            new UKLevelDef
            {
                id = "0-4", name = "TEK MAKİNELİK ORDU", layer = PRELUDE, build = UKLevels.L04,
                desc = "Kolezyumda altı dalgalı tek meydan savaşı. Malicious Face'ler ve bir Swordsmachine.",
                time = new float[] { 240, 330, 420, 540 }, style = new float[] { 9000, 6500, 4200, 2000 },
                challengeText = r => "Hiç ölmeden bitir (" + r.restarts + ")", challenge = r => r.restarts == 0,
            },
            new UKLevelDef
            {
                id = "0-5", name = "CERBERUS", layer = PRELUDE, build = UKLevels.L05,
                desc = "Kapının bekçileri: uyanan iki taş heykel. PRELUDE'un son bölümü.",
                time = new float[] { 150, 220, 300, 400 }, style = new float[] { 6000, 4200, 2800, 1400 },
                challengeText = r => "En az 8 PARRY yap (" + r.parries + ")", challenge = r => r.parries >= 8,
                finale = "PRELUDE TAMAMLANDI — CEHENNEMİN KAPILARI AÇILDI. SIRADA ARAF.",
            },
            new UKLevelDef
            {
                id = "1-1", name = "GÜNDOĞUMUNUN KALBİ", layer = LIMBO, build = UKLevels.L11,
                desc = "Güneşli kale bahçeleri, kırık hendek köprüsü ve kule salonu. Yeni düşman: DRONE.",
                time = new float[] { 230, 320, 410, 520 }, style = new float[] { 8000, 5600, 3600, 1800 },
                challengeText = r => "Bir DRONE'u yumrukla geri yolla (" + r.droneParries + ")", challenge = r => r.droneParries >= 1,
            },
            new UKLevelDef
            {
                id = "1-2", name = "YANAN DÜNYA", layer = LIMBO, build = UKLevels.L12,
                desc = "Yanan köy, alevli kirişler ve yıkık kilise. Yeni düşman: STREETCLEANER.",
                time = new float[] { 240, 330, 420, 540 }, style = new float[] { 8500, 6000, 3800, 1900 },
                challengeText = r => "3 Streetcleaner tankını patlat (" + r.tanks + ")", challenge = r => r.tanks >= 3,
            },
            new UKLevelDef
            {
                id = "1-3", name = "KUTSAL KALINTILAR SALONU", layer = LIMBO, build = UKLevels.L13,
                desc = "Beyaz mermer, altın kiriş ve heykeller galerisi. Mini boss: HIDEOUS MASS.",
                time = new float[] { 220, 310, 400, 500 }, style = new float[] { 8000, 5600, 3600, 1800 },
                challengeText = r => "150'den az hasar al (" + Mathf.RoundToInt(r.damage) + ")", challenge = r => r.damage < 150,
            },
            new UKLevelDef
            {
                id = "1-4", name = "AY IŞIĞI", layer = LIMBO, build = UKLevels.L14,
                desc = "Ay ışığında düello: kendin gibi bir makine. Boss: V2. Kazan → Knuckleblaster ve oynanabilir V2.",
                time = new float[] { 120, 180, 250, 340 }, style = new float[] { 6500, 4500, 3000, 1500 },
                challengeText = r => "V2'nin yumruğunu PARRY yap (" + r.parries + ")", challenge = r => r.parries >= 1,
                finale = "KATMAN 1 TAMAMLANDI — V2 ARTIK OYNANABİLİR KARAKTER.",
            },
            new UKLevelDef
            {
                id = "CG", name = "SİBER ÖĞÜTÜCÜ", layer = "SİBER ÖĞÜTÜCÜ", build = UKLevels.CyberGrind, endless = true,
                desc = "Sonsuz dalga modu: neon ızgarada yükselen sütunlar, her dalga daha zor. En yüksek dalgayı kovala. (0-1 bitince açılır)",
                time = new float[] { 0, 0, 0, 0 }, style = new float[] { 0, 0, 0, 0 },
                challengeText = r => "10. dalgaya ulaş (" + r.wave + ")", challenge = r => r.wave >= 10,
            },
        };

        public static readonly int STORY_COUNT = 9;

        public static int IndexOf(string id)
        {
            for (int i = 0; i < LEVELS.Length; i++) if (LEVELS[i].id == id) return i;
            return 0;
        }
    }
}
