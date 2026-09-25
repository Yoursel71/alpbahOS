// Mermiler (web: projectiles.js): düşman küreleri/saçmaları (savuşturulabilir), boss kılıcı (bumerang),
// dalan drone gövdesi, oyuncu mermileri (çekirdek bombası, roket, gülle, çivi, testere diski, zincirli
// testere, mıknatıs), Marksman bozuk paraları ve Cerberus/Hideous Mass sarsıntı dalgası.
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKProjectile : MonoBehaviour
    {
        public enum Kind { Orb, Nail, Core, Bullet, Rocket, Cannonball, Saw, Chainsaw, Magnet, Sword, Drone }
        public static readonly List<UKProjectile> All = new List<UKProjectile>();

        public Kind kind;
        public Vector3 vel;
        public float radius = 0.3f, damage = 20, life = 6, gravity, age, homeRate = 5;
        public bool fromPlayer, parryable = true, parried, dead, explosive, heated, boosted;
        public int bounces;
        public UKEnemy source, homeTarget, stuckTo;
        public Color color;
        Transform glow, mesh;
        Material glowMat;
        Vector3 prev, stuckOff;
        bool stuck, back, hitPlayerOnce;
        float outT;
        readonly Dictionary<UKEnemy, float> hitCd = new Dictionary<UKEnemy, float>();

        static UKPlayer P => UKGame.I.player;

        public static UKProjectile Spawn(Kind kind, Vector3 pos, Vector3 vel, bool fromPlayer, float damage, Color color, UKEnemy source = null, float radius = -1, Transform adopt = null, bool heated = false)
        {
            var go = new GameObject("proj_" + kind);
            go.transform.position = pos;
            var p = go.AddComponent<UKProjectile>();
            p.kind = kind;
            p.vel = vel;
            p.prev = pos;
            p.fromPlayer = fromPlayer;
            p.damage = damage;
            p.color = color;
            p.source = source;
            p.heated = heated;
            p.parryable = kind == Kind.Orb || kind == Kind.Drone;
            switch (kind)
            {
                case Kind.Nail: p.radius = 0.12f; p.gravity = 2.5f; p.life = 1.6f; break;
                case Kind.Core: p.radius = 0.22f; p.gravity = 20f; p.life = 3f; break;
                case Kind.Bullet: p.radius = 0.2f; p.life = 2f; break;
                case Kind.Rocket: p.radius = 0.18f; p.life = 5f; break;
                case Kind.Cannonball: p.radius = 0.4f; p.gravity = 16; p.life = 4; break;
                case Kind.Saw: p.radius = 0.28f; p.gravity = 1; p.life = 3; p.bounces = 3; break;
                case Kind.Chainsaw: p.radius = 0.4f; p.life = 6; break;
                case Kind.Magnet: p.radius = 0.15f; p.life = 8; break;
                case Kind.Sword: p.radius = 0.6f; p.life = 8; break;
                case Kind.Drone: p.radius = 0.5f; p.gravity = 9; p.life = 3; break;
                default: p.radius = 0.35f; break;
            }
            if (radius > 0) p.radius = radius;
            p.Build(adopt);
            All.Add(p);
            return p;
        }

        void Glow(Color c, float size)
        {
            var g = UKFx.Billboard(transform, Vector3.zero, size, c);
            glow = g.transform;
            glowMat = new Material(g.GetComponent<MeshRenderer>().sharedMaterial);
            g.GetComponent<MeshRenderer>().sharedMaterial = glowMat;
            gameObject.AddComponent<UKOwnMat>().m = glowMat;
        }

        void SetGlowColor(Color c)
        {
            if (glowMat == null) return;
            if (glowMat.HasProperty("_BaseColor")) glowMat.SetColor("_BaseColor", c);
            if (glowMat.HasProperty("_Color")) glowMat.SetColor("_Color", c);
        }

        void Build(Transform adopt)
        {
            var root = new GameObject("mesh").transform;
            root.SetParent(transform, false);
            mesh = root;
            switch (kind)
            {
                case Kind.Sword:
                case Kind.Drone:
                    if (adopt != null) { adopt.SetParent(root, false); adopt.localPosition = Vector3.zero; }
                    return;
                case Kind.Rocket:
                    UKFx.Cyl(root, Vector3.zero, 0.07f, 0.45f, UKFx.Lit(new Color(0.75f, 0.77f, 0.8f)), new Vector3(90, 0, 0));
                    UKFx.Cone(root, new Vector3(0, 0, 0.3f), 0.07f, 0.16f, UKFx.Lit(new Color(0.82f, 0.13f, 0.13f)), new Vector3(90, 0, 0), 8);
                    Glow(new Color(1f, 0.54f, 0.19f), 0.9f);
                    glow.localPosition = new Vector3(0, 0, -0.3f);
                    return;
                case Kind.Cannonball:
                    UKFx.Shape(root, UKFx.Sphere, Vector3.zero, Vector3.one * 0.7f, UKFx.Lit(new Color(0.16f, 0.16f, 0.19f)));
                    Glow(new Color(0.38f, 1f, 0.5f), 1.2f);
                    return;
                case Kind.Nail:
                    UKFx.Part(root, Vector3.zero, new Vector3(0.03f, 0.03f, 0.3f), UKFx.Unlit(heated ? new Color(1f, 0.63f, 0.25f) : new Color(0.78f, 0.8f, 0.83f)));
                    if (heated) Glow(new Color(1f, 0.38f, 0.13f), 0.5f);
                    return;
                case Kind.Saw:
                    {
                        var steel = UKFx.Lit(new Color(0.85f, 0.86f, 0.89f), 0.1f);
                        var red = UKFx.Unlit(new Color(1f, 0.29f, 0.19f));
                        UKFx.Cyl(root, Vector3.zero, 0.28f, 0.035f, steel, new Vector3(90, 0, 0), 14);
                        UKFx.Cyl(root, Vector3.zero, 0.09f, 0.06f, red, new Vector3(90, 0, 0), 8);
                        for (int k = 0; k < 12; k++)
                        {
                            float a = k * 30f;
                            var t = UKFx.Part(root, Vector3.zero, new Vector3(0.04f, 0.06f, 0.028f), red);
                            t.transform.localPosition = Quaternion.Euler(0, 0, a) * new Vector3(0, 0.29f, 0);
                            t.transform.localRotation = Quaternion.Euler(0, 0, a);
                        }
                        Glow(new Color(1f, 0.25f, 0.19f), 0.9f);
                        return;
                    }
                case Kind.Chainsaw:
                    UKFx.Part(root, Vector3.zero, new Vector3(0.5f, 0.04f, 0.16f), UKFx.Lit(new Color(0.85f, 0.86f, 0.89f)));
                    UKFx.Part(root, new Vector3(0, 0, 0.09f), new Vector3(0.54f, 0.05f, 0.04f), UKFx.Unlit(new Color(1f, 0.23f, 0.16f)));
                    return;
                case Kind.Magnet:
                    UKFx.Part(root, Vector3.zero, Vector3.one * 0.18f, UKFx.Lit(new Color(0.23f, 0.38f, 1f), 0.5f));
                    Glow(new Color(0.23f, 0.54f, 1f), 1.4f);
                    return;
                case Kind.Bullet:
                    UKFx.Part(root, Vector3.zero, new Vector3(0.12f, 0.12f, 0.24f), UKFx.Unlit(new Color(1f, 0.95f, 0.75f)));
                    Glow(color, 0.6f);
                    return;
                case Kind.Core:
                    UKFx.Part(root, Vector3.zero, Vector3.one * radius * 1.4f, UKFx.Unlit(new Color(0.6f, 0.85f, 1f))).transform.localRotation = Random.rotation;
                    Glow(color, radius * 5);
                    return;
                default:
                    UKFx.Part(root, Vector3.zero, Vector3.one * radius * 1.2f, UKFx.Unlit(new Color(1f, 0.95f, 0.75f))).transform.localRotation = Random.rotation;
                    UKFx.Part(root, Vector3.zero, Vector3.one * radius * 1.2f, UKFx.Unlit(new Color(1f, 0.95f, 0.75f))).transform.localRotation = Random.rotation;
                    Glow(color, radius * 5);
                    return;
            }
        }

        public void Parry(Vector3 dir, float speed, UKEnemy target)
        {
            fromPlayer = true;
            parried = true;
            homeTarget = target;
            if (kind == Kind.Drone)
            {
                UKGame.I.stats.droneParries++;
                vel = dir * speed * 1.2f;
                gravity = 0;
                life = 3;
                return;
            }
            vel = dir * speed;
            damage = kind == Kind.Orb ? 4.5f : 3f;
            life = 4;
            gravity = 0;
            color = new Color(0.62f, 0.85f, 1f);
            SetGlowColor(new Color(0.62f, 0.85f, 1f, 1f));
            if (glow) glow.localScale *= 1.4f;
        }

        public void Kill()
        {
            if (dead) return;
            dead = true;
            All.Remove(this);
            Destroy(gameObject);
        }

        public static void ClearAll()
        {
            for (int i = All.Count - 1; i >= 0; i--) if (All[i]) All[i].Kill();
            All.Clear();
        }

        // ------------------------------------------------------------ çarpışma yardımcıları
        // Dünya (tetik, karakter kapsülü ve düşman bölgesi olmayan) ilk isabet
        public static bool WorldCast(Vector3 o, Vector3 d, float dist, out RaycastHit best)
        {
            best = default;
            float bd = float.MaxValue;
            bool any = false;
            foreach (var h in Physics.RaycastAll(o, d, dist, UKFx.RayMask, QueryTriggerInteraction.Ignore))
            {
                if (h.collider is CharacterController || h.collider.GetComponent<UKHitbox>() != null) continue;
                if (h.distance < bd) { bd = h.distance; best = h; any = true; }
            }
            return any;
        }

        // a→b parçası boyunca yarıçaplı tarama: en yakın canlı düşman bölgesi (kafa öncelikli)
        public static UKHitbox EnemyCast(Vector3 a, Vector3 b, float r, out Vector3 point)
        {
            point = b;
            Vector3 d = b - a;
            float dist = d.magnitude;
            if (dist < 1e-4f) { d = Vector3.forward * 0.001f; dist = 0.001f; }
            var hits = Physics.SphereCastAll(a, r, d / dist, dist, UKFx.RayMask, QueryTriggerInteraction.Collide);
            System.Array.Sort(hits, (x, y) => x.distance.CompareTo(y.distance));
            for (int i = 0; i < hits.Length; i++)
            {
                var hb = hits[i].collider.GetComponent<UKHitbox>();
                if (hb == null || hb.owner == null || hb.owner.dead || hb.owner.State == "spawn") continue;
                hb = UKHitbox.PreferHead(hits, i, hb, 0.6f, out var hh);
                point = hh.point == Vector3.zero ? a : hh.point;
                return hb;
            }
            return null;
        }

        // İki doğru parçası arası en kısa uzaklığın karesi (örnekleyerek)
        static float SegSegDist2(Vector3 a0, Vector3 a1, Vector3 b0, Vector3 b1)
        {
            float best = float.MaxValue;
            Vector3 d = b1 - b0;
            float l2 = d.sqrMagnitude;
            for (int i = 0; i <= 4; i++)
            {
                Vector3 a = Vector3.Lerp(a0, a1, i / 4f);
                float t = l2 > 0 ? Mathf.Clamp01(Vector3.Dot(a - b0, d) / l2) : 0;
                best = Mathf.Min(best, (b0 + d * t - a).sqrMagnitude);
            }
            return best;
        }

        bool TouchesPlayer(Vector3 a, Vector3 b)
        {
            var p = P;
            if (p.dead) return false;
            Vector3 pa = p.transform.position + Vector3.up * 0.35f, pb = p.transform.position + Vector3.up * Mathf.Max(0.5f, p.cc.height - 0.3f);
            float rr = radius + 0.4f;
            return SegSegDist2(a, b, pa, pb) < rr * rr;
        }

        // ------------------------------------------------------------ güncelleme
        void Update()
        {
            if (dead) return;
            float dt = Time.deltaTime;
            if (dt <= 0) return;
            age += dt;
            life -= dt;
            if (kind == Kind.Sword) { UpdateSword(dt); return; }
            if (kind == Kind.Chainsaw) { UpdateChainsaw(dt); return; }
            if (kind == Kind.Magnet) { UpdateMagnet(dt); return; }
            if (kind == Kind.Drone) { UpdateDrone(dt); return; }
            if (life <= 0)
            {
                if (kind == Kind.Core || kind == Kind.Rocket) Explode();
                Kill();
                return;
            }
            var w = UKGame.I.weapons;
            // Freezeframe: donmuş roketler hareket etmez
            if (kind == Kind.Rocket && w.FreezeActive)
            {
                life += dt;
                SetGlowColor(new Color(0.5f, 0.82f, 1f));
                return;
            }
            if (kind == Kind.Rocket) SetGlowColor(boosted ? Color.white : new Color(1f, 0.54f, 0.19f));
            // Attractor mıknatısları çivileri çeker
            if (kind == Kind.Nail)
            {
                UKProjectile best = null;
                float bd = 196;
                foreach (var m in All)
                {
                    if (m.kind != Kind.Magnet || m.dead) continue;
                    float d2 = (m.transform.position - transform.position).sqrMagnitude;
                    if (d2 < bd) { bd = d2; best = m; }
                }
                if (best != null) vel = Vector3.Lerp(vel, (best.transform.position - transform.position).normalized * vel.magnitude, Mathf.Min(1, dt * 10));
            }
            // parry yardımı: geri yollanan mermi hedefine kıvrılır
            if (homeTarget != null && fromPlayer)
            {
                if (homeTarget.dead) homeTarget = null;
                else vel = Vector3.Lerp(vel, (homeTarget.Center - transform.position).normalized * vel.magnitude, Mathf.Min(1, dt * homeRate));
            }
            prev = transform.position;
            vel.y -= gravity * dt;
            float sp = vel.magnitude, step = sp * dt;
            if (step > 0)
            {
                if (WorldCast(prev, vel / sp, step + radius * 0.5f, out var hit))
                {
                    transform.position = hit.point;
                    if (OnWorldHit(hit)) return;
                }
                else transform.position = prev + vel * dt;
            }
            Animate(dt);

            if (!fromPlayer)
            {
                if (TouchesPlayer(prev, transform.position))
                {
                    if (explosive)
                    {
                        UKGame.I.Explode(transform.position, 3, 0.6f, false, damage, 10);
                        Kill();
                        return;
                    }
                    if (UKGame.I.DamagePlayer(damage, transform.position, false))
                    {
                        UKFx.I.Burst(transform.position, 10, 6, color, 0.3f, 0.06f);
                        UKAudio.I.Play("projHit");
                        Kill();
                        return;
                    }
                }
            }
            else
            {
                var hb = EnemyCast(prev, transform.position, radius, out var pt);
                if (hb != null) OnEnemyHit(hb.owner, pt, hb.head);
            }
        }

        void Animate(float dt)
        {
            if (kind == Kind.Core)
            {
                mesh.Rotate(dt * 460, dt * 340, 0);
                if (glow) glow.localScale = Vector3.one * radius * 5 * (1 + Mathf.Sin(age * 30) * 0.2f);
            }
            else if (kind == Kind.Rocket || kind == Kind.Nail || kind == Kind.Bullet || kind == Kind.Saw)
            {
                if (vel.sqrMagnitude > 0.01f) transform.rotation = Quaternion.LookRotation(vel);
                if (kind == Kind.Saw) mesh.Rotate(0, 0, -dt * 2300, Space.Self);
                if (kind == Kind.Rocket && Random.value < dt * 40) UKFx.I.Smoke(transform.position - vel * 0.012f, 1, new Color(0.54f, 0.52f, 0.5f), 0.35f, 0.6f, 0.3f);
            }
            else if (kind == Kind.Cannonball) mesh.Rotate(dt * 570, 0, 0);
            else mesh.Rotate(dt * 120, dt * 90, 0);
        }

        // true: mermi yok oldu
        bool OnEnemyHit(UKEnemy e, Vector3 pt, bool head)
        {
            var game = UKGame.I;
            Vector3 dir = vel.normalized;
            switch (kind)
            {
                case Kind.Core:
                case Kind.Rocket:
                    transform.position = pt;
                    Explode();
                    Kill();
                    return true;
                case Kind.Nail:
                    e.Hit(damage, pt, dir, head, "nailgun", 0.6f, 1.5f, true);
                    if (heated) e.burn = Mathf.Max(e.burn, 2.5f);
                    Kill();
                    return true;
                case Kind.Saw:
                case Kind.Cannonball:
                    {
                        hitCd.TryGetValue(e, out var last);
                        if (last > 0 && age - last < (kind == Kind.Saw ? 0.18f : 1f)) return false;
                        hitCd[e] = age;
                        if (kind == Kind.Saw)
                        {
                            e.Hit(damage, pt, dir, head, "nailgun", 1, 1.5f);
                            UKAudio.I.PlayAt("enemyHit", pt);
                        }
                        else
                        {
                            float sp = vel.magnitude;
                            var d2 = dir; d2.y = 0.6f;
                            e.Hit(damage * Mathf.Min(1.5f, sp / 35f), pt, d2.normalized, head, "rocket", 28, 1.5f);
                            UKAudio.I.PlayAt("punchHit", pt);
                            P.Shake(0.3f);
                            vel *= 0.6f;
                        }
                        return false;
                    }
            }
            e.Hit(damage, pt, dir, head, parried ? "parry" : "revolver", 10, 1.5f, false, parried);
            UKFx.I.Burst(pt, 16, 8, new Color(0.75f, 0.9f, 1f), 0.35f, 0.07f);
            UKAudio.I.PlayAt("projHit", pt);
            if (parried && explosive) game.Explode(pt, 4.5f, 3, true, 0, 16, "parry");
            else if (parried && kind == Kind.Orb) game.Explode(pt, 2.5f, 1.5f, true, 0, 15, "parry", true);
            Kill();
            return true;
        }

        // true: işlem bitti
        bool OnWorldHit(RaycastHit hit)
        {
            var game = UKGame.I;
            Vector3 n = hit.normal;
            switch (kind)
            {
                case Kind.Core:
                case Kind.Rocket:
                    transform.position = hit.point + n * 0.2f;
                    Explode();
                    Kill();
                    return true;
                case Kind.Saw:
                    if (bounces > 0)
                    {
                        bounces--;
                        vel = Vector3.Reflect(vel, n);
                        transform.position = hit.point + n * 0.05f;
                        UKFx.I.Spark(transform.position, n, 8, 7, new Color(1f, 0.75f, 0.38f), 0.3f, 0.05f, 0.6f);
                        UKAudio.I.PlayAt("walljump", transform.position, 0.6f);
                        return true;
                    }
                    break;
                case Kind.Cannonball:
                    game.Explode(hit.point + n * 0.2f, 3, 1.5f, false, 10, 12, "rocket");
                    Kill();
                    return true;
                case Kind.Nail:
                    if (Random.value < 0.3f) UKFx.I.BulletHole(hit.point, n, 0.08f);
                    if (Random.value < 0.5f) UKFx.I.Spark(hit.point, n, 2, 4, new Color(1f, 0.82f, 0.5f), 0.15f, 0.03f, 0.8f);
                    Kill();
                    return true;
            }
            if (explosive)
            {
                var p = hit.point + n * 0.2f;
                if (parried) game.Explode(p, 4.5f, 3, true, 0, 16, "parry");
                else game.Explode(p, 3.2f, 0.6f, false, damage, 12);
                Kill();
                return true;
            }
            UKFx.I.Spark(hit.point, n, 8, 6, color, 0.3f, 0.06f, 0.8f);
            if (parried) game.Explode(hit.point, 2.5f, 1.5f, true, 0, 15, "parry", true);
            Kill();
            return true;
        }

        void Explode()
        {
            var g = UKGame.I;
            if (kind == Kind.Core) g.Explode(transform.position, boosted ? 7.5f : 5.5f, boosted ? 5 : 3.5f, false, 30, 18, "shotgun");
            else if (kind == Kind.Rocket) g.Explode(transform.position, boosted ? 6.5f : 5f, boosted ? 5 : 3.5f, false, 28, 22, "rocket");
        }

        // Revolver ile vurulan çekirdek (CORE SNIPE) ya da shotgun saçması
        public void Detonate(bool boost)
        {
            if (dead) return;
            boosted = boosted || boost;
            Explode();
            Kill();
        }

        // ---- Mıknatıs (Attractor): yüzeye ya da düşmana yapışır
        void UpdateMagnet(float dt)
        {
            if (life <= 0) { Kill(); return; }
            if (stuckTo != null)
            {
                if (stuckTo.dead) { stuckTo = null; vel = Vector3.zero; stuck = false; }
                else transform.position = stuckTo.Center + stuckOff;
            }
            else if (!stuck)
            {
                prev = transform.position;
                vel.y -= 12 * dt;
                float sp = vel.magnitude;
                if (sp > 0 && WorldCast(prev, vel / sp, sp * dt + 0.1f, out var hit))
                {
                    transform.position = hit.point + hit.normal * 0.1f;
                    stuck = true;
                    UKAudio.I.PlayAt("magnet", transform.position);
                }
                else
                {
                    transform.position = prev + vel * dt;
                    var hb = EnemyCast(prev, transform.position, 0.2f, out _);
                    if (hb != null) { stuckTo = hb.owner; stuckOff = transform.position - hb.owner.Center; UKAudio.I.PlayAt("magnet", transform.position); }
                }
            }
            mesh.Rotate(0, dt * 170, 0);
            if (glow) glow.localScale = Vector3.one * (1.2f + Mathf.Sin(age * 8) * 0.3f);
        }

        // ---- Sawed-On zincirli testere: gider, biçer, geri döner
        void UpdateChainsaw(float dt)
        {
            mesh.Rotate(0, dt * 1430, 0);
            if (!back)
            {
                outT += dt;
                float sp = vel.magnitude;
                if (sp > 0 && WorldCast(transform.position, vel / sp, sp * dt + 0.4f, out var hit))
                {
                    UKFx.I.Burst(hit.point, 12, 8, new Color(1f, 0.75f, 0.25f), 0.3f, 0.06f);
                    UKAudio.I.PlayAt("projHit", transform.position);
                    back = true;
                }
                else if (outT > 0.65f) back = true;
                else transform.position += vel * dt;
            }
            else
            {
                Vector3 to = P.EyePos - transform.position;
                float d = to.magnitude;
                if (d < 1.4f || age > 5) { UKGame.I.weapons.SawReturned(); Kill(); return; }
                vel = Vector3.Lerp(vel, to / d * 40, Mathf.Min(1, dt * 6));
                transform.position += vel * dt;
            }
            if (Random.value < dt * 30) UKFx.I.Burst(transform.position, 1, 3, new Color(1f, 0.63f, 0.19f), 0.25f, 0.05f);
            for (int i = UKEnemy.All.Count - 1; i >= 0; i--)
            {
                if (i >= UKEnemy.All.Count) continue;
                var e = UKEnemy.All[i];
                if (e == null || e.dead || e.State == "spawn") continue;
                float rr = e.radius + 1.1f;
                if ((e.Center - transform.position).sqrMagnitude > rr * rr) continue;
                hitCd.TryGetValue(e, out var last);
                if (last > 0 && age - last < 0.12f) continue;
                hitCd[e] = age;
                e.Hit(0.4f, transform.position, vel.normalized, false, "shotgun", 2);
                UKAudio.I.PlayAt("chainsaw", transform.position, 0.5f);
            }
        }

        // ---- Boss kılıcı (bumerang)
        void UpdateSword(float dt)
        {
            mesh.Rotate(0, dt * 1260, 0, Space.World);
            var boss = source as UKSwordsmachine;
            if (!back)
            {
                outT += dt;
                float sp = vel.magnitude;
                if (sp > 0 && WorldCast(transform.position, vel / sp, sp * dt + 0.5f, out var hit))
                {
                    UKFx.I.Burst(hit.point, 16, 10, new Color(1f, 0.75f, 0.25f), 0.4f, 0.07f);
                    UKAudio.I.PlayAt("projHit", transform.position);
                    P.Shake(0.2f);
                    back = true;
                    hitPlayerOnce = false;
                }
                else if (outT > 1f) { back = true; hitPlayerOnce = false; }
                else transform.position += vel * dt;
            }
            else
            {
                Vector3 target = boss != null && !boss.dead ? boss.HandWorld : transform.position;
                Vector3 to = target - transform.position;
                float d = to.magnitude;
                if (boss == null || boss.dead || d < 1.2f || age > 6)
                {
                    if (boss != null && !boss.dead) boss.CatchSword();
                    Kill();
                    return;
                }
                vel = Vector3.Lerp(vel, to / d * 34, Mathf.Min(1, dt * 6));
                transform.position += vel * dt;
            }
            if (Random.value < dt * 30) UKFx.I.Burst(transform.position, 1, 3, new Color(1f, 0.63f, 0.19f), 0.25f, 0.05f);
            var p = P;
            if (!p.dead && !hitPlayerOnce && (p.transform.position + Vector3.up * 0.9f - transform.position).sqrMagnitude < 1.6f * 1.6f)
                if (UKGame.I.DamagePlayer(damage, transform.position, false)) hitPlayerOnce = true;
        }

        // ---- Ölen drone: oyuncuya dalar, çarpınca patlar (yumrukla geri yollanabilir)
        void UpdateDrone(float dt)
        {
            prev = transform.position;
            if (homeTarget != null && !homeTarget.dead)
                vel = Vector3.Lerp(vel, (homeTarget.Center - transform.position).normalized * vel.magnitude, Mathf.Min(1, dt * homeRate));
            vel.y -= gravity * dt;
            transform.position += vel * dt;
            mesh.Rotate(dt * 515, 0, dt * 340);
            if (Random.value < dt * 30) UKFx.I.Smoke(transform.position, 1, new Color(0.19f, 0.16f, 0.16f), 0.4f, 0.7f, 0.8f);
            bool boom = life <= 0;
            float sp = vel.magnitude;
            if (sp > 0 && WorldCast(prev, vel / sp, sp * dt + 0.4f, out _)) boom = true;
            if (fromPlayer) { if (EnemyCast(prev, transform.position, 0.5f, out _) != null) boom = true; }
            else if ((transform.position - (P.transform.position + Vector3.up * 0.8f)).magnitude < 1.2f) boom = true;
            if (boom)
            {
                if (fromPlayer) UKGame.I.Explode(transform.position, 5, 4, true, 0, 14, "parry");
                else UKGame.I.Explode(transform.position, 3.6f, 2, false, 24, 14, "explosion");
                Kill();
            }
        }
    }

    // Marksman bozuk parası: havaya atılır, vurulunca en yakın düşmana (ya da diğer paraya) seker
    public class UKCoin : MonoBehaviour
    {
        public static readonly List<UKCoin> All = new List<UKCoin>();
        public Vector3 vel;
        public float age;
        public bool alive = true;
        Transform glow;

        public static UKCoin Spawn(Vector3 pos, Vector3 vel)
        {
            var go = new GameObject("coin");
            go.transform.position = pos;
            var c = go.AddComponent<UKCoin>();
            c.vel = vel;
            UKFx.Cyl(go.transform, Vector3.zero, 0.17f, 0.035f, UKFx.Unlit(new Color(1f, 0.82f, 0.29f)), new Vector3(90, 0, 0), 10);
            c.glow = UKFx.Billboard(go.transform, Vector3.zero, 0.9f, new Color(1f, 0.75f, 0.19f)).transform;
            All.Add(c);
            return c;
        }

        void Update()
        {
            if (!alive) return;
            float dt = Time.deltaTime;
            if (dt <= 0) return;
            age += dt;
            float assist = UKGame.I.settings.coinAssist;
            float apexSlow = assist >= 2 ? 0.3f : assist >= 1 ? 0.6f : 1;
            vel.y -= 24 * dt * (Mathf.Abs(vel.y) < 4 ? apexSlow : 1);
            Vector3 next = transform.position + vel * dt;
            bool solid = false;
            foreach (var c in Physics.OverlapSphere(next, 0.06f, UKFx.RayMask, QueryTriggerInteraction.Ignore))
                if (!(c is CharacterController) && c.GetComponent<UKHitbox>() == null) { solid = true; break; }
            if (solid || age > 5)
            {
                UKAudio.I.PlayAt("empty", transform.position);
                Kill();
                return;
            }
            transform.position = next;
            transform.Rotate(dt * 650, dt * 1030, 0);
            bool apex = Mathf.Abs(vel.y) < 3;
            glow.localScale = Vector3.one * (apex ? 1.5f + Mathf.Sin(age * 40) * 0.2f : 0.9f);
        }

        public void Kill()
        {
            if (!alive) return;
            alive = false;
            All.Remove(this);
            Destroy(gameObject);
        }

        public static void ClearAll()
        {
            for (int i = All.Count - 1; i >= 0; i--) if (All[i]) All[i].Kill();
            All.Clear();
        }
    }

    // Yer sarsıntısı: zeminde genişleyen halka; yerdeysen vurur, üstünden zıpla
    public class UKShockwave : MonoBehaviour
    {
        public static readonly List<UKShockwave> All = new List<UKShockwave>();
        float r = 0.6f, speed = 17, max = 24, dmg = 20;
        bool hitP;
        LineRenderer lr;
        Transform wall;
        Material wallMat;
        Color col;

        public static UKShockwave Spawn(Vector3 pos, float dmg, float speed, float max, Color c)
        {
            var go = new GameObject("shockwave");
            go.transform.position = pos;
            var s = go.AddComponent<UKShockwave>();
            s.dmg = dmg; s.speed = speed; s.max = max; s.col = c;
            s.lr = go.AddComponent<LineRenderer>();
            s.lr.sharedMaterial = UKFx.Unlit(Color.white);
            s.lr.useWorldSpace = false;
            s.lr.loop = true;
            s.lr.positionCount = 48;
            s.lr.startWidth = s.lr.endWidth = 0.2f;
            s.lr.startColor = s.lr.endColor = c;
            var w = UKFx.Shape(go.transform, UKFx.Frustum(1, 32), new Vector3(0, 0.4f, 0), Vector3.one, UKFx.Unlit(Color.white));
            s.wall = w.transform;
            s.wallMat = new Material(w.GetComponent<MeshRenderer>().sharedMaterial);
            w.GetComponent<MeshRenderer>().sharedMaterial = s.wallMat;
            go.AddComponent<UKOwnMat>().m = s.wallMat;
            s.Tick(0);
            All.Add(s);
            return s;
        }

        void Update()
        {
            float dt = Time.deltaTime;
            if (dt > 0) Tick(dt);
        }

        void Tick(float dt)
        {
            r += speed * dt;
            float k = 1 - r / max;
            var c = col; c.a = Mathf.Clamp01(k * 2);
            lr.startColor = lr.endColor = c;
            for (int i = 0; i < lr.positionCount; i++) { float a = i * Mathf.PI * 2 / lr.positionCount; lr.SetPosition(i, new Vector3(Mathf.Cos(a) * r, 0.25f, Mathf.Sin(a) * r)); }
            wall.localScale = new Vector3(r * 2, 0.8f, r * 2);
            var wc = col; wc.a = 0.28f * Mathf.Clamp01(k);
            if (wallMat.HasProperty("_Color")) wallMat.SetColor("_Color", wc);
            if (wallMat.HasProperty("_BaseColor")) wallMat.SetColor("_BaseColor", wc);
            if (dt <= 0) return;
            var p = UKGame.I.player;
            if (!hitP && !p.dead)
            {
                Vector3 d = p.transform.position - transform.position;
                float dy = d.y;
                d.y = 0;
                if (Mathf.Abs(d.magnitude - r) < 0.9f && dy < 0.85f && dy > -1.5f)
                {
                    hitP = true;
                    if (UKGame.I.DamagePlayer(dmg * UKGame.I.Diff.dmg, transform.position, false)) { p.vel.y = Mathf.Max(p.vel.y, 9); p.grounded = false; }
                }
            }
            if (r >= max) Kill();
        }

        public void Kill()
        {
            All.Remove(this);
            Destroy(gameObject);
        }

        public static void ClearAll()
        {
            for (int i = All.Count - 1; i >= 0; i--) if (All[i]) All[i].Kill();
            All.Clear();
        }
    }
}
