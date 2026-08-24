import SwiftUI
import VelloCapture
import VelloCore

struct PreferencesView: View {
    // Qualified because SwiftUI declares a `Settings` scene type as well.
    @Bindable var settings: VelloCore.Settings

    @State private var audioDevices: [AudioInputDevice] = []
    @State private var videoDevices: [VideoInputDevice] = []
    @State private var launchesAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Recording") {
                Toggle("Show cursor", isOn: $settings.showsCursor)

                Toggle("Highlight clicks", isOn: $settings.highlightClicks)
                    .help("Draws an expanding ring under each mouse click in the recording.")

                Picker("Frame rate", selection: $settings.recordingFrameRate) {
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }

                Picker("Countdown", selection: $settings.recordingCountdown) {
                    ForEach(RecordingCountdown.allCases) { countdown in
                        Text(countdown.displayName).tag(countdown)
                    }
                }

                Picker("Audio", selection: $settings.audioCaptureMode) {
                    ForEach(AudioCaptureMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Picker("Input device", selection: audioDeviceBinding) {
                    Text("System Default").tag(systemDefaultAudioDeviceID)
                    ForEach(audioDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .disabled(!settings.audioCaptureMode.includesMicrophone)

                Divider()

                Toggle("Include webcam bubble", isOn: $settings.webcamEnabled)

                Picker("Camera", selection: videoDeviceBinding) {
                    ForEach(videoDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .disabled(!settings.webcamEnabled || videoDevices.isEmpty)

                Picker("Webcam position", selection: $settings.webcamPosition) {
                    ForEach(WebcamPosition.allCases) { position in
                        Text(position.displayName).tag(position)
                    }
                }
                .disabled(!settings.webcamEnabled)

                if settings.webcamEnabled, settings.webcamPosition == .custom {
                    Text("Drag the webcam bubble inside the capture area to place it anywhere.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Webcam size", selection: $settings.webcamSize) {
                    ForEach(WebcamSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .disabled(!settings.webcamEnabled)
            }

            Section("Exports") {
                Picker("Default format", selection: $settings.defaultExportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }

                Toggle("Loop GIF and APNG exports", isOn: $settings.loopAnimatedExports)

                LabeledContent("Save to") {
                    HStack(spacing: 8) {
                        Text(settings.saveDirectoryDisplayName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") { SaveDestination.chooseFolder(settings: settings) }
                        if settings.saveDirectoryBookmark != nil || settings.asksForSaveLocation {
                            Button("Reset") { SaveDestination.useDownloadsFolder(settings: settings) }
                        }
                    }
                }
            }

            Section("Shortcut") {
                Toggle("Enable global shortcut", isOn: $settings.enableShortcuts)

                Picker("Toggle Vello", selection: shortcutBinding) {
                    ForEach(Self.shortcutPresets, id: \.keyCode) { preset in
                        Text(preset.combo.displayString).tag(preset.keyCode)
                    }
                }
                .disabled(!settings.enableShortcuts)
            }

            Section("General") {
                Toggle("Launch Vello at login", isOn: $launchesAtLogin)
                    .onChange(of: launchesAtLogin) { _, newValue in
                        LaunchAtLogin.setEnabled(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            audioDevices = CaptureDevices.audioInputDevices()
            videoDevices = CaptureDevices.videoInputDevices()
            if settings.webcamDeviceID == nil {
                settings.webcamDeviceID = CaptureDevices.defaultVideoInputDevice()?.id
            }
            launchesAtLogin = LaunchAtLogin.isEnabled
        }
    }

    private var audioDeviceBinding: Binding<String> {
        Binding(
            get: { settings.audioInputDeviceID ?? systemDefaultAudioDeviceID },
            set: { settings.audioInputDeviceID = $0 }
        )
    }

    private var videoDeviceBinding: Binding<String> {
        Binding(
            get: { settings.webcamDeviceID ?? videoDevices.first?.id ?? "" },
            set: { settings.webcamDeviceID = $0 }
        )
    }

    /// Offers the same fixed choices Kap did, which avoids building a key recorder
    /// while still covering the shortcuts people expect.
    private static let shortcutPresets: [(keyCode: UInt16, combo: HotKeyCombo)] = [
        (0x14, HotKeyCombo(keyCode: 0x14, modifierFlags: HotKeyCombo.commandFlag | HotKeyCombo.shiftFlag)),
        (0x15, HotKeyCombo(keyCode: 0x15, modifierFlags: HotKeyCombo.commandFlag | HotKeyCombo.shiftFlag)),
        (0x17, HotKeyCombo(keyCode: 0x17, modifierFlags: HotKeyCombo.commandFlag | HotKeyCombo.shiftFlag)),
        (0x16, HotKeyCombo(keyCode: 0x16, modifierFlags: HotKeyCombo.commandFlag | HotKeyCombo.shiftFlag))
    ]

    private var shortcutBinding: Binding<UInt16> {
        Binding(
            get: { settings.toggleCropperShortcut?.keyCode ?? HotKeyCombo.defaultToggleCropper.keyCode },
            set: { keyCode in
                settings.toggleCropperShortcut = Self.shortcutPresets
                    .first { $0.keyCode == keyCode }?.combo
            }
        )
    }
}
