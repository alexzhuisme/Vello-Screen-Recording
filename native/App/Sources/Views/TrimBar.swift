import SwiftUI
import VelloCore

/// Filmstrip scrubber with draggable trim handles and a playhead.
struct TrimBar: View {
    @Bindable var model: EditorModel

    private let handleWidth: CGFloat = 10
    private let barHeight: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .topLeading) {
                filmstrip
                dimmedRegions(width: width)
                trimSelectionBorder(width: width)
                handle(for: .start, width: width)
                handle(for: .end, width: width)
                playhead(width: width)
            }
            .frame(width: width, height: barHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
            .gesture(scrubGesture(width: width))
        }
        .frame(height: barHeight)
    }

    // MARK: - Layers

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
        .frame(height: barHeight)
    }

    private func dimmedRegions(width: CGFloat) -> some View {
        let startX = x(for: model.trimStart, width: width)
        let endX = x(for: model.trimEnd, width: width)
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(width: max(0, startX), height: barHeight)
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(width: max(0, width - endX), height: barHeight)
                .offset(x: endX)
        }
        .allowsHitTesting(false)
    }

    private func trimSelectionBorder(width: CGFloat) -> some View {
        let startX = x(for: model.trimStart, width: width)
        let endX = x(for: model.trimEnd, width: width)
        return Rectangle()
            .strokeBorder(Color.accentColor, lineWidth: 2)
            .frame(width: max(0, endX - startX), height: barHeight)
            .offset(x: startX)
            .allowsHitTesting(false)
    }

    private enum TrimEdge { case start, end }

    private func handle(for edge: TrimEdge, width: CGFloat) -> some View {
        let time = edge == .start ? model.trimStart : model.trimEnd
        let centre = x(for: time, width: width)

        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.accentColor)
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2, height: 16)
            )
            .frame(width: handleWidth, height: barHeight)
            .offset(x: min(max(0, centre - handleWidth / 2), width - handleWidth))
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newTime = self.time(forX: value.location.x + centre - handleWidth / 2, width: width)
                        switch edge {
                        case .start: model.setTrimStart(newTime)
                        case .end: model.setTrimEnd(newTime)
                        }
                    }
            )
    }

    private func playhead(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: barHeight)
            .shadow(color: .black.opacity(0.6), radius: 2)
            .offset(x: min(max(0, x(for: model.currentTime, width: width) - 1), width - 2))
            .allowsHitTesting(false)
    }

    // MARK: - Gestures

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let target = time(forX: value.location.x, width: width)
                model.seek(to: min(max(target, model.trimStart), model.trimEnd))
            }
    }

    // MARK: - Mapping

    private func x(for time: TimeInterval, width: CGFloat) -> CGFloat {
        guard model.duration > 0 else { return 0 }
        return CGFloat(time / model.duration) * width
    }

    private func time(forX x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        return TimeInterval(min(max(x / width, 0), 1)) * model.duration
    }
}
