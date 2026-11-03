# Verification for 2.0.0

Recorded on 2026-11-03 (Asia/Shanghai) on the local Apple Silicon Mac.

## macOS unit tests

```text
Executed 19 tests, with 0 failures
```

The suite now covers:

- single/double click classification and spatial rejection
- preference round-tripping
- target policy
- `DoubaoDetectorTests` for missing, installed-not-registered, registered-not-selected, and ready states
- `TranscriptFinalizerTests` for stable text, marked-text persistence, fallback, and empty transcript handling

The transcript finalizer no longer waits for the input method to clear marked text. It finishes non-empty text after the minimum elapsed time plus a short stability window, with a 1.20-second fallback.

## Installed legacy-compatible build

The last installed build used the existing bundle identifier and Apple Development identity so it could reuse the previously granted Accessibility authorization:

```text
Identifier=local.leicheng.middle-option-bridge
TeamIdentifier=V489WBSLAY
CDHash=d1955841f66a82e5fb18b3d7e48c26b2a6c8d636
```

Observed status after launch:

```json
{
  "accessibility": true,
  "canPostEvents": true,
  "mappingActive": true,
  "microphoneActive": false,
  "voiceState": "idle"
}
```

This is the final local legacy-compatible development install for this change set. Public release artifacts use the separate public bundle identifier and still require Developer ID signing and notarization.

## Single middle click through the real event tap

The test window was focused and a synthetic system-origin middle click was posted through the active session event tap:

```text
READY pid=31854 preview=false ax=true post=true
TAP_STARTED
SELF_TEST_MIDDLE_DOWN
SELF_TEST_MIDDLE_UP
VOICE_SHORTCUT_SENT shortcut=rightOption sent=true
MICROPHONE_ACTIVE
SELF_TEST_RESULT mapped=1 mic=true voice=idle
```

This verifies the full local chain: CG button 2 -> active event tap -> Right Option keycode 61 -> sustained microphone activity.

## Double middle click through the real event tap

```text
SELF_TEST_MIDDLE_DOWN
DIRECT_GESTURE gesture=pendingSingle pending=1
SELF_TEST_MIDDLE_UP
SELF_TEST_MIDDLE_DOWN
DIRECT_GESTURE gesture=doubleClick pending=0
DOUBLE_CLICK_RETURN
SELF_TEST_MIDDLE_UP
DOUBLE_SELF_TEST_RESULT double=1 mapped=2
```

This verifies the 0.28-second double-click path and Return event without starting a voice shortcut.

## Speed evidence

The following is from the live UU Remote session in the diagnostics log. The target was `com.netease.uuremote`:

```text
2026-11-03T06:28:05.513Z MICROPHONE_STOPPED duration=2.63s
2026-11-03T06:28:05.520Z TRANSCRIPT_READY chars=11
2026-11-03T06:28:05.570Z RESTORE_APP pid=724 activated=true
2026-11-03T06:28:05.704Z REMOTE_FOCUS_CLICK_SENT
2026-11-03T06:28:05.773Z PASTE_SHORTCUT_SENT
```

Observed timing:

- microphone stopped -> transcript ready: about **7 ms**
- microphone stopped -> paste shortcut sent: about **260 ms**

This confirms the app is not waiting for a multi-second marked-text timeout on a normal completed transcript.

## Marked-text finalization self-test

The `--composer-finalize-test` run deliberately inserted marked text and left it marked:

```text
2026-11-03T06:50:15.485Z FINALIZE_SELF_TEST_STARTED marked=true
2026-11-03T06:50:15.920Z TRANSCRIPT_READY chars=6 latencyMs=461
2026-11-03T06:50:15.924Z RESTORE_APP pid=44180 activated=true
2026-11-03T06:50:15.924Z CLIPBOARD_SETTLE target=local.leicheng.middle-option-bridge delay=0.06
2026-11-03T06:50:15.986Z CLIPBOARD_VERIFIED target=local.leicheng.middle-option-bridge
2026-11-03T06:50:16.009Z REMOTE_FOCUS_CLICK_SENT
2026-11-03T06:50:16.637Z FINALIZE_SELF_TEST_RESULT chars=6 paste=false state=idle
```

The marked text became a ready transcript in **461 ms**, and the clipboard was verified and focus click sent within the next **89 ms**. There is no `marked_text_timeout` in this run. The self-test asserts finalization, not clipboard paste; its `paste=false` result is expected for that harness.

## Windows build

The Windows solution was cross-built on this Mac with .NET SDK 8.0.427:

```text
dotnet build windows/MiddleFlow.Windows.sln -c Release -p:EnableWindowsTargeting=true

Build succeeded.
    0 Warning(s)
    0 Error(s)
```

Both console smoke-test harnesses pass:

```text
MiddleFlow smoke tests passed.
INPUT=40, MOUSEINPUT=32, KEYBDINPUT=24, unionOffset=8, process64=True
Windows input layout test passed.
```

Self-contained single-file publish also succeeds for both architectures:

```text
win-x64:   PE32+ executable (GUI) x86-64, for MS Windows
win-arm64: PE32+ executable (GUI) Aarch64, for MS Windows
```

`.github/workflows/windows.yml` is present for Windows CI, but has not completed a recorded run yet. Real Windows runtime acceptance and a signed installer remain pending. See [windows.md](windows.md) for the checklist.

## What remains unverified

- A physical M720 click was not independently repeated after the final install; the test used system-origin synthetic middle events through the same event tap.
- UU Remote's guest input contents cannot be read back. The app can verify that `Cmd+V` and Return events were sent, not that the remote application committed them.
- The public bundle ID (`io.github.leicheng42.middleflow`) requires its own Accessibility authorization and does not inherit the legacy authorization.
- Public macOS distribution still requires Developer ID signing and notarization.
- The current installed legacy-compatible build needs one final rebuild after the documentation/code freeze.
- Windows WPF runtime acceptance on real Windows hardware remains pending.
