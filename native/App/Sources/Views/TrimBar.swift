import SwiftUI
import VelloCore

/// Filmstrip scrubber with draggable trim handles and a playhead.
///
/// One gesture owns the whole bar. Using absolute `location.x` inside a view that
/// does not move under the cursor avoids the classic feedback loop where
/// `translation` is half-consumed as the handle relocates during the drag.
struct TrimBar: View {
    @Bindable var model: EditorModel

    private let barHeight: CGFloat = 44
    private let handleWidth: CGFloat = 8
    private let handleHitSlop: CGFloat = 14
    private let playheadWidth: CGFloat = 3

    @State private var activeDrag: DragKind?

    private enum DragKind {
        case playhead
        case trimStart
        case trimEnd
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)

            ZStack {
                filmstrip
                dimmedRegions(width: width)
                selectionOutline(width: width)
                handleVisual(at: model.trimStart, width: width)
                handleVisual(at: model.trimEnd, width: width)
                playheadVisual(width: width)
            }
            .frame(width: width, height: barHeight)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            // Gesture sits on the stable full-width frame — never on a moving handle.
            .gesture(barGesture(width: width))
            .onHover { inside in
                // Rough cursor hint near either trim edge.
                guard inside else {
                    NSCursor.arrow.set()
                    return
                }
            }
        }
        .frame(height: barHeight)
    }

    // MARK: - Gesture

    private func barGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if activeDrag == nil {
                    activeDrag = hitTest(value.startLocation.x, width: width)
                }
                apply(drag: activeDrag, atX: value.location.x, width: width)
            }
            .onEnded { _ in
                activeDrag = nil
            }
    }

    /// Prefer grabbing a nearby trim handle; otherwise scrub the playhead.
    private func hitTest(_ xPosition: CGFloat, width: CGFloat) -> DragKind {
        let startX = x(for: model.trimStart, width: width)
        let endX = x(for: model.trimEnd, width: width)

        let distanceToStart = abs(xPosition - startX)
        let distanceToEnd = abs(xPosition - endX)

        if distanceToStart <= handleHitSlop || distanceToEnd <= handleHitSlop {
            return distanceToStart <= distanceToEnd ? .trimStart : .trimEnd
        }
        return .playhead
    }

    private func apply(drag: DragKind?, atX locationX: CGFloat, width: CGFloat) {
        let time = time(forX: locationX, width: width)
        switch drag {
        case .trimStart:
            model.setTrimStart(time)
        case .trimEnd:
            model.setTrimEnd(time)
        case .playhead, .none:
            model.pause()
            model.seek(to: min(max(time, model.trimStart), model.trimEnd))
        }
    }

    // MARK: - Visuals (no gestures — drawing only)

    private var filmstrip: some View {
        HStack(spacing: 0) {
            if model.thumbnails.isEmpty {
                Rectangle().fill(Color.black.opacity(0.35))
            } else {
                ForEach(Array(model.thumbnails.enumerated()), id: \.offset) { _, image in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dimmedRegions(width: CGFloat) -> some View {
        let startX = x(for: model.trimStart, width: width)
        let endX = x(for: model.trimEnd, width: width)

        return HStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(width: max(0, startX))
            Color.clear
                .frame(width: max(0, endX - startX))
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(width: max(0, width - endX))
        }
        .frame(width: width, height: barHeight)
    }

    private func selectionOutline(width: CGFloat) -> some View {
        let startX = x(for: model.trimStart, width: width)
        let endX = x(for: model.trimEnd, width: width)

        return HStack(spacing: 0) {
            Color.clear.frame(width: max(0, startX))
            Rectangle()
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .frame(width: max(0, endX - startX), height: barHeight)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: barHeight)
    }

    private func handleVisual(at time: TimeInterval, width: CGFloat) -> some View {
        let centre = x(for: time, width: width)
        let leading = min(max(centre - handleWidth / 2, 0), max(width - handleWidth, 0))

        return HStack(spacing: 0) {
            Color.clear.frame(width: leading)
            ZStack {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.accentColor)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 2, height: 16)
            }
            .frame(width: handleWidth, height: barHeight)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: barHeight)
        .allowsHitTesting(false)
    }

    private func playheadVisual(width: CGFloat) -> some View {
        let centre = x(for: model.currentTime, width: width)
        let leading = min(max(centre - playheadWidth / 2, 0), max(width - playheadWidth, 0))

        return HStack(spacing: 0) {
            Color.clear.frame(width: leading)
            Capsule()
                .fill(Color.white)
                .frame(width: playheadWidth, height: barHeight - 6)
                .shadow(color: .black.opacity(0.7), radius: 2)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: barHeight)
        .allowsHitTesting(false)
    }

    // MARK: - Mapping

    private func x(for time: TimeInterval, width: CGFloat) -> CGFloat {
        guard model.duration > 0, width > 0, time.isFinite else { return 0 }
        let ratio = min(max(time / model.duration, 0), 1)
        return CGFloat(ratio) * width
    }

    private func time(forX x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0, model.duration > 0 else { return 0 }
        return TimeInterval(min(max(x / width, 0), 1)) * model.duration
    }
}
