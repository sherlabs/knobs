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
        .onAppear { monitor.start(); fan.startPolling(); touch.refresh(); helper.refresh(); Task { await updater.checkIfStale() } }
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
            Text(label.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
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
                    switchRow("hand.point.up.left.fill", "Ignore Touch Gestures", Binding(get: { !touch.isEnabled }, set: { _ in touch.toggle() }))
                }
                if let m = touch.error {
                    Text(m).font(.caption).foregroundStyle(Theme.warm).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.bottom, 8)
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
        .contentShape(Rectangle())
        .onTapGesture { if !busy { isOn.wrappedValue.toggle() } }
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
                Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(.secondary).frame(width: 28, height: 28).contentShape(Rectangle())
                    .accessibilityLabel("More")
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
    @State private var dragValid = false
    @State private var lastDetent = -1
    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    private var modeLabel: String { !interactive ? "Monitor only" : fan.mode == .auto ? (!fan.fans.isEmpty && rpm == 0 ? "Automatic \u{00B7} idle" : "Automatic") : (fan.mode == .full ? "Full blast" : "Manual") }

    var body: some View {
        ZStack {
            // soft halo behind the dial while the user is in control
            Circle().fill(Color.accentColor.opacity(fan.mode == .auto ? 0.0 : 0.22)).blur(radius: 28).frame(width: capSize + 20, height: capSize + 20)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: fan.mode)

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
                    let alpha = lit ? strength + (1 - strength) * (fraction > 0 ? t / max(fraction, 0.01) : 0) : (major ? 0.42 : 0.26)
                    ctx.stroke(p, with: .color((lit ? Color.accentColor : Color.primary).opacity(alpha)), style: StrokeStyle(lineWidth: major ? 2.2 : 1.5, lineCap: .round))
                }
            }
            .frame(width: size, height: size)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: fraction)

            // cap: system material with a specular rim
            cap
                .scaleEffect(pressed ? 0.985 : 1)
                .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: pressed)

            // notch
            Capsule().fill(Color.accentColor).frame(width: 3.5, height: 10)
                .shadow(color: Color.accentColor.opacity(0.6), radius: 3)
                .offset(y: -capSize / 2 + 11)
                .rotationEffect(.degrees(-135 + fraction * sweep))
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: fraction)

            VStack(spacing: 3) {
                Text(fan.fans.isEmpty ? "\u{2013}" : rpm.formatted())
                    .font(.system(size: 40, weight: .light, design: .rounded)).monospacedDigit().numericFlip()
                Text("RPM").font(.system(size: 11, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                Text(modeLabel).font(.caption2.weight(.medium))
                    .foregroundStyle(fan.mode == .auto ? Color.secondary : Color.accentColor)
                    .padding(.top, 4)
            }

            // range captions under the open end of the arc
            Text("MIN").font(.system(size: 11, weight: .semibold)).tracking(0.8).foregroundStyle(.secondary)
                .offset(x: -size * 0.27, y: size * 0.46)
            Text("MAX").font(.system(size: 11, weight: .semibold)).tracking(0.8).foregroundStyle(.secondary)
                .offset(x: size * 0.27, y: size * 0.46)
        }
        .frame(width: size, height: size + 8)
        .opacity(interactive ? 1 : 0.7)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 4)
            .onChanged { v in
                if !pressed { dragValid = startsOnDial(v.startLocation) }
                pressed = true
                if dragValid { turn(to: v.location, final: false) }
            }
            .onEnded { v in
                pressed = false
                if dragValid { turn(to: v.location, final: true) }
                dragValid = false
            },
                 including: interactive ? .all : .subviews)
        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2).padding(2).opacity(focused ? 0.8 : 0))
        .focusable(interactive)
        .focused($focused)
        .onMoveCommand { dir in
            switch dir {
            case .left, .down: nudge(-0.05)
            case .right, .up: nudge(0.05)
            default: break
            }
        }
        .help(interactive ? "Drag or use the arrow keys to set fan speed" : "Fan speed (monitor only)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fan speed")
        .accessibilityValue("\(rpm.formatted()) RPM, \(modeLabel)")
        .accessibilityHint(interactive ? "Adjustable. Swipe up or down to change the speed." : "Monitoring only.")
        .accessibilityAdjustableAction { direction in
            guard interactive else { return }
            switch direction {
            case .increment: nudge(0.05)
            case .decrement: nudge(-0.05)
            @unknown default: break
            }
        }
    }

    /// Only a press on the dial itself may take over the fans, never a stray click near it.
    private func startsOnDial(_ p: CGPoint) -> Bool {
        let d = hypot(p.x - size / 2, p.y - (size + 8) / 2)
        return d >= 30 && d <= size / 2 + 6
    }

    private func nudge(_ delta: Double) {
        let base = fan.mode == .manual ? fan.manualFraction : fraction
        fan.manualFraction = min(1, max(0, base + delta))
        if fan.mode != .manual { fan.choose(.manual) }
        detent(fan.manualFraction)
        fan.commitManual()
    }

    /// A small tap each time the knob crosses one of the major ticks.
    private func detent(_ f: Double) {
        let i = Int((f * 6).rounded())
        if i != lastDetent {
            if lastDetent != -1 { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
            lastDetent = i
        }
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
        // Pin to the end instead of flipping to the other one when the drag crosses the gap.
        let held = fan.mode == .manual ? fan.manualFraction : fraction
        let value = abs(f - held) > 0.5 ? (held > 0.5 ? 1.0 : 0.0) : f
        fan.manualFraction = value
        if fan.mode != .manual { fan.choose(.manual) }
        detent(value)
        if final || Date().timeIntervalSince(lastSend) > 0.3 { lastSend = Date(); fan.commitManual() }
    }
}

private extension View {
    /// Digits roll instead of snapping (macOS 14+); a no-op on 13.
    @ViewBuilder func numericFlip() -> some View {
        if #available(macOS 14.0, *) { self.contentTransition(.numericText()) } else { self }
    }
}
