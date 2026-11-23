import SwiftUI
import KnobsKit

struct FansView: View {
    @EnvironmentObject var fan: FanController
    @EnvironmentObject var helper: HelperClient

    var body: some View {
        VStack(spacing: 12) {
            if !fan.available {
                GlassCard { Text("Fan sensors aren\u{2019}t available on this Mac.").font(.system(size: 12)).foregroundStyle(.secondary) }
            } else {
                HStack(spacing: 10) {
                    ForEach(fan.fans) { FanGauge(reading: $0) }
                }
                temps
                controls
            }
        }
        .onAppear { fan.startPolling(); helper.refresh() }
        .onDisappear { fan.stopPolling() }
    }

    private var temps: some View {
        let t = fan.temps
        let items: [(String, Double?)] = [("CPU", t.cpu), ("GPU", t.gpu), ("Battery", t.battery), ("Memory", t.memory)]
        return GlassCard(padding: 10) {
            HStack {
                ForEach(items, id: \.0) { item in
                    VStack(spacing: 2) {
                        Text(item.1.map { String(format: "%.0f\u{00B0}", $0) } ?? "\u{2013}")
                            .font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(color(item.1))
                        Text(item.0).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func color(_ t: Double?) -> Color {
        guard let t else { return .secondary }
        return t >= 95 ? .red : (t >= 85 ? .orange : .white)
    }

    @ViewBuilder private var controls: some View {
        switch helper.state {
        case .ready:
            GlassCard {
                VStack(spacing: 12) {
                    GlassSegments(items: FanController.Mode.allCases, selection: Binding(get: { fan.mode }, set: { fan.choose($0) }), label: { $0.rawValue })
                    if fan.mode == .manual {
                        VStack(spacing: 4) {
                            HStack {
                                Text("Speed").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(fan.manualFraction * 100))%").font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
                            }
                            Slider(value: $fan.manualFraction, in: 0...1) { editing in if !editing { fan.commitManual() } }.tint(.cyan)
                        }
                    }
                    Text(caption).font(.system(size: 10.5)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if let e = fan.error { Text(e).font(.system(size: 11)).foregroundStyle(.red.opacity(0.9)) }
                }
            }
        case .needsApproval:
            setup(text: "Allow the Knobs helper in System Settings \u{2192} Login Items, then come back.", button: "Open Login Items") { helper.enable() }
        case .notInstalled:
            setup(text: "Changing fan speeds needs a small background helper. You approve it once in System Settings.", button: "Enable fan control") { helper.enable() }
        case .unavailable(let why):
            GlassCard { Text(why + " Monitoring still works.").font(.system(size: 11)).foregroundStyle(.secondary) }
        }
    }

    private func setup(text: String, button: String, action: @escaping () -> Void) -> some View {
        GlassCard {
            VStack(spacing: 10) {
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                GlassButton(title: button, icon: "lock.open.fill", prominent: true, action: action)
            }.frame(maxWidth: .infinity)
        }
    }

    private var caption: String {
        switch fan.mode {
        case .auto: "macOS manages the fans."
        case .manual: "Fans hold this speed until you switch back or quit Knobs."
        case .full: "Maximum speed. Loud, and uses more power. Returns to auto when you quit."
        }
    }
}

struct FanGauge: View {
    let reading: FanReading
    var body: some View {
        GlassCard(padding: 12) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(.white.opacity(0.1), lineWidth: 7)
                    Circle().trim(from: 0, to: max(0.02, reading.fraction))
                        .stroke(AngularGradient(colors: [.cyan, .blue, .purple, .pink], center: .center), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: reading.fraction)
                    VStack(spacing: 0) {
                        Text("\(Int(reading.actual))").font(.system(size: 19, weight: .bold, design: .rounded)).monospacedDigit()
                        Text("RPM").font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 84, height: 84)
                HStack(spacing: 4) {
                    Text("Fan \(reading.index + 1)").font(.system(size: 11, weight: .semibold, design: .rounded))
                    if reading.isManual { Circle().fill(.orange).frame(width: 6, height: 6) }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
