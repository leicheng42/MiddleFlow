# Verification for 2.0.0

Recorded on 2026-11-03 (Asia/Shanghai) on the local Apple Silicon Mac.

## Unit tests

```text
Executed 10 tests, with 0 failures
```

The tests cover single/double click classification, spatial rejection, preference round-tripping, and target policy.

## Installed legacy-compatible build

The local installed app was built with the existing bundle identifier and Apple Development identity so it could reuse the previously granted Accessibility authorization:

```text
Identifier=local.leicheng.middle-option-bridge
TeamIdentifier=V489WBSLAY
CDHash=a6240df9b2b13eea3ccdafe5d3e6e5685a09ec9c
```

Persistent launchd status:

```json
{
  "accessibility": true,
  "canPostEvents": true,
  "mappingActive": true,
  "microphoneActive": false,
  "voiceState": "idle"
}
```

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

## What remains unverified

- A physical M720 click was not independently repeated after the final install; the test used system-origin synthetic middle events through the same event tap.
- UU Remote's guest input contents cannot be read back. The app can verify that `Cmd+V` and Return events were sent, not that the remote application committed them.
- The public bundle ID (`io.github.leicheng42.middleflow`) requires its own Accessibility authorization and does not inherit the legacy authorization.
- Public distribution still requires Developer ID signing and notarization.
