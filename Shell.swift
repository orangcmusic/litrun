import Darwin
import Foundation

final class Shell {
    static func run(
        _ launchPath: String,
        _ arguments: [String],
        timeout: TimeInterval = 15
    ) throws -> String {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        let outputQueue = DispatchQueue(label: "io.github.achengbatian.lidrunswitch.shell-output", qos: .utility)
        let errorQueue = DispatchQueue(label: "io.github.achengbatian.lidrunswitch.shell-error", qos: .utility)
        var outputData = Data()
        var errorData = Data()
        let group = DispatchGroup()
        let terminationSemaphore = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        try process.run()
        group.enter()
        outputQueue.async {
            outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        errorQueue.async {
            errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        if terminationSemaphore.wait(timeout: .now() + timeout) == .timedOut {
            if process.isRunning {
                process.terminate()
            }
            if terminationSemaphore.wait(timeout: .now() + 1) == .timedOut {
                _ = Darwin.kill(process.processIdentifier, SIGKILL)
                _ = terminationSemaphore.wait(timeout: .now() + 1)
            }
            _ = group.wait(timeout: .now() + 2)
            throw NSError(
                domain: "LidRunSwitch.Shell",
                code: 124,
                userInfo: [
                    NSLocalizedDescriptionKey: L10n.text(
                        "系统命令响应超时，请重试。",
                        "The system command timed out. Please try again."
                    )
                ]
            )
        }
        group.wait()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "LidRunSwitch",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorOutput.isEmpty ? output : errorOutput]
            )
        }

        return output
    }

    static func runAdminScript(_ script: String) throws {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lid-run-switch-\(UUID().uuidString).sh")
        try script.write(to: tempURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tempURL.path)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let appleScript = "do shell script " + quoteForAppleScript("/bin/sh \(quoteForShell(tempURL.path))") + " with administrator privileges"
        _ = try run("/usr/bin/osascript", ["-e", appleScript], timeout: 180)
    }

    static func quoteForShell(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func quoteForAppleScript(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
