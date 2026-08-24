import CoreGraphics
import Foundation

public enum WebcamPosition: String, Sendable, Codable, Hashable, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .custom: "Custom"
        }
    }

    public static let corners: [WebcamPosition] = [
        .topLeft, .topRight, .bottomLeft, .bottomRight
    ]
}

/// Resolution-independent camera center measured from the top-left of the
/// capture area. Keeping this normalized makes a dragged position stable when
/// the user switches between displays, regions, and windows of different sizes.
public struct WebcamCustomPosition: Sendable, Codable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }

    public static let center = WebcamCustomPosition(x: 0.5, y: 0.5)
}

public enum WebcamSize: String, Sendable, Codable, Hashable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }

    private var fraction: CGFloat {
        switch self {
        case .small: 0.18
        case .medium: 0.25
        case .large: 0.33
        }
    }

    /// Pixel frame for the circular camera bubble within a captured video frame.
    /// Core Image uses a bottom-left origin, while `customPosition` is stored in
    /// the top-left coordinate space users interact with in the cropper.
    public func frame(
        in canvasSize: CGSize,
        position: WebcamPosition,
        customPosition: WebcamCustomPosition = .center
    ) -> CGRect {
        let preview = previewFrame(
            in: canvasSize,
            position: position,
            customPosition: customPosition
        )
        return CGRect(
            x: preview.minX,
            y: canvasSize.height - preview.maxY,
            width: preview.width,
            height: preview.height
        )
    }

    /// Top-left-origin frame used by the on-screen cropper and drag interaction.
    public func previewFrame(
        in canvasSize: CGSize,
        position: WebcamPosition,
        customPosition: WebcamCustomPosition = .center
    ) -> CGRect {
        let metrics = layoutMetrics(in: canvasSize)
        let diameter = metrics.diameter
        let margin = metrics.margin

        let maximumX = max(margin, canvasSize.width - diameter - margin)
        let maximumY = max(margin, canvasSize.height - diameter - margin)

        let origin: CGPoint
        switch position {
        case .topLeft:
            origin = CGPoint(x: margin, y: margin)
        case .topRight:
            origin = CGPoint(x: maximumX, y: margin)
        case .bottomLeft:
            origin = CGPoint(x: margin, y: maximumY)
        case .bottomRight:
            origin = CGPoint(x: maximumX, y: maximumY)
        case .custom:
            let inset = margin + diameter / 2
            let maximumCenterX = max(inset, canvasSize.width - inset)
            let maximumCenterY = max(inset, canvasSize.height - inset)
            let center = CGPoint(
                x: min(max(CGFloat(customPosition.x) * canvasSize.width, inset), maximumCenterX),
                y: min(max(CGFloat(customPosition.y) * canvasSize.height, inset), maximumCenterY)
            )
            origin = CGPoint(x: center.x - diameter / 2, y: center.y - diameter / 2)
        }

        return CGRect(x: origin.x, y: origin.y, width: diameter, height: diameter)
    }

    /// Converts a drag center into a constrained custom position, snapping to a
    /// named corner when it enters the supplied threshold.
    public func placement(
        forPreviewCenter proposedCenter: CGPoint,
        in canvasSize: CGSize,
        snappingThreshold: CGFloat = 28
    ) -> (position: WebcamPosition, customPosition: WebcamCustomPosition) {
        let metrics = layoutMetrics(in: canvasSize)
        let inset = metrics.margin + metrics.diameter / 2
        let maximumCenterX = max(inset, canvasSize.width - inset)
        let maximumCenterY = max(inset, canvasSize.height - inset)
        let center = CGPoint(
            x: min(max(proposedCenter.x, inset), maximumCenterX),
            y: min(max(proposedCenter.y, inset), maximumCenterY)
        )
        let customPosition = WebcamCustomPosition(
            x: Double(center.x / max(1, canvasSize.width)),
            y: Double(center.y / max(1, canvasSize.height))
        )

        var nearestCorner: WebcamPosition?
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        for corner in WebcamPosition.corners {
            let frame = previewFrame(in: canvasSize, position: corner)
            let distance = hypot(frame.midX - center.x, frame.midY - center.y)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestCorner = corner
            }
        }

        if nearestDistance <= max(0, snappingThreshold), let nearestCorner {
            return (nearestCorner, customPosition)
        }
        return (.custom, customPosition)
    }

    private func layoutMetrics(in canvasSize: CGSize) -> (diameter: CGFloat, margin: CGFloat) {
        let shortestSide = max(2, min(canvasSize.width, canvasSize.height))
        let maximumDiameter = max(24, shortestSide - 24)
        let diameter = min(max(48, shortestSide * fraction), maximumDiameter)
        let margin = min(24, max(8, diameter * 0.1))
        return (diameter, margin)
    }
}

public struct WebcamConfiguration: Sendable, Codable, Hashable {
    public var deviceID: String
    public var position: WebcamPosition
    public var customPosition: WebcamCustomPosition
    public var size: WebcamSize

    public init(
        deviceID: String,
        position: WebcamPosition = .bottomRight,
        customPosition: WebcamCustomPosition = .center,
        size: WebcamSize = .medium
    ) {
        self.deviceID = deviceID
        self.position = position
        self.customPosition = customPosition
        self.size = size
    }
}
