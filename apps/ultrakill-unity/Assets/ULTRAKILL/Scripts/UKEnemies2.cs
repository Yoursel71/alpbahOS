// Düşmanlar 2 (web: enemies.js sonu + enemies2.js): MALICIOUS FACE, CERBERUS (boss, ikiz heykel),
// DRONE (ölünce dalış), STREETCLEANER (alev + sırt tankı), HIDEOUS MASS (mini boss), V2 (boss).
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    // Dünya uzayında kutu ışın (işaret/lazer): from → yön, uzunluk
    public class UKBeam
    {
        readonly Transform t;
        readonly Material m;
        public UKBeam(string name)
        {
            var go = UKFx.Part(null, Vector3.zero, Vector3.one, UKFx.Unlit(Color.red));
            go.name = name;
            m = new Material(go.GetComponent<MeshRenderer>().sharedMaterial);
            go.GetComponent<MeshRenderer>().sharedMaterial = m;
            go.AddComponent<UKOwnMat>().m = m;
            t = go.transform;
            go.SetActive(false);
        }
        public void Show(Vector3 from, Vector3 dir, float len, float w, Color c)
        {
            t.gameObject.SetActive(true);
            t.position = from + dir * len * 0.5f;
            t.rotation = Quaternion.LookRotation(dir);
            t.localScale = new Vector3(w, w, len);
            if (m.HasProperty("_Color")) m.SetColor("_Color", c);
            if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", c);
        }
        public void Hide() { if (t) t.gameObject.SetActive(false); }
        public void Destroy() { if (t) Object.Destroy(t.gameObject); }
    }

    // ------------------------------------------------------------------ MALICIOUS FACE
    public class UKMaliciousFace : UKEnemy
    {
        float hoverY, strafeDir = 1, strafeT, jawOpen;
        bool nextBeam, locked;
        int shots;
        Transform head, jaw, mouth, mouthGlow;
        Material eyeMat;
        readonly List<Transform> rubble = new List<Transform>();
        readonly List<Vector4> rubbleP = new List<Vector4>();
        UKBeam laser;
        Vector3 aimPt, beamDir;
        float beamLen = 150, fallRot;
        protected override string FirstState => "hover";
        protected override float SpawnDur => 0.9f;

        protected override void Init()
        {
            type = "maliciousface"; enemyName = "MALICIOUS FACE"; maxHp = 10; radius = 1.05f; height = 2.2f; flying = true; big = true; killPts = 280; knockMul = 0.1f;
            speed = 4 * DSpeed; hoverY = transform.position.y; tint = 1;
            strafeDir = Random.value < 0.5f ? 1 : -1; strafeT = Random.Range(2f, 4f); atkCd = Random.Range(1.4f, 2.4f); nextBeam = Random.value < 0.5f;
            var stone = M(C(0xc4b49e), 0.1f, UKFx.TexStone);
            var dark = M(C(0x4e3e34), 0.08f, UKFx.TexRock);
            var bone = M(C(0xf4e6c4), 0.12f, UKFx.TexBone);
            head = W.J(model, 0, 1.1f, 0, "face");
            W.Box(head, 1.9f, 1.45f, 1.8f, stone, 0, 0.18f, 0.05f);
            W.Box(head, 1.55f, 0.35f, 1.45f, stone, 0, 1.0f, 0.12f);
            W.Box(head, 2.08f, 0.3f, 0.5f, dark, 0, 0.46f, -0.82f);
            foreach (float x in new[] { -0.82f, 0.82f }) W.Box(head, 0.45f, 0.62f, 0.5f, stone, x, -0.18f, -0.74f);
            W.Box(head, 0.32f, 0.5f, 0.36f, stone, 0, 0.02f, -0.98f, 0.25f);
            var black = UKFx.Unlit(C(0x0a0204));
            foreach (float x in new[] { -0.46f, 0.46f }) W.Box(head, 0.52f, 0.3f, 0.1f, black, x, 0.2f, -0.94f, 0, 0, 0, true);
            eyeMat = new Material(UKFx.Unlit(C(0xff6a1a)));
            gameObject.AddComponent<UKOwnMat>().m = eyeMat;
            foreach (float x in new[] { -0.46f, 0.46f }) W.Box(head, 0.22f, 0.14f, 0.06f, eyeMat, x, 0.2f, -0.99f, 0, 0, 0, true);
            W.Box(head, 1.35f, 0.3f, 0.1f, black, 0, -0.52f, -0.9f, 0, 0, 0, true);
            UKHumanoid.Teeth(head, -0.42f, -0.95f, 1.2f, bone, 8, true);
            jaw = W.J(head, 0, -0.55f, 0.2f);
            W.Box(jaw, 1.6f, 0.42f, 1.55f, stone, 0, -0.22f, -0.2f);
            UKHumanoid.Teeth(jaw, 0.02f, -0.92f, 1.15f, bone, 7, false);
            mouth = W.J(head, 0, -0.62f, -1.05f);
            mouthGlow = W.Glow(mouth, 0, 0, 0, 1, C(0xff7a20)).transform;
            mouthGlow.localScale = Vector3.one * 0.1f;
            foreach (var xr in new[] { new Vector2(-0.6f, 0.5f), new Vector2(-0.2f, 0.15f), new Vector2(0.25f, -0.2f), new Vector2(0.65f, -0.55f) })
                W.Cone(head, 0.14f, 0.75f, dark, xr.x, 1.45f, 0.25f, -0.35f, 0, xr.y);
            var crack = UKFx.Unlit(C(0xa0301a));
            W.Box(head, 0.05f, 0.75f, 0.04f, crack, -0.25f, 0.72f, -0.9f, 0, 0, 0.45f, true);
            W.Box(head, 0.05f, 0.5f, 0.04f, crack, 0.62f, -0.1f, -0.99f, 0, 0, -0.3f, true);
            W.Box(head, 0.04f, 0.6f, 0.04f, crack, 0.96f, 0.4f, -0.3f, 0.2f, 0, 0, true);
            for (int k = 0; k < 5; k++)
            {
                rubble.Add(W.Box(model, Random.Range(0.2f, 0.35f), Random.Range(0.18f, 0.3f), Random.Range(0.2f, 0.35f), dark, 0, 0, 0).transform);
                rubbleP.Add(new Vector4(k / 5f * Mathf.PI * 2, Random.Range(1.5f, 1.9f), Random.Range(0.3f, 1.8f), Random.Range(0.6f, 1.1f)));
            }
            AddHitSphere(head, W.V(0, 0.2f, -0.92f), 0.42f, true);
            laser = new UKBeam("mfLaser");
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist);
            var p = P;
            float aggro = Aggro;
            atkCd -= dt;
            float wantY = Mathf.Max(hoverY, p.transform.position.y + 3) + Mathf.Sin(time * 1.3f) * 0.35f;
            vel.y = Mathf.Clamp((wantY - transform.position.y) * 2, -6, 6);
            switch (state)
            {
                case "hover":
                    {
                        Face(d, 3, dt);
                        strafeT -= dt;
                        if (strafeT <= 0) { strafeT = Random.Range(2f, 4f); strafeDir *= -1; }
                        float want = dist > 26 ? 1 : dist < 12 ? -1 : 0;
                        AccelTo((d * want + Side(d) * strafeDir * 0.6f) * speed, 8, dt);
                        if (blocked > 0.3f) { strafeDir *= -1; blocked = 0; }
                        if (atkCd <= 0 && canSee && dist < 70)
                        {
                            SetState(nextBeam ? "beamWind" : "volleyWind");
                            nextBeam = !nextBeam;
                            UKAudio.I.PlayAt(state == "beamWind" ? "windup" : "orbCharge", transform.position, 1, 0.6f);
                            aimPt = p.transform.position + Vector3.up * 0.9f;
                        }
                        break;
                    }
                case "volleyWind":
                    {
                        Face(d, 5, dt); Brake(8, dt);
                        float dur = 0.85f / aggro;
                        jawOpen = Mathf.Clamp01(st / dur);
                        mouthGlow.localScale = Vector3.one * (0.3f + jawOpen * 1.6f);
                        if (st >= dur) { state = "volley"; st = 0; shots = 0; }
                        break;
                    }
                case "volley":
                    Face(d, 4, dt);
                    while (shots < 7 && st >= shots * 0.07f) { FireOrb(shots, 7); shots++; }
                    if (st > 7 * 0.07f + 0.35f) { SetState("hover"); atkCd = Random.Range(2.2f, 3.4f) / aggro; }
                    break;
                case "beamWind":
                    {
                        Brake(8, dt);
                        float dur = 1.45f / aggro, lockT = dur - 0.38f;
                        if (st < lockT)
                        {
                            Face(d, 4, dt);
                            aimPt = Vector3.Lerp(aimPt, p.transform.position + Vector3.up * 0.9f, 1 - Mathf.Exp(-dt * 3.2f));
                        }
                        else if (!locked) { locked = true; UKAudio.I.PlayAt("glint", transform.position); }
                        jawOpen = Mathf.Clamp01(st / dur) * 0.7f;
                        mouthGlow.localScale = Vector3.one * (0.3f + st * 1.4f);
                        bool lk = st >= lockT;
                        ShowLaser(lk ? 0.09f : 0.035f, lk ? Color.white : new Color(1f, 0.19f, 0.13f, 0.55f + Mathf.Sin(time * 40) * 0.25f));
                        if (st >= dur) { locked = false; FireBeam(); state = "beam"; st = 0; }
                        break;
                    }
                case "beam":
                    {
                        Brake(8, dt);
                        float kk = 1 - st / 0.35f;
                        if (kk > 0) laser.Show(mouth.position, beamDir, beamLen, 0.9f * kk + 0.1f, new Color(1f, 0.63f, 0.38f, kk));
                        else laser.Hide();
                        if (st > 0.7f) { SetState("hover"); atkCd = Random.Range(2.6f, 4f) / aggro; }
                        break;
                    }
            }
            if (state != "beamWind" && state != "beam") laser.Hide();
            if (state == "hover") mouthGlow.localScale = Vector3.one * 0.1f;
        }

        void ShowLaser(float w, Color c)
        {
            Vector3 from = mouth.position;
            Vector3 dir = (aimPt - from).normalized;
            beamLen = UKProjectile.WorldCast(from, dir, 150, out var hit) ? hit.distance : 150;
            beamDir = dir;
            laser.Show(from, dir, beamLen, w, c);
        }

        void FireBeam()
        {
            Vector3 from = mouth.position;
            Vector3 end = from + beamDir * beamLen;
            Vector3 pc = P.transform.position + Vector3.up * 0.9f;
            float t = Mathf.Clamp(Vector3.Dot(pc - from, beamDir), 0, beamLen);
            if ((from + beamDir * t - pc).magnitude < 1.0f) UKGame.I.DamagePlayer(32 * DDmg, from, false);
            UKGame.I.Explode(end, 2.5f, 0, true, 0, 15, "explosion", false, true);
            UKFx.I.Burst(from, 20, 10, new Color(1f, 0.75f, 0.5f), 0.4f, 0.08f);
            UKFx.I.Flash(from, new Color(1f, 0.5f, 0.25f), 10, 20, 0.2f);
            UKAudio.I.PlayAt("rail", from, 1, 0.7f);
            P.Shake(0.25f);
        }

        void FireOrb(int kk, int n)
        {
            Vector3 from = mouth.position;
            float sp = 23 * DSpeed;
            Vector3 target = P.transform.position + Vector3.up * 0.9f;
            target += P.vel * (Vector3.Distance(from, target) / sp) * 0.3f;
            Vector3 dir = (target - from).normalized;
            float spread = (kk / (float)(n - 1) - 0.5f) * 0.5f;
            dir = Quaternion.AngleAxis(spread * Mathf.Rad2Deg, Vector3.up) * dir;
            dir.y += Random.Range(-0.03f, 0.03f);
            Shoot(from, dir.normalized, sp, 14, C(0xff6a1a), 0.4f);
            if (kk == 0) UKAudio.I.PlayAt("orbThrow", from, 1, 0.7f);
        }

        protected override void OnHurt(float dmg) { head.localRotation = W.Q(0, 0, Random.Range(-0.1f, 0.1f)); }

        protected override void Animate(float dt)
        {
            float kk = 1 - Mathf.Exp(-10 * dt);
            if (state != "volleyWind" && state != "volley" && state != "beamWind") jawOpen = Mathf.Max(0, jawOpen - dt * 2);
            jaw.localRotation = Quaternion.Slerp(jaw.localRotation, W.Q(-jawOpen * 0.55f), kk);
            hr *= Mathf.Exp(-8 * dt);
            head.localRotation = W.Q(Mathf.Sin(time * 0.9f) * 0.05f + hr.x * 0.4f, 0, Mathf.Sin(time * 0.7f) * 0.06f + hr.y * 0.4f);
            head.localPosition = new Vector3(0, 1.1f + Mathf.Sin(time * 1.7f) * 0.06f, 0);
            for (int i = 0; i < rubble.Count; i++)
            {
                var r = rubbleP[i];
                float a = r.x + time * r.w;
                rubble[i].localPosition = W.V(Mathf.Cos(a) * r.y, r.z + Mathf.Sin(time * 2 + r.x) * 0.15f, Mathf.Sin(a) * r.y);
                rubble[i].localRotation = W.Q(time * r.w, time * r.w * 0.7f, 0);
            }
            float heat = state == "beamWind" || state == "volleyWind" ? 1 : 0.4f;
            var ec = new Color(1, 0.35f + heat * 0.3f, 0.1f * heat);
            if (eyeMat.HasProperty("_Color")) eyeMat.SetColor("_Color", ec);
            if (eyeMat.HasProperty("_BaseColor")) eyeMat.SetColor("_BaseColor", ec);
        }

        protected override string DeathMode(float dmg, string weapon, bool head_, bool explosion, int pellets) => dmg >= 99 ? "gib" : "collapse";

        protected override void OnDied(float dmg, string weapon, bool h, Vector3 dir, bool silent)
        {
            laser.Destroy();
            mouthGlow.gameObject.SetActive(false);
            var dc = C(0x301008);
            if (eyeMat.HasProperty("_Color")) eyeMat.SetColor("_Color", dc);
            if (eyeMat.HasProperty("_BaseColor")) eyeMat.SetColor("_BaseColor", dc);
        }

        // Ceset: kafa dönerek düşer, yere çarpınca patlar ve parçalanır
        protected override void CorpseTick(float dt)
        {
            vel.y -= 35 * dt;
            Vector3 step = vel * dt;
            bool ground = UKProjectile.WorldCast(transform.position + Vector3.up * 0.3f, Vector3.down, 0.3f - step.y + 0.05f, out _);
            transform.position += step;
            fallRot += dt;
            head.localRotation = W.Q(fallRot * 2.4f, 0, fallRot * 1.2f);
            if (Random.value < dt * 25) UKFx.I.Smoke(Center, 1, new Color(0.42f, 0.35f, 0.31f), 0.7f, 0.8f, 1);
            if (ground || fallRot > 3.5f || transform.position.y < UKGame.I.level.killY)
            {
                Vector3 c = Center;
                UKGame.I.Explode(c, 5, 2.5f, false, 20, 18, "explosion");
                foreach (var mr in model.GetComponentsInChildren<MeshRenderer>())
                    if (mr.gameObject.name != "ng") UKFx.I.GibFromPart(mr.transform, new Vector3(Random.Range(-1f, 1f), Random.Range(0.5f, 1.5f), Random.Range(-1f, 1f)) * 9);
                RemoveSilently();
            }
        }

        public override void RemoveSilently() { laser?.Destroy(); base.RemoveSilently(); }
    }

    // ------------------------------------------------------------------ CERBERUS (boss): canlanan taş heykel
    public class UKCerberus : UKEnemy
    {
        float baseSpeed, cdMul = 1;
        bool tackleHit;
        Vector3 tackleDir;
        Material crackMat, eyeMat, orbCoreMat, orbGlowMat;
        Transform orb, orbGlow;
        protected override string FirstState => dormantFirst ? "dormant" : chasing ? "chase" : "roar";
        bool dormantFirst, chasing;
        protected override float SpawnDur => 0.9f;

        protected override void Init()
        {
            type = "cerberus"; enemyName = "CERBERUS"; maxHp = 32; radius = 0.9f; height = 4.0f; big = true; boss = true; killPts = 600; knockMul = 0.15f; parryDmg = 6; parryStun = 1.4f;
            baseSpeed = 5.2f * DSpeed; speed = baseSpeed; atkCd = 1.2f; tint = 1;
            dormantFirst = dormant;
            invuln = dormant;
            var stone = M(C(0xd0c8ba), 0.08f, UKFx.TexStone);
            var dark = M(C(0x5e554c), 0.06f, UKFx.TexRock);
            H = UKHumanoid.Build(model, stone, dark, 0.06f, 0.64f, 0.72f, 0.38f, 0.32f, 1.12f, 1.05f, 1.9f, 0.72f);
            crackMat = OwnUnlit(C(0x2a1e18));
            eyeMat = OwnUnlit(C(0x1a1412));
            W.Box(H.head, 0.36f, 0.14f, 0.38f, dark, 0, 0.36f, 0);
            for (int k = 0; k < 7; k++)
            {
                float a = (k / 6f - 0.5f) * 2.4f;
                W.Cone(H.head, 0.04f, 0.2f, dark, Mathf.Sin(a) * 0.18f, 0.46f, Mathf.Cos(a) * 0.12f, -0.25f, 0, -a * 0.5f, false, 4);
            }
            foreach (float x in new[] { -0.075f, 0.075f }) W.Box(H.head, 0.07f, 0.04f, 0.02f, eyeMat, x, 0.2f, -0.165f, 0, 0, 0, true);
            W.Box(H.head, 0.2f, 0.06f, 0.02f, dark, 0, 0.08f, -0.165f);
            foreach (var sh in new[] { H.shL, H.shR }) { W.Box(sh, 0.3f, 0.16f, 0.36f, dark, 0, 0.06f, 0); W.Cone(sh, 0.06f, 0.22f, dark, 0, 0.2f, 0, 0, 0, 0, false, 4); }
            W.Box(H.spine, H.torsoW * 0.9f, H.torsoH * 0.35f, 0.05f, dark, 0, H.torsoH * 0.72f, -H.torsoD / 2 - 0.02f);
            W.Box(H.hips, 0.42f, 0.5f, 0.05f, dark, 0, -0.3f, -0.16f);
            W.Box(H.hips, 0.42f, 0.45f, 0.05f, dark, 0, -0.28f, 0.16f);
            void Cr(Transform p, float x, float y, float z, float h, float rz) => W.Box(p, 0.025f, h, 0.02f, crackMat, x, y, z, 0, 0, rz, true);
            Cr(H.spine, -0.12f, H.torsoH * 0.5f, -H.torsoD / 2 - 0.05f, 0.4f, 0.4f);
            Cr(H.spine, 0.1f, H.torsoH * 0.3f, -H.torsoD / 2 - 0.02f, 0.3f, -0.5f);
            Cr(H.spine, 0.2f, H.torsoH * 0.62f, -H.torsoD / 2 - 0.05f, 0.22f, 0.2f);
            foreach (var up in new[] { H.shL, H.shR }) Cr(up, 0, -0.18f, -0.06f, 0.25f, 0.3f);
            foreach (var el in new[] { H.elL, H.elR }) Cr(el, 0, -0.15f, -0.05f, 0.2f, -0.3f);
            foreach (var kn in new[] { H.knL, H.knR }) Cr(kn, 0, -0.2f, -0.065f, 0.25f, 0.2f);
            orb = W.J(H.haR, 0, -0.2f, -0.04f);
            orbCoreMat = OwnUnlit(C(0x6a5a4a));
            var core = UKFx.Part(orb, Vector3.zero, Vector3.one * 0.36f, orbCoreMat);
            core.name = "ng";
            core.transform.localRotation = Quaternion.Euler(30, 45, 10);
            var g = UKFx.Billboard(orb, Vector3.zero, 1.4f, C(0xff8a20));
            g.name = "ng";
            orbGlow = g.transform;
            orbGlowMat = new Material(g.GetComponent<MeshRenderer>().sharedMaterial);
            g.GetComponent<MeshRenderer>().sharedMaterial = orbGlowMat;
            gameObject.AddComponent<UKOwnMat>().m = orbGlowMat;
            SetAwake(!dormant);
        }

        Material OwnUnlit(Color c)
        {
            var m = new Material(UKFx.Unlit(c));
            var h = new GameObject("mat").AddComponent<UKOwnMat>();
            h.transform.SetParent(transform, false);
            h.m = m;
            return m;
        }

        static void SetC(Material m, Color c)
        {
            if (m.HasProperty("_Color")) m.SetColor("_Color", c);
            if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", c);
        }

        void SetAwake(bool on)
        {
            SetC(crackMat, on ? (enraged ? C(0xff3010) : C(0xff8a20)) : C(0x2a1e18));
            SetC(eyeMat, on ? (enraged ? C(0xff2010) : C(0xffc040)) : C(0x1a1412));
            SetC(orbCoreMat, on ? C(0xfff0c0) : C(0x6a5a4a));
            var gc = C(0xff8a20); gc.a = on ? 1 : 0;
            SetC(orbGlowMat, gc);
        }

        public void Wake()
        {
            if (!dormant || dead) return;
            dormant = false;
            invuln = false;
            dormantFirst = false;
            SetAwake(true);
            SetState("roar");
            UKAudio.I.PlayAt("bossRoar", transform.position);
            P.Shake(0.5f);
            UKFx.I.Burst(Center, 40, 8, new Color(1f, 0.6f, 0.25f), 0.8f, 0.08f);
            UKFx.I.Smoke(transform.position + Vector3.up, 8, new Color(0.6f, 0.54f, 0.48f), 1.2f, 1.2f, 1);
            UKGame.I.hud.Message("CERBERUS UYANDI", 1.6f);
        }

        public void Enrage()
        {
            if (enraged || dead) return;
            enraged = true;
            speed = baseSpeed * 1.2f;
            cdMul = 0.8f;
            SetAwake(true);
            UKAudio.I.PlayAt("bossRoar", transform.position, 1, 0.8f);
            UKGame.I.style.Add("ENRAGED", 50, null);
        }

        protected override void OnHurt(float dmg)
        {
            var pa = partner as UKCerberus;
            if (pa != null && pa.dormant && hp < maxHp * 0.55f) pa.Wake();
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist, out float dy);
            float cd = cdMul / Aggro;
            var game = UKGame.I;
            if (state != "dormant" && state != "roar") atkCd -= dt;
            switch (state)
            {
                case "dormant": Brake(30, dt); break;
                case "roar":
                    Brake(30, dt);
                    Face(d, 4, dt);
                    if (st > 1.1f) { chasing = true; SetState("chase"); atkCd = 0.6f; }
                    break;
                case "chase":
                    Face(d, 5, dt);
                    AccelTo(d * (dist > 5 ? speed : 0), 25, dt);
                    if (atkCd <= 0)
                    {
                        float r = Random.value;
                        if (dist < 4.2f) { SetState("swipeWind"); UKAudio.I.PlayAt("windup", transform.position); }
                        else if (r < 0.25f && canSee && game.runTime - game.cerbOrbT > 3.2f) { game.cerbOrbT = game.runTime; SetState("orbWind"); UKAudio.I.PlayAt("orbCharge", transform.position, 1, 0.7f); }
                        else if (r < 0.7f) { SetState("stompWind"); UKAudio.I.PlayAt("slamStart", transform.position, 1, 0.6f); }
                        else if (canSee && dist > 6) { SetState("tackleWind"); UKAudio.I.PlayAt("windup", transform.position, 1, 0.7f); }
                        else { SetState("stompWind"); UKAudio.I.PlayAt("slamStart", transform.position, 1, 0.6f); }
                    }
                    break;
                case "orbWind":
                    {
                        Face(d, 7, dt); Brake(30, dt);
                        float dur = Mathf.Max(0.8f, 0.95f * cd);
                        orbGlow.localScale = Vector3.one * (1.4f + st / dur * 2);
                        if (st >= dur) { ThrowOrb(); orbGlow.localScale = Vector3.one * 1.4f; state = "recover"; st = 0; atkCd = Random.Range(2.2f, 3.2f) * cd; }
                        break;
                    }
                case "stompWind":
                    Brake(30, dt);
                    if (st >= 0.65f * cd) { Stomp(); state = "recover"; st = 0; atkCd = Random.Range(1.4f, 2.4f) * cd; }
                    break;
                case "tackleWind":
                    {
                        Face(d, 6, dt); Brake(30, dt);
                        float dur = 0.7f * cd;
                        SetParryable(st > dur - 0.4f, HeadPos);
                        if (st >= dur) { tackleDir = d; tackleHit = false; state = "tackle"; st = 0; UKAudio.I.PlayAt("dash", transform.position, 1, 0.6f); }
                        break;
                    }
                case "tackle":
                    {
                        float sp = 28 * DSpeed;
                        vel.x = tackleDir.x * sp; vel.z = tackleDir.z * sp;
                        SetParryable(st < 0.2f, HeadPos);
                        if (!tackleHit && dist < 1.9f && Mathf.Abs(dy) < 2.5f)
                        {
                            tackleHit = true;
                            if (game.DamagePlayer(25 * DDmg, transform.position, false)) { P.vel += tackleDir * 18; P.vel.y = Mathf.Max(P.vel.y, 8); }
                        }
                        if (Random.value < dt * 30) UKFx.I.Smoke(transform.position + Vector3.up * 0.2f, 1, new Color(0.54f, 0.48f, 0.42f), 0.6f, 0.5f, 0.5f);
                        if (blocked > 0.05f && st > 0.1f)
                        {
                            P.Shake(0.4f);
                            UKAudio.I.PlayAt("slam", transform.position, 0.8f);
                            stun = 1.1f;
                            vel = Vector3.zero;
                            SetState("stagger");
                            atkCd = Random.Range(1f, 1.8f) * cd;
                        }
                        else if (st > 0.75f) { state = "recover"; st = 0; SetParryable(false); atkCd = Random.Range(1.2f, 2f) * cd; }
                        break;
                    }
                case "swipeWind":
                    {
                        Face(d, 8, dt); Brake(30, dt);
                        float dur = 0.5f * cd;
                        SetParryable(st > dur - 0.3f, H.haL.position);
                        if (st >= dur)
                        {
                            SetParryable(false);
                            UKAudio.I.PlayAt("swing", transform.position, 1, 0.7f);
                            MeleeHit(4.4f, 22, 0.1f);
                            state = "recover"; st = 0;
                            atkCd = Random.Range(0.9f, 1.6f) * cd;
                        }
                        break;
                    }
                case "recover":
                    Brake(30, dt);
                    if (st > 0.5f) SetState("chase");
                    break;
            }
        }

        void ThrowOrb()
        {
            Vector3 from = orb.position;
            float sp = 19 * DSpeed;
            Vector3 target = P.transform.position + Vector3.up * 0.9f;
            target += P.vel * (Vector3.Distance(from, target) / sp) * 0.2f;
            Shoot(from, (target - from).normalized, sp, 18, C(0xff7a20), 0.6f);
            UKAudio.I.PlayAt("orbThrow", from, 1, 0.6f);
        }

        void Stomp()
        {
            Vector3 pos = transform.position;
            UKShockwave.Spawn(pos, 20, 17, 24, enraged ? C(0xff3a20) : C(0xff8a30));
            UKFx.I.Ring(pos, C(0xffb060), 5, 0.4f);
            UKFx.I.Smoke(pos + Vector3.up * 0.3f, 10, new Color(0.6f, 0.54f, 0.48f), 1.4f, 1, 0.8f);
            UKFx.I.Burst(pos + Vector3.up * 0.3f, 30, 10, C(0xffc080), 0.5f, 0.08f);
            UKAudio.I.PlayAt("slam", pos, 1, 0.7f);
            P.Shake(Mathf.Clamp(0.7f - Vector3.Distance(pos, P.transform.position) / 40, 0.15f, 0.6f));
            ToPlayer(out float dist, out float dy);
            if (dist < 3.2f && Mathf.Abs(dy) < 1.5f) UKGame.I.DamagePlayer(18 * DDmg, pos, false);
        }

        public override void Parried(Vector3 dir)
        {
            base.Parried(dir);
            if (!dead) UKAudio.I.PlayAt("bossRoar", transform.position, 0.5f, 1.2f);
        }

        protected override void OnDied(float dmg, string weapon, bool h, Vector3 dir, bool silent)
        {
            UKGame.I.Hitstop(0.3f);
            var pa = partner as UKCerberus;
            if (pa != null && !pa.dead)
            {
                if (pa.dormant) pa.Wake();
                pa.Enrage();
            }
        }

        protected override void Animate(float dt)
        {
            k = 1 - Mathf.Exp(-12 * dt);
            float hsp = HSpeed;
            walkPhase += hsp * dt * 0.9f;
            float amt = Mathf.Clamp01(hsp / 5);
            switch (state)
            {
                case "dormant":
                    WalkPose(0, 0, 0);
                    Rot(H.shR, -1.2f, 0, 0.2f); Rot(H.elR, 1.4f); Rot(H.shL, 0.1f, 0, -0.15f); Rot(H.spine, 0.02f);
                    break;
                case "roar":
                    Rot(H.spine, -0.35f);
                    Rot(H.shL, -2.6f, 0, -0.5f); Rot(H.shR, -2.6f, 0, 0.5f);
                    Rot(H.elL, 0.3f); Rot(H.elR, 0.3f);
                    WalkPose(0, 0, 0);
                    break;
                case "orbWind":
                    Rot(H.spine, -0.15f, 0.5f); Rot(H.shR, -2.7f, 0, 0.3f); Rot(H.elR, 0.6f); Rot(H.shL, 0.6f, 0, -0.4f);
                    break;
                case "stompWind":
                    {
                        float kk = Mathf.Clamp01(st / 0.65f);
                        Rot(H.hipR, 1.2f * kk); Rot(H.knR, -1.5f * kk); Rot(H.spine, -0.15f * kk);
                        Rot(H.shL, -0.8f * kk, 0, -0.6f); Rot(H.shR, -0.8f * kk, 0, 0.6f);
                        break;
                    }
                case "tackleWind":
                    Rot(H.spine, 0.55f); Rot(H.shL, 0.9f, 0, -0.5f); Rot(H.shR, 0.9f, 0, 0.5f);
                    Rot(H.hipL, 0.6f); Rot(H.knL, -1.0f); Rot(H.hipR, -0.3f); Rot(H.knR, -0.5f);
                    break;
                case "tackle":
                    Rot(H.spine, 0.7f); Rot(H.shL, -1.6f, 0, -0.2f); Rot(H.shR, -1.6f, 0, 0.2f);
                    walkPhase += dt * 14;
                    WalkPose(1, 0, -1.6f);
                    break;
                case "swipeWind":
                    Rot(H.spine, -0.1f, -0.7f); Rot(H.shL, -1.8f, 0, -1.2f); Rot(H.elL, 0.4f);
                    break;
                case "recover":
                case "stagger":
                case "flinch":
                    Rot(H.spine, 0.25f, 0.3f); Rot(H.shL, 0.3f, 0, -0.3f); Rot(H.shR, 0.3f, 0, 0.3f);
                    WalkPose(0, 0, 0);
                    break;
                default:
                    Rot(H.spine, 0.05f);
                    WalkPose(amt, 0.6f, 0.1f);
                    Rot(H.shR, -1.0f, 0, 0.2f); Rot(H.elR, 1.2f);
                    Breathe(0.02f);
                    break;
            }
        }
    }

    // ------------------------------------------------------------------ DRONE
    public class UKDrone : UKEnemy
    {
        float orbitDir = 1, orbitT, dodgeCd, alt = 4;
        int shots;
        Transform body, muzzle, eyeGlow;
        readonly List<Transform> fins = new List<Transform>();
        Material eyeMat;
        protected override string FirstState => "fly";

        protected override void Init()
        {
            type = "drone"; enemyName = "DRONE"; maxHp = 1.2f; radius = 0.5f; height = 0.9f; flying = true; killPts = 60; knockMul = 1.4f; speed = 7 * DSpeed; tint = 1;
            orbitDir = Random.value < 0.5f ? 1 : -1; orbitT = Random.Range(2f, 4f); atkCd = Random.Range(1.2f, 2.6f); dodgeCd = Random.Range(1f, 2f); alt = Random.Range(3f, 5f);
            var shell = M(C(0xb8c0cc), 0.12f, UKFx.TexMetal);
            var dark = M(C(0x3a3e48), 0.08f, UKFx.TexMachine);
            body = W.J(model, 0, 0.45f, 0, "drone");
            W.Box(body, 0.72f, 0.5f, 0.72f, shell, 0, 0, 0);
            W.Box(body, 0.5f, 0.18f, 0.5f, dark, 0, 0.32f, 0);
            W.Box(body, 0.42f, 0.14f, 0.42f, dark, 0, -0.3f, 0);
            foreach (var xz in new[] { new Vector2(-0.5f, 0), new Vector2(0.5f, 0), new Vector2(0, 0.5f) })
            {
                var f = W.J(body, xz.x, 0, xz.y);
                W.Box(f, xz.x != 0 ? 0.3f : 0.5f, 0.05f, xz.x != 0 ? 0.5f : 0.3f, dark, xz.x * 0.25f, 0, xz.y * 0.25f);
                fins.Add(f);
            }
            W.Cone(body, 0.02f, 0.4f, dark, 0.15f, 0.55f, 0.1f, 0, 0, 0, false, 4);
            eyeMat = new Material(UKFx.Unlit(C(0x40a0ff)));
            gameObject.AddComponent<UKOwnMat>().m = eyeMat;
            W.Box(body, 0.3f, 0.2f, 0.06f, eyeMat, 0, 0.02f, -0.38f, 0, 0, 0, true);
            eyeGlow = W.Glow(body, 0, 0.02f, -0.45f, 0.5f, C(0x3a8aff)).transform;
            muzzle = W.J(body, 0, 0, -0.5f);
            AddHitSphere(body, W.V(0, 0.02f, -0.36f), 0.2f, true);
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist);
            var p = P;
            float aggro = Aggro;
            atkCd -= dt; dodgeCd -= dt;
            float wantY = p.transform.position.y + alt + Mathf.Sin(time * 2.1f) * 0.5f;
            vel.y = Mathf.Clamp((wantY - transform.position.y) * 2.5f, -7, 7);
            switch (state)
            {
                case "fly":
                    {
                        Face(d, 5, dt);
                        orbitT -= dt;
                        if (orbitT <= 0) { orbitT = Random.Range(2f, 4f); orbitDir *= -1; alt = Random.Range(2.5f, 5.5f); }
                        float want = dist > 18 ? 1 : dist < 9 ? -1 : 0;
                        AccelTo((d * want + Side(d) * orbitDir * 0.8f) * speed, 10, dt);
                        if (blocked > 0.3f) { orbitDir *= -1; blocked = 0; }
                        // oyuncu nişan alınca yana kaçış
                        if (dodgeCd <= 0 && dist < 40 && Vector3.Dot(p.AimDir, (Center - p.EyePos).normalized) > 0.985f)
                        {
                            dodgeCd = Random.Range(1.6f, 3f) / aggro;
                            vel += Side(d) * (Random.value < 0.5f ? 1 : -1) * 13;
                            UKAudio.I.PlayAt("dash", transform.position, 0.5f, 1.4f);
                        }
                        if (atkCd <= 0 && canSee && dist < 45) { SetState("charge"); UKAudio.I.PlayAt("orbCharge", transform.position, 1, 1.6f); }
                        break;
                    }
                case "charge":
                    {
                        Face(d, 8, dt); Brake(12, dt);
                        float dur = 0.6f / aggro;
                        eyeGlow.localScale = Vector3.one * (0.5f + 1.2f * Mathf.Clamp01(st / dur));
                        if (st >= dur) { state = "shoot"; st = 0; shots = 0; }
                        break;
                    }
                case "shoot":
                    Face(d, 8, dt);
                    while (shots < 2 && st >= shots * 0.16f)
                    {
                        float sp = 30 * DSpeed;
                        Shoot(muzzle.position, AimAt(muzzle.position, sp, 0.3f), sp, 15, C(0x3a8aff), 0.28f);
                        UKAudio.I.PlayAt("schismShot", muzzle.position, 1, 1.5f);
                        shots++;
                    }
                    if (st > 0.4f) { SetState("fly"); atkCd = Random.Range(2f, 3.4f) / aggro; eyeGlow.localScale = Vector3.one * 0.5f; }
                    break;
            }
        }

        // Ölünce: parçalanmak yerine oyuncuya doğru dalış, çarpınca patlama
        protected override string DeathMode(float dmg, string weapon, bool head, bool explosion, int pellets)
            => explosion || dmg >= 99 || weapon == "rail" ? "gib" : "dive";

        // parçalanınca yerinde patlar
        protected override void OnGibbed() { UKGame.I.Explode(Center, 3.2f, 2, true, 0, 10, "explosion"); }

        // dalış: gövde, oyuncuya doğru düşen (yumrukla geri yollanabilen) mermi olur
        protected override void Dive()
        {
            Vector3 from = Center;
            Vector3 to = P.transform.position + Vector3.up * 0.8f;
            body.SetParent(null, true);
            var pr = UKProjectile.Spawn(UKProjectile.Kind.Drone, from, (to - from).normalized * 16, false, 0, Color.white, null, 0.5f, body);
            pr.parryable = true;
            RemoveSilently();
        }

        protected override void Animate(float dt)
        {
            float hsp = HSpeed;
            body.localRotation = W.Q(Mathf.Clamp(hsp * 0.02f, 0, 0.3f), 0, Mathf.Clamp(-vel.x * 0.02f, -0.3f, 0.3f) + Mathf.Sin(time * 3) * 0.05f);
            for (int i = 0; i < fins.Count; i++) fins[i].localRotation = W.Q(0, 0, Mathf.Sin(time * 20 + i) * 0.25f);
            bool ch = state == "charge" || state == "shoot";
            var c = ch && Mathf.Sin(time * 40) > 0 ? Color.white : C(0x40a0ff);
            if (eyeMat.HasProperty("_Color")) eyeMat.SetColor("_Color", c);
            if (eyeMat.HasProperty("_BaseColor")) eyeMat.SetColor("_BaseColor", c);
        }
    }

    // ------------------------------------------------------------------ STREETCLEANER: alev püskürtücü
    public class UKStreetcleaner : UKEnemy
    {
        float dodgeCd, flameT, loopT;
        Transform nozzle, tank, flameSpr;
        Material pilotMat;

        protected override void Init()
        {
            type = "streetcleaner"; enemyName = "STREETCLEANER"; maxHp = 3; radius = 0.45f; height = 2.0f; speed = 8.5f * DSpeed; killPts = 90;
            dodgeCd = Random.Range(1f, 2f);
            var suit = M(C(0xd8b030), 0.13f, UKFx.TexCloth);
            var dark = M(C(0x2e3036), 0.13f, UKFx.TexMachine);
            var rubber = M(C(0x24262a), 0.13f, UKFx.TexSkin);
            var tankM = M(C(0xc83a20), 0.2f, UKFx.TexMetal);
            H = UKHumanoid.Build(model, suit, rubber, 0.12f, 0.46f, 0.6f, 0.3f, 0.3f, 1.02f, 1.05f, 1.05f, 0.9f);
            W.Box(H.head, 0.32f, 0.3f, 0.32f, rubber, 0, 0.16f, 0);
            var lens = UKFx.Unlit(C(0xffd060));
            foreach (float x in new[] { -0.08f, 0.08f }) W.Cone(H.head, 0.06f, 0.04f, lens, x, 0.2f, -0.17f, Mathf.PI / 2, 0, 0, true, 8);
            W.Cone(H.head, 0.07f, 0.16f, dark, 0, 0.05f, -0.2f, Mathf.PI / 2 + 0.4f, 0, 0, false, 6);
            tank = W.J(H.spine, 0, H.torsoH * 0.55f, H.torsoD / 2 + 0.14f);
            foreach (float x in new[] { -0.1f, 0.1f }) W.Cone(tank, 0.1f, 0.55f, tankM, x, 0, 0, 0, 0, 0, false, 8);
            W.Box(tank, 0.3f, 0.08f, 0.14f, dark, 0, 0.3f, 0);
            var gun = W.J(H.haR, 0, -0.06f, 0, "flamer");
            W.Box(gun, 0.1f, 0.1f, 0.62f, dark, 0, 0, -0.26f);
            W.Cone(gun, 0.06f, 0.18f, tankM, 0, -0.08f, -0.12f, Mathf.PI / 2, 0, 0, false, 6);
            nozzle = W.J(gun, 0, 0, -0.6f);
            var pg = W.Glow(nozzle, 0, 0, 0, 0.25f, C(0x40a0ff));
            pilotMat = new Material(pg.GetComponent<MeshRenderer>().sharedMaterial);
            pg.GetComponent<MeshRenderer>().sharedMaterial = pilotMat;
            gameObject.AddComponent<UKOwnMat>().m = pilotMat;
            gun.localRotation = W.Q(Mathf.PI / 2);
            flameSpr = UKFx.Billboard(null, Vector3.zero, 3, C(0xff7a20)).transform;
            flameSpr.gameObject.SetActive(false);
            // tank: kritik bölge; vurulursa patlar
            AddHitSphere(tank, Vector3.zero, 0.24f, true);
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist, out float dy);
            var p = P;
            float aggro = Aggro;
            dodgeCd -= dt;
            switch (state)
            {
                case "chase":
                    {
                        Face(d, 9, dt);
                        Vector3 tv = d * speed;
                        if (dist < 4) tv *= 0.2f;
                        if (grounded && !GroundAhead(d)) tv = Vector3.zero;
                        AccelTo(tv, 34, dt);
                        if (grounded && blocked > 0.4f) { vel.y = 10; grounded = false; blocked = 0; }
                        if (dodgeCd <= 0 && dist > 5 && dist < 30 && grounded && Vector3.Dot(p.AimDir, (Center - p.EyePos).normalized) > 0.99f)
                        {
                            dodgeCd = Random.Range(1.4f, 2.6f) / aggro;
                            var sd = Side(d) * (Random.value < 0.5f ? 1 : -1) * 15;
                            vel.x = sd.x; vel.z = sd.z;
                            SetState("dodge");
                            UKAudio.I.PlayAt("dash", transform.position, 0.6f, 1.2f);
                            break;
                        }
                        if (dist < 7.5f && canSee && Mathf.Abs(dy) < 3) { SetState("flame"); UKAudio.I.PlayAt("windup", transform.position, 1, 1.6f); }
                        break;
                    }
                case "dodge":
                    Brake(30, dt);
                    if (st > 0.35f) SetState("chase");
                    break;
                case "flame":
                    Face(d, 4, dt);
                    AccelTo(d * speed * 0.25f, 20, dt);
                    if (st > 0.2f) Spray(dt);
                    if (st > 1.9f || (dist > 11 && st > 0.6f)) { SetState("chase"); dodgeCd = Mathf.Max(dodgeCd, 0.6f); }
                    break;
            }
            if (state != "flame") FlameOff();
        }

        void Spray(float dt)
        {
            var game = UKGame.I;
            var p = P;
            Vector3 from = nozzle.position;
            var f = Forward;
            flameSpr.gameObject.SetActive(true);
            flameSpr.position = from + f * 2.2f;
            flameSpr.localScale = Vector3.one * (3 + Random.value * 1.2f);
            for (int kk = 0; kk < 2; kk++) UKFx.I.Spark(from, new Vector3(f.x, Random.Range(-0.05f, 0.12f), f.z), 3, Random.Range(12f, 17f), Random.value < 0.5f ? C(0xff7a20) : C(0xffc040), 0.45f, 0.14f, 0.25f);
            if (Random.value < dt * 12) UKFx.I.Smoke(from + f * 4, 1, new Color(0.23f, 0.2f, 0.19f), 0.7f, 0.9f, 1.4f);
            loopT -= dt;
            if (loopT <= 0) { loopT = 0.5f; UKAudio.I.PlayAt("flame", from, 0.8f); }
            flameT -= dt;
            if (flameT <= 0)
            {
                flameT = 0.2f;
                Vector3 dd = p.transform.position - from; dd.y = 0;
                float dist = dd.magnitude;
                if (dist < 7.2f && Mathf.Abs(p.transform.position.y + 0.8f - from.y) < 2.4f && Vector3.Dot(dd / Mathf.Max(dist, 0.001f), f) > 0.88f)
                    game.DamagePlayer(5 * DDmg, from, true);
                foreach (var e in All)
                {
                    if (e == this || e.dead) continue;
                    Vector3 ed = e.transform.position - from; ed.y = 0;
                    float el = ed.magnitude;
                    if (el < 6 && Vector3.Dot(ed / Mathf.Max(el, 0.001f), f) > 0.85f) e.burn = Mathf.Max(e.burn, 1.5f);
                }
            }
        }

        void FlameOff() { if (flameSpr && flameSpr.gameObject.activeSelf) flameSpr.gameObject.SetActive(false); }

        protected override void OnHurt(float dmg) { if (state == "flame" && Random.value < 0.3f) SetState("chase"); }

        protected override string DeathMode(float dmg, string weapon, bool head, bool explosion, int pellets)
            => head ? "gib" : base.DeathMode(dmg, weapon, head, explosion, pellets);

        protected override void OnDied(float dmg, string weapon, bool head, Vector3 dir, bool silent)
        {
            if (flameSpr) Destroy(flameSpr.gameObject);
            if (head)
            {
                UKGame.I.Explode(Center, 4.5f, 3, false, 18, 16, weapon ?? "explosion");
                UKGame.I.style.Add("TANK PATLADI", 80, null);
                UKGame.I.stats.tanks++;
            }
        }

        public override void RemoveSilently() { if (flameSpr) Destroy(flameSpr.gameObject); base.RemoveSilently(); }

        protected override void Animate(float dt)
        {
            float hsp = HSpeed;
            walkPhase += hsp * dt * 1.3f;
            float amt = Mathf.Clamp01(hsp / 8);
            WalkPose(amt, 0.3f, 0);
            Rot(H.shR, -1.25f, 0, 0.15f); Rot(H.elR, 0.25f);
            Rot(H.shL, -1.0f, 0.4f, -0.2f); Rot(H.elL, 0.9f);
            if (state == "flame") Rot(H.spine, 0.12f, Mathf.Sin(time * 7) * 0.12f);
            else if (state == "dodge") Rot(H.spine, 0.2f, 0, 0.3f);
            else { Rot(H.spine, -0.06f - amt * 0.12f, 0); if (!grounded && state != "spawn") AirPose(); }
            var pc = state == "flame" ? C(0xffa040) : C(0x40a0ff);
            if (pilotMat.HasProperty("_Color")) pilotMat.SetColor("_Color", pc);
            if (pilotMat.HasProperty("_BaseColor")) pilotMat.SetColor("_BaseColor", pc);
        }
    }

    // ------------------------------------------------------------------ HIDEOUS MASS (mini boss)
    public class UKHideousMass : UKEnemy
    {
        int shots;
        string lastAtk = "";
        Transform bodyG, tail, head, mouth, mouthGlow;
        readonly List<Transform> segs = new List<Transform>(), vents = new List<Transform>();
        Material eyeMat;
        float tailX = -0.3f, headX;
        protected override string FirstState => "crawl";
        protected override float SpawnDur => 1.0f;

        protected override void Init()
        {
            type = "hideousmass"; enemyName = "HIDEOUS MASS"; maxHp = 28; radius = 1.6f; height = 2.6f; big = true; boss = true; killPts = 450; knockMul = 0.04f; parryDmg = 4; parryStun = 1.1f;
            speed = 2.6f * DSpeed; atkCd = 1.6f; tint = 1;
            var flesh = M(C(0xe8a8a0), 0.16f, UKFx.TexFlesh);
            var skin = M(C(0xc89080), 0.12f, UKFx.TexSkin);
            var bone = M(C(0xf4e6c4), 0.12f, UKFx.TexBone);
            var dark = M(C(0x5a2a28), 0.1f, UKFx.TexRock);
            bodyG = W.J(model, 0, 0, 0, "mass");
            for (int kk = 0; kk < 5; kk++)
            {
                var s = W.J(bodyG, 0, 0, kk * 1.1f - 0.4f);
                float w = 2.6f - kk * 0.38f, hh = 2.1f - kk * 0.3f;
                W.Box(s, w, hh, 1.3f, kk % 2 == 1 ? skin : flesh, 0, hh / 2, 0);
                if (kk < 4) foreach (float x in new[] { -w / 2 + 0.2f, w / 2 - 0.2f }) W.Cone(s, 0.08f, 0.5f, bone, x, hh + 0.1f, 0, 0.3f, 0, x > 0 ? -0.4f : 0.4f, false, 4);
                segs.Add(s);
            }
            tail = W.J(segs[4], 0, 0.6f, 0.6f);
            W.Limb(tail, 0.7f, 2.4f, 0.7f, dark, 1.1f);
            W.Cone(tail, 0.35f, 0.8f, bone, 0, 2.6f, 0);
            head = W.J(bodyG, 0, 1.2f, -1.2f);
            W.Box(head, 1.6f, 1.2f, 0.6f, flesh, 0, 0.1f, 0);
            W.Box(head, 1.0f, 0.5f, 0.1f, UKFx.Unlit(C(0x0a0204)), 0, 0.05f, -0.31f, 0, 0, 0, true);
            eyeMat = new Material(UKFx.Unlit(C(0xff5020)));
            gameObject.AddComponent<UKOwnMat>().m = eyeMat;
            foreach (float x in new[] { -0.45f, 0.45f }) W.Box(head, 0.2f, 0.14f, 0.05f, eyeMat, x, 0.5f, -0.32f, 0, 0, 0, true);
            mouth = W.J(head, 0, 0.05f, -0.4f);
            mouthGlow = W.Glow(mouth, 0, 0, 0, 1, C(0xff6020)).transform;
            mouthGlow.localScale = Vector3.one * 0.1f;
            foreach (var xz in new[] { new Vector2(-0.6f, 0), new Vector2(0.6f, 0.2f), new Vector2(0, 1.1f) })
            {
                var v = W.J(bodyG, xz.x, 2.0f, xz.y);
                W.Cone(v, 0.22f, 0.3f, dark, 0, 0, 0, 0, 0, 0, false, 6);
                vents.Add(v);
            }
            AddHitSphere(bodyG, W.V(0, 1.1f, 0.2f), 1.35f, false);
            AddHitSphere(bodyG, W.V(0, 0.9f, 2.0f), 1.0f, false);
            AddHitSphere(head, W.V(0, 0.2f, -0.2f), 0.62f, true);
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist);
            float aggro = Aggro * (enraged ? 1.3f : 1);
            atkCd -= dt;
            if (!enraged && hp < maxHp * 0.5f)
            {
                enraged = true;
                UKAudio.I.PlayAt("bossRoar", transform.position, 1, 0.7f);
                UKGame.I.hud.Message("HIDEOUS MASS ÖFKELENDİ", 1.4f);
            }
            switch (state)
            {
                case "crawl":
                    {
                        Face(d, 1.4f, dt);
                        var f = Forward;
                        AccelTo(f * speed * (dist > 9 ? 1 : 0), 6, dt);
                        if (atkCd <= 0)
                        {
                            string next;
                            if (dist < 7 && lastAtk != "tail") next = "tailWind";
                            else if (lastAtk == "mortar" || (canSee && Random.value < 0.5f)) next = "harpoonWind";
                            else next = "mortarWind";
                            lastAtk = next == "tailWind" ? "tail" : next == "harpoonWind" ? "harpoon" : "mortar";
                            SetState(next);
                            UKAudio.I.PlayAt(next == "harpoonWind" ? "windup" : "orbCharge", transform.position, 1, 0.6f);
                        }
                        break;
                    }
                case "mortarWind":
                    Brake(10, dt);
                    if (st > 0.7f / aggro) { state = "mortar"; st = 0; shots = 0; }
                    break;
                case "mortar":
                    {
                        int n = enraged ? 5 : 3;
                        while (shots < n && st >= shots * 0.22f) { FireMortar(shots, n); shots++; }
                        if (st > n * 0.22f + 0.5f) { SetState("crawl"); atkCd = Random.Range(1.6f, 2.4f) / aggro; }
                        break;
                    }
                case "harpoonWind":
                    {
                        Face(d, 3, dt); Brake(10, dt);
                        float dur = 0.9f / aggro;
                        mouthGlow.localScale = Vector3.one * (0.3f + 2 * Mathf.Clamp01(st / dur));
                        if (st >= dur)
                        {
                            float sp = 48 * DSpeed;
                            Shoot(mouth.position, AimAt(mouth.position, sp, 0.25f, 0.55f), sp, 30, C(0xffd0a0), 0.4f, UKProjectile.Kind.Bullet);
                            UKAudio.I.PlayAt("bossShotgun", mouth.position, 1, 0.7f);
                            state = "harpoon"; st = 0;
                        }
                        break;
                    }
                case "harpoon":
                    mouthGlow.localScale = Vector3.one * Mathf.Max(0.1f, 2.3f - st * 6);
                    if (st > 0.6f) { SetState("crawl"); atkCd = Random.Range(1.4f, 2.2f) / aggro; }
                    break;
                case "tailWind":
                    Brake(10, dt);
                    if (st > 0.85f / aggro)
                    {
                        state = "tail"; st = 0;
                        Vector3 pos = transform.position;
                        UKShockwave.Spawn(pos, 20, 15, 20, C(0xff6030));
                        if (enraged) UKGame.I.Schedule(0.35f, () => { if (!dead) UKShockwave.Spawn(pos, 20, 19, 22, C(0xff3020)); });
                        UKFx.I.Explosion(tail.position, 2);
                        UKAudio.I.PlayAt("slam", transform.position);
                        P.Shake(0.5f);
                    }
                    break;
                case "tail":
                    if (st > 0.7f) { SetState("crawl"); atkCd = Random.Range(1.5f, 2.3f) / aggro; }
                    break;
            }
        }

        void FireMortar(int kk, int n)
        {
            var p = P;
            Vector3 from = vents[kk % vents.Count].position + Vector3.up * 0.3f;
            const float T = 1.35f, g = 22;
            float ang = kk / (float)n * Mathf.PI * 2 + Random.Range(-0.3f, 0.3f);
            float spread = kk == 0 ? 0 : Random.Range(2f, 4.5f);
            float tx = p.transform.position.x + Mathf.Cos(ang) * spread + p.vel.x * 0.4f, tz = p.transform.position.z + Mathf.Sin(ang) * spread + p.vel.z * 0.4f;
            var v = new Vector3((tx - from.x) / T, (p.transform.position.y - from.y + 0.5f * g * T * T) / T, (tz - from.z) / T);
            var pr = UKProjectile.Spawn(UKProjectile.Kind.Orb, from, v, false, 18 * DDmg, C(0xff5020), this, 0.5f);
            pr.gravity = g;
            pr.life = 5;
            pr.explosive = true;
            UKAudio.I.PlayAt("orbThrow", from, 1, 0.7f);
            UKFx.I.Smoke(from, 3, new Color(0.42f, 0.19f, 0.16f), 0.6f, 0.8f, 1.5f);
        }

        protected override void Animate(float dt)
        {
            float t = time, hsp = HSpeed;
            for (int i = 0; i < segs.Count; i++)
            {
                segs[i].localPosition = W.V(0, Mathf.Max(0, Mathf.Sin(t * 3 - i * 0.9f)) * 0.12f * (0.3f + hsp), i * 1.1f - 0.4f);
                segs[i].localScale = new Vector3(1 + Mathf.Sin(t * 2 - i) * 0.03f, 1, 1);
            }
            float target = -0.3f + Mathf.Sin(t * 1.3f) * 0.1f;
            if (state == "tailWind") target = -0.3f - 1.2f * Mathf.Clamp01(st / 0.6f);
            else if (state == "tail") target = -1.5f + 2.4f * Mathf.Clamp01(st / 0.12f);
            tailX += (target - tailX) * Mathf.Min(1, dt * (state == "tail" ? 30 : 8));
            tail.localRotation = W.Q(tailX);
            bool rear = state == "mortarWind" || state == "mortar";
            headX += ((rear ? -0.5f : 0) - headX) * Mathf.Min(1, dt * 6);
            head.localRotation = W.Q(headX);
            var ec = enraged ? (Mathf.Sin(t * 12) > 0 ? C(0xff2010) : C(0xffa040)) : C(0xff5020);
            if (eyeMat.HasProperty("_Color")) eyeMat.SetColor("_Color", ec);
            if (eyeMat.HasProperty("_BaseColor")) eyeMat.SetColor("_BaseColor", ec);
        }
    }

    // ------------------------------------------------------------------ V2 (boss): kırmızı rakip makine
    public class UKV2 : UKEnemy
    {
        float baseSpeed, orbitDir = 1, orbitT, dashCd = 6, jumpCd;
        int shots;
        bool sliding, fired, hitDone;
        Transform muzzle, fistGlow;
        readonly List<Transform> wings = new List<Transform>();
        Material visorMat, wingMat;
        UKBeam laser;
        Vector3 aimPt;
        protected override string FirstState => "strafe";
        protected override float SpawnDur => 0.9f;
        float Spd => baseSpeed * (enraged ? 1.25f : 1);

        protected override void Init()
        {
            type = "v2"; enemyName = "V2"; maxHp = 42; radius = 0.45f; height = 2.0f; big = true; boss = true; killPts = 600; knockMul = 0.35f; parryDmg = 5; parryStun = 1.4f;
            baseSpeed = 12.5f * DSpeed; tint = 1;
            orbitDir = Random.value < 0.5f ? 1 : -1; orbitT = Random.Range(1.5f, 3f); atkCd = 1.2f; jumpCd = Random.Range(1f, 3f);
            var red = M(C(0xd8342a), 0.2f, UKFx.TexMetal);
            var metal = M(C(0xc0c6d2), 0.1f, UKFx.TexMachine);
            var dark = M(C(0x2c2e36), 0.06f, UKFx.TexMachine);
            H = UKHumanoid.Build(model, metal, dark, 0.05f, 0.44f, 0.58f, 0.28f, 0.28f, 1.02f, 1.08f, 1.1f, 0.72f);
            W.Box(H.head, 0.3f, 0.3f, 0.32f, red, 0, 0.16f, 0);
            visorMat = new Material(UKFx.Unlit(C(0xffe0a0)));
            gameObject.AddComponent<UKOwnMat>().m = visorMat;
            W.Box(H.head, 0.11f, 0.04f, 0.02f, visorMat, -0.06f, 0.2f, -0.165f, 0, 0, -0.35f, true);
            W.Box(H.head, 0.11f, 0.04f, 0.02f, visorMat, 0.06f, 0.2f, -0.165f, 0, 0, 0.35f, true);
            W.Box(H.spine, H.torsoW + 0.04f, 0.3f, H.torsoD + 0.04f, red, 0, H.torsoH * 0.72f, 0);
            W.Box(H.spine, 0.16f, 0.16f, 0.04f, visorMat, 0, H.torsoH * 0.62f, -H.torsoD / 2 - 0.03f, 0, 0, 0, true);
            foreach (var sh in new[] { H.shL, H.shR }) W.Box(sh, 0.2f, 0.14f, 0.24f, red, 0, 0.04f, 0);
            wingMat = new Material(UKFx.Unlit(C(0xffb040)));
            gameObject.AddComponent<UKOwnMat>().m = wingMat;
            foreach (var w in new[] { new Vector3(-0.2f, 0.62f, 0.7f), new Vector3(0.2f, 0.62f, -0.7f), new Vector3(-0.18f, 0.4f, 1.1f), new Vector3(0.18f, 0.4f, -1.1f) })
            {
                var j = W.J(H.spine, w.x, w.y, H.torsoD / 2 + 0.05f);
                j.localRotation = W.Q(0, 0, w.z);
                W.Box(j, 0.05f, 0.55f, 0.03f, wingMat, 0, 0.28f, 0, 0, 0, 0, true);
                wings.Add(j);
            }
            var gun = W.J(H.haR, 0, -0.1f, 0, "v2gun");
            W.Box(gun, 0.08f, 0.12f, 0.34f, dark, 0, 0, -0.14f);
            W.Cone(gun, 0.06f, 0.1f, red, 0, 0.02f, -0.08f, Mathf.PI / 2, 0, 0, false, 6);
            W.Box(gun, 0.05f, 0.14f, 0.06f, dark, 0, -0.1f, 0.02f);
            muzzle = W.J(gun, 0, 0.02f, -0.34f);
            gun.localRotation = W.Q(Mathf.PI / 2);
            W.Box(H.haL, 0.17f, 0.17f, 0.17f, red, 0, -0.06f, 0);
            fistGlow = W.Glow(H.haL, 0, 0, 0, 1, C(0x9fe0ff)).transform;
            fistGlow.localScale = Vector3.one * 0.01f;
            laser = new UKBeam("v2Laser");
        }

        protected override void Think(float dt)
        {
            var d = ToPlayer(out float dist, out float dy);
            var p = P;
            float aggro = Aggro * (enraged ? 1.35f : 1);
            atkCd -= dt; dashCd -= dt; jumpCd -= dt;
            if (!enraged && hp < maxHp * 0.5f && state == "strafe")
            {
                enraged = true;
                UKGame.I.hud.Message("V2 ÖFKELENDİ", 1.4f);
                UKAudio.I.PlayAt("bossRoar", transform.position, 1, 1.3f);
            }
            if (state != "aim") laser.Hide();
            switch (state)
            {
                case "strafe":
                    {
                        Face(d, 10, dt);
                        orbitT -= dt;
                        if (orbitT <= 0) { orbitT = Random.Range(1.2f, 2.6f); orbitDir *= -1; }
                        float want = dist > 16 ? 1 : dist < 8 ? -0.7f : 0;
                        float sp = Spd;
                        Vector3 tv = (d * want + Side(d) * orbitDir * 0.75f) * sp;
                        if (tv.sqrMagnitude > 0.01f && grounded && !GroundAhead(tv.normalized, 1.6f)) { orbitDir *= -1; tv = d * sp * 0.5f; }
                        if (blocked > 0.25f) { orbitDir *= -1; blocked = 0; if (grounded) { vel.y = 12; grounded = false; } }
                        AccelTo(tv, 40, dt);
                        sliding = grounded && want > 0;
                        if (jumpCd <= 0 && grounded) { jumpCd = Random.Range(1.8f, 3.5f); vel.y = 12; grounded = false; UKAudio.I.PlayAt("jump", transform.position, 1, 0.8f); }
                        if (dashCd <= 0 && canSee && dist < 18 && dist > 3 && Mathf.Abs(dy) < 2.5f)
                        {
                            dashCd = Random.Range(6f, 9f) / aggro;
                            SetState("dashWind");
                            UKAudio.I.PlayAt("windup", transform.position, 1, 1.3f);
                            break;
                        }
                        if (atkCd <= 0 && canSee)
                        {
                            if (dist < 6) SetState("shotgun");
                            else if (dist < 13 && Random.value < 0.55f) { SetState("nails"); shots = 0; }
                            else { SetState("aim"); UKAudio.I.PlayAt("chargeReady", transform.position, 1, 0.8f); }
                        }
                        break;
                    }
                case "aim":
                    {
                        Brake(25, dt);
                        Face(d, 12, dt);
                        float dur = 0.75f / aggro, lockT = dur - 0.2f;
                        Vector3 from = muzzle.position;
                        if (st < lockT) aimPt = p.transform.position + Vector3.up * 1.0f;
                        Vector3 dir = (aimPt - from).normalized;
                        bool lk = st >= lockT;
                        laser.Show(from, dir, Vector3.Distance(from, aimPt) + 30, lk ? 0.07f : 0.025f, new Color(1f, 0.19f, 0.13f, lk ? 0.9f : 0.35f + Mathf.Sin(st * 40) * 0.1f));
                        if (st >= dur)
                        {
                            laser.Hide();
                            var pr = Shoot(from, dir, 110, 22, C(0xff4020), 0.3f, UKProjectile.Kind.Bullet);
                            pr.parryable = false;
                            UKFx.I.Tracer(from, from + dir * 60, C(0xffa060), 0.06f, 0.15f);
                            UKAudio.I.PlayAt("revolver", from, 1, 0.85f);
                            UKFx.I.Glow(from, C(0xffd080), 1, 0.08f);
                            SetState("recover");
                            atkCd = Random.Range(1.1f, 1.8f) / aggro;
                        }
                        break;
                    }
                case "nails":
                    {
                        Face(d, 10, dt);
                        AccelTo(Side(d) * orbitDir * Spd * 0.5f, 30, dt);
                        int n = enraged ? 14 : 10;
                        while (shots < n && st >= 0.25f + shots * 0.06f)
                        {
                            float sp = 50 * DSpeed;
                            var dir = AimAt(muzzle.position, sp, 0.5f) + new Vector3(Random.Range(-0.05f, 0.05f), Random.Range(-0.04f, 0.04f), Random.Range(-0.05f, 0.05f));
                            Shoot(muzzle.position, dir.normalized, sp, 5, C(0xc0d0ff), 0.18f, UKProjectile.Kind.Bullet);
                            if (shots % 2 == 0) UKAudio.I.PlayAt("schismShot", muzzle.position, 0.6f, 2);
                            shots++;
                        }
                        if (st > 0.25f + n * 0.06f + 0.2f) { SetState("strafe"); atkCd = Random.Range(1.2f, 2f) / aggro; }
                        break;
                    }
                case "shotgun":
                    Face(d, 14, dt); Brake(30, dt);
                    if (!fired && st > 0.3f / aggro)
                    {
                        fired = true;
                        Vector3 from = muzzle.position;
                        var b = AimAt(from, 60, 0.2f);
                        for (int kk = 0; kk < 8; kk++)
                        {
                            var pr = Shoot(from, (b + new Vector3(Random.Range(-0.13f, 0.13f), Random.Range(-0.08f, 0.08f), Random.Range(-0.13f, 0.13f))).normalized, 60, 7, C(0xffb040), 0.2f, UKProjectile.Kind.Bullet);
                            pr.life = 0.6f;
                        }
                        UKAudio.I.PlayAt("bossShotgun", from);
                        UKFx.I.Glow(from, C(0xffd080), 1.4f, 0.1f);
                        vel.x -= d.x * 8; vel.z -= d.z * 8;
                    }
                    if (st > 0.6f) { fired = false; SetState("strafe"); atkCd = Random.Range(1f, 1.6f) / aggro; }
                    break;
                case "dashWind":
                    {
                        Face(d, 14, dt); Brake(30, dt);
                        float dur = 0.55f / aggro;
                        fistGlow.localScale = Vector3.one * (0.3f + 1.4f * Mathf.Clamp01(st / dur));
                        if (st > dur - 0.3f) SetParryable(true, H.haL.position);
                        if (st >= dur) { state = "dash"; st = 0; hitDone = false; vel.x = d.x * 30; vel.z = d.z * 30; UKAudio.I.PlayAt("dash", transform.position); }
                        break;
                    }
                case "dash":
                    if (st > 0.3f) SetParryable(false);
                    if (!hitDone && dist < 2.2f && MeleeHit(2.6f, 25, 0))
                    {
                        hitDone = true;
                        p.vel += d * 18; p.vel.y = Mathf.Max(p.vel.y, 8);
                    }
                    if (st > 0.4f) { fistGlow.localScale = Vector3.one * 0.01f; SetState("recover"); }
                    break;
                case "recover":
                    Brake(30, dt);
                    if (st > 0.3f) SetState("strafe");
                    break;
            }
            if (state != "strafe") sliding = false;
            if (state != "dashWind" && state != "dash") fistGlow.localScale = Vector3.one * 0.01f;
        }

        protected override void OnDied(float dmg, string weapon, bool head, Vector3 dir, bool silent) => laser.Destroy();
        public override void RemoveSilently() { laser?.Destroy(); base.RemoveSilently(); }

        protected override void Animate(float dt)
        {
            k = 1 - Mathf.Exp(-18 * dt);
            float hsp = HSpeed;
            walkPhase += hsp * dt * 1.2f;
            float amt = Mathf.Clamp01(hsp / 10);
            var f = Forward;
            float side = (f.x * vel.z - f.z * vel.x) / Mathf.Max(Spd, 0.01f);
            if (sliding)
            {
                Rot(H.hipL, 1.3f); Rot(H.hipR, 0.2f); Rot(H.knL, -0.2f); Rot(H.knR, -1.6f);
                Rot(H.spine, -0.35f);
                H.hips.localPosition = new Vector3(0, H.hipY - 0.35f, 0);
                if (Random.value < dt * 30) UKFx.I.Spark(transform.position, new Vector3(-vel.x, 2, -vel.z).normalized, 2, 5, C(0xffc060), 0.25f, 0.04f, 0.6f);
            }
            else
            {
                WalkPose(amt, 0.4f, 0);
                Rot(H.spine, -0.08f, 0, Mathf.Clamp(side * 0.25f, -0.3f, 0.3f));
                if (!grounded && state != "spawn") AirPose();
            }
            if (state != "spawn" && state != "stagger") { Rot(H.shR, -1.45f + lookPitch * 0.8f, 0, 0.1f); Rot(H.elR, 0.05f); }
            if (state == "dashWind") { Rot(H.shL, 0.6f, 0, -0.3f); Rot(H.elL, 1.6f); }
            else if (state == "dash") { Rot(H.shL, -1.5f, 0, -0.1f); Rot(H.elL, 0); }
            else if (state == "stagger") { Rot(H.spine, 0.35f); Rot(H.shL, -0.2f, 0, -0.5f); }
            float glow = 0.5f + 0.5f * Mathf.Sin(time * (enraged ? 16 : 6));
            var wc = new Color(1, 0.45f + glow * 0.35f, 0.15f + glow * 0.2f);
            if (wingMat.HasProperty("_Color")) wingMat.SetColor("_Color", wc);
            if (wingMat.HasProperty("_BaseColor")) wingMat.SetColor("_BaseColor", wc);
            for (int i = 0; i < wings.Count; i++) wings[i].localRotation = W.Q(-0.2f - amt * 0.4f + Mathf.Sin(time * 4 + i) * 0.05f, 0, i == 0 ? 0.7f : i == 1 ? -0.7f : i == 2 ? 1.1f : -1.1f);
            var vc = enraged ? (Mathf.Sin(time * 14) > 0 ? C(0xff4020) : C(0xffe0a0)) : C(0xffe0a0);
            if (visorMat.HasProperty("_Color")) visorMat.SetColor("_Color", vc);
            if (visorMat.HasProperty("_BaseColor")) visorMat.SetColor("_BaseColor", vc);
        }
    }
}
