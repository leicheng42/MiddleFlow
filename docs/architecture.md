# Architecture

## Layers

### App

`AppController` owns the macOS application lifecycle, menu bar item, status item, timers, settings window, and voice session. It is the only layer that combines the core adapters with the UI.

### Core

- `EventTapService`: creates and recovers the session-level CGEvent tap.
- `GestureClassifier`: recognizes single and double middle clicks using a monotonic timestamp and a spatial threshold.
- `KeyboardSynthesizer`: emits the configured voice modifier, Return, and Cmd+V.
- `AudioInputMonitor`: reads only audio-device running state.
- `ClipboardService`: snapshots the clipboard and restores it only when it is unchanged.
- `PermissionCenter`: Accessibility checks and System Settings links.
- `PreferencesStore`: versionable JSON preferences.
- `Diagnostics`: asynchronous file logging with no transcript content.

### UI

- `SettingsRootView`: native SwiftUI settings surface.
- `VoiceComposerPanel`: AppKit floating panel with a custom text view. The custom text view avoids placeholder and IME marked-text overlap.
- `StatusToastPanel`: transient non-interactive status messages.

## Voice session

```text
middle down
  -> target policy
     -> direct shortcut
     -> composer
          -> open panel
          -> send voice shortcut after double-click window
          -> microphone running
          -> stop request or microphone stopped
          -> stable transcript
          -> clipboard transaction
          -> restore target app
          -> verify target is frontmost
          -> click original input point
          -> send Cmd+V
          -> optional Return
          -> restore clipboard if unchanged
```

The composer never logs transcript content. It logs only character count and state transitions.

## Safety boundaries

- The event tap suppresses only CG button 2.
- Keyboard synthesis is limited to the configured voice modifier, Return, and Cmd+V.
- The target app must still exist, be frontmost, and have a fresh input point before focus click and paste.
- A paste is reported as “event sent”, not “remote field confirmed”.
