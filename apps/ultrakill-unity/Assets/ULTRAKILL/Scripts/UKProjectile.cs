// Mermiler: düşman küreleri (PARRY ile geri yollanabilir), oyuncu çivileri ve çekirdek bombası.
// Her karede önceki konumdan yeni konuma küre taraması yapılır (hızlı mermiler tünellemez).
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKProjectile : MonoBehaviour
    {
        public enum Kind { Orb, Nail, Core, Bullet }
        public static readonly List<UKProjectile> All = new List<UKProjectile>();

        public Kind kind;
        public Vector3 vel;
        public float radius = 0.3f, damage = 20, life = 6, gravity;
        public bool fromPlayer, parryable = true, parried, dead;
        public UKEnemy source, homeTarget;
        Color color;
        Transform glow;

        public static UKProjectile Spawn(Kind kind, Vector3 pos, Vector3 vel, bool fromPlayer, float damage, Color color, UKEnemy source = null, float radius = -1)
        {
            var go = new GameObject("proj_" + kind);
            go.transform.position = pos;
            var p = go.AddComponent<UKProjectile>();
            p.kind = kind;
            p.vel = vel;
            p.fromPlayer = fromPlayer;
            p.damage = damage;
            p.color = color;
            p.source = source;
            p.parryable = kind == Kind.Orb;
            if (kind == Kind.Nail) { p.radius = 0.1f; p.gravity = 2.5f; p.life = 1.6f; }
            else if (kind == Kind.Core) { p.radius = 0.22f; p.gravity = 20f; p.life = 3f; }
            else if (kind == Kind.Bullet) { p.radius = 0.2f; p.life = 2f; p.parryable = false; }
            else { p.radius = 0.35f; }
            if (radius > 0) p.radius = radius;
            p.Build();
            All.Add(p);
            return p;
        }

        void Build()
        {
            if (kind == Kind.Nail)
            {
                var n = UKFx.Part(transform, Vector3.zero, new Vector3(0.03f, 0.03f, 0.3f), UKFx.Unlit(color));
                n.transform.localRotation = Quaternion.identity;
                return;
            }
            var core = UKFx.Part(transform, Vector3.zero, Vector3.one * radius * (kind == Kind.Core ? 1.6f : 1.3f), UKFx.Unlit(kind == Kind.Orb ? new Color(1f, 0.95f, 0.75f) : color));
            core.transform.localRotation = Random.rotation;
            var go = new GameObject("glow");
            go.transform.SetParent(transform, false);
            go.AddComponent<MeshFilter>().sharedMesh = UKFx.Quad;
            var r = go.AddComponent<MeshRenderer>();
            var c = color; c.a = 0.55f;
            r.sharedMaterial = UKFx.Unlit(c);
            glow = go.transform;
            glow.localScale = Vector3.one * radius * 4.5f;
        }

        public void Parry(Vector3 dir, float speed, UKEnemy target)
        {
            fromPlayer = true;
            parried = true;
            vel = dir * speed;
            damage = kind == Kind.Orb ? 4.5f : 3f;
            life = 4;
            gravity = 0;
            homeTarget = target;
            color = new Color(0.62f, 0.85f, 1f);
            if (glow) glow.GetComponent<MeshRenderer>().sharedMaterial = UKFx.Unlit(new Color(0.62f, 0.85f, 1f, 0.7f));
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

        void Update()
        {
            if (dead) return;
            float dt = Time.deltaTime;
            if (dt <= 0) return;
            life -= dt;
            if (life <= 0) { if (kind == Kind.Core) Explode(); Kill(); return; }
            if (homeTarget != null && !homeTarget.dead)
            {
                float sp = vel.magnitude;
                vel = Vector3.Lerp(vel, (homeTarget.Center - transform.position).normalized * sp, Mathf.Min(1, dt * 5));
            }
            vel.y -= gravity * dt;
            Vector3 p0 = transform.position, step = vel * dt;
            float dist = step.magnitude;
            var cam = Camera.main;
            if (glow && cam) glow.rotation = Quaternion.LookRotation(glow.position - cam.transform.position);
            if (kind == Kind.Nail && dist > 0) transform.rotation = Quaternion.LookRotation(vel);
            if (dist > 0)
            {
                var hits = Physics.SphereCastAll(p0, radius, step / dist, dist, ~0, QueryTriggerInteraction.Collide);
                System.Array.Sort(hits, (a, b) => a.distance.CompareTo(b.distance));
                var player = UKGame.I.player;
                for (int i = 0; i < hits.Length; i++)
                {
                    var h = hits[i];
                    var hb = h.collider.GetComponent<UKHitbox>();
                    if (h.collider == player.cc)
                    {
                        if (fromPlayer) continue;
                        if (UKGame.I.DamagePlayer(damage, p0, false))
                        {
                            UKFx.I.Burst(transform.position, 10, 6, color, 0.3f, 0.06f);
                            UKAudio.I.Play("projHit");
                        }
                        Kill();
                        return;
                    }
                    if (hb != null)
                    {
                        if (!fromPlayer || hb.owner == null || hb.owner.dead) continue;
                        hb = UKHitbox.PreferHead(hits, i, hb, 0.6f, out var hh);
                        HitEnemy(hb, hh.point == Vector3.zero ? p0 : hh.point);
                        return;
                    }
                    if (h.collider.isTrigger) continue;
                    // dünya
                    Vector3 pt = h.point == Vector3.zero ? p0 : h.point;
                    transform.position = pt;
                    if (kind == Kind.Core) { Explode(); Kill(); return; }
                    UKFx.I.Burst(pt, kind == Kind.Nail ? 2 : 8, 6, color, 0.3f, 0.05f, 10, h.normal, 0.8f);
                    if (parried) UKGame.I.Explode(pt, 2.5f, 1.5f, true, 0);
                    Kill();
                    return;
                }
            }
            transform.position = p0 + step;
        }

        void HitEnemy(UKHitbox hb, Vector3 pt)
        {
            var e = hb.owner;
            Vector3 dir = vel.normalized;
            if (kind == Kind.Core) { transform.position = pt; Explode(); Kill(); return; }
            if (kind == Kind.Nail)
            {
                e.Hit(damage, pt, dir, hb.head, "nailgun", 0.6f, 1.5f, true);
                Kill();
                return;
            }
            e.Hit(damage, pt, dir, hb.head, parried ? "parry" : "revolver", 10, 1.5f, false, parried);
            UKFx.I.Burst(pt, 16, 8, new Color(0.75f, 0.9f, 1f), 0.35f, 0.07f);
            UKAudio.I.Play("projHit");
            if (parried) UKGame.I.Explode(pt, 2.5f, 1.5f, true, 0);
            Kill();
        }

        void Explode()
        {
            UKGame.I.Explode(transform.position, 5.5f, 3.5f, false, 30);
        }
    }
}
