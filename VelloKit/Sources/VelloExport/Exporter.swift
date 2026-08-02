import Foundation
import VelloCore

public enum Exporter {
    /// Routes to the encoder that can produce `options.format`.
    public static func export(
        source: URL,
        to destination: URL,
        options: ExportOptions,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        switch options.format {
        case .mp4, .hevc:
            try await VideoExporter.export(
                source: source,
                to: destination,
                options: options,
                onProgress: onProgress
            )
        case .gif, .apng:
            try await AnimatedImageExporter.export(
                source: source,
                to: destination,
                options: options,
                onProgress: onProgress
            )
        }
    }
}
