import Foundation

enum InterruptedFanRecovery {
    case none
    case recovered
    case needsAttention(String)
}

final class FanControlManager {
    private let privilegedHelper = PrivilegedPowerHelper()
    private let exitWatchdog = ExitRecoveryWatchdog()

    private var activeSessionURL: URL {
        AppPaths.applicationSupportDirectory.appendingPathComponent("fan-session-active")
    }

    func enable(targets: [Int]) throws {
        try recoverExistingSessionBeforeEnableIfNeeded()
        try privilegedHelper.prepare()
        try markSessionActive()

        do {
            let recovery = privilegedHelper.fanRecoveryCommand()
            try exitWatchdog.arm(executable: recovery.executable, arguments: recovery.arguments)
            try privilegedHelper.setFansManual(targets: targets)
        } catch {
            if (try? privilegedHelper.setFansAutomatic()) != nil {
                exitWatchdog.cancel()
                clearActiveSession()
            } else {
                exitWatchdog.triggerRecovery()
            }
            throw error
        }
    }

    func update(targets: [Int]) throws {
        do {
            try privilegedHelper.setFansManual(targets: targets)
        } catch {
            if (try? privilegedHelper.setFansAutomatic()) != nil {
                exitWatchdog.cancel()
                clearActiveSession()
            } else {
                exitWatchdog.triggerRecovery()
            }
            throw error
        }
    }

    func disable() throws {
        try privilegedHelper.setFansAutomatic()
        exitWatchdog.cancel()
        clearActiveSession()
    }

    func recoverInterruptedSessionIfNeeded() -> InterruptedFanRecovery {
        guard FileManager.default.fileExists(atPath: activeSessionURL.path) else {
            return .none
        }
        guard privilegedHelper.isReadyWithoutInstallation else {
            return .needsAttention(
                L10n.text(
                    "发现上次未正常结束的手动风扇会话，需要重新授权助手后恢复自动温控。",
                    "A previous manual fan session did not end normally. Reauthorize the helper to restore automatic fan control."
                )
            )
        }

        do {
            try privilegedHelper.setFansAutomatic()
            clearActiveSession()
            return .recovered
        } catch {
            return .needsAttention(
                L10n.format(
                    "风扇尚未恢复自动温控：%@",
                    "Automatic fan control has not been restored: %@",
                    error.localizedDescription
                )
            )
        }
    }

    private func markSessionActive() throws {
        try AppPaths.ensureApplicationSupportDirectory()
        try Data("active\n".utf8).write(to: activeSessionURL, options: .atomic)
    }

    private func recoverExistingSessionBeforeEnableIfNeeded() throws {
        guard FileManager.default.fileExists(atPath: activeSessionURL.path) else {
            return
        }
        try privilegedHelper.setFansAutomatic()
        clearActiveSession()
    }

    private func clearActiveSession() {
        try? FileManager.default.removeItem(at: activeSessionURL)
    }
}
