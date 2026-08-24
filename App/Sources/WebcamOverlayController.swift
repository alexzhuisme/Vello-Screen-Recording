import AVFoundation
import AppKit
import VelloCapture
import VelloCore

/// Shows the live camera bubble while recording. Vello's own windows are excluded
/// from ScreenCaptureKit; the matching bubble is composited into the video frames.
@MainActor
final class WebcamOverlayController {
    private var panel: NSPanel?
    private var followTimer: Timer?
    private var target: CaptureTarget?
    private var position: WebcamPosition = .bottomRight
    private var customPosition: WebcamCustomPosition = .center
    private var size: WebcamSize = .medium

    func show(
        session: AVCaptureSession,
        target: CaptureTarget,
        position: WebcamPosition,
        customPosition: WebcamCustomPosition,
        size: WebcamSize
    ) {
        stop()
        self.target = target
        self.position = position
        self.customPosition = customPosition
        self.size = size

        let preview = WebcamPreviewView(session: session)
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = preview
        self.panel = panel

        updateFrame()
        panel.orderFrontRegardless()

        if case .window = target {
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateFrame() }
            }
            RunLoop.main.add(timer, forMode: .common)
            followTimer = timer
        }
    }

    func stop() {
        followTimer?.invalidate()
        followTimer = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        target = nil
    }

    private func updateFrame() {
        guard let panel, let target, let targetFrame = captureFrame(for: target) else { return }
        let local = size.frame(
            in: targetFrame.size,
            position: position,
            customPosition: customPosition
        )
        let global = CGRect(
            x: targetFrame.minX + local.minX,
            y: targetFrame.minY + local.minY,
            width: local.width,
            height: local.height
        )
        panel.setFrame(global.integral, display: true)
        panel.contentView?.layer?.cornerRadius = global.width / 2
    }

    private func captureFrame(for target: CaptureTarget) -> CGRect? {
        switch target {
        case let .window(windowID):
            return CaptureDevices.cgWindowFrames()[windowID]

        case let .display(displayID, cropRect):
            guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else {
                return nil
            }
            guard let cropRect else { return screen.frame }
            return CGRect(
                x: screen.frame.minX + cropRect.minX,
                y: screen.frame.maxY - cropRect.maxY,
                width: cropRect.width,
                height: cropRect.height
            )
        }
    }
}

private final class WebcamPreviewView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = true
        layer?.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
        layer?.borderWidth = 3
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)

        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        layer?.cornerRadius = bounds.width / 2
    }
}
