using MiddleFlow.Core.Models;
using MiddleFlow.Core.Services;
using MiddleFlow.Core.Interop;
using System.Runtime.InteropServices;

var failures = new List<string>();

void Check(bool condition, string message)
{
    if (!condition)
    {
        failures.Add(message);
    }
}

var settings = new AppSettings
{
    DoubleClickIntervalMs = 20,
    ClipboardRestoreDelayMs = 10,
    CanvasAppPatterns = "  "
};
settings.Normalize();
Check(settings.DoubleClickIntervalMs == 150, "double-click interval lower clamp");
Check(settings.ClipboardRestoreDelayMs == 400, "clipboard restore lower clamp");
Check(settings.CanvasAppPatterns.Contains("uu.exe"), "empty canvas patterns reset");

var classifier = new GestureClassifier();
Check(classifier.Register(1000, 260) == MouseGestureKind.Single, "first click is single");
Check(classifier.Register(1200, 260) == MouseGestureKind.Double, "second quick click is double");
Check(classifier.Register(1500, 260) == MouseGestureKind.Single, "triple resets classifier");
Check(classifier.Register(1700, 260) == MouseGestureKind.Double, "fourth quick click is double");

Check(
    TargetPolicy.IsCanvasTarget("UU.exe", "UU Remote", "uu.exe,uu remote"),
    "process and title matching");
Check(
    TargetPolicy.IsCanvasTarget("unknown", "UU远程 - 画布", "uu远程"),
    "window title matching");
Check(
    !TargetPolicy.IsCanvasTarget("notepad", "Untitled - Notepad", "uu.exe,uu remote"),
    "ordinary app does not match");

var stabilizer = new TranscriptStabilizer();
stabilizer.Start(0);
Check(stabilizer.Evaluate("你好", 100) == TranscriptDecision.Waiting, "text is not immediately final");
Check(stabilizer.Evaluate("你好", 260) == TranscriptDecision.Ready, "stable text becomes ready");
stabilizer.Start(500);
Check(stabilizer.Evaluate("你好", 800) == TranscriptDecision.Waiting, "elapsed minimum is enforced");
Check(stabilizer.Evaluate("你好呀", 1000) == TranscriptDecision.Waiting, "text change resets stability");
Check(stabilizer.Evaluate("你好呀", 1200) == TranscriptDecision.Ready, "changed text can stabilize");
stabilizer.Start(2000);
Check(stabilizer.Evaluate("", 3000) == TranscriptDecision.Waiting, "empty transcript waits longer");
Check(stabilizer.Evaluate("", 4600) == TranscriptDecision.Empty, "empty transcript times out");
stabilizer.Start(5000);
Check(stabilizer.Evaluate("慢速转写", 6200) == TranscriptDecision.Ready, "non-empty fallback is ready");

var tempRoot = Path.Combine(Path.GetTempPath(), "MiddleFlow-tests-" + Guid.NewGuid().ToString("N"));
try
{
    var paths = new AppPaths(tempRoot);
    paths.EnsureCreated();
    var store = new SettingsStore(paths.SettingsPath);
    var saved = new AppSettings
    {
        MappingEnabled = false,
        DoubleClickIntervalMs = 333,
        CanvasAppPatterns = "custom.exe"
    };
    store.Save(saved);
    var loaded = store.Load();
    Check(!loaded.MappingEnabled, "settings mapping roundtrip");
    Check(loaded.DoubleClickIntervalMs == 333, "settings interval roundtrip");
    Check(loaded.CanvasAppPatterns == "custom.exe", "settings patterns roundtrip");

    var diagnostics = new DiagnosticsLog(paths.DiagnosticsPath, paths.DiagnosticsArchivePath);
    diagnostics.Write("TEST_EVENT", "chars=4 process=test");
    var tail = diagnostics.Tail();
    Check(tail.Contains("TEST_EVENT", StringComparison.Ordinal), "diagnostics tail");
    Check(!tail.Contains("你好", StringComparison.Ordinal), "diagnostics do not contain transcript text");
}
finally
{
    try
    {
        if (Directory.Exists(tempRoot))
        {
            Directory.Delete(tempRoot, recursive: true);
        }
    }
    catch
    {
    }
}

var doubao = DoubaoDetector.Detect();
Check(!string.IsNullOrWhiteSpace(doubao.Message), "Doubao detector returns a status message");

var inputSize = Marshal.SizeOf<Win32Input.INPUT>();
Check(
    inputSize == (IntPtr.Size == 8 ? 40 : 28),
    $"Win32 INPUT layout should match pointer size, got {inputSize}");

if (failures.Count > 0)
{
    Console.Error.WriteLine("MiddleFlow smoke tests failed:");
    foreach (var failure in failures)
    {
        Console.Error.WriteLine(" - " + failure);
    }
    return 1;
}

Console.WriteLine("MiddleFlow smoke tests passed.");
return 0;
