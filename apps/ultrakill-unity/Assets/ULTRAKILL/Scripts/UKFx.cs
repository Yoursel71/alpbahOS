// Malzemeler, kodla üretilen dokular, kutu ağları ve görsel efektler (parçacık, iz, halka, parlama,
// ışık, kan lekesi). Her şey çalışma anında üretilir; proje içinde doku/malzeme dosyası gerekmez.
// Built-in ve URP ile çalışır: temel ışıklı malzeme bir ilkel küpün varsayılan malzemesinden alınır.
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKFx : MonoBehaviour
    {
        public static UKFx I;
        static Material litBase, unlitBase;
        static Mesh cube, quad;
        static readonly Dictionary<string, Material> cache = new Dictionary<string, Material>();
        static readonly Dictionary<Vector4, Mesh> boxMeshes = new Dictionary<Vector4, Mesh>();
        public static Texture2D TexStone, TexTiles, TexMetal, TexRock, TexFlesh, TexNoise;

        // ------------------------------------------------------------ malzemeler
        public static void Init()
        {
            // Domain reload kapalıyken önceki oturumun yok edilmiş nesneleri önbellekte kalabilir
            if (litBase != null && cube != null && quad != null && TexStone != null) return;
            cache.Clear();
            boxMeshes.Clear();
            var tmp = GameObject.CreatePrimitive(PrimitiveType.Cube);
            litBase = tmp.GetComponent<MeshRenderer>().sharedMaterial;
            cube = tmp.GetComponent<MeshFilter>().sharedMesh;
            DestroyImmediate(tmp);
            var tq = GameObject.CreatePrimitive(PrimitiveType.Quad);
            quad = tq.GetComponent<MeshFilter>().sharedMesh;
            DestroyImmediate(tq);
            var sh = Shader.Find("Sprites/Default");
            unlitBase = sh != null ? new Material(sh) : new Material(litBase);
            TexStone = MakeTex(0, new Color(0.25f, 0.19f, 0.17f), new Color(0.43f, 0.36f, 0.32f));
            TexTiles = MakeTex(1, new Color(0.18f, 0.15f, 0.14f), new Color(0.35f, 0.3f, 0.27f));
            TexMetal = MakeTex(2, new Color(0.24f, 0.25f, 0.28f), new Color(0.42f, 0.44f, 0.48f));
            TexRock = MakeTex(3, new Color(0.16f, 0.06f, 0.04f), new Color(0.42f, 0.17f, 0.11f));
            TexFlesh = MakeTex(3, new Color(0.24f, 0.02f, 0.03f), new Color(0.56f, 0.11f, 0.1f));
            TexNoise = MakeTex(4, new Color(0.7f, 0.7f, 0.7f), Color.white);
        }

        public static Mesh Cube => cube;
        // URP/HDRP nokta ışıkları fiziksel (1/d²) söner; yerleşik hattaki parlaklığa yaklaştırmak için çarpan
        public static bool SRP => UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline != null;
        public static float LightMul => SRP ? 4f : 1f;
        public static Mesh Quad => quad;

        static void SetCol(Material m, Color c)
        {
            if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", c);
            if (m.HasProperty("_Color")) m.SetColor("_Color", c);
        }

        // Işıklı (gölgeli) malzeme; emit > 0 → kendi renginde parlar
        public static Material Lit(Color c, float emit = 0f, Texture2D tex = null)
        {
            string key = "L" + c + emit + (tex ? tex.name : "");
            if (cache.TryGetValue(key, out var m) && m != null) return m;
            m = new Material(litBase);
            SetCol(m, c);
            if (tex != null)
            {
                if (m.HasProperty("_BaseMap")) m.SetTexture("_BaseMap", tex);
                if (m.HasProperty("_MainTex")) m.SetTexture("_MainTex", tex);
            }
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

        // 64×64 piksel kodla doku (0 taş tuğla, 1 karo, 2 metal plaka, 3 kaya/et, 4 gürültü)
        static Texture2D MakeTex(int kind, Color a, Color b)
        {
            const int N = 64;
            var t = new Texture2D(N, N, TextureFormat.RGBA32, true) { filterMode = FilterMode.Point, wrapMode = TextureWrapMode.Repeat, name = "uk" + kind + a };
            var px = new Color[N * N];
            float seed = kind * 17.3f;
            for (int y = 0; y < N; y++)
                for (int x = 0; x < N; x++)
                {
                    float n = Mathf.PerlinNoise(x * 0.09f + seed, y * 0.09f + seed) * 0.7f + Mathf.PerlinNoise(x * 0.3f + seed, y * 0.3f) * 0.3f;
                    Color c = Color.Lerp(a, b, n);
                    if (kind == 0)
                    {
                        int row = y / 8, off = (row % 2) * 8;
                        if (y % 8 == 0 || (x + off) % 16 == 0) c *= 0.45f;
                        else if (y % 8 == 1 || (x + off) % 16 == 1) c *= 1.15f;
                    }
                    else if (kind == 1)
                    {
                        if (x % 16 == 0 || y % 16 == 0) c *= 0.4f;
                        else if (x % 16 == 1 || y % 16 == 1) c *= 1.2f;
                    }
                    else if (kind == 2)
                    {
                        if (x % 32 == 0 || y % 32 == 0) c *= 0.5f;
                        int rx = x % 32, ry = y % 32;
                        if ((rx == 4 || rx == 27) && (ry == 4 || ry == 27)) c = b * 1.4f;
                    }
                    else if (kind == 3)
                    {
                        float r = Mathf.Abs(Mathf.PerlinNoise(x * 0.12f + 40, y * 0.12f) - 0.5f);
                        if (r < 0.03f) c *= 0.35f;
                    }
                    c.a = 1f;
                    px[y * N + x] = c;
                }
            t.SetPixels(px);
            t.Apply(true);
            return t;
        }

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

        // Çarpışmasız görsel kutu (model parçaları için)
        public static GameObject Part(Transform parent, Vector3 localPos, Vector3 size, Material m, Vector3 euler = default)
        {
            var go = new GameObject("p");
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localEulerAngles = euler;
            go.transform.localScale = size;
            go.AddComponent<MeshFilter>().sharedMesh = cube;
            var r = go.AddComponent<MeshRenderer>();
            r.sharedMaterial = m;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            return go;
        }

        // ------------------------------------------------------------ efektler
        class Particle { public Transform t; public MeshRenderer r; public Vector3 v, spin; public float life, max, g, size; public bool blood, gib; }
        class Timed { public GameObject go; public float life, max; public System.Action<float> tick; }
        readonly List<Particle> parts = new List<Particle>();
        readonly Stack<Particle> pool = new Stack<Particle>();
        readonly List<Timed> timed = new List<Timed>();
        readonly List<Light> lights = new List<Light>();
        readonly float[] lightT = new float[6], lightMax = new float[6], lightBase = new float[6];
        readonly Queue<GameObject> decals = new Queue<GameObject>();
        Material bloodMat, gibMat, decalMat;
        const int MaxParts = 420;

        void Awake()
        {
            I = this;
            bloodMat = Lit(new Color(0.55f, 0.02f, 0.02f), 0.2f);
            gibMat = Lit(new Color(0.75f, 0.25f, 0.25f), 0.1f, TexFlesh);
            decalMat = Unlit(new Color(0.35f, 0f, 0f, 0.85f));
            for (int i = 0; i < 6; i++)
            {
                var l = new GameObject("fxLight").AddComponent<Light>();
                l.transform.SetParent(transform, false);
                l.type = LightType.Point;
                l.intensity = 0;
                l.enabled = false;
                lights.Add(l);
            }
        }

        Particle Get()
        {
            if (parts.Count >= MaxParts) { var old = parts[0]; parts.RemoveAt(0); return old; }
            if (pool.Count > 0) { var p = pool.Pop(); p.t.gameObject.SetActive(true); return p; }
            var go = new GameObject("fx");
            go.transform.SetParent(transform, false);
            go.AddComponent<MeshFilter>().sharedMesh = cube;
            var r = go.AddComponent<MeshRenderer>();
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            return new Particle { t = go.transform, r = r };
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
                p.blood = false; p.gib = false;
                p.spin = Vector3.zero;
                parts.Add(p);
            }
        }

        public void Blood(Vector3 pos, int n, float speed, Vector3? dir = null)
        {
            for (int i = 0; i < n; i++)
            {
                var p = Get();
                Vector3 d = dir.HasValue ? (dir.Value.normalized * 0.7f + Random.insideUnitSphere * 0.8f + Vector3.up * 0.3f).normalized : (Random.onUnitSphere + Vector3.up * 0.5f).normalized;
                p.v = d * speed * Random.Range(0.3f, 1f);
                p.t.position = pos;
                p.size = Random.Range(0.05f, 0.14f);
                p.t.localScale = Vector3.one * p.size;
                p.r.sharedMaterial = bloodMat;
                p.life = p.max = Random.Range(0.6f, 1.4f);
                p.g = 22f;
                p.blood = true; p.gib = false;
                p.spin = Vector3.zero;
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
            p.blood = false; p.gib = true;
            p.spin = Random.insideUnitSphere * 720f;
            parts.Add(p);
        }

        // Görsel parçayı dünyaya kopar (ölüm parçalanması)
        public void GibFromPart(Transform part, Vector3 vel)
        {
            var mr = part.GetComponent<MeshRenderer>();
            if (mr == null) return;
            var p = Get();
            p.v = vel;
            p.t.position = part.position;
            p.t.rotation = part.rotation;
            p.t.localScale = part.lossyScale;
            p.size = Mathf.Min(part.lossyScale.x, part.lossyScale.y, part.lossyScale.z);
            p.r.sharedMaterial = mr.sharedMaterial;
            p.life = p.max = Random.Range(4f, 6f);
            p.g = 25f;
            p.blood = false; p.gib = true;
            p.spin = Random.insideUnitSphere * 540f;
            parts.Add(p);
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

        // Kameraya dönük parlama karesi
        public void Glow(Vector3 pos, Color c, float size, float life = 0.15f, float grow = 1.6f)
        {
            var go = new GameObject("glow");
            go.transform.SetParent(transform, false);
            go.transform.position = pos;
            go.AddComponent<MeshFilter>().sharedMesh = quad;
            var r = go.AddComponent<MeshRenderer>();
            r.sharedMaterial = Unlit(c);
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            var cam = Camera.main;
            AddTimed(go, life, (k) =>
            {
                if (cam) go.transform.rotation = Quaternion.LookRotation(go.transform.position - cam.transform.position);
                go.transform.localScale = Vector3.one * size * (1 + k * (grow - 1)) * (1 - k * 0.5f);
                go.transform.Rotate(0, 0, k * 90f);
            });
        }

        public void Explosion(Vector3 pos, float radius)
        {
            Glow(pos, new Color(1f, 0.55f, 0.15f), radius * 1.8f, 0.35f, 1.8f);
            Glow(pos, new Color(1f, 0.95f, 0.7f), radius * 0.9f, 0.2f, 1.5f);
            Burst(pos, 40, radius * 3f, new Color(1f, 0.6f, 0.2f), 0.7f, 0.12f, 12f);
            Ring(pos, new Color(1f, 0.5f, 0.2f), radius * 1.4f, 0.5f);
            Flash(pos, new Color(1f, 0.55f, 0.2f), 8f, radius * 5f, 0.25f);
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

        public void Decal(Vector3 pos, Vector3 normal, float size)
        {
            var go = new GameObject("decal");
            go.transform.SetParent(transform, false);
            go.transform.position = pos + normal * 0.02f;
            go.transform.rotation = Quaternion.LookRotation(-normal) * Quaternion.Euler(0, 0, Random.Range(0, 360f));
            go.transform.localScale = Vector3.one * size * Random.Range(0.7f, 1.3f);
            go.AddComponent<MeshFilter>().sharedMesh = quad;
            var r = go.AddComponent<MeshRenderer>();
            r.sharedMaterial = decalMat;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            decals.Enqueue(go);
            if (decals.Count > 160) Destroy(decals.Dequeue());
        }

        void AddTimed(GameObject go, float life, System.Action<float> tick)
        {
            tick(0);
            timed.Add(new Timed { go = go, life = life, max = life, tick = tick });
        }

        public void ClearAll()
        {
            foreach (var p in parts) { p.t.gameObject.SetActive(false); pool.Push(p); }
            parts.Clear();
            foreach (var t in timed) Destroy(t.go);
            timed.Clear();
            while (decals.Count > 0) Destroy(decals.Dequeue());
        }

        void Update()
        {
            float dt = Time.deltaTime;
            for (int i = parts.Count - 1; i >= 0; i--)
            {
                var p = parts[i];
                p.life -= dt;
                if (p.life <= 0) { p.t.gameObject.SetActive(false); pool.Push(p); parts.RemoveAt(i); continue; }
                p.v.y -= p.g * dt;
                Vector3 step = p.v * dt;
                if ((p.blood || p.gib) && step.sqrMagnitude > 1e-6f && Physics.Raycast(p.t.position, step.normalized, out var hit, step.magnitude + p.size * 0.5f, ~0, QueryTriggerInteraction.Ignore) && !(hit.collider is CharacterController) && hit.collider.GetComponent<UKHitbox>() == null)
                {
                    if (p.blood)
                    {
                        if (Random.value < 0.35f) Decal(hit.point, hit.normal, Random.Range(0.3f, 0.8f));
                        p.life = 0.01f;
                        p.t.position = hit.point;
                        continue;
                    }
                    p.v = Vector3.Reflect(p.v, hit.normal) * 0.35f;
                    p.spin *= 0.5f;
                    p.t.position = hit.point + hit.normal * p.size * 0.5f;
                    if (p.v.magnitude < 1f) { p.v = Vector3.zero; p.g = 0; p.spin = Vector3.zero; }
                }
                else p.t.position += step;
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
            for (int i = 0; i < lights.Count; i++)
            {
                if (lightT[i] <= 0) { if (lights[i].enabled) lights[i].enabled = false; continue; }
                lightT[i] -= dt;
                lights[i].intensity = lightBase[i] * Mathf.Max(0, lightT[i] / lightMax[i]);
            }
        }
    }
}
