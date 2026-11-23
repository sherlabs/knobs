import Foundation
import SwiftUI

/// Toggles the backlit Apple logo on MacBook Pro by writing
/// `LEBacklightMode` in the `com.apple.CoreBrightness` domain (needs admin rights).
@MainActor
final class LogoController: ObservableObject {
    @Published private(set) var isOn: Bool
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private let storeKey = "logoIsOn"
    /// When the privileged helper is installed, toggling needs no password prompt.
    weak var helper: HelperClient?

    init() {
        if let stored = UserDefaults.standard.object(forKey: storeKey) as? Bool {
            isOn = stored
        } else if let system = Self.readSystemValue() {
            isOn = system != 0
        } else {
            isOn = true // macOS default: logo lit
        }
    }

    func set(_ on: Bool) {
        guard !isWorking, on != isOn else { return }
        isWorking = true
        errorMessage = nil
        let value = on ? 1 : 0

        let viaHelper = helper?.isReady == true ? helper : nil
        Task.detached(priority: .userInitiated) {
            let result: RunResult
            if let viaHelper, await viaHelper.setLogoLight(on) { result = .success } else { result = Self.runPrivileged(value: value) }
            await MainActor.run {
                self.isWorking = false
                switch result {
                case .success:
                    self.isOn = on
                    UserDefaults.standard.set(on, forKey: self.storeKey)
                case .cancelled:
                    break
                case .failure(let message):
                    self.errorMessage = message
                }
            }
        }
    }

    func toggle() { set(!isOn) }

    // MARK: - Privileged write

    private enum RunResult { case success, cancelled, failure(String) }

    private nonisolated static func runPrivileged(value: Int) -> RunResult {
        let command = "defaults write com.apple.CoreBrightness LEBacklightMode -int \(value)"
        let source = "do shell script \"\(command)\" with administrator privileges"
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .failure("Could not build script.")
        }
        script.executeAndReturnError(&error)
        guard let error else { return .success }
        if (error[NSAppleScript.errorNumber] as? Int) == -128 { return .cancelled }
        return .failure((error[NSAppleScript.errorMessage] as? String) ?? "Unknown error.")
    }

    // MARK: - Best-effort read of the current value

    private nonisolated static func readSystemValue() -> Int? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = ["read", "com.apple.CoreBrightness", "LEBacklightMode"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        return Int(out?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }
}
