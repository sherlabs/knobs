import Foundation
import IOKit
import IOKit.ps
import Darwin

/// One point-in-time reading of load and power. Every field is optional because
/// not every Mac exposes every counter.
public struct SystemSample: Equatable {
    public var cpuLoad: Double?          // 0...1 across all cores
    public var gpuLoad: Double?          // 0...1
    public var memoryUsed: Double?       // 0...1 of physical memory
    public var memoryPressure: MemoryPressure = .normal
    public var batteryLevel: Double?     // 0...1
    public var isCharging = false
    public var onACPower = false
    public var systemPowerWatts: Double? // whole-system draw from SMC
    public init() {}
}

public enum MemoryPressure: Int { case normal = 1, warning = 2, critical = 4 }

public final class SystemStats {
    public static let shared = SystemStats()
    private var lastTicks: [UInt32]?
    private init() {}

    public func sample() -> SystemSample {
        var s = SystemSample()
        s.cpuLoad = cpuLoad()
        s.gpuLoad = gpuLoad()
        (s.memoryUsed, s.memoryPressure) = memory()
        let b = battery()
        s.batteryLevel = b.level; s.isCharging = b.charging; s.onACPower = b.ac
        s.systemPowerWatts = SMC.shared.double("PSTR").flatMap { $0 > 0 && $0 < 400 ? $0 : nil }
        return s
    }

    // MARK: CPU

    private func cpuLoad() -> Double? {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS, let info else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)) }
        var ticks: [UInt32] = []
        for cpu in 0..<Int(count) {
            let base = cpu * Int(CPU_STATE_MAX)
            for st in [CPU_STATE_USER, CPU_STATE_SYSTEM, CPU_STATE_IDLE, CPU_STATE_NICE] {
                ticks.append(UInt32(bitPattern: info[base + Int(st)]))
            }
        }
        defer { lastTicks = ticks }
        guard let last = lastTicks, last.count == ticks.count else { return nil }
        var busy: UInt64 = 0, total: UInt64 = 0
        for i in stride(from: 0, to: ticks.count, by: 4) {
            let u = UInt64(ticks[i] &- last[i]), sy = UInt64(ticks[i + 1] &- last[i + 1])
            let id = UInt64(ticks[i + 2] &- last[i + 2]), ni = UInt64(ticks[i + 3] &- last[i + 3])
            busy += u + sy + ni; total += u + sy + id + ni
        }
        return total > 0 ? Double(busy) / Double(total) : nil
    }

    // MARK: GPU

    private func gpuLoad() -> Double? {
        var it: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &it) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(it) }
        var best: Double?
        while case let svc = IOIteratorNext(it), svc != 0 {
            defer { IOObjectRelease(svc) }
            guard let props = IORegistryEntryCreateCFProperty(svc, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] else { continue }
            if let v = (props["Device Utilization %"] as? NSNumber)?.doubleValue ?? (props["GPU Activity(%)"] as? NSNumber)?.doubleValue {
                best = max(best ?? 0, v / 100)
            }
        }
        return best
    }

    // MARK: Memory

    private func memory() -> (Double?, MemoryPressure) {
        var size = vm_size_t(0)
        host_page_size(mach_host_self(), &size)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &stats) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) } }
        var total: UInt64 = 0; var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &len, nil, 0)
        var level: Int32 = 1; var llen = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &llen, nil, 0)
        let pressure = MemoryPressure(rawValue: Int(level)) ?? .normal
        guard r == KERN_SUCCESS, total > 0 else { return (nil, pressure) }
        let used = UInt64(stats.active_count + stats.wire_count + stats.compressor_page_count) * UInt64(size)
        return (min(1, Double(used) / Double(total)), pressure)
    }

    // MARK: Battery

    private func battery() -> (level: Double?, charging: Bool, ac: Bool) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return (nil, false, false) }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            let cur = (d[kIOPSCurrentCapacityKey] as? Double) ?? Double((d[kIOPSCurrentCapacityKey] as? Int) ?? 0)
            let mx = (d[kIOPSMaxCapacityKey] as? Double) ?? Double((d[kIOPSMaxCapacityKey] as? Int) ?? 100)
            return (mx > 0 ? cur / mx : nil, (d[kIOPSIsChargingKey] as? Bool) ?? false, (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue)
        }
        return (nil, false, false)
    }
}
