namespace MiddleFlow.Core.Models;

public sealed record RuntimeState(
    bool MappingEnabled,
    bool HookInstalled,
    bool VoiceActive,
    bool Transcribing,
    bool Pasting,
    string Mode,
    string LastEvent,
    int MappedClicks,
    int DoubleClicks)
{
    public static RuntimeState Initial { get; } = new(
        MappingEnabled: true,
        HookInstalled: false,
        VoiceActive: false,
        Transcribing: false,
        Pasting: false,
        Mode: "待机",
        LastEvent: "等待启动",
        MappedClicks: 0,
        DoubleClicks: 0);
}
