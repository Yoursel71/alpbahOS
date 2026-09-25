// Bölüm altyapısı (web: level.js + levels/common.js). Bölüm düzenleri UKLevels.cs içinde web
// koordinatlarıyla yazılır; burada z ekseni çevrilir (web -z = Unity +z, ilerleme yönü ileri).
// Kutular malzeme ve 24 m'lik hücre başına tek ağda birleştirilir (dünya ölçekli UV, hücre başına
// doğru nokta ışığı seçimi); çarpışma tek statik gövdede BoxCollider'lardır.
// Kapılar, tetikleyiciler, ipuçları, checkpoint'ler, lav/çukur bölgeleri, arenalar (dalga, kilit, boss,
// sonsuz mod), gizli küreler, silah sunakları, dükkân terminalleri, mangal/meşale/ateş, zincir, kafatası,
// mühür, öğütücü, et kancası, heykel, çıkış deliği, kule, üs (üsten iniş), portal, gökyüzü ve ışık havuzu.
using System;
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public struct UKSpawn { public string t; public float[] p; public bool dormant; }

    public class UKTrigger { public Bounds b; public Action fn; public bool once = true, fired; }

    public class UKArena
    {
        public string id, name, bossSub;
        public Bounds trigger;
        public string[] locks = new string[0], exits = new string[0];
        public readonly List<UKSpawn[]> waves = new List<UKSpawn[]>();
        public bool boss, prespawn, endless;
        public int total;
        public Func<int, UKGame, UKSpawn[]> genWave;
        public Action<UKGame> onStart, onClear;
        public Action<UKGame, int, UKArena> onWave;
        // çalışma anı
        public string state = "idle";
        public int wave = -1, killsAtStart = -1;
        public float delay;
        public readonly List<UKEnemy> enemies = new List<UKEnemy>(), bossList = new List<UKEnemy>();
        public List<UKEnemy> pre;
        public UKTrigger trig;
    }

    public class UKDoor
    {
        public string id;
        public Transform t;
        public BoxCollider col;
        public Vector3 basePos;
        public float travel, speed = 0.9f, k, target;
        public bool up = true, initialOpen, saved, hasSaved;
        public Material lampMat;

        public bool IsOpen => target > 0.5f;
        public Vector3 Center => t.position;

        public void Open(bool silent = false)
        {
            if (target >= 1) return;
            target = 1;
            if (!silent) UKAudio.I.PlayAt("door", Center);
            SetLamp();
        }

        public void Close(bool silent = false)
        {
            if (target <= 0) return;
            target = 0;
            if (!silent) UKAudio.I.PlayAt("doorSlam", Center);
            SetLamp();
        }

        void SetLamp()
        {
            if (lampMat == null) return;
            var c = target > 0.5f ? new Color(0.13f, 1f, 0.38f) : new Color(1f, 0.13f, 0.06f);
            if (lampMat.HasProperty("_Color")) lampMat.SetColor("_Color", c);
            if (lampMat.HasProperty("_BaseColor")) lampMat.SetColor("_BaseColor", c);
        }

        public void Apply()
        {
            t.position = basePos + Vector3.up * (k * travel * (up ? 1 : -1));
            col.enabled = k < 0.97f;
            SetLamp();
        }

        public bool Tick(float dt)
        {
            if (k == target) return false;
            float sp = target > k ? speed : 3f;
            k = Mathf.MoveTowards(k, target, dt * sp);
            Apply();
            return true;
        }

        public void Reset() => SetInstant(initialOpen);
        public void SetInstant(bool open) { k = target = open ? 1 : 0; Apply(); }
    }

    public class UKLevel : MonoBehaviour
    {
        // ------------------------------------------------------------ iç türler
        public class Theme
        {
            public Color fog = C(0x2a0806), hemiSky = C(0xffa888), hemiGround = C(0x3a1410), ambient = C(0x5a3030), sun = C(0xff9a70);
            public float fogNear = 30, fogFar = 140, hemi = 1.9f;
            public Color skyTop = new Color(0.02f, 0, 0), skyHor = new Color(0.3f, 0.05f, 0.02f), skyCloud = new Color(0.25f, 0.05f, 0.01f), skyGlow = new Color(0.4f, 0.08f, 0);
            public Theme Clone() => (Theme)MemberwiseClone();
        }

        public class Lamp { public Vector3 pos; public Color color; public float power; public UKSecret secret; public UKPickup pickup; }
        public class Hurt { public Bounds b; public float dps; public string kind; }
        public class FireFx { public Transform s1, s2; public float size, phase, y; }
        public class UKSecret { public Transform g, core, shell; public Vector3 pos; public float baseY; public bool taken; }
        public class UKPickup { public string weapon; public Vector3 pos; public Transform holder, ring; public float baseY; public bool taken; public Action<UKGame> onTake, onGive; }
        public class ShopTerm { public Vector3 pos; public Transform g; }
        public class Extra { public Bounds trigger; public UKSpawn[] list; public UKTrigger trig; }
        public class Decor { public string t; public Vector3 pos; public float yawDeg; public bool dormant; }
        public class CgPillar { public Transform t; public BoxCollider col; public int i, j; public float h, target; }

        public static Color C(int hex) => new Color(((hex >> 16) & 255) / 255f, ((hex >> 8) & 255) / 255f, (hex & 255) / 255f);
        static Color C3(float[] a) => a == null ? Color.black : new Color(a[0], a[1], a[2]);

        // ------------------------------------------------------------ bölüm durumu
        public UKLevelDef def;
        public Transform root;
        public readonly Dictionary<string, UKDoor> doors = new Dictionary<string, UKDoor>();
        public readonly List<UKTrigger> triggers = new List<UKTrigger>();
        public readonly List<UKArena> arenas = new List<UKArena>();
        public readonly List<UKSecret> secrets = new List<UKSecret>();
        public readonly List<Hurt> hurtZones = new List<Hurt>();
        public readonly List<Lamp> lamps = new List<Lamp>();
        public readonly List<FireFx> fires = new List<FireFx>();
        public readonly List<Action<float>> animated = new List<Action<float>>();
        public readonly List<Extra> extraEnemies = new List<Extra>();
        public readonly List<UKPickup> pickups = new List<UKPickup>();
        public readonly List<KeyValuePair<Vector3, string>> trainers = new List<KeyValuePair<Vector3, string>>();
        public readonly List<ShopTerm> shops = new List<ShopTerm>();
        public readonly List<Decor> decor = new List<Decor>();
        public readonly List<CgPillar> cgPillars = new List<CgPillar>();
        public Vector3 spawnPos, spawnCheckpoint, menuTarget;
        public float spawnYaw, spawnPitch = 28f, menuRadius = 15, menuHeight = 5.5f;
        public float killY = -40;
        public int totalEnemies;
        public bool startArmed = true, noBase, endless;
        public Theme theme = new Theme();
        public UKGame game => UKGame.I;

        readonly Dictionary<string, Material> mats = new Dictionary<string, Material>();
        readonly Dictionary<string, Bucket> buckets = new Dictionary<string, Bucket>();
        GameObject solids, playerSolids;
        Material lavaMat, skyMat;
        Transform sky;
        readonly List<Material> owned = new List<Material>();
        readonly List<Mesh> ownedMeshes = new List<Mesh>();
        readonly List<Light> pool = new List<Light>();
        readonly float[] poolBase = new float[12];
        float lightT, grinderN;
        bool doorsMoved;

        class Bucket { public string mat; public readonly List<Vector3> v = new List<Vector3>(); public readonly List<Vector3> n = new List<Vector3>(); public readonly List<Vector2> uv = new List<Vector2>(); public readonly List<int> tri = new List<int>(); }

        // ------------------------------------------------------------ koordinat
        public static Vector3 P(float x, float y, float z) => new Vector3(x, y, -z);
        public static Vector3 P(float[] a) => new Vector3(a[0], a[1], -a[2]);
        public static float YawDeg(float webRad) => -webRad * Mathf.Rad2Deg;

        public static Bounds BB(float x0, float y0, float z0, float x1, float y1, float z1)
        {
            var b = new Bounds();
            b.SetMinMax(new Vector3(Mathf.Min(x0, x1), Mathf.Min(y0, y1), Mathf.Min(-z0, -z1)), new Vector3(Mathf.Max(x0, x1), Mathf.Max(y0, y1), Mathf.Max(-z0, -z1)));
            return b;
        }

        public static Bounds BB(float[] a) => BB(a[0], a[1], a[2], a[3], a[4], a[5]);

        // ------------------------------------------------------------ malzemeler
        public Material Mat(string key)
        {
            if (mats.TryGetValue(key, out var m) && m != null) return m;
            switch (key)
            {
                case "stone": m = UKFx.Lit(Color.white, 0, UKFx.TexStone); break;
                case "tiles": m = UKFx.Lit(Color.white, 0, UKFx.TexTiles); break;
                case "metal": m = UKFx.Lit(Color.white, 0, UKFx.TexMetal); break;
                case "rock": m = UKFx.Lit(Color.white, 0, UKFx.TexRock); break;
                case "flesh": m = UKFx.Lit(Color.white, 0, UKFx.TexFlesh); break;
                case "door": m = UKFx.Lit(Color.white, 0, UKFx.TexDoor); break;
                case "bone": m = UKFx.Lit(Color.white, 0, UKFx.TexBone); break;
                case "dark": m = UKFx.Lit(C(0x553333), 0, UKFx.TexRock); break;
                case "meat": m = UKFx.Lit(C(0xffb0a8), 0, UKFx.TexFlesh); break;
                case "ruin": m = UKFx.Lit(C(0xffc890), 0, UKFx.TexStone); break;
                case "marble": m = UKFx.Lit(C(0xdcdcf0), 0, UKFx.TexStone); break;
                case "ash": m = UKFx.Lit(C(0xa89c98), 0, UKFx.TexRock); break;
                case "gold": m = UKFx.Lit(C(0xffc860), 0, UKFx.TexMetal); break;
                case "grass": m = UKFx.Lit(Color.white, 0, UKFx.TexGrass); break;
                case "castle": m = UKFx.Lit(Color.white, 0, UKFx.TexLimestone); break;
                case "castleDark": m = UKFx.Lit(C(0x9a9488), 0, UKFx.TexLimestone); break;
                case "bluegold": m = UKFx.Lit(C(0x5a8adc), 0, UKFx.TexMetal); break;
                case "neon": m = Emissive(new Color(0.02f, 0.02f, 0.04f), UKFx.TexGrid, Color.white); break;
                case "neonWall": m = Emissive(new Color(0.03f, 0.01f, 0.03f), UKFx.TexGrid, C(0xff60d0)); break;
                case "lava": m = lavaMat = Emissive(new Color(0.3f, 0.08f, 0.02f), UKFx.TexLava, Color.white); break;
                case "glow": m = UKFx.Lit(C(0xff4020), 1.6f); break;
                default: m = UKFx.Lit(Color.gray); break;
            }
            mats[key] = m;
            return m;
        }

        // Dokulu öz aydınlatmalı malzeme (lav, neon ızgara): ışıktan bağımsız parlar
        Material Emissive(Color baseCol, Texture2D tex, Color emit)
        {
            var m = new Material(UKFx.Lit(baseCol, 0, tex));
            m.EnableKeyword("_EMISSION");
            m.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
            if (m.HasProperty("_EmissionColor")) m.SetColor("_EmissionColor", emit);
            if (m.HasProperty("_EmissionMap")) m.SetTexture("_EmissionMap", tex);
            owned.Add(m);
            return m;
        }

        Material OwnUnlit(Color c, Texture2D tex = null)
        {
            var m = new Material(tex != null ? UKFx.UnlitTex(c, tex) : UKFx.Unlit(c));
            owned.Add(m);
            return m;
        }

        // ------------------------------------------------------------ kurulum
        public void Build(UKLevelDef d)
        {
            Clear();
            def = d;
            root = new GameObject("Level " + d.id).transform;
            root.SetParent(transform, false);
            solids = new GameObject("Solids");
            solids.transform.SetParent(root, false);
            solids.isStatic = true;
            playerSolids = new GameObject("PlayerOnly") { layer = 2 };
            playerSolids.transform.SetParent(root, false);
            spawnPos = P(0, 40, 108);
            spawnCheckpoint = P(0, 0, 106);
            spawnYaw = 0;
            spawnPitch = 40;
            menuTarget = P(0, 2.2f, -3);
            menuRadius = 15;
            menuHeight = 5.5f;
            killY = -40;
            startArmed = true;
            noBase = endless = false;
            theme = new Theme();
            d.build(this);
        }

        public void Clear()
        {
            foreach (var e in decorSpawned) if (e) Destroy(e.gameObject);
            decorSpawned.Clear();
            if (root) Destroy(root.gameObject);
            foreach (var m in owned) if (m) Destroy(m);
            foreach (var m in ownedMeshes) if (m) Destroy(m);
            owned.Clear(); ownedMeshes.Clear(); mats.Clear(); buckets.Clear();
            doors.Clear(); triggers.Clear(); arenas.Clear(); secrets.Clear(); hurtZones.Clear(); lamps.Clear(); fires.Clear();
            animated.Clear(); extraEnemies.Clear(); pickups.Clear(); trainers.Clear(); shops.Clear(); decor.Clear(); cgPillars.Clear();
            pool.Clear();
            lavaMat = null; sky = null;
            totalEnemies = 0;
            grinderN = 0;
        }

        // ------------------------------------------------------------ geometri
        // Kutu: çarpışma + (görünürse) malzeme kovasına dünya-UV'li yüzler
        public void Box(float x0, float y0, float z0, float x1, float y1, float z1, string mat = "stone", bool solid = true, bool visible = true, float texScale = 4, bool playerOnly = false)
        {
            var b = BB(x0, y0, z0, x1, y1, z1);
            if (b.size.x < 1e-4f || b.size.y < 1e-4f || b.size.z < 1e-4f) return;
            if (solid)
            {
                var bc = (playerOnly ? playerSolids : solids).AddComponent<BoxCollider>();
                bc.center = b.center;
                bc.size = b.size;
            }
            if (visible) AddBoxGeo(mat, b.min, b.max, texScale);
        }

        void AddBoxGeo(string mat, Vector3 mn, Vector3 mx, float texScale)
        {
            // Büyük kutuları görsel olarak parçala (ışık seçimi hücre başına yapılır); iç yüzler çizilmez
            const float MAXP = 14f;
            int nx = Mathf.Max(1, Mathf.CeilToInt((mx.x - mn.x) / MAXP)), nz = Mathf.Max(1, Mathf.CeilToInt((mx.z - mn.z) / MAXP));
            for (int i = 0; i < nx; i++)
                for (int j = 0; j < nz; j++)
                {
                    var a = new Vector3(Mathf.Lerp(mn.x, mx.x, i / (float)nx), mn.y, Mathf.Lerp(mn.z, mx.z, j / (float)nz));
                    var b = new Vector3(Mathf.Lerp(mn.x, mx.x, (i + 1) / (float)nx), mx.y, Mathf.Lerp(mn.z, mx.z, (j + 1) / (float)nz));
                    var c = (a + b) * 0.5f;
                    string key = mat + "|" + Mathf.FloorToInt(c.x / 24f) + "|" + Mathf.FloorToInt(c.z / 24f);
                    if (!buckets.TryGetValue(key, out var bk)) { bk = new Bucket { mat = mat }; buckets[key] = bk; }
                    int faces = 0x0C | (i == 0 ? 0x02 : 0) | (i == nx - 1 ? 0x01 : 0) | (j == 0 ? 0x20 : 0) | (j == nz - 1 ? 0x10 : 0);
                    BoxFaces(bk, a, b, texScale, faces, Vector3.zero);
                }
        }

        // faces: 1=+x 2=-x 4=+y 8=-y 16=+z 32=-z. UV: web kuralı (x yüzü: z,y · y yüzü: x,z · z yüzü: x,y)
        static void BoxFaces(Bucket bk, Vector3 a, Vector3 b, float ts, int faces, Vector3 origin)
        {
            void Quad(Vector3 p0, Vector3 p1, Vector3 p2, Vector3 p3, Vector3 nrm, int uAxis, int vAxis)
            {
                int i = bk.v.Count;
                foreach (var p in new[] { p0, p1, p2, p3 })
                {
                    bk.v.Add(p - origin);
                    bk.n.Add(nrm);
                    bk.uv.Add(new Vector2(p[uAxis] / ts, p[vAxis] / ts));
                }
                bk.tri.Add(i); bk.tri.Add(i + 1); bk.tri.Add(i + 2);
                bk.tri.Add(i); bk.tri.Add(i + 2); bk.tri.Add(i + 3);
            }
            float x0 = a.x, y0 = a.y, z0 = a.z, x1 = b.x, y1 = b.y, z1 = b.z;
            if ((faces & 1) != 0) Quad(new Vector3(x1, y0, z0), new Vector3(x1, y1, z0), new Vector3(x1, y1, z1), new Vector3(x1, y0, z1), Vector3.right, 2, 1);
            if ((faces & 2) != 0) Quad(new Vector3(x0, y0, z1), new Vector3(x0, y1, z1), new Vector3(x0, y1, z0), new Vector3(x0, y0, z0), Vector3.left, 2, 1);
            if ((faces & 4) != 0) Quad(new Vector3(x0, y1, z0), new Vector3(x0, y1, z1), new Vector3(x1, y1, z1), new Vector3(x1, y1, z0), Vector3.up, 0, 2);
            if ((faces & 8) != 0) Quad(new Vector3(x0, y0, z1), new Vector3(x0, y0, z0), new Vector3(x1, y0, z0), new Vector3(x1, y0, z1), Vector3.down, 0, 2);
            if ((faces & 16) != 0) Quad(new Vector3(x1, y0, z1), new Vector3(x1, y1, z1), new Vector3(x0, y1, z1), new Vector3(x0, y0, z1), Vector3.forward, 0, 1);
            if ((faces & 32) != 0) Quad(new Vector3(x0, y0, z0), new Vector3(x0, y1, z0), new Vector3(x1, y1, z0), new Vector3(x1, y0, z0), Vector3.back, 0, 1);
        }

        Mesh MeshFrom(Bucket bk, string name)
        {
            var m = new Mesh { name = name };
            if (bk.v.Count > 65000) m.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
            m.SetVertices(bk.v);
            m.SetNormals(bk.n);
            m.SetUVs(0, bk.uv);
            m.SetTriangles(bk.tri, 0);
            m.RecalculateBounds();
            ownedMeshes.Add(m);
            return m;
        }

        GameObject MeshObj(Transform parent, Mesh mesh, Material mat, Vector3 pos, string name = "mesh")
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.position = pos;
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var r = go.AddComponent<MeshRenderer>();
            r.sharedMaterial = mat;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            return go;
        }

        // Basamaklar (x ekseninde): xBottom → xTop yönünde yükselir
        public void StairsX(float z0, float z1, float xBottom, float xTop, float y0, float y1, float n, string mat = "stone")
        {
            float dir = Mathf.Sign(xTop - xBottom), dx = Mathf.Abs(xTop - xBottom) / n, dy = (y1 - y0) / n;
            for (int k = 1; k <= n; k++)
            {
                float xs = xBottom + dir * (k - 1) * dx;
                Box(Mathf.Min(xs, xTop), y0, z0, Mathf.Max(xs, xTop), y0 + k * dy, z1, mat);
            }
        }

        public void StairsZ(float x0, float x1, float zBottom, float zTop, float y0, float y1, float n, string mat = "stone")
        {
            float dir = Mathf.Sign(zTop - zBottom), dz = Mathf.Abs(zTop - zBottom) / n, dy = (y1 - y0) / n;
            for (int k = 1; k <= n; k++)
            {
                float zs = zBottom + dir * (k - 1) * dz;
                Box(x0, y0, Mathf.Min(zs, zTop), x1, y0 + k * dy, Mathf.Max(zs, zTop), mat);
            }
        }

        public UKDoor Door(string id, float x0, float y0, float z0, float x1, float y1, float z1, bool open = false, string dir = "up", float travel = -1, string mat = "door", float speed = 0.9f)
        {
            var b = BB(x0, y0, z0, x1, y1, z1);
            var go = new GameObject("door " + id);
            go.transform.SetParent(root, false);
            go.transform.position = b.center;
            var bk = new Bucket { mat = mat };
            BoxFaces(bk, b.min, b.max, mat == "door" ? Mathf.Max(b.size.x, b.size.z) : 4, 63, b.center);
            go.AddComponent<MeshFilter>().sharedMesh = MeshFrom(bk, "door");
            var r = go.AddComponent<MeshRenderer>();
            r.sharedMaterial = Mat(mat);
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            var col = go.AddComponent<BoxCollider>();
            col.size = b.size;
            var d = new UKDoor { id = id, t = go.transform, col = col, basePos = b.center, up = dir == "up", speed = speed, travel = travel >= 0 ? travel : b.size.y, initialOpen = open };
            if (mat == "door")
            {
                // kilit lambası (kırmızı: kilitli, yeşil: açık)
                bool thin = b.size.x > b.size.z;
                d.lampMat = OwnUnlit(Color.red);
                UKFx.Part(go.transform, new Vector3(0, b.size.y / 2 + 0.5f, 0), thin ? new Vector3(1.2f, 0.3f, 0.3f) : new Vector3(0.3f, 0.3f, 1.2f), d.lampMat);
            }
            doors[id] = d;
            d.SetInstant(open);
            return d;
        }

        public UKTrigger Trigger(float[] box, Action fn, bool once = true)
        {
            var t = new UKTrigger { b = BB(box), fn = fn, once = once };
            triggers.Add(t);
            return t;
        }

        public UKTrigger Hint(float[] box, string text, float dur = 7) => Trigger(box, () => game.hud.Hint(text, dur));

        public UKTrigger Checkpoint(float[] box, float[] spawn, float yaw = 0) => Trigger(box, () => game.SetCheckpoint(P(spawn), YawDeg(yaw)));

        public void HurtZone(float[] box, float dps, string kind = "lava") => hurtZones.Add(new Hurt { b = BB(box), dps = dps, kind = kind });

        public UKArena Arena(string id, string name, float[] trigger, string[] locks, string[] exits, UKSpawn[][] waves, bool boss = false, string bossSub = null,
            bool prespawn = false, bool endless = false, Action<UKGame> onStart = null, Action<UKGame> onClear = null, Action<UKGame, int, UKArena> onWave = null,
            Func<int, UKGame, UKSpawn[]> genWave = null)
        {
            var a = new UKArena
            {
                id = id, name = name, trigger = BB(trigger), locks = locks ?? new string[0], exits = exits ?? new string[0], boss = boss, bossSub = bossSub,
                prespawn = prespawn, endless = endless, onStart = onStart, onClear = onClear, onWave = onWave, genWave = genWave,
            };
            if (waves != null) foreach (var w in waves) { a.waves.Add(w); a.total += w.Length; }
            totalEnemies += a.total;
            a.trig = Trigger(trigger, () => StartArena(a));
            arenas.Add(a);
            return a;
        }

        public UKSecret Secret(float x, float y, float z)
        {
            var g = new GameObject("secret").transform;
            g.SetParent(root, false);
            g.position = P(x, y, z);
            var core = UKFx.Shape(g, UKFx.Sphere, Vector3.zero, Vector3.one * 0.6f, UKFx.Lit(C(0xbfe6ff), 1.2f)).transform;
            var shell = UKFx.Shape(g, UKFx.Torus(0.12f, 12, 4), Vector3.zero, Vector3.one * 1.1f, UKFx.Unlit(C(0x4aa8ff))).transform;
            var shell2 = UKFx.Shape(shell, UKFx.Torus(0.12f, 12, 4), Vector3.zero, Vector3.one, UKFx.Unlit(C(0x4aa8ff)), new Vector3(90, 0, 0));
            UKFx.Billboard(g, Vector3.zero, 2.5f, new Color(0.38f, 0.69f, 1f, 0.8f));
            var s = new UKSecret { g = g, core = core, shell = shell, pos = g.position, baseY = g.position.y };
            secrets.Add(s);
            lamps.Add(new Lamp { pos = g.position, color = C(0x4aa8ff), power = 0.6f, secret = s });
            return s;
        }

        public void Brazier(float x, float y, float z)
        {
            Box(x - 0.45f, y, z - 0.45f, x + 0.45f, y + 1.1f, z + 0.45f, "metal");
            Box(x - 0.6f, y + 1.1f, z - 0.6f, x + 0.6f, y + 1.35f, z + 0.6f, "dark");
            Fire(x, y + 1.35f, z, 1.4f);
            lamps.Add(new Lamp { pos = P(x, y + 2.2f, z), color = C(0xff7a30), power = 1 });
        }

        public void Torch(float x, float y, float z)
        {
            Box(x - 0.15f, y - 0.4f, z - 0.15f, x + 0.15f, y, z + 0.15f, "metal", solid: false);
            Fire(x, y, z, 0.8f);
            lamps.Add(new Lamp { pos = P(x, y + 0.5f, z), color = C(0xff8a40), power = 0.8f });
        }

        public void Fire(float x, float y, float z, float size)
        {
            var p = P(x, y, z);
            var s1 = UKFx.Billboard(root, p + Vector3.up * size * 0.4f, 1, new Color(1f, 0.44f, 0.13f, 0.85f)).transform;
            var s2 = UKFx.Billboard(root, p + Vector3.up * size * 0.25f, 1, new Color(1f, 0.82f, 0.38f, 0.9f)).transform;
            fires.Add(new FireFx { s1 = s1, s2 = s2, size = size, phase = UnityEngine.Random.Range(0f, 10f), y = y });
        }

        public void Chain(float x, float yTop, float z, float len)
        {
            for (float i = 0; i < len; i += 0.35f)
            {
                bool alt = Mathf.FloorToInt(i / 0.35f + 0.01f) % 2 == 0;
                Box(x - (alt ? 0.06f : 0.12f), yTop - i - 0.3f, z - (alt ? 0.12f : 0.06f), x + (alt ? 0.06f : 0.12f), yTop - i, z + (alt ? 0.12f : 0.06f), "metal", solid: false, texScale: 1);
            }
        }

        public void Skulls(float x, float y, float z, float n = 5)
        {
            for (int i = 0; i < n; i++)
            {
                float sx = x + UnityEngine.Random.Range(-0.8f, 0.8f), sz = z + UnityEngine.Random.Range(-0.8f, 0.8f), sy = y + (i > 3 ? 0.35f : 0);
                Box(sx - 0.18f, sy, sz - 0.2f, sx + 0.18f, sy + 0.32f, sz + 0.2f, "bone", solid: false, texScale: 1);
                Box(sx - 0.1f, sy + 0.08f, sz - 0.21f, sx - 0.02f, sy + 0.18f, sz - 0.19f, "dark", solid: false, texScale: 1);
                Box(sx + 0.02f, sy + 0.08f, sz - 0.21f, sx + 0.1f, sy + 0.18f, sz - 0.19f, "dark", solid: false, texScale: 1);
            }
        }

        public void Sigil(float x, float y, float z, float size)
        {
            var m = OwnUnlit(new Color(1f, 0.31f, 0.19f, 0.6f), UKFx.TexSigil);
            var q = UKFx.Shape(root, UKFx.Quad, P(x, y + 0.03f, z), new Vector3(size, size, 1), m, new Vector3(90, 0, 0)).transform;
            animated.Add(t =>
            {
                var c = new Color(1f, 0.31f, 0.19f, 0.55f + Mathf.Sin(t * 2) * 0.2f);
                if (m.HasProperty("_Color")) m.SetColor("_Color", c);
                if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", c);
                q.localRotation = Quaternion.Euler(90, t * 2.9f, 0);
            });
        }

        // Lav yüzeyi: dünya-UV'li düz ağ (paylaşılan kayan doku), yakında turuncu ışık
        public void LavaPlane(float x0, float z0, float x1, float z1, float y)
        {
            var b = BB(x0, y - 0.02f, z0, x1, y, z1);
            var bk = new Bucket { mat = "lava" };
            BoxFaces(bk, b.min, b.max, 6, 4, Vector3.zero);
            MeshObj(root, MeshFrom(bk, "lava"), Mat("lava"), Vector3.zero, "lava");
            lamps.Add(new Lamp { pos = P((x0 + x1) / 2, y + 2, (z0 + z1) / 2), color = C(0xff5010), power = 1.4f });
        }

        // Öğütücü: çukurda dönen dişli silindir (görsel; hasar için HurtZone)
        public void Grinder(float x, float y, float z, float len, string axis = "x", float r = 0.9f)
        {
            var spin = new GameObject("grinder").transform;
            spin.SetParent(root, false);
            spin.position = P(x, y, z);
            var g = new GameObject("g").transform;
            g.SetParent(spin, false);
            g.localRotation = axis == "x" ? Quaternion.Euler(0, 0, 90) : Quaternion.Euler(90, 0, 0);
            UKFx.Cyl(g, Vector3.zero, r, len, Mat("metal"), default, 10);
            int rows = Mathf.FloorToInt(len / 0.7f);
            for (int k = 0; k < rows; k++)
                for (int j = 0; j < 6; j++)
                {
                    float a = j / 6f * Mathf.PI * 2 + k * 0.5f;
                    var dir = new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a));
                    var tooth = UKFx.Cone(g, dir * (r + 0.2f) + Vector3.up * (-len / 2 + 0.35f + k * 0.7f), 0.16f, 0.5f, Mat("bone"), default, 4).transform;
                    tooth.localRotation = Quaternion.FromToRotation(Vector3.up, dir);
                }
            float sgn = (++grinderN) % 2 == 1 ? 1 : -1;
            Vector3 ax = axis == "x" ? Vector3.right : Vector3.forward;
            animated.Add(t => spin.localRotation = Quaternion.AngleAxis(t * 3 * sgn * Mathf.Rad2Deg, ax));
        }

        public void MeatHook(float x, float yTop, float z, float len = 3)
        {
            Chain(x, yTop, z, len);
            Box(x - 0.35f, yTop - len - 1.6f, z - 0.25f, x + 0.35f, yTop - len, z + 0.25f, "meat", solid: false, texScale: 1.5f);
            Box(x - 0.08f, yTop - len - 0.1f, z - 0.08f, x + 0.08f, yTop - len + 0.2f, z + 0.08f, "metal", solid: false, texScale: 1);
        }

        public void Statue(float x, float y, float z, float s = 1, string mat = "marble")
        {
            Box(x - 0.9f * s, y, z - 0.9f * s, x + 0.9f * s, y + 0.8f * s, z + 0.9f * s, "dark");
            Box(x - 0.35f * s, y + 0.8f * s, z - 0.25f * s, x + 0.35f * s, y + 2.4f * s, z + 0.25f * s, mat, texScale: 2);
            Box(x - 0.55f * s, y + 2.4f * s, z - 0.3f * s, x + 0.55f * s, y + 3.1f * s, z + 0.3f * s, mat, texScale: 2);
            Box(x - 0.2f * s, y + 3.1f * s, z - 0.2f * s, x + 0.2f * s, y + 3.6f * s, z + 0.2f * s, mat, texScale: 2);
        }

        // Çıkış deliği: zeminde açılan kapak + aşağıda lav; düşünce bölüm biter
        public void ExitHatch(string id, float x0, float z0, float x1, float z1, float y = 0)
        {
            Door(id, x0, y - 2, z0, x1, y, z1, open: false, dir: "down", travel: 26, mat: "metal");
            Box(x0 - 1, y - 32, z0 - 1, x0, y - 2, z1 + 1, "rock");
            Box(x1, y - 32, z0 - 1, x1 + 1, y - 2, z1 + 1, "rock");
            Box(x0, y - 32, z0 - 1, x1, y - 2, z0, "rock");
            Box(x0, y - 32, z1, x1, y - 2, z1 + 1, "rock");
            Box(x0, y - 34, z0, x1, y - 32, z1, "rock");
            LavaPlane(x0, z0, x1, z1, y - 31.5f);
            Trigger(new[] { x0, y - 24, z0, x1, y - 4, z1 }, () => game.LevelComplete());
        }

        public void Spire(float x, float z, float h, float w)
        {
            Box(x - w, -30, z - w, x + w, h, z + w, "rock", solid: false, texScale: 8);
            Box(x - w * 0.6f, h, z - w * 0.6f, x + w * 0.6f, h + w * 3, z + w * 0.6f, "rock", solid: false, texScale: 8);
        }

        // Dükkân terminali: yeşil ekranlı dikili taş. yaw (web, radyan): ekranın baktığı yön (0 → web +z)
        public ShopTerm Shop(float x, float y, float z, float yaw = 0)
        {
            var g = new GameObject("shop").transform;
            g.SetParent(root, false);
            g.position = P(x, y, z);
            Vector3 face = new Vector3(Mathf.Sin(yaw), 0, -Mathf.Cos(yaw));
            g.rotation = Quaternion.LookRotation(face);
            UKFx.Part(g, new Vector3(0, 1.45f, 0), new Vector3(1.7f, 2.9f, 0.7f), Mat("metal"));
            UKFx.Part(g, new Vector3(0, 3.0f, 0), new Vector3(1.95f, 0.25f, 0.9f), Mat("dark"));
            UKFx.Part(g, new Vector3(0, 0.15f, 0), new Vector3(2.1f, 0.3f, 1.1f), Mat("dark"));
            UKFx.Part(g, new Vector3(0, 1.75f, 0.36f), new Vector3(1.3f, 1.62f, 0.02f), UKFx.Lit(C(0x021a08), 0.6f));
            var font = UKHud.BuiltinFont();
            if (font != null)
            {
                var tgo = new GameObject("screen");
                tgo.transform.SetParent(g, false);
                tgo.transform.localPosition = new Vector3(0, 1.78f, 0.38f);
                tgo.transform.localRotation = Quaternion.Euler(0, 180, 0);
                var tm = tgo.AddComponent<TextMesh>();
                tm.font = font;
                tm.text = "DÜKKÂN\n\nSİLAH · VARYANT\nKOL · KANCA\n— P İLE ÖDE —\n\n[B]";
                tm.anchor = TextAnchor.MiddleCenter;
                tm.alignment = TextAlignment.Center;
                tm.fontSize = 48;
                tm.characterSize = 0.022f;
                tm.color = new Color(0.22f, 1f, 0.42f);
                tgo.GetComponent<MeshRenderer>().sharedMaterial = font.material;
            }
            var glow = UKFx.Billboard(g, new Vector3(0, 1.75f, 0.6f), 2.4f, new Color(0.22f, 1f, 0.42f, 0.3f));
            Vector3 front = g.position + face * 1.3f;
            // çarpışma: dönüşe göre eksen hizalı kutu
            bool along = Mathf.Abs(Mathf.Sin(yaw)) > 0.5f;
            float hw = along ? 0.35f : 0.85f, hd = along ? 0.85f : 0.35f;
            var bc = solids.AddComponent<BoxCollider>();
            var cb = BB(x - hw, y, z - hd, x + hw, y + 3.1f, z + hd);
            bc.center = cb.center; bc.size = cb.size;
            var sh = new ShopTerm { pos = front, g = g };
            shops.Add(sh);
            lamps.Add(new Lamp { pos = g.position + face * 1.2f + Vector3.up * 2.2f, color = C(0x39ff6a), power = 0.9f });
            return sh;
        }

        // Silah sunağı: kaide + dönen silah modeli. weapon: "0".."4" ya da "knuckle" / "hook"
        public UKPickup Altar(float x, float y, float z, int weapon, Action<UKGame> onTake, Action<UKGame> onGive = null) => Altar(x, y, z, weapon.ToString(), onTake, onGive);

        public UKPickup Altar(float x, float y, float z, string weapon, Action<UKGame> onTake, Action<UKGame> onGive = null)
        {
            Box(x - 0.8f, y, z - 0.8f, x + 0.8f, y + 0.9f, z + 0.8f, "metal");
            Box(x - 1.0f, y + 0.9f, z - 1.0f, x + 1.0f, y + 1.1f, z + 1.0f, "dark");
            int col = weapon == "0" ? 0x3aa0ff : weapon == "1" ? 0xff8a30 : weapon == "2" ? 0x9adf5a : weapon == "3" ? 0x3aeaff : weapon == "4" ? 0xff3a2a : weapon == "knuckle" ? 0xff5030 : 0x9adf5a;
            var ring = UKFx.Shape(root, UKFx.Torus(0.11f, 24, 6), P(x, y + 1.15f, z), Vector3.one * 1.8f, UKFx.Unlit(C(col))).transform;
            var holder = new GameObject("pickup").transform;
            holder.SetParent(root, false);
            holder.position = P(x, y + 2.0f, z);
            var gc = C(col); gc.a = 0.7f;
            UKFx.Billboard(holder, Vector3.zero, 3, gc);
            var pk = new UKPickup { weapon = weapon, pos = P(x, y + 1.6f, z), holder = holder, ring = ring, onTake = onTake, onGive = onGive, baseY = y + 2.0f };
            if (game != null && game.weapons != null) game.weapons.PickupModel(weapon, holder);
            pickups.Add(pk);
            lamps.Add(new Lamp { pos = P(x, y + 2.8f, z), color = C(col), power = 1.1f, pickup = pk });
            return pk;
        }

        public void Lamp_(Vector3 pos, int color, float power) => lamps.Add(new Lamp { pos = pos, color = C(color), power = power });

        // V1'in üssü: başlangıcın üstünde asılı metal oda; kapak açılınca oyuncu bölüme düşer
        void BuildBase()
        {
            Vector3 sp = spawnPos;
            float x = sp.x, y = sp.y, z = -sp.z;
            const float R = 4.5f, H = 4.2f, h = 1.7f;
            Box(x - R, y - 0.6f, z - R, x + R, y, z - h, "metal");
            Box(x - R, y - 0.6f, z + h, x + R, y, z + R, "metal");
            Box(x - R, y - 0.6f, z - h, x - h, y, z + h, "metal");
            Box(x + h, y - 0.6f, z - h, x + R, y, z + h, "metal");
            Box(x - R - 0.4f, y - 0.6f, z - R - 0.4f, x + R + 0.4f, y + H, z - R, "dark");
            Box(x - R - 0.4f, y - 0.6f, z + R, x + R + 0.4f, y + H, z + R + 0.4f, "dark");
            Box(x - R - 0.4f, y - 0.6f, z - R, x - R, y + H, z + R, "dark");
            Box(x + R, y - 0.6f, z - R, x + R + 0.4f, y + H, z + R, "dark");
            Box(x - R - 0.4f, y + H, z - R - 0.4f, x + R + 0.4f, y + H + 0.5f, z + R + 0.4f, "metal");
            foreach (var q in new[] { new[] { -h - 0.25f, -h - 0.25f, h + 0.25f, -h }, new[] { -h - 0.25f, h, h + 0.25f, h + 0.25f }, new[] { -h - 0.25f, -h, -h, h }, new[] { h, -h, h + 0.25f, h } })
                Box(x + q[0], y, z + q[1], x + q[2], y + 0.03f, z + q[3], "glow", solid: false, texScale: 1);
            foreach (var zz in new[] { -R + 0.02f, R - 0.02f }) Box(x - 2.4f, y + 1.6f, z + zz - 0.02f, x + 2.4f, y + 1.75f, z + zz + 0.02f, "glow", solid: false, texScale: 1);
            Door("baseHatch", x - h, y - 0.5f, z - h, x + h, y, z + h, open: false, dir: "down", travel: 2.5f, mat: "metal", speed: 3.5f);
            lamps.Add(new Lamp { pos = P(x, y + H - 0.8f, z), color = C(0xff3020), power = 1.4f });
        }

        // ------------------------------------------------------------ ortak düzen yardımcıları (common.js)
        public class Gap { public float g0, g1, top = 6, bottom; }
        public class Gaps { public Gap n, s, w, e; }

        static Gap ToGap(float[] a) => a == null ? null : new Gap { g0 = a[0], g1 = a[1], top = a.Length > 2 ? a[2] : 6, bottom = a.Length > 3 ? a[3] : 0 };
        public static Gaps MakeGaps(float[] n = null, float[] s = null, float[] w = null, float[] e = null) => new Gaps { n = ToGap(n), s = ToGap(s), w = ToGap(w), e = ToGap(e) };

        void WallAlongX(float x0, float x1, float za, float zb, float y, float h, string mat, Gap gap)
        {
            if (gap == null) { Box(x0 - 1, y, za, x1 + 1, y + h, zb, mat); return; }
            Box(x0 - 1, y, za, gap.g0, y + h, zb, mat);
            Box(gap.g1, y, za, x1 + 1, y + h, zb, mat);
            if (gap.top < h) Box(gap.g0, y + gap.top, za, gap.g1, y + h, zb, mat);
            if (gap.bottom > 0) Box(gap.g0, y, za, gap.g1, y + gap.bottom, zb, mat);
        }

        void WallAlongZ(float xa, float xb, float z0, float z1, float y, float h, string mat, Gap gap)
        {
            if (gap == null) { Box(xa, y, z0, xb, y + h, z1, mat); return; }
            Box(xa, y, z0, xb, y + h, gap.g0, mat);
            Box(xa, y, gap.g1, xb, y + h, z1, mat);
            if (gap.top < h) Box(xa, y + gap.top, gap.g0, xb, y + h, gap.g1, mat);
            if (gap.bottom > 0) Box(xa, y, gap.g0, xb, y + gap.bottom, gap.g1, mat);
        }

        // Dört duvarlı oda. Kenarlar (web): n = z0 (küçük z), s = z1, w = x0, e = x1
        public void Room(float x0, float z0, float x1, float z1, float y = 0, float h = 12, string mat = "stone", string floor = "tiles", string ceil = null, Gaps gaps = null, string[] skip = null)
        {
            gaps = gaps ?? new Gaps();
            bool Skip(string k) => skip != null && Array.IndexOf(skip, k) >= 0;
            if (floor != null) Box(x0 - 1, y - 2, z0 - 1, x1 + 1, y, z1 + 1, floor);
            if (ceil != null) Box(x0 - 1, y + h, z0 - 1, x1 + 1, y + h + 1, z1 + 1, ceil);
            if (!Skip("n")) WallAlongX(x0, x1, z0 - 1, z0, y, h, mat, gaps.n);
            if (!Skip("s")) WallAlongX(x0, x1, z1, z1 + 1, y, h, mat, gaps.s);
            if (!Skip("w")) WallAlongZ(x0 - 1, x0, z0, z1, y, h, mat, gaps.w);
            if (!Skip("e")) WallAlongZ(x1, x1 + 1, z0, z1, y, h, mat, gaps.e);
        }

        public void FloorWithHoles(float x0, float z0, float x1, float z1, float[][] holes, float y = 0, string mat = "tiles")
        {
            var hs = new List<float[]>(holes);
            hs.Sort((a, b) => a[1].CompareTo(b[1]));
            float z = z0;
            foreach (var hh in hs)
            {
                float hx0 = hh[0], hz0 = hh[1], hx1 = hh[2], hz1 = hh[3];
                if (hz0 > z) Box(x0, y - 2, z, x1, y, hz0, mat);
                if (hx0 > x0) Box(x0, y - 2, hz0, hx0, y, hz1, mat);
                if (hx1 < x1) Box(hx1, y - 2, hz0, x1, y, hz1, mat);
                z = hz1;
            }
            if (z < z1) Box(x0, y - 2, z, x1, y, z1, mat);
        }

        // Çukur: dört yan duvar + taban; düşen oyuncu son güvenli yere döner, düşman ölür
        public void Pit(float x0, float z0, float x1, float z1, float depth = 10, float dmg = 25, string mat = "rock", string bottom = "meat")
        {
            Box(x0 - 1, -depth, z0 - 1, x0, 0, z1 + 1, mat);
            Box(x1, -depth, z0 - 1, x1 + 1, 0, z1 + 1, mat);
            Box(x0, -depth, z0 - 1, x1, 0, z0, mat);
            Box(x0, -depth, z1, x1, 0, z1 + 1, mat);
            Box(x0, -depth - 2, z0, x1, -depth, z1, bottom);
            HurtZone(new[] { x0, -depth - 4, z0, x1, -1.5f, z1 }, dmg, "pit");
        }

        public void Pillar(float x, float z, float h = 12, float w = 1, string mat = "stone", float y = 0)
        {
            Box(x - w, y, z - w, x + w, y + h, z + w, mat);
            Box(x - w - 0.3f, y + h, z - w - 0.3f, x + w + 0.3f, y + h + 0.4f, z + w + 0.3f, "metal");
            Box(x - w - 0.3f, y, z - w - 0.3f, x + w + 0.3f, y + 0.4f, z + w + 0.3f, "metal");
        }

        public void Spires(float[][] list) { foreach (var s in list) Spire(s[0], s[1], s[2], s[3]); }

        public void Tree(float x, float z, float h = 5, float y = 0)
        {
            Box(x - 0.35f, y, z - 0.35f, x + 0.35f, y + h, z + 0.35f, "ruin");
            Box(x - 1.8f, y + h - 0.6f, z - 1.8f, x + 1.8f, y + h + 1.4f, z + 1.8f, "grass", texScale: 2);
            Box(x - 1.1f, y + h + 1.4f, z - 1.1f, x + 1.1f, y + h + 2.4f, z + 1.1f, "grass", texScale: 2);
        }

        public void House(float x0, float z0, float x1, float z1, float h = 5, string mat = "castleDark", string door = "s", bool burning = false)
        {
            float cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
            var gaps = new Gaps();
            var g = door == "s" || door == "n" ? new Gap { g0 = cx - 1.2f, g1 = cx + 1.2f, top = 3 } : new Gap { g0 = cz - 1.2f, g1 = cz + 1.2f, top = 3 };
            if (door == "n") gaps.n = g; else if (door == "s") gaps.s = g; else if (door == "w") gaps.w = g; else gaps.e = g;
            Room(x0, z0, x1, z1, h: h, mat: mat, floor: null, gaps: gaps);
            Box(x0 - 1.4f, h, z0 - 1.4f, x1 + 1.4f, h + 0.6f, z1 + 1.4f, "ruin");
            if (burning)
            {
                Fire(cx - (x1 - x0) * 0.25f, h + 0.6f, cz, 2.6f);
                Fire(cx + (x1 - x0) * 0.2f, h + 0.6f, cz + 0.6f, 2);
                lamps.Add(new Lamp { pos = P(cx, h + 2, cz), color = C(0xff7a30), power = 1.2f });
                var sp = P(cx, h + 2.5f, cz);
                animated.Add(t => { if (UnityEngine.Random.value < 0.12f && UKFx.I) UKFx.I.Smoke(sp + new Vector3(Mathf.Sin(t * 3) * 1.5f, 0, 0), 1, C(0x3a3230), 1.4f, 2.2f, 3); });
            }
        }

        // Parlayan geçit düzlemi (görsel)
        public void PortalVisual(float x, float y, float z, float w, float h, int color, int glowColor)
        {
            var pm = OwnUnlit(C(color));
            var q = UKFx.Shape(root, UKFx.Quad, P(x, y, z), new Vector3(w, h, 1), pm).transform;
            var gc = C(glowColor); gc.a = 0.55f;
            var glow = UKFx.Billboard(root, P(x, y, z + 1.1f), 1, gc).transform;
            glow.localScale = new Vector3(w * 1.7f, h * 1.6f, 1);
            animated.Add(t =>
            {
                var c = C(color); c.a = 0.7f + Mathf.Sin(t * 3) * 0.15f;
                if (pm.HasProperty("_Color")) pm.SetColor("_Color", c);
                if (pm.HasProperty("_BaseColor")) pm.SetColor("_BaseColor", c);
            });
        }

        // Bölüm çıkışı: parlayan kapı + girince bölüm biter
        public void Portal(float x, float z, float y = 0, int color = 0xff3010, int glowColor = 0xff5020, float w = 8, float h = 10)
        {
            PortalVisual(x, y + h / 2, z, w, h, color, glowColor);
            lamps.Add(new Lamp { pos = P(x, y + h / 2, z + 3), color = C(glowColor), power = 1.6f });
            Trigger(new[] { x - w / 2, y, z - 0.5f, x + w / 2, y + h, z + 2.5f }, () => game.LevelComplete());
        }

        // Nabız gibi parlayan büyük ışık lekesi (Siber Öğütücü tavanı)
        public void GlowSprite(float x, float y, float z, float size, int color)
        {
            var m = OwnUnlit(C(color), UKFx.TexGlow);
            var g = UKFx.Shape(root, UKFx.Quad, P(x, y, z), Vector3.one * size, m).transform;
            g.gameObject.AddComponent<UKFaceCam>();
            animated.Add(t =>
            {
                var c = C(color); c.a = 0.35f + Mathf.Sin(t * 1.5f) * 0.1f;
                if (m.HasProperty("_Color")) m.SetColor("_Color", c);
                if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", c);
            });
        }

        // Gökyüzünde ay (1-4)
        public void Moon(float x, float y, float z)
        {
            var g = UKFx.Billboard(root, P(x, y, z), 60, new Color(0.87f, 0.9f, 1f, 0.5f));
            var d = UKFx.Billboard(root, P(x, y, z - 2), 18, new Color(0.96f, 0.97f, 1f), UKFx.TexGlow);
            d.GetComponent<Renderer>().sharedMaterial = UKFx.Unlit(new Color(0.96f, 0.97f, 1f));
            d.GetComponent<MeshFilter>().sharedMesh = DiscMesh();
        }

        Mesh DiscMesh()
        {
            var v = new List<Vector3> { Vector3.zero };
            var tri = new List<int>();
            for (int i = 0; i <= 24; i++) { float a = i / 24f * Mathf.PI * 2; v.Add(new Vector3(Mathf.Cos(a), Mathf.Sin(a), 0) * 0.5f); }
            for (int i = 0; i < 24; i++) { tri.Add(0); tri.Add(i + 1); tri.Add(i + 2); }
            var m = new Mesh();
            m.SetVertices(v); m.SetTriangles(tri, 0); m.RecalculateBounds();
            ownedMeshes.Add(m);
            return m;
        }

        // ------------------------------------------------------------ bölüm ayarları
        public void SetLimbo()
        {
            theme = new Theme
            {
                fog = C(0xa8b8d0), fogNear = 40, fogFar = 210,
                skyTop = new Color(0.16f, 0.32f, 0.66f), skyHor = new Color(0.7f, 0.78f, 0.9f), skyCloud = new Color(0.55f, 0.55f, 0.58f), skyGlow = new Color(0.9f, 0.72f, 0.4f),
                hemiSky = C(0xf4f8ff), hemiGround = C(0x5a6a48), hemi = 2.3f, ambient = C(0x7a8090), sun = C(0xfff2d8),
            };
        }

        public void Theme_(int? fog = null, float? fogNear = null, float? fogFar = null, float[] skyTop = null, float[] skyHor = null, float[] skyCloud = null, float[] skyGlow = null,
            int? hemiSky = null, int? hemiGround = null, float? hemi = null, int? ambient = null, int? sun = null)
        {
            var t = theme;
            if (fog.HasValue) t.fog = C(fog.Value);
            if (fogNear.HasValue) t.fogNear = fogNear.Value;
            if (fogFar.HasValue) t.fogFar = fogFar.Value;
            if (skyTop != null) t.skyTop = C3(skyTop);
            if (skyHor != null) t.skyHor = C3(skyHor);
            if (skyCloud != null) t.skyCloud = C3(skyCloud);
            if (skyGlow != null) t.skyGlow = C3(skyGlow);
            if (hemiSky.HasValue) t.hemiSky = C(hemiSky.Value);
            if (hemiGround.HasValue) t.hemiGround = C(hemiGround.Value);
            if (hemi.HasValue) t.hemi = hemi.Value;
            if (ambient.HasValue) t.ambient = C(ambient.Value);
            if (sun.HasValue) t.sun = C(sun.Value);
        }

        public void SetSpawn(float[] pos, float yaw = 0, float[] checkpoint = null, float pitch = float.NaN)
        {
            spawnPos = P(pos);
            spawnYaw = YawDeg(yaw);
            spawnCheckpoint = checkpoint != null ? P(checkpoint) : spawnPos;
            if (!float.IsNaN(pitch)) spawnPitch = -pitch * Mathf.Rad2Deg;
        }

        public void MenuCam(float[] target, float radius, float height) { menuTarget = P(target); menuRadius = radius; menuHeight = height; }
        public void AddDecor(string t, float x, float y, float z, float yaw = 0, bool dormant = false) => decor.Add(new Decor { t = t, pos = P(x, y, z), yawDeg = YawDeg(yaw), dormant = dormant });
        public void Trainer(float[] p, string door) => trainers.Add(new KeyValuePair<Vector3, string>(P(p), door));
        public void ExtraEnemies(float[] trigger, UKSpawn[] list) => extraEnemies.Add(new Extra { trigger = BB(trigger), list = list });

        public void FinishBuild()
        {
            if (!noBase && spawnPos.y - spawnCheckpoint.y > 10) BuildBase();
            foreach (var kv in buckets)
            {
                if (kv.Value.v.Count == 0) continue;
                var go = MeshObj(root, MeshFrom(kv.Value, kv.Key), Mat(kv.Value.mat), Vector3.zero, kv.Value.mat);
                go.isStatic = true;
            }
            buckets.Clear();
            foreach (var ex in extraEnemies)
            {
                totalEnemies += ex.list.Length;
                var e = ex;
                ex.trig = new UKTrigger { b = ex.trigger, fn = () => { foreach (var s in e.list) SpawnEnemy(s, null); } };
                triggers.Add(ex.trig);
            }
            BuildSky();
            for (int i = 0; i < poolBase.Length; i++)
            {
                var l = new GameObject("lamp").AddComponent<Light>();
                l.transform.SetParent(root, false);
                l.type = LightType.Point;
                l.shadows = LightShadows.None;
                l.range = 22;
                l.intensity = 0;
                l.enabled = false;
                pool.Add(l);
            }
            lightT = 0;
            Physics.SyncTransforms();
        }

        // Gökyüzü: tepe rengi → ufuk, bulut bandı ve ufuk parıltısı (köşe renkli ters küre)
        void BuildSky()
        {
            const int SEG = 32, RING = 16;
            var v = new List<Vector3>(); var col = new List<Color>(); var tri = new List<int>();
            var th = theme;
            for (int j = 0; j <= RING; j++)
            {
                float lat = Mathf.Lerp(-Mathf.PI / 2, Mathf.PI / 2, j / (float)RING);
                for (int i = 0; i <= SEG; i++)
                {
                    float lon = i / (float)SEG * Mathf.PI * 2;
                    var d = new Vector3(Mathf.Cos(lat) * Mathf.Cos(lon), Mathf.Sin(lat), Mathf.Cos(lat) * Mathf.Sin(lon));
                    float y = d.y;
                    float k = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(-0.05f, 0.55f, y));
                    Color c = Color.Lerp(th.skyHor, th.skyTop, k);
                    float cl = Mathf.PerlinNoise(lon * 3f + 11, y * 8f) * Mathf.PerlinNoise(lon * 6.5f, y * 16f + 5);
                    c += th.skyCloud * cl * Mathf.Clamp01(1 - Mathf.Abs(y - 0.12f) * 2);
                    c += th.skyGlow * Mathf.Pow(Mathf.Max(0, 1 - Mathf.Abs(y + 0.02f) * 6), 3);
                    c.a = 1;
                    v.Add(d * 450);
                    col.Add(c);
                }
            }
            for (int j = 0; j < RING; j++)
                for (int i = 0; i < SEG; i++)
                {
                    int a = j * (SEG + 1) + i, b = a + SEG + 1;
                    tri.Add(a); tri.Add(b); tri.Add(a + 1);
                    tri.Add(a + 1); tri.Add(b); tri.Add(b + 1);
                }
            var m = new Mesh { name = "sky" };
            m.SetVertices(v); m.SetColors(col); m.SetTriangles(tri, 0); m.RecalculateBounds();
            ownedMeshes.Add(m);
            skyMat = OwnUnlit(Color.white);
            skyMat.renderQueue = 1000;
            var go = MeshObj(root, m, skyMat, Vector3.zero, "sky");
            sky = go.transform;
        }

        // ------------------------------------------------------------ çalışma anı
        public string HurtAt(Vector3 p)
        {
            foreach (var z in hurtZones) if (z.b.Contains(p)) return z.kind;
            return null;
        }

        public void CheckHazards(UKPlayer p)
        {
            Vector3 pos = p.transform.position + Vector3.up * 0.1f;
            foreach (var z in hurtZones)
            {
                if (!z.b.Contains(pos)) continue;
                if (z.kind == "pit") { p.OutOfBounds(z.dps); return; }
                p.LavaHit(z.dps);
            }
        }

        public UKEnemy SpawnEnemy(UKSpawn s, UKArena a, bool instant = false)
        {
            var pos = P(s.p) + Vector3.up * 0.06f;
            var e = UKEnemy.Spawn(s.t, pos, a, instant || s.dormant, s.dormant);
            if (a != null) a.enemies.Add(e);
            return e;
        }

        readonly List<UKEnemy> decorSpawned = new List<UKEnemy>();

        public void SpawnDecor()
        {
            ClearDecor();
            foreach (var d in decor) decorSpawned.Add(UKEnemy.Spawn(d.t, d.pos + Vector3.up * 0.06f, null, true, d.dormant, true, d.yawDeg));
        }

        public void ClearDecor()
        {
            foreach (var e in decorSpawned) if (e) Destroy(e.gameObject);
            decorSpawned.Clear();
        }

        public void SpawnTrainers()
        {
            foreach (var t in trainers)
            {
                var e = UKEnemy.Spawn("trainer", t.Key + Vector3.up * 0.06f, null, true, false, false, -90);
                if (e is UKTrainer tr) tr.trainerDoor = t.Value;
            }
        }

        // Görsel güncelleme (menüde de çalışır)
        public void Tick(float dt, float time, Vector3 camPos)
        {
            doorsMoved = false;
            foreach (var d in doors.Values) doorsMoved |= d.Tick(dt);
            foreach (var p in cgPillars)
            {
                if (p.h == p.target) continue;
                p.h = Mathf.MoveTowards(p.h, p.target, 5 * dt);
                var pos = p.t.position; pos.y = p.h; p.t.position = pos;
                doorsMoved = true;
            }
            if (doorsMoved) Physics.SyncTransforms();
            foreach (var f in fires)
            {
                if (!f.s1) continue;
                float kk = 0.85f + Mathf.Sin(time * 13 + f.phase) * 0.08f + Mathf.Sin(time * 29 + f.phase * 2) * 0.07f;
                f.s1.localScale = new Vector3(f.size * kk, f.size * 1.4f * (2 - kk), 1);
                var p1 = f.s1.position; p1.y = f.y + f.size * 0.4f + Mathf.Sin(time * 7 + f.phase) * 0.04f; f.s1.position = p1;
                f.s2.localScale = new Vector3(f.size * 0.5f * kk, f.size * 0.8f * kk, 1);
            }
            foreach (var s in secrets)
            {
                if (s.taken) continue;
                var p = s.g.position; p.y = s.baseY + Mathf.Sin(time * 2) * 0.15f; s.g.position = p;
                s.core.localRotation = Quaternion.Euler(0, time * 86, 0);
                s.shell.localRotation = Quaternion.Euler(time * 29, -time * 46, 0);
            }
            foreach (var pk in pickups)
            {
                if (pk.taken) continue;
                var p = pk.holder.position; p.y = pk.baseY + Mathf.Sin(time * 2) * 0.12f; pk.holder.position = p;
                pk.holder.rotation = Quaternion.Euler(0, time * 74, 0);
                pk.ring.rotation = Quaternion.Euler(0, time * 34, 0);
            }
            foreach (var fn in animated) fn(time);
            if (lavaMat)
            {
                var off = new Vector2(time * 0.03f, time * 0.02f);
                lavaMat.mainTextureOffset = off;
                if (lavaMat.HasProperty("_EmissionMap")) lavaMat.SetTextureOffset("_EmissionMap", off);
            }
            if (sky) sky.position = camPos;
            UpdateLights(dt, time, camPos);
        }

        void UpdateLights(float dt, float time, Vector3 cp)
        {
            lightT -= dt;
            if (lightT <= 0)
            {
                lightT = 0.2f;
                var list = new List<Lamp>();
                foreach (var l in lamps) if ((l.secret == null || !l.secret.taken) && (l.pickup == null || !l.pickup.taken)) list.Add(l);
                list.Sort((a, b) => (a.pos - cp).sqrMagnitude.CompareTo((b.pos - cp).sqrMagnitude));
                for (int i = 0; i < pool.Count; i++)
                {
                    var L = pool[i];
                    if (!L) continue;
                    if (i < list.Count && (list[i].pos - cp).sqrMagnitude < 75 * 75)
                    {
                        L.transform.position = list[i].pos;
                        L.color = list[i].color;
                        L.range = 16 + list[i].power * 8;
                        poolBase[i] = list[i].power * 1.5f * UKFx.LightMul;
                        L.enabled = true;
                    }
                    else { poolBase[i] = 0; L.enabled = false; }
                }
            }
            for (int i = 0; i < pool.Count; i++)
                if (pool[i] && pool[i].enabled) pool[i].intensity = poolBase[i] * (0.88f + 0.12f * Mathf.Sin(time * 13 + i * 7) * Mathf.Sin(time * 7.3f + i));
        }

        // Oyun kuralları (yalnız oynarken): tetikleyiciler, gizli küreler, sunaklar, dükkân yakınlığı, arenalar
        public ShopTerm NearShop { get; private set; }

        public void GameTick(float dt)
        {
            var g = game;
            var p = g.player;
            Vector3 pp = p.transform.position + Vector3.up * 0.5f;
            for (int i = 0; i < triggers.Count; i++)
            {
                var t = triggers[i];
                if (t.fired && t.once) continue;
                if (t.b.Contains(pp)) { t.fired = true; t.fn(); if (g.state != UKGame.State.Playing) return; }
            }
            Vector3 c = p.transform.position + Vector3.up * 0.9f;
            foreach (var s in secrets)
            {
                if (s.taken || (s.g.position - c).sqrMagnitude > 1.5f * 1.5f) continue;
                s.taken = true;
                s.g.gameObject.SetActive(false);
                g.OnSecret(s, secrets.Count);
            }
            foreach (var pk in pickups)
            {
                if (pk.taken || (pk.pos - c).sqrMagnitude > 2f * 2f) continue;
                pk.taken = true;
                pk.holder.gameObject.SetActive(false);
                pk.ring.gameObject.SetActive(false);
                g.OnPickup(pk);
            }
            ShopTerm near = null;
            foreach (var sh in shops)
            {
                var d = sh.pos - p.transform.position;
                if (d.x * d.x + d.z * d.z < 2.8f * 2.8f && Mathf.Abs(d.y) < 2) { near = sh; break; }
            }
            NearShop = near;
            UpdateArenas(dt);
        }

        // ------------------------------------------------------------ arenalar (web: Arenas)
        public void Prespawn()
        {
            foreach (var a in arenas)
            {
                if (!a.prespawn || a.state != "idle" || a.pre != null || a.waves.Count == 0) continue;
                a.pre = new List<UKEnemy>();
                foreach (var s in a.waves[0]) a.pre.Add(SpawnEnemy(s, null, true));
            }
        }

        void StartArena(UKArena a)
        {
            var g = game;
            if (a.state != "idle" || g.state != UKGame.State.Playing) return;
            a.state = "active";
            a.wave = -1;
            a.enemies.Clear();
            a.bossList.Clear();
            a.delay = a.boss ? 2.4f : 0.35f;
            foreach (var id in a.locks) if (doors.TryGetValue(id, out var d)) { d.saved = d.target > 0.5f; d.hasSaved = true; d.Close(); }
            a.killsAtStart = g.stats.kills;
            if (a.boss)
            {
                g.music.SetMode("boss");
                g.hud.BossTitle(a.bossSub ?? "BOSS", a.name, 3.2f);
                UKAudio.I.Play("bossRoar");
            }
            else g.music.SetMode("combat");
            if (a.pre != null)
            {
                a.wave = 0;
                foreach (var e in a.pre) if (e && !e.dead) { e.arena = a; a.enemies.Add(e); if (e.boss) a.bossList.Add(e); }
                a.pre = null;
                a.delay = 0.9f;
                a.onWave?.Invoke(g, 0, a);
            }
            a.onStart?.Invoke(g);
        }

        void UpdateArenas(float dt)
        {
            var g = game;
            foreach (var a in arenas)
            {
                if (a.state != "active") continue;
                a.enemies.RemoveAll(e => e == null || e.dead);
                if (a.enemies.Count > 0) continue;
                a.delay -= dt;
                if (a.delay > 0) continue;
                if (a.endless && a.wave + 1 >= a.waves.Count)
                {
                    a.waves.Add(a.genWave(a.wave + 1, g));
                    a.delay = a.wave < 0 ? 0.6f : 1.8f;
                    continue;
                }
                if (a.wave + 1 < a.waves.Count)
                {
                    a.wave++;
                    foreach (var s in a.waves[a.wave])
                    {
                        var e = SpawnEnemy(s, a);
                        if (e.boss) a.bossList.Add(e);
                    }
                    a.onWave?.Invoke(g, a.wave, a);
                    a.delay = 0.9f;
                }
                else ClearArena(a);
            }
        }

        void ClearArena(UKArena a)
        {
            var g = game;
            a.state = "cleared";
            foreach (var id in a.exits) if (doors.TryGetValue(id, out var d)) d.Open();
            a.onClear?.Invoke(g);
            if (!arenas.Exists(x => x.state == "active")) g.music.SetMode("calm");
            if (!a.boss) { g.hud.Message("ALAN TEMİZLENDİ", 1.6f); UKAudio.I.Play("checkpoint"); }
        }

        // Ölünce: etkin arenalar baştan (öldürmeler geri alınır, kapılar eski hâline)
        public void ResetActiveArenas()
        {
            var g = game;
            foreach (var a in arenas)
            {
                if (a.state != "active") continue;
                foreach (var e in a.enemies) if (e) e.RemoveSilently();
                foreach (var e in a.bossList) if (e) e.RemoveSilently();
                a.enemies.Clear();
                a.bossList.Clear();
                a.pre = null;
                if (a.killsAtStart >= 0) g.stats.kills = a.killsAtStart;
                a.state = "idle";
                a.wave = -1;
                if (a.endless) a.waves.Clear();
                a.trig.fired = false;
                foreach (var id in a.locks) if (doors.TryGetValue(id, out var d)) d.SetInstant(d.hasSaved ? d.saved : d.initialOpen);
                foreach (var id in a.exits) if (doors.TryGetValue(id, out var d)) d.Reset();
            }
        }

        // Bölümü ilk hâline getir (yeniden başlatma)
        public void ResetState()
        {
            foreach (var d in doors.Values) { d.hasSaved = false; d.Reset(); }
            foreach (var p in cgPillars) { p.h = p.target = 0; var pos = p.t.position; pos.y = 0; p.t.position = pos; }
            foreach (var a in arenas)
            {
                a.state = "idle";
                a.wave = -1;
                if (a.endless) a.waves.Clear();
                a.enemies.Clear();
                a.bossList.Clear();
                a.pre = null;
                a.killsAtStart = -1;
            }
            foreach (var t in triggers) t.fired = false;
            foreach (var s in secrets) { s.taken = false; s.g.gameObject.SetActive(true); }
            foreach (var pk in pickups) { pk.taken = false; pk.holder.gameObject.SetActive(true); pk.ring.gameObject.SetActive(true); }
            Physics.SyncTransforms();
        }

        // Boss çubuğu: etkin arenadaki boss'ların toplam canı
        public bool BossInfo(out string name, out float frac, out bool enraged)
        {
            name = null; frac = 0; enraged = false;
            foreach (var a in arenas)
            {
                if (a.state != "active" || a.bossList.Count == 0) continue;
                float hp = 0, max = 0;
                foreach (var e in a.bossList) { if (!e) continue; hp += e.dead ? 0 : Mathf.Max(0, e.hp); max += e.maxHp; enraged |= !e.dead && e.enraged; }
                if (max <= 0) continue;
                name = a.boss ? a.name : a.bossList[0].enemyName;
                frac = hp / max;
                return true;
            }
            return false;
        }

        // CG: sütun ekle (Siber Öğütücü)
        public CgPillar AddCgPillar(float x0, float z0, float x1, float z1, float depth, int i, int j)
        {
            var b = BB(x0, -depth, z0, x1, 0, z1);
            var go = new GameObject("cg");
            go.transform.SetParent(root, false);
            go.transform.position = new Vector3(0, 0, 0);
            var bk = new Bucket { mat = "neon" };
            BoxFaces(bk, b.min, b.max, 4, 63, Vector3.zero);
            go.AddComponent<MeshFilter>().sharedMesh = MeshFrom(bk, "cg");
            var r = go.AddComponent<MeshRenderer>();
            r.sharedMaterial = Mat("neon");
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            var col = go.AddComponent<BoxCollider>();
            col.center = b.center;
            col.size = b.size;
            var p = new CgPillar { t = go.transform, col = col, i = i, j = j };
            cgPillars.Add(p);
            return p;
        }

        void OnDestroy() => Clear();
    }

    // ================================================================ bölüm sonu düşüşü
    // Sonuç ekranı açıkken V1 karanlık bir kuyuda düşer: çizgili tünel, yukarı akan rüzgâr çizgileri,
    // dipte bölüm renginde parıltı. Bölümden uzakta ayrı bir yerde kurulur.
    public class UKFall : MonoBehaviour
    {
        public static readonly Vector3 ORIGIN = new Vector3(0, -3000, 0);
        Transform tunnel, glow;
        Material tunnelMat, glowMat, streakMat;
        readonly List<Transform> streaks = new List<Transform>();
        readonly List<float> speeds = new List<float>();
        public bool active;

        public void Build()
        {
            var tex = new Texture2D(64, 256, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Repeat, filterMode = FilterMode.Bilinear };
            var px = new Color[64 * 256];
            for (int i = 0; i < px.Length; i++) px[i] = new Color(0.04f, 0.02f, 0.024f);
            var rng = new System.Random(5);
            for (int i = 0; i < 160; i++)
            {
                float a = 0.04f + (float)rng.NextDouble() * 0.3f;
                int x = rng.Next(64), y = rng.Next(256), w = 1 + rng.Next(2), h = 8 + rng.Next(60);
                for (int yy = y; yy < Mathf.Min(256, y + h); yy++)
                    for (int xx = x; xx < Mathf.Min(64, x + w); xx++) px[yy * 64 + xx] = Color.Lerp(px[yy * 64 + xx], Color.white, a);
            }
            tex.SetPixels(px);
            tex.Apply();
            // iç yüzü görünen silindir
            var v = new List<Vector3>(); var uv = new List<Vector2>(); var tri = new List<int>();
            const int SEG = 20;
            for (int i = 0; i <= SEG; i++)
            {
                float a = i / (float)SEG * Mathf.PI * 2;
                var d = new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a)) * 10;
                v.Add(d + Vector3.down * 130); uv.Add(new Vector2(i / (float)SEG * 5, 0));
                v.Add(d + Vector3.up * 130); uv.Add(new Vector2(i / (float)SEG * 5, 2));
            }
            for (int i = 0; i < SEG; i++) { int a = i * 2; tri.Add(a); tri.Add(a + 2); tri.Add(a + 1); tri.Add(a + 1); tri.Add(a + 2); tri.Add(a + 3); }
            var m = new Mesh();
            m.SetVertices(v); m.SetUVs(0, uv); m.SetTriangles(tri, 0); m.RecalculateBounds(); m.RecalculateNormals();
            tunnelMat = new Material(UKFx.UnlitTex(Color.white, tex));
            tunnel = UKFx.Shape(transform, m, Vector3.zero, Vector3.one, tunnelMat).transform;
            glowMat = new Material(UKFx.UnlitTex(new Color(1, 0.3f, 0.12f), UKFx.TexGlow));
            glow = UKFx.Shape(transform, UKFx.Quad, Vector3.down * 115, Vector3.one * 80, glowMat, new Vector3(-90, 0, 0)).transform;
            streakMat = new Material(UKFx.Unlit(new Color(1, 1, 1, 0.5f)));
            for (int i = 0; i < 80; i++)
            {
                float a = (float)rng.NextDouble() * Mathf.PI * 2, r = 1.4f + (float)rng.NextDouble() * 7.5f;
                var s = UKFx.Part(transform, new Vector3(Mathf.Cos(a) * r, -130 + (float)rng.NextDouble() * 160, Mathf.Sin(a) * r), new Vector3(0.035f, 3.2f, 0.035f), streakMat).transform;
                streaks.Add(s);
                speeds.Add(45 + (float)rng.NextDouble() * 40);
            }
            transform.position = ORIGIN;
            gameObject.SetActive(false);
        }

        public void Begin(UKLevel.Theme th)
        {
            active = true;
            gameObject.SetActive(true);
            var baseC = Color.Lerp(th.fog * 2.6f, th.skyGlow, 0.35f); baseC.a = 1;
            SetC(tunnelMat, baseC);
            var gc = th.skyGlow * 1.6f; gc.a = 0.9f;
            SetC(glowMat, gc);
        }

        static void SetC(Material m, Color c)
        {
            if (m.HasProperty("_Color")) m.SetColor("_Color", c);
            if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", c);
        }

        public void End()
        {
            active = false;
            gameObject.SetActive(false);
        }

        public void Tick(float dt, float t)
        {
            if (!active) return;
            tunnelMat.mainTextureOffset = new Vector2(0, t * 0.9f);
            for (int i = 0; i < streaks.Count; i++)
            {
                var p = streaks[i].localPosition;
                p.y += speeds[i] * dt;
                if (p.y > 30) p.y -= 160;
                streaks[i].localPosition = p;
            }
        }
    }
}
