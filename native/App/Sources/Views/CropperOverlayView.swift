import AppKit
import SwiftUI
import VelloCapture
import VelloCore
import VelloUI

/// Full-screen overlay for one display: dims everything outside the capture
/// region and lets the user draw, move and resize that region.
struct CropperOverlayView: View {
    let display: CaptureDisplay
    @Bindable var model: CropperModel

    @State private var rectAtGestureStart: CGRect?

    private var isActive: Bool { model.activeDisplayID == display.id }
    private var bounds: CGRect { model.bounds(for: display) }
    private var selection: CGRect { model.selection }
    private var showsSelection: Bool { isActive && model.hasSelection }

    var body: some View {
        ZStack(alignment: .topLeading) {
            dimmingMask
                .contentShape(Rectangle())
                .gesture(createSelectionGesture)

            if showsSelection {
                selectionBorder
                if !model.isRecording {
                    moveSurface
                    handles
                    actionBar
                }
            }

            if isActive, !model.hasSelection, !model.isRecording {
                hint
            }
        }
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
        .ignoresSafeArea()
    }

    // MARK: - Layers

    /// One even-odd filled path gives a dimmed screen with a clear hole.
    private var dimmingMask: some View {
        Path { path in
            path.addRect(bounds)
            if showsSelection { path.addRect(selection) }
        }
        .fill(
            Color.black.opacity(model.isRecording ? 0.1 : 0.32),
            style: FillStyle(eoFill: true)
        )
    }

    private var selectionBorder: some View {
        Rectangle()
            .strokeBorder(borderColor, lineWidth: model.isRecording ? 2 : 1)
            .frame(width: selection.width, height: selection.height)
            .offset(x: selection.minX, y: selection.minY)
            .allowsHitTesting(false)
    }

    private var borderColor: Color {
        guard model.isRecording else { return .white.opacity(0.95) }
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

    private var actionBar: some View {
        CropperActionBar(model: model)
            .frame(width: VelloMetrics.actionBarSize.width, height: VelloMetrics.actionBarSize.height)
            .offset(x: actionBarOrigin.x, y: actionBarOrigin.y)
    }

    private var hint: some View {
        Text("Drag to select an area to record")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .frame(width: bounds.width, height: bounds.height)
            .allowsHitTesting(false)
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

    // MARK: - Layout

    /// Prefers sitting below the selection, flipping above when there is no room.
    private var actionBarOrigin: CGPoint {
        let size = VelloMetrics.actionBarSize
        let gap: CGFloat = 12

        var y = selection.maxY + gap
        if y + size.height > bounds.maxY - gap {
            y = selection.minY - size.height - gap
        }
        if y < bounds.minY + gap {
            y = max(bounds.minY + gap, bounds.maxY - size.height - gap)
        }

        let x = min(
            max(bounds.minX + gap, selection.midX - size.width / 2),
            max(bounds.minX + gap, bounds.maxX - size.width - gap)
        )
        return CGPoint(x: x, y: y)
    }
}
