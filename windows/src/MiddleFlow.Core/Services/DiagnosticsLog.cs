using System.Text;

namespace MiddleFlow.Core.Services;

public sealed class DiagnosticsLog
{
    private readonly object _gate = new();
    private readonly string _path;
    private readonly string _archivePath;
    private const long MaxBytes = 512 * 1024;

    public DiagnosticsLog(string path, string archivePath)
    {
        _path = path;
        _archivePath = archivePath;
    }

    public string Path => _path;

    public void Write(string eventName, string? detail = null)
    {
        lock (_gate)
        {
            try
            {
                Directory.CreateDirectory(System.IO.Path.GetDirectoryName(_path)!);
                RotateIfNeeded();
                var line = $"{DateTimeOffset.Now:yyyy-MM-ddTHH:mm:ss.fffzzz} {Sanitize(eventName)}";
                if (!string.IsNullOrWhiteSpace(detail))
                {
                    line += " " + Sanitize(detail);
                }
                File.AppendAllText(_path, line + Environment.NewLine, Encoding.UTF8);
            }
            catch
            {
                // Diagnostics must never take down the input path.
            }
        }
    }

    public string Tail(int maxLines = 120)
    {
        lock (_gate)
        {
            try
            {
                if (!File.Exists(_path))
                {
                    return "暂无诊断记录。";
                }
                var lines = File.ReadAllLines(_path, Encoding.UTF8);
                return string.Join(
                    Environment.NewLine,
                    lines.TakeLast(Math.Clamp(maxLines, 20, 500)));
            }
            catch (Exception ex)
            {
                return $"无法读取诊断日志：{ex.Message}";
            }
        }
    }

    public void Clear()
    {
        lock (_gate)
        {
            try
            {
                if (File.Exists(_path))
                {
                    File.Delete(_path);
                }
                if (File.Exists(_archivePath))
                {
                    File.Delete(_archivePath);
                }
            }
            catch
            {
            }
        }
    }

    private void RotateIfNeeded()
    {
        if (!File.Exists(_path) || new FileInfo(_path).Length < MaxBytes)
        {
            return;
        }
        File.Move(_path, _archivePath, true);
    }

    private static string Sanitize(string value)
    {
        return value.Replace('\r', ' ').Replace('\n', ' ').Trim();
    }
}
