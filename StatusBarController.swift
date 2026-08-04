import AppKit
import CoreText

enum StatusBarTypography {
    static let minimumCanvasHeight: CGFloat = 22
    static let maximumCanvasHeight: CGFloat = 30
    static let singleMetricFontSize: CGFloat = 12
    static let twoMetricFontSize: CGFloat = 10
    static let preferredFontSize: CGFloat = 8
    static let fourMetricFontSize: CGFloat = 9
    static let columnGap: CGFloat = 4
    static let fourMetricColumnGap: CGFloat = 0.5
    static let compactFiveMetricColumnGap: CGFloat = 2

    static func fixedCellReferenceText(for metric: MenuBarMetric) -> String {
        switch metric {
        case .power:
            return "999 W"
        case .temperature:
            return "100°C"
        case .fan:
            return "9.9k R"
        case .memory:
            return "999.9G"
        case .disk:
            return "100%"
        case .network:
            return "↓999M ↑999M"
        }
    }

    static func fixedCellWidth(for metric: MenuBarMetric, font: NSFont) -> CGFloat {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: fixedCellReferenceText(for: metric),
                attributes: [.font: font]
            )
        )
        return ceil(CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))) + 2
    }

    static func canvasHeight(for screen: NSScreen?) -> CGFloat {
        guard let screen else { return minimumCanvasHeight }
        let visibleTopInset = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        let safeTopInset = max(0, screen.safeAreaInsets.top)
        return min(
            maximumCanvasHeight,
            max(minimumCanvasHeight, ceil(max(visibleTopInset, safeTopInset)))
        )
    }

    static func fontSize(
        for lineCount: Int,
        canvasHeight: CGFloat,
        isFourMetricLayout: Bool = false
    ) -> CGFloat {
        precondition((1...3).contains(lineCount))
        if isFourMetricLayout {
            precondition(lineCount == 2)
            return fourMetricFontSize(for: canvasHeight)
        }
        if lineCount == 1 {
            return singleMetricFontSize
        }
        if lineCount == 2 {
            return twoMetricFontSize
        }
        if canvasHeight >= 28 {
            return preferredFontSize
        }
        if canvasHeight >= 25 {
            return 7
        }
        return 6
    }

    static func fourMetricFontSize(for canvasHeight: CGFloat) -> CGFloat {
        _ = canvasHeight
        return fourMetricFontSize
    }

    static func baselines(
        for lineCount: Int,
        canvasHeight: CGFloat,
        font: NSFont
    ) -> [CGFloat] {
        precondition((1...3).contains(lineCount))
        let lineAdvance = font.pointSize
        let glyphHeight = font.ascender - font.descender
        let occupiedHeight = glyphHeight + lineAdvance * CGFloat(lineCount - 1)
        let bottomBaseline = (canvasHeight - occupiedHeight) / 2 - font.descender
        return (0..<lineCount).map { index in
            bottomBaseline + CGFloat(lineCount - index - 1) * lineAdvance
        }
    }
}

private struct StatusBarCell {
    let metric: MenuBarMetric
    let text: String
}

final class StatusBarController: NSObject {
    var onShowWindow: (() -> Void)?
    var onToggleLidMode: (() -> Void)?
    var onToggleLowPowerMode: (() -> Void)?
    var onRemovePrivilegedComponents: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let powerStateItem = NSMenuItem(
        title: L10n.text("实时功耗：读取中", "Power: Reading"),
        action: nil,
        keyEquivalent: ""
    )
    private let fanStateItem = NSMenuItem(
        title: L10n.text("风扇转速：读取中", "Fan speed: Reading"),
        action: nil,
        keyEquivalent: ""
    )
    private let temperatureStateItem = NSMenuItem(
        title: L10n.text("芯片温度：读取中", "Chip temperature: Reading"),
        action: nil,
        keyEquivalent: ""
    )
    private let memoryStateItem = NSMenuItem(
        title: L10n.text("内存占用：读取中", "Memory: Reading"),
        action: nil,
        keyEquivalent: ""
    )
    private let diskStateItem = NSMenuItem(
        title: L10n.text("磁盘占用：读取中", "Disk: Reading"),
        action: nil,
        keyEquivalent: ""
    )
    private let networkStateItem = NSMenuItem(
        title: L10n.text("网速：读取中", "Network: Reading"),
        action: nil,
        keyEquivalent: ""
    )
    private lazy var lidModeItem = NSMenuItem(
        title: L10n.text("合盖运行", "Run with lid closed"),
        action: #selector(toggleLidMode),
        keyEquivalent: ""
    )
    private lazy var lowPowerModeItem = NSMenuItem(
        title: L10n.text("低功耗模式", "Low power"),
        action: #selector(toggleLowPowerMode),
        keyEquivalent: ""
    )
    private lazy var showItem = NSMenuItem(
        title: L10n.text("显示窗口", "Show Window"),
        action: #selector(showWindow),
        keyEquivalent: ""
    )
    private lazy var removeHelperItem = NSMenuItem(
        title: L10n.text("移除管理员组件...", "Remove Privileged Components..."),
        action: #selector(removePrivilegedComponents),
        keyEquivalent: ""
    )
    private lazy var quitItem = NSMenuItem(
        title: L10n.text("退出软件", "Quit LitRun!"),
        action: #selector(quit),
        keyEquivalent: "q"
    )
    private var powerText = "-- W"
    private var powerDetail = L10n.text(
        "电脑用电与充电输入：暂时无法读取",
        "Mac power use and charging input are unavailable"
    )
    private var fanText = "-- RPM"
    private var fanDetail = L10n.text("风扇转速：暂时无法读取", "Fan speed is unavailable")
    private var latestFanReading: FanReading?
    private var isFanManual = false
    private var temperatureText = "--°C"
    private var temperatureDetail = L10n.text(
        "芯片温度：暂时无法读取",
        "Chip temperature is unavailable"
    )
    private var memoryText = "--G"
    private var memoryDetail = L10n.text(
        "内存占用：暂时无法读取",
        "Memory use is unavailable"
    )
    private var diskText = "--%"
    private var diskDetail = L10n.text(
        "磁盘占用：暂时无法读取",
        "Disk use is unavailable"
    )
    private var networkText = L10n.text("网速 --", "Net --")
    private var networkDetail = L10n.text(
        "网络：正在初始化",
        "Network: starting"
    )
    private var latestNetworkReading: NetworkTelemetryReading?
    private var selection = MenuBarSelection.defaultSelection
    private var currentStatusTitle = ""
    private(set) var canvasHeightForTesting = StatusBarTypography.minimumCanvasHeight
    private(set) var canvasWidthForTesting: CGFloat = 0
    private(set) var fontSizeForTesting = StatusBarTypography.preferredFontSize
    private(set) var columnGapForTesting = StatusBarTypography.columnGap
    private(set) var usesFourMetricLayoutForTesting = false
    private(set) var usesCompactFiveMetricLayoutForTesting = false

    var buttonTitleForTesting: String {
        currentStatusTitle
    }

    var isVisibleForTesting: Bool {
        statusItem.isVisible
    }

    override init() {
        super.init()

        if let button = statusItem.button {
            if let cell = button.cell as? NSButtonCell {
                cell.usesSingleLineMode = false
                cell.wraps = true
                cell.truncatesLastVisibleLine = false
            }
            button.imagePosition = .noImage
        }
        updateStatusButton()

        let menu = NSMenu()
        powerStateItem.isEnabled = false
        fanStateItem.isEnabled = false
        temperatureStateItem.isEnabled = false
        memoryStateItem.isEnabled = false
        diskStateItem.isEnabled = false
        networkStateItem.isEnabled = false
        menu.addItem(powerStateItem)
        menu.addItem(temperatureStateItem)
        menu.addItem(fanStateItem)
        menu.addItem(memoryStateItem)
        menu.addItem(diskStateItem)
        menu.addItem(networkStateItem)
        menu.addItem(.separator())

        showItem.target = self
        menu.addItem(showItem)
        lidModeItem.target = self
        lowPowerModeItem.target = self
        menu.addItem(lidModeItem)
        menu.addItem(lowPowerModeItem)

        removeHelperItem.target = self
        quitItem.target = self
        menu.addItem(.separator())
        menu.addItem(removeHelperItem)
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func updatePower(_ text: String, detail: String? = nil) {
        powerText = text
        powerDetail = detail ?? L10n.format(
            "电脑用电与充电输入：%@",
            "Mac power use and charging input: %@",
            text
        )
        powerStateItem.title = powerDetail
        updateStatusButton()
    }

    func updateFans(_ reading: FanReading?) {
        latestFanReading = reading
        fanText = reading?.shortText ?? "-- RPM"
        updateFanDetail()
        updateStatusButton()
    }

    func updateFanMode(manual: Bool) {
        isFanManual = manual
        updateFanDetail()
        updateStatusButton()
    }

    func updateTemperature(_ reading: TemperatureReading) {
        temperatureText = reading.shortText
        temperatureDetail = reading.detailText
        temperatureStateItem.title = temperatureDetail
        updateStatusButton()
    }

    func updateSystemResources(_ reading: SystemResourceReading?) {
        if let memory = reading?.memoryUsedGigabytes {
            memoryText = String(format: "%.1fG", memory)
            if let totalBytes = reading?.physicalMemoryBytes {
                let total = Double(totalBytes) / 1_073_741_824.0
                memoryDetail = L10n.format(
                    "内存占用：%.1f GB / %.0f GB",
                    "Memory used: %.1f GB / %.0f GB",
                    memory,
                    total
                )
            } else {
                memoryDetail = L10n.format(
                    "内存占用：%.1f GB",
                    "Memory used: %.1f GB",
                    memory
                )
            }
        } else {
            memoryText = "--G"
            memoryDetail = L10n.text(
                "内存占用：暂时无法读取",
                "Memory use is unavailable"
            )
        }

        if let percentage = reading?.diskUsedPercentage {
            diskText = "\(percentage)%"
            if let usedBytes = reading?.diskUsedBytes,
               let totalBytes = reading?.diskTotalBytes {
                let used = Double(usedBytes) / 1_000_000_000.0
                let total = Double(totalBytes) / 1_000_000_000.0
                diskDetail = L10n.format(
                    "磁盘占用：%.0f GB / %.0f GB",
                    "Disk used: %.0f GB / %.0f GB",
                    used,
                    total
                )
            } else {
                diskDetail = L10n.format(
                    "磁盘占用：%@",
                    "Disk used: %@",
                    diskText
                )
            }
        } else {
            diskText = "--%"
            diskDetail = L10n.text(
                "磁盘占用：暂时无法读取",
                "Disk use is unavailable"
            )
        }
        memoryStateItem.title = memoryDetail
        diskStateItem.title = diskDetail
        updateStatusButton()
    }

    func updateNetwork(_ reading: NetworkTelemetryReading?) {
        latestNetworkReading = reading
        guard let reading else {
            networkText = L10n.text("网速 --", "Net --")
            networkDetail = L10n.text(
                "网络：暂时无法读取",
                "Network: unavailable"
            )
            networkStateItem.title = networkDetail
            updateStatusButton()
            return
        }
        if L10n.language == .simplifiedChinese {
            networkText = reading.menuBarText
            networkDetail = L10n.format("网络：%@", "Network: %@", reading.detailTextChinese)
        } else {
            networkText = reading.menuBarText
            networkDetail = L10n.format("网络：%@", "Network: %@", reading.detailTextEnglish)
        }
        networkStateItem.title = networkDetail
        updateStatusButton()
    }

    func updateSelection(_ selection: MenuBarSelection) {
        self.selection = selection
        updateStatusButton()
    }

    func updateModes(
        lidModeEnabled: Bool,
        lowPowerModeEnabled: Bool,
        lidControlEnabled: Bool = true,
        lowPowerControlEnabled: Bool = true
    ) {
        lidModeItem.state = lidModeEnabled ? .on : .off
        lowPowerModeItem.state = lowPowerModeEnabled ? .on : .off
        lidModeItem.isEnabled = lidControlEnabled
        lowPowerModeItem.isEnabled = lowPowerControlEnabled
    }

    func applyLanguage() {
        showItem.title = L10n.text("显示窗口", "Show Window")
        lidModeItem.title = L10n.text("合盖运行", "Run with lid closed")
        lowPowerModeItem.title = L10n.text("低功耗模式", "Low power")
        removeHelperItem.title = L10n.text(
            "移除管理员组件...",
            "Remove Privileged Components..."
        )
        quitItem.title = L10n.text("退出软件", "Quit LitRun!")
        if latestFanReading == nil {
            fanDetail = L10n.text(
                "风扇转速：暂时无法读取",
                "Fan speed is unavailable"
            )
        }
        updateFanDetail()
        memoryStateItem.title = memoryDetail
        diskStateItem.title = diskDetail
        if let latestNetworkReading {
            updateNetwork(latestNetworkReading)
        } else {
            networkStateItem.title = networkDetail
        }
        updateStatusButton()
    }

    @objc private func showWindow() {
        onShowWindow?()
    }

    @objc private func toggleLidMode() {
        onToggleLidMode?()
    }

    @objc private func toggleLowPowerMode() {
        onToggleLowPowerMode?()
    }

    @objc private func removePrivilegedComponents() {
        onRemovePrivilegedComponents?()
    }

    @objc private func quit() {
        onQuit?()
    }

    private func updateStatusButton() {
        let selectedMetrics = selection.orderedMetrics
        if selectedMetrics.isEmpty {
            currentStatusTitle = ""
            statusItem.isVisible = false
            guard let button = statusItem.button else { return }
            button.attributedTitle = NSAttributedString()
            button.imagePosition = .noImage
            button.image = nil
            button.toolTip = nil
            button.setAccessibilityLabel(
                L10n.text("状态栏未显示指标", "No menu-bar metrics selected")
            )
            return
        }

        statusItem.isVisible = true
        guard let button = statusItem.button else { return }
        let rows = selection.statusRows().map { row in
            row.map { metric in
                StatusBarCell(metric: metric, text: statusText(for: metric))
            }
        }
        let title = rows
            .map { $0.map(\.text).joined(separator: "  ") }
            .joined(separator: "\n")
        currentStatusTitle = title
        button.attributedTitle = NSAttributedString()
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.image = makeStatusImage(rows)
        button.setAccessibilityLabel(title.replacingOccurrences(of: "\n", with: "，"))

        let details: [String] = selectedMetrics.map { metric in
            switch metric {
            case .temperature:
                return temperatureDetail
            case .power:
                return powerDetail
            case .fan:
                return fanDetail
            case .memory:
                return memoryDetail
            case .disk:
                return diskDetail
            case .network:
                return networkDetail
            }
        }
        button.toolTip = details.joined(separator: "\n")
    }

    private func statusText(for metric: MenuBarMetric) -> String {
        switch metric {
        case .power:
            return powerText
        case .temperature:
            return temperatureText
        case .fan:
            return MenuBarSelection.compactFanTextForStatusBar(fanText)
        case .memory:
            return memoryText
        case .disk:
            return diskText
        case .network:
            return networkText
        }
    }

    private func makeStatusImage(_ rows: [[StatusBarCell]]) -> NSImage {
        precondition((1...3).contains(rows.count))
        precondition(rows.allSatisfy { (1...3).contains($0.count) })

        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        let canvasHeight = StatusBarTypography.canvasHeight(for: screen)
        let usesFourMetricLayout = rows.count == 2
            && rows.allSatisfy { $0.count == 2 }
        let fontSize = StatusBarTypography.fontSize(
            for: rows.count,
            canvasHeight: canvasHeight,
            isFourMetricLayout: usesFourMetricLayout
        )
        canvasHeightForTesting = canvasHeight
        fontSizeForTesting = fontSize
        usesFourMetricLayoutForTesting = usesFourMetricLayout
        let unifiedFont = NSFont.monospacedDigitSystemFont(
            ofSize: fontSize,
            weight: .medium
        )
        let lines = rows.map { row in
            row.map { cell in
                CTLineCreateWithAttributedString(
                    NSAttributedString(
                        string: cell.text,
                        attributes: [
                            .font: unifiedFont,
                            .foregroundColor: NSColor.white
                        ]
                    )
                )
            }
        }
        let columnCount = rows.map(\.count).max() ?? 1
        let usesCompactFiveMetricLayout = rows.count == 3
            && rows[0].count == 2
            && rows[1].count == 2
            && rows[2].count == 1
        usesCompactFiveMetricLayoutForTesting = usesCompactFiveMetricLayout
        let columnGap: CGFloat
        if usesCompactFiveMetricLayout {
            columnGap = StatusBarTypography.compactFiveMetricColumnGap
        } else if usesFourMetricLayout {
            columnGap = StatusBarTypography.fourMetricColumnGap
        } else {
            columnGap = StatusBarTypography.columnGap
        }
        columnGapForTesting = columnGap
        let widthRows = usesCompactFiveMetricLayout
            ? Array(rows.dropLast())
            : rows
        let columnWidths = (0..<columnCount).map { columnIndex in
            widthRows.enumerated().compactMap { rowIndex, row in
                guard columnIndex < row.count else { return nil }
                return StatusBarTypography.fixedCellWidth(
                    for: row[columnIndex].metric,
                    font: unifiedFont
                )
            }
            .max() ?? 0
        }
        let gridWidth = columnWidths.reduce(0, +)
            + CGFloat(max(0, columnCount - 1)) * columnGap
        let compactTrailingWidth = usesCompactFiveMetricLayout
            ? StatusBarTypography.fixedCellWidth(
                for: rows[2][0].metric,
                font: unifiedFont
            )
            : 0
        let contentWidth = max(gridWidth, compactTrailingWidth)
        let canvasWidth = ceil(contentWidth) + (usesCompactFiveMetricLayout ? 2 : 4)
        canvasWidthForTesting = canvasWidth
        let canvasSize = NSSize(
            width: canvasWidth,
            height: canvasHeight
        )
        let image = NSImage(size: canvasSize, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }
            context.setShouldAntialias(true)
            context.setShouldSmoothFonts(true)
            let baselines = StatusBarTypography.baselines(
                for: rows.count,
                canvasHeight: canvasHeight,
                font: unifiedFont
            )
            for (rowIndex, row) in lines.enumerated() {
                let rowOrigin = usesCompactFiveMetricLayout
                    ? 1
                    : (canvasWidth - gridWidth) / 2
                for (columnIndex, line) in row.enumerated() {
                    let cellOrigin = rowOrigin
                        + columnWidths[0..<columnIndex].reduce(0, +)
                        + CGFloat(columnIndex) * columnGap
                    let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
                    let textOrigin = usesCompactFiveMetricLayout
                        ? cellOrigin
                        : cellOrigin + (columnWidths[columnIndex] - textWidth) / CGFloat(2)
                    context.textPosition = CGPoint(
                        x: textOrigin,
                        y: baselines[rowIndex]
                    )
                    CTLineDraw(line, context)
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func updateFanDetail() {
        fanDetail = latestFanReading?.detailText(manual: isFanManual)
            ?? L10n.text("风扇转速：暂时无法读取", "Fan speed is unavailable")
        fanStateItem.title = fanDetail
    }
}
