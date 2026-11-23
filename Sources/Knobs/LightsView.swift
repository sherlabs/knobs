import SwiftUI

struct LightsView: View {
    @EnvironmentObject var logo: LogoController
    @EnvironmentObject var touch: TouchController

    var body: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(RadialGradient(colors: [Color.white.opacity(logo.isOn ? 0.55 : 0), .clear],
                                                     center: .center, startRadius: 2, endRadius: 60))
                            .frame(width: 120, height: 120).blur(radius: 6)
                        Circle().fill(.ultraThinMaterial)
                            .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.05)],
                                                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                            .frame(width: 64, height: 64).shadow(color: .black.opacity(0.25), radius: 10, y: 5)
                        Image(systemName: "apple.logo").font(.system(size: 27))
                            .foregroundStyle(logo.isOn ? Color.white : Color.white.opacity(0.35))
                            .shadow(color: .white.opacity(logo.isOn ? 0.9 : 0), radius: 9)
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: logo.isOn)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Logo light").font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text(logo.isWorking ? "Applying\u{2026}" : (logo.isOn ? "Illuminated" : "Off"))
                                .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        GlassSwitch(isOn: logo.isOn, busy: logo.isWorking, large: true) { logo.toggle() }
                    }
                    if let message = logo.errorMessage {
                        Text(message).font(.system(size: 11)).foregroundStyle(.red.opacity(0.9)).lineLimit(3)
                    }
                }
            }

            GlassCard {
                HStack(spacing: 10) {
                    Image(systemName: "hand.point.up.left.fill").font(.system(size: 15))
                        .foregroundStyle(touch.isEnabled ? Color.white : Color.white.opacity(0.35)).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Touch input").font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(touch.isEnabled ? "Enabled" : "Disabled").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    GlassSwitch(isOn: touch.isEnabled) { touch.toggle() }
                }
            }
            .onAppear { touch.refresh() }
        }
    }
}
