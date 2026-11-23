import Foundation
import KnobsKit

/// Root helper. Runs as a launchd daemon registered through SMAppService.
/// Safety rules:
///  * only the signed Knobs app (same team) may connect;
///  * manual fan control expires unless the app keeps sending heartbeats;
///  * fans go back to automatic when the app disconnects or the helper stops;
///  * if the CPU gets dangerously hot, fans are forced to full speed.
final class Service: NSObject, KnobsHelperProtocol {
    private let smc = SMC.shared
    private let queue = DispatchQueue(label: "knobs.helper.state")
    private var manual = false
    private var lastBeat = Date()
    private var timer: DispatchSourceTimer?
    private let heartbeatTimeout: TimeInterval = 12
    private let hotLimit: Double = 98

    override init() {
        super.init()
        smc.open()
        _ = smc.setAuto()                       // never inherit a stale manual state
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 2, repeating: 2)
        t.setEventHandler { [weak self] in self?.watchdog() }
        t.resume()
        timer = t
    }

    private func watchdog() {
        guard manual else { return }
        if Date().timeIntervalSince(lastBeat) > heartbeatTimeout { revertToAuto(); return }
        if let cpu = smc.temperatures().cpu, cpu >= hotLimit { _ = smc.setManual(fraction: 1) }
    }

    private func revertToAuto() { manual = false; _ = smc.setAuto() }

    func restoreAutoNow() { queue.sync { revertToAuto() } }

    /// "<version>@<path of this helper>", so the app can tell a helper started from a different copy of itself.
    func version(reply: @escaping (String) -> Void) {
        var buf = [CChar](repeating: 0, count: 4096)
        let n = proc_pidpath(getpid(), &buf, UInt32(buf.count))
        reply("\(KnobsConstants.helperVersion)@" + (n > 0 ? String(cString: buf) : ""))
    }

    func setFanFraction(_ fraction: Double, reply: @escaping (Bool) -> Void) {
        queue.async {
            let ok = self.smc.setManual(fraction: fraction)
            self.manual = ok; self.lastBeat = Date()
            reply(ok)
        }
    }

    func fullBlast(reply: @escaping (Bool) -> Void) { setFanFraction(1, reply: reply) }

    func setAuto(reply: @escaping (Bool) -> Void) {
        queue.async { self.revertToAuto(); reply(true) }
    }

    func heartbeat() { queue.async { self.lastBeat = Date() } }

    func setLogoLight(_ on: Bool, reply: @escaping (Bool) -> Void) {
        queue.async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            p.arguments = ["write", "com.apple.CoreBrightness", "LEBacklightMode", "-int", on ? "1" : "0"]
            p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
            do { try p.run(); p.waitUntilExit(); reply(p.terminationStatus == 0) } catch { reply(false) }
        }
    }
}

final class Delegate: NSObject, NSXPCListenerDelegate {
    let service = Service()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection c: NSXPCConnection) -> Bool {
        // Refuse unless this helper is team-signed and the peer is the Knobs app from the same team.
        guard let requirement = Trust.requirement(identifier: KnobsConstants.appIdentifier) else { return false }
        c.setCodeSigningRequirement(requirement)
        c.exportedInterface = NSXPCInterface(with: KnobsHelperProtocol.self)
        c.exportedObject = service
        c.invalidationHandler = { [weak self] in self?.service.restoreAutoNow() }
        c.interruptionHandler = { [weak self] in self?.service.restoreAutoNow() }
        c.resume()
        return true
    }
}

let delegate = Delegate()
let listener = NSXPCListener(machServiceName: KnobsConstants.machService)
listener.delegate = delegate
for sig in [SIGTERM, SIGINT] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler { delegate.service.restoreAutoNow(); exit(0) }
    src.resume()
}
listener.resume()
RunLoop.main.run()
