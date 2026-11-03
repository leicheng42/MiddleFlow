# MiddleFlow for Windows

> **Preview status:** the Windows 10/11 WPF host, tray, settings pages, global mouse hook, floating voice composer, clipboard transaction, keyboard service, startup integration, diagnostics, and Doubao detection are present under `windows/`.
>
> The solution builds successfully with .NET 8 (0 warnings, 0 errors), both console smoke-test harnesses pass, and self-contained `win-x64` / `win-arm64` publishes complete successfully. A Windows CI workflow is included, but it has not run yet. Real Windows 10/11 hardware acceptance, code signing, and a signed installer are still pending.

## What is implemented

- `MiddleFlow.Windows`: WPF application host and custom window chrome.
- `MainWindow` and `Views/`: Overview, Gestures, Voice, Doubao, Apps, Permissions, Diagnostics, and About pages.
- `TrayService`: tray menu for opening settings, testing, pausing/resuming mapping, and quitting.
- `MouseHookService`: global low-level mouse hook for the middle button.
- `KeyboardService`: long-press Right Alt, paste, and Enter synthesis through `SendInput`.
- `VoiceComposerWindow`: Doubao-style floating composer.
- `ClipboardService`: clipboard capture, text write, and restore-if-current protection.
- `WindowTargetService`: target-window activation and foreground checks.
- `StartupService`: per-user startup registration.
- `MiddleFlow.Core`: settings, gestures, transcript stabilization, target policy, diagnostics, and Doubao detection.
- `tests/`: console smoke-test harnesses for core logic and Windows input layout.

The Windows edition keeps the macOS product contract:

- Doubao input method for Windows
- Long-press **Right Alt** by default
- Global middle-click mapping
- UU Remote floating overlay
- Automatic paste with clipboard restoration
- Tray controls and settings

## Interaction

### Normal apps

- **Single middle click**: send the configured voice shortcut. The default is a long-press Right Alt.
- **Double middle click**: send Enter.
- During a voice session, double-click stops voice input and queues Enter until the transcript has been pasted.
- When mapping is paused, the original middle click is passed through.

### UU Remote and canvas apps

The target policy recognizes UU Remote by process name or window title using configurable patterns:

```text
uu.exe,uuclient.exe,uu_remote.exe,uu remote,uu远程
```

The intended flow is:

1. Focus the remote input box.
2. Middle-click to start voice input.
3. Middle-click again to stop, or double-click to stop and queue Enter.
4. MiddleFlow captures stable text, restores the target window, pastes through the clipboard, and optionally sends Enter.
5. The previous clipboard is restored only if it still contains the transcript written by MiddleFlow.

UU Remote must have clipboard synchronization enabled. MiddleFlow can verify that a paste shortcut was sent; it cannot read the guest input contents. Remote clipboard synchronization is asynchronous, so a paste event does not prove that the guest field accepted the text.

### Transcript stabilization

The Windows core uses the same speed principle as macOS: do not wait for an input method to clear a marked/composition state. `TranscriptStabilizer` currently defaults to:

- minimum elapsed time: 170 ms
- text stability window: 150 ms
- maximum wait before accepting non-empty text: 1200 ms
- empty-transcript timeout: 2500 ms

The host commits or otherwise finalizes the Doubao composition before pasting. Runtime behavior on a real Windows desktop remains part of acceptance testing.

## Doubao setup

1. Open the official Doubao input-method download page: <https://shurufa.doubao.com/pc>.
2. Download the **Windows version** and complete its first-run setup.
3. Add or enable Doubao in the Windows input-method list.
4. Switch to Doubao and confirm that Chinese input works.
5. In Doubao's voice settings, set the toggle/免按模式 shortcut to **Right Alt**.
6. In MiddleFlow, run the Doubao detection check. The core checks the uninstall registry, Windows keyboard layouts, and current keyboard layout.
7. Run a voice test and confirm that MiddleFlow sends Right Alt and receives a stable transcript.

The macOS Doubao page remains <https://shurufa.doubao.com/>.

## Build and test

Requirements:

- Windows 10/11 for the WPF app and runtime tests
- .NET 8 SDK
- macOS can cross-build and run the two console test harnesses with `-p:EnableWindowsTargeting=true`

From the repository root on Windows:

```powershell
dotnet restore windows\MiddleFlow.Windows.sln
dotnet build windows\MiddleFlow.Windows.sln -c Release -p:EnableWindowsTargeting=true
dotnet run --project windows\tests\MiddleFlow.Core.Tests\MiddleFlow.Core.Tests.csproj -c Release -p:EnableWindowsTargeting=true
dotnet run --project windows\tests\MiddleFlow.Windows.Tests\MiddleFlow.Windows.Tests.csproj -c Release -p:EnableWindowsTargeting=true
```

The test projects are console smoke-test harnesses rather than xUnit/NUnit adapters, so `dotnet test` does not execute their checks. Run the two executables directly.

### Verified in this checkout

On 2026-11-03, using .NET SDK 8.0.427:

```text
dotnet build windows/MiddleFlow.Windows.sln -c Release -p:EnableWindowsTargeting=true

Build succeeded.
    0 Warning(s)
    0 Error(s)
```

Both console smoke tests also pass:

```text
MiddleFlow smoke tests passed.
INPUT=40, MOUSEINPUT=32, KEYBDINPUT=24, unionOffset=8, process64=True
Windows input layout test passed.
```

Self-contained single-file publish was verified locally for both architectures:

```text
win-x64:   PE32+ executable (GUI) x86-64, for MS Windows
win-arm64: PE32+ executable (GUI) Aarch64, for MS Windows
```

`.github/workflows/windows.yml` builds and tests both architectures on `windows-latest` and uploads portable artifacts. The workflow has not produced a recorded green run yet. There is no signed Windows installer.

## Verification checklist

Run this on a real Windows 10/11 machine before calling the edition ready:

- [ ] The global mouse hook starts and pauses without leaving a stuck Right Alt.
- [ ] Middle-click does not leak to the foreground app while mapping is active.
- [ ] Right Alt starts and stops Doubao voice input.
- [ ] Doubao detection distinguishes missing, installed-not-registered, registered-not-selected, and ready.
- [ ] The UU Remote overlay appears on the intended monitor and does not steal focus.
- [ ] A stable transcript is pasted into the original input box.
- [ ] Clipboard restoration does not overwrite a newer clipboard value.
- [ ] Double-click sends Enter only after the paste when a voice session is active.
- [ ] Tray pause, resume, settings, diagnostics, and quit work.
- [ ] An elevated target app is tested separately; Windows integrity levels may block a non-elevated global hook.

## Known limitations

- The WPF host, core tests, and cross-platform publish build are verified; real Windows runtime acceptance is still pending.
- The Windows CI workflow is present but has not completed a recorded run yet.
- No Authenticode-signed installer is available yet; the portable zip may trigger SmartScreen.
- Windows global hooks can be restricted by integrity level, security software, or remote-desktop software.
- Remote clipboard synchronization is asynchronous; a paste event does not prove the guest field accepted the text.

## Related docs

- [macOS README](../README.md)
- [Windows source notes](../windows/README.md)
- [Architecture](architecture.md)
- [Privacy](../PRIVACY.md)
