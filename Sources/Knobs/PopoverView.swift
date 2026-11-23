import SwiftUI
import AppKit

enum Tab: String, CaseIterable, Identifiable {
    case lights = "Lights", fans = "Fans", about = "About"
    var id: String { rawValue }
    var icon: String { switch self { case .lights: "lightbulb.fill"; case .fans: "fan.fill"; case .about: "info.circle.fill" } }
}

struct PopoverView: View {
    @EnvironmentObject var updater: Updater
    @State private var tab: Tab = .lights

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Knobs").font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                if updater.hasUpdate {
                    Button { tab = .about } label: {
                        Label("Update", systemImage: "arrow.down.circle.fill").font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(.green.opacity(0.35)))
                    }.buttonStyle(.plain)
                }
                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                }.buttonStyle(.plain).keyboardShortcut("q").help("Quit Knobs")
            }

            GlassSegments(items: Tab.allCases, selection: $tab, label: { $0.rawValue }, icon: { $0.icon })

            Group {
                switch tab {
                case .lights: LightsView()
                case .fans: FansView()
                case .about: AboutView()
                }
            }
            .transition(.opacity)
        }
        .padding(18)
        .frame(width: 330)
        .background(GlassBackground())
        .preferredColorScheme(.dark)
    }
}
