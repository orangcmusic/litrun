import Foundation

enum MenuBarMetric: String, CaseIterable, Hashable {
    case power
    case temperature
    case fan
    case memory
    case disk
    case network

    var title: String {
        switch self {
        case .temperature:
            return L10n.text("温度", "Temperature")
        case .power:
            return L10n.text("功耗", "Power")
        case .fan:
            return L10n.text("风扇", "Fans")
        case .memory:
            return L10n.text("内存", "Memory")
        case .disk:
            return L10n.text("磁盘", "Disk")
        case .network:
            return L10n.text("网速", "Network")
        }
    }
}

struct MenuBarSelection: Equatable {
    static let empty = MenuBarSelection([])
    static let all = MenuBarSelection(Set(MenuBarMetric.allCases))
    static let defaultSelection = MenuBarSelection(
        Set(MenuBarMetric.allCases.filter { $0 != .network })
    )

    private let metrics: Set<MenuBarMetric>

    init(_ metrics: Set<MenuBarMetric>) {
        self.metrics = metrics
    }

    var orderedMetrics: [MenuBarMetric] {
        MenuBarMetric.allCases.filter(metrics.contains)
    }

    func contains(_ metric: MenuBarMetric) -> Bool {
        metrics.contains(metric)
    }

    func toggling(_ metric: MenuBarMetric) -> MenuBarSelection {
        var next = metrics
        if next.contains(metric) {
            next.remove(metric)
        } else {
            next.insert(metric)
        }
        return MenuBarSelection(next)
    }

    func stackedStatusTitle(
        powerText: String,
        fanText: String,
        temperatureText: String,
        memoryText: String = "--G",
        diskText: String = "--%",
        networkText: String = "Net --"
    ) -> String {
        let values = valueMap(
            powerText: powerText,
            fanText: fanText,
            temperatureText: temperatureText,
            memoryText: memoryText,
            diskText: diskText,
            networkText: networkText
        )
        return statusRows().map { row in
            row.map { values[$0] ?? "--" }.joined(separator: "  ")
        }.joined(separator: "\n")
    }

    func statusRows() -> [[MenuBarMetric]] {
        let ordered = orderedMetrics
        guard !ordered.isEmpty else { return [] }

        if ordered.count == 5, ordered.contains(.network) {
            let withoutNetwork = ordered.filter { $0 != .network }
            return verticalRows(for: withoutNetwork) + [[.network]]
        }
        return verticalRows(for: ordered)
    }

    private func verticalRows(for ordered: [MenuBarMetric]) -> [[MenuBarMetric]] {
        let columnCount = ordered.count <= 3 ? 1 : 2
        let rowCount = (ordered.count + columnCount - 1) / columnCount
        return (0..<rowCount).map { rowIndex in
            (0..<columnCount).compactMap { columnIndex in
                let metricIndex = columnIndex * rowCount + rowIndex
                guard metricIndex < ordered.count else { return nil }
                return ordered[metricIndex]
            }
        }
    }

    private func valueMap(
        powerText: String,
        fanText: String,
        temperatureText: String,
        memoryText: String,
        diskText: String,
        networkText: String
    ) -> [MenuBarMetric: String] {
        [
            .power: powerText,
            .temperature: temperatureText,
            .fan: Self.compactFanTextForStatusBar(fanText),
            .memory: memoryText,
            .disk: diskText,
            .network: networkText
        ]
    }

    static func compactFanTextForStatusBar(_ fanText: String) -> String {
        let suffix = " RPM"
        guard fanText.hasSuffix(suffix) else {
            return fanText
        }
        let valueText = String(fanText.dropLast(suffix.count))
        guard let rpm = Double(valueText) else {
            return "\(valueText) R"
        }
        if rpm >= 1_000 {
            return String(format: "%.1fk R", rpm / 1_000)
        }
        return "\(Int(rpm.rounded())) R"
    }
}

final class MenuBarPreferences {
    private static let selectionKey = "menuBarMetrics"
    private static let legacyDisplayModeKey = "menuBarDisplayMode"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selection: MenuBarSelection {
        get {
            if let rawValues = defaults.stringArray(forKey: Self.selectionKey) {
                let metrics = Set(rawValues.compactMap(MenuBarMetric.init(rawValue:)))
                if rawValues.isEmpty || !metrics.isEmpty {
                    return MenuBarSelection(metrics)
                }
            }
            return migratedLegacySelection()
        }
        set {
            defaults.set(
                newValue.orderedMetrics.map(\.rawValue),
                forKey: Self.selectionKey
            )
        }
    }

    private func migratedLegacySelection() -> MenuBarSelection {
        guard let legacy = defaults.string(forKey: Self.legacyDisplayModeKey) else {
            return .defaultSelection
        }
        switch legacy {
        case "power":
            return MenuBarSelection([.temperature, .power])
        case "fan":
            return MenuBarSelection([.temperature, .fan])
        case "both":
            return MenuBarSelection([.temperature, .power, .fan])
        default:
            return .defaultSelection
        }
    }
}
