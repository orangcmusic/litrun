import Foundation

enum LowPowerSchedulingPolicy {
    static let cycleSeconds = 5.0
    static let minimumPauseSeconds = 3.5
    static let maximumPauseSeconds = 4.4

    static func pauseSeconds(
        powerWatts: Double?,
        chipCelsius: Double?,
        thermalState: ProcessInfo.ThermalState
    ) -> TimeInterval {
        if thermalState == .serious || thermalState == .critical {
            return maximumPauseSeconds
        }
        if thermalState == .fair {
            return 4.2
        }
        if (chipCelsius ?? 0) >= 78 || (powerWatts ?? 0) >= 18 {
            return 4.3
        }
        if (chipCelsius ?? 0) >= 70 || (powerWatts ?? 0) >= 10 {
            return 4.0
        }
        return minimumPauseSeconds
    }
}
