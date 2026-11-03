# Security

## Reporting

Please report a security issue privately through the repository's GitHub Security Advisory page rather than opening a public issue with exploit details.

## Permission model

MiddleFlow requires macOS Accessibility permission for a global `CGEventTap`. That permission is broad by design: it allows the app to observe and synthesize input events. The implementation limits itself to:

- CG mouse button number 2 (middle click)
- the configured voice modifier shortcut
- Return
- `Cmd+V`

The app does not capture audio, read screen contents, or record transcript text.

## Signing

Release artifacts should be signed with a Developer ID Application certificate, use Hardened Runtime, be notarized with Apple, and pass:

```sh
codesign --verify --deep --strict --verbose=2 MiddleFlow.app
spctl --assess --type execute --verbose=4 MiddleFlow.app
```

Do not disable Gatekeeper, modify the TCC database, or use `xattr -dr com.apple.quarantine` as an installation instruction.

## Secrets

Never commit a `.p12`, notarization password, App Store Connect API key, or exported keychain. CI should use a protected environment and short-lived secrets.
