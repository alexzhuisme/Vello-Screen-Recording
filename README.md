# Vello

A native macOS screen recorder written in Swift.

Vello lives in the menu bar. Pick a region, record, trim, and export to MP4,
HEVC, GIF, or APNG — without Electron, Node, or a bundled ffmpeg.

> The previous Electron app is preserved under [`archive/electron/`](archive/electron/)
> for reference only. It is not the product anymore.

## Requirements

- macOS 15 Sequoia or later
- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```sh
xcodegen generate
open Vello.xcodeproj
```

Or from the command line:

```sh
xcodegen generate
xcodebuild -project Vello.xcodeproj -scheme Vello -configuration Release build
```

`project.yml` pins `DEVELOPMENT_TEAM`. Change it to your team. Screen Recording
permission is tied to the signing identity, so ad-hoc Debug builds will keep
re-prompting.

## Test

```sh
cd VelloKit
swift test
```

Export tests synthesize a short clip and run the real encoders. Capture tests
drive a live `SCStream` and skip themselves when Screen Recording permission is
missing.

## Layout

```
App/           Menu bar app, cropper, editor, preferences
VelloKit/      Testable packages: capture, export, settings, UI geometry
project.yml    XcodeGen spec
archive/       Historical Electron Vello (not shipped)
```

## How it works

**Capture.** `SCStream` records the chosen display (optionally cropped), writes
H.264 through `AVAssetWriter`, and can take microphone audio on the same stream
on macOS 15+. Pause subtracts the paused span from later timestamps so the file
timeline stays continuous. Optional click ripples are drawn on overlay windows
that are excepted into the capture filter.

**Export.** Trim, resize, frame rate, and mute go through `AVAssetExportSession`
for MP4 / HEVC. GIF and APNG are rendered with `AVAssetImageGenerator` + ImageIO.

**Sandbox.** The app is sandboxed. Exports use a save panel or a security-scoped
bookmark for a folder you chose once.

## License

MIT. See [LICENSE.md](LICENSE.md) and [PRIVACY.md](PRIVACY.md).
