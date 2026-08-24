import Foundation

/// Scratch space for in-progress recordings and conversions.
///
/// Everything lives under one directory inside the sandbox container so a crash
/// leaves a single place to reclaim on next launch.
public enum TemporaryFiles {
    private static let rootName = "Vello"

    public static var root: URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(rootName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Live captures use a QuickTime working file because AVAssetWriter supports
    /// Vello's separate video, system-audio, and microphone tracks in that
    /// container. The editor still exports the user's chosen final format.
    public static func newRecordingURL(fileExtension: String = "mov") -> URL {
        root.appendingPathComponent("recording-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
    }

    public static func newExportURL(fileExtension: String) -> URL {
        root.appendingPathComponent("export-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
    }

    /// Removes leftovers from previous launches. Files still referenced by the
    /// current session are passed in `keeping` so recovery flows are not clobbered.
    public static func purge(keeping keep: Set<URL> = []) {
        let keepPaths = Set(keep.map(\.standardizedFileURL.path))
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else { return }

        for url in contents where !keepPaths.contains(url.standardizedFileURL.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
