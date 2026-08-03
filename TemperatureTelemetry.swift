import Foundation

struct TemperatureReading {
    let celsius: Double?
    let thermalState: ProcessInfo.ThermalState

    var shortText: String {
        if let celsius {
            return "\(Int(celsius.rounded()))°C"
        }
        return thermalState.shortTemperatureText
    }

    var detailText: String {
        if let celsius {
            return L10n.format(
                "芯片温度：约 %.1f°C（可读传感器峰值）",
                "Chip temperature: about %.1f°C (highest readable sensor)",
                celsius
            )
        }
        return L10n.format(
            "芯片温度：无法读取摄氏度 · %@",
            "Chip temperature is unavailable · %@",
            thermalState.temperatureDescription
        )
    }

    var isElevated: Bool {
        if let celsius, celsius >= 75 {
            return true
        }
        return thermalState != .nominal
    }
}

enum TemperatureSafetyPolicy {
    static let automaticRestoreCelsius = 99.0

    static func shouldRestoreAutomaticFans(
        reading: TemperatureReading,
        fanPercentage: Int
    ) -> Bool {
        if let celsius = reading.celsius, celsius >= automaticRestoreCelsius {
            return true
        }
        guard FanControlPolicy.requiresLowSpeedWarning(fanPercentage) else {
            return false
        }
        return reading.thermalState != .nominal
    }
}

enum TemperatureTelemetryReader {
    private static let sensorKeys = [
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0T",
        "Tp0X", "Tp0b", "Tp0f", "Tp0j", "Tp1D", "Tp1H", "Tp1P", "Tp1T",
        "TC0P", "TC0D", "TC0E", "TC0C", "TC1C", "TC2C", "TC3C",
        "TC4C", "TC5C", "TC6C", "TC7C", "TG0P", "TG0D"
    ]

    static func currentReading() -> TemperatureReading {
        let thermalState = ProcessInfo.processInfo.thermalState
        guard var client = AppleSMCClient() else {
            return TemperatureReading(celsius: nil, thermalState: thermalState)
        }
        defer { client.close() }

        let values = sensorKeys.compactMap { key -> Double? in
            guard let value = client.readValue(for: key),
                  value.isFinite,
                  value > 0,
                  value < 115
            else {
                return nil
            }
            return value
        }
        return TemperatureReading(celsius: values.max(), thermalState: thermalState)
    }
}

final class TemperatureMonitor {
    var onUpdate: ((TemperatureReading) -> Void)?

    private let queue = DispatchQueue(
        label: "io.github.achengbatian.lidrunswitch.temperature",
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
            let reading = TemperatureTelemetryReader.currentReading()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.sampleInProgress = false
                guard self.generation == activeGeneration else { return }
                self.onUpdate?(reading)
            }
        }
    }
}

private extension ProcessInfo.ThermalState {
    var shortTemperatureText: String {
        switch self {
        case .nominal:
            return L10n.text("正常", "Normal")
        case .fair:
            return L10n.text("升温", "Warm")
        case .serious:
            return L10n.text("高温", "Hot")
        case .critical:
            return L10n.text("过热", "Critical")
        @unknown default:
            return "--"
        }
    }

    var temperatureDescription: String {
        L10n.format(
            "系统热状态：%@",
            "System thermal state: %@",
            shortTemperatureText
        )
    }
}
