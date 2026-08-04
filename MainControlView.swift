import AppKit

final class MainControlView: NSView {
    enum StatusTone {
        case idle
        case active
        case working
        case warning
    }

    let powerLabel = NSTextField(labelWithString: "-- W")
    let inputPowerLabel = NSTextField(labelWithString: "-- W")
    let lidModeSwitch = NSSwitch(frame: .zero)
    let lowPowerModeSwitch = NSSwitch(frame: .zero)
    let manualFanSwitch = NSSwitch(frame: .zero)
    let fanSpeedSlider = NSSlider(value: 65, minValue: 0, maxValue: 100, target: nil, action: nil)
    let settingsButton: NSButton = HeaderIconButton()
    let memoryLabel = NSTextField(labelWithString: "-- GB")
    let diskLabel = NSTextField(labelWithString: "--%")
    let temperatureLabel = NSTextField(labelWithString: "--°C")
    let networkLabel = NSTextField(labelWithString: "--")

    private let productLabel = NSTextField(labelWithString: "LitRun!")
    private let statusLine = NSView()
    private let statusDot = NSView()
    private let statusLabel = NSTextField(labelWithString: L10n.text("待机", "Standby"))
    private let powerTitleLabel = NSTextField(
        labelWithString: L10n.text("电脑用电", "Mac use")
    )
    private let inputPowerTitleLabel = NSTextField(
        labelWithString: L10n.text("充电输入", "Power in")
    )
    private let memoryTitleLabel = NSTextField(
        labelWithString: L10n.text("内存占用", "Memory")
    )
    private let diskTitleLabel = NSTextField(
        labelWithString: L10n.text("磁盘占用", "Disk")
    )
    private let temperatureTitleLabel = NSTextField(
        labelWithString: L10n.text("芯片温度", "Chip temp")
    )
    private let networkLine = NSStackView()
    private let networkTitleLabel = NSTextField(
        labelWithString: L10n.text("网速", "Network")
    )
    private let telemetryRow = NSStackView()
    private let fanControlRow: FanControlRowView
    private let lidModeRow: ModeRowView
    private let lowPowerModeRow: ModeRowView
    private let controlGroup = ControlGroupView()
    private var currentStatusTone = StatusTone.idle

    override init(frame frameRect: NSRect) {
        fanControlRow = FanControlRowView(
            switchControl: manualFanSwitch,
            slider: fanSpeedSlider
        )
        lidModeRow = ModeRowView(
            title: L10n.text("合盖运行", "Lid mode"),
            symbolName: "laptopcomputer",
            symbolFallback: "rectangle",
            switchControl: lidModeSwitch
        )
        lowPowerModeRow = ModeRowView(
            title: L10n.text("低功耗", "Low power"),
            symbolName: "leaf",
            symbolFallback: "bolt",
            switchControl: lowPowerModeSwitch
        )
        super.init(frame: frameRect)
        buildInterface()
        updateModeAppearance(lidModeEnabled: false, lowPowerModeEnabled: false)
        setStatus(L10n.text("待机", "Standby"), tone: .idle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateModeAppearance(lidModeEnabled: Bool, lowPowerModeEnabled: Bool) {
        lidModeRow.setActive(lidModeEnabled)
        lowPowerModeRow.setActive(lowPowerModeEnabled)
    }

    func setModeControlsEnabled(lidEnabled: Bool, lowPowerEnabled: Bool) {
        lidModeRow.setEnabled(lidEnabled)
        lowPowerModeRow.setEnabled(lowPowerEnabled)
    }

    func setLidControlAvailable(_ available: Bool) {
        lidModeSwitch.toolTip = available
            ? nil
            : L10n.text(
                "这台 Mac 没有可检测的电脑盖",
                "This Mac does not have a detectable lid"
            )
    }

    func setFanControlsEnabled(
        _ switchEnabled: Bool,
        sliderEnabled: Bool? = nil,
        availabilityText: String? = nil
    ) {
        fanControlRow.setEnabled(
            switchEnabled,
            sliderEnabled: sliderEnabled ?? switchEnabled,
            availabilityText: availabilityText
        )
    }

    func updateFanAppearance(manualEnabled: Bool, percentage: Int) {
        fanControlRow.setManual(manualEnabled, percentage: percentage)
    }

    func updateFans(_ reading: FanReading?) {
        fanControlRow.setReading(reading)
    }

    var fanModeTextForTesting: String {
        fanControlRow.modeTextForTesting
    }

    var fanPercentageTextForTesting: String {
        fanControlRow.percentageTextForTesting
    }

    var fanSliderAlphaForTesting: CGFloat {
        fanControlRow.sliderAlphaForTesting
    }

    var fanPercentageAlphaForTesting: CGFloat {
        fanControlRow.percentageAlphaForTesting
    }

    var fanModeAlphaForTesting: CGFloat {
        fanControlRow.modeAlphaForTesting
    }

    var fanSliderUsesRefinedCellForTesting: Bool {
        fanControlRow.usesRefinedSliderCellForTesting
    }

    var usesNativeSwitchesForTesting: Bool {
        ObjectIdentifier(type(of: lidModeSwitch)) == ObjectIdentifier(NSSwitch.self)
            && ObjectIdentifier(type(of: lowPowerModeSwitch))
                == ObjectIdentifier(NSSwitch.self)
            && ObjectIdentifier(type(of: manualFanSwitch))
                == ObjectIdentifier(NSSwitch.self)
    }

    func updateTemperature(_ reading: TemperatureReading) {
        if let celsius = reading.celsius {
            temperatureLabel.attributedStringValue = metricString(
                value: "\(Int(celsius.rounded()))",
                unit: "°C",
                separatesUnit: false,
                alignment: temperatureLabel.alignment
            )
        } else {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = temperatureLabel.alignment
            temperatureLabel.attributedStringValue = NSAttributedString(
                string: reading.shortText,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 17, weight: .light),
                    .paragraphStyle: paragraph
                ]
            )
        }
        temperatureLabel.toolTip = reading.detailText
        temperatureLabel.textColor = reading.isElevated ? .systemOrange : .labelColor
    }

    func updatePower(_ reading: PowerReading?) {
        let mainWatts = reading.flatMap {
            $0.source == .adapterInput ? nil : $0.watts
        }
        setPowerMetric(mainWatts, on: powerLabel)
        powerLabel.toolTip = reading?.detailText
            ?? L10n.text("电脑用电：暂时无法读取", "Mac power use is unavailable")
        if let reading, !reading.externalConnected {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = inputPowerLabel.alignment
            inputPowerLabel.attributedStringValue = NSAttributedString(
                string: "—",
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(
                        ofSize: 17,
                        weight: .light
                    ),
                    .paragraphStyle: paragraph
                ]
            )
        } else {
            setPowerMetric(reading?.adapterInputWatts, on: inputPowerLabel)
        }
        inputPowerLabel.toolTip = reading?.inputDetailText
            ?? L10n.text("充电输入：暂时无法读取", "Charging input is unavailable")
        powerLabel.textColor = mainWatts == nil ? .tertiaryLabelColor : .labelColor
        inputPowerLabel.textColor = reading?.adapterInputWatts == nil
            ? .tertiaryLabelColor
            : .labelColor
    }

    func updateSystemResources(_ reading: SystemResourceReading?) {
        let memoryValue = reading?.memoryUsedGigabytes.map {
            String(format: "%.1f", $0)
        } ?? "--"
        memoryLabel.attributedStringValue = metricString(
            value: memoryValue,
            unit: "GB",
            separatesUnit: true,
            alignment: memoryLabel.alignment
        )

        let diskValue = reading?.diskUsedPercentage.map(String.init) ?? "--"
        diskLabel.attributedStringValue = metricString(
            value: diskValue,
            unit: "%",
            separatesUnit: false,
            alignment: diskLabel.alignment
        )

        if let used = reading?.memoryUsedGigabytes,
           let totalBytes = reading?.physicalMemoryBytes {
            let total = Double(totalBytes) / 1_073_741_824.0
            memoryLabel.toolTip = L10n.format(
                "内存占用：%.1f GB / %.0f GB",
                "Memory used: %.1f GB / %.0f GB",
                used,
                total
            )
        } else {
            memoryLabel.toolTip = L10n.text(
                "内存占用：暂时无法读取",
                "Memory use is unavailable"
            )
        }

        if let usedBytes = reading?.diskUsedBytes,
           let totalBytes = reading?.diskTotalBytes {
            let used = Double(usedBytes) / 1_000_000_000.0
            let total = Double(totalBytes) / 1_000_000_000.0
            diskLabel.toolTip = L10n.format(
                "磁盘占用：%.0f GB / %.0f GB",
                "Disk used: %.0f GB / %.0f GB",
                used,
                total
            )
        } else {
            diskLabel.toolTip = L10n.text(
                "磁盘占用：暂时无法读取",
                "Disk use is unavailable"
            )
        }

        memoryLabel.textColor = reading?.memoryUsedBytes == nil
            ? .tertiaryLabelColor
            : .labelColor
        diskLabel.textColor = reading?.diskUsedPercentage == nil
            ? .tertiaryLabelColor
            : .labelColor
    }

    func updateNetwork(_ reading: NetworkTelemetryReading?) {
        networkLabel.stringValue = reading?.menuBarText ?? "--"
        networkLabel.toolTip = reading.map {
            L10n.format(
                "网速：%@",
                "Network speed: %@",
                L10n.language == .simplifiedChinese
                    ? $0.detailTextChinese
                    : $0.detailTextEnglish
            )
        } ?? L10n.text("网速：暂时无法读取", "Network speed is unavailable")
        networkLabel.textColor = reading?.isReady == true
            ? .secondaryLabelColor
            : .tertiaryLabelColor
    }

    func setStatus(_ text: String, tone: StatusTone, busy: Bool = false) {
        statusLabel.stringValue = text
        currentStatusTone = tone
        applyStatusTone()
        updateStatusMotion(busy: busy)
    }

    private func applyStatusTone() {
        switch currentStatusTone {
        case .idle:
            statusDot.layer?.backgroundColor = resolvedCGColor(
                .tertiaryLabelColor.withAlphaComponent(0.72)
            )
            statusLabel.textColor = .secondaryLabelColor
        case .active:
            statusDot.layer?.backgroundColor = resolvedCGColor(.systemGreen)
            statusLabel.textColor = .secondaryLabelColor
        case .working:
            statusDot.layer?.backgroundColor = resolvedCGColor(.controlAccentColor)
            statusLabel.textColor = .controlAccentColor
        case .warning:
            statusDot.layer?.backgroundColor = resolvedCGColor(.systemOrange)
            statusLabel.textColor = .systemOrange
        }
    }

    func applyLanguage() {
        productLabel.stringValue = "LitRun!"
        powerTitleLabel.stringValue = L10n.text("电脑用电", "Mac use")
        inputPowerTitleLabel.stringValue = L10n.text("充电输入", "Power in")
        memoryTitleLabel.stringValue = L10n.text("内存占用", "Memory")
        diskTitleLabel.stringValue = L10n.text("磁盘占用", "Disk")
        temperatureTitleLabel.stringValue = L10n.text("芯片温度", "Chip temp")
        networkTitleLabel.stringValue = L10n.text("网速", "Network")
        lidModeRow.setTitle(L10n.text("合盖运行", "Lid mode"))
        lowPowerModeRow.setTitle(L10n.text("低功耗", "Low power"))
        lidModeSwitch.setAccessibilityLabel(L10n.text("合盖运行", "Run with lid closed"))
        lowPowerModeSwitch.setAccessibilityLabel(L10n.text("低功耗", "Low power"))
        fanControlRow.applyLanguage()
        powerLabel.setAccessibilityLabel(
            L10n.text("电脑用电功率", "Mac power use")
        )
        inputPowerLabel.setAccessibilityLabel(
            L10n.text("充电输入功率", "Charging input power")
        )
        memoryLabel.setAccessibilityLabel(L10n.text("内存占用", "Memory used"))
        diskLabel.setAccessibilityLabel(L10n.text("磁盘占用", "Disk used"))
        temperatureLabel.setAccessibilityLabel(
            L10n.text("芯片温度", "Chip temperature")
        )
        networkTitleLabel.setAccessibilityLabel(L10n.text("网速", "Network speed"))
        networkLabel.setAccessibilityLabel(L10n.text("网速", "Network speed"))
        settingsButton.toolTip = L10n.text("设置", "Settings")
        settingsButton.setAccessibilityLabel(L10n.text("设置", "Settings"))
        statusLabel.setAccessibilityLabel(L10n.text("当前状态", "Current status"))
    }

    var productLabelFrameForTesting: NSRect {
        productLabel.convert(productLabel.bounds, to: self)
    }

    var productLabelAlignmentFrameForTesting: NSRect {
        guard let superview = productLabel.superview else { return .zero }
        return superview.convert(
            productLabel.alignmentRect(forFrame: productLabel.frame),
            to: self
        )
    }

    var statusLabelFrameForTesting: NSRect {
        statusLabel.convert(statusLabel.bounds, to: self)
    }

    var statusLabelAlignmentFrameForTesting: NSRect {
        guard let superview = statusLabel.superview else { return .zero }
        return superview.convert(
            statusLabel.alignmentRect(forFrame: statusLabel.frame),
            to: self
        )
    }

    var statusLineFrameForTesting: NSRect {
        statusLine.convert(statusLine.bounds, to: self)
    }

    var statusDotFrameForTesting: NSRect {
        statusDot.convert(statusDot.bounds, to: self)
    }

    var telemetryFrameForTesting: NSRect {
        telemetryRow.convert(telemetryRow.bounds, to: self)
    }

    var networkLineFrameForTesting: NSRect {
        networkLine.convert(networkLine.bounds, to: self)
    }

    var controlGroupFrameForTesting: NSRect {
        controlGroup.convert(controlGroup.bounds, to: self)
    }

    var controlGroupUsesOutlinedSurfaceForTesting: Bool {
        controlGroup.usesOutlinedSurfaceForTesting
    }

    var controlSeparatorsMatchForTesting: Bool {
        controlGroup.separatorsMatchForTesting
    }

    var controlGroupUsesCenterSeparatorForTesting: Bool {
        controlGroup.usesCenterSeparatorForTesting
    }

    var featureColumnFramesForTesting: (
        modeIcon: NSRect,
        fanIcon: NSRect,
        modeTitle: NSRect,
        fanTitle: NSRect,
        fanReading: NSRect
    ) {
        (
            lidModeRow.iconFrame(in: self),
            fanControlRow.iconFrame(in: self),
            lidModeRow.titleFrame(in: self),
            fanControlRow.titleFrame(in: self),
            fanControlRow.readingFrame(in: self)
        )
    }

    var usesFeatureSymbolsForTesting: Bool {
        lidModeRow.hasSymbolForTesting
            && lowPowerModeRow.hasSymbolForTesting
            && fanControlRow.hasSymbolForTesting
    }

    var modeRowSwitchTrailingClearancesForTesting: (lid: CGFloat, lowPower: CGFloat) {
        (
            lidModeRow.switchTrailingClearanceForTesting,
            lowPowerModeRow.switchTrailingClearanceForTesting
        )
    }

    var fanControlAlignmentFramesForTesting: (
        lidSwitch: NSRect,
        lowPowerSwitch: NSRect,
        fanSwitch: NSRect,
        fanSlider: NSRect
    ) {
        (
            lidModeRow.switchFrame(in: self),
            lowPowerModeRow.switchFrame(in: self),
            fanControlRow.switchFrame(in: self),
            fanControlRow.sliderFrame(in: self)
        )
    }

    var fanElementsWithinBoundsForTesting: Bool {
        fanControlRow.elementsWithinBounds(in: self)
    }

    var typographyForTesting: (
        product: CGFloat,
        status: CGFloat,
        metricTitle: CGFloat,
        metricValue: CGFloat,
        fanTitle: CGFloat,
        fanReading: CGFloat,
        fanMode: CGFloat,
        fanPercentage: CGFloat,
        modeTitle: CGFloat
    ) {
        (
            productLabel.font?.pointSize ?? 0,
            statusLabel.font?.pointSize ?? 0,
            powerTitleLabel.font?.pointSize ?? 0,
            powerLabel.font?.pointSize ?? 0,
            fanControlRow.titleFontSizeForTesting,
            fanControlRow.readingFontSizeForTesting,
            fanControlRow.modeFontSizeForTesting,
            fanControlRow.percentageFontSizeForTesting,
            lidModeRow.titleFontSizeForTesting
        )
    }

    func performLidModeRowClickForTesting() {
        lidModeRow.performPrimaryActionForTesting()
    }

    func setLidModeHoveredForTesting(_ hovered: Bool) {
        lidModeRow.setHoveredForTesting(hovered)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func buildInterface() {
        wantsLayer = true

        productLabel.translatesAutoresizingMaskIntoConstraints = false
        productLabel.font = .systemFont(ofSize: 18, weight: .medium)
        productLabel.textColor = .labelColor
        productLabel.setContentHuggingPriority(.required, for: .horizontal)
        productLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        for titleLabel in [
            powerTitleLabel,
            inputPowerTitleLabel,
            memoryTitleLabel,
            diskTitleLabel,
            temperatureTitleLabel,
            networkTitleLabel
        ] {
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.font = .systemFont(ofSize: 10, weight: .light)
            titleLabel.textColor = .secondaryLabelColor
            titleLabel.alphaValue = 0.82
            titleLabel.lineBreakMode = .byClipping
            titleLabel.alignment = .center
        }

        for valueLabel in [
            powerLabel,
            inputPowerLabel,
            memoryLabel,
            diskLabel,
            temperatureLabel
        ] {
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .light)
            valueLabel.textColor = .labelColor
            valueLabel.alignment = .center
            valueLabel.lineBreakMode = .byClipping
        }
        powerLabel.setAccessibilityLabel(L10n.text("电脑用电功率", "Mac power use"))
        inputPowerLabel.setAccessibilityLabel(
            L10n.text("充电输入功率", "Charging input power")
        )
        memoryLabel.setAccessibilityLabel(L10n.text("内存占用", "Memory used"))
        diskLabel.setAccessibilityLabel(L10n.text("磁盘占用", "Disk used"))
        temperatureLabel.setAccessibilityLabel(
            L10n.text("芯片温度", "Chip temperature")
        )

        networkTitleLabel.font = .systemFont(ofSize: 9, weight: .light)
        networkTitleLabel.setContentHuggingPriority(.required, for: .horizontal)
        networkTitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        networkLabel.translatesAutoresizingMaskIntoConstraints = false
        networkLabel.font = .monospacedDigitSystemFont(ofSize: 8.5, weight: .regular)
        networkLabel.lineBreakMode = .byClipping
        networkLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        networkLabel.setAccessibilityLabel(L10n.text("网速", "Network speed"))

        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.bezelStyle = .accessoryBarAction
        settingsButton.isBordered = false
        settingsButton.image = configuredSymbol(
            named: "gearshape",
            fallback: "gear",
            pointSize: 13.5,
            weight: .light
        )
        settingsButton.contentTintColor = .secondaryLabelColor
        settingsButton.toolTip = L10n.text("设置", "Settings")
        settingsButton.setAccessibilityLabel(L10n.text("设置", "Settings"))

        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        statusLine.translatesAutoresizingMaskIntoConstraints = false
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 3
        telemetryRow.translatesAutoresizingMaskIntoConstraints = false
        telemetryRow.orientation = .horizontal
        telemetryRow.distribution = .fillEqually
        telemetryRow.alignment = .top
        telemetryRow.spacing = 0
        header.addSubview(productLabel)
        header.addSubview(settingsButton)
        header.addSubview(statusLine)
        statusLine.addSubview(statusDot)
        statusLine.addSubview(statusLabel)
        telemetryRow.addArrangedSubview(
            makeMetricView(title: powerTitleLabel, value: powerLabel)
        )
        telemetryRow.addArrangedSubview(
            makeMetricView(title: inputPowerTitleLabel, value: inputPowerLabel)
        )
        telemetryRow.addArrangedSubview(
            makeMetricView(title: memoryTitleLabel, value: memoryLabel)
        )
        telemetryRow.addArrangedSubview(
            makeMetricView(title: diskTitleLabel, value: diskLabel)
        )
        telemetryRow.addArrangedSubview(
            makeMetricView(title: temperatureTitleLabel, value: temperatureLabel)
        )

        networkLine.translatesAutoresizingMaskIntoConstraints = false
        networkLine.orientation = .horizontal
        networkLine.alignment = .centerY
        networkLine.distribution = .fill
        networkLine.spacing = 6
        networkLine.addArrangedSubview(networkTitleLabel)
        networkLine.addArrangedSubview(networkLabel)

        controlGroup.translatesAutoresizingMaskIntoConstraints = false
        controlGroup.addRows(lidModeRow, lowPowerModeRow, fanControlRow)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 11.5, weight: .light)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 1
        statusLabel.wantsLayer = true
        statusLabel.setAccessibilityLabel(L10n.text("当前状态", "Current status"))

        addSubview(header)
        addSubview(telemetryRow)
        addSubview(networkLine)
        addSubview(controlGroup)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 41),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            header.heightAnchor.constraint(equalToConstant: 27),

            productLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            productLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            productLabel.heightAnchor.constraint(equalToConstant: 27),

            statusLine.leadingAnchor.constraint(equalTo: productLabel.trailingAnchor, constant: 12),
            statusLine.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -8),
            statusLine.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            statusLine.heightAnchor.constraint(equalToConstant: 18),

            statusDot.leadingAnchor.constraint(equalTo: statusLine.leadingAnchor),
            statusDot.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6),

            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),
            statusLabel.trailingAnchor.constraint(equalTo: statusLine.trailingAnchor),
            statusLabel.centerYAnchor.constraint(
                equalTo: productLabel.centerYAnchor,
                constant: -0.5
            ),
            statusLabel.heightAnchor.constraint(equalToConstant: 16),

            settingsButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            settingsButton.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: -4.5),
            settingsButton.widthAnchor.constraint(equalToConstant: 28),
            settingsButton.heightAnchor.constraint(equalToConstant: 28),

            telemetryRow.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
            telemetryRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            telemetryRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            telemetryRow.heightAnchor.constraint(equalToConstant: 43),

            networkLine.topAnchor.constraint(equalTo: telemetryRow.bottomAnchor, constant: 2),
            networkLine.leadingAnchor.constraint(equalTo: telemetryRow.leadingAnchor, constant: 22),
            networkLine.trailingAnchor.constraint(lessThanOrEqualTo: telemetryRow.trailingAnchor),
            networkLine.heightAnchor.constraint(equalToConstant: 12),

            controlGroup.topAnchor.constraint(equalTo: networkLine.bottomAnchor, constant: 2),
            controlGroup.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            controlGroup.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            controlGroup.heightAnchor.constraint(equalToConstant: 131)
        ])

        applyLanguage()
        updateColors()
        updateNetwork(nil)
    }

    private func makeMetricView(
        title titleLabel: NSTextField,
        value valueLabel: NSTextField
    ) -> NSView {
        let metricView = NSView()
        metricView.translatesAutoresizingMaskIntoConstraints = false
        metricView.addSubview(titleLabel)
        metricView.addSubview(valueLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: metricView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: metricView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: metricView.trailingAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 14),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            valueLabel.leadingAnchor.constraint(equalTo: metricView.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: metricView.trailingAnchor),
            valueLabel.heightAnchor.constraint(equalToConstant: 26),
            valueLabel.bottomAnchor.constraint(lessThanOrEqualTo: metricView.bottomAnchor)
        ])
        return metricView
    }

    private func configuredSymbol(
        named name: String,
        fallback: String,
        pointSize: CGFloat,
        weight: NSFont.Weight
    ) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: fallback, accessibilityDescription: nil)
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return image?.withSymbolConfiguration(configuration)
    }

    private func updateStatusMotion(busy: Bool) {
        if busy {
            guard InterfaceMotion.isEnabled,
                  statusDot.layer?.animation(forKey: "statusPulse") == nil
            else { return }
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1
            pulse.toValue = 0.48
            pulse.duration = 0.72
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            statusDot.layer?.add(pulse, forKey: "statusPulse")
        } else {
            statusDot.layer?.removeAnimation(forKey: "statusPulse")
            statusDot.alphaValue = 1
        }
    }

    private func setPowerMetric(_ watts: Double?, on label: NSTextField) {
        let value = watts.map { String(format: "%.1f", $0) } ?? "--"
        label.attributedStringValue = metricString(
            value: value,
            unit: "W",
            separatesUnit: true,
            alignment: label.alignment
        )
    }

    private func metricString(
        value: String,
        unit: String,
        separatesUnit: Bool,
        alignment: NSTextAlignment
    ) -> NSAttributedString {
        let separator = separatesUnit ? " " : ""
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let result = NSMutableAttributedString(
            string: "\(value)\(separator)\(unit)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: 17,
                    weight: .light
                ),
                .paragraphStyle: paragraph
            ]
        )
        let unitRange = (result.string as NSString).range(of: unit)
        result.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 9, weight: .light),
                .baselineOffset: 1
            ],
            range: unitRange
        )
        return result
    }

    private func updateColors() {
        layer?.backgroundColor = resolvedCGColor(.windowBackgroundColor)
        controlGroup.updateColors()
        fanControlRow.updateColors()
        lidModeRow.updateColors()
        lowPowerModeRow.updateColors()
        applyStatusTone()
    }
}

private final class ControlGroupView: NSView {
    private let topSeparator = NSView()
    private let horizontalSeparator = NSView()

    var usesOutlinedSurfaceForTesting: Bool {
        (layer?.borderWidth ?? 0) > 0
    }

    var separatorsMatchForTesting: Bool {
        layoutSubtreeIfNeeded()
        return abs(topSeparator.frame.minX - horizontalSeparator.frame.minX) < 0.1
            && abs(topSeparator.frame.maxX - horizontalSeparator.frame.maxX) < 0.1
    }

    var usesCenterSeparatorForTesting: Bool {
        false
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.borderWidth = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addRows(_ firstModeRow: NSView, _ secondModeRow: NSView, _ fanRow: NSView) {
        firstModeRow.translatesAutoresizingMaskIntoConstraints = false
        secondModeRow.translatesAutoresizingMaskIntoConstraints = false
        fanRow.translatesAutoresizingMaskIntoConstraints = false
        topSeparator.translatesAutoresizingMaskIntoConstraints = false
        horizontalSeparator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(topSeparator)
        addSubview(firstModeRow)
        addSubview(secondModeRow)
        addSubview(fanRow)
        addSubview(horizontalSeparator)

        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            topSeparator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            topSeparator.heightAnchor.constraint(equalToConstant: 1),

            firstModeRow.topAnchor.constraint(equalTo: topSeparator.bottomAnchor, constant: 3),
            firstModeRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            firstModeRow.widthAnchor.constraint(equalToConstant: 160),
            firstModeRow.heightAnchor.constraint(equalToConstant: 46),

            secondModeRow.topAnchor.constraint(equalTo: firstModeRow.topAnchor),
            secondModeRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 224),
            secondModeRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -21),
            secondModeRow.heightAnchor.constraint(equalTo: firstModeRow.heightAnchor),

            horizontalSeparator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            horizontalSeparator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            horizontalSeparator.topAnchor.constraint(
                equalTo: firstModeRow.bottomAnchor,
                constant: 3
            ),
            horizontalSeparator.heightAnchor.constraint(equalToConstant: 1),

            fanRow.topAnchor.constraint(equalTo: horizontalSeparator.bottomAnchor),
            fanRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            fanRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            fanRow.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func updateColors() {
        layer?.backgroundColor = resolvedCGColor(.clear)
        let separatorColor = resolvedCGColor(
            .separatorColor.withAlphaComponent(0.14)
        )
        topSeparator.wantsLayer = true
        topSeparator.layer?.backgroundColor = separatorColor
        horizontalSeparator.wantsLayer = true
        horizontalSeparator.layer?.backgroundColor = separatorColor
    }
}

private final class FanControlRowView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(
        labelWithString: L10n.text("风扇控制", "Fan control")
    )
    private let readingLabel = NSTextField(labelWithString: "-- R")
    private let modeLabel = NSTextField(labelWithString: L10n.text("自动", "Auto"))
    private let percentageLabel = NSTextField(labelWithString: "65%")
    private let switchControl: NSSwitch
    private let slider: NSSlider
    private var manualEnabled = false
    private var latestReading: FanReading?
    private var availabilityText: String? = L10n.text("检测中", "Detecting")
    private var sliderControlEnabled = false

    var modeTextForTesting: String {
        modeLabel.stringValue
    }

    var percentageTextForTesting: String {
        percentageLabel.stringValue
    }

    var sliderAlphaForTesting: CGFloat {
        slider.alphaValue
    }

    var percentageAlphaForTesting: CGFloat {
        percentageLabel.alphaValue
    }

    var modeAlphaForTesting: CGFloat {
        modeLabel.alphaValue
    }

    var usesRefinedSliderCellForTesting: Bool {
        slider.cell is RefinedSliderCell
    }

    var titleFontSizeForTesting: CGFloat {
        titleLabel.font?.pointSize ?? 0
    }

    var readingFontSizeForTesting: CGFloat {
        readingLabel.font?.pointSize ?? 0
    }

    var modeFontSizeForTesting: CGFloat {
        modeLabel.font?.pointSize ?? 0
    }

    var percentageFontSizeForTesting: CGFloat {
        percentageLabel.font?.pointSize ?? 0
    }

    var hasSymbolForTesting: Bool {
        iconView.image != nil
    }

    func iconFrame(in view: NSView) -> NSRect {
        iconView.convert(iconView.bounds, to: view)
    }

    func titleFrame(in view: NSView) -> NSRect {
        titleLabel.convert(titleLabel.bounds, to: view)
    }

    func readingFrame(in view: NSView) -> NSRect {
        readingLabel.convert(readingLabel.bounds, to: view)
    }

    func switchFrame(in view: NSView) -> NSRect {
        switchControl.convert(switchControl.bounds, to: view)
    }

    func sliderFrame(in view: NSView) -> NSRect {
        slider.convert(slider.bounds, to: view)
    }

    func elementsWithinBounds(in view: NSView) -> Bool {
        [
            iconView.convert(iconView.bounds, to: view),
            titleLabel.convert(titleLabel.bounds, to: view),
            readingLabel.convert(readingLabel.bounds, to: view),
            switchControl.convert(switchControl.bounds, to: view),
            slider.convert(slider.bounds, to: view),
            percentageLabel.convert(percentageLabel.bounds, to: view),
            modeLabel.convert(modeLabel.bounds, to: view)
        ].allSatisfy { view.bounds.contains($0) }
    }

    init(switchControl: NSSwitch, slider: NSSlider) {
        self.switchControl = switchControl
        self.slider = slider
        super.init(frame: .zero)
        buildInterface()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setManual(_ enabled: Bool, percentage: Int) {
        let shouldAnimate = manualEnabled != enabled
        manualEnabled = enabled
       switchControl.state = enabled ? .on : .off
       slider.doubleValue = Double(percentage)
        slider.isEnabled = sliderControlEnabled
       slider.needsDisplay = true
        percentageLabel.stringValue = "\(percentage)%"
        updateReadingText()
        updateColors()
        updateMotionState(animated: shouldAnimate)
    }

    func setReading(_ reading: FanReading?) {
        latestReading = reading
        updateReadingText()
    }

    func setEnabled(
        _ enabled: Bool,
        sliderEnabled: Bool,
        availabilityText: String?
    ) {
       self.availabilityText = availabilityText
       sliderControlEnabled = sliderEnabled
       switchControl.isEnabled = enabled
       slider.isEnabled = sliderEnabled
       updateReadingText()
        updateColors()
        if InterfaceMotion.isEnabled {
            InterfaceMotion.animate {
                self.switchControl.animator().alphaValue = enabled ? 1 : 0.55
            }
        } else {
            switchControl.alphaValue = enabled ? 1 : 0.55
        }
        updateMotionState(animated: true)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func updateColors() {
        let isLowSpeed = manualEnabled
            && slider.doubleValue < Double(FanControlPolicy.lowSpeedWarningThreshold)
        iconView.contentTintColor = manualEnabled ? .labelColor : .secondaryLabelColor
        titleLabel.textColor = .labelColor
        readingLabel.textColor = .secondaryLabelColor
        modeLabel.textColor = .secondaryLabelColor
        percentageLabel.textColor = isLowSpeed
            ? .systemOrange
            : (manualEnabled ? .labelColor : .tertiaryLabelColor)
    }

    func applyLanguage() {
        titleLabel.stringValue = L10n.text("风扇控制", "Fan control")
        switchControl.setAccessibilityLabel(L10n.text("风扇控制", "Fan control"))
        slider.setAccessibilityLabel(L10n.text("风扇速度", "Fan speed"))
        updateReadingText()
    }

    private func updateReadingText() {
        let readingDetail = latestReading?.detailText(manual: manualEnabled)
            ?? L10n.text(
                "风扇转速：此机型不可用或无法读取",
                "Fan speed is unavailable on this Mac"
            )
        if let availabilityText {
            readingLabel.toolTip = L10n.format(
                "%@；风扇控制：%@",
                "%@; fan control: %@",
                readingDetail,
                availabilityText
            )
       } else {
           readingLabel.toolTip = readingDetail
       }
        switchControl.toolTip = availabilityText.map {
            L10n.format("风扇控制：%@", "Fan control: %@", $0)
        }
        slider.toolTip = availabilityText.map {
            L10n.format("风扇控制：%@", "Fan control: %@", $0)
        } ?? (manualEnabled
            ? readingDetail
            : L10n.text("拖动滑条开启手动风扇", "Drag to enable manual fans"))
       readingLabel.stringValue = latestReading?.compactText ?? "-- R"
        modeLabel.stringValue = availabilityText
            ?? (manualEnabled ? L10n.text("手动", "Manual") : L10n.text("自动", "Auto"))
        percentageLabel.stringValue = availabilityText == nil ? "\(Int(slider.doubleValue.rounded()))%" : "—"
    }

    private func updateMotionState(animated: Bool) {
        let controlsAvailable = availabilityText == nil && switchControl.isEnabled
        let sliderAlpha: CGFloat = sliderControlEnabled ? (manualEnabled ? 1 : 0.42) : 0.3
        let modeAlpha: CGFloat = controlsAvailable ? (manualEnabled ? 1 : 0.72) : 0.62
        guard animated, InterfaceMotion.isEnabled else {
            slider.alphaValue = sliderAlpha
            percentageLabel.alphaValue = sliderAlpha
            modeLabel.alphaValue = modeAlpha
            return
        }
        modeLabel.alphaValue = 0.35
        InterfaceMotion.animate {
            self.slider.animator().alphaValue = sliderAlpha
            self.percentageLabel.animator().alphaValue = sliderAlpha
            self.modeLabel.animator().alphaValue = modeAlpha
        }
    }

    private func buildInterface() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let fanImage = NSImage(
            systemSymbolName: "fanblades",
            accessibilityDescription: nil
        ) ?? NSImage(systemSymbolName: "circle.grid.2x2", accessibilityDescription: nil)
        iconView.image = fanImage?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 15.5, weight: .light)
        )
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = .secondaryLabelColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 11.5, weight: .light)

        readingLabel.translatesAutoresizingMaskIntoConstraints = false
        readingLabel.font = .systemFont(ofSize: 9.5, weight: .light)
        readingLabel.lineBreakMode = .byClipping

        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.controlSize = .mini
        switchControl.isEnabled = false
        switchControl.setAccessibilityLabel(L10n.text("风扇控制", "Fan control"))

        modeLabel.translatesAutoresizingMaskIntoConstraints = false
        modeLabel.font = .systemFont(ofSize: 9.5, weight: .light)
        modeLabel.alignment = .center

        slider.translatesAutoresizingMaskIntoConstraints = false
        let refinedSliderCell = RefinedSliderCell()
        refinedSliderCell.minValue = slider.minValue
        refinedSliderCell.maxValue = slider.maxValue
        refinedSliderCell.doubleValue = slider.doubleValue
        refinedSliderCell.isContinuous = true
        slider.cell = refinedSliderCell
        slider.isContinuous = true
        slider.controlSize = .small
        slider.isEnabled = false
        slider.setAccessibilityLabel(L10n.text("风扇速度", "Fan speed"))

        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        percentageLabel.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        percentageLabel.alignment = .right

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(readingLabel)
        addSubview(switchControl)
        addSubview(modeLabel)
        addSubview(slider)
        addSubview(percentageLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -7.5),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 19),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 17),
            titleLabel.heightAnchor.constraint(equalToConstant: 17),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: slider.leadingAnchor,
                constant: -6
            ),

            switchControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -27),
            switchControl.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -7.5),
            switchControl.widthAnchor.constraint(equalToConstant: 28),
            switchControl.heightAnchor.constraint(equalToConstant: 16),

            modeLabel.centerXAnchor.constraint(equalTo: switchControl.centerXAnchor),
            modeLabel.topAnchor.constraint(equalTo: switchControl.bottomAnchor, constant: 2),
            modeLabel.widthAnchor.constraint(equalToConstant: 42),
            modeLabel.heightAnchor.constraint(equalToConstant: 13),

            readingLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            readingLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: slider.leadingAnchor,
                constant: -4
            ),
            readingLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            readingLabel.heightAnchor.constraint(equalToConstant: 14),

            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 116),
            slider.trailingAnchor.constraint(equalTo: percentageLabel.leadingAnchor, constant: -13),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -7.5),
            slider.heightAnchor.constraint(equalToConstant: 18),

            percentageLabel.trailingAnchor.constraint(
                equalTo: switchControl.leadingAnchor,
                constant: -23
            ),
            percentageLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            percentageLabel.widthAnchor.constraint(equalToConstant: 34)
        ])

        updateReadingText()
        updateColors()
        updateMotionState(animated: false)
    }
}

private final class ModeRowView: NSView {
    private let iconView = NSImageView()
    private let titleLabel: NSTextField
    private let switchControl: NSSwitch
    private var isActive = false
    private var isHovered = false
    private var trackingAreaReference: NSTrackingArea?

    var hasSymbolForTesting: Bool {
        iconView.image != nil
    }

    func iconFrame(in view: NSView) -> NSRect {
        iconView.convert(iconView.bounds, to: view)
    }

    func titleFrame(in view: NSView) -> NSRect {
        titleLabel.convert(titleLabel.bounds, to: view)
    }

    var titleFontSizeForTesting: CGFloat {
        titleLabel.font?.pointSize ?? 0
    }

    func switchFrame(in view: NSView) -> NSRect {
        switchControl.convert(switchControl.bounds, to: view)
    }

    init(
        title: String,
        symbolName: String,
        symbolFallback: String,
        switchControl: NSSwitch
    ) {
        titleLabel = NSTextField(labelWithString: title)
        self.switchControl = switchControl
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        ) ?? NSImage(systemSymbolName: symbolFallback, accessibilityDescription: nil)
        iconView.image = image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 16.5, weight: .light)
        )
        iconView.imageScaling = .scaleProportionallyUpOrDown
        buildInterface()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActive(_ active: Bool) {
        let shouldAnimate = isActive != active
        isActive = active
        updateColors(animated: shouldAnimate)
    }

    func setTitle(_ title: String) {
        titleLabel.stringValue = title
        titleLabel.invalidateIntrinsicContentSize()
        needsLayout = true
        switchControl.setAccessibilityLabel(title)
    }

    func setEnabled(_ enabled: Bool) {
        switchControl.isEnabled = enabled
        if InterfaceMotion.isEnabled {
            InterfaceMotion.animate {
                self.animator().alphaValue = enabled ? 1 : 0.6
            }
        } else {
            alphaValue = enabled ? 1 : 0.6
        }
    }

    func performPrimaryActionForTesting() {
        guard switchControl.isEnabled else { return }
        switchControl.performClick(nil)
    }

    var switchTrailingClearanceForTesting: CGFloat {
        layoutSubtreeIfNeeded()
        let switchAlignmentFrame = switchControl.alignmentRect(forFrame: switchControl.frame)
        return bounds.maxX - switchAlignmentFrame.maxX
    }

    func setHoveredForTesting(_ hovered: Bool) {
        isHovered = hovered
        updateColors()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateColors()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateColors()
    }

    override func mouseDown(with event: NSEvent) {
        guard switchControl.isEnabled else { return }
        switchControl.performClick(nil)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func updateColors(animated: Bool = false) {
        titleLabel.textColor = .labelColor
        iconView.contentTintColor = isActive ? .labelColor : .secondaryLabelColor
        let background: NSColor
        if isHovered {
            background = .labelColor.withAlphaComponent(0.05)
        } else {
            background = .clear
        }
        let resolvedBackground = resolvedCGColor(background)
        guard animated, InterfaceMotion.isEnabled else {
            layer?.backgroundColor = resolvedBackground
            return
        }
        let transition = CABasicAnimation(keyPath: "backgroundColor")
        transition.fromValue = layer?.backgroundColor
        transition.toValue = resolvedBackground
        transition.duration = InterfaceMotion.quickDuration
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer?.backgroundColor = resolvedBackground
        layer?.add(transition, forKey: "modeBackground")
    }

    private func buildInterface() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .secondaryLabelColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 11.5, weight: .light)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.controlSize = .mini
        switchControl.setAccessibilityLabel(titleLabel.stringValue)

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(switchControl)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -2),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 19),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 72),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: switchControl.leadingAnchor,
                constant: -8
            ),

            switchControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            switchControl.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -2),
            switchControl.widthAnchor.constraint(equalToConstant: 28),
            switchControl.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
}

private final class RefinedSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        // Keep the visible track endpoints under the knob centers. NSSliderCell
        // reserves the knob's half-width for travel, while the custom bar used
        // to paint through that reserved space and made 100% look unfinished.
        let nativeKnobRect = knobRect(flipped: flipped)
        let endpointInset = nativeKnobRect.width / 2
        let trackWidth = max(0, rect.width - endpointInset * 2)
        let track = NSRect(
            x: rect.minX + endpointInset,
            y: rect.midY - 1.5,
            width: trackWidth,
            height: 3
        )
        NSColor.separatorColor.withAlphaComponent(isEnabled ? 0.24 : 0.18).setFill()
        NSBezierPath(roundedRect: track, xRadius: 1.5, yRadius: 1.5).fill()

        let span = maxValue - minValue
        let fraction = span > 0
            ? min(1, max(0, (doubleValue - minValue) / span))
            : 0
        let activeTrack = NSRect(
            x: track.minX,
            y: track.minY,
            width: track.width * CGFloat(fraction),
            height: track.height
        )
        let activeColor = isEnabled
            ? NSColor.controlAccentColor
            : NSColor.secondaryLabelColor.withAlphaComponent(0.36)
        activeColor.setFill()
        NSBezierPath(roundedRect: activeTrack, xRadius: 1.5, yRadius: 1.5).fill()
    }

    override func drawKnob(_ knobRect: NSRect) {
        let diameter: CGFloat = 13
        let circleRect = NSRect(
            x: knobRect.midX - diameter / 2,
            y: knobRect.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
        let circle = NSBezierPath(ovalIn: circleRect)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = NSSize(width: 0, height: -0.5)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
        shadow.set()
        NSColor.controlBackgroundColor.setFill()
        circle.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.separatorColor.withAlphaComponent(0.7).setStroke()
        circle.lineWidth = 0.5
        circle.stroke()
    }
}

private final class HeaderIconButton: NSButton {
    private var isHovered = false
    private var trackingAreaReference: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        updateColors(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateColors(animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateColors(animated: true)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors(animated: false)
    }

    private func updateColors(animated: Bool) {
        let color = isHovered
            ? NSColor.labelColor.withAlphaComponent(0.075)
            : .clear
        let previousColor = layer?.backgroundColor
        let resolvedColor = resolvedCGColor(color)
        layer?.backgroundColor = resolvedColor
        contentTintColor = isHovered ? .labelColor : .secondaryLabelColor

        guard animated, InterfaceMotion.isEnabled, let previousColor else { return }
        let transition = CABasicAnimation(keyPath: "backgroundColor")
        transition.fromValue = previousColor
        transition.toValue = resolvedColor
        transition.duration = InterfaceMotion.quickDuration
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer?.add(transition, forKey: "settingsHover")
    }
}

private extension NSView {
    func resolvedCGColor(_ color: NSColor) -> CGColor {
        var resolvedColor = NSColor.clear.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            resolvedColor = color.cgColor
        }
        return resolvedColor
    }
}
