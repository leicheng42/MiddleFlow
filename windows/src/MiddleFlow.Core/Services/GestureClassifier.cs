namespace MiddleFlow.Core.Services;

public enum MouseGestureKind
{
    Single,
    Double
}

public sealed class GestureClassifier
{
    private long? _lastClickAt;

    public MouseGestureKind Register(long nowMs, int intervalMs)
    {
        if (_lastClickAt is { } last && nowMs - last <= Math.Max(80, intervalMs))
        {
            _lastClickAt = null;
            return MouseGestureKind.Double;
        }
        _lastClickAt = nowMs;
        return MouseGestureKind.Single;
    }

    public void Reset()
    {
        _lastClickAt = null;
    }
}
