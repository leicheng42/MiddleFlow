using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32;
using MiddleFlow.Core.Models;

namespace MiddleFlow.Core.Services;

public static class DoubaoDetector
{
    public const string DownloadUrl = "https://shurufa.doubao.com/pc";

    private static readonly string[] UninstallRoots =
    {
        @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    };

    private static readonly string[] KnownExecutables =
    {
        @"Doubao\Doubao.exe",
        @"Doubao\DoubaoIME.exe",
        @"Doubao\DoubaoInput.exe",
        @"ByteDance\Doubao\Doubao.exe",
        @"DoubaoIME\DoubaoIME.exe"
    };

    public static DoubaoStatus Detect()
    {
        if (!OperatingSystem.IsWindows())
        {
            return DoubaoStatus.Missing("豆包输入法检测仅在 Windows 上可用。");
        }

        var install = FindInstallation();
        var layouts = ReadKeyboardLayouts();
        var registeredByLayout = layouts.Any(IsDoubaoLayout);
        var registeredByRegistry = RegistryContainsDoubao();
        var registered = registeredByLayout || registeredByRegistry;
        var selected = IsDoubaoLayout(ReadCurrentKeyboardLayout());
        var installed = install.Found || registered;

        if (!installed)
        {
            return new DoubaoStatus(
                DoubaoReadiness.Missing,
                false,
                false,
                false,
                null,
                null,
                "未检测到豆包输入法，请先下载安装。");
        }

        if (!registered)
        {
            return new DoubaoStatus(
                DoubaoReadiness.InstalledNotRegistered,
                true,
                false,
                false,
                install.Version,
                install.Path,
                "检测到豆包，但输入法尚未加入 Windows 键盘列表。");
        }

        if (!selected)
        {
            return new DoubaoStatus(
                DoubaoReadiness.RegisteredNotSelected,
                true,
                true,
                false,
                install.Version,
                install.Path,
                "豆包输入法已安装，请切换到豆包输入法后再测试。");
        }

        return new DoubaoStatus(
            DoubaoReadiness.Ready,
            true,
            true,
            true,
            install.Version,
            install.Path,
            "豆包输入法已安装并处于当前输入法。");
    }

    private static InstallationInfo FindInstallation()
    {
        foreach (var hive in new[] { RegistryHive.CurrentUser, RegistryHive.LocalMachine })
        {
            foreach (var view in new[] { RegistryView.Registry64, RegistryView.Registry32 })
            {
                foreach (var root in UninstallRoots)
                {
                    var result = FindInUninstallRoot(hive, view, root);
                    if (result.Found)
                    {
                        return result;
                    }
                }
            }
        }

        foreach (var candidate in CandidateExecutables())
        {
            if (!File.Exists(candidate))
            {
                continue;
            }
            return new InstallationInfo(
                true,
                FileVersionInfo.GetVersionInfo(candidate).FileVersion,
                Path.GetDirectoryName(candidate));
        }

        return InstallationInfo.NotFound;
    }

    private static InstallationInfo FindInUninstallRoot(
        RegistryHive hive,
        RegistryView view,
        string root)
    {
        try
        {
            using var baseKey = RegistryKey.OpenBaseKey(hive, view);
            using var uninstall = baseKey.OpenSubKey(root);
            if (uninstall is null)
            {
                return InstallationInfo.NotFound;
            }

            foreach (var subKeyName in uninstall.GetSubKeyNames())
            {
                try
                {
                    using var app = uninstall.OpenSubKey(subKeyName);
                    if (app is null)
                    {
                        continue;
                    }
                    var displayName = app.GetValue("DisplayName") as string;
                    if (!IsDoubaoName(displayName))
                    {
                        continue;
                    }
                    var version = app.GetValue("DisplayVersion") as string;
                    var location = app.GetValue("InstallLocation") as string;
                    var icon = app.GetValue("DisplayIcon") as string;
                    if (string.IsNullOrWhiteSpace(location) && !string.IsNullOrWhiteSpace(icon))
                    {
                        location = Path.GetDirectoryName(icon.Trim('"').Split(',')[0]);
                    }
                    return new InstallationInfo(true, version, location);
                }
                catch
                {
                }
            }
        }
        catch
        {
        }
        return InstallationInfo.NotFound;
    }

    private static bool RegistryContainsDoubao()
    {
        foreach (var hive in new[] { RegistryHive.CurrentUser, RegistryHive.LocalMachine })
        {
            foreach (var root in new[]
                     {
                         @"SOFTWARE\Microsoft\CTF",
                         @"SOFTWARE\Microsoft\Input",
                         @"SOFTWARE\Microsoft\Windows\CurrentVersion\Input"
                     })
            {
                try
                {
                    using var baseKey = RegistryKey.OpenBaseKey(hive, RegistryView.Default);
                    using var key = baseKey.OpenSubKey(root);
                    if (key is not null && ContainsDoubaoValue(key, 0))
                    {
                        return true;
                    }
                }
                catch
                {
                }
            }
        }
        return false;
    }

    private static bool ContainsDoubaoValue(RegistryKey key, int depth)
    {
        if (depth > 4)
        {
            return false;
        }
        try
        {
            foreach (var valueName in key.GetValueNames())
            {
                if (IsDoubaoName(valueName) ||
                    IsDoubaoName(key.GetValue(valueName)?.ToString()))
                {
                    return true;
                }
            }
            foreach (var childName in key.GetSubKeyNames())
            {
                using var child = key.OpenSubKey(childName);
                if (child is not null && ContainsDoubaoValue(child, depth + 1))
                {
                    return true;
                }
            }
        }
        catch
        {
        }
        return false;
    }

    private static IReadOnlyList<KeyboardLayoutInfo> ReadKeyboardLayouts()
    {
        var result = new List<KeyboardLayoutInfo>();
        var count = GetKeyboardLayoutList(0, null);
        if (count <= 0)
        {
            return result;
        }
        var layouts = new IntPtr[count];
        if (GetKeyboardLayoutList(count, layouts) <= 0)
        {
            return result;
        }
        foreach (var layout in layouts)
        {
            result.Add(DescribeLayout(layout));
        }
        return result;
    }

    private static KeyboardLayoutInfo ReadCurrentKeyboardLayout()
    {
        try
        {
            return DescribeLayout(GetKeyboardLayout(GetCurrentThreadId()));
        }
        catch
        {
            return new KeyboardLayoutInfo(IntPtr.Zero, string.Empty, string.Empty);
        }
    }

    private static KeyboardLayoutInfo DescribeLayout(IntPtr layout)
    {
        return new KeyboardLayoutInfo(
            layout,
            GetImeDescription(layout),
            GetImeFileName(layout));
    }

    private static string GetImeDescription(IntPtr layout)
    {
        try
        {
            var builder = new StringBuilder(256);
            var length = (int)ImmGetDescription(
                layout,
                builder,
                (uint)builder.Capacity);
            if (length <= 0)
            {
                return string.Empty;
            }
            return builder.ToString(0, Math.Min(length, builder.Length));
        }
        catch
        {
            return string.Empty;
        }
    }

    private static string GetImeFileName(IntPtr layout)
    {
        try
        {
            var builder = new StringBuilder(256);
            var length = (int)ImmGetIMEFileName(
                layout,
                builder,
                (uint)builder.Capacity);
            if (length <= 0)
            {
                return string.Empty;
            }
            return builder.ToString(0, Math.Min(length, builder.Length));
        }
        catch
        {
            return string.Empty;
        }
    }

    private static bool IsDoubaoLayout(KeyboardLayoutInfo layout)
    {
        return IsDoubaoName(layout.Description) || IsDoubaoName(layout.FileName);
    }

    private static bool IsDoubaoName(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }
        return value.Contains("豆包", StringComparison.OrdinalIgnoreCase) ||
               value.Contains("doubao", StringComparison.OrdinalIgnoreCase) ||
               value.Contains("bytedance", StringComparison.OrdinalIgnoreCase);
    }

    private static IEnumerable<string> CandidateExecutables()
    {
        foreach (var root in new[]
                 {
                     Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                     Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
                     Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)
                 })
        {
            if (string.IsNullOrWhiteSpace(root))
            {
                continue;
            }
            foreach (var relative in KnownExecutables)
            {
                yield return Path.Combine(root, relative);
            }
        }
    }

    private sealed record InstallationInfo(bool Found, string? Version, string? Path)
    {
        public static InstallationInfo NotFound { get; } = new(false, null, null);
    }

    private sealed record KeyboardLayoutInfo(
        IntPtr Handle,
        string Description,
        string FileName);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetKeyboardLayoutList(
        int nBuff,
        [Out] IntPtr[]? lpList);

    [DllImport("user32.dll")]
    private static extern IntPtr GetKeyboardLayout(uint idThread);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("imm32.dll", CharSet = CharSet.Unicode)]
    private static extern uint ImmGetDescription(
        IntPtr hkl,
        StringBuilder? lpszDescription,
        uint uBufLen);

    [DllImport("imm32.dll", CharSet = CharSet.Unicode)]
    private static extern uint ImmGetIMEFileName(
        IntPtr hkl,
        StringBuilder? lpszFileName,
        uint uBufLen);
}
