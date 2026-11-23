import SwiftUI
import AppKit
import Charts
import ServiceManagement
import KnobsKit

/// One calm dashboard, no tabs: status header, tiles, controls, footer.
struct PopoverView: View {
    @EnvironmentObject var monitor: MonitorController
    @EnvironmentObject var fan: FanController
    @EnvironmentObject var helper: HelperClient
    @EnvironmentObject var logo: LogoController
    @EnvironmentObject var touch: TouchController
    @EnvironmentObject var updater: Updater

    var body: some View {
        VStack(spacing: 10) {
            header
            fansTile
            HStack(spacing: 10) { loadTile("CPU", "cpu", monitor.sample.cpuLoad, monitor.temps.cpu, monitor.history.map(\.cpu))
                                  loadTile("GPU", "display", monitor.sample.gpuLoad, monitor.temps.gpu, monitor.history.map(\.gpu)) }
            HStack(spacing: 10) { memoryTile; batteryTile }
            HStack(spacing: 10) { powerTile; thermalsTile }
            Text("Controls").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
            HStack(spacing: 10) { logoTile; touchTile }
            footer
        }
        .padding(16)
        .frame(width: 420)
        .background(GlassBackground())
        .preferredColorScheme(.dark)
        .onAppear { monitor.start(); fan.startPolling(); touch.refresh(); helper.refresh() }
        .onDisappear { fan.stopPolling() }
    }

    // MARK: header

    private var header: some View {
        let cpu = monitor.temps.cpu
        let (word, tint): (String, Color) = {
            guard let t = cpu else { return ("Good", Theme.accent) }
            return t >= 95 ? ("Hot", Theme.hot) : (t >= 82 ? ("Warm", Theme.warm) : ("Cool", Theme.accent))
        }()
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                (Text("Your Mac is ").foregroundColor(.white) + Text(word).foregroundColor(tint))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(Host.current().localizedName ?? "Mac").font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if let icon = NSApp.applicationIconImage { Image(nsImage: icon).resizable().frame(width: 46, height: 46) }
        }
        .padding(.horizontal, 4).padding(.bottom, 2)
    }

    // MARK: fans

    private var fansTile: some View {
        GlassCard(padding: 12) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "fan.fill").font(.system(size: 16)).frame(width: 22).foregroundStyle(.white.opacity(0.9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fans").font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(fan.fans.isEmpty ? "No fan sensors" : fan.fans.map { "\(Int($0.actual).formatted()) RPM" }.joined(separator: "  \u{00B7}  "))
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.65)).monospacedDigit()
                    }
                    Spacer()
                    if helper.state == .ready {
                        GlassSegments(items: FanController.Mode.allCases, selection: Binding(get: { fan.mode }, set: { fan.choose($0) }), label: { $0.rawValue })
                            .frame(width: 200)
                    }
                }
                switch helper.state {
                case .ready:
                    HStack(spacing: 8) {
                        Image(systemName: "tortoise.fill").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                        Slider(value: $fan.manualFraction, in: 0...1) { editing in if !editing { fan.commitManual() } }
                            .tint(Theme.accent).disabled(fan.mode != .manual)
                        Image(systemName: "hare.fill").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    }
                    .opacity(fan.mode == .manual ? 1 : 0.35)
                    if fan.mode == .full || fan.error != nil {
                        Text(fan.error ?? "Full speed. Loud and power hungry. Returns to Auto when you quit.")
                            .font(.system(size: 11)).foregroundStyle(fan.error != nil ? Theme.hot : .white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .needsApproval:
                    actionRow("Allow Knobs in System Settings \u{2192} Login Items (one time).", "Open") { helper.enable() }
                case .notInstalled:
                    actionRow("Fan control needs a one-time approval.", "Set up") { helper.enable() }
                case .unavailable(let why):
                    Text(why + " Monitoring still works.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func actionRow(_ text: String, _ button: String, _ action: @escaping () -> Void) -> some View {
        HStack {
            Text(text).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.65))
            Spacer()
            Button(button, action: action).buttonStyle(.plain).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Theme.accent)
        }
    }

    // MARK: tiles

    private func heat(_ t: Double?) -> Color { guard let t else { return .white.opacity(0.6) }; return t >= 95 ? Theme.hot : (t >= 85 ? Theme.warm : .white.opacity(0.75)) }

    private func tile<C: View>(_ icon: String, _ title: String, trailing: String? = nil, trailingTint: Color = .white.opacity(0.7), @ViewBuilder _ content: () -> C) -> some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon).font(.system(size: 15)).frame(width: 20).foregroundStyle(.white.opacity(0.85))
                    Text(title).font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer(minLength: 0)
                    if let trailing { Text(trailing).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(trailingTint).monospacedDigit() }
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sub(_ text: String) -> some View { Text(text).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.65)).monospacedDigit() }

    private func loadTile(_ title: String, _ icon: String, _ load: Double?, _ temp: Double?, _ series: [Double]) -> some View {
        tile(icon, title, trailing: temp.map { "\(Int($0))\u{00B0}C" }, trailingTint: heat(temp)) {
            sub("Load: \(load.map { "\(Int($0 * 100))%" } ?? "\u{2013}")")
            Spark(values: series).frame(height: 26)
        }
    }

    private var memoryTile: some View {
        let used = monitor.sample.memoryUsed ?? 0
        let p = monitor.sample.memoryPressure
        let tint: Color = p == .critical ? Theme.hot : (p == .warning ? Theme.warm : Theme.accent)
        return tile("memorychip", "Memory", trailing: "\(Int(used * 100))%") {
            sub("Pressure: \(p == .normal ? "normal" : (p == .warning ? "elevated" : "critical"))")
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(tint).frame(width: max(5, g.size.width * used))
                }
            }.frame(height: 5).padding(.top, 2)
        }
    }

    private var batteryTile: some View {
        let s = monitor.sample
        let icon = s.isCharging ? "battery.100.bolt" : (s.onACPower ? "powerplug.fill" : "battery.75")
        return tile(icon, "Battery", trailing: s.batteryLevel.map { "\(Int($0 * 100))%" }) {
            sub(s.isCharging ? "Charging" : (s.onACPower ? ((s.batteryLevel ?? 0) >= 0.99 ? "Fully charged" : "On power") : "On battery"))
            Spacer(minLength: 0)
        }
    }

    private var powerTile: some View {
        tile("bolt.fill", "Power", trailing: monitor.sample.systemPowerWatts.map { String(format: "%.0f W", $0) }) {
            sub("System draw")
            Spark(values: monitor.history.compactMap(\.watts), zeroBased: true).frame(height: 22)
        }
    }

    private var thermalsTile: some View {
        let t = monitor.temps
        return tile("thermometer.medium", "Thermals") {
            VStack(alignment: .leading, spacing: 2) {
                row("Battery", t.battery); row("Memory", t.memory); row("Ambient", t.ambient)
            }
        }
    }

    private func row(_ name: String, _ v: Double?) -> some View {
        HStack { sub(name); Spacer(); Text(v.map { "\(Int($0))\u{00B0}" } ?? "\u{2013}").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(heat(v)).monospacedDigit() }
    }

    // MARK: controls

    private var logoTile: some View {
        tile("apple.logo", "Logo light") {
            HStack {
                sub(logo.isWorking ? "Applying\u{2026}" : (logo.isOn ? "Illuminated" : "Off"))
                Spacer()
                GlassSwitch(isOn: logo.isOn, busy: logo.isWorking) { logo.toggle() }
            }
            if let m = logo.errorMessage { Text(m).font(.system(size: 10.5)).foregroundStyle(Theme.warm).lineLimit(3) }
        }
    }

    private var touchTile: some View {
        tile("hand.point.up.left.fill", "Touch input") {
            HStack {
                sub(touch.isEnabled ? "Enabled" : "Disabled")
                Spacer()
                GlassSwitch(isOn: touch.isEnabled) { touch.toggle() }
            }
        }
    }

    // MARK: footer

    private var footer: some View {
        HStack {
            Group {
                switch updater.state {
                case .available(let r):
                    Button { Task { await updater.install(r) } } label: {
                        Label("Update to \(r.version)", systemImage: "arrow.down.circle.fill").font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(Theme.accent.opacity(0.9))).foregroundStyle(Color(white: 0.1))
                    }.buttonStyle(.plain)
                case .working(let step): Text(step).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                case .failed(let m): Text(m).font(.system(size: 11)).foregroundStyle(Theme.warm).lineLimit(2)
                default: Text("Knobs \(updater.currentVersion)").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                }
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
                Image(systemName: "gearshape.fill").font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
                    .frame(width: 32, height: 28).background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.10)))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
        .padding(.top, 4)
    }
}

/// Tiny trend line with a soft fade underneath.
struct Spark: View {
    let values: [Double]
    var zeroBased = false
    var body: some View {
        if values.count < 2 {
            Capsule().fill(.white.opacity(0.08)).frame(height: 2).frame(maxHeight: .infinity, alignment: .bottom)
        } else {
            Chart(Array(values.enumerated()), id: \.offset) { i, v in
                AreaMark(x: .value("i", i), y: .value("v", v)).foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)).interpolationMethod(.monotone)
                LineMark(x: .value("i", i), y: .value("v", v)).foregroundStyle(Theme.accent).lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round)).interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .chartYScale(domain: zeroBased ? .automatic(includesZero: true) : .automatic(includesZero: false))
        }
    }
}
