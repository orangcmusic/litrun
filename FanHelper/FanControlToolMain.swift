import Darwin
import Foundation

@main
enum FanControlTool {
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            Darwin.exit(1)
        }
    }

    private static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            throw toolError("Usage: fanctl status | manual <rpm...> | auto")
        }

        switch command {
        case "version":
            guard arguments.count == 1 else { throw toolError("Invalid arguments") }
            print("3")
        case "status":
            guard arguments.count == 1 else { throw toolError("Invalid arguments") }
            print(try FanControlEngine.statusText())
        case "manual":
            guard getuid() == 0 else { throw toolError("Root privileges required") }
            let targets = arguments.dropFirst().compactMap(Int.init)
            guard targets.count == arguments.count - 1,
                  targets.allSatisfy({ (0...FanControlPolicy.maximumAcceptedRPM).contains($0) })
            else {
                throw toolError("Invalid fan target")
            }
            try FanControlEngine.setManual(targets: targets)
            print(try FanControlEngine.statusText())
        case "auto":
            guard arguments.count == 1 else { throw toolError("Invalid arguments") }
            guard getuid() == 0 else { throw toolError("Root privileges required") }
            try FanControlEngine.setAutomatic()
            print(try FanControlEngine.statusText())
        default:
            throw toolError("Unknown command")
        }
    }

    private static func toolError(_ message: String) -> NSError {
        NSError(
            domain: "LidRunSwitch.FanControlTool",
            code: 64,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
