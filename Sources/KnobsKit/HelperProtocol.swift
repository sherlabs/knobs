import Foundation

public enum KnobsConstants {
    public static let appIdentifier = "com.sherlabs.knobs"
    public static let helperIdentifier = "com.sherlabs.knobs.helper"
    public static let helperPlist = "com.sherlabs.knobs.helper.plist"
    public static let machService = "com.sherlabs.knobs.helper"
    /// Bump when the helper's behaviour or protocol changes; the app re-installs a stale helper.
    public static let helperVersion = "2"
}

/// What the app may ask the root helper to do. Deliberately narrow: there is no
/// way to write an arbitrary SMC key through this interface.
@objc public protocol KnobsHelperProtocol {
    func version(reply: @escaping (String) -> Void)
    /// Manual mode, all fans, at `fraction` (0...1) of each fan's min...max range.
    func setFanFraction(_ fraction: Double, reply: @escaping (Bool) -> Void)
    func fullBlast(reply: @escaping (Bool) -> Void)
    func setAuto(reply: @escaping (Bool) -> Void)
    /// Must be sent at least every few seconds while fans are manual, or the helper reverts to auto.
    func heartbeat()
    func setLogoLight(_ on: Bool, reply: @escaping (Bool) -> Void)
}
