import AppKit
import SwiftUI
import VelloCapture
import VelloCore
import VelloUI

/// Full-screen overlay for one display: dims everything outside the capture
/// region and lets the user draw, move and resize that region — or hover-pick
/// a window when Space toggles into window mode.
struct CropperOverlayView: View {
    let display: CaptureDisplay
    @Bindable var model: CropperModel

    @State private var rectAtGestureStart: CGRect?
    @State private var webcamCenterAtGestureStart: CGPoint?
    @State private var isWebcamHovered = false

    private var isActive: Bool { model.activeDisplayID == display.id }
    private var bounds: CGRect { model.bounds(for: display) }
    private var selection: CGRect { model.selection }
    private var isRegionMode: Bool { model.selectionMode == .region }
    private var isWindowMode: Bool { model.selectionMode == .window }

    private var showsRegionSelection: Bool {
        isRegionMode && isActive && model.hasSelection
    }

    private var windowHighlight: CGRect? {
        guard isWindowMode, !model.isRecording else { return nil }
        return model.windowHighlightFrame(on: display)
    }

    private var showsWindowActionBar: Bool {
        isWindowMode && model.selectedWindow != nil && !model.isRecording && !model.isCountingDown
            && model.selectedWindow.map { $0.frame.intersects(display.frame) } == true
    }

    private var showsModeHint: Bool {
        guard isActive, !model.isRecording, !model.isCountingDown else { return false }
        // Region always starts with a default rect, so don't gate on hasSelection.
        if isWindowMode, model.selectedWindow != nil { return false }
        return true
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            interactionLayer

            if showsRegionSelection {
                selectionBorder(frame: selection, recording: model.isRecording)
                if model.isCountingDown {
                    countdownOverlay(anchoredTo: selection)
                } else if !model.isRecording {
                    moveSurface
                    handles
                    actionBar(anchoredTo: selection)
                    if model.settings.webcamEnabled {
                        webcamPlacementBubble(in: selection)
                    }
                }
            }

            if let highlight = windowHighlight {
                windowHighlightFill(highlight)
                selectionBorder(frame: highlight, recording: false)
                if model.isCountingDown, isActive {
                    countdownOverlay(anchoredTo: highlight)
                } else if showsWindowActionBar {
                    actionBar(anchoredTo: highlight)
                    if model.settings.webcamEnabled {
                        webcamPlacementBubble(in: highlight)
                    }
                } else if let summary = model.highlightedWindowSummary {
                    hoverLabel(summary, anchoredTo: highlight)
                }
            }

            // Mode switch hint stays up in region mode even with a default
            // selection — otherwise "Press Space to capture a window" never
            // appears. In window mode it yields once a window is confirmed.
            if showsModeHint {
                hint
            }
        }
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
        .ignoresSafeArea()
    }

    /// Region and window modes need different gesture recognizers; attaching both
    /// lets the drag gesture steal clicks meant for window selection.
    ///
    /// Dimming is visual-only (even-odd hole). A full-bounds catcher owns hit
    /// testing so clicks never fall through that hole to the app underneath —
    /// which is especially important in window mode, where the highlight punches
    /// a hole with no Region-style `moveSurface` to seal it.
    @ViewBuilder
    private var interactionLayer: some View {
        ZStack(alignment: .topLeading) {
            dimmingMask
                .allowsHitTesting(false)

            if isRegionMode, !model.isRecording, !model.isCountingDown {
                hitCatcher.gesture(createSelectionGesture)
            } else if isWindowMode, !model.isRecording, !model.isCountingDown {
                hitCatcher
                    .onTapGesture {
                        if model.selectedWindow != nil {
                            model.clearWindowSelection()
                        } else {
                            model.selectHoveredWindow(on: display)
                        }
                    }
                    .onContinuousHover { phase in
                        if case .ended = phase, model.selectedWindow == nil {
                            model.hoveredWindowID = nil
                            model.highlightFrame = nil
                        }
                    }
            } else {
                hitCatcher
            }
        }
    }

    // MARK: - Layers

    /// Nearly invisible, but hittable — same trick as `moveSurface`.
    private var hitCatcher: some View {
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(width: bounds.width, height: bounds.height)
    }

    /// One even-odd filled path gives a dimmed screen with a clear hole.
    private var dimmingMask: some View {
        Path { path in
            path.addRect(bounds)
            if showsRegionSelection {
                path.addRect(selection)
            } else if let highlight = windowHighlight {
                let radius = WindowGeometry.windowCornerRadius(for: highlight)
                path.addRoundedRect(in: highlight, cornerSize: CGSize(width: radius, height: radius))
            }
        }
        .fill(
            Color.black.opacity(model.isRecording ? 0.1 : 0.32),
            style: FillStyle(eoFill: true)
        )
        .allowsHitTesting(false)
    }

    private func windowHighlightFill(_ frame: CGRect) -> some View {
        let radius = WindowGeometry.windowCornerRadius(for: frame)
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.white.opacity(model.selectedWindow == nil ? 0.08 : 0.04))
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
            .allowsHitTesting(false)
    }

    private func selectionBorder(frame: CGRect, recording: Bool) -> some View {
        let radius = model.selectionMode == .window
            ? WindowGeometry.windowCornerRadius(for: frame)
            : 0
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(borderColor(recording: recording), lineWidth: recording ? 2 : 1)
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
            .allowsHitTesting(false)
    }

    /// Direct manipulation is the primary placement control. The menu remains
    /// available as an accessible, deterministic alternative for the four corners.
    private func webcamPlacementBubble(in captureFrame: CGRect) -> some View {
        let localFrame = model.settings.webcamSize.previewFrame(
            in: captureFrame.size,
            position: model.settings.webcamPosition,
            customPosition: model.settings.webcamCustomPosition
        )
        let diameter = localFrame.width

        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.39, blue: 0.96),
                            Color(red: 0.16, green: 0.68, blue: 0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "video.fill")
                .font(.system(size: max(14, diameter * 0.22), weight: .semibold))
                .foregroundStyle(.white)

            if diameter >= 58 {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: max(8, diameter * 0.09), weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: max(20, diameter * 0.22), height: max(20, diameter * 0.22))
                    .background(Color.black.opacity(0.58), in: Circle())
                    .offset(x: diameter * 0.31, y: diameter * 0.31)
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay {
            Circle().strokeBorder(.white.opacity(0.92), lineWidth: 3)
        }
        .shadow(color: .black.opacity(0.32), radius: 12, y: 6)
        .scaleEffect(isWebcamHovered ? 1.025 : 1)
        .offset(
            x: captureFrame.minX + localFrame.minX,
            y: captureFrame.minY + localFrame.minY
        )
        .contentShape(Circle())
        // The capture region has its own full-surface drag gesture underneath.
        // Give direct camera placement precedence so that gesture cannot steal
        // the mouse-down (which made the bubble appear stuck on full-screen crops).
        .highPriorityGesture(webcamPlacementGesture(in: captureFrame), including: .all)
        .zIndex(10)
        .onHover { inside in
            isWebcamHovered = inside
            if inside {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.snappy(duration: 0.18), value: model.settings.webcamPosition)
        .animation(.easeOut(duration: 0.12), value: isWebcamHovered)
        .help("Drag to position the webcam bubble. It snaps to the four corners.")
        .accessibilityLabel("Webcam bubble position")
        .accessibilityHint("Drag to move, or choose a position from the Webcam menu")
    }

    private func borderColor(recording: Bool) -> Color {
        guard recording else { return .white.opacity(0.95) }
        return model.isPaused ? .orange.opacity(0.9) : .red.opacity(0.9)
    }

    private var moveSurface: some View {
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(width: selection.width, height: selection.height)
            .offset(x: selection.minX, y: selection.minY)
            .onHover { inside in
                if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
            }
            .gesture(moveGesture)
    }

    private var handles: some View {
        ForEach(ResizeHandle.allCases) { handle in
            let position = handle.position(in: selection)
            Rectangle()
                .fill(Color.white)
                .frame(width: VelloMetrics.cropHandleSize, height: VelloMetrics.cropHandleSize)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .offset(
                    x: position.x - VelloMetrics.cropHandleSize / 2,
                    y: position.y - VelloMetrics.cropHandleSize / 2
                )
                .gesture(resizeGesture(for: handle))
        }
    }

    private func actionBar(anchoredTo frame: CGRect) -> some View {
        CropperActionBar(model: model)
            .frame(width: VelloMetrics.actionBarSize.width, height: VelloMetrics.actionBarSize.height)
            .offset(x: actionBarOrigin(for: frame).x, y: actionBarOrigin(for: frame).y)
    }

    private func countdownOverlay(anchoredTo frame: CGRect) -> some View {
        let shortestSide = min(frame.width, frame.height)
        let badgeSize = min(112, max(22, shortestSide * 0.72))

        return VStack(spacing: 7) {
            if let remaining = model.countdownRemaining {
                Text("\(remaining)")
                    .font(.system(size: badgeSize * 0.56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .frame(width: badgeSize, height: badgeSize)
                    .background(Color.black.opacity(0.78), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 14, y: 4)
            }

            if shortestSide >= 160 {
                Text("Esc to cancel")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.68), in: Capsule())
            }
        }
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: frame.minY)
        .animation(.snappy(duration: 0.22), value: model.countdownRemaining)
        .allowsHitTesting(false)
    }

    /// Shown while hovering a window (before click) so the user knows which app is targeted.
    private func hoverLabel(_ text: String, anchoredTo frame: CGRect) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.78), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
            .fixedSize()
            .offset(x: hoverLabelOrigin(for: frame, labelWidth: 220).x, y: hoverLabelOrigin(for: frame, labelWidth: 220).y)
            .allowsHitTesting(false)
    }

    private var hint: some View {
        Text(hintText)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.72), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
            .frame(width: bounds.width, height: bounds.height)
            .allowsHitTesting(false)
    }

    private var hintText: String {
        switch model.selectionMode {
        case .region:
            "Drag to select · Press Space to capture a window"
        case .window:
            "Click a window · Press Space for region"
        }
    }

    // MARK: - Gestures

    private var createSelectionGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                model.beginSelection(on: display.id)
                model.selection = SelectionGeometry.normalized(
                    from: value.startLocation,
                    to: value.location,
                    in: bounds
                )
            }
            .onEnded { _ in model.commitSelection() }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = rectAtGestureStart ?? selection
                rectAtGestureStart = start
                model.selection = SelectionGeometry.move(start, by: value.translation, in: bounds)
            }
            .onEnded { _ in
                rectAtGestureStart = nil
                model.commitSelection()
            }
    }

    private func resizeGesture(for handle: ResizeHandle) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = rectAtGestureStart ?? selection
                rectAtGestureStart = start
                model.selection = SelectionGeometry.resize(
                    start,
                    handle: handle,
                    translation: value.translation,
                    // Holding Shift keeps the region's proportions while dragging.
                    lockAspectRatio: NSEvent.modifierFlags.contains(.shift),
                    in: bounds,
                    minimumSize: VelloMetrics.minimumCropSize
                )
            }
            .onEnded { _ in
                rectAtGestureStart = nil
                model.commitSelection()
            }
    }

    private func webcamPlacementGesture(in captureFrame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let settings = model.settings
                let localFrame = settings.webcamSize.previewFrame(
                    in: captureFrame.size,
                    position: settings.webcamPosition,
                    customPosition: settings.webcamCustomPosition
                )
                let currentCenter = CGPoint(
                    x: captureFrame.minX + localFrame.midX,
                    y: captureFrame.minY + localFrame.midY
                )
                let start = webcamCenterAtGestureStart ?? currentCenter
                webcamCenterAtGestureStart = start
                model.updateWebcamPlacement(
                    to: CGPoint(
                        x: start.x + value.translation.width,
                        y: start.y + value.translation.height
                    ),
                    in: captureFrame
                )
            }
            .onEnded { value in
                if let start = webcamCenterAtGestureStart {
                    model.updateWebcamPlacement(
                        to: CGPoint(
                            x: start.x + value.translation.width,
                            y: start.y + value.translation.height
                        ),
                        in: captureFrame
                    )
                }
                webcamCenterAtGestureStart = nil
            }
    }

    // MARK: - Layout

    /// Prefers sitting below the selection, flipping above when there is no room.
    private func actionBarOrigin(for frame: CGRect) -> CGPoint {
        let size = VelloMetrics.actionBarSize
        let gap: CGFloat = 12

        var y = frame.maxY + gap
        if y + size.height > bounds.maxY - gap {
            y = frame.minY - size.height - gap
        }
        if y < bounds.minY + gap {
            y = max(bounds.minY + gap, bounds.maxY - size.height - gap)
        }

        let x = min(
            max(bounds.minX + gap, frame.midX - size.width / 2),
            max(bounds.minX + gap, bounds.maxX - size.width - gap)
        )
        return CGPoint(x: x, y: y)
    }

    /// Sits just above the hovered window; falls below if there is no room.
    private func hoverLabelOrigin(for frame: CGRect, labelWidth: CGFloat) -> CGPoint {
        let labelHeight: CGFloat = 34
        let gap: CGFloat = 10

        var y = frame.minY - labelHeight - gap
        if y < bounds.minY + gap {
            y = frame.maxY + gap
        }

        let x = min(
            max(bounds.minX + gap, frame.midX - labelWidth / 2),
            max(bounds.minX + gap, bounds.maxX - labelWidth - gap)
        )
        return CGPoint(x: x, y: y)
    }
}
