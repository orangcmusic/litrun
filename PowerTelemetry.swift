import Foundation
import IOKit

enum PowerReadingSource: Equatable {
    case battery
    case ac
    case acCharging
    case acBatteryAssist
    case adapterInput
}

struct PowerReading {
    let watts: Double
    let source: PowerReadingSource
    let chargingWatts: Double?
    let adapterInputWatts: Double?
    let externalConnected: Bool

    var shortText: String {
        switch source {
        case .adapterInput:
            return L10n.text("电脑用电 -- W", "Mac use -- W")
        default:
            return L10n.format("电脑用电 %.1f W", "Mac use %.1f W", watts)
        }
    }

    var statusText: String {
        source == .adapterInput
            ? "-- W"
            : "\(Int(watts.rounded())) W"
    }

    var detailText: String {
        switch source {
        case .battery:
            return L10n.format(
                "电脑用电：%.1f W（使用电池）",
                "Mac power use: %.1f W (on battery)",
                watts
            )
        case .ac:
            return L10n.format(
                "电脑用电估算：%.1f W（接通电源）",
                "Estimated Mac power use: %.1f W (connected to power)",
                watts
            )
        case .acCharging:
            return L10n.format(
                "电脑用电估算：%.1f W（已扣除进入电池的功率）",
                "Estimated Mac power use: %.1f W (battery charging excluded)",
                watts
            )
        case .acBatteryAssist:
            return L10n.format(
                "电脑用电估算：%.1f W（充电器与电池共同供电）",
                "Estimated Mac power use: %.1f W (adapter and battery)",
                watts
            )
        case .adapterInput:
            return L10n.text(
                "电脑用电：暂时无法从充电输入中单独拆分",
                "Mac power use cannot currently be separated from charging input"
            )
        }
    }

    var inputShortText: String {
        guard externalConnected else {
            return L10n.text("未连接充电器", "Not connected")
        }
        guard let adapterInputWatts else {
            return L10n.text("充电输入 -- W", "Power in -- W")
        }
        return L10n.format(
            "充电输入 %.1f W",
            "Power in %.1f W",
            adapterInputWatts
        )
    }

    var inputDetailText: String {
        guard externalConnected else {
            return L10n.text(
                "充电输入：未连接充电器",
                "Charging input: not connected"
            )
        }
        guard let adapterInputWatts else {
            return L10n.text(
                "充电输入：暂时无法读取",
                "Charging input is unavailable"
            )
        }
        return L10n.format(
            "充电输入：%.1f W（充电器进入 Mac 的总功率）",
            "Charging input: %.1f W (total power entering the Mac)",
            adapterInputWatts
        )
    }

    var combinedDetailText: String {
        L10n.format("%@；%@", "%@; %@", detailText, inputDetailText)
    }
}

enum PowerTelemetryEstimator {
    static func reading(
        externalConnected: Bool,
        isCharging: Bool,
        systemPowerWatts: Double?,
        telemetrySystemLoadMilliwatts: Double? = nil,
        adapterInputMilliwatts: Double?,
        batteryVoltageMillivolts: Double?,
        batteryCurrentMilliamps: Double?
    ) -> PowerReading? {
        let batteryFlowWatts = batteryPower(
            voltageMillivolts: batteryVoltageMillivolts,
            currentMilliamps: batteryCurrentMilliamps
        )
        let chargingWatts = externalConnected
            ? batteryFlowWatts.flatMap { isValid(max($0, 0)) ? max($0, 0) : nil }
            : nil
        let measuredAdapterInputWatts = adapterInputMilliwatts
            .map { $0 / 1_000.0 }
            .flatMap { isValid($0) ? $0 : nil }
        let measuredSystemLoadWatts = telemetrySystemLoadMilliwatts
            .map { $0 / 1_000.0 }
            .flatMap { isValidSystemLoad($0) ? $0 : nil }

        func makeReading(watts: Double, source: PowerReadingSource) -> PowerReading {
            let derivedAdapterInputWatts: Double?
            if let measuredAdapterInputWatts {
                derivedAdapterInputWatts = measuredAdapterInputWatts
            } else if externalConnected,
                      source != .adapterInput,
                      let batteryFlowWatts {
                let candidate = watts + batteryFlowWatts
                derivedAdapterInputWatts = isValid(candidate) ? candidate : nil
            } else {
                derivedAdapterInputWatts = nil
            }
            return PowerReading(
                watts: watts,
                source: source,
                chargingWatts: chargingWatts,
                adapterInputWatts: derivedAdapterInputWatts,
                externalConnected: externalConnected
            )
        }

        if externalConnected {
            let source = acSource(isCharging: isCharging, batteryFlowWatts: batteryFlowWatts)

            if let systemPowerWatts, isValid(systemPowerWatts) {
                return makeReading(watts: systemPowerWatts, source: source)
            }
            if let measuredSystemLoadWatts {
                return makeReading(watts: measuredSystemLoadWatts, source: source)
            }

            if let adapterInputMilliwatts, let batteryFlowWatts {
                let watts = adapterInputMilliwatts / 1_000.0 - batteryFlowWatts
                if isValid(watts) {
                    return makeReading(watts: watts, source: source)
                }
            }

            if let adapterInputMilliwatts {
                let watts = adapterInputMilliwatts / 1_000.0
                if isValid(watts) {
                    return makeReading(watts: watts, source: .adapterInput)
                }
            }

            return nil
        }

        if let systemPowerWatts, isValid(systemPowerWatts) {
            return makeReading(watts: systemPowerWatts, source: .battery)
        }
        if let measuredSystemLoadWatts {
            return makeReading(watts: measuredSystemLoadWatts, source: .battery)
        }

        if let batteryFlowWatts {
            let watts = abs(batteryFlowWatts)
            if isValid(watts) {
                return makeReading(watts: watts, source: .battery)
            }
        }

        return nil
    }

    private static func batteryPower(
        voltageMillivolts: Double?,
        currentMilliamps: Double?
    ) -> Double? {
        guard let voltageMillivolts,
              let currentMilliamps,
              voltageMillivolts > 0
        else { return nil }

        return voltageMillivolts * currentMilliamps / 1_000_000.0
    }

    private static func acSource(
        isCharging: Bool,
        batteryFlowWatts: Double?
    ) -> PowerReadingSource {
        if isCharging || (batteryFlowWatts ?? 0) > 0.5 {
            return .acCharging
        }
        if (batteryFlowWatts ?? 0) < -0.5 {
            return .acBatteryAssist
        }
        return .ac
    }

    private static func isValid(_ watts: Double) -> Bool {
        watts.isFinite && watts >= 0 && watts < 250
    }

    private static func isValidSystemLoad(_ watts: Double) -> Bool {
        isValid(watts) && watts > 0
    }
}

enum PowerTelemetryReader {
    static func currentReading() -> PowerReading? {
        guard let matching = IOServiceMatching("AppleSmartBattery") else {
            return nil
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != IO_OBJECT_NULL else {
            return nil
        }
        defer { IOObjectRelease(service) }

        let telemetry = property("PowerTelemetryData", from: service) as? NSDictionary
        let batteryData = property("BatteryData", from: service) as? NSDictionary

        return PowerTelemetryEstimator.reading(
            externalConnected: (property("ExternalConnected", from: service) as? NSNumber)?.boolValue ?? false,
            isCharging: (property("IsCharging", from: service) as? NSNumber)?.boolValue ?? false,
            systemPowerWatts: (batteryData?["SystemPower"] as? NSNumber)?.doubleValue,
            telemetrySystemLoadMilliwatts: (telemetry?["SystemLoad"] as? NSNumber)?.doubleValue,
            adapterInputMilliwatts: (telemetry?["SystemPowerIn"] as? NSNumber)?.doubleValue,
            batteryVoltageMillivolts: (property("Voltage", from: service) as? NSNumber)?.doubleValue,
            batteryCurrentMilliamps: signedBatteryCurrent(
                property("InstantAmperage", from: service) ?? property("Amperage", from: service)
            )
        )
    }

    static func currentWatts() -> Double? {
        currentReading()?.watts
    }

    static func signedBatteryCurrent(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let signed = number.int64Value
        if signed < 0 {
            return Double(signed)
        }
        let unsigned = number.uint64Value
        if unsigned > UInt64(Int32.max), unsigned <= UInt64(UInt32.max) {
            return Double(Int32(bitPattern: UInt32(unsigned)))
        }
        return number.doubleValue
    }

    private static func property(_ key: String, from service: io_service_t) -> Any? {
        IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue()
    }
}

final class PowerMonitor {
    var onUpdate: ((PowerReading?) -> Void)?

    private var timer: Timer?
    private var smoothedWatts: Double?
    private var smoothedChargingWatts: Double?
    private var smoothedAdapterInputWatts: Double?
    private var smoothedSource: PowerReadingSource?
    private var externalConnected = false

    func start() {
        stop()
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let current = PowerTelemetryReader.currentReading()
        if let current {
            if let previous = smoothedWatts, smoothedSource == current.source {
                smoothedWatts = previous * 0.65 + current.watts * 0.35
            } else {
                smoothedWatts = current.watts
            }
            if let currentChargingWatts = current.chargingWatts {
                if let previousChargingWatts = smoothedChargingWatts,
                   smoothedSource == current.source {
                    smoothedChargingWatts = previousChargingWatts * 0.65
                        + currentChargingWatts * 0.35
                } else {
                    smoothedChargingWatts = currentChargingWatts
                }
            } else {
                smoothedChargingWatts = nil
            }
            if let currentAdapterInputWatts = current.adapterInputWatts {
                if let previousAdapterInputWatts = smoothedAdapterInputWatts,
                   smoothedSource == current.source {
                    smoothedAdapterInputWatts = previousAdapterInputWatts * 0.65
                        + currentAdapterInputWatts * 0.35
                } else {
                    smoothedAdapterInputWatts = currentAdapterInputWatts
                }
            } else {
                smoothedAdapterInputWatts = nil
            }
            smoothedSource = current.source
            externalConnected = current.externalConnected
        } else {
            smoothedWatts = nil
            smoothedChargingWatts = nil
            smoothedAdapterInputWatts = nil
            smoothedSource = nil
            externalConnected = false
        }

        guard let watts = smoothedWatts, let source = smoothedSource else {
            onUpdate?(nil)
            return
        }
        onUpdate?(PowerReading(
            watts: watts,
            source: source,
            chargingWatts: smoothedChargingWatts,
            adapterInputWatts: smoothedAdapterInputWatts,
            externalConnected: externalConnected
        ))
    }
}
