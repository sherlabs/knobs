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

/// Grouped rounded container, like a System Settings section.
struct GroupBox26<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        content
            .background(shape.fill(Color.primary.opacity(0.06)))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
    }
}

extension View {
    /// The one grouped surface used for stats, switches and the setup prompt.
    func surface() -> some View { GroupBox26 { self } }
}
