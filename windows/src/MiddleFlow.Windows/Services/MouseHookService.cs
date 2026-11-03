using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows.Threading;
using MiddleFlow.Windows.Interop;

namespace MiddleFlow.Windows.Services;

public sealed class MiddleClickEventArgs : EventArgs
{
    public MiddleClickEventArgs(IntPtr foregroundWindow, MousePoint point, uint time)
    {
        ForegroundWindow = foregroundWindow;
        Point = point;
        Time = time;
    }

    public IntPtr ForegroundWindow { get; }
    public MousePoint Point { get; }
    public uint Time { get; }
}

public sealed record MousePoint(int X, int Y);

public sealed class MouseHookService : IDisposable
{
    private readonly Dispatcher _dispatcher;
    private readonly NativeMethods.LowLevelMouseProc _callback;
    private IntPtr _hook;
    private bool _disposed;

    public MouseHookService(Dispatcher dispatcher)
    {
        _dispatcher = dispatcher;
        _callback = HookCallback;
    }

    public event EventHandler<MiddleClickEventArgs>? MiddleClick;

    public bool IsInstalled => _hook != IntPtr.Zero;

    public bool Enabled { get; set; } = true;

    public void Start()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (_hook != IntPtr.Zero)
        {
            return;
        }

        _hook = NativeMethods.SetWindowsHookEx(
            NativeMethods.WH_MOUSE_LL,
            _callback,
            NativeMethods.GetModuleHandle(null),
            0);
        if (_hook == IntPtr.Zero)
        {
            throw new Win32Exception(
                Marshal.GetLastWin32Error(),
                "无法安装全局鼠标钩子。");
        }
    }

    public void Stop()
    {
        if (_hook == IntPtr.Zero)
        {
            return;
        }
        NativeMethods.UnhookWindowsHookEx(_hook);
        _hook = IntPtr.Zero;
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }
        _disposed = true;
        Stop();
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode < 0)
        {
            return NativeMethods.CallNextHookEx(_hook, nCode, wParam, lParam);
        }

        var message = wParam.ToInt32();
        if (!Enabled ||
            (message != NativeMethods.WM_MBUTTONDOWN &&
             message != NativeMethods.WM_MBUTTONUP &&
             message != NativeMethods.WM_MBUTTONDBLCLK))
        {
            return NativeMethods.CallNextHookEx(_hook, nCode, wParam, lParam);
        }

        // Windows may emit WM_MBUTTONDOWN and WM_MBUTTONDBLCLK for one
        // physical double click. Only the down event is a click edge.
        if (message == NativeMethods.WM_MBUTTONDOWN)
        {
            var data = Marshal.PtrToStructure<NativeMethods.MSLLHOOKSTRUCT>(lParam);
            if ((data.flags & NativeMethods.LLMHF_INJECTED) == 0)
            {
                var foreground = NativeMethods.GetForegroundWindow();
                var args = new MiddleClickEventArgs(
                    foreground,
                    new MousePoint(data.pt.X, data.pt.Y),
                    data.time);
                try
                {
                    _dispatcher.BeginInvoke(
                        DispatcherPriority.Input,
                        new Action(() => MiddleClick?.Invoke(this, args)));
                }
                catch (InvalidOperationException)
                {
                    // The app is shutting down; suppress the click for one last frame.
                }
            }
        }

        return (IntPtr)1;
    }
}
