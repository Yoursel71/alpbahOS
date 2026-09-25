// Prosedürel müzik (web: music.js): sakin (keşif) ve savaş katmanları arasında geçen breakcore /
// endüstriyel döngü. Davullar başlangıçta DSP ile örneklenir; bas, distorsiyonlu gitar, koro pad'i,
// alt bas ve lead ses iş parçacığında (OnAudioFilterRead) gerçek zamanlı sentezlenir.
// Stil rütbesi yükseldikçe gitar ve lead katmanları açılır; boss'ta ayrı akor dizisi ve hız.
// Duraklatma / dükkân / ölüm: alçak geçiren süzgeçle boğuklaşır.
using System;
using UnityEngine;

namespace UK
{
    public class UKMusic : MonoBehaviour
    {
        public float volume = 0.6f;
        volatile int mode, styleRank;
        volatile bool muffled;
        int sr = 48000;
        const float TAU = Mathf.PI * 2;

        // ------------------------------------------------------------ DSP
        class BQ
        {
            float b0, b1, b2, a1, a2, x1, x2, y1, y2;
            readonly int sr; readonly string type; readonly float q, gainDb;
            public BQ(int sr, string type, float f, float q = 0.707f, float gainDb = 0) { this.sr = sr; this.type = type; this.q = q; this.gainDb = gainDb; Set(f); }
            public void Set(float f)
            {
                f = Mathf.Clamp(f, 20f, sr * 0.45f);
                float w = TAU * f / sr, cs = Mathf.Cos(w), sn = Mathf.Sin(w), al = sn / (2 * q);
                float a0, _a1, _a2, _b0, _b1, _b2;
                if (type == "peak")
                {
                    float A = Mathf.Pow(10, gainDb / 40);
                    _b0 = 1 + al * A; _b1 = -2 * cs; _b2 = 1 - al * A; a0 = 1 + al / A; _a1 = -2 * cs; _a2 = 1 - al / A;
                }
                else
                {
                    a0 = 1 + al; _a1 = -2 * cs; _a2 = 1 - al;
                    if (type == "lp") { _b0 = (1 - cs) / 2; _b1 = 1 - cs; _b2 = (1 - cs) / 2; }
                    else if (type == "hp") { _b0 = (1 + cs) / 2; _b1 = -(1 + cs); _b2 = (1 + cs) / 2; }
                    else { _b0 = al; _b1 = 0; _b2 = -al; }
                }
                b0 = _b0 / a0; b1 = _b1 / a0; b2 = _b2 / a0; a1 = _a1 / a0; a2 = _a2 / a0;
            }
            public float Run(float x)
            {
                float y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
                x2 = x1; x1 = x; y2 = y1; y1 = y;
                if (float.IsNaN(y) || y > 1e6f || y < -1e6f) { x1 = x2 = y1 = y2 = 0; return 0; }
                return y;
            }
        }

        static float Midi(float n) => 440f * Mathf.Pow(2, (n - 69) / 12f);
        static float Cents(float c) => Mathf.Pow(2, c / 1200f);
        readonly System.Random rng = new System.Random(3);
        float Rnd() => (float)(rng.NextDouble() * 2 - 1);
        static float Sat(float x) => (float)Math.Tanh(x);

        // ------------------------------------------------------------ davul örnekleri
        float[] kick, snare, hat, ohat, crash;

        float[] Mk(float dur, Func<float, float> gen)
        {
            int n = Mathf.CeilToInt(dur * sr);
            var o = new float[n];
            for (int i = 0; i < n; i++) o[i] = gen(i / (float)sr);
            return o;
        }

        void BuildDrums()
        {
            {
                double ph = 0; var hp = new BQ(sr, "hp", 2000);
                kick = Mk(0.45f, t => { ph += (45 + 140 * Math.Exp(-t / 0.035)) / sr; return Sat((Mathf.Sin(TAU * (float)(ph % 1)) * Mathf.Exp(-t / 0.2f) * 1.4f + hp.Run(Rnd()) * Mathf.Exp(-t / 0.004f) * 0.8f) * 1.8f); });
            }
            {
                double ph = 0; var bp = new BQ(sr, "bp", 2200, 0.7f); var hp = new BQ(sr, "hp", 800);
                snare = Mk(0.35f, t =>
                {
                    float z = Rnd();
                    ph += 180 * (1 + 0.6 * Math.Exp(-t / 0.01)) / sr;
                    float tri = 4 * Mathf.Abs((float)(ph % 1) - 0.5f) - 1;
                    return Sat((bp.Run(z) * Mathf.Exp(-t / 0.09f) * 1.4f + hp.Run(z) * Mathf.Exp(-t / 0.13f) * 0.6f + tri * Mathf.Exp(-t / 0.05f) * 0.9f) * 1.6f);
                });
            }
            {
                var hp = new BQ(sr, "hp", 8000); var bp = new BQ(sr, "bp", 10000, 2);
                hat = Mk(0.06f, t => { float z = Rnd(); return (hp.Run(z) + bp.Run(z)) * Mathf.Exp(-t / 0.012f); });
            }
            {
                var hp = new BQ(sr, "hp", 7000); var bp = new BQ(sr, "bp", 9000, 2);
                ohat = Mk(0.3f, t => { float z = Rnd(); return (hp.Run(z) + bp.Run(z)) * Mathf.Exp(-t / 0.09f); });
            }
            {
                var hp = new BQ(sr, "hp", 4000); var bp = new BQ(sr, "bp", 6000, 1);
                crash = Mk(1.6f, t => { float z = Rnd(); return (hp.Run(z) * 0.8f + bp.Run(z) * 0.6f) * Mathf.Exp(-t / 0.45f); });
            }
        }

        // ------------------------------------------------------------ sesler
        enum VK { Drum, Bass, Guitar, Sub, Lead, Pad }
        const int DRUMS = 0, BASS = 1, PAD = 2, LEAD = 3, BEAT = 4, GTR = 5, NB = 6;

        class Voice
        {
            public bool on;
            public VK kind;
            public int bus, len, t, delay;
            public float[] buf;
            public double pos, rate;
            public float gain, dur, f0;
            public readonly double[] ph = new double[9];
            public readonly float[] fr = new float[9];
            public int nOsc;
            public BQ f1, f2;
        }

        readonly Voice[] voices = new Voice[96];
        readonly float[] busGain = new float[NB], busTarget = new float[NB], busTc = new float[NB];
        readonly float[] bus = new float[NB];
        float[] delayBuf;
        int delayPos;
        float[] verbA, verbB;
        int verbPosA, verbPosB;
        BQ gtrHp, gtrMid, gtrLp, muffleL, muffleR;
        float muffleF = 20000;

        // sıralayıcı (ses iş parçacığı)
        int step, sampleInStep, prevMode = -1, kickVar, snareVar;
        bool crashNext;

        static readonly int[][] KICKS =
        {
            new[] { 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0 },
            new[] { 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0 },
            new[] { 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0 },
        };
        static readonly int[][] SNARES =
        {
            new[] { 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0 },
            new[] { 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0 },
            new[] { 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1 },
        };
        static readonly int[] BASS_GATE = { 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1 };
        static readonly int[] GTR_GATE = { 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0 };
        static readonly int[] MAIN_ROOTS = { 38, 34, 41, 36 }, BOSS_ROOTS = { 40, 41, 40, 38 };
        static readonly int[][] MAIN_CHORDS = { new[] { 50, 53, 57 }, new[] { 46, 50, 53 }, new[] { 53, 57, 60 }, new[] { 48, 52, 55 } };
        static readonly int[][] BOSS_CHORDS = { new[] { 52, 55, 59 }, new[] { 53, 57, 60 }, new[] { 52, 55, 59 }, new[] { 50, 53, 57 } };
        static readonly int[] ARP = { 0, 1, 2, 1, 2, 0, 2, 1 };
        // katman kazançları: davul, bas, pad, lead, nabız, gitar (kapalı / menü / sakin / savaş / boss)
        static readonly float[][] MIX =
        {
            new float[NB],
            new[] { 0f, 0f, 0.4f, 0f, 0.55f, 0f },
            new[] { 0f, 0f, 0.42f, 0f, 0.5f, 0f },
            new[] { 0.8f, 0.55f, 0.18f, 0f, 0f, 0f },
            new[] { 0.9f, 0.6f, 0.16f, 0.3f, 0f, 0.32f },
        };

        void Awake()
        {
            sr = AudioSettings.outputSampleRate > 0 ? AudioSettings.outputSampleRate : 48000;
            for (int i = 0; i < voices.Length; i++) voices[i] = new Voice();
            BuildDrums();
            delayBuf = new float[Mathf.CeilToInt(sr * 0.265f)];
            verbA = new float[Mathf.CeilToInt(sr * 0.0413f)];
            verbB = new float[Mathf.CeilToInt(sr * 0.0571f)];
            gtrHp = new BQ(sr, "hp", 90); gtrMid = new BQ(sr, "peak", 800, 0.7f, -5); gtrLp = new BQ(sr, "lp", 3200, 0.9f);
            muffleL = new BQ(sr, "lp", 20000); muffleR = new BQ(sr, "lp", 20000);
            var src = gameObject.AddComponent<AudioSource>();
            src.playOnAwake = false;
            src.loop = true;
            src.spatialBlend = 0;
            src.clip = AudioClip.Create("ukmusic", sr, 1, sr, false);
            src.clip.SetData(new float[sr], 0);
            src.Play();
        }

        public void SetMode(string m)
        {
            int v = m == "menu" ? 1 : m == "calm" ? 2 : m == "combat" ? 3 : m == "boss" ? 4 : 0;
            mode = v;
        }

        public void SetStyleRank(int r) => styleRank = r;
        public void Muffle(bool on) => muffled = on;

        // ------------------------------------------------------------ ses iş parçacığı
        Voice Alloc()
        {
            foreach (var v in voices) if (!v.on) return v;
            return null;
        }

        void Hit(float[] b, int at, float vol, int dest, float rate = 1)
        {
            var v = Alloc(); if (v == null) return;
            v.on = true; v.kind = VK.Drum; v.buf = b; v.pos = 0; v.rate = rate; v.gain = vol; v.bus = dest; v.delay = at; v.t = 0;
            v.len = int.MaxValue;
        }

        void Tone(VK kind, int at, float dur, int bus_, float gain, params float[] freqs)
        {
            var v = Alloc(); if (v == null) return;
            v.on = true; v.kind = kind; v.delay = at; v.t = 0; v.bus = bus_; v.gain = gain; v.dur = dur;
            v.len = Mathf.CeilToInt((kind == VK.Pad ? dur * 1.1f : dur + 0.02f) * sr);
            v.nOsc = Mathf.Min(freqs.Length, 9);
            for (int i = 0; i < v.nOsc; i++) { v.fr[i] = freqs[i]; v.ph[i] = rng.NextDouble(); }
            v.f0 = freqs.Length > 0 ? freqs[0] : 100;
            if (kind == VK.Bass) v.f1 = new BQ(sr, "lp", 2200, 6);
            else if (kind == VK.Lead) v.f1 = new BQ(sr, "lp", 2600);
            else if (kind == VK.Pad) { v.f1 = new BQ(sr, "lp", 900, 0.6f); v.f2 = new BQ(sr, "peak", 700, 2, 6); }
            else v.f1 = null;
        }

        float StepDur(int m) => 60f / (m == 1 ? 84 : m == 4 ? 180 : 170) / 4f;

        void PlayStep(int stp, int m)
        {
            int s = stp % 16, bar = (stp / 16) % 4;
            bool boss = m == 4, combat = m == 3 || m == 4;
            int root = boss ? BOSS_ROOTS[bar] : MAIN_ROOTS[bar];
            var chord = boss ? BOSS_CHORDS[bar] : MAIN_CHORDS[bar];
            float sd = StepDur(m);
            if (s == 0)
            {
                kickVar = rng.Next(KICKS.Length);
                snareVar = rng.Next(SNARES.Length);
                var fq = new float[9];
                int k = 0;
                foreach (int n in chord) foreach (float det in new[] { -11f, 0f, 11f }) fq[k++] = Midi(n - 12) * Cents(det);
                Tone(VK.Pad, 0, sd * 16, PAD, 0.09f, fq);
                if (combat && (crashNext || bar == 0)) { Hit(crash, 0, 0.5f, DRUMS); crashNext = false; }
            }
            // sakin nabız (menü / keşif)
            if (s == 0 || s == 3 || (m == 2 && (s == 8 || s == 11))) Hit(kick, 0, 0.55f, BEAT, 0.8f);
            if (m == 2 && (s == 4 || s == 12)) Hit(ohat, 0, 0.08f, BEAT);
            if (s == 0 && bar % 2 == 0) Tone(VK.Sub, 0, sd * 32, BEAT, 0.25f, Midi(root - 12));
            if (!combat) return;
            // savaş davulları
            bool fill = bar == 3 && s >= 12;
            if (KICKS[kickVar][s] == 1) Hit(kick, 0, 1, DRUMS);
            if (fill)
            {
                Hit(snare, 0, 0.5f + (s - 12) * 0.14f, DRUMS, 1 + (s - 12) * 0.04f);
                Hit(snare, Mathf.RoundToInt(sd / 2 * sr), 0.4f + (s - 12) * 0.12f, DRUMS, 1.05f + (s - 12) * 0.04f);
            }
            else if (SNARES[snareVar][s] == 1) Hit(snare, 0, s == 4 || s == 12 ? 0.9f : 0.45f, DRUMS);
            if (s % 2 == 0) Hit(s % 8 == 6 ? ohat : hat, 0, s % 4 == 2 ? 0.3f : 0.18f, DRUMS);
            else if (rng.NextDouble() < 0.35) Hit(hat, 0, 0.09f, DRUMS);
            if (BASS_GATE[s] == 1)
            {
                float n = root + (s % 4 == 3 ? 12 : 0) + (s == 14 ? 7 : 0);
                Tone(VK.Bass, 0, sd * 0.9f, BASS, 0.28f, Midi(n), Midi(n) * 0.5f);
            }
            if (GTR_GATE[s] == 1)
            {
                bool acc = s % 8 == 0;
                Tone(VK.Guitar, 0, acc ? sd * 1.8f : sd * 0.7f, GTR, acc ? 0.22f : 0.16f,
                    Midi(root + 12) * Cents(-6), Midi(root + 12) * Cents(7), Midi(root + 19) * Cents(3), Midi(root + 24) * Cents(-4));
            }
            if (s % 2 == 0 || boss)
            {
                int note = chord[ARP[(stp >> (boss ? 0 : 1)) % ARP.Length]] + 12;
                Tone(VK.Lead, 0, sd * 0.8f, LEAD, 0.12f, Midi(note));
            }
        }

        void UpdateTargets(int m, int rank)
        {
            var v = MIX[Mathf.Clamp(m, 0, 4)];
            float tc = m == 3 || m == 4 ? 0.06f : 0.8f;
            for (int i = 0; i < NB; i++) { busTarget[i] = v[i]; busTc[i] = tc; }
            if (m == 3)
            {
                busTarget[GTR] = rank >= 2 ? 0.2f + (rank - 2) * 0.03f : 0;
                busTarget[LEAD] = rank >= 4 ? 0.16f + (rank - 4) * 0.04f : 0;
                busTc[GTR] = busTc[LEAD] = 0.3f;
            }
            if (m == 4) { busTarget[LEAD] = 0.28f + rank * 0.02f; busTarget[GTR] = 0.3f; busTc[GTR] = busTc[LEAD] = 0.3f; }
        }

        float VoiceSample(Voice v)
        {
            float t = v.t / (float)sr;
            switch (v.kind)
            {
                case VK.Drum:
                {
                    int i = (int)v.pos;
                    if (i + 1 >= v.buf.Length) { v.on = false; return 0; }
                    float fr = (float)(v.pos - i);
                    float x = v.buf[i] + (v.buf[i + 1] - v.buf[i]) * fr;
                    v.pos += v.rate;
                    return x * v.gain;
                }
                case VK.Bass:
                {
                    v.ph[0] += v.fr[0] / sr; v.ph[1] += v.fr[1] / sr;
                    float saw = 2 * (float)(v.ph[0] % 1) - 1, sq = (v.ph[1] % 1) < 0.5 ? 1 : -1;
                    float x = Sat((saw + sq) * 1.4f) * 0.8f;
                    if ((v.t & 31) == 0) v.f1.Set(2200 * Mathf.Pow(260f / 2200f, Mathf.Clamp01(t / v.dur)));
                    return v.f1.Run(x) * v.gain * Mathf.Pow(0.001f / v.gain, Mathf.Clamp01(t / v.dur));
                }
                case VK.Guitar:
                {
                    float x = 0;
                    for (int k = 0; k < v.nOsc; k++) { v.ph[k] += v.fr[k] / sr; x += 2 * (float)(v.ph[k] % 1) - 1; }
                    return x * v.gain * Mathf.Pow(0.001f / v.gain, Mathf.Clamp01(t / v.dur));
                }
                case VK.Sub:
                {
                    v.ph[0] += v.fr[0] / sr;
                    float env = t < 0.4f ? 0.0001f * Mathf.Pow(0.25f / 0.0001f, t / 0.4f) : 0.25f * Mathf.Pow(0.001f / 0.25f, Mathf.Clamp01((t - 0.4f) / Mathf.Max(0.01f, v.dur - 0.4f)));
                    return Mathf.Sin(TAU * (float)(v.ph[0] % 1)) * env;
                }
                case VK.Lead:
                {
                    v.ph[0] += v.fr[0] / sr;
                    float sq = (v.ph[0] % 1) < 0.5 ? 1 : -1;
                    return v.f1.Run(sq) * v.gain * Mathf.Pow(0.001f / v.gain, Mathf.Clamp01(t / v.dur));
                }
                case VK.Pad:
                {
                    float x = 0;
                    for (int k = 0; k < v.nOsc; k++) { v.ph[k] += v.fr[k] / sr; x += 2 * (float)(v.ph[k] % 1) - 1; }
                    float a = v.dur * 0.3f, e;
                    if (t < a) e = 0.0001f * Mathf.Pow(v.gain / 0.0001f, t / a);
                    else e = v.gain * Mathf.Pow(0.001f / v.gain, Mathf.Clamp01((t - a) / (v.dur * 0.75f)));
                    return v.f2.Run(v.f1.Run(x * 0.33f)) * e;
                }
            }
            return 0;
        }

        void OnAudioFilterRead(float[] data, int channels)
        {
            int m = mode, rank = styleRank;
            if (m != prevMode)
            {
                if ((m == 3 || m == 4) && prevMode != 3 && prevMode != 4) { crashNext = true; step = (step + 15) / 16 * 16; sampleInStep = 0; }
                prevMode = m;
            }
            UpdateTargets(m, rank);
            float vol = volume;
            float mf = muffled ? 650f : 20000f;
            int stepLen = Mathf.Max(1, Mathf.RoundToInt(StepDur(m) * sr));
            int frames = data.Length / channels;
            for (int f = 0; f < frames; f++)
            {
                if (sampleInStep <= 0)
                {
                    if (m != 0) PlayStep(step, m);
                    step++;
                    sampleInStep = stepLen;
                }
                sampleInStep--;
                for (int b = 0; b < NB; b++) bus[b] = 0;
                for (int i = 0; i < voices.Length; i++)
                {
                    var v = voices[i];
                    if (!v.on) continue;
                    if (v.delay > 0) { v.delay--; continue; }
                    if (v.t >= v.len) { v.on = false; continue; }
                    bus[v.bus] += VoiceSample(v);
                    v.t++;
                }
                // katman kazançları (yumuşak geçiş)
                for (int b = 0; b < NB; b++) busGain[b] += (busTarget[b] - busGain[b]) * (1f / (busTc[b] * sr + 1));
                float gtr = gtrLp.Run(gtrMid.Run(gtrHp.Run(Sat(bus[GTR] * 6f) * 0.5f)));
                // lead ekosu
                float dly = delayBuf[delayPos];
                delayBuf[delayPos] = bus[LEAD] + dly * 0.32f;
                delayPos = (delayPos + 1) % delayBuf.Length;
                float lead = (bus[LEAD] + dly) * busGain[LEAD];
                float pad = bus[PAD] * busGain[PAD], beat = bus[BEAT] * busGain[BEAT];
                float dry = bus[DRUMS] * busGain[DRUMS] + bus[BASS] * busGain[BASS] + pad + beat + lead + gtr * busGain[GTR];
                // basit yankı (iki tarak)
                float send = pad * 0.5f + lead * 0.3f + beat * 0.2f + bus[DRUMS] * busGain[DRUMS] * 0.08f;
                float ra = verbA[verbPosA], rb = verbB[verbPosB];
                verbA[verbPosA] = send + ra * 0.72f; verbPosA = (verbPosA + 1) % verbA.Length;
                verbB[verbPosB] = send + rb * 0.68f; verbPosB = (verbPosB + 1) % verbB.Length;
                float outL = dry + ra * 0.35f + rb * 0.15f, outR = dry + ra * 0.15f + rb * 0.35f;
                if ((f & 63) == 0)
                {
                    muffleF += (mf - muffleF) * 0.08f;
                    muffleL.Set(muffleF); muffleR.Set(muffleF);
                }
                outL = Sat(muffleL.Run(outL) * vol * 0.9f);
                outR = Sat(muffleR.Run(outR) * vol * 0.9f);
                if (channels >= 2)
                {
                    data[f * channels] += outL;
                    data[f * channels + 1] += outR;
                    for (int c = 2; c < channels; c++) data[f * channels + c] += (outL + outR) * 0.5f;
                }
                else data[f] += (outL + outR) * 0.5f;
            }
        }
    }
}
