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
