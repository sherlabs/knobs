import SwiftUI

/// Shared glassmorphism pieces.
struct GlassBackground: View {
    var body: some View {
        ZStack {
            // Neutral graphite, a touch lighter at the top like light catching glass
            LinearGradient(colors: [Color(white: 0.20).opacity(0.55), Color(white: 0.07).opacity(0.65)],
                           startPoint: .top, endPoint: .bottom)
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.04)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            )
    }
}

/// Capsule switch with a glass track.
struct GlassSwitch: View {
    let isOn: Bool
    var busy = false
    var large = false
    let action: () -> Void

    var body: some View {
        let h: CGFloat = large ? 40 : 26, w: CGFloat = large ? 84 : 48
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(LinearGradient(
                        colors: isOn ? [.white.opacity(0.82), .white.opacity(0.68)] : [.white.opacity(0.08), .white.opacity(0.02)],
                        startPoint: .leading, endPoint: .trailing)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                Circle().fill(isOn ? Color(white: 0.16) : Color.white.opacity(0.9)).shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .overlay { if busy { ProgressView().controlSize(.small) } }
                    .padding(3).frame(width: h, height: h)
            }
            .frame(width: w, height: h)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isOn)
        }
        .buttonStyle(.plain).disabled(busy)
    }
}

/// Glass segmented control used for tabs and fan modes.
struct GlassSegments<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    let label: (T) -> String
    var icon: ((T) -> String)? = nil
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let on = item == selection
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = item } } label: {
                    HStack(spacing: 5) {
                        if let icon { Image(systemName: icon(item)).font(.system(size: 11, weight: .semibold)) }
                        Text(label(item)).font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .foregroundStyle(on ? Color.white : Color.white.opacity(0.55))
                    .background {
                        if on {
                            Capsule().fill(.white.opacity(0.18))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                                .matchedGeometryEffect(id: "pill", in: ns)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(.black.opacity(0.18)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

struct GlassButton: View {
    let title: String
    var icon: String? = nil
    var prominent = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .semibold)) }
                Text(title).font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundStyle(prominent ? Color(white: 0.1) : Color.white)
            .background(Capsule().fill(prominent ? Color.white.opacity(0.9) : Color.white.opacity(0.12)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
