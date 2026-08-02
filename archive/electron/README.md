# Archived Electron Vello — frozen / disposable

This directory is a **frozen snapshot** of the old Electron + TypeScript +
Next.js Vello app (a Kap fork). It is **not maintained**, **not shipped**, and
**not** the Mac App Store product.

The shipping app is the native Swift project at the repository root
(`App/`, `VelloKit/`, `project.yml`).

## Status

| | |
|--|--|
| Product | No — Swift app only |
| App Store | No — do not submit this tree |
| Maintenance | None — reference only |
| Safe to delete later | Yes, if you no longer want history in-tree |

Incomplete Electron Mac App Store packaging experiments that lived only in a
working tree were discarded; do not resume them here.

## Why it was archived

Vello is macOS-only. The Swift rewrite uses ScreenCaptureKit and
AVFoundation / ImageIO, and does not ship Electron, Node, ffmpeg, or gifsicle.

## Layout (historical)

| Path | Role |
|------|------|
| `main/` | Electron main process |
| `renderer/` | Next.js UI |
| `build/` | electron-builder assets (including unfinished MAS entitlements) |
| `docs/` | Notes from that era |
| `package.json` / `yarn.lock` | Node dependencies |

## If you must run it locally

```sh
cd archive/electron
yarn install
yarn start
```

Apple silicon, macOS 11+. Expect bitrot; fix nothing unless you intentionally
un-archive this stack.

New work belongs in `App/` and `VelloKit/` only.
