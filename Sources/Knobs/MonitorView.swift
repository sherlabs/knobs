import SwiftUI
import Charts
import KnobsKit

/// Calm by design: two rings, one bar, one chart. Colour appears only when something is warm or hot.
struct MonitorView: View {
    @EnvironmentObject var monitor: MonitorController

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                LoadRing(title: "CPU", load: monitor.sample.cpuLoad, temp: monitor.temps.cpu)
                LoadRing(title: "GPU", load: monitor.sample.gpuLoad, temp: monitor.temps.gpu)
            }
            memoryCard
            chartCard
            powerCard
        }
        .onAppear { monitor.start() }
    }

    // MARK: memory

    private var memoryCard: some View {
        let used = monitor.sample.memoryUsed ?? 0
        let pressure = monitor.sample.memoryPressure
        let tint: Color = pressure == .critical ? .red : (pressure == .warning ? .orange : .white)
        return GlassCard(padding: 12) {
            VStack(spacing: 8) {
                HStack {
                    Text("Memory").font(.system(size: 12, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(pressure == .normal ? "Pressure normal" : (pressure == .warning ? "Pressure elevated" : "Pressure critical"))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded)).foregroundStyle(pressure == .normal ? Color.secondary : tint)
                    Text("\(Int(used * 100))%").font(.system(size: 12, weight: .bold, design: .rounded)).monospacedDigit()
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.10))
                        Capsule().fill(tint).frame(width: max(6, g.size.width * used))
                            .animation(.easeOut(duration: 0.5), value: used)
                    }
                }.frame(height: 7)
            }
        }
    }

    // MARK: history chart

    private var chartCard: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    legend("CPU", .white); legend("GPU", .white.opacity(0.45))
                    Spacer()
                    Text("last 3 min").font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.tertiary)
                }
                if monitor.history.count < 2 {
                    Text("Collecting\u{2026}").font(.system(size: 11)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 78)
                } else {
                    Chart {
                        ForEach(monitor.history) { p in
                            AreaMark(x: .value("t", p.time), y: .value("CPU", p.cpu * 100), series: .value("m", "cpu"))
                                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.monotone)
                            LineMark(x: .value("t", p.time), y: .value("CPU", p.cpu * 100), series: .value("m", "cpu"))
                                .foregroundStyle(.white).lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round)).interpolationMethod(.monotone)
                            LineMark(x: .value("t", p.time), y: .value("GPU", p.gpu * 100), series: .value("m", "gpu"))
                                .foregroundStyle(.white.opacity(0.45)).lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round)).interpolationMethod(.monotone)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(values: [0, 50, 100]) { v in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.white.opacity(0.08))
                            AxisValueLabel { if let n = v.as(Int.self) { Text("\(n)").font(.system(size: 9)).foregroundStyle(.tertiary) } }
                        }
                    }
                    .frame(height: 78)
                }
            }
        }
    }

    private func legend(_ name: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(name).font(.system(size: 11, weight: .semibold, design: .rounded))
        }
    }

    // MARK: power + battery

    private var powerCard: some View {
        let s = monitor.sample
        return GlassCard(padding: 12) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.systemPowerWatts.map { String(format: "%.0f W", $0) } ?? "\u{2013}")
                        .font(.system(size: 18, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("System power").font(.system(size: 10.5, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }
                Chart(monitor.history.compactMap { p in p.watts.map { (p.id, $0) } }, id: \.0) { item in
                    LineMark(x: .value("i", item.0), y: .value("W", item.1)).foregroundStyle(.white.opacity(0.75)).interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
                .chartXAxis(.hidden).chartYAxis(.hidden).chartYScale(domain: .automatic(includesZero: true))
                .frame(height: 34)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 3) {
                        if s.isCharging || s.onACPower { Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(.white.opacity(0.85)) }
                        Text(s.batteryLevel.map { "\(Int($0 * 100))%" } ?? "\u{2013}")
                            .font(.system(size: 18, weight: .bold, design: .rounded)).monospacedDigit()
                    }
                    Text(s.isCharging ? "Charging" : (s.onACPower ? "On power" : "Battery")).font(.system(size: 10.5, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct LoadRing: View {
    let title: String
    let load: Double?
    let temp: Double?

    private var tint: Color {
        guard let t = temp else { return .white }
        return t >= 95 ? .red : (t >= 85 ? .orange : .white)
    }

    var body: some View {
        GlassCard(padding: 12) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(.white.opacity(0.10), lineWidth: 7)
                    Circle().trim(from: 0, to: max(0.015, load ?? 0))
                        .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: load)
                    VStack(spacing: 0) {
                        Text(load.map { "\(Int($0 * 100))" } ?? "\u{2013}").font(.system(size: 21, weight: .bold, design: .rounded)).monospacedDigit()
                        Text("%").font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 78, height: 78)
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 12, weight: .semibold, design: .rounded))
                    if let t = temp {
                        Text("\(Int(t))\u{00B0}").font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
                            .foregroundStyle(t >= 85 ? tint : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
