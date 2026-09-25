// Stil ölçeri (web sürümüyle aynı tablo): D → ULTRAKILL rütbeleri, bonus listesi,
// silah tazeliği (FRESH/USED/STALE/DULL), çoklu öldürme ve ARSENAL.
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKStyle
    {
        public struct Rank { public string letter, name; public Color color; public float cap, decay; }
        public struct Fresh { public float min, mult; public string name; public Color color; }
        public class Bonus { public string name; public Color color; public float t; public int count; }

        static Color Hex(string h) { ColorUtility.TryParseHtmlString(h, out var c); return c; }

        public static readonly Rank[] RANKS =
        {
            new Rank { letter = "D", name = "DESTRUCTIVE", color = Hex("#4aa3ff"), cap = 260, decay = 14 },
            new Rank { letter = "C", name = "CHAOTIC", color = Hex("#3ee06a"), cap = 320, decay = 20 },
            new Rank { letter = "B", name = "BRUTAL", color = Hex("#ffd21f"), cap = 380, decay = 27 },
            new Rank { letter = "A", name = "ANARCHIC", color = Hex("#ff8a1f"), cap = 440, decay = 34 },
            new Rank { letter = "S", name = "SUPREME", color = Hex("#ff3a24"), cap = 500, decay = 42 },
            new Rank { letter = "SS", name = "SSADISTIC", color = Hex("#ff3a24"), cap = 560, decay = 50 },
            new Rank { letter = "SSS", name = "SSSHITSTORM", color = Hex("#ff3a24"), cap = 620, decay = 58 },
            new Rank { letter = "ULTRAKILL", name = "ULTRAKILL", color = Hex("#ffd24a"), cap = 700, decay = 66 },
        };

        public static readonly Fresh[] FRESHNESS =
        {
            new Fresh { min = 0.75f, name = "FRESH", mult = 1.5f, color = Hex("#3ee06a") },
            new Fresh { min = 0.5f, name = "USED", mult = 1f, color = Hex("#ffd21f") },
            new Fresh { min = 0.25f, name = "STALE", mult = 0.5f, color = Hex("#ff8a1f") },
            new Fresh { min = -1f, name = "DULL", mult = 0.2f, color = Hex("#ff3a24") },
        };

        static readonly Dictionary<string, string> BONUS_COLORS = new Dictionary<string, string>
        {
            { "PARRY", "#3ee06a" }, { "BIG KILL", "#ff5a4a" }, { "INSTAKILL", "#ff5a4a" }, { "ARSENAL", "#4aa3ff" },
            { "ENRAGED", "#ff3a24" }, { "INTERRUPTION", "#3ee06a" }, { "PROJECTILE BOOST", "#3ee06a" },
            { "BIG HEADSHOT", "#ffffff" }, { "SPLATTERED", "#ff5a4a" }, { "PARRIED KILL", "#3ee06a" },
            { "AIRSHOT", "#ffae2a" }, { "FRIED", "#ff8a1f" }, { "RICOSHOT", "#ffae2a" }, { "QUICKDRAW", "#4aa3ff" },
            { "CORE SNIPE", "#ffae2a" }, { "SHOTGUN PARRY", "#3ee06a" }, { "COIN PUNCH", "#ffae2a" }, { "HOOKED", "#9adf5a" },
            { "DRILLED", "#3ee06a" }, { "BURNED", "#ff8a1f" }, { "CHARGEBACK", "#3ee06a" }, { "SECRET", "#80c8ff" },
        };

        public static readonly string[] WEAPON_KEYS = { "revolver", "shotgun", "nailgun", "rail", "rocket" };

        // Tazelik izlenen silah kimliği (yumruk, patlama, lav vb. → null)
        public static string FreshWeapon(string w) => w != null && System.Array.IndexOf(WEAPON_KEYS, w) >= 0 ? w : null;

        public int rank;
        public float meter, total, pulse;
        public bool active, frozen;
        public readonly List<Bonus> bonuses = new List<Bonus>();
        public readonly Dictionary<string, float> fresh = new Dictionary<string, float>();
        readonly List<KeyValuePair<string, float>> killWeapons = new List<KeyValuePair<string, float>>();
        float lastKillT = -10;
        int combo;

        static float Now => Time.time;

        public void Reset(bool full)
        {
            rank = 0;
            meter = 0;
            if (full) total = 0;
            bonuses.Clear();
            fresh.Clear();
            foreach (var k in WEAPON_KEYS) fresh[k] = 1;
            lastKillT = -10;
            combo = 0;
            frozen = false;
            killWeapons.Clear();
            active = false;
        }

        public Fresh Freshness(string w)
        {
            float f = w != null && fresh.TryGetValue(w, out var v) ? v : 1;
            foreach (var fr in FRESHNESS) if (f >= fr.min) return fr;
            return FRESHNESS[FRESHNESS.Length - 1];
        }

        public void Add(string name, float pts, string weapon, int count = 0)
        {
            if (frozen) return;
            float mult = 1;
            if (weapon != null && fresh.ContainsKey(weapon))
            {
                mult = Freshness(weapon).mult;
                fresh[weapon] = Mathf.Max(0, fresh[weapon] - pts / 1400f);
            }
            float gained = Mathf.Round(pts * mult);
            meter += gained;
            total += gained;
            active = true;
            if (name != null) PushBonus(name, count);
            CheckRank();
        }

        // yalnız puan (hasar vb.), liste satırı yok
        public void AddRaw(float pts, string weapon) => Add(null, pts, weapon);

        void PushBonus(string name, int count)
        {
            float now = Now;
            var last = bonuses.Count > 0 ? bonuses[bonuses.Count - 1] : null;
            if (last != null && last.name == name && now - last.t < 1.2f && count == 0)
            {
                last.count = Mathf.Max(1, last.count) + 1;
                last.t = now;
                return;
            }
            var col = BONUS_COLORS.TryGetValue(name, out var h) ? Hex(h) : Color.white;
            bonuses.Add(new Bonus { name = name, color = col, t = now, count = count });
            if (bonuses.Count > 7) bonuses.RemoveAt(0);
        }

        void CheckRank()
        {
            while (rank < RANKS.Length - 1 && meter >= RANKS[rank].cap)
            {
                meter -= RANKS[rank].cap;
                rank++;
                pulse = 1;
                UKAudio.I.Play("rankUp", 1, Mathf.Pow(2, rank / 6f), true);
            }
            if (rank == RANKS.Length - 1) meter = Mathf.Min(meter, RANKS[rank].cap);
        }

        public void OnKill(string weapon)
        {
            float now = Now;
            if (now - lastKillT < 0.45f) combo++;
            else combo = 1;
            lastKillT = now;
            if (combo == 2) Add("DOUBLE KILL", 60, null);
            else if (combo == 3) Add("TRIPLE KILL", 110, null);
            else if (combo >= 4) Add("MULTIKILL", 160, null, combo);
            if (weapon != null && fresh.ContainsKey(weapon))
            {
                killWeapons.Add(new KeyValuePair<string, float>(weapon, now));
                killWeapons.RemoveAll(k => now - k.Value > 6);
                var set = new HashSet<string>();
                foreach (var k in killWeapons) set.Add(k.Key);
                if (set.Count >= 3) { Add("ARSENAL", 150, null); killWeapons.Clear(); }
            }
        }

        public void OnDamageTaken(float dmg)
        {
            if (frozen) return;
            meter -= dmg * 7;
            while (meter < 0 && rank > 0)
            {
                rank--;
                meter += RANKS[rank].cap * 0.6f;
            }
            if (meter < 0) meter = 0;
        }

        public void Tick(float dt, string currentWeapon)
        {
            pulse = Mathf.Max(0, pulse - Time.unscaledDeltaTime * 3);
            if (frozen) return;
            var keys = new List<string>(fresh.Keys);
            foreach (var w in keys) if (w != currentWeapon) fresh[w] = Mathf.Min(1, fresh[w] + dt * 0.06f);
            float now = Now;
            bonuses.RemoveAll(b => now - b.t > 3.2f);
            if (!active) return;
            meter -= RANKS[rank].decay * dt;
            if (meter < 0)
            {
                if (rank > 0)
                {
                    rank--;
                    meter = RANKS[rank].cap * 0.7f;
                }
                else
                {
                    meter = 0;
                    if (bonuses.Count == 0) active = false;
                }
            }
        }
    }
}
