// Oyunun çekirdeği: sahneyi devralır (kamera, ışık, sis), oyuncuyu/silahları/bölümü kurar,
// durum makinesini (menü → intro → oyun → duraklat / ölüm → sonuç) ve savaş kurallarını yürütür:
// oyuncu hasarı, kanla iyileşme, PARRY, yumruk, patlama, nişan yardımı, vuruş donması, ağır çekim.
// ULTRAKILL sahnesinde (ya da kaydedilmemiş boş sahnede) Play'e basmak yeterlidir: UKGame kendiliğinden kurulur.
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace UK
{
    public class UKGame : MonoBehaviour
    {
        public static UKGame I;
        public enum State { Menu, Intro, Playing, Paused, Dead, Results }

        public class Settings
        {
            public float sensitivity = 1f, fov = 100f, volume = 0.8f, shake = 1f, aimAssist = 1f;
            public bool invertY;

            public static Settings Load()
            {
                var s = new Settings();
                s.sensitivity = PlayerPrefs.GetFloat("uk.sens", s.sensitivity);
                s.fov = PlayerPrefs.GetFloat("uk.fov", s.fov);
                s.volume = PlayerPrefs.GetFloat("uk.vol", s.volume);
                s.shake = PlayerPrefs.GetFloat("uk.shake", s.shake);
                s.aimAssist = PlayerPrefs.GetFloat("uk.assist", s.aimAssist);
                s.invertY = PlayerPrefs.GetInt("uk.invy", 0) == 1;
                return s;
            }

            public void Save()
            {
                PlayerPrefs.SetFloat("uk.sens", sensitivity);
                PlayerPrefs.SetFloat("uk.fov", fov);
                PlayerPrefs.SetFloat("uk.vol", volume);
                PlayerPrefs.SetFloat("uk.shake", shake);
                PlayerPrefs.SetFloat("uk.assist", aimAssist);
                PlayerPrefs.SetInt("uk.invy", invertY ? 1 : 0);
                PlayerPrefs.Save();
            }
        }

        public struct Difficulty { public string name, desc; public float dmg, speed, aggro; }
        public static readonly Difficulty[] DIFFS =
        {
            new Difficulty { name = "ZARARSIZ", desc = "Düşmanlar çok az hasar verir, yavaş saldırır.", dmg = 0.3f, speed = 0.75f, aggro = 0.6f },
            new Difficulty { name = "HOŞGÖRÜLÜ", desc = "Öğrenmek için rahat bir tempo.", dmg = 0.6f, speed = 0.88f, aggro = 0.8f },
            new Difficulty { name = "STANDART", desc = "Oyunun tasarlandığı gibi.", dmg = 1f, speed = 1f, aggro = 1f },
            new Difficulty { name = "ŞİDDETLİ", desc = "Daha hızlı, daha acımasız.", dmg = 1.4f, speed = 1.15f, aggro = 1.3f },
        };

        public class Results
        {
            public float time, style;
            public int kills, total, restarts;
            public string timeRank, killRank, styleRank, final;
        }

        public State state = State.Menu;
        public Settings settings;
        public int diffIndex = 2;
        public Difficulty Diff => DIFFS[Mathf.Clamp(diffIndex, 0, DIFFS.Length - 1)];
        public UKPlayer player;
        public UKWeapons weapons;
        public UKHud hud;
        public UKLevel level;
        public readonly UKStyle style = new UKStyle();
        public Camera cam;
        public float parryBuffer, runTime, deathT, resultsT;
        public int kills, restarts;
        public Results results;
        public bool introSeen;
        Vector3 checkpoint;
        float checkpointYaw, hitstopT, slowT, slowK = 1, screamT = -1, menuT;
        int screams;
        readonly List<KeyValuePair<float, System.Action>> sched = new List<KeyValuePair<float, System.Action>>();

        // ölüm ekranındaki kafatasının çığlık miktarı (0..1)
        public float ScreamK => screamT >= 0 && screamT < 0.9f ? Mathf.Sin(Mathf.Clamp01(screamT / 0.9f) * Mathf.PI) : 0;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void AutoBoot()
        {
            if (I != null) return;
            // Aynı projedeki başka oyunların sahnelerini ele geçirme: yalnız "ULTRAKILL" adlı sahnede
            // ya da kaydedilmemiş boş sahnede (yeni açılmış proje) kendiliğinden kurul.
            var scene = SceneManager.GetActiveScene();
            bool ours = scene.name == "ULTRAKILL";
            bool blank = string.IsNullOrEmpty(scene.path) && scene.rootCount <= 3;
            if (!ours && !blank) return;
            new GameObject("ULTRAKILL").AddComponent<UKGame>();
        }

        // ------------------------------------------------------------ kurulum
        void Awake()
        {
            if (I != null && I != this) { Destroy(gameObject); return; }
            I = this;
            UKEnemy.All.Clear();
            UKProjectile.All.Clear();
            UKInput.Blocked = true;
            settings = Settings.Load();
            if (!UKInput.Available)
                Debug.LogError("ULTRAKILL: Etkin girdi sistemi yok. Project Settings > Player > Active Input Handling = 'Both' (ya da 'Input Manager (Old)') yapın veya Input System paketini kurun.");
            diffIndex = Mathf.Clamp(PlayerPrefs.GetInt("uk.diff", 2), 0, DIFFS.Length - 1);
            UKFx.Init();
            new GameObject("UKFx").AddComponent<UKFx>();
            new GameObject("UKAudio").AddComponent<UKAudio>();
            SetupScene();
            var pgo = new GameObject("V1");
            player = pgo.AddComponent<UKPlayer>();
            player.Setup(cam);
            weapons = pgo.AddComponent<UKWeapons>();
            weapons.Setup(cam);
            hud = gameObject.AddComponent<UKHud>();
            level = new GameObject("World").AddComponent<UKLevel>();
            ToMenu();
        }

        void SetupScene()
        {
            // sahnedeki ışıkları kapat (sürümden bağımsız: kök nesnelerden tara)
            var lights = new List<Light>();
            var listeners = new List<AudioListener>();
            foreach (var root in gameObject.scene.GetRootGameObjects())
            {
                lights.AddRange(root.GetComponentsInChildren<Light>(true));
                listeners.AddRange(root.GetComponentsInChildren<AudioListener>(true));
            }
            foreach (var l in lights) l.enabled = false;
            cam = Camera.main;
            if (cam == null)
            {
                var cgo = new GameObject("Main Camera") { tag = "MainCamera" };
                cam = cgo.AddComponent<Camera>();
            }
            foreach (var al in listeners) if (al.gameObject != cam.gameObject) al.enabled = false;
            if (cam.GetComponent<AudioListener>() == null) cam.gameObject.AddComponent<AudioListener>();
            var fog = new Color(0.12f, 0.04f, 0.035f);
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = fog;
            cam.nearClipPlane = UKFx.SRP ? 0.03f : 0.05f;
            cam.farClipPlane = 500f;
            cam.depth = 0;
            var sun = new GameObject("Sun").AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.color = new Color(1f, 0.78f, 0.62f);
            sun.intensity = 0.55f;
            sun.shadows = LightShadows.None;
            sun.transform.rotation = Quaternion.Euler(55, -35, 0);
            RenderSettings.skybox = null;
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.36f, 0.26f, 0.24f);
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogStartDistance = 25f;
            RenderSettings.fogEndDistance = 170f;
            RenderSettings.fogColor = fog;
            QualitySettings.pixelLightCount = Mathf.Max(QualitySettings.pixelLightCount, 8);
        }

        // ------------------------------------------------------------ durum geçişleri
        public void ToMenu()
        {
            ClearCombat();
            level.Build();
            state = State.Menu;
            hud.panel = UKHud.Panel.Main;
            hud.ResetAll();
            player.ResetAt(level.startCheckpoint, 0);
            player.frozen = true;
            weapons.SetVisible(false);
            UKAudio.I.Slide(false);
            menuT = 0;
        }

        public void StartNew()
        {
            if (!introSeen)
            {
                introSeen = true;
                state = State.Intro;
                hud.StartIntro();
                return;
            }
            BeginLevel();
        }

        // Bölümü baştan başlat: üsten bacadan aşağı düşerek iniş
        public void BeginLevel()
        {
            ClearCombat();
            level.Build();
            style.Reset(true);
            runTime = 0;
            kills = 0;
            restarts = 0;
            results = null;
            checkpoint = level.startCheckpoint;
            checkpointYaw = 0;
            ResetCamera();
            player.ResetAt(level.spawnPos, 0);
            player.frozen = false;
            player.pitch = 35;
            player.vel = Vector3.down * 6;
            weapons.ResetAll();
            weapons.SetVisible(true);
            hud.ResetAll();
            hud.panel = UKHud.Panel.Main;
            hud.Title(level.layerName, level.levelId + " " + level.levelName, 3.2f);
            hud.SpeedLines(1.2f);
            UKAudio.I.Play("dash", 0.7f, 0.5f, true);
            state = State.Playing;
        }

        public void Pause()
        {
            if (state != State.Playing) return;
            state = State.Paused;
            hud.panel = UKHud.Panel.Main;
            UKAudio.I.Slide(false);
        }

        public void Resume()
        {
            if (state != State.Paused) return;
            state = State.Playing;
        }

        // Son kontrol noktasından devam (ölüm ekranı ya da duraklatma menüsü)
        public void Respawn()
        {
            ClearCombat();
            level.ResetUnfinishedArenas();
            restarts++;
            style.Reset(false);
            ResetCamera();
            player.ResetAt(checkpoint, checkpointYaw);
            player.frozen = false;
            weapons.ResetAll();
            weapons.SetVisible(true);
            hud.ResetAll();
            deathT = 0;
            screamT = -1;
            state = State.Playing;
        }

        public void SetCheckpoint(Vector3 pos, float yaw)
        {
            checkpoint = pos;
            checkpointYaw = yaw;
        }

        public void FinishLevel()
        {
            if (state != State.Playing) return;
            state = State.Results;
            resultsT = 0;
            style.frozen = true;
            var lv = level;
            var r = new Results { time = runTime, kills = kills, total = lv.TotalEnemies, style = style.total, restarts = restarts };
            r.timeRank = r.time <= lv.timeThresh[0] ? "S" : r.time <= lv.timeThresh[1] ? "A" : r.time <= lv.timeThresh[2] ? "B" : r.time <= lv.timeThresh[3] ? "C" : "D";
            r.styleRank = r.style >= lv.styleThresh[0] ? "S" : r.style >= lv.styleThresh[1] ? "A" : r.style >= lv.styleThresh[2] ? "B" : r.style >= lv.styleThresh[3] ? "C" : "D";
            float kf = r.kills / (float)Mathf.Max(1, r.total);
            r.killRank = kf >= 1 ? "S" : kf >= 0.9f ? "A" : kf >= 0.75f ? "B" : kf >= 0.5f ? "C" : "D";
            const string ORDER = "DCBAS";
            int a = ORDER.IndexOf(r.timeRank), b = ORDER.IndexOf(r.killRank), c = ORDER.IndexOf(r.styleRank);
            if (a == 4 && b == 4 && c == 4 && r.restarts == 0) r.final = "P";
            else r.final = ORDER[Mathf.Min(4, Mathf.RoundToInt((a + b + c) / 3f))].ToString();
            results = r;
            string key = "uk.best." + lv.levelId;
            string best = PlayerPrefs.GetString(key, "");
            if (best == "" || "DCBASP".IndexOf(r.final) > "DCBASP".IndexOf(best)) { PlayerPrefs.SetString(key, r.final); PlayerPrefs.Save(); }
            weapons.SetVisible(false);
            UKAudio.I.Slide(false);
            UKAudio.I.Play("secret");
            player.cc.enabled = false;
            player.vel = new Vector3(0, Mathf.Min(player.vel.y, -12), 0);
        }

        void PlayerDie()
        {
            var p = player;
            p.dead = true;
            p.hp = 0;
            p.sliding = p.slamming = false;
            state = State.Dead;
            deathT = 0;
            screamT = -1;
            screams = 0;
            parryBuffer = 0;
            weapons.SetVisible(false);
            UKAudio.I.Slide(false);
            UKAudio.I.Play("death");
            UKFx.I.Blood(p.EyePos, 40, 8);
            p.Shake(0.6f);
        }

        void ClearCombat()
        {
            var list = new List<UKEnemy>(UKEnemy.All);
            foreach (var e in list) if (e) e.RemoveSilently();
            UKEnemy.All.Clear();
            UKProjectile.ClearAll();
            if (UKFx.I) UKFx.I.ClearAll();
            sched.Clear();
            hitstopT = slowT = 0;
            parryBuffer = 0;
            Time.timeScale = 1;
        }

        void ResetCamera()
        {
            cam.transform.localPosition = Vector3.zero;
            cam.transform.localRotation = Quaternion.identity;
        }

        // ------------------------------------------------------------ zaman
        public void Schedule(float delay, System.Action a) => sched.Add(new KeyValuePair<float, System.Action>(delay, a));
        public void Hitstop(float t) { if (state == State.Playing) hitstopT = Mathf.Max(hitstopT, t); }
        public void SlowMo(float t, float k) { slowT = t; slowK = k; }

        void RunSchedule(float dt)
        {
            if (sched.Count == 0) return;
            var due = new List<System.Action>();
            for (int i = sched.Count - 1; i >= 0; i--)
            {
                float t = sched[i].Key - dt;
                if (t <= 0) { due.Add(sched[i].Value); sched.RemoveAt(i); }
                else sched[i] = new KeyValuePair<float, System.Action>(t, sched[i].Value);
            }
            for (int i = due.Count - 1; i >= 0; i--) due[i]();
        }

        // ------------------------------------------------------------ döngü
        void Update()
        {
            if (I != this) return;
            float rdt = Mathf.Min(Time.unscaledDeltaTime, 0.1f);
            UKInput.Blocked = state != State.Playing;
            UKAudio.I.master = settings.volume;

            if (state == State.Playing)
            {
                if (hitstopT > 0) { hitstopT -= rdt; Time.timeScale = 0f; }
                else if (slowT > 0) { slowT -= rdt; Time.timeScale = slowK; }
                else Time.timeScale = 1f;
            }
            else if (state == State.Paused) Time.timeScale = 0f;
            else if (state == State.Dead) Time.timeScale = Mathf.Lerp(0.3f, 1f, Mathf.Clamp01(deathT / 1.2f));
            else Time.timeScale = 1f;

            bool locked = state == State.Playing;
            Cursor.lockState = locked ? CursorLockMode.Locked : CursorLockMode.None;
            Cursor.visible = !locked;

            float dt = Time.deltaTime;
            switch (state)
            {
                case State.Menu:
                    menuT += rdt;
                    break;
                case State.Playing:
                    if (UKInput.DownUnblocked(UKKey.Esc)) { Pause(); break; }
                    player.Look(rdt, 1f);
                    if (dt > 0) player.Tick(dt);
                    if (state != State.Playing) break;
                    weapons.Tick(dt);
                    style.Tick(dt, weapons.CurKey);
                    if (parryBuffer > 0)
                    {
                        parryBuffer -= dt;
                        if (TryParry(true)) parryBuffer = 0;
                    }
                    runTime += dt;
                    RunSchedule(dt);
                    break;
                case State.Paused:
                    if (UKInput.DownUnblocked(UKKey.Esc)) Resume();
                    break;
                case State.Dead:
                    deathT += rdt;
                    // kafatası çığlığı: ilk açılışta, sonra bir kez daha
                    if (screams == 0 && deathT > 0.45f || screams == 1 && deathT > 2.6f)
                    {
                        screams++;
                        screamT = 0;
                        UKAudio.I.Play("skullScream", 1f, screams == 1 ? 1f : 0.92f, true);
                    }
                    if (screamT >= 0) screamT += rdt;
                    if (deathT > 1f && (UKInput.DownUnblocked(UKKey.R) || UKInput.DownUnblocked(UKKey.Mouse0) || UKInput.DownUnblocked(UKKey.Enter) || UKInput.DownUnblocked(UKKey.Space))) Respawn();
                    break;
                case State.Results:
                    resultsT += rdt;
                    FallTick(rdt);
                    if (resultsT > 3.5f)
                    {
                        if (UKInput.DownUnblocked(UKKey.R)) BeginLevel();
                        else if (UKInput.DownUnblocked(UKKey.Mouse0) || UKInput.DownUnblocked(UKKey.Enter)) ToMenu();
                    }
                    break;
            }
            level.Tick(dt);
        }

        // Sonuç ekranı: kapaktan sonsuz bacada düşüş (her 100 m'de bir yukarı sarılır)
        void FallTick(float dt)
        {
            var p = player;
            p.vel.y = Mathf.Max(p.vel.y - 38f * dt, -55f);
            var pos = p.transform.position;
            pos.y += p.vel.y * dt;
            pos.x = Mathf.Lerp(pos.x, 0, dt * 2);
            pos.z = Mathf.Lerp(pos.z, 154, dt * 2);
            if (pos.y < -170) pos.y += 100;
            p.transform.position = pos;
            p.pitch = Mathf.Lerp(p.pitch, 82f, dt * 1.5f);
            p.yaw += dt * 25f;
        }

        void LateUpdate()
        {
            if (I != this) return;
            float rdt = Mathf.Min(Time.unscaledDeltaTime, 0.1f);
            float vf = VFov(settings.fov);
            if (state == State.Playing || state == State.Dead)
                player.UpdateCamera(rdt, vf, state == State.Dead ? Mathf.Clamp01(deathT / 0.6f) : 0);
            else if (state == State.Results)
                player.UpdateCamera(rdt, vf + 8, 0);
            else if (state == State.Menu || state == State.Intro)
            {
                float a = menuT * 0.12f;
                var c = level.menuCamCenter;
                cam.transform.position = c + new Vector3(Mathf.Sin(a) * 13f, 2.5f + Mathf.Sin(menuT * 0.3f) * 0.8f, Mathf.Cos(a) * 13f);
                cam.transform.rotation = Quaternion.LookRotation(c - cam.transform.position);
                cam.fieldOfView = 60;
            }
        }

        float VFov(float hfov)
        {
            float aspect = cam.aspect > 0.01f ? cam.aspect : 16f / 9f;
            return 2f * Mathf.Atan(Mathf.Tan(hfov * Mathf.Deg2Rad / 2f) / aspect) * Mathf.Rad2Deg;
        }

        void OnApplicationFocus(bool focus)
        {
            if (!focus && state == State.Playing) Pause();
        }

        void OnDestroy()
        {
            if (I == this) { I = null; Time.timeScale = 1; }
        }

        // ------------------------------------------------------------ savaş kuralları
        public bool DamagePlayer(float dmg, Vector3? from, bool force)
        {
            var p = player;
            if (p.dead || state != State.Playing) return false;
            if (!force && p.iframes > 0) return false;
            p.Damage(dmg);
            style.OnDamageTaken(dmg);
            float? ang = null;
            if (from.HasValue)
            {
                Vector3 d = from.Value - p.transform.position;
                d.y = 0;
                if (d.sqrMagnitude > 0.01f)
                {
                    Vector3 f = Quaternion.Euler(0, p.yaw, 0) * Vector3.forward, r = Quaternion.Euler(0, p.yaw, 0) * Vector3.right;
                    float a = Mathf.Atan2(Vector3.Dot(d, r), Vector3.Dot(d, f));
                    ang = a;
                    // darbe kamerayı saldırıdan uzağa iter
                    p.hurtRoll += Mathf.Sin(a) * Mathf.Min(5f, 1.7f + dmg * 0.11f);
                    p.hurtPitch += Mathf.Cos(a) * Mathf.Min(3.4f, 1.1f + dmg * 0.09f);
                    Vector3 push = -d.normalized;
                    p.vel.x += push.x * 6;
                    p.vel.z += push.z * 6;
                }
            }
            hud.Hurt(dmg, ang);
            p.Shake(0.22f + Mathf.Min(dmg, 40) * 0.008f);
            UKAudio.I.Play("hurt");
            if (p.hp <= 0) PlayerDie();
            return true;
        }

        // Yakında dökülen kan canı doldurur (ULTRAKILL'in temel kuralı)
        public void BloodHeal(Vector3 pt, float dmg)
        {
            var p = player;
            if (p.dead || state != State.Playing) return;
            float d = Vector3.Distance(pt, p.EyePos);
            if (d >= 8) return;
            float amt = dmg * 32 * (1 - d / 8) + 1.5f;
            if (p.Heal(amt) > 0.5f) { UKAudio.I.Play("heal", 0.6f); hud.HealFlash(); }
        }

        public void OnSlamLand(Vector3 pos, float fall)
        {
            var list = new List<UKEnemy>(UKEnemy.All);
            foreach (var e in list)
            {
                if (e.dead || e.State == "spawn") continue;
                Vector3 d = e.transform.position - pos;
                float dy = d.y;
                d.y = 0;
                float dist = d.magnitude;
                if (dist < 4 && Mathf.Abs(dy) < 1.5f)
                {
                    e.Launch(e.boss ? 4 : 11);
                    var dir = new Vector3(d.x / Mathf.Max(dist, 0.01f), 0.5f, d.z / Mathf.Max(dist, 0.01f));
                    e.Hit(0.25f, e.Center, dir, false, "slam", 6);
                }
            }
        }

        public void OnEnemyKilled(UKEnemy e)
        {
            kills++;
            level.OnEnemyKilled(e);
        }

        // fromPlayer = true → oyuncuya zarar vermez (savuşturulmuş küre, drone enkazı)
        public void Explode(Vector3 pos, float radius, float dmg, bool fromPlayer, float playerDmg)
        {
            UKFx.I.Explosion(pos, radius * 0.7f);
            // yanık izi yalnız yakında zemin varsa
            if (Physics.Raycast(pos + Vector3.up * 0.2f, Vector3.down, out var ground, 2.2f, ~0, QueryTriggerInteraction.Ignore) && !(ground.collider is CharacterController))
                UKFx.I.Decal(ground.point, ground.normal, radius * 0.5f);
            UKAudio.I.PlayAt("explosion", pos);
            var list = new List<UKEnemy>(UKEnemy.All);
            foreach (var e in list)
            {
                if (e.dead) continue;
                Vector3 c = e.Center;
                float dist = Vector3.Distance(c, pos), rr = radius + e.radius;
                if (dist >= rr) continue;
                float f = 1 - dist / rr * 0.6f;
                Vector3 dir = ((c - pos).normalized + Vector3.up * 0.4f).normalized;
                e.Hit(dmg * f, c, dir, false, "explosion", 14 * f);
            }
            var p = player;
            if (p.dead) return;
            Vector3 pc = p.transform.position + Vector3.up * 0.9f;
            float pd = Vector3.Distance(pc, pos);
            p.Shake(Mathf.Clamp01(1 - pd / (radius * 4)) * 0.6f);
            if (pd < radius)
            {
                float f = 1 - pd / radius;
                Vector3 dir = (pc - pos).normalized;
                p.vel += dir * (10 + 14 * f);
                p.vel.y = Mathf.Max(p.vel.y, 6 + 8 * f);
                if (!fromPlayer && playerDmg > 0) DamagePlayer(playerDmg * f, pos, true);
            }
        }

        // Nişan yardımı: nişangâh zaten bir düşmana değmiyorsa, koninin içindeki görünen en yakın düşmana büker
        public Vector3 AssistDir(Vector3 o, Vector3 d, float maxA)
        {
            float assist = settings.aimAssist;
            if (assist <= 0.01f) return d;
            if (UKWeapons.Hitscan(o, d, 300, out _, out var box) && box != null) return d;
            float bestA = 999;
            Vector3 best = d;
            foreach (var e in UKEnemy.All)
            {
                if (e.dead || e.State == "spawn") continue;
                Vector3 to = e.Center - o;
                float dist = to.magnitude;
                if (dist < 0.5f || dist > 120) continue;
                to /= dist;
                float ang = Mathf.Acos(Mathf.Clamp(Vector3.Dot(d, to), -1f, 1f));
                float lim = maxA * assist + Mathf.Atan2(e.radius * 1.2f, dist);
                if (ang > lim || ang >= bestA) continue;
                if (!UKWeapons.Hitscan(o, to, dist + 1, out _, out var b2) || b2 == null || b2.owner != e) continue;
                bestA = ang;
                best = to;
            }
            return best;
        }

        // PARRY: önce düşman mermileri, sonra parlayan yakın saldırılar, en son oyuncunun çekirdeği (hızlandırma)
        public bool TryParry(bool buffered = false)
        {
            var p = player;
            Vector3 o = p.EyePos, d = p.AimDir;
            var list = new List<UKProjectile>();
            foreach (var pr in UKProjectile.All)
            {
                if (pr.dead || pr.fromPlayer || !pr.parryable) continue;
                Vector3 v = pr.transform.position - o;
                float dist = v.magnitude;
                if (dist > 7) continue;
                float dot = Vector3.Dot(v, d) / Mathf.Max(dist, 0.001f);
                if (dot > 0.2f || dist < 2.4f) list.Add(pr);
            }
            if (list.Count > 0)
            {
                Vector3 aim = AssistDir(o, d, 0.5f);
                Vector3 target = o + aim * 300;
                UKEnemy targetEnemy = null;
                if (UKWeapons.Hitscan(o, aim, 300, out var h, out var hb))
                {
                    target = h.point;
                    if (hb != null) targetEnemy = hb.owner;
                }
                foreach (var pr in list)
                {
                    Vector3 dir = (target - pr.transform.position).normalized;
                    pr.Parry(dir, Mathf.Max(pr.vel.magnitude * 1.8f, 65f), targetEnemy);
                }
                OnParry(list[0].transform.position, false);
                return true;
            }
            UKEnemy best = null;
            float bd = 1e9f;
            foreach (var e in UKEnemy.All)
            {
                if (e.dead || !e.parryable) continue;
                Vector3 c = e.Center;
                float dist = Vector3.Distance(c, o);
                if (dist > 6.5f + e.radius) continue;
                float dot = Vector3.Dot((c - o).normalized, d);
                if (dot < 0.15f && dist > 2.6f) continue;
                float score = dist * (1.6f - dot);
                if (score < bd) { bd = score; best = e; }
            }
            if (best != null)
            {
                Vector3 pos = best.Center;
                best.Parried(d);
                OnParry(pos, true);
                return true;
            }
            if (buffered) return false;
            foreach (var pr in UKProjectile.All)
            {
                if (pr.dead || !pr.fromPlayer || pr.kind != UKProjectile.Kind.Core) continue;
                Vector3 v = pr.transform.position - o;
                float dist = v.magnitude;
                if (dist < 5.5f && Vector3.Dot(v, d) / Mathf.Max(dist, 0.001f) > 0.2f)
                {
                    pr.vel = AssistDir(o, d, 0.2f) * 70f;
                    pr.gravity = 4;
                    style.Add("PROJECTILE BOOST", 90, "shotgun");
                    Hitstop(0.06f);
                    UKAudio.I.PlayAt("punchHit", pr.transform.position);
                    UKFx.I.Glow(pr.transform.position, Color.white, 2, 0.2f, 1.6f);
                    return true;
                }
            }
            return false;
        }

        // Özel parry efekti: donma, beyaz-yeşil patlama, ışık, kol animasyonu, tam can. (Ekranda "PARRY!" yazısı yok.)
        void OnParry(Vector3 pos, bool melee)
        {
            var p = player;
            Hitstop(melee ? 0.16f : 0.11f);
            weapons.ParryAnim();
            UKAudio.I.Play("parry");
            UKFx.I.Glow(pos, new Color(1f, 1f, 1f, 0.95f), 2.6f, 0.22f, 2.2f);
            UKFx.I.Glow(pos, new Color(0.45f, 1f, 0.6f, 0.7f), 4.2f, 0.32f, 1.8f);
            UKFx.I.Burst(pos, 26, 14, new Color(0.75f, 1f, 0.82f), 0.4f, 0.06f, 0);
            UKFx.I.Flash(pos, new Color(0.6f, 1f, 0.7f), 6, 12, 0.18f);
            hud.Flash(new Color(1f, 1f, 1f, 0.3f), 0.14f);
            p.hard = 0;
            p.hp = p.maxHp;
            hud.HealFlash();
            style.Add("PARRY", 100, null);
            p.Shake(0.3f);
            p.camKick += 2f;
        }

        // Feedbacker yumruğu: öndeki en yakın düşmana
        public bool MeleePunch()
        {
            var p = player;
            Vector3 o = p.EyePos, d = p.AimDir;
            UKEnemy best = null;
            float bd = 99;
            foreach (var e in UKEnemy.All)
            {
                if (e.dead || e.State == "spawn") continue;
                Vector3 to = e.Center - o;
                float dist = to.magnitude - e.radius;
                if (dist > 2.6f) continue;
                if (Vector3.Dot(to.normalized, d) < 0.4f && dist > 1f) continue;
                if (dist < bd) { bd = dist; best = e; }
            }
            if (best == null) return false;
            Vector3 pt = best.Center - (best.Center - o).normalized * best.radius;
            best.Hit(1f, pt, d, false, "punch", 14);
            UKAudio.I.Play("punchHit");
            Hitstop(0.05f);
            p.Shake(0.2f);
            UKFx.I.Burst(pt, 12, 8, new Color(1f, 0.9f, 0.7f), 0.25f, 0.05f);
            return true;
        }
    }
}
