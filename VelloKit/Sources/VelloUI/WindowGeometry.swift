import CoreGraphics
import Foundation
import VelloCapture

/// A WindowServer window under the cursor, ordered front to back.
public struct WindowServerHit: Sendable, Equatable {
    public let windowID: CGWindowID
    public let ownerPID: pid_t
    public let layer: Int
    public let frame: CGRect

    public init(windowID: CGWindowID, ownerPID: pid_t, layer: Int, frame: CGRect) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.layer = layer
        self.frame = frame
    }

    public var area: CGFloat { frame.width * frame.height }
}

/// Converts between global AppKit/SCK frames (bottom-left origin) and the
/// display-local top-left coordinates used by the cropper overlay.
public enum WindowGeometry {
    /// Maps a window's global frame into display-local top-left points.
    public static func displayLocalFrame(
        _ globalFrame: CGRect,
        on display: CaptureDisplay
    ) -> CGRect {
        CGRect(
            x: globalFrame.minX - display.frame.minX,
            y: display.frame.maxY - globalFrame.maxY,
            width: globalFrame.width,
            height: globalFrame.height
        )
    }

    /// Maps a global AppKit mouse location into display-local top-left points.
    public static func displayLocalPoint(
        _ globalPoint: CGPoint,
        on display: CaptureDisplay
    ) -> CGPoint {
        CGPoint(
            x: globalPoint.x - display.frame.minX,
            y: display.frame.maxY - globalPoint.y
        )
    }

    /// Frontmost → backmost windows under `point`, from `CGWindowList`.
    public static func windowServerHits(
        at point: CGPoint,
        excludingWindowNumbers: Set<Int> = []
    ) -> [WindowServerHit] {
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        var hits: [WindowServerHit] = []
        for entry in info {
            guard let number = entry[kCGWindowNumber as String] as? Int,
                  !excludingWindowNumbers.contains(number),
                  let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let width = bounds["Width"], let height = bounds["Height"]
            else { continue }

            let alpha = entry[kCGWindowAlpha as String] as? CGFloat ?? 1
            guard alpha > 0.05 else { continue }

            let frame = CaptureDevices.appKitFrame(
                fromCGWindowBounds: CGRect(x: x, y: y, width: width, height: height)
            )
            guard frame.width >= 1, frame.height >= 1, frame.contains(point) else { continue }

            hits.append(
                WindowServerHit(
                    windowID: CGWindowID(number),
                    ownerPID: ownerPID,
                    layer: layer,
                    frame: frame
                )
            )
        }
        return hits
    }

    /// Resolves the capture target under the cursor.
    ///
    /// Walks WindowServer z-order, skips utility layers, and prefers each app's
    /// main (`layer == 0`) window over floating panels (Typeless Status, etc.).
    public static func captureWindow(
        at point: CGPoint,
        hitsFrontToBack: [WindowServerHit],
        in windows: [CaptureWindow]
    ) -> CaptureWindow? {
        let byID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })

        for hit in hitsFrontToBack {
            guard (0...8).contains(hit.layer) else { continue }

            // Floating panels (layer > 0) often sit above the real window and have
            // inset frames. Prefer that process's largest capturable layer-0 window.
            if let main = mainWindow(
                forProcess: hit.ownerPID,
                hitsFrontToBack: hitsFrontToBack,
                byID: byID
            ) {
                return main
            }

            if let exact = byID[hit.windowID] {
                return exact.withFrame(hit.frame)
            }

            // Child surface omitted from SCK — largest capturable window of that PID.
            if let fallback = largestWindow(forProcess: hit.ownerPID, in: Array(byID.values), hits: hitsFrontToBack) {
                return fallback
            }
        }
        return nil
    }

    /// Largest layer-0 capturable window for `pid` that appears in the live hit list.
    private static func mainWindow(
        forProcess pid: pid_t,
        hitsFrontToBack: [WindowServerHit],
        byID: [CGWindowID: CaptureWindow]
    ) -> CaptureWindow? {
        let layerZero = hitsFrontToBack.compactMap { hit -> CaptureWindow? in
            guard hit.layer == 0, hit.ownerPID == pid, let window = byID[hit.windowID] else {
                return nil
            }
            return window.withFrame(hit.frame)
        }
        return layerZero.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
    }

    private static func largestWindow(
        forProcess pid: pid_t,
        in windows: [CaptureWindow],
        hits: [WindowServerHit]
    ) -> CaptureWindow? {
        let liveFrames = Dictionary(uniqueKeysWithValues: hits.map { ($0.windowID, $0.frame) })
        let candidates = windows.filter { $0.processID == pid }
        guard let best = candidates.max(by: {
            $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height
        }) else { return nil }
        return best.withFrame(liveFrames[best.id] ?? best.frame)
    }

    /// Corner radius that visually matches standard macOS windows at typical sizes.
    public static func windowCornerRadius(for frame: CGRect) -> CGFloat {
        min(14, max(10, min(frame.width, frame.height) * 0.025))
    }
}
