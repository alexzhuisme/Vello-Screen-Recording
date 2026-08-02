import CoreGraphics
import Foundation

public enum ResizeHandle: String, CaseIterable, Sendable, Identifiable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    public var id: String { rawValue }

    public var affectsLeft: Bool { self == .topLeft || self == .left || self == .bottomLeft }
    public var affectsRight: Bool { self == .topRight || self == .right || self == .bottomRight }
    public var affectsTop: Bool { self == .topLeft || self == .top || self == .topRight }
    public var affectsBottom: Bool { self == .bottomLeft || self == .bottom || self == .bottomRight }

    public var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomLeft, .bottomRight: true
        case .top, .right, .bottom, .left: false
        }
    }

    /// Anchor point that stays put while this handle is dragged.
    public func anchor(in rect: CGRect) -> CGPoint {
        CGPoint(
            x: affectsLeft ? rect.maxX : rect.minX,
            y: affectsTop ? rect.maxY : rect.minY
        )
    }

    public func position(in rect: CGRect) -> CGPoint {
        let x: CGFloat = affectsLeft ? rect.minX : (affectsRight ? rect.maxX : rect.midX)
        let y: CGFloat = affectsTop ? rect.minY : (affectsBottom ? rect.maxY : rect.midY)
        return CGPoint(x: x, y: y)
    }
}

/// Pure geometry for the crop overlay. All rectangles use a top-left origin in
/// display-local points, matching what `SCStreamConfiguration.sourceRect` expects.
public enum SelectionGeometry {
    public static func normalized(from start: CGPoint, to end: CGPoint, in bounds: CGRect) -> CGRect {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        return rect.intersection(bounds)
    }

    public static func move(_ rect: CGRect, by translation: CGSize, in bounds: CGRect) -> CGRect {
        let proposedX = rect.minX + translation.width
        let proposedY = rect.minY + translation.height
        return CGRect(
            x: clamp(proposedX, bounds.minX, max(bounds.minX, bounds.maxX - rect.width)),
            y: clamp(proposedY, bounds.minY, max(bounds.minY, bounds.maxY - rect.height)),
            width: rect.width,
            height: rect.height
        )
    }

    public static func resize(
        _ rect: CGRect,
        handle: ResizeHandle,
        translation: CGSize,
        lockAspectRatio: Bool = false,
        in bounds: CGRect,
        minimumSize: CGSize
    ) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        // A handle never drives opposite edges, so these clamps cannot fight.
        if handle.affectsLeft {
            minX = clamp(rect.minX + translation.width, bounds.minX, maxX - minimumSize.width)
        }
        if handle.affectsRight {
            maxX = clamp(rect.maxX + translation.width, minX + minimumSize.width, bounds.maxX)
        }
        if handle.affectsTop {
            minY = clamp(rect.minY + translation.height, bounds.minY, maxY - minimumSize.height)
        }
        if handle.affectsBottom {
            maxY = clamp(rect.maxY + translation.height, minY + minimumSize.height, bounds.maxY)
        }

        let resized = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        guard lockAspectRatio, rect.width > 0, rect.height > 0 else { return resized }

        return applyAspectRatio(
            rect.height / rect.width,
            to: resized,
            handle: handle,
            in: bounds,
            minimumSize: minimumSize
        )
    }

    /// Reshapes `rect` to `ratio` while keeping the handle's opposite corner fixed.
    private static func applyAspectRatio(
        _ ratio: CGFloat,
        to rect: CGRect,
        handle: ResizeHandle,
        in bounds: CGRect,
        minimumSize: CGSize
    ) -> CGRect {
        var width = rect.width
        var height = rect.height

        // Edge handles drive a single axis, so derive the other one from it.
        if handle.affectsLeft || handle.affectsRight {
            height = width * ratio
        } else {
            width = height / max(ratio, 0.0001)
        }

        width = max(width, minimumSize.width)
        height = max(height, minimumSize.height)

        let anchoredRight = handle.affectsLeft
        let anchoredBottom = handle.affectsTop
        var originX = anchoredRight ? rect.maxX - width : rect.minX
        var originY = anchoredBottom ? rect.maxY - height : rect.minY

        // Shrink rather than spill outside the display.
        if originX < bounds.minX || originX + width > bounds.maxX {
            width = min(width, anchoredRight ? rect.maxX - bounds.minX : bounds.maxX - rect.minX)
            height = width * ratio
            originX = anchoredRight ? rect.maxX - width : rect.minX
            originY = anchoredBottom ? rect.maxY - height : rect.minY
        }
        if originY < bounds.minY || originY + height > bounds.maxY {
            height = min(height, anchoredBottom ? rect.maxY - bounds.minY : bounds.maxY - rect.minY)
            width = height / max(ratio, 0.0001)
            originX = anchoredRight ? rect.maxX - width : rect.minX
            originY = anchoredBottom ? rect.maxY - height : rect.minY
        }

        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    /// A sensible starting region: 16:9 at roughly two thirds of the display, centred.
    public static func defaultSelection(in bounds: CGRect) -> CGRect {
        let width = (bounds.width * 0.66).rounded()
        let height = min((width * 9 / 16).rounded(), bounds.height * 0.8)
        return CGRect(
            x: bounds.minX + ((bounds.width - width) / 2).rounded(),
            y: bounds.minY + ((bounds.height - height) / 2).rounded(),
            width: width,
            height: height
        )
    }

    /// Recordings encode more reliably when both dimensions are even.
    public static func evenSized(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x.rounded(),
            y: rect.origin.y.rounded(),
            width: max(2, rect.width.rounded().evenDown),
            height: max(2, rect.height.rounded().evenDown)
        )
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        guard upper > lower else { return lower }
        return min(max(value, lower), upper)
    }
}

private extension CGFloat {
    var evenDown: CGFloat {
        let integer = Int(self)
        return CGFloat(integer - (integer % 2))
    }
}
