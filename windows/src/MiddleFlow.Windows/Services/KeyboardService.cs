using System.Runtime.InteropServices;
using MiddleFlow.Core.Interop;
using MiddleFlow.Windows.Interop;

namespace MiddleFlow.Windows.Services;

public sealed class KeyboardService
{
    private bool _rightAltDown;

    public static int InputSize => Marshal.SizeOf<Win32Input.INPUT>();

    public bool RightAltDown => _rightAltDown;

    public bool PressRightAlt()
    {
        if (_rightAltDown)
        {
            return true;
        }
        var sent = SendKey(NativeMethods.VK_RMENU, keyUp: false, extended: true);
        if (sent)
        {
            _rightAltDown = true;
        }
        return sent;
    }

    public bool ReleaseRightAlt()
    {
        if (!_rightAltDown)
        {
            return true;
        }
        var sent = SendKey(NativeMethods.VK_RMENU, keyUp: true, extended: true);
        if (sent)
        {
            _rightAltDown = false;
        }
        return sent;
    }

    public bool SendPaste()
    {
        var inputs = new[]
        {
            KeyInput(NativeMethods.VK_CONTROL, false),
            KeyInput(NativeMethods.VK_V, false),
            KeyInput(NativeMethods.VK_V, true),
            KeyInput(NativeMethods.VK_CONTROL, true)
        };
        return NativeMethods.SendInput(
            (uint)inputs.Length,
            inputs,
            Marshal.SizeOf<Win32Input.INPUT>()) == (uint)inputs.Length;
    }

    public bool SendReturn()
    {
        var inputs = new[]
        {
            KeyInput(NativeMethods.VK_RETURN, false),
            KeyInput(NativeMethods.VK_RETURN, true)
        };
        return NativeMethods.SendInput(
            (uint)inputs.Length,
            inputs,
            Marshal.SizeOf<Win32Input.INPUT>()) == (uint)inputs.Length;
    }

    public void ReleaseAll()
    {
        ReleaseRightAlt();
    }

    private static bool SendKey(ushort virtualKey, bool keyUp, bool extended)
    {
        var input = KeyInput(virtualKey, keyUp, extended);
        return NativeMethods.SendInput(
            1,
            new[] { input },
            Marshal.SizeOf<Win32Input.INPUT>()) == 1;
    }

    private static Win32Input.INPUT KeyInput(
        ushort virtualKey,
        bool keyUp,
        bool extended = false)
    {
        var flags = 0u;
        if (extended)
        {
            flags |= NativeMethods.KEYEVENTF_EXTENDEDKEY;
        }
        if (keyUp)
        {
            flags |= NativeMethods.KEYEVENTF_KEYUP;
        }

        return new Win32Input.INPUT
        {
            type = NativeMethods.INPUT_KEYBOARD,
            U = new Win32Input.InputUnion
            {
                ki = new Win32Input.KEYBDINPUT
                {
                    wVk = virtualKey,
                    wScan = (ushort)NativeMethods.MapVirtualKey(
                        virtualKey,
                        NativeMethods.MAPVK_VK_TO_VSC),
                    dwFlags = flags,
                    time = 0,
                    dwExtraInfo = IntPtr.Zero
                }
            }
        };
    }
}
