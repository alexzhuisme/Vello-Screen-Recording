import CoreGraphics
import Foundation
import Testing
import VelloCapture
import VelloUI

@Suite("WindowGeometry")
struct WindowGeometryTests {
    private let display = CaptureDisplay(
        id: 1,
        frame: CGRect(x: 100, y: 200, width: 800, height: 600),
        scaleFactor: 2,
        localizedName: "Test"
    )

    @Test("Global window frames convert into display-local top-left coordinates")
    func convertsGlobalFrameToDisplayLocal() {
        let global = CGRect(x: 150, y: 250, width: 200, height: 100)
        let local = WindowGeometry.displayLocalFrame(global, on: display)

        #expect(local.origin.x == 50)
        #expect(local.origin.y == 450)
        #expect(local.size == CGSize(width: 200, height: 100))
    }

    @Test("Quartz top-left window bounds flip into AppKit bottom-left coordinates")
    func flipsCGWindowBoundsToAppKit() {
        // Primary display is 1512×982; a window 69pt from the top with height 909
        // bottoms out at AppKit y = 982 - 69 - 909 = 4.
        let primaryHeight: CGFloat = 982
        let cgBounds = CGRect(x: 264, y: 69, width: 1161, height: 909)
        let appKit = CaptureDevices.appKitFrame(
            fromCGWindowBounds: cgBounds,
            primaryDisplayHeight: primaryHeight
        )

        #expect(appKit.origin.x == 264)
        #expect(appKit.origin.y == primaryHeight - 69 - 909)
        #expect(appKit.size == cgBounds.size)

        let main = CaptureDisplay(
            id: 1,
            frame: CGRect(x: 0, y: 0, width: 1512, height: primaryHeight),
            scaleFactor: 2,
            localizedName: "Main"
        )
        let local = WindowGeometry.displayLocalFrame(appKit, on: main)
        #expect(local.origin.y == 69)
    }

    @Test("Capture resolution skips high-layer overlays then picks the front capturable window")
    func skipsUtilityLayersThenPicksFrontWindow() {
        let appStore = CaptureWindow(
            id: 10,
            title: "App Store",
            applicationName: "App Store",
            bundleIdentifier: "com.apple.AppStore",
            processID: 42,
            frame: CGRect(x: 100, y: 100, width: 800, height: 600)
        )
        let behind = CaptureWindow(
            id: 11,
            title: "Typeless",
            applicationName: "Typeless",
            bundleIdentifier: "app.typeless",
            processID: 7,
            frame: CGRect(x: 150, y: 150, width: 500, height: 400)
        )

        let point = CGPoint(x: 400, y: 300)
        let hits = [
            WindowServerHit(
                windowID: 99,
                ownerPID: 1,
                layer: 25,
                frame: CGRect(x: 0, y: 0, width: 1500, height: 1000)
            ),
            WindowServerHit(
                windowID: appStore.id,
                ownerPID: appStore.processID,
                layer: 0,
                frame: appStore.frame
            ),
            WindowServerHit(
                windowID: behind.id,
                ownerPID: behind.processID,
                layer: 0,
                frame: behind.frame
            )
        ]

        let resolved = WindowGeometry.captureWindow(
            at: point,
            hitsFrontToBack: hits,
            in: [appStore, behind]
        )
        #expect(resolved?.id == appStore.id)
        #expect(resolved?.frame == appStore.frame)
    }

    @Test("Floating Status panels are skipped so the layer-0 window underneath wins")
    func skipsFloatingStatusForLayerZeroUnderneath() {
        let main = CaptureWindow(
            id: 10898,
            title: "Typeless",
            applicationName: "Typeless",
            bundleIdentifier: "app.typeless",
            processID: 38954,
            frame: CGRect(x: 314, y: 146, width: 1080, height: 750)
        )
        let status = CaptureWindow(
            id: 10899,
            title: "Status",
            applicationName: "Typeless",
            bundleIdentifier: "app.typeless",
            processID: 38954,
            frame: CGRect(x: 368, y: 482, width: 750, height: 500)
        )

        let point = CGPoint(x: 700, y: 600)
        let hits = [
            WindowServerHit(
                windowID: status.id,
                ownerPID: status.processID,
                layer: 4,
                frame: status.frame
            ),
            WindowServerHit(
                windowID: main.id,
                ownerPID: main.processID,
                layer: 0,
                frame: main.frame
            )
        ]

        let resolved = WindowGeometry.captureWindow(
            at: point,
            hitsFrontToBack: hits,
            in: [status, main]
        )
        #expect(resolved?.id == main.id)
        #expect(resolved?.frame == main.frame)
    }

    @Test("Floating Status over another app does not steal the hit for Typeless behind it")
    func floatingStatusDoesNotSkipInterveningApp() {
        let typeless = CaptureWindow(
            id: 10898,
            title: "Typeless",
            applicationName: "Typeless",
            bundleIdentifier: "app.typeless",
            processID: 38954,
            frame: CGRect(x: 100, y: 100, width: 1200, height: 800)
        )
        let status = CaptureWindow(
            id: 10899,
            title: "Status",
            applicationName: "Typeless",
            bundleIdentifier: "app.typeless",
            processID: 38954,
            frame: CGRect(x: 200, y: 200, width: 750, height: 500)
        )
        let codex = CaptureWindow(
            id: 42,
            title: "Codex",
            applicationName: "Cursor",
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            processID: 99,
            frame: CGRect(x: 150, y: 120, width: 900, height: 700)
        )

        let point = CGPoint(x: 400, y: 400)
        let hits = [
            WindowServerHit(
                windowID: status.id,
                ownerPID: status.processID,
                layer: 4,
                frame: status.frame
            ),
            WindowServerHit(
                windowID: codex.id,
                ownerPID: codex.processID,
                layer: 0,
                frame: codex.frame
            ),
            WindowServerHit(
                windowID: typeless.id,
                ownerPID: typeless.processID,
                layer: 0,
                frame: typeless.frame
            )
        ]

        let resolved = WindowGeometry.captureWindow(
            at: point,
            hitsFrontToBack: hits,
            in: [status, typeless, codex]
        )
        #expect(resolved?.id == codex.id)
        #expect(resolved?.applicationName == "Cursor")
    }

    @Test("Unknown child surfaces promote to the capturable window of the same process")
    func promotesUnknownChildToSameProcessWindow() {
        let appStore = CaptureWindow(
            id: 10,
            title: "App Store",
            applicationName: "App Store",
            bundleIdentifier: "com.apple.AppStore",
            processID: 42,
            frame: CGRect(x: 100, y: 100, width: 800, height: 600)
        )

        let point = CGPoint(x: 400, y: 300)
        let hits = [
            WindowServerHit(
                windowID: 555,
                ownerPID: 42,
                layer: 0,
                frame: CGRect(x: 200, y: 200, width: 400, height: 300)
            ),
            WindowServerHit(
                windowID: appStore.id,
                ownerPID: appStore.processID,
                layer: 0,
                frame: appStore.frame
            )
        ]

        let resolved = WindowGeometry.captureWindow(
            at: point,
            hitsFrontToBack: hits,
            in: [appStore]
        )
        #expect(resolved?.id == appStore.id)
        #expect(resolved?.frame == appStore.frame)
    }
}
