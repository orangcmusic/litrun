import Foundation

struct PowerSnapshot: Codable, Equatable {
    let sleepDisabled: String
    let batterySleep: String
    let acSleep: String

    var restoreArguments: [String] {
        [
            "restore",
            sleepDisabled,
            batterySleep,
            acSleep
        ]
    }

    static func parse(pmsetOutput: String, globalOutput: String) throws -> PowerSnapshot {
        PowerSnapshot(
            sleepDisabled: try sleepDisabledValue(
                in: globalOutput,
                key: "SleepDisabled"
            ),
            batterySleep: try requiredValue(
                in: pmsetOutput,
                section: "Battery Power:",
                key: "sleep"
            ),
            acSleep: try requiredValue(
                in: pmsetOutput,
                section: "AC Power:",
                key: "sleep"
            )
        )
    }

    private static func sleepDisabledValue(
        in text: String,
        key: String
    ) throws -> String {
        for line in text.components(separatedBy: .newlines) {
            let parts = line
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: { $0 == " " || $0 == "\t" })
                .map(String.init)
            guard parts.first == key else { continue }
            guard parts.count == 2, ["0", "1"].contains(parts[1]) else {
                throw PowerSnapshotError.missingValue(section: "System-wide", key: key)
            }
            return parts[1]
        }

        // macOS may omit this undocumented key when its effective value is off.
        return "0"
    }

    private static func requiredValue(
        in text: String,
        section: String,
        key: String
    ) throws -> String {
        var inSection = false

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == section {
                inSection = true
                continue
            }
            if trimmed.hasSuffix("Power:") && trimmed != section && inSection {
                break
            }

            guard inSection else { continue }
            let parts = trimmed
                .split(whereSeparator: { $0 == " " || $0 == "\t" })
                .map(String.init)
            if parts.first == key,
               parts.count >= 2,
               !parts[1].isEmpty,
               parts[1].allSatisfy(\.isNumber) {
                return parts[1]
            }
        }

        throw PowerSnapshotError.missingValue(section: section, key: key)
    }
}

enum PowerSnapshotError: LocalizedError {
    case missingValue(section: String, key: String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let section, let key):
            return L10n.format(
                "无法完整读取这台 Mac 的电源设置（%@ %@）。系统设置未被更改。",
                "Could not read this Mac's complete power settings (%@ %@). No settings were changed.",
                section,
                key
            )
        }
    }
}

enum InterruptedSessionRecovery {
    case none
    case recovered
    case needsAttention(String)
}

final class PowerSettings {
    private let privilegedHelper = PrivilegedPowerHelper()
    private let exitWatchdog = ExitRecoveryWatchdog()
    private var snapshotURL: URL {
        AppPaths.applicationSupportDirectory.appendingPathComponent("original-pmset.json")
    }
    private var snapshotTextURL: URL {
        AppPaths.applicationSupportDirectory.appendingPathComponent("original-pmset.txt")
    }
    private var activeSessionURL: URL {
        AppPaths.applicationSupportDirectory.appendingPathComponent("lid-session-active")
    }

    func enable() throws {
        try recoverExistingSessionBeforeEnableIfNeeded()
        let snapshot = try saveSnapshotForSession()
        try privilegedHelper.prepare()
        try markSessionActive()

        do {
            let recovery = privilegedHelper.recoveryCommand(for: snapshot)
            try exitWatchdog.arm(executable: recovery.executable, arguments: recovery.arguments)
            try privilegedHelper.enablePrepared()
        } catch {
            if (try? privilegedHelper.restorePrepared(snapshot)) != nil {
                exitWatchdog.cancel()
                clearActiveSession()
            } else {
                exitWatchdog.triggerRecovery()
            }
            throw error
        }
    }

    func disable() throws {
        let snapshot = try loadSnapshot()
        try privilegedHelper.restore(snapshot)
        exitWatchdog.cancel()
        clearActiveSession()
    }

    func recoverInterruptedSessionIfNeeded() -> InterruptedSessionRecovery {
        guard FileManager.default.fileExists(atPath: activeSessionURL.path) else {
            return .none
        }

        let snapshot: PowerSnapshot
        do {
            snapshot = try loadSnapshot()
        } catch {
            return .needsAttention(
                L10n.text(
                    "发现上次未正常结束的合盖会话，但原始电源设置记录已损坏。",
                    "A previous lid session did not end normally, but its original power record is damaged."
                )
            )
        }

        guard privilegedHelper.isReadyWithoutInstallation else {
            return .needsAttention(
                L10n.text(
                    "发现上次未正常结束的合盖会话。再次开启时，App 会先恢复旧设置，再重新开始。",
                    "A previous lid session did not end normally. The App will restore it before starting a new session."
                )
            )
        }

        do {
            try privilegedHelper.restorePrepared(snapshot)
            clearActiveSession()
            return .recovered
        } catch {
            return .needsAttention(
                L10n.format(
                    "上次合盖会话尚未恢复：%@",
                    "The previous lid session has not been restored: %@",
                    error.localizedDescription
                )
            )
        }
    }

    func removePrivilegedComponents() throws {
        guard !FileManager.default.fileExists(atPath: activeSessionURL.path) else {
            throw powerError(
                L10n.text(
                    "请先关闭合盖运行，再移除管理员组件。",
                    "Turn off lid-closed running before removing privileged components."
                )
            )
        }
        try privilegedHelper.removeInstallation()
    }

    private func saveSnapshotForSession() throws -> PowerSnapshot {
        try AppPaths.ensureApplicationSupportDirectory()
        let custom = try Shell.run("/usr/bin/pmset", ["-g", "custom"])
        let global = try Shell.run("/usr/bin/pmset", ["-g"])
        let snapshot = try PowerSnapshot.parse(pmsetOutput: custom, globalOutput: global)

        let sourceText = "\(global)\n--- pmset -g custom ---\n\(custom)"
        try sourceText.write(to: snapshotTextURL, atomically: true, encoding: .utf8)
        try JSONEncoder().encode(snapshot).write(to: snapshotURL, options: .atomic)
        return snapshot
    }

    private func recoverExistingSessionBeforeEnableIfNeeded() throws {
        guard FileManager.default.fileExists(atPath: activeSessionURL.path) else {
            return
        }

        let snapshot = try loadSnapshot()
        try privilegedHelper.prepare()
        try privilegedHelper.restorePrepared(snapshot)
        clearActiveSession()
    }

    private func loadSnapshot() throws -> PowerSnapshot {
        do {
            try AppPaths.migrateLegacyFileIfNeeded(named: "original-pmset.json")
            let data = try Data(contentsOf: snapshotURL)
            return try JSONDecoder().decode(PowerSnapshot.self, from: data)
        } catch {
            throw powerError(
                L10n.text(
                    "原始电源设置记录不完整。为避免覆盖系统状态，App 没有执行恢复或开启。",
                    "The original power record is incomplete. The App did not restore or enable the mode to avoid overwriting system state."
                )
            )
        }
    }

    private func markSessionActive() throws {
        try Data("active\n".utf8).write(to: activeSessionURL, options: .atomic)
    }

    private func clearActiveSession() {
        try? FileManager.default.removeItem(at: activeSessionURL)
    }

    private func powerError(_ message: String) -> NSError {
        NSError(
            domain: "LidRunSwitch.PowerSettings",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
