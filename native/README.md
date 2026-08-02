# Vello (native)

A native Swift rewrite of Vello for macOS 15 and later. It records the screen with
ScreenCaptureKit, edits with AVFoundation, and exports without bundling any
third-party encoder.

The Electron app in the repository root still builds and runs; this directory is
independent of it.

## Requirements

- macOS 15 Sequoia or later
- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Layout

```
native/
├── project.yml          XcodeGen spec for the app target
├── App/                 The application: windows, menu bar, SwiftUI views
│   ├── Sources/
│   └── Resources/       Info.plist, entitlements, asset catalog
└── VelloKit/            Swift package holding the testable logic
    ├── Sources/
    │   ├── VelloCore    Settings, models, recording state, temp files
    │   ├── VelloCapture Permissions, device enumeration, the recorder
    │   ├── VelloExport  Encoders, export jobs, progress and cancellation
    │   └── VelloUI      Shared metrics and crop selection geometry
    └── Tests/
```

Logic lives in `VelloKit` so it can be exercised with `swift test` in about five
seconds, without launching the app.

## Building

```sh
cd native
xcodegen generate
open Vello.xcodeproj
```

Or from the command line:

```sh
xcodebuild -project Vello.xcodeproj -scheme Vello -configuration Release build
```

`project.yml` pins `DEVELOPMENT_TEAM`. Change it to your own team, because screen
recording permission is granted to a signing identity: ad-hoc signed builds get a
new identity on every rebuild and re-prompt each time.

## Testing

```sh
cd native/VelloKit
swift test
```

The export tests synthesize a short clip and run it through the real encoders. The
capture tests drive an actual `SCStream`, and skip themselves when the test runner
has not been granted Screen Recording permission.

## How it works

**Capture.** `SCStream` renders the chosen display, cropped with `sourceRect`, into
`CMSampleBuffer`s that an `AVAssetWriter` encodes as H.264 through VideoToolbox.
Vello's own windows are excluded from the content filter so the overlay never
appears in the recording. On macOS 15 the same stream can also deliver microphone
audio, which keeps video and audio on one clock and avoids a second capture
session.

Pause and resume are implemented in the writer rather than the stream: incoming
timestamps keep advancing while paused, and the gap is subtracted from everything
that follows, so the output timeline stays continuous.

**Export.** Trim, resize, frame rate and mute are applied through an
`AVMutableComposition` plus an `AVMutableVideoComposition`, then encoded by
`AVAssetExportSession` as H.264 or HEVC. GIF and APNG are rendered by pulling
frames with `AVAssetImageGenerator` and writing them with ImageIO. Nothing here
needs ffmpeg or gifsicle, which also removes the GPL licensing problem the
Electron app had to work around on the Mac App Store.

Every export writes to a temporary file first and moves it into place only on
success, so a cancelled or failed export never leaves a truncated file where the
user expects a finished one.

**Sandboxing.** The app is sandboxed. Exports reach the user's folders either
through a save panel, which grants access to the chosen file, or through a
security-scoped bookmark for a folder the user picked once and Vello remembers.

## Deliberately not in v1

- **WebM and AV1.** AVFoundation cannot encode either, so supporting them means
  bundling ffmpeg again.
- **Click highlighting.** ScreenCaptureKit has no equivalent of the old
  `capturesMouseClicks`; it would need a custom event-tap overlay.
- **System audio capture.** The Electron app never had it either.
- **The plugin system.** Vello's JavaScript share services do not carry over.
- **A key-capture shortcut recorder.** Preferences offers the same fixed choices
  Kap did rather than recording arbitrary key combinations.
