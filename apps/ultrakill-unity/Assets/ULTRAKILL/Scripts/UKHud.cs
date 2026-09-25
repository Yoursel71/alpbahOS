// Arayüz (IMGUI, 1080p sanal çözünürlük): oyun içi HUD normal görünümdedir (can, stamina, silah,
// stil ölçeri, boss çubuğu, isabet işareti, kan lekeleri, hız çizgileri). Terminal/ASCII görünüm
// yalnız ana menü ve intro'dadır. Ölüm ekranında çığlık atan piksel kafatası, bölüm sonunda
// düşerken sonuç ekranı gösterilir.
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKHud : MonoBehaviour
    {
        public enum Panel { Main, Settings, Controls }
        public Panel panel = Panel.Main;

        UKGame G => UKGame.I;
        const float H = 1080f;
        float W, S;
        Matrix4x4 baseM;

        // zamanlayıcılar (ölçeklenmemiş zaman)
        string msg, hint, titleA, titleB;
        float msgT, msgDur = 1, hintT, hintDur = 1, titleT, titleDur = 1, hitT, flashT, flashDur = 1, speedT, speedDur = 1, hurtT, healT, dirT, dirAng, rankPulse, bossGhost = 1;
        bool hitKill;
        Color flashCol;

        class Splat { public Vector2 p; public float size, rot, t, life, drip; public int tex; }
        readonly List<Splat> splats = new List<Splat>();

        // intro
        struct Line { public string a, b; public Color bc; public float cps, pause, bar, start, end; }
        readonly List<Line> intro = new List<Line>();
        float introT, introEnd, lastBeep;
        int beepCount;
        static readonly string[] BIG = { "İNSANLIK ÖLDÜ.", "KAN YAKITTIR.", "CEHENNEM DOLU." };

        // kaynaklar
        Texture2D white, vignette, skull, jaw;
        Texture2D[] splatTex;
        Font mono;
        GUIStyle sText, sSmall, sBig, sHuge, sCenter, sMono, sMonoBig, sHint, sRank;
        bool styled;

        static readonly Color RED = new Color(1f, 0.23f, 0.14f), BLUE = new Color(0.29f, 0.64f, 1f), GRAY = new Color(0.62f, 0.62f, 0.66f);
        static readonly Color TERM = new Color(0.8f, 0.82f, 0.8f), TERM_DIM = new Color(0.45f, 0.47f, 0.46f), TERM_RED = new Color(1f, 0.25f, 0.18f), TERM_OK = new Color(0.35f, 1f, 0.5f);

        static readonly Dictionary<char, string[]> FONT5 = new Dictionary<char, string[]>
        {
            { 'U', new[] { "█   █", "█   █", "█   █", "█   █", " ███ " } },
            { 'L', new[] { "█    ", "█    ", "█    ", "█    ", "█████" } },
            { 'T', new[] { "█████", "  █  ", "  █  ", "  █  ", "  █  " } },
            { 'R', new[] { "████ ", "█   █", "████ ", "█  █ ", "█   █" } },
            { 'A', new[] { " ███ ", "█   █", "█████", "█   █", "█   █" } },
            { 'K', new[] { "█   █", "█  █ ", "███  ", "█  █ ", "█   █" } },
            { 'I', new[] { "█████", "  █  ", "  █  ", "  █  ", "█████" } },
        };
        string logo;

        void Awake()
        {
            white = Texture2D.whiteTexture;
            vignette = MakeVignette();
            splatTex = new[] { MakeSplat(11), MakeSplat(23), MakeSplat(37) };
            skull = PixelTex(new[]
            {
                "....########....",
                "..############..",
                ".##############.",
                "################",
                "################",
                "##oooo####oooo##",
                "#oooooo##oooooo#",
                "#ooorro##orrooo#",
                "#oooooo##oooooo#",
                "##oooo####oooo##",
                ".######oo######.",
                "..#####oo#####..",
                "...##########...",
                "...#.##.##.##...",
            });
            jaw = PixelTex(new[]
            {
                "...##.##.##.#...",
                "...##########...",
                "....########....",
                ".....######.....",
            });
            var rows = new string[5];
            for (int r = 0; r < 5; r++)
            {
                var sb = new System.Text.StringBuilder();
                foreach (char ch in "ULTRAKILL") { sb.Append(FONT5[ch][r]); sb.Append(' '); }
                rows[r] = sb.ToString();
            }
            logo = string.Join("\n", rows);
        }

        // ------------------------------------------------------------ doku üretimi
        static Texture2D PixelTex(string[] rows)
        {
            int w = 16, h = rows.Length;
            var t = new Texture2D(w, h, TextureFormat.RGBA32, false) { filterMode = FilterMode.Point, wrapMode = TextureWrapMode.Clamp };
            var bone = new Color(0.93f, 0.88f, 0.78f);
            for (int y = 0; y < h; y++)
            {
                string row = rows[h - 1 - y].PadRight(w, '.');
                for (int x = 0; x < w; x++)
                {
                    char c = row[x];
                    Color col = c == '#' ? bone : c == 'o' ? new Color(0.08f, 0.01f, 0.01f) : c == 'r' ? new Color(1f, 0.1f, 0.05f) : new Color(0, 0, 0, 0);
                    t.SetPixel(x, y, col);
                }
            }
            t.Apply();
            return t;
        }

        static Texture2D MakeVignette()
        {
            const int N = 128;
            var t = new Texture2D(N, N, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            for (int y = 0; y < N; y++)
                for (int x = 0; x < N; x++)
                {
                    float dx = (x + 0.5f) / N * 2 - 1, dy = (y + 0.5f) / N * 2 - 1;
                    float d = Mathf.Sqrt(dx * dx + dy * dy) / 1.414f;
                    float a = Mathf.Clamp01((d - 0.35f) / 0.65f);
                    t.SetPixel(x, y, new Color(1, 1, 1, a * a));
                }
            t.Apply();
            return t;
        }

        // Kan lekesi: ana damla + sıçrantılar + aşağı akan izler
        static Texture2D MakeSplat(int seed)
        {
            const int N = 128;
            var rng = new System.Random(seed);
            float R() => (float)rng.NextDouble();
            var blobs = new List<Vector3>();
            blobs.Add(new Vector3(0.5f, 0.55f, 0.2f + R() * 0.06f));
            for (int i = 0; i < 14; i++)
            {
                float a = R() * Mathf.PI * 2, d = 0.12f + R() * 0.3f;
                blobs.Add(new Vector3(0.5f + Mathf.Cos(a) * d, 0.55f + Mathf.Sin(a) * d, 0.015f + R() * 0.05f));
            }
            var drips = new List<Vector3>();
            for (int i = 0; i < 4; i++) drips.Add(new Vector3(0.35f + R() * 0.3f, 0.02f + R() * 0.012f, 0.25f + R() * 0.35f));
            var t = new Texture2D(N, N, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            for (int y = 0; y < N; y++)
                for (int x = 0; x < N; x++)
                {
                    float u = (x + 0.5f) / N, v = (y + 0.5f) / N;
                    float a = 0, core = 0;
                    foreach (var b in blobs)
                    {
                        float d = Vector2.Distance(new Vector2(u, v), new Vector2(b.x, b.y));
                        float n = Mathf.PerlinNoise(u * 14 + seed, v * 14) * 0.35f;
                        float k = Mathf.Clamp01((b.z * (1 + n) - d) / 0.012f);
                        a = Mathf.Max(a, k);
                        if (b == blobs[0]) core = Mathf.Clamp01(1 - d / b.z);
                    }
                    foreach (var dr in drips)
                    {
                        float top = 0.55f, bot = top - dr.z;
                        if (v < top && v > bot && Mathf.Abs(u - dr.x) < dr.y * (0.6f + 0.4f * (v - bot) / dr.z)) a = 1;
                        if (Vector2.Distance(new Vector2(u, v), new Vector2(dr.x, bot)) < dr.y * 1.3f) a = 1;
                    }
                    var c = Color.Lerp(new Color(0.32f, 0f, 0.01f), new Color(0.55f, 0.02f, 0.02f), core * 0.8f);
                    c.a = a * 0.92f;
                    t.SetPixel(x, y, c);
                }
            t.Apply();
            return t;
        }

        // ------------------------------------------------------------ dış arayüz
        public void Message(string text, float dur) { msg = text; msgT = msgDur = dur; }
        public void Hint(string text, float dur) { hint = text; hintT = hintDur = dur; }
        public void Title(string a, string b, float dur) { titleA = a; titleB = b; titleT = titleDur = dur; }
        public void Hitmarker(bool kill) { hitT = kill ? 0.3f : 0.16f; hitKill = kill; }
        public void Flash(Color c, float dur) { flashCol = c; flashT = flashDur = dur; }
        public void SpeedLines(float dur = 0.35f) { speedT = Mathf.Max(speedT, dur); speedDur = Mathf.Max(0.01f, speedT); }
        public void HealFlash() { healT = 0.3f; }
        public void RankPulse() { rankPulse = 1; }

        public void Hurt(float dmg, float? ang)
        {
            hurtT = Mathf.Min(1, hurtT + 0.35f + dmg * 0.012f);
            int n = dmg >= 25 ? 3 : dmg >= 10 ? 2 : 1;
            for (int i = 0; i < n; i++)
            {
                var s = new Splat
                {
                    tex = Random.Range(0, splatTex.Length),
                    size = Random.Range(260f, 430f) * (0.7f + Mathf.Min(dmg, 40) / 60f),
                    rot = Random.Range(-25f, 25f),
                    life = Random.Range(1.6f, 2.6f),
                };
                // kenarlara yakın, saldırı yönüne meyilli
                float side = ang.HasValue ? Mathf.Sin(ang.Value) : Random.Range(-1f, 1f);
                float x = Mathf.Clamp01(0.5f + side * 0.35f + Random.Range(-0.3f, 0.3f));
                float y = Random.Range(0.1f, 0.8f);
                if (x > 0.3f && x < 0.7f && y > 0.3f && y < 0.7f) x = x < 0.5f ? 0.12f : 0.88f;
                s.p = new Vector2(x, y);
                splats.Add(s);
            }
            if (splats.Count > 10) splats.RemoveRange(0, splats.Count - 10);
            if (ang.HasValue) { dirAng = ang.Value * Mathf.Rad2Deg; dirT = 0.9f; }
        }

        public void ResetAll()
        {
            msgT = hintT = titleT = hitT = flashT = speedT = hurtT = healT = dirT = 0;
            splats.Clear();
            bossGhost = 1;
        }

        // ------------------------------------------------------------ intro terminali
        public void StartIntro()
        {
            intro.Clear();
            void L(string a, string b = null, Color? bc = null, float cps = 120, float pause = 0.12f, float bar = 0)
            {
                intro.Add(new Line { a = a, b = b, bc = bc ?? TERM_OK, cps = cps, pause = pause, bar = bar });
            }
            L("ARAF-BIOS v0.1 — (C) CEHENNEM DİNAMİK A.Ş.", null, null, 160);
            L("BELLEK TARAMASI ............................ ", "640K TAMAM", TERM, 180);
            L("");
            L("BİRİM KİMLİĞİ: ", "V1", TERM_OK, 70);
            L("SINIF: SÜPER-MOBİL SAVAŞ MAKİNESİ", null, null, 90);
            L("DURUM: ", "UYANIŞ", TERM_OK, 70, 0.35f);
            L("");
            L("> ana güç kaynağı .......................... ", "[YOK]", TERM_RED, 120, 0.35f);
            L("> alternatif yakıt aranıyor ", null, null, 90, 0.1f, 1.1f);
            L("> KAN ...................................... ", "[TESPİT EDİLDİ]", TERM_RED, 120, 0.3f);
            L("> yakıt dönüştürücü ", null, null, 110, 0.1f, 0.7f);
            L("> hareket sistemleri ....................... ", "[TAMAM]", TERM_OK, 140);
            L("> silah sistemleri ......................... ", "[TAMAM]", TERM_OK, 140);
            L("> geribesleme kolu (FEEDBACKER) ............ ", "[TAMAM]", TERM_OK, 140);
            L("> hedef: CEHENNEM / KATMAN 0 — ARAF", null, null, 70, 0.6f);
            float t = 0.3f;
            for (int i = 0; i < intro.Count; i++)
            {
                var l = intro[i];
                l.start = t;
                t += l.a.Length / l.cps + l.bar + (l.b != null ? l.b.Length / l.cps + 0.1f : 0) + l.pause;
                l.end = t;
                intro[i] = l;
            }
            introEnd = t;
            introT = 0;
        }

        void UpdateIntro(float rdt)
        {
            introT += rdt;
            int chars = 0;
            foreach (var l in intro) if (introT >= l.start) chars += Mathf.Min(l.a.Length, (int)((introT - l.start) * l.cps));
            if (chars > beepCount && Time.unscaledTime - lastBeep > 0.045f) { UKAudio.I.Play("beep", 0.25f, 1.6f); lastBeep = Time.unscaledTime; }
            beepCount = chars;
            float bigEnd = introEnd + BIG.Length * 0.95f + 1.1f;
            for (int i = 0; i < BIG.Length; i++)
            {
                float at = introEnd + i * 0.95f;
                if (introT - rdt < at && introT >= at) { UKAudio.I.Play("slam", 0.8f, 0.8f + i * 0.08f); }
            }
            bool skip = UKInput.DownUnblocked(UKKey.Mouse0) || UKInput.DownUnblocked(UKKey.Enter) || UKInput.DownUnblocked(UKKey.Esc) || UKInput.DownUnblocked(UKKey.Space);
            if (introT >= bigEnd || (skip && introT > 0.2f)) G.BeginLevel();
        }

        // ------------------------------------------------------------ güncelleme
        void Update()
        {
            float rdt = Mathf.Min(Time.unscaledDeltaTime, 0.1f);
            msgT -= rdt; hintT -= rdt; titleT -= rdt; hitT -= rdt; flashT -= rdt; speedT -= rdt; healT -= rdt; dirT -= rdt;
            hurtT = Mathf.Max(0, hurtT - rdt * 0.9f);
            rankPulse = Mathf.Max(0, rankPulse - rdt * 3);
            for (int i = splats.Count - 1; i >= 0; i--)
            {
                var s = splats[i];
                s.t += rdt;
                s.drip += rdt * 18f * Mathf.Max(0, 1 - s.t / s.life);
                if (s.t >= s.life) splats.RemoveAt(i);
            }
            if (G != null && G.state == UKGame.State.Intro) UpdateIntro(rdt);
        }

        // ------------------------------------------------------------ çizim yardımcıları
        void EnsureStyles()
        {
            if (styled) return;
            styled = true;
            mono = Font.CreateDynamicFontFromOSFont(new[] { "Consolas", "Cascadia Mono", "Lucida Console", "Courier New", "DejaVu Sans Mono", "Liberation Mono", "Menlo", "Monaco" }, 20);
            sText = new GUIStyle(GUI.skin.label) { fontSize = 22, fontStyle = FontStyle.Bold, wordWrap = false, alignment = TextAnchor.MiddleLeft, richText = false, clipping = TextClipping.Overflow };
            sSmall = new GUIStyle(sText) { fontSize = 16 };
            sBig = new GUIStyle(sText) { fontSize = 40, alignment = TextAnchor.MiddleCenter };
            sHuge = new GUIStyle(sText) { fontSize = 64, alignment = TextAnchor.MiddleCenter };
            sCenter = new GUIStyle(sText) { alignment = TextAnchor.MiddleCenter };
            sHint = new GUIStyle(sText) { fontSize = 20, fontStyle = FontStyle.Normal, wordWrap = true, alignment = TextAnchor.MiddleCenter };
            sRank = new GUIStyle(sText) { fontSize = 72, alignment = TextAnchor.MiddleLeft, fontStyle = FontStyle.BoldAndItalic };
            sMono = new GUIStyle(sText) { font = mono, fontSize = 20, fontStyle = FontStyle.Normal, alignment = TextAnchor.UpperLeft };
            sMonoBig = new GUIStyle(sMono) { fontSize = 46, fontStyle = FontStyle.Bold, alignment = TextAnchor.MiddleLeft };
        }

        void Fill(Rect r, Color c)
        {
            var o = GUI.color;
            GUI.color = c;
            GUI.DrawTexture(r, white);
            GUI.color = o;
        }

        void Tex(Rect r, Texture t, Color c)
        {
            var o = GUI.color;
            GUI.color = c;
            GUI.DrawTexture(r, t);
            GUI.color = o;
        }

        void Text(Rect r, string s, GUIStyle st, Color c, bool shadow = true)
        {
            if (shadow)
            {
                st.normal.textColor = new Color(0, 0, 0, c.a * 0.75f);
                GUI.Label(new Rect(r.x + 2, r.y + 2, r.width, r.height), s, st);
            }
            st.normal.textColor = c;
            GUI.Label(r, s, st);
        }

        void Rotated(Vector2 pivot, float deg, System.Action draw)
        {
            var m = GUI.matrix;
            GUI.matrix = baseM * Matrix4x4.TRS(pivot, Quaternion.Euler(0, 0, deg), Vector3.one) * Matrix4x4.TRS(-pivot, Quaternion.identity, Vector3.one);
            draw();
            GUI.matrix = m;
        }

        bool Item(Rect r, string label, GUIStyle st, Color c, Color hover)
        {
            bool over = r.Contains(Event.current.mousePosition);
            Text(r, (over ? "> " : "  ") + label + (over && Mathf.Repeat(Time.unscaledTime, 1f) < 0.55f ? " █" : ""), st, over ? hover : c, false);
            bool click = GUI.Button(r, GUIContent.none, GUIStyle.none);
            if (click) UKAudio.I.Play("beep", 0.4f, 1.2f);
            return click;
        }

        bool Button(Rect r, string label)
        {
            bool over = r.Contains(Event.current.mousePosition);
            Fill(r, over ? new Color(0.9f, 0.2f, 0.12f, 0.9f) : new Color(0.12f, 0.12f, 0.14f, 0.9f));
            Fill(new Rect(r.x, r.yMax - 3, r.width, 3), over ? Color.white : RED);
            Text(r, label, sCenter, Color.white, false);
            bool click = GUI.Button(r, GUIContent.none, GUIStyle.none);
            if (click) UKAudio.I.Play("beep", 0.4f, 1.2f);
            return click;
        }

        static string Fmt(float t) { int s = Mathf.FloorToInt(t); return (s / 60) + ":" + (s % 60).ToString("00") + "." + Mathf.FloorToInt((t - s) * 10); }

        static Color RankCol(string r)
        {
            switch (r)
            {
                case "D": return new Color(0.29f, 0.64f, 1f);
                case "C": return new Color(0.24f, 0.88f, 0.42f);
                case "B": return new Color(1f, 0.82f, 0.12f);
                case "A": return new Color(1f, 0.54f, 0.12f);
                case "S": return new Color(1f, 0.23f, 0.14f);
                default: return new Color(1f, 0.82f, 0.29f);
            }
        }

        // ------------------------------------------------------------ OnGUI
        void OnGUI()
        {
            if (G == null) return;
            EnsureStyles();
            S = Screen.height / H;
            W = Screen.width / S;
            baseM = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(S, S, 1));
            GUI.matrix = baseM;
            var st = G.state;
            if (st == UKGame.State.Menu) { DrawMenu(); return; }
            if (st == UKGame.State.Intro) { DrawIntro(); return; }
            DrawWorldFx();
            if (st == UKGame.State.Playing || st == UKGame.State.Paused) DrawHud();
            if (st == UKGame.State.Paused) DrawPause();
            if (st == UKGame.State.Dead) DrawDeath();
            if (st == UKGame.State.Results) DrawResults();
            if (flashT > 0) { var c = flashCol; c.a *= Mathf.Clamp01(flashT / flashDur); Fill(new Rect(0, 0, W, H), c); }
        }

        void DrawWorldFx()
        {
            var p = G.player;
            // hız çizgileri: atılma, hızlı düşüş, sonuç ekranı düşüşü
            float fall = Mathf.Clamp01((-p.vel.y - 40f) / 40f);
            float sk = Mathf.Max(speedT > 0 ? speedT / speedDur : 0, G.state == UKGame.State.Results ? 0.8f : fall);
            if (sk > 0.01f)
            {
                var c = new Vector2(W / 2, H / 2);
                float t = Time.unscaledTime;
                for (int i = 0; i < 30; i++)
                {
                    float a = i * 12f + Mathf.PerlinNoise(i * 1.7f, t * 3f) * 20f;
                    float r0 = 260 + Mathf.Repeat(t * 900 + i * 97, 360);
                    float len = 80 + (i * 37) % 120;
                    Rotated(c, a, () => Fill(new Rect(c.x + r0, c.y - 1, len, 2), new Color(1, 1, 1, 0.22f * sk)));
                }
            }
            // kan lekeleri
            foreach (var s in splats)
            {
                float a = s.t < 0.08f ? s.t / 0.08f : Mathf.Clamp01(1 - (s.t - s.life * 0.55f) / (s.life * 0.45f));
                float sc = s.t < 0.08f ? 0.7f + 0.3f * s.t / 0.08f : 1;
                var pos = new Vector2(s.p.x * W, s.p.y * H + s.drip);
                var r = new Rect(pos.x - s.size * sc / 2, pos.y - s.size * sc / 2, s.size * sc, s.size * sc * 1.15f);
                var tex = splatTex[s.tex];
                Rotated(pos, s.rot, () => Tex(r, tex, new Color(1, 1, 1, a)));
            }
            // hasar kenar kızarması + düşük can nabzı
            float low = p.hp < 30 && !p.dead ? (0.25f + 0.15f * Mathf.Sin(Time.unscaledTime * 6f)) : 0;
            float vig = Mathf.Max(hurtT * 0.75f, low);
            if (vig > 0.01f) Tex(new Rect(0, 0, W, H), vignette, new Color(0.7f, 0, 0, vig));
            if (healT > 0) Tex(new Rect(0, 0, W, H), vignette, new Color(0.3f, 1f, 0.45f, healT));
            // saldırı yönü
            if (dirT > 0 && G.state == UKGame.State.Playing)
            {
                var c = new Vector2(W / 2, H / 2);
                float a = Mathf.Clamp01(dirT / 0.9f);
                Rotated(c, dirAng, () => Fill(new Rect(c.x - 50, c.y - 150, 100, 8), new Color(1, 0.1f, 0.05f, 0.8f * a)));
            }
        }

        void DrawHud()
        {
            var p = G.player;
            var w = G.weapons;
            var c = new Vector2(W / 2, H / 2);
            // nişangâh
            var ch = new Color(1, 1, 1, 0.9f);
            Fill(new Rect(c.x - 1, c.y - 12, 2, 7), ch); Fill(new Rect(c.x - 1, c.y + 5, 2, 7), ch);
            Fill(new Rect(c.x - 12, c.y - 1, 7, 2), ch); Fill(new Rect(c.x + 5, c.y - 1, 7, 2), ch);
            float charge = w.PierceCharge;
            if (charge > 0)
            {
                int n = Mathf.CeilToInt(charge * 16);
                for (int i = 0; i < n; i++)
                {
                    float a = i / 16f * Mathf.PI * 2 - Mathf.PI / 2;
                    Fill(new Rect(c.x + Mathf.Cos(a) * 26 - 2, c.y + Mathf.Sin(a) * 26 - 2, 4, 4), charge >= 1 ? Color.white : BLUE);
                }
            }
            if (hitT > 0)
            {
                float k = hitKill ? 1.5f : 1f;
                var col = hitKill ? new Color(1, 0.2f, 0.1f, Mathf.Clamp01(hitT / 0.3f)) : new Color(1, 1, 1, Mathf.Clamp01(hitT / 0.16f));
                Rotated(c, 45, () =>
                {
                    Fill(new Rect(c.x - 1.5f * k, c.y - 18 * k, 3 * k, 10 * k), col); Fill(new Rect(c.x - 1.5f * k, c.y + 8 * k, 3 * k, 10 * k), col);
                    Fill(new Rect(c.x - 18 * k, c.y - 1.5f * k, 10 * k, 3 * k), col); Fill(new Rect(c.x + 8 * k, c.y - 1.5f * k, 10 * k, 3 * k), col);
                });
            }

            // sol alt: can, stamina, silah
            var box = new Rect(36, H - 196, 440, 160);
            Fill(box, new Color(0.05f, 0.05f, 0.06f, 0.72f));
            Fill(new Rect(box.x, box.y, 4, box.height), RED);
            Text(new Rect(box.x + 18, box.y + 8, 120, 50), Mathf.CeilToInt(Mathf.Max(0, p.hp)).ToString(), new GUIStyle(sText) { fontSize = 44 }, Color.white);
            var hpR = new Rect(box.x + 130, box.y + 20, 290, 26);
            Fill(hpR, new Color(0.18f, 0.03f, 0.03f, 0.9f));
            Fill(new Rect(hpR.x, hpR.y, hpR.width * Mathf.Clamp01(p.hp / p.maxHp), hpR.height), new Color(0.92f, 0.12f, 0.1f));
            if (p.hard > 0) Fill(new Rect(hpR.xMax - hpR.width * p.hard / p.maxHp, hpR.y, hpR.width * p.hard / p.maxHp, hpR.height), new Color(0.35f, 0.35f, 0.38f));
            for (int i = 0; i < 3; i++)
            {
                var r = new Rect(box.x + 130 + i * 98, box.y + 56, 92, 10);
                Fill(r, new Color(0.08f, 0.14f, 0.22f, 0.9f));
                float f = Mathf.Clamp01(p.stamina - i);
                Fill(new Rect(r.x, r.y, r.width * f, r.height), f >= 1 ? BLUE : new Color(0.2f, 0.4f, 0.65f));
            }
            Text(new Rect(box.x + 18, box.y + 82, 300, 32), w.CurName, new GUIStyle(sText) { fontSize = 26 }, w.CurAccent);
            Text(new Rect(box.x + 18, box.y + 112, 300, 24), "SAĞ TIK: " + w.CurSub, sSmall, GRAY);
            for (int i = 0; i < 3; i++)
            {
                var r = new Rect(box.x + 330 + i * 34, box.y + 92, 28, 28);
                Fill(r, i == w.cur ? w.CurAccent : new Color(0.2f, 0.2f, 0.22f, 0.9f));
                Text(r, (i + 1).ToString(), sCenter, i == w.cur ? Color.black : GRAY, false);
            }
            var fr = G.style.Freshness(w.CurKey);
            Text(new Rect(box.x + 330, box.y + 124, 110, 24), fr.name, sSmall, fr.color);

            // üst sol: bölüm ve süre
            Text(new Rect(36, 26, 500, 28), G.level.levelId + "  " + G.level.levelName, sSmall, GRAY);
            Text(new Rect(36, 48, 500, 28), Fmt(G.runTime) + "   ÖLDÜRME " + G.kills + "/" + G.level.TotalEnemies, sSmall, Color.white);

            DrawStyle();
            DrawBoss();

            // mesaj, başlık kartı, ipucu
            if (titleT > 0)
            {
                float a = Mathf.Clamp01(Mathf.Min(titleT, titleDur - titleT) * 2.5f);
                Text(new Rect(0, H * 0.3f - 40, W, 40), titleA, new GUIStyle(sCenter) { fontSize = 24 }, new Color(0.8f, 0.8f, 0.82f, a));
                Text(new Rect(0, H * 0.3f, W, 80), titleB, sHuge, new Color(1, 1, 1, a));
            }
            if (msgT > 0)
            {
                float a = Mathf.Clamp01(Mathf.Min(msgT, msgDur - msgT) * 4f);
                float sc = 1 + Mathf.Max(0, 0.15f - (msgDur - msgT)) * 2f;
                Text(new Rect(0, H * 0.2f, W, 60), msg, new GUIStyle(sBig) { fontSize = Mathf.RoundToInt(40 * sc) }, new Color(1, 1, 1, a));
            }
            if (hintT > 0 && !string.IsNullOrEmpty(hint))
            {
                float a = Mathf.Clamp01(Mathf.Min(hintT, hintDur - hintT) * 3f);
                var r = new Rect(W / 2 - 480, H - 150, 960, 76);
                Fill(r, new Color(0.04f, 0.04f, 0.05f, 0.75f * a));
                Fill(new Rect(r.x, r.y, r.width, 3), new Color(RED.r, RED.g, RED.b, a));
                Text(new Rect(r.x + 16, r.y + 4, r.width - 32, r.height - 8), hint, sHint, new Color(1, 1, 1, a));
            }
        }

        void DrawStyle()
        {
            var s = G.style;
            if (!s.active && s.total <= 0) return;
            var R = UKStyle.RANKS[s.rank];
            var box = new Rect(W - 400, 40, 360, 124 + s.bonuses.Count * 26);
            Fill(box, new Color(0.05f, 0.05f, 0.06f, s.active ? 0.72f : 0.35f));
            float pulse = Mathf.Max(s.pulse, rankPulse);
            Text(new Rect(box.x + 16, box.y + 6, 340, 80), R.letter, new GUIStyle(sRank) { fontSize = Mathf.RoundToInt((R.letter.Length > 3 ? 44 : 72) * (1 + pulse * 0.25f)) }, R.color);
            Text(new Rect(box.x + 18, box.y + 78, 340, 24), R.name, sSmall, R.color);
            var bar = new Rect(box.x + 18, box.y + 104, 324, 6);
            Fill(bar, new Color(0.15f, 0.15f, 0.17f));
            Fill(new Rect(bar.x, bar.y, bar.width * Mathf.Clamp01(s.meter / R.cap), bar.height), R.color);
            for (int i = 0; i < s.bonuses.Count; i++)
            {
                var b = s.bonuses[i];
                float age = Time.time - b.t;
                float a = Mathf.Clamp01((3.2f - age) * 2f);
                string t = "+ " + b.name + (b.count > 1 ? " x" + b.count : "");
                Text(new Rect(box.x + 18, box.y + 118 + i * 26, 340, 26), t, sSmall, new Color(b.color.r, b.color.g, b.color.b, a));
            }
        }

        void DrawBoss()
        {
            UKEnemy boss = null;
            foreach (var e in UKEnemy.All) if (e.boss && !e.dead) { boss = e; break; }
            if (boss == null) { bossGhost = 1; return; }
            float f = Mathf.Clamp01(boss.hp / boss.maxHp);
            bossGhost = Mathf.MoveTowards(bossGhost, f, Time.unscaledDeltaTime * 0.35f);
            if (bossGhost < f) bossGhost = f;
            var r = new Rect(W / 2 - 460, 74, 920, 22);
            Text(new Rect(r.x, r.y - 36, r.width, 32), boss.enemyName, sCenter, Color.white);
            Fill(new Rect(r.x - 3, r.y - 3, r.width + 6, r.height + 6), new Color(0, 0, 0, 0.7f));
            Fill(new Rect(r.x, r.y, r.width * bossGhost, r.height), new Color(1f, 0.85f, 0.4f));
            Fill(new Rect(r.x, r.y, r.width * f, r.height), boss.enraged ? new Color(1f, 0.1f, 0.05f) : new Color(0.85f, 0.1f, 0.08f));
        }

        // ------------------------------------------------------------ menü (terminal)
        void DrawMenu()
        {
            Fill(new Rect(0, 0, W, H), new Color(0.01f, 0.01f, 0.01f, 0.82f));
            float x = 90, y = 70;
            Text(new Rect(x, y, 1200, 30), "v1@araf:~$ ./ultrakill --unity --katman 0", sMono, TERM_DIM, false);
            y += 50;
            var lg = new GUIStyle(sMono) { fontSize = 26, alignment = TextAnchor.UpperLeft };
            Text(new Rect(x, y, 1600, 200), logo, lg, TERM_RED, false);
            y += 190;
            Text(new Rect(x, y, 1200, 30), "UNITY SÜRÜMÜ · PRELUDE / 0-1 ATEŞİN İÇİNE", sMono, TERM, false);
            y += 70;
            var item = new GUIStyle(sMono) { fontSize = 30, alignment = TextAnchor.MiddleLeft };
            if (panel == Panel.Main)
            {
                if (Item(new Rect(x, y, 700, 44), "OYNA", item, TERM, TERM_RED)) G.StartNew();
                y += 50;
                var d = UKGame.DIFFS[G.diffIndex];
                if (Item(new Rect(x, y, 700, 44), "ZORLUK: < " + d.name + " >", item, TERM, TERM_RED))
                {
                    G.diffIndex = (G.diffIndex + 1) % UKGame.DIFFS.Length;
                    PlayerPrefs.SetInt("uk.diff", G.diffIndex);
                }
                Text(new Rect(x + 40, y + 40, 900, 26), d.desc, new GUIStyle(sMono) { fontSize = 18 }, TERM_DIM, false);
                y += 80;
                if (Item(new Rect(x, y, 700, 44), "AYARLAR", item, TERM, TERM_RED)) panel = Panel.Settings;
                y += 50;
                if (Item(new Rect(x, y, 700, 44), "KONTROLLER", item, TERM, TERM_RED)) panel = Panel.Controls;
                y += 50;
                if (Item(new Rect(x, y, 700, 44), "ÇIKIŞ", item, TERM, TERM_RED)) Application.Quit();
                string best = PlayerPrefs.GetString("uk.best." + G.level.levelId, "");
                if (best != "") Text(new Rect(x, y + 70, 700, 30), "EN İYİ: " + best, sMono, RankCol(best), false);
            }
            else if (panel == Panel.Settings) { if (SettingsPanel(new Rect(x, y, 820, 460), true)) panel = Panel.Main; }
            else { if (ControlsPanel(new Rect(x, y, 1100, 520), true)) panel = Panel.Main; }
            if (!UKInput.Available) Text(new Rect(x, H - 100, W - 180, 30), "GİRDİ YOK: Project Settings > Player > Active Input Handling = Both yapın.", new GUIStyle(sMono) { fontSize = 18 }, TERM_RED, false);
            Text(new Rect(x, H - 60, W - 180, 30), "Hayran yapımı, ticari değildir. ULTRAKILL; Arsi \"Hakita\" Patala ve New Blood Interactive'e aittir.", new GUIStyle(sMono) { fontSize = 16 }, TERM_DIM, false);
        }

        // true dönerse "geri"
        bool SettingsPanel(Rect r, bool mono_)
        {
            var s = G.settings;
            var lab = mono_ ? new GUIStyle(sMono) { fontSize = 22, alignment = TextAnchor.MiddleLeft } : new GUIStyle(sText) { fontSize = 22 };
            var col = mono_ ? TERM : Color.white;
            float y = r.y;
            bool changed = false;
            float Slider(string name, float v, float min, float max, string fmt)
            {
                Text(new Rect(r.x, y, 330, 34), name, lab, col, false);
                float nv = GUI.HorizontalSlider(new Rect(r.x + 340, y + 12, 330, 20), v, min, max);
                Text(new Rect(r.x + 690, y, 140, 34), nv.ToString(fmt), lab, col, false);
                y += 46;
                if (!Mathf.Approximately(nv, v)) changed = true;
                return nv;
            }
            s.sensitivity = Slider("FARE HASSASİYETİ", s.sensitivity, 0.1f, 4f, "0.00");
            s.fov = Mathf.Round(Slider("GÖRÜŞ AÇISI (FOV)", s.fov, 80f, 130f, "0"));
            s.volume = Slider("SES", s.volume, 0f, 1f, "0.00");
            s.shake = Slider("EKRAN SARSINTISI", s.shake, 0f, 1.5f, "0.00");
            s.aimAssist = Slider("NİŞAN YARDIMI", s.aimAssist, 0f, 2f, "0.00");
            Text(new Rect(r.x, y, 330, 34), "Y EKSENİ TERS", lab, col, false);
            bool inv = GUI.Toggle(new Rect(r.x + 340, y + 6, 40, 24), s.invertY, "");
            if (inv != s.invertY) { s.invertY = inv; changed = true; }
            y += 60;
            if (changed) s.Save();
            if (mono_) return Item(new Rect(r.x, y, 300, 44), "GERİ", new GUIStyle(sMono) { fontSize = 30, alignment = TextAnchor.MiddleLeft }, TERM, TERM_RED);
            return Button(new Rect(r.x, y, 300, 50), "GERİ");
        }

        bool ControlsPanel(Rect r, bool mono_)
        {
            string[] lines =
            {
                "[W A S D]      hareket          [FARE]          bak",
                "[BOŞLUK]       zıpla / havada duvara doğru: DUVAR SIÇRAMASI (3)",
                "[SHIFT]        atıl (hasarsız, 3 stamina) · atılırken zıpla: uzun sıçrayış",
                "[C] / [CTRL]   yerde KAY · havada YERE ÇAK → çarpınca zıpla: ÇAKIŞ SIÇRAYIŞI",
                "[SOL TIK]      ateş                [SAĞ TIK]       alternatif atış",
                "[1] [2] [3]    REVOLVER / SHOTGUN / NAILGUN · [TEKERLEK] silah değiştir",
                "[F]            FEEDBACKER yumruğu · mermiyi ya da PARLAYAN saldırıyı PARRY'le",
                "[ESC]          duraklat",
            };
            var lab = mono_ ? new GUIStyle(sMono) { fontSize = 22 } : new GUIStyle(sText) { fontSize = 20, fontStyle = FontStyle.Normal };
            float y = r.y;
            foreach (var l in lines) { Text(new Rect(r.x, y, r.width, 32), l, lab, mono_ ? TERM : Color.white, false); y += 38; }
            y += 20;
            if (mono_) return Item(new Rect(r.x, y, 300, 44), "GERİ", new GUIStyle(sMono) { fontSize = 30, alignment = TextAnchor.MiddleLeft }, TERM, TERM_RED);
            return Button(new Rect(r.x, y, 300, 50), "GERİ");
        }

        void DrawIntro()
        {
            Fill(new Rect(0, 0, W, H), Color.black);
            float x = 110, y = 90;
            foreach (var l in intro)
            {
                if (introT < l.start) break;
                float t = introT - l.start;
                int n = Mathf.Min(l.a.Length, (int)(t * l.cps));
                string s = l.a.Substring(0, n);
                float after = t - l.a.Length / l.cps;
                if (l.bar > 0 && after > 0)
                {
                    int bars = Mathf.Clamp(Mathf.FloorToInt(after / l.bar * 24), 0, 24);
                    s += "[" + new string('#', bars) + new string('.', 24 - bars) + "]";
                }
                Text(new Rect(x, y, 1600, 30), s, sMono, TERM, false);
                if (l.b != null && after > l.bar)
                {
                    int m = Mathf.Min(l.b.Length, (int)((after - l.bar) * l.cps));
                    var sz = sMono.CalcSize(new GUIContent(l.a));
                    Text(new Rect(x + sz.x, y, 600, 30), l.b.Substring(0, m), sMono, l.bc, false);
                }
                y += 30;
            }
            bool cursorOn = Mathf.Repeat(Time.unscaledTime, 0.8f) < 0.45f;
            if (introT < introEnd && cursorOn) Text(new Rect(x, y, 30, 30), "█", sMono, TERM, false);
            for (int i = 0; i < BIG.Length; i++)
            {
                float at = introEnd + i * 0.95f;
                if (introT < at) break;
                float k = Mathf.Clamp01((introT - at) / 0.12f);
                Text(new Rect(x, y + 50 + i * 70, 1400, 70), BIG[i], new GUIStyle(sMonoBig) { fontSize = Mathf.RoundToInt(46 * (1.3f - 0.3f * k)) }, new Color(TERM_RED.r, TERM_RED.g, TERM_RED.b, k), false);
            }
            Text(new Rect(W - 520, H - 60, 480, 30), "[TIKLA / ENTER] atla", new GUIStyle(sMono) { fontSize = 18, alignment = TextAnchor.MiddleRight }, TERM_DIM, false);
        }

        // ------------------------------------------------------------ duraklatma
        void DrawPause()
        {
            Fill(new Rect(0, 0, W, H), new Color(0, 0, 0, 0.65f));
            Text(new Rect(0, 140, W, 80), "DURAKLATILDI", sHuge, Color.white);
            float x = W / 2 - 220, y = 280;
            if (panel == Panel.Settings) { if (SettingsPanel(new Rect(W / 2 - 415, y, 830, 460), false)) panel = Panel.Main; return; }
            if (panel == Panel.Controls) { if (ControlsPanel(new Rect(W / 2 - 560, y, 1120, 520), false)) panel = Panel.Main; return; }
            if (Button(new Rect(x, y, 440, 54), "DEVAM ET")) G.Resume();
            if (Button(new Rect(x, y + 66, 440, 54), "SON KONTROL NOKTASI")) G.Respawn();
            if (Button(new Rect(x, y + 132, 440, 54), "BÖLÜMÜ BAŞTAN BAŞLAT")) G.BeginLevel();
            if (Button(new Rect(x, y + 198, 440, 54), "AYARLAR")) panel = Panel.Settings;
            if (Button(new Rect(x, y + 264, 440, 54), "KONTROLLER")) panel = Panel.Controls;
            if (Button(new Rect(x, y + 330, 440, 54), "ANA MENÜ")) G.ToMenu();
        }

        // ------------------------------------------------------------ ölüm ekranı
        void DrawDeath()
        {
            float t = G.deathT;
            Fill(new Rect(0, 0, W, H), new Color(0.35f, 0, 0, Mathf.Clamp01(t / 0.6f) * 0.55f));
            Tex(new Rect(0, 0, W, H), vignette, new Color(0, 0, 0, Mathf.Clamp01(t / 0.8f)));
            if (t < 0.35f) return;
            // kafatası: çığlık atarken çene açılır, titrer
            float scream = G.ScreamK;
            float px = 18;
            float sw = 16 * px, sh = 14 * px;
            var jit = scream > 0 ? new Vector2(Random.Range(-6f, 6f), Random.Range(-6f, 6f)) * scream : Vector2.zero;
            float pop = Mathf.Clamp01((t - 0.35f) / 0.15f);
            float sc = 0.6f + 0.4f * pop + scream * 0.08f;
            var c = new Vector2(W / 2, H / 2 - 60) + jit;
            var sr = new Rect(c.x - sw * sc / 2, c.y - sh * sc / 2, sw * sc, sh * sc);
            float jawDrop = scream * 5 * px * sc;
            var jr = new Rect(c.x - sw * sc / 2, sr.yMax - px * sc * 0.5f + jawDrop, sw * sc, 4 * px * sc);
            if (scream > 0) Fill(new Rect(c.x - 4 * px * sc, sr.yMax - px * sc, 8 * px * sc, jawDrop + px * sc), new Color(0.12f, 0, 0, pop));
            Tex(sr, skull, new Color(1, 1, 1, pop));
            Tex(jr, jaw, new Color(1, 1, 1, pop));
            Text(new Rect(0, jr.yMax + 30, W, 60), "ÖLDÜN", sBig, new Color(1, 0.2f, 0.12f, pop));
            if (t > 1.0f && Mathf.Repeat(Time.unscaledTime, 1f) < 0.7f)
                Text(new Rect(0, jr.yMax + 90, W, 40), "[R] / [TIKLA]  →  SON KONTROL NOKTASI", sCenter, new Color(1, 1, 1, 0.85f));
        }

        // ------------------------------------------------------------ sonuç ekranı (düşerken)
        void DrawResults()
        {
            var r = G.results;
            if (r == null) return;
            float t = G.resultsT;
            float slide = 1 - Mathf.Pow(1 - Mathf.Clamp01(t / 0.6f), 3);
            var box = new Rect(W - 40 - 640 * slide, 110, 640, 620);
            Fill(box, new Color(0.04f, 0.04f, 0.05f, 0.86f));
            Fill(new Rect(box.x, box.y, box.width, 4), RED);
            Text(new Rect(box.x + 30, box.y + 20, 580, 40), G.level.layerName, sSmall, GRAY);
            Text(new Rect(box.x + 30, box.y + 44, 580, 50), G.level.levelId + ": " + G.level.levelName, new GUIStyle(sText) { fontSize = 34 }, Color.white);
            string[] names = { "SÜRE", "ÖLDÜRME", "STİL" };
            string[] vals = { Fmt(r.time), r.kills + " / " + r.total, Mathf.RoundToInt(r.style).ToString() };
            string[] ranks = { r.timeRank, r.killRank, r.styleRank };
            for (int i = 0; i < 3; i++)
            {
                float at = 0.8f + i * 0.55f;
                if (t < at) break;
                float y = box.y + 130 + i * 90;
                Fill(new Rect(box.x + 30, y, 580, 70), new Color(1, 1, 1, 0.04f));
                Text(new Rect(box.x + 50, y, 250, 70), names[i], new GUIStyle(sText) { fontSize = 26 }, GRAY);
                Text(new Rect(box.x + 250, y, 250, 70), vals[i], new GUIStyle(sText) { fontSize = 30 }, Color.white);
                if (t > at + 0.3f) Text(new Rect(box.x + 520, y, 80, 70), ranks[i], new GUIStyle(sRank) { fontSize = 48, alignment = TextAnchor.MiddleCenter }, RankCol(ranks[i]));
            }
            float ft = 0.8f + 3 * 0.55f + 0.5f;
            if (t > ft)
            {
                float k = Mathf.Clamp01((t - ft) / 0.2f);
                float y = box.y + 420;
                Text(new Rect(box.x + 50, y, 250, 110), "SONUÇ", new GUIStyle(sText) { fontSize = 32 }, Color.white);
                Text(new Rect(box.x + 330, y, 250, 110), r.final, new GUIStyle(sRank) { fontSize = Mathf.RoundToInt(110 * (1.6f - 0.6f * k)), alignment = TextAnchor.MiddleCenter }, RankCol(r.final));
                if (r.restarts > 0) Text(new Rect(box.x + 50, y + 100, 500, 30), "YENİDEN DOĞUŞ: " + r.restarts, sSmall, GRAY);
            }
            if (t > ft + 0.8f && Mathf.Repeat(Time.unscaledTime, 1f) < 0.7f)
                Text(new Rect(box.x, box.yMax + 16, box.width, 40), "[TIKLA] ANA MENÜ   ·   [R] TEKRAR OYNA", sCenter, Color.white);
        }
    }
}
