import AppKit

enum SingleInstanceGuard {
    static func activateExistingInstance() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard let existing = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: {
                $0.processIdentifier != currentPID && !$0.isTerminated
            })
        else {
            return false
        }

        existing.activate(options: [.activateAllWindows])
        return true
    }
}
