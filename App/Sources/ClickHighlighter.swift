import AppKit
import SwiftUI

/// Draws expanding click ripples into the recording.
///
/// ScreenCaptureKit has no equivalent of AVFoundation's `capturesMouseClicks`, so
/// the ripples live in transparent overlay windows that are explicitly included in
/// the capture filter via `exceptingWindows`.
@MainActor
final class ClickHighlighter {
    private var overlays: [ClickHighlightOverlay] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isActive = false

    /// Window numbers currently hosting the ripple layers. Pass these to
    /// `ScreenRecorder` so the overlays are captured while the rest of Vello is not.
    var windowIDs: [CGWindowID] {
        overlays.map { CGWindowID($0.window.windowNumber) }
    }

    /// Shows one fullscreen, click-through overlay per display and starts listening.
    func start() {
        stop()
        isActive = true

        overlays = NSScreen.screens.map { screen in
            ClickHighlightOverlay(screen: screen)
        }
        for overlay in overlays {
            overlay.show()
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
        }

        // Clicks that land on Vello itself only arrive through the local monitor.
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
            return event
        }
    }

    func stop() {
        isActive = false

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        for overlay in overlays {
            overlay.close()
        }
        overlays.removeAll()
    }

    /// While paused the writer drops frames, so ripples would only distract on screen.
    func setPaused(_ paused: Bool) {
        isActive = !paused
    }

    private func handle(_ event: NSEvent) {
        guard isActive else { return }

        let location = NSEvent.mouseLocation
        guard let overlay = overlays.first(where: { $0.screen.frame.contains(location) }) else {
            return
        }

        let isRightClick = event.type == .rightMouseDown
            || event.modifierFlags.contains(.control)
        overlay.addRipple(at: location, style: isRightClick ? .secondary : .primary)
    }
}

// MARK: - Overlay window

@MainActor
private final class ClickHighlightOverlay {
    let screen: NSScreen
    let window: NSPanel
    private let model = ClickHighlightModel()

    init(screen: NSScreen) {
        self.screen = screen

        window = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        // Without this, ScreenCaptureKit would skip the window even when excepted.
        window.sharingType = .readOnly

        let hostingView = NSHostingView(rootView: ClickHighlightRootView(model: model))
        hostingView.frame = CGRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
    }

    func show() {
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
    }

    func close() {
        window.orderOut(nil)
        window.contentView = nil
    }

    func addRipple(at screenPoint: CGPoint, style: ClickRippleStyle) {
        // Convert from global bottom-left coordinates into the overlay's view space.
        // SwiftUI's top-leading layout wants a top-left origin.
        let local = CGPoint(
            x: screenPoint.x - screen.frame.minX,
            y: screen.frame.maxY - screenPoint.y
        )
        model.add(at: local, style: style)
    }
}

// MARK: - SwiftUI ripples

private enum ClickRippleStyle {
    case primary
    case secondary

    var color: Color {
        switch self {
        case .primary: Color(red: 0.25, green: 0.55, blue: 1.0)
        case .secondary: Color(red: 1.0, green: 0.45, blue: 0.2)
        }
    }
}

@MainActor
private final class ClickHighlightModel: ObservableObject {
    struct Ripple: Identifiable {
        let id = UUID()
        let point: CGPoint
        let style: ClickRippleStyle
    }

    @Published var ripples: [Ripple] = []

    func add(at point: CGPoint, style: ClickRippleStyle) {
        let ripple = Ripple(point: point, style: style)
        ripples.append(ripple)

        // Remove after the animation finishes so the overlay stays empty between clicks.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(520))
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

private struct ClickHighlightRootView: View {
    @ObservedObject var model: ClickHighlightModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(model.ripples) { ripple in
                ClickRippleView(color: ripple.style.color)
                    .position(ripple.point)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

private struct ClickRippleView: View {
    let color: Color

    @State private var scale: CGFloat = 0.35
    @State private var opacity: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.28))
            Circle()
                .strokeBorder(Color.white.opacity(0.95), lineWidth: 2.5)
            Circle()
                .strokeBorder(color.opacity(0.9), lineWidth: 2)
                .padding(3)
        }
        .frame(width: 52, height: 52)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.48)) {
                scale = 2.1
                opacity = 0
            }
        }
    }
}
