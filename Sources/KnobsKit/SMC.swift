import Foundation
import CSMC

public struct FanReading: Equatable, Identifiable {
    public let index: Int
    public let actual: Double
    public let minimum: Double
    public let maximum: Double
    public let target: Double
    public let isManual: Bool
    public var id: Int { index }
    /// 0...1 position of the current speed within the fan's range.
    public var fraction: Double { maximum > minimum ? min(1, max(0, (actual - minimum) / (maximum - minimum))) : 0 }
}

public struct TemperatureSummary: Equatable {
    public var cpu: Double?
    public var gpu: Double?
    public var memory: Double?
    public var battery: Double?
    public var ambient: Double?
    public init() {}
}

/// Thin, thread-safe Swift layer over the AppleSMC user client.
public final class SMC {
    public static let shared = SMC()
    private let lock = NSLock()
    private var opened = false
    private var groups: [String: [String]]?

    private init() {}

    @discardableResult
    public func open() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if opened { return true }
        opened = csmc_open() == 0
        return opened
    }

    // MARK: raw reads / writes

    public func rawRead(_ key: String) -> CSMCValue? {
        lock.lock(); defer { lock.unlock() }
        guard opened else { return nil }
        var v = CSMCValue()
        return csmc_read(key, &v) == 0 ? v : nil
    }

    public func double(_ key: String) -> Double? {
        guard var v = rawRead(key) else { return nil }
        var b = v.bytes
        let type = Self.code(v.dataType)
        return withUnsafeBytes(of: &b) { p -> Double? in
            switch type {
            case "flt ": return Double(p.loadUnaligned(as: Float.self))
            case "ui8 ": return Double(p[0])
            case "ui16": return Double(UInt16(p[0]) << 8 | UInt16(p[1]))
            case "ui32": return Double(UInt32(p[0]) << 24 | UInt32(p[1]) << 16 | UInt32(p[2]) << 8 | UInt32(p[3]))
            case "sp78": return Double(Int16(bitPattern: UInt16(p[0]) << 8 | UInt16(p[1]))) / 256
            case "fpe2": return Double(UInt16(p[0]) << 8 | UInt16(p[1])) / 4
            default: return nil
            }
        }
    }

    /// Writes require root. Returns true on success.
    @discardableResult
    public func writeFloat(_ key: String, _ value: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard opened else { return false }
        let bytes = withUnsafeBytes(of: Float(value)) { Array($0) }   // native (little-endian) float
        return csmc_write(key, bytes, 4) == 0
    }

    @discardableResult
    public func writeUInt8(_ key: String, _ value: UInt8) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard opened else { return false }
        return csmc_write(key, [value], 1) == 0
    }

    static func code(_ v: UInt32) -> String {
        String(bytes: [UInt8(v >> 24 & 255), UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255)], encoding: .ascii) ?? ""
    }

    // MARK: fans

    public func fanCount() -> Int { Int(double("FNum") ?? 0) }

    /// The mode key is `F<n>md` on current macOS, `F<n>Md` on older releases.
    func modeKey(_ i: Int) -> String { rawRead("F\(i)md") != nil ? "F\(i)md" : "F\(i)Md" }

    public func fans() -> [FanReading] {
        (0..<fanCount()).compactMap { i in
            guard let actual = double("F\(i)Ac"), let lo = double("F\(i)Mn"), let hi = double("F\(i)Mx") else { return nil }
            return FanReading(index: i, actual: actual, minimum: lo, maximum: hi,
                              target: double("F\(i)Tg") ?? actual,
                              isManual: (double(modeKey(i)) ?? 0) != 0)
        }
    }

    // MARK: fan control (root only)

    /// Manual mode at `fraction` (0...1) of each fan's own range.
    @discardableResult
    public func setManual(fraction: Double) -> Bool {
        let f = min(1, max(0, fraction))
        var ok = true
        for fan in fans() {
            let rpm = fan.minimum + f * (fan.maximum - fan.minimum)
            ok = writeUInt8(modeKey(fan.index), 1) && writeFloat("F\(fan.index)Tg", rpm) && ok
        }
        return ok
    }

    @discardableResult
    public func setAuto() -> Bool {
        var ok = true
        for i in 0..<fanCount() { ok = writeUInt8(modeKey(i), 0) && ok }
        return ok
    }

    // MARK: temperatures

    private func discoverGroups() -> [String: [String]] {
        if let g = groups { return g }
        var result: [String: [String]] = ["cpu": [], "gpu": [], "mem": [], "batt": [], "amb": []]
        lock.lock()
        var count: UInt32 = 0
        var keys: [String] = []
        if opened, csmc_key_count(&count) == 0 {
            var name = [CChar](repeating: 0, count: 5)
            for i in 0..<count where csmc_key_at(i, &name) == 0 {
                let k = String(cString: name)
                if k.hasPrefix("T") { keys.append(k) }
            }
        }
        lock.unlock()
        for k in keys {
            if k.hasPrefix("Tp") { result["cpu"]!.append(k) }
            else if k.hasPrefix("Tg") { result["gpu"]!.append(k) }
            else if k.hasPrefix("Tm") { result["mem"]!.append(k) }
            else if k.hasPrefix("TB") { result["batt"]!.append(k) }
            else if k.hasPrefix("TA") { result["amb"]!.append(k) }
        }
        groups = result
        return result
    }

    private func hottest(_ keys: [String]) -> Double? {
        keys.compactMap { double($0) }.filter { $0 > 0 && $0 < 150 }.max()
    }

    public func temperatures() -> TemperatureSummary {
        let g = discoverGroups()
        var t = TemperatureSummary()
        t.cpu = hottest(g["cpu"] ?? [])
        t.gpu = hottest(g["gpu"] ?? [])
        t.memory = hottest(g["mem"] ?? [])
        t.battery = hottest(g["batt"] ?? [])
        t.ambient = hottest(g["amb"] ?? [])
        return t
    }
}
