# Release

## Current local build

The repository can build a universal app with:

```sh
MIDDLEFLOW_SIGN_IDENTITY="Apple Development: 990941570@qq.com (HN9XKB76DP)" \
  ./scripts/build_app.sh
```

This produces:

```text
build/MiddleFlow.app
```

The local machine currently has only an Apple Development identity. That is sufficient for local TCC testing but not for a normal public download.

## Public release requirements

1. Install a **Developer ID Application** certificate.
2. Build universal2.
3. Sign with Hardened Runtime and a secure timestamp.
4. Submit to `notarytool`.
5. Staple the notarization ticket.
6. Verify with `spctl`.
7. Create a zip and DMG.
8. Upload the artifacts and `SHA256SUMS` to GitHub Releases.

Example:

```sh
APP=build/MiddleFlow.app
IDENTITY="Developer ID Application: Your Name (TEAMID)"

codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" build/MiddleFlow.zip
xcrun notarytool submit build/MiddleFlow.zip \
  --keychain-profile AC_PASSWORD --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=4 "$APP"
```

Never commit a certificate, notarization password, or exported keychain.

## GitHub Actions

The CI workflow runs unit tests and an unsigned universal build. The release workflow is intentionally gated on a protected environment and expects the signing/notarization secrets to be configured by the repository owner.

## TCC note

Changing the bundle identifier, signing identity, or application path can cause macOS to treat the app as a new Accessibility client. Test the final signed artifact on a clean user account before publishing.
