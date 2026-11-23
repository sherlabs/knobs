import Foundation
import ObjectiveC
import SwiftUI

/// Mirrors "Ignore Touch Gestures" in System Settings > Accessibility > Touch (on = gestures from touch displays and Sidecar are ignored). That pane does not just write a preference: it asks
/// the system's `UASidecarTouchDisableManager`, which also tells the touch driver. Writing the
/// preference alone changes nothing on screen, so this calls the same manager (a private API,
/// looked up at run time; if it is ever missing the preference is written as a fallback).
@MainActor
final class TouchController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var error: String?

    private typealias Getter = @convention(c) (AnyObject, Selector) -> Bool
    private typealias Setter = @convention(c) (AnyObject, Selector, Bool) -> Void
    private static let getSel = NSSelectorFromString("sidecarTouchInputDisabled")
    private static let setSel = NSSelectorFromString("setSidecarTouchInputDisabled:")

    private static let manager: (obj: AnyObject, get: Getter, set: Setter)? = {
        dlopen("/System/Library/PrivateFrameworks/UniversalAccess.framework/UniversalAccess", RTLD_NOW)
        guard let cls = NSClassFromString("UASidecarTouchDisableManager"),
              let shared = (cls as AnyObject).perform(NSSelectorFromString("sharedInstance"))?.takeUnretainedValue(),
              let g = class_getMethodImplementation(cls, getSel),
              let s = class_getMethodImplementation(cls, setSel),
              class_respondsToSelector(cls, getSel), class_respondsToSelector(cls, setSel) else { return nil }
        return (shared, unsafeBitCast(g, to: Getter.self), unsafeBitCast(s, to: Setter.self))
    }()

    private static let suite = "com.apple.universalaccess"
    private static let key = "SidecarTouchInputDisabled"

    private static func readDisabled() -> Bool {
        if let m = manager { return m.get(m.obj, getSel) }
        return UserDefaults(suiteName: suite)?.bool(forKey: key) ?? false
    }

    private var watcher: Timer?

    init() { isEnabled = !Self.readDisabled() }

    /// Re-read the system value (the user may have changed it in System Settings).
    func refresh() {
        let value = !Self.readDisabled()
        if value != isEnabled { isEnabled = value }
    }

    /// Keeps the switch in step with System Settings while the popover is open.
    func startWatching() {
        refresh()
        guard watcher == nil else { return }
        watcher = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopWatching() { watcher?.invalidate(); watcher = nil }

    /// Sets an explicit state (never "flip what I last saw"), then checks that macOS applied it.
    func set(_ enabled: Bool) {
        apply(enabled)
        refresh()
        if isEnabled != enabled {          // one retry after a fresh read
            apply(enabled)
            refresh()
        }
        error = isEnabled == enabled ? nil : "macOS didn\u{2019}t apply the change. Try System Settings \u{203A} Accessibility \u{203A} Touch."
    }

    private func apply(_ enabled: Bool) {
        if let m = Self.manager {
            m.set(m.obj, Self.setSel, !enabled)
        } else {
            let d = UserDefaults(suiteName: Self.suite)
            d?.set(!enabled, forKey: Self.key); d?.synchronize()
        }
    }

    func toggle() { refresh(); set(!isEnabled) }
}
