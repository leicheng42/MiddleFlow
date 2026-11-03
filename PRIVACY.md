# Privacy

MiddleFlow is a local macOS utility. It does not operate a server and does not upload data.

## What the app accesses

- Accessibility events for the middle mouse button (`CG button 2`).
- Keyboard event synthesis for the configured voice shortcut, Return, and `Cmd+V`.
- The system clipboard when a transcript is ready or the user asks to paste the latest transcript.
- Audio device running state, only to detect when a microphone starts or stops. The app does not capture audio samples.

## What is stored

Preferences are stored at:

```text
~/Library/Application Support/MiddleFlow/preferences.json
```

Runtime status is stored at:

```text
~/Library/Application Support/MiddleFlow/status.json
```

Diagnostics are stored at:

```text
~/Library/Application Support/MiddleFlow/diagnostics.log
```

Diagnostics contain event types, state names, timestamps, character counts, and error descriptions. They do not contain transcript text, ordinary typed keys, or audio.

The latest transcript is kept in memory only. When auto-paste is used, the previous clipboard contents are snapshotted so the app can restore them if the clipboard has not been changed by another app.

## Network

MiddleFlow does not make network requests. It does not contain analytics, crash reporting, advertising, or update checks.

## Third-party names

Doubao, UU Remote, Logitech, and macOS are trademarks of their respective owners. MiddleFlow is an independent utility and is not endorsed by those companies.
