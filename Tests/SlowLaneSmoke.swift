import Foundation

@main
struct SlowLaneSmoke {
    static func main() throws {
        precondition(SlowLaneManager.shouldSkip(
            command: "/private/var/folders/x/lidrun-tests.123/slow-lane-crash-smoke"
        ))
        precondition(SlowLaneManager.shouldSkip(
            command: "/Applications/ChatGPT.app/Contents/Frameworks/Codex Framework.framework/"
                + "Helpers/Codex (Renderer).app/Contents/MacOS/Codex (Renderer) --type=renderer"
        ))
        precondition(SlowLaneManager.shouldSkip(
            command: "/Applications/ChatGPT.app/Contents/Frameworks/Codex Framework.framework/"
                + "Helpers/Codex (Service).app/Contents/MacOS/Codex (Service) --type=gpu-process"
        ))
        precondition(!SlowLaneManager.shouldSkip(
            command: "/Applications/ChatGPT.app/Contents/Resources/codex-code-mode-host"
        ))
        precondition(!SlowLaneManager.shouldSkip(
            command: "/opt/homebrew/bin/node /Users/example/project/build.js"
        ))
        let processTree = [
            SlowLaneProcess(pid: 100, parentPID: 1, cpu: 2, command: "/Applications/Editor"),
            SlowLaneProcess(pid: 101, parentPID: 100, cpu: 80, command: "editor renderer"),
            SlowLaneProcess(pid: 102, parentPID: 101, cpu: 70, command: "editor worker"),
            SlowLaneProcess(pid: 200, parentPID: 1, cpu: 90, command: "build worker")
        ]
        precondition(
            SlowLaneManager.descendantPIDs(processes: processTree, roots: [100])
                == Set<Int32>([100, 101, 102])
        )
        precondition(SlowLaneManager.isProtectedCommand(
            "/Applications/Editor.app/Contents/Frameworks/Renderer --type=gpu",
            prefixes: ["/Applications/Editor.app"]
        ))
        precondition(!SlowLaneManager.isProtectedCommand(
            "/opt/homebrew/bin/node /Users/example/project/build.js",
            prefixes: ["/Applications/Editor.app"]
        ))

        let workerURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LidRunSwitchSlowLaneTest-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(
            at: workerURL,
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/yes")
        )
        defer { try? FileManager.default.removeItem(at: workerURL) }

        let worker = Process()
        worker.executableURL = workerURL
        worker.standardOutput = FileHandle.nullDevice
        worker.standardError = FileHandle.nullDevice
        try worker.run()
        defer {
            if worker.isRunning {
                _ = try? Shell.run("/bin/kill", ["-CONT", "\(worker.processIdentifier)"])
                worker.terminate()
                worker.waitUntilExit()
            }
        }

        Thread.sleep(forTimeInterval: 0.2)
        let pid = worker.processIdentifier
        let manager = SlowLaneManager()
        let baseline = try processState(pid: pid)

        guard !manager.applyForTesting(pid: pid, protectedPIDs: [pid]) else {
            throw smokeError("Protected test process was modified")
        }
        let protectedState = try processState(pid: pid)

        guard manager.applyForTesting(pid: pid, ignoreSkipPolicy: true) else {
            throw smokeError("Controlled test process did not enter the slow lane")
        }

        let slowed = try waitForStoppedState(pid: pid, timeout: 1.5)
        let restoreCommandSucceeded = manager.restoreTouchedProcesses()
        Thread.sleep(forTimeInterval: 0.2)
        let restored = try processState(pid: pid)

        guard !baseline.state.contains("T"),
              !protectedState.state.contains("T"),
              protectedState.nice == baseline.nice
        else {
            throw smokeError("Protected process state changed: \(protectedState)")
        }
        guard slowed.state.contains("T") else {
            throw smokeError("Controlled process did not visibly slow: \(slowed)")
        }
        guard restoreCommandSucceeded,
              !restored.state.contains("T"),
              restored.nice == baseline.nice
        else {
            throw smokeError("Controlled process was not restored: \(restored)")
        }

        print("OK protected=untouched controlled=slowed restored=normal")
    }

    private static func processState(pid: Int32) throws -> (state: String, nice: Int) {
        let output = try Shell.run("/bin/ps", ["-p", "\(pid)", "-o", "state=,nice="])
        let parts = output.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
        guard parts.count >= 2, let nice = Int(parts[1]) else {
            throw NSError(
                domain: "SlowLaneSmoke",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not parse process state: \(output)"]
            )
        }
        return (String(parts[0]), nice)
    }

    private static func waitForStoppedState(
        pid: Int32,
        timeout: TimeInterval
    ) throws -> (state: String, nice: Int) {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let state = try processState(pid: pid)
            if state.state.contains("T") {
                return state
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        return try processState(pid: pid)
    }

    private static func smokeError(_ message: String) -> NSError {
        NSError(
            domain: "SlowLaneSmoke",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
