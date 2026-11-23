import Foundation
import Security

/// Builds code-signing requirements from the running process's own signature, so a
/// fork signed with a different Developer ID works without editing any constants.
public enum Trust {
    public static func ownTeamID() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Requirement string for a peer with `identifier`, signed by the same team as this process.
    /// nil when this process is ad-hoc signed (no team), in which case the connection must be refused.
    public static func requirement(identifier: String) -> String? {
        guard let team = ownTeamID() else { return nil }
        return "identifier \"\(identifier)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
    }
}
