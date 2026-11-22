import SwiftUI

@main
struct GlowBarApp: App {
    @StateObject private var logo = LogoController()
    @StateObject private var touch = TouchController()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(logo)
                .environmentObject(touch)
        } label: {
            Image(systemName: logo.isOn ? "apple.logo" : "apple.logo")
                .symbolRenderingMode(.hierarchical)
                .opacity(logo.isOn ? 1.0 : 0.45)
        }
        .menuBarExtraStyle(.window)
    }
}
