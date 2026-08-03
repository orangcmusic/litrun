import Foundation
import IOKit

enum LidState {
    case open
    case closed
    case unknown
}

enum LidStateReader {
    static func current() -> LidState {
        guard let matching = IOServiceMatching("IOPMrootDomain") else {
            return .unknown
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != IO_OBJECT_NULL else {
            return .unknown
        }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return .unknown
        }

        if let value = property as? Bool {
            return value ? .closed : .open
        }
        if let value = property as? NSNumber {
            return value.boolValue ? .closed : .open
        }
        return .unknown
    }
}
