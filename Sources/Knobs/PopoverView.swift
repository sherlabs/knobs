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
        VStack(spacing: 14) {
            header
            FanKnob()
            fanControls
            stats
            group
            footer
        }
        .padding(16)
        .frame(width: 320)
        .background(VisualEffect())
        .onAppear { monitor.start(); fan.startPolling(); touch.refresh(); helper.refresh() }
        .onDisappear { fan.stopPolling() }
    }

    // MARK: header

    private var header: some View {
        let t = monitor.temps.cpu
        let (word, dot): (String, Color) = {
            guard let t else { return ("", .secondary) }
            return t >= 95 ? ("Hot", Theme.hot) : (t >= 82 ? ("Warm", Theme.warm) : ("Normal", .green))
        }()
        return HStack {
            Text("Knobs").font(.system(.title3, design: .rounded).weight(.semibold))
            Spacer()
            if let t {
                HStack(spacing: 6) {
                    Circle().fill(dot).frame(width: 6, height: 6).shadow(color: dot.opacity(0.7), radius: 3)
                    Text("\(Int(t))\u{00B0}").font(.caption.weight(.semibold)).monospacedDigit()
                    Text(word).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                .help("CPU temperature")
            }
        }
    }

    // MARK: fan mode / setup

    @ViewBuilder private var fanControls: some View {
        switch helper.state {
        case .ready:
            VStack(spacing: 6) {
                Picker("Fan mode", selection: Binding(get: { fan.mode }, set: { fan.choose($0) })) {
                    ForEach(FanController.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                if let e = fan.error { Text(e).font(.caption).foregroundStyle(Theme.hot) }
            }
        case .needsApproval:
            setup("Allow Knobs in System Settings \u{203A} Login Items to control fans.", "Open Login Items\u{2026}")
        case .notInstalled:
            setup("Fan control needs a one-time approval.", "Set Up\u{2026}")
        case .unavailable(let why):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text(why + " Monitoring still works.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
        }
    }

    private func setup(_ text: String, _ button: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "lock.shield").font(.title2).symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor).frame(width: 28)
            VStack(alignment: .leading, spacing: 8) {
                Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(button) { helper.enable() }.buttonStyle(.borderedProminent).controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .surface()
    }

    // MARK: numbers

    private var stats: some View {
        let s = monitor.sample
        func pct(_ v: Double?) -> String { v.map { "\(Int($0 * 100))%" } ?? "\u{2013}" }
        let power = s.systemPowerWatts.map { "\(Int($0)) W" } ?? (s.batteryLevel.map { "\(Int($0 * 100))%" } ?? "\u{2013}")
        return HStack(spacing: 0) {
            stat(pct(s.cpuLoad), "CPU")
            statDivider
            stat(pct(s.gpuLoad), "GPU")
            statDivider
            stat(pct(s.memoryUsed), "Memory")
            statDivider
            stat(power, s.systemPowerWatts != nil ? "Power" : "Battery")
        }
        .padding(.vertical, 11)
        .surface()
    }

    private var statDivider: some View { Rectangle().fill(Color.primary.opacity(0.10)).frame(width: 0.5, height: 28) }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit().numericFlip()
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    // MARK: switches

    @ViewBuilder private var group: some View {
        if Capabilities.hasLogoLight || Capabilities.hasTouchDisplay { switches }
    }

    private var switches: some View {
        VStack(spacing: 0) {
                if Capabilities.hasLogoLight {
                    switchRow("apple.logo", "Logo Light", Binding(get: { logo.isOn }, set: { _ in logo.toggle() }), busy: logo.isWorking)
                }
                if Capabilities.hasLogoLight && Capabilities.hasTouchDisplay { Rectangle().fill(Color.primary.opacity(0.10)).frame(height: 0.5).padding(.leading, 42) }
                if Capabilities.hasTouchDisplay {
                    switchRow("hand.point.up.left.fill", "Touch Input", Binding(get: { touch.isEnabled }, set: { _ in touch.toggle() }))
                }
                if let m = logo.errorMessage {
                    Text(m).font(.caption).foregroundStyle(Theme.warm).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.bottom, 8)
                }
        }
        .surface()
    }

    private func switchRow(_ icon: String, _ title: String, _ isOn: Binding<Bool>, busy: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary).frame(width: 22)
            Text(title).font(.callout)
            Spacer()
            if busy { ProgressView().controlSize(.small) }
            Toggle(title, isOn: isOn).toggleStyle(.switch).labelsHidden().controlSize(.small).disabled(busy)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    // MARK: footer

    private var footer: some View {
        HStack {
            switch updater.state {
            case .available(let r):
                Button("Update to \(r.version)") { Task { await updater.install(r) } }.buttonStyle(.borderedProminent).controlSize(.small)
            case .working(let step): Text(step).font(.caption).foregroundStyle(.secondary)
            case .failed(let m): Text(m).font(.caption).foregroundStyle(Theme.warm).lineLimit(2)
            default: Text("v\(updater.currentVersion)").monospacedDigit().font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Check for Updates") { Task { await updater.check() } }
                Toggle("Check Automatically", isOn: $updater.autoCheck)
                Toggle("Open at Login", isOn: Binding(get: { SMAppService.mainApp.status == .enabled }, set: { on in
                    if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() } }))
                Divider()
                Link("Knobs on GitHub", destination: URL(string: "https://github.com/\(Updater.repo)")!)
                Divider()
                Button("Quit Knobs") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle").font(.body).foregroundStyle(.secondary)
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
    @Environment(\.colorScheme) private var scheme
    private let size: CGFloat = 212
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
    private var capSize: CGFloat { size - 56 }
    private var modeLabel: String { fan.mode == .auto ? "Automatic" : (fan.mode == .full ? "Full blast" : "Manual") }

    var body: some View {
        ZStack {
            // soft halo behind the dial while the user is in control
            Circle().fill(Color.accentColor.opacity(fan.mode == .auto ? 0.0 : 0.22)).blur(radius: 28).frame(width: capSize + 20, height: capSize + 20)
                .animation(.easeOut(duration: 0.4), value: fan.mode)

            // machined tick ring: lit ticks warm up toward the current value
            Canvas { ctx, sz in
                let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let outer = sz.width / 2 - 2
                for i in 0..<ticks {
                    let t = Double(i) / Double(ticks - 1)
                    let a = (startDeg - sweep * t) * .pi / 180
                    let major = i % 10 == 0
                    let len: CGFloat = major ? 12 : 7
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + cos(a) * (outer - len), y: c.y - sin(a) * (outer - len)))
                    p.addLine(to: CGPoint(x: c.x + cos(a) * outer, y: c.y - sin(a) * outer))
                    let lit = t <= fraction + 0.0001
                    let strength = fan.mode == .auto ? 0.5 : 0.7
                    let alpha = lit ? strength + (1 - strength) * (fraction > 0 ? t / max(fraction, 0.01) : 0) : (major ? 0.30 : 0.16)
                    ctx.stroke(p, with: .color((lit ? Color.accentColor : Color.primary).opacity(alpha)), style: StrokeStyle(lineWidth: major ? 2.2 : 1.5, lineCap: .round))
                }
            }
            .frame(width: size, height: size)
            .animation(.easeOut(duration: 0.3), value: fraction)

            // cap: system material with a specular rim
            cap
                .scaleEffect(pressed ? 0.985 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)

            // notch
            Capsule().fill(Color.accentColor).frame(width: 3.5, height: 10)
                .shadow(color: Color.accentColor.opacity(0.6), radius: 3)
                .offset(y: -capSize / 2 + 11)
                .rotationEffect(.degrees(-135 + fraction * sweep))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: fraction)

            VStack(spacing: 3) {
                Text(rpm > 0 ? rpm.formatted() : "\u{2013}")
                    .font(.system(size: 40, weight: .light, design: .rounded)).monospacedDigit().numericFlip()
                Text("RPM").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                Text(modeLabel).font(.caption2.weight(.medium))
                    .foregroundStyle(fan.mode == .auto ? Color.secondary : Color.accentColor)
                    .padding(.top, 4)
            }

            // range captions under the open end of the arc
            Text("MIN").font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(.tertiary)
                .offset(x: -size * 0.27, y: size * 0.46)
            Text("MAX").font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(.tertiary)
                .offset(x: size * 0.27, y: size * 0.46)
        }
        .frame(width: size, height: size + 8)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in pressed = true; turn(to: v.location, final: false) }
            .onEnded { v in pressed = false; turn(to: v.location, final: true) },
                 including: interactive ? .all : .subviews)
        .help(interactive ? "Drag to set fan speed" : "Fan speed (monitor only)")
    }

    @ViewBuilder private var cap: some View {
        let rim = LinearGradient(colors: [Color.white.opacity(scheme == .dark ? 0.28 : 0.9), Color.white.opacity(0.0), Color.black.opacity(0.10)],
                                 startPoint: .top, endPoint: .bottom)
        do {
            Circle().fill(.regularMaterial)
                .overlay(Circle().fill(LinearGradient(colors: [Color.white.opacity(scheme == .dark ? 0.10 : 0.45), .clear], startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().strokeBorder(rim, lineWidth: 1))
                .frame(width: capSize, height: capSize)
                .shadow(color: .black.opacity(0.20), radius: 12, y: 6)
        }
    }

    private func turn(to p: CGPoint, final: Bool) {
        let dx = p.x - size / 2, dy = -(p.y - (size + 8) / 2)
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
