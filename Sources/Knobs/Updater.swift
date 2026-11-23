import Foundation
import AppKit
import CryptoKit
import Security
import KnobsKit

/// Self-update from GitHub Releases. The new build is only installed if its SHA-256 matches the
/// published checksum AND it is signed by the same Developer ID team as the running app.
@MainActor
final class Updater: ObservableObject {
    struct Release: Equatable { let version: String; let notes: String; let zip: URL; let sha: URL }
    enum State: Equatable { case idle, checking, upToDate, available(Release), working(String), failed(String) }

    static let repo = "sherlabs/knobs"
    @Published private(set) var state: State = .idle
    @Published var autoCheck: Bool = UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoCheck, forKey: "autoCheckUpdates") }
    }
    private var timer: Timer?

    var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    var hasUpdate: Bool { if case .available = state { return true }; return false }

    func start() {
        Task { try? await Task.sleep(nanoseconds: 4_000_000_000); if autoCheck { await check() } }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in if self?.autoCheck == true { await self?.check() } }
        }
    }

    func check() async {
        state = .checking
        do {
            var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("Knobs/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { state = .failed("No release information available."); return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard Self.isNewer(latest, than: currentVersion) else { state = .upToDate; return }
            let assets = (json["assets"] as? [[String: Any]]) ?? []
            func url(_ suffix: String) -> URL? {
                assets.first { ($0["name"] as? String)?.hasSuffix(suffix) == true }.flatMap { ($0["browser_download_url"] as? String).flatMap(URL.init) }
            }
            guard let zip = url("-macOS.zip"), let sha = url("-macOS.zip.sha256") else { state = .failed("Release has no download."); return }
            state = .available(Release(version: latest, notes: (json["body"] as? String) ?? "", zip: zip, sha: sha))
        } catch { state = .failed("Couldn\u{2019}t reach GitHub.") }
    }

    func install(_ release: Release) async {
        do {
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("knobs-update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

            state = .working("Downloading\u{2026}")
            let (zipTmp, _) = try await URLSession.shared.download(from: release.zip)
            let (shaData, _) = try await URLSession.shared.data(from: release.sha)

            state = .working("Verifying\u{2026}")
            let expected = String(decoding: shaData, as: UTF8.self).split(separator: " ").first.map(String.init)?.lowercased() ?? ""
            let actual = SHA256.hash(data: try Data(contentsOf: zipTmp)).map { String(format: "%02x", $0) }.joined()
            guard expected.count == 64, expected == actual else { throw Failure("The download didn\u{2019}t match its checksum.") }

            let zip = work.appendingPathComponent("Knobs.zip")
            try FileManager.default.moveItem(at: zipTmp, to: zip)
            try run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])
            let newApp = work.appendingPathComponent("Knobs.app")
            guard FileManager.default.fileExists(atPath: newApp.path) else { throw Failure("The update archive is missing Knobs.app.") }
            try verifySignature(of: newApp)

            let current = Bundle.main.bundleURL
            guard FileManager.default.isWritableFile(atPath: current.deletingLastPathComponent().path) else {
                throw Failure("Can\u{2019}t write to \(current.deletingLastPathComponent().path). Move Knobs to Applications first.")
            }
            state = .working("Installing\u{2026}")
            // Swap after this process exits, then relaunch. Paths are passed as arguments, never interpolated.
            let script = """
            while kill -0 "$1" 2>/dev/null; do sleep 0.3; done
            rm -rf "$2.old"; mv "$2" "$2.old" && mv "$3" "$2" && rm -rf "$2.old"
            xattr -dr com.apple.quarantine "$2" 2>/dev/null
            open "$2"
            """
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sh")
            p.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), current.path, newApp.path]
            try p.run()
            NSApplication.shared.terminate(nil)
        } catch let f as Failure { state = .failed(f.message) } catch { state = .failed("Update failed: \(error.localizedDescription)") }
    }

    // MARK: helpers

    private struct Failure: Error { let message: String; init(_ m: String) { message = m } }

    private func run(_ tool: String, _ args: [String]) throws {
        let p = Process(); p.executableURL = URL(fileURLWithPath: tool); p.arguments = args
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw Failure("Couldn\u{2019}t unpack the update.") }
    }

    /// The new app must be validly signed by our own Developer ID team under our bundle identifier.
    private func verifySignature(of app: URL) throws {
        guard let req = Trust.requirement(identifier: KnobsConstants.appIdentifier) else {
            throw Failure("This build can\u{2019}t verify updates (it isn\u{2019}t Developer ID signed).")
        }
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(req as CFString, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode), requirement) == errSecSuccess
        else { throw Failure("The update isn\u{2019}t signed by the expected developer.") }
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
