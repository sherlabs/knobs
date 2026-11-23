import Foundation
import AppKit
import KnobsKit

@MainActor
final class FanController: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable { case auto = "Auto", manual = "Manual", full = "Full blast"; var id: String { rawValue } }

    @Published private(set) var fans: [FanReading] = []
    @Published private(set) var temps = TemperatureSummary()
    @Published private(set) var mode: Mode = .auto
    @Published var manualFraction: Double = 0.5
    @Published private(set) var error: String?
    @Published private(set) var available = false

    private let helper: HelperClient
    private var pollTimer: Timer?
    private var beatTimer: Timer?
    private var polling = 0

    init(helper: HelperClient) {
        self.helper = helper
        available = SMC.shared.open()
        refreshNow()
        // Fans must never be left manual by a quitting app.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.mode != .auto else { return }
            Task { _ = await self.helper.setAuto() }
        }
    }

    /// Call from the fan view's appear/disappear so we only poll while it is on screen.
    func startPolling() {
        polling += 1
        guard pollTimer == nil else { return }
        refreshNow()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
    }

    func stopPolling() {
        polling = max(0, polling - 1)
        if polling == 0 { pollTimer?.invalidate(); pollTimer = nil }
    }

    func refreshNow() {
        guard available else { return }
        Task.detached(priority: .utility) {
            let f = SMC.shared.fans(), t = SMC.shared.temperatures()
            await MainActor.run {
                self.fans = f; self.temps = t
                // Reflect reality: if the system (or another tool) changed the mode, follow it.
                if !f.contains(where: { $0.isManual }), self.mode != .auto { self.mode = .auto; self.stopBeat() }
            }
        }
    }

    func choose(_ newMode: Mode) {
        guard helper.isReady else { return }
        Task {
            error = nil
            switch newMode {
            case .auto:
                if await helper.setAuto() { mode = .auto; stopBeat() } else { error = "Couldn\u{2019}t hand fans back to automatic." }
            case .manual:
                if await helper.setFanFraction(manualFraction) { mode = .manual; startBeat() } else { error = "The helper refused the request." }
            case .full:
                if await helper.fullBlast() { mode = .full; startBeat() } else { error = "The helper refused the request." }
            }
            refreshNow()
        }
    }

    func commitManual() {
        guard mode == .manual else { return }
        Task { if !(await helper.setFanFraction(manualFraction)) { error = "Couldn\u{2019}t set the fan speed." }; refreshNow() }
    }

    private func startBeat() {
        beatTimer?.invalidate()
        beatTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.helper.heartbeat() }
        }
    }
    private func stopBeat() { beatTimer?.invalidate(); beatTimer = nil }
}
