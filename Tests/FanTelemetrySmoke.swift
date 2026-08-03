import Foundation

@main
enum FanTelemetrySmoke {
    static func main() {
        let floatValue = FanValueDecoder.decode(
            bytes: [0x00, 0x00, 0x96, 0x44],
            dataType: FanValueDecoder.fourCharacterCode("flt ")
        )
        precondition(floatValue == 1_200)

        let fixedPointValue = FanValueDecoder.decode(
            bytes: [0x12, 0xc0],
            dataType: FanValueDecoder.fourCharacterCode("fpe2")
        )
        precondition(fixedPointValue == 1_200)

        let reading = FanReading(fans: [
            FanSpeed(index: 0, currentRPM: 3_200, maximumRPM: 5_779),
            FanSpeed(index: 1, currentRPM: 3_400, maximumRPM: 6_241)
        ])
        precondition(reading.shortText == "3400 RPM")
        precondition(reading.compactText == "3.2k · 3.4k R")
        precondition(reading.detailText.contains("系统自动"))
        precondition(reading.detailText(manual: true).contains("手动控制"))
        precondition(reading.peakFraction > 0.54 && reading.peakFraction < 0.56)
        precondition(reading.manualControlSupported)

        let singleFan = FanReading(fans: [
            FanSpeed(index: 0, currentRPM: 2_100, maximumRPM: 5_000)
        ])
        precondition(singleFan.compactText == "2.1k R")
        precondition(singleFan.detailText.contains("风扇 1"))

        let manyFans = FanReading(
            fans: [
                FanSpeed(index: 0, currentRPM: 1_900, maximumRPM: 5_000),
                FanSpeed(index: 1, currentRPM: 2_100, maximumRPM: 5_000),
                FanSpeed(index: 2, currentRPM: 2_300, maximumRPM: 5_000)
            ],
            manualControlSupported: false
        )
        precondition(manyFans.compactText == "3F · 2.3k R")
        precondition(!manyFans.manualControlSupported)

        print("OK fan-decoding=float-and-fpe2 fan-summary=variable capability=guarded")
    }
}
