// Generates the Knobs app icon as an .iconset folder.
// Usage: swift Tools/make_icon.swift <output.iconset>
import AppKit

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let cs = CGColorSpaceCreateDeviceRGB()

    // macOS icon grid: squircle inset ~10%
    let inset = s * 0.098
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill(); squircle.fill()
    ctx.restoreGState()

    ctx.saveGState()
    squircle.addClip()

    // Background gradient: deep indigo -> violet -> cyan hint
    let bg = CGGradient(colorsSpace: cs, colors: [
        NSColor(red: 0.07, green: 0.06, blue: 0.20, alpha: 1).cgColor,
        NSColor(red: 0.30, green: 0.16, blue: 0.62, alpha: 1).cgColor,
        NSColor(red: 0.16, green: 0.50, blue: 0.85, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 0.6, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY), options: [])

    let c = CGPoint(x: s / 2, y: s / 2)

    // Big soft halo
    let halo = CGGradient(colorsSpace: cs, colors: [
        NSColor(red: 0.85, green: 0.95, blue: 1, alpha: 0.95).cgColor,
        NSColor(red: 0.55, green: 0.80, blue: 1, alpha: 0.45).cgColor,
        NSColor(red: 0.50, green: 0.55, blue: 1, alpha: 0.12).cgColor,
        NSColor(white: 1, alpha: 0).cgColor,
    ] as CFArray, locations: [0, 0.35, 0.7, 1])!
    ctx.drawRadialGradient(halo, startCenter: c, startRadius: 0, endCenter: c, endRadius: s * 0.46, options: [])

    // Glass disc
    let r = s * 0.25
    let disc = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.015), blur: s * 0.05,
                  color: NSColor.black.withAlphaComponent(0.3).cgColor)
    // Orb lit from within: white core, cool cyan-blue edge
    let glass = CGGradient(colorsSpace: cs, colors: [
        NSColor(white: 1, alpha: 1).cgColor,
        NSColor(red: 0.80, green: 0.93, blue: 1, alpha: 1).cgColor,
        NSColor(red: 0.45, green: 0.68, blue: 1, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 0.55, 1])!
    ctx.addEllipse(in: disc); ctx.clip()
    let core = CGPoint(x: c.x - r * 0.1, y: c.y + r * 0.15)
    ctx.drawRadialGradient(glass, startCenter: core, startRadius: 0, endCenter: c, endRadius: r * 1.05, options: [])
    // Specular highlight
    let spec = CGGradient(colorsSpace: cs, colors: [
        NSColor(white: 1, alpha: 0.9).cgColor, NSColor(white: 1, alpha: 0).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(spec, start: CGPoint(x: c.x, y: disc.maxY),
                           end: CGPoint(x: c.x, y: c.y + r * 0.2), options: [])
    ctx.restoreGState()

    // Glass rim
    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.9).cgColor)
    ctx.setLineWidth(s * 0.006)
    ctx.strokeEllipse(in: disc.insetBy(dx: s * 0.003, dy: s * 0.003))

    // Tick arc around the knob (270 degrees, open at the bottom)
    let ticks = 21
    let tickR = s * 0.335
    for i in 0..<ticks {
        let t = CGFloat(i) / CGFloat(ticks - 1)
        let a = (225 - 270 * t) * .pi / 180            // from lower-left, clockwise over the top
        let lit = t <= 0.68
        let len = (i % 5 == 0 ? s * 0.035 : s * 0.022)
        let p1 = CGPoint(x: c.x + cos(a) * tickR, y: c.y + sin(a) * tickR)
        let p2 = CGPoint(x: c.x + cos(a) * (tickR + len), y: c.y + sin(a) * (tickR + len))
        ctx.setLineCap(.round)
        ctx.setLineWidth(s * 0.009)
        ctx.setStrokeColor(lit ? NSColor(red: 0.62, green: 0.92, blue: 1, alpha: 0.95).cgColor : NSColor(white: 1, alpha: 0.28).cgColor)
        if lit { ctx.setShadow(offset: .zero, blur: s * 0.012, color: NSColor.cyan.withAlphaComponent(0.9).cgColor) } else { ctx.setShadow(offset: .zero, blur: 0, color: nil) }
        ctx.move(to: p1); ctx.addLine(to: p2); ctx.strokePath()
    }
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Indicator notch on the knob, pointing at the last lit tick
    let na = (225 - 270 * 0.68) * .pi / 180
    let n1 = CGPoint(x: c.x + cos(na) * r * 0.30, y: c.y + sin(na) * r * 0.30)
    let n2 = CGPoint(x: c.x + cos(na) * r * 0.80, y: c.y + sin(na) * r * 0.80)
    ctx.setLineCap(.round)
    ctx.setLineWidth(s * 0.022)
    ctx.setStrokeColor(NSColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1).cgColor)
    ctx.setShadow(offset: .zero, blur: s * 0.02, color: NSColor(red: 0.2, green: 0.6, blue: 1, alpha: 0.9).cgColor)
    ctx.move(to: n1); ctx.addLine(to: n2); ctx.strokePath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Top gloss on the squircle
    let gloss = CGGradient(colorsSpace: cs, colors: [
        NSColor(white: 1, alpha: 0.28).cgColor,
        NSColor(white: 1, alpha: 0).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gloss, start: CGPoint(x: s / 2, y: rect.maxY),
                           end: CGPoint(x: s / 2, y: rect.midY), options: [])
    ctx.restoreGState()

    // Rim light on the squircle edge
    ctx.saveGState()
    squircle.addClip()
    NSColor(white: 1, alpha: 0.25).setStroke()
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
