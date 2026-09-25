// Düşmanlar: eklem hiyerarşili kutu modeller, prosedürel animasyon, durum makinesi.
// FILTH (yakın dövüş, parlayan atlayış), STRAY (savuşturulabilir küre), DRONE (uçan, iki küre),
// SWORDSMACHINE (boss: kılıç kombosu — son vuruş parlar ve PARRY'lenir, pompalı, öfke fazı).
// Ölüm: parçalanma (parçalar dünyaya savrulur) + kan; boss'ta ağır çekimli parça parça kopma sekansı.
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    // İnsansı iskelet: kalça → omurga → boyun/kafa, omuzlar → dirsekler, kalçalar → dizler
    public class UKBody
    {
        public Transform root, hips, spine, head, shL, shR, elL, elR, hipL, hipR, knL, knR, handR;
        public float hipY;

        public static UKBody Build(Transform parent, Material skin, Material dark, float hunch, float torsoW, float torsoH, float headS, float armL, float legL, float scale)
        {
            var b = new UKBody();
            b.root = new GameObject("body").transform;
            b.root.SetParent(parent, false);
            float thigh = 0.42f * legL, shin = 0.43f * legL;
            b.hipY = thigh + shin + 0.06f;
            b.hips = J(b.root, 0, b.hipY, 0);
            UKFx.Part(b.hips, Vector3.zero, new Vector3(torsoW * 0.8f, 0.2f, 0.24f), skin);
            b.spine = J(b.hips, 0, 0.06f, 0);
            b.spine.localRotation = Quaternion.Euler(hunch * Mathf.Rad2Deg, 0, 0);
            UKFx.Part(b.spine, new Vector3(0, torsoH * 0.22f, 0), new Vector3(torsoW * 0.8f, torsoH * 0.45f, 0.24f), skin);
            UKFx.Part(b.spine, new Vector3(0, torsoH * 0.7f, 0), new Vector3(torsoW, torsoH * 0.6f, 0.27f), skin);
            b.head = J(b.spine, 0, torsoH + 0.05f, 0);
            UKFx.Part(b.head, new Vector3(0, headS * 0.55f, 0), new Vector3(headS, headS * 1.1f, headS), skin);
            foreach (int side in new[] { -1, 1 })
            {
                var sh = J(b.spine, side * (torsoW / 2 + 0.07f), torsoH - 0.07f, 0);
                UKFx.Part(sh, new Vector3(0, -0.18f * armL, 0), new Vector3(0.11f, 0.36f * armL, 0.11f), skin);
                var el = J(sh, 0, -0.36f * armL, 0);
                UKFx.Part(el, new Vector3(0, -0.17f * armL, 0), new Vector3(0.095f, 0.34f * armL, 0.095f), skin);
                var ha = J(el, 0, -0.34f * armL, 0);
                UKFx.Part(ha, new Vector3(0, -0.05f, 0), new Vector3(0.11f, 0.13f, 0.11f), dark);
                var hip = J(b.hips, side * torsoW * 0.26f, -0.04f, 0);
                UKFx.Part(hip, new Vector3(0, -thigh / 2, 0), new Vector3(0.15f, thigh, 0.15f), skin);
                var kn = J(hip, 0, -thigh, 0);
                UKFx.Part(kn, new Vector3(0, -shin / 2, 0), new Vector3(0.12f, shin, 0.12f), skin);
                UKFx.Part(kn, new Vector3(0, -shin, 0.05f), new Vector3(0.13f, 0.07f, 0.24f), dark);
                if (side < 0) { b.shL = sh; b.elL = el; b.hipL = hip; b.knL = kn; }
                else { b.shR = sh; b.elR = el; b.hipR = hip; b.knR = kn; b.handR = ha; }
            }
            b.root.localScale = Vector3.one * scale;
            return b;
        }

        static Transform J(Transform parent, float x, float y, float z)
        {
            var t = new GameObject("j").transform;
            t.SetParent(parent, false);
            t.localPosition = new Vector3(x, y, z);
            return t;
        }
    }

    public abstract class UKEnemy : MonoBehaviour
    {
        public static readonly List<UKEnemy> All = new List<UKEnemy>();

        public string enemyName = "ENEMY";
        public float maxHp = 1, hp, radius = 0.4f, height = 1.9f, speed = 8, killPts = 60;
        public bool dead, big, boss, flying, parryable, enraged, invuln;
        public UKArena arena;
        public CharacterController cc;
        protected Transform model;
        protected UKBody B;
        protected Vector3 vel, knock;
        protected float yaw, st, atkCd = 1, time, flash, spawnT, stun = 0.9f, k;
        protected string state = "spawn";
        protected readonly List<Material> mats = new List<Material>();
        readonly List<Color> matBase = new List<Color>();
        bool glinted;
        float deathT = -1, nextPop;
        List<Transform> deathParts;

        public Vector3 Center => transform.position + Vector3.up * height * 0.55f;
        public string State => state;
        protected UKPlayer P => UKGame.I.player;

        public static T Spawn<T>(Vector3 pos, UKArena arena = null) where T : UKEnemy
        {
            var go = new GameObject(typeof(T).Name);
            go.transform.position = pos;
            var e = go.AddComponent<T>();
            e.arena = arena;
            e.Setup();
            return e;
        }

        protected Material M(Color c, float glow = 0.12f, Texture2D tex = null)
        {
            var m = new Material(UKFx.Lit(c, 0.001f, tex));
            m.EnableKeyword("_EMISSION");
            mats.Add(m);
            matBase.Add(c * glow);
            return m;
        }

        void Setup()
        {
            model = new GameObject("model").transform;
            model.SetParent(transform, false);
            Init();
            hp = maxHp;
            cc = gameObject.AddComponent<CharacterController>();
            cc.radius = radius;
            cc.height = height;
            cc.center = new Vector3(0, height / 2, 0);
            cc.stepOffset = Mathf.Min(0.5f, height * 0.3f);
            cc.skinWidth = 0.05f;
            var hb = gameObject.AddComponent<UKHitbox>();
            hb.owner = this;
            // kafa: tetik küre
            if (B != null)
            {
                var hc = new GameObject("headbox");
                hc.transform.SetParent(B.head, false);
                hc.transform.localPosition = new Vector3(0, 0.18f, 0);
                var sc = hc.AddComponent<SphereCollider>();
                sc.isTrigger = true;
                sc.radius = 0.26f;
                hc.AddComponent<UKHitbox>().owner = this;
                hc.GetComponent<UKHitbox>().head = true;
            }
            var p = UKGame.I.player;
            if (p) yaw = Mathf.Atan2(p.transform.position.x - transform.position.x, p.transform.position.z - transform.position.z) * Mathf.Rad2Deg;
            transform.rotation = Quaternion.Euler(0, yaw, 0);
            All.Add(this);
            UKFx.I.Ring(transform.position, new Color(0.6f, 0.85f, 1f), 2.5f, 0.6f);
            UKFx.I.Burst(Center, 20, 6, new Color(0.63f, 0.88f, 1f), 0.6f, 0.07f, -2);
            UKAudio.I.PlayAt("glint", transform.position, 0.5f, 0.6f);
        }

        protected abstract void Init();
        protected abstract void Think(float dt);
        protected virtual void Animate(float dt) { }
        protected virtual string FirstState => "chase";
        protected virtual float SpawnDur => 0.6f;

        void Update()
        {
            float dt = Time.deltaTime;
            if (deathT >= 0) { BossDeathTick(dt); return; }
            if (dead) return;
            time += dt;
            st += dt;
            flash = Mathf.Max(0, flash - dt * 6);
            if (state == "spawn")
            {
                spawnT += dt;
                float kk = Mathf.Clamp01(spawnT / SpawnDur);
                model.localScale = new Vector3(1 + (1 - kk) * 0.6f, 0.15f + 0.85f * kk * kk, 1 + (1 - kk) * 0.6f);
                flash = Mathf.Max(flash, 1 - kk);
                if (spawnT >= SpawnDur) { model.localScale = Vector3.one; SetState(FirstState); }
            }
            else if (state == "stagger") { Brake(20, dt); if (st > stun) SetState(FirstState); }
            else if (state == "flinch") { Brake(30, dt); if (st > 0.14f) SetState(FirstState); }
            else if (UKGame.I.state == UKGame.State.Playing && !P.dead) Think(dt);
            else Brake(20, dt);
            Physics_(dt);
            if (dead) return;
            transform.rotation = Quaternion.Euler(0, yaw, 0);
            k = 1 - Mathf.Exp(-16 * dt);
            Animate(dt);
            UpdateFlash();
        }

        protected void SetState(string s)
        {
            state = s;
            st = 0;
            if (s != "windup" && s != "attack" && s != "pounce" && s != "combo" && s != "lunge") SetParryable(false);
        }

        protected void SetParryable(bool on)
        {
            if (on && !parryable && !glinted)
            {
                glinted = true;
                var hp = B != null ? B.head.position + Vector3.up * 0.2f : Center;
                UKFx.I.Glow(hp, new Color(0.62f, 0.88f, 1f), 1.8f, 0.4f, 1.7f);
                UKAudio.I.PlayAt("glint", transform.position);
            }
            if (!on) glinted = false;
            parryable = on;
        }

        protected void Physics_(float dt)
        {
            if (!flying) vel.y -= 35 * dt;
            vel.y = Mathf.Max(vel.y, -80);
            var flags = cc.Move((vel + knock) * dt);
            if ((flags & CollisionFlags.Below) != 0 && vel.y < 0) vel.y = -1;
            knock *= Mathf.Exp(-dt * (cc.isGrounded ? 7 : 1.5f));
            if (transform.position.y < UKGame.I.level.killY) { Die(99, "pit", false, Vector3.zero, true); return; }
            if (UKGame.I.level.InLava(transform.position) && !flying)
            {
                vel.y = 12;
                Hit(maxHp * 0.25f + 0.3f, Center, Vector3.up, false, "lava", 0, 1, true);
            }
        }

        protected void Brake(float a, float dt) { vel.x = Mathf.MoveTowards(vel.x, 0, a * dt); vel.z = Mathf.MoveTowards(vel.z, 0, a * dt); }

        protected void AccelTo(Vector3 target, float a, float dt)
        {
            var h = new Vector3(vel.x, 0, vel.z);
            h = Vector3.MoveTowards(h, new Vector3(target.x, 0, target.z), a * dt);
            vel.x = h.x; vel.z = h.z;
        }

        protected Vector3 ToPlayer(out float dist)
        {
            var d = P.transform.position - transform.position;
            d.y = 0;
            dist = d.magnitude;
            return dist > 0.001f ? d / dist : Vector3.forward;
        }

        protected void Face(Vector3 dir, float rate, float dt)
        {
            float t = Mathf.Atan2(dir.x, dir.z) * Mathf.Rad2Deg;
            yaw = Mathf.LerpAngle(yaw, t, Mathf.Min(1, rate * dt));
        }

        protected Vector3 Forward => Quaternion.Euler(0, yaw, 0) * Vector3.forward;

        protected bool CanSee()
        {
            Vector3 a = transform.position + Vector3.up * height * 0.85f, b = P.EyePos;
            var hits = Physics.RaycastAll(a, (b - a).normalized, Vector3.Distance(a, b), ~0, QueryTriggerInteraction.Ignore);
            foreach (var h in hits) if (h.collider != P.cc && h.collider.GetComponent<UKHitbox>() == null) return false;
            return true;
        }

        protected bool GroundAhead(Vector3 dir, float dist = 1.2f)
        {
            Vector3 o = transform.position + dir * dist + Vector3.up * 0.5f;
            return Physics.Raycast(o, Vector3.down, 2.2f, ~0, QueryTriggerInteraction.Ignore);
        }

        // Yakın saldırı: önde parlak kavis + ses; menzilde ve öndeyse hasar
        protected bool MeleeHit(float range, float dmg, float arc = 0.2f)
        {
            var f = Forward;
            var c = Center + f * Mathf.Min(1.4f, range * 0.4f);
            UKFx.I.Glow(c, new Color(1f, 0.88f, 0.75f, 0.7f), Mathf.Min(3.2f, range * 0.8f), 0.18f, 1.3f);
            UKAudio.I.PlayAt("meleeWhoosh", transform.position, 1, big ? 0.75f : 1.1f);
            var d = ToPlayer(out float dist);
            float dy = P.transform.position.y - transform.position.y;
            if (dist > range || Mathf.Abs(dy + 0.5f) > 2.6f) return false;
            if (Vector3.Dot(f, d) < arc) return false;
            bool ok = UKGame.I.DamagePlayer(dmg * UKGame.I.Diff.dmg, Center, false);
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

        protected void Throw(Transform from, float speed, float dmg, Color col, float lead = 0.4f, float r = 0.35f)
        {
            Vector3 o = from.position;
            Vector3 target = P.transform.position + Vector3.up * 1.1f;
            float t = Vector3.Distance(o, target) / speed;
            target += P.vel * t * lead;
            UKProjectile.Spawn(UKProjectile.Kind.Orb, o, (target - o).normalized * speed, false, dmg * UKGame.I.Diff.dmg, col, this, r);
            UKAudio.I.PlayAt("orbThrow", o);
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
        public void Hit(float dmg, Vector3 point, Vector3 dir, bool head, string weapon, float knockF, float headMult = 2f, bool quiet = false, bool parried = false)
        {
            if (dead || state == "spawn" && spawnT < 0.15f) return;
            if (invuln) { UKFx.I.Burst(point, 6, 6, Color.white, 0.2f, 0.05f); UKAudio.I.PlayAt("empty", point); return; }
            if (head) dmg *= headMult;
            bool wasFull = hp >= maxHp - 0.001f;
            hp -= dmg;
            flash = 1;
            var game = UKGame.I;
            if (dir != Vector3.zero && knockF > 0)
            {
                float km = big ? 0.25f : 1f;
                knock += new Vector3(dir.x, 0, dir.z) * knockF * km;
                if (dir.y > 0.3f) vel.y = Mathf.Max(vel.y, knockF * 0.6f * km);
            }
            UKFx.I.Blood(point, Mathf.Min(45, 6 + Mathf.RoundToInt(dmg * 10)), 5 + Mathf.Min(dmg, 4) * 2, dir);
            if (!quiet)
            {
                UKFx.I.Glow(point, head ? new Color(1f, 0.88f, 0.4f) : Color.white, head ? 1.1f : 0.6f, 0.07f, 1.8f);
                UKAudio.I.Play("hitTick", 1, head ? 1.3f : 1);
                UKAudio.I.PlayAt(head ? "headshot" : "enemyHit", point);
            }
            if (weapon != "lava") game.BloodHeal(point, dmg);
            game.style.AddRaw(Mathf.Min(dmg, 6) * 18, weapon);
            if (!cc.isGrounded && !flying && state != "spawn" && weapon != "lava") game.style.Add("AIRSHOT", 35, weapon);
            game.hud.Hitmarker(hp <= 0);
            if (hp <= 0) { Die(dmg, weapon, head, dir, false, wasFull); return; }
            if (!big && !quiet && dmg >= 0.9f && state != "stagger" && state != "flinch")
            {
                if (parryable) game.style.Add("INTERRUPTION", 50, weapon);
                SetState("flinch");
            }
        }

        public void Parried(Vector3 dir)
        {
            parryable = false;
            Hit(big ? 5f : 4f, Center, dir, false, "parry", 16);
            if (!dead) { stun = big ? 1.5f : 0.9f; SetState("stagger"); }
        }

        protected virtual void Die(float dmg, string weapon, bool head, Vector3 dir, bool silent, bool wasFull = false)
        {
            if (dead) return;
            dead = true;
            parryable = false;
            All.Remove(this);
            var game = UKGame.I;
            Vector3 c = Center;
            cc.enabled = false;
            foreach (var h in GetComponentsInChildren<Collider>()) h.enabled = false;
            if (boss && !silent && dmg < 99)
            {
                // boss: ağır çekim + parça parça kopma
                deathT = 0;
                nextPop = 0.12f;
                deathParts = new List<Transform>();
                foreach (var mr in model.GetComponentsInChildren<MeshRenderer>()) deathParts.Add(mr.transform);
                for (int i = deathParts.Count - 1; i > 0; i--) { int j = Random.Range(0, i + 1); var t = deathParts[i]; deathParts[i] = deathParts[j]; deathParts[j] = t; }
                game.SlowMo(1.1f, 0.28f);
                game.Hitstop(0.2f);
                game.hud.Flash(new Color(1, 1, 1, 0.9f), 0.35f);
                P.Shake(0.7f);
                UKAudio.I.Play("bossDeath");
                UKFx.I.Blood(c, 60, 10, dir);
            }
            else
            {
                float force = 5 + Mathf.Min(dmg, 10) * 1.5f;
                foreach (var mr in model.GetComponentsInChildren<MeshRenderer>())
                    UKFx.I.GibFromPart(mr.transform, (new Vector3(Random.Range(-1f, 1f), Random.Range(0.3f, 1.4f), Random.Range(-1f, 1f)) * force * Random.Range(0.4f, 1f)) + dir * force * 0.8f);
                for (int i = 0; i < (big ? 12 : 6); i++) UKFx.I.Gib(c + Random.insideUnitSphere * 0.3f, new Vector3(Random.Range(-6f, 6f), Random.Range(3f, 9f), Random.Range(-6f, 6f)), Random.Range(0.08f, 0.2f));
                UKFx.I.Blood(c, big ? 110 : 60, big ? 15 : 11);
                Destroy(gameObject);
            }
            if (!silent)
            {
                UKAudio.I.PlayAt("gore", c);
                game.BloodHeal(c, big ? 3 : 1.5f);
                game.style.Add(big ? "BIG KILL" : null, killPts, weapon);
                if (head) game.style.Add(big ? "BIG HEADSHOT" : "HEADSHOT", big ? 120 : 60, weapon);
                if (weapon == "punch") game.style.Add("SPLATTERED", 60, null);
                if (weapon == "parry") game.style.Add("PARRIED KILL", 80, null);
                if (wasFull && big && dmg >= maxHp) game.style.Add("INSTAKILL", 100, weapon);
                game.style.OnKill(weapon);
            }
            game.OnEnemyKilled(this);
            OnDied();
        }

        protected virtual void OnDied() { }

        void BossDeathTick(float dt)
        {
            deathT += dt;
            float j = 0.04f + deathT * 0.05f;
            model.localPosition = new Vector3(Random.Range(-j, j), Random.Range(-j, j) * 0.5f, Random.Range(-j, j));
            float pulse = 0.5f + 0.5f * Mathf.Sin(deathT * 38);
            foreach (var m in mats) m.SetColor("_EmissionColor", new Color(0.6f + 0.4f * pulse, 0.12f * pulse, 0.08f * pulse));
            if (deathT >= nextPop && deathT < 1.6f && deathParts.Count > 0)
            {
                nextPop = deathT + Mathf.Max(0.07f, 0.16f - deathT * 0.05f);
                var t = deathParts[deathParts.Count - 1];
                deathParts.RemoveAt(deathParts.Count - 1);
                if (t)
                {
                    Vector3 v = (t.position - Center); v.y = 0;
                    v = v.normalized * Random.Range(4f, 8f) + Vector3.up * Random.Range(4f, 9f);
                    UKFx.I.GibFromPart(t, v);
                    UKFx.I.Blood(t.position, 18, 8, v);
                    UKFx.I.Burst(t.position, 10, 8, new Color(1f, 0.75f, 0.38f), 0.35f, 0.06f);
                    UKAudio.I.PlayAt("gore", t.position, 1, Random.Range(0.8f, 1.2f));
                    t.gameObject.SetActive(false);
                    P.Shake(0.25f);
                }
            }
            if (deathT >= 1.7f)
            {
                Vector3 c = Center;
                foreach (var t in deathParts)
                    if (t && t.gameObject.activeInHierarchy) UKFx.I.GibFromPart(t, new Vector3(Random.Range(-1f, 1f), Random.Range(0.4f, 1.4f), Random.Range(-1f, 1f)) * Random.Range(8f, 16f));
                for (int i = 0; i < 16; i++) UKFx.I.Gib(c + Random.insideUnitSphere * 0.5f, new Vector3(Random.Range(-9f, 9f), Random.Range(4f, 13f), Random.Range(-9f, 9f)), Random.Range(0.1f, 0.25f));
                UKFx.I.Explosion(c, 5);
                UKFx.I.Blood(c, 160, 16);
                UKFx.I.Decal(transform.position + Vector3.up * 0.02f, Vector3.up, 5);
                UKAudio.I.Play("explosion", 1, 0.7f);
                UKGame.I.hud.Flash(new Color(1, 0.16f, 0.08f, 0.6f), 0.4f);
                P.Shake(0.9f);
                Destroy(gameObject);
                deathT = -1;
            }
        }

        // yere çakma sarsıntısı: havaya fırlat
        public void Launch(float vy) { vel.y = vy; }

        public void RemoveSilently()
        {
            All.Remove(this);
            dead = true;
            Destroy(gameObject);
        }

        // ------------------------------------------------------------ animasyon yardımcıları
        protected void Rot(Transform j, float x, float y = 0, float z = 0)
        {
            var target = Quaternion.Euler(x * Mathf.Rad2Deg, y * Mathf.Rad2Deg, z * Mathf.Rad2Deg);
            j.localRotation = Quaternion.Slerp(j.localRotation, target, k);
        }

        protected float walkPhase;

        protected void WalkPose(float amt, float armSwing = 1, float armBase = 0)
        {
            float s = Mathf.Sin(walkPhase), c = Mathf.Cos(walkPhase);
            Rot(B.hipL, s * 0.75f * amt); Rot(B.hipR, -s * 0.75f * amt);
            Rot(B.knL, Mathf.Max(0, c) * 1.2f * amt + 0.05f); Rot(B.knR, Mathf.Max(0, -c) * 1.2f * amt + 0.05f);
            Rot(B.shL, armBase - s * 0.6f * amt * armSwing, 0, -0.08f); Rot(B.shR, armBase + s * 0.6f * amt * armSwing, 0, 0.08f);
            Rot(B.elL, -0.35f - 0.3f * amt); Rot(B.elR, -0.35f - 0.3f * amt);
            B.hips.localPosition = new Vector3(0, B.hipY + Mathf.Abs(c) * 0.06f * amt - 0.03f * amt, 0);
        }
    }

    // ------------------------------------------------------------------ FILTH
    public class UKFilth : UKEnemy
    {
        float pounceCd;
        bool hitDone;
        protected override void Init()
        {
            enemyName = "FILTH"; maxHp = 0.6f; radius = 0.4f; height = 1.55f; speed = 10.5f * UKGame.I.Diff.speed; killPts = 50;
            pounceCd = Random.Range(1f, 3f);
            B = UKBody.Build(model, M(new Color(0.62f, 0.78f, 0.47f), 0.12f, UKFx.TexNoise), M(new Color(0.35f, 0.23f, 0.16f)), 0.62f, 0.42f, 0.52f, 0.3f, 1.35f, 0.95f, 1f);
            var bone = M(new Color(1f, 0.94f, 0.82f));
            for (int i = 0; i < 4; i++) UKFx.Part(B.spine, new Vector3(0, 0.1f + i * 0.08f, 0.14f), new Vector3(0.36f, 0.03f, 0.02f), bone);
            var black = UKFx.Unlit(new Color(0.06f, 0.02f, 0.02f));
            UKFx.Part(B.head, new Vector3(-0.075f, 0.22f, 0.155f), new Vector3(0.07f, 0.06f, 0.02f), black);
            UKFx.Part(B.head, new Vector3(0.075f, 0.22f, 0.155f), new Vector3(0.07f, 0.06f, 0.02f), black);
            UKFx.Part(B.head, new Vector3(0, 0.1f, 0.155f), new Vector3(0.22f, 0.12f, 0.02f), black);
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist);
            float aggro = UKGame.I.Diff.aggro;
            atkCd -= dt; pounceCd -= dt;
            switch (state)
            {
                case "chase":
                    Face(d, 10, dt);
                    Vector3 tv = d * speed;
                    if (cc.isGrounded && !GroundAhead(d)) tv = Vector3.zero;
                    AccelTo(tv, 40, dt);
                    if (dist < 2.6f && atkCd <= 0) SetState("windup");
                    else if (dist > 5 && dist < 12 && pounceCd <= 0 && cc.isGrounded) SetState("pounceWind");
                    break;
                case "pounceWind":
                    Face(d, 14, dt); Brake(40, dt);
                    if (st > 0.3f / aggro)
                    {
                        state = "pounce"; st = 0; hitDone = false;
                        float s = Mathf.Min(16, dist * 1.9f);
                        vel = new Vector3(d.x * s, 8.5f, d.z * s);
                        pounceCd = Random.Range(3f, 5f) / aggro;
                        SetParryable(true);
                    }
                    break;
                case "pounce":
                    if (st > 0.35f) SetParryable(false);
                    if (!hitDone && dist < 1.8f && MeleeHit(2.2f, 18, -0.2f)) hitDone = true;
                    if (st > 1.2f || (st > 0.3f && cc.isGrounded)) SetState("recover");
                    break;
                case "windup":
                    Face(d, 12, dt); Brake(40, dt);
                    float dur = 0.5f / aggro;
                    if (st > dur - 0.24f) SetParryable(true);
                    if (st >= dur) { state = "attack"; st = 0; hitDone = false; var f = Forward; vel.x = f.x * 9; vel.z = f.z * 9; }
                    break;
                case "attack":
                    if (st > 0.12f) SetParryable(false);
                    if (!hitDone && st > 0.08f) { MeleeHit(2.9f, 20, 0.25f); hitDone = true; }
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
            float hsp = new Vector2(vel.x, vel.z).magnitude;
            walkPhase += hsp * dt * 1.5f;
            float amt = Mathf.Clamp01(hsp / 8);
            if (state == "windup") { WalkPose(0); Rot(B.spine, 0.2f); Rot(B.shL, -2.2f); Rot(B.shR, -2.2f); }
            else if (state == "attack") { Rot(B.spine, 0.9f); Rot(B.shL, -1.2f); Rot(B.shR, -1.2f); }
            else if (state == "pounce") { Rot(B.hipL, -0.9f); Rot(B.hipR, -0.4f); Rot(B.shL, -2.6f); Rot(B.shR, -2.6f); }
            else { WalkPose(amt, 1.2f, 0.3f); Rot(B.spine, 0.62f); }
        }
    }

    // ------------------------------------------------------------------ STRAY
    public class UKStray : UKEnemy
    {
        float strafeT, strafeDir = 1;
        Transform orb;
        bool thrown;
        protected override string FirstState => "move";
        protected override void Init()
        {
            enemyName = "STRAY"; maxHp = 2; radius = 0.4f; height = 1.95f; speed = 6.5f * UKGame.I.Diff.speed; killPts = 70;
            strafeT = Random.Range(1f, 2.5f); strafeDir = Random.value < 0.5f ? 1 : -1; atkCd = Random.Range(1f, 2.2f);
            var cloth = M(new Color(0.85f, 0.35f, 0.11f));
            B = UKBody.Build(model, M(new Color(0.88f, 0.66f, 0.51f)), M(new Color(0.29f, 0.16f, 0.11f)), 0.22f, 0.36f, 0.58f, 0.27f, 1.08f, 1.1f, 1.05f);
            UKFx.Part(B.head, new Vector3(0, 0.3f, -0.03f), new Vector3(0.36f, 0.42f, 0.36f), cloth);
            UKFx.Part(B.spine, new Vector3(0, 0.33f, -0.18f), new Vector3(0.44f, 0.52f, 0.04f), cloth);
            var eyeM = UKFx.Unlit(new Color(1f, 0.7f, 0.25f));
            UKFx.Part(B.head, new Vector3(-0.065f, 0.18f, 0.16f), new Vector3(0.05f, 0.035f, 0.02f), eyeM);
            UKFx.Part(B.head, new Vector3(0.065f, 0.18f, 0.16f), new Vector3(0.05f, 0.035f, 0.02f), eyeM);
            orb = UKFx.Part(B.handR, new Vector3(0, -0.14f, 0), Vector3.one * 0.3f, UKFx.Unlit(new Color(1f, 0.85f, 0.5f))).transform;
            orb.gameObject.SetActive(false);
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist);
            float aggro = UKGame.I.Diff.aggro;
            atkCd -= dt;
            switch (state)
            {
                case "move":
                    Face(d, 8, dt);
                    strafeT -= dt;
                    if (strafeT <= 0) { strafeT = Random.Range(1.2f, 2.8f); strafeDir *= -1; }
                    float want = dist > 26 ? 1 : dist < 11 ? -1 : 0;
                    Vector3 side = new Vector3(-d.z, 0, d.x) * strafeDir;
                    Vector3 tv = (d * want + side * 0.55f) * speed;
                    if (tv.sqrMagnitude > 0.01f && cc.isGrounded && !GroundAhead(tv.normalized)) { tv = Vector3.zero; strafeDir *= -1; }
                    AccelTo(tv, 30, dt);
                    if (atkCd <= 0 && dist < 50 && CanSee()) { SetState("windup"); UKAudio.I.PlayAt("orbCharge", transform.position); }
                    break;
                case "windup":
                    Face(d, 10, dt); Brake(25, dt);
                    float dur = 0.95f / aggro;
                    orb.gameObject.SetActive(true);
                    orb.localScale = Vector3.one * (0.1f + 0.3f * Mathf.Clamp01(st / dur));
                    if (st >= dur) { state = "throw"; st = 0; thrown = false; }
                    break;
                case "throw":
                    if (!thrown && st > 0.1f) { thrown = true; orb.gameObject.SetActive(false); Throw(orb, 27 * UKGame.I.Diff.speed, 25, new Color(1f, 0.54f, 0.13f)); }
                    if (st > 0.45f) { SetState("move"); atkCd = Random.Range(1.9f, 3.2f) / aggro; }
                    break;
            }
            if (state != "windup" && state != "throw" && orb.gameObject.activeSelf) orb.gameObject.SetActive(false);
        }

        protected override void Animate(float dt)
        {
            float hsp = new Vector2(vel.x, vel.z).magnitude;
            walkPhase += hsp * dt * 1.4f;
            float amt = Mathf.Clamp01(hsp / 6);
            if (state == "windup") { WalkPose(0); Rot(B.spine, 0.05f, 0.4f); Rot(B.shR, -2.5f, 0, 0.3f); Rot(B.elR, -0.9f); }
            else if (state == "throw") { Rot(B.spine, 0.45f, -0.35f); Rot(B.shR, -1.5f); Rot(B.elR, -0.1f); }
            else { Rot(B.spine, 0.22f); WalkPose(amt, 0.8f, 0.1f); }
        }
    }

    // ------------------------------------------------------------------ DRONE
    public class UKDrone : UKEnemy
    {
        float orbitT, orbitDir = 1, alt = 4, shots;
        Transform muzzle, body;
        Material eyeM;
        protected override string FirstState => "fly";
        protected override void Init()
        {
            enemyName = "DRONE"; maxHp = 1.2f; radius = 0.5f; height = 0.9f; speed = 7 * UKGame.I.Diff.speed; killPts = 60; flying = true;
            orbitT = Random.Range(2f, 4f); orbitDir = Random.value < 0.5f ? 1 : -1; atkCd = Random.Range(1.2f, 2.6f);
            var shell = M(new Color(0.72f, 0.75f, 0.8f), 0.12f, UKFx.TexMetal);
            var dark = M(new Color(0.23f, 0.24f, 0.28f));
            body = new GameObject("drone").transform;
            body.SetParent(model, false);
            body.localPosition = new Vector3(0, 0.45f, 0);
            UKFx.Part(body, Vector3.zero, new Vector3(0.72f, 0.5f, 0.72f), shell);
            UKFx.Part(body, new Vector3(0, 0.32f, 0), new Vector3(0.5f, 0.18f, 0.5f), dark);
            UKFx.Part(body, new Vector3(-0.5f, 0, 0), new Vector3(0.3f, 0.05f, 0.5f), dark);
            UKFx.Part(body, new Vector3(0.5f, 0, 0), new Vector3(0.3f, 0.05f, 0.5f), dark);
            eyeM = M(new Color(0.25f, 0.63f, 1f), 1.2f);
            UKFx.Part(body, new Vector3(0, 0.02f, 0.38f), new Vector3(0.3f, 0.2f, 0.06f), eyeM);
            muzzle = new GameObject("muzzle").transform;
            muzzle.SetParent(body, false);
            muzzle.localPosition = new Vector3(0, 0, 0.55f);
            // uçan düşmanda kafa kutusu: göz
            var hc = new GameObject("headbox");
            hc.transform.SetParent(body, false);
            hc.transform.localPosition = new Vector3(0, 0.02f, 0.36f);
            var sc = hc.AddComponent<SphereCollider>();
            sc.isTrigger = true; sc.radius = 0.2f;
            var hb = hc.AddComponent<UKHitbox>(); hb.owner = this; hb.head = true;
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist);
            float aggro = UKGame.I.Diff.aggro;
            atkCd -= dt;
            float wantY = P.transform.position.y + alt + Mathf.Sin(time * 2.1f) * 0.5f;
            vel.y = Mathf.Clamp((wantY - transform.position.y) * 2.5f, -7, 7);
            switch (state)
            {
                case "fly":
                    Face(d, 5, dt);
                    orbitT -= dt;
                    if (orbitT <= 0) { orbitT = Random.Range(2f, 4f); orbitDir *= -1; alt = Random.Range(2.5f, 5.5f); }
                    float want = dist > 18 ? 1 : dist < 9 ? -1 : 0;
                    Vector3 side = new Vector3(-d.z, 0, d.x) * orbitDir;
                    AccelTo((d * want + side * 0.8f) * speed, 10, dt);
                    if (atkCd <= 0 && dist < 45 && CanSee()) { SetState("charge"); UKAudio.I.PlayAt("orbCharge", transform.position, 1, 1.6f); }
                    break;
                case "charge":
                    Face(d, 8, dt); Brake(12, dt);
                    if (st >= 0.6f / aggro) { state = "shoot"; st = 0; shots = 0; }
                    break;
                case "shoot":
                    Face(d, 8, dt);
                    while (shots < 2 && st >= shots * 0.16f) { Throw(muzzle, 30 * UKGame.I.Diff.speed, 15, new Color(0.23f, 0.54f, 1f), 0.3f, 0.28f); shots++; }
                    if (st > 0.4f) { SetState("fly"); atkCd = Random.Range(2f, 3.4f) / aggro; }
                    break;
            }
        }

        protected override void Animate(float dt)
        {
            body.localRotation = Quaternion.Euler(Mathf.Clamp(new Vector2(vel.x, vel.z).magnitude * 1.2f, 0, 18), 0, Mathf.Sin(time * 3) * 3);
            bool ch = state == "charge" || state == "shoot";
            eyeM.SetColor("_EmissionColor", ch && Mathf.Sin(time * 40) > 0 ? Color.white * 1.5f : new Color(0.25f, 0.63f, 1f) * 1.2f);
        }

        protected override void OnDied()
        {
            // düşüp patlar
            UKGame.I.Explode(Center, 3.2f, 1.5f, true, 0);
        }
    }

    // ------------------------------------------------------------------ SWORDSMACHINE (boss)
    public class UKSwordsmachine : UKEnemy
    {
        int combo;
        bool hitDone, fired;
        Transform sword, gun;
        protected override float SpawnDur => 0.9f;
        protected override void Init()
        {
            enemyName = "SWORDSMACHINE"; maxHp = 40; radius = 0.6f; height = 2.55f; speed = 9.5f * UKGame.I.Diff.speed; killPts = 400; big = true; boss = true;
            atkCd = 1;
            var metal = M(new Color(0.78f, 0.82f, 0.86f), 0.1f, UKFx.TexMetal);
            var dark = M(new Color(0.23f, 0.24f, 0.3f));
            var plate = M(new Color(1f, 0.7f, 0.13f), 0.18f, UKFx.TexMetal);
            B = UKBody.Build(model, metal, dark, 0.1f, 0.58f, 0.64f, 0.3f, 1.08f, 1.08f, 1.32f);
            var orange = UKFx.Unlit(new Color(1f, 0.63f, 0.13f));
            UKFx.Part(B.head, new Vector3(0, 0.2f, 0.16f), new Vector3(0.28f, 0.06f, 0.02f), orange);
            UKFx.Part(B.head, new Vector3(0, 0.34f, 0), new Vector3(0.32f, 0.08f, 0.34f), plate);
            UKFx.Part(B.spine, new Vector3(0, 0.42f, 0.18f), new Vector3(0.18f, 0.18f, 0.04f), orange);
            UKFx.Part(B.spine, new Vector3(-0.16f, 0.5f, 0.17f), new Vector3(0.26f, 0.24f, 0.05f), plate);
            UKFx.Part(B.spine, new Vector3(0.16f, 0.5f, 0.17f), new Vector3(0.26f, 0.24f, 0.05f), plate);
            UKFx.Part(B.shL, new Vector3(0, 0.04f, 0), new Vector3(0.26f, 0.14f, 0.32f), plate);
            UKFx.Part(B.shR, new Vector3(0, 0.04f, 0), new Vector3(0.26f, 0.14f, 0.32f), plate);
            sword = new GameObject("sword").transform;
            sword.SetParent(B.handR, false);
            sword.localPosition = new Vector3(0, -0.06f, 0);
            sword.localRotation = Quaternion.Euler(90, 0, 0);
            UKFx.Part(sword, new Vector3(0, -0.06f, 0), new Vector3(0.06f, 0.22f, 0.06f), dark);
            UKFx.Part(sword, new Vector3(0, -0.9f, 0), new Vector3(0.05f, 1.4f, 0.2f), M(new Color(0.8f, 0.8f, 0.84f), 0.1f, UKFx.TexMetal));
            UKFx.Part(sword, new Vector3(0, -0.9f, 0.11f), new Vector3(0.055f, 1.35f, 0.025f), orange);
            gun = new GameObject("gun").transform;
            gun.SetParent(B.elL, false);
            gun.localPosition = new Vector3(0, -0.4f, 0.05f);
            UKFx.Part(gun, new Vector3(0, -0.2f, 0), new Vector3(0.12f, 0.5f, 0.14f), dark);
            gun.gameObject.SetActive(false);
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist);
            float aggro = UKGame.I.Diff.aggro * (enraged ? 1.35f : 1);
            atkCd -= dt;
            if (!enraged && hp < maxHp * 0.5f && state == "chase")
            {
                enraged = true;
                speed *= 1.25f;
                UKAudio.I.Play("bossRoar");
                UKGame.I.hud.Message("SWORDSMACHINE ÖFKELENDİ", 1.4f);
                UKGame.I.style.Add("ENRAGED", 50, null);
            }
            switch (state)
            {
                case "chase":
                    Face(d, 6, dt);
                    AccelTo(d * (dist > 3 ? speed : 0), 30, dt);
                    if (atkCd <= 0)
                    {
                        if (dist < 4.5f) { combo = 0; SetState("combo"); }
                        else if (dist > 9 && Random.value < 0.45f && CanSee()) { SetState("gunWind"); fired = false; }
                        else if (dist > 6) { SetState("lungeWind"); UKAudio.I.PlayAt("windup", transform.position, 1, 0.7f); }
                        else atkCd = 0.3f;
                    }
                    break;
                case "combo":
                    {
                        // 3 vuruş; sonuncusu parlar (PARRY edilebilir)
                        Face(d, 5, dt);
                        float wind = (combo == 2 ? 0.55f : 0.35f) / aggro;
                        if (combo == 2) SetParryable(st > wind - 0.35f && st < wind + 0.08f);
                        if (st < wind) Brake(30, dt);
                        if (!hitDone && st >= wind)
                        {
                            hitDone = true;
                            var f = Forward; vel.x = f.x * 7; vel.z = f.z * 7;
                            UKAudio.I.PlayAt("swing", transform.position);
                            MeleeHit(4.2f, 20, 0.1f);
                        }
                        if (st > wind + 0.28f)
                        {
                            hitDone = false;
                            combo++;
                            st = 0;
                            SetParryable(false);
                            if (combo >= 3) { SetState("recover"); atkCd = Random.Range(0.8f, 1.4f) / aggro; }
                        }
                        break;
                    }
                case "gunWind":
                    Face(d, 8, dt); Brake(30, dt);
                    gun.gameObject.SetActive(true);
                    if (!fired && st > 0.5f / aggro)
                    {
                        fired = true;
                        Vector3 o = gun.position + Vector3.up * 0.1f;
                        Vector3 aim = (P.transform.position + Vector3.up * 1f - o).normalized;
                        for (int i = 0; i < 8; i++) UKProjectile.Spawn(UKProjectile.Kind.Bullet, o, (aim + Random.insideUnitSphere * 0.1f).normalized * 55, false, 7 * UKGame.I.Diff.dmg, new Color(1f, 0.7f, 0.25f), this);
                        UKAudio.I.PlayAt("shotgun", o, 1, 0.8f);
                        UKFx.I.Glow(o, new Color(1f, 0.8f, 0.5f), 1.4f, 0.1f);
                    }
                    if (st > 0.9f) { gun.gameObject.SetActive(false); SetState("recover"); atkCd = Random.Range(1f, 1.6f) / aggro; }
                    break;
                case "lungeWind":
                    Face(d, 10, dt); Brake(30, dt);
                    if (st > 0.45f / aggro) { SetState("lunge"); hitDone = false; vel.x = d.x * 26; vel.z = d.z * 26; UKAudio.I.PlayAt("dash", transform.position, 1, 0.7f); }
                    break;
                case "lunge":
                    if (!hitDone && dist < 2.8f) { hitDone = true; MeleeHit(3.2f, 25, 0); }
                    if (st > 0.45f) { SetState("recover"); atkCd = Random.Range(0.6f, 1.2f) / aggro; }
                    break;
                case "recover":
                    Brake(30, dt);
                    if (st > 0.45f) SetState("chase");
                    break;
            }
        }

        protected override void Animate(float dt)
        {
            float hsp = new Vector2(vel.x, vel.z).magnitude;
            walkPhase += hsp * dt * 1.1f;
            float amt = Mathf.Clamp01(hsp / 8);
            WalkPose(amt, 0.5f, 0);
            if (state == "combo")
            {
                float wind = combo == 2 ? 0.55f : 0.35f;
                bool pre = st < wind;
                float side = combo % 2 == 0 ? 1 : -1;
                Rot(B.spine, 0.1f, pre ? 0.6f * side : -0.7f * side);
                Rot(B.shR, pre ? -2.4f : -0.6f, 0, pre ? 0.6f * side : -0.3f * side);
                Rot(B.elR, pre ? -1.2f : -0.2f);
            }
            else if (state == "gunWind") { Rot(B.shL, -1.5f); Rot(B.elL, -0.1f); }
            else if (state == "lungeWind") { Rot(B.spine, 0.45f); Rot(B.shR, -2.8f); }
            else if (state == "lunge") { Rot(B.spine, 0.3f); Rot(B.shR, -1.2f); }
            else if (state == "stagger") { Rot(B.spine, -0.3f); Rot(B.shL, -0.5f, 0, -0.6f); Rot(B.shR, -0.5f, 0, 0.6f); }
            else { Rot(B.spine, 0.1f); Rot(B.shR, -0.5f, 0, 0.15f); Rot(B.elR, -0.9f); }
        }
    }
}
