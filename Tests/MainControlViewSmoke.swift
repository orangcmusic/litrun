import AppKit
import Foundation

@main
enum MainControlViewSmoke {
    static func main() throws {
        _ = NSApplication.shared
        InterfaceMotion.enabledOverrideForTesting = false
        L10n.use(.simplifiedChinese)
        let view = MainControlView(frame: NSRect(x: 0, y: 0, width: 456, height: 272))
        view.layoutSubtreeIfNeeded()

        precondition(view.lidModeSwitch.state == .off)
        precondition(view.lowPowerModeSwitch.state == .off)
        precondition(view.manualFanSwitch.state == .off)
        precondition(!view.manualFanSwitch.isEnabled)
        precondition(!view.fanSpeedSlider.isEnabled)
        precondition(view.fanModeTextForTesting == "检测中")
        precondition(view.fanSpeedSlider.minValue == 0)
        precondition(view.fanSpeedSlider.maxValue == 100)
        precondition(view.fanSpeedSlider.isContinuous)
        precondition(view.usesNativeSwitchesForTesting)
        precondition(view.lidModeSwitch.accessibilityRole() == .button)
        precondition(view.lidModeSwitch.accessibilitySubrole() == .switch)
        view.lidModeSwitch.performClick(nil)
        precondition(view.lidModeSwitch.state == .on)
        view.lidModeSwitch.performClick(nil)
        precondition(view.lidModeSwitch.state == .off)
        view.performLidModeRowClickForTesting()
        precondition(view.lidModeSwitch.state == .on)
        view.performLidModeRowClickForTesting()
        precondition(view.lidModeSwitch.state == .off)

        view.setLidControlAvailable(false)
        view.setModeControlsEnabled(lidEnabled: false, lowPowerEnabled: true)
        precondition(!view.lidModeSwitch.isEnabled)
        precondition(view.lowPowerModeSwitch.isEnabled)
        view.setFanControlsEnabled(false, availabilityText: "不可用")
        precondition(!view.manualFanSwitch.isEnabled)
        precondition(view.fanModeTextForTesting == "不可用")

       view.lidModeSwitch.state = .on
       view.updateModeAppearance(lidModeEnabled: true, lowPowerModeEnabled: false)
       view.setFanControlsEnabled(true, sliderEnabled: true)
        view.updateFanAppearance(manualEnabled: false, percentage: 65)
        precondition(view.manualFanSwitch.state == .off)
        precondition(view.fanSpeedSlider.isEnabled)
        precondition(view.fanModeTextForTesting == "自动")
       view.updateFanAppearance(manualEnabled: true, percentage: 65)
       precondition(view.fanPercentageTextForTesting == "65%")
        view.updateFans(FanReading(fans: [
            FanSpeed(index: 0, currentRPM: 3_200, maximumRPM: 5_779),
            FanSpeed(index: 1, currentRPM: 3_400, maximumRPM: 6_241)
        ]))
        view.updateTemperature(TemperatureReading(celsius: 64.8, thermalState: .nominal))
        precondition(view.temperatureLabel.stringValue == "65°C")
        view.layoutSubtreeIfNeeded()
        let manualSwitchFrame = view.manualFanSwitch.convert(
            view.manualFanSwitch.bounds,
            to: view
        )
        let lidSwitchFrame = view.lidModeSwitch.convert(
            view.lidModeSwitch.bounds,
            to: view
        )
        let lowPowerSwitchFrame = view.lowPowerModeSwitch.convert(
            view.lowPowerModeSwitch.bounds,
            to: view
        )
        let fanSliderFrame = view.fanSpeedSlider.convert(
            view.fanSpeedSlider.bounds,
            to: view
        )
        precondition(manualSwitchFrame.midY < lowPowerSwitchFrame.midY)
        precondition(abs(lidSwitchFrame.midY - lowPowerSwitchFrame.midY) < 0.1)
        precondition(lidSwitchFrame.maxX < lowPowerSwitchFrame.minX)
        precondition(abs(manualSwitchFrame.midY - fanSliderFrame.midY) < 16)
        let alignmentFrames = view.fanControlAlignmentFramesForTesting
        precondition(abs(alignmentFrames.fanSwitch.maxX - alignmentFrames.lowPowerSwitch.maxX) < 0.1)
        precondition(abs(alignmentFrames.fanSlider.minX - alignmentFrames.lidSwitch.minX) < 0.1)
        precondition(view.fanElementsWithinBoundsForTesting)
        precondition(containsText("风扇控制", in: view))
        precondition(containsText("手动", in: view))
        precondition(view.usesFeatureSymbolsForTesting)
        precondition(view.controlSeparatorsMatchForTesting)
        precondition(!view.controlGroupUsesCenterSeparatorForTesting)
        let featureColumns = view.featureColumnFramesForTesting
        precondition(abs(featureColumns.modeIcon.minX - featureColumns.fanIcon.minX) < 0.1)
        precondition(abs(featureColumns.modeTitle.minX - featureColumns.fanTitle.minX) < 0.1)
        guard abs(featureColumns.modeIcon.midY - featureColumns.modeTitle.midY) < 3 else {
            fatalError(
                "Mode icon/title vertical mismatch: \(featureColumns.modeIcon) vs \(featureColumns.modeTitle)"
            )
        }
        let fanTextFrame = featureColumns.fanTitle.union(featureColumns.fanReading)
        precondition(abs(featureColumns.fanIcon.midY - fanTextFrame.midY) < 5.1)
        precondition(featureColumns.fanTitle.maxX <= alignmentFrames.fanSlider.minX - 6.0)
        precondition(featureColumns.fanReading.maxX <= alignmentFrames.fanSlider.minX - 4.0)
        precondition(textField(named: "低功耗", in: view)?.frame.width ?? 0 >= 54)
        view.setModeControlsEnabled(lidEnabled: false, lowPowerEnabled: false)
        view.setFanControlsEnabled(false, availabilityText: "只读")
        precondition(!view.lidModeSwitch.isEnabled)
        precondition(!view.lowPowerModeSwitch.isEnabled)
        precondition(!view.manualFanSwitch.isEnabled)
        precondition(view.fanModeTextForTesting == "只读")

        view.setModeControlsEnabled(lidEnabled: true, lowPowerEnabled: true)
        view.setLidControlAvailable(true)
        view.setFanControlsEnabled(true, sliderEnabled: true)
        view.setStatus("合盖运行中", tone: .active)
        view.updatePower(PowerReading(
            watts: 12.8,
            source: .acCharging,
            chargingWatts: 18.4,
            adapterInputWatts: 31.2,
            externalConnected: true
        ))
        precondition(view.powerLabel.stringValue == "12.8 W")
        precondition(view.inputPowerLabel.stringValue == "31.2 W")
        precondition(!view.powerLabel.stringValue.contains("≈"))
        view.updateSystemResources(SystemResourceReading(
            memoryUsedBytes: 19_971_620_864,
            physicalMemoryBytes: 34_359_738_368,
            diskUsedBytes: 460_000_000_000,
            diskTotalBytes: 500_000_000_000
        ))
        precondition(view.memoryLabel.stringValue == "18.6 GB")
        precondition(view.diskLabel.stringValue == "92%")
        view.updateNetwork(NetworkTelemetryReading(
            downloadBytesPerSecond: 2_100,
            uploadBytesPerSecond: 1_000,
            interfaceCount: 1,
            state: .ready
        ))
        precondition(view.networkLabel.stringValue == "↓2.1k ↑1k")
        view.layoutSubtreeIfNeeded()
        let productFrame = view.productLabelFrameForTesting
        let productAlignmentFrame = view.productLabelAlignmentFrameForTesting
        let statusLineFrame = view.statusLineFrameForTesting
        let statusFrame = view.statusLabelFrameForTesting
        let statusAlignmentFrame = view.statusLabelAlignmentFrameForTesting
        let statusDotFrame = view.statusDotFrameForTesting
        let telemetryFrame = view.telemetryFrameForTesting
        let networkLineFrame = view.networkLineFrameForTesting
        let controlGroupFrame = view.controlGroupFrameForTesting
        precondition(view.bounds.size == NSSize(width: 456, height: 272))
        precondition(abs(telemetryFrame.minX - 6) < 0.1)
        precondition(abs(telemetryFrame.width - 444) < 0.1)
        precondition(abs(telemetryFrame.height - 43) < 0.1)
        precondition(abs(telemetryFrame.maxY - 190) < 0.1)
        precondition(abs(networkLineFrame.minX - telemetryFrame.minX - 22) < 0.1)
        precondition(networkLineFrame.maxY < telemetryFrame.minY)
        precondition(controlGroupFrame.maxY < networkLineFrame.minY)
        precondition(networkLineFrame.height == 12)
        precondition(abs(controlGroupFrame.height - 131) < 0.1)
        precondition(statusLineFrame.minX >= productAlignmentFrame.maxX + 10)
        precondition(statusAlignmentFrame.minX >= statusLineFrame.minX + 12)
        precondition(abs(productFrame.midY - statusFrame.midY) < 0.6)
        precondition(abs(statusDotFrame.midY - statusFrame.midY) < 0.1)
        precondition(abs(statusDotFrame.width - 6) < 0.1)
        precondition(statusAlignmentFrame.maxX <= statusLineFrame.maxX + 0.1)
        precondition(containsText("电脑用电", in: view))
        precondition(containsText("充电输入", in: view))
        precondition(containsText("内存占用", in: view))
        precondition(containsText("磁盘占用", in: view))
        precondition(containsText("芯片温度", in: view))
        precondition(containsText("网速", in: view))
        let inputFrame = view.inputPowerLabel.convert(view.inputPowerLabel.bounds, to: view)
        let powerFrame = view.powerLabel.convert(view.powerLabel.bounds, to: view)
        let memoryFrame = view.memoryLabel.convert(view.memoryLabel.bounds, to: view)
        let diskFrame = view.diskLabel.convert(view.diskLabel.bounds, to: view)
        let temperatureFrame = view.temperatureLabel.convert(
            view.temperatureLabel.bounds,
            to: view
        )
        let expectedMetricSpacing = telemetryFrame.width / 5
        precondition(abs(inputFrame.midX - powerFrame.midX - expectedMetricSpacing) < 0.6)
        precondition(abs(memoryFrame.midX - inputFrame.midX - expectedMetricSpacing) < 0.6)
        precondition(abs(diskFrame.midX - memoryFrame.midX - expectedMetricSpacing) < 0.6)
        precondition(abs(temperatureFrame.midX - diskFrame.midX - expectedMetricSpacing) < 0.6)
        precondition(view.powerLabel.alignment == .center)
        precondition(view.inputPowerLabel.alignment == .center)
        precondition(view.memoryLabel.alignment == .center)
        precondition(view.diskLabel.alignment == .center)
        precondition(view.temperatureLabel.alignment == .center)
        precondition(controlGroupFrame.maxY < telemetryFrame.minY)
        precondition(abs(controlGroupFrame.minY) < 0.2)
        precondition(!view.controlGroupUsesOutlinedSurfaceForTesting)
        precondition(view.lidModeSwitch.isEnabled)
        precondition(view.lowPowerModeSwitch.isEnabled)
        precondition(view.manualFanSwitch.isEnabled)
        precondition(view.fanSpeedSlider.isEnabled)
        precondition(abs(view.fanSliderAlphaForTesting - 1) < 0.01)
        precondition(abs(view.fanPercentageAlphaForTesting - 1) < 0.01)
        precondition(abs(view.fanModeAlphaForTesting - 1) < 0.01)
        precondition(view.fanSliderUsesRefinedCellForTesting)
        let typography = view.typographyForTesting
        precondition(abs(typography.product - 18) < 0.01)
        precondition(abs(typography.status - 11.5) < 0.01)
        precondition(abs(typography.metricTitle - 10) < 0.01)
        precondition(abs(typography.metricValue - 17) < 0.01)
        precondition(abs(typography.fanTitle - 11.5) < 0.01)
        precondition(abs(typography.fanReading - 9.5) < 0.01)
        precondition(abs(typography.fanMode - 9.5) < 0.01)
        precondition(abs(typography.fanPercentage - 10.5) < 0.01)
        precondition(abs(typography.modeTitle - 11.5) < 0.01)
        precondition(abs((view.networkLabel.font?.pointSize ?? 0) - 8.5) < 0.01)
        let modeTrailingClearances = view.modeRowSwitchTrailingClearancesForTesting
        precondition(abs(modeTrailingClearances.lid - 12) < 0.1)
        precondition(abs(modeTrailingClearances.lowPower - 12) < 0.1)
        if CommandLine.arguments.count > 1 {
            view.appearance = NSAppearance(named: .aqua)
            view.layoutSubtreeIfNeeded()
            view.needsDisplay = true
            view.displayIfNeeded()
            try render(view, to: CommandLine.arguments[1])
        }

        L10n.use(.english)
        view.applyLanguage()
        view.setStatus("Lid mode active", tone: .active)
        view.updatePower(PowerReading(
            watts: 12.8,
            source: .acCharging,
            chargingWatts: 18.4,
            adapterInputWatts: 31.2,
            externalConnected: true
        ))
        view.setFanControlsEnabled(true, sliderEnabled: true)
        view.updateFanAppearance(manualEnabled: true, percentage: 65)
        precondition(containsText("LitRun!", in: view))
        precondition(containsText("Fan control", in: view))
        precondition(
            (textField(named: "Low power", in: view)?.frame.width ?? 0)
                >= (textField(named: "Low power", in: view)?.intrinsicContentSize.width ?? 1)
        )
        precondition(view.fanModeTextForTesting == "Manual")
        precondition(view.powerLabel.stringValue == "12.8 W")
        precondition(view.inputPowerLabel.stringValue == "31.2 W")
        precondition(view.memoryLabel.stringValue == "18.6 GB")
        precondition(view.diskLabel.stringValue == "92%")
        precondition(view.networkLabel.stringValue == "↓2.1k ↑1k")
        view.layoutSubtreeIfNeeded()
        precondition(
            view.statusLineFrameForTesting.minX
                >= view.productLabelAlignmentFrameForTesting.maxX + 10
        )
        precondition(
            view.statusLabelAlignmentFrameForTesting.minX
                >= view.statusLineFrameForTesting.minX + 12
        )

        view.appearance = NSAppearance(named: .aqua)
        view.layoutSubtreeIfNeeded()
        view.needsDisplay = true
        view.displayIfNeeded()
        verifyReadableAppearance(view, expectsDarkBackground: false)
        verifyMetricTitleAppearance(view, expectsDarkBackground: false)

        if CommandLine.arguments.count > 2 {
            try render(view, to: CommandLine.arguments[2])
        }
        if CommandLine.arguments.count > 3 {
            view.appearance = NSAppearance(named: .darkAqua)
            view.layoutSubtreeIfNeeded()
            view.needsDisplay = true
            view.displayIfNeeded()
            verifyReadableAppearance(view, expectsDarkBackground: true)
            verifyMetricTitleAppearance(view, expectsDarkBackground: true)
            try render(view, to: CommandLine.arguments[3])
        }
        if CommandLine.arguments.count > 4 {
            L10n.use(.simplifiedChinese)
            view.applyLanguage()
            view.setStatus("待机", tone: .idle)
            view.lidModeSwitch.state = .off
            view.updateModeAppearance(
                lidModeEnabled: false,
                lowPowerModeEnabled: false
            )
            view.setLidModeHoveredForTesting(true)
            view.appearance = NSAppearance(named: .darkAqua)
            view.layoutSubtreeIfNeeded()
            view.needsDisplay = true
            view.displayIfNeeded()
            try render(view, to: CommandLine.arguments[4])
            view.setLidModeHoveredForTesting(false)
        }

        view.updateFanAppearance(manualEnabled: true, percentage: 0)
        precondition(view.fanSpeedSlider.doubleValue == 0)
        precondition(view.fanPercentageTextForTesting == "0%")

        if CommandLine.arguments.count > 5 {
            view.setFanControlsEnabled(true, sliderEnabled: true)
            view.updateFanAppearance(manualEnabled: true, percentage: 100)
            view.appearance = NSAppearance(named: .aqua)
            view.layoutSubtreeIfNeeded()
            view.needsDisplay = true
            view.displayIfNeeded()
            precondition(view.fanSpeedSlider.doubleValue == 100)
            try render(view, to: CommandLine.arguments[5])
        }

        print("OK main-control-view=ready size=456x272 telemetry=5 network=secondary")
        L10n.use(.simplifiedChinese)
    }

    private static func verifyReadableAppearance(
        _ view: MainControlView,
        expectsDarkBackground: Bool
    ) {
        guard let background = view.layer?.backgroundColor,
              let textColor = view.powerLabel.textColor
        else {
            fatalError("Appearance colors are unavailable")
        }
        let backgroundLuminance = luminance(background)
        var resolvedText = NSColor.clear.cgColor
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolvedText = textColor.cgColor
        }
        let textLuminance = luminance(resolvedText)
        if expectsDarkBackground {
            precondition(backgroundLuminance < 0.35)
            precondition(textLuminance > 0.65)
        } else {
            precondition(backgroundLuminance > 0.65)
            precondition(textLuminance < 0.35)
        }
    }

    private static func verifyMetricTitleAppearance(
        _ view: MainControlView,
        expectsDarkBackground: Bool
    ) {
        guard let title = textField(named: "Mac use", in: view),
              let textColor = title.textColor
        else {
            fatalError("Metric title color is unavailable")
        }
        var resolvedText = NSColor.clear.cgColor
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolvedText = textColor.cgColor
        }
        let textLuminance = luminance(resolvedText)
        if expectsDarkBackground {
            precondition(textLuminance > 0.55)
        } else {
            precondition(textLuminance < 0.45)
        }
    }

    private static func luminance(_ color: CGColor) -> CGFloat {
        guard let rgb = NSColor(cgColor: color)?.usingColorSpace(.deviceRGB) else {
            fatalError("Could not convert appearance color")
        }
        return 0.2126 * rgb.redComponent
            + 0.7152 * rgb.greenComponent
            + 0.0722 * rgb.blueComponent
    }

    private static func containsText(_ text: String, in view: NSView) -> Bool {
        if let field = view as? NSTextField, field.stringValue == text {
            return true
        }
        return view.subviews.contains { containsText(text, in: $0) }
    }

    private static func textField(named text: String, in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.stringValue == text {
            return field
        }
        return view.subviews.lazy.compactMap { textField(named: text, in: $0) }.first
    }

    private static func render(_ view: NSView, to path: String) throws {
        let destination = URL(fileURLWithPath: path)
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw NSError(domain: "MainControlViewSmoke", code: 1)
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let png = representation.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "MainControlViewSmoke", code: 2)
        }
        try png.write(to: destination, options: .atomic)
    }
}
