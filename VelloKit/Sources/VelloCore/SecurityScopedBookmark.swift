import Foundation

/// Sandboxed builds can only reach user-chosen folders across launches by way of
/// security-scoped bookmarks, so every persisted destination round-trips through here.
public enum SecurityScopedBookmark {
    public static func create(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public static func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }

    /// Runs `body` with the security scope held open, releasing it even on throw.
    public static func withAccess<T>(to url: URL, perform body: () throws -> T) rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        return try body()
    }

    public static func withAccess<T>(to url: URL, perform body: () async throws -> T) async rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        return try await body()
    }
}
