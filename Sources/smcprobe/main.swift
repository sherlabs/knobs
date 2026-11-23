import Foundation
import CSMC

// Read-only probe: what does this Mac's SMC expose for fans and temperatures?
func code(_ v: UInt32) -> String {
    String(bytes: [UInt8(v >> 24 & 255), UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255)], encoding: .ascii) ?? "????"
}
func decode(_ v: CSMCValue) -> String {
    var b = v.bytes
    let t = code(v.dataType), n = Int(v.dataSize)
    return withUnsafeBytes(of: &b) { p -> String in
        switch t {
        case "flt ": return n == 4 ? String(p.loadUnaligned(as: Float.self)) : "?"
        case "ui8 ": return String(p[0])
        case "ui16": return String(UInt16(p[0]) << 8 | UInt16(p[1]))
        case "ui32": return String(UInt32(p[0]) << 24 | UInt32(p[1]) << 16 | UInt32(p[2]) << 8 | UInt32(p[3]))
        case "fpe2": return String(Double(UInt16(p[0]) << 8 | UInt16(p[1])) / 4)
        case "sp78": return String(Double(Int16(bitPattern: UInt16(p[0]) << 8 | UInt16(p[1]))) / 256)
        default: return "0x" + (0..<n).map { String(format: "%02x", p[$0]) }.joined()
        }
    }
}

let r = csmc_open()
guard r == 0 else { print("open failed: \(r)"); exit(1) }
defer { csmc_close() }

var count: UInt32 = 0
print("#KEY read: \(csmc_key_count(&count)) count=\(count)")

func show(_ k: String) {
    var v = CSMCValue()
    let rc = csmc_read(k, &v)
    print(rc == 0 ? "\(k)  type=\(code(v.dataType)) size=\(v.dataSize) value=\(decode(v))" : "\(k)  <unavailable rc=\(rc)>")
}
for k in ["FNum", "Ftst", "F0Ac", "F0Mn", "F0Mx", "F0Tg", "F0md", "F1Ac", "F1Mn", "F1Mx", "F1Tg", "F1md", "F0Rn", "F0Rs", "F0St"] { show(k) }

// Discover keys by prefix instead of assuming a sensor table.
var fans: [String] = [], temps: [String] = []
var name = [CChar](repeating: 0, count: 5)
for i in 0..<count where csmc_key_at(i, &name) == 0 {
    let k = String(cString: name)
    if k.hasPrefix("F") && k.count == 4 && k.dropFirst().first?.isNumber == true { fans.append(k) }
    if k.hasPrefix("T") { temps.append(k) }
}
print("fan-ish keys: \(fans.joined(separator: " "))")
print("temp keys: \(temps.count)")
let want = CommandLine.arguments.contains("--all-temps")
var byPrefix: [String: Int] = [:]
for k in temps { byPrefix[String(k.prefix(2)), default: 0] += 1 }
print("prefix counts: \(byPrefix.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))")
for k in (want ? temps : Array(temps.prefix(0))) { show(k) }

// ---- Optional write test: sudo .build/debug/smcprobe --write-test ----
// Sets BOTH fans to a moderate manual target for ~12 s, prints RPM, then returns them to auto.
// Always restores auto on exit, on Ctrl-C and on error.
if CommandLine.arguments.contains("--write-test") {
    guard geteuid() == 0 else { print("\nwrite test needs root: sudo .build/debug/smcprobe --write-test"); exit(2) }
    func setFloatLE(_ k: String, _ x: Float) -> Int32 {
        // SMC "flt " values are stored in native (little-endian) byte order on Apple Silicon.
        let b = withUnsafeBytes(of: x) { Array($0) }
        return csmc_write(k, b, 4)
    }
    func rpm(_ k: String) -> Float { var v = CSMCValue(); _ = csmc_read(k, &v); var b = v.bytes; return withUnsafeBytes(of: &b) { $0.loadUnaligned(as: Float.self) } }
    func auto() { for m in ["F0md", "F1md"] { _ = csmc_write(m, [0], 1) } }
    signal(SIGINT) { _ in
        for m in ["F0md", "F1md"] { _ = csmc_write(m, [0], 1) }
        print("\nrestored auto"); exit(130)
    }
    print("\n== write test: manual 4500 RPM for 12 s, then auto ==")
    for (i, mode) in ["F0md", "F1md"].enumerated() {
        let a = csmc_write(mode, [1], 1)
        let b = setFloatLE("F\(i)Tg", 4500)
        print("fan \(i): mode write rc=\(a), target write rc=\(b)")
    }
    for s in 0..<12 {
        sleep(1)
        print("t=\(s + 1)s  fan0=\(Int(rpm("F0Ac"))) rpm  fan1=\(Int(rpm("F1Ac"))) rpm")
    }
    auto()
    print("restored auto; watching RPM fall back:")
    for s in 0..<8 { sleep(1); print("t=\(s + 1)s  fan0=\(Int(rpm("F0Ac"))) rpm  fan1=\(Int(rpm("F1Ac"))) rpm") }
}
