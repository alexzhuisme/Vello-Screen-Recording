import AppKit
import SwiftUI

struct PermissionSetupView: View {
    let onContinue: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PermissionHeroIllustration()
                .frame(height: 190)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Let’s get Vello ready")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Three quick permissions unlock screen capture, narration, and the optional webcam.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    PermissionStepRow(
                        number: 1,
                        symbol: "mic.fill",
                        color: Color(red: 0.38, green: 0.42, blue: 0.96),
                        title: "Microphone",
                        detail: "Record your voice and selected input"
                    )
                    PermissionStepRow(
                        number: 2,
                        symbol: "video.fill",
                        color: Color(red: 0.18, green: 0.68, blue: 0.82),
                        title: "Camera",
                        detail: "Add the optional webcam bubble"
                    )
                    PermissionStepRow(
                        number: 3,
                        symbol: "macwindow",
                        color: Color(red: 0.16, green: 0.52, blue: 0.98),
                        title: "Screen Recording",
                        detail: "Capture the screen or window you choose"
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("You can change access anytime in System Settings.")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12, weight: .medium))

                HStack(spacing: 18) {
                    Button("Not Now", action: onNotNow)
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .keyboardShortcut(.cancelAction)

                    Button(action: onContinue) {
                        HStack(spacing: 8) {
                            Text("Set Up Permissions")
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PermissionPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 26)
        }
        .frame(width: 560)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(width: 240, height: 240)
                        .blur(radius: 40)
                        .offset(x: 90, y: 100)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.secondary.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct PermissionHeroIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.47, blue: 0.98),
                            Color(red: 0.31, green: 0.76, blue: 0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.20))
                .frame(width: 170, height: 170)
                .blur(radius: 12)
                .offset(x: 190, y: -82)

            Circle()
                .fill(Color(red: 0.39, green: 0.30, blue: 0.96).opacity(0.25))
                .frame(width: 150, height: 150)
                .blur(radius: 18)
                .offset(x: -205, y: 82)

            RecordingCanvas()

            PermissionOrb(symbol: "mic.fill")
                .offset(x: -182, y: 50)
            PermissionOrb(symbol: "video.fill")
                .offset(x: 182, y: 36)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .accessibilityHidden(true)
    }
}

private struct RecordingCanvas: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(.white.opacity(0.50)).frame(width: 5, height: 5)
                Circle().fill(.white.opacity(0.35)).frame(width: 5, height: 5)
                Circle().fill(.white.opacity(0.25)).frame(width: 5, height: 5)
                Spacer()
                Text("VELLO")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .frame(height: 25)

            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    .white.opacity(0.72),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .overlay {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(width: 270, height: 130)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.20), radius: 24, y: 12)
    }
}

private struct PermissionOrb: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle().strokeBorder(.white.opacity(0.40), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 7)
    }
}

private struct PermissionStepRow: View {
    let number: Int
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(.secondary.opacity(0.10), in: Circle())

            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: color.opacity(0.24), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.secondary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct PermissionPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 42)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.17, green: 0.48, blue: 0.98),
                        Color(red: 0.22, green: 0.65, blue: 0.96)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .shadow(color: Color.blue.opacity(configuration.isPressed ? 0.12 : 0.24), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
