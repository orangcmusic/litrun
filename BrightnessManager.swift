import CoreGraphics
import Darwin
import Foundation

private struct SavedBrightness: Codable {
    let value: Float
    let dimmedByApp: Bool
}

private final class DisplayBrightnessClient {
    typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let handle: UnsafeMutableRawPointer
    private let getBrightness: GetBrightness
    private let setBrightness: SetBrightness

    init?() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        ),
        let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
        let setSymbol = dlsym(handle, "DisplayServicesSetBrightness")
        else {
            return nil
        }

        self.handle = handle
        getBrightness = unsafeBitCast(getSymbol, to: GetBrightness.self)
        setBrightness = unsafeBitCast(setSymbol, to: SetBrightness.self)
    }

    deinit {
        dlclose(handle)
    }

    func read(_ displayID: CGDirectDisplayID) -> Float? {
        var value: Float = -1
        guard getBrightness(displayID, &value) == 0, (0...1).contains(value) else {
            return nil
        }
        return value
    }

    func set(_ value: Float, for displayID: CGDirectDisplayID) -> Bool {
        setBrightness(displayID, min(max(value, 0), 1)) == 0
    }
}

final class BrightnessManager {
    private static let recoveryArgument = "--recover-saved-brightness"
    private static let recoveryPollInterval: TimeInterval = 2
    private static let recoveryTimeout: TimeInterval = 7 * 24 * 60 * 60
    private let client = DisplayBrightnessClient()
    private let exitWatchdog = ExitRecoveryWatchdog()
    private let stateURL = AppPaths.applicationSupportDirectory
        .appendingPathComponent("brightness-state.json")
    private var timer: Timer?
    private var displayID: CGDirectDisplayID?
    private var savedBrightness: Float?
    private var dimmedByApp = false
    private var lastLidState: LidState = .unknown

    static func handleRecoveryCommandIfNeeded() -> Bool {
        guard isRecoveryCommand(arguments: CommandLine.arguments) else {
            return false
        }
        let stateURL = AppPaths.applicationSupportDirectory
            .appendingPathComponent("brightness-state.json")
        let deadline = Date().addingTimeInterval(recoveryTimeout)
        while Date() < deadline {
            guard let data = try? Data(contentsOf: stateURL),
                  let state = try? JSONDecoder().decode(SavedBrightness.self, from: data),
                  state.dimmedByApp
            else {
                return true
            }
            if LidStateReader.current() == .open,
               let displayID = builtInDisplayID(),
               DisplayBrightnessClient()?.set(state.value, for: displayID) == true {
                try? FileManager.default.removeItem(at: stateURL)
                return true
            }
            Thread.sleep(forTimeInterval: recoveryPollInterval)
        }
        return true
    }

    static func isRecoveryCommand(arguments: [String]) -> Bool {
        arguments.count == 2 && arguments[1] == recoveryArgument
    }

    func recoverIfNeeded() {
        try? AppPaths.migrateLegacyFileIfNeeded(named: "brightness-state.json")
        guard let state = loadState(), state.dimmedByApp else {
            return
        }
        if LidStateReader.current() == .open,
           let displayID = Self.builtInDisplayID(),
           client?.set(state.value, for: displayID) == true {
            removeState()
        } else {
            startDetachedRecovery()
        }
    }

    func start() {
        stopTimer()
        displayID = Self.builtInDisplayID()
        lastLidState = LidStateReader.current()
        if lastLidState == .open {
            captureCurrentBrightness()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.checkLidState()
        }
    }

    func stopAndRestore() {
        stopTimer()
        restoreBrightnessIfNeeded()
        if recoveryState() != nil {
            exitWatchdog.triggerRecovery()
            dimmedByApp = false
        }
        displayID = nil
        savedBrightness = nil
        lastLidState = .unknown
    }

    private func checkLidState() {
        let current = LidStateReader.current()
        switch current {
        case .open:
            if dimmedByApp || lastLidState == .closed {
                restoreBrightnessIfNeeded()
            } else {
                captureCurrentBrightness()
            }
        case .closed:
            if lastLidState == .open, !dimmedByApp {
                dimDisplay()
            }
        case .unknown:
            break
        }

        if current != .unknown {
            lastLidState = current
        }
    }

    private func captureCurrentBrightness() {
        guard !dimmedByApp,
              let displayID,
              let value = client?.read(displayID)
        else {
            return
        }
        savedBrightness = value
    }

    private func dimDisplay() {
        guard let displayID,
              let original = savedBrightness ?? client?.read(displayID)
        else {
            return
        }

        guard saveState(SavedBrightness(value: original, dimmedByApp: true)) else {
            return
        }
        guard armRecoveryWatchdog() else {
            removeState()
            return
        }
        guard client?.set(0, for: displayID) == true else {
            exitWatchdog.cancel()
            removeState()
            return
        }

        savedBrightness = original
        dimmedByApp = true
    }

    private func restoreBrightnessIfNeeded() {
        guard let state = recoveryState(),
              let displayID = displayID ?? Self.builtInDisplayID(),
              client?.set(state.value, for: displayID) == true
        else {
            return
        }

        dimmedByApp = false
        exitWatchdog.cancel()
        removeState()
    }

    private func recoveryState() -> SavedBrightness? {
        if dimmedByApp, let savedBrightness {
            return SavedBrightness(value: savedBrightness, dimmedByApp: true)
        }
        guard let state = loadState(), state.dimmedByApp else {
            return nil
        }
        return state
    }

    private static func builtInDisplayID() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            return nil
        }

        var displays = Array(repeating: CGDirectDisplayID(0), count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else {
            return nil
        }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    private func armRecoveryWatchdog() -> Bool {
        guard let executable = Bundle.main.executableURL?.path else {
            return false
        }
        do {
            try exitWatchdog.arm(
                executable: executable,
                arguments: [Self.recoveryArgument]
            )
            return true
        } catch {
            logBrightnessError("watchdog", error: error)
            return false
        }
    }

    private func startDetachedRecovery() {
        guard armRecoveryWatchdog() else { return }
        exitWatchdog.triggerRecovery()
    }

    @discardableResult
    private func saveState(_ state: SavedBrightness) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: stateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
            return true
        } catch {
            logBrightnessError("save", error: error)
            return false
        }
    }

    private func loadState() -> SavedBrightness? {
        do {
            try AppPaths.migrateLegacyFileIfNeeded(named: "brightness-state.json")
        } catch {
            logBrightnessError("migrate", error: error)
        }
        guard FileManager.default.fileExists(atPath: stateURL.path),
              let data = try? Data(contentsOf: stateURL)
        else {
            return nil
        }
        return try? JSONDecoder().decode(SavedBrightness.self, from: data)
    }

    private func removeState() {
        try? FileManager.default.removeItem(at: stateURL)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func logBrightnessError(_ operation: String, error: Error) {
        let message = "LitRun! brightness \(operation) error: \(error.localizedDescription)\n"
        FileHandle.standardError.write(Data(message.utf8))
    }
}
