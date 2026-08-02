import AppKit
import UniformTypeIdentifiers
import VelloCore

/// Works out where an export should be written.
///
/// In the sandbox, writing anywhere outside the container needs either a
/// security-scoped bookmark for a remembered folder or a fresh save panel, which
/// grants access to the specific file the user picked.
@MainActor
enum SaveDestination {
    struct Resolution {
        let url: URL
        /// Folder whose security scope must be held while writing, if any.
        let accessScope: URL?
    }

    static func resolve(settings: Settings, fileName: String, format: ExportFormat) -> Resolution? {
        let suggestedName = "\(fileName).\(format.fileExtension)"

        if let folder = settings.resolveSaveDirectory() {
            return Resolution(
                url: folder.appendingPathComponent(suggestedName),
                accessScope: folder
            )
        }

        return promptForLocation(settings: settings, suggestedName: suggestedName, format: format)
    }

    /// Always asks, and remembers the chosen folder for next time.
    static func promptForLocation(
        settings: Settings,
        suggestedName: String,
        format: ExportFormat
    ) -> Resolution? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Save Recording"
        panel.prompt = "Save"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let folder = url.deletingLastPathComponent()
        try? settings.rememberSaveDirectory(folder)

        // The panel itself granted access to this path, so no scope is needed.
        return Resolution(url: url, accessScope: nil)
    }

    /// Lets the user pick the folder future exports land in without exporting now.
    static func chooseFolder(settings: Settings) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Choose where recordings are saved"
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? settings.rememberSaveDirectory(url)
    }

    static func forgetFolder(settings: Settings) {
        settings.saveDirectoryBookmark = nil
        settings.saveDirectoryPath = nil
    }
}
