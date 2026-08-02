import AppKit
import SwiftUI
import VelloExport

/// Covers the editor while an export runs, then reports the outcome.
struct ExportProgressView: View {
    @Bindable var job: ExportJob
    @Bindable var model: EditorModel

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThickMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                icon
                Text(headline)
                    .font(.headline)
                Text(job.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if case .exporting = job.status {
                    ProgressView(value: job.status.progress)
                        .frame(width: 240)
                }
                if case let .failed(reason) = job.status {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }

                actions
            }
            .padding(28)
        }
    }

    private var icon: some View {
        Group {
            switch job.status {
            case .pending, .exporting:
                Image(systemName: "square.and.arrow.down")
            case .completed:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            case .cancelled:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 32))
    }

    private var headline: String {
        switch job.status {
        case .pending: "Preparing…"
        case let .exporting(progress): "Exporting \(Int(progress * 100))%"
        case .completed: "Export complete"
        case .failed: "Export failed"
        case .cancelled: "Export cancelled"
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch job.status {
        case .pending, .exporting:
            Button("Cancel") { model.cancelExport() }

        case let .completed(url):
            HStack(spacing: 10) {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                Button("Done") {
                    model.dismissExport()
                    model.onClose?()
                }
                .buttonStyle(.borderedProminent)
            }

        case .failed:
            HStack(spacing: 10) {
                Button("Back") { model.dismissExport() }
                Button("Try Again") {
                    model.dismissExport()
                    model.export()
                }
                .buttonStyle(.borderedProminent)
            }

        case .cancelled:
            Button("Back") { model.dismissExport() }
        }
    }
}
