import Foundation

final class ExitRecoveryWatchdog {
    private var process: Process?
    private var inputPipe: Pipe?

    var isArmed: Bool {
        process?.isRunning == true && inputPipe != nil
    }

    func arm(executable: String, arguments: [String]) throws {
        cancel()

        let pipe = Pipe()
        let watchdog = Process()
        watchdog.executableURL = URL(fileURLWithPath: "/bin/sh")
        watchdog.arguments = [
            "-c",
            "if IFS= read -r action; then [ \"$action\" = cancel ] && exit 0; fi; exec \"$@\"",
            "lid-run-exit-watchdog",
            executable
        ] + arguments
        watchdog.standardInput = pipe
        watchdog.standardOutput = FileHandle.nullDevice
        watchdog.standardError = FileHandle.nullDevice

        try watchdog.run()
        process = watchdog
        inputPipe = pipe
    }

    func cancel() {
        guard let pipe = inputPipe else {
            process = nil
            return
        }

        try? pipe.fileHandleForWriting.write(contentsOf: Data("cancel\n".utf8))
        try? pipe.fileHandleForWriting.close()
        inputPipe = nil
        process = nil
    }

    func triggerRecovery() {
        try? inputPipe?.fileHandleForWriting.close()
        inputPipe = nil
        process = nil
    }
}
