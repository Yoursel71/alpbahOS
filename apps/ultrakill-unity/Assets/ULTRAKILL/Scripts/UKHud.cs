// Arayüz (IMGUI, 1080p sanal çözünürlük). Oyun içi HUD normal görünümdedir: can / sert hasar / stamina,
// 5 silah yuvası + varyant noktaları + silaha özgü şarj göstergesi, kol ve kanca, P sayacı, süre / öldürme /
// gizli küre, stil ölçeri, boss çubuğu, isabet işareti, dükkân uyarısı, kan lekeleri ve hız çizgileri.
// Terminal/ASCII görünüm yalnız ana menü (bölüm seçimi, ayarlar) ve intro'dadır. Dükkân ekranı, duraklatma,
// çığlık atan kafatasıyla ölüm ekranı ve kuyuda düşerken sonuç ekranı (sıra, meydan okuma, P) buradadır.
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKHud : MonoBehaviour
    {
        public enum Panel { Main, Levels, Settings, Controls }
        public Panel panel = Panel.Main;
        public int shopTab;

        UKGame G => UKGame.I;
        const float H = 1080f;
        float W, S;
        Matrix4x4 baseM;

        // zamanlayıcılar (ölçeklenmemiş zaman)
        string msg, msgStyle, hint, titleA, titleB, titleC, wmsg;
        float msgT, msgDur = 1, hintT, hintDur = 1, titleT, titleDur = 1, hitT, flashT, flashDur = 1, speedT, speedDur = 1, hurtT, healT, dirT, dirAng, rankPulse, bossGhost = 1, wmsgT;
        bool hitKill, titleBoss;
        Color flashCol, wmsgCol;

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

        static readonly Color RED = new Color(1f, 0.23f, 0.14f), BLUE = new Color(0.29f, 0.64f, 1f), GRAY = new Color(0.62f, 0.62f, 0.66f), GOLD = new Color(1f, 0.82f, 0.29f), GREENC = new Color(0.24f, 0.88f, 0.42f);
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

        // Dünya içi yazılar (dükkân ekranı) için yerleşik yazı tipi
        static Font builtin;
        public static Font BuiltinFont()
        {
            if (builtin != null) return builtin;
            foreach (var n in new[] { "LegacyRuntime.ttf", "Arial.ttf" })
            {
                try { builtin = Resources.GetBuiltinResource<Font>(n); } catch { builtin = null; }
                if (builtin != null) break;
            }
            return builtin;
        }

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
        public void Message(string text, float dur, string style = null) { msg = text; msgT = msgDur = dur; msgStyle = style; }
        public void Hint(string text, float dur) { hint = text; hintT = hintDur = dur; }
        public void Title(string a, string b, float dur, string c = null) { titleA = a; titleB = b; titleC = c; titleT = titleDur = dur; titleBoss = false; }
        public void BossTitle(string sub, string name, float dur) { titleA = sub; titleB = name; titleC = null; titleT = titleDur = dur; titleBoss = true; }
        public void WeaponMessage(string text, Color c) { wmsg = text; wmsgCol = c; wmsgT = 1.2f; }
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
            msgT = hintT = titleT = hitT = flashT = speedT = hurtT = healT = dirT = wmsgT = 0;
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
                if (introT - rdt < at && introT >= at) UKAudio.I.Play("slam", 0.8f, 0.8f + i * 0.08f);
            }
            bool skip = UKInput.DownUnblocked(UKKey.Mouse0) || UKInput.DownUnblocked(UKKey.Enter) || UKInput.DownUnblocked(UKKey.Esc) || UKInput.DownUnblocked(UKKey.Space);
            if (introT >= bigEnd || (skip && introT > 0.2f)) G.IntroDone();
        }

        // ------------------------------------------------------------ güncelleme
        void Update()
        {
            float rdt = Mathf.Min(Time.unscaledDeltaTime, 0.1f);
            msgT -= rdt; hintT -= rdt; titleT -= rdt; hitT -= rdt; flashT -= rdt; speedT -= rdt; healT -= rdt; dirT -= rdt; wmsgT -= rdt;
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

        bool Item(Rect r, string label, GUIStyle st, Color c, Color hover, bool enabled = true)
        {
            bool over = enabled && r.Contains(Event.current.mousePosition);
            Text(r, (over ? "> " : "  ") + label + (over && Mathf.Repeat(Time.unscaledTime, 1f) < 0.55f ? " █" : ""), st, !enabled ? TERM_DIM : over ? hover : c, false);
            bool click = GUI.Button(r, GUIContent.none, GUIStyle.none) && enabled;
            if (click) UKAudio.I.Play("uiClick", 0.6f);
            return click;
        }

        bool Button(Rect r, string label, bool enabled = true, Color? accent = null)
        {
            bool over = enabled && r.Contains(Event.current.mousePosition);
            Fill(r, !enabled ? new Color(0.1f, 0.1f, 0.11f, 0.8f) : over ? new Color(0.9f, 0.2f, 0.12f, 0.9f) : new Color(0.12f, 0.12f, 0.14f, 0.9f));
            Fill(new Rect(r.x, r.yMax - 3, r.width, 3), !enabled ? GRAY * 0.5f : over ? Color.white : accent ?? RED);
            Text(r, label, sCenter, enabled ? Color.white : GRAY, false);
            bool click = GUI.Button(r, GUIContent.none, GUIStyle.none) && enabled;
            if (click) UKAudio.I.Play("uiClick", 0.6f);
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
                default: return GOLD;
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
            if (st == UKGame.State.Playing || st == UKGame.State.Paused || st == UKGame.State.Shop) DrawHud();
            if (st == UKGame.State.Paused) DrawPause();
            if (st == UKGame.State.Shop) DrawShop();
            if (st == UKGame.State.Dead) DrawDeath();
            if (st == UKGame.State.Results) DrawResults();
            if (flashT > 0) { var c = flashCol; c.a *= Mathf.Clamp01(flashT / flashDur); Fill(new Rect(0, 0, W, H), c); }
        }

        void DrawWorldFx()
        {
            var p = G.player;
            // hız çizgileri: atılma, hızlı düşüş, sonuç ekranı düşüşü
            float fall = G.state == UKGame.State.Playing ? Mathf.Clamp01((-p.vel.y - 40f) / 40f) : 0;
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
            if (G.state == UKGame.State.Results) return;
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

        // Silaha özgü şarj göstergesi: etiket + dolum (0..1) + parça sayısı (0 = sürekli çubuk)
        void Charge(UKWeapons w, out string label, out float fill, out int pips, out Color col)
        {
            label = null; fill = 0; pips = 0; col = w.CurAccent;
            switch (w.VarId)
            {
                case "marksman": label = "PARA"; fill = w.CoinCharges / 4f; pips = 4; break;
                case "sharpshooter": label = "SEKME"; fill = w.SharpCharges / 3f; pips = 3; break;
                case "pump": label = "POMPA"; fill = w.Pumps / 3f; pips = 3; col = w.Pumps >= 3 ? RED : w.CurAccent; break;
                case "saw": label = w.SawOut ? "TESTERE DIŞARIDA" : "TESTERE HAZIR"; fill = w.SawOut ? 0 : 1; break;
                case "attractor": label = "MIKNATIS"; fill = w.Magnets / 3f; pips = 3; break;
                case "overheat": label = "ISI"; fill = w.Heat; col = Color.Lerp(new Color(1f, 0.8f, 0.3f), RED, w.Heat); break;
                case "electric": case "screwdriver": case "malicious": label = w.RailCharge >= 1 ? "RAIL HAZIR" : "ŞARJ"; fill = w.RailCharge; col = w.RailCharge >= 1 ? new Color(0.23f, 0.92f, 1f) : GRAY; break;
                case "freeze": label = w.FreezeActive ? "DONDURULDU" : "FREEZEFRAME"; fill = w.FreezeEnergy; break;
                case "cannon": label = "GÜLLE"; fill = w.CannonReady; break;
                case "fire": label = "YAKIT"; fill = w.Fuel; break;
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
            var box = new Rect(36, H - 236, 480, 200);
            Fill(box, new Color(0.05f, 0.05f, 0.06f, 0.72f));
            Fill(new Rect(box.x, box.y, 4, box.height), p.v2 ? new Color(1f, 0.35f, 0.2f) : RED);
            Text(new Rect(box.x + 18, box.y + 8, 120, 50), Mathf.CeilToInt(Mathf.Max(0, p.hp)).ToString(), new GUIStyle(sText) { fontSize = 44 }, Color.white);
            var hpR = new Rect(box.x + 130, box.y + 20, 330, 26);
            Fill(hpR, new Color(0.18f, 0.03f, 0.03f, 0.9f));
            Fill(new Rect(hpR.x, hpR.y, hpR.width * Mathf.Clamp01(p.hp / p.maxHp), hpR.height), new Color(0.92f, 0.12f, 0.1f));
            if (p.hard > 0) Fill(new Rect(hpR.xMax - hpR.width * p.hard / p.maxHp, hpR.y, hpR.width * p.hard / p.maxHp, hpR.height), new Color(0.35f, 0.35f, 0.38f));
            for (int i = 0; i < 3; i++)
            {
                var r = new Rect(box.x + 130 + i * 111, box.y + 56, 105, 10);
                Fill(r, new Color(0.08f, 0.14f, 0.22f, 0.9f));
                float f = Mathf.Clamp01(p.stamina - i);
                Fill(new Rect(r.x, r.y, r.width * f, r.height), f >= 1 ? BLUE : new Color(0.2f, 0.4f, 0.65f));
            }
            Text(new Rect(box.x + 18, box.y + 78, 300, 32), w.CurName, new GUIStyle(sText) { fontSize = 26 }, w.CurAccent);
            Text(new Rect(box.x + 18, box.y + 108, 300, 24), w.CurSub, sSmall, GRAY);
            // yuvalar 1-5 + varyant noktaları
            for (int i = 0; i < UKWeapons.WEAPONS.Length; i++)
            {
                var r = new Rect(box.x + 290 + i * 36, box.y + 84, 30, 30);
                bool own = w.owned[i], cur = i == w.cur;
                var acc = UKWeapons.WEAPONS[i].variants[w.variant[i]].color;
                Fill(r, cur ? acc : own ? new Color(0.2f, 0.2f, 0.22f, 0.9f) : new Color(0.1f, 0.1f, 0.11f, 0.6f));
                Text(r, (i + 1).ToString(), sCenter, cur ? Color.black : own ? Color.white : new Color(0.35f, 0.35f, 0.38f), false);
                if (own)
                    for (int v = 0; v < 3; v++)
                        if (w.varOwned[i][v]) Fill(new Rect(r.x + 3 + v * 9, r.yMax + 3, 7, 4), v == w.variant[i] ? UKWeapons.WEAPONS[i].variants[v].color : new Color(0.4f, 0.4f, 0.42f));
            }
            // şarj göstergesi
            Charge(w, out string lab, out float fill, out int pips, out Color ccol);
            if (lab != null)
            {
                Text(new Rect(box.x + 18, box.y + 136, 160, 22), lab, sSmall, ccol);
                var bar = new Rect(box.x + 180, box.y + 142, 280, 10);
                if (pips > 0)
                    for (int i = 0; i < pips; i++)
                    {
                        var rr = new Rect(bar.x + i * (bar.width / pips), bar.y, bar.width / pips - 5, bar.height);
                        Fill(rr, new Color(0.15f, 0.15f, 0.17f));
                        float f = Mathf.Clamp01(fill * pips - i);
                        Fill(new Rect(rr.x, rr.y, rr.width * f, rr.height), f >= 1 ? ccol : ccol * 0.6f);
                    }
                else { Fill(bar, new Color(0.15f, 0.15f, 0.17f)); Fill(new Rect(bar.x, bar.y, bar.width * Mathf.Clamp01(fill), bar.height), ccol); }
            }
            // kol / kanca / tazelik
            string armTxt = "[F] " + UKWeapons.ARM_NAMES[w.arm] + (w.armsOwned[1] ? "  [G]" : "") + (w.hookOwned ? "   [E] WHIPLASH" : "");
            Text(new Rect(box.x + 18, box.y + 166, 360, 24), armTxt, sSmall, w.arm == 1 ? RED : BLUE);
            if (w.Armed)
            {
                var fr = G.style.Freshness(w.CurKey);
                Text(new Rect(box.x + 380, box.y + 166, 100, 24), fr.name, sSmall, fr.color);
            }
            if (wmsgT > 0) Text(new Rect(0, H * 0.62f, W, 40), wmsg, new GUIStyle(sCenter) { fontSize = 28 }, new Color(wmsgCol.r, wmsgCol.g, wmsgCol.b, Mathf.Clamp01(wmsgT * 3)));

            // üst sol: bölüm, süre, öldürme, gizli küre, P
            var L = G.level;
            Text(new Rect(36, 26, 700, 28), G.LevelDef.id + "  " + G.LevelDef.name + "   ·   " + G.Diff.name, sSmall, GRAY);
            string line = Fmt(G.stats.time) + (G.Endless ? "   DALGA " + G.cgWave : "   ÖLDÜRME " + G.stats.kills + "/" + L.totalEnemies) + (L.secrets.Count > 0 ? "   GİZLİ " + G.stats.secrets + "/" + L.secrets.Count : "");
            Text(new Rect(36, 48, 800, 28), line, sSmall, Color.white);
            Text(new Rect(36, 70, 500, 28), (G.progress.points + G.UnbankedP) + " P" + (G.UnbankedP > 0 ? "  (+" + G.UnbankedP + " kasada değil)" : ""), sSmall, GOLD);

            DrawStyle();
            DrawBoss();

            // dükkân uyarısı
            if (G.state == UKGame.State.Playing && L.NearShop != null)
            {
                var r = new Rect(W / 2 - 230, H * 0.66f, 460, 50);
                Fill(r, new Color(0.01f, 0.1f, 0.04f, 0.85f));
                Fill(new Rect(r.x, r.y, r.width, 3), TERM_OK);
                Text(r, "[B]  DÜKKÂN  ·  " + G.progress.points + " P", new GUIStyle(sCenter) { fontSize = 24 }, TERM_OK);
            }

            // başlık kartı, mesaj, ipucu
            if (titleT > 0)
            {
                float a = Mathf.Clamp01(Mathf.Min(titleT, titleDur - titleT) * 2.5f);
                Text(new Rect(0, H * 0.3f - 40, W, 40), titleA, new GUIStyle(sCenter) { fontSize = 24 }, titleBoss ? new Color(1f, 0.4f, 0.3f, a) : new Color(0.8f, 0.8f, 0.82f, a));
                Text(new Rect(0, H * 0.3f, W, 80), titleB, new GUIStyle(sHuge) { fontSize = titleBoss ? 80 : 64 }, titleBoss ? new Color(1f, 0.25f, 0.15f, a) : new Color(1, 1, 1, a));
                if (titleC != null) Text(new Rect(0, H * 0.3f + 82, W, 36), titleC, new GUIStyle(sCenter) { fontSize = 22 }, new Color(0.8f, 0.8f, 0.82f, a));
            }
            if (msgT > 0)
            {
                float a = Mathf.Clamp01(Mathf.Min(msgT, msgDur - msgT) * 4f);
                float sc = 1 + Mathf.Max(0, 0.15f - (msgDur - msgT)) * 2f;
                bool big = msgStyle == "big";
                Color mc = msgStyle == "cp" ? GREENC : msgStyle == "secret" ? new Color(0.5f, 0.78f, 1f) : big ? new Color(1f, 0.3f, 0.2f) : Color.white;
                mc.a = a;
                Text(new Rect(0, H * 0.2f, W, 60), msg, new GUIStyle(sBig) { fontSize = Mathf.RoundToInt((big ? 52 : msgStyle == "cp" ? 30 : 40) * sc) }, mc);
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
            if (!G.level.BossInfo(out string name, out float f, out bool enraged)) { bossGhost = 1; return; }
            bossGhost = Mathf.MoveTowards(bossGhost, f, Time.unscaledDeltaTime * 0.35f);
            if (bossGhost < f) bossGhost = f;
            var r = new Rect(W / 2 - 460, 74, 920, 22);
            Text(new Rect(r.x, r.y - 36, r.width, 32), name, sCenter, Color.white);
            Fill(new Rect(r.x - 3, r.y - 3, r.width + 6, r.height + 6), new Color(0, 0, 0, 0.7f));
            Fill(new Rect(r.x, r.y, r.width * bossGhost, r.height), new Color(1f, 0.85f, 0.4f));
            Fill(new Rect(r.x, r.y, r.width * f, r.height), enraged ? new Color(1f, 0.1f, 0.05f) : new Color(0.85f, 0.1f, 0.08f));
        }

        // ------------------------------------------------------------ menü (terminal)
        void DrawMenu()
        {
            Fill(new Rect(0, 0, W, H), new Color(0.01f, 0.01f, 0.01f, 0.72f));
            float x = 90, y = 60;
            var def = G.LevelDef;
            Text(new Rect(x, y, 1200, 30), "v1@araf:~$ ./ultrakill --unity --bolum " + def.id, sMono, TERM_DIM, false);
            y += 44;
            var lg = new GUIStyle(sMono) { fontSize = 24, alignment = TextAnchor.UpperLeft };
            Text(new Rect(x, y, 1600, 200), logo, lg, TERM_RED, false);
            y += 170;
            Text(new Rect(x, y, 1400, 30), def.layer + " /// " + def.id + " " + def.name, sMono, TERM, false);
            Text(new Rect(W - 520, 60, 440, 30), G.progress.points + " P", new GUIStyle(sMono) { fontSize = 26, alignment = TextAnchor.UpperRight }, GOLD, false);
            y += 56;
            var item = new GUIStyle(sMono) { fontSize = 30, alignment = TextAnchor.MiddleLeft };
            if (panel == Panel.Main)
            {
                if (Item(new Rect(x, y, 760, 44), "OYNA: " + def.id + " " + def.name, item, TERM, TERM_RED)) G.StartNew(G.levelIdx);
                y += 50;
                if (Item(new Rect(x, y, 760, 44), "BÖLÜM SEÇ", item, TERM, TERM_RED)) panel = Panel.Levels;
                y += 50;
                var d = UKGame.DIFFS[G.diffIndex];
                if (Item(new Rect(x, y, 760, 44), "ZORLUK: < " + d.name + " >", item, TERM, TERM_RED))
                {
                    G.diffIndex = (G.diffIndex + 1) % UKGame.DIFFS.Length;
                    PlayerPrefs.SetInt("uk.diff", G.diffIndex);
                }
                Text(new Rect(x + 40, y + 40, 900, 26), d.desc, new GUIStyle(sMono) { fontSize = 18 }, TERM_DIM, false);
                y += 78;
                if (G.progress.v2Unlocked)
                {
                    if (Item(new Rect(x, y, 760, 44), "KARAKTER: < " + (G.settings.v2 ? "V2" : "V1") + " >", item, TERM, TERM_RED)) { G.settings.v2 = !G.settings.v2; G.settings.Save(); }
                    Text(new Rect(x + 40, y + 40, 900, 26), G.settings.v2 ? "85 can · %12 daha hızlı · hızlı stamina · kırmızı kol" : "100 can · standart", new GUIStyle(sMono) { fontSize = 18 }, TERM_DIM, false);
                    y += 78;
                }
                if (Item(new Rect(x, y, 760, 44), "AYARLAR", item, TERM, TERM_RED)) panel = Panel.Settings;
                y += 50;
                if (Item(new Rect(x, y, 760, 44), "KONTROLLER", item, TERM, TERM_RED)) panel = Panel.Controls;
                y += 50;
                if (Item(new Rect(x, y, 760, 44), "ÇIKIŞ", item, TERM, TERM_RED)) Application.Quit();
                y += 60;
                if (G.progress.levels.TryGetValue(def.id, out var rec))
                    Text(new Rect(x, y, 900, 30), def.endless ? "EN YÜKSEK DALGA: " + rec.wave : "EN İYİ: " + rec.rank + "   " + Fmt(rec.time) + "   STİL " + Mathf.RoundToInt(rec.style), sMono, RankCol(rec.rank), false);
            }
            else if (panel == Panel.Levels) DrawLevels(new Rect(x, y, W - 180, H - y - 110));
            else if (panel == Panel.Settings) { if (SettingsPanel(new Rect(x, y, 900, 600), true)) panel = Panel.Main; }
            else { if (ControlsPanel(new Rect(x, y, 1300, 560), true)) panel = Panel.Main; }
            if (!UKInput.Available) Text(new Rect(x, H - 100, W - 180, 30), "GİRDİ YOK: Project Settings > Player > Active Input Handling = Both yapın.", new GUIStyle(sMono) { fontSize = 18 }, TERM_RED, false);
            Text(new Rect(x, H - 60, W - 180, 30), "Hayran yapımı, ticari değildir. ULTRAKILL; Arsi \"Hakita\" Patala ve New Blood Interactive'e aittir.", new GUIStyle(sMono) { fontSize = 16 }, TERM_DIM, false);
        }

        void DrawLevels(Rect area)
        {
            var LV = UKLevelDefs.LEVELS;
            var st = new GUIStyle(sMono) { fontSize = 24, alignment = TextAnchor.MiddleLeft };
            var small = new GUIStyle(sMono) { fontSize = 16, alignment = TextAnchor.MiddleLeft, wordWrap = true };
            float y = area.y;
            string layer = null;
            for (int i = 0; i < LV.Length; i++)
            {
                var d = LV[i];
                if (d.layer != layer) { layer = d.layer; Text(new Rect(area.x, y, 900, 26), "// " + layer, new GUIStyle(sMono) { fontSize = 18 }, TERM_DIM, false); y += 28; }
                bool open = G.Unlocked(i);
                G.progress.levels.TryGetValue(d.id, out var rec);
                string rank = rec == null ? "  -" : d.endless ? "  D" + rec.wave : "  " + rec.rank;
                var r = new Rect(area.x, y, 760, 34);
                bool sel = i == G.levelIdx;
                if (sel) Fill(new Rect(r.x - 10, r.y, 780, r.height), new Color(1f, 0.25f, 0.18f, 0.12f));
                if (Item(r, (open ? "" : "[KİLİTLİ] ") + d.id + "  " + d.name, st, sel ? TERM_OK : TERM, TERM_RED, open)) G.SelectLevel(i);
                if (rec != null) Text(new Rect(area.x + 770, y, 120, 34), rank, st, d.endless ? TERM_OK : RankCol(rec.rank), false);
                y += 36;
            }
            var def = G.LevelDef;
            var dr = new Rect(area.x + 920, area.y, Mathf.Min(620, W - area.x - 1000), 300);
            Text(new Rect(dr.x, dr.y, dr.width, 30), def.id + " " + def.name, new GUIStyle(sMono) { fontSize = 26 }, TERM_RED, false);
            Text(new Rect(dr.x, dr.y + 40, dr.width, 110), def.desc, small, TERM, false);
            var dummy = new UKResults();
            Text(new Rect(dr.x, dr.y + 150, dr.width, 30), "MEYDAN OKUMA: " + def.challengeText(dummy).Split('(')[0].Trim(), small, GOLD, false);
            if (!def.endless) Text(new Rect(dr.x, dr.y + 184, dr.width, 30), "S SÜRE < " + Fmt(def.time[0]) + "  ·  S STİL > " + def.style[0], small, TERM_DIM, false);
            float by = Mathf.Max(y + 16, dr.y + 240);
            if (Item(new Rect(dr.x, dr.y + 230, 400, 44), "OYNA", new GUIStyle(sMono) { fontSize = 30, alignment = TextAnchor.MiddleLeft }, TERM_OK, TERM_RED)) G.StartNew(G.levelIdx);
            if (Item(new Rect(area.x, by, 300, 44), "GERİ", new GUIStyle(sMono) { fontSize = 30, alignment = TextAnchor.MiddleLeft }, TERM, TERM_RED)) panel = Panel.Main;
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
                y += 42;
                if (!Mathf.Approximately(nv, v)) changed = true;
                return nv;
            }
            int Choice(string name, int v, string[] opts)
            {
                Text(new Rect(r.x, y, 330, 34), name, lab, col, false);
                for (int i = 0; i < opts.Length; i++)
                {
                    var br = new Rect(r.x + 340 + i * 112, y + 2, 106, 30);
                    bool on = i == v;
                    Fill(br, on ? new Color(0.9f, 0.2f, 0.12f, 0.9f) : new Color(0.15f, 0.15f, 0.17f, 0.9f));
                    Text(br, opts[i], new GUIStyle(sCenter) { fontSize = 16 }, Color.white, false);
                    if (GUI.Button(br, GUIContent.none, GUIStyle.none) && !on) { v = i; changed = true; UKAudio.I.Play("uiClick", 0.6f); }
                }
                y += 42;
                return v;
            }
            s.sensitivity = Slider("FARE HASSASİYETİ", s.sensitivity, 0.1f, 4f, "0.00");
            s.fov = Mathf.Round(Slider("GÖRÜŞ AÇISI (FOV)", s.fov, 80f, 130f, "0"));
            s.volume = Slider("ANA SES", s.volume, 0f, 1f, "0.00");
            s.music = Slider("MÜZİK", s.music, 0f, 1f, "0.00");
            s.shake = Slider("EKRAN SARSINTISI", s.shake, 0f, 1.5f, "0.00");
            s.aimAssist = Slider("NİŞAN YARDIMI", s.aimAssist, 0f, 2f, "0.00");
            string[] lvls = { "KAPALI", "HAFİF", "GÜÇLÜ" };
            s.parryAssist = Choice("PARRY YARDIMI", s.parryAssist, lvls);
            s.coinAssist = Choice("PARA YARDIMI", s.coinAssist, lvls);
            int inv = Choice("Y EKSENİ", s.invertY ? 1 : 0, new[] { "NORMAL", "TERS" });
            s.invertY = inv == 1;
            int allW = Choice("TÜM SİLAHLAR (TEST)", s.allWeapons ? 1 : 0, new[] { "KAPALI", "AÇIK" });
            s.allWeapons = allW == 1;
            y += 10;
            if (changed) s.Save();
            var bs = mono_ ? new GUIStyle(sMono) { fontSize = 30, alignment = TextAnchor.MiddleLeft } : null;
            if (mono_)
            {
                if (Item(new Rect(r.x + 420, y, 480, 44), resetArm ? "EMİN MİSİN? TEKRAR TIKLA" : "İLERLEMEYİ SIFIRLA", bs, TERM_DIM, TERM_RED))
                {
                    if (resetArm) { UKProgress.Wipe(); G.progress = UKProgress.Load(); resetArm = false; }
                    else resetArm = true;
                }
                return Item(new Rect(r.x, y, 300, 44), "GERİ", bs, TERM, TERM_RED);
            }
            return Button(new Rect(r.x, y, 300, 50), "GERİ");
        }
        bool resetArm;

        bool ControlsPanel(Rect r, bool mono_)
        {
            string[] lines =
            {
                "[W A S D]      hareket                 [FARE]          bak",
                "[BOŞLUK]       zıpla / havada duvara doğru: DUVAR SIÇRAMASI (3)",
                "[SHIFT]        atıl (hasarsız, 3 stamina) · atılırken zıpla: uzun sıçrayış",
                "[C] / [CTRL]   yerde KAY · havada YERE ÇAK → çarpınca zıpla: ÇAKIŞ SIÇRAYIŞI",
                "[SOL TIK]      ateş                    [SAĞ TIK]       alternatif atış / şarj",
                "[1]-[5]        silahlar · aynı tuş: VARYANT · [Q] son silah · [TEKERLEK] değiştir",
                "[F]            yumruk · mermiyi ya da PARLAYAN saldırıyı PARRY'le (canı doldurur)",
                "[G]            Feedbacker ⇄ Knuckleblaster      [E]  Whiplash kancası",
                "[B]            dükkân (yeşil terminalin önünde)  [ESC]  duraklat",
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
            Text(new Rect(0, 130, W, 80), "DURAKLATILDI", sHuge, Color.white);
            float x = W / 2 - 220, y = 250;
            if (panel == Panel.Settings) { if (SettingsPanel(new Rect(W / 2 - 450, y - 30, 900, 600), false)) panel = Panel.Main; return; }
            if (panel == Panel.Controls) { if (ControlsPanel(new Rect(W / 2 - 640, y, 1280, 560), false)) panel = Panel.Main; return; }
            if (Button(new Rect(x, y, 440, 54), "DEVAM ET")) G.Resume();
            if (Button(new Rect(x, y + 66, 440, 54), G.Endless ? "KOŞUYU BİTİR" : "SON CHECKPOINT", true)) G.Respawn(true);
            if (Button(new Rect(x, y + 132, 440, 54), "BÖLÜMÜ BAŞTAN BAŞLAT")) G.BeginLevel(G.levelIdx);
            if (Button(new Rect(x, y + 198, 440, 54), "AYARLAR")) panel = Panel.Settings;
            if (Button(new Rect(x, y + 264, 440, 54), "KONTROLLER")) panel = Panel.Controls;
            if (Button(new Rect(x, y + 330, 440, 54), "ANA MENÜ")) G.ToMenu();
            if (G.UnbankedP > 0) Text(new Rect(0, y + 400, W, 30), "Checkpoint'e dönersen kasaya girmemiş " + G.UnbankedP + " P kaybolur.", new GUIStyle(sCenter) { fontSize = 18 }, GRAY);
        }

        // ------------------------------------------------------------ dükkân
        void DrawShop()
        {
            var prog = G.progress;
            bool all = G.settings.allWeapons;
            Fill(new Rect(0, 0, W, H), new Color(0, 0.02f, 0.01f, 0.86f));
            var box = new Rect(W / 2 - 700, 70, 1400, H - 140);
            Fill(box, new Color(0.01f, 0.06f, 0.03f, 0.95f));
            Fill(new Rect(box.x, box.y, box.width, 4), TERM_OK);
            var mono_ = new GUIStyle(sMono) { fontSize = 24, alignment = TextAnchor.MiddleLeft };
            Text(new Rect(box.x + 30, box.y + 16, 600, 40), "DÜKKÂN — V1 TEDARİK TERMİNALİ", new GUIStyle(sMono) { fontSize = 30, alignment = TextAnchor.MiddleLeft }, TERM_OK, false);
            Text(new Rect(box.xMax - 430, box.y + 16, 400, 40), prog.points + " P", new GUIStyle(sMono) { fontSize = 32, alignment = TextAnchor.MiddleRight }, GOLD, false);
            if (all) Text(new Rect(box.x + 30, box.y + 52, 900, 26), "TEST MODU: tüm silahlar açık (ayarlardan kapatılabilir)", new GUIStyle(sMono) { fontSize = 16 }, TERM_DIM, false);
            // sekmeler
            float tx = box.x + 30, ty = box.y + 84;
            for (int i = 0; i < UKShop.GROUPS.Length; i++)
            {
                var r = new Rect(tx, ty, 186, 40);
                bool on = i == shopTab;
                Fill(r, on ? new Color(0.1f, 0.45f, 0.2f, 0.95f) : new Color(0.04f, 0.14f, 0.08f, 0.95f));
                Text(r, UKShop.GROUPS[i][1], new GUIStyle(sCenter) { fontSize = 15 }, on ? Color.white : TERM_OK, false);
                if (GUI.Button(r, GUIContent.none, GUIStyle.none)) { shopTab = i; UKAudio.I.Play("uiClick", 0.6f); }
                tx += 192;
            }
            // öğeler
            string grp = UKShop.GROUPS[shopTab][0];
            float y = ty + 64;
            foreach (var it in UKShop.ITEMS)
            {
                if (it.group != grp) continue;
                var r = new Rect(box.x + 30, y, box.width - 60, 84);
                Fill(r, new Color(0.03f, 0.1f, 0.05f, 0.95f));
                Fill(new Rect(r.x, r.y, 6, r.height), it.color);
                bool owned = prog.Has(it.id) || all;
                bool locked = it.needs != null && !prog.Has(it.needs) && !all;
                Text(new Rect(r.x + 24, r.y + 8, 700, 36), it.name, new GUIStyle(sText) { fontSize = 28 }, it.color);
                Text(new Rect(r.x + 24, r.y + 46, 900, 28), it.sub + (locked ? "   · önce " + (UKShop.Find(it.needs)?.name ?? it.needs) + " gerekli" : ""), sSmall, locked ? TERM_RED : GRAY);
                var br = new Rect(r.xMax - 300, r.y + 16, 280, 52);
                if (it.alt != null && owned)
                {
                    bool on = prog.AltOn(it.alt);
                    if (Button(br, on ? "ÇIKAR" : "KULLAN", true, TERM_OK)) G.ToggleAlt(it.id);
                    Text(new Rect(br.x - 220, br.y, 200, 52), on ? "TAKILI" : "SAHİP", new GUIStyle(sMono) { fontSize = 20, alignment = TextAnchor.MiddleRight }, TERM_OK, false);
                }
                else if (owned) Text(br, "SAHİP ✓", new GUIStyle(sMono) { fontSize = 24, alignment = TextAnchor.MiddleCenter }, TERM_OK, false);
                else
                {
                    bool can = !locked && prog.points >= it.price;
                    if (Button(br, it.price + " P  SATIN AL", can, TERM_OK)) G.Buy(it.id);
                }
                y += 94;
            }
            if (grp == "revolver") Text(new Rect(box.x + 30, y, 1200, 30), "REVOLVER (PIERCER) ücretsizdir. Varyant: silah tuşuna tekrar bas.", new GUIStyle(sMono) { fontSize = 18 }, TERM_DIM, false);
            if (Button(new Rect(box.x + 30, box.yMax - 74, 360, 54), "KAPAT  [B] / [ESC]", true, TERM_OK)) G.CloseShop();
            Text(new Rect(box.x + 420, box.yMax - 74, 900, 54), "P: stil puanın. Checkpoint, dükkân ve bölüm sonunda kasaya girer; ölünce kasaya girmemiş P kaybolur.", new GUIStyle(sMono) { fontSize = 16, alignment = TextAnchor.MiddleLeft, wordWrap = true }, TERM_DIM, false);
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
            if (G.lostP > 0) Text(new Rect(0, jr.yMax + 84, W, 30), "-" + G.lostP + " P (kasaya girmemişti)", new GUIStyle(sCenter) { fontSize = 20 }, new Color(1, 0.8f, 0.3f, pop));
            if (t > 1.0f && Mathf.Repeat(Time.unscaledTime, 1f) < 0.7f)
                Text(new Rect(0, jr.yMax + 124, W, 40), G.Endless ? "[R] / [TIKLA]  →  KOŞUYU BİTİR" : "[R] / [TIKLA]  →  SON KONTROL NOKTASI", sCenter, new Color(1, 1, 1, 0.85f));
        }

        // ------------------------------------------------------------ sonuç ekranı (düşerken)
        void DrawResults()
        {
            var r = G.results;
            if (r == null) return;
            float t = G.resultsT;
            float slide = 1 - Mathf.Pow(1 - Mathf.Clamp01(t / 0.6f), 3);
            var box = new Rect(W - 40 - 680 * slide, 60, 680, 900);
            Fill(box, new Color(0.04f, 0.04f, 0.05f, 0.88f));
            Fill(new Rect(box.x, box.y, box.width, 4), RED);
            Text(new Rect(box.x + 30, box.y + 16, 620, 30), G.LevelDef.layer + "   ·   " + r.difficulty, sSmall, GRAY);
            Text(new Rect(box.x + 30, box.y + 40, 620, 50), r.levelTitle, new GUIStyle(sText) { fontSize = 32 }, Color.white);
            string[] names, vals, ranks;
            if (r.endless)
            {
                names = new[] { "DALGA", "ÖLDÜRME", "STİL" };
                vals = new[] { r.wave + "  (en iyi " + r.bestWave + ")", r.kills.ToString(), Mathf.RoundToInt(r.style).ToString() };
                ranks = new[] { r.final, "", "" };
            }
            else
            {
                names = new[] { "SÜRE", "ÖLDÜRME", "STİL" };
                vals = new[] { Fmt(r.time), r.kills + " / " + r.killsTotal, Mathf.RoundToInt(r.style).ToString() };
                ranks = new[] { r.timeRank, r.killRank, r.styleRank };
            }
            for (int i = 0; i < 3; i++)
            {
                float at = 0.8f + i * 0.5f;
                if (t < at) break;
                float y = box.y + 110 + i * 82;
                Fill(new Rect(box.x + 30, y, 620, 70), new Color(1, 1, 1, 0.04f));
                Text(new Rect(box.x + 50, y, 250, 70), names[i], new GUIStyle(sText) { fontSize = 26 }, GRAY);
                Text(new Rect(box.x + 230, y, 330, 70), vals[i], new GUIStyle(sText) { fontSize = 28 }, Color.white);
                if (t > at + 0.3f && ranks[i] != "") Text(new Rect(box.x + 560, y, 80, 70), ranks[i], new GUIStyle(sRank) { fontSize = 48, alignment = TextAnchor.MiddleCenter }, RankCol(ranks[i]));
            }
            float ty = box.y + 360;
            if (t > 2.4f)
            {
                var sm = new GUIStyle(sText) { fontSize = 20 };
                if (!r.endless) Text(new Rect(box.x + 50, ty, 600, 30), "GİZLİ KÜRE  " + r.secrets + " / " + r.secretsTotal + "     PARRY  " + r.parries + "     ÖLÜM  " + r.restarts, sm, GRAY);
                else Text(new Rect(box.x + 50, ty, 600, 30), "PARRY  " + r.parries + "     SÜRE  " + Fmt(r.time), sm, GRAY);
                Text(new Rect(box.x + 50, ty + 36, 600, 30), (r.challenge ? "✓ " : "✗ ") + "MEYDAN OKUMA: " + r.challengeText, sm, r.challenge ? GREENC : new Color(1f, 0.5f, 0.4f));
                Text(new Rect(box.x + 50, ty + 72, 600, 30), "+" + r.pointsEarned + " P  (ödül " + r.rankBonus + ")     TOPLAM " + r.pointsTotal + " P", sm, GOLD);
            }
            float ft = 3.0f;
            if (t > ft)
            {
                float k = Mathf.Clamp01((t - ft) / 0.2f);
                float y = box.y + 480;
                Text(new Rect(box.x + 50, y, 250, 120), "SONUÇ", new GUIStyle(sText) { fontSize = 32 }, Color.white);
                Text(new Rect(box.x + 330, y, 250, 120), r.final, new GUIStyle(sRank) { fontSize = Mathf.RoundToInt(120 * (1.6f - 0.6f * k)), alignment = TextAnchor.MiddleCenter }, RankCol(r.final));
                if (r.newBest) Text(new Rect(box.x + 50, y + 90, 300, 30), "YENİ REKOR!", new GUIStyle(sText) { fontSize = 22 }, GOLD);
            }
            if (!string.IsNullOrEmpty(r.finale) && t > 3.4f)
                Text(new Rect(box.x + 30, box.y + 630, 620, 60), r.finale, new GUIStyle(sHint) { fontSize = 20 }, new Color(1f, 0.55f, 0.35f));
            if (t > 3.5f)
            {
                float by = box.y + 700;
                if (r.hasNext && !r.endless) { if (Button(new Rect(box.x + 30, by, 620, 54), "SONRAKİ BÖLÜM  [ENTER]")) G.NextLevel(); by += 64; }
                if (Button(new Rect(box.x + 30, by, 300, 54), "TEKRAR  [R]")) G.BeginLevel(G.levelIdx);
                if (Button(new Rect(box.x + 350, by, 300, 54), "ANA MENÜ")) G.ToMenu();
            }
        }
    }
}
