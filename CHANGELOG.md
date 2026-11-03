# Changelog

## Unreleased

- Added Doubao input-method detection with installation, registration, current-source, and version guidance.
- Added a real settings top bar with page identity, mapping state, and Doubao readiness.
- Finalized stable Doubao text without waiting for marked text to clear; live verification reduced stop-to-transcript latency to milliseconds and stop-to-paste to about 260 ms.
- Added bilingual Chinese/English documentation and a Windows 10/11 WPF edition with a global middle-button hook, Right Alt hold, UU Remote overlay, clipboard paste, tray, settings, diagnostics, and self-contained x64/ARM64 builds.
- Added Windows CI, portable packaging, and dual-architecture release artifacts.

## 2.0.0

- Productized the prototype as MiddleFlow.
- Added a native settings window with Overview, Gestures, Voice, Apps, Permissions, Diagnostics, and About pages.
- Added configurable composer targets, voice shortcut, auto-paste, Return behavior, and clipboard restoration.
- Added a universal Apple Silicon + Intel build.
- Added app icon, app bundle metadata, launch-at-login via `SMAppService`, tests, and release scripts.
- Added asynchronous diagnostics and a privacy boundary that excludes transcript text.
- Preserved the proven Right Option `flagsChanged` keycode 61 path and the UU Remote floating composer.

## 1.3.0

- Added the Doubao-style UU Remote composer, automatic clipboard paste, and double-click Return.
- Improved transcript timing and focus restoration.

## 1.1.0

- Added double-click Return and a persistent menu bar control.
