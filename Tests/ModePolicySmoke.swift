import Foundation

@main
struct ModePolicySmoke {
    static func main() {
        guard !ModePolicy.shouldRunSlowLane(lowPowerModeEnabled: false) else {
            fatalError("Slow lane must stay off when low-power mode is off")
        }
        guard ModePolicy.shouldRunSlowLane(lowPowerModeEnabled: true) else {
            fatalError("Slow lane must run when low-power mode is on")
        }

        print("OK slow-lane policy depends only on low-power mode")
    }
}
