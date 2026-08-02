import SwiftUI
import VelloCapture
import VelloCore
import VelloUI

/// Floating controls beneath the capture region: size presets, the record button,
/// and the microphone and cursor toggles.
struct CropperActionBar: View {
    @Bindable var model: CropperModel

    private var settings: VelloCore.Settings { model.settings }

    var body: some View {
        HStack(spacing: 0) {
            sizeControl
            Spacer(minLength: 12)
            recordButton
            Spacer(minLength: 12)
            trailingControls
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: VelloMetrics.actionBarCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelloMetrics.actionBarCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14))
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
    }

    // MARK: - Size

    private var sizeControl: some View {
        Menu {
            Button("Full Display") { model.selectFullDisplay() }
            Divider()
            ForEach(Self.presets, id: \.label) { preset in
                Button(preset.label) { model.setSelectionSize(preset.size) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(Int(model.selection.width)) × \(Int(model.selection.height))")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                Text("\(Int(model.selectionPixelSize.width)) × \(Int(model.selectionPixelSize.height)) px")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Choose a preset size")
    }

    private static let presets: [(label: String, size: CGSize)] = [
        ("1920 × 1080", CGSize(width: 1920, height: 1080)),
        ("1280 × 720", CGSize(width: 1280, height: 720)),
        ("1080 × 1080", CGSize(width: 1080, height: 1080)),
        ("800 × 600", CGSize(width: 800, height: 600))
    ]

    // MARK: - Record

    private var recordButton: some View {
        Button(action: model.startRecording) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 42, height: 42)
                Circle()
                    .fill(model.hasSelection ? Color.red : Color.gray)
                    .frame(width: 30, height: 30)
            }
        }
        .buttonStyle(.plain)
        .disabled(!model.hasSelection)
        .help("Start recording")
    }

    // MARK: - Trailing

    private var trailingControls: some View {
        HStack(spacing: 6) {
            microphoneMenu
            cursorToggle
            optionsMenu
        }
    }

    private var microphoneMenu: some View {
        Menu {
            Button {
                settings.recordAudio = false
            } label: {
                Label("Off", systemImage: settings.recordAudio ? "" : "checkmark")
            }

            Divider()

            Button {
                settings.recordAudio = true
                settings.audioInputDeviceID = systemDefaultAudioDeviceID
            } label: {
                Text("System Default")
            }

            ForEach(model.audioInputDevices) { device in
                Button {
                    settings.recordAudio = true
                    settings.audioInputDeviceID = device.id
                } label: {
                    Text(device.name)
                }
            }
        } label: {
            Image(systemName: settings.recordAudio ? "mic.fill" : "mic.slash")
                .font(.system(size: 14))
                .foregroundStyle(settings.recordAudio ? Color.accentColor : .secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Microphone: \(model.microphoneSummary)")
    }

    private var cursorToggle: some View {
        Button {
            settings.showsCursor.toggle()
        } label: {
            Image(systemName: settings.showsCursor ? "cursorarrow" : "cursorarrow.slash")
                .font(.system(size: 14))
                .foregroundStyle(settings.showsCursor ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(settings.showsCursor ? "Cursor is visible in recordings" : "Cursor is hidden in recordings")
    }

    private var optionsMenu: some View {
        Menu {
            Picker("Frame Rate", selection: Binding(
                get: { settings.recordingFrameRate },
                set: { settings.recordingFrameRate = $0 }
            )) {
                Text("30 fps").tag(30)
                Text("60 fps").tag(60)
            }
            Divider()
            Button("Preferences…") { model.onOpenPreferences?() }
            Button("Cancel") { model.onCancel?() }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More options")
    }
}
