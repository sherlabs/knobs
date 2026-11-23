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
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            let out = CommandLine.arguments[i + 1]
            DispatchQueue.main.async { Snapshot.render(to: out) }
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
            Image(nsImage: MenuBarIcon.image)
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


/// The app icon as a menu bar template: a ring, a solid knob and its notch. macOS tints it for light and dark.
enum MenuBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            let c = CGPoint(x: rect.midX, y: rect.midY)
            NSColor.black.setStroke()
            let ring = NSBezierPath(ovalIn: CGRect(x: c.x - 8, y: c.y - 8, width: 16, height: 16))
            ring.lineWidth = 1.2
            ring.stroke()
            NSColor.black.setFill()
            NSBezierPath(ovalIn: CGRect(x: c.x - 5.2, y: c.y - 5.2, width: 10.4, height: 10.4)).fill()
            // notch: knocked out of the knob
            NSGraphicsContext.current?.compositingOperation = .clear
            let notch = NSBezierPath()
            notch.move(to: CGPoint(x: c.x, y: c.y + 1.2)); notch.line(to: CGPoint(x: c.x, y: c.y + 4.2))
            notch.lineWidth = 1.6; notch.lineCapStyle = .round
            notch.stroke()
            return true
        }
        img.isTemplate = true
        return img
    }()
}


/// Developer aid: `Knobs --snapshot out` writes out-light.png and out-dark.png of the popover, then quits.
@MainActor
enum Snapshot {
    static func render(to base: String) {
        let helper = HelperClient()
        let logo = LogoController(); logo.helper = helper
        let fan = FanController(helper: helper)
        let monitor = MonitorController()
        helper.refresh(); monitor.start(); fan.startPolling()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let view = PopoverView()
                    .environmentObject(helper).environmentObject(logo).environmentObject(TouchController())
                    .environmentObject(fan).environmentObject(Updater()).environmentObject(monitor)
                    .background(Color(nsColor: .windowBackgroundColor))
                let host = NSHostingView(rootView: view)
                host.appearance = NSAppearance(named: appearance)
                let size = host.fittingSize
                host.frame = NSRect(origin: .zero, size: size)
                let win = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                win.appearance = NSAppearance(named: appearance)
                win.contentView = host
                win.orderFrontRegardless()
                host.layoutSubtreeIfNeeded()
                if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(base)-\(name).png"))
                }
                win.orderOut(nil)
            }
            NSApplication.shared.terminate(nil)
        }
    }
}
