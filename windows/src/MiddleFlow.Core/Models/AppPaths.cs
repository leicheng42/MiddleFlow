namespace MiddleFlow.Core.Models;

public sealed class AppPaths
{
    public AppPaths(string? localRoot = null)
    {
        LocalRoot = localRoot ??
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "MiddleFlow");
        SettingsPath = Path.Combine(LocalRoot, "settings.json");
        DiagnosticsPath = Path.Combine(LocalRoot, "diagnostics.log");
        DiagnosticsArchivePath = Path.Combine(LocalRoot, "diagnostics.1.log");
    }

    public string LocalRoot { get; }
    public string SettingsPath { get; }
    public string DiagnosticsPath { get; }
    public string DiagnosticsArchivePath { get; }

    public void EnsureCreated()
    {
        Directory.CreateDirectory(LocalRoot);
    }
}
