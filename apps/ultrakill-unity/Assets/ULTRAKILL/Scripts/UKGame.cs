// Oyunun çekirdeği: sahneyi devralır (kamera, ışık, sis), oyuncuyu/silahları/bölümü kurar ve durum
// makinesini yürütür (menü → intro → oyun ⇄ duraklat / dükkân → ölüm → sonuç). Web sürümündeki
// main.js'in karşılığıdır: bölüm yükleme, üsten iniş, checkpoint ve P (stil parası) kasası, dükkân,
// gizli küreler, silah sunakları, bölüm sonu sıralaması ve meydan okuma, Siber Öğütücü, ilerleme kaydı.
// Savaş kuralları: oyuncu hasarı, kanla iyileşme, PARRY (mermi / parlayan saldırı / PROJECTILE BOOST /
// COIN PUNCH), parry yardımı (ağır çekim), yumruk ve SHOTGUN PARRY, patlama, nişan yardımı.
// ULTRAKILL sahnesinde (ya da kaydedilmemiş boş sahnede) Play'e basmak yeterlidir: UKGame kendiliğinden kurulur.
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace UK
{
    public class UKGame : MonoBehaviour
    {
        public static UKGame I;
        public enum State { Menu, Intro, Playing, Paused, Shop, Dead, Results }

        public class Settings
        {
            public float sensitivity = 1f, fov = 100f, volume = 0.8f, music = 0.7f, shake = 1f, aimAssist = 1f;
            public int parryAssist = 1, coinAssist = 1;
            public bool invertY, allWeapons, v2;

            public static Settings Load()
            {
                var s = new Settings();
                s.sensitivity = PlayerPrefs.GetFloat("uk.sens", s.sensitivity);
                s.fov = PlayerPrefs.GetFloat("uk.fov", s.fov);
                s.volume = PlayerPrefs.GetFloat("uk.vol", s.volume);
                s.music = PlayerPrefs.GetFloat("uk.music", s.music);
                s.shake = PlayerPrefs.GetFloat("uk.shake", s.shake);
                s.aimAssist = PlayerPrefs.GetFloat("uk.assist", s.aimAssist);
                s.parryAssist = PlayerPrefs.GetInt("uk.parryAssist", s.parryAssist);
                s.coinAssist = PlayerPrefs.GetInt("uk.coinAssist", s.coinAssist);
                s.invertY = PlayerPrefs.GetInt("uk.invy", 0) == 1;
                s.allWeapons = PlayerPrefs.GetInt("uk.allWeapons", 0) == 1;
                s.v2 = PlayerPrefs.GetInt("uk.v2", 0) == 1;
                return s;
            }

            public void Save()
            {
                PlayerPrefs.SetFloat("uk.sens", sensitivity);
                PlayerPrefs.SetFloat("uk.fov", fov);
                PlayerPrefs.SetFloat("uk.vol", volume);
                PlayerPrefs.SetFloat("uk.music", music);
                PlayerPrefs.SetFloat("uk.shake", shake);
                PlayerPrefs.SetFloat("uk.assist", aimAssist);
                PlayerPrefs.SetInt("uk.parryAssist", parryAssist);
                PlayerPrefs.SetInt("uk.coinAssist", coinAssist);
                PlayerPrefs.SetInt("uk.invy", invertY ? 1 : 0);
                PlayerPrefs.SetInt("uk.allWeapons", allWeapons ? 1 : 0);
                PlayerPrefs.SetInt("uk.v2", v2 ? 1 : 0);
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

        public class Stats { public float time, damageTaken; public int kills, restarts, secrets, parries, droneParries, tanks; }

        public State state = State.Menu;
        public Settings settings;
        public UKProgress progress;
        public Stats stats = new Stats();
        public int diffIndex = 2, levelIdx = -1, cgWave, bonusP, levelP, lostP;
        public Difficulty Diff => DIFFS[Mathf.Clamp(diffIndex, 0, DIFFS.Length - 1)];
        public UKLevelDef LevelDef => UKLevelDefs.LEVELS[Mathf.Clamp(levelIdx, 0, UKLevelDefs.LEVELS.Length - 1)];
        public UKPlayer player;
        public UKWeapons weapons;
        public UKHud hud;
        public UKLevel level;
        public UKMusic music;
        public UKFall fall;
        public readonly UKStyle style = new UKStyle();
        public Camera cam;
        public float parryBuffer, runTime, deathT, resultsT, cerbOrbT = -99, menuT;
        public UKResults results;
        public string pendingHint;
        Vector3 checkpoint;
        float checkpointYaw, hitstopT, slowT, slowK = 1, screamT = -1, pauseT;
        int screams, bankedStyle;
        bool levelDone;
        Light sun;
        readonly List<KeyValuePair<float, Action>> sched = new List<KeyValuePair<float, Action>>();
        readonly HashSet<UnityEngine.Object> assisted = new HashSet<UnityEngine.Object>();

        public int kills => stats.kills;
        public bool Endless => LevelDef.endless;
        // ölüm ekranındaki kafatasının çığlık miktarı (0..1)
        public float ScreamK => screamT >= 0 && screamT < 0.9f ? Mathf.Sin(Mathf.Clamp01(screamT / 0.9f) * Mathf.PI) : 0;
        // Stil puanı anında P olarak birikir; checkpoint'te, dükkânda ve bölüm sonunda kasaya girer.
        public int UnbankedP => Mathf.Max(0, Mathf.FloorToInt(style.total) - bankedStyle) + bonusP;

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
            progress = UKProgress.Load();
            if (!UKInput.Available)
                Debug.LogError("ULTRAKILL: Etkin girdi sistemi yok. Project Settings > Player > Active Input Handling = 'Both' (ya da 'Input Manager (Old)') yapın veya Input System paketini kurun.");
            diffIndex = Mathf.Clamp(PlayerPrefs.GetInt("uk.diff", 2), 0, DIFFS.Length - 1);
            UKFx.Init();
            new GameObject("UKFx").AddComponent<UKFx>();
            new GameObject("UKAudio").AddComponent<UKAudio>();
            music = new GameObject("UKMusic").AddComponent<UKMusic>();
            SetupScene();
            var pgo = new GameObject("V1");
            player = pgo.AddComponent<UKPlayer>();
            player.Setup(cam);
            weapons = pgo.AddComponent<UKWeapons>();
            weapons.Setup(cam);
            hud = gameObject.AddComponent<UKHud>();
            level = new GameObject("World").AddComponent<UKLevel>();
            fall = new GameObject("Fall").AddComponent<UKFall>();
            fall.Build();
            int last = PlayerPrefs.GetInt("uk.level", 0);
            if (last < 0 || last >= UKLevelDefs.LEVELS.Length || !Unlocked(last)) last = 0;
            LoadLevel(last);
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
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.nearClipPlane = UKFx.SRP ? 0.03f : 0.05f;
            cam.farClipPlane = 500f;
            cam.depth = 0;
            sun = new GameObject("Sun").AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.shadows = LightShadows.None;
            sun.transform.rotation = Quaternion.LookRotation(-new Vector3(0.4f, 1f, -0.6f));
            RenderSettings.skybox = null;
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Linear;
            QualitySettings.pixelLightCount = Mathf.Max(QualitySettings.pixelLightCount, 8);
        }

        // Bölüm teması: sis, ortam (yarımküre) ışığı ve güneş
        void ApplyTheme(UKLevel.Theme th)
        {
            RenderSettings.fogColor = th.fog;
            RenderSettings.fogStartDistance = th.fogNear;
            RenderSettings.fogEndDistance = th.fogFar;
            cam.backgroundColor = th.fog;
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            float k = th.hemi / 1.9f;
            RenderSettings.ambientSkyColor = Color.Lerp(th.hemiSky, th.ambient, 0.35f) * 0.42f * k;
            RenderSettings.ambientEquatorColor = Color.Lerp(th.hemiSky, th.hemiGround, 0.5f) * 0.36f * k + th.ambient * 0.12f;
            RenderSettings.ambientGroundColor = th.hemiGround * 0.55f * k + th.ambient * 0.1f;
            sun.color = th.sun;
            sun.intensity = 0.62f;
        }

        // ------------------------------------------------------------ bölüm yükleme
        public bool Unlocked(int idx)
        {
            var d = UKLevelDefs.LEVELS[idx];
            if (d.endless) return progress.levels.ContainsKey("0-1") || progress.unlocked >= 2;
            return idx < progress.unlocked;
        }

        // Bölümü kur (zaten yüklüyse bir şey yapmaz)
        public bool LoadLevel(int idx)
        {
            idx = Mathf.Clamp(idx, 0, UKLevelDefs.LEVELS.Length - 1);
            if (levelIdx == idx && level.root != null) return false;
            ClearCombat();
            levelIdx = idx;
            level.Build(UKLevelDefs.LEVELS[idx]);
            ApplyTheme(level.theme);
            checkpoint = level.spawnCheckpoint;
            checkpointYaw = level.spawnYaw;
            return true;
        }

        public void SelectLevel(int idx)
        {
            if (idx < 0 || idx >= UKLevelDefs.LEVELS.Length || !Unlocked(idx)) return;
            PlayerPrefs.SetInt("uk.level", idx);
            if (LoadLevel(idx)) { level.SpawnDecor(); menuT = 0; }
        }

        void ResetLevelState()
        {
            cerbOrbT = -99;
            ClearCombat();
            level.ResetState();
            levelDone = false;
            results = null;
            fall.End();
        }

        // ------------------------------------------------------------ durum geçişleri
        public void ToMenu()
        {
            ResetLevelState();
            level.SpawnDecor();
            state = State.Menu;
            hud.panel = UKHud.Panel.Main;
            hud.ResetAll();
            player.ResetAt(level.spawnCheckpoint, 0);
            player.frozen = true;
            player.cc.enabled = false;
            weapons.SetVisible(false);
            UKAudio.I.StopAllLoops();
            music.SetMode("menu");
            menuT = 0;
            ApplyTheme(level.theme);
        }

        public void StartNew(int idx)
        {
            if (!Unlocked(idx)) return;
            PlayerPrefs.SetInt("uk.level", idx);
            if (!progress.introSeen)
            {
                progress.introSeen = true;
                progress.Save();
                levelIdxPending = idx;
                state = State.Intro;
                music.SetMode("off");
                level.ClearDecor();
                hud.StartIntro();
                return;
            }
            BeginLevel(idx);
        }

        int levelIdxPending;
        public void IntroDone() => BeginLevel(levelIdxPending);

        // Bölümü baştan başlat: üsten, kapaktan aşağı düşerek iniş
        public void BeginLevel(int idx = -1)
        {
            if (idx < 0) idx = levelIdx;
            level.ClearDecor();
            if (!LoadLevel(idx)) ResetLevelState();
            levelDone = false;
            results = null;
            fall.End();
            ApplyTheme(level.theme);
            hud.ResetAll();
            hud.panel = UKHud.Panel.Main;
            player.v2 = settings.v2 && progress.v2Unlocked;
            player.ResetAt(level.spawnPos, level.spawnYaw);
            player.pitch = level.spawnPitch;
            player.frozen = false;
            checkpoint = level.spawnCheckpoint;
            checkpointYaw = level.spawnYaw;
            weapons.ResetAll(false);
            weapons.SetSkin(player.v2);
            if (settings.allWeapons) weapons.ApplyLoadout(progress.Has, true);
            else if (level.startArmed) ApplyLoadout();
            else weapons.SetUnarmed();
            weapons.SetVisible(true);
            level.SpawnTrainers();
            level.Prespawn();
            style.Reset(true);
            bankedStyle = 0;
            bonusP = 0;
            levelP = 0;
            lostP = 0;
            stats = new Stats();
            runTime = 0;
            results = null;
            state = State.Playing;
            music.SetMode("calm");
            var d = LevelDef;
            hud.Title(d.layer + " /// " + d.id, d.name, 4.5f);
            // üsten iniş: alarm, kapak açılır, oyuncu bölüme düşer
            if (level.doors.TryGetValue("baseHatch", out var hatch))
            {
                hatch.SetInstant(false);
                player.pitch = 43;
                UKAudio.I.Play("beep", 0.8f, 0.7f, true);
                Schedule(0.25f, () => UKAudio.I.Play("beep", 0.8f, 0.7f, true));
                Schedule(0.5f, () => { hatch.Open(true); player.Shake(0.25f); UKAudio.I.Play("doorSlam", 0.6f, 1.4f, true); });
            }
        }

        // Dükkân sahipliğini silahlara uygula (test modu: her şey)
        public void ApplyLoadout() => weapons.ApplyLoadout(progress.Has, settings.allWeapons);

        public void Pause()
        {
            if (state != State.Playing) return;
            state = State.Paused;
            pauseT = Time.unscaledTime;
            hud.panel = UKHud.Panel.Main;
            UKAudio.I.StopAllLoops();
            music.Muffle(true);
        }

        public void Resume()
        {
            if (state != State.Paused) return;
            state = State.Playing;
            music.Muffle(false);
        }

        // Son kontrol noktasından devam (ölüm ekranı ya da duraklatma menüsü)
        public void Respawn(bool fromPause = false)
        {
            if (state != State.Dead && !(fromPause && state == State.Paused)) return;
            if (Endless) { EndlessOver(); return; }
            level.ResetActiveArenas();
            level.Prespawn();
            UKProjectile.ClearAll();
            UKCoin.ClearAll();
            UKShockwave.ClearAll();
            int cur = weapons.cur;
            weapons.ResetAll(true);
            if (cur >= 0 && weapons.owned[cur]) weapons.cur = cur;
            player.ResetAt(checkpoint, checkpointYaw);
            player.frozen = false;
            if (fromPause) DropUnbanked();
            style.Reset(false);
            stats.restarts++;
            weapons.SetVisible(true);
            hud.ResetAll();
            deathT = 0;
            screamT = -1;
            hitstopT = slowT = 0;
            state = State.Playing;
            music.Muffle(false);
            music.SetMode("calm");
        }

        public void SetCheckpoint(Vector3 pos, float yawDeg)
        {
            if ((checkpoint - pos).sqrMagnitude < 0.25f) return;
            checkpoint = pos;
            checkpointYaw = yawDeg;
            int n = BankPoints();
            hud.Message(n > 0 ? "CHECKPOINT  +" + n + " P" : "CHECKPOINT", 1.5f, "cp");
            UKAudio.I.Play("checkpoint");
        }

        public int BankPoints()
        {
            int n = UnbankedP;
            progress.points += n;
            levelP += n;
            bankedStyle = Mathf.FloorToInt(style.total);
            bonusP = 0;
            progress.Save();
            return n;
        }

        void DropUnbanked()
        {
            bankedStyle = Mathf.FloorToInt(style.total);
            bonusP = 0;
        }

        // ------------------------------------------------------------ dükkân
        public void OpenShop()
        {
            if (state != State.Playing) return;
            BankPoints();
            state = State.Shop;
            pauseT = Time.unscaledTime;
            UKAudio.I.StopAllLoops();
            UKAudio.I.Play("uiClick");
            music.Muffle(true);
            hud.shopTab = 0;
        }

        public void CloseShop()
        {
            if (state != State.Shop) return;
            state = State.Playing;
            music.Muffle(false);
            if (pendingHint != null) { hud.Hint(pendingHint, 9); pendingHint = null; }
        }

        public bool Buy(string id)
        {
            var it = UKShop.Find(id);
            if (it == null || progress.Has(id) || settings.allWeapons) return false;
            if (it.needs != null && !progress.Has(it.needs)) return false;
            if (progress.points < it.price) { UKAudio.I.Play("empty"); return false; }
            progress.points -= it.price;
            progress.shop.Add(id);
            if (it.alt != null) progress.altOn.Add(it.alt);
            progress.Save();
            ApplyLoadout();
            if (it.alt != null) weapons.Equip(it.w);
            else if (it.w >= 0) weapons.EquipVariant(it.w, it.v);
            else if (id == "arm.knuckle") weapons.arm = 1;
            UKAudio.I.Play("pickup");
            hud.Flash(new Color(0.35f, 1f, 0.55f, 0.35f), 0.3f);
            pendingHint = UKShop.HINTS.TryGetValue(id, out var h) ? h : null;
            return true;
        }

        // Alınmış alternatif silahı takıp çıkar
        public bool ToggleAlt(string id)
        {
            var it = UKShop.Find(id);
            if (it == null || it.alt == null || (!progress.Has(id) && !settings.allWeapons)) return false;
            if (progress.AltOn(it.alt)) progress.altOn.Remove(it.alt); else progress.altOn.Add(it.alt);
            progress.Save();
            ApplyLoadout();
            weapons.Equip(it.w);
            UKAudio.I.Play("pump");
            return true;
        }

        // ------------------------------------------------------------ bölüm sonu
        public void LevelComplete()
        {
            if (levelDone || state != State.Playing) return;
            levelDone = true;
            state = State.Results;
            resultsT = 0;
            style.frozen = true;
            UKAudio.I.StopAllLoops();
            music.SetMode("calm");
            hud.Flash(Color.white, 0.8f);
            var def = LevelDef;
            var s = stats;
            var r = new UKResults
            {
                time = s.time, kills = s.kills, killsTotal = level.totalEnemies, style = Mathf.Round(style.total), secrets = s.secrets, secretsTotal = level.secrets.Count,
                parries = s.parries, restarts = s.restarts, damage = s.damageTaken, droneParries = s.droneParries, tanks = s.tanks, difficulty = Diff.name,
                levelId = def.id, levelTitle = def.id + ": " + def.name,
            };
            r.timeRank = UKProgress.RankTime(r.time, def.time);
            r.killRank = UKProgress.RankKills(r.kills / (float)Mathf.Max(1, r.killsTotal));
            r.styleRank = UKProgress.RankStyle(r.style, def.style);
            r.final = UKProgress.FinalRank(new[] { r.timeRank, r.killRank, r.styleRank }, r.restarts);
            r.challenge = def.challenge(r);
            r.challengeText = def.challengeText(r);
            // P: kasaya kalanı yatır + sıra ve meydan okuma ödülü
            int rb = r.final == "P" ? 5000 : r.final == "S" ? 3000 : r.final == "A" ? 2000 : r.final == "B" ? 1200 : r.final == "C" ? 600 : 300;
            r.rankBonus = rb + (r.challenge ? 1000 : 0);
            bonusP += r.rankBonus;
            BankPoints();
            r.pointsEarned = levelP;
            r.pointsTotal = progress.points;
            progress.levels.TryGetValue(def.id, out var rec);
            r.newBest = rec == null || UKProgress.Better(rec.rank, r.final) || (rec.rank == r.final && (rec.time <= 0 || r.time < rec.time));
            if (r.newBest) progress.levels[def.id] = new UKProgress.LevelRec { rank = r.final, time = r.time, style = Mathf.Max(r.style, rec != null ? rec.style : 0) };
            else rec.style = Mathf.Max(rec.style, r.style);
            progress.unlocked = Mathf.Max(progress.unlocked, Mathf.Min(UKLevelDefs.STORY_COUNT, levelIdx + 2));
            r.hasNext = levelIdx + 1 < UKLevelDefs.STORY_COUNT;
            r.finale = def.finale;
            progress.Save();
            results = r;
            weapons.SetVisible(false);
            ClearCombat();
            // sonuç ekranı: karanlık kuyuda düşüş
            fall.Begin(level.theme);
            player.cc.enabled = false;
            player.transform.position = UKFall.ORIGIN;
            player.vel = Vector3.down * 20;
            player.pitch = 60;
            RenderSettings.fogColor = level.theme.fog * 0.25f;
            RenderSettings.fogStartDistance = 20;
            RenderSettings.fogEndDistance = 130;
            cam.backgroundColor = level.theme.fog * 0.25f;
        }

        public void NextLevel()
        {
            if (levelIdx + 1 < UKLevelDefs.STORY_COUNT) { PlayerPrefs.SetInt("uk.level", levelIdx + 1); BeginLevel(levelIdx + 1); }
            else ToMenu();
        }

        // Siber Öğütücü: ölüm (ya da checkpoint'e dönüş) koşuyu bitirir; ulaşılan dalga kaydedilir
        void EndlessOver()
        {
            if (levelDone) return;
            levelDone = true;
            state = State.Results;
            resultsT = 0;
            style.frozen = true;
            UKAudio.I.StopAllLoops();
            music.Muffle(false);
            music.SetMode("calm");
            var def = LevelDef;
            var s = stats;
            int wave = cgWave;
            progress.levels.TryGetValue(def.id, out var rec);
            string final = wave >= 20 ? "P" : wave >= 15 ? "S" : wave >= 10 ? "A" : wave >= 6 ? "B" : wave >= 3 ? "C" : "D";
            var r = new UKResults
            {
                endless = true, wave = wave, time = s.time, kills = s.kills, style = Mathf.Round(style.total), parries = s.parries, damage = s.damageTaken,
                difficulty = Diff.name, levelId = def.id, levelTitle = def.name, final = final,
                bestWave = Mathf.Max(rec != null ? rec.wave : 0, wave), newBest = wave > (rec != null ? rec.wave : 0),
            };
            r.challenge = def.challenge(r);
            r.challengeText = def.challengeText(r);
            // koşuda kasaya girmemiş stil yanar ama dalga ödülü verilir
            DropUnbanked();
            bonusP = wave * 250 + (r.challenge ? 1000 : 0);
            r.rankBonus = bonusP;
            BankPoints();
            r.pointsEarned = levelP;
            r.pointsTotal = progress.points;
            progress.levels[def.id] = new UKProgress.LevelRec { rank = r.newBest || rec == null ? final : rec.rank, wave = r.bestWave, style = Mathf.Max(rec != null ? rec.style : 0, r.style) };
            progress.Save();
            results = r;
            weapons.SetVisible(false);
            ClearCombat();
            fall.Begin(level.theme);
            player.dead = false;
            player.cc.enabled = false;
            player.transform.position = UKFall.ORIGIN;
            player.pitch = 60;
            cam.backgroundColor = level.theme.fog * 0.25f;
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
            UKAudio.I.StopAllLoops();
            UKAudio.I.Play("death");
            UKAudio.I.Play("glitch");
            music.Muffle(true);
            UKFx.I.Blood(p.EyePos, 50, 8);
            hud.Flash(new Color(1, 0, 0, 0.8f), 0.5f);
            p.Shake(0.8f);
            lostP = UnbankedP;
            DropUnbanked();
            style.Reset(false);
        }

        void ClearCombat()
        {
            var list = new List<UKEnemy>(UKEnemy.All);
            foreach (var e in list) if (e) e.RemoveSilently();
            UKEnemy.All.Clear();
            UKEnemy.ClearCorpses();
            UKProjectile.ClearAll();
            UKCoin.ClearAll();
            UKShockwave.ClearAll();
            if (UKFx.I) UKFx.I.ClearAll();
            sched.Clear();
            assisted.Clear();
            hitstopT = slowT = 0;
            parryBuffer = 0;
            Time.timeScale = 1;
        }

        // ------------------------------------------------------------ olaylar
        public void OnEnemyKilled(UKEnemy e)
        {
            if (e.decor) return;
            if (e is UKTrainer tr)
            {
                if (tr.trainerDoor != null && level.doors.TryGetValue(tr.trainerDoor, out var door)) Schedule(0.8f, () => door.Open());
                hud.Message("PARRY ÖĞRENİLDİ", 2.2f, "secret");
                hud.Hint("Harika! Mermileri ve PARLAYAN saldırıları geri çevirmek canını tamamen doldurur. Kapı açıldı.", 7);
                return;
            }
            if (e.noCount) return;
            stats.kills++;
        }

        public void OnSecret(UKLevel.UKSecret s, int total)
        {
            stats.secrets++;
            bonusP += 1000;
            UKAudio.I.Play("secret");
            hud.Message("GİZLİ KÜRE  " + stats.secrets + " / " + total + "  +1000 P", 2.5f, "secret");
            UKFx.I.Burst(s.g.position, 30, 8, new Color(0.5f, 0.78f, 1f), 0.8f, 0.08f, 0);
            UKFx.I.Ring(s.g.position, new Color(0.5f, 0.78f, 1f), 3, 0.6f);
        }

        public void OnPickup(UKLevel.UKPickup pk)
        {
            bool first;
            string name, sub, kind;
            if (int.TryParse(pk.weapon, out int wi))
            {
                first = weapons.Give(wi);
                var W = UKWeapons.WEAPONS[wi];
                name = W.name;
                sub = (wi + 1) + " · " + string.Join(" / ", Array.ConvertAll(W.variants, v => v.name));
                kind = "YENİ SİLAH";
            }
            else
            {
                first = weapons.GiveArm(pk.weapon);
                name = pk.weapon == "hook" ? "WHIPLASH" : "KNUCKLEBLASTER";
                sub = pk.weapon == "hook" ? "E · KANCA" : "G · KOL DEĞİŞTİR";
                kind = "YENİ KOL";
            }
            UKAudio.I.Play("pickup");
            Hitstop(0.08f);
            hud.Flash(new Color(0.63f, 0.82f, 1f, 0.5f), 0.4f);
            hud.Title(kind, name, 3, sub);
            UKFx.I.Burst(pk.pos, 30, 8, new Color(0.62f, 0.85f, 1f), 0.7f, 0.07f, 0);
            UKFx.I.Ring(pk.pos + Vector3.down * 1.5f, new Color(0.62f, 0.85f, 1f), 3, 0.6f);
            pk.onGive?.Invoke(this);
            if (first) pk.onTake?.Invoke(this);
        }

        public void OnBossDefeated(string msg, Action then)
        {
            hud.Message(msg, 2.5f, "big");
            music.SetMode("calm");
            if (then != null) Schedule(2.0f, then);
        }

        // ------------------------------------------------------------ zaman
        public void Schedule(float delay, Action a) => sched.Add(new KeyValuePair<float, Action>(delay, a));
        public void Hitstop(float t) { if (state == State.Playing) hitstopT = Mathf.Max(hitstopT, t); }
        public void SlowMo(float t, float k) { slowT = t; slowK = k; }

        void RunSchedule(float dt)
        {
            if (sched.Count == 0) return;
            var due = new List<Action>();
            for (int i = sched.Count - 1; i >= 0; i--)
            {
                float t = sched[i].Key - dt;
                if (t <= 0) { due.Add(sched[i].Value); sched.RemoveAt(i); }
                else sched[i] = new KeyValuePair<float, Action>(t, sched[i].Value);
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
            music.volume = settings.music * settings.volume;
            music.SetStyleRank(style.rank);

            if (state == State.Playing)
            {
                if (hitstopT > 0) { hitstopT -= rdt; Time.timeScale = 0f; }
                else if (slowT > 0) { slowT -= rdt; Time.timeScale = slowK; }
                else Time.timeScale = 1f;
            }
            else if (state == State.Paused || state == State.Shop) Time.timeScale = 0f;
            else if (state == State.Dead) Time.timeScale = deathT < 1.5f ? 0.22f : 0.5f;
            else Time.timeScale = 1f;

            bool locked = state == State.Playing;
            Cursor.lockState = locked ? CursorLockMode.Locked : CursorLockMode.None;
            Cursor.visible = !locked;

            float dt = Time.deltaTime;
            switch (state)
            {
                case State.Menu:
                case State.Intro:
                    menuT += rdt;
                    level.Tick(rdt, Time.time, cam.transform.position);
                    break;
                case State.Playing:
                    if (UKInput.DownUnblocked(UKKey.Esc)) { Pause(); break; }
                    stats.time += rdt;
                    runTime = stats.time;
                    ParryAssist(rdt);
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
                    RunSchedule(dt);
                    if (state != State.Playing) break;
                    level.GameTick(dt);
                    if (state == State.Playing && level.NearShop != null && UKInput.Down(UKKey.B)) OpenShop();
                    level.Tick(dt, Time.time, cam.transform.position);
                    break;
                case State.Paused:
                    if (UKInput.DownUnblocked(UKKey.Esc) && Time.unscaledTime - pauseT > 0.2f) { if (hud.panel != UKHud.Panel.Main) hud.panel = UKHud.Panel.Main; else Resume(); }
                    break;
                case State.Shop:
                    if ((UKInput.DownUnblocked(UKKey.Esc) || UKInput.DownUnblocked(UKKey.B)) && Time.unscaledTime - pauseT > 0.25f) CloseShop();
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
                    RunSchedule(dt);
                    level.Tick(dt, Time.time, cam.transform.position);
                    if (deathT > 1f && (UKInput.DownUnblocked(UKKey.R) || UKInput.DownUnblocked(UKKey.Mouse0) || UKInput.DownUnblocked(UKKey.Enter) || UKInput.DownUnblocked(UKKey.Space))) Respawn();
                    break;
                case State.Results:
                    resultsT += rdt;
                    fall.Tick(rdt, Time.unscaledTime);
                    player.yaw += rdt * 25f;
                    player.pitch = Mathf.Lerp(player.pitch, 78f, rdt * 1.5f);
                    if (resultsT > 3.5f)
                    {
                        if (UKInput.DownUnblocked(UKKey.R)) BeginLevel(levelIdx);
                        else if (UKInput.DownUnblocked(UKKey.Enter) && results != null && results.hasNext && !results.endless) NextLevel();
                    }
                    break;
            }
        }

        void LateUpdate()
        {
            if (I != this) return;
            float rdt = Mathf.Min(Time.unscaledDeltaTime, 0.1f);
            float vf = VFov(settings.fov);
            if (state == State.Playing || state == State.Dead || state == State.Paused || state == State.Shop)
                player.UpdateCamera(rdt, vf, state == State.Dead ? Mathf.Clamp01(deathT / 0.6f) : 0);
            else if (state == State.Results)
                player.UpdateCamera(rdt, vf + 8, 0);
            else if (state == State.Menu || state == State.Intro)
            {
                float a = menuT * 0.06f;
                var c = level.menuTarget;
                cam.transform.position = c + new Vector3(Mathf.Sin(a) * level.menuRadius, level.menuHeight - c.y + Mathf.Sin(a * 2.3f) * 0.8f, Mathf.Cos(a) * level.menuRadius);
                cam.transform.rotation = Quaternion.LookRotation(c - cam.transform.position);
                cam.fieldOfView = 62;
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
            stats.damageTaken += dmg;
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

        // safe = true → oyuncuya zarar vermez. small → mavi parry patlaması. visualOnly → yalnız efekt
        public void Explode(Vector3 pos, float radius, float dmg, bool safe, float playerDmg, float knock = 15, string weapon = "explosion", bool small = false, bool visualOnly = false)
        {
            if (small)
            {
                UKFx.I.Shell(pos, new Color(0.75f, 0.9f, 1f), radius, 0.3f);
                UKFx.I.Burst(pos, 16, radius * 3, new Color(0.62f, 0.85f, 1f), 0.4f, 0.08f);
                UKAudio.I.PlayAt("projHit", pos, 1.5f);
            }
            else
            {
                UKFx.I.Explosion(pos, radius * 0.7f);
                if (Physics.Raycast(pos + Vector3.up * 0.2f, Vector3.down, out var ground, 2.2f, UKFx.RayMask, QueryTriggerInteraction.Ignore) && !(ground.collider is CharacterController))
                    UKFx.I.Scorch(ground.point, ground.normal, radius * 0.5f);
                UKAudio.I.PlayAt("explosion", pos);
                float dd = Vector3.Distance(pos, cam.transform.position);
                player.Shake(Mathf.Clamp(0.8f - dd / 30, 0.1f, 0.7f));
            }
            if (visualOnly) return;
            var list = new List<UKEnemy>(UKEnemy.All);
            foreach (var e in list)
            {
                if (e.dead) continue;
                Vector3 c = e.Center;
                float dist = Vector3.Distance(c, pos);
                if (dist >= radius + e.radius) continue;
                float k = 1 - Mathf.Clamp01(dist / radius) * 0.6f;
                Vector3 dir = c - pos;
                dir.y = Mathf.Max(dir.y, 0) + 0.6f;
                e.Hit(dmg * k, c, dir.normalized, false, weapon, knock, 1, false, false, false, false, true);
            }
            if (safe || playerDmg <= 0) return;
            var p = player;
            if (p.dead) return;
            Vector3 pc = p.transform.position + Vector3.up * 0.9f;
            float pd = Vector3.Distance(pc, pos);
            if (pd < radius)
            {
                float k = 1 - pd / radius * 0.5f;
                Vector3 dir = (pc - pos).normalized;
                if (DamagePlayer(playerDmg * k, null, false))
                {
                    p.vel += dir * knock * k;
                    p.vel.y = Mathf.Max(p.vel.y, 12 * k);
                    p.grounded = false;
                }
            }
        }

        // Nişan yardımı: nişangâh zaten bir düşmana değmiyorsa, koninin içindeki görünen en yakın düşmana büker.
        // force: ayardan bağımsız tam yardım (Sharpshooter sekmesi)
        public Vector3 AssistDir(Vector3 o, Vector3 d, float maxA, bool force = false) => AssistTarget(o, d, maxA, force, out _);

        public Vector3 AssistDir(Vector3 o, Vector3 d, float maxA) => AssistTarget(o, d, maxA, false, out _);

        public Vector3 AssistTarget(Vector3 o, Vector3 d, float maxA, bool force, out UKEnemy target)
        {
            target = null;
            float assist = force ? 1 : settings.aimAssist;
            if (assist <= 0.01f) return d;
            var r0 = UKWeapons.DoScan(o, d, 300);
            if (r0.hits.Count > 0) { target = r0.hits[0].enemy; return d; }
            float bestA = 999;
            Vector3 best = d;
            foreach (var e in UKEnemy.All)
            {
                if (e.dead || e.State == "spawn" || e.decor || e.dormant) continue;
                Vector3 to = e.Center - o;
                float dist = to.magnitude;
                if (dist < 0.5f || dist > 120) continue;
                to /= dist;
                float ang = Mathf.Acos(Mathf.Clamp(Vector3.Dot(d, to), -1f, 1f));
                float lim = maxA * assist + Mathf.Atan2(e.radius * 1.2f, dist);
                if (ang > lim || ang >= bestA) continue;
                var r = UKWeapons.DoScan(o, to, dist + 1);
                if (r.hits.Count == 0 || r.hits[0].enemy != e) continue;
                bestA = ang;
                best = to;
                target = e;
            }
            return best;
        }

        UKEnemy NearestVisibleEnemy(Vector3 o, float maxD)
        {
            UKEnemy best = null;
            float bd = maxD;
            foreach (var e in UKEnemy.All)
            {
                if (e.dead || e.decor || e.State == "spawn" || e.dormant) continue;
                float dd = Vector3.Distance(e.Center, o);
                if (dd < bd && !UKProjectile.WorldCast(o, (e.Center - o).normalized, dd - 0.3f, out _)) { bd = dd; best = e; }
            }
            return best;
        }

        // PARRY: 1) düşman mermileri (Knuckleblaster savuşturamaz), 2) parlayan yakın saldırılar,
        // 3) oyuncunun çekirdek/roket/güllesi (PROJECTILE BOOST), 4) havadaki bozuk para (COIN PUNCH)
        public bool TryParry(bool buffered = false)
        {
            var p = player;
            bool knuckle = weapons.ArmId == "knuckle";
            Vector3 o = p.EyePos, d = p.AimDir;
            var list = new List<UKProjectile>();
            if (!knuckle)
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
                // hedef: nişangâh; yakınında düşman varsa ona (parry yardımıyla daha geniş koni + güdüm)
                int lvl = settings.parryAssist;
                var r = UKWeapons.DoScan(o, d, 300);
                Vector3 target = r.hits.Count > 0 ? r.hits[0].point : r.end;
                UKEnemy targetEnemy = r.hits.Count > 0 ? r.hits[0].enemy : null;
                float cone = lvl >= 2 ? 0.9f : lvl >= 1 ? 0.5f : 0.26f;
                Vector3 ad = AssistTarget(o, d, cone, true, out var ae);
                if (ae != null)
                {
                    var h = UKWeapons.DoScan(o, ad, 300);
                    if (h.hits.Count > 0) { target = h.hits[0].point; targetEnemy = h.hits[0].enemy; }
                }
                else if (lvl >= 2)
                {
                    var e = NearestVisibleEnemy(o, 60);
                    if (e != null) { target = e.Center; targetEnemy = e; }
                }
                foreach (var pr in list)
                {
                    Vector3 dir = (target - pr.transform.position).normalized;
                    pr.Parry(dir, Mathf.Max(pr.vel.magnitude * 1.8f, 65f), lvl > 0 ? targetEnemy : null);
                    if (lvl > 0 && targetEnemy != null) pr.homeRate = lvl >= 2 ? 7 : 3.5f;
                }
                OnParry(list[0].transform.position, list.Count, false);
                return true;
            }
            // parlayan yakın saldırı: nişangâhın baktığı (yakın ve önde olan) düşman
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
                OnParry(pos, 1, true);
                return true;
            }
            if (buffered) return false;
            foreach (var pr in UKProjectile.All)
            {
                if (pr.dead || !pr.fromPlayer || !(pr.kind == UKProjectile.Kind.Core || pr.kind == UKProjectile.Kind.Rocket || pr.kind == UKProjectile.Kind.Cannonball)) continue;
                Vector3 v = pr.transform.position - o;
                float dist = v.magnitude;
                if (dist < 5.5f && Vector3.Dot(v, d) / Mathf.Max(dist, 0.001f) > 0.2f)
                {
                    pr.vel = AssistDir(o, d, 0.2f) * (pr.kind == UKProjectile.Kind.Cannonball ? 60f : 70f);
                    pr.boosted = true;
                    pr.damage *= 1.5f;
                    if (pr.kind == UKProjectile.Kind.Core) pr.gravity = 4;
                    style.Add("PROJECTILE BOOST", 90, pr.kind == UKProjectile.Kind.Core ? "shotgun" : "rocket");
                    Hitstop(0.06f);
                    UKAudio.I.PlayAt("punchHit", pr.transform.position);
                    UKFx.I.Star(pr.transform.position, Color.white, 2, 0.2f, 1.6f);
                    return true;
                }
            }
            foreach (var c in UKCoin.All)
            {
                if (!c.alive) continue;
                Vector3 v = c.transform.position - o;
                float dist = v.magnitude;
                if (dist < 4.5f && Vector3.Dot(v, d) / Mathf.Max(dist, 0.001f) > 0.3f)
                {
                    style.Add("COIN PUNCH", 60, "revolver");
                    weapons.Ricochet(c, 1);
                    return true;
                }
            }
            return false;
        }

        // Parry yardımı: savuşturulabilir tehlike yaklaşınca kısa ağır çekim (KAPALI / HAFİF / GÜÇLÜ)
        void ParryAssist(float rdt)
        {
            int lvl = settings.parryAssist;
            if (lvl <= 0 || player.dead) return;
            Vector3 eye = player.EyePos;
            float win = lvl >= 2 ? 0.42f : 0.28f, bt = 1e9f;
            UnityEngine.Object best = null;
            foreach (var pr in UKProjectile.All)
            {
                if (pr.dead || pr.fromPlayer || !pr.parryable) continue;
                Vector3 dv = eye - pr.transform.position;
                float dist = dv.magnitude;
                if (dist > 20) continue;
                float closing = Vector3.Dot(pr.vel, dv) / Mathf.Max(dist, 0.001f);
                if (closing <= 1) continue;
                float t = (dist - 1.2f) / closing;
                if (t < win && t < bt) { bt = t; best = pr; }
            }
            foreach (var e in UKEnemy.All)
            {
                if (e.dead || !e.parryable) { assisted.Remove(e); continue; }
                if (Vector3.Distance(e.Center, eye) < 6.5f + e.radius && 0.1f < bt) { bt = 0.1f; best = e; }
            }
            if (best == null || assisted.Contains(best)) return;
            assisted.Add(best);
            slowT = lvl >= 2 ? 0.34f : 0.18f;
            slowK = lvl >= 2 ? 0.3f : 0.55f;
        }

        // Parry: donma, beyaz parlama, kol animasyonu, tam can, stil. (Ekranda "PARRY!" yazısı yok.)
        void OnParry(Vector3 pos, int n, bool melee)
        {
            var p = player;
            slowT = 0;
            weapons.ParryAnim();
            stats.parries++;
            p.hp = p.maxHp;
            p.hard = 0;
            p.fovKick = -14;
            UKAudio.I.Play("parry");
            Schedule(0.05f, () => UKAudio.I.Play("parryRing"));
            Hitstop(melee ? 0.22f : 0.15f);
            hud.Flash(new Color(1f, 1f, 1f, 0.85f), 0.22f);
            hud.HealFlash();
            p.Shake(0.35f);
            UKFx.I.Star(pos, Color.white, 4, 0.3f, 2);
            UKFx.I.Ring(pos, new Color(0.62f, 0.85f, 1f), 3, 0.35f);
            UKFx.I.Burst(pos, 24, 12, new Color(0.75f, 0.9f, 1f), 0.5f, 0.08f, 0);
            UKFx.I.Flash(pos, new Color(0.6f, 1f, 0.7f), 6, 12, 0.18f);
            style.Add("PARRY", 150, null, n > 1 ? n : 0);
            if (melee) style.Add("INTERRUPTION", 60, null);
            p.camKick += 2f;
        }

        // Yumruk: öndeki en yakın düşmana. Shotgun isabetinden hemen sonra → SHOTGUN PARRY
        public bool MeleePunch(bool knuckle = false)
        {
            var p = player;
            Vector3 o = p.EyePos, d = p.AimDir;
            UKEnemy best = null;
            float bd = 1e9f;
            foreach (var e in UKEnemy.All)
            {
                if (e.dead || e.State == "spawn" || e.decor) continue;
                Vector3 c = e.Center;
                float dist = Vector3.Distance(c, o) - e.radius;
                if (dist > (knuckle ? 4.6f : 4.2f)) continue;
                if (Vector3.Dot((c - o).normalized, d) < 0.4f) continue;
                if (dist < bd) { bd = dist; best = e; }
            }
            if (best == null) return false;
            Vector3 pc = best.Center;
            Vector3 dir = d;
            dir.y = Mathf.Max(dir.y, 0.35f);
            if (weapons.TakeShotgunParry(best))
            {
                best.Hit(4, pc, dir, false, "shotgun", 24);
                style.Add("SHOTGUN PARRY", 160, "shotgun");
                OnParry(pc, 1, true);
                return true;
            }
            best.Hit(knuckle ? 3 : 1, pc, dir, false, "punch", knuckle ? 30 : 14);
            UKAudio.I.PlayAt("punchHit", pc, 1, knuckle ? 0.7f : 1);
            p.Shake(knuckle ? 0.35f : 0.15f);
            Hitstop(knuckle ? 0.09f : 0.05f);
            UKFx.I.Burst(pc, knuckle ? 20 : 10, 7, knuckle ? new Color(1f, 0.54f, 0.38f) : Color.white, 0.25f, 0.06f);
            return true;
        }
    }
}
