import Foundation

@main
enum LowPowerSchedulingPolicySmoke {
    static func main() {
        precondition(LowPowerSchedulingPolicy.pauseSeconds(
            powerWatts: 5,
            chipCelsius: 60,
            thermalState: .nominal
        ) == 3.5)
        precondition(LowPowerSchedulingPolicy.pauseSeconds(
            powerWatts: 12,
            chipCelsius: 60,
            thermalState: .nominal
        ) == 4.0)
        precondition(LowPowerSchedulingPolicy.pauseSeconds(
            powerWatts: 20,
            chipCelsius: 60,
            thermalState: .nominal
        ) == 4.3)
        precondition(LowPowerSchedulingPolicy.pauseSeconds(
            powerWatts: nil,
            chipCelsius: nil,
            thermalState: .fair
        ) == 4.2)
        precondition(
            LowPowerSchedulingPolicy.cycleSeconds -
                LowPowerSchedulingPolicy.maximumPauseSeconds >= 0.59
        )

        print("OK low-power-scheduling=adaptive continuity-window=0.6s")
    }
}
