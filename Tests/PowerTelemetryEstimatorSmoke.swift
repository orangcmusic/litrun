import Foundation

@main
struct PowerTelemetryEstimatorSmoke {
    static func main() {
        let directCharging = requireReading(
            externalConnected: true,
            isCharging: true,
            systemPowerWatts: 10.5,
            adapterInputMilliwatts: 59_400,
            batteryVoltageMillivolts: 12_190,
            batteryCurrentMilliamps: 4_028
        )
        assertClose(directCharging.watts, 10.5)
        precondition(directCharging.source == .acCharging)
        precondition(directCharging.shortText == "电脑用电 10.5 W")
        precondition(directCharging.statusText == "11 W")
        assertClose(directCharging.chargingWatts ?? -1, 49.10132)
        assertClose(directCharging.adapterInputWatts ?? -1, 59.4)
        precondition(directCharging.inputShortText == "充电输入 59.4 W")

        let derivedCharging = requireReading(
            externalConnected: true,
            isCharging: true,
            systemPowerWatts: nil,
            adapterInputMilliwatts: 59_400,
            batteryVoltageMillivolts: 12_190,
            batteryCurrentMilliamps: 4_028
        )
        assertClose(derivedCharging.watts, 10.29868)
        assertClose(derivedCharging.chargingWatts ?? -1, 49.10132)
        assertClose(derivedCharging.adapterInputWatts ?? -1, 59.4)
        precondition(derivedCharging.source == .acCharging)

        let directTelemetryLoad = requireReading(
            externalConnected: true,
            isCharging: true,
            systemPowerWatts: nil,
            telemetrySystemLoadMilliwatts: 10_300,
            adapterInputMilliwatts: 59_400,
            batteryVoltageMillivolts: 12_190,
            batteryCurrentMilliamps: 4_028
        )
        assertClose(directTelemetryLoad.watts, 10.3)
        assertClose(directTelemetryLoad.adapterInputWatts ?? -1, 59.4)

        let batteryAssist = requireReading(
            externalConnected: true,
            isCharging: false,
            systemPowerWatts: nil,
            adapterInputMilliwatts: 30_000,
            batteryVoltageMillivolts: 12_000,
            batteryCurrentMilliamps: -1_000
        )
        assertClose(batteryAssist.watts, 42)
        assertClose(batteryAssist.chargingWatts ?? -1, 0)
        assertClose(batteryAssist.adapterInputWatts ?? -1, 30)
        precondition(batteryAssist.inputShortText == "充电输入 30.0 W")
        precondition(batteryAssist.statusText == "42 W")
        precondition(batteryAssist.source == .acBatteryAssist)

        let honestFallback = requireReading(
            externalConnected: true,
            isCharging: true,
            systemPowerWatts: nil,
            adapterInputMilliwatts: 60_000,
            batteryVoltageMillivolts: nil,
            batteryCurrentMilliamps: nil
        )
        assertClose(honestFallback.watts, 60)
        precondition(honestFallback.source == .adapterInput)
        precondition(honestFallback.shortText == "电脑用电 -- W")
        precondition(honestFallback.statusText == "-- W")
        precondition(honestFallback.chargingWatts == nil)
        assertClose(honestFallback.adapterInputWatts ?? -1, 60)
        precondition(honestFallback.inputShortText == "充电输入 60.0 W")

        let batteryDirect = requireReading(
            externalConnected: false,
            isCharging: false,
            systemPowerWatts: 8.2,
            adapterInputMilliwatts: nil,
            batteryVoltageMillivolts: 12_000,
            batteryCurrentMilliamps: -1_000
        )
        assertClose(batteryDirect.watts, 8.2)
        precondition(batteryDirect.source == .battery)
        precondition(batteryDirect.statusText == "8 W")
        precondition(batteryDirect.inputShortText == "未连接充电器")

        let batteryDerived = requireReading(
            externalConnected: false,
            isCharging: false,
            systemPowerWatts: nil,
            adapterInputMilliwatts: nil,
            batteryVoltageMillivolts: 12_000,
            batteryCurrentMilliamps: -1_000
        )
        assertClose(batteryDerived.watts, 12)
        precondition(batteryDerived.source == .battery)

        let wrappedNegativeCurrent = NSNumber(
            value: UInt32(bitPattern: Int32(-1_000))
        )
        assertClose(
            PowerTelemetryReader.signedBatteryCurrent(wrappedNegativeCurrent) ?? 0,
            -1_000
        )
        assertClose(
            PowerTelemetryReader.signedBatteryCurrent(NSNumber(value: Int32(-1_000))) ?? 0,
            -1_000
        )

        print("OK computer-use=direct-load charge-corrected adapter-input=total signed-current=robust")
    }

    private static func requireReading(
        externalConnected: Bool,
        isCharging: Bool,
        systemPowerWatts: Double?,
        telemetrySystemLoadMilliwatts: Double? = nil,
        adapterInputMilliwatts: Double?,
        batteryVoltageMillivolts: Double?,
        batteryCurrentMilliamps: Double?
    ) -> PowerReading {
        guard let reading = PowerTelemetryEstimator.reading(
            externalConnected: externalConnected,
            isCharging: isCharging,
            systemPowerWatts: systemPowerWatts,
            telemetrySystemLoadMilliwatts: telemetrySystemLoadMilliwatts,
            adapterInputMilliwatts: adapterInputMilliwatts,
            batteryVoltageMillivolts: batteryVoltageMillivolts,
            batteryCurrentMilliamps: batteryCurrentMilliamps
        ) else {
            fatalError("Expected a power reading")
        }
        return reading
    }

    private static func assertClose(_ actual: Double, _ expected: Double) {
        precondition(abs(actual - expected) < 0.001, "Expected \(expected), got \(actual)")
    }
}
