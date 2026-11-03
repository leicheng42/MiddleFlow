namespace MiddleFlow.Core.Services;

public enum TranscriptDecision
{
    Waiting,
    Ready,
    Empty
}

public sealed class TranscriptStabilizer
{
    private string _text = string.Empty;
    private long _lastChangeMs;
    private long _stoppedAtMs;

    public void Start(long nowMs)
    {
        _text = string.Empty;
        _lastChangeMs = nowMs;
        _stoppedAtMs = nowMs;
    }

    public TranscriptDecision Evaluate(
        string? currentText,
        long nowMs,
        int stabilityMs = 150,
        int minimumElapsedMs = 170,
        int nonEmptyFallbackMs = 1200,
        int emptyTimeoutMs = 2500)
    {
        var text = (currentText ?? string.Empty).Trim();
        if (!string.Equals(text, _text, StringComparison.Ordinal))
        {
            _text = text;
            _lastChangeMs = nowMs;
        }

        var elapsed = nowMs - _stoppedAtMs;
        var stableFor = nowMs - _lastChangeMs;
        if (text.Length > 0 && elapsed >= minimumElapsedMs && stableFor >= stabilityMs)
        {
            return TranscriptDecision.Ready;
        }
        if (text.Length > 0 && elapsed >= nonEmptyFallbackMs)
        {
            return TranscriptDecision.Ready;
        }
        if (text.Length == 0 && elapsed >= emptyTimeoutMs)
        {
            return TranscriptDecision.Empty;
        }
        return TranscriptDecision.Waiting;
    }
}
