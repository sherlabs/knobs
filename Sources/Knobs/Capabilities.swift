import Foundation
import IOKit

/// Which optional hardware this Mac has. The backlit Apple logo and the touch display exist only on
/// the PROLED XDR MacBook Pro, which identifies itself in the platform's `product-name`.
enum Capabilities {
    static let productName: String = {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        guard entry != 0 else { return "" }
        defer { IOObjectRelease(entry) }
        guard let raw = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data else { return "" }
        return String(decoding: raw.filter { $0 != 0 }, as: UTF8.self)
    }()

    static let isProLED = productName.localizedCaseInsensitiveContains("PROLED")
    static let hasLogoLight = isProLED
    static let hasTouchDisplay = isProLED
}
