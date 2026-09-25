// V1 hareket denetleyicisi (web sürümüyle aynı sabitler): koşu, zıplama, duvar sıçraması (3),
// atılma (dash, hasarsızlık, 3 stamina), kayma, yere çakma (slam) + çakış sıçrayışı, atılma zıplaması.
// Kamera: fare bakışı, yürüme salınımı, iniş çökmesi, eğim, sarsıntı, FOV vuruşu, darbe itmesi.
using UnityEngine;

namespace UK
{
    [RequireComponent(typeof(CharacterController))]
    public class UKPlayer : MonoBehaviour
    {
        // sabitler (m, m/s)
        const float RUN = 13.5f, GROUND_ACCEL = 130f, OVERSPEED_FRIC = 45f, AIR_ACCEL = 42f, G = 38f, JUMP = 15f;
        const float WJ_V = 13.5f, WJ_H = 11f, DASH_SPEED = 44f, DASH_TIME = 0.18f, DASHJUMP_H = 30f, DASHJUMP_V = 10.5f;
        const float SLIDE_SPEED = 22f, SLAM_SPEED = 85f, WALL_SLIDE = 5f, STAND_H = 1.8f, SLIDE_H = 0.85f;
        const float EYE_STAND = 1.55f, EYE_SLIDE = 0.62f, STAMINA_REGEN = 1.3f;

        public CharacterController cc;
        public Camera cam;
        public Transform eye;
        public float yaw, pitch;
        public Vector3 vel;
        public float hp = 100, maxHp = 100, hard, stamina = 3, iframes;
        public bool grounded, sliding, slamming, dead, frozen, v2;
        public float dashT, fovKick, trauma, hurtRoll, hurtPitch, camKick;
        public int wallJumps = 3;
        public Vector3 dashDir, slideDir, lastSafe;
        float slideSpeed, jumpBuffer, coyote, slamStartY, slamLandT = 99, slamStored, hardDelay, eyeH = EYE_STAND;
        float landDip, landVel, tilt, bob, bobT, stepT, safeT, airT, hurtCd;
        bool slideLock;

        public Vector3 EyePos => transform.position + Vector3.up * eyeH;
        public Vector3 AimDir => Quaternion.Euler(pitch, yaw, 0) * Vector3.forward;
        public float Bob => bob;
        public float BobT => bobT;

        public void Setup(Camera camera)
        {
            cc = GetComponent<CharacterController>();
            cc.height = STAND_H;
            cc.radius = 0.4f;
            cc.center = new Vector3(0, STAND_H / 2, 0);
            cc.stepOffset = 0.55f;
            cc.slopeLimit = 50f;
            cc.skinWidth = 0.04f;
            cc.minMoveDistance = 0f;
            eye = new GameObject("Eye").transform;
            eye.SetParent(transform, false);
            eye.localPosition = new Vector3(0, EYE_STAND, 0);
            cam = camera;
            cam.transform.SetParent(eye, false);
            cam.transform.localPosition = Vector3.zero;
            cam.transform.localRotation = Quaternion.identity;
        }

        public void ResetAt(Vector3 pos, float yawDeg)
        {
            cc.enabled = false;
            transform.position = pos;
            cc.enabled = true;
            yaw = yawDeg;
            pitch = 0;
            vel = Vector3.zero;
            maxHp = v2 ? 85 : 100;
            hp = maxHp;
            hard = 0;
            stamina = 3;
            dead = false;
            sliding = slamming = false;
            dashT = 0;
            iframes = 0.5f;
            wallJumps = 3;
            lastSafe = pos;
            SetHeight(STAND_H);
        }

        public void Teleport(Vector3 pos)
        {
            cc.enabled = false;
            transform.position = pos;
            cc.enabled = true;
            vel = Vector3.zero;
        }

        void SetHeight(float h)
        {
            cc.height = h;
            cc.center = new Vector3(0, h / 2, 0);
        }

        bool CanStand()
        {
            Vector3 p = transform.position;
            return !OverlapsWorld(p);
        }

        bool OverlapsWorld(Vector3 p)
        {
            var hits = Physics.OverlapCapsule(p + Vector3.up * 0.45f, p + Vector3.up * (STAND_H - 0.4f), 0.36f, ~0, QueryTriggerInteraction.Ignore);
            foreach (var h in hits) if (h != cc && h.GetComponent<UKHitbox>() == null) return true;
            return false;
        }

        // Yakındaki duvarın normali (duvar sıçraması / kayması)
        bool WallCheck(float extra, out Vector3 normal)
        {
            normal = Vector3.zero;
            float best = 99f;
            Vector3 o = transform.position + Vector3.up * 0.9f;
            for (int i = 0; i < 8; i++)
            {
                float a = i * Mathf.PI / 4;
                var d = new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a));
                if (Physics.Raycast(o, d, out var hit, cc.radius + extra, ~0, QueryTriggerInteraction.Ignore) && Mathf.Abs(hit.normal.y) < 0.3f && hit.collider != cc && hit.collider.GetComponent<UKHitbox>() == null && hit.distance < best)
                {
                    best = hit.distance;
                    normal = new Vector3(hit.normal.x, 0, hit.normal.z).normalized;
                }
            }
            return best < 99f;
        }

        public void Look(float dt, float friction)
        {
            if (dead || frozen) return;
            var s = UKGame.I.settings;
            Vector2 d = UKInput.MouseDelta * s.sensitivity * friction;
            yaw += d.x * 2.2f;
            pitch = Mathf.Clamp(pitch - d.y * 2.2f * (s.invertY ? -1 : 1), -89f, 89f);
        }

        public void Tick(float dt)
        {
            var game = UKGame.I;
            var au = UKAudio.I;
            iframes = Mathf.Max(0, iframes - dt);
            hurtCd = Mathf.Max(0, hurtCd - dt);
            slamLandT += dt;
            if (dashT <= 0) stamina = Mathf.Min(3, stamina + STAMINA_REGEN * (v2 ? 1.4f : 1f) * dt);
            hardDelay -= dt;
            if (hardDelay <= 0) hard = Mathf.Max(0, hard - 12 * dt);
            if (hp > maxHp - hard) hp = maxHp - hard;
            if (jumpBuffer > 0) jumpBuffer -= dt;
            if (coyote > 0) coyote -= dt;

            // istek yönü
            Vector3 fwd = Quaternion.Euler(0, yaw, 0) * Vector3.forward, right = Quaternion.Euler(0, yaw, 0) * Vector3.right;
            float mf = 0, ms = 0;
            if (!frozen && !dead)
            {
                if (UKInput.Held(UKKey.W)) mf += 1;
                if (UKInput.Held(UKKey.S)) mf -= 1;
                if (UKInput.Held(UKKey.D)) ms += 1;
                if (UKInput.Held(UKKey.A)) ms -= 1;
            }
            Vector3 wish = fwd * mf + right * ms;
            bool hasWish = wish.sqrMagnitude > 0.01f;
            if (hasWish) wish.Normalize();

            if (!frozen && !dead)
            {
                if (UKInput.Down(UKKey.Space)) jumpBuffer = 0.14f;
                // ATILMA
                if (UKInput.Down(UKKey.Shift) && stamina >= 1 && dashT <= 0)
                {
                    dashDir = hasWish ? wish : fwd;
                    dashT = DASH_TIME;
                    iframes = DASH_TIME + 0.05f;
                    stamina -= 1;
                    slamming = false;
                    EndSlide(true);
                    vel = dashDir * DASH_SPEED;
                    fovKick = 8;
                    game.weapons.OnMove("dash");
                    game.hud.SpeedLines();
                    au.Play("dash");
                    UKFx.I.Burst(transform.position + Vector3.up * 0.8f, 8, 10, new Color(0.6f, 0.8f, 1f), 0.25f, 0.05f, 0, -dashDir, 0.4f);
                }
                // KAYMA / ÇAKMA
                bool slideHeld = UKInput.Held(UKKey.C) || UKInput.Held(UKKey.Ctrl);
                bool slidePressed = UKInput.Down(UKKey.C) || UKInput.Down(UKKey.Ctrl);
                if (!slideHeld) slideLock = false;
                if (slidePressed && !grounded && coyote <= 0 && !slamming && dashT <= 0)
                {
                    slamming = true;
                    slamStartY = transform.position.y;
                    EndSlide(true);
                    vel = Vector3.down * SLAM_SPEED;
                    game.weapons.OnMove("slam");
                    au.Play("dash", 0.6f, 0.6f);
                }
                if (slideHeld && grounded && !sliding && !slideLock && dashT <= 0) StartSlide(hasWish ? wish : fwd);
                if (sliding && !slideHeld && CanStand()) EndSlide();
            }

            // fizik
            if (dashT > 0)
            {
                dashT -= dt;
                vel = new Vector3(dashDir.x * DASH_SPEED, grounded ? -2 : 0, dashDir.z * DASH_SPEED);
                if (dashT <= 0) { vel.x = dashDir.x * RUN * 1.1f; vel.z = dashDir.z * RUN * 1.1f; }
            }
            else if (slamming) vel = Vector3.down * SLAM_SPEED;
            else if (sliding)
            {
                if (hasWish) slideDir = Vector3.Lerp(slideDir, wish, Mathf.Min(1, dt * 1.5f)).normalized;
                vel.x = slideDir.x * slideSpeed;
                vel.z = slideDir.z * slideSpeed;
                vel.y -= G * dt;
                if (Random.value < dt * 25) UKFx.I.Burst(transform.position + Vector3.up * 0.05f, 1, 5, new Color(1f, 0.7f, 0.4f), 0.25f, 0.04f, 10, new Vector3(-slideDir.x, 0.4f, -slideDir.z), 0.5f);
            }
            else if (grounded)
            {
                float run = RUN * (v2 ? 1.12f : 1f);
                Vector3 target = wish * run;
                Vector3 h = new Vector3(vel.x, 0, vel.z);
                float sp = h.magnitude;
                if (sp > run + 0.5f)
                {
                    float ns = Mathf.Max(run, sp - OVERSPEED_FRIC * dt);
                    h *= ns / sp;
                    h = Vector3.Lerp(h, target, Mathf.Min(1, dt * 4));
                }
                else h = Vector3.MoveTowards(h, target, GROUND_ACCEL * dt);
                vel.x = h.x; vel.z = h.z;
                vel.y -= G * dt;
            }
            else
            {
                if (hasWish)
                {
                    float cur = vel.x * wish.x + vel.z * wish.z;
                    float add = Mathf.Min(AIR_ACCEL * dt, Mathf.Max(0, RUN * (v2 ? 1.12f : 1f) - cur));
                    vel.x += wish.x * add;
                    vel.z += wish.z * add;
                }
                vel.y -= G * dt;
                if (WallCheck(0.3f, out var wn) && vel.y < -WALL_SLIDE && hasWish && Vector3.Dot(wish, wn) < -0.2f)
                {
                    vel.y = Mathf.MoveTowards(vel.y, -WALL_SLIDE, 90 * dt);
                    if (Random.value < dt * 20) UKFx.I.Burst(transform.position + Vector3.up - wn * 0.4f, 1, 3, new Color(1f, 0.75f, 0.45f), 0.3f, 0.04f);
                }
            }
            vel.y = Mathf.Max(vel.y, -120);

            // ZIPLAMA
            if (jumpBuffer > 0 && !frozen && !dead)
            {
                if (grounded || coyote > 0) DoJump();
                else if (dashT <= 0 && !slamming && wallJumps > 0 && WallCheck(0.45f, out var wn))
                {
                    wallJumps--;
                    jumpBuffer = 0;
                    vel = wn * WJ_H + wish * 3 + Vector3.up * WJ_V;
                    game.weapons.OnMove("wall");
                    au.Play("walljump");
                    UKFx.I.Burst(transform.position + Vector3.up * 0.8f - wn * 0.4f, 8, 6, new Color(1f, 0.82f, 0.5f), 0.3f, 0.05f);
                }
            }

            // yükseklik
            float targetH = sliding ? SLIDE_H : STAND_H;
            if (targetH > cc.height) { if (CanStand()) SetHeight(targetH); }
            else if (targetH < cc.height) SetHeight(targetH);

            // hareket
            bool wasGrounded = grounded;
            float fallSpeed = -vel.y;
            var flags = cc.Move(vel * dt);
            if ((flags & CollisionFlags.Above) != 0 && vel.y > 0) vel.y = 0;
            if ((flags & CollisionFlags.Sides) != 0 && dashT > 0) { }
            bool g = (flags & CollisionFlags.Below) != 0 && vel.y <= 0.01f;
            if (!g && wasGrounded && vel.y <= 0 && jumpBuffer <= 0 && dashT <= 0 && !slamming)
            {
                // aşağı basamak yapıştırma
                if (Physics.Raycast(transform.position + Vector3.up * 0.1f, Vector3.down, out var hit, 0.75f, ~0, QueryTriggerInteraction.Ignore) && hit.collider != cc)
                {
                    cc.Move(Vector3.down * (hit.distance - 0.05f));
                    g = true;
                }
            }
            if (g)
            {
                if (!wasGrounded) OnLand(fallSpeed);
                grounded = true;
                vel.y = -1f;
                coyote = 0.1f;
                wallJumps = 3;
                airT = 0;
                safeT += dt;
                if (safeT > 0.25f && hurtCd <= 0) { lastSafe = transform.position; safeT = 0; }
            }
            else
            {
                if (wasGrounded && vel.y <= 0) coyote = 0.1f;
                grounded = false;
                airT += dt;
                if (sliding && airT > 0.15f) EndSlide();
            }
            au.Slide(sliding && grounded && !dead);

            // adımlar ve salınım
            float hsp = new Vector2(vel.x, vel.z).magnitude;
            if (grounded && !sliding && hsp > 3)
            {
                stepT += dt * hsp / RUN;
                if (stepT > 0.3f) { stepT = 0; au.Play("step"); }
                bobT += dt * hsp * 0.9f;
            }

            game.level.CheckHazards(this);
            if (transform.position.y < game.level.killY) OutOfBounds(35);

            // kamera etkileri
            eyeH = Mathf.Lerp(eyeH, sliding ? EYE_SLIDE : EYE_STAND, 1 - Mathf.Exp(-14 * dt));
            tilt = Mathf.Lerp(tilt, -ms * 2f + (sliding ? 2.3f : 0), 1 - Mathf.Exp(-8 * dt));
            landVel += (-landDip * 120 - landVel * 16) * dt;
            landDip += landVel * dt;
            fovKick = Mathf.Lerp(fovKick, 0, 1 - Mathf.Exp(-6 * dt));
            bob = Mathf.Lerp(bob, grounded && !sliding ? Mathf.Min(1, hsp / RUN) : 0, 1 - Mathf.Exp(-10 * dt));
        }

        void StartSlide(Vector3 dir)
        {
            sliding = true;
            slideDir = dir.normalized;
            float sp = new Vector2(vel.x, vel.z).magnitude;
            slideSpeed = Mathf.Max(SLIDE_SPEED, Mathf.Min(sp, 40));
            UKAudio.I.Play("dash", 0.4f);
        }

        void EndSlide(bool force = false)
        {
            if (!sliding) return;
            if (!force && !CanStand()) return;
            sliding = false;
        }

        void DoJump()
        {
            var au = UKAudio.I;
            jumpBuffer = 0;
            coyote = 0;
            if (dashT > 0)
            {
                // atılma zıplaması: uzun menzil
                float extra = stamina >= 1 ? 1 : 0;
                stamina -= extra;
                float k = extra > 0 ? 1 : 0.7f;
                vel = new Vector3(dashDir.x * DASHJUMP_H * k, DASHJUMP_V, dashDir.z * DASHJUMP_H * k);
                dashT = 0;
                au.Play("walljump");
            }
            else if (sliding)
            {
                vel.x = slideDir.x * slideSpeed;
                vel.z = slideDir.z * slideSpeed;
                vel.y = JUMP * 0.92f;
                EndSlide(true);
                slideLock = true;
                au.Play("jump");
            }
            else if (slamLandT < 0.18f)
            {
                // çakış sıçrayışı
                vel.y = JUMP + slamStored;
                UKFx.I.Ring(transform.position, new Color(1f, 0.82f, 0.5f), 2, 0.3f);
                au.Play("walljump");
                slamLandT = 99;
            }
            else
            {
                vel.y = JUMP;
                au.Play("jump");
            }
            grounded = false;
            UKGame.I.weapons.OnMove("jump");
        }

        void OnLand(float fallSpeed)
        {
            var game = UKGame.I;
            game.weapons.OnMove("land");
            if (slamming)
            {
                slamming = false;
                slamLandT = 0;
                float fall = Mathf.Max(0, slamStartY - transform.position.y);
                slamStored = Mathf.Min(4 + fall * 0.9f, 20);
                slideLock = true;
                Shake(0.55f);
                UKAudio.I.Play("slam");
                UKFx.I.Ring(transform.position, new Color(1f, 0.88f, 0.7f), 4 + Mathf.Min(fall * 0.3f, 4), 0.4f);
                UKFx.I.Burst(transform.position + Vector3.up * 0.1f, 20, 10, new Color(1f, 0.75f, 0.5f), 0.4f, 0.06f);
                game.OnSlamLand(transform.position, fall);
                landDip = -0.35f;
            }
            else if (fallSpeed > 38)
            {
                landDip = -0.4f;
                Shake(0.6f);
                UKAudio.I.Play("slam");
                UKFx.I.Ring(transform.position, new Color(1f, 0.75f, 0.5f), 6, 0.5f);
                UKFx.I.Burst(transform.position + Vector3.up * 0.1f, 30, 12, new Color(1f, 0.63f, 0.38f), 0.5f, 0.07f);
            }
            else if (fallSpeed > 12)
            {
                landDip = -Mathf.Min(0.3f, fallSpeed * 0.008f);
                UKAudio.I.Play("land", 1, fallSpeed > 22 ? 0.8f : 1);
                if (fallSpeed > 18) UKFx.I.Ring(transform.position, new Color(0.72f, 0.66f, 0.6f), 2 + fallSpeed * 0.05f, 0.35f);
            }
        }

        public void OutOfBounds(float dmg)
        {
            Teleport(lastSafe);
            slamming = false;
            EndSlide(true);
            hurtCd = 0.5f;
            if (dmg > 0) UKGame.I.DamagePlayer(dmg, null, true);
            UKGame.I.hud.Message("SINIR DIŞI", 1.2f);
        }

        public void LavaHit(float dmg)
        {
            if (hurtCd > 0) return;
            hurtCd = 0.45f;
            vel.y = 17;
            grounded = false;
            slamming = false;
            UKGame.I.DamagePlayer(dmg, null, true);
            UKAudio.I.Play("lava");
            UKFx.I.Burst(transform.position, 16, 8, new Color(1f, 0.5f, 0.12f), 0.5f, 0.08f);
        }

        public void Damage(float dmg)
        {
            hp -= dmg;
            hard = Mathf.Min(maxHp, hard + dmg * 0.35f);
            hardDelay = 1.2f;
        }

        public float Heal(float amount)
        {
            float cap = maxHp - hard;
            if (hp >= cap) return 0;
            float before = hp;
            hp = Mathf.Min(cap, hp + amount);
            return hp - before;
        }

        public void Shake(float amount) => trauma = Mathf.Min(1, trauma + amount);

        // kamera yerleşimi (her karede, ölçeklenmemiş zamanla)
        public void UpdateCamera(float realDt, float fovSetting, float deathK)
        {
            trauma = Mathf.Max(0, trauma - realDt * 1.6f);
            float sh = trauma * trauma * UKGame.I.settings.shake;
            hurtRoll = Mathf.Lerp(hurtRoll, 0, 1 - Mathf.Exp(-7 * realDt));
            hurtPitch = Mathf.Lerp(hurtPitch, 0, 1 - Mathf.Exp(-7 * realDt));
            camKick = Mathf.Lerp(camKick, 0, 1 - Mathf.Exp(-14 * realDt));
            float bobY = -Mathf.Abs(Mathf.Sin(bobT * 0.95f)) * 0.07f * bob;
            float bobX = Mathf.Sin(bobT * 0.95f) * 0.025f * bob;
            float e = eyeH + landDip + bobY;
            float roll = tilt - hurtRoll;
            if (dead) { e = Mathf.Lerp(eyeH, 0.25f, deathK); roll = 30f * deathK; }
            eye.localPosition = new Vector3(bobX + Random.Range(-1f, 1f) * sh * 0.2f, e + Random.Range(-1f, 1f) * sh * 0.2f, Random.Range(-1f, 1f) * sh * 0.2f);
            transform.rotation = Quaternion.Euler(0, yaw, 0);
            eye.localRotation = Quaternion.Euler(pitch - hurtPitch - camKick + Random.Range(-1f, 1f) * sh * 1.7f, Random.Range(-1f, 1f) * sh * 1.7f, roll + Random.Range(-1f, 1f) * sh * 2.3f);
            float fov = fovSetting + fovKick + (sliding ? 5 : 0);
            cam.fieldOfView = Mathf.Lerp(cam.fieldOfView, fov, 1 - Mathf.Exp(-12 * realDt));
        }
    }
}
