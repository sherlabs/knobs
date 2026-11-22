import SwiftUI
import AppKit

struct PopoverView: View {
    @EnvironmentObject var logo: LogoController
    @EnvironmentObject var touch: TouchController

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                // Soft glow behind the logo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(logo.isOn ? 0.55 : 0.0), .clear],
                            center: .center, startRadius: 2, endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .blur(radius: 8)

                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
                    .frame(width: 76, height: 76)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)

                Image(systemName: "apple.logo")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(logo.isOn ? Color.white : Color.white.opacity(0.35))
                    .shadow(color: .white.opacity(logo.isOn ? 0.9 : 0), radius: 10)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: logo.isOn)
            .padding(.top, 6)

            VStack(spacing: 3) {
                Text("Logo Light")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(statusText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }

            GlassToggle(isOn: logo.isOn, isBusy: logo.isWorking) { logo.toggle() }

            if let message = logo.errorMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Divider().opacity(0.3)

            HStack(spacing: 10) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(touch.isEnabled ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Touch Input")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(touch.isEnabled ? "Enabled" : "Disabled")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                MiniGlassSwitch(isOn: touch.isEnabled) { touch.toggle() }
            }
            .onAppear { touch.refresh() }

            Divider().opacity(0.3)

            HStack {
                Text("Logo light needs admin approval")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("q")
            }
        }
        .padding(20)
        .frame(width: 250)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color.indigo.opacity(0.35), Color.purple.opacity(0.2), Color.cyan.opacity(0.25)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
    }

    private var statusText: String {
        if logo.isWorking { return "Applying…" }
        return logo.isOn ? "Illuminated" : "Off"
    }
}

/// Capsule glass switch.
struct GlassToggle: View {
    let isOn: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule().fill(
                            LinearGradient(colors: isOn
                                           ? [Color.cyan.opacity(0.55), Color.blue.opacity(0.45)]
                                           : [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                                           startPoint: .leading, endPoint: .trailing))
                    )
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .overlay {
                        if isBusy { ProgressView().controlSize(.small) }
                    }
                    .padding(4)
                    .frame(width: 44, height: 44)
            }
            .frame(width: 96, height: 44)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isOn)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

/// Compact capsule switch for secondary settings.
struct MiniGlassSwitch: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule().fill(
                            LinearGradient(colors: isOn
                                           ? [Color.cyan.opacity(0.55), Color.blue.opacity(0.45)]
                                           : [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                                           startPoint: .leading, endPoint: .trailing))
                    )
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .padding(3)
                    .frame(width: 28, height: 28)
            }
            .frame(width: 52, height: 28)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
        }
        .buttonStyle(.plain)
    }
}
