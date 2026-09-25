// Ses motoru: tüm efektler başlangıçta C# içinde DSP ile (osilatör, gürültü, RBJ biquad filtre,
// doyum, zarf) üretilir ve AudioClip olarak saklanır. Harici ses dosyası yoktur.
// Çalarken rastgele perde ve 3B konum (düşman sesleri) uygulanır.
using System;
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKAudio : MonoBehaviour
    {
        public static UKAudio I;
        const int SR = 44100;
        const float TAU = Mathf.PI * 2f;
        readonly Dictionary<string, AudioClip> bank = new Dictionary<string, AudioClip>();
        readonly Dictionary<string, float> vol = new Dictionary<string, float>();
        readonly List<AudioSource> sources2D = new List<AudioSource>();
        readonly List<AudioSource> sources3D = new List<AudioSource>();
        readonly Dictionary<string, float> lastPlay = new Dictionary<string, float>();
        int next2D, next3D;
        AudioSource slideLoop;
        public float master = 0.8f;
        static readonly System.Random rng = new System.Random(7);
        static float Rnd() => (float)(rng.NextDouble() * 2 - 1);
        static float Sat(float x) => (float)Math.Tanh(x);

        // RBJ biquad (lp / hp / bp)
        class BQ
        {
            readonly string type; readonly float q;
            float b0, b1, b2, a1, a2, x1, x2, y1, y2;
            public BQ(string type, float f, float q = 0.707f) { this.type = type; this.q = q; Set(f); }
            public void Set(float f)
            {
                f = Mathf.Clamp(f, 20f, SR * 0.45f);
                float w = TAU * f / SR, cs = Mathf.Cos(w), sn = Mathf.Sin(w), a = sn / (2 * q);
                float a0 = 1 + a, _a1 = -2 * cs, _a2 = 1 - a, _b0, _b1, _b2;
                if (type == "lp") { _b0 = (1 - cs) / 2; _b1 = 1 - cs; _b2 = (1 - cs) / 2; }
                else if (type == "hp") { _b0 = (1 + cs) / 2; _b1 = -(1 + cs); _b2 = (1 + cs) / 2; }
                else { _b0 = a; _b1 = 0; _b2 = -a; }
                b0 = _b0 / a0; b1 = _b1 / a0; b2 = _b2 / a0; a1 = _a1 / a0; a2 = _a2 / a0;
            }
            public float Run(float x)
            {
                float y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
                x2 = x1; x1 = x; y2 = y1; y1 = y;
                return y;
            }
        }

        class Osc
        {
            readonly int type; double ph;
            public Osc(int type = 0) { this.type = type; ph = rng.NextDouble(); }
            public float Run(float f)
            {
                ph += f / SR; ph -= Math.Floor(ph);
                float p = (float)ph;
                switch (type)
                {
                    case 1: return 2 * p - 1;                     // testere
                    case 2: return p < 0.5f ? 1 : -1;             // kare
                    case 3: return 4 * Mathf.Abs(p - 0.5f) - 1;   // üçgen
                    default: return Mathf.Sin(TAU * p);
                }
            }
        }

        delegate void Gen(float[] o, int n);

        void Def(string name, float dur, float volume, Gen g)
        {
            int n = Mathf.CeilToInt(dur * SR);
            var o = new float[n];
            g(o, n);
            float peak = 0;
            for (int i = 0; i < n; i++) peak = Mathf.Max(peak, Mathf.Abs(o[i]));
            float k = peak > 0 ? 0.95f / peak : 1f;
            for (int i = 0; i < n; i++) o[i] *= k;
            var clip = AudioClip.Create(name, n, 1, SR, false);
            clip.SetData(o, 0);
            bank[name] = clip;
            vol[name] = volume;
        }

        void Awake()
        {
            I = this;
            for (int i = 0; i < 12; i++) sources2D.Add(MakeSource(false));
            for (int i = 0; i < 16; i++) sources3D.Add(MakeSource(true));
            slideLoop = MakeSource(false);
            slideLoop.loop = true;
            Build();
            Build2();
            slideLoop.clip = bank["slide"];
        }

        // Eski/diğer adlar → bankadaki ses
        static readonly Dictionary<string, string> alias = new Dictionary<string, string> { { "bossShotgun", "shotgun" }, { "chargeReady", "charge" } };
        static string Res(string name) => alias.TryGetValue(name, out var a) ? a : name;

        // Adlandırılmış döngüler (şarj, alev): açıkken çalar, kapanınca durur
        readonly Dictionary<string, AudioSource> loops = new Dictionary<string, AudioSource>();
        public void Loop(string id, bool on, string clip = null, float volume = 1f, float pitch = 1f)
        {
            loops.TryGetValue(id, out var s);
            if (!on) { if (s != null && s.isPlaying) s.Stop(); return; }
            if (s == null)
            {
                s = MakeSource(false);
                s.loop = true;
                loops[id] = s;
            }
            var name = Res(clip ?? id);
            if (!bank.TryGetValue(name, out var c)) return;
            if (s.clip != c) s.clip = c;
            s.volume = vol[name] * volume * master;
            s.pitch = pitch;
            if (!s.isPlaying) s.Play();
        }

        public void StopAllLoops()
        {
            foreach (var s in loops.Values) if (s.isPlaying) s.Stop();
            Slide(false);
        }

        AudioSource MakeSource(bool spatial)
        {
            var go = new GameObject(spatial ? "sfx3d" : "sfx2d");
            go.transform.SetParent(transform, false);
            var s = go.AddComponent<AudioSource>();
            s.playOnAwake = false;
            s.spatialBlend = spatial ? 1f : 0f;
            s.rolloffMode = AudioRolloffMode.Linear;
            s.minDistance = 4f;
            s.maxDistance = 70f;
            s.dopplerLevel = 0f;
            return s;
        }

        public void Play(string name, float volume = 1f, float pitch = 1f, bool exactPitch = false)
        {
            name = Res(name);
            if (!bank.TryGetValue(name, out var clip)) return;
            if (lastPlay.TryGetValue(name, out var t) && Time.unscaledTime - t < 0.03f) return;
            lastPlay[name] = Time.unscaledTime;
            var s = sources2D[next2D = (next2D + 1) % sources2D.Count];
            s.clip = clip;
            s.volume = vol[name] * volume * master;
            s.pitch = exactPitch ? pitch : pitch * UnityEngine.Random.Range(0.93f, 1.07f);
            s.Play();
        }

        public void PlayAt(string name, Vector3 pos, float volume = 1f, float pitch = 1f)
        {
            name = Res(name);
            if (!bank.TryGetValue(name, out var clip)) return;
            var s = sources3D[next3D = (next3D + 1) % sources3D.Count];
            s.transform.position = pos;
            s.clip = clip;
            s.volume = vol[name] * volume * master;
            s.pitch = pitch * UnityEngine.Random.Range(0.92f, 1.08f);
            s.Play();
        }

        public void Slide(bool on)
        {
            if (on && !slideLoop.isPlaying) { slideLoop.volume = 0.12f * master; slideLoop.Play(); }
            else if (!on && slideLoop.isPlaying) slideLoop.Stop();
        }

        public bool Has(string name) => bank.ContainsKey(Res(name));

        // ------------------------------------------------------------ ses tanımları
        void Build()
        {
            Def("revolver", 0.7f, 0.55f, (o, n) =>
            {
                var lp = new BQ("lp", 7000, 0.8f); var bp = new BQ("bp", 1100, 0.9f); var th = new Osc();
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    float v = t < 0.0025f ? z * 1.4f : 0;
                    v += lp.Run(z) * Mathf.Exp(-t / 0.03f) * 1.1f;
                    v += th.Run(48 + 170 * Mathf.Exp(-t / 0.018f)) * Mathf.Exp(-t / 0.08f) * 1.1f;
                    v += bp.Run(z) * Mathf.Exp(-t / 0.18f) * 0.5f;
                    o[i] = Sat(v * 1.6f);
                }
            });
            Def("piercer", 1.1f, 0.7f, (o, n) =>
            {
                var lp = new BQ("lp", 9000, 0.7f); var s = new Osc(1); var th = new Osc(); var r1 = new Osc(); var r2 = new Osc();
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    lp.Set(9000 * Mathf.Exp(-t / 0.15f) + 300);
                    float v = lp.Run(z) * Mathf.Exp(-t / 0.12f) * 1.2f;
                    v += s.Run(2600 * Mathf.Exp(-t / 0.08f) + 90) * Mathf.Exp(-t / 0.2f) * 0.5f;
                    v += th.Run(40 + 140 * Mathf.Exp(-t / 0.03f)) * Mathf.Exp(-t / 0.18f) * 1.3f;
                    v += (r1.Run(2310) * 0.5f + r2.Run(3140) * 0.35f) * Mathf.Exp(-t / 0.35f) * 0.35f;
                    o[i] = Sat(v * 1.8f);
                }
            });
            Def("charge", 0.5f, 0.35f, (o, n) =>
            {
                var a = new Osc(); var b = new Osc();
                for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = (a.Run(1760) * 0.5f + b.Run(2640) * 0.35f) * Mathf.Exp(-t / 0.14f) * Mathf.Min(1, t / 0.004f); }
            });
            Def("shotgun", 1.0f, 0.8f, (o, n) =>
            {
                var lp = new BQ("lp", 4000, 0.7f); var th = new Osc(); var bp = new BQ("bp", 700, 0.8f); var lp2 = new BQ("lp", 300);
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    lp.Set(200 + 5000 * Mathf.Exp(-t / 0.08f));
                    float v = lp.Run(z) * Mathf.Exp(-t / 0.25f) * 1.6f;
                    v += th.Run(40 + 120 * Mathf.Exp(-t / 0.03f)) * Mathf.Exp(-t / 0.2f) * 1.6f;
                    v += bp.Run(z) * Mathf.Exp(-t / 0.3f) * 0.6f + lp2.Run(z) * Mathf.Exp(-t / 0.5f) * 1.2f;
                    o[i] = Sat(v * 1.7f);
                }
            });
            Def("pump", 0.5f, 0.45f, (o, n) =>
            {
                var bp = new BQ("bp", 1800, 3); var bp2 = new BQ("bp", 900, 2);
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    float a = t < 0.2f ? Mathf.Exp(-t / 0.02f) : Mathf.Exp(-(t - 0.2f) / 0.02f);
                    o[i] = (bp.Run(z) * 1.5f + bp2.Run(z)) * a;
                }
            });
            Def("nail", 0.18f, 0.3f, (o, n) =>
            {
                var bp = new BQ("bp", 2500, 1.5f); var s = new Osc(2);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = (bp.Run(Rnd()) * 1.5f + s.Run(900 - 2000 * t) * 0.3f) * Mathf.Exp(-t / 0.035f); }
            });
            Def("explosion", 2.0f, 0.95f, (o, n) =>
            {
                var lp = new BQ("lp", 3000); var th = new Osc(); var lp2 = new BQ("lp", 120);
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    lp.Set(80 + 3000 * Mathf.Exp(-t / 0.06f));
                    float v = lp.Run(z) * Mathf.Exp(-t / 0.4f) * 1.5f;
                    v += th.Run(22 + 60 * Mathf.Exp(-t / 0.08f)) * Mathf.Exp(-t / 0.8f) * 2;
                    v += lp2.Run(z) * Mathf.Exp(-t / 1.2f) * 2;
                    o[i] = Sat(v * 1.6f);
                }
            });
            Def("empty", 0.08f, 0.3f, (o, n) => { var bp = new BQ("bp", 2500, 5); for (int i = 0; i < n; i++) o[i] = bp.Run(Rnd()) * Mathf.Exp(-(float)i / SR / 0.01f) * 3; });
            Def("punch", 0.3f, 0.35f, (o, n) =>
            {
                var bp = new BQ("bp", 600, 1.4f);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; bp.Set(500 + 3500 * (t / 0.3f)); o[i] = bp.Run(Rnd()) * Mathf.Sin(Mathf.PI * Mathf.Min(1, t / 0.3f)) * 1.5f; }
            });
            Def("punchHit", 0.4f, 0.6f, (o, n) =>
            {
                var th = new Osc(); var lp = new BQ("lp", 1500); var bp = new BQ("bp", 400, 1.5f);
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    o[i] = Sat((th.Run(45 + 120 * Mathf.Exp(-t / 0.03f)) * Mathf.Exp(-t / 0.1f) * 1.4f + lp.Run(z) * Mathf.Exp(-t / 0.04f) * 1.2f + bp.Run(z) * Mathf.Exp(-t / 0.12f) * 0.6f) * 1.6f);
                }
            });
            Def("parry", 1.6f, 1.0f, (o, n) =>
            {
                // keskin metal tık + gövde darbesi + alt bas + çınlama
                var hp = new BQ("hp", 3500); var bp = new BQ("bp", 5200, 2.5f); var th = new Osc(); var sub = new Osc(); var lp = new BQ("lp", 900);
                float[] ratios = { 1, 2.41f, 3.9f, 5.37f, 7.1f }, amps = { 0.45f, 0.32f, 0.22f, 0.14f, 0.08f }, taus = { 0.55f, 0.38f, 0.26f, 0.18f, 0.12f };
                var oscs = new Osc[5];
                for (int k = 0; k < 5; k++) oscs[k] = new Osc();
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    float v = hp.Run(z) * Mathf.Exp(-t / 0.006f) * 2.2f + bp.Run(z) * Mathf.Exp(-t / 0.03f) * 1.2f;
                    for (int k = 0; k < 5; k++) v += oscs[k].Run(880 * ratios[k]) * amps[k] * Mathf.Exp(-t / taus[k]);
                    v += th.Run(55 + 260 * Mathf.Exp(-t / 0.02f)) * Mathf.Exp(-t / 0.16f) * 1.6f;
                    v += sub.Run(32 + 30 * Mathf.Exp(-t / 0.08f)) * Mathf.Exp(-t / 0.45f) * 1.4f;
                    v += lp.Run(z) * Mathf.Exp(-t / 0.09f) * 0.9f;
                    o[i] = Sat(v * 1.5f);
                }
            });
            Def("dash", 0.4f, 0.4f, (o, n) =>
            {
                var bp = new BQ("bp", 600, 2.2f); var th = new Osc();
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    bp.Set(500 + 5000 * Mathf.Pow(t / 0.4f, 0.6f));
                    float env = Mathf.Pow(Mathf.Sin(Mathf.PI * Mathf.Min(1, t / 0.4f)), 0.8f);
                    o[i] = bp.Run(z) * 1.5f * env + th.Run(70 * Mathf.Exp(-t / 0.05f) + 40) * Mathf.Exp(-t / 0.06f) * 0.8f;
                }
            });
            Def("jump", 0.18f, 0.25f, (o, n) => { var bp = new BQ("bp", 700, 2); for (int i = 0; i < n; i++) { float t = (float)i / SR; bp.Set(600 + 1800 * (t / 0.18f)); o[i] = bp.Run(Rnd()) * Mathf.Exp(-t / 0.06f) * 1.2f; } });
            Def("walljump", 0.3f, 0.35f, (o, n) => { var bp = new BQ("bp", 2400, 3); var bp2 = new BQ("bp", 900, 1.5f); for (int i = 0; i < n; i++) { float t = (float)i / SR, z = Rnd(); o[i] = bp.Run(z) * Mathf.Exp(-t / 0.02f) * 1.5f + bp2.Run(z) * Mathf.Exp(-t / 0.09f) * 0.8f; } });
            Def("land", 0.25f, 0.35f, (o, n) => { var lp = new BQ("lp", 500); var th = new Osc(); for (int i = 0; i < n; i++) { float t = (float)i / SR, z = Rnd(); o[i] = lp.Run(z) * Mathf.Exp(-t / 0.05f) * 1.3f + th.Run(60 + 60 * Mathf.Exp(-t / 0.02f)) * Mathf.Exp(-t / 0.06f); } });
            Def("step", 0.12f, 0.14f, (o, n) => { var bp = new BQ("bp", 1500, 5); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = bp.Run(Rnd()) * Mathf.Exp(-t / 0.012f) * 2.2f; } });
            Def("slide", 1.0f, 0.18f, (o, n) =>
            {
                var bp = new BQ("bp", 900, 1.2f); var bp2 = new BQ("bp", 3200, 2);
                for (int i = 0; i < n; i++) { float t = (float)i / SR, z = Rnd(); float m = 0.75f + 0.25f * Mathf.Sin(TAU * 7 * t) * Mathf.Sin(TAU * 3 * t); o[i] = (bp.Run(z) * 0.9f + bp2.Run(z) * 0.4f) * m; }
                int f = SR / 50; for (int i = 0; i < f; i++) { float k = (float)i / f; o[i] *= k; o[n - 1 - i] *= k; }
            });
            Def("slam", 1.1f, 0.8f, (o, n) =>
            {
                var lp = new BQ("lp", 2000); var th = new Osc(); var lp2 = new BQ("lp", 150);
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    lp.Set(100 + 3000 * Mathf.Exp(-t / 0.08f));
                    float v = lp.Run(z) * Mathf.Exp(-t / 0.25f) * 1.6f + th.Run(28 + 90 * Mathf.Exp(-t / 0.05f)) * Mathf.Exp(-t / 0.3f) * 1.8f + lp2.Run(z) * Mathf.Exp(-t / 0.5f) * 1.5f;
                    o[i] = Sat(v * 1.8f);
                }
            });
            Def("hurt", 0.45f, 0.6f, (o, n) =>
            {
                var lp = new BQ("lp", 1200); var s = new Osc(1); var hp = new BQ("hp", 2000); float hold = 0;
                for (int i = 0; i < n; i++) { float t = (float)i / SR, z = Rnd(); if (i % 40 == 0) hold = Rnd(); o[i] = Sat((lp.Run(z) * 1.2f + s.Run(140 - 80 * t) * 0.5f + hp.Run(hold) * 0.6f) * Mathf.Exp(-t / 0.12f) * 2.5f); }
            });
            Def("heal", 0.2f, 0.12f, (o, n) => { var a = new Osc(); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = a.Run(700 + 900 * t) * Mathf.Exp(-t / 0.05f) * 0.4f; } });
            Def("enemyHit", 0.3f, 0.45f, (o, n) =>
            {
                var bp = new BQ("bp", 500, 1.5f); var lp = new BQ("lp", 600);
                for (int i = 0; i < n; i++) { float t = (float)i / SR, z = Rnd(); bp.Set(450 * (1 + 1.5f * Mathf.Exp(-t / 0.03f))); o[i] = (bp.Run(z) * 1.4f + lp.Run(z) * 0.8f) * Mathf.Exp(-t / 0.07f); }
            });
            Def("hitTick", 0.09f, 0.16f, (o, n) => { var hp = new BQ("hp", 2500); var a = new Osc(3); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = hp.Run(Rnd()) * Mathf.Exp(-t / 0.004f) * 1.6f + a.Run(1900) * Mathf.Exp(-t / 0.025f) * 0.5f; } });
            Def("headshot", 0.45f, 0.6f, (o, n) =>
            {
                var a = new Osc(); var b = new Osc(); var hp = new BQ("hp", 3000); var lp = new BQ("lp", 900);
                for (int i = 0; i < n; i++) { float t = (float)i / SR, z = Rnd(); o[i] = (a.Run(1800) * 0.4f + b.Run(2700) * 0.25f) * Mathf.Exp(-t / 0.12f) + hp.Run(z) * Mathf.Exp(-t / 0.01f) + lp.Run(z) * Mathf.Exp(-t / 0.08f) * 1.2f; }
            });
            Def("gore", 1.0f, 0.75f, (o, n) =>
            {
                var lp = new BQ("lp", 800); var bp = new BQ("bp", 300, 1.2f); var th = new Osc();
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    float wob = 0.6f + 0.4f * Mathf.Sin(TAU * 23 * t) * Mathf.Sin(TAU * 7 * t);
                    o[i] = Sat((lp.Run(z) * 1.4f * wob + bp.Run(z) * 0.9f + th.Run(50 + 50 * Mathf.Exp(-t / 0.05f)) * 0.8f) * Mathf.Exp(-t / 0.22f) * 1.8f);
                }
            });
            Def("orbCharge", 0.6f, 0.22f, (o, n) => { var a = new Osc(); var b = new Osc(1); for (int i = 0; i < n; i++) { float t = (float)i / SR; float f = 200 + 700 * t; o[i] = (a.Run(f) * 0.6f + b.Run(f * 0.5f) * 0.2f) * Mathf.Min(1, t / 0.1f); } });
            Def("orbThrow", 0.45f, 0.4f, (o, n) => { var bp = new BQ("bp", 800, 1.2f); var a = new Osc(); for (int i = 0; i < n; i++) { float t = (float)i / SR; bp.Set(1600 - 1200 * (t / 0.45f)); o[i] = (bp.Run(Rnd()) * 1.4f + a.Run(300 - 200 * t) * 0.4f) * Mathf.Exp(-t / 0.15f); } });
            Def("projHit", 0.4f, 0.4f, (o, n) => { var lp = new BQ("lp", 2000); var a = new Osc(); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = (lp.Run(Rnd()) * 1.2f + a.Run(200 * Mathf.Exp(-t / 0.05f) + 60) * 0.8f) * Mathf.Exp(-t / 0.08f); } });
            Def("glint", 0.7f, 0.45f, (o, n) => { var a = new Osc(); var b = new Osc(); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = (a.Run(2800 + 900 * t) * 0.5f + b.Run(4200) * 0.3f) * Mathf.Exp(-t / 0.18f) * Mathf.Min(1, t / 0.005f); } });
            Def("windup", 0.6f, 0.3f, (o, n) => { var bp = new BQ("bp", 400, 3); for (int i = 0; i < n; i++) { float t = (float)i / SR; bp.Set(300 + 2500 * t); o[i] = bp.Run(Rnd()) * Mathf.Min(1, t / 0.3f) * 1.6f; } });
            Def("swing", 0.45f, 0.6f, (o, n) => { var bp = new BQ("bp", 300, 1.8f); for (int i = 0; i < n; i++) { float t = (float)i / SR; float e = Mathf.Sin(Mathf.PI * Mathf.Min(1, t / 0.45f)); bp.Set(300 + 2400 * e); o[i] = bp.Run(Rnd()) * 1.6f * e; } });
            Def("bossRoar", 1.8f, 0.8f, (o, n) =>
            {
                var s = new Osc(1); var s2 = new Osc(2); var lp = new BQ("lp", 900); var bp = new BQ("bp", 700, 2);
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    float f = 70 + 30 * Mathf.Sin(TAU * 3 * t);
                    o[i] = Sat((lp.Run(s.Run(f) + s2.Run(f * 1.5f) * 0.4f) * 1.3f + bp.Run(z) * 0.6f) * Mathf.Min(1, t / 0.1f) * Mathf.Exp(-t / 1.0f) * 2);
                }
            });
            Def("bossDeath", 2.4f, 0.95f, (o, n) =>
            {
                var s = new Osc(1); var s2 = new Osc(2); var lp = new BQ("lp", 1500); var bp = new BQ("bp", 1800, 6); var th = new Osc(); var lp2 = new BQ("lp", 120);
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    float f = 180 * Mathf.Exp(-t / 0.9f) + 35;
                    lp.Set(200 + 2500 * Mathf.Exp(-t / 0.7f));
                    float v = lp.Run(s.Run(f) + s2.Run(f * 1.5f) * 0.4f) * 1.2f + bp.Run(z) * (0.6f + 0.4f * Mathf.Sin(TAU * 13 * t)) * Mathf.Exp(-t / 0.5f) * 0.7f;
                    v += th.Run(28 + 60 * Mathf.Exp(-t / 0.1f)) * Mathf.Exp(-t / 0.8f) * 1.5f + lp2.Run(z) * Mathf.Exp(-t / 1.2f) * 2;
                    o[i] = Sat(v * 1.7f) * Mathf.Min(1, t / 0.01f);
                }
            });
            Def("skullScream", 1.9f, 0.75f, (o, n) =>
            {
                var s1 = new Osc(1); var s2 = new Osc(1); var s3 = new Osc(2);
                var f1 = new BQ("bp", 820, 4); var f2 = new BQ("bp", 1250, 5); var f3 = new BQ("bp", 2700, 6); var nb = new BQ("bp", 3200, 1.5f); var lp = new BQ("lp", 6000);
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    float glide = t < 0.12f ? 380 + 900 * (t / 0.12f) : 1280 * Mathf.Exp(-(t - 0.12f) / 1.4f) + 260;
                    float f = glide * (1 + 0.05f * Mathf.Sin(TAU * 7.5f * t) + 0.02f * Mathf.Sin(TAU * 31 * t));
                    float src = s1.Run(f) + s2.Run(f * 1.012f) * 0.8f + s3.Run(f * 0.5f) * 0.35f + z * 0.35f;
                    float v = f1.Run(src) * 1.2f + f2.Run(src) * 0.9f + f3.Run(src) * 0.6f + nb.Run(z) * 0.5f;
                    float env = Mathf.Min(1, t / 0.025f) * (t < 1.2f ? 1 : Mathf.Exp(-(t - 1.2f) / 0.22f));
                    o[i] = lp.Run(Sat(v * 3.2f)) * env;
                }
            });
            Def("death", 2.6f, 0.7f, (o, n) =>
            {
                var a = new Osc(1); var lp = new BQ("lp", 2000); var th = new Osc();
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR;
                    lp.Set(100 + 2500 * Mathf.Exp(-t / 0.6f));
                    o[i] = Sat((lp.Run(a.Run(320 * Mathf.Exp(-t / 0.7f) + 25)) * Mathf.Exp(-t / 1.2f) * 1.2f + th.Run(30 + 80 * Mathf.Exp(-t / 0.05f)) * Mathf.Exp(-t / 0.4f) * 1.5f) * 1.8f);
                }
            });
            Def("beep", 0.12f, 0.2f, (o, n) => { var a = new Osc(2); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = a.Run(880) * (t < 0.1f ? 1 : 0) * 0.5f; } });
            Def("door", 1.4f, 0.5f, (o, n) => { var lp = new BQ("lp", 300); var bp = new BQ("bp", 120, 2); for (int i = 0; i < n; i++) { float t = (float)i / SR, z = Rnd(); o[i] = (lp.Run(z) * 1.5f + bp.Run(z)) * Mathf.Min(1, t / 0.1f) * (t < 1.1f ? 1 : Mathf.Exp(-(t - 1.1f) / 0.05f)); } });
            Def("checkpoint", 0.5f, 0.3f, (o, n) => { var a = new Osc(); var b = new Osc(); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = (a.Run(t < 0.12f ? 660 : 990) * 0.5f + b.Run(t < 0.12f ? 1320 : 1980) * 0.2f) * Mathf.Exp(-(t % 0.12f) / 0.1f); } });
            Def("secret", 1.2f, 0.35f, (o, n) => { var a = new Osc(); var b = new Osc(3); for (int i = 0; i < n; i++) { float t = (float)i / SR; float f = 523 * Mathf.Pow(1.5f, Mathf.Floor(t / 0.15f) % 4); o[i] = (a.Run(f) * 0.5f + b.Run(f * 2) * 0.2f) * Mathf.Exp(-(t % 0.15f) / 0.12f) * Mathf.Exp(-t / 0.8f); } });
            Def("rankUp", 0.3f, 0.2f, (o, n) => { var a = new Osc(3); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = a.Run(600 + 1200 * t) * Mathf.Exp(-t / 0.1f); } });
            Def("meleeWhoosh", 0.32f, 0.35f, (o, n) => { var bp = new BQ("bp", 300, 1.8f); for (int i = 0; i < n; i++) { float t = (float)i / SR; float e = Mathf.Sin(Mathf.PI * Mathf.Min(1, t / 0.32f)); bp.Set(300 + 2400 * e); o[i] = bp.Run(Rnd()) * 1.6f * e; } });
            Def("lava", 0.5f, 0.45f, (o, n) => { var hp = new BQ("hp", 3000); var lp = new BQ("lp", 600); for (int i = 0; i < n; i++) { float t = (float)i / SR, z = Rnd(); o[i] = (hp.Run(z) * (UnityEngine.Random.value < 0.15f ? 1.5f : 0.3f) + lp.Run(z) * 1.2f) * Mathf.Exp(-t / 0.18f); } });
        }
    
        // Tam cephanelik ve yeni düşmanlar için ek sesler (web sürümündeki DSP tarifleri)
        void Build2()
        {
            Def("coin", 0.35f, 0.35f, (o, n) =>
            {
                var a = new Osc(); var b = new Osc(); var hp = new BQ("hp", 5000);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; float trem = 0.6f + 0.4f * Mathf.Sin(TAU * 38 * t); o[i] = (a.Run(2400 + 800 * t) * 0.6f + b.Run(3800) * 0.25f) * Mathf.Exp(-t / 0.12f) * trem + hp.Run(Rnd()) * Mathf.Exp(-t / 0.01f) * 0.5f; }
            });
            Def("ricochet", 0.9f, 0.5f, (o, n) =>
            {
                var a = new Osc(); var b = new Osc(); var c = new Osc(); var hp = new BQ("hp", 4000);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; float f = 3300 - 900 * (1 - Mathf.Exp(-t / 0.3f)); o[i] = (a.Run(f) * 0.55f + b.Run(f * 1.46f) * 0.3f + c.Run(f * 2.1f) * 0.12f) * Mathf.Exp(-t / 0.28f) + hp.Run(Rnd()) * Mathf.Exp(-t / 0.008f) * 0.8f; }
            });
            Def("shell", 0.25f, 0.12f, (o, n) => { var a = new Osc(); var b = new Osc(); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = (a.Run(3900) * 0.5f + b.Run(6200) * 0.3f) * Mathf.Exp(-t / 0.05f); } });
            Def("overpump", 0.8f, 0.35f, (o, n) =>
            {
                var s = new Osc(1); var lp = new BQ("lp", 900, 4);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; lp.Set(300 + 3000 * (t / 0.8f)); o[i] = Sat(lp.Run(s.Run(80 + 360 * (t / 0.8f) + 20 * Mathf.Sin(TAU * 12 * t))) * 3) * Mathf.Min(1, t / 0.05f) * Mathf.Exp(-Mathf.Max(0, t - 0.6f) / 0.08f); }
            });
            Def("coreLaunch", 0.45f, 0.5f, (o, n) =>
            {
                var th = new Osc(); var lp = new BQ("lp", 1400, 0.8f);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = Sat((th.Run(70 + 220 * Mathf.Exp(-t / 0.05f)) * Mathf.Exp(-t / 0.12f) * 1.2f + lp.Run(Rnd()) * Mathf.Exp(-t / 0.08f)) * 1.4f); }
            });
            Def("rail", 1.6f, 0.85f, (o, n) =>
            {
                var sq = new Osc(2); var th = new Osc(); var lp = new BQ("lp", 9000); var hp = new BQ("hp", 3000); var s2 = new Osc(1);
                float gate = 1;
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, z = Rnd();
                    if (i % 220 == 0) gate = Rnd() > -0.2f ? 1 : 0.2f;
                    lp.Set(200 + 9000 * Mathf.Exp(-t / 0.25f));
                    float v = sq.Run(1900 * Mathf.Exp(-t / 0.12f) + 55) * Mathf.Exp(-t / 0.35f) * 0.7f;
                    v += lp.Run(z) * Mathf.Exp(-t / 0.3f) * 1.4f;
                    v += th.Run(20 + 80 * Mathf.Exp(-t / 0.08f)) * Mathf.Exp(-t / 0.7f) * 1.8f;
                    v += hp.Run(z) * gate * Mathf.Exp(-t / 0.6f) * 0.6f;
                    v += s2.Run(4200 - 1500 * t) * Mathf.Exp(-t / 0.15f) * 0.12f;
                    o[i] = Sat(v * 2.2f);
                }
            });
            Def("railReady", 0.7f, 0.3f, (o, n) =>
            {
                var a = new Osc(); var b = new Osc(3);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; float f = t < 0.12f ? 660 : t < 0.24f ? 990 : 1320; o[i] = (a.Run(f) * 0.6f + b.Run(f * 2) * 0.2f) * Mathf.Exp(-((t % 0.12f) / 0.08f)) * (t < 0.5f ? 1 : Mathf.Exp(-(t - 0.5f) / 0.05f)); }
            });
            Def("chargeLoop", 0.6f, 0.25f, (o, n) =>
            {
                var a = new Osc(); var b = new Osc(1); var lp = new BQ("lp", 1800, 2);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; float f = 300 + (t / 0.6f) * 900; o[i] = (a.Run(f * (1 + 0.02f * Mathf.Sin(TAU * 30 * t))) * 0.6f + lp.Run(b.Run(f * 0.5f)) * 0.3f) * Mathf.Min(1, t / 0.05f) * 0.8f; }
            });
            Def("parryRing", 2.0f, 0.3f, (o, n) =>
            {
                var a = new Osc(); var b = new Osc(); var c = new Osc(3); var hp = new BQ("hp", 6000);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; float env = Mathf.Min(1, t / 0.02f) * Mathf.Exp(-t / 0.7f); float f = 1320 + 220 * (1 - Mathf.Exp(-t / 0.4f)); o[i] = (a.Run(f) * 0.4f + b.Run(f * 1.5f) * 0.25f + c.Run(f * 2.01f) * 0.15f) * env * (0.8f + 0.2f * Mathf.Sin(TAU * 11 * t)) + hp.Run(Rnd()) * Mathf.Exp(-t / 0.25f) * 0.12f; }
            });
            Def("slamStart", 0.4f, 0.35f, (o, n) =>
            {
                var bp = new BQ("bp", 3000, 1.2f);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; bp.Set(3000 - 2500 * (t / 0.4f)); o[i] = bp.Run(Rnd()) * Mathf.Min(1, t / 0.05f) * 1.3f; }
            });
            Def("filthGrowl", 0.7f, 0.35f, (o, n) =>
            {
                var s = new Osc(1); var f1 = new BQ("bp", 520, 4); var f2 = new BQ("bp", 1400, 5);
                float f0 = 85 + (Rnd() * 0.5f + 0.5f) * 30;
                for (int i = 0; i < n; i++) { float t = (float)i / SR; float x = s.Run(f0 * (1 + 0.06f * Mathf.Sin(TAU * 13 * t)) * (1 - 0.3f * t)) + Rnd() * 0.3f; o[i] = Sat((f1.Run(x) * 1.5f + f2.Run(x)) * 3) * Mathf.Min(1, t / 0.05f) * Mathf.Exp(-t / 0.3f); }
            });
            Def("screech", 0.6f, 0.35f, (o, n) =>
            {
                var s = new Osc(1); var f1 = new BQ("bp", 900, 5); var f2 = new BQ("bp", 2400, 6);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; float x = s.Run(260 - 120 * t + 20 * Mathf.Sin(TAU * 25 * t)) + Rnd() * 0.4f; o[i] = Sat((f1.Run(x) + f2.Run(x) * 0.8f) * 4) * Mathf.Min(1, t / 0.03f) * Mathf.Exp(-t / 0.22f); }
            });
            Def("schismShot", 0.25f, 0.3f, (o, n) =>
            {
                var s = new Osc(2); var lp = new BQ("lp", 2500); var bp = new BQ("bp", 1600, 3);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = lp.Run(s.Run(1200 * Mathf.Exp(-t / 0.05f) + 200)) * Mathf.Exp(-t / 0.08f) * 0.6f + bp.Run(Rnd()) * Mathf.Exp(-t / 0.03f); }
            });
            Def("chainsaw", 0.8f, 0.4f, (o, n) =>
            {
                var s = new Osc(1); var s2 = new Osc(2); var bp = new BQ("bp", 1200, 1);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; float f = 55 + 40 * Mathf.Min(1, t / 0.2f); float am = 0.6f + 0.4f * Mathf.Sign(Mathf.Sin(TAU * 28 * t)); o[i] = Sat((s.Run(f) + s2.Run(f * 1.01f) * 0.5f + bp.Run(Rnd()) * 0.4f) * am * 2.5f) * Mathf.Min(1, t / 0.03f) * Mathf.Exp(-Mathf.Max(0, t - 0.5f) / 0.1f); }
            });
            Def("spawn", 0.9f, 0.35f, (o, n) =>
            {
                var a = new Osc(); var b = new Osc(); var bp = new BQ("bp", 3000, 2);
                for (int i = 0; i < n; i++) { float t = (float)i / SR; float env = t < 0.6f ? (t / 0.6f) * (t / 0.6f) : Mathf.Exp(-(t - 0.6f) / 0.06f); o[i] = (a.Run(220 + 900 * t) * 0.3f + b.Run(1650 + 1200 * t) * 0.15f + bp.Run(Rnd()) * 0.8f) * env; }
            });
            Def("doorSlam", 0.9f, 0.7f, (o, n) =>
            {
                var lp = new BQ("lp", 900); var th = new Osc(); var a = new Osc(); var b = new Osc();
                for (int i = 0; i < n; i++) { float t = (float)i / SR, z = Rnd(); o[i] = Sat((lp.Run(z) * Mathf.Exp(-t / 0.08f) * 1.8f + th.Run(35 + 60 * Mathf.Exp(-t / 0.05f)) * Mathf.Exp(-t / 0.2f) * 1.6f + (a.Run(420) + b.Run(1170) * 0.6f) * Mathf.Exp(-t / 0.25f) * 0.25f) * 1.6f); }
            });
            Def("pickup", 1.6f, 0.55f, (o, n) =>
            {
                float[] notes = { 262, 330, 392, 523, 659 };
                var oscs = new Osc[notes.Length];
                for (int k = 0; k < notes.Length; k++) oscs[k] = new Osc(1);
                var lp = new BQ("lp", 1500, 1.5f); var bp = new BQ("bp", 2500, 4);
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR, v = 0;
                    for (int k = 0; k < notes.Length; k++) v += oscs[k].Run(notes[k] * (1 + 0.003f * Mathf.Sin(TAU * 5 * t + k))) * 0.2f;
                    lp.Set(400 + 3000 * Mathf.Min(1, t / 0.4f));
                    v = lp.Run(v) * Mathf.Min(1, t / 0.05f) * Mathf.Exp(-Mathf.Max(0, t - 0.6f) / 0.35f);
                    if (t < 0.05f) v += bp.Run(Rnd()) * Mathf.Exp(-t / 0.008f) * 2;
                    if (t > 0.18f && t < 0.25f) v += bp.Run(Rnd()) * Mathf.Exp(-(t - 0.18f) / 0.008f) * 2;
                    o[i] = Sat(v * 1.5f);
                }
            });
            Def("uiClick", 0.12f, 0.22f, (o, n) => { var a = new Osc(2); var lp = new BQ("lp", 3500); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = lp.Run(a.Run(600 + 600 * (t / 0.12f))) * Mathf.Exp(-t / 0.035f) * 0.6f; } });
            Def("flame", 0.6f, 0.3f, (o, n) =>
            {
                var lp = new BQ("lp", 700); var bp = new BQ("bp", 2200, 0.7f);
                for (int i = 0; i < n; i++) { float z = Rnd(); o[i] = lp.Run(z) * 1.6f + bp.Run(z) * (Rnd() > 0.96f ? 2.2f : 0.35f); }
                int f = SR / 50;
                for (int i = 0; i < f; i++) { float k = (float)i / f; o[i] *= k; o[n - 1 - i] *= k; }
            });
            Def("magnet", 0.3f, 0.3f, (o, n) => { var a = new Osc(3); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = a.Run(900 - 500 * t) * Mathf.Exp(-t / 0.08f) * (0.6f + 0.4f * Mathf.Sin(TAU * 60 * t)); } });
            // ölüm: dijital bozulma (parçalı kare dalga + kırpılmış gürültü)
            Def("glitch", 0.7f, 0.45f, (o, n) =>
            {
                var sq = new Osc(2); float f = 300, hold = 0;
                for (int i = 0; i < n; i++)
                {
                    float t = (float)i / SR;
                    if (--hold <= 0) { hold = SR * (0.015f + (float)rng.NextDouble() * 0.05f); f = 120 + (float)rng.NextDouble() * 1400; }
                    float z = Mathf.Round(Rnd() * 4) / 4;
                    o[i] = (sq.Run(f) * 0.6f + z * 0.5f) * Mathf.Exp(-t / 0.28f) * (Mathf.Sin(TAU * 23 * t) > -0.3f ? 1 : 0.1f);
                }
            });
            Def("freeze", 0.5f, 0.3f, (o, n) => { var a = new Osc(); var b = new Osc(); for (int i = 0; i < n; i++) { float t = (float)i / SR; o[i] = (a.Run(1200 - 700 * t) * 0.5f + b.Run(1800 - 900 * t) * 0.3f) * Mathf.Exp(-t / 0.15f); } });
        }
    }
}
