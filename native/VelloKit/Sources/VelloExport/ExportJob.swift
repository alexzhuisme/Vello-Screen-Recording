import Foundation
import Observation
import VelloCore

/// A single export from a recording to a file the user chose, with observable progress.
///
/// Encoding always targets a temporary file first so a failure or cancellation
/// never leaves a truncated file where the user expects a finished one.
@MainActor
@Observable
public final class ExportJob: Identifiable {
    public enum Status: Equatable, Sendable {
        case pending
        case exporting(Double)
        case completed(URL)
        case failed(String)
        case cancelled

        public var isFinished: Bool {
            switch self {
            case .completed, .failed, .cancelled: true
            case .pending, .exporting: false
            }
        }

        public var progress: Double {
            switch self {
            case .pending: 0
            case let .exporting(value): value
            case .completed: 1
            case .failed, .cancelled: 0
            }
        }
    }

    public let id = UUID()
    public let sourceURL: URL
    public let destinationURL: URL
    public let options: ExportOptions
    public let createdAt = Date()

    public private(set) var status: Status = .pending

    /// Folder the destination lives in. Sandboxed writes need its security scope held open.
    @ObservationIgnored private let accessScope: URL?
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(source: URL, destination: URL, options: ExportOptions, accessScope: URL? = nil) {
        sourceURL = source
        destinationURL = destination
        self.options = options
        self.accessScope = accessScope
    }

    public var fileName: String { destinationURL.lastPathComponent }

    public func start() {
        guard task == nil else { return }
        status = .exporting(0)

        let source = sourceURL
        let destination = destinationURL
        let options = self.options
        let accessScope = self.accessScope

        let onProgress: @Sendable (Double) -> Void = { [weak self] value in
            Task { @MainActor in
                guard let self, case .exporting = self.status else { return }
                self.status = .exporting(min(max(value, 0), 1))
            }
        }

        task = Task { [weak self] in
            let temporaryURL = TemporaryFiles.newExportURL(fileExtension: options.format.fileExtension)

            do {
                try await Exporter.export(
                    source: source,
                    to: temporaryURL,
                    options: options,
                    onProgress: onProgress
                )
                try Task.checkCancellation()
                try Self.install(temporaryURL, at: destination, accessScope: accessScope)

                await MainActor.run { [weak self] in
                    self?.status = .completed(destination)
                }
            } catch {
                try? FileManager.default.removeItem(at: temporaryURL)
                let isCancellation = error is CancellationError
                    || (error as? ExportError) == .cancelled
                await MainActor.run { [weak self] in
                    self?.status = isCancellation
                        ? .cancelled
                        : .failed(error.localizedDescription)
                }
            }
        }
    }

    public func cancel() {
        guard !status.isFinished else { return }
        task?.cancel()
        status = .cancelled
    }

    private static func install(_ temporaryURL: URL, at destination: URL, accessScope: URL?) throws {
        let move = {
            if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
        }

        if let accessScope {
            try SecurityScopedBookmark.withAccess(to: accessScope, perform: move)
        } else {
            try move()
        }
    }
}
