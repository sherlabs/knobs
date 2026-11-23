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
        VStack(spacing: 16) {
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
            Text("Knobs").font(.headline)
            Spacer()
            if let t {
                HStack(spacing: 6) {
                    Circle().fill(dot).frame(width: 7, height: 7)
                    Text("CPU \(Int(t))\u{00B0} \u{00B7} \(word)").font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                }
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
            Text(why + " Monitoring still works.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private func setup(_ text: String, _ button: String) -> some View {
        VStack(spacing: 8) {
            Text(text).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(button) { helper.enable() }.buttonStyle(.borderedProminent).controlSize(.regular)
        }
    }

    // MARK: numbers

    private var stats: some View {
        let s = monitor.sample
        func pct(_ v: Double?) -> String { v.map { "\(Int($0 * 100))%" } ?? "\u{2013}" }
        let power = s.systemPowerWatts.map { "\(Int($0)) W" } ?? (s.batteryLevel.map { "\(Int($0 * 100))%" } ?? "\u{2013}")
        return HStack(spacing: 0) {
            stat(pct(s.cpuLoad), "CPU")
            stat(pct(s.gpuLoad), "GPU")
            stat(pct(s.memoryUsed), "Memory")
            stat(power, s.systemPowerWatts != nil ? "Power" : "Battery")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.medium)).monospacedDigit().numericFlip()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    // MARK: switches

    private var group: some View {
        GroupBox26 {
            VStack(spacing: 0) {
                switchRow("apple.logo", "Logo Light", Binding(get: { logo.isOn }, set: { _ in logo.toggle() }), busy: logo.isWorking)
                Divider().padding(.leading, 42)
                switchRow("hand.point.up.left.fill", "Touch Input", Binding(get: { touch.isEnabled }, set: { _ in touch.toggle() }))
                if let m = logo.errorMessage {
                    Text(m).font(.caption).foregroundStyle(Theme.warm).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.bottom, 8)
                }
            }
        }
    }

    private func switchRow(_ icon: String, _ title: String, _ isOn: Binding<Bool>, busy: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.body).foregroundStyle(.secondary).frame(width: 22)
            Text(title)
            Spacer()
            if busy { ProgressView().controlSize(.small) }
            Toggle(title, isOn: isOn).toggleStyle(.switch).labelsHidden().controlSize(.small).disabled(busy)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    // MARK: footer

    private var footer: some View {
        HStack {
            switch updater.state {
            case .available(let r):
                Button("Update to \(r.version)") { Task { await updater.install(r) } }.buttonStyle(.borderedProminent).controlSize(.small)
            case .working(let step): Text(step).font(.caption).foregroundStyle(.secondary)
            case .failed(let m): Text(m).font(.caption).foregroundStyle(Theme.warm).lineLimit(2)
            default: Text("Version \(updater.currentVersion)").font(.caption).foregroundStyle(.secondary)
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
    private var capSize: CGFloat { size - 40 }

    var body: some View {
        ZStack {
            // soft halo behind the dial while the user is in control
            Circle().fill(Color.accentColor.opacity(fan.mode == .auto ? 0.0 : 0.18)).blur(radius: 26).frame(width: capSize, height: capSize)
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
                    let alpha = lit ? (fan.mode == .auto ? 0.55 : 1.0) : 0.18
                    ctx.stroke(p, with: .color((lit ? Color.accentColor : Color.primary).opacity(alpha)), style: StrokeStyle(lineWidth: major ? 2 : 1.4, lineCap: .round))
                }
            }
            .frame(width: size, height: size)
            .animation(.easeOut(duration: 0.3), value: fraction)

            // cap: system material with a hairline edge
            Circle().fill(.regularMaterial)
                .overlay(Circle().strokeBorder(.separator, lineWidth: 0.75))
                .frame(width: capSize, height: capSize)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
                .scaleEffect(pressed ? 0.985 : 1)

            // notch
            Capsule().fill(Color.accentColor).frame(width: 3, height: 9)
                .offset(y: -capSize / 2 + 10)
                .rotationEffect(.degrees(-135 + fraction * sweep))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: fraction)

            VStack(spacing: 2) {
                Text(rpm > 0 ? rpm.formatted() : "\u{2013}").font(.system(size: 32, weight: .light)).monospacedDigit().numericFlip()
                Text("RPM").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
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
