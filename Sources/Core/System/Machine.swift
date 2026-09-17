import Foundation
import IOKit
import IOKit.ps

public enum Machine {
    public static func isPortable(model: String, hasInternalBattery: Bool, publishesClamshellState: Bool) -> Bool {
        publishesClamshellState || hasInternalBattery || model.lowercased().contains("book")
    }

    public static var isPortable: Bool {
        isPortable(
            model: hardwareModel,
            hasInternalBattery: hasInternalBattery,
            publishesClamshellState: publishesClamshellState
        )
    }

    static var publishesClamshellState: Bool {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        let state = IORegistryEntryCreateCFProperty(
            root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
        )
        return state != nil
    }

    static var hasInternalBattery: Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }
        return sources.contains { source in
            let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any]
            return description?[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
    }

    public static var hardwareModel: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &bytes, &size, nil, 0) == 0 else { return "" }
        return String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
}
