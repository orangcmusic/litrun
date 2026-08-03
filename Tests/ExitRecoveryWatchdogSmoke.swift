import Foundation

@main
struct ExitRecoveryWatchdogSmoke {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lid-run-watchdog-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let recoveredURL = directory.appendingPathComponent("recovered")
        let cancelledURL = directory.appendingPathComponent("cancelled")
        let watchdog = ExitRecoveryWatchdog()

        try watchdog.arm(executable: "/usr/bin/touch", arguments: [recoveredURL.path])
        guard watchdog.isArmed else {
            fatalError("Recovery watchdog did not arm")
        }
        watchdog.triggerRecovery()
        try waitForFile(recoveredURL)

        try watchdog.arm(executable: "/usr/bin/touch", arguments: [cancelledURL.path])
        watchdog.cancel()
        Thread.sleep(forTimeInterval: 0.3)
        guard !FileManager.default.fileExists(atPath: cancelledURL.path) else {
            fatalError("Cancelled watchdog still ran recovery")
        }

        print("OK exit-watchdog=recovered cancellation=clean")
    }

    private static func waitForFile(_ url: URL) throws {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) {
                return
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw NSError(
            domain: "ExitRecoveryWatchdogSmoke",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for recovery command"]
        )
    }
}
