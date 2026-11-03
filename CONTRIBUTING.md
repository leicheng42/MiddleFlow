# Contributing

## Development setup

```sh
swift test
xcodegen generate --spec project.yml
```

Run the app in a safe preview mode while changing the settings UI:

```sh
open -n build/MiddleFlow.app --args --ui-preview --show-settings
```

Use `--test-window` for a safe editable text target and `--composer-demo` for a visual check of the floating composer.

## Rules

- Keep event-tap callbacks short and non-blocking.
- Do not log transcript text, typed keys, audio samples, or window contents.
- Do not change Logitech configuration or the TCC database.
- Keep the event-tap and clipboard core independent of the settings UI.
- Add a unit test for any pure gesture, target-policy, or preference behavior.
- Test both the direct shortcut path and the composer path when changing session state.
- Do not commit certificates, passwords, logs, or generated build products.

## Pull requests

Describe the user-visible behavior, the verification performed, and any remaining unverified remote-app behavior. UU Remote's guest input cannot be read back programmatically; say “paste event sent” rather than claiming the remote field was confirmed.
