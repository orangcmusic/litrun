import Foundation

enum FanControlEngineError: LocalizedError {
    case unavailable
    case invalidTargets
    case manualModeUnavailable
    case manualModeTimeout
    case automaticModeTimeout

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return L10n.text(
                "这台电脑没有可控制的风扇。",
                "This Mac does not have controllable fans."
            )
        case .invalidTargets:
            return L10n.text(
                "风扇目标转速无效。",
                "The requested fan speed is invalid."
            )
        case .manualModeUnavailable:
            return L10n.text(
                "这台电脑没有开放手动风扇模式。",
                "This Mac does not expose manual fan mode."
            )
        case .manualModeTimeout:
            return L10n.text(
                "系统没有及时交出风扇控制权。",
                "The system did not hand over fan control in time."
            )
        case .automaticModeTimeout:
            return L10n.text(
                "系统没有及时恢复自动风扇控制。",
                "The system did not restore automatic fan control in time."
            )
        }
    }
}

enum FanControlEngine {
    static func setManual(targets: [Int]) throws {
        guard var client = AppleSMCClient() else {
            throw FanControlEngineError.unavailable
        }
        defer { client.close() }

        let fanCount = try requireFanCount(client)
        guard targets.count == fanCount else {
            throw FanControlEngineError.invalidTargets
        }

        let modeKeyFormat = try detectModeKeyFormat(client, fanCount: fanCount)
        let forceTestAvailable = client.readRaw(for: "Ftst") != nil

        do {
            for index in 0..<fanCount {
                let maximum = client.readValue(for: "F\(index)Mx") ?? 0
                guard let target = FanControlPolicy.boundedTarget(
                    targets[index],
                    maximumRPM: maximum
                ) else {
                    throw FanControlEngineError.invalidTargets
                }

                try enableManualMode(
                    fan: index,
                    modeKeyFormat: modeKeyFormat,
                    forceTestAvailable: forceTestAvailable,
                    client: client
                )
                try client.writeFloatingPoint(Float(target), for: "F\(index)Tg")
            }
        } catch {
            try? setAutomatic(client: client, fanCount: fanCount, modeKeyFormat: modeKeyFormat)
            throw error
        }
    }

    static func setAutomatic() throws {
        guard var client = AppleSMCClient() else {
            throw FanControlEngineError.unavailable
        }
        defer { client.close() }

        let fanCount = try requireFanCount(client)
        let modeKeyFormat = try detectModeKeyFormat(client, fanCount: fanCount)
        try setAutomatic(client: client, fanCount: fanCount, modeKeyFormat: modeKeyFormat)
    }

    static func statusText() throws -> String {
        guard var client = AppleSMCClient() else {
            throw FanControlEngineError.unavailable
        }
        defer { client.close() }

        let fanCount = try requireFanCount(client)
        let modeKeyFormat = try detectModeKeyFormat(client, fanCount: fanCount)
        let forceTest = client.readRaw(for: "Ftst") != nil ? "present" : "absent"
        let fans = (0..<fanCount).map { index in
            let mode = Int(client.readValue(
                for: String(format: modeKeyFormat, index)
            ) ?? -1)
            let actual = Int((client.readValue(for: "F\(index)Ac") ?? -1).rounded())
            let target = Int((client.readValue(for: "F\(index)Tg") ?? -1).rounded())
            return "F\(index):mode=\(mode),actual=\(actual),target=\(target)"
        }
        return "fans=\(fanCount) mode=\(modeKeyFormat) Ftst=\(forceTest) \(fans.joined(separator: " "))"
    }

    private static func requireFanCount(_ client: AppleSMCClient) throws -> Int {
        let count = Int((client.readValue(for: "FNum") ?? 0).rounded())
        guard count > 0, count <= 8 else { throw FanControlEngineError.unavailable }
        return count
    }

    private static func detectModeKeyFormat(
        _ client: AppleSMCClient,
        fanCount: Int
    ) throws -> String {
        for candidate in ["F%dmd", "F%dMd"] {
            if (0..<fanCount).allSatisfy({
                client.readRaw(for: String(format: candidate, $0)) != nil
            }) {
                return candidate
            }
        }
        throw FanControlEngineError.manualModeUnavailable
    }

    private static func enableManualMode(
        fan: Int,
        modeKeyFormat: String,
        forceTestAvailable: Bool,
        client: AppleSMCClient
    ) throws {
        let modeKey = String(format: modeKeyFormat, fan)
        if let current = client.readValue(for: modeKey), Int(current.rounded()) == 1 {
            return
        }

        do {
            try client.writeUInt8(1, for: modeKey)
            if waitForMode(1, key: modeKey, timeout: 0.6, client: client) {
                return
            }
        } catch {
            guard forceTestAvailable else { throw error }
        }
        guard forceTestAvailable else {
            throw FanControlEngineError.manualModeTimeout
        }

        try client.writeUInt8(1, for: "Ftst")
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            try? client.writeUInt8(1, for: modeKey)
            if waitForMode(1, key: modeKey, timeout: 0.2, client: client) {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw FanControlEngineError.manualModeTimeout
    }

    private static func setAutomatic(
        client: AppleSMCClient,
        fanCount: Int,
        modeKeyFormat: String
    ) throws {
        var writeError: Error?
        for index in 0..<fanCount {
            let modeKey = String(format: modeKeyFormat, index)
            do {
                try client.writeUInt8(0, for: modeKey)
            } catch {
                writeError = writeError ?? error
            }
            do {
                try client.writeFloatingPoint(0, for: "F\(index)Tg")
            } catch {
                // The target is irrelevant after the mode key returns to automatic.
            }
        }

        if client.readRaw(for: "Ftst") != nil {
            do {
                try client.writeUInt8(0, for: "Ftst")
            } catch {
                writeError = writeError ?? error
            }
        }
        var finalError: Error?
        for index in 0..<fanCount {
            let modeKey = String(format: modeKeyFormat, index)
            if !waitForMode(0, key: modeKey, timeout: 1.0, client: client) {
                finalError = writeError ?? FanControlEngineError.automaticModeTimeout
            }
        }
        if client.readValue(for: "Ftst") != nil,
           !waitForMode(0, key: "Ftst", timeout: 1.0, client: client) {
            finalError = finalError ?? writeError ?? FanControlEngineError.automaticModeTimeout
        }
        if let finalError {
            throw finalError
        }
    }

    private static func waitForMode(
        _ expected: Int,
        key: String,
        timeout: TimeInterval,
        client: AppleSMCClient
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let value = client.readValue(for: key),
               Int(value.rounded()) == expected {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        return false
    }
}
