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

    // Flat palette
    let ink = rgb(0.067, 0.071, 0.133)        // #111222 background
    let white = rgb(1, 1, 1)
    let accent = rgb(0.24, 0.86, 1.0)         // #3DDBFF
    let track = rgb(1, 1, 1, 0.14)

    // macOS icon grid, flat squircle
    let inset = s * 0.098
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    ctx.setFillColor(ink)
    squircle.fill()
    let c = CGPoint(x: s / 2, y: s / 2)

    // Arc: 270 degrees, open at the bottom
    let arcR = s * 0.315
    let arcW = s * 0.05
    let startDeg: CGFloat = 225, sweep: CGFloat = 270
    func arc(to t: CGFloat, color: CGColor) {
        let path = CGMutablePath()
        path.addArc(center: c, radius: arcR, startAngle: startDeg * .pi / 180,
                    endAngle: (startDeg - sweep * t) * .pi / 180, clockwise: true)
        ctx.addPath(path)
        ctx.setStrokeColor(color); ctx.setLineWidth(arcW); ctx.setLineCap(.round)
        ctx.strokePath()
    }
    arc(to: 1, color: track)
    let level: CGFloat = 0.7
    arc(to: level, color: accent)

    // Knob: a plain white disc
    let r = s * 0.205
    ctx.setFillColor(white)
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))

    // Indicator notch in the ink colour, pointing at the end of the lit arc
    let a = (startDeg - sweep * level) * .pi / 180
    ctx.setStrokeColor(ink); ctx.setLineWidth(s * 0.036); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: c.x + cos(a) * r * 0.30, y: c.y + sin(a) * r * 0.30))
    ctx.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.74, y: c.y + sin(a) * r * 0.74))
    ctx.strokePath()

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
