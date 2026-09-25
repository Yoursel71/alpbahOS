// Düşmanlar (web: enemies.js): eklem hiyerarşili kutu/koni modeller, prosedürel animasyon, durum makinesi.
// Model ve animasyon sayıları web sürümünden birebir alınır: W* yardımcıları web koordinatlarını
// (model önü -z, sağ elli) Unity'ye (model önü +z, sol elli) aynalayarak çevirir: z → -z, rx → -rx,
// ry → -ry, rz aynı. Ölüm: parçalanma / kafa kopması / yığılan ceset / boss'ta parça parça kopma sekansı.
// Bu dosya: taban sınıf, iskelet, FILTH, STRAY, EĞİTMEN, SCHISM, SWORDSMACHINE.
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    // ------------------------------------------------------------------ web koordinat yardımcıları
    public static class W
    {
        const float R2D = Mathf.Rad2Deg;
        // web Euler (XYZ, radyan) → Unity yerel dönüş (aynalanmış)
        public static Quaternion Q(float x, float y = 0, float z = 0) =>
            Quaternion.AngleAxis(-x * R2D, Vector3.right) * Quaternion.AngleAxis(-y * R2D, Vector3.up) * Quaternion.AngleAxis(z * R2D, Vector3.forward);
        public static Vector3 V(float x, float y, float z) => new Vector3(x, y, -z);

        public static Transform J(Transform parent, float x, float y, float z, string name = "j")
        {
            var t = new GameObject(name).transform;
            t.SetParent(parent, false);
            t.localPosition = V(x, y, z);
            return t;
        }

        // Kutu parça (web: part(parent, bgeo(w,h,d), mat, x,y,z, rx,ry,rz, noGib))
        public static GameObject Box(Transform parent, float w, float h, float d, Material m, float x, float y, float z, float rx = 0, float ry = 0, float rz = 0, bool noGib = false)
        {
            var go = UKFx.Part(parent, V(x, y, z), new Vector3(w, h, d), m);
            go.transform.localRotation = Q(rx, ry, rz);
            if (noGib) go.name = "ng";
            return go;
        }

        // Koni (web: ConeGeometry(r, h, seg): uç +y)
        public static GameObject Cone(Transform parent, float r, float h, Material m, float x, float y, float z, float rx = 0, float ry = 0, float rz = 0, bool noGib = false, int seg = 5)
        {
            var go = UKFx.Shape(parent, UKFx.Frustum(0, seg), V(x, y, z), new Vector3(r * 2, h, r * 2), m);
            go.transform.localRotation = Q(rx, ry, rz);
            if (noGib) go.name = "ng";
            return go;
        }

        // Silindir (web: CylinderGeometry(rTop, rBottom, h))
        public static GameObject Cyl(Transform parent, float rTop, float rBot, float h, Material m, float x, float y, float z, float rx = 0, float ry = 0, float rz = 0, int seg = 8)
        {
            var go = UKFx.Shape(parent, UKFx.Frustum(rBot > 0 ? rTop / rBot : 1, seg), V(x, y, z), new Vector3(rBot * 2, h, rBot * 2), m);
            go.transform.localRotation = Q(rx, ry, rz);
            return go;
        }

        // Uzuv (web: limb(parent, w,h,d, mat, y = -h/2))
        public static GameObject Limb(Transform parent, float w, float h, float d, Material m, float? y = null)
            => Box(parent, w, h, d, m, 0, y ?? -h / 2, 0);

        public static GameObject Glow(Transform parent, float x, float y, float z, float size, Color c)
        {
            var g = UKFx.Billboard(parent, V(x, y, z), size, c);
            g.name = "ng";
            return g;
        }
    }

    // İnsansı iskelet (web: buildHumanoid)
    public class UKHumanoid
    {
        public Transform root, hips, spine, neck, head, shL, shR, elL, elR, haL, haR, hipL, hipR, knL, knR, ftL, ftR;
        public GameObject foreL, foreR, handL, handR, upperL, upperR, headMesh;
        public float hipY, thigh, shin, torsoH, headS, torsoW, torsoD, armL, scale;

        public static UKHumanoid Build(Transform parent, Material skin, Material dark, float hunch = 0.3f, float torsoW = 0.42f, float torsoH = 0.55f, float torsoD = 0.26f, float headS = 0.3f, float armL = 1, float legL = 1, float scale = 1, float taper = 0.85f)
        {
            var H = new UKHumanoid { torsoW = torsoW, torsoH = torsoH, torsoD = torsoD, headS = headS, armL = armL, scale = scale };
            H.root = W.J(parent, 0, 0, 0, "body");
            H.thigh = 0.42f * legL; H.shin = 0.43f * legL;
            H.hipY = H.thigh + H.shin + 0.06f;
            H.hips = W.J(H.root, 0, H.hipY, 0, "hips");
            W.Limb(H.hips, torsoW * 0.8f, 0.2f, torsoD * 0.85f, skin, 0);
            H.spine = W.J(H.hips, 0, 0.06f, 0, "spine");
            H.spine.localRotation = W.Q(-hunch);
            W.Limb(H.spine, torsoW * taper, torsoH * 0.45f, torsoD * 0.9f, skin, torsoH * 0.22f);
            W.Limb(H.spine, torsoW, torsoH * 0.6f, torsoD, skin, torsoH * 0.7f);
            H.neck = W.J(H.spine, 0, torsoH, 0, "neck");
            H.neck.localRotation = W.Q(hunch * 0.8f);
            W.Limb(H.neck, headS * 0.4f, 0.08f, headS * 0.4f, skin, 0.02f);
            H.head = W.J(H.neck, 0, 0.05f, 0, "head");
            H.headMesh = W.Limb(H.head, headS, headS * 1.1f, headS, skin, headS * 0.55f);
            foreach (int side in new[] { -1, 1 })
            {
                var sh = W.J(H.spine, side * (torsoW / 2 + 0.07f), torsoH - 0.07f, 0, "sh");
                W.Limb(sh, 0.15f, 0.12f, 0.15f, skin, -0.02f);
                var upper = W.Limb(sh, 0.11f, 0.36f * armL, 0.11f, skin);
                var el = W.J(sh, 0, -0.36f * armL, 0, "el");
                var fore = W.Limb(el, 0.095f, 0.34f * armL, 0.095f, skin);
                var ha = W.J(el, 0, -0.34f * armL, 0, "ha");
                var hand = W.Limb(ha, 0.11f, 0.13f, 0.11f, dark, -0.05f);
                var hip = W.J(H.hips, side * torsoW * 0.26f, -0.04f, 0, "hip");
                W.Limb(hip, 0.15f, H.thigh, 0.15f, skin);
                var kn = W.J(hip, 0, -H.thigh, 0, "kn");
                W.Limb(kn, 0.12f, H.shin, 0.12f, skin);
                var ft = W.J(kn, 0, -H.shin, 0, "ft");
                W.Box(ft, 0.13f, 0.07f, 0.24f, dark, 0, 0, -0.05f);
                if (side < 0) { H.shL = sh; H.elL = el; H.haL = ha; H.hipL = hip; H.knL = kn; H.ftL = ft; H.foreL = fore; H.handL = hand; H.upperL = upper; }
                else { H.shR = sh; H.elR = el; H.haR = ha; H.hipR = hip; H.knR = kn; H.ftR = ft; H.foreR = fore; H.handR = hand; H.upperR = upper; }
            }
            H.root.localScale = Vector3.one * scale;
            return H;
        }

        // Kaburgalar (göğüs önü), omurga çıkıntıları, diş sırası, pençeler
        public void Ribs(Material bone, int n = 4)
        {
            for (int k = 0; k < n; k++) W.Box(spine, torsoW * (0.95f - k * 0.06f), 0.03f, 0.04f, bone, 0, torsoH * (0.78f - k * 0.1f), -torsoD / 2 - 0.01f);
            W.Box(spine, 0.05f, torsoH * 0.45f, 0.04f, bone, 0, torsoH * 0.65f, -torsoD / 2 - 0.015f);
        }

        public void Vertebrae(Material bone, int n = 5)
        {
            for (int k = 0; k < n; k++) W.Box(spine, 0.06f, 0.05f, 0.07f, bone, 0, torsoH * (0.15f + k * 0.18f), torsoD / 2 + 0.02f, 0.3f);
        }

        public static void Teeth(Transform parent, float y, float z, float w, Material bone, int n = 5, bool up = true)
        {
            for (int k = 0; k < n; k++) W.Cone(parent, 0.018f, 0.05f, bone, (k / (float)(n - 1) - 0.5f) * w, y, z, up ? Mathf.PI : 0, 0, 0, true, 4);
        }

        public static void Claws(Transform ha, Material bone)
        {
            foreach (float x in new[] { -0.035f, 0, 0.035f }) W.Cone(ha, 0.016f, 0.12f, bone, x, -0.16f, -0.02f, Mathf.PI - 0.3f, 0, 0, false, 4);
        }
    }

    public abstract class UKEnemy : MonoBehaviour
    {
        public static readonly List<UKEnemy> All = new List<UKEnemy>();
        static readonly List<UKEnemy> corpses = new List<UKEnemy>();

        public string type = "enemy", enemyName = "ENEMY";
        public float maxHp = 1, hp, radius = 0.4f, height = 1.9f, speed = 8, killPts = 60, knockMul = 1, parryDmg = 4, parryStun = 0.9f, dmgMul = 1;
        public float burn, drill;
        public bool dead, big, boss, flying, parryable, enraged, invuln, onlyParry, noCount, decor, dormant;
        public UKArena arena;
        public CharacterController cc;
        public UKEnemy partner;
        protected Transform model;
        protected UKHumanoid H;
        protected Vector3 vel, knock;
        protected float yaw, st, atkCd = 1, time, flash, spawnT, stun = 0.9f, k, walkPhase, blocked, seeT, lookYaw, lookPitch, tint = 1, burnTick, drillTick, lavaT;
        protected Vector2 hr;
        protected bool grounded, canSee, instant;
        protected string state = "spawn", resume;
        protected Color slashColor = new Color(1f, 0.88f, 0.75f, 0.8f);
        protected readonly List<Material> mats = new List<Material>();
        readonly List<Color> matBase = new List<Color>();
        bool glinted;
        float deathT = -1, nextPop, corpseT = -1, fallSign = 1;
        Vector3 corpseVel, deathDir;
        List<Transform> deathParts;
        bool landed;
        Transform headBox;

        public Vector3 Center => transform.position + Vector3.up * height * 0.55f;
        public string State => state;
        public Vector3 HeadPos => headBox != null ? headBox.position : Center;
        protected UKPlayer P => UKGame.I.player;
        protected virtual string FirstState => "chase";
        protected virtual float SpawnDur => 0.6f;
        protected float Aggro => UKGame.I.Diff.aggro;
        protected static float DSpeed => UKGame.I.Diff.speed;
        protected static float DDmg => UKGame.I.Diff.dmg;

        public static UKEnemy Spawn(string t, Vector3 pos, UKArena arena = null, bool instant = false, bool dormant = false, bool decor = false, float? yawDeg = null)
        {
            System.Type ty;
            switch (t)
            {
                case "filth": ty = typeof(UKFilth); break;
                case "stray": ty = typeof(UKStray); break;
                case "trainer": ty = typeof(UKTrainer); break;
                case "schism": ty = typeof(UKSchism); break;
                case "swordsmachine": case "sword": ty = typeof(UKSwordsmachine); break;
                case "maliciousface": ty = typeof(UKMaliciousFace); break;
                case "cerberus": ty = typeof(UKCerberus); break;
                case "drone": ty = typeof(UKDrone); break;
                case "streetcleaner": ty = typeof(UKStreetcleaner); break;
                case "hideousmass": ty = typeof(UKHideousMass); break;
                case "v2": ty = typeof(UKV2); break;
                default: ty = typeof(UKFilth); break;
            }
            var go = new GameObject(t);
            go.transform.position = pos;
            var e = (UKEnemy)go.AddComponent(ty);
            e.arena = arena;
            e.instant = instant;
            e.dormant = dormant;
            e.decor = decor;
            e.Setup(yawDeg);
            return e;
        }

        public static T Spawn<T>(Vector3 pos, UKArena arena = null) where T : UKEnemy
        {
            var go = new GameObject(typeof(T).Name);
            go.transform.position = pos;
            var e = go.AddComponent<T>();
            e.arena = arena;
            e.Setup(null);
            return e;
        }

        // glow: malzemenin kendi renginde hafif öz aydınlatma (karanlıkta renk kaybolmasın)
        protected Material M(Color c, float glow = 0.13f, Texture2D tex = null)
        {
            c = new Color(c.r * tint, c.g * tint, c.b * tint);
            var m = new Material(UKFx.Lit(c, 0.001f, tex));
            m.EnableKeyword("_EMISSION");
            mats.Add(m);
            matBase.Add(c * glow);
            return m;
        }

        protected static Color C(int hex) => new Color(((hex >> 16) & 255) / 255f, ((hex >> 8) & 255) / 255f, (hex & 255) / 255f);

        void Setup(float? yawDeg)
        {
            tint = Random.Range(0.88f, 1.08f);
            walkPhase = Random.Range(0f, 6f);
            atkCd = Random.Range(0.5f, 1.2f);
            model = new GameObject("model").transform;
            model.SetParent(transform, false);
            Init();
            hp = maxHp;
            cc = gameObject.AddComponent<CharacterController>();
            cc.radius = radius;
            cc.height = Mathf.Max(height, radius * 2 + 0.01f);
            cc.center = new Vector3(0, cc.height / 2, 0);
            cc.stepOffset = Mathf.Min(0.5f, cc.height * 0.3f);
            cc.skinWidth = 0.05f;
            cc.slopeLimit = 50;
            gameObject.AddComponent<UKHitbox>().owner = this;
            if (H != null) headBox = AddHitSphere(H.head, W.V(0, H.headS * 0.55f, 0), H.headS * 0.8f, true);
            AfterInit();
            var p = UKGame.I.player;
            if (yawDeg.HasValue) yaw = yawDeg.Value;
            else if (p) yaw = Mathf.Atan2(p.transform.position.x - transform.position.x, p.transform.position.z - transform.position.z) * Mathf.Rad2Deg;
            transform.rotation = Quaternion.Euler(0, yaw, 0);
            if (!decor) All.Add(this);
            if (instant || decor) { state = decor ? "idle" : FirstState; model.localScale = Vector3.one; }
            else
            {
                UKFx.I.SpawnFX(transform.position, height);
                UKAudio.I.PlayAt("spawn", transform.position, 0.8f);
            }
            if (decor) { cc.enabled = false; foreach (var c in GetComponentsInChildren<Collider>()) c.enabled = false; }
        }

        // Ek isabet küresi (tetik). head=true → kritik bölge (kafa, göz, tank)
        protected Transform AddHitSphere(Transform parent, Vector3 localPos, float r, bool head)
        {
            var go = new GameObject(head ? "headbox" : "hitbox");
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            var sc = go.AddComponent<SphereCollider>();
            sc.isTrigger = true;
            sc.radius = r;
            var hb = go.AddComponent<UKHitbox>();
            hb.owner = this;
            hb.head = head;
            return go.transform;
        }

        protected abstract void Init();
        protected virtual void AfterInit() { }
        protected abstract void Think(float dt);
        protected virtual void Animate(float dt) { }

        // ------------------------------------------------------------ döngü
        void Update()
        {
            float dt = Time.deltaTime;
            if (dt <= 0) return;
            if (deathT >= 0) { BossDeathTick(dt); return; }
            if (corpseT >= 0) { CorpseTick(dt); return; }
            if (dead) return;
            time += dt;
            st += dt;
            flash = Mathf.Max(0, flash - dt * 6);
            var game = UKGame.I;
            if (state == "spawn")
            {
                spawnT += dt;
                float kk = Mathf.Clamp01(spawnT / SpawnDur);
                model.localScale = new Vector3(1 + (1 - kk) * 0.6f, 0.15f + 0.85f * kk * kk, 1 + (1 - kk) * 0.6f);
                flash = Mathf.Max(flash, 1 - kk);
                if (spawnT >= SpawnDur) { model.localScale = Vector3.one; SetState(FirstState); }
            }
            else if (state == "idle") { }
            else if (state == "stagger") { Brake(20, dt); if (st > stun) SetState(FirstState); }
            else if (state == "flinch") { Brake(30, dt); if (st > 0.14f) SetState(resume ?? FirstState); }
            else if (game.state == UKGame.State.Playing && !P.dead)
            {
                seeT -= dt;
                if (seeT <= 0) { seeT = 0.25f; canSee = CanSee(); }
                Think(dt);
            }
            else Brake(20, dt);
            if (!decor) Physics_(dt);
            if (dead) return;
            Dots(dt);
            if (dead) return;
            transform.rotation = Quaternion.Euler(0, yaw, 0);
            k = 1 - Mathf.Exp(-16 * dt);
            Animate(dt);
            PostAnimate(dt);
            UpdateFlash();
        }

        protected void SetState(string s)
        {
            state = s;
            st = 0;
            if (s != "windup" && s != "attack" && s != "pounce") SetParryable(false);
        }

        protected void Glint(Vector3? pos = null)
        {
            var p = pos ?? HeadPos + Vector3.up * 0.1f;
            UKFx.I.Star(p, new Color(0.62f, 0.88f, 1f), 2.4f, 0.38f, 1.7f);
            UKAudio.I.PlayAt("glint", p);
        }

        protected void SetParryable(bool on, Vector3? glintPos = null)
        {
            if (on && !parryable && !glinted) { glinted = true; Glint(glintPos); }
            if (!on) glinted = false;
            parryable = on;
        }

        protected void Physics_(float dt)
        {
            var game = UKGame.I;
            if (!flying) vel.y -= 35 * dt;
            vel.y = Mathf.Max(vel.y, -80);
            bool was = grounded;
            var flags = cc.Move((vel + knock) * dt);
            if ((flags & CollisionFlags.Sides) != 0) { blocked += dt; knock *= -0.3f; }
            else blocked = Mathf.Max(0, blocked - dt * 2);
            if ((flags & CollisionFlags.Above) != 0 && vel.y > 0) vel.y = 0;
            bool g = (flags & CollisionFlags.Below) != 0 && vel.y <= 0;
            if (!g && was && vel.y <= 0 && !flying)
            {
                // basamak inişinde yere yapış
                if (Physics.Raycast(transform.position + Vector3.up * 0.1f, Vector3.down, out var hit, 0.6f, ~0, QueryTriggerInteraction.Ignore) && !(hit.collider is CharacterController))
                {
                    cc.Move(Vector3.down * (hit.distance - 0.05f));
                    g = true;
                }
            }
            if (g && !was) OnLand();
            grounded = g;
            if (g) vel.y = -1f;
            knock *= Mathf.Exp(-dt * (g ? 7 : 1.5f));
            var L = game.level;
            if (transform.position.y < L.killY) { Die(99, null, false, Vector3.zero, true); return; }
            string hz = L.HurtAt(transform.position + Vector3.up * 0.1f);
            if (hz == "pit") { Die(99, null, false, Vector3.zero, false); return; }
            if (hz != null && !flying)
            {
                lavaT -= dt;
                if (lavaT <= 0)
                {
                    lavaT = 0.4f;
                    vel.y = 12;
                    Hit(maxHp * 0.25f + 0.3f, Center, Vector3.up, false, "lava", 0, 1, true, false, true);
                }
            }
        }

        protected virtual void OnLand() { }

        // Süreli hasarlar: yanma (Firestarter/Overheat/Streetcleaner) ve matkap (Screwdriver)
        void Dots(float dt)
        {
            if (burn > 0)
            {
                burn -= dt;
                burnTick -= dt;
                if (Random.value < dt * 25) UKFx.I.Burst(Center + new Vector3(Random.Range(-0.3f, 0.3f), Random.Range(-0.6f, 0.6f), Random.Range(-0.3f, 0.3f)), 1, 2, Random.value < 0.5f ? new Color(1f, 0.48f, 0.13f) : new Color(1f, 0.75f, 0.25f), 0.5f, 0.1f, -3);
                if (burnTick <= 0) { burnTick = 0.5f; Hit(0.2f, Center, Vector3.zero, false, "rocket", 0, 1, true, false, false, true); }
            }
            if (drill > 0 && !dead)
            {
                drill -= dt;
                drillTick -= dt;
                if (drillTick <= 0) { drillTick = 0.12f; Hit(0.2f, Center, Vector3.zero, false, "rail", 0, 1, true); UKFx.I.Blood(Center, 3, 4); }
            }
        }

        // Ortak: kafa ile oyuncuyu takip, vurulma tepkisi
        void PostAnimate(float dt)
        {
            if (H == null) return;
            float ty = 0, tp = 0;
            var p = P;
            if (state != "idle" && state != "spawn" && !p.dead)
            {
                Vector3 d = p.transform.position - transform.position;
                float rel = Mathf.DeltaAngle(yaw, Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg);
                ty = Mathf.Clamp(-rel * Mathf.Deg2Rad, -0.9f, 0.9f);
                float dy = p.EyePos.y - (transform.position.y + height);
                tp = Mathf.Clamp(Mathf.Atan2(dy, new Vector2(d.x, d.z).magnitude), -0.5f, 0.6f);
            }
            else if (state == "idle") ty = Mathf.Sin(time * 0.5f) * 0.5f;
            float kk = 1 - Mathf.Exp(-8 * dt);
            lookYaw += (ty - lookYaw) * kk;
            lookPitch += (tp - lookPitch) * kk;
            hr *= Mathf.Exp(-10 * dt);
            H.head.localRotation = W.Q(lookPitch * 0.7f + hr.x * 0.8f, lookYaw, hr.y);
            H.spine.localRotation = H.spine.localRotation * W.Q(hr.x * 0.15f, 0, hr.y * 0.6f);
        }

        protected void Brake(float a, float dt) { vel.x = Mathf.MoveTowards(vel.x, 0, a * dt); vel.z = Mathf.MoveTowards(vel.z, 0, a * dt); }

        protected void AccelTo(Vector3 target, float a, float dt)
        {
            var h = new Vector3(vel.x, 0, vel.z);
            h = Vector3.MoveTowards(h, new Vector3(target.x, 0, target.z), a * dt);
            vel.x = h.x; vel.z = h.z;
        }

        protected Vector3 ToPlayer(out float dist, out float dy)
        {
            var d = P.transform.position - transform.position;
            dy = d.y;
            d.y = 0;
            dist = d.magnitude;
            return dist > 0.001f ? d / dist : Vector3.forward;
        }

        protected Vector3 ToPlayer(out float dist) => ToPlayer(out dist, out _);

        protected void Face(Vector3 dir, float rate, float dt)
        {
            float t = Mathf.Atan2(dir.x, dir.z) * Mathf.Rad2Deg;
            yaw = Mathf.LerpAngle(yaw, t, Mathf.Min(1, rate * dt));
        }

        protected Vector3 Forward => Quaternion.Euler(0, yaw, 0) * Vector3.forward;
        protected static Vector3 Side(Vector3 d) => new Vector3(-d.z, 0, d.x);

        protected bool CanSee()
        {
            Vector3 a = transform.position + Vector3.up * height * 0.85f, b = P.EyePos;
            var hits = Physics.RaycastAll(a, (b - a).normalized, Vector3.Distance(a, b), UKFx.RayMask, QueryTriggerInteraction.Ignore);
            foreach (var h in hits) if (!(h.collider is CharacterController) && h.collider.GetComponent<UKHitbox>() == null) return false;
            return true;
        }

        protected bool GroundAhead(Vector3 dir, float dist = 1.2f)
        {
            Vector3 o = transform.position + dir * dist + Vector3.up * 0.5f;
            return Physics.Raycast(o, Vector3.down, 2.0f, ~0, QueryTriggerInteraction.Ignore);
        }

        // Yakın saldırı: önde parlak kavis + ses; menzilde ve öndeyse hasar
        protected bool MeleeHit(float range, float dmg, float arc = 0.2f)
        {
            var f = Forward;
            UKFx.I.Slash(Center + f * Mathf.Min(1.4f, range * 0.4f), yaw, slashColor, Mathf.Min(3.4f, range * 0.75f), 0.2f, Random.Range(-0.35f, 0.35f));
            UKAudio.I.PlayAt("meleeWhoosh", transform.position, 1, big ? 0.75f : 1.1f);
            var d = ToPlayer(out float dist, out float dy);
            if (dist > range || Mathf.Abs(dy + 0.5f) > 2.6f) return false;
            if (Vector3.Dot(f, d) < arc) return false;
            bool ok = UKGame.I.DamagePlayer(dmg * DDmg, Center, false);
            if (ok)
            {
                UKFx.I.Blood(P.EyePos + f * 0.3f, 14, 6);
                UKAudio.I.Play("punchHit", 1, big ? 0.7f : 1);
                UKGame.I.Hitstop(big ? 0.08f : 0.05f);
                P.Shake(big ? 0.45f : 0.3f);
                P.vel += f * (big ? 9 : 5);
            }
            return ok;
        }

        // Oyuncuya doğru (hafif öngörülü) atış yönü
        protected Vector3 AimAt(Vector3 from, float speed, float lead = 0.4f, float yOff = 0.6f)
        {
            var p = P;
            Vector3 target = p.transform.position + Vector3.up * 1.8f * yOff;
            float t = Vector3.Distance(from, target) / speed;
            target += p.vel * t * lead;
            return (target - from).normalized;
        }

        protected UKProjectile Shoot(Vector3 from, Vector3 dir, float speed, float dmg, Color col, float r = 0.35f, UKProjectile.Kind kind = UKProjectile.Kind.Orb)
        {
            var pr = UKProjectile.Spawn(kind, from, dir * speed, false, dmg * DDmg, col, this, r);
            if (kind == UKProjectile.Kind.Bullet) pr.parryable = true;
            return pr;
        }

        void UpdateFlash()
        {
            float r = flash, g = flash, b = flash;
            if (parryable) { float kk = 0.2f + Mathf.Sin(time * 40) * 0.12f; r = Mathf.Max(r, 0.1f * kk); g = Mathf.Max(g, 0.35f * kk); b = Mathf.Max(b, 0.8f * kk); }
            if (enraged) r = Mathf.Max(r, 0.35f + Mathf.Sin(time * 10) * 0.1f);
            for (int i = 0; i < mats.Count; i++)
            {
                var gl = matBase[i];
                mats[i].SetColor("_EmissionColor", new Color(Mathf.Max(r, gl.r), Mathf.Max(g, gl.g), Mathf.Max(b, gl.b)));
            }
        }

        // ------------------------------------------------------------ hasar ve ölüm
        public void Hit(float dmg, Vector3 point, Vector3 dir, bool head, string weapon, float knockF, float headMult = 2f, bool quiet = false, bool parried = false, bool noHeal = false, bool burning = false, bool explosion = false, int pellets = 0)
        {
            if (dead || decor || state == "spawn" && spawnT < 0.15f) return;
            var game = UKGame.I;
            if (invuln || (onlyParry && !parried))
            {
                UKFx.I.Burst(point, 6, 6, Color.white, 0.2f, 0.05f);
                UKAudio.I.PlayAt("empty", point);
                return;
            }
            if (head) dmg *= headMult;
            dmg *= dmgMul;
            bool wasFull = hp >= maxHp - 0.001f;
            hp -= dmg;
            flash = 1;
            if (dir != Vector3.zero && knockF > 0)
            {
                knock += new Vector3(dir.x, 0, dir.z) * knockF * knockMul;
                if (dir.y > 0.3f || explosion) vel.y = Mathf.Max(vel.y, knockF * 0.6f * knockMul);
            }
            // vurulma tepkisi: gövde darbenin yönünde sarsılır
            if (dir != Vector3.zero)
            {
                var f = Forward;
                float into = f.x * dir.x + f.z * dir.z;
                float side = f.x * dir.z - f.z * dir.x;
                float kk = Mathf.Min(1, 0.35f + dmg * 0.3f) / (big ? 2 : 1);
                hr.x += (into > 0 ? -1 : 1) * kk * (head ? 1.4f : 1);
                hr.y += side * kk;
            }
            UKFx.I.Blood(point, Mathf.Min(45, 6 + Mathf.RoundToInt(dmg * 10)), 5 + Mathf.Min(dmg, 4) * 2, dir);
            if (!quiet)
            {
                UKFx.I.Star(point, head ? new Color(1f, 0.88f, 0.38f) : Color.white, head ? 1.1f : 0.6f, 0.07f, 1.8f);
                if (weapon != "lava") UKAudio.I.Play("hitTick", 1, head ? 1.3f : 1);
            }
            if (!noHeal) game.BloodHeal(point, dmg);
            string fw = UKStyle.FreshWeapon(weapon);
            game.style.AddRaw(Mathf.Min(dmg, 6) * 18, fw);
            if (!grounded && state != "spawn" && !flying && weapon != "lava") game.style.Add("AIRSHOT", 35, fw);
            if (!quiet || Random.value < 0.25f) UKAudio.I.PlayAt(head ? "headshot" : "enemyHit", point);
            game.hud.Hitmarker(hp <= 0);
            if (hp <= 0) { Die(dmg, weapon, head, dir, false, wasFull, explosion, burning, pellets, knockF); return; }
            if (!big && !quiet && dmg >= 0.9f && state != "spawn" && state != "stagger" && state != "flinch" && H != null)
            {
                if (parryable) game.style.Add("INTERRUPTION", 50, fw);
                resume = FirstState;
                SetState("flinch");
            }
            OnHurt(dmg);
        }

        protected virtual void OnHurt(float dmg) { }

        public virtual void Parried(Vector3 dir)
        {
            parryable = false;
            stun = parryStun;
            Hit(parryDmg, Center, dir, false, "parry", 16, 2, false, true);
            if (!dead && state != "enrage") SetState("stagger");
        }

        // Ölüm biçimi: parçalanma / kafa kopması / yığılma
        protected virtual string DeathMode(float dmg, string weapon, bool head, bool explosion, int pellets)
        {
            if (boss || type == "trainer") return "gib";
            if (explosion || weapon == "rail" || weapon == "lava" || dmg >= 99) return "gib";
            if (dmg >= maxHp * 2.2f && !big) return "gib";
            if (weapon == "shotgun" && pellets >= 7) return "gib";
            if (head && H != null) return "decap";
            return "collapse";
        }

        protected virtual void Die(float dmg, string weapon, bool head, Vector3 dir, bool silent, bool wasFull = false, bool explosion = false, bool burning = false, int pellets = 0, float knockF = 0)
        {
            if (dead) return;
            dead = true;
            parryable = false;
            All.Remove(this);
            var game = UKGame.I;
            Vector3 c = Center;
            string fw = UKStyle.FreshWeapon(weapon);
            for (int i = 0; i < mats.Count; i++) mats[i].SetColor("_EmissionColor", matBase[i]);
            cc.enabled = false;
            foreach (var h in GetComponentsInChildren<Collider>()) h.enabled = false;
            string mode = DeathMode(dmg, weapon, head, explosion, pellets);
            if (boss && !silent && dmg < 99 && !decor) mode = "bossDeath";
            if (mode == "bossDeath")
            {
                deathT = 0;
                nextPop = 0.12f;
                deathDir = dir;
                deathParts = new List<Transform>();
                foreach (var mr in model.GetComponentsInChildren<MeshRenderer>()) if (mr.gameObject.name != "ng") deathParts.Add(mr.transform);
                for (int i = deathParts.Count - 1; i > 0; i--) { int j = Random.Range(0, i + 1); var t = deathParts[i]; deathParts[i] = deathParts[j]; deathParts[j] = t; }
                game.SlowMo(1.1f, 0.28f);
                game.Hitstop(0.2f);
                game.hud.Flash(new Color(1, 1, 1, 0.9f), 0.35f);
                P.Shake(0.7f);
                UKAudio.I.PlayAt("bossDeath", c);
                UKFx.I.Blood(c, 60, 10, dir);
            }
            else if (mode == "gib")
            {
                float force = explosion ? 12 : 5 + Mathf.Min(knockF, 20) * 0.4f;
                foreach (var mr in model.GetComponentsInChildren<MeshRenderer>())
                    if (mr.gameObject.name != "ng" && mr.gameObject.activeInHierarchy)
                        UKFx.I.GibFromPart(mr.transform, new Vector3(Random.Range(-1f, 1f), Random.Range(0.3f, 1.4f), Random.Range(-1f, 1f)) * force * Random.Range(0.4f, 1f) + dir * force * 0.8f);
                for (int i = 0; i < (big ? 12 : 6); i++) UKFx.I.Gib(c + Random.insideUnitSphere * 0.3f, new Vector3(Random.Range(-6f, 6f), Random.Range(3f, 9f), Random.Range(-6f, 6f)), Random.Range(0.08f, 0.2f));
                UKFx.I.Blood(c, big ? 110 : 60, big ? 15 : 11);
                OnGibbed();
                Destroy(gameObject);
            }
            else if (mode == "dive") { }
            else
            {
                if (mode == "decap")
                {
                    var v = dir * 6 + new Vector3(Random.Range(-1f, 1f), 5, Random.Range(-1f, 1f));
                    foreach (var mr in H.head.GetComponentsInChildren<MeshRenderer>())
                        if (mr.gameObject.name != "ng") UKFx.I.GibFromPart(mr.transform, v + new Vector3(Random.Range(-1f, 1f), Random.Range(0f, 1f), Random.Range(-1f, 1f)), 14);
                    UKFx.I.Blood(HeadPos, 40, 9, Vector3.up);
                    H.head.gameObject.SetActive(false);
                    UKFx.I.BloodFountain(H.neck, 1.6f);
                }
                else UKFx.I.Blood(c, 30, 8, dir);
                var f = Forward;
                fallSign = f.x * dir.x + f.z * dir.z > 0 ? -1 : 1;
                corpseT = 0;
                corpseVel = new Vector3(dir.x, 0, dir.z) * Mathf.Min(8, 2 + knockF * 0.4f);
                vel = Vector3.zero;
                corpses.Add(this);
                if (corpses.Count > 18) { var old = corpses[0]; corpses.RemoveAt(0); if (old) Destroy(old.gameObject); }
            }
            if (!silent)
            {
                UKAudio.I.PlayAt("gore", c);
                if (weapon != "lava") game.BloodHeal(c, big ? 3 : 1.5f);
                game.style.Add(big ? "BIG KILL" : null, killPts, fw);
                if (head && weapon != "lava") game.style.Add(big ? "BIG HEADSHOT" : "HEADSHOT", big ? 120 : 60, fw);
                if (explosion) game.style.Add("FRIED", 60, fw);
                if (wasFull && big && dmg >= maxHp) game.style.Add("INSTAKILL", 100, fw);
                if (weapon == "punch") game.style.Add("SPLATTERED", 60, null);
                if (weapon == "parry") game.style.Add("PARRIED KILL", 80, null);
                if (burning) game.style.Add("BURNED", 50, "rocket");
                game.style.OnKill(fw);
            }
            game.OnEnemyKilled(this);
            OnDied(dmg, weapon, head, dir, silent);
            if (mode == "dive") Dive();
        }

        protected virtual void OnGibbed() { }
        protected virtual void Dive() { RemoveSilently(); }
        protected virtual void OnDied(float dmg, string weapon, bool head, Vector3 dir, bool silent) { }

        // Ceset: öne/arkaya devrilir, uzuvlar gevşer, sonra yere gömülüp kaybolur
        protected virtual void CorpseTick(float dt)
        {
            corpseT += dt;
            float t = corpseT;
            if (t < 0.7f)
            {
                corpseVel *= Mathf.Exp(-dt * 4);
                vel.y -= 35 * dt;
                Vector3 step = new Vector3(corpseVel.x, vel.y, corpseVel.z) * dt;
                if (Physics.Raycast(transform.position + Vector3.up * 0.3f, Vector3.down, out var g, 0.3f - Mathf.Min(0, step.y) + 0.02f, ~0, QueryTriggerInteraction.Ignore) && !(g.collider is CharacterController))
                {
                    vel.y = 0;
                    step.y = 0;
                    transform.position = new Vector3(transform.position.x, g.point.y, transform.position.z);
                }
                if (!UKProjectile.WorldCast(transform.position + Vector3.up * 0.5f, new Vector3(step.x, 0, step.z).normalized, new Vector3(step.x, 0, step.z).magnitude + 0.3f, out _))
                    transform.position += new Vector3(step.x, 0, step.z);
                transform.position += new Vector3(0, step.y, 0);
            }
            float kk = Mathf.Min(1, t / 0.55f);
            float fall = kk * kk * (Mathf.PI / 2 - 0.08f);
            model.localRotation = W.Q(fallSign * fall, 0, 0);
            if (H != null)
            {
                float lk = 1 - Mathf.Exp(-6 * dt);
                void L(Transform j, float x, float z = 0) => j.localRotation = Quaternion.Slerp(j.localRotation, W.Q(x, 0, z), lk);
                L(H.spine, 0.1f * fallSign);
                L(H.shL, fallSign > 0 ? 2.4f : -0.5f, -0.5f);
                L(H.shR, fallSign > 0 ? 2.1f : -0.3f, 0.6f);
                L(H.elL, 0.3f); L(H.elR, 0.6f);
                L(H.hipL, 0.4f); L(H.hipR, -0.1f);
                L(H.knL, -0.8f); L(H.knR, -0.2f);
            }
            if (t > 0.5f && !landed)
            {
                landed = true;
                UKFx.I.Decal(transform.position + Vector3.up * 0.02f, Vector3.up, 2.2f);
                UKAudio.I.PlayAt("land", transform.position, 0.6f);
            }
            if (t > 7) model.localPosition = new Vector3(0, -(t - 7) * 0.4f, 0);
            if (t > 9) { corpses.Remove(this); Destroy(gameObject); }
        }

        void BossDeathTick(float dt)
        {
            deathT += dt;
            float j = 0.04f + deathT * 0.05f;
            model.localPosition = new Vector3(Random.Range(-j, j), Random.Range(-j, j) * 0.5f, Random.Range(-j, j));
            model.localRotation = Quaternion.Euler(0, 0, Random.Range(-2.3f, 2.3f));
            float pulse = 0.5f + 0.5f * Mathf.Sin(deathT * 38);
            foreach (var m in mats) m.SetColor("_EmissionColor", new Color(0.6f + 0.4f * pulse, 0.12f * pulse, 0.08f * pulse));
            if (deathT >= nextPop && deathT < 1.6f && deathParts.Count > 0)
            {
                nextPop = deathT + Mathf.Max(0.07f, 0.16f - deathT * 0.05f);
                var t = deathParts[deathParts.Count - 1];
                deathParts.RemoveAt(deathParts.Count - 1);
                if (t && t.gameObject.activeInHierarchy)
                {
                    Vector3 v = t.position - Center; v.y = 0;
                    v = v.normalized * Random.Range(4f, 8f) + Vector3.up * Random.Range(4f, 9f);
                    UKFx.I.GibFromPart(t, v, 12);
                    UKFx.I.Blood(t.position, 18, 8, v);
                    UKFx.I.Burst(t.position, 10, 8, new Color(1f, 0.75f, 0.38f), 0.35f, 0.06f);
                    if (Random.value < 0.5f && t.parent) UKFx.I.BloodFountain(t.parent, 0.6f);
                    UKAudio.I.PlayAt("gore", t.position, 1, Random.Range(0.8f, 1.2f));
                    t.gameObject.SetActive(false);
                    P.Shake(0.25f);
                }
            }
            if (deathT >= 1.7f)
            {
                Vector3 c = Center;
                foreach (var t in deathParts)
                    if (t && t.gameObject.activeInHierarchy) UKFx.I.GibFromPart(t, new Vector3(Random.Range(-1f, 1f), Random.Range(0.4f, 1.4f), Random.Range(-1f, 1f)) * Random.Range(8f, 16f) + deathDir * 5, 14);
                for (int i = 0; i < 16; i++) UKFx.I.Gib(c + Random.insideUnitSphere * 0.5f, new Vector3(Random.Range(-9f, 9f), Random.Range(4f, 13f), Random.Range(-9f, 9f)), Random.Range(0.1f, 0.25f));
                UKFx.I.Explosion(c, 5);
                UKFx.I.Blood(c, 160, 16);
                UKFx.I.Ring(transform.position, new Color(1f, 0.19f, 0.13f), 9, 0.6f);
                UKFx.I.Decal(transform.position + Vector3.up * 0.02f, Vector3.up, 5);
                UKAudio.I.PlayAt("explosion", c, 1, 0.7f);
                UKAudio.I.PlayAt("gore", c, 1, 0.6f);
                UKGame.I.hud.Flash(new Color(1, 0.16f, 0.08f, 0.6f), 0.4f);
                P.Shake(0.9f);
                deathT = -1;
                Destroy(gameObject);
            }
        }

        public virtual void RemoveSilently()
        {
            All.Remove(this);
            corpses.Remove(this);
            dead = true;
            Destroy(gameObject);
        }

        public static void ClearCorpses()
        {
            foreach (var c in corpses) if (c) Destroy(c.gameObject);
            corpses.Clear();
        }

        // Yumrukla/kancayla çekme vb. için
        public void Launch(float vy) { vel.y = vy; grounded = false; }
        public void Pull(Vector3 v) { vel = v; grounded = false; }
        public bool Grounded => grounded;

        // ------------------------------------------------------------ animasyon yardımcıları (web değerleri)
        protected void Rot(Transform j, float x, float y = 0, float z = 0) => j.localRotation = Quaternion.Slerp(j.localRotation, W.Q(x, y, z), k);

        protected void WalkPose(float amt, float armSwing = 1, float armBase = 0)
        {
            float s = Mathf.Sin(walkPhase), c = Mathf.Cos(walkPhase);
            Rot(H.hipL, s * 0.75f * amt); Rot(H.hipR, -s * 0.75f * amt);
            Rot(H.knL, -Mathf.Max(0, c) * 1.2f * amt - 0.05f); Rot(H.knR, -Mathf.Max(0, -c) * 1.2f * amt - 0.05f);
            Rot(H.shL, armBase - s * 0.6f * amt * armSwing, 0, -0.08f); Rot(H.shR, armBase + s * 0.6f * amt * armSwing, 0, 0.08f);
            Rot(H.elL, 0.35f + 0.3f * amt); Rot(H.elR, 0.35f + 0.3f * amt);
            H.hips.localPosition = new Vector3(0, H.hipY + Mathf.Abs(c) * 0.06f * amt - 0.03f * amt, 0);
            H.hips.localRotation = W.Q(0, s * 0.12f * amt, 0);
        }

        protected void AirPose()
        {
            Rot(H.hipL, 0.9f); Rot(H.hipR, 0.4f);
            Rot(H.knL, -1.3f); Rot(H.knR, -0.9f);
        }

        protected void Breathe(float amt = 0.04f)
        {
            H.spine.localRotation = H.spine.localRotation * W.Q(Mathf.Sin(time * 2.2f) * amt * k, 0, 0);
        }

        protected float HSpeed => new Vector2(vel.x, vel.z).magnitude;
    }

    // ------------------------------------------------------------------ FILTH: kambur, hızlı yakın dövüşçü
    public class UKFilth : UKEnemy
    {
        float jumpCd, pounceCd;
        bool hitDone;
        Transform jaw;
        protected override void Init()
        {
            type = "filth"; enemyName = "FILTH"; maxHp = 0.6f; radius = 0.4f; height = 1.55f; speed = 10.5f * DSpeed; killPts = 50;
            pounceCd = Random.Range(1f, 3f);
            var skin = M(C(0x9ec878), 0.13f, UKFx.TexSkin);
            var dark = M(C(0x5a3a28), 0.13f, UKFx.TexSkin);
            var bone = M(C(0xfff0d0), 0.13f, UKFx.TexBone);
            var flesh = M(C(0xff5050), 0.25f, UKFx.TexFlesh);
            H = UKHumanoid.Build(model, skin, dark, 0.62f, 0.42f, 0.52f, 0.3f, 0.3f, 1.35f, 0.95f, 1, 0.7f);
            H.Ribs(bone, 4);
            H.Vertebrae(bone, 5);
            W.Box(H.spine, H.torsoW * 0.6f, H.torsoH * 0.3f, 0.02f, flesh, 0, H.torsoH * 0.2f, -H.torsoD * 0.45f - 0.005f);
            var black = UKFx.Unlit(C(0x100404));
            W.Box(H.head, 0.22f, 0.12f, 0.02f, black, 0, 0.1f, -0.155f, 0, 0, 0, true);
            UKHumanoid.Teeth(H.head, 0.14f, -0.16f, 0.18f, bone, 6, true);
            jaw = W.J(H.head, 0, 0.05f, -0.02f);
            W.Limb(jaw, 0.24f, 0.06f, 0.26f, dark, -0.03f);
            UKHumanoid.Teeth(jaw, 0, -0.14f, 0.16f, bone, 5, false);
            foreach (float x in new[] { -0.075f, 0.075f }) W.Box(H.head, 0.07f, 0.06f, 0.02f, black, x, 0.22f, -0.155f, 0, 0, 0, true);
            W.Box(H.head, 0.04f, 0.04f, 0.02f, black, 0, 0.17f, -0.158f, 0, 0, 0, true);
            UKHumanoid.Claws(H.haL, bone);
            UKHumanoid.Claws(H.haR, bone);
        }

        protected override void OnLand()
        {
            if (state == "pounce") { SetState("recover"); UKAudio.I.PlayAt("land", transform.position, 0.5f); }
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist, out float dy);
            float aggro = Aggro;
            jumpCd -= dt; atkCd -= dt; pounceCd -= dt;
            switch (state)
            {
                case "chase":
                    {
                        Face(d, 10, dt);
                        float sp = dist > 1.8f ? speed : 0;
                        AccelTo(d * sp, grounded ? 60 : 12, dt);
                        if (grounded && jumpCd <= 0 && ((dy > 2 && dist < 10) || blocked > 0.35f))
                        {
                            vel = new Vector3(d.x * 9, 16.5f, d.z * 9);
                            grounded = false;
                            jumpCd = 1.4f;
                            blocked = 0;
                        }
                        if (dist < 2.9f && Mathf.Abs(dy) < 2 && atkCd <= 0 && grounded) { SetState("windup"); UKAudio.I.PlayAt("filthGrowl", transform.position); }
                        else if (dist > 4.5f && dist < 8 && Mathf.Abs(dy) < 1.5f && pounceCd <= 0 && grounded && canSee) { SetState("pounceWind"); UKAudio.I.PlayAt("screech", transform.position); }
                        break;
                    }
                case "pounceWind":
                    Face(d, 14, dt); Brake(40, dt);
                    if (st > 0.3f / aggro)
                    {
                        state = "pounce"; st = 0; hitDone = false;
                        float s = Mathf.Min(16, dist * 1.9f);
                        vel = new Vector3(d.x * s, 8.5f, d.z * s);
                        grounded = false;
                        pounceCd = Random.Range(3f, 5f) / aggro;
                        SetParryable(true, HeadPos);
                    }
                    break;
                case "pounce":
                    if (st > 0.35f) SetParryable(false);
                    if (!hitDone && dist < 1.8f && MeleeHit(2.2f, 18, -0.2f)) hitDone = true;
                    if (st > 1.2f) SetState("recover");
                    break;
                case "windup":
                    {
                        Face(d, 12, dt); Brake(40, dt);
                        float dur = 0.5f / aggro;
                        if (st > dur - 0.24f) SetParryable(true);
                        if (st >= dur) { state = "attack"; st = 0; hitDone = false; var f = Forward; vel.x = f.x * 9; vel.z = f.z * 9; }
                        break;
                    }
                case "attack":
                    if (st > 0.12f) SetParryable(false);
                    if (!hitDone && st > 0.08f) { if (MeleeHit(2.9f, 20, 0.25f)) hitDone = true; if (st > 0.2f) hitDone = true; }
                    Brake(25, dt);
                    if (st > 0.4f) SetState("recover");
                    break;
                case "recover":
                    Brake(30, dt);
                    if (st > 0.45f / aggro) { SetState("chase"); atkCd = 0.5f; }
                    break;
            }
        }

        protected override void Animate(float dt)
        {
            k = 1 - Mathf.Exp(-18 * dt);
            float hsp = HSpeed;
            walkPhase += hsp * dt * 1.25f;
            float amt = Mathf.Clamp01(hsp / 8);
            float jawOpen = 0.1f;
            if (state == "windup" || state == "pounceWind")
            {
                Rot(H.spine, state == "pounceWind" ? -0.9f : -0.25f);
                Rot(H.shL, 2.7f, 0, -0.3f); Rot(H.shR, 2.7f, 0, 0.3f);
                Rot(H.elL, 0.6f); Rot(H.elR, 0.6f);
                Rot(H.hipL, 0.5f); Rot(H.hipR, -0.2f);
                Rot(H.knL, -0.9f); Rot(H.knR, -0.7f);
                jawOpen = 0.6f;
            }
            else if (state == "pounce")
            {
                Rot(H.spine, -0.9f);
                Rot(H.shL, 1.8f, 0, -0.5f); Rot(H.shR, 1.8f, 0, 0.5f);
                Rot(H.elL, 0.1f); Rot(H.elR, 0.1f);
                AirPose();
                jawOpen = 0.9f;
            }
            else if (state == "attack")
            {
                Rot(H.spine, -1.0f);
                Rot(H.shL, 0.5f, 0, -0.1f); Rot(H.shR, 0.5f, 0, 0.1f);
                Rot(H.elL, 0.2f); Rot(H.elR, 0.2f);
                jawOpen = 0.8f;
            }
            else if (state == "idle") { Rot(H.spine, -0.6f); WalkPose(0, 0, 0.3f); Breathe(0.05f); }
            else if (state == "flinch" || state == "stagger")
            {
                Rot(H.spine, 0.1f);
                Rot(H.shL, -0.4f, 0, -0.5f); Rot(H.shR, -0.4f, 0, 0.5f);
                jawOpen = 0.7f;
            }
            else
            {
                Rot(H.spine, -0.62f - amt * 0.25f);
                WalkPose(amt, 1.3f, 0.5f + amt * 0.4f);
                if (!grounded && state != "spawn") AirPose();
                jawOpen = 0.25f + Mathf.Abs(Mathf.Sin(time * 6)) * 0.2f;
            }
            jaw.localRotation = W.Q(-jawOpen);
        }
    }

    // ------------------------------------------------------------------ STRAY: kukuletalı küre atıcı
    public class UKStray : UKEnemy
    {
        protected float strafeT, strafeDir = 1;
        protected Transform orb;
        protected bool thrown;
        readonly List<Transform> rags = new List<Transform>();
        protected override string FirstState => "move";
        protected virtual Color SkinColor => C(0xe0a882);
        protected virtual Color ClothColor => C(0xd8581c);

        protected override void Init()
        {
            type = "stray"; enemyName = "STRAY"; maxHp = 2; radius = 0.4f; height = 1.95f; speed = 6.5f * DSpeed; killPts = 70;
            strafeDir = Random.value < 0.5f ? 1 : -1;
            strafeT = Random.Range(1f, 2.5f);
            atkCd = Random.Range(1f, 2.2f);
            var skin = M(SkinColor, 0.13f, UKFx.TexSkin);
            var dark = M(C(0x4a2a1c), 0.13f, UKFx.TexSkin);
            var cloth = M(ClothColor, 0.13f, UKFx.TexCloth);
            var band = M(C(0xfff0c0), 0.13f, UKFx.TexBone);
            H = UKHumanoid.Build(model, skin, dark, 0.22f, 0.36f, 0.58f, 0.26f, 0.27f, 1.08f, 1.1f, 1.05f, 0.75f);
            W.Cone(H.head, 0.23f, 0.42f, cloth, 0, 0.26f, 0.03f, -0.25f, 0, 0, false, 6);
            W.Box(H.head, 0.3f, 0.3f, 0.06f, cloth, 0, 0.15f, 0.13f);
            W.Box(H.spine, H.torsoW + 0.08f, H.torsoH * 0.9f, 0.04f, cloth, 0, H.torsoH * 0.55f, H.torsoD / 2 + 0.03f);
            foreach (float x in new[] { -0.12f, 0, 0.12f })
            {
                var rj = W.J(H.hips, x, -0.05f, -0.12f);
                W.Limb(rj, 0.1f, 0.42f, 0.02f, cloth, -0.2f);
                rags.Add(rj);
            }
            foreach (var el in new[] { H.elL, H.elR }) foreach (float y in new[] { -0.1f, -0.22f }) W.Box(el, 0.11f, 0.04f, 0.11f, band, 0, y, 0);
            var glowEye = UKFx.Unlit(C(0xffb040));
            foreach (float x in new[] { -0.065f, 0.065f }) W.Box(H.head, 0.05f, 0.035f, 0.02f, glowEye, x, 0.18f, -0.14f, 0, 0, 0, true);
            W.Box(H.head, 0.14f, 0.05f, 0.02f, UKFx.Unlit(C(0x100404)), 0, 0.08f, -0.14f, 0, 0, 0, true);
            orb = W.J(H.haR, 0, -0.14f, 0);
            var core = UKFx.Part(orb, Vector3.zero, Vector3.one * 0.3f, UKFx.Unlit(C(0xfff2c0)));
            core.name = "ng";
            core.transform.localRotation = Quaternion.Euler(45, 45, 0);
            W.Glow(orb, 0, 0, 0, 1.2f, C(0xff8a20));
            orb.gameObject.SetActive(false);
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist);
            float aggro = Aggro;
            atkCd -= dt;
            switch (state)
            {
                case "move":
                    {
                        Face(d, 8, dt);
                        strafeT -= dt;
                        if (strafeT <= 0) { strafeT = Random.Range(1.2f, 2.8f); strafeDir *= -1; }
                        float want = dist > 26 ? 1 : dist < 11 ? -1 : 0;
                        Vector3 tv = (d * want + Side(d) * strafeDir * 0.55f) * speed;
                        if (tv.sqrMagnitude > 0.01f && grounded && !GroundAhead(tv.normalized)) { tv = Vector3.zero; strafeDir *= -1; }
                        if (blocked > 0.3f) { strafeDir *= -1; blocked = 0; }
                        AccelTo(tv, 30, dt);
                        if (atkCd <= 0 && canSee && dist < 50) { SetState("windup"); UKAudio.I.PlayAt("orbCharge", transform.position); }
                        break;
                    }
                case "windup":
                    {
                        Face(d, 10, dt); Brake(25, dt);
                        float dur = 0.95f / aggro;
                        orb.gameObject.SetActive(true);
                        orb.localScale = Vector3.one * (0.3f + 0.9f * Mathf.Clamp01(st / dur));
                        if (st >= dur) { state = "throw"; st = 0; thrown = false; }
                        break;
                    }
                case "throw":
                    if (!thrown && st > 0.1f) { thrown = true; orb.gameObject.SetActive(false); ThrowOrb(); }
                    if (st > 0.45f) { SetState("move"); atkCd = Random.Range(1.9f, 3.2f) / aggro; }
                    break;
            }
            if (state != "windup" && state != "throw" && orb.gameObject.activeSelf) orb.gameObject.SetActive(false);
        }

        protected override void OnHurt(float dmg) { orb.gameObject.SetActive(false); }

        protected void ThrowOrb(float speedMul = 1, float dmg = 25)
        {
            Vector3 from = orb.position;
            float sp = 27 * DSpeed * speedMul;
            Shoot(from, AimAt(from, sp, 0.4f, 0.6f), sp, dmg, C(0xff8a20), 0.35f);
            UKAudio.I.PlayAt("orbThrow", from);
        }

        protected override void Animate(float dt)
        {
            float hsp = HSpeed;
            walkPhase += hsp * dt * 1.4f;
            float amt = Mathf.Clamp01(hsp / 6);
            if (state == "windup")
            {
                WalkPose(0, 0, 0);
                Rot(H.spine, -0.05f, 0.4f);
                Rot(H.shR, -2.5f, 0, 0.3f); Rot(H.elR, 0.9f);
                Rot(H.shL, 0.6f, 0, -0.4f);
            }
            else if (state == "throw")
            {
                Rot(H.spine, -0.45f, -0.35f);
                Rot(H.shR, 1.5f, 0, 0.1f); Rot(H.elR, 0.1f);
                Rot(H.shL, -0.3f);
            }
            else if (state == "flinch" || state == "stagger")
            {
                Rot(H.spine, 0.25f);
                Rot(H.shL, -0.3f, 0, -0.4f); Rot(H.shR, -0.3f, 0, 0.4f);
            }
            else
            {
                Rot(H.spine, -0.22f, 0);
                WalkPose(amt, 0.8f, 0.1f);
                if (!grounded && state != "spawn") AirPose();
                Breathe(0.03f);
            }
            for (int i = 0; i < rags.Count; i++) rags[i].localRotation = W.Q(0.15f + amt * 0.5f + Mathf.Sin(time * 7 + i) * 0.12f);
        }
    }

    // Parry eğitmeni: kafesteki hareketsiz Stray; yavaş küre fırlatır, yalnız savuşturulan kendi küresiyle ölür
    public class UKTrainer : UKStray
    {
        public string trainerDoor;
        protected override Color SkinColor => C(0xa8c0ff);
        protected override Color ClothColor => C(0x2c50e0);
        protected override void Init()
        {
            base.Init();
            type = "trainer"; enemyName = "EĞİTMEN"; maxHp = 1; onlyParry = true; noCount = true; killPts = 0; speed = 0; atkCd = 1.5f;
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist);
            atkCd -= dt;
            Face(d, 8, dt);
            Brake(30, dt);
            if (state == "move" && atkCd <= 0 && canSee && dist < 22) { SetState("windup"); UKAudio.I.PlayAt("orbCharge", transform.position); }
            else if (state == "windup")
            {
                const float dur = 1.1f;
                orb.gameObject.SetActive(true);
                orb.localScale = Vector3.one * (0.3f + 0.9f * Mathf.Clamp01(st / dur));
                if (st >= dur) { state = "throw"; st = 0; thrown = false; }
            }
            else if (state == "throw")
            {
                if (!thrown && st > 0.1f) { thrown = true; orb.gameObject.SetActive(false); ThrowOrb(0.42f, 6); }
                if (st > 0.45f) { SetState("move"); atkCd = 2; }
            }
        }
    }

    // ------------------------------------------------------------------ SCHISM: bıçak kollu, mermi dizisi
    public class UKSchism : UKEnemy
    {
        float strafeT = 2, strafeDir = 1, meleeCd, aimYaw;
        int shots;
        bool hitDone;
        string mode = "H";
        Transform tip, tipGlow;
        protected override string FirstState => "move";

        protected override void Init()
        {
            type = "schism"; enemyName = "SCHISM"; maxHp = 6; radius = 0.55f; height = 2.3f; speed = 4.6f * DSpeed; big = true; killPts = 130; knockMul = 0.55f;
            atkCd = Random.Range(1.2f, 2f);
            var skin = M(C(0xa08ae8), 0.13f, UKFx.TexSkin);
            var dark = M(C(0x38225a), 0.13f, UKFx.TexSkin);
            var bone = M(C(0xfff0c0), 0.13f, UKFx.TexBone);
            var flesh = M(C(0xff4a8a), 0.25f, UKFx.TexFlesh);
            H = UKHumanoid.Build(model, skin, dark, 0.16f, 0.56f, 0.66f, 0.34f, 0.3f, 1.12f, 1.1f, 1.2f, 0.8f);
            H.foreL.SetActive(false);
            H.handL.SetActive(false);
            W.Cyl(H.elL, 0.02f, 0.14f, 1.4f, bone, 0, -0.7f, 0, 0, 0, 0, 5);
            var rune = UKFx.Unlit(C(0xffd040));
            for (int k = 0; k < 4; k++) W.Box(H.elL, 0.03f, 0.08f, 0.03f, rune, 0.06f - k * 0.005f, -0.25f - k * 0.25f, -0.05f, 0, 0, 0, true);
            tip = W.J(H.elL, 0, -1.4f, 0);
            tipGlow = W.Glow(tip, 0, 0, 0, 0.5f, C(0xffd040)).transform;
            foreach (float x in new[] { -0.22f, 0, 0.22f }) W.Cone(H.spine, 0.06f, 0.3f, dark, x, 0.68f, 0.12f, 0.5f, 0, 0, false, 4);
            for (int k = 0; k < 5; k++)
            {
                float a = (k / 4f - 0.5f) * 1.6f;
                W.Cone(H.head, 0.035f, 0.2f, bone, Mathf.Sin(a) * 0.13f, 0.36f, Mathf.Cos(a) * 0.05f, -0.2f, 0, -a * 0.6f, false, 4);
            }
            W.Box(H.spine, H.torsoW * 0.5f, H.torsoH * 0.35f, 0.02f, flesh, 0, H.torsoH * 0.25f, -H.torsoD / 2 - 0.005f);
            for (int k = 0; k < 4; k++) W.Box(H.spine, 0.16f, 0.015f, 0.03f, dark, 0, H.torsoH * (0.14f + k * 0.07f), -H.torsoD / 2 - 0.01f);
            H.Vertebrae(bone, 4);
            var eyes = UKFx.Unlit(C(0xffe060));
            foreach (float x in new[] { -0.07f, 0.07f }) W.Box(H.head, 0.06f, 0.04f, 0.02f, eyes, x, 0.21f, -0.155f, 0, 0, 0, true);
            W.Box(H.head, 0.16f, 0.06f, 0.02f, UKFx.Unlit(C(0x100404)), 0, 0.08f, -0.155f, 0, 0, 0, true);
            UKHumanoid.Teeth(H.head, 0.11f, -0.16f, 0.14f, bone, 5, true);
            AddHitSphere(tip, W.V(0, 0.5f, 0), 0.18f, false);
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist, out float dy);
            float aggro = Aggro;
            atkCd -= dt; meleeCd -= dt;
            switch (state)
            {
                case "move":
                    {
                        Face(d, 6, dt);
                        strafeT -= dt;
                        if (strafeT <= 0) { strafeT = Random.Range(1.5f, 3f); strafeDir *= -1; }
                        float want = dist > 17 ? 1 : dist < 7 ? -0.6f : 0;
                        if (blocked > 0.4f) { strafeDir *= -1; blocked = 0; }
                        AccelTo((d * want + Side(d) * strafeDir * 0.4f) * speed, 20, dt);
                        if (dist < 3.4f && meleeCd <= 0 && Mathf.Abs(dy) < 2) { SetState("swipeWind"); UKAudio.I.PlayAt("windup", transform.position); }
                        else if (atkCd <= 0 && canSee)
                        {
                            mode = Random.value < 0.5f ? "H" : "V";
                            SetState("wind");
                            UKAudio.I.PlayAt("windup", transform.position);
                            UKAudio.I.PlayAt("filthGrowl", transform.position, 1, 0.6f);
                        }
                        break;
                    }
                case "wind":
                    Face(d, 8, dt); Brake(20, dt);
                    if (st >= 0.8f / aggro) { state = "fire"; st = 0; shots = 0; aimYaw = yaw; }
                    break;
                case "fire":
                    {
                        int n = mode == "H" ? 9 : 7;
                        float dur = mode == "H" ? 0.55f : 0.42f;
                        while (shots < n && st >= (shots / (float)(n - 1)) * dur) { FireShot(shots, n); shots++; }
                        if (shots >= n && st > dur + 0.15f) SetState("recover");
                        break;
                    }
                case "swipeWind":
                    {
                        Face(d, 10, dt); Brake(20, dt);
                        float dur = 0.55f / aggro;
                        if (st > dur - 0.26f) SetParryable(true, tip.position);
                        if (st >= dur) { state = "attack"; st = 0; hitDone = false; UKAudio.I.PlayAt("swing", transform.position); }
                        break;
                    }
                case "attack":
                    if (st > 0.1f) SetParryable(false);
                    if (!hitDone && st > 0.06f) { if (MeleeHit(3.6f, 30, 0.1f)) hitDone = true; if (st > 0.2f) hitDone = true; }
                    if (st > 0.4f) { SetState("recover"); meleeCd = 1.5f; }
                    break;
                case "recover":
                    Brake(20, dt);
                    if (st > 0.6f / aggro) { SetState("move"); atkCd = Random.Range(2f, 3.2f) / aggro; }
                    break;
            }
        }

        void FireShot(int idx, int n)
        {
            Vector3 from = tip.position;
            Vector3 target = P.transform.position + Vector3.up * 0.9f;
            Vector3 b = (target - from).normalized;
            float y = Mathf.Atan2(b.x, b.z), pitch = Mathf.Asin(Mathf.Clamp(b.y, -1, 1));
            float kk = idx / (float)(n - 1);
            float dy = 0, dp = 0;
            if (mode == "H") dy = (kk - 0.5f) * 1.1f; else dp = (kk - 0.35f) * 0.65f;
            float cp = Mathf.Cos(pitch + dp);
            var dir = new Vector3(Mathf.Sin(y + dy) * cp, Mathf.Sin(pitch + dp), Mathf.Cos(y + dy) * cp);
            Shoot(from, dir, 30 * DSpeed, 20, C(0xffd040), 0.26f);
            UKAudio.I.PlayAt("schismShot", from);
        }

        protected override void Animate(float dt)
        {
            k = 1 - Mathf.Exp(-14 * dt);
            float hsp = HSpeed;
            walkPhase += hsp * dt * 1.2f;
            float amt = Mathf.Clamp01(hsp / 4.5f);
            tipGlow.localScale = Vector3.one * (state == "wind" || state == "fire" ? 0.9f + Mathf.Sin(time * 30) * 0.2f : 0.45f);
            if (state == "wind")
            {
                WalkPose(0);
                if (mode == "H") { Rot(H.spine, -0.1f, 0.7f); Rot(H.shL, 1.5f); } else { Rot(H.spine, 0.05f, 0.2f); Rot(H.shL, 1.2f); }
                Rot(H.elL, 0);
            }
            else if (state == "fire")
            {
                float kk = Mathf.Clamp01(st / (mode == "H" ? 0.55f : 0.42f));
                if (mode == "H") { Rot(H.spine, -0.1f, 0.55f - kk * 1.1f); Rot(H.shL, 1.55f); } else { Rot(H.spine, 0.05f, 0.2f); Rot(H.shL, 1.2f + kk * 0.9f); }
                Rot(H.elL, 0);
            }
            else if (state == "swipeWind") { Rot(H.spine, 0.1f, 0.6f); Rot(H.shL, -0.9f, 0, -0.6f); Rot(H.elL, 0.2f); }
            else if (state == "attack") { Rot(H.spine, -0.35f, -0.6f); Rot(H.shL, 1.7f, 0, 0.2f); Rot(H.elL, 0.1f); }
            else if (state == "stagger") Rot(H.spine, 0.35f);
            else
            {
                Rot(H.spine, -0.16f, 0);
                WalkPose(amt, 0.6f, 0.05f);
                Rot(H.shL, 0.5f - Mathf.Sin(walkPhase) * 0.3f * amt, 0, -0.15f);
                Rot(H.elL, 0.4f);
                Breathe(0.03f);
            }
        }
    }

    // ------------------------------------------------------------------ SWORDSMACHINE (boss)
    public class UKSwordsmachine : UKEnemy
    {
        float baseSpeed, cdMul = 1;
        int combo;
        bool hasSword = true, hitDone, gunGlint;
        Transform sword, gun, gunMuzzle, exhaust;
        readonly List<Transform> teeth = new List<Transform>();
        Material visorMat;
        protected override float SpawnDur => 0.9f;

        public Vector3 HandWorld => H.haR.position;

        protected override void Init()
        {
            type = "swordsmachine"; enemyName = "SWORDSMACHINE"; maxHp = 40; radius = 0.6f; height = 2.55f; big = true; boss = true; killPts = 400; knockMul = 0.25f; parryDmg = 5; parryStun = 1.6f;
            baseSpeed = 9.5f * DSpeed; speed = baseSpeed; atkCd = 1; tint = 1;
            var metal = M(C(0xc8d0dc), 0.13f, UKFx.TexMachine);
            var dark = M(C(0x3a3e4c), 0.13f, UKFx.TexMachine);
            var plate = M(C(0xffb420), 0.18f, UKFx.TexMetal);
            H = UKHumanoid.Build(model, metal, dark, 0.1f, 0.58f, 0.64f, 0.34f, 0.3f, 1.08f, 1.08f, 1.32f, 0.7f);
            visorMat = new Material(UKFx.Unlit(C(0xffa020)));
            gameObject.AddComponent<UKOwnMat>().m = visorMat;
            W.Box(H.head, 0.28f, 0.06f, 0.02f, visorMat, 0, 0.2f, -0.16f, 0, 0, 0, true);
            W.Box(H.head, 0.32f, 0.08f, 0.34f, plate, 0, 0.34f, 0);
            foreach (float x in new[] { -0.12f, 0.12f }) W.Cone(H.head, 0.03f, 0.22f, dark, x, 0.42f, 0.08f, -0.5f, 0, x * 2, false, 4);
            W.Box(H.spine, 0.18f, 0.18f, 0.04f, visorMat, 0, 0.42f, -0.18f, 0, 0, 0, true);
            W.Box(H.spine, 0.26f, 0.24f, 0.05f, plate, -0.16f, 0.5f, -0.17f, 0, 0.3f, 0);
            W.Box(H.spine, 0.26f, 0.24f, 0.05f, plate, 0.16f, 0.5f, -0.17f, 0, -0.3f, 0);
            for (int k = 0; k < 3; k++) W.Box(H.spine, H.torsoW * 0.7f, 0.05f, H.torsoD + 0.02f, dark, 0, 0.08f + k * 0.08f, 0);
            foreach (float x in new[] { -0.14f, 0.14f }) W.Cyl(H.spine, 0.05f, 0.06f, 0.4f, dark, x, 0.55f, 0.22f, 0.2f, 0, 0, 6);
            exhaust = W.J(H.spine, 0, 0.8f, 0.26f);
            foreach (var t in new[] { H.shL, H.shR }) W.Box(t, 0.26f, 0.14f, 0.32f, plate, 0, 0.04f, 0);
            foreach (var t in new[] { H.knL, H.knR }) W.Box(t, 0.16f, 0.14f, 0.08f, plate, 0, 0.02f, -0.08f);
            // kılıç (zincirli testere kılıcı, dişleri akar)
            sword = W.J(H.haR, 0, 0, 0, "sword");
            var blade = M(C(0xc8ccd4), 0.13f, UKFx.TexMetal);
            W.Box(sword, 0.06f, 0.22f, 0.06f, dark, 0, -0.06f, 0);
            W.Box(sword, 0.3f, 0.05f, 0.1f, dark, 0, -0.18f, 0);
            W.Box(sword, 0.05f, 1.4f, 0.2f, blade, 0, -0.9f, 0);
            W.Box(sword, 0.055f, 1.35f, 0.025f, visorMat, 0, -0.9f, -0.11f);
            for (int k = 0; k < 10; k++) teeth.Add(W.Box(sword, 0.035f, 0.06f, 0.05f, dark, 0, -0.3f - k * 0.13f, -0.135f, 0, 0, 0, true).transform);
            sword.localRotation = W.Q(Mathf.PI / 2);
            // pompalı tüfek (sol elde, kullanırken görünür)
            gun = W.J(H.haL, 0, 0, 0, "gun");
            W.Box(gun, 0.12f, 0.62f, 0.14f, dark, 0, -0.28f, 0);
            W.Box(gun, 0.07f, 0.3f, 0.07f, metal, 0, -0.62f, -0.02f);
            W.Box(gun, 0.13f, 0.04f, 0.15f, visorMat, 0, -0.1f, 0, 0, 0, 0, true);
            gunMuzzle = W.J(gun, 0, -0.8f, 0);
            gun.gameObject.SetActive(false);
        }

        public void CatchSword()
        {
            hasSword = true;
            sword.gameObject.SetActive(true);
            UKAudio.I.PlayAt("chainsaw", transform.position);
        }

        protected override void OnHurt(float dmg)
        {
            if (!enraged && hp < maxHp * 0.5f && state != "enrage")
            {
                SetState("enrage");
                invuln = true;
                UKAudio.I.PlayAt("bossRoar", transform.position);
                P.Shake(0.5f);
            }
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist);
            float cd = cdMul / Aggro;
            atkCd -= dt;
            switch (state)
            {
                case "chase":
                    Face(d, 8, dt);
                    AccelTo(d * (dist > 3 ? speed : 0), 40, dt);
                    if (atkCd <= 0)
                    {
                        if (dist < 4.5f && hasSword) { combo = 0; SetState("swingWind"); UKAudio.I.PlayAt("chainsaw", transform.position); }
                        else if (dist > 11 && hasSword && Random.value < 0.45f) { SetState("throwWind"); UKAudio.I.PlayAt("windup", transform.position); }
                        else if (Random.value < 0.5f || !hasSword) { SetState("gunWind"); gun.gameObject.SetActive(true); UKAudio.I.PlayAt("windup", transform.position); }
                        else if (hasSword) { SetState("dash"); UKAudio.I.PlayAt("dash", transform.position); }
                        else atkCd = 0.3f;
                    }
                    if (blocked > 0.5f && grounded) { vel.y = 14; grounded = false; blocked = 0; }
                    break;
                case "dash":
                    {
                        Face(d, 10, dt);
                        float s = 30 * DSpeed;
                        vel.x = d.x * s; vel.z = d.z * s;
                        if (Random.value < dt * 40) UKFx.I.Burst(transform.position + Vector3.up * 0.2f, 1, 4, new Color(1f, 0.63f, 0.19f), 0.3f, 0.06f);
                        if (dist < 3.6f || st > 0.45f) { combo = 0; SetState("swingWind"); }
                        break;
                    }
                case "swingWind":
                    {
                        Face(d, 9, dt); Brake(30, dt);
                        bool last = combo == 2;
                        float dur = (last ? 0.55f : 0.34f) * cd;
                        if (last && st > dur - 0.27f) SetParryable(true, HandWorld);
                        if (st >= dur)
                        {
                            state = "swing"; st = 0; hitDone = false;
                            var f = Forward; vel.x = f.x * 10; vel.z = f.z * 10;
                            UKAudio.I.PlayAt("swing", transform.position);
                        }
                        break;
                    }
                case "swing":
                    if (st > 0.1f) SetParryable(false);
                    Brake(40, dt);
                    if (!hitDone && st > 0.05f) { if (MeleeHit(4.3f, 25, 0.15f)) hitDone = true; if (st > 0.18f) hitDone = true; }
                    if (st > 0.28f)
                    {
                        combo++;
                        if (combo >= 3) { SetState("recover"); atkCd = Random.Range(0.8f, 1.4f) * cd; }
                        else { state = "swingWind"; st = 0; }
                    }
                    break;
                case "throwWind":
                    Face(d, 9, dt); Brake(30, dt);
                    if (st >= 0.6f * cd) { ThrowSword(); SetState("recoverShort"); }
                    break;
                case "recoverShort":
                    Brake(30, dt);
                    if (st > 0.35f) { SetState("gunWind"); gun.gameObject.SetActive(true); }
                    break;
                case "gunWind":
                    Face(d, 10, dt); Brake(30, dt);
                    if (st > 0.55f * cd - 0.2f && !gunGlint) { gunGlint = true; Glint(gunMuzzle.position); }
                    if (st >= 0.55f * cd) { FireShotgun(); gunGlint = false; SetState("gunRecover"); }
                    break;
                case "gunRecover":
                    Brake(30, dt);
                    if (st > 0.5f) { gun.gameObject.SetActive(false); SetState("chase"); atkCd = Random.Range(0.6f, 1.2f) * cd; }
                    break;
                case "recover":
                    Brake(30, dt);
                    if (st > 0.7f * cd) SetState("chase");
                    break;
                case "enrage":
                    Brake(30, dt);
                    if (Random.value < dt * 20) UKFx.I.Burst(Center, 3, 8, new Color(1f, 0.25f, 0.13f), 0.4f, 0.07f);
                    if (st > 1.3f)
                    {
                        enraged = true;
                        invuln = false;
                        speed = baseSpeed * 1.3f;
                        cdMul = 0.7f;
                        var c = C(0xff2010);
                        if (visorMat.HasProperty("_Color")) visorMat.SetColor("_Color", c);
                        if (visorMat.HasProperty("_BaseColor")) visorMat.SetColor("_BaseColor", c);
                        UKGame.I.style.Add("ENRAGED", 50, null);
                        UKGame.I.hud.Message("SWORDSMACHINE ÖFKELENDİ", 1.4f);
                        SetState("chase");
                    }
                    break;
            }
        }

        void ThrowSword()
        {
            Vector3 from = HandWorld;
            Vector3 dir = (P.transform.position + Vector3.up - from).normalized;
            hasSword = false;
            var copy = Instantiate(sword.gameObject).transform;
            copy.gameObject.SetActive(true);
            copy.localScale = Vector3.one * H.scale;
            copy.localRotation = Quaternion.Euler(0, 0, 90);
            sword.gameObject.SetActive(false);
            UKProjectile.Spawn(UKProjectile.Kind.Sword, from, dir * 32 * DSpeed, false, 30 * DDmg, Color.white, this, 0.6f, copy);
            UKAudio.I.PlayAt("swing", from);
            UKAudio.I.PlayAt("chainsaw", from);
        }

        void FireShotgun()
        {
            Vector3 from = gunMuzzle.position;
            Vector3 b = (P.transform.position + Vector3.up * 0.9f - from).normalized;
            for (int k = 0; k < 9; k++)
            {
                var dd = (b + new Vector3(Random.Range(-0.11f, 0.11f), Random.Range(-0.06f, 0.08f), Random.Range(-0.11f, 0.11f))).normalized;
                var pr = Shoot(from, dd, 65, 9, C(0xffc040), 0.2f, UKProjectile.Kind.Bullet);
                pr.life = 1.5f;
            }
            UKFx.I.Glow(from, new Color(1f, 0.82f, 0.5f), 1.5f, 0.08f, 2);
            UKFx.I.Smoke(from, 3, new Color(0.6f, 0.54f, 0.5f), 0.6f, 0.8f, 0.6f);
            UKFx.I.Flash(from, new Color(1f, 0.7f, 0.25f), 8, 18, 0.08f);
            UKAudio.I.PlayAt("bossShotgun", from, 1, 0.8f);
        }

        public override void Parried(Vector3 dir)
        {
            base.Parried(dir);
            if (!dead) UKAudio.I.PlayAt("bossRoar", transform.position, 0.5f);
        }

        protected override void OnDied(float dmg, string weapon, bool head, Vector3 dir, bool silent)
        {
            gun.gameObject.SetActive(false);
            UKGame.I.Hitstop(0.35f);
        }

        protected override void Animate(float dt)
        {
            float hsp = HSpeed;
            walkPhase += hsp * dt;
            float amt = Mathf.Clamp01(hsp / 9);
            string s = state;
            float saw = s == "swing" || s == "swingWind" || s == "dash" ? 6 : 1.2f;
            for (int i = 0; i < teeth.Count; i++) teeth[i].localPosition = W.V(0, -0.3f - Mathf.Repeat(i * 0.13f + time * saw, 1.3f), -0.135f);
            if (Random.value < dt * (enraged ? 10 : 3)) UKFx.I.Smoke(exhaust.position, 1, enraged ? new Color(0.38f, 0.13f, 0.06f) : new Color(0.38f, 0.38f, 0.38f), 0.35f, 0.8f, 1.5f);
            if (s == "swingWind")
            {
                bool alt = combo % 2 == 1;
                WalkPose(0);
                Rot(H.spine, 0.1f, alt ? -0.7f : 0.7f);
                Rot(H.shR, alt ? 1.2f : 2.9f, 0, alt ? 1.3f : 0.2f);
                Rot(H.elR, 0.5f);
                Rot(H.shL, 0.4f, 0, -0.3f);
                Rot(H.hipL, 0.4f); Rot(H.knL, -0.5f); Rot(H.hipR, -0.3f);
            }
            else if (s == "swing")
            {
                bool alt = combo % 2 == 1;
                Rot(H.spine, -0.4f, alt ? 0.7f : -0.5f);
                Rot(H.shR, alt ? 1.3f : 0.5f, 0, alt ? -0.9f : 0);
                Rot(H.elR, 0.1f);
            }
            else if (s == "throwWind") { WalkPose(0); Rot(H.spine, 0.1f, 0.9f); Rot(H.shR, 2.6f, 0, 0.8f); Rot(H.elR, 0.4f); }
            else if (s == "recoverShort") { Rot(H.spine, -0.3f, -0.5f); Rot(H.shR, 1.5f, 0, -0.5f); }
            else if (s == "gunWind" || s == "gunRecover")
            {
                WalkPose(0);
                Rot(H.spine, 0, -0.35f);
                Rot(H.shL, 1.55f + (s == "gunRecover" && st < 0.15f ? 0.5f : 0), 0.2f, 0);
                Rot(H.elL, 0);
                Rot(H.shR, 0.3f, 0, 0.2f);
            }
            else if (s == "enrage")
            {
                float sh = Mathf.Sin(time * 50) * 0.05f;
                Rot(H.spine, 0.35f + sh, 0);
                Rot(H.shL, 0.3f, 0, -1.2f); Rot(H.shR, 0.3f, 0, 1.2f);
                Rot(H.neck, -0.5f);
            }
            else if (s == "dash")
            {
                Rot(H.spine, -0.6f, 0);
                Rot(H.shR, -0.6f, 0, 0.3f);
                Rot(H.hipL, 0.9f); Rot(H.knL, -0.3f); Rot(H.hipR, -0.8f); Rot(H.knR, -1.0f);
            }
            else if (s == "stagger")
            {
                Rot(H.spine, 0.5f, 0.2f);
                Rot(H.shL, -0.3f, 0, -0.9f); Rot(H.shR, -0.3f, 0, 0.9f);
                Rot(H.neck, -0.4f);
            }
            else if (s == "spawn") { Rot(H.spine, 0.1f); Rot(H.shR, 2.4f, 0, 0.3f); Rot(H.elR, 0.8f); }
            else
            {
                Rot(H.spine, -0.12f - amt * 0.2f, 0);
                WalkPose(amt, 0.6f, 0.15f);
                Rot(H.shR, 0.6f + Mathf.Sin(walkPhase) * 0.3f * amt, 0, 0.2f);
                Rot(H.elR, 0.8f);
                Rot(H.neck, 0.1f, 0);
                if (!grounded) AirPose();
            }
        }
    }
}
