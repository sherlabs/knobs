import Foundation
import AppKit
import ServiceManagement
import KnobsKit

/// Installs (via SMAppService) and talks to the privileged helper.
@MainActor
final class HelperClient: ObservableObject {
    enum State: Equatable {
        case notInstalled, needsApproval, ready
        case unavailable(String)
    }

    @Published private(set) var state: State = .notInstalled
    private var connection: NSXPCConnection?
    private let service = SMAppService.daemon(plistName: KnobsConstants.helperPlist)

    private var approvalTimer: Timer?

    init() {
        refresh()
        // Coming back from System Settings: pick up the approval without any extra click.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// One-time setup at first launch: register the helper and send the user to Login Items to
    /// approve it. After that, every action (fans, logo light) runs without another prompt.
    func firstLaunchSetup() {
        let key = "helperSetupOffered.v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        guard state == .notInstalled || state == .needsApproval else { return }
        UserDefaults.standard.set(true, forKey: key)
        enable()
    }

    var isReady: Bool { state == .ready }

    func refresh() {
        guard Trust.ownTeamID() != nil else {
            state = .unavailable("This build isn\u{2019}t signed with a Developer ID, so the helper can\u{2019}t be trusted.")
            return
        }
        switch service.status {
        case .enabled:
            state = .ready
            Task { await self.ensureCurrent() }
        case .requiresApproval:
            state = .needsApproval
            watchForApproval()
        case .notRegistered: state = .notInstalled
        case .notFound:
            // Before the first registration macOS reports "not found". If the daemon plist is bundled, we can still register it.
            let plist = Bundle.main.bundlePath + "/Contents/Library/LaunchDaemons/" + KnobsConstants.helperPlist
            state = FileManager.default.fileExists(atPath: plist) ? .notInstalled : .unavailable("Helper is missing from this build.")
        @unknown default: state = .notInstalled
        }
    }

    private var healing = false

    private func watchForApproval() {
        guard approvalTimer == nil else { return }
        approvalTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self else { t.invalidate(); return }
                if self.service.status != .requiresApproval { t.invalidate(); self.approvalTimer = nil; self.refresh() }
            }
        }
    }

    /// Registers the helper; macOS then asks the user to allow it in Login Items.
    func enable() {
        do { try service.register() } catch {
            // Already registered / waiting for approval both throw; the status below tells which.
        }
        refresh()
        if state == .needsApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    func disable() {
        connection?.invalidate(); connection = nil
        Task { try? await service.unregister(); refresh() }
    }

    /// After an app update the old helper may still be running; replace it.
    private func ensureCurrent() async {
        let v = await version()
        // Healthy and current: nothing to do. A helper that is enabled but does not answer is a stale
        // job (for example one started from a replaced or moved copy of the app), so re-register it
        // from this copy of the app.
        let expected = KnobsConstants.helperVersion + "@" + Bundle.main.bundlePath + "/Contents/MacOS/knobs-helper"
        if let v, v == expected { return }
        guard !healing else { return }
        healing = true
        connection?.invalidate(); connection = nil
        try? await service.unregister()
        try? await Task.sleep(nanoseconds: 800_000_000)
        try? service.register()
        healing = false
        refresh()
    }

    // MARK: XPC

    private func proxy(_ onError: @escaping () -> Void) -> KnobsHelperProtocol? {
        if connection == nil {
            let c = NSXPCConnection(machServiceName: KnobsConstants.machService, options: .privileged)
            c.remoteObjectInterface = NSXPCInterface(with: KnobsHelperProtocol.self)
            if let req = Trust.requirement(identifier: KnobsConstants.helperIdentifier) { c.setCodeSigningRequirement(req) }
            c.invalidationHandler = { [weak self] in Task { @MainActor in self?.connection = nil } }
            c.resume()
            connection = c
        }
        return connection?.remoteObjectProxyWithErrorHandler { _ in onError() } as? KnobsHelperProtocol
    }

    private func call(_ body: @escaping (KnobsHelperProtocol, @escaping (Bool) -> Void) -> Void) async -> Bool {
        guard state == .ready else { return false }
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let once = Once()
            guard let p = proxy({ if once.fire() { cont.resume(returning: false) } }) else { cont.resume(returning: false); return }
            body(p) { ok in if once.fire() { cont.resume(returning: ok) } }
        }
    }

    func version() async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            let once = Once()
            guard let p = proxy({ if once.fire() { cont.resume(returning: nil) } }) else { cont.resume(returning: nil); return }
            p.version { v in if once.fire() { cont.resume(returning: v) } }
        }
    }

    func setFanFraction(_ f: Double) async -> Bool { await call { p, r in p.setFanFraction(f, reply: r) } }
    func fullBlast() async -> Bool { await call { p, r in p.fullBlast(reply: r) } }
    func setAuto() async -> Bool { await call { p, r in p.setAuto(reply: r) } }
    func setLogoLight(_ on: Bool) async -> Bool { await call { p, r in p.setLogoLight(on, reply: r) } }
    func heartbeat() { if state == .ready { proxy({})?.heartbeat() } }
}

/// Guards a continuation against being resumed twice.
private final class Once {
    private let lock = NSLock(); private var done = false
    func fire() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
}
