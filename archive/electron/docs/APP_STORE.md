# Mac App Store submission guide (Vello)

## Prerequisites

1. Apple Developer Program membership — **Team: Yueming Ji (`VDH5V96VHH`)**
2. Certificates in Keychain:
   - **Apple Development** (local `mas-dev` testing) — e.g. `Apple Development: admin@joletory.com`
   - **Apple Distribution** (App Store upload)
3. Create a **Mac** App ID for Vello: `app.vello.desktop` (do **not** reuse Scrolloom’s bundle ID)
4. Enable App Groups on that App ID for: `VDH5V96VHH.app.vello.desktop`
5. Mac App Store provisioning profiles (development + distribution) for `app.vello.desktop`
6. LGPL-safe `ffmpeg` binary per [build/binaries/README.md](../build/binaries/README.md)

Entitlements already use team `VDH5V96VHH` in [build/entitlements.mas.plist](../build/entitlements.mas.plist).

## Build

```sh
# Local sandbox test (register this Mac + development profile first)
CSC_NAME="Apple Development: admin@joletory.com" \
  CSC_PROVISIONING_PROFILE="/path/to/vello_mas_dev.provisionprofile" \
  yarn dist:mas-dev

# Distribution package for Transporter
CSC_NAME="Apple Distribution: Yueming Ji" \
  CSC_PROVISIONING_PROFILE="/path/to/vello_mas_dist.provisionprofile" \
  yarn dist:mas
```

Direct-download DMG (unchanged):

```sh
yarn dist
```

Notarization runs only for Developer ID builds (`build/after-sign.js` skips MAS).

## App Store Connect checklist

- **Privacy policy URL:** host [PRIVACY.md](../PRIVACY.md) at e.g. `https://vello.app/privacy`
- **Category:** Photo & Video / Video (`public.app-category.video`)
- **Encryption:** `ITSAppUsesNonExemptEncryption` is `false` (standard HTTPS only)
- **Architecture:** arm64 only (Apple silicon)
- **App Privacy labels:** match what the build actually collects (see PRIVACY.md)
- **Screenshots** of menubar cropper, editor, and export
- **Review notes** (paste below)

## App Review notes (template)

```text
Vello is a menubar screen recorder (no Dock icon by default).

How to demo:
1. Click the Vello icon in the menu bar.
2. Grant Screen Recording when macOS prompts (required).
3. Optionally enable microphone audio in Preferences and grant Microphone access.
4. Drag to select a region, press Record, then click the menu bar icon to stop.
5. Trim/export from the editor (Save to Disk).

Notes:
- Updates are delivered through the Mac App Store (no in-app updater).
- The app uses AVFoundation-based capture (aperture) and VideoToolbox encoders on MAS.
- Window-list / “select app” may be limited under App Sandbox; region capture is the primary flow.
```

## Smoke test on mas-dev

1. App launches under App Sandbox
2. Screen Recording + Microphone prompts work
3. Record → stop → editor opens
4. Export MP4 (H.264 via VideoToolbox) and GIF (no gifsicle)
5. Choosing a custom recordings folder persists (security-scoped bookmark)
6. No electron-updater network calls
