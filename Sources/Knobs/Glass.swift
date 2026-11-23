import SwiftUI
import AppKit

/// Semantic, system-adaptive styling (follows light/dark and the user's accent colour).
enum Theme {
    static let warm = Color.orange
    static let hot = Color.red
}

/// Native macOS vibrancy.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material; v.blendingMode = .behindWindow; v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}

/// Grouped rounded container, like a System Settings section. Uses Liquid Glass on macOS 26+.
struct GroupBox26<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(shape.fill(.quaternary.opacity(0.6)))
                .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
        }
    }
}
