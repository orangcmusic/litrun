import Darwin
import Foundation

@main
struct SlowLaneCrashSmoke {
    static func main() throws {
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--apply-and-exit" {
            guard let pid = Int32(CommandLine.arguments[2]) else {
                Darwin.exit(64)
            }
            let manager = SlowLaneManager()
            guard manager.applyForTesting(pid: pid) else {
                Darwin.exit(1)
            }
            Thread.sleep(forTimeInterval: 0.25)
            Darwin._exit(0)
        }

        let worker = Process()
        worker.executableURL = URL(fileURLWithPath: "/usr/bin/yes")
        worker.standardOutput = FileHandle.nullDevice
        worker.standardError = FileHandle.nullDevice
        try worker.run()
        defer {
            if worker.isRunning {
                _ = try? Shell.run("/bin/kill", ["-CONT", "\(worker.processIdentifier)"])
                _ = try? Shell.run("/usr/sbin/taskpolicy", ["-B", "-p", "\(worker.processIdentifier)"])
                worker.terminate()
                worker.waitUntilExit()
            }
        }

        let baseline = try processState(pid: worker.processIdentifier)
        let harness = Process()
        harness.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        harness.arguments = ["--apply-and-exit", "\(worker.processIdentifier)"]
        try harness.run()
        harness.waitUntilExit()
        guard harness.terminationStatus == 0 else {
            throw smokeError("Crash harness failed to start the guarded pause")
        }

        let paused = try waitForStoppedState(
            pid: worker.processIdentifier,
            timeout: 1.5
        )
        guard paused.state.contains("T") else {
            throw smokeError("Worker was not paused before simulated app exit: \(paused)")
        }

        Thread.sleep(forTimeInterval: 3.5)
        let recovered = try processState(pid: worker.processIdentifier)
        guard !recovered.state.contains("T"), recovered.nice == baseline.nice else {
            throw smokeError("Worker did not recover after simulated app exit: \(recovered)")
        }

        print("OK simulated-app-exit task=resumed scheduling=normal")
    }

    private static func processState(pid: Int32) throws -> (state: String, nice: Int) {
        let output = try Shell.run("/bin/ps", ["-p", "\(pid)", "-o", "state=,nice="])
        let parts = output.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
        guard parts.count >= 2, let nice = Int(parts[1]) else {
            throw smokeError("Could not parse process state: \(output)")
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
            domain: "SlowLaneCrashSmoke",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
