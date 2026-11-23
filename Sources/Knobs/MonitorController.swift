import Foundation
import KnobsKit

struct HistoryPoint: Identifiable, Equatable {
    let id: Int
    let time: Date
    let cpu: Double
    let gpu: Double
    let watts: Double?
}

/// Samples system load on a gentle timer and keeps a few minutes of history for the charts.
@MainActor
final class MonitorController: ObservableObject {
    @Published private(set) var sample = SystemSample()
    @Published private(set) var temps = TemperatureSummary()
    @Published private(set) var history: [HistoryPoint] = []

    private var timer: Timer?
    private var counter = 0
    private let interval: TimeInterval = 2
    private let capacity = 90      // ~3 minutes

    func start() {
        guard timer == nil else { return }
        SMC.shared.open()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func tick() {
        Task.detached(priority: .utility) {
            let s = SystemStats.shared.sample()
            let t = SMC.shared.temperatures()
            await MainActor.run {
                self.sample = s; self.temps = t
                self.counter += 1
                guard let cpu = s.cpuLoad else { return }
                self.history.append(HistoryPoint(id: self.counter, time: Date(), cpu: cpu, gpu: s.gpuLoad ?? 0, watts: s.systemPowerWatts))
                if self.history.count > self.capacity { self.history.removeFirst(self.history.count - self.capacity) }
            }
        }
    }
}
