import SwiftUI
import AppKit
import ServiceManagement
import KnobsKit

/// Calm and small: one rotary knob for the fans, a line of numbers, two switches.
struct PopoverView: View {
    @EnvironmentObject var monitor: MonitorController
    @EnvironmentObject var fan: FanController
    @EnvironmentObject var helper: HelperClient
    @EnvironmentObject var logo: LogoController
    @EnvironmentObject var touch: TouchController
    @EnvironmentObject var updater: Updater

    var body: some View {
        VStack(spacing: 18) {
            header
            FanKnob()
            fanControls
            stats
            Divider().overlay(Color.white.opacity(0.12))
            VStack(spacing: 14) {
                switchRow("apple.logo", "Logo light", logo.isWorking ? "Applying\u{2026}" : (logo.isOn ? "On" : "Off"), isOn: logo.isOn, busy: logo.isWorking) { logo.toggle() }
                if let m = logo.errorMessage { Text(m).font(.system(size: 11)).foregroundStyle(Theme.warm).frame(maxWidth: .infinity, alignment: .leading) }
                switchRow("hand.point.up.left.fill", "Touch input", touch.isEnabled ? "On" : "Off", isOn: touch.isEnabled) { touch.toggle() }
            }
            footer
        }
        .padding(22)
        .frame(width: 320)
        .background(GlassBackground())
        .preferredColorScheme(.dark)
        .onAppear { monitor.start(); fan.startPolling(); touch.refresh(); helper.refresh() }
        .onDisappear { fan.stopPolling() }
    }

    // MARK: header

    private var header: some View {
        let t = monitor.temps.cpu
        let (word, tint): (String, Color) = {
            guard let t else { return ("", .white.opacity(0.6)) }
            return t >= 95 ? ("Hot", Theme.hot) : (t >= 82 ? ("Warm", Theme.warm) : ("Cool", .white.opacity(0.6)))
        }()
        return HStack(alignment: .firstTextBaseline) {
            Text("Knobs").font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            if let t {
                Text("\(Int(t))\u{00B0}  ").font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                + Text(word).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(tint)
            }
        }
    }

    // MARK: fan mode / setup

    @ViewBuilder private var fanControls: some View {
        switch helper.state {
        case .ready:
            VStack(spacing: 8) {
                GlassSegments(items: FanController.Mode.allCases, selection: Binding(get: { fan.mode }, set: { fan.choose($0) }), label: { $0.rawValue })
                if let e = fan.error { Text(e).font(.system(size: 11)).foregroundStyle(Theme.hot) }
            }
        case .needsApproval:
            setup("Allow Knobs in System Settings \u{2192} Login Items", "Open")
        case .notInstalled:
            setup("Fan control needs a one-time approval", "Set up")
        case .unavailable(let why):
            Text(why + " Monitoring still works.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
        }
    }

    private func setup(_ text: String, _ button: String) -> some View {
        VStack(spacing: 8) {
            Text(text).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            GlassButton(title: button, prominent: true) { helper.enable() }
        }
    }

    // MARK: numbers (no bars, no charts)

    private var stats: some View {
        let s = monitor.sample
        func pct(_ v: Double?) -> String { v.map { "\(Int($0 * 100))%" } ?? "\u{2013}" }
        return HStack {
            stat(pct(s.cpuLoad), "CPU")
            stat(pct(s.gpuLoad), "GPU")
            stat(pct(s.memoryUsed), "Memory")
            stat(s.systemPowerWatts.map { "\(Int($0)) W" } ?? (s.batteryLevel.map { "\(Int($0 * 100))%" } ?? "\u{2013}"),
                 s.systemPowerWatts != nil ? "Power" : "Battery")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 16, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(label).font(.system(size: 10.5, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.5))
        }.frame(maxWidth: .infinity)
    }

    // MARK: switches

    private func switchRow(_ icon: String, _ title: String, _ state: String, isOn: Bool, busy: Bool = false, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).frame(width: 22).foregroundStyle(.white.opacity(isOn ? 0.95 : 0.45))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .medium, design: .rounded))
                Text(state).font(.system(size: 11.5, design: .rounded)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            GlassSwitch(isOn: isOn, busy: busy, action: action)
        }
    }

    // MARK: footer

    private var footer: some View {
        HStack {
            switch updater.state {
            case .available(let r):
                Button { Task { await updater.install(r) } } label: {
                    Text("Update to \(r.version)").font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(.white.opacity(0.92))).foregroundStyle(Color(white: 0.1))
                }.buttonStyle(.plain)
            case .working(let step): Text(step).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.6))
            case .failed(let m): Text(m).font(.system(size: 11)).foregroundStyle(Theme.warm).lineLimit(2)
            default: Text("Version \(updater.currentVersion)").font(.system(size: 11.5, design: .rounded)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Menu {
                Button("Check for Updates") { Task { await updater.check() } }
                Toggle("Check automatically", isOn: $updater.autoCheck)
                Toggle("Open at login", isOn: Binding(get: { SMAppService.mainApp.status == .enabled }, set: { on in
                    if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() } }))
                Divider()
                Link("Knobs on GitHub", destination: URL(string: "https://github.com/\(Updater.repo)")!)
                Divider()
                Button("Quit Knobs") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.6)).frame(width: 28, height: 24)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
    }
}

/// The hero: a rotary dial. Auto shows what the fans are doing; grab and turn it to take over.
struct FanKnob: View {
    @EnvironmentObject var fan: FanController
    @EnvironmentObject var helper: HelperClient
    @State private var lastSend = Date.distantPast
    private let size: CGFloat = 176
    private let startDeg = 225.0, sweep = 270.0

    private var fraction: Double {
        switch fan.mode {
        case .manual: return fan.manualFraction
        case .full: return 1
        case .auto:
            let f = fan.fans.map(\.fraction)
            return f.isEmpty ? 0 : f.reduce(0, +) / Double(f.count)
        }
    }
    private var rpm: Int { Int((fan.fans.map(\.actual).max() ?? 0).rounded()) }
    private var interactive: Bool { helper.state == .ready }

    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: sweep / 360).stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(135)).frame(width: size, height: size)
            Circle().trim(from: 0, to: max(0.004, fraction * sweep / 360))
                .stroke(.white.opacity(fan.mode == .auto ? 0.5 : 0.95), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(135)).frame(width: size, height: size)
                .animation(.easeOut(duration: 0.35), value: fraction)
            // knob cap
            Circle().fill(.white.opacity(0.08))
                .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .frame(width: size - 40, height: size - 40)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
            // indicator
            Circle().fill(.white).frame(width: 8, height: 8)
                .offset(y: -(size - 40) / 2 + 14)
                .rotationEffect(.degrees(-135 + fraction * sweep))
                .animation(.easeOut(duration: 0.35), value: fraction)
            VStack(spacing: 0) {
                Text(rpm > 0 ? rpm.formatted() : "\u{2013}").font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("RPM").font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in turn(to: v.location, final: false) }.onEnded { v in turn(to: v.location, final: true) },
                 including: interactive ? .all : .subviews)
        .opacity(interactive || fan.fans.isEmpty == false ? 1 : 0.6)
        .help(interactive ? "Drag to set fan speed" : "Fan speed (monitor only)")
    }

    private func turn(to p: CGPoint, final: Bool) {
        let dx = p.x - size / 2, dy = -(p.y - size / 2)
        guard hypot(dx, dy) > 14 else { return }
        var theta = atan2(dy, dx) * 180 / .pi; if theta < 0 { theta += 360 }
        var delta = startDeg - theta; if delta < 0 { delta += 360 }
        let f: Double = delta <= sweep ? delta / sweep : (delta < sweep + (360 - sweep) / 2 ? 1 : 0)
        fan.manualFraction = f
        if fan.mode != .manual { fan.choose(.manual) }
        if final || Date().timeIntervalSince(lastSend) > 0.3 { lastSend = Date(); fan.commitManual() }
    }
}
