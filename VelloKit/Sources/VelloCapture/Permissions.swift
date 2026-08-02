import AVFoundation
import AppKit
import CoreGraphics
import ScreenCaptureKit
import VelloCore

public enum PermissionStatus: Sendable, Equatable {
    case granted
    case denied
    case notDetermined
}

public enum Permissions {
    // MARK: - Screen recording

    /// Fast, non-prompting check. Can lag behind System Settings for Debug builds.
    public static var hasScreenRecordingAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Authoritative check: ask ScreenCaptureKit itself. Prefer this over
    /// `CGPreflightScreenCaptureAccess`, which often stays false for Xcode
    /// Debug binaries even after the Screen Recording toggle is On.
    public static func verifyScreenRecordingAccess() async -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            return true
        } catch {
            return false
        }
    }

    /// Triggers the system prompt the first time it is called for this app.
    /// Subsequent calls just report the stored decision.
    @discardableResult
    public static func requestScreenRecordingAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    // MARK: - Microphone

    public static var microphoneStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }

    public static func requestMicrophoneAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Settings deep links

    public static func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    public static func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    private static func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
