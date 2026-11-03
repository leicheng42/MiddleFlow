namespace MiddleFlow.Core.Services;

public static class TargetPolicy
{
    public static bool IsCanvasTarget(
        string? processName,
        string? windowTitle,
        string? patterns)
    {
        if (string.IsNullOrWhiteSpace(patterns))
        {
            return false;
        }

        var process = Normalize(processName);
        var title = Normalize(windowTitle);
        foreach (var raw in patterns.Split(
                     new[] { ',', ';', '\n', '\r' },
                     StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var pattern = Normalize(raw);
            if (pattern.Length == 0)
            {
                continue;
            }
            if (process.Contains(pattern, StringComparison.OrdinalIgnoreCase) ||
                title.Contains(pattern, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }
        return false;
    }

    private static string Normalize(string? value)
    {
        return (value ?? string.Empty)
            .Trim()
            .TrimEnd('.', ' ')
            .Replace(".exe", string.Empty, StringComparison.OrdinalIgnoreCase);
    }
}
