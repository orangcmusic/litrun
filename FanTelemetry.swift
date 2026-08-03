import Foundation
import IOKit

struct FanSpeed: Equatable {
    let index: Int
    let currentRPM: Double
    let maximumRPM: Double?

    var fraction: Double {
        guard let maximumRPM, maximumRPM > 0 else { return 0 }
        return min(max(currentRPM / maximumRPM, 0), 1)
    }
}

struct FanReading: Equatable {
    let fans: [FanSpeed]
    let manualControlSupported: Bool

    init(fans: [FanSpeed], manualControlSupported: Bool = true) {
        self.fans = fans
        self.manualControlSupported = manualControlSupported
    }

    var shortText: String {
        guard let peak = fans.map(\.currentRPM).max() else { return "-- RPM" }
        return "\(Int(peak.rounded())) RPM"
    }

    var compactText: String {
        switch fans.count {
        case 0:
            return "-- R"
        case 1:
            return "\(compactRPM(fans[0].currentRPM)) R"
        case 2:
            return "\(compactRPM(fans[0].currentRPM))"
                + " · \(compactRPM(fans[1].currentRPM)) R"
        default:
            let peak = fans.map(\.currentRPM).max() ?? 0
            return "\(fans.count)F · \(compactRPM(peak)) R"
        }
    }

    private func compactRPM(_ rpm: Double) -> String {
        if rpm >= 1_000 {
            return String(format: "%.1fk", rpm / 1_000)
        }
        return "\(Int(rpm.rounded()))"
    }

    var detailText: String {
        detailText(manual: false)
    }

    func detailText(manual: Bool) -> String {
        guard !fans.isEmpty else {
            return L10n.text(
                "风扇转速：暂时无法读取",
                "Fan speed is unavailable"
            )
        }
        let values = fans.map { fan in
            let name: String
            switch (fans.count, fan.index) {
            case (2, 0):
                name = L10n.text("左", "Left")
            case (2, 1):
                name = L10n.text("右", "Right")
            default:
                name = L10n.text(
                    "风扇 \(fan.index + 1)",
                    "Fan \(fan.index + 1)"
                )
            }
            return "\(name) \(Int(fan.currentRPM.rounded())) RPM"
        }
        let mode = manual
            ? L10n.text("手动控制", "Manual")
            : L10n.text("系统自动", "System automatic")
        return L10n.format(
            "风扇转速：%@（%@）",
            "Fan speed: %@ (%@)",
            values.joined(separator: " · "),
            mode
        )
    }

    var peakFraction: Double {
        fans.map(\.fraction).max() ?? 0
    }
}

enum FanValueDecoder {
    static func decode(bytes: [UInt8], dataType: UInt32) -> Double? {
        switch dataType {
        case fourCharacterCode("flt "):
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0])
                | UInt32(bytes[1]) << 8
                | UInt32(bytes[2]) << 16
                | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: bits))
        case fourCharacterCode("fpe2"):
            guard bytes.count >= 2 else { return nil }
            return Double((Int(bytes[0]) << 6) + (Int(bytes[1]) >> 2))
        case fourCharacterCode("sp78"):
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256
        case fourCharacterCode("ui8 "):
            guard let first = bytes.first else { return nil }
            return Double(first)
        default:
            return nil
        }
    }

    static func fourCharacterCode(_ text: String) -> UInt32 {
        guard text.utf8.count == 4 else { return 0 }
        return text.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

enum FanTelemetryReader {
    static func currentReading() -> FanReading? {
        guard var client = AppleSMCClient() else { return nil }
        defer { client.close() }

        guard let countValue = client.readValue(for: "FNum"),
              countValue.isFinite
        else { return nil }

        let count = min(max(Int(countValue.rounded()), 0), 8)
        guard count > 0 else { return nil }

        let fans = (0..<count).compactMap { index -> FanSpeed? in
            guard let current = client.readValue(for: "F\(index)Ac"),
                  current.isFinite,
                  current >= 0,
                  current < 20_000
            else { return nil }

            let maximum = client.readValue(for: "F\(index)Mx").flatMap { value in
                value.isFinite && value > 0 && value < 20_000 ? value : nil
            }
            return FanSpeed(index: index, currentRPM: current, maximumRPM: maximum)
        }

        guard !fans.isEmpty else { return nil }
        return FanReading(
            fans: fans,
            manualControlSupported: supportsManualControl(
                client: client,
                reportedFanCount: count,
                readableFans: fans
            )
        )
    }

    private static func supportsManualControl(
        client: AppleSMCClient,
        reportedFanCount: Int,
        readableFans: [FanSpeed]
    ) -> Bool {
        guard readableFans.count == reportedFanCount,
              readableFans.allSatisfy({ ($0.maximumRPM ?? 0) > 0 })
        else {
            return false
        }

        let hasModeKeys = ["F%dmd", "F%dMd"].contains { format in
            (0..<reportedFanCount).allSatisfy { index in
                client.readRaw(for: String(format: format, index)) != nil
            }
        }
        guard hasModeKeys else { return false }

        return (0..<reportedFanCount).allSatisfy { index in
            client.readRaw(for: "F\(index)Tg") != nil
        }
    }
}

final class FanMonitor {
    var onUpdate: ((FanReading?) -> Void)?

    private let queue = DispatchQueue(
        label: "io.github.achengbatian.lidrunswitch.fan-telemetry",
        qos: .utility
    )
    private var timer: Timer?
    private var sampleInProgress = false
    private var generation = 0

    func start() {
        stop()
        generation += 1
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        generation += 1
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        guard !sampleInProgress else { return }
        sampleInProgress = true
        let activeGeneration = generation

        queue.async { [weak self] in
            let reading = FanTelemetryReader.currentReading()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.sampleInProgress = false
                guard self.generation == activeGeneration else { return }
                self.onUpdate?(reading)
            }
        }
    }
}

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var version = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

enum AppleSMCClientError: LocalizedError {
    case invalidKey
    case keyUnavailable(String)
    case communicationFailed
    case firmwareRejected(String, UInt8)
    case unsupportedDataType(String)

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return L10n.text("SMC 键格式无效。", "The SMC key format is invalid.")
        case .keyUnavailable(let key):
            return L10n.format(
                "这台电脑不支持风扇控制键 %@。",
                "This Mac does not support fan-control key %@.",
                key
            )
        case .communicationFailed:
            return L10n.text(
                "无法与风扇控制器通信。",
                "Could not communicate with the fan controller."
            )
        case .firmwareRejected(let key, let code):
            return L10n.text(
                "风扇控制器拒绝了 \(key)（\(code)）。",
                "The fan controller rejected \(key) (\(code))."
            )
        case .unsupportedDataType(let key):
            return L10n.format(
                "风扇控制键 %@ 的数据格式不受支持。",
                "Fan-control key %@ uses an unsupported data format.",
                key
            )
        }
    }
}

struct AppleSMCClient {
    private static let callSelector: UInt32 = 2
    private static let readKeyCommand: UInt8 = 5
    private static let getKeyInfoCommand: UInt8 = 9

    private var connection: io_connect_t = 0

    init?() {
        guard let matching = IOServiceMatching("AppleSMC") else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else {
            return nil
        }
    }

    mutating func close() {
        guard connection != 0 else { return }
        IOServiceClose(connection)
        connection = 0
    }

    func readValue(for key: String) -> Double? {
        guard let value = readRaw(for: key) else { return nil }
        return FanValueDecoder.decode(bytes: value.bytes, dataType: value.dataType)
    }

    func readRaw(for key: String) -> (bytes: [UInt8], dataType: UInt32, dataSize: UInt32)? {
        let code = FanValueDecoder.fourCharacterCode(key)
        guard code != 0, let info = keyInformation(code) else { return nil }

        var input = SMCParamStruct()
        input.key = code
        input.keyInfo.dataSize = info.dataSize
        input.data8 = Self.readKeyCommand
        guard let output = call(&input), output.result == 0 else { return nil }

        let count = min(Int(info.dataSize), MemoryLayout<SMCBytes>.size)
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(count)) }
        return (bytes, info.dataType, info.dataSize)
    }

    func writeUInt8(_ value: UInt8, for key: String) throws {
        try writeBytes([value], for: key)
    }

    func writeFloatingPoint(_ value: Float, for key: String) throws {
        guard let info = keyInformation(FanValueDecoder.fourCharacterCode(key)) else {
            throw AppleSMCClientError.keyUnavailable(key)
        }

        let bytes: [UInt8]
        switch info.dataType {
        case FanValueDecoder.fourCharacterCode("flt "):
            var value = value
            bytes = withUnsafeBytes(of: &value) { Array($0.prefix(4)) }
        case FanValueDecoder.fourCharacterCode("fpe2"):
            let raw = UInt16(max(value, 0) * 4)
            bytes = [UInt8(raw >> 8), UInt8(raw & 0xff)]
        default:
            throw AppleSMCClientError.unsupportedDataType(key)
        }
        try writeBytes(bytes, for: key, knownInfo: info)
    }

    private func keyInformation(_ key: UInt32) -> SMCKeyInfoData? {
        guard key != 0 else { return nil }
        var input = SMCParamStruct()
        input.key = key
        input.data8 = Self.getKeyInfoCommand
        guard let output = call(&input), output.result == 0 else { return nil }
        return output.keyInfo
    }

    private func writeBytes(
        _ bytes: [UInt8],
        for key: String,
        knownInfo: SMCKeyInfoData? = nil
    ) throws {
        let code = FanValueDecoder.fourCharacterCode(key)
        guard code != 0 else { throw AppleSMCClientError.invalidKey }
        guard let info = knownInfo ?? keyInformation(code) else {
            throw AppleSMCClientError.keyUnavailable(key)
        }

        var input = SMCParamStruct()
        input.key = code
        input.keyInfo.dataSize = info.dataSize
        input.data8 = 6
        input.bytes = smcByteTuple(bytes)

        guard let output = call(&input) else {
            throw AppleSMCClientError.communicationFailed
        }
        guard output.result == 0 else {
            throw AppleSMCClientError.firmwareRejected(key, output.result)
        }
    }

    private func call(_ input: inout SMCParamStruct) -> SMCParamStruct? {
        guard MemoryLayout<SMCParamStruct>.stride == 80 else { return nil }
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = IOConnectCallStructMethod(
            connection,
            Self.callSelector,
            &input,
            MemoryLayout<SMCParamStruct>.stride,
            &output,
            &outputSize
        )
        return result == kIOReturnSuccess ? output : nil
    }

    private func smcByteTuple(_ bytes: [UInt8]) -> SMCBytes {
        let padded = Array((bytes + Array(repeating: 0, count: 32)).prefix(32))
        return (
            padded[0], padded[1], padded[2], padded[3],
            padded[4], padded[5], padded[6], padded[7],
            padded[8], padded[9], padded[10], padded[11],
            padded[12], padded[13], padded[14], padded[15],
            padded[16], padded[17], padded[18], padded[19],
            padded[20], padded[21], padded[22], padded[23],
            padded[24], padded[25], padded[26], padded[27],
            padded[28], padded[29], padded[30], padded[31]
        )
    }
}
