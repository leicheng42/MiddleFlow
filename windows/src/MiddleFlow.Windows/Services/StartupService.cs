using System.Diagnostics;
using System.IO;
using Microsoft.Win32;

namespace MiddleFlow.Windows.Services;

public sealed class StartupService
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "MiddleFlow";

    public bool IsEnabled()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: false);
            return key?.GetValue(ValueName) is string value &&
                   value.Contains("MiddleFlow", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    public bool SetEnabled(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKey, writable: true);
            if (key is null)
            {
                return false;
            }
            if (!enabled)
            {
                key.DeleteValue(ValueName, throwOnMissingValue: false);
                return true;
            }

            var executable = ResolveExecutable();
            if (string.IsNullOrWhiteSpace(executable))
            {
                return false;
            }
            key.SetValue(ValueName, $"\"{executable}\" --background");
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static string? ResolveExecutable()
    {
        var processPath = Environment.ProcessPath;
        if (!string.IsNullOrWhiteSpace(processPath) &&
            Path.GetFileName(processPath)
                .Contains("MiddleFlow", StringComparison.OrdinalIgnoreCase))
        {
            return processPath;
        }

        var localAppHost = Path.Combine(AppContext.BaseDirectory, "MiddleFlow.exe");
        if (File.Exists(localAppHost))
        {
            return localAppHost;
        }

        return processPath ?? Process.GetCurrentProcess().MainModule?.FileName;
    }
}
