// Renders the popover UI to Assets/ui-preview.png and exports the icon.
// Usage: swift Tools/render/main.swift Sources/GlowBar/PopoverView.swift Sources/GlowBar/LogoController.swift
import SwiftUI
import AppKit

@MainActor
func run() {
    let fm = FileManager.default
    try? fm.createDirectory(atPath: "Assets", withIntermediateDirectories: true)

    // Icon
    let src = "build/AppIcon.iconset/icon_512x512@2x.png"
    try? fm.removeItem(atPath: "Assets/AppIcon.png")
    try? fm.copyItem(atPath: src, toPath: "Assets/AppIcon.png")

    for (name, on) in [("ui-on", true), ("ui-off", false)] {
        UserDefaults.standard.set(on, forKey: "logoIsOn")
        let logo = LogoController()
        let content = PopoverView()
            .environmentObject(logo)
            .environment(\.colorScheme, .dark)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .padding(40)
            .background(
                LinearGradient(colors: [Color(red: 0.10, green: 0.08, blue: 0.30),
                                        Color(red: 0.25, green: 0.45, blue: 0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing))
        let r = ImageRenderer(content: content)
        r.scale = 2
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "Assets/\(name).png"))
            print("wrote Assets/\(name).png")
        }
    }
}
MainActor.assumeIsolated { run() }
