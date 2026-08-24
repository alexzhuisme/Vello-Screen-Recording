import Foundation

public struct ExportPreset: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    public var name: String
    public var format: ExportFormat
    public var scalePercent: Int
    public var frameRate: Int
    public var isMuted: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        format: ExportFormat,
        scalePercent: Int,
        frameRate: Int,
        isMuted: Bool
    ) {
        self.id = id
        self.name = name
        self.format = format
        self.scalePercent = scalePercent
        self.frameRate = frameRate
        self.isMuted = isMuted
    }

    public var summary: String {
        "\(format.displayName) · \(scalePercent)% · \(frameRate) fps"
    }
}
