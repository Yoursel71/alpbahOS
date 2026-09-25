// Malzemeler, kodla üretilen dokular (web sürümünün tarifleri: döşenebilir fbm gürültüsü), ilkel ağlar
// (kutu, koni/kesik koni, halka, küre) ve görsel efektler: kıvılcım, kan (lekeli), parçalanma, kovan,
// duman, iz, şimşek, halka, parlama/yıldız, şok küresi, yakın saldırı kavisi, patlama, ışık, mermi
// deliği ve kan fıskiyesi. Built-in ve URP ile çalışır.
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKFx : MonoBehaviour
    {
        public static UKFx I;
        static Material litBase, unlitBase;
        static Mesh cube, quad, sphere;
        static readonly Dictionary<string, Material> cache = new Dictionary<string, Material>();
        static readonly Dictionary<Vector4, Mesh> boxMeshes = new Dictionary<Vector4, Mesh>();
        static readonly Dictionary<string, Mesh> shapeMeshes = new Dictionary<string, Mesh>();
        public static Texture2D TexStone, TexTiles, TexMetal, TexRock, TexFlesh, TexNoise, TexLava, TexDoor, TexSkin, TexCloth,
            TexMachine, TexBone, TexGrass, TexLimestone, TexGrid, TexSigil, TexStar, TexGlow, TexHole, TexBlood;

        // ------------------------------------------------------------ kurulum
        public static void Init()
        {
            // Domain reload kapalıyken önceki oturumun yok edilmiş nesneleri önbellekte kalabilir
            if (litBase != null && cube != null && quad != null && sphere != null && TexStone != null) return;
            cache.Clear();
            boxMeshes.Clear();
            shapeMeshes.Clear();
            var tmp = GameObject.CreatePrimitive(PrimitiveType.Cube);
            litBase = tmp.GetComponent<MeshRenderer>().sharedMaterial;
            cube = tmp.GetComponent<MeshFilter>().sharedMesh;
            DestroyImmediate(tmp);
            var tq = GameObject.CreatePrimitive(PrimitiveType.Quad);
            quad = tq.GetComponent<MeshFilter>().sharedMesh;
            DestroyImmediate(tq);
            var ts = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sphere = ts.GetComponent<MeshFilter>().sharedMesh;
            DestroyImmediate(ts);
            var sh = Shader.Find("Sprites/Default");
            unlitBase = sh != null ? new Material(sh) : new Material(litBase);
            BuildTextures();
        }

        public static Mesh Cube => cube;
        public static Mesh Quad => quad;
        public static Mesh Sphere => sphere;
        // URP/HDRP nokta ışıkları fiziksel (1/d²) söner; yerleşik hattaki parlaklığa yaklaştırmak için çarpan
        public static bool SRP => UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline != null;
        public static float LightMul => SRP ? 4f : 1f;
        // Mermi/nişan/görüş ışınları: "Ignore Raycast" katmanını (yalnız oyuncuyu durduran parmaklıklar) atla
        public const int RayMask = ~(1 << 2);

        static void SetCol(Material m, Color c)
        {
            if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", c);
            if (m.HasProperty("_Color")) m.SetColor("_Color", c);
        }

        static void SetTex(Material m, Texture t)
        {
            if (m.HasProperty("_BaseMap")) m.SetTexture("_BaseMap", t);
            if (m.HasProperty("_MainTex")) m.SetTexture("_MainTex", t);
        }

        // Işıklı (gölgeli) malzeme; emit > 0 → kendi renginde parlar
        public static Material Lit(Color c, float emit = 0f, Texture2D tex = null)
        {
            string key = "L" + c + emit + (tex ? tex.name : "");
            if (cache.TryGetValue(key, out var m) && m != null) return m;
            m = new Material(litBase);
            SetCol(m, c);
            if (tex != null) SetTex(m, tex);
            if (m.HasProperty("_Glossiness")) m.SetFloat("_Glossiness", 0.15f);
            if (m.HasProperty("_Smoothness")) m.SetFloat("_Smoothness", 0.15f);
            if (emit > 0f)
            {
                m.EnableKeyword("_EMISSION");
                if (m.HasProperty("_EmissionColor")) m.SetColor("_EmissionColor", c * emit);
            }
            cache[key] = m;
            return m;
        }

        // Işıksız, saydamlık destekli (efektler, izler, parlayan şeritler)
        public static Material Unlit(Color c)
        {
            string key = "U" + c;
            if (cache.TryGetValue(key, out var m) && m != null) return m;
            m = new Material(unlitBase);
            SetCol(m, c);
            cache[key] = m;
            return m;
        }

        // Dokulu ışıksız (parlama, yıldız, neon ızgara, mühür)
        public static Material UnlitTex(Color c, Texture2D tex)
        {
            string key = "T" + c + (tex ? tex.name : "");
            if (cache.TryGetValue(key, out var m) && m != null) return m;
            m = new Material(unlitBase);
            SetCol(m, c);
            if (tex != null) SetTex(m, tex);
            cache[key] = m;
            return m;
        }

        // ------------------------------------------------------------ dokular (web: textures.js)
        class Noise
        {
            readonly float[] tbl = new float[65536];
            public Noise(int seed) { var r = new System.Random(seed); for (int i = 0; i < tbl.Length; i++) tbl[i] = (float)r.NextDouble(); }
            public float Get(float x, float y, int p)
            {
                int x0 = Mathf.FloorToInt(x), y0 = Mathf.FloorToInt(y);
                float fx = x - x0, fy = y - y0;
                float sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
                int X0 = ((x0 % p) + p) % p, X1 = (X0 + 1) % p, Y0 = ((y0 % p) + p) % p, Y1 = (Y0 + 1) % p, o = p * 97;
                float V(int i, int j) => tbl[((j + o) * 256 + i + o) & 65535];
                float a = V(X0, Y0) + (V(X1, Y0) - V(X0, Y0)) * sx;
                float b = V(X0, Y1) + (V(X1, Y1) - V(X0, Y1)) * sx;
                return a + (b - a) * sy;
            }
        }

        static float Fbm(Noise n, float u, float v, int bas = 4, int oct = 4)
        {
            float a = 0.5f, s = 0, norm = 0;
            int p = bas;
            for (int o = 0; o < oct; o++) { s += a * n.Get(u * p, v * p, p); norm += a; a *= 0.5f; p *= 2; }
            return s / norm;
        }

        static float Hash2(int x, int y, int s)
        {
            unchecked
            {
                int h = x * 374761393 + y * 668265263 + s * 982451653;
                h = (h ^ (int)((uint)h >> 13)) * 1274126177;
                return (uint)(h ^ (int)((uint)h >> 16)) / 4294967296f;
            }
        }

        static Color H(int hex) => new Color(((hex >> 16) & 255) / 255f, ((hex >> 8) & 255) / 255f, (hex & 255) / 255f);
        static Color Mix(Color a, Color b, float t) { var c = Color.LerpUnclamped(a, b, t); c.a = 1; return c; }
        static Color Mul(Color a, float k) => new Color(a.r * k, a.g * k, a.b * k, a.a);

        delegate Color PixFn(int x, int y, int s);

        static Texture2D Pix(string name, int size, PixFn fn, bool repeat = true, bool point = true)
        {
            var t = new Texture2D(size, size, TextureFormat.RGBA32, true)
            {
                name = "uk_" + name,
                filterMode = point ? FilterMode.Point : FilterMode.Bilinear,
                wrapMode = repeat ? TextureWrapMode.Repeat : TextureWrapMode.Clamp,
            };
            var px = new Color[size * size];
            // web tuvali y aşağı; Unity dokusu y yukarı → satırları çevir
            for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++)
                {
                    var c = fn(x, y, size);
                    px[(size - 1 - y) * size + x] = new Color(Mathf.Clamp01(c.r), Mathf.Clamp01(c.g), Mathf.Clamp01(c.b), Mathf.Clamp01(c.a));
                }
            t.SetPixels(px);
            t.Apply(true);
            return t;
        }

        static void BuildTextures()
        {
            var n1 = new Noise(11); var n2 = new Noise(23); var n3 = new Noise(37);
            TexStone = Pix("stone", 64, (x, y, s) =>
            {
                int row = y / 8, off = (row % 2) * 8, bx = (x + off) / 16;
                float shade = Hash2(bx & 3, row & 7, 1), n = Fbm(n1, x / 64f, y / 64f, 4, 4);
                var c = Mix(H(0x3e302b), H(0x6e5d52), n * 0.7f + shade * 0.35f);
                if (y % 8 == 0 || (x + off) % 16 == 0) c = Mul(c, 0.45f);
                else if (y % 8 == 1 || (x + off) % 16 == 1) c = Mul(c, 1.15f);
                if (Fbm(n2, x / 64f, y / 64f, 8, 2) > 0.7f) c = Mul(c, 0.7f);
                return c;
            });
            TexTiles = Pix("tiles", 64, (x, y, s) =>
            {
                float shade = Hash2(x / 16, y / 16, 2), n = Fbm(n2, x / 64f, y / 64f, 4, 4);
                var c = Mix(H(0x2e2624), H(0x5a4c46), n * 0.8f + shade * 0.25f);
                if (x % 16 == 0 || y % 16 == 0) c = Mul(c, 0.4f);
                else if (x % 16 == 1 || y % 16 == 1) c = Mul(c, 1.2f);
                float st = Fbm(n3, x / 64f, y / 64f, 4, 3);
                if (st > 0.62f) c = Mix(c, H(0x4a0a06), (st - 0.62f) * 2.2f);
                return c;
            });
            TexMetal = Pix("metal", 64, (x, y, s) =>
            {
                float n = Fbm(n3, x / 64f, y / 64f, 4, 3), streak = n1.Get(x / 3f, y / 24f, 21) * 0.15f;
                var c = Mix(H(0x3c4048), H(0x6a707a), n * 0.6f + streak);
                if (x % 32 == 0 || y % 32 == 0) c = Mul(c, 0.5f);
                if (x % 32 == 1 || y % 32 == 1) c = Mul(c, 1.25f);
                int rx = x % 32, ry = y % 32;
                if ((rx == 4 || rx == 27) && (ry == 4 || ry == 27)) c = H(0xa0a6b0);
                if ((rx == 5 || rx == 28) && (ry == 5 || ry == 28)) c = H(0x202228);
                return c;
            });
            TexRock = Pix("rock", 64, (x, y, s) =>
            {
                var c = Mix(H(0x2a0f0b), H(0x6a2c1c), Fbm(n1, x / 64f, y / 64f, 4, 5));
                if (Mathf.Abs(Fbm(n3, x / 64f, y / 64f, 4, 3) - 0.5f) < 0.025f) c = Mul(c, 0.35f);
                return c;
            });
            TexFlesh = Pix("flesh", 64, (x, y, s) =>
            {
                float n = Fbm(n2, x / 64f, y / 64f, 4, 4);
                var c = Mix(H(0x3c0508), H(0x8e1c1a), n);
                if (Mathf.Abs(Fbm(n1, x / 64f, y / 64f, 4, 3) - 0.5f) < 0.03f) c = Mix(c, H(0x24030a), 0.7f);
                if (n > 0.7f) c = Mix(c, H(0xc04030), (n - 0.7f) * 2);
                return c;
            });
            TexLava = Pix("lava", 64, (x, y, s) =>
            {
                float n = Fbm(n3, x / 64f, y / 64f, 4, 4);
                var c = Mix(H(0xc02000), H(0xffd050), n);
                if (n < 0.38f) c = Mix(H(0x300400), c, n / 0.38f);
                return c;
            });
            TexDoor = Pix("door", 64, (x, y, s) =>
            {
                var c = Mix(H(0x2c2e34), H(0x585d66), Fbm(n3, x / 64f, y / 64f, 4, 3) * 0.7f);
                if (x == 31 || x == 32) c = H(0x121316);
                if (y >= 50 && y < 60) c = (x + y) % 16 < 8 ? H(0xd8a010) : H(0x161412);
                if (y == 49 || y == 60) c = H(0x101010);
                if (y < 4) c = H(0x3a0a08);
                if (x % 16 == 8 && y > 6 && y < 46) c = Mul(c, 0.6f);
                return c;
            });
            TexSkin = Pix("skinW", 64, (x, y, s) =>
            {
                var c = Mix(H(0x9a9a9a), H(0xffffff), Fbm(n1, x / 64f, y / 64f, 8, 4));
                float b = Fbm(n2, x / 64f, y / 64f, 4, 3);
                if (b > 0.62f) c = Mix(c, H(0x7a2020), (b - 0.62f) * 2.2f);
                if (Mathf.Abs(Fbm(n3, x / 64f, y / 64f, 4, 3) - 0.5f) < 0.02f) c = Mul(c, 0.7f);
                return c;
            });
            TexNoise = TexSkin;
            TexCloth = Pix("clothW", 64, (x, y, s) =>
            {
                var c = Mix(H(0x8a8a8a), H(0xf0f0f0), Fbm(n2, x / 64f, y / 64f, 8, 3));
                if ((x + y) % 4 == 0) c = Mul(c, 0.85f);
                if (x % 4 == 0) c = Mul(c, 0.9f);
                if (Fbm(n3, x / 64f, y / 64f, 4, 2) > 0.66f) c = Mul(c, 0.55f);
                return c;
            });
            TexMachine = Pix("machine", 64, (x, y, s) =>
            {
                var c = Mix(H(0x2a2c30), H(0x55595f), Fbm(n2, x / 64f, y / 64f, 4, 3) * 0.8f);
                if (x % 16 == 0 || y % 21 == 0) c = Mul(c, 0.55f);
                if ((x + y * 3) % 23 == 0) c = Mul(c, 1.3f);
                return c;
            });
            TexBone = Pix("bone", 64, (x, y, s) => Mix(H(0x8a7e68), H(0xd6ccb0), Fbm(n3, x / 64f, y / 64f, 8, 3)));
            TexGrass = Pix("grass", 64, (x, y, s) =>
            {
                var c = Mix(H(0x2e5a1c), H(0x6aa83a), Fbm(n2, x / 64f, y / 64f, 4, 4));
                float b = Hash2(x, y, 7);
                if (b > 0.86f) c = Mul(c, 1.25f); else if (b < 0.1f) c = Mul(c, 0.75f);
                if (Fbm(n3, x / 64f, y / 64f, 6, 2) > 0.68f) c = Mix(c, H(0x7a6a3a), 0.35f);
                return c;
            });
            TexLimestone = Pix("limestone", 64, (x, y, s) =>
            {
                int row = y / 16, off = (row % 2) * 16, bx = (x + off) / 32;
                float shade = Hash2(bx & 3, row & 3, 5), n = Fbm(n1, x / 64f, y / 64f, 4, 4);
                var c = Mix(H(0xb0a898), H(0xe8e2d4), n * 0.6f + shade * 0.4f);
                if (y % 16 == 0 || (x + off) % 32 == 0) c = Mul(c, 0.6f);
                else if (y % 16 == 1 || (x + off) % 32 == 1) c = Mul(c, 1.08f);
                if (Fbm(n2, x / 64f, y / 64f, 8, 2) > 0.72f) c = Mix(c, H(0x6a7a4a), 0.3f);
                return c;
            });
            TexGrid = Pix("grid", 64, (x, y, s) =>
            {
                bool e = x % 32 == 0 || y % 32 == 0 || x % 32 == 31 || y % 32 == 31;
                bool f = x % 32 == 1 || y % 32 == 1 || x % 32 == 30 || y % 32 == 30;
                if (e) return H(0x40f0ff);
                if (f) return H(0x1a6a90);
                return Mix(H(0x060a14), H(0x0e1428), Fbm(n3, x / 64f, y / 64f, 4, 2));
            });
            TexGlow = Pix("glow", 64, (x, y, s) =>
            {
                float r = Mathf.Sqrt((x - 31.5f) * (x - 31.5f) + (y - 31.5f) * (y - 31.5f)) / 32f;
                float a = r < 0.25f ? Mathf.Lerp(1, 0.8f, r / 0.25f) : r < 0.6f ? Mathf.Lerp(0.8f, 0.2f, (r - 0.25f) / 0.35f) : Mathf.Lerp(0.2f, 0, Mathf.Clamp01((r - 0.6f) / 0.4f));
                return new Color(1, 1, 1, a);
            }, false, false);
            TexStar = Pix("star", 64, (x, y, s) =>
            {
                float cx = (x - 31.5f) / 32f, cy = (y - 31.5f) / 32f, ax = Mathf.Abs(cx), ay = Mathf.Abs(cy);
                float cross = Mathf.Max(Mathf.Exp(-ay * 22) * (1 - ax), Mathf.Exp(-ax * 22) * (1 - ay));
                float d = Mathf.Sqrt(cx * cx + cy * cy);
                float diag = Mathf.Exp(-Mathf.Abs(ax - ay) * 16) * Mathf.Max(0, 1 - d * 1.6f) * 0.5f;
                float core = Mathf.Max(0, 1 - d * 3);
                return new Color(1, 1, 1, Mathf.Min(1, cross + diag + core));
            }, false, false);
            TexHole = Pix("hole", 32, (x, y, s) =>
            {
                float cx = x - 15.5f, cy = y - 15.5f, r = Mathf.Sqrt(cx * cx + cy * cy) / 16f;
                float jag = 0.55f + Hash2(Mathf.FloorToInt(Mathf.Atan2(cy, cx) * 3), 1, 5) * 0.25f;
                if (r < 0.28f) return new Color(0.03f, 0.024f, 0.024f, 1);
                if (r < jag) return new Color(0.12f, 0.094f, 0.086f, 0.78f);
                if (r < jag + 0.12f) return new Color(0.27f, 0.235f, 0.215f, 0.43f);
                return new Color(0, 0, 0, 0);
            }, false);
            TexBlood = Pix("blood", 64, (x, y, s) =>
            {
                float cx = x - 32, cy = y - 32, ang = Mathf.Atan2(cy, cx), r = Mathf.Sqrt(cx * cx + cy * cy) / 32f;
                float edge = 0.55f + Fbm(n1, ang / (Mathf.PI * 2) + 0.5f, 0.5f, 8, 2) * 0.45f;
                float a = r < edge ? 1 : 0;
                if (a == 0 && Hash2(x / 4, y / 4, 9) > 0.94f && r < 1) a = 1;
                var c = Mix(H(0x3a0000), H(0x8a0a06), Fbm(n2, x / 64f, y / 64f, 4, 3));
                c.a = a * 0.92f;
                return c;
            }, false);
            // mühür: iç içe halkalar, yedi köşeli yıldız ve runik noktalar (saydam)
            TexSigil = Pix("sigil", 128, (x, y, s) =>
            {
                float cx = x - 64, cy = y - 64, r = Mathf.Sqrt(cx * cx + cy * cy);
                float a = 0;
                if (Mathf.Abs(r - 58) < 1.6f || Mathf.Abs(r - 48) < 1.1f || Mathf.Abs(r - 10) < 1.1f) a = 0.95f;
                for (int i = 0; i < 7 && a == 0; i++)
                {
                    float a0 = ((i * 3) % 7) / 7f * Mathf.PI * 2 - Mathf.PI / 2, a1 = (((i + 1) * 3) % 7) / 7f * Mathf.PI * 2 - Mathf.PI / 2;
                    Vector2 p0 = new Vector2(Mathf.Cos(a0), Mathf.Sin(a0)) * 48, p1 = new Vector2(Mathf.Cos(a1), Mathf.Sin(a1)) * 48, q = new Vector2(cx, cy);
                    Vector2 d = p1 - p0;
                    float t = Mathf.Clamp01(Vector2.Dot(q - p0, d) / d.sqrMagnitude);
                    if ((p0 + d * t - q).magnitude < 1.1f) a = 0.95f;
                }
                for (int i = 0; i < 14 && a == 0; i++)
                {
                    float an = i / 14f * Mathf.PI * 2;
                    if (Mathf.Abs(cx - Mathf.Cos(an) * 53) < 2 && Mathf.Abs(cy - Mathf.Sin(an) * 53) < 2) a = 0.9f;
                }
                return new Color(1, 0.16f, 0.08f, a);
            }, false);
        }

        // ------------------------------------------------------------ ağlar
        // Dünya ölçekli UV'li kutu ağı (dokular büyük kutularda gerilmez)
        public static Mesh BoxMesh(Vector3 s, float texScale = 4f)
        {
            var key = new Vector4(s.x, s.y, s.z, texScale);
            if (boxMeshes.TryGetValue(key, out var mesh) && mesh != null) return mesh;
            var v = new List<Vector3>();
            var n = new List<Vector3>();
            var uv = new List<Vector2>();
            var tri = new List<int>();
            Vector3 h = s * 0.5f;
            void Face(Vector3 nrm, Vector3 u, Vector3 w, float du, float dw)
            {
                int i = v.Count;
                Vector3 c = Vector3.Scale(nrm, h);
                Vector3 hu = u * (du * 0.5f), hw = w * (dw * 0.5f);
                v.Add(c - hu - hw); v.Add(c + hu - hw); v.Add(c + hu + hw); v.Add(c - hu + hw);
                for (int k = 0; k < 4; k++) n.Add(nrm);
                uv.Add(new Vector2(0, 0)); uv.Add(new Vector2(du / texScale, 0)); uv.Add(new Vector2(du / texScale, dw / texScale)); uv.Add(new Vector2(0, dw / texScale));
                tri.Add(i); tri.Add(i + 2); tri.Add(i + 1); tri.Add(i); tri.Add(i + 3); tri.Add(i + 2);
            }
            Face(Vector3.up, Vector3.right, Vector3.forward, s.x, s.z);
            Face(Vector3.down, Vector3.right, Vector3.back, s.x, s.z);
            Face(Vector3.right, Vector3.back, Vector3.up, s.z, s.y);
            Face(Vector3.left, Vector3.forward, Vector3.up, s.z, s.y);
            Face(Vector3.forward, Vector3.right, Vector3.up, s.x, s.y);
            Face(Vector3.back, Vector3.left, Vector3.up, s.x, s.y);
            mesh = new Mesh { name = "ukbox" };
            mesh.SetVertices(v);
            mesh.SetNormals(n);
            mesh.SetUVs(0, uv);
            mesh.SetTriangles(tri, 0);
            mesh.RecalculateBounds();
            boxMeshes[key] = mesh;
            return mesh;
        }

        // Kesik koni (y ekseni, yükseklik 1, alt yarıçap 0,5, üst yarıçap 0,5·top). top=0 → koni, top=1 → silindir
        public static Mesh Frustum(float top, int seg = 8)
        {
            string key = "F" + top + "_" + seg;
            if (shapeMeshes.TryGetValue(key, out var m) && m != null) return m;
            var v = new List<Vector3>(); var n = new List<Vector3>(); var uv = new List<Vector2>(); var tri = new List<int>();
            float rb = 0.5f, rt = 0.5f * top;
            float slope = rb - rt;
            for (int i = 0; i <= seg; i++)
            {
                float a = i / (float)seg * Mathf.PI * 2, c = Mathf.Cos(a), s = Mathf.Sin(a);
                var nn = new Vector3(c, slope, s).normalized;
                v.Add(new Vector3(c * rb, -0.5f, s * rb)); n.Add(nn); uv.Add(new Vector2(i / (float)seg, 0));
                v.Add(new Vector3(c * rt, 0.5f, s * rt)); n.Add(nn); uv.Add(new Vector2(i / (float)seg, 1));
            }
            for (int i = 0; i < seg; i++)
            {
                int a = i * 2;
                tri.Add(a); tri.Add(a + 1); tri.Add(a + 2);
                tri.Add(a + 2); tri.Add(a + 1); tri.Add(a + 3);
            }
            // kapaklar
            int cb = v.Count; v.Add(new Vector3(0, -0.5f, 0)); n.Add(Vector3.down); uv.Add(new Vector2(0.5f, 0.5f));
            for (int i = 0; i <= seg; i++) { float a = i / (float)seg * Mathf.PI * 2; v.Add(new Vector3(Mathf.Cos(a) * rb, -0.5f, Mathf.Sin(a) * rb)); n.Add(Vector3.down); uv.Add(new Vector2(0.5f + Mathf.Cos(a) * 0.5f, 0.5f + Mathf.Sin(a) * 0.5f)); }
            for (int i = 0; i < seg; i++) { tri.Add(cb); tri.Add(cb + 1 + i); tri.Add(cb + 2 + i); }
            if (top > 0.001f)
            {
                int ct = v.Count; v.Add(new Vector3(0, 0.5f, 0)); n.Add(Vector3.up); uv.Add(new Vector2(0.5f, 0.5f));
                for (int i = 0; i <= seg; i++) { float a = i / (float)seg * Mathf.PI * 2; v.Add(new Vector3(Mathf.Cos(a) * rt, 0.5f, Mathf.Sin(a) * rt)); n.Add(Vector3.up); uv.Add(new Vector2(0.5f + Mathf.Cos(a) * 0.5f, 0.5f + Mathf.Sin(a) * 0.5f)); }
                for (int i = 0; i < seg; i++) { tri.Add(ct); tri.Add(ct + 2 + i); tri.Add(ct + 1 + i); }
            }
            m = new Mesh { name = key };
            m.SetVertices(v); m.SetNormals(n); m.SetUVs(0, uv); m.SetTriangles(tri, 0); m.RecalculateBounds();
            shapeMeshes[key] = m;
            return m;
        }

        // Halka (xz düzleminde, ana yarıçap 0,5; tüp yarıçapı 0,5·tube)
        public static Mesh Torus(float tube, int seg = 16, int ring = 6)
        {
            string key = "O" + tube + "_" + seg + "_" + ring;
            if (shapeMeshes.TryGetValue(key, out var m) && m != null) return m;
            var v = new List<Vector3>(); var n = new List<Vector3>(); var tri = new List<int>();
            float R = 0.5f, r = 0.5f * tube;
            for (int i = 0; i <= seg; i++)
            {
                float a = i / (float)seg * Mathf.PI * 2;
                var dir = new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a));
                for (int j = 0; j <= ring; j++)
                {
                    float b = j / (float)ring * Mathf.PI * 2;
                    var nn = dir * Mathf.Cos(b) + Vector3.up * Mathf.Sin(b);
                    v.Add(dir * R + nn * r); n.Add(nn);
                }
            }
            for (int i = 0; i < seg; i++)
                for (int j = 0; j < ring; j++)
                {
                    int a = i * (ring + 1) + j, b = a + ring + 1;
                    tri.Add(a); tri.Add(a + 1); tri.Add(b);
                    tri.Add(b); tri.Add(a + 1); tri.Add(b + 1);
                }
            m = new Mesh { name = key };
            m.SetVertices(v); m.SetNormals(n); m.SetTriangles(tri, 0); m.RecalculateBounds();
            shapeMeshes[key] = m;
            return m;
        }

        // Çarpışmasız görsel kutu (model parçaları için)
        public static GameObject Part(Transform parent, Vector3 localPos, Vector3 size, Material m, Vector3 euler = default)
        {
            return Shape(parent, cube, localPos, size, m, euler);
        }

        public static GameObject Shape(Transform parent, Mesh mesh, Vector3 localPos, Vector3 scale, Material m, Vector3 euler = default)
        {
            var go = new GameObject("p");
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localEulerAngles = euler;
            go.transform.localScale = scale;
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var r = go.AddComponent<MeshRenderer>();
            r.sharedMaterial = m;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            return go;
        }

        // Koni (y ekseni boyunca, uç +y): yarıçap r, yükseklik h
        public static GameObject Cone(Transform parent, Vector3 localPos, float r, float h, Material m, Vector3 euler = default, int seg = 6)
            => Shape(parent, Frustum(0, seg), localPos, new Vector3(r * 2, h, r * 2), m, euler);

        // Silindir (y ekseni): yarıçap r, yükseklik h
        public static GameObject Cyl(Transform parent, Vector3 localPos, float r, float h, Material m, Vector3 euler = default, int seg = 8)
            => Shape(parent, Frustum(1, seg), localPos, new Vector3(r * 2, h, r * 2), m, euler);

        // Kamerayı izleyen dokulu kare (parlama)
        public static GameObject Billboard(Transform parent, Vector3 localPos, float size, Color c, Texture2D tex = null)
        {
            var go = Shape(parent, quad, localPos, Vector3.one * size, UnlitTex(c, tex ?? TexGlow));
            go.AddComponent<UKFaceCam>();
            return go;
        }

        // ------------------------------------------------------------ efektler
        class Particle { public Transform t; public MeshRenderer r; public MeshFilter f; public Vector3 v, spin; public float life, max, g, size, grow; public bool blood, gib, smoke, casing; }
        class Timed { public GameObject go; public float life, max; public System.Action<float> tick; }
        class Fountain { public Transform t; public float life; }
        readonly List<Particle> parts = new List<Particle>();
        readonly Stack<Particle> pool = new Stack<Particle>();
        readonly List<Timed> timed = new List<Timed>();
        readonly List<Fountain> fountains = new List<Fountain>();
        readonly List<Light> lights = new List<Light>();
        readonly float[] lightT = new float[8], lightMax = new float[8], lightBase = new float[8];
        readonly Queue<GameObject> decals = new Queue<GameObject>();
        Material bloodMat, gibMat, decalMat, holeMat, scorchMat, brassMat, redShellMat;
        const int MaxParts = 520;

        void Awake()
        {
            I = this;
            bloodMat = Lit(new Color(0.55f, 0.02f, 0.02f), 0.2f);
            gibMat = Lit(new Color(0.75f, 0.25f, 0.25f), 0.1f, TexFlesh);
            decalMat = UnlitTex(new Color(0.75f, 0.1f, 0.1f, 0.9f), TexBlood);
            holeMat = UnlitTex(Color.white, TexHole);
            scorchMat = UnlitTex(new Color(0.05f, 0.03f, 0.02f, 0.85f), TexGlow);
            brassMat = Lit(new Color(0.85f, 0.63f, 0.25f), 0.15f);
            redShellMat = Lit(new Color(0.8f, 0.15f, 0.1f), 0.15f);
            for (int i = 0; i < 8; i++)
            {
                var l = new GameObject("fxLight").AddComponent<Light>();
                l.transform.SetParent(transform, false);
                l.type = LightType.Point;
                l.intensity = 0;
                l.shadows = LightShadows.None;
                l.enabled = false;
                lights.Add(l);
            }
        }

        Particle Get()
        {
            Particle p;
            if (parts.Count >= MaxParts) { p = parts[0]; parts.RemoveAt(0); }
            else if (pool.Count > 0) { p = pool.Pop(); p.t.gameObject.SetActive(true); }
            else
            {
                var go = new GameObject("fx");
                go.transform.SetParent(transform, false);
                var f = go.AddComponent<MeshFilter>();
                var r = go.AddComponent<MeshRenderer>();
                r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                p = new Particle { t = go.transform, r = r, f = f };
            }
            p.f.sharedMesh = cube;
            p.t.rotation = Quaternion.identity;
            p.blood = p.gib = p.smoke = p.casing = false;
            p.grow = 0;
            p.spin = Vector3.zero;
            return p;
        }

        public void Burst(Vector3 pos, int n, float speed, Color c, float life = 0.35f, float size = 0.06f, float grav = 10f, Vector3? dir = null, float spread = 1f)
        {
            var m = Unlit(c);
            for (int i = 0; i < n; i++)
            {
                var p = Get();
                Vector3 d = dir.HasValue ? (dir.Value.normalized + Random.insideUnitSphere * spread).normalized : Random.onUnitSphere;
                p.v = d * speed * Random.Range(0.4f, 1f);
                p.t.position = pos;
                p.size = size * Random.Range(0.6f, 1.3f);
                p.t.localScale = Vector3.one * p.size;
                p.r.sharedMaterial = m;
                p.life = p.max = life * Random.Range(0.6f, 1.2f);
                p.g = grav;
                parts.Add(p);
            }
        }

        // Yönlü kıvılcım (yüzey normali boyunca)
        public void Spark(Vector3 pos, Vector3 dir, int n, float speed, Color c, float life = 0.3f, float size = 0.05f, float spread = 0.7f)
            => Burst(pos, n, speed, c, life, size, 10f, dir, spread);

        public void Blood(Vector3 pos, int n, float speed, Vector3? dir = null)
        {
            for (int i = 0; i < n; i++)
            {
                var p = Get();
                Vector3 d = dir.HasValue && dir.Value != Vector3.zero ? (dir.Value.normalized * 0.7f + Random.insideUnitSphere * 0.8f + Vector3.up * 0.3f).normalized : (Random.onUnitSphere + Vector3.up * 0.5f).normalized;
                p.v = d * speed * Random.Range(0.3f, 1f);
                p.t.position = pos;
                p.size = Random.Range(0.05f, 0.14f);
                p.t.localScale = Vector3.one * p.size;
                p.r.sharedMaterial = bloodMat;
                p.life = p.max = Random.Range(0.6f, 1.4f);
                p.g = 22f;
                p.blood = true;
                parts.Add(p);
            }
        }

        public void Gib(Vector3 pos, Vector3 vel, float size, Material m = null)
        {
            var p = Get();
            p.v = vel;
            p.t.position = pos;
            p.size = size;
            p.t.localScale = new Vector3(size, size * Random.Range(0.6f, 1.3f), size * Random.Range(0.6f, 1.3f));
            p.r.sharedMaterial = m ?? gibMat;
            p.life = p.max = Random.Range(3f, 5f);
            p.g = 25f;
            p.gib = true;
            p.spin = Random.insideUnitSphere * 720f;
            parts.Add(p);
        }

        // Görsel parçayı dünyaya kopar (ölüm parçalanması)
        public void GibFromPart(Transform part, Vector3 vel, float life = -1)
        {
            var mr = part.GetComponent<MeshRenderer>();
            var mf = part.GetComponent<MeshFilter>();
            if (mr == null || mf == null) return;
            var p = Get();
            p.f.sharedMesh = mf.sharedMesh;
            p.v = vel;
            p.t.position = part.position;
            p.t.rotation = part.rotation;
            p.t.localScale = part.lossyScale;
            p.size = Mathf.Min(part.lossyScale.x, part.lossyScale.y, part.lossyScale.z);
            p.r.sharedMaterial = mr.sharedMaterial;
            p.life = p.max = life > 0 ? life : Random.Range(4f, 6f);
            p.g = 25f;
            p.gib = true;
            p.spin = Random.insideUnitSphere * 540f;
            parts.Add(p);
        }

        public void Casing(Vector3 pos, Vector3 vel, bool red)
        {
            var p = Get();
            p.v = vel;
            p.t.position = pos;
            p.size = 0.03f;
            p.t.localScale = red ? new Vector3(0.05f, 0.05f, 0.1f) : new Vector3(0.025f, 0.025f, 0.06f);
            p.r.sharedMaterial = red ? redShellMat : brassMat;
            p.life = p.max = 1.8f;
            p.g = 25f;
            p.gib = true;
            p.casing = true;
            p.spin = Random.insideUnitSphere * 1400f;
            parts.Add(p);
        }

        public void Debris(Vector3 pos, Vector3 normal, int n, float speed)
        {
            var m = Lit(new Color(0.5f, 0.45f, 0.4f));
            for (int i = 0; i < n; i++) Gib(pos + normal * 0.05f, (normal + Random.insideUnitSphere * 0.6f + Vector3.up * 0.4f) * speed * Random.Range(0.5f, 1f), Random.Range(0.04f, 0.09f), m);
        }

        // Duman: yükselip büyüyen yumuşak kareler
        public void Smoke(Vector3 pos, int n, Color c, float size = 0.5f, float life = 0.8f, float rise = 1f)
        {
            c.a = Mathf.Min(c.a, 0.55f);
            var m = UnlitTex(c, TexGlow);
            for (int i = 0; i < n; i++)
            {
                var p = Get();
                p.f.sharedMesh = quad;
                p.v = Random.insideUnitSphere * 0.6f + Vector3.up * rise;
                p.t.position = pos + Random.insideUnitSphere * size * 0.3f;
                p.size = size * Random.Range(0.6f, 1.1f);
                p.grow = size * 1.4f;
                p.t.localScale = Vector3.one * p.size;
                p.r.sharedMaterial = m;
                p.life = p.max = life * Random.Range(0.7f, 1.2f);
                p.g = 0;
                p.smoke = true;
                parts.Add(p);
            }
        }

        public void Tracer(Vector3 a, Vector3 b, Color c, float width = 0.05f, float life = 0.1f)
        {
            var go = new GameObject("tracer");
            go.transform.SetParent(transform, false);
            var lr = go.AddComponent<LineRenderer>();
            lr.sharedMaterial = unlitBase;
            lr.positionCount = 2;
            lr.SetPosition(0, a);
            lr.SetPosition(1, b);
            lr.startWidth = width;
            lr.endWidth = width * 0.6f;
            lr.startColor = lr.endColor = c;
            lr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            AddTimed(go, life, (k) => { var cc = c; cc.a = c.a * (1 - k); lr.startColor = lr.endColor = cc; lr.widthMultiplier = 1 - k * 0.6f; });
        }

        // Şimşek: zikzak çizgi (Piercer, railcannon)
        public void Lightning(Vector3 a, Vector3 b, Color c, float width = 0.03f, float life = 0.2f, int segs = 10, float jitter = 0.15f)
        {
            var go = new GameObject("bolt");
            go.transform.SetParent(transform, false);
            var lr = go.AddComponent<LineRenderer>();
            lr.sharedMaterial = unlitBase;
            lr.positionCount = segs + 1;
            for (int i = 0; i <= segs; i++)
            {
                var p = Vector3.Lerp(a, b, i / (float)segs);
                if (i > 0 && i < segs) p += Random.insideUnitSphere * jitter;
                lr.SetPosition(i, p);
            }
            lr.startWidth = lr.endWidth = width;
            lr.startColor = lr.endColor = c;
            lr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            AddTimed(go, life, (k) => { var cc = c; cc.a = c.a * (1 - k); lr.startColor = lr.endColor = cc; });
        }

        // Yerde büyüyen halka (çakma, sarsıntı dalgası, iniş)
        public void Ring(Vector3 pos, Color c, float radius, float life = 0.4f)
        {
            var go = new GameObject("ring");
            go.transform.SetParent(transform, false);
            go.transform.position = pos + Vector3.up * 0.05f;
            var lr = go.AddComponent<LineRenderer>();
            lr.sharedMaterial = unlitBase;
            lr.useWorldSpace = false;
            lr.loop = true;
            const int S = 32;
            lr.positionCount = S;
            for (int i = 0; i < S; i++) { float a = i * Mathf.PI * 2 / S; lr.SetPosition(i, new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a))); }
            lr.startWidth = lr.endWidth = 0.15f;
            lr.startColor = lr.endColor = c;
            AddTimed(go, life, (k) => { go.transform.localScale = Vector3.one * (0.1f + radius * (1 - (1 - k) * (1 - k))); var cc = c; cc.a = 1 - k; lr.startColor = lr.endColor = cc; });
        }

        // Kameraya dönük yumuşak parlama
        public void Glow(Vector3 pos, Color c, float size, float life = 0.15f, float grow = 1.6f) => Sprite(pos, c, size, life, grow, TexGlow);

        // Kameraya dönük yıldız parlaması (isabet, parry, glint)
        public void Star(Vector3 pos, Color c, float size, float life = 0.15f, float grow = 1.6f) => Sprite(pos, c, size, life, grow, TexStar);

        void Sprite(Vector3 pos, Color c, float size, float life, float grow, Texture2D tex)
        {
            var go = new GameObject("glow");
            go.transform.SetParent(transform, false);
            go.transform.position = pos;
            go.AddComponent<MeshFilter>().sharedMesh = quad;
            var r = go.AddComponent<MeshRenderer>();
            var m = new Material(UnlitTex(c, tex));
            r.sharedMaterial = m;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            var cam = Camera.main;
            float rot = Random.Range(0f, 90f);
            AddTimed(go, life, (k) =>
            {
                if (cam) go.transform.rotation = Quaternion.LookRotation(go.transform.position - cam.transform.position) * Quaternion.Euler(0, 0, rot + k * 90f);
                go.transform.localScale = Vector3.one * size * (1 + k * (grow - 1));
                var cc = c; cc.a = c.a * (1 - k * k);
                SetCol(m, cc);
            }, m);
        }

        // Genişleyen saydam şok küresi (Knuckleblaster, Jackhammer)
        public void Shell(Vector3 pos, Color c, float radius, float life = 0.3f)
        {
            var go = new GameObject("shell");
            go.transform.SetParent(transform, false);
            go.transform.position = pos;
            go.AddComponent<MeshFilter>().sharedMesh = sphere;
            var r = go.AddComponent<MeshRenderer>();
            var m = new Material(Unlit(c));
            r.sharedMaterial = m;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            AddTimed(go, life, (k) =>
            {
                go.transform.localScale = Vector3.one * radius * 2 * (0.2f + 0.8f * (1 - (1 - k) * (1 - k)));
                var cc = c; cc.a = 0.45f * (1 - k);
                SetCol(m, cc);
            }, m);
        }

        // Düşman yakın saldırısının önünde süpürülen parlak kavis
        public void Slash(Vector3 pos, float yawDeg, Color c, float size, float life = 0.2f, float tilt = 0)
        {
            var go = new GameObject("slash");
            go.transform.SetParent(transform, false);
            go.transform.position = pos;
            go.transform.rotation = Quaternion.Euler(0, yawDeg, tilt * Mathf.Rad2Deg);
            var lr = go.AddComponent<LineRenderer>();
            lr.sharedMaterial = unlitBase;
            lr.useWorldSpace = false;
            const int S = 14;
            lr.positionCount = S;
            for (int i = 0; i < S; i++)
            {
                float a = Mathf.Lerp(-1.1f, 1.1f, i / (S - 1f));
                lr.SetPosition(i, new Vector3(Mathf.Sin(a), 0, Mathf.Cos(a) - 0.6f) * size * 0.5f);
            }
            lr.widthCurve = new AnimationCurve(new Keyframe(0, 0.02f), new Keyframe(0.5f, 0.22f), new Keyframe(1, 0.02f));
            lr.startColor = lr.endColor = c;
            lr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            AddTimed(go, life, (k) => { var cc = c; cc.a = c.a * (1 - k); lr.startColor = lr.endColor = cc; go.transform.localScale = Vector3.one * (0.8f + k * 0.4f); });
        }

        public void Explosion(Vector3 pos, float radius)
        {
            Glow(pos, new Color(1f, 0.55f, 0.15f), radius * 1.8f, 0.35f, 1.8f);
            Glow(pos, new Color(1f, 0.95f, 0.7f), radius * 0.9f, 0.2f, 1.5f);
            Shell(pos, new Color(1f, 0.6f, 0.25f), radius * 0.9f, 0.3f);
            Burst(pos, 40, radius * 3f, new Color(1f, 0.6f, 0.2f), 0.7f, 0.12f, 12f);
            Smoke(pos, 6, new Color(0.35f, 0.3f, 0.28f), radius * 0.5f, 1.2f, 1.5f);
            Ring(pos, new Color(1f, 0.5f, 0.2f), radius * 1.4f, 0.5f);
            Flash(pos, new Color(1f, 0.55f, 0.2f), 8f, radius * 5f, 0.25f);
        }

        public void SpawnFX(Vector3 pos, float h)
        {
            Ring(pos, new Color(0.6f, 0.85f, 1f), 2.5f, 0.6f);
            Burst(pos + Vector3.up * h * 0.5f, 20, 6, new Color(0.63f, 0.88f, 1f), 0.6f, 0.07f, -2);
            Flash(pos + Vector3.up, new Color(0.5f, 0.75f, 1f), 3, 8, 0.4f);
        }

        public void Flash(Vector3 pos, Color c, float intensity, float range, float dur)
        {
            int best = 0;
            for (int i = 1; i < lights.Count; i++) if (lightT[i] < lightT[best]) best = i;
            var l = lights[best];
            l.transform.position = pos;
            l.color = c;
            l.range = range;
            l.enabled = true;
            lightT[best] = lightMax[best] = dur;
            lightBase[best] = intensity * LightMul;
        }

        void AddDecal(Vector3 pos, Vector3 normal, float size, Material m)
        {
            var go = new GameObject("decal");
            go.transform.SetParent(transform, false);
            go.transform.position = pos + normal * 0.02f;
            go.transform.rotation = Quaternion.LookRotation(-normal) * Quaternion.Euler(0, 0, Random.Range(0, 360f));
            go.transform.localScale = Vector3.one * size;
            go.AddComponent<MeshFilter>().sharedMesh = quad;
            var r = go.AddComponent<MeshRenderer>();
            r.sharedMaterial = m;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            decals.Enqueue(go);
            if (decals.Count > 220) Destroy(decals.Dequeue());
        }

        public void Decal(Vector3 pos, Vector3 normal, float size) => AddDecal(pos, normal, size * Random.Range(0.7f, 1.3f), decalMat);
        public void BulletHole(Vector3 pos, Vector3 normal, float size) => AddDecal(pos, normal, size, holeMat);
        public void Scorch(Vector3 pos, Vector3 normal, float size) => AddDecal(pos, normal, size, scorchMat);

        // Kopan uzvun/kafanın yerinden bir süre kan fışkırır
        public void BloodFountain(Transform t, float dur)
        {
            if (t != null) fountains.Add(new Fountain { t = t, life = dur });
        }

        void AddTimed(GameObject go, float life, System.Action<float> tick, Material own = null)
        {
            tick(0);
            timed.Add(new Timed { go = go, life = life, max = life, tick = tick });
            if (own != null) go.AddComponent<UKOwnMat>().m = own;
        }

        public void ClearAll()
        {
            foreach (var p in parts) { p.t.gameObject.SetActive(false); pool.Push(p); }
            parts.Clear();
            foreach (var t in timed) if (t.go) Destroy(t.go);
            timed.Clear();
            fountains.Clear();
            while (decals.Count > 0) { var d = decals.Dequeue(); if (d) Destroy(d); }
            for (int i = 0; i < lights.Count; i++) { lightT[i] = 0; lights[i].enabled = false; }
        }

        void Update()
        {
            float dt = Time.deltaTime;
            var cam = Camera.main;
            for (int i = parts.Count - 1; i >= 0; i--)
            {
                var p = parts[i];
                p.life -= dt;
                if (p.life <= 0) { p.t.gameObject.SetActive(false); pool.Push(p); parts.RemoveAt(i); continue; }
                p.v.y -= p.g * dt;
                Vector3 step = p.v * dt;
                if ((p.blood || p.gib) && step.sqrMagnitude > 1e-6f && Physics.Raycast(p.t.position, step.normalized, out var hit, step.magnitude + p.size * 0.5f, RayMask, QueryTriggerInteraction.Ignore) && !(hit.collider is CharacterController) && hit.collider.GetComponent<UKHitbox>() == null)
                {
                    if (p.blood)
                    {
                        if (Random.value < 0.35f) Decal(hit.point, hit.normal, Random.Range(0.3f, 0.8f));
                        p.life = 0.01f;
                        p.t.position = hit.point;
                        continue;
                    }
                    if (p.casing && p.v.magnitude > 3 && Random.value < 0.5f) UKAudio.I.PlayAt("shell", hit.point, 0.5f, Random.Range(0.8f, 1.3f));
                    p.v = Vector3.Reflect(p.v, hit.normal) * 0.35f;
                    p.spin *= 0.5f;
                    p.t.position = hit.point + hit.normal * p.size * 0.5f;
                    if (p.v.magnitude < 1f) { p.v = Vector3.zero; p.g = 0; p.spin = Vector3.zero; }
                }
                else
                {
                    p.t.position += step;
                    if (p.smoke) p.v *= Mathf.Exp(-dt * 1.5f);
                }
                if (p.smoke)
                {
                    float k = 1 - p.life / p.max;
                    if (cam) p.t.rotation = Quaternion.LookRotation(p.t.position - cam.transform.position);
                    p.t.localScale = Vector3.one * (p.size + p.grow * k) * Mathf.Min(1, (1 - k) * 3);
                    continue;
                }
                if (p.spin != Vector3.zero) p.t.Rotate(p.spin * dt);
                if (!p.gib) p.t.localScale = Vector3.one * p.size * Mathf.Clamp01(p.life / p.max * 1.5f);
                else if (p.life < 0.6f) p.t.localScale *= 1 - dt * 3;
            }
            for (int i = timed.Count - 1; i >= 0; i--)
            {
                var t = timed[i];
                t.life -= dt;
                if (t.life <= 0 || t.go == null) { if (t.go) Destroy(t.go); timed.RemoveAt(i); continue; }
                t.tick(1 - t.life / t.max);
            }
            for (int i = fountains.Count - 1; i >= 0; i--)
            {
                var f = fountains[i];
                f.life -= dt;
                if (f.life <= 0 || f.t == null) { fountains.RemoveAt(i); continue; }
                if (dt > 0 && Random.value < dt * 40) Blood(f.t.position, 2, 7, f.t.up + Vector3.up);
            }
            for (int i = 0; i < lights.Count; i++)
            {
                if (lightT[i] <= 0) { if (lights[i].enabled) lights[i].enabled = false; continue; }
                lightT[i] -= dt;
                lights[i].intensity = lightBase[i] * Mathf.Max(0, lightT[i] / lightMax[i]);
            }
        }
    }

    // Kameraya dönen parça (parlama sprite'ları)
    public class UKFaceCam : MonoBehaviour
    {
        void LateUpdate()
        {
            var cam = Camera.main;
            if (cam) transform.rotation = Quaternion.LookRotation(transform.position - cam.transform.position);
        }
    }

    // Nesneyle birlikte yok edilecek kopya malzeme (sızıntı olmasın)
    public class UKOwnMat : MonoBehaviour
    {
        public Material m;
        void OnDestroy() { if (m) Destroy(m); }
    }
}
