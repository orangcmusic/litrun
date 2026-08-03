import Foundation

enum FanControlPolicy {
    static let minimumPercentage = 0
    static let maximumPercentage = 100
    static let lowSpeedWarningThreshold = 50
    static let maximumAcceptedRPM = 10_000

    static func requiresLowSpeedWarning(_ percentage: Int) -> Bool {
        percentage < lowSpeedWarningThreshold
    }

    static func targetRPM(maximumRPM: Double, percentage: Int) -> Int? {
        guard maximumRPM.isFinite,
              maximumRPM > 0,
              (minimumPercentage...maximumPercentage).contains(percentage)
        else {
            return nil
        }

        let requested = Int((maximumRPM * Double(percentage) / 100).rounded())
        return boundedTarget(requested, maximumRPM: maximumRPM)
    }

    static func boundedTarget(_ requested: Int, maximumRPM: Double) -> Int? {
        guard maximumRPM.isFinite,
              maximumRPM > 0,
              (0...maximumAcceptedRPM).contains(requested)
        else {
            return nil
        }

        let hardwareMaximum = Int(maximumRPM.rounded(.down))
        return min(requested, hardwareMaximum)
    }
}
