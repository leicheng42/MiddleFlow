namespace MiddleFlow.Core.Models;

public sealed class AppSettings
{
    public bool MappingEnabled { get; set; } = true;
    public bool DoubleClickEnabled { get; set; } = true;
    public int DoubleClickIntervalMs { get; set; } = 260;
    public bool OverlayEnabled { get; set; } = true;
    public bool DirectModeEnabled { get; set; } = true;
    public bool AutoPaste { get; set; } = true;
    public bool PasteThenEnter { get; set; }
    public bool RestoreClipboard { get; set; } = true;
    public int ClipboardRestoreDelayMs { get; set; } = 1800;
    public bool StartAtLogin { get; set; }
    public bool ShowTrayNotifications { get; set; } = true;
    public string CanvasAppPatterns { get; set; } =
        "uu.exe,uuclient.exe,uu_remote.exe,uu remote,uu远程";
    public string VoiceShortcut { get; set; } = "RightAlt";
    public string Theme { get; set; } = "warm";
    public bool FirstRunCompleted { get; set; }

    public void Normalize()
    {
        DoubleClickIntervalMs = Math.Clamp(DoubleClickIntervalMs, 150, 600);
        ClipboardRestoreDelayMs = Math.Clamp(ClipboardRestoreDelayMs, 400, 8000);
        CanvasAppPatterns = string.IsNullOrWhiteSpace(CanvasAppPatterns)
            ? "uu.exe,uuclient.exe,uu_remote.exe,uu remote,uu远程"
            : CanvasAppPatterns.Trim();
        VoiceShortcut = string.IsNullOrWhiteSpace(VoiceShortcut)
            ? "RightAlt"
            : VoiceShortcut.Trim();
        Theme = string.IsNullOrWhiteSpace(Theme) ? "warm" : Theme.Trim();
    }

    public AppSettings Clone()
    {
        return new AppSettings
        {
            MappingEnabled = MappingEnabled,
            DoubleClickEnabled = DoubleClickEnabled,
            DoubleClickIntervalMs = DoubleClickIntervalMs,
            OverlayEnabled = OverlayEnabled,
            DirectModeEnabled = DirectModeEnabled,
            AutoPaste = AutoPaste,
            PasteThenEnter = PasteThenEnter,
            RestoreClipboard = RestoreClipboard,
            ClipboardRestoreDelayMs = ClipboardRestoreDelayMs,
            StartAtLogin = StartAtLogin,
            ShowTrayNotifications = ShowTrayNotifications,
            CanvasAppPatterns = CanvasAppPatterns,
            VoiceShortcut = VoiceShortcut,
            Theme = Theme,
            FirstRunCompleted = FirstRunCompleted
        };
    }
}
