// Silahlar (web: weapons.js + arms.js). ULTRAKILL'deki gibi her silahın üç varyantı vardır; aynı sayı
// tuşuna tekrar basınca varyant değişir:
//   1 Revolver:        Piercer / Marksman (bozuk para) / Sharpshooter (seken ışın)   · alternatif: SLAB
//   2 Shotgun:         Core Eject / Pump Charge / Sawed-On                          · alternatif: JACKHAMMER
//   3 Nailgun:         Attractor (mıknatıs) / Overheat / Sawblade
//   4 Railcannon:      Electric / Screwdriver / Malicious
//   5 Rocket Launcher: Freezeframe / S.R.S. Cannon / Firestarter
// Kollar: Feedbacker (parry) / Knuckleblaster ([G] ile), Whiplash kancası ([E]).
// Görünür modeller web koordinatlarıyla kurulur (W yardımcıları aynalar). Yerleşik hatta ayrı bir
// görünür-model kamerası (katman 1) silahın duvara girmesini önler; SRP'de model kameraya doğru küçültülür.
using System.Collections.Generic;
using UnityEngine;

namespace UK
{
    public class UKWeapons : MonoBehaviour
    {
        public struct Variant { public string id, name; public Color color; }
        public struct WeaponDef { public string id, name; public Variant[] variants; }
        static readonly Color BLUE = new Color(0.23f, 0.63f, 1f), GREEN = new Color(0.24f, 0.88f, 0.42f), RED = new Color(1f, 0.23f, 0.16f);
        public static readonly WeaponDef[] WEAPONS =
        {
            new WeaponDef { id = "revolver", name = "REVOLVER", variants = new[] { V("piercer", "PIERCER", BLUE), V("marksman", "MARKSMAN", GREEN), V("sharpshooter", "SHARPSHOOTER", RED) } },
            new WeaponDef { id = "shotgun", name = "SHOTGUN", variants = new[] { V("core", "CORE EJECT", BLUE), V("pump", "PUMP CHARGE", GREEN), V("saw", "SAWED-ON", RED) } },
            new WeaponDef { id = "nailgun", name = "NAILGUN", variants = new[] { V("attractor", "ATTRACTOR", BLUE), V("overheat", "OVERHEAT", GREEN), V("sawblade", "SAWBLADE", RED) } },
            new WeaponDef { id = "rail", name = "RAILCANNON", variants = new[] { V("electric", "ELECTRIC", BLUE), V("screwdriver", "SCREWDRIVER", GREEN), V("malicious", "MALICIOUS", RED) } },
            new WeaponDef { id = "rocket", name = "ROCKET LAUNCHER", variants = new[] { V("freeze", "FREEZEFRAME", BLUE), V("cannon", "S.R.S. CANNON", GREEN), V("fire", "FIRESTARTER", RED) } },
        };
        static Variant V(string id, string name, Color c) => new Variant { id = id, name = name, color = c };
        public static readonly string[] ARM_NAMES = { "FEEDBACKER", "KNUCKLEBLASTER" };
        const int N = 5;
        const float RAIL_TIME = 12, COIN_TIME = 2.2f;

        // ------------------------------------------------------------ durum
        public int cur = -1, last = -1, arm;
        public readonly bool[] owned = new bool[N];
        public readonly bool[][] varOwned = { new bool[3], new bool[3], new bool[3], new bool[3], new bool[3] };
        public readonly int[] variant = new int[N];
        public readonly bool[] alt = new bool[N];
        public readonly bool[] armsOwned = { true, false };
        public bool hookOwned;
        readonly float[] cd = new float[N];
        float punchCd, blastCd, blastHold, hookCd, cannonCd, switchT = 1, switchTime = -10, equipSpin;
        float pierceCharge, sharpCharge, sharpCharges = 3, coinCharges = 4, coreCharge, corePopT = 1, pumpAnim = 1, heat, heatBurst, nailT;
        float barrelSpin, barrelAngle, magnetCharges = 3, railCharge = 1, railHeat, freezeEnergy = 1, cannonCharge, fuel = 1, rocketLoadT = 1;
        float recoil, recoilRot, swayX, swayY, idleT, inspectT, drumAngle, drumTarget, hammerT = 1, coinFlick = 1, flashT, pendingCasing = -1, sawReload = 1, slideK, flameT;
        int pumps;
        bool pierceReady, railWasReady = true, freezeActive, flaming, sawOut;
        UKEnemy lastShotgunHitEnemy;
        float lastShotgunHitTime = -10;
        readonly List<UKProjectile> magnets = new List<UKProjectile>();
        readonly Spring sprZ = new Spring(210, 17), sprY = new Spring(150, 13), sprR = new Spring(190, 15);

        // kanca
        class Hook { public string phase; public Vector3 pos, vel; public float t; public UKEnemy target; }
        Hook hook;
        LineRenderer rope;
        Transform hookTip;

        // ------------------------------------------------------------ modeller
        class Model { public Transform group, gun, altGun, muzzle, muzzleBase, muzzleAlt, drum, hammer, pump, coreCell, saw, eject, barrels, drum2, sawRig, sawDisc, meter, nose, ball; public List<Transform> heat = new List<Transform>(), coils = new List<Transform>(); public Vector3 basePos; public float ry = 0.05f; }
        readonly Model[] models = new Model[N];
        readonly Material[] accents = new Material[N];
        Material coilMat, meterMat, heatMat;
        Transform vm, fist, flashStar1, flashStar2, flashGlow, flashCone, flashCore;
        Material flashConeMat;
        Camera vmCam, mainCam;
        Light muzzleLight;
        ViewArms arms;
        readonly Dictionary<string, Material> MT = new Dictionary<string, Material>();
        const int VM_LAYER = 1; // yerleşik "TransparentFX" katmanı: yalnız görünür-model kamerası çizer

        UKPlayer P => UKGame.I.player;
        public bool Armed => cur >= 0;
        public string CurKey => cur >= 0 ? WEAPONS[cur].id : "fist";
        public string VarId => cur >= 0 ? WEAPONS[cur].variants[variant[cur]].id : "fist";
        public string ArmId => arm == 1 ? "knuckle" : "feedbacker";
        public string CurName => cur < 0 ? "YUMRUK" : cur == 0 && alt[0] ? "SLAB REVOLVER" : cur == 1 && alt[1] ? "JACKHAMMER" : WEAPONS[cur].name;
        public string CurSub => cur < 0 ? ARM_NAMES[arm] : WEAPONS[cur].variants[variant[cur]].name;
        public Color CurAccent => cur < 0 ? (arm == 1 ? RED : BLUE) : WEAPONS[cur].variants[variant[cur]].color;
        public float PierceCharge => Mathf.Max(pierceCharge, sharpCharge, coreCharge, cannonCharge);
        public bool FreezeActive => freezeActive;
        public float CoinCharges => coinCharges;
        public float SharpCharges => sharpCharges;
        public float RailCharge => railCharge;
        public int Pumps => pumps;
        public float Heat => heat;
        public float Magnets => magnetCharges;
        public float FreezeEnergy => freezeEnergy;
        public float Fuel => fuel;
        public float CannonReady => cannonCd > 0 ? 1 - cannonCd / 4 : 1;
        public bool SawOut => sawOut;

        public class Spring
        {
            readonly float k, c; float x, v;
            public Spring(float k, float c) { this.k = k; this.c = c; }
            public void Kick(float vv) => v += vv;
            public float Update(float dt)
            {
                int steps = dt > 0.02f ? 2 : 1;
                float h = dt / steps;
                for (int i = 0; i < steps; i++) { v += (-k * x - c * v) * h; x += v * h; }
                return x;
            }
            public void Reset() { x = v = 0; }
        }

        Material Mt(string key, Color c, Texture2D tex = null, float emit = 0)
        {
            if (!MT.TryGetValue(key, out var m)) { m = UKFx.Lit(c, emit, tex); MT[key] = m; }
            return m;
        }

        public void Setup(Camera main)
        {
            mainCam = main;
            vm = new GameObject("Viewmodel").transform;
            vm.SetParent(main.transform, false);
            bool srp = UKFx.SRP;
            if (!srp)
            {
                vmCam = new GameObject("VMCam").AddComponent<Camera>();
                vmCam.transform.SetParent(main.transform, false);
                vmCam.clearFlags = CameraClearFlags.Depth;
                vmCam.cullingMask = 1 << VM_LAYER;
                vmCam.depth = main.depth + 1;
                vmCam.nearClipPlane = 0.01f;
                vmCam.farClipPlane = 20f;
                vmCam.fieldOfView = 58f;
                main.cullingMask &= ~(1 << VM_LAYER);
            }
            Mt("gun", new Color(0.66f, 0.68f, 0.73f), UKFx.TexMetal);
            Mt("dark", new Color(0.23f, 0.24f, 0.27f), UKFx.TexMachine);
            Mt("black", new Color(0.08f, 0.08f, 0.09f));
            Mt("grip", new Color(0.69f, 0.54f, 0.44f), UKFx.TexRock);
            Mt("arm", new Color(0.72f, 0.75f, 0.82f), UKFx.TexMachine);
            Mt("armDark", new Color(0.35f, 0.38f, 0.42f), UKFx.TexMachine);
            Mt("armLight", new Color(0.77f, 0.8f, 0.85f), UKFx.TexMetal, 0.05f);
            Mt("blue", new Color(0.29f, 0.55f, 1f), UKFx.TexMetal, 0.25f);
            Mt("red", new Color(0.88f, 0.23f, 0.16f), UKFx.TexMetal, 0.2f);
            Mt("green", new Color(0.42f, 0.85f, 0.29f), UKFx.TexMetal, 0.2f);
            Mt("rocketRed", new Color(0.82f, 0.13f, 0.13f), null, 0.15f);
            for (int i = 0; i < N; i++) accents[i] = Own(new Material(UKFx.Unlit(BLUE)));
            coilMat = Own(new Material(UKFx.Unlit(new Color(0.23f, 0.92f, 1f))));
            meterMat = Own(new Material(UKFx.Unlit(new Color(0.23f, 0.92f, 1f))));
            heatMat = Own(new Material(UKFx.Unlit(new Color(0.25f, 0.06f, 0.03f))));
            models[0] = BuildRevolver();
            models[1] = BuildShotgun();
            models[2] = BuildNailgun();
            models[3] = BuildRail();
            models[4] = BuildRocket();
            arms = new ViewArms(this, vm);
            fist = BuildIdleFist();
            // namlu alevi: iki yıldız, parlama, koni
            flashStar1 = UKFx.Billboard(vm, Vector3.zero, 1, new Color(1f, 0.88f, 0.63f), UKFx.TexStar).transform;
            flashStar2 = UKFx.Billboard(vm, Vector3.zero, 1, new Color(1f, 0.88f, 0.63f), UKFx.TexStar).transform;
            flashGlow = UKFx.Billboard(vm, Vector3.zero, 1, new Color(1f, 0.69f, 0.38f)).transform;
            flashConeMat = Own(new Material(UKFx.Unlit(new Color(1f, 0.69f, 0.31f, 0.85f))));
            flashCone = UKFx.Shape(vm, UKFx.Frustum(0, 7), Vector3.zero, Vector3.one, flashConeMat).transform;
            flashCore = UKFx.Shape(vm, UKFx.Frustum(0, 7), Vector3.zero, Vector3.one, UKFx.Unlit(new Color(1, 1, 1, 0.9f))).transform;
            foreach (var t in new[] { flashStar1, flashStar2, flashGlow, flashCone, flashCore }) t.gameObject.SetActive(false);
            muzzleLight = new GameObject("muzzleLight").AddComponent<Light>();
            muzzleLight.transform.SetParent(vm, false);
            muzzleLight.type = LightType.Point;
            muzzleLight.range = 6;
            muzzleLight.color = new Color(1f, 0.75f, 0.45f);
            muzzleLight.intensity = 0;
            muzzleLight.shadows = LightShadows.None;
            if (!srp) SetLayer(vm, VM_LAYER);
            else vm.localScale = Vector3.one * 0.35f; // SRP: kameraya doğru orantılı küçült (perspektifte aynı görünür)
            // Whiplash halatı (dünyada)
            rope = new GameObject("rope").AddComponent<LineRenderer>();
            rope.sharedMaterial = UKFx.Unlit(new Color(0.6f, 0.87f, 0.35f));
            rope.positionCount = 2;
            rope.startWidth = rope.endWidth = 0.03f;
            rope.enabled = false;
            hookTip = UKFx.Cone(null, Vector3.zero, 0.12f, 0.3f, UKFx.Unlit(new Color(0.78f, 0.94f, 0.63f)), default, 5).transform;
            hookTip.gameObject.SetActive(false);
            ResetAll(false);
        }

        Material Own(Material m) { gameObject.AddComponent<UKOwnMat>().m = m; return m; }

        static void SetLayer(Transform t, int layer)
        {
            t.gameObject.layer = layer;
            foreach (Transform c in t) SetLayer(c, layer);
        }

        public void SetVisible(bool on)
        {
            if (vm) vm.gameObject.SetActive(on);
            if (vmCam) vmCam.enabled = on;
            if (!on) { if (rope) rope.enabled = false; if (hookTip) hookTip.gameObject.SetActive(false); }
        }

        GameObject B(Transform p, float w, float h, float d, Material m, float x, float y, float z, float rx = 0, float ry = 0, float rz = 0) => W.Box(p, w, h, d, m, x, y, z, rx, ry, rz);
        GameObject CylZ(Transform p, float r1, float r2, float len, Material m, float x, float y, float z, int seg = 10) => W.Cyl(p, r1, r2, len, m, x, y, z, Mathf.PI / 2, 0, 0, seg);

        Transform Hand(Transform parent, float gx, float gy, float gz, float tilt = -0.28f)
        {
            var hand = W.J(parent, gx, gy, gz, "hand");
            hand.localRotation = W.Q(tilt);
            B(hand, 0.1f, 0.1f, 0.1f, MT["arm"], 0.006f, -0.02f, 0.02f);
            for (int k = 0; k < 4; k++) B(hand, 0.028f, 0.03f, 0.05f, MT["armDark"], -0.046f, 0.02f - k * 0.034f, -0.035f, 0, 0.2f);
            B(hand, 0.03f, 0.03f, 0.07f, MT["armDark"], 0.05f, 0.035f, -0.02f, 0, 0, -0.3f);
            var fore = W.J(hand, 0.01f, -0.06f, 0.1f);
            fore.localRotation = W.Q(-0.1f);
            B(fore, 0.11f, 0.11f, 0.34f, MT["arm"], 0, 0, 0.17f);
            B(fore, 0.125f, 0.04f, 0.12f, MT["armDark"], 0, 0.05f, 0.08f);
            B(fore, 0.125f, 0.04f, 0.12f, MT["armDark"], 0, 0.05f, 0.24f);
            CylZ(fore, 0.06f, 0.06f, 0.03f, MT["black"], 0, 0, 0.005f, 8);
            return hand;
        }

        Model NewModel(string name, Vector3 basePos)
        {
            var m = new Model { basePos = basePos };
            m.group = W.J(vm, basePos.x, basePos.y, basePos.z, name);
            m.gun = W.J(m.group, 0, 0, 0, "gun");
            return m;
        }

        Model BuildRevolver()
        {
            var M = MT; var A = accents[0];
            var m = NewModel("REVOLVER", new Vector3(0.25f, -0.26f, -0.52f));
            var g = m.gun;
            B(g, 0.075f, 0.085f, 0.2f, M["gun"], 0, 0, -0.03f);
            B(g, 0.05f, 0.026f, 0.25f, M["gun"], 0, 0.058f, -0.1f);
            CylZ(g, 0.026f, 0.026f, 0.3f, M["dark"], 0, 0.042f, -0.32f, 12);
            CylZ(g, 0.032f, 0.032f, 0.035f, M["gun"], 0, 0.042f, -0.46f, 12);
            CylZ(g, 0.011f, 0.011f, 0.07f, M["black"], 0, 0.042f, -0.478f, 8);
            CylZ(g, 0.013f, 0.013f, 0.2f, M["gun"], 0, 0.006f, -0.28f, 8);
            B(g, 0.012f, 0.035f, 0.03f, M["dark"], 0, 0.08f, -0.44f);
            B(g, 0.012f, 0.02f, 0.02f, M["dark"], -0.016f, 0.078f, 0.02f);
            B(g, 0.012f, 0.02f, 0.02f, M["dark"], 0.016f, 0.078f, 0.02f);
            B(g, 0.078f, 0.02f, 0.14f, A, 0, 0.022f, -0.02f);
            m.drum = W.J(g, 0, 0.022f, -0.1f, "drum");
            CylZ(m.drum, 0.06f, 0.06f, 0.13f, M["gun"], 0, 0, 0, 8);
            for (int k = 0; k < 6; k++)
            {
                float a = k / 6f * Mathf.PI * 2;
                CylZ(m.drum, 0.014f, 0.014f, 0.135f, M["black"], Mathf.Cos(a) * 0.036f, Mathf.Sin(a) * 0.036f, 0, 6);
                B(m.drum, 0.014f, 0.012f, 0.11f, A, Mathf.Cos(a + 0.52f) * 0.058f, Mathf.Sin(a + 0.52f) * 0.058f, 0, 0, 0, a + 0.52f);
            }
            m.hammer = W.J(g, 0, 0.05f, 0.06f, "hammer");
            B(m.hammer, 0.022f, 0.055f, 0.03f, M["dark"], 0, 0.025f, 0, -0.3f);
            B(g, 0.012f, 0.012f, 0.07f, M["dark"], 0, -0.06f, 0.0f);
            B(g, 0.01f, 0.035f, 0.012f, M["black"], 0, -0.05f, 0.005f, 0.3f);
            B(g, 0.062f, 0.18f, 0.082f, M["grip"], 0, -0.1f, 0.08f, -0.28f);
            B(g, 0.066f, 0.12f, 0.05f, M["dark"], 0, -0.1f, 0.08f, -0.28f);
            B(g, 0.068f, 0.03f, 0.03f, A, 0, -0.07f, 0.07f, -0.28f);
            m.muzzle = W.J(g, 0, 0.042f, -0.5f, "muzzle");
            Hand(g, 0, -0.1f, 0.1f);
            // SLAB: kalın gövdeli ağır revolver
            var s = W.J(m.group, 0, 0, 0, "slab");
            B(s, 0.1f, 0.12f, 0.26f, M["dark"], 0, 0.01f, -0.06f);
            B(s, 0.09f, 0.07f, 0.36f, M["gun"], 0, 0.05f, -0.2f);
            B(s, 0.06f, 0.05f, 0.1f, M["black"], 0, 0.05f, -0.42f);
            B(s, 0.104f, 0.02f, 0.2f, A, 0, 0.09f, -0.12f);
            for (int k = 0; k < 3; k++) B(s, 0.106f, 0.012f, 0.02f, M["black"], 0, 0.02f, -0.14f + k * 0.05f);
            CylZ(s, 0.065f, 0.065f, 0.12f, M["gun"], 0, 0.02f, -0.02f, 6);
            B(s, 0.07f, 0.19f, 0.09f, M["grip"], 0, -0.11f, 0.1f, -0.32f);
            B(s, 0.074f, 0.03f, 0.04f, A, 0, -0.06f, 0.08f, -0.32f);
            Hand(s, 0, -0.11f, 0.11f);
            s.gameObject.SetActive(false);
            m.altGun = s;
            m.muzzleBase = m.muzzle;
            m.muzzleAlt = W.J(s, 0, 0.05f, -0.46f, "muzzleAlt");
            return m;
        }

        Model BuildShotgun()
        {
            var M = MT; var A = accents[1];
            var m = NewModel("SHOTGUN", new Vector3(0.27f, -0.3f, -0.6f));
            var g = m.gun;
            B(g, 0.1f, 0.13f, 0.32f, M["gun"], 0, 0, -0.02f);
            B(g, 0.104f, 0.025f, 0.3f, M["dark"], 0, 0.07f, -0.02f);
            CylZ(g, 0.035f, 0.035f, 0.62f, M["dark"], 0, 0.038f, -0.49f, 12);
            CylZ(g, 0.042f, 0.042f, 0.06f, M["gun"], 0, 0.038f, -0.8f, 8);
            CylZ(g, 0.015f, 0.015f, 0.1f, M["black"], 0, 0.038f, -0.81f, 8);
            CylZ(g, 0.026f, 0.026f, 0.44f, M["dark"], 0, -0.03f, -0.42f, 10);
            m.pump = W.J(g, 0, -0.03f, -0.4f, "pump");
            B(m.pump, 0.09f, 0.08f, 0.22f, M["grip"], 0, 0, 0);
            for (int k = 0; k < 5; k++) B(m.pump, 0.094f, 0.01f, 0.012f, M["dark"], 0, -0.02f, -0.08f + k * 0.04f);
            var stock = W.J(g, 0, -0.04f, 0.14f);
            B(stock, 0.072f, 0.11f, 0.3f, M["grip"], 0, -0.02f, 0.14f, 0.14f);
            B(stock, 0.075f, 0.13f, 0.03f, M["black"], 0, -0.05f, 0.29f);
            B(g, 0.004f, 0.035f, 0.1f, M["black"], 0.052f, 0.025f, -0.03f);
            m.coreCell = CylZ(g, 0.03f, 0.03f, 0.1f, A, -0.058f, 0, -0.02f, 8).transform;
            m.saw = W.J(g, 0, -0.09f, -0.5f, "saw");
            B(m.saw, 0.02f, 0.05f, 0.36f, M["gun"], 0, 0, 0);
            for (int k = 0; k < 7; k++) B(m.saw, 0.024f, 0.02f, 0.02f, A, 0, -0.035f, -0.15f + k * 0.05f);
            B(g, 0.02f, 0.012f, 0.52f, A, 0, 0.088f, -0.42f);
            B(g, 0.104f, 0.03f, 0.08f, A, 0, -0.035f, 0.06f);
            m.muzzle = W.J(g, 0, 0.038f, -0.86f, "muzzle");
            m.eject = W.J(g, 0.06f, 0.03f, -0.03f, "eject");
            Hand(g, 0, -0.1f, 0.1f, -0.2f);
            // JACKHAMMER: pistonlu dev darbe
            var j = W.J(m.group, 0, 0, 0, "jackhammer");
            B(j, 0.14f, 0.16f, 0.34f, M["dark"], 0, 0, -0.04f);
            B(j, 0.12f, 0.05f, 0.3f, M["gun"], 0, 0.1f, -0.04f);
            CylZ(j, 0.07f, 0.07f, 0.34f, M["gun"], 0, 0, -0.36f, 8);
            CylZ(j, 0.05f, 0.05f, 0.2f, M["black"], 0, 0, -0.56f, 8);
            CylZ(j, 0.085f, 0.085f, 0.06f, A, 0, 0, -0.66f, 6);
            for (int k = 0; k < 3; k++) CylZ(j, 0.074f, 0.074f, 0.018f, M["black"], 0, 0, -0.26f - k * 0.07f, 8);
            B(j, 0.16f, 0.03f, 0.12f, A, 0, -0.07f, -0.02f);
            B(j, 0.02f, 0.12f, 0.14f, M["black"], 0.08f, 0.02f, -0.06f);
            B(j, 0.08f, 0.2f, 0.09f, M["grip"], 0, -0.14f, 0.1f, -0.2f);
            Hand(j, 0, -0.11f, 0.1f, -0.2f);
            j.gameObject.SetActive(false);
            m.altGun = j;
            m.muzzleBase = m.muzzle;
            m.muzzleAlt = W.J(j, 0, 0.02f, -0.7f, "muzzleAlt");
            return m;
        }

        Model BuildNailgun()
        {
            var M = MT; var A = accents[2];
            var m = NewModel("NAILGUN", new Vector3(0.26f, -0.29f, -0.58f));
            var g = m.gun;
            B(g, 0.12f, 0.13f, 0.34f, M["gun"], 0, 0, -0.05f);
            B(g, 0.13f, 0.05f, 0.2f, M["dark"], 0, -0.07f, -0.02f);
            m.barrels = W.J(g, 0, 0.01f, -0.36f, "barrels");
            for (int k = 0; k < 4; k++) { float a = k / 4f * Mathf.PI * 2; CylZ(m.barrels, 0.016f, 0.016f, 0.34f, M["dark"], Mathf.Cos(a) * 0.035f, Mathf.Sin(a) * 0.035f, 0, 6); }
            CylZ(m.barrels, 0.055f, 0.055f, 0.03f, M["gun"], 0, 0, 0.14f, 8);
            CylZ(m.barrels, 0.055f, 0.055f, 0.03f, M["gun"], 0, 0, -0.14f, 8);
            m.drum2 = W.Cyl(g, 0.07f, 0.07f, 0.1f, M["gun"], 0, 0.1f, -0.02f, 0, 0, Mathf.PI / 2, 10).transform;
            for (int k = 0; k < 3; k++) m.heat.Add(B(g, 0.125f, 0.012f, 0.03f, heatMat, 0, 0.03f, -0.12f + k * 0.05f).transform);
            B(g, 0.124f, 0.02f, 0.2f, A, 0, -0.03f, -0.05f);
            B(g, 0.06f, 0.16f, 0.08f, M["grip"], 0, -0.12f, 0.08f, -0.25f);
            m.muzzle = W.J(g, 0, 0.01f, -0.55f, "muzzle");
            // SAWBLADE: testere yuvası ve içinde dönen dişli disk
            m.sawRig = W.J(g, 0, 0.1f, -0.26f, "sawRig");
            foreach (float x in new[] { -0.045f, 0.045f }) B(m.sawRig, 0.012f, 0.1f, 0.3f, M["dark"], x, -0.06f, 0);
            B(m.sawRig, 0.1f, 0.02f, 0.3f, M["gun"], 0, -0.11f, 0);
            B(m.sawRig, 0.104f, 0.02f, 0.05f, A, 0, -0.005f, 0.13f);
            B(m.sawRig, 0.02f, 0.025f, 0.28f, A, 0, -0.095f, 0);
            m.sawDisc = W.J(m.sawRig, 0, 0, 0, "disc");
            SawDisc(m.sawDisc, 0.1f, M["gun"], A);
            m.sawRig.gameObject.SetActive(false);
            Hand(g, 0, -0.1f, 0.1f);
            return m;
        }

        // Dişli testere diski: eksen x (dikey disk, ileri yöne bakar)
        static void SawDisc(Transform g, float r, Material mat, Material tooth)
        {
            W.Cyl(g, r, r, r * 0.12f, mat, 0, 0, 0, 0, 0, Mathf.PI / 2, 18);
            W.Cyl(g, r * 0.3f, r * 0.3f, r * 0.2f, tooth, 0, 0, 0, 0, 0, Mathf.PI / 2, 8);
            for (int k = 0; k < 12; k++)
            {
                float a = k / 12f * Mathf.PI * 2;
                W.Box(g, r * 0.1f, r * 0.22f, r * 0.14f, tooth, 0, Mathf.Cos(a) * r, Mathf.Sin(a) * r, -a);
            }
        }

        Model BuildRail()
        {
            var M = MT; var A = accents[3];
            var m = NewModel("RAILCANNON", new Vector3(0.28f, -0.32f, -0.64f));
            var g = m.gun;
            B(g, 0.16f, 0.16f, 0.46f, M["gun"], 0, 0, -0.14f);
            B(g, 0.13f, 0.15f, 0.18f, M["dark"], 0, 0.005f, 0.16f);
            B(g, 0.19f, 0.06f, 0.22f, M["dark"], 0, -0.06f, -0.3f);
            m.meter = B(g, 0.03f, 0.022f, 0.14f, meterMat, 0, 0.092f, 0.16f).transform;
            CylZ(g, 0.04f, 0.04f, 0.2f, meterMat, 0, 0.1f, -0.05f, 8);
            foreach (var xy in new[] { new Vector2(0, 0.1f), new Vector2(-0.09f, -0.05f), new Vector2(0.09f, -0.05f) }) B(g, 0.024f, 0.024f, 0.78f, M["dark"], xy.x, xy.y, -0.54f);
            foreach (float z in new[] { -0.36f, -0.52f, -0.68f })
            {
                var c = UKFx.Shape(g, UKFx.Torus(0.2f, 14, 6), W.V(0, 0.015f, z), Vector3.one * 0.22f, coilMat, new Vector3(90, 0, 0));
                m.coils.Add(c.transform);
            }
            B(g, 0.165f, 0.02f, 0.3f, A, 0, -0.08f, -0.1f);
            m.muzzle = W.J(g, 0, 0.015f, -0.95f, "muzzle");
            Hand(g, 0, -0.12f, 0.14f, -0.2f);
            return m;
        }

        Model BuildRocket()
        {
            var M = MT; var A = accents[4];
            var m = NewModel("ROCKET", new Vector3(0.28f, -0.3f, -0.6f));
            var g = m.gun;
            CylZ(g, 0.085f, 0.085f, 0.72f, M["gun"], 0, 0.03f, -0.22f, 10);
            CylZ(g, 0.1f, 0.085f, 0.08f, M["dark"], 0, 0.03f, 0.16f, 10);
            CylZ(g, 0.095f, 0.095f, 0.05f, M["dark"], 0, 0.03f, -0.56f, 10);
            CylZ(g, 0.06f, 0.06f, 0.02f, M["black"], 0, 0.03f, -0.59f, 10);
            B(g, 0.03f, 0.05f, 0.12f, M["dark"], 0, 0.13f, -0.2f);
            B(g, 0.07f, 0.16f, 0.08f, M["grip"], 0, -0.1f, 0.02f, -0.2f);
            B(g, 0.06f, 0.12f, 0.07f, M["grip"], 0, -0.08f, -0.3f, -0.1f);
            foreach (float z in new[] { -0.45f, -0.05f }) CylZ(g, 0.089f, 0.089f, 0.03f, A, 0, 0.03f, z, 10);
            m.nose = W.Cone(g, 0.06f, 0.14f, M["rocketRed"], 0, 0.03f, -0.6f, -Mathf.PI / 2, 0, 0, false, 8).transform;
            m.ball = UKFx.Shape(g, UKFx.Sphere, W.V(0, 0.03f, -0.58f), Vector3.one * 0.14f, M["black"]).transform;
            m.ball.gameObject.SetActive(false);
            m.muzzle = W.J(g, 0, 0.03f, -0.66f, "muzzle");
            Hand(g, 0, -0.1f, 0.06f, -0.2f);
            return m;
        }

        // silahsızken görünen sağ yumruk
        Transform BuildIdleFist()
        {
            var f = W.J(vm, 0.3f, -0.3f, -0.52f, "fist");
            var a = ViewArms.BuildArm(f, MT, "plain", out _, out _, out _);
            a.localScale = new Vector3(-1, 1, 1);
            a.localRotation = W.Q(0.42f, 0.5f, -0.15f);
            f.gameObject.SetActive(false);
            return f;
        }

        // ------------------------------------------------------------ sahiplik
        public void ResetAll(bool keepOwned = true)
        {
            if (!keepOwned)
            {
                for (int i = 0; i < N; i++) { owned[i] = false; for (int v = 0; v < 3; v++) varOwned[i][v] = false; variant[i] = 0; }
                armsOwned[0] = true; armsOwned[1] = false; hookOwned = false; arm = 0;
            }
            cur = System.Array.IndexOf(owned, true);
            last = cur;
            for (int i = 0; i < N; i++) cd[i] = 0;
            switchT = 1; switchTime = -10; equipSpin = 0;
            pierceCharge = sharpCharge = coreCharge = cannonCharge = 0; pierceReady = false;
            sharpCharges = 3; coinCharges = 4; corePopT = 1; pumps = 0; pumpAnim = 1; sawOut = false;
            heat = heatBurst = nailT = barrelSpin = 0; magnetCharges = 3; railCharge = 1; railWasReady = true; railHeat = 0;
            freezeEnergy = 1; freezeActive = false; fuel = 1; flaming = false; rocketLoadT = 1;
            punchCd = blastCd = hookCd = cannonCd = 0; blastHold = 0; hook = null;
            recoil = recoilRot = swayX = swayY = 0; flashT = 0; hammerT = 1; coinFlick = 1; pendingCasing = -1;
            sprZ.Reset(); sprY.Reset(); sprR.Reset();
            lastShotgunHitEnemy = null;
            UKCoin.ClearAll();
            magnets.Clear();
            if (UKAudio.I) { UKAudio.I.Loop("pierce", false); UKAudio.I.Loop("flame", false); }
            if (rope) rope.enabled = false;
            if (hookTip) hookTip.gameObject.SetActive(false);
            ApplyVisual();
        }

        public bool Give(int i)
        {
            bool first = !owned[i];
            owned[i] = true;
            bool any = false;
            foreach (var b in varOwned[i]) any |= b;
            if (!any) varOwned[i][0] = true;
            if (!varOwned[i][variant[i]]) variant[i] = System.Array.IndexOf(varOwned[i], true);
            last = cur;
            cur = i;
            switchT = 0;
            equipSpin = i == 0 ? 1 : 0;
            switchTime = Time.time;
            CancelCharges();
            ApplyVisual();
            return first;
        }

        public bool GiveArm(string id)
        {
            if (id == "hook") { bool f = !hookOwned; hookOwned = true; return f; }
            int i = id == "knuckle" ? 1 : 0;
            bool first = !armsOwned[i];
            armsOwned[i] = true;
            arm = i;
            return first;
        }

        // Dükkân sahipliğini uygula. Revolver (Piercer) her zaman vardır.
        public void ApplyLoadout(System.Func<string, bool> has, bool all)
        {
            for (int i = 0; i < N; i++)
            {
                var W_ = WEAPONS[i];
                bool bas = all || i == 0 || has(W_.id);
                owned[i] = bas;
                for (int v = 0; v < 3; v++) varOwned[i][v] = bas && (v == 0 || all || has(W_.id + "." + W_.variants[v].id));
                if (!varOwned[i][variant[i]]) variant[i] = 0;
                alt[i] = (all || has("alt." + W_.id)) && UKGame.I.progress.AltOn(W_.id);
            }
            armsOwned[1] = all || has("arm.knuckle");
            if (!armsOwned[arm]) arm = 0;
            hookOwned = all || has("arm.hook");
            if (cur < 0 || !owned[cur]) { cur = 0; switchT = 0; equipSpin = 1; switchTime = Time.time; }
            ApplyVisual();
        }

        public void SetUnarmed()
        {
            for (int i = 0; i < N; i++) owned[i] = false;
            cur = -1;
            ApplyVisual();
        }

        void ApplyVisual()
        {
            if (models[0] == null) return;
            for (int i = 0; i < N; i++)
            {
                var c = WEAPONS[i].variants[variant[i]].color;
                SetMat(accents[i], c);
                var m = models[i];
                if (m.altGun != null)
                {
                    m.gun.gameObject.SetActive(!alt[i]);
                    m.altGun.gameObject.SetActive(alt[i]);
                    m.muzzle = alt[i] ? m.muzzleAlt : m.muzzleBase;
                }
            }
        }

        static void SetMat(Material m, Color c)
        {
            if (m.HasProperty("_Color")) m.SetColor("_Color", c);
            if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", c);
        }

        void Select(int i)
        {
            if (i < 0 || i >= N || !owned[i]) return;
            sprR.Kick(-2.2f);
            idleT = 0;
            if (i == cur)
            {
                int v = variant[i];
                for (int kk = 1; kk <= 3; kk++) { int c = (variant[i] + kk) % 3; if (varOwned[i][c]) { v = c; break; } }
                if (v == variant[i]) return;
                variant[i] = v;
                switchT = 0.3f;
                equipSpin = i == 0 ? 1 : 0;
                CancelCharges();
                ApplyVisual();
                UKAudio.I.Play("uiClick");
                UKGame.I.hud.WeaponMessage(WEAPONS[i].variants[v].name, WEAPONS[i].variants[v].color);
                return;
            }
            last = cur;
            cur = i;
            switchT = 0;
            equipSpin = i == 0 ? 1 : 0;
            switchTime = Time.time;
            CancelCharges();
            UKAudio.I.Play("uiClick");
        }

        void SwitchArm()
        {
            int next = (arm + 1) % 2;
            if (!armsOwned[next]) return;
            arm = next;
            UKAudio.I.Play("uiClick");
            UKGame.I.hud.WeaponMessage(ARM_NAMES[next], next == 1 ? RED : BLUE);
        }

        int NextOwned(int dir)
        {
            for (int kk = 1; kk <= N; kk++) { int i = ((cur + dir * kk) % N + N) % N; if (owned[i]) return i; }
            return cur;
        }

        void CancelCharges()
        {
            pierceCharge = sharpCharge = coreCharge = cannonCharge = 0;
            pierceReady = false;
            freezeActive = false;
            flaming = false;
            UKAudio.I.Loop("pierce", false);
            UKAudio.I.Loop("flame", false);
        }

        public void OnMove(string ev)
        {
            if (ev == "land") sprY.Kick(-1.2f);
            else if (ev == "jump") sprY.Kick(0.9f);
            else if (ev == "dash") { arms.Play("dash"); sprR.Kick(0.8f); }
            else if (ev == "slam") arms.Play("slam");
            else if (ev == "wall") { arms.Play("wall"); sprY.Kick(1.2f); }
        }

        public void ParryAnim() { arms.Play("parry"); arms.Flash(); }

        // Dükkândan alınan silahı / varyantı hemen eline al
        public void Equip(int w)
        {
            if (w < 0 || w >= N || !owned[w]) return;
            if (cur != w) { last = cur; cur = w; }
            switchT = 0;
            equipSpin = w == 0 ? 1 : 0;
            switchTime = Time.time;
            CancelCharges();
            ApplyVisual();
        }

        public void EquipVariant(int w, int v)
        {
            if (w < 0 || w >= N || !owned[w] || !varOwned[w][v]) return;
            variant[w] = v;
            Equip(w);
        }

        // V2 karakteri: kırmızı Feedbacker
        public void SetSkin(bool v2)
        {
            if (!MT.TryGetValue("blue", out var m)) return;
            var c = v2 ? new Color(0.85f, 0.25f, 0.16f) : new Color(0.29f, 0.55f, 1f);
            SetMat(m, c);
            if (m.HasProperty("_EmissionColor")) m.SetColor("_EmissionColor", c * 0.25f);
        }

        // Sunakta dönen silah / kol modeli (görünür modelin kopyası)
        public void PickupModel(string weapon, Transform holder)
        {
            Transform t;
            if (int.TryParse(weapon, out int i) && i >= 0 && i < N && models[i] != null)
            {
                t = Instantiate(models[i].gun.gameObject, holder).transform;
                t.gameObject.SetActive(true);
                t.localScale = Vector3.one * 2.6f;
            }
            else
            {
                t = ViewArms.BuildArm(holder, MT, weapon == "knuckle" ? "knuckle" : "whiplash", out _, out _, out _);
                t.localScale = Vector3.one * 3.2f;
            }
            t.localPosition = Vector3.zero;
            t.localRotation = Quaternion.Euler(0, 90, 0);
            SetLayer(t, 0);
        }
        public void SawReturned() { sawOut = false; UKAudio.I.Play("pump", 1, 1.3f); }

        // ------------------------------------------------------------ nişan / namlu
        Vector3 Aim(out Vector3 o)
        {
            o = P.EyePos;
            return UKGame.I.AssistDir(o, P.AimDir, 0.06f);
        }

        // Para yardımı: nişangâhın yakınındaki havadaki paraya yönel
        Vector3? CoinAssistDir(Vector3 o, Vector3 d)
        {
            int lvl = Mathf.RoundToInt(UKGame.I.settings.coinAssist);
            if (lvl <= 0 || UKCoin.All.Count == 0) return null;
            float bestA = lvl >= 2 ? 0.24f : 0.1f;
            Vector3? best = null;
            foreach (var c in UKCoin.All)
            {
                if (!c.alive || c.age < 0.06f) continue;
                Vector3 to = c.transform.position - o;
                float dist = to.magnitude;
                if (dist > 60) continue;
                float a = Mathf.Acos(Mathf.Clamp(Vector3.Dot(to / dist, d), -1, 1));
                if (a < bestA && !UKProjectile.WorldCast(o, to / dist, dist, out _)) { bestA = a; best = to / dist; }
            }
            return best;
        }

        public Vector3 MuzzleWorld()
        {
            if (cur < 0) return mainCam.transform.position;
            var c = vmCam != null ? vmCam : mainCam;
            Vector3 vp = c.WorldToViewportPoint(models[cur].muzzle.position);
            return mainCam.ViewportPointToRay(vp).GetPoint(0.9f);
        }

        Vector3 ToWorld(Transform t, float depth)
        {
            var c = vmCam != null ? vmCam : mainCam;
            Vector3 vp = c.WorldToViewportPoint(t.position);
            return mainCam.ViewportPointToRay(vp).GetPoint(depth);
        }

        void Kick(float kk, float rot = 1)
        {
            recoil = Mathf.Min(3, recoil + kk);
            recoilRot = Mathf.Min(3, recoilRot + kk * rot);
            sprZ.Kick(kk * 0.9f);
            sprR.Kick(kk * rot * 2.2f);
            idleT = 0;
            inspectT = 0;
            flashT = 0.055f;
            P.camKick = Mathf.Min(4.5f, P.camKick + kk * 0.5f);
        }

        void QuickdrawCheck()
        {
            if (Time.time - switchTime < 0.35f) { UKGame.I.style.Add("QUICKDRAW", 40, CurKey); switchTime = -10; }
        }

        // ------------------------------------------------------------ tarama (hitscan)
        public struct Hit { public float t; public Vector3 point; public UKEnemy enemy; public bool head; public UKCoin coin; public UKProjectile core; }
        public class Scan { public readonly List<Hit> hits = new List<Hit>(); public bool world; public Vector3 end, normal; public float worldT; }

        public static Scan DoScan(Vector3 o, Vector3 d, float max, bool coins = false, bool cores = false)
        {
            var s = new Scan();
            var raw = Physics.RaycastAll(o, d, max, UKFx.RayMask, QueryTriggerInteraction.Collide);
            System.Array.Sort(raw, (a, b) => a.distance.CompareTo(b.distance));
            float tW = max;
            var pcc = UKGame.I.player.cc;
            foreach (var h in raw)
            {
                if (h.collider == pcc || h.collider.isTrigger || h.collider is CharacterController || h.collider.GetComponent<UKHitbox>() != null) continue;
                tW = h.distance; s.world = true; s.normal = h.normal;
                break;
            }
            s.worldT = tW;
            s.end = o + d * tW;
            var seen = new HashSet<UKEnemy>();
            for (int i = 0; i < raw.Length; i++)
            {
                var h = raw[i];
                if (h.distance > tW) break;
                var hb = h.collider.GetComponent<UKHitbox>();
                if (hb == null || hb.owner == null || hb.owner.dead || seen.Contains(hb.owner)) continue;
                if (hb.owner.State == "spawn") continue;
                seen.Add(hb.owner);
                hb = UKHitbox.PreferHead(raw, i, hb, 0.9f, out var hh);
                s.hits.Add(new Hit { t = hh.distance, point = hh.point, enemy = hb.owner, head = hb.head });
            }
            float SphereT(Vector3 c, float r)
            {
                Vector3 oc = o - c;
                float b = Vector3.Dot(oc, d), cc = oc.sqrMagnitude - r * r, disc = b * b - cc;
                if (disc < 0) return -1;
                float t = -b - Mathf.Sqrt(disc);
                return t < 0 || t > tW ? -1 : t;
            }
            if (coins)
            {
                int lvl = Mathf.RoundToInt(UKGame.I.settings.coinAssist);
                float r = lvl >= 2 ? 0.9f : lvl >= 1 ? 0.7f : 0.55f;
                foreach (var c in UKCoin.All) { if (!c.alive) continue; float t = SphereT(c.transform.position, r); if (t >= 0) s.hits.Add(new Hit { t = t, point = o + d * t, coin = c }); }
            }
            if (cores)
                foreach (var p in UKProjectile.All)
                {
                    if (p.dead || p.kind != UKProjectile.Kind.Core || !p.fromPlayer) continue;
                    float t = SphereT(p.transform.position, 0.6f);
                    if (t >= 0) s.hits.Add(new Hit { t = t, point = o + d * t, core = p });
                }
            s.hits.Sort((a, b) => a.t.CompareTo(b.t));
            return s;
        }

        void Impact(Scan r, bool big = false)
        {
            if (!r.world) return;
            var fx = UKFx.I;
            Vector3 p = r.end, n = r.normal;
            fx.Spark(p, n, big ? 14 : 7, big ? 10 : 7, new Color(1f, 0.82f, 0.5f), 0.3f, 0.045f, 0.7f);
            fx.BulletHole(p, n, big ? 0.3f : 0.16f);
            fx.Smoke(p + n * 0.1f, big ? 4 : 2, new Color(0.6f, 0.55f, 0.5f), big ? 0.8f : 0.45f, 0.8f, 0.9f);
            fx.Star(p + n * 0.08f, new Color(1f, 0.88f, 0.63f), big ? 1.4f : 0.7f, 0.06f, 1.6f);
            fx.Debris(p, n, big ? 5 : 2, big ? 6 : 4);
        }

        void EjectCasing(bool red)
        {
            var m = models[cur];
            Vector3 from = m.eject != null ? ToWorld(m.eject, 0.55f) : ToWorld(m.muzzle, 0.55f);
            Vector3 right = mainCam.transform.right;
            UKFx.I.Casing(from, right * Random.Range(2.5f, 4f) + Vector3.up * Random.Range(2f, 3.5f) + P.vel * 0.8f, red);
        }

        // ------------------------------------------------------------ güncelleme
        public void Tick(float dt)
        {
            var game = UKGame.I;
            var p = P;
            for (int i = 0; i < N; i++) cd[i] = Mathf.Max(0, cd[i] - dt);
            punchCd = Mathf.Max(0, punchCd - dt);
            blastCd = Mathf.Max(0, blastCd - dt);
            hookCd = Mathf.Max(0, hookCd - dt);
            cannonCd = Mathf.Max(0, cannonCd - dt);
            coinCharges = Mathf.Min(4, coinCharges + dt / COIN_TIME);
            sharpCharges = Mathf.Min(3, sharpCharges + dt / 2.5f);
            magnetCharges = Mathf.Min(3, magnetCharges + dt / 3);
            railCharge = Mathf.Min(1, railCharge + dt / RAIL_TIME);
            railHeat = Mathf.Max(0, railHeat - dt * 0.6f);
            if (!freezeActive) freezeEnergy = Mathf.Min(1, freezeEnergy + dt * 0.15f);
            if (!flaming) fuel = Mathf.Min(1, fuel + dt * 0.2f);
            if (heatBurst <= 0) heat = Mathf.Max(0, heat - dt * 0.08f);
            barrelSpin = Mathf.Lerp(barrelSpin, 0, 1 - Mathf.Exp(-3 * dt));
            rocketLoadT = Mathf.Min(1, rocketLoadT + dt / 0.8f);
            if (owned[3] && railCharge >= 1 && !railWasReady) { railWasReady = true; UKAudio.I.Play("railReady"); }
            pumpAnim = Mathf.Min(1, pumpAnim + dt / 0.6f);
            corePopT = Mathf.Min(1, corePopT + dt / 0.9f);
            hammerT = Mathf.Min(1, hammerT + dt / 0.25f);
            coinFlick = Mathf.Min(1, coinFlick + dt / 0.3f);
            magnets.RemoveAll(m => m == null || m.dead);

            bool canAct = !p.dead && !p.frozen && game.state == UKGame.State.Playing;
            if (canAct)
            {
                if (UKInput.Down(UKKey.N1)) Select(0);
                if (UKInput.Down(UKKey.N2)) Select(1);
                if (UKInput.Down(UKKey.N3)) Select(2);
                if (UKInput.Down(UKKey.N4)) Select(3);
                if (UKInput.Down(UKKey.N5)) Select(4);
                if (UKInput.Down(UKKey.Q) && last >= 0) Select(last);
                float sc = UKInput.Scroll;
                if (Armed && sc > 0.1f) Select(NextOwned(1)); else if (Armed && sc < -0.1f) Select(NextOwned(-1));
                if (UKInput.Down(UKKey.G)) SwitchArm();
                if (UKInput.Down(UKKey.E)) ThrowHook();
                ArmLogic(dt);
                if (!Armed) { if (UKInput.Down(UKKey.Mouse0)) Punch(); }
                else if (switchT >= 0.8f) FireLogic(dt);
            }
            else if (flaming) { flaming = false; UKAudio.I.Loop("flame", false); }
            UpdateHook(dt);
            Animate(dt);
        }

        void ArmLogic(float dt)
        {
            if (ArmId == "knuckle")
            {
                // basılı tut → şok dalgası
                if (UKInput.Held(UKKey.F))
                {
                    blastHold += dt;
                    if (blastHold > 0.35f && blastCd <= 0) { Blast(); blastHold = -10; }
                }
                else blastHold = 0;
            }
            if (UKInput.Down(UKKey.F)) Punch();
        }

        void FireLogic(float dt)
        {
            bool fire = UKInput.Held(UKKey.Mouse0), altH = UKInput.Held(UKKey.Mouse1), altD = UKInput.Down(UKKey.Mouse1), fireD = UKInput.Down(UKKey.Mouse0);
            string v = VarId;
            var au = UKAudio.I;
            switch (cur)
            {
                case 0:
                    if (v == "piercer")
                    {
                        if (altH && cd[0] <= 0)
                        {
                            if (pierceCharge == 0) au.Loop("pierce", true, "chargeLoop", 1);
                            pierceCharge = Mathf.Min(1, pierceCharge + dt / 0.55f);
                            if (pierceCharge >= 1 && !pierceReady) { pierceReady = true; au.Play("chargeReady"); au.Loop("pierce", false); }
                        }
                        else if (pierceCharge > 0)
                        {
                            au.Loop("pierce", false);
                            if (pierceCharge >= 1) FirePiercer();
                            pierceCharge = 0; pierceReady = false;
                        }
                        if (fire && cd[0] <= 0 && pierceCharge <= 0) FireRevolver();
                    }
                    else if (v == "marksman")
                    {
                        if (altD) { if (coinCharges >= 1) TossCoin(); else au.Play("empty"); }
                        if (fire && cd[0] <= 0) FireRevolver();
                    }
                    else
                    {
                        if (altH && cd[0] <= 0 && sharpCharges >= 1)
                        {
                            if (sharpCharge == 0) au.Loop("pierce", true, "chargeLoop", 0.8f);
                            sharpCharge = Mathf.Min(1, sharpCharge + dt / 0.4f);
                        }
                        else if (sharpCharge > 0)
                        {
                            au.Loop("pierce", false);
                            if (sharpCharge >= 1) FireSharpshooter();
                            sharpCharge = 0;
                        }
                        if (fire && cd[0] <= 0 && sharpCharge <= 0) FireRevolver();
                    }
                    break;
                case 1:
                    if (v == "core")
                    {
                        if (altH && cd[1] <= 0) coreCharge = Mathf.Min(1, coreCharge + dt / 0.5f);
                        else if (coreCharge > 0) { LaunchCore(coreCharge); coreCharge = 0; }
                        if (fire && cd[1] <= 0 && coreCharge <= 0) FireShotgun(0);
                    }
                    else if (v == "pump")
                    {
                        if (altD && cd[1] <= 0)
                        {
                            pumps++;
                            cd[1] = 0.24f;
                            pumpAnim = 0.35f;
                            au.Play("pump", 1, 1.2f + pumps * 0.1f, true);
                            if (pumps >= 3) au.Play("overpump");
                        }
                        if (fire && cd[1] <= 0) { if (pumps >= 3) Overpump(); else FireShotgun(pumps); pumps = 0; }
                    }
                    else
                    {
                        if (altD && !sawOut) ThrowSaw();
                        if (fire && cd[1] <= 0) FireShotgun(0);
                    }
                    break;
                case 2:
                    NailLogic(dt, v, fire, altD);
                    break;
                case 3:
                    if (fireD) { if (railCharge >= 1) FireRail(v); else au.Play("empty"); }
                    break;
                case 4:
                    RocketLogic(dt, v, fire, altH);
                    break;
            }
        }

        // ------------------------------------------------------------ revolver
        void FireRevolver()
        {
            var game = UKGame.I;
            bool slab = alt[0];
            cd[0] = slab ? 0.62f : 0.36f;
            Kick(slab ? 1.5f : 0.8f, 1.2f);
            drumTarget += 60;
            hammerT = 0;
            UKAudio.I.Play("revolver", 1, slab ? 0.72f : 1, slab);
            if (slab) P.Shake(0.12f);
            Vector3 d = Aim(out var o);
            d = CoinAssistDir(o, P.AimDir) ?? d;
            var r = DoScan(o, d, 400, true, true);
            Vector3 end = r.end;
            if (r.hits.Count > 0)
            {
                var h = r.hits[0];
                end = h.point;
                if (h.coin != null) Ricochet(h.coin, 0);
                else if (h.core != null) { h.core.Detonate(true); game.style.Add("CORE SNIPE", 80, "revolver"); }
                else { h.enemy.Hit(slab ? 1.7f : 1, h.point, d, h.head, "revolver", slab ? 7 : 3); QuickdrawCheck(); }
            }
            else Impact(r);
            Vector3 from = MuzzleWorld();
            UKFx.I.Tracer(from, end, slab ? new Color(1f, 0.69f, 0.44f) : new Color(1f, 0.94f, 0.69f), slab ? 0.06f : 0.035f, 0.09f);
            UKFx.I.Tracer(from, Vector3.Lerp(from, end, Mathf.Min(1, 3 / Mathf.Max(1, Vector3.Distance(from, end)))), Color.white, 0.06f, 0.05f);
            UKFx.I.Smoke(from, 1, new Color(0.69f, 0.63f, 0.56f), 0.25f, 0.4f, 0.5f);
            UKFx.I.Flash(mainCam.transform.position, new Color(1f, 0.75f, 0.44f), 3, 10, 0.05f);
        }

        void FirePiercer()
        {
            var game = UKGame.I;
            cd[0] = 0.5f;
            Kick(1.7f, 1.6f);
            drumTarget += 60;
            hammerT = 0;
            UKAudio.I.Play("piercer");
            P.Shake(0.25f);
            Vector3 d = Aim(out var o);
            d = CoinAssistDir(o, P.AimDir) ?? d;
            var r = DoScan(o, d, 400, true, true);
            Vector3 end = r.end;
            bool stopped = false;
            foreach (var h in r.hits)
            {
                if (h.coin != null) { Ricochet(h.coin, 1); end = h.point; stopped = true; break; }
                if (h.core != null) { h.core.Detonate(true); game.style.Add("CORE SNIPE", 80, "revolver"); end = h.point; stopped = true; break; }
                h.enemy.Hit(alt[0] ? 3.4f : 2.5f, h.point, d, h.head, "revolver", 8, 1.5f);
                QuickdrawCheck();
            }
            if (!stopped) Impact(r, true);
            Vector3 from = MuzzleWorld();
            UKFx.I.Tracer(from, end, new Color(0.44f, 0.75f, 1f), 0.16f, 0.35f);
            UKFx.I.Tracer(from, end, Color.white, 0.05f, 0.22f);
            UKFx.I.Lightning(from, end, new Color(0.62f, 0.85f, 1f), 0.025f, 0.2f, 10, 0.12f);
            UKFx.I.Flash(mainCam.transform.position, new Color(0.5f, 0.75f, 1f), 5, 14, 0.1f);
        }

        // Sharpshooter: duvarlardan 3 kez seken, düşmanları delen ışın
        void FireSharpshooter()
        {
            var game = UKGame.I;
            sharpCharges -= 1;
            cd[0] = 0.5f;
            Kick(1.6f, 1.4f);
            drumTarget += 180;
            hammerT = 0;
            UKAudio.I.Play("piercer", 1, 1.25f, true);
            P.Shake(0.2f);
            Vector3 d = Aim(out var o);
            Vector3 from = MuzzleWorld();
            var hitSet = new HashSet<UKEnemy>();
            for (int bounce = 0; bounce < 4; bounce++)
            {
                var r = DoScan(o, d, 200);
                foreach (var h in r.hits)
                {
                    if (hitSet.Contains(h.enemy)) continue;
                    hitSet.Add(h.enemy);
                    h.enemy.Hit(2 + bounce * 0.5f, h.point, d, h.head, "revolver", 6, 1.5f);
                    if (bounce > 0) game.style.Add("RICOSHOT", 70, "revolver", bounce + 1);
                }
                UKFx.I.Tracer(from, r.end, new Color(1f, 0.42f, 0.29f), 0.1f, 0.35f);
                UKFx.I.Tracer(from, r.end, Color.white, 0.035f, 0.25f);
                if (!r.world) break;
                UKFx.I.Spark(r.end, r.normal, 8, 7, new Color(1f, 0.54f, 0.38f), 0.3f, 0.05f, 0.6f);
                d = Vector3.Reflect(d, r.normal).normalized;
                o = r.end + r.normal * 0.05f;
                var a = UKGame.I.AssistDir(o, d, 0.35f, true);
                d = a;
                from = o;
            }
            UKFx.I.Flash(mainCam.transform.position, new Color(1f, 0.38f, 0.25f), 5, 14, 0.1f);
        }

        void TossCoin()
        {
            var p = P;
            coinCharges -= 1;
            coinFlick = 0;
            Vector3 f = p.AimDir;
            Vector3 pos = p.EyePos + f * 0.6f - Vector3.up * 0.1f;
            UKCoin.Spawn(pos, f * 13 + Vector3.up * 8.5f + p.vel * 0.6f);
            arms.Play("coin");
            UKAudio.I.Play("coin");
        }

        public void Ricochet(UKCoin coin, int chain)
        {
            var game = UKGame.I;
            coin.Kill();
            Vector3 cp = coin.transform.position;
            UKAudio.I.PlayAt("ricochet", cp, 1, 1 + chain * 0.08f);
            UKFx.I.Burst(cp, 14, 9, new Color(1f, 0.82f, 0.29f), 0.35f, 0.05f);
            UKFx.I.Star(cp, new Color(1f, 0.88f, 0.5f), 1.8f, 0.2f, 1.8f);
            UKCoin best = null;
            float bd = 1e9f;
            foreach (var c in UKCoin.All)
            {
                if (!c.alive || c == coin) continue;
                float dd = Vector3.Distance(c.transform.position, cp);
                if (dd < 70 && dd < bd && !UKProjectile.WorldCast(cp, (c.transform.position - cp).normalized, dd, out _)) { best = c; bd = dd; }
            }
            if (best != null && chain < 10)
            {
                UKFx.I.Tracer(cp, best.transform.position, new Color(1f, 0.82f, 0.29f), 0.06f, 0.28f);
                Ricochet(best, chain + 1);
                return;
            }
            UKEnemy target = null;
            Vector3 aimPt = cp;
            bool headAim = false;
            bd = 1e9f;
            foreach (var e in UKEnemy.All)
            {
                if (e.dead || e.State == "spawn" || e.type == "trainer") continue;
                Vector3 hp = e.HeadPos;
                float dd = Vector3.Distance(cp, hp);
                if (dd > 100 || dd >= bd) continue;
                if (!UKProjectile.WorldCast(cp, (hp - cp).normalized, dd, out _)) { target = e; bd = dd; aimPt = hp; headAim = true; }
                else
                {
                    Vector3 c = e.Center;
                    if (!UKProjectile.WorldCast(cp, (c - cp).normalized, Vector3.Distance(cp, c), out _)) { target = e; bd = dd; aimPt = c; headAim = false; }
                }
            }
            if (target != null)
            {
                UKFx.I.Tracer(cp, aimPt, new Color(1f, 0.82f, 0.29f), 0.08f, 0.34f);
                UKFx.I.Tracer(cp, aimPt, Color.white, 0.025f, 0.2f);
                game.style.Add("RICOSHOT", 90 + chain * 40, "revolver", chain > 0 ? chain + 1 : 0);
                target.Hit(1.5f + chain, aimPt, (aimPt - cp).normalized, headAim, "revolver", 6, 2);
                game.Hitstop(0.045f);
            }
            else
            {
                Vector3 dir = new Vector3(Random.Range(-1f, 1f), Random.Range(-0.3f, 0.6f), Random.Range(-1f, 1f)).normalized;
                Vector3 end = UKProjectile.WorldCast(cp, dir, 40, out var h) ? h.point : cp + dir * 40;
                UKFx.I.Tracer(cp, end, new Color(1f, 0.82f, 0.29f), 0.05f, 0.2f);
            }
        }

        // ------------------------------------------------------------ shotgun
        void FireShotgun(int pmp)
        {
            if (alt[1]) { FireJackhammer(pmp); return; }
            var game = UKGame.I;
            cd[1] = 0.95f;
            Kick(1.6f + pmp * 0.4f, 1.4f);
            pumpAnim = 0;
            UKAudio.I.Play("shotgun", 1, 1 - pmp * 0.06f, pmp > 0);
            game.Schedule(0.33f, () => UKAudio.I.Play("pump"));
            P.Shake(0.2f + pmp * 0.08f);
            Vector3 d = Aim(out var o);
            Vector3 right = Vector3.Cross(Vector3.up, d).normalized;
            if (right.sqrMagnitude < 0.1f) right = Vector3.right;
            Vector3 up = Vector3.Cross(d, right).normalized;
            float spread = 0.085f * (1 + pmp * 0.6f), pd = 0.32f * (1 + pmp * 0.5f);
            var acc = new Dictionary<UKEnemy, Vector4>(); // x dmg, y head, z n, w t
            var accPt = new Dictionary<UKEnemy, Vector3>();
            Vector3 from = MuzzleWorld();
            for (int kk = 0; kk < 12; kk++)
            {
                float a = Random.value * Mathf.PI * 2, rr = Mathf.Sqrt(Random.value) * spread;
                Vector3 dir = (d + right * Mathf.Cos(a) * rr + up * Mathf.Sin(a) * rr).normalized;
                var r = DoScan(o, dir, 120, false, true);
                Vector3 end = r.end;
                if (r.hits.Count > 0)
                {
                    var h = r.hits[0];
                    end = h.point;
                    if (h.core != null) h.core.Detonate(true);
                    else
                    {
                        acc.TryGetValue(h.enemy, out var v);
                        v.x += pd * (h.head ? 1.5f : 1); if (h.head) v.y++; v.z++; v.w = v.z == 1 ? h.t : Mathf.Min(v.w, h.t);
                        acc[h.enemy] = v;
                        accPt[h.enemy] = h.point;
                    }
                }
                else if (r.world)
                {
                    if (kk % 2 == 0) UKFx.I.BulletHole(r.end, r.normal, 0.12f);
                    if (kk % 3 == 0) UKFx.I.Spark(end, r.normal, 3, 5, new Color(1f, 0.82f, 0.5f), 0.2f, 0.04f, 0.8f);
                }
                UKFx.I.Tracer(from, end, new Color(1f, 0.88f, 0.63f), 0.028f, 0.07f);
            }
            foreach (var kv in acc)
            {
                var v = kv.Value;
                if (v.w < 4.5f) { lastShotgunHitEnemy = kv.Key; lastShotgunHitTime = Time.time; }
                kv.Key.Hit(v.x, accPt[kv.Key], d, v.y >= Mathf.Max(2, v.z * 0.5f), "shotgun", 3 + v.z * 1.3f, 1, false, false, false, false, false, (int)v.z);
            }
            if (acc.Count > 0) QuickdrawCheck();
            UKFx.I.Smoke(from, 3, new Color(0.63f, 0.56f, 0.5f), 0.5f, 0.7f, 0.6f);
            UKFx.I.Flash(mainCam.transform.position, new Color(1f, 0.69f, 0.38f), 5, 12, 0.07f);
            pendingCasing = 0.36f;
        }

        // Shotgun parry: yakından shotgun isabetinin hemen ardından yumruk
        public bool TakeShotgunParry(UKEnemy e)
        {
            if (lastShotgunHitEnemy == e && Time.time - lastShotgunHitTime < 0.3f) { lastShotgunHitEnemy = null; return true; }
            return false;
        }

        // JACKHAMMER: önündeki koniye dev piston darbesi. Havada yere ateş → yüksek zıplama
        void FireJackhammer(int pmp)
        {
            var game = UKGame.I;
            var p = P;
            cd[1] = 1.05f;
            Kick(2.6f + pmp * 0.5f, 1.6f);
            pumpAnim = 0;
            UKAudio.I.Play("shotgun", 1, 0.68f, true);
            UKAudio.I.Play("punchHit", 1, 0.8f);
            game.Schedule(0.4f, () => UKAudio.I.Play("pump", 1, 0.8f));
            p.Shake(0.35f + pmp * 0.1f);
            Vector3 d = Aim(out var o);
            float range = 7.5f + pmp * 1.5f, dmg = 4.2f * (1 + pmp * 0.35f);
            int hits = 0;
            foreach (var e in new List<UKEnemy>(UKEnemy.All))
            {
                if (e.dead || e.State == "spawn") continue;
                Vector3 c = e.Center, v = c - o;
                float dist = v.magnitude;
                if (dist > range + e.radius) continue;
                if (Vector3.Dot(v / Mathf.Max(dist, 0.01f), d) < 0.8f && dist > 1.6f) continue;
                if (UKProjectile.WorldCast(o, v / Mathf.Max(dist, 0.01f), dist, out _)) continue;
                float kk = 1 - Mathf.Clamp(dist / (range * 2.2f), 0, 0.5f);
                var hd = d; hd.y = Mathf.Max(hd.y, 0.25f);
                e.Hit(dmg * kk, c, hd.normalized, false, "shotgun", 24 + pmp * 6, 1, false, false, false, false, false, 12);
                hits++;
            }
            if (hits > 0) { QuickdrawCheck(); if (hits > 1) game.style.Add("JACKHAMMERED", 60 * hits, "shotgun"); }
            var r = DoScan(o, d, range);
            if (r.world)
            {
                UKFx.I.Spark(r.end, r.normal, 18, 9, new Color(1f, 0.82f, 0.5f), 0.35f, 0.07f, 0.9f);
                UKFx.I.Ring(r.end + r.normal * 0.05f, new Color(1f, 0.69f, 0.38f), 2.4f, 0.35f);
                UKFx.I.BulletHole(r.end, r.normal, 0.4f);
                float near = 1 - r.worldT / range;
                if (d.y < -0.55f && near > 0.2f)
                {
                    p.vel.y = Mathf.Max(p.vel.y, 11 + near * 9 + pmp * 3);
                    p.grounded = false;
                    game.style.Add("JACKHAMMER JUMP", 40, "shotgun");
                }
                else p.vel -= d * near * 9;
            }
            else p.vel -= d * 2.5f;
            Vector3 from = MuzzleWorld();
            UKFx.I.Shell(from + d * 1.2f, new Color(1f, 0.75f, 0.44f), 1.6f + pmp * 0.4f, 0.22f);
            UKFx.I.Spark(from, d, 14, 16, new Color(1f, 0.75f, 0.38f), 0.25f, 0.05f, 0.35f);
            UKFx.I.Smoke(from, 4, new Color(0.63f, 0.56f, 0.5f), 0.6f, 0.8f, 0.6f);
            UKFx.I.Flash(mainCam.transform.position, new Color(1f, 0.69f, 0.38f), 6, 12, 0.08f);
            pendingCasing = 0.4f;
        }

        void LaunchCore(float charge)
        {
            var p = P;
            cd[1] = 0.9f;
            Kick(1.1f, 0.6f);
            pumpAnim = 0;
            corePopT = 0;
            Vector3 d = p.AimDir;
            Vector3 pos = p.EyePos + d * 0.8f - Vector3.up * 0.12f;
            UKProjectile.Spawn(UKProjectile.Kind.Core, pos, d * (18 + 26 * charge) + Vector3.up * (2 + 2 * charge) + p.vel * 0.3f, true, 0, BLUE, null, 0.22f);
            UKAudio.I.Play("coreLaunch");
            UKGame.I.Schedule(0.3f, () => UKAudio.I.Play("pump"));
        }

        void Overpump()
        {
            var p = P;
            cd[1] = 1.2f;
            Kick(2.8f, 2);
            pumpAnim = 0;
            UKAudio.I.Play("shotgun");
            UKGame.I.Explode(p.EyePos + p.AimDir * 1.2f, 7, 6, false, 35, 22, "shotgun");
        }

        // Sawed-On: zincirli testereyi fırlat (gider, biçer, geri gelir)
        void ThrowSaw()
        {
            var p = P;
            sawOut = true;
            Kick(0.8f, 0.5f);
            Vector3 d = p.AimDir;
            UKProjectile.Spawn(UKProjectile.Kind.Chainsaw, p.EyePos + d * 0.8f, d * 38, true, 0.4f, RED);
            UKAudio.I.Play("chainsaw");
            UKAudio.I.Play("swing");
        }

        // ------------------------------------------------------------ nailgun
        void NailLogic(float dt, string v, bool fire, bool altD)
        {
            nailT -= dt;
            if (heatBurst > 0)
            {
                // Overheat: kızgın çivi yağmuru
                heatBurst -= dt;
                heat = Mathf.Max(0, heatBurst / 1.2f);
                if (nailT <= 0) { FireNail(true, 0.035f); nailT = 0.035f; }
                return;
            }
            if (fire && nailT <= 0)
            {
                if (v == "sawblade") { FireSawblade(); nailT = 0.3f; }
                else { FireNail(false, 0.03f); nailT = 0.075f; }
                if (v == "overheat") heat = Mathf.Min(1, heat + 0.03f);
            }
            if (altD)
            {
                if (v == "overheat")
                {
                    if (heat >= 1) { heatBurst = 1.2f; UKAudio.I.Play("overpump", 1, 1.6f, true); }
                    else UKAudio.I.Play("empty");
                }
                else if (magnetCharges >= 1) ThrowMagnet();
                else UKAudio.I.Play("empty");
            }
        }

        void FireNail(bool heated, float sp)
        {
            Vector3 d = Aim(out _);
            Vector3 dir = (d + new Vector3(Random.Range(-sp, sp), Random.Range(-sp, sp), Random.Range(-sp, sp))).normalized;
            UKProjectile.Spawn(UKProjectile.Kind.Nail, MuzzleWorld(), dir * 95, true, heated ? 0.3f : 0.14f, new Color(0.85f, 0.87f, 0.9f), null, 0.12f, null, heated);
            recoil = Mathf.Min(3, recoil + 0.12f);
            flashT = 0.03f;
            barrelSpin = 1;
            UKAudio.I.Play("nail", 0.8f, heated ? 1.2f : 1.4f);
        }

        void FireSawblade()
        {
            Vector3 d = Aim(out _);
            Vector3 from = MuzzleWorld();
            UKProjectile.Spawn(UKProjectile.Kind.Saw, from, d * 55, true, 0.55f, RED);
            Kick(0.35f, 0.4f);
            sawReload = 0;
            UKFx.I.Spark(from, d, 6, 8, new Color(1f, 0.69f, 0.38f), 0.2f, 0.04f, 0.4f);
            barrelSpin = 1;
            UKAudio.I.Play("chainsaw", 0.5f, 1.6f);
        }

        void ThrowMagnet()
        {
            var p = P;
            magnetCharges -= 1;
            Vector3 d = p.AimDir;
            var m = UKProjectile.Spawn(UKProjectile.Kind.Magnet, p.EyePos + d * 0.7f, d * 26 + Vector3.up * 4, true, 0, BLUE);
            magnets.Add(m);
            if (magnets.Count > 3) { magnets[0].Kill(); magnets.RemoveAt(0); }
            UKAudio.I.Play("coin", 1, 0.6f, true);
        }

        // ------------------------------------------------------------ railcannon
        void FireRail(string v)
        {
            var game = UKGame.I;
            var p = P;
            railCharge = 0;
            railWasReady = false;
            railHeat = 1;
            cd[3] = 0.8f;
            Kick(3, 1.2f);
            UKAudio.I.Play("rail", 1, v == "malicious" ? 0.8f : v == "screwdriver" ? 1.15f : 1, true);
            p.Shake(0.85f);
            Vector3 d = Aim(out var o);
            var r = DoScan(o, d, 500);
            Vector3 from = MuzzleWorld();
            Color col = v == "malicious" ? new Color(1f, 0.29f, 0.16f) : v == "screwdriver" ? new Color(0.35f, 1f, 0.48f) : new Color(0.25f, 0.91f, 1f);
            Vector3 end = r.end;
            if (v == "screwdriver")
            {
                if (r.hits.Count > 0)
                {
                    var h = r.hits[0];
                    end = h.point;
                    h.enemy.Hit(2, h.point, d, h.head, "rail", 6);
                    h.enemy.drill = 3;
                    game.style.Add("DRILLED", 60, "rail");
                }
            }
            else foreach (var h in r.hits) h.enemy.Hit(v == "malicious" ? 5 : 8, h.point, d, h.head, "rail", 25, 1.5f);
            if (r.hits.Count > 0) QuickdrawCheck();
            UKFx.I.Tracer(from, end, col, 0.45f, 0.7f);
            UKFx.I.Tracer(from, end, Color.white, 0.14f, 0.5f);
            for (int kk = 0; kk < 3; kk++) UKFx.I.Lightning(from, end, col, 0.03f, 0.35f, 14, 0.45f);
            if (v == "malicious") game.Explode(end, 8, 5, false, 35, 24, "rail");
            else if (r.world)
            {
                UKFx.I.Burst(end, 30, 12, col, 0.6f, 0.08f);
                UKFx.I.BulletHole(end, r.normal, 0.6f);
                UKFx.I.Smoke(end, 5, new Color(0.5f, 0.6f, 0.63f), 0.8f, 1, 1);
            }
            UKFx.I.Flash(end, col, 10, 20, 0.15f);
            UKFx.I.Flash(mainCam.transform.position, col, 6, 12, 0.1f);
            p.vel -= d * 7;
        }

        // ------------------------------------------------------------ rocket launcher
        void RocketLogic(float dt, string v, bool fire, bool altH)
        {
            var au = UKAudio.I;
            if (fire && cd[4] <= 0) FireRocket();
            if (v == "freeze")
            {
                bool want = altH && freezeEnergy > 0.02f;
                if (want != freezeActive) { freezeActive = want; au.Play(want ? "freeze" : "uiClick", 1, 0.6f, true); }
                if (freezeActive) freezeEnergy = Mathf.Max(0, freezeEnergy - dt * 0.3f);
            }
            else if (v == "cannon")
            {
                if (altH && cannonCd <= 0) cannonCharge = Mathf.Min(1, cannonCharge + dt / 0.8f);
                else if (cannonCharge > 0) { FireCannonball(cannonCharge); cannonCharge = 0; }
            }
            else
            {
                bool want = altH && fuel > 0.02f;
                if (want != flaming) { flaming = want; au.Loop("flame", want, "flame", 1.2f); }
                if (flaming) { fuel = Mathf.Max(0, fuel - dt * 0.35f); Flame(dt); }
            }
        }

        void FireRocket()
        {
            cd[4] = 0.85f;
            rocketLoadT = 0;
            Kick(1.4f, 0.8f);
            Vector3 d = Aim(out _);
            Vector3 from = MuzzleWorld();
            UKProjectile.Spawn(UKProjectile.Kind.Rocket, from, d * 42, true, 0, RED);
            UKAudio.I.Play("coreLaunch", 1, 0.8f, true);
            UKAudio.I.Play("dash", 0.6f);
            UKFx.I.Smoke(from, 4, new Color(0.54f, 0.52f, 0.5f), 0.6f, 0.8f, 0.4f);
        }

        void FireCannonball(float charge)
        {
            cannonCd = 4;
            Kick(2.4f, 1.4f);
            Vector3 d = Aim(out _);
            UKProjectile.Spawn(UKProjectile.Kind.Cannonball, MuzzleWorld(), d * (25 + 30 * charge) + Vector3.up * 2, true, 4 + 3 * charge, GREEN);
            UKAudio.I.Play("shotgun", 1, 0.6f, true);
            P.Shake(0.4f);
        }

        // Firestarter: kısa menzilli alev (düşmanları tutuşturur)
        void Flame(float dt)
        {
            Vector3 d = Aim(out var o);
            Vector3 from = MuzzleWorld();
            UKFx.I.Spark(from, d, 3, 16, Random.value < 0.5f ? new Color(1f, 0.48f, 0.13f) : new Color(1f, 0.75f, 0.25f), 0.35f, 0.12f, 0.25f);
            flameT -= dt;
            bool tick = flameT <= 0;
            if (tick) flameT = 0.2f;
            foreach (var e in new List<UKEnemy>(UKEnemy.All))
            {
                if (e.dead || e.State == "spawn") continue;
                Vector3 to = e.Center - o;
                float dist = to.magnitude;
                if (dist > 7.5f || Vector3.Dot(to / dist, d) < 0.8f) continue;
                e.burn = Mathf.Max(e.burn, 3);
                if (tick) e.Hit(0.25f, e.Center, d, false, "rocket", 1, 1, true);
            }
        }

        // ------------------------------------------------------------ kollar
        void Punch()
        {
            if (punchCd > 0) return;
            var game = UKGame.I;
            bool knuckle = ArmId == "knuckle";
            punchCd = knuckle ? 0.7f : 0.4f;
            arms.Play("punch");
            sprY.Kick(-0.6f);
            UKAudio.I.Play("punch", 1, knuckle ? 0.7f : 1, true);
            if (game.TryParry(false)) return;
            int pa = Mathf.RoundToInt(game.settings.parryAssist);
            game.parryBuffer = pa >= 2 ? 0.34f : pa >= 1 ? 0.26f : 0.18f; // erken basılan yumruk da yakalasın
            game.MeleePunch(knuckle);
        }

        // Knuckleblaster şok dalgası
        void Blast()
        {
            var p = P;
            blastCd = 3;
            arms.Play("punch");
            Vector3 pos = p.EyePos + p.AimDir;
            UKFx.I.Shell(pos, new Color(1f, 0.42f, 0.23f), 6, 0.4f);
            UKFx.I.Ring(p.transform.position, new Color(1f, 0.42f, 0.23f), 7, 0.5f);
            UKAudio.I.Play("explosion", 0.7f, 1.3f, true);
            p.Shake(0.5f);
            foreach (var e in new List<UKEnemy>(UKEnemy.All))
            {
                if (e.dead) continue;
                Vector3 c = e.Center;
                float dist = Vector3.Distance(c, pos);
                if (dist > 6 + e.radius) continue;
                var dir = c - pos; dir.y = 0.6f;
                e.Hit(1.2f, c, dir.normalized, false, "punch", 30);
            }
            foreach (var pr in new List<UKProjectile>(UKProjectile.All))
                if (!pr.dead && !pr.fromPlayer && Vector3.Distance(pr.transform.position, pos) < 6) { UKFx.I.Burst(pr.transform.position, 6, 5, new Color(1f, 0.54f, 0.38f), 0.3f, 0.05f); pr.Kill(); }
        }

        // Whiplash: kanca at — hafif düşmanı çek, ağır düşmana kendini çek
        void ThrowHook()
        {
            if (!hookOwned || hook != null || hookCd > 0) return;
            var p = P;
            Vector3 d = p.AimDir;
            hook = new Hook { phase = "out", pos = p.EyePos + d * 0.5f, vel = d * 90, t = 0 };
            arms.Play("hook");
            UKAudio.I.Play("walljump", 1, 0.7f, true);
        }

        void UpdateHook(float dt)
        {
            var h = hook;
            var p = P;
            if (h == null) { rope.enabled = false; hookTip.gameObject.SetActive(false); return; }
            h.t += dt;
            Vector3 hand = ToWorld(arms.HandAnchor, 0.6f);
            if (h.phase == "out")
            {
                Vector3 prev = h.pos;
                float sp = h.vel.magnitude;
                bool wall = UKProjectile.WorldCast(h.pos, h.vel / sp, sp * dt, out _);
                h.pos += h.vel * dt;
                var hb = UKProjectile.EnemyCast(prev, h.pos, 0.35f, out _);
                if (hb != null && hb.owner.type != "trainer") { h.target = hb.owner; h.phase = "pull"; h.t = 0; }
                if (h.phase == "out" && (wall || h.t > 0.45f)) h.phase = "back";
                if (h.target != null)
                {
                    UKAudio.I.PlayAt("punchHit", h.pos, 0.7f);
                    UKGame.I.style.Add("HOOKED", 30, null);
                    if (h.target.big) UKGame.I.hud.WeaponMessage("ÇEKİLİYOR", new Color(0.6f, 0.87f, 0.35f));
                }
            }
            else if (h.phase == "pull")
            {
                var e = h.target;
                if (e == null || e.dead || h.t > 0.9f) h.phase = "back";
                else
                {
                    h.pos = e.Center;
                    Vector3 to = e.Center - p.EyePos;
                    float dist = to.magnitude;
                    if (dist < 2.2f) h.phase = "back";
                    else if (e.big)
                    {
                        p.vel = to / dist * 34;
                        p.grounded = false;
                        p.slamming = false;
                    }
                    else
                    {
                        var v = -to / dist * 30;
                        v.y = Mathf.Max(v.y, 3);
                        e.Pull(v);
                    }
                }
            }
            else
            {
                Vector3 to = hand - h.pos;
                float d = to.magnitude;
                if (d < 1) { hook = null; hookCd = 0.35f; rope.enabled = false; hookTip.gameObject.SetActive(false); return; }
                h.pos += to / d * Mathf.Min(d, 110 * dt);
            }
            rope.enabled = true;
            rope.SetPosition(0, hand);
            rope.SetPosition(1, h.pos);
            hookTip.gameObject.SetActive(true);
            hookTip.position = h.pos;
            hookTip.rotation = Quaternion.LookRotation(h.pos - hand) * Quaternion.Euler(90, 0, 0);
        }

        // ------------------------------------------------------------ animasyon
        void Animate(float dt)
        {
            var p = P;
            var game = UKGame.I;
            switchT = Mathf.Min(1, switchT + dt / 0.3f);
            float sw = 1 - (1 - Mathf.Pow(1 - switchT, 3));
            recoil = Mathf.Lerp(recoil, 0, 1 - Mathf.Exp(-12 * dt));
            recoilRot = Mathf.Lerp(recoilRot, 0, 1 - Mathf.Exp(-9 * dt));
            Vector2 md = UKInput.MouseDelta;
            float rdt = Time.unscaledDeltaTime;
            swayX = Mathf.Lerp(swayX, Mathf.Clamp(-md.x * 0.009f, -0.06f, 0.06f), 1 - Mathf.Exp(-9 * rdt));
            swayY = Mathf.Lerp(swayY, Mathf.Clamp(-md.y * 0.009f, -0.06f, 0.06f), 1 - Mathf.Exp(-9 * rdt));
            float bt = p.BobT, ba = p.Bob;
            float bx = Mathf.Sin(bt * 0.95f) * 0.014f * ba, by = -Mathf.Abs(Mathf.Cos(bt * 0.95f)) * 0.016f * ba;
            float breath = Mathf.Sin(Time.time * 1.6f) * 0.004f * (1 - ba);
            float airY = Mathf.Clamp(-p.vel.y * 0.0012f, -0.03f, 0.03f);
            slideK = Mathf.Lerp(slideK, p.sliding ? 1 : 0, 1 - Mathf.Exp(-10 * dt));
            float sz = sprZ.Update(dt), sy = sprY.Update(dt), sr = sprR.Update(dt);
            bool idle = !UKInput.Held(UKKey.Mouse0) && !UKInput.Held(UKKey.Mouse1) && new Vector2(p.vel.x, p.vel.z).magnitude < 0.5f && p.grounded;
            idleT = idle ? idleT + dt : 0;
            if (idleT > 9 && Armed && inspectT <= 0) { inspectT = 1.5f; idleT = 0; if (cur == 0) equipSpin = 1; }
            inspectT = Mathf.Max(0, inspectT - dt);
            float insp = inspectT > 0 ? Mathf.Sin((1 - inspectT / 1.5f) * Mathf.PI) : 0;
            for (int i = 0; i < N; i++) models[i].group.gameObject.SetActive(i == cur);
            fist.gameObject.SetActive(!Armed && !arms.Busy);
            if (!Armed) fist.localPosition = W.V(0.3f + bx + swayX, -0.3f + by + breath + swayY - slideK * 0.03f + sy * 0.05f, -0.52f + sz * 0.04f);

            if (Armed)
            {
                var m = models[cur];
                Vector3 shake = Vector3.zero;
                bool charging = (cur == 0 && (pierceCharge > 0 || sharpCharge > 0)) || (cur == 1 && VarId == "pump" && pumps >= 3) || (cur == 4 && cannonCharge > 0) || heatBurst > 0;
                if (charging) shake = new Vector3(Random.Range(-1f, 1f), Random.Range(-1f, 1f), 0) * 0.005f;
                float lift = cur == 1 ? coreCharge : cur == 4 ? cannonCharge * 0.5f : 0;
                float coinDip = coinFlick < 1 ? Mathf.Sin(coinFlick * Mathf.PI) : 0;
                m.group.localPosition = W.V(
                    m.basePos.x + bx + swayX + shake.x - slideK * 0.04f - insp * 0.08f,
                    m.basePos.y + by + breath + swayY - sw * 0.5f + airY + shake.y - recoil * 0.012f - slideK * 0.02f - coinDip * 0.05f + sy * 0.05f + insp * 0.06f,
                    m.basePos.z + recoil * 0.05f + sz * 0.06f);
                if (equipSpin > 0) equipSpin = Mathf.Max(0, equipSpin - dt / 0.38f);
                float spinK = Mathf.Clamp01(1 - equipSpin);
                float spin = equipSpin > 0 ? spinK * spinK * (3 - 2 * spinK) * Mathf.PI * 2 : 0;
                m.group.localRotation = W.Q(recoilRot * 0.2f + sr * 0.07f + sw * 0.9f + swayY * 1.5f + lift * 0.35f - coinDip * 0.3f + insp * 0.25f, m.ry + swayX * 1.5f + insp * 0.9f, slideK * 0.25f + insp * 0.3f);
                var gunT = m.altGun != null && alt[cur] ? m.altGun : m.gun;
                gunT.localRotation = W.Q(cur == 0 ? -spin : 0);
                if (cur == 0)
                {
                    float ch = Mathf.Max(pierceCharge, sharpCharge);
                    if (ch > 0) drumTarget += dt * (4 + ch * 20) * Mathf.Rad2Deg;
                    drumAngle = Mathf.Lerp(drumAngle, drumTarget, 1 - Mathf.Exp(-16 * dt));
                    m.drum.localRotation = Quaternion.Euler(0, 0, drumAngle);
                    float he = hammerT < 1 ? -0.6f * (1 - (1 - Mathf.Pow(1 - hammerT, 3))) : 0;
                    m.hammer.localRotation = W.Q(he);
                    SetMat(accents[0], WEAPONS[0].variants[variant[0]].color * (1 + ch * 2));
                }
                else if (cur == 1)
                {
                    float t = pumpAnim;
                    float kk = t > 0.45f && t < 0.95f ? Mathf.Sin((t - 0.45f) / 0.5f * Mathf.PI) : 0;
                    m.pump.localPosition = W.V(0, -0.03f, -0.4f + kk * 0.13f);
                    gunT.localRotation = W.Q(0, 0, kk * 0.12f);
                    if (pendingCasing >= 0) { pendingCasing -= dt; if (pendingCasing < 0) EjectCasing(true); }
                    m.coreCell.gameObject.SetActive(VarId != "core" || corePopT > 0.6f);
                    m.saw.gameObject.SetActive(VarId == "saw" && !sawOut && !alt[1]);
                    float hot = VarId == "pump" ? pumps / 3f : coreCharge;
                    var bc = WEAPONS[1].variants[variant[1]].color;
                    SetMat(accents[1], (VarId == "pump" && pumps >= 3 ? (Mathf.Sin(Time.time * 40) > 0 ? new Color(1f, 0.13f, 0.06f) : new Color(1f, 0.75f, 0.13f)) : bc) * (1 + hot * 1.5f));
                }
                else if (cur == 2)
                {
                    barrelAngle += dt * (2 + barrelSpin * 30) * Mathf.Rad2Deg;
                    m.barrels.localRotation = Quaternion.Euler(0, 0, barrelAngle);
                    bool sawV = VarId == "sawblade";
                    m.barrels.gameObject.SetActive(!sawV);
                    m.drum2.gameObject.SetActive(!sawV);
                    m.sawRig.gameObject.SetActive(sawV);
                    if (sawV)
                    {
                        sawReload = Mathf.Min(1, sawReload + dt / 0.28f);
                        m.sawDisc.gameObject.SetActive(sawReload > 0.35f);
                        float e = Mathf.Clamp01((sawReload - 0.35f) / 0.65f);
                        m.sawDisc.localPosition = W.V(0, 0, 0.12f * (1 - (1 - Mathf.Pow(1 - e, 3))));
                        m.sawDisc.Rotate(-dt * (6 + barrelSpin * 40) * Mathf.Rad2Deg, 0, 0, Space.Self);
                    }
                    float h = heat;
                    SetMat(heatMat, heatBurst > 0 ? (Mathf.Sin(Time.time * 50) > 0 ? Color.white : new Color(1f, 0.5f, 0.13f)) : new Color(0.25f + h * 0.75f, 0.06f + h * 0.4f, 0.03f + h * 0.1f));
                }
                else if (cur == 3)
                {
                    float c = railCharge, h = railHeat;
                    var vc = WEAPONS[3].variants[variant[3]].color;
                    var col = new Color(vc.r * (0.1f + 0.9f * c) + h, vc.g * (0.1f + 0.9f * c) + h * 0.8f, vc.b * (0.1f + 0.9f * c) + h * 0.6f);
                    if (c >= 1) col *= 1 + Mathf.Sin(Time.time * 8) * 0.3f;
                    SetMat(coilMat, col);
                    SetMat(meterMat, col);
                    for (int i = 0; i < m.coils.Count; i++) m.coils[i].Rotate(0, dt * (1 + c * 6 + h * 20) * (i % 2 == 1 ? 1 : -1) * Mathf.Rad2Deg, 0, Space.Self);
                    m.meter.localScale = new Vector3(0.03f, 0.022f, 0.14f * Mathf.Max(0.05f, c));
                    m.meter.localPosition = W.V(0, 0.092f, 0.16f - (1 - c) * 0.065f);
                    if (h > 0.2f && Random.value < dt * 20) UKFx.I.Smoke(ToWorld(m.muzzle, 1.1f), 1, new Color(0.6f, 0.69f, 0.72f), 0.25f, 0.6f, 1.2f);
                }
                else if (cur == 4)
                {
                    m.nose.gameObject.SetActive(rocketLoadT > 0.7f && (VarId != "cannon" || cannonCharge <= 0));
                    m.ball.gameObject.SetActive(VarId == "cannon" && cannonCharge > 0);
                    SetMat(accents[4], freezeActive ? Color.white : WEAPONS[4].variants[variant[4]].color);
                }
            }

            arms.Update(dt, p);

            // namlu alevi
            flashT -= dt;
            if (flashT > 0 && Armed)
            {
                var m = models[cur];
                Vector3 mp = m.muzzle.position;
                float s = new[] { 0.34f, 0.55f, 0.25f, 0.7f, 0.5f }[cur] * vm.localScale.x;
                bool blue = cur == 0 && VarId == "piercer" && recoil > 1.2f;
                Color col = cur == 3 ? WEAPONS[3].variants[variant[3]].color : blue ? new Color(0.62f, 0.85f, 1f) : new Color(1f, 0.88f, 0.63f);
                foreach (var f in new[] { flashStar1, flashStar2 })
                {
                    f.gameObject.SetActive(true);
                    f.position = mp;
                    f.localScale = Vector3.one * s * Random.Range(0.7f, 1.3f) / vm.localScale.x;
                    SetMat(f.GetComponent<MeshRenderer>().sharedMaterial, col);
                }
                flashGlow.gameObject.SetActive(true);
                flashGlow.position = mp;
                flashGlow.localScale = Vector3.one * s * 2.2f / vm.localScale.x;
                muzzleLight.transform.position = mp;
                muzzleLight.intensity = 5 * UKFx.LightMul;
                if (cur != 3)
                {
                    float len = new[] { 0.55f, 0.8f, 0.35f, 0, 0.7f }[cur] * Random.Range(0.8f, 1.25f);
                    float w = new[] { 0.09f, 0.16f, 0.06f, 0, 0.14f }[cur] * Random.Range(0.8f, 1.2f);
                    Quaternion q = m.muzzle.rotation * Quaternion.Euler(0, 0, Random.Range(0, 180f));
                    Vector3 fwd = m.muzzle.forward;
                    float sc = vm.localScale.x;
                    flashCone.gameObject.SetActive(true);
                    flashCore.gameObject.SetActive(true);
                    flashCone.rotation = q * Quaternion.Euler(-90, 0, 0);
                    flashCore.rotation = flashCone.rotation;
                    flashCone.localScale = new Vector3(w * 2, len, w * 2 * Random.Range(0.7f, 1.1f));
                    flashCore.localScale = new Vector3(w, len * 0.78f, w);
                    flashCone.position = mp + fwd * len * 0.5f * sc;
                    flashCore.position = mp + fwd * len * 0.39f * sc;
                    SetMat(flashConeMat, col == new Color(1f, 0.88f, 0.63f) ? new Color(1f, 0.69f, 0.31f, 0.85f) : new Color(col.r, col.g, col.b, 0.85f));
                }
            }
            else
            {
                foreach (var f in new[] { flashStar1, flashStar2, flashGlow, flashCone, flashCore }) f.gameObject.SetActive(false);
                muzzleLight.intensity = 0;
            }
        }

        // ------------------------------------------------------------ sol kol (web: arms.js ViewArms)
        class ViewArms
        {
            readonly UKWeapons w;
            readonly Transform feed, knuck, whip, leg, coinMesh, ring, flare;
            readonly Transform[][] fingers = new Transform[3][];
            readonly Transform[] thumbs = new Transform[3];
            readonly Material[] glowMats = new Material[3];
            readonly Color[] glowBase = new Color[3];
            Material ringMat, flareMat;
            string act;
            float t, dur, glow, legK, ringT = 1;
            public Transform HandAnchor;
            public bool Busy => act != null && t < dur;

            static readonly float[] OFF = { -0.5f, -0.5f, -0.22f, 0.5f, -0.6f, 0.1f }, COCK = { -0.4f, -0.34f, -0.3f, 0.45f, -0.75f, 0.25f },
                HIT = { -0.1f, -0.13f, -0.76f, 0.26f, -0.36f, 0.12f }, COIN = { -0.2f, -0.16f, -0.58f, 0.15f, -0.35f, 1.05f },
                REACH = { -0.16f, -0.17f, -0.72f, 0.24f, -0.38f, 0.1f }, PUSH = { -0.36f, -0.12f, -0.5f, 0.55f, -0.25f, -1.35f },
                GUARD = { -0.26f, -0.2f, -0.5f, 0.35f, -0.5f, 0.3f }, DOWN = { -0.18f, -0.32f, -0.55f, 0.9f, -0.4f, 0.2f },
                SWING = { -0.3f, -0.22f, -0.46f, 0.3f, -0.95f, 0.5f }, SUPER = { -0.04f, -0.08f, -0.86f, 0.12f, -0.22f, 0.05f };

            public ViewArms(UKWeapons w, Transform vm)
            {
                this.w = w;
                var M = w.MT;
                feed = Holder(vm, "feedbacker", 0, M, out fingers[0], out thumbs[0], out glowMats[0]);
                knuck = Holder(vm, "knuckle", 1, M, out fingers[1], out thumbs[1], out glowMats[1]);
                whip = Holder(vm, "whiplash", 2, M, out fingers[2], out thumbs[2], out glowMats[2]);
                for (int i = 0; i < 3; i++) glowBase[i] = glowMats[i].HasProperty("_Color") ? glowMats[i].GetColor("_Color") : Color.white;
                HandAnchor = W.J(feed, 0, 0, -0.2f, "anchor");
                leg = W.J(vm, 0, 0, 0, "leg");
                W.Box(leg, 0.12f, 0.12f, 0.5f, M["armLight"], 0, 0, 0.1f);
                W.Box(leg, 0.1f, 0.03f, 0.3f, M["blue"], 0, 0.065f, 0.1f);
                W.Box(leg, 0.14f, 0.09f, 0.22f, M["armDark"], 0, -0.03f, -0.24f);
                W.Box(leg, 0.14f, 0.03f, 0.06f, M["black"], 0, -0.07f, -0.34f);
                leg.gameObject.SetActive(false);
                coinMesh = W.Cyl(vm, 0.036f, 0.036f, 0.01f, UKFx.Unlit(new Color(1f, 0.82f, 0.29f)), 0, 0, 0, 0, 0, 0, 12).transform;
                coinMesh.gameObject.SetActive(false);
                var rg = UKFx.Shape(vm, UKFx.Torus(0.26f, 32, 4), Vector3.zero, Vector3.one * 0.23f, UKFx.Unlit(new Color(0.75f, 0.91f, 1f)), new Vector3(90, 0, 0));
                ring = rg.transform;
                ringMat = w.Own(new Material(rg.GetComponent<MeshRenderer>().sharedMaterial));
                rg.GetComponent<MeshRenderer>().sharedMaterial = ringMat;
                ring.gameObject.SetActive(false);
                var fl = UKFx.Shape(vm, UKFx.Quad, Vector3.zero, Vector3.one, UKFx.UnlitTex(Color.white, UKFx.TexStar));
                flare = fl.transform;
                flareMat = w.Own(new Material(fl.GetComponent<MeshRenderer>().sharedMaterial));
                fl.GetComponent<MeshRenderer>().sharedMaterial = flareMat;
                flare.gameObject.SetActive(false);
            }

            static Transform Holder(Transform vm, string kind, int idx, Dictionary<string, Material> M, out Transform[] fingers, out Transform thumb, out Material glowMat)
            {
                var h = W.J(vm, 0, 0, 0, kind);
                var a = BuildArm(h, M, kind, out fingers, out thumb, out glowMat);
                h.gameObject.SetActive(false);
                return h;
            }

            // web: buildArm (ön kol + avuç + 4 parmak + başparmak)
            public static Transform BuildArm(Transform parent, Dictionary<string, Material> M, string kind, out Transform[] fingers, out Transform thumb, out Material glowMat)
            {
                var g = W.J(parent, 0, 0, 0, "arm");
                bool knuckle = kind == "knuckle", wh = kind == "whiplash", plain = kind == "plain";
                var main = knuckle ? M["red"] : wh ? M["green"] : plain ? M["armLight"] : M["blue"];
                var dark = M["armDark"];
                glowMat = new Material(UKFx.Unlit(knuckle ? new Color(1f, 0.63f, 0.25f) : wh ? new Color(0.72f, 1f, 0.5f) : plain ? new Color(0.6f, 0.65f, 0.75f) : new Color(0.56f, 0.82f, 1f)));
                g.gameObject.AddComponent<UKOwnMat>().m = glowMat;
                float s = knuckle ? 1.2f : 1;
                W.Box(g, 0.12f * s, 0.115f * s, 0.26f, main, 0, 0, 0.17f);
                W.Box(g, 0.105f * s, 0.1f * s, 0.26f, M["armLight"], 0, -0.005f, 0.42f);
                W.Box(g, 0.135f * s, 0.04f, 0.14f, dark, 0, 0.062f * s, 0.14f);
                if (!plain)
                {
                    W.Box(g, 0.016f, 0.02f, 0.2f, glowMat, 0.062f * s, 0.025f, 0.17f);
                    W.Box(g, 0.016f, 0.02f, 0.2f, glowMat, -0.062f * s, 0.025f, 0.17f);
                }
                if (knuckle)
                {
                    foreach (float x in new[] { -0.045f, 0.045f }) W.Cyl(g, 0.02f, 0.02f, 0.2f, M["black"], x, 0.095f, 0.16f, Mathf.PI / 2, 0, 0, 6);
                    W.Box(g, 0.09f, 0.05f, 0.08f, glowMat, 0, 0.1f, 0.3f);
                }
                if (wh)
                {
                    W.Cone(g, 0.032f, 0.11f, M["black"], 0, 0.075f, -0.02f, -Mathf.PI / 2, 0, 0, false, 5);
                    W.Box(g, 0.05f, 0.03f, 0.18f, glowMat, 0, 0.075f, 0.14f);
                }
                W.Box(g, 0.125f * s, 0.1f * s, 0.07f, dark, 0, 0, 0);
                W.Box(g, 0.13f * s, 0.055f * s, 0.12f * s, main, 0, 0, -0.095f * s);
                if (knuckle) W.Box(g, 0.15f, 0.05f, 0.05f, M["black"], 0, 0.045f, -0.15f * s);
                fingers = new Transform[8];
                for (int i = 0; i < 4; i++)
                {
                    float x = (-0.045f + i * 0.03f) * s;
                    var p1 = W.J(g, x, 0, -0.155f * s);
                    W.Box(p1, 0.024f * s, 0.028f * s, 0.052f * s, main, 0, 0, -0.025f * s);
                    var p2 = W.J(p1, 0, 0, -0.052f * s);
                    W.Box(p2, 0.022f * s, 0.025f * s, 0.042f * s, dark, 0, 0, -0.02f * s);
                    fingers[i * 2] = p1; fingers[i * 2 + 1] = p2;
                }
                thumb = W.J(g, 0.07f * s, -0.005f, -0.075f * s);
                thumb.localRotation = W.Q(0, -0.7f, 0);
                W.Box(thumb, 0.024f * s, 0.026f * s, 0.065f * s, main, 0, 0, -0.032f * s);
                SetCurl(fingers, thumb, plain ? 1 : 0.6f);
                return g;
            }

            public static void SetCurl(Transform[] f, Transform thumb, float c, float? th = null)
            {
                float tc = th ?? c;
                for (int i = 0; i < 4; i++)
                {
                    float ci = Mathf.Clamp01(c + (i - 1.5f) * 0.04f);
                    f[i * 2].localRotation = W.Q(-ci * 1.45f);
                    f[i * 2 + 1].localRotation = W.Q(-ci * 1.7f);
                }
                thumb.localRotation = W.Q(-tc * 0.9f, -0.7f, tc * 0.6f);
            }

            public void Play(string type)
            {
                float d;
                switch (type) { case "punch": d = 0.42f; break; case "coin": d = 0.36f; break; case "hook": d = 0.3f; break; case "wall": d = 0.3f; break; case "slam": d = 9; break; case "slamHit": d = 0.3f; break; case "dash": d = 0.24f; break; case "parry": d = 0.62f; break; default: d = 0.3f; break; }
                if (act != null && (act == "punch" || act == "parry") && type != "punch" && type != "parry" && t < dur) return;
                if (type == "parry") { ring.gameObject.SetActive(true); ringT = 0; }
                act = type; t = 0; dur = d;
            }

            public void Flash() => glow = 1;

            static float EaseOut(float x) => 1 - Mathf.Pow(1 - Mathf.Clamp01(x), 3);
            static float EaseIn(float x) { x = Mathf.Clamp01(x); return x * x; }
            static float[] Lerp(float[] a, float[] b, float k) { var r = new float[6]; for (int i = 0; i < 6; i++) r[i] = a[i] + (b[i] - a[i]) * k; return r; }

            public void Update(float dt, UKPlayer p)
            {
                feed.gameObject.SetActive(false); knuck.gameObject.SetActive(false); whip.gameObject.SetActive(false);
                coinMesh.gameObject.SetActive(false);
                glow = Mathf.Max(0, glow - dt * 2.2f);
                if (ring.gameObject.activeSelf)
                {
                    ringT += dt;
                    float kk = ringT / 0.4f;
                    if (kk >= 1) { ring.gameObject.SetActive(false); flare.gameObject.SetActive(false); }
                    else
                    {
                        ring.localPosition = W.V(-0.04f, -0.08f, -0.95f);
                        ring.localScale = Vector3.one * 0.23f * (0.6f + kk * 5);
                        SetMat(ringMat, new Color(0.75f, 0.91f, 1f, (1 - kk) * 0.9f));
                        flare.gameObject.SetActive(true);
                        flare.localPosition = W.V(-0.05f, -0.1f, -0.9f);
                        flare.localRotation = Quaternion.Euler(0, 0, kk * 115f);
                        flare.localScale = Vector3.one * (0.5f + (1 - kk) * 0.9f);
                        SetMat(flareMat, new Color(1, 1, 1, 1 - kk));
                    }
                }
                legK += ((p.sliding ? 1 : 0) - legK) * Mathf.Min(1, dt * 14);
                leg.gameObject.SetActive(legK > 0.03f);
                if (leg.gameObject.activeSelf)
                {
                    float kk = EaseOut(legK), sh = Mathf.Sin(Time.time * 60) * 0.004f;
                    leg.localPosition = W.V(0.02f, -0.64f + 0.36f * kk + sh, -0.56f);
                    leg.localRotation = W.Q(0.5f, -0.2f, 0.22f);
                }
                if (act == null) return;
                t += dt;
                if (act == "slam" && !p.slamming) { Play("slamHit"); return; }
                if (t >= dur) { act = null; return; }
                int idx = act == "hook" ? 2 : w.ArmId == "knuckle" ? 1 : 0;
                var m = idx == 2 ? whip : idx == 1 ? knuck : feed;
                m.gameObject.SetActive(true);
                float[] P = OFF;
                float curl = 1;
                switch (act)
                {
                    case "parry":
                        if (t < 0.04f) P = Lerp(OFF, SUPER, EaseOut(t / 0.04f));
                        else if (t < 0.3f)
                        {
                            P = (float[])SUPER.Clone();
                            float j = 0.012f * (1 - (t - 0.04f) / 0.26f);
                            P[0] += (Random.value - 0.5f) * j; P[1] += (Random.value - 0.5f) * j; P[5] += Mathf.Sin(t * 60) * 0.05f;
                        }
                        else P = Lerp(SUPER, OFF, EaseIn((t - 0.3f) / 0.32f));
                        break;
                    case "punch":
                        if (t < 0.05f) P = Lerp(OFF, COCK, EaseOut(t / 0.05f));
                        else if (t < 0.11f) P = Lerp(COCK, HIT, EaseOut((t - 0.05f) / 0.06f));
                        else if (t < 0.17f) P = HIT;
                        else P = Lerp(HIT, OFF, EaseIn((t - 0.17f) / 0.25f));
                        break;
                    case "coin":
                        {
                            float up = t < 0.1f ? EaseOut(t / 0.1f) : t < 0.2f ? 1 : 1 - EaseIn((t - 0.2f) / 0.16f);
                            P = Lerp(OFF, COIN, up);
                            float flick = t < 0.1f ? 0.9f : t < 0.14f ? 0.9f - 1.6f * ((t - 0.1f) / 0.04f) : -0.7f;
                            SetCurl(fingers[idx], thumbs[idx], 0.85f, flick);
                            break;
                        }
                    case "hook":
                        P = Lerp(OFF, REACH, t < 0.08f ? EaseOut(t / 0.08f) : 1);
                        if (w.hook != null && w.hook.phase != "out") P[2] += 0.08f;
                        curl = w.hook != null ? 0.15f : 0.55f;
                        if (w.hook != null) t = Mathf.Min(t, 0.1f);
                        break;
                    case "wall":
                        P = Lerp(OFF, PUSH, t < 0.06f ? EaseOut(t / 0.06f) : 1 - EaseIn((t - 0.06f) / 0.24f));
                        curl = 0.05f;
                        break;
                    case "slam":
                        P = Lerp(OFF, GUARD, EaseOut(Mathf.Min(1, t / 0.12f)));
                        t = Mathf.Min(t, 1);
                        break;
                    case "slamHit":
                        P = t < 0.05f ? Lerp(GUARD, DOWN, EaseOut(t / 0.05f)) : Lerp(DOWN, OFF, EaseIn((t - 0.05f) / 0.25f));
                        break;
                    case "dash":
                        P = Lerp(OFF, SWING, Mathf.Sin(Mathf.Clamp01(t / dur) * Mathf.PI));
                        curl = 0.35f;
                        break;
                }
                if (act != "coin") SetCurl(fingers[idx], thumbs[idx], curl);
                float bob = p.Bob * Mathf.Sin(p.BobT * 0.95f) * 0.01f;
                m.localPosition = W.V(P[0], P[1] + bob, P[2]);
                m.localRotation = W.Q(P[3], P[4], P[5]);
                if (act == "coin" && t < 0.11f)
                {
                    coinMesh.gameObject.SetActive(true);
                    coinMesh.position = thumbs[idx].TransformPoint(W.V(0, 0.028f, -0.06f));
                    coinMesh.rotation = m.rotation * W.Q(0.3f, 0, P[5]);
                }
                var gc = glowBase[idx];
                if (glow > 0) gc = Color.Lerp(gc, Color.white, glow);
                SetMat(glowMats[idx], gc);
            }
        }
    }
}
