// Generates the Knobs app icon as an .iconset folder.
// Usage: swift Tools/make_icon.swift <output.iconset>
import AppKit

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let cs = CGColorSpaceCreateDeviceRGB()

    // macOS icon grid
    let inset = s * 0.098
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    let c = CGPoint(x: s / 2, y: s / 2)

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.014), blur: s * 0.035, color: rgb(0, 0, 0, 0.4))
    NSColor.black.setFill(); squircle.fill()
    ctx.restoreGState()

    ctx.saveGState()
    squircle.addClip()

    // Background: midnight navy to deep violet, lit from below
    let bg = CGGradient(colorsSpace: cs, colors: [rgb(0.03, 0.04, 0.14), rgb(0.12, 0.08, 0.34), rgb(0.20, 0.12, 0.50)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: s / 2, y: rect.maxY), end: CGPoint(x: s / 2, y: rect.minY), options: [])
    let under = CGGradient(colorsSpace: cs, colors: [rgb(0.25, 0.55, 1, 0.45), rgb(0.25, 0.55, 1, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(under, startCenter: CGPoint(x: c.x, y: rect.minY + s * 0.02), startRadius: 0,
                           endCenter: CGPoint(x: c.x, y: rect.minY + s * 0.02), endRadius: s * 0.55, options: [])

    // Arc geometry: 270 degrees, open at the bottom
    let arcR = s * 0.335
    let arcW = s * 0.034
    let startDeg: CGFloat = 225, sweep: CGFloat = 270
    func point(_ deg: CGFloat, _ r: CGFloat) -> CGPoint {
        CGPoint(x: c.x + cos(deg * .pi / 180) * r, y: c.y + sin(deg * .pi / 180) * r)
    }
    func arcSegment(from t0: CGFloat, to t1: CGFloat, color: CGColor, width: CGFloat) {
        let path = CGMutablePath()
        path.addArc(center: c, radius: arcR, startAngle: (startDeg - sweep * t0) * .pi / 180,
                    endAngle: (startDeg - sweep * t1) * .pi / 180, clockwise: true)
        ctx.addPath(path)
        ctx.setStrokeColor(color); ctx.setLineWidth(width); ctx.setLineCap(.round)
        ctx.strokePath()
    }

    // Unlit track
    arcSegment(from: 0, to: 1, color: rgb(1, 1, 1, 0.10), width: arcW)

    // Lit portion: glowing gradient (cyan -> blue -> violet -> pink)
    let level: CGFloat = 0.72
    let stops: [(CGFloat, CGFloat, CGFloat)] = [(0.30, 0.90, 1.0), (0.30, 0.55, 1.0), (0.62, 0.40, 1.0), (0.95, 0.45, 0.90)]
    func lerp(_ t: CGFloat) -> CGColor {
        let f = t * CGFloat(stops.count - 1), i = min(Int(f), stops.count - 2), u = f - CGFloat(i)
        let a = stops[i], b = stops[i + 1]
        return rgb(a.0 + (b.0 - a.0) * u, a.1 + (b.1 - a.1) * u, a.2 + (b.2 - a.2) * u)
    }
    // Glow pass then crisp pass
    for pass in 0..<2 {
        ctx.saveGState()
        if pass == 0 { ctx.setShadow(offset: .zero, blur: s * 0.05, color: rgb(0.35, 0.65, 1, 0.9)) }
        let n = 90
        for k in 0..<n {
            let t0 = level * CGFloat(k) / CGFloat(n), t1 = level * CGFloat(k + 1) / CGFloat(n) + 0.002
            arcSegment(from: t0, to: t1, color: lerp(CGFloat(k) / CGFloat(n)), width: pass == 0 ? arcW * 1.1 : arcW)
        }
        ctx.restoreGState()
    }

    // Knob: bezel ring
    let rOuter = s * 0.255
    let bezel = CGRect(x: c.x - rOuter, y: c.y - rOuter, width: 2 * rOuter, height: 2 * rOuter)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.05, color: rgb(0, 0, 0, 0.55))
    ctx.addEllipse(in: bezel); ctx.setFillColor(rgb(0.1, 0.1, 0.2)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addEllipse(in: bezel); ctx.clip()
    let bez = CGGradient(colorsSpace: cs, colors: [rgb(0.95, 0.97, 1), rgb(0.55, 0.62, 0.85), rgb(0.18, 0.20, 0.40), rgb(0.60, 0.68, 0.95)] as CFArray, locations: [0, 0.4, 0.75, 1])!
    ctx.drawLinearGradient(bez, start: CGPoint(x: bezel.minX, y: bezel.maxY), end: CGPoint(x: bezel.maxX, y: bezel.minY), options: [])
    ctx.restoreGState()

    // Knob: concave glass face
    let rFace = rOuter * 0.86
    let face = CGRect(x: c.x - rFace, y: c.y - rFace, width: 2 * rFace, height: 2 * rFace)
    ctx.saveGState()
    ctx.addEllipse(in: face); ctx.clip()
    let faceG = CGGradient(colorsSpace: cs, colors: [rgb(0.86, 0.93, 1), rgb(0.62, 0.78, 1), rgb(0.36, 0.50, 0.92)] as CFArray, locations: [0, 0.6, 1])!
    ctx.drawRadialGradient(faceG, startCenter: CGPoint(x: c.x - rFace * 0.25, y: c.y + rFace * 0.3), startRadius: 0,
                           endCenter: c, endRadius: rFace * 1.15, options: [.drawsAfterEndLocation])
    // inner shadow along the top edge to read as concave
    let inner = CGGradient(colorsSpace: cs, colors: [rgb(0.1, 0.15, 0.5, 0.35), rgb(0.1, 0.15, 0.5, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(inner, start: CGPoint(x: c.x, y: face.maxY), end: CGPoint(x: c.x, y: c.y + rFace * 0.2), options: [])
    // lower rim light
    let rim = CGGradient(colorsSpace: cs, colors: [rgb(1, 1, 1, 0.55), rgb(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(rim, start: CGPoint(x: c.x, y: face.minY), end: CGPoint(x: c.x, y: c.y - rFace * 0.35), options: [])
    ctx.restoreGState()

    // Indicator: glowing capsule toward the lit end of the arc
    let indDeg = startDeg - sweep * level
    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setShadow(offset: .zero, blur: s * 0.03, color: rgb(0.3, 0.6, 1, 0.9))
    ctx.setStrokeColor(rgb(0.16, 0.34, 0.9))
    ctx.setLineWidth(s * 0.026)
    ctx.move(to: point(indDeg, rFace * 0.42)); ctx.addLine(to: point(indDeg, rFace * 0.82)); ctx.strokePath()
    ctx.restoreGState()

    // Specular highlight arc on the bezel
    ctx.saveGState()
    ctx.addEllipse(in: bezel); ctx.clip()
    ctx.setStrokeColor(rgb(1, 1, 1, 0.85)); ctx.setLineWidth(s * 0.006); ctx.setLineCap(.round)
    let hl = CGMutablePath()
    hl.addArc(center: c, radius: rOuter * 0.965, startAngle: 120 * .pi / 180, endAngle: 175 * .pi / 180, clockwise: false)
    ctx.addPath(hl); ctx.strokePath()
    ctx.restoreGState()

    // Glass sheen on the squircle
    let gloss = CGGradient(colorsSpace: cs, colors: [rgb(1, 1, 1, 0.22), rgb(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gloss, start: CGPoint(x: s / 2, y: rect.maxY), end: CGPoint(x: s / 2, y: rect.midY + s * 0.05), options: [])
    ctx.restoreGState()

    // Edge light
    ctx.saveGState()
    squircle.addClip()
    NSColor(white: 1, alpha: 0.28).setStroke()
    squircle.lineWidth = s * 0.006
    squircle.stroke()
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count > 1 else {
    print("usage: make_icon.swift <output.iconset>"); exit(1)
}
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.removeItem(at: out)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in entries {
    try render(size: px).write(to: out.appendingPathComponent("\(name).png"))
}
print("Wrote \(out.path)")
