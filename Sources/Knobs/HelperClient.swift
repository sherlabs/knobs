import Foundation
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

    init() { refresh() }

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
        case .requiresApproval: state = .needsApproval
        case .notRegistered: state = .notInstalled
        case .notFound: state = .unavailable("Helper is missing from this build.")
        @unknown default: state = .notInstalled
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
        guard let v = await version(), v != KnobsConstants.helperVersion else { return }
        connection?.invalidate(); connection = nil
        try? await service.unregister()
        try? service.register()
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
