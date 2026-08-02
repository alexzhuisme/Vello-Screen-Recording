# MAS helper binaries

Mac App Store builds must not ship GPL-encumbered helper tools.

## ffmpeg (required for App Store submission)

Place an **LGPL-licensed** (or VideoToolbox-only) `ffmpeg` binary at:

```text
build/binaries/ffmpeg
```

Recommended configure flags for Apple silicon MAS builds:

- Enable VideoToolbox: `--enable-videotoolbox`
- Do **not** enable GPL codecs: no `--enable-gpl`, no `libx264` / `libx265`
- Prefer system/aac audio encode paths used by the MAS code (`h264_videotoolbox`, `hevc_videotoolbox`, `aac`)

Then wire it into the MAS package (example `package.json` `build.mas.extraResources`):

```json
"extraResources": [
  {
    "from": "build/binaries/ffmpeg",
    "to": "ffmpeg"
  }
]
```

The app resolves `Contents/Resources/ffmpeg` first when `process.mas` is true (see `main/utils/ffmpeg-path.ts`).

Until this binary is present, MAS/dev builds fall back to `ffmpeg-static` with a console warning — **do not submit that fallback to App Store Connect**.

## gifsicle

Not used on MAS builds. GIF export skips the gifsicle compression pass when `process.mas` is true.
