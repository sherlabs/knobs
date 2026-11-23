import SwiftUI

@main
struct KnobsApp: App {
    @StateObject private var helper: HelperClient
    @StateObject private var logo = LogoController()
    @StateObject private var touch = TouchController()
    @StateObject private var fan: FanController
    @StateObject private var updater = Updater()
    @StateObject private var monitor = MonitorController()

    init() {
        let h = HelperClient()
        _helper = StateObject(wrappedValue: h)
        _fan = StateObject(wrappedValue: FanController(helper: h))
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(helper).environmentObject(logo).environmentObject(touch)
                .environmentObject(fan).environmentObject(updater).environmentObject(monitor)
                .task { logo.helper = helper; updater.start() }
        } label: {
            Image(systemName: "dial.medium.fill").symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }
}
