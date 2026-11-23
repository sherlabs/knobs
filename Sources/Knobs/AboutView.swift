import SwiftUI
import AppKit

struct AboutView: View {
    @EnvironmentObject var updater: Updater

    var body: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(spacing: 8) {
                    if let icon = NSApp.applicationIconImage { Image(nsImage: icon).resizable().frame(width: 56, height: 56) }
                    Text("Knobs").font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Version \(updater.currentVersion)").font(.system(size: 11)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
            }
            GlassCard {
                VStack(spacing: 10) {
                    statusRow
                    Divider().opacity(0.25)
                    HStack {
                        Text("Check automatically").font(.system(size: 12, weight: .medium, design: .rounded))
                        Spacer()
                        GlassSwitch(isOn: updater.autoCheck) { updater.autoCheck.toggle() }
                    }
                }
            }
            HStack(spacing: 14) {
                Link("GitHub", destination: URL(string: "https://github.com/\(Updater.repo)")!)
                Link("sherlabs.com", destination: URL(string: "https://www.sherlabs.com/products/knobs")!)
            }
            .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Text("Open source (MIT). Not affiliated with Apple.").font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private var statusRow: some View {
        switch updater.state {
        case .idle, .upToDate:
            row(updater.state == .upToDate ? "You\u{2019}re up to date" : "Check for updates", systemImage: updater.state == .upToDate ? "checkmark.circle.fill" : "arrow.clockwise") {
                GlassButton(title: "Check") { Task { await updater.check() } }
            }
        case .checking:
            row("Checking\u{2026}", systemImage: "arrow.clockwise") { ProgressView().controlSize(.small) }
        case .available(let r):
            VStack(alignment: .leading, spacing: 8) {
                row("Version \(r.version) is available", systemImage: "arrow.down.circle.fill") {
                    GlassButton(title: "Update", prominent: true) { Task { await updater.install(r) } }
                }
                if !r.notes.isEmpty { Text(r.notes).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(4) }
            }
        case .working(let step):
            row(step, systemImage: "arrow.down.circle") { ProgressView().controlSize(.small) }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                row("Update problem", systemImage: "exclamationmark.triangle.fill") { GlassButton(title: "Retry") { Task { await updater.check() } } }
                Text(message).font(.system(size: 10.5)).foregroundStyle(.red.opacity(0.9))
            }
        }
    }

    private func row<T: View>(_ text: String, systemImage: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack {
            Image(systemName: systemImage).foregroundStyle(.cyan)
            Text(text).font(.system(size: 12, weight: .medium, design: .rounded))
            Spacer()
            trailing()
        }
    }
}
