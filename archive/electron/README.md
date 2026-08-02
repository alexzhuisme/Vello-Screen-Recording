# Archived Electron Vello

This directory is the previous Vello desktop app: an Electron + TypeScript +
Next.js fork of [Kap](https://github.com/wulkano/kap). It is kept only for
reference. The supported application is the native Swift app at the repository
root.

## Why it was archived

Vello is macOS-only. The native rewrite records with ScreenCaptureKit, edits and
exports with AVFoundation / ImageIO, and no longer ships Electron, Node, ffmpeg,
or gifsicle. That removes the Mac App Store GPL friction and a large web stack
for a menu-bar recorder.

## Layout (historical)

| Path | Role |
|------|------|
| `main/` | Electron main process |
| `renderer/` | Next.js UI |
| `build/` | electron-builder assets and MAS entitlements |
| `docs/` | Plugin and App Store notes from that era |
| `package.json` / `yarn.lock` | Node dependencies |

## Running the archived app

Not maintained. If you still need it locally:

```sh
cd archive/electron
yarn install
yarn start
```

Requirements matched the old README: Apple silicon, macOS 11+.

Do not treat this tree as the product; new work belongs in `App/` and `VelloKit/`
at the repository root.
