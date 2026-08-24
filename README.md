# Vello

A native macOS screen recorder written in Swift.

Vello lives in the menu bar. Pick a region, record, trim, and export to MP4,
HEVC, GIF, or APNG — without Electron, Node, or a bundled ffmpeg.

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

On first launch, Vello explains and requests Microphone, Camera, and Screen &
System Audio Recording access. Screen Recording is requested last because macOS
may require Vello to quit and reopen before that permission becomes effective.
Choosing **Not Now** defers the prompts; Vello will still request a required
permission when its corresponding recording feature is used.

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
```

## How it works

**Capture.** `SCStream` records the chosen display (optionally cropped), writes
H.264 through `AVAssetWriter`, and can capture system audio, microphone audio,
or both on macOS 15+. The two sources use separate synchronized tracks that are
mixed during video export. An optional three- or five-second countdown runs
before the stream starts and can be cancelled with Escape. Pause subtracts the
paused span from later timestamps so the file timeline stays continuous.
Optional click ripples are drawn on overlay windows that are excepted into the
capture filter. Microphone modes show a live input meter before recording, and
an optional camera feed can be composited as a circular bubble. Four corner
presets are available, or the bubble can be dragged anywhere inside the capture
area; custom placement is constrained, corner-snapping, and resolution independent.

**Export.** Trim, resize, frame rate, and mute go through `AVAssetExportSession`
for MP4 / HEVC. GIF and APNG are rendered with `AVAssetImageGenerator` + ImageIO.
Named presets remember common export combinations. In the editor, Space toggles
playback, the arrow keys seek, and I / O set the trim start and end.

**Sandbox.** The app is sandboxed. Exports save to Downloads by default. You can
switch to a save panel or remember another folder with a security-scoped bookmark.

## Inspired by

Vello started as a native rewrite of [Kap](https://github.com/wulkano/kap),
the open-source screen recorder by [Wulkano](https://github.com/wulkano).
Kap's product ideas and UX still shape a lot of what Vello does.

## License

MIT. See [LICENSE.md](LICENSE.md) and [PRIVACY.md](PRIVACY.md).
