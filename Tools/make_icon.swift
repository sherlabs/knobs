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

    // Flat: graphite square, faint ring, white knob, one notch.
    let ink = rgb(0.09, 0.09, 0.11)
    let inset = s * 0.098
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    ctx.setFillColor(ink)
    squircle.fill()
    let c = CGPoint(x: s / 2, y: s / 2)

    let ringR = s * 0.315
    ctx.setStrokeColor(rgb(1, 1, 1, 0.25)); ctx.setLineWidth(s * 0.016)
    ctx.strokeEllipse(in: CGRect(x: c.x - ringR, y: c.y - ringR, width: 2 * ringR, height: 2 * ringR))

    let r = s * 0.235
    ctx.setFillColor(rgb(1, 1, 1))
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))

    ctx.setStrokeColor(ink); ctx.setLineWidth(s * 0.04); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: c.x, y: c.y + s * 0.07)); ctx.addLine(to: CGPoint(x: c.x, y: c.y + s * 0.17)); ctx.strokePath()

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
