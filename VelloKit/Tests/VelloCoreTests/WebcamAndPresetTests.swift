import Foundation
import Testing
@testable import VelloCore

@Suite("Webcam configuration")
struct WebcamConfigurationTests {
    @Test("Bubble sizes grow and stay inside every corner")
    func laysOutBubble() {
        let canvas = CGSize(width: 1_280, height: 720)
        let small = WebcamSize.small.frame(in: canvas, position: .topLeft)
        let medium = WebcamSize.medium.frame(in: canvas, position: .topLeft)
        let large = WebcamSize.large.frame(in: canvas, position: .topLeft)

        #expect(small.width < medium.width)
        #expect(medium.width < large.width)

        for position in WebcamPosition.allCases {
            let frame = WebcamSize.medium.frame(in: canvas, position: position)
            #expect(CGRect(origin: .zero, size: canvas).contains(frame))
            #expect(frame.width == frame.height)
        }
    }

    @Test("Tiny recordings still receive a usable in-bounds bubble")
    func clampsTinyCanvas() {
        let canvas = CGSize(width: 96, height: 96)
        let frame = WebcamSize.large.frame(in: canvas, position: .bottomRight)

        #expect(frame.width >= 24)
        #expect(CGRect(origin: .zero, size: canvas).contains(frame))
    }

    @Test("Custom positions remain constrained and resolution independent")
    func laysOutCustomPosition() {
        let canvas = CGSize(width: 1_280, height: 720)
        let proposed = CGPoint(x: 560, y: 310)
        let placement = WebcamSize.medium.placement(
            forPreviewCenter: proposed,
            in: canvas,
            snappingThreshold: 18
        )

        #expect(placement.position == .custom)
        let preview = WebcamSize.medium.previewFrame(
            in: canvas,
            position: placement.position,
            customPosition: placement.customPosition
        )
        #expect(CGRect(origin: .zero, size: canvas).contains(preview))
        #expect(abs(preview.midX - proposed.x) < 0.001)
        #expect(abs(preview.midY - proposed.y) < 0.001)

        let output = WebcamSize.medium.frame(
            in: canvas,
            position: placement.position,
            customPosition: placement.customPosition
        )
        #expect(abs(output.midY - (canvas.height - preview.midY)) < 0.001)
    }

    @Test("Dragging near a corner snaps to its preset")
    func snapsToCorner() {
        let canvas = CGSize(width: 1_280, height: 720)
        let topRight = WebcamSize.medium.previewFrame(in: canvas, position: .topRight)
        let placement = WebcamSize.medium.placement(
            forPreviewCenter: CGPoint(x: topRight.midX - 8, y: topRight.midY + 8),
            in: canvas,
            snappingThreshold: 18
        )

        #expect(placement.position == .topRight)
    }

    @Test("Dragging a custom bubble applies the pointer translation")
    func movesCustomPositionByTranslation() {
        let canvas = CGSize(width: 1_280, height: 720)
        let initial = WebcamCustomPosition(x: 0.5, y: 0.5)
        let startFrame = WebcamSize.medium.previewFrame(
            in: canvas,
            position: .custom,
            customPosition: initial
        )
        let translation = CGSize(width: -180, height: 95)
        let expectedCenter = CGPoint(
            x: startFrame.midX + translation.width,
            y: startFrame.midY + translation.height
        )

        let placement = WebcamSize.medium.placement(
            forPreviewCenter: expectedCenter,
            in: canvas,
            snappingThreshold: 18
        )
        let movedFrame = WebcamSize.medium.previewFrame(
            in: canvas,
            position: placement.position,
            customPosition: placement.customPosition
        )

        #expect(placement.position == .custom)
        #expect(abs(movedFrame.midX - expectedCenter.x) < 0.001)
        #expect(abs(movedFrame.midY - expectedCenter.y) < 0.001)
    }
}

@MainActor
@Suite("Export presets and webcam settings")
struct ExportPresetSettingsTests {
    @Test("Custom presets, webcam choices, and permission setup state persist")
    func persistsSettings() throws {
        let suiteName = "VelloCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preset = ExportPreset(
            name: "Compact MP4",
            format: .mp4,
            scalePercent: 50,
            frameRate: 30,
            isMuted: true
        )
        let settings = Settings(defaults: defaults)
        settings.exportPresets = [preset]
        settings.webcamEnabled = true
        settings.webcamDeviceID = "camera-id"
        settings.webcamPosition = .custom
        settings.webcamCustomPosition = WebcamCustomPosition(x: 0.42, y: 0.31)
        settings.webcamSize = .large
        #expect(!settings.didShowInitialPermissionSetup)
        settings.didShowInitialPermissionSetup = true

        let restored = Settings(defaults: defaults)
        #expect(restored.exportPresets == [preset])
        #expect(restored.webcamEnabled)
        #expect(restored.webcamDeviceID == "camera-id")
        #expect(restored.webcamPosition == .custom)
        #expect(restored.webcamCustomPosition == WebcamCustomPosition(x: 0.42, y: 0.31))
        #expect(restored.webcamSize == .large)
        #expect(restored.didShowInitialPermissionSetup)
    }
}
