import Foundation

@main
enum TemperatureTelemetrySmoke {
    static func main() {
        let fixedPoint = FanValueDecoder.decode(
            bytes: [0x40, 0x80],
            dataType: FanValueDecoder.fourCharacterCode("sp78")
        )
        precondition(fixedPoint == 64.5)

        let reading = TemperatureReading(celsius: 64.8, thermalState: .nominal)
        precondition(reading.shortText == "65°C")
        precondition(reading.detailText.contains("64.8°C"))
        precondition(!reading.isElevated)
        precondition(!TemperatureSafetyPolicy.shouldRestoreAutomaticFans(
            reading: reading,
            fanPercentage: 0
        ))

        let warm = TemperatureReading(celsius: 98.9, thermalState: .nominal)
        precondition(!TemperatureSafetyPolicy.shouldRestoreAutomaticFans(
            reading: warm,
            fanPercentage: 0
        ))
        let hot = TemperatureReading(celsius: 99, thermalState: .nominal)
        precondition(TemperatureSafetyPolicy.shouldRestoreAutomaticFans(
            reading: hot,
            fanPercentage: 0
        ))
        precondition(TemperatureSafetyPolicy.shouldRestoreAutomaticFans(
            reading: hot,
            fanPercentage: 100
        ))

        let fallback = TemperatureReading(celsius: nil, thermalState: .fair)
        precondition(fallback.shortText == "升温")
        precondition(TemperatureSafetyPolicy.shouldRestoreAutomaticFans(
            reading: fallback,
            fanPercentage: 20
        ))

        print("OK temperature=smc-and-fallback fan-restore=99C-or-thermal-state")
    }
}
