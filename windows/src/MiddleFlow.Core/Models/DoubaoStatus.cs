namespace MiddleFlow.Core.Models;

public enum DoubaoReadiness
{
    Missing,
    InstalledNotRegistered,
    RegisteredNotSelected,
    Ready
}

public sealed record DoubaoStatus(
    DoubaoReadiness Readiness,
    bool Installed,
    bool Registered,
    bool Selected,
    string? Version,
    string? InstallPath,
    string Message)
{
    public static DoubaoStatus Missing(string message) =>
        new(DoubaoReadiness.Missing, false, false, false, null, null, message);

    public bool IsReady => Readiness == DoubaoReadiness.Ready;
}
