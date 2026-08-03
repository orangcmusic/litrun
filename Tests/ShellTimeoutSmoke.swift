import Foundation

@main
struct ShellTimeoutSmoke {
    static func main() throws {
        let startedAt = Date()
        do {
            _ = try Shell.run("/bin/sh", ["-c", "/bin/sleep 5"], timeout: 0.2)
            fatalError("Timed command unexpectedly completed")
        } catch let error as NSError {
            let elapsed = Date().timeIntervalSince(startedAt)
            guard error.domain == "LidRunSwitch.Shell",
                  error.code == 124,
                  elapsed < 2
            else {
                fatalError("Timed command did not fail promptly: \(error) elapsed=\(elapsed)")
            }
        }

        let output = try Shell.run("/bin/echo", ["ready"], timeout: 1)
        guard output.trimmingCharacters(in: .whitespacesAndNewlines) == "ready" else {
            fatalError("Shell did not recover after timeout")
        }

        print("OK timeout=bounded next-command=ready")
    }
}
