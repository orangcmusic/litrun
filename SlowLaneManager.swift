import Darwin
import Foundation

struct SlowLaneProcess {
    let pid: Int32
    let parentPID: Int32
    let cpu: Double
    let command: String
}

final class SlowLaneManager {
    private let currentUID = Int(getuid())
    private let currentPID = Int32(ProcessInfo.processInfo.processIdentifier)
    private let cpuThreshold = 25.0
    private let stateLock = NSLock()
    private var touchedProcessStorage: [Int32: String] = [:]
    private var pausedPIDs = Set<Int32>()

    func apply(
        protectedPIDs: Set<Int32> = [],
        protectedCommandPrefixes: [String] = [],
        pauseSeconds: TimeInterval = LowPowerSchedulingPolicy.minimumPauseSeconds
    ) -> String {
        do {
            let candidates = try highLoadUserProcesses(
                protectedPIDs: protectedPIDs,
                protectedCommandPrefixes: protectedCommandPrefixes
            )
            guard !candidates.isEmpty else {
                return "慢车道：当前没有明显高负载任务"
            }

            var changed: [String] = []
            for process in candidates.prefix(8) {
                let ok = moveToSlowLane(process, pauseSeconds: pauseSeconds)
                if ok {
                    recordTouched(process)
                    changed.append(shortName(for: process.command))
                }
            }

            if changed.isEmpty {
                return "慢车道：发现高负载，但没有可降速进程"
            }

            let uniqueNames = Array(NSOrderedSet(array: changed)).compactMap { $0 as? String }.prefix(4)
            return "慢跑中：\(uniqueNames.joined(separator: "、"))"
        } catch {
            let message = "LitRun! slow-lane error: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            return "慢车道：检测失败"
        }
    }

    @discardableResult
    func restoreTouchedProcesses() -> Bool {
        stateLock.lock()
        let processes = touchedProcessStorage
        touchedProcessStorage.removeAll()
        pausedPIDs.removeAll()
        stateLock.unlock()

        var restored = true
        for (pid, expectedCommand) in processes {
            guard commandStillMatches(pid: pid, expectedCommand: expectedCommand) else { continue }
            if (try? Shell.run("/bin/kill", ["-CONT", "\(pid)"])) == nil {
                restored = false
            }
            if (try? Shell.run("/usr/sbin/taskpolicy", ["-B", "-p", "\(pid)"])) == nil {
                restored = false
            }
        }
        return restored
    }

    func applyForTesting(
        pid: Int32,
        protectedPIDs: Set<Int32> = [],
        ignoreSkipPolicy: Bool = false
    ) -> Bool {
        guard pid != currentPID, !protectedPIDs.contains(pid) else {
            return false
        }

        let process: SlowLaneProcess?
        do {
            process = try userProcess(pid: pid)
        } catch {
            return false
        }
        guard let process,
              ignoreSkipPolicy || !Self.shouldSkip(command: process.command)
        else {
            return false
        }

        let changed = moveToSlowLane(process, pauseSeconds: 3)
        if changed {
            recordTouched(process)
        }
        return changed
    }

    private func highLoadUserProcesses(
        protectedPIDs: Set<Int32>,
        protectedCommandPrefixes: [String]
    ) throws -> [SlowLaneProcess] {
        let output = try Shell.run("/bin/ps", ["-axo", "pid=,ppid=,uid=,pcpu=,command="])
        let processes = output
            .components(separatedBy: .newlines)
            .compactMap(parseProcessLine)
        let protectedProcessTree = Self.descendantPIDs(
            processes: processes,
            roots: protectedPIDs
        )
        return processes
            .filter { process in
                process.cpu >= cpuThreshold &&
                process.pid != currentPID &&
                !protectedProcessTree.contains(process.pid) &&
                !Self.isProtectedCommand(
                    process.command,
                    prefixes: protectedCommandPrefixes
                ) &&
                !Self.shouldSkip(command: process.command)
            }
            .sorted { $0.cpu > $1.cpu }
    }

    private func parseProcessLine(_ line: String) -> SlowLaneProcess? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(maxSplits: 4, whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard parts.count == 5,
              let pid = Int32(parts[0]),
              let parentPID = Int32(parts[1]),
              let uid = Int(parts[2]),
              let cpu = Double(parts[3]),
              uid == currentUID
        else { return nil }

        return SlowLaneProcess(
            pid: pid,
            parentPID: parentPID,
            cpu: cpu,
            command: parts[4]
        )
    }

    private func userProcess(pid: Int32) throws -> SlowLaneProcess? {
        let output = try Shell.run(
            "/bin/ps",
            ["-p", "\(pid)", "-o", "pid=,ppid=,uid=,pcpu=,command="]
        )
        return output.components(separatedBy: .newlines).compactMap(parseProcessLine).first
    }

    private func moveToSlowLane(
        _ process: SlowLaneProcess,
        pauseSeconds: TimeInterval
    ) -> Bool {
        pauseBriefly(process, pauseSeconds: pauseSeconds)
    }

    private func pauseBriefly(
        _ process: SlowLaneProcess,
        pauseSeconds: TimeInterval
    ) -> Bool {
        let pid = process.pid
        let boundedPauseSeconds = min(
            max(pauseSeconds, 1),
            LowPowerSchedulingPolicy.maximumPauseSeconds
        )
        stateLock.lock()
        if pausedPIDs.contains(pid) {
            stateLock.unlock()
            return false
        }
        pausedPIDs.insert(pid)
        stateLock.unlock()

        let guardian = Process()
        guardian.executableURL = URL(fileURLWithPath: "/bin/sh")
        guardian.arguments = [
            "-c",
            Self.guardedPauseScript,
            "lid-run-slow-lane-guardian",
            "\(pid)",
            "\(boundedPauseSeconds)"
        ]
        guardian.standardOutput = FileHandle.nullDevice
        guardian.standardError = FileHandle.nullDevice
        guardian.terminationHandler = { [weak self] _ in
            self?.stateLock.lock()
            self?.pausedPIDs.remove(pid)
            self?.stateLock.unlock()
        }

        do {
            try guardian.run()
        } catch {
            stateLock.lock()
            pausedPIDs.remove(pid)
            stateLock.unlock()
            return false
        }
        return true
    }

    private static let guardedPauseScript = """
    pid="$1"
    delay="$2"
    start=$(/bin/ps -p "$pid" -o lstart= 2>/dev/null) || exit 1
    command=$(/bin/ps -p "$pid" -o command= 2>/dev/null) || exit 1
    backgrounded=0
    armed=0
    restore_process() {
        [ "$armed" -eq 1 ] || return 0
        current_start=$(/bin/ps -p "$pid" -o lstart= 2>/dev/null || true)
        current_command=$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)
        if [ "$current_start" = "$start" ] && [ "$current_command" = "$command" ]; then
            /bin/kill -CONT "$pid" >/dev/null 2>&1 || true
            if [ "$backgrounded" -eq 1 ]; then
                /usr/sbin/taskpolicy -B -p "$pid" >/dev/null 2>&1 || true
            fi
        fi
        armed=0
    }
    trap 'restore_process' EXIT HUP INT TERM
    if /usr/sbin/taskpolicy -b -p "$pid" >/dev/null 2>&1; then
        backgrounded=1
    fi
    if ! /bin/kill -STOP "$pid" >/dev/null 2>&1; then
        if [ "$backgrounded" -eq 1 ]; then
            /usr/sbin/taskpolicy -B -p "$pid" >/dev/null 2>&1 || true
        fi
        exit 1
    fi
    armed=1
    /bin/sleep "$delay" || true
    restore_process
    trap - EXIT HUP INT TERM
    """

    static func descendantPIDs(
        processes: [SlowLaneProcess],
        roots: Set<Int32>
    ) -> Set<Int32> {
        guard !roots.isEmpty else { return [] }
        var protected = roots
        var changed = true
        while changed {
            changed = false
            for process in processes
            where protected.contains(process.parentPID) && !protected.contains(process.pid) {
                protected.insert(process.pid)
                changed = true
            }
        }
        return protected
    }

    static func isProtectedCommand(_ command: String, prefixes: [String]) -> Bool {
        let normalizedCommand = command.lowercased()
        return prefixes.contains {
            !$0.isEmpty && normalizedCommand.hasPrefix($0.lowercased())
        }
    }

    private func recordTouched(_ process: SlowLaneProcess) {
        stateLock.lock()
        touchedProcessStorage[process.pid] = process.command
        stateLock.unlock()
    }

    private func commandStillMatches(pid: Int32, expectedCommand: String) -> Bool {
        let current: SlowLaneProcess?
        do {
            current = try userProcess(pid: pid)
        } catch {
            return false
        }
        return current?.command == expectedCommand
    }

    static func shouldSkip(command: String) -> Bool {
        let text = command.lowercased()
        return text.contains("lidrunswitch") ||
            text.contains("litrun!") ||
            text.contains("不熄！") ||
            text.contains("临时合盖运行开关") ||
            text.contains("simplepowermode") ||
            text.contains("/lidrun-tests.") ||
            text.contains("lid-run-slow-lane") ||
            text.contains("/helpers/codex (renderer).app/") ||
            text.contains("/helpers/codex (service).app/") ||
            text.contains("/helpers/chatgpt helper (renderer).app/") ||
            text.contains("/helpers/chatgpt helper (gpu).app/") ||
            text.contains("windowserver") ||
            text.contains("wechat") ||
            text.contains("微信") ||
            text.contains("longmao") ||
            text.contains("龙猫") ||
            text.contains("clash") ||
            text.contains("vpn") ||
            text.contains("proxy") ||
            text.contains("lmclient") ||
            text.contains("onedrive") ||
            text.contains("dropbox") ||
            text.contains("syncthing") ||
            text.contains("sunlogin") ||
            text.contains("awesun") ||
            text.contains("向日葵") ||
            text.contains("messages") ||
            text.contains("discord") ||
            text.contains("slack") ||
            text.contains("telegram") ||
            text.contains("zoom") ||
            text.contains("music") ||
            text.contains("netease") ||
            text.contains("网易云") ||
            text.contains("logic") ||
            text.contains("ableton") ||
            text.contains("photoshop") ||
            text.contains("premiere") ||
            text.contains("final cut") ||
            text.contains("/library/apple/system/") ||
            text.contains("/system/library/") ||
            text.contains("/usr/libexec/") ||
            text.contains("/usr/sbin/")
    }

    private func shortName(for command: String) -> String {
        let executable = command.split(separator: " ").first.map(String.init) ?? command
        return URL(fileURLWithPath: executable).lastPathComponent
    }
}
