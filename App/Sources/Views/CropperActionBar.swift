import SwiftUI
import VelloCapture
import VelloCore
import VelloUI

/// Floating controls beneath the capture region: size presets / window label,
/// the record button, and the microphone and cursor toggles.
struct CropperActionBar: View {
    @Bindable var model: CropperModel

    private var settings: VelloCore.Settings { model.settings }

    var body: some View {
        HStack(spacing: 0) {
            leadingControl
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

    // MARK: - Leading

    @ViewBuilder
    private var leadingControl: some View {
        switch model.selectionMode {
        case .region:
            sizeControl
        case .window:
            windowLabel
        }
    }

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

    private var windowLabel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(model.windowSummary)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Text("\(Int(model.selectionPixelSize.width)) × \(Int(model.selectionPixelSize.height)) px")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 168, alignment: .leading)
        .help(model.windowSummary)
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
            cursorMenu
            optionsMenu
        }
    }

    private var microphoneMenu: some View {
        Menu {
            Button {
                settings.recordAudio = false
            } label: {
                if !settings.recordAudio {
                    Label("Off", systemImage: "checkmark")
                } else {
                    Text("Off")
                }
            }

            Divider()

            Button {
                settings.recordAudio = true
                settings.audioInputDeviceID = systemDefaultAudioDeviceID
            } label: {
                if isSelectedMicrophone(systemDefaultAudioDeviceID) {
                    Label("System Default", systemImage: "checkmark")
                } else {
                    Text("System Default")
                }
            }

            ForEach(model.audioInputDevices) { device in
                Button {
                    settings.recordAudio = true
                    settings.audioInputDeviceID = device.id
                } label: {
                    if isSelectedMicrophone(device.id) {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
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

    private func isSelectedMicrophone(_ deviceID: String) -> Bool {
        settings.recordAudio && settings.audioInputDeviceID == deviceID
    }

    private var cursorMenu: some View {
        Menu {
            Button {
                settings.showsCursor.toggle()
            } label: {
                if settings.showsCursor {
                    Label("Show Cursor", systemImage: "checkmark")
                } else {
                    Text("Show Cursor")
                }
            }

            if model.selectionMode == .region {
                Button {
                    settings.highlightClicks.toggle()
                } label: {
                    if settings.highlightClicks {
                        Label("Highlight Clicks", systemImage: "checkmark")
                    } else {
                        Text("Highlight Clicks")
                    }
                }
            }
        } label: {
            Image(systemName: cursorMenuSymbol)
                .font(.system(size: 14))
                .foregroundStyle(settings.showsCursor ? Color.accentColor : .secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(cursorMenuHelp)
    }

    private var cursorMenuSymbol: String {
        if model.selectionMode == .region, settings.highlightClicks {
            return "hand.tap.fill"
        }
        return settings.showsCursor ? "cursorarrow" : "cursorarrow.slash"
    }

    private var cursorMenuHelp: String {
        if model.selectionMode == .region, settings.highlightClicks {
            return "Cursor visible, clicks highlighted"
        }
        return settings.showsCursor
            ? "Cursor is visible in recordings"
            : "Cursor is hidden in recordings"
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
