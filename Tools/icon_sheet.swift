// Renders flat icon concepts side by side: swift Tools/icon_sheet.swift out.png
import AppKit

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }

func icon(_ ctx: CGContext, origin: CGPoint, s: CGFloat, style: Int) {
    ctx.saveGState()
    ctx.translateBy(x: origin.x, y: origin.y)
    let rect = CGRect(x: s * 0.098, y: s * 0.098, width: s * 0.804, height: s * 0.804)
    let path = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)
    let c = CGPoint(x: s / 2, y: s / 2)
    func ring(_ r: CGFloat, _ w: CGFloat, _ col: CGColor) { ctx.setStrokeColor(col); ctx.setLineWidth(w); ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)) }
    func disc(_ r: CGFloat, _ col: CGColor) { ctx.setFillColor(col); ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)) }
    func dot(_ deg: CGFloat, _ dist: CGFloat, _ r: CGFloat, _ col: CGColor) {
        let a = deg * .pi / 180; ctx.setFillColor(col)
        ctx.fillEllipse(in: CGRect(x: c.x + cos(a) * dist - r, y: c.y + sin(a) * dist - r, width: 2 * r, height: 2 * r))
    }
    ctx.addPath(path); ctx.clip()
    switch style {
    case 0: // A: off-white, graphite knob, single indigo dot
        ctx.setFillColor(rgb(0.95, 0.95, 0.97)); ctx.fill(rect)
        disc(s * 0.27, rgb(0.10, 0.10, 0.13))
        dot(60, s * 0.19, s * 0.035, rgb(0.55, 0.50, 1))
    case 1: // B: vivid indigo, white thick ring, white dot
        ctx.setFillColor(rgb(0.30, 0.27, 0.92)); ctx.fill(rect)
        ring(s * 0.22, s * 0.075, rgb(1, 1, 1))
        dot(60, s * 0.22, s * 0.05, rgb(1, 1, 1))
        disc(s * 0.075, rgb(1, 1, 1, 0.0))
    case 2: // C: graphite, white knob disc with ring gap and notch
        ctx.setFillColor(rgb(0.09, 0.09, 0.11)); ctx.fill(rect)
        ring(s * 0.315, s * 0.016, rgb(1, 1, 1, 0.25))
        disc(s * 0.235, rgb(1, 1, 1))
        ctx.setStrokeColor(rgb(0.09, 0.09, 0.11)); ctx.setLineWidth(s * 0.04); ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: c.x, y: c.y + s * 0.07)); ctx.addLine(to: CGPoint(x: c.x, y: c.y + s * 0.17)); ctx.strokePath()
    case 3: // D: two tone, indigo top half / graphite bottom, knob straddling
        ctx.setFillColor(rgb(0.10, 0.09, 0.20)); ctx.fill(rect)
        ctx.setFillColor(rgb(0.36, 0.32, 0.95)); ctx.fill(CGRect(x: rect.minX, y: c.y, width: rect.width, height: rect.height / 2))
        disc(s * 0.2, rgb(1, 1, 1))
        dot(90, s * 0.11, s * 0.03, rgb(0.10, 0.09, 0.20))
    default: break
    }
    ctx.restoreGState()
}

let cell: CGFloat = 400, pad: CGFloat = 20, n = 4
let W = Int(CGFloat(n) * cell + CGFloat(n + 1) * pad), H = Int(cell + 2 * pad)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
ctx.setFillColor(rgb(0.78, 0.78, 0.80)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
for i in 0..<n { icon(ctx, origin: CGPoint(x: pad + CGFloat(i) * (cell + pad), y: pad), s: cell, style: i) }
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("ok")
