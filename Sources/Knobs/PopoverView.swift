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
        VStack(spacing: 22) {
            header
            FanKnob()
            fanControls
            stats
            group
            footer
        }
        .padding(.horizontal, 24).padding(.vertical, 22)
        .frame(width: 328)
        .background(GlassBackground())
        .preferredColorScheme(.dark)
        .onAppear { monitor.start(); fan.startPolling(); touch.refresh(); helper.refresh() }
        .onDisappear { fan.stopPolling() }
    }

    // MARK: header

    private var header: some View {
        let t = monitor.temps.cpu
        let (word, dot): (String, Color) = {
            guard let t else { return ("", .white.opacity(0.4)) }
            return t >= 95 ? ("Hot", Theme.hot) : (t >= 82 ? ("Warm", Theme.warm) : ("Cool", Color(white: 0.85)))
        }()
        return HStack {
            Text("Knobs").font(.system(size: 13, weight: .semibold)).tracking(0.3).foregroundStyle(.white.opacity(0.9))
            Spacer()
            if let t {
                HStack(spacing: 6) {
                    Circle().fill(dot).frame(width: 6, height: 6)
                    Text("\(Int(t))\u{00B0} \(word)").font(.system(size: 11.5, weight: .medium)).monospacedDigit().foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
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
        let power = s.systemPowerWatts.map { "\(Int($0)) W" } ?? (s.batteryLevel.map { "\(Int($0 * 100))%" } ?? "\u{2013}")
        return HStack(spacing: 0) {
            stat(pct(s.cpuLoad), "CPU")
            hairline
            stat(pct(s.gpuLoad), "GPU")
            hairline
            stat(pct(s.memoryUsed), "MEMORY")
            hairline
            stat(power, s.systemPowerWatts != nil ? "POWER" : "BATTERY")
        }
    }

    private var hairline: some View { Rectangle().fill(.white.opacity(0.10)).frame(width: 0.5, height: 26) }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .light)).monospacedDigit().numericFlip()
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(0.9).foregroundStyle(.white.opacity(0.42))
        }.frame(maxWidth: .infinity)
    }

    // MARK: switches (one grouped glass list)

    private var group: some View {
        VStack(spacing: 0) {
            switchRow("apple.logo", "Logo light", logo.isWorking ? "Applying\u{2026}" : (logo.isOn ? "On" : "Off"), isOn: logo.isOn, busy: logo.isWorking) { logo.toggle() }
            Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5).padding(.leading, 56)
            switchRow("hand.point.up.left.fill", "Touch input", touch.isEnabled ? "On" : "Off", isOn: touch.isEnabled) { touch.toggle() }
            if let m = logo.errorMessage {
                Text(m).font(.system(size: 11)).foregroundStyle(Theme.warm).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.bottom, 10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
    }

    private func switchRow(_ icon: String, _ title: String, _ state: String, isOn: Bool, busy: Bool = false, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(isOn ? 0.95 : 0.5))
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(isOn ? 0.14 : 0.07)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                Text(state).font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            GlassSwitch(isOn: isOn, busy: busy, action: action)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: footer

    private var footer: some View {
        HStack {
            switch updater.state {
            case .available(let r):
                Button { Task { await updater.install(r) } } label: {
                    Text("Update to \(r.version)").font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(.white.opacity(0.92))).foregroundStyle(Color(white: 0.1))
                }.buttonStyle(.plain)
            case .working(let step): Text(step).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            case .failed(let m): Text(m).font(.system(size: 11)).foregroundStyle(Theme.warm).lineLimit(2)
            default: Text("Version \(updater.currentVersion)").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.4))
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
    @State private var pressed = false
    private let size: CGFloat = 196
    private let startDeg = 225.0, sweep = 270.0
    private let ticks = 61

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
    private var capSize: CGFloat { size - 62 }

    var body: some View {
        ZStack {
            // soft halo behind the dial while the user is in control
            Circle().fill(.white.opacity(fan.mode == .auto ? 0.0 : 0.10)).blur(radius: 26).frame(width: capSize, height: capSize)
                .animation(.easeOut(duration: 0.4), value: fan.mode)

            // machined tick ring
            Canvas { ctx, sz in
                let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let outer = sz.width / 2 - 2
                for i in 0..<ticks {
                    let t = Double(i) / Double(ticks - 1)
                    let a = (startDeg - sweep * t) * .pi / 180
                    let major = i % 10 == 0
                    let len: CGFloat = major ? 11 : 7
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + cos(a) * (outer - len), y: c.y - sin(a) * (outer - len)))
                    p.addLine(to: CGPoint(x: c.x + cos(a) * outer, y: c.y - sin(a) * outer))
                    let lit = t <= fraction + 0.0001
                    let alpha = lit ? (fan.mode == .auto ? 0.55 : 0.98) : 0.14
                    ctx.stroke(p, with: .color(.white.opacity(alpha)), style: StrokeStyle(lineWidth: major ? 2 : 1.4, lineCap: .round))
                }
            }
            .frame(width: size, height: size)
            .animation(.easeOut(duration: 0.3), value: fraction)

            // cap: dark glass with a faint machined sheen
            Circle().fill(Color.black.opacity(0.28))
                .overlay(Circle().fill(AngularGradient(colors: [.white.opacity(0.16), .white.opacity(0.02), .white.opacity(0.12), .white.opacity(0.02), .white.opacity(0.16)], center: .center)))
                .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.40), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .frame(width: capSize, height: capSize)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                .scaleEffect(pressed ? 0.985 : 1)

            // notch
            Capsule().fill(.white).frame(width: 3, height: 13)
                .offset(y: -capSize / 2 + 12)
                .rotationEffect(.degrees(-135 + fraction * sweep))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: fraction)

            VStack(spacing: 2) {
                Text(rpm > 0 ? rpm.formatted() : "\u{2013}").font(.system(size: 34, weight: .thin)).monospacedDigit().numericFlip()
                Text("RPM").font(.system(size: 9.5, weight: .semibold)).tracking(1.2).foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in pressed = true; turn(to: v.location, final: false) }
            .onEnded { v in pressed = false; turn(to: v.location, final: true) },
                 including: interactive ? .all : .subviews)
        .help(interactive ? "Drag to set fan speed" : "Fan speed (monitor only)")
    }

    private func turn(to p: CGPoint, final: Bool) {
        let dx = p.x - size / 2, dy = -(p.y - size / 2)
        guard hypot(dx, dy) > 16 else { return }
        var theta = atan2(dy, dx) * 180 / .pi; if theta < 0 { theta += 360 }
        var delta = startDeg - theta; if delta < 0 { delta += 360 }
        let f: Double = delta <= sweep ? delta / sweep : (delta < sweep + (360 - sweep) / 2 ? 1 : 0)
        fan.manualFraction = f
        if fan.mode != .manual { fan.choose(.manual) }
        if final || Date().timeIntervalSince(lastSend) > 0.3 { lastSend = Date(); fan.commitManual() }
    }
}

private extension View {
    /// Digits roll instead of snapping (macOS 14+); a no-op on 13.
    @ViewBuilder func numericFlip() -> some View {
        if #available(macOS 14.0, *) { self.contentTransition(.numericText()) } else { self }
    }
}
