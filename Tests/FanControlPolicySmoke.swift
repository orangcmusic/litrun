import Foundation

@main
enum FanControlPolicySmoke {
    static func main() {
        precondition(FanControlPolicy.targetRPM(maximumRPM: 5_779, percentage: 0) == 0)
        precondition(FanControlPolicy.targetRPM(maximumRPM: 5_779, percentage: 50) == 2_890)
        precondition(FanControlPolicy.targetRPM(maximumRPM: 6_241, percentage: 100) == 6_241)
        precondition(FanControlPolicy.boundedTarget(0, maximumRPM: 5_779) == 0)
        precondition(FanControlPolicy.boundedTarget(9_000, maximumRPM: 5_779) == 5_779)
        precondition(FanControlPolicy.targetRPM(maximumRPM: 5_779, percentage: -1) == nil)
        precondition(FanControlPolicy.targetRPM(maximumRPM: 5_779, percentage: 101) == nil)
        precondition(FanControlPolicy.boundedTarget(10_001, maximumRPM: 5_779) == nil)
        precondition(FanControlPolicy.requiresLowSpeedWarning(0))
        precondition(FanControlPolicy.requiresLowSpeedWarning(49))
        precondition(!FanControlPolicy.requiresLowSpeedWarning(50))

        print("OK fan-control=zero-to-maximum warning=below-50")
    }
}
