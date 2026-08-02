import AppKit
import SwiftUI
import VelloCore
import VelloExport
import VelloUI

struct EditorView: View {
    @Bindable var model: EditorModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                videoArea
                Divider()
                playbackBar
                Divider()
                optionsBar
            }

            if let job = model.exportJob {
                ExportProgressView(job: job, model: model)
                    .transition(.opacity)
            }
        }
        .frame(
            minWidth: VelloMetrics.editorMinimumSize.width,
            minHeight: VelloMetrics.editorMinimumSize.height
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.15), value: model.exportJob == nil)
        .task { await model.load() }
    }

    // MARK: - Video

    private var videoArea: some View {
        ZStack {
            Color.black
            PlayerView(player: model.player)
                .onTapGesture { model.togglePlayback() }

            if let loadError = model.loadError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                    Text(loadError)
                        .multilineTextAlignment(.center)
                        .font(.callout)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding()
            } else if !model.isLoaded {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Playback

    private var playbackBar: some View {
        HStack(spacing: 12) {
            Button(action: model.togglePlayback) {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .frame(width: 20)
            }
            .buttonStyle(.plain)
            .disabled(!model.isLoaded)
            .help(model.isPlaying ? "Pause" : "Play")

            Text(formatDuration(model.currentTime))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            TrimBar(model: model)

            Text(formatDuration(model.trimmedDuration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)

            Button(action: model.toggleMute) {
                Image(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
            .disabled(!model.supportsAudio)
            .help(model.supportsAudio ? (model.isMuted ? "Unmute" : "Mute") : "This recording has no audio")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Options

    private var optionsBar: some View {
        HStack(spacing: 10) {
            Picker("", selection: $model.scalePercent) {
                ForEach(EditorModel.scaleOptions, id: \.self) { percent in
                    Text("\(percent)%").tag(percent)
                }
            }
            .labelsHidden()
            .frame(width: 78)
            .help("Output scale")

            Picker("", selection: $model.frameRate) {
                Text("30 fps").tag(30)
                Text("60 fps").tag(60)
            }
            .labelsHidden()
            .frame(width: 88)
            .help("Output frame rate")

            Text("\(Int(model.exportSize.width)) × \(Int(model.exportSize.height))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            Picker("", selection: $model.format) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .labelsHidden()
            .frame(width: 84)
            .help("Output format")

            saveLocationMenu

            Button("Discard", role: .destructive) {
                model.discardRecording()
                model.onClose?()
            }

            Button("Export") { model.export() }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canExport)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var saveLocationMenu: some View {
        Menu {
            Button("Choose Folder…") { SaveDestination.chooseFolder(settings: model.settings) }
            Button("Ask Every Time") { SaveDestination.forgetFolder(settings: model.settings) }
        } label: {
            Label(model.settings.saveDirectoryDisplayName, systemImage: "folder")
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Where exports are saved")
    }
}
