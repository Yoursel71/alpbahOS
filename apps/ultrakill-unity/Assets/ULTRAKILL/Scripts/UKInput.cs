// Giriş katmanı: projede eski Input Manager açıksa onu, yalnız yeni Input System açıksa onu kullanır.
// (Unity 6 şablonları çoğunlukla yeni Input System ile gelir; iki durumda da derlenir.
// UK_INPUTSYSTEM, ULTRAKILL.asmdef içinde com.unity.inputsystem paketi kuruluysa tanımlanır.)
using UnityEngine;
#if !ENABLE_LEGACY_INPUT_MANAGER && ENABLE_INPUT_SYSTEM && UK_INPUTSYSTEM
using UnityEngine.InputSystem;
#endif

namespace UK
{
    public enum UKKey { W, A, S, D, Space, Shift, C, Ctrl, F, R, Q, E, G, Esc, Tab, Enter, B, N1, N2, N3, N4, N5, Mouse0, Mouse1 }

    public static class UKInput
    {
        // Menü ya da ölüm ekranında yapay "basıldı" üretmemek için kilit
        public static bool Blocked;

#if ENABLE_LEGACY_INPUT_MANAGER || (ENABLE_INPUT_SYSTEM && UK_INPUTSYSTEM)
        public static readonly bool Available = true;
#else
        public static readonly bool Available = false;
#endif

        public static bool Held(UKKey k) => !Blocked && Raw(k, false);
        public static bool Down(UKKey k) => !Blocked && Raw(k, true);
        public static bool DownUnblocked(UKKey k) => Raw(k, true);

        // Tekerlek: platform/sürüm farkı (±1, ±120) olmadan yalnız yön
        static float Notch(float y) => y > 0.01f ? 1f : y < -0.01f ? -1f : 0f;

#if ENABLE_LEGACY_INPUT_MANAGER
        static KeyCode Map(UKKey k)
        {
            switch (k)
            {
                case UKKey.W: return KeyCode.W;
                case UKKey.A: return KeyCode.A;
                case UKKey.S: return KeyCode.S;
                case UKKey.D: return KeyCode.D;
                case UKKey.Space: return KeyCode.Space;
                case UKKey.Shift: return KeyCode.LeftShift;
                case UKKey.C: return KeyCode.C;
                case UKKey.Ctrl: return KeyCode.LeftControl;
                case UKKey.F: return KeyCode.F;
                case UKKey.R: return KeyCode.R;
                case UKKey.Q: return KeyCode.Q;
                case UKKey.E: return KeyCode.E;
                case UKKey.G: return KeyCode.G;
                case UKKey.Esc: return KeyCode.Escape;
                case UKKey.Tab: return KeyCode.Tab;
                case UKKey.Enter: return KeyCode.Return;
                case UKKey.B: return KeyCode.B;
                case UKKey.N1: return KeyCode.Alpha1;
                case UKKey.N2: return KeyCode.Alpha2;
                case UKKey.N3: return KeyCode.Alpha3;
                case UKKey.N4: return KeyCode.Alpha4;
                case UKKey.N5: return KeyCode.Alpha5;
                case UKKey.Mouse0: return KeyCode.Mouse0;
                case UKKey.Mouse1: return KeyCode.Mouse1;
            }
            return KeyCode.None;
        }

        static bool Raw(UKKey k, bool down)
        {
            var c = Map(k);
            return down ? Input.GetKeyDown(c) : Input.GetKey(c);
        }

        public static Vector2 MouseDelta => Blocked ? Vector2.zero : new Vector2(Input.GetAxisRaw("Mouse X"), Input.GetAxisRaw("Mouse Y"));
        public static float Scroll => Blocked ? 0f : Notch(Input.mouseScrollDelta.y);
#elif ENABLE_INPUT_SYSTEM && UK_INPUTSYSTEM
        static bool Raw(UKKey k, bool down)
        {
            var kb = Keyboard.current;
            var ms = Mouse.current;
            if (k == UKKey.Mouse0 || k == UKKey.Mouse1)
            {
                if (ms == null) return false;
                var b = k == UKKey.Mouse0 ? ms.leftButton : ms.rightButton;
                return down ? b.wasPressedThisFrame : b.isPressed;
            }
            if (kb == null) return false;
            Key key;
            switch (k)
            {
                case UKKey.W: key = Key.W; break;
                case UKKey.A: key = Key.A; break;
                case UKKey.S: key = Key.S; break;
                case UKKey.D: key = Key.D; break;
                case UKKey.Space: key = Key.Space; break;
                case UKKey.Shift: key = Key.LeftShift; break;
                case UKKey.C: key = Key.C; break;
                case UKKey.Ctrl: key = Key.LeftCtrl; break;
                case UKKey.F: key = Key.F; break;
                case UKKey.R: key = Key.R; break;
                case UKKey.Q: key = Key.Q; break;
                case UKKey.E: key = Key.E; break;
                case UKKey.G: key = Key.G; break;
                case UKKey.Esc: key = Key.Escape; break;
                case UKKey.Tab: key = Key.Tab; break;
                case UKKey.Enter: key = Key.Enter; break;
                case UKKey.B: key = Key.B; break;
                case UKKey.N1: key = Key.Digit1; break;
                case UKKey.N2: key = Key.Digit2; break;
                case UKKey.N3: key = Key.Digit3; break;
                case UKKey.N4: key = Key.Digit4; break;
                default: key = Key.Digit5; break;
            }
            var c = kb[key];
            return down ? c.wasPressedThisFrame : c.isPressed;
        }

        // Yeni sistemde fare deltası piksel cinsindendir; eski sistemin birimine (piksel × 0,1) çevir
        public static Vector2 MouseDelta => Blocked || Mouse.current == null ? Vector2.zero : Mouse.current.delta.ReadValue() * 0.1f;
        public static float Scroll => Blocked || Mouse.current == null ? 0f : Notch(Mouse.current.scroll.ReadValue().y);
#else
        static bool Raw(UKKey k, bool down) => false;
        public static Vector2 MouseDelta => Vector2.zero;
        public static float Scroll => 0f;
#endif
    }
}
