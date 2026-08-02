# Third-party notices

Vello bundles or depends on third-party software. Key distribution notes for Mac App Store vs direct download:

## FFmpeg

- **Direct download (DMG):** uses `ffmpeg-static`, which typically includes GPL-enabled codecs (for example libx264 / libx265). Redistribution must comply with the FFmpeg and codec licenses applicable to that binary.
- **Mac App Store:** must ship an LGPL-safe / VideoToolbox-oriented `ffmpeg` at `Contents/Resources/ffmpeg` (see [build/binaries/README.md](build/binaries/README.md)). MAS code paths prefer `h264_videotoolbox` and `hevc_videotoolbox` and must not rely on GPL encoders.

Upstream: https://ffmpeg.org/legal.html

## gifsicle

Used for optional GIF compression in **non–App Store** builds only. Licensed under GPL. Not invoked when `process.mas` is true.

Upstream: https://www.lcdf.org/gifsicle/

## Electron

Electron and its dependencies are used under their respective licenses. See the Electron project for the full dependency tree.

Upstream: https://www.electronjs.org/

## Other npm dependencies

Run `yarn licenses list` (or equivalent) before each store submission and retain the output with release artifacts. Include any additional license texts required by LGPL components you ship with the MAS binary.
