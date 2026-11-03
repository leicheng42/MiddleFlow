using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using MiddleFlow.Core.Interop;
using MiddleFlow.Windows.Interop;

namespace MiddleFlow.Windows.Services;

public sealed record ScreenRect(int Left, int Top, int Right, int Bottom)
{
    public int Width => Right - Left;
    public int Height => Bottom - Top;
}

public sealed record WindowTarget(
    IntPtr Handle,
    uint ProcessId,
    string ProcessName,
    string WindowTitle,
    ScreenRect Bounds)
{
    public bool IsEmpty => Handle == IntPtr.Zero;
}

public sealed class WindowTargetService
{
    public WindowTarget Describe(IntPtr handle)
    {
        if (handle == IntPtr.Zero)
        {
            return new WindowTarget(
                IntPtr.Zero,
                0,
                string.Empty,
                string.Empty,
                new ScreenRect(0, 0, 0, 0));
        }

        NativeMethods.GetWindowThreadProcessId(handle, out var processId);
        var processName = string.Empty;
        if (processId != 0)
        {
            try
            {
                using var process = Process.GetProcessById((int)processId);
                processName = process.ProcessName;
            }
            catch
            {
            }
        }

        var length = Math.Max(0, NativeMethods.GetWindowTextLength(handle));
        var title = new StringBuilder(length + 1);
        NativeMethods.GetWindowText(handle, title, title.Capacity);
        NativeMethods.GetWindowRect(handle, out var nativeBounds);

        return new WindowTarget(
            handle,
            processId,
            processName,
            title.ToString(),
            new ScreenRect(
                nativeBounds.Left,
                nativeBounds.Top,
                nativeBounds.Right,
                nativeBounds.Bottom));
    }

    public WindowTarget Foreground()
    {
        return Describe(NativeMethods.GetForegroundWindow());
    }

    public bool Activate(IntPtr handle)
    {
        if (handle == IntPtr.Zero)
        {
            return false;
        }
        if (NativeMethods.IsIconic(handle))
        {
            NativeMethods.ShowWindow(handle, NativeMethods.SW_RESTORE);
        }

        var foreground = NativeMethods.GetForegroundWindow();
        if (foreground == handle)
        {
            return true;
        }

        var foregroundThread = NativeMethods.GetWindowThreadProcessId(foreground, out _);
        var targetThread = NativeMethods.GetWindowThreadProcessId(handle, out _);
        var currentThread = NativeMethods.GetCurrentThreadId();
        var attachedForeground = false;
        var attachedTarget = false;
        try
        {
            if (foregroundThread != 0 && foregroundThread != currentThread)
            {
                attachedForeground = NativeMethods.AttachThreadInput(
                    currentThread,
                    foregroundThread,
                    true);
            }
            if (targetThread != 0 && targetThread != currentThread)
            {
                attachedTarget = NativeMethods.AttachThreadInput(
                    currentThread,
                    targetThread,
                    true);
            }
            NativeMethods.BringWindowToTop(handle);
            NativeMethods.SetForegroundWindow(handle);
            return NativeMethods.GetForegroundWindow() == handle;
        }
        catch
        {
            return false;
        }
        finally
        {
            if (attachedTarget)
            {
                NativeMethods.AttachThreadInput(currentThread, targetThread, false);
            }
            if (attachedForeground)
            {
                NativeMethods.AttachThreadInput(currentThread, foregroundThread, false);
            }
        }
    }

    public bool IsForeground(IntPtr handle)
    {
        return handle != IntPtr.Zero && NativeMethods.GetForegroundWindow() == handle;
    }

    public MousePoint CursorPosition()
    {
        NativeMethods.GetCursorPos(out var point);
        return new MousePoint(point.X, point.Y);
    }

    public bool ClickAt(MousePoint point)
    {
        if (!NativeMethods.SetCursorPos(point.X, point.Y))
        {
            return false;
        }
        var inputs = new[]
        {
            new Win32Input.INPUT
            {
                type = NativeMethods.INPUT_MOUSE,
                U = new Win32Input.InputUnion
                {
                    mi = new Win32Input.MOUSEINPUT
                    {
                        dwFlags = NativeMethods.MOUSEEVENTF_LEFTDOWN
                    }
                }
            },
            new Win32Input.INPUT
            {
                type = NativeMethods.INPUT_MOUSE,
                U = new Win32Input.InputUnion
                {
                    mi = new Win32Input.MOUSEINPUT
                    {
                        dwFlags = NativeMethods.MOUSEEVENTF_LEFTUP
                    }
                }
            }
        };
        return NativeMethods.SendInput(
            (uint)inputs.Length,
            inputs,
            Marshal.SizeOf<Win32Input.INPUT>()) == (uint)inputs.Length;
    }
}
