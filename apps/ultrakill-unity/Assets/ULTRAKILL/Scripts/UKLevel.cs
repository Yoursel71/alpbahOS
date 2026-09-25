// Bölüm 0-1 "ATEŞİN İÇİNE" (Unity sürümü): üsten bacadan düşerek iniş odası, atılma boşluğu,
// ARENA 1 (Filth + Stray), lav koridoru, ARENA 2 (Drone + Stray + Filth), boss SWORDSMACHINE ve
// boss ölünce açılan çıkış kapağı: kapaktan düşerken sonuç ekranı gelir.
// Tüm geometri kodla kutulardan kurulur (dünya ölçekli UV'li dokular, BoxCollider).
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKArena
    {
        public struct SpawnDef { public string t; public Vector3 p; public SpawnDef(string t, Vector3 p) { this.t = t; this.p = p; } }
        public string name;
        public Bounds trigger;
        public string[] lockDoors = new string[0], exitDoors = new string[0];
        public readonly List<List<SpawnDef>> waves = new List<List<SpawnDef>>();
        public Vector3 checkpoint;
        public float checkpointYaw;
        public bool isBoss, started, cleared, advancing;
        public int wave = -1, alive, pending;
        public System.Action onStart, onClear;
        public int Total { get { int n = 0; foreach (var w in waves) n += w.Count; return n; } }
    }

    public class UKDoor
    {
        public string id;
        public Transform t;
        public Vector3 closedPos, openPos;
        public bool open;
        public Renderer strip;
        float k;

        public void Set(bool o, bool instant = false)
        {
            if (o != open && !instant) UKAudio.I.PlayAt("door", t.position);
            open = o;
            if (instant) { k = o ? 1 : 0; t.position = Vector3.Lerp(closedPos, openPos, k); }
            if (strip) strip.sharedMaterial = UKFx.Unlit(o ? new Color(0.3f, 1f, 0.45f) : new Color(1f, 0.2f, 0.12f));
        }

        public void Tick(float dt)
        {
            float target = open ? 1 : 0;
            if (Mathf.Approximately(k, target)) return;
            k = Mathf.MoveTowards(k, target, dt / 0.55f);
            t.position = Vector3.Lerp(closedPos, openPos, k * k * (3 - 2 * k));
        }
    }

    public class UKLevel : MonoBehaviour
    {
        public string levelId = "0-1", levelName = "ATEŞİN İÇİNE", layerName = "KATMAN 0: ARAF";
        public float killY = -60f;
        public Vector3 spawnPos = new Vector3(0, 64, 0), startCheckpoint = new Vector3(0, 0.05f, 0);
        public Vector3 menuCamCenter = new Vector3(0, 5, 50);
        public readonly float[] timeThresh = { 150, 210, 280, 360 };   // S, A, B, C (saniye)
        public readonly float[] styleThresh = { 4000, 2800, 1800, 900 };
        public readonly List<UKArena> arenas = new List<UKArena>();
        public readonly Dictionary<string, UKDoor> doors = new Dictionary<string, UKDoor>();
        readonly List<Bounds> lava = new List<Bounds>(), pits = new List<Bounds>();
        readonly List<KeyValuePair<Bounds, string>> hints = new List<KeyValuePair<Bounds, string>>();
        readonly HashSet<int> hintsShown = new HashSet<int>();
        readonly List<Light> flicker = new List<Light>();
        readonly List<float> flickerBase = new List<float>();
        Bounds exitBounds;
        Material lavaMat;
        Transform root;
        readonly Dictionary<string, Material> mats = new Dictionary<string, Material>();
        public int TotalEnemies { get { int n = 0; foreach (var a in arenas) n += a.Total; return n; } }

        // ------------------------------------------------------------ yapı yardımcıları
        Material Mat(string key)
        {
            if (mats.TryGetValue(key, out var m)) return m;
            switch (key)
            {
                case "stone": m = UKFx.Lit(new Color(0.95f, 0.9f, 0.88f), 0, UKFx.TexStone); break;
                case "tiles": m = UKFx.Lit(new Color(0.95f, 0.92f, 0.9f), 0, UKFx.TexTiles); break;
                case "metal": m = UKFx.Lit(new Color(0.9f, 0.9f, 0.95f), 0, UKFx.TexMetal); break;
                case "rock": m = UKFx.Lit(new Color(0.9f, 0.8f, 0.78f), 0, UKFx.TexRock); break;
                case "door": m = UKFx.Lit(new Color(0.75f, 0.62f, 0.5f), 0, UKFx.TexMetal); break;
                case "lava":
                    m = new Material(UKFx.Lit(new Color(1f, 0.5f, 0.15f), 1.4f, UKFx.TexRock));
                    lavaMat = m;
                    break;
                default: m = UKFx.Lit(Color.gray); break;
            }
            mats[key] = m;
            return m;
        }

        GameObject Box(float x0, float y0, float z0, float x1, float y1, float z1, string mat = "stone", bool solid = true, float texScale = 4f)
        {
            var size = new Vector3(Mathf.Abs(x1 - x0), Mathf.Abs(y1 - y0), Mathf.Abs(z1 - z0));
            var go = new GameObject(mat);
            go.transform.SetParent(root, false);
            go.transform.position = new Vector3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
            go.AddComponent<MeshFilter>().sharedMesh = UKFx.BoxMesh(size, texScale);
            go.AddComponent<MeshRenderer>().sharedMaterial = Mat(mat);
            if (solid) go.AddComponent<BoxCollider>().size = size;
            return go;
        }

        static Bounds B(float x0, float y0, float z0, float x1, float y1, float z1)
        {
            var b = new Bounds();
            b.SetMinMax(new Vector3(Mathf.Min(x0, x1), Mathf.Min(y0, y1), Mathf.Min(z0, z1)), new Vector3(Mathf.Max(x0, x1), Mathf.Max(y0, y1), Mathf.Max(z0, z1)));
            return b;
        }

        UKDoor Door(string id, float x0, float y0, float z0, float x1, float y1, float z1, bool open, Vector3? slide = null)
        {
            var go = Box(x0, y0, z0, x1, y1, z1, "door", true, 2f);
            var d = new UKDoor { id = id, t = go.transform };
            d.closedPos = go.transform.position;
            d.openPos = d.closedPos + (slide ?? new Vector3(0, Mathf.Abs(y1 - y0) + 0.1f, 0));
            // kilit şeridi: kırmızı = kilitli, yeşil = açık (yer kapağında yok)
            var size = go.GetComponent<BoxCollider>().size;
            if (size.y >= 1f)
            {
                bool thinX = size.x < size.z;
                var s = UKFx.Part(go.transform, Vector3.zero, thinX ? new Vector3(size.x + 0.04f, 0.18f, size.z * 0.9f) : new Vector3(size.x * 0.9f, 0.18f, size.z + 0.04f), UKFx.Unlit(Color.red));
                d.strip = s.GetComponent<Renderer>();
            }
            doors[id] = d;
            d.Set(open, true);
            return d;
        }

        Light AddLight(Vector3 p, Color c, float range, float intensity, bool flick = true)
        {
            var l = new GameObject("light").AddComponent<Light>();
            l.transform.SetParent(root, false);
            l.transform.position = p;
            l.type = LightType.Point;
            l.color = c;
            l.range = range;
            l.intensity = intensity * UKFx.LightMul;
            l.shadows = LightShadows.None;
            if (flick) { flicker.Add(l); flickerBase.Add(intensity * UKFx.LightMul); }
            return l;
        }

        void Torch(float x, float y, float z)
        {
            UKFx.Part(root, new Vector3(x, y - 0.3f, z), new Vector3(0.12f, 0.6f, 0.12f), UKFx.Lit(new Color(0.25f, 0.2f, 0.18f)));
            UKFx.Part(root, new Vector3(x, y + 0.08f, z), new Vector3(0.2f, 0.28f, 0.2f), UKFx.Unlit(new Color(1f, 0.62f, 0.2f)));
            AddLight(new Vector3(x, y + 0.4f, z), new Color(1f, 0.6f, 0.3f), 9, 1.3f);
        }

        void Brazier(float x, float y, float z)
        {
            var dark = UKFx.Lit(new Color(0.3f, 0.28f, 0.27f), 0, UKFx.TexMetal);
            UKFx.Part(root, new Vector3(x, y + 0.45f, z), new Vector3(0.22f, 0.9f, 0.22f), dark);
            UKFx.Part(root, new Vector3(x, y + 0.95f, z), new Vector3(0.9f, 0.3f, 0.9f), dark);
            UKFx.Part(root, new Vector3(x, y + 1.25f, z), new Vector3(0.6f, 0.45f, 0.6f), UKFx.Unlit(new Color(1f, 0.55f, 0.15f)));
            UKFx.Part(root, new Vector3(x, y + 1.5f, z), new Vector3(0.3f, 0.4f, 0.3f), UKFx.Unlit(new Color(1f, 0.85f, 0.4f)));
            AddLight(new Vector3(x, y + 2f, z), new Color(1f, 0.55f, 0.25f), 13, 1.7f);
        }

        void Lava(float x0, float y, float z0, float x1, float z1, float depth = 1.2f)
        {
            Box(x0, y - 0.4f, z0, x1, y, z1, "lava", false, 6f);
            lava.Add(B(x0, y - depth, z0, x1, y + 0.3f, z1));
        }

        void Hint(Bounds b, string text) => hints.Add(new KeyValuePair<Bounds, string>(b, text));

        UKArena Arena(string name, Bounds trigger, Vector3 cp, string[] locks, string[] exits)
        {
            var a = new UKArena { name = name, trigger = trigger, checkpoint = cp, lockDoors = locks, exitDoors = exits };
            arenas.Add(a);
            return a;
        }

        static List<UKArena.SpawnDef> Wave(params object[] defs)
        {
            var l = new List<UKArena.SpawnDef>();
            for (int i = 0; i + 1 < defs.Length; i += 2) l.Add(new UKArena.SpawnDef((string)defs[i], (Vector3)defs[i + 1]));
            return l;
        }

        static Vector3 V(float x, float y, float z) => new Vector3(x, y, z);

        // ------------------------------------------------------------ kurulum
        public void Build()
        {
            if (root) Destroy(root.gameObject);
            root = new GameObject("Level " + levelId).transform;
            root.SetParent(transform, false);
            arenas.Clear(); doors.Clear(); lava.Clear(); pits.Clear(); hints.Clear(); hintsShown.Clear(); flicker.Clear(); flickerBase.Clear(); mats.Clear();

            // ===== İNİŞ ODASI + BACA (x -8..8, z -8..8): üsten düşülerek girilir
            Box(-9, -2, -9, 9, 0, 9, "tiles");
            Box(-9, 0, -9, -8, 15, 9); Box(8, 0, -9, 9, 15, 9); Box(-8, 0, -9, 8, 15, -8);
            Box(-8, 0, 8, -3, 15, 9); Box(3, 0, 8, 8, 15, 9); Box(-3, 6, 8, 3, 15, 9);
            Box(-8, 14, -8, 8, 15, -5, "rock"); Box(-8, 14, 5, 8, 15, 8, "rock"); Box(-8, 14, -5, -5, 15, 5, "rock"); Box(5, 14, -5, 8, 15, 5, "rock");
            Box(-6, 15, -6, -5, 71, 6, "metal"); Box(5, 15, -6, 6, 71, 6, "metal"); Box(-5, 15, -6, 5, 71, -5, "metal"); Box(-5, 15, 5, 5, 71, 6, "metal");
            Box(-6, 71, -6, 6, 72, 6, "metal");
            for (int i = 0; i < 4; i++) { Torch(-4.6f, 22 + i * 13, 0); Torch(4.6f, 28 + i * 13, 0); }
            Brazier(-6, 0, 6); Brazier(6, 0, 6); Brazier(-6, 0, -6); Brazier(6, 0, -6);
            for (int i = 0; i < 6; i++) UKFx.Part(root, V(0, 0.01f, -6 + i * 2.4f), V(0.25f, 0.02f, 1.2f), UKFx.Unlit(new Color(0.8f, 0.12f, 0.08f)));
            Hint(B(-8, -1, -8, 8, 4, 8), "[WASD] yürü · [BOŞLUK] zıpla · [SHIFT] atıl · [C] kay / havada YERE ÇAK · [F] yumruk ve PARRY · [1][2][3] silahlar. Kuzeydeki kapıdan ilerle.");

            // ===== ATILMA BOŞLUĞU (x -3..3, z 9..34; boşluk z 14..26)
            Box(-3, -2, 9, 3, 0, 14, "tiles"); Box(-3, -2, 26, 3, 0, 34, "tiles");
            Box(-3, -18, 14, 3, -16.4f, 26, "rock");
            Lava(-3, -16, 14, 3, 26, 3);
            Box(-4, -18, 9, -3, 8, 34); Box(3, -18, 9, 4, 8, 34); Box(-4, 8, 9, 4, 9, 33, "rock");
            pits.Add(B(-3, -17, 14, 3, -5, 26));
            Torch(-2.7f, 5, 12); Torch(2.7f, 5, 29); AddLight(V(0, -13, 20), new Color(1f, 0.45f, 0.1f), 16, 2.2f);
            Hint(B(-3, -1, 9, 3, 4, 13.5f), "Boşluk normal zıplamaya fazla geniş! [SHIFT] ile atıl, atılırken [BOŞLUK] → ATILMA ZIPLAMASI. Kayarken ([C]) zıplamak da uzağa fırlatır.");

            // ===== ARENA 1 (x -16..16, z 34..66)
            Box(-17, -2, 33, 17, 0, 67, "tiles");
            Box(-17, 0, 34, -16, 16, 66); Box(16, 0, 34, 17, 16, 66);
            Box(-17, 0, 33, -3, 16, 34); Box(3, 0, 33, 17, 16, 34); Box(-3, 8, 33, 3, 16, 34);
            Box(-17, 0, 66, -3, 16, 67); Box(3, 0, 66, 17, 16, 67); Box(-3, 6, 66, 3, 16, 67);
            Box(-17, 16, 33, 17, 17, 67, "rock");
            Door("a1in", -3, 0, 33.2f, 3, 8, 33.8f, true);
            Door("a1out", -3, 0, 66.2f, 3, 6, 66.8f, false);
            Box(-16, 0, 34, -5, 3, 39); Box(5, 0, 34, 16, 3, 39);
            foreach (var pz in new[] { V(-9, 0, 45), V(9, 0, 45), V(-9, 0, 57), V(9, 0, 57) })
            {
                Box(pz.x - 1, 0, pz.z - 1, pz.x + 1, 10, pz.z + 1);
                Box(pz.x - 1.3f, 10, pz.z - 1.3f, pz.x + 1.3f, 10.4f, pz.z + 1.3f, "metal");
                Box(pz.x - 1.3f, 0, pz.z - 1.3f, pz.x + 1.3f, 0.4f, pz.z + 1.3f, "metal");
            }
            Box(-5, 0, 48, -2, 1.2f, 49.5f, "metal"); Box(2, 0, 53, 5, 1.2f, 54.5f, "metal");
            Brazier(-14, 0, 63); Brazier(14, 0, 63); Brazier(-14, 3, 37); Brazier(14, 3, 37);
            {
                var a = Arena("ARENA 1", B(-15, -1, 39, 15, 6, 65), V(0, 0.05f, 36), new[] { "a1in" }, new[] { "a1out" });
                a.waves.Add(Wave("filth", V(-8, 0, 60), "filth", V(8, 0, 60), "filth", V(0, 0, 62)));
                a.waves.Add(Wave("filth", V(-13, 0, 50), "filth", V(13, 0, 50), "filth", V(-6, 0, 62), "filth", V(6, 0, 62), "stray", V(-11, 3, 36.5f), "stray", V(11, 3, 36.5f)));
                a.onStart = () => UKGame.I.hud.Hint("Arena kilitlendi! Hepsini öldür — kapılar alan temizlenince açılır. Kafadan vuruş 2x, havadaki düşmanı vurmak +AIRSHOT.", 8);
            }

            // ===== LAV KORİDORU (x -4..4, z 66..93)
            Box(-4, -2, 66, 4, 0, 69, "tiles"); Box(-4, -2, 91, 4, 0, 93, "tiles");
            Box(-4, -3, 69, 4, -1.6f, 91, "rock");
            Lava(-4, -1.2f, 69, 4, 91);
            foreach (var pz in new[] { V(-1.6f, 0, 73), V(1.6f, 0, 77.5f), V(-1.6f, 0, 82), V(1.6f, 0, 86.5f) })
                Box(pz.x - 1.2f, -1.6f, pz.z - 1.2f, pz.x + 1.2f, 0.2f, pz.z + 1.2f, "metal");
            Box(-5, -3, 66, -4, 10, 93); Box(4, -3, 66, 5, 10, 93); Box(-5, 10, 67, 5, 11, 92, "rock");
            AddLight(V(0, 1, 75), new Color(1f, 0.45f, 0.12f), 12, 1.8f); AddLight(V(0, 1, 85), new Color(1f, 0.45f, 0.12f), 12, 1.8f);
            Hint(B(-4, -1, 67, 4, 4, 69.5f), "LAV! Platformlardan zıpla ya da duvardan sek ([BOŞLUK] havada duvara doğru). Lava düşersen yanarsın ve havaya fırlarsın.");

            // ===== ARENA 2 (x -18..18, z 93..127)
            Box(-19, -2, 92, 19, 0, 128, "tiles");
            Box(-19, 0, 93, -18, 17, 127); Box(18, 0, 93, 19, 17, 127);
            Box(-19, 0, 92, -4, 17, 93); Box(4, 0, 92, 19, 17, 93); Box(-4, 10, 92, 4, 17, 93);
            Box(-19, 0, 127, -3, 17, 128); Box(3, 0, 127, 19, 17, 128); Box(-3, 6, 127, 3, 17, 128);
            Box(-19, 17, 92, 19, 18, 128, "rock");
            Door("a2in", -4, 0, 92.2f, 4, 10, 92.8f, true);
            Door("a2out", -3, 0, 127.2f, 3, 6, 127.8f, false);
            Box(-5, 0, 106, 5, 2.5f, 114, "metal"); Box(-2, 0, 104, 2, 1.25f, 106, "metal");
            Box(-18, 0, 100, -12, 4, 120); Box(12, 0, 100, 18, 4, 120);
            Box(-12, 0, 108, -10, 2, 112, "metal"); Box(10, 0, 108, 12, 2, 112, "metal");
            Brazier(-15, 4, 103); Brazier(15, 4, 117); Brazier(-8, 0, 124); Brazier(8, 0, 124);
            {
                var a = Arena("ARENA 2", B(-17, -1, 97, 17, 7, 126), V(0, 0.05f, 95), new[] { "a2in" }, new[] { "a2out" });
                a.waves.Add(Wave("drone", V(-8, 6, 120), "drone", V(8, 6, 120), "filth", V(0, 0, 123), "filth", V(-4, 0, 123), "filth", V(4, 0, 123)));
                a.waves.Add(Wave("stray", V(-15, 4, 110), "stray", V(15, 4, 110), "drone", V(0, 7, 100), "filth", V(-10, 0, 100), "filth", V(10, 0, 100), "filth", V(0, 2.5f, 110)));
                a.onStart = () => UKGame.I.hud.Hint("DRONE'lar uçar ve mavi küre atar. Küreler ve PARLAYAN saldırılar [F] ile PARRY'lenir: geri döner, canın tamamen dolar.", 8);
            }

            // ===== BOSS KORİDORU + ODASI (x -20..20, z 136..172)
            Box(-3, -2, 128, 3, 0, 136, "tiles");
            Box(-4, 0, 128, -3, 6, 135); Box(3, 0, 128, 4, 6, 135); Box(-4, 6, 128, 4, 7, 135, "rock");
            Box(-21, -2, 135, 21, 0, 152, "tiles"); Box(-21, -2, 156, 21, 0, 173, "tiles");
            Box(-21, -2, 152, -2, 0, 156, "tiles"); Box(2, -2, 152, 21, 0, 156, "tiles");
            Box(-21, 0, 136, -20, 20, 172); Box(20, 0, 136, 21, 20, 172);
            Box(-21, 0, 135, -3, 20, 136); Box(3, 0, 135, 21, 20, 136); Box(-3, 6, 135, 3, 20, 136);
            Box(-21, 0, 172, 21, 20, 173);
            Box(-21, 20, 135, 21, 21, 173, "rock");
            Door("bossIn", -3, 0, 135.2f, 3, 6, 135.8f, true);
            Door("hatch", -2, -0.35f, 152, 2, -0.02f, 156, false, new Vector3(4.3f, 0, 0));
            foreach (var pz in new[] { V(-12, 0, 146), V(12, 0, 146), V(-12, 0, 162), V(12, 0, 162) })
                Box(pz.x - 1.2f, 0, pz.z - 1.2f, pz.x + 1.2f, 20, pz.z + 1.2f);
            Brazier(-17, 0, 139); Brazier(17, 0, 139); Brazier(-17, 0, 169); Brazier(17, 0, 169);
            for (int i = 0; i < 4; i++)
            {
                float a = i * Mathf.PI / 2;
                UKFx.Part(root, V(Mathf.Cos(a) * 2.25f, 0.01f, 154 + Mathf.Sin(a) * 2.25f), i % 2 == 0 ? V(0.25f, 0.02f, 4.7f) : V(4.7f, 0.02f, 0.25f), UKFx.Unlit(new Color(1f, 0.25f, 0.12f)));
            }
            // kapağın altındaki sonsuz baca (sonuç ekranı düşüşü)
            Box(-3, -230, 151, -2, -2, 157, "metal"); Box(2, -230, 151, 3, -2, 157, "metal");
            Box(-2, -230, 151, 2, -2, 152, "metal"); Box(-2, -230, 156, 2, -2, 157, "metal");
            for (int i = 0; i < 11; i++) AddLight(V(i % 2 == 0 ? -1.6f : 1.6f, -10 - i * 20, 154), new Color(1f, 0.35f, 0.15f), 14, 1.6f, false);
            exitBounds = B(-2, -14, 152, 2, -1.2f, 156);
            {
                var a = Arena("SWORDSMACHINE", B(-19, -1, 140, 19, 8, 171), V(0, 0.05f, 137.5f), new[] { "bossIn" }, new string[0]);
                a.isBoss = true;
                a.waves.Add(Wave("sword", V(0, 0, 163)));
                a.onStart = () =>
                {
                    UKAudio.I.Play("bossRoar");
                    UKGame.I.hud.Hint("Kılıç kombosunun SON vuruşu parlar — tam o an [F] ile PARRY'le! Uzaktan pompalı ve atılma saldırısı yapar.", 8);
                };
                a.onClear = () => UKGame.I.Schedule(2.2f, () =>
                {
                    doors["hatch"].Set(true);
                    AddLight(V(0, 1.5f, 154), new Color(0.4f, 1f, 0.5f), 8, 2.5f, false);
                    UKGame.I.hud.Message("ÇIKIŞ AÇILDI", 2);
                    UKGame.I.hud.Hint("Ortadaki kapaktan aşağı atla.", 6);
                });
            }
            // yeni çarpıştırıcılar aynı karedeki ışın sorgularında görünsün
            Physics.SyncTransforms();
        }

        // ------------------------------------------------------------ çalışma anı
        public bool InLava(Vector3 p)
        {
            foreach (var b in lava) if (b.Contains(p)) return true;
            return false;
        }

        public void CheckHazards(UKPlayer p)
        {
            Vector3 pos = p.transform.position + Vector3.up * 0.1f;
            if (InLava(pos)) p.LavaHit(15);
            foreach (var b in pits) if (b.Contains(pos)) { p.OutOfBounds(20); return; }
            if (exitBounds.Contains(pos) && doors.TryGetValue("hatch", out var h) && h.open) UKGame.I.FinishLevel();
        }

        public void Tick(float dt)
        {
            foreach (var d in doors.Values) d.Tick(dt);
            float t = Time.time;
            for (int i = 0; i < flicker.Count; i++)
                if (flicker[i]) flicker[i].intensity = flickerBase[i] * (0.82f + 0.18f * Mathf.PerlinNoise(t * 7f, i * 3.1f));
            if (lavaMat) lavaMat.mainTextureOffset = new Vector2(t * 0.04f, t * 0.025f);

            var game = UKGame.I;
            if (game.state != UKGame.State.Playing || game.player.dead) return;
            Vector3 pp = game.player.transform.position + Vector3.up * 0.5f;
            for (int i = 0; i < hints.Count; i++)
                if (!hintsShown.Contains(i) && hints[i].Key.Contains(pp)) { hintsShown.Add(i); game.hud.Hint(hints[i].Value, 10); }
            foreach (var a in arenas)
                if (!a.started && !a.cleared && a.trigger.Contains(pp)) StartArena(a);
        }

        void StartArena(UKArena a)
        {
            var game = UKGame.I;
            a.started = true;
            a.wave = -1;
            a.alive = a.pending = 0;
            a.advancing = false;
            foreach (var id in a.lockDoors) if (doors.TryGetValue(id, out var d)) d.Set(false);
            game.SetCheckpoint(a.checkpoint, a.checkpointYaw);
            game.hud.Message(a.name, 1.6f);
            a.onStart?.Invoke();
            NextWave(a);
        }

        void NextWave(UKArena a)
        {
            a.advancing = false;
            if (!a.started || a.cleared) return;
            a.wave++;
            if (a.wave >= a.waves.Count) { ClearArena(a); return; }
            var list = a.waves[a.wave];
            a.pending = list.Count;
            for (int i = 0; i < list.Count; i++)
            {
                var s = list[i];
                UKGame.I.Schedule(0.25f + i * 0.18f, () =>
                {
                    if (!a.started || a.cleared) return;
                    a.pending--;
                    a.alive++;
                    SpawnOne(s, a);
                });
            }
        }

        static void SpawnOne(UKArena.SpawnDef s, UKArena a)
        {
            switch (s.t)
            {
                case "filth": UKEnemy.Spawn<UKFilth>(s.p + Vector3.up * 0.05f, a); break;
                case "stray": UKEnemy.Spawn<UKStray>(s.p + Vector3.up * 0.05f, a); break;
                case "drone": UKEnemy.Spawn<UKDrone>(s.p, a); break;
                case "sword": UKEnemy.Spawn<UKSwordsmachine>(s.p + Vector3.up * 0.05f, a); break;
            }
        }

        public void OnEnemyKilled(UKEnemy e)
        {
            var a = e.arena;
            if (a == null || !a.started || a.cleared) return;
            a.alive--;
            if (a.alive <= 0 && a.pending <= 0 && !a.advancing)
            {
                a.advancing = true;
                UKGame.I.Schedule(a.wave + 1 >= a.waves.Count ? 0.4f : 0.7f, () => NextWave(a));
            }
        }

        void ClearArena(UKArena a)
        {
            a.cleared = true;
            foreach (var id in a.lockDoors) if (doors.TryGetValue(id, out var d)) d.Set(true);
            foreach (var id in a.exitDoors) if (doors.TryGetValue(id, out var d)) d.Set(true);
            if (!a.isBoss) UKGame.I.hud.Message("ALAN TEMİZLENDİ", 1.6f);
            UKAudio.I.Play("checkpoint");
            a.onClear?.Invoke();
        }

        // Kontrol noktasından dönüşte: yarım kalan arenaları sıfırla, kilitleri aç
        public void ResetUnfinishedArenas()
        {
            foreach (var a in arenas)
            {
                if (!a.started || a.cleared) continue;
                a.started = false;
                a.wave = -1;
                a.alive = a.pending = 0;
                a.advancing = false;
                foreach (var id in a.lockDoors) if (doors.TryGetValue(id, out var d)) d.Set(true, true);
            }
        }
    }
}
