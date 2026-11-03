using System.Text.Json;
using MiddleFlow.Core.Models;

namespace MiddleFlow.Core.Services;

public sealed class SettingsStore
{
    private readonly string _path;
    private readonly JsonSerializerOptions _json = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true
    };

    public SettingsStore(string path)
    {
        _path = path;
    }

    public string Path => _path;

    public AppSettings Load()
    {
        try
        {
            if (!File.Exists(_path))
            {
                var fresh = new AppSettings();
                fresh.Normalize();
                return fresh;
            }
            var settings = JsonSerializer.Deserialize<AppSettings>(
                File.ReadAllText(_path),
                _json) ?? new AppSettings();
            settings.Normalize();
            return settings;
        }
        catch
        {
            TryArchiveCorruptFile();
            var fallback = new AppSettings();
            fallback.Normalize();
            return fallback;
        }
    }

    public void Save(AppSettings settings)
    {
        settings.Normalize();
        var directory = System.IO.Path.GetDirectoryName(_path)!;
        Directory.CreateDirectory(directory);
        var temporary = _path + ".tmp";
        var json = JsonSerializer.Serialize(settings, _json);
        File.WriteAllText(temporary, json);
        File.Move(temporary, _path, true);
    }

    private void TryArchiveCorruptFile()
    {
        try
        {
            if (!File.Exists(_path))
            {
                return;
            }
            var stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
            File.Move(_path, $"{_path}.corrupt-{stamp}", true);
        }
        catch
        {
        }
    }
}
