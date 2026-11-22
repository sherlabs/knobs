import Foundation
import SwiftUI

/// Mirrors the "Touch" pane in System Settings, which stores a per-user flag
/// (`SidecarTouchInputDisabled` in `com.apple.universalaccess`). No admin rights needed.
@MainActor
final class TouchController: ObservableObject {
    @Published private(set) var isEnabled: Bool

    private static let suite = "com.apple.universalaccess"
    private static let key = "SidecarTouchInputDisabled"
    private let defaults = UserDefaults(suiteName: TouchController.suite)

    init() {
        let disabled = UserDefaults(suiteName: Self.suite)?.bool(forKey: Self.key) ?? false
        isEnabled = !disabled
    }

    /// Re-read the system value (the user may have changed it in System Settings).
    func refresh() {
        defaults?.synchronize()
        isEnabled = !(defaults?.bool(forKey: Self.key) ?? false)
    }

    func set(_ enabled: Bool) {
        defaults?.set(!enabled, forKey: Self.key)
        defaults?.synchronize()
        refresh()
    }

    func toggle() { set(!isEnabled) }
}
