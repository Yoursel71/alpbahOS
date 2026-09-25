// Silahlar ve görünür modeller: 1 Revolver (sol tık; sağ tık basılı → PIERCER delici atış),
// 2 Shotgun (12 saçma; sağ tık → çekirdek bombası), 3 Nailgun (basılı tut: çivi yağmuru),
// F Feedbacker yumruğu ve PARRY. Görünür kol/silah modelleri ilkel kutulardan kurulur; yerleşik
// render hattında ayrı bir görünür-model kamerası duvara girmeyi önler.
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKWeapons : MonoBehaviour
    {
        class Gun
        {
            public string name, sub;
            public Transform root, model, muzzle, spin;
            public Vector3 basePos;
            public Color accent;
        }

        public int cur;
        readonly List<Gun> guns = new List<Gun>();
        readonly float[] cd = new float[3];
        Transform vm, arm;
        Camera vmCam;
        float switchT = 1, recoil, recoilRot, swayX, swayY, pierce, nailT, punchT = 9, punchCd, armT = 9, spinT = 1, flashT, coreHold;
        bool pierceReady, armParry;
        Light muzzleLight;
        GameObject flash;
        UKPlayer P => UKGame.I.player;
        const int VM_LAYER = 1; // yerleşik "TransparentFX" katmanı: yalnız görünür-model kamerası çizer

        public string CurName => guns.Count > 0 ? guns[cur].name : "";
        public string CurSub => guns.Count > 0 ? guns[cur].sub : "";
        public Color CurAccent => guns.Count > 0 ? guns[cur].accent : Color.white;
        public float PierceCharge => pierce;
        public string CurKey => cur == 0 ? "revolver" : cur == 1 ? "shotgun" : "nailgun";

        // menüde / ölümde görünür modeli gizle
        public void SetVisible(bool on)
        {
            if (vm) vm.gameObject.SetActive(on);
            if (vmCam) vmCam.enabled = on;
        }

        public void Setup(Camera mainCam)
        {
            vm = new GameObject("Viewmodel").transform;
            vm.SetParent(mainCam.transform, false);
            bool srp = UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline != null;
            if (!srp)
            {
                // ayrı kamera: silah duvarların önünde çizilir
                vmCam = new GameObject("VMCam").AddComponent<Camera>();
                vmCam.transform.SetParent(mainCam.transform, false);
                vmCam.clearFlags = CameraClearFlags.Depth;
                vmCam.cullingMask = 1 << VM_LAYER;
                vmCam.depth = mainCam.depth + 1;
                vmCam.nearClipPlane = 0.01f;
                vmCam.farClipPlane = 10f;
                vmCam.fieldOfView = 62f;
                mainCam.cullingMask &= ~(1 << VM_LAYER);
            }
            var metal = UKFx.Lit(new Color(0.66f, 0.68f, 0.73f), 0, UKFx.TexMetal);
            var dark = UKFx.Lit(new Color(0.23f, 0.24f, 0.27f), 0, UKFx.TexMetal);
            var grip = UKFx.Lit(new Color(0.55f, 0.4f, 0.3f));
            var armMat = UKFx.Lit(new Color(0.72f, 0.75f, 0.82f), 0, UKFx.TexMetal);
            var blue = UKFx.Lit(new Color(0.29f, 0.55f, 1f), 0.4f);

            // REVOLVER
            {
                var g = NewGun("REVOLVER", "PIERCER", new Vector3(0.24f, -0.25f, 0.5f), new Color(0.23f, 0.63f, 1f));
                var m = g.model;
                UKFx.Part(m, new Vector3(0, 0, 0.02f), new Vector3(0.075f, 0.085f, 0.2f), metal);
                UKFx.Part(m, new Vector3(0, 0.043f, 0.32f), new Vector3(0.05f, 0.05f, 0.3f), dark);
                UKFx.Part(m, new Vector3(0, 0.058f, 0.1f), new Vector3(0.05f, 0.026f, 0.25f), metal);
                var drum = new GameObject("drum").transform;
                drum.SetParent(m, false);
                drum.localPosition = new Vector3(0, 0.022f, 0.1f);
                UKFx.Part(drum, Vector3.zero, new Vector3(0.12f, 0.12f, 0.13f), metal);
                for (int k = 0; k < 6; k++)
                {
                    float a = k * Mathf.PI / 3;
                    UKFx.Part(drum, new Vector3(Mathf.Cos(a) * 0.058f, Mathf.Sin(a) * 0.058f, 0), new Vector3(0.02f, 0.02f, 0.11f), UKFx.Lit(g.accent, 0.8f));
                }
                g.spin = drum;
                UKFx.Part(m, new Vector3(0, 0.022f, 0.02f), new Vector3(0.078f, 0.02f, 0.14f), UKFx.Lit(g.accent, 0.8f));
                UKFx.Part(m, new Vector3(0, -0.1f, -0.08f), new Vector3(0.062f, 0.18f, 0.082f), grip, new Vector3(-16, 0, 0));
                Hand(m, new Vector3(0, -0.1f, -0.1f), armMat);
                g.muzzle = Anchor(m, new Vector3(0, 0.043f, 0.5f));
            }
            // SHOTGUN
            {
                var g = NewGun("SHOTGUN", "CORE EJECT", new Vector3(0.26f, -0.29f, 0.58f), new Color(0.23f, 0.63f, 1f));
                var m = g.model;
                UKFx.Part(m, new Vector3(0, 0, 0.02f), new Vector3(0.1f, 0.13f, 0.32f), metal);
                UKFx.Part(m, new Vector3(0, 0.038f, 0.49f), new Vector3(0.07f, 0.07f, 0.62f), dark);
                UKFx.Part(m, new Vector3(0, -0.03f, 0.42f), new Vector3(0.052f, 0.052f, 0.44f), dark);
                var pump = new GameObject("pump").transform;
                pump.SetParent(m, false);
                pump.localPosition = new Vector3(0, -0.03f, 0.4f);
                UKFx.Part(pump, Vector3.zero, new Vector3(0.09f, 0.08f, 0.22f), grip);
                g.spin = pump;
                UKFx.Part(m, new Vector3(0, -0.06f, -0.28f), new Vector3(0.072f, 0.11f, 0.3f), grip, new Vector3(8, 0, 0));
                UKFx.Part(m, new Vector3(0, 0.088f, 0.42f), new Vector3(0.02f, 0.012f, 0.52f), UKFx.Lit(g.accent, 0.8f));
                UKFx.Part(m, new Vector3(-0.058f, 0, 0.02f), new Vector3(0.06f, 0.06f, 0.1f), UKFx.Lit(g.accent, 0.8f));
                Hand(m, new Vector3(0, -0.1f, -0.1f), armMat);
                g.muzzle = Anchor(m, new Vector3(0, 0.038f, 0.86f));
            }
            // NAILGUN
            {
                var g = NewGun("NAILGUN", "ATTRACTOR", new Vector3(0.26f, -0.28f, 0.56f), new Color(0.23f, 0.63f, 1f));
                var m = g.model;
                UKFx.Part(m, new Vector3(0, 0, 0.05f), new Vector3(0.12f, 0.13f, 0.34f), metal);
                UKFx.Part(m, new Vector3(0, 0.1f, 0.02f), new Vector3(0.1f, 0.1f, 0.14f), dark);
                var barrels = new GameObject("barrels").transform;
                barrels.SetParent(m, false);
                barrels.localPosition = new Vector3(0, 0.01f, 0.36f);
                for (int k = 0; k < 4; k++)
                {
                    float a = k * Mathf.PI / 2;
                    UKFx.Part(barrels, new Vector3(Mathf.Cos(a) * 0.035f, Mathf.Sin(a) * 0.035f, 0), new Vector3(0.03f, 0.03f, 0.34f), dark);
                }
                UKFx.Part(barrels, new Vector3(0, 0, 0.14f), new Vector3(0.11f, 0.11f, 0.03f), metal);
                g.spin = barrels;
                UKFx.Part(m, new Vector3(0, -0.03f, 0.05f), new Vector3(0.124f, 0.02f, 0.2f), UKFx.Lit(g.accent, 0.8f));
                UKFx.Part(m, new Vector3(0, -0.12f, -0.08f), new Vector3(0.06f, 0.16f, 0.08f), grip, new Vector3(-14, 0, 0));
                Hand(m, new Vector3(0, -0.1f, -0.1f), armMat);
                g.muzzle = Anchor(m, new Vector3(0, 0.01f, 0.55f));
            }
            // FEEDBACKER (sol kol): ön kol + parmaklı yumruk
            arm = new GameObject("Feedbacker").transform;
            arm.SetParent(vm, false);
            UKFx.Part(arm, new Vector3(0, 0, -0.17f), new Vector3(0.12f, 0.115f, 0.26f), blue);
            UKFx.Part(arm, new Vector3(0, -0.005f, -0.42f), new Vector3(0.105f, 0.1f, 0.26f), armMat);
            UKFx.Part(arm, new Vector3(0.062f, 0.025f, -0.17f), new Vector3(0.016f, 0.02f, 0.2f), UKFx.Lit(new Color(0.56f, 0.82f, 1f), 1.2f));
            UKFx.Part(arm, new Vector3(-0.062f, 0.025f, -0.17f), new Vector3(0.016f, 0.02f, 0.2f), UKFx.Lit(new Color(0.56f, 0.82f, 1f), 1.2f));
            UKFx.Part(arm, new Vector3(0, 0, 0.02f), new Vector3(0.13f, 0.12f, 0.14f), blue);
            for (int k = 0; k < 4; k++) UKFx.Part(arm, new Vector3(-0.045f + k * 0.03f, 0.03f, 0.1f), new Vector3(0.026f, 0.05f, 0.04f), armMat);
            arm.gameObject.SetActive(false);

            // namlu alevi ve ışığı
            flash = new GameObject("flash");
            flash.transform.SetParent(vm, false);
            flash.AddComponent<MeshFilter>().sharedMesh = UKFx.Quad;
            var fr = flash.AddComponent<MeshRenderer>();
            fr.sharedMaterial = UKFx.Unlit(new Color(1f, 0.85f, 0.5f, 0.95f));
            flash.SetActive(false);
            muzzleLight = new GameObject("muzzleLight").AddComponent<Light>();
            muzzleLight.transform.SetParent(vm, false);
            muzzleLight.type = LightType.Point;
            muzzleLight.range = 6;
            muzzleLight.color = new Color(1f, 0.75f, 0.45f);
            muzzleLight.intensity = 0;
            if (!srp) SetLayer(vm, VM_LAYER);
            // SRP'de ayrı kamera yok: modeli kameraya doğru orantılı küçült. Perspektifte aynı görünür,
            // ama oyuncu kapsülünün (0,4 m) içinde kaldığı için duvara girmez.
            else vm.localScale = Vector3.one * 0.35f;
            Select(0, true);
        }

        static void SetLayer(Transform t, int layer)
        {
            t.gameObject.layer = layer;
            foreach (Transform c in t) SetLayer(c, layer);
        }

        Gun NewGun(string name, string sub, Vector3 basePos, Color accent)
        {
            var g = new Gun { name = name, sub = sub, basePos = basePos, accent = accent };
            g.root = new GameObject(name).transform;
            g.root.SetParent(vm, false);
            g.model = new GameObject("model").transform;
            g.model.SetParent(g.root, false);
            g.root.localPosition = basePos;
            guns.Add(g);
            return g;
        }

        static Transform Anchor(Transform parent, Vector3 pos)
        {
            var t = new GameObject("muzzle").transform;
            t.SetParent(parent, false);
            t.localPosition = pos;
            return t;
        }

        static void Hand(Transform parent, Vector3 pos, Material m)
        {
            UKFx.Part(parent, pos, new Vector3(0.1f, 0.1f, 0.1f), m);
            UKFx.Part(parent, pos + new Vector3(0, -0.02f, 0.28f), new Vector3(0.11f, 0.11f, 0.4f), m, new Vector3(-10, 0, 0));
        }

        public void ResetAll()
        {
            for (int i = 0; i < cd.Length; i++) cd[i] = 0;
            pierce = 0;
            pierceReady = false;
            Select(0, true);
        }

        void Select(int i, bool instant = false)
        {
            if (i == cur && !instant) return;
            cur = i;
            for (int k = 0; k < guns.Count; k++) guns[k].root.gameObject.SetActive(k == i);
            switchT = instant ? 1 : 0;
            if (i == 0) spinT = 0;
            pierce = 0;
            UKAudio.I.Play("pump", 0.4f, 1.4f);
        }

        public void OnMove(string ev)
        {
            if (ev == "land") recoil += 0.4f;
            else if (ev == "jump") recoil -= 0.2f;
            else if (ev == "dash") swayX += 0.05f;
        }

        Vector3 MuzzleWorld() => guns[cur].muzzle.position;

        // ------------------------------------------------------------ güncelleme
        public void Tick(float dt)
        {
            var game = UKGame.I;
            for (int i = 0; i < cd.Length; i++) cd[i] = Mathf.Max(0, cd[i] - dt);
            punchCd = Mathf.Max(0, punchCd - dt);
            if (!P.dead && game.state == UKGame.State.Playing)
            {
                if (UKInput.Down(UKKey.N1)) Select(0);
                if (UKInput.Down(UKKey.N2)) Select(1);
                if (UKInput.Down(UKKey.N3)) Select(2);
                float sc = UKInput.Scroll;
                if (sc > 0.1f) Select((cur + 1) % 3);
                else if (sc < -0.1f) Select((cur + 2) % 3);
                if (UKInput.Down(UKKey.F)) Punch();
                if (switchT >= 0.8f) FireLogic(dt);
            }
            Animate(dt);
        }

        void FireLogic(float dt)
        {
            bool fire = UKInput.Held(UKKey.Mouse0), alt = UKInput.Held(UKKey.Mouse1);
            if (cur == 0)
            {
                if (alt && cd[0] <= 0)
                {
                    pierce = Mathf.Min(1, pierce + dt / 0.55f);
                    if (pierce >= 1 && !pierceReady) { pierceReady = true; UKAudio.I.Play("charge"); }
                }
                else if (pierce > 0)
                {
                    if (pierce >= 1) FirePiercer();
                    pierce = 0;
                    pierceReady = false;
                }
                if (fire && cd[0] <= 0 && pierce <= 0) FireRevolver();
            }
            else if (cur == 1)
            {
                if (alt && cd[1] <= 0) coreHold = Mathf.Min(1, coreHold + dt / 0.5f);
                else if (coreHold > 0) { LaunchCore(coreHold); coreHold = 0; }
                if (fire && cd[1] <= 0 && coreHold <= 0) FireShotgun();
            }
            else
            {
                nailT -= dt;
                if (fire && nailT <= 0) { FireNail(); nailT = 0.075f; }
            }
        }

        void Kick(float k, float rot = 1)
        {
            recoil = Mathf.Min(3, recoil + k);
            recoilRot = Mathf.Min(3, recoilRot + k * rot);
            flashT = 0.055f;
            P.camKick = Mathf.Min(4.5f, P.camKick + k * 0.5f);
        }

        // Işın: ilk isabet (düşman bölgesi ya da dünya). Oyuncunun kendi gövdesi atlanır.
        public static bool Hitscan(Vector3 o, Vector3 d, float max, out RaycastHit best, out UKHitbox box)
        {
            best = default;
            box = null;
            var hits = Physics.RaycastAll(o, d, max, ~0, QueryTriggerInteraction.Collide);
            System.Array.Sort(hits, (a, b) => a.distance.CompareTo(b.distance));
            for (int i = 0; i < hits.Length; i++)
            {
                var h = hits[i];
                if (h.collider == UKGame.I.player.cc) continue;
                var hb = h.collider.GetComponent<UKHitbox>();
                if (hb != null) { if (hb.owner == null || hb.owner.dead) continue; box = UKHitbox.PreferHead(hits, i, hb, 0.9f, out best); return true; }
                if (h.collider.isTrigger) continue;
                best = h;
                return true;
            }
            return false;
        }

        void Impact(RaycastHit h, bool big = false)
        {
            UKFx.I.Burst(h.point, big ? 14 : 7, big ? 10 : 7, new Color(1f, 0.82f, 0.5f), 0.3f, 0.045f, 10, h.normal, 0.7f);
            UKFx.I.Glow(h.point + h.normal * 0.08f, new Color(1f, 0.88f, 0.6f), big ? 1.2f : 0.6f, 0.06f);
            for (int i = 0; i < (big ? 4 : 2); i++) UKFx.I.Gib(h.point + h.normal * 0.05f, (h.normal + Random.insideUnitSphere * 0.6f + Vector3.up * 0.4f) * 4, Random.Range(0.04f, 0.08f), UKFx.Lit(new Color(0.5f, 0.45f, 0.4f)));
        }

        void FireRevolver()
        {
            cd[0] = 0.36f;
            Kick(0.8f, 1.2f);
            spinT = Mathf.Min(spinT, 0.99f);
            UKAudio.I.Play("revolver");
            Vector3 o = P.EyePos, d = UKGame.I.AssistDir(o, P.AimDir, 0.1f);
            Vector3 end = o + d * 300;
            if (Hitscan(o, d, 300, out var h, out var box))
            {
                end = h.point;
                if (box != null) box.owner.Hit(1f, h.point, d, box.head, "revolver", 3);
                else Impact(h);
            }
            var from = MuzzleWorld();
            UKFx.I.Tracer(from, end, new Color(1f, 0.94f, 0.7f), 0.035f, 0.09f);
            UKFx.I.Flash(from, new Color(1f, 0.75f, 0.45f), 3, 10, 0.05f);
        }

        void FirePiercer()
        {
            cd[0] = 0.5f;
            Kick(1.7f, 1.6f);
            UKAudio.I.Play("piercer");
            P.Shake(0.25f);
            Vector3 o = P.EyePos, d = UKGame.I.AssistDir(o, P.AimDir, 0.1f);
            var hits = Physics.RaycastAll(o, d, 400, ~0, QueryTriggerInteraction.Collide);
            System.Array.Sort(hits, (a, b) => a.distance.CompareTo(b.distance));
            Vector3 end = o + d * 400;
            var done = new HashSet<UKEnemy>();
            for (int i = 0; i < hits.Length; i++)
            {
                var h = hits[i];
                if (h.collider == P.cc) continue;
                var hb = h.collider.GetComponent<UKHitbox>();
                if (hb != null)
                {
                    if (hb.owner == null || hb.owner.dead || done.Contains(hb.owner)) continue;
                    done.Add(hb.owner);
                    hb = UKHitbox.PreferHead(hits, i, hb, 0.9f, out var hh);
                    hb.owner.Hit(2.5f, hh.point, d, hb.head, "revolver", 8, 1.5f);
                    continue;
                }
                if (h.collider.isTrigger) continue;
                end = h.point;
                Impact(h, true);
                break;
            }
            var from = MuzzleWorld();
            UKFx.I.Tracer(from, end, new Color(0.45f, 0.75f, 1f), 0.16f, 0.35f);
            UKFx.I.Tracer(from, end, Color.white, 0.05f, 0.22f);
            UKFx.I.Flash(from, new Color(0.5f, 0.75f, 1f), 5, 14, 0.1f);
        }

        void FireShotgun()
        {
            cd[1] = 0.95f;
            Kick(1.6f, 1.4f);
            UKAudio.I.Play("shotgun");
            UKAudio.I.Play("pump", 1, 1, true);
            P.Shake(0.2f);
            Vector3 o = P.EyePos, d = P.AimDir;
            var acc = new Dictionary<UKEnemy, (float dmg, int n, int head, Vector3 pt)>();
            var from = MuzzleWorld();
            for (int k = 0; k < 12; k++)
            {
                Vector3 dir = (d + Random.insideUnitSphere * 0.085f).normalized;
                Vector3 end = o + dir * 120;
                if (Hitscan(o, dir, 120, out var h, out var box))
                {
                    end = h.point;
                    if (box != null)
                    {
                        acc.TryGetValue(box.owner, out var a);
                        acc[box.owner] = (a.dmg + 0.32f * (box.head ? 1.5f : 1), a.n + 1, a.head + (box.head ? 1 : 0), h.point);
                    }
                    else if (k % 3 == 0) Impact(h);
                }
                UKFx.I.Tracer(from, end, new Color(1f, 0.88f, 0.63f), 0.028f, 0.07f);
            }
            foreach (var kv in acc) kv.Key.Hit(kv.Value.dmg, kv.Value.pt, d, kv.Value.head >= Mathf.Max(2, kv.Value.n / 2), "shotgun", 3 + kv.Value.n * 1.3f, 1f);
            UKFx.I.Flash(from, new Color(1f, 0.7f, 0.4f), 5, 12, 0.07f);
        }

        void LaunchCore(float charge)
        {
            cd[1] = 0.9f;
            Kick(1.1f, 0.6f);
            Vector3 d = P.AimDir;
            Vector3 pos = P.EyePos + d * 0.8f - Vector3.up * 0.12f;
            Vector3 v = d * (18 + 26 * charge) + Vector3.up * (2 + 2 * charge) + P.vel * 0.3f;
            UKProjectile.Spawn(UKProjectile.Kind.Core, pos, v, true, 0, new Color(0.35f, 0.65f, 1f));
            UKAudio.I.Play("pump", 1, 1.3f);
        }

        void FireNail()
        {
            Vector3 d = (UKGame.I.AssistDir(P.EyePos, P.AimDir, 0.08f) + Random.insideUnitSphere * 0.03f).normalized;
            UKProjectile.Spawn(UKProjectile.Kind.Nail, MuzzleWorld(), d * 95, true, 0.14f, new Color(0.85f, 0.87f, 0.9f));
            recoil = Mathf.Min(3, recoil + 0.12f);
            flashT = 0.03f;
            UKAudio.I.Play("nail", 0.8f, 1.4f);
        }

        // ------------------------------------------------------------ yumruk / parry
        void Punch()
        {
            if (punchCd > 0) return;
            punchCd = 0.35f;
            punchT = 0;
            armT = 0;
            armParry = false;
            arm.gameObject.SetActive(true);
            UKAudio.I.Play("punch");
            var game = UKGame.I;
            if (game.TryParry()) { armParry = true; return; }
            if (!game.MeleePunch()) game.parryBuffer = 0.18f;
        }

        public void ParryAnim() { armParry = true; armT = 0; arm.gameObject.SetActive(true); }

        void Animate(float dt)
        {
            var p = P;
            float rdt = Time.unscaledDeltaTime;
            switchT = Mathf.Min(1, switchT + dt / 0.3f);
            float sw = 1 - (1 - Mathf.Pow(1 - switchT, 3));
            recoil = Mathf.Lerp(recoil, 0, 1 - Mathf.Exp(-12 * dt));
            recoilRot = Mathf.Lerp(recoilRot, 0, 1 - Mathf.Exp(-9 * dt));
            Vector2 md = UKInput.MouseDelta;
            swayX = Mathf.Lerp(swayX, Mathf.Clamp(-md.x * 0.012f, -0.06f, 0.06f), 1 - Mathf.Exp(-9 * rdt));
            swayY = Mathf.Lerp(swayY, Mathf.Clamp(-md.y * 0.012f, -0.06f, 0.06f), 1 - Mathf.Exp(-9 * rdt));
            float bx = Mathf.Sin(p.BobT * 0.95f) * 0.014f * p.Bob, by = -Mathf.Abs(Mathf.Cos(p.BobT * 0.95f)) * 0.016f * p.Bob;
            float breath = Mathf.Sin(Time.time * 1.6f) * 0.004f * (1 - p.Bob);
            var g = guns[cur];
            float charge = cur == 0 ? pierce : cur == 1 ? coreHold : 0;
            Vector3 shake = charge > 0 ? Random.insideUnitSphere * 0.005f * charge : Vector3.zero;
            g.root.localPosition = g.basePos + new Vector3(bx + swayX + shake.x - (p.sliding ? 0.04f : 0), by + breath + swayY - sw * 0.5f + shake.y - recoil * 0.012f, -recoil * 0.05f);
            spinT = Mathf.Min(1, spinT + dt / 0.38f);
            float spin = cur == 0 && spinT < 1 ? (1 - Mathf.Pow(1 - spinT, 2)) * 360f : 0;
            g.root.localRotation = Quaternion.Euler(-recoilRot * 11f - sw * 50f - swayY * 85f + charge * 12f - spin, swayX * 85f, p.sliding ? 14f : 0);
            if (g.spin != null)
            {
                if (cur == 0) g.spin.localRotation = Quaternion.Euler(0, 0, (1 - spinT) * 360f + pierce * 900f * Time.time % 360f);
                else if (cur == 2) g.spin.Rotate(0, 0, dt * (UKInput.Held(UKKey.Mouse0) ? 1400f : 120f), Space.Self);
                else if (cur == 1) { float t = Mathf.Clamp01(cd[1] > 0 ? 1 - cd[1] / 0.95f : 1); float k = t > 0.45f && t < 0.95f ? Mathf.Sin((t - 0.45f) / 0.5f * Mathf.PI) : 0; g.spin.localPosition = new Vector3(0, -0.03f, 0.4f - k * 0.13f); }
            }
            // namlu alevi
            flashT -= dt;
            bool fl = flashT > 0;
            flash.SetActive(fl);
            if (fl)
            {
                flash.transform.position = g.muzzle.position;
                flash.transform.rotation = g.muzzle.rotation * Quaternion.Euler(0, 0, Random.Range(0, 360f));
                flash.transform.localScale = Vector3.one * (cur == 1 ? 0.5f : cur == 2 ? 0.22f : 0.34f) * Random.Range(0.7f, 1.3f);
                muzzleLight.transform.position = g.muzzle.position;
                muzzleLight.intensity = 4 * UKFx.LightMul;
            }
            else muzzleLight.intensity = 0;
            // sol kol: yumruk / parry
            armT += dt;
            float dur = armParry ? 0.62f : 0.42f;
            if (armT < dur)
            {
                float t = armT, k;
                if (armParry) k = t < 0.04f ? t / 0.04f : t < 0.3f ? 1 : 1 - (t - 0.3f) / 0.32f;
                else k = t < 0.05f ? -0.25f * (t / 0.05f) : t < 0.11f ? -0.25f + 1.25f * (1 - Mathf.Pow(1 - (t - 0.05f) / 0.06f, 3)) : t < 0.17f ? 1 : 1 - Mathf.Pow((t - 0.17f) / 0.25f, 2);
                float kk = Mathf.Max(0, k);
                var off = new Vector3(-0.5f, -0.5f, 0.22f);
                var hit = new Vector3(-0.08f, -0.13f, armParry ? 0.86f : 0.76f);
                arm.localPosition = Vector3.Lerp(off, hit, kk) + (armParry && t < 0.3f ? Random.insideUnitSphere * 0.008f : Vector3.zero);
                arm.localRotation = Quaternion.Euler(Mathf.Lerp(28f, 14f, kk), Mathf.Lerp(-35f, -20f, kk), 6f);
            }
            else if (arm.gameObject.activeSelf) arm.gameObject.SetActive(false);
        }
    }
}
