import SwiftUI

@main
struct KnobsApp: App {
    @StateObject private var helper: HelperClient
    @StateObject private var logo: LogoController
    @StateObject private var touch = TouchController()
    @StateObject private var fan: FanController
    @StateObject private var updater = Updater()
    @StateObject private var monitor = MonitorController()

    init() {
        if CommandLine.arguments.contains("--diagnose") {
            import_diagnose()
        }
        let h = HelperClient()
        let l = LogoController()
        l.helper = h
        _helper = StateObject(wrappedValue: h)
        _logo = StateObject(wrappedValue: l)
        _fan = StateObject(wrappedValue: FanController(helper: h))
        DispatchQueue.main.async { h.firstLaunchSetup() }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(helper).environmentObject(logo).environmentObject(touch)
                .environmentObject(fan).environmentObject(updater).environmentObject(monitor)
                .task { updater.start() }
        } label: {
            Image(systemName: "dial.medium.fill").symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }
}

import ServiceManagement
import KnobsKit

/// `Knobs --diagnose`: print the helper's registration state, then exit. For support and debugging.
func import_diagnose() {
    let svc = SMAppService.daemon(plistName: KnobsConstants.helperPlist)
    print("bundle:", Bundle.main.bundlePath)
    print("team:", Trust.ownTeamID() ?? "none")
    print("daemon status:", svc.status.rawValue, "(0 notRegistered, 1 enabled, 2 requiresApproval, 3 notFound)")
    if CommandLine.arguments.contains("--register") {
        do { try svc.register(); print("register: ok") } catch { print("register error:", error, (error as NSError).domain, (error as NSError).code) }
        print("status after:", svc.status.rawValue)
    }
    print("plist exists:", FileManager.default.fileExists(atPath: Bundle.main.bundlePath + "/Contents/Library/LaunchDaemons/" + KnobsConstants.helperPlist))
    exit(0)
}
