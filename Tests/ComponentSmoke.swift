import AppKit
import Foundation

@main
struct ComponentSmoke {
    static func main() {
        _ = NSApplication.shared

        guard let reading = PowerTelemetryReader.currentReading(),
              reading.watts >= 0,
              reading.watts < 250
        else {
            fatalError("Power telemetry is unavailable or outside the expected range")
        }
        if reading.externalConnected {
            guard reading.inputShortText != "未连接充电器",
                  reading.adapterInputWatts.map({ $0 >= 0 && $0 < 250 }) ?? true
            else {
                fatalError("Adapter-input telemetry contradicts the connected power state")
            }
        } else if reading.inputShortText != "未连接充电器" {
            fatalError("Battery use was incorrectly presented as adapter input")
        }
        guard LidStateReader.current() != .unknown else {
            fatalError("Lid state is unavailable")
        }
        precondition(BrightnessManager.isRecoveryCommand(
            arguments: ["LidRunSwitch", "--recover-saved-brightness"]
        ))
        precondition(!BrightnessManager.isRecoveryCommand(arguments: ["LidRunSwitch"]))

        let statusBar = StatusBarController()
        statusBar.updatePower(reading.statusText, detail: reading.detailText)
        let fanReading = FanTelemetryReader.currentReading()
        guard fanReading?.manualControlSupported == true else {
            fatalError("This development Mac's manual fan capability probe failed")
        }
        statusBar.updateFans(fanReading)
        let temperatureReading = TemperatureTelemetryReader.currentReading()
        statusBar.updateTemperature(temperatureReading)
        let systemResourceReading = SystemResourceTelemetryReader.currentReading()
        statusBar.updateSystemResources(systemResourceReading)
        let networkReading = NetworkTelemetryReading(
            downloadBytesPerSecond: 1_000,
            uploadBytesPerSecond: 500,
            interfaceCount: 1,
            state: .ready
        )
        statusBar.updateNetwork(networkReading)
        statusBar.updateSelection(.defaultSelection)
        statusBar.updateModes(lidModeEnabled: false, lowPowerModeEnabled: false)
        let statusTitle = statusBar.buttonTitleForTesting
        let statusLines = statusTitle.components(separatedBy: "\n")
        let defaultTopCells = statusLines[0].components(separatedBy: "  ")
        let defaultMiddleCells = statusLines[1].components(separatedBy: "  ")
        let defaultBottomCells = statusLines[2].components(separatedBy: "  ")
        guard statusLines.count == 3,
              defaultTopCells.count == 2,
              defaultTopCells[0].hasSuffix(" W"),
              !defaultTopCells[0].contains("."),
              !defaultTopCells[0].contains("用"),
              !defaultTopCells[0].contains("入"),
              defaultTopCells[1].contains("G"),
              defaultMiddleCells.count == 2,
              defaultMiddleCells[0].contains("°C"),
              defaultMiddleCells[1].contains("%"),
              defaultBottomCells.count == 1,
              defaultBottomCells[0].hasSuffix(" R"),
              StatusBarTypography.singleMetricFontSize == 12,
              StatusBarTypography.twoMetricFontSize == 10,
              StatusBarTypography.preferredFontSize == 8,
              StatusBarTypography.fourMetricFontSize == 9,
              StatusBarTypography.fourMetricFontSize(for: 22) == 9,
              StatusBarTypography.fourMetricFontSize(for: 25) == 9,
              StatusBarTypography.fourMetricFontSize(for: 28) == 9,
              StatusBarTypography.fourMetricFontSize(for: 30) == 9,
              (22...30).contains(statusBar.canvasHeightForTesting),
              StatusBarTypography.fontSize(for: 1, canvasHeight: 22) == 12,
              StatusBarTypography.fontSize(for: 2, canvasHeight: 22) == 10,
              StatusBarTypography.fontSize(for: 3, canvasHeight: 30) == 8,
              StatusBarTypography.fontSize(for: 3, canvasHeight: 26) == 7,
              StatusBarTypography.fontSize(for: 3, canvasHeight: 22) == 6
        else {
            fatalError("Status-bar default two-row layout is unavailable")
        }
        statusBar.updateSelection(
            MenuBarSelection([.power, .temperature, .fan, .memory])
        )
        precondition(statusBar.usesFourMetricLayoutForTesting)
        precondition(
            statusBar.columnGapForTesting == StatusBarTypography.fourMetricColumnGap
        )
        precondition(
            statusBar.fontSizeForTesting == StatusBarTypography.fourMetricFontSize(
                for: statusBar.canvasHeightForTesting
            )
        )
        precondition(
            statusBar.fontSizeForTesting
                == StatusBarTypography.fourMetricFontSize
        )
        statusBar.updateSelection(.empty)
        precondition(!statusBar.isVisibleForTesting)
        precondition(statusBar.buttonTitleForTesting.isEmpty)
        statusBar.updateSelection(MenuBarSelection([.temperature]))
        precondition(statusBar.isVisibleForTesting)
        precondition(statusBar.buttonTitleForTesting == temperatureReading.shortText)
        statusBar.updateSelection(.defaultSelection)
        statusBar.updateSelection(.all)
        precondition(!statusBar.usesCompactFiveMetricLayoutForTesting)
        precondition(!statusBar.usesFourMetricLayoutForTesting)
        precondition(statusBar.columnGapForTesting == StatusBarTypography.columnGap)
        precondition(
            statusBar.fontSizeForTesting == StatusBarTypography.fontSize(
                for: 3,
                canvasHeight: statusBar.canvasHeightForTesting
            )
        )
        let allStatusLines = statusBar.buttonTitleForTesting.components(separatedBy: "\n")
        let compactNetworkWidth = statusBar.canvasWidthForTesting
        guard allStatusLines.count == 3,
              allStatusLines.allSatisfy({ $0.components(separatedBy: "  ").count == 2 }),
              allStatusLines[2].contains("↓"),
              allStatusLines[2].contains("↑")
        else {
            fatalError("Status-bar optional network metric layout is unavailable")
        }
        statusBar.updateNetwork(
            NetworkTelemetryReading(
                downloadBytesPerSecond: 999_000_000,
                uploadBytesPerSecond: 999_000_000,
                interfaceCount: 1,
                state: .ready
            )
        )
        precondition(statusBar.canvasWidthForTesting == compactNetworkWidth)
        statusBar.updateSelection(
            MenuBarSelection([.power, .temperature, .fan, .memory, .network])
        )
        let fiveMetricLines = statusBar.buttonTitleForTesting.components(separatedBy: "\n")
        precondition(
            fiveMetricLines.count == 3
                && fiveMetricLines[0].components(separatedBy: "  ").count == 2
                && fiveMetricLines[1].components(separatedBy: "  ").count == 2
                && fiveMetricLines[2].components(separatedBy: "  ").count == 1
        )
        precondition(statusBar.usesCompactFiveMetricLayoutForTesting)
        precondition(!statusBar.usesFourMetricLayoutForTesting)
        precondition(
            statusBar.columnGapForTesting == StatusBarTypography.compactFiveMetricColumnGap
        )
        precondition(
            statusBar.fontSizeForTesting == StatusBarTypography.fontSize(
                for: 3,
                canvasHeight: statusBar.canvasHeightForTesting
            )
        )
        precondition(statusBar.canvasWidthForTesting < compactNetworkWidth)
        statusBar.updateSelection(.defaultSelection)
        verifyAdaptiveStatusLayout()
        if let previewPath = ProcessInfo.processInfo.environment["LIDRUN_STATUS_PREVIEW_PATH"] {
            writeStatusButtonPreview(statusBar, to: previewPath)
        }
        if let previewFourPath = ProcessInfo.processInfo.environment[
            "LIDRUN_STATUS_PREVIEW_FOUR_PATH"
        ] {
            statusBar.updateSelection(
                MenuBarSelection([.power, .temperature, .fan, .memory])
            )
            writeStatusButtonPreview(statusBar, to: previewFourPath)
            statusBar.updateSelection(.defaultSelection)
        }
        if let previewAllPath = ProcessInfo.processInfo.environment[
            "LIDRUN_STATUS_PREVIEW_ALL_PATH"
        ] {
            statusBar.updateSelection(.all)
            writeStatusButtonPreview(statusBar, to: previewAllPath)
            statusBar.updateSelection(.defaultSelection)
        }
        if let previewFiveNetworkPath = ProcessInfo.processInfo.environment[
            "LIDRUN_STATUS_PREVIEW_FIVE_NETWORK_PATH"
        ] {
            statusBar.updateNetwork(
                NetworkTelemetryReading(
                    downloadBytesPerSecond: 2_100,
                    uploadBytesPerSecond: 1_000,
                    interfaceCount: 1,
                    state: .ready
                )
            )
            statusBar.updateSelection(
                MenuBarSelection([.power, .temperature, .fan, .memory, .network])
            )
            writeStatusButtonPreview(statusBar, to: previewFiveNetworkPath)
            statusBar.updateSelection(.defaultSelection)
        }

        let brightness = BrightnessManager()
        brightness.recoverIfNeeded()
        brightness.start()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        brightness.stopAndRestore()

        let fanText = fanReading?.detailText ?? "fan=unavailable"
        print(
            "OK \(reading.detailText) \(reading.inputDetailText) " +
            "\(fanText) \(temperatureReading.detailText) " +
            "lid=readable status=ready brightness=readable"
        )
    }

    private static func verifyAdaptiveStatusLayout() {
        for lineCount in [1, 2, 3] {
            for height in [CGFloat(22), 25, 30] {
                let size = StatusBarTypography.fontSize(
                    for: lineCount,
                    canvasHeight: height
                )
                let font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
                let baselines = StatusBarTypography.baselines(
                    for: lineCount,
                    canvasHeight: height,
                    font: font
                )
                guard baselines.count == lineCount,
                      baselines == baselines.sorted(by: >),
                      baselines[0] + font.ascender <= height + 0.01,
                      baselines[lineCount - 1] + font.descender >= -0.01
                else {
                    fatalError(
                        "Status-bar text does not fit a \(height)-point menu bar"
                    )
                }
                if lineCount == 2 {
                    let fourSize = StatusBarTypography.fontSize(
                        for: lineCount,
                        canvasHeight: height,
                        isFourMetricLayout: true
                    )
                    let fourFont = NSFont.monospacedDigitSystemFont(
                        ofSize: fourSize,
                        weight: .medium
                    )
                    let fourBaselines = StatusBarTypography.baselines(
                        for: lineCount,
                        canvasHeight: height,
                        font: fourFont
                    )
                    guard fourBaselines[0] + fourFont.ascender <= height + 0.01,
                          fourBaselines[lineCount - 1] + fourFont.descender >= -0.01
                    else {
                        fatalError(
                            "Four-metric status text does not fit a \(height)-point menu bar"
                        )
                    }
                }
            }
        }
    }

    private static func writeStatusButtonPreview(
        _ controller: StatusBarController,
        to path: String
    ) {
        let statusItem = Mirror(reflecting: controller).children.first {
            $0.label == "statusItem"
        }?.value as? NSStatusItem
        guard let image = statusItem?.button?.image else {
            fatalError("Could not find status-button preview image")
        }
        let scale: CGFloat = 2
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(ceil(image.size.width * scale)),
            pixelsHigh: Int(ceil(image.size.height * scale)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        else {
            fatalError("Could not create status-button preview")
        }
        bitmap.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.current?.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Could not encode status-button preview")
        }
        do {
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            fatalError("Could not write status-button preview: \(error)")
        }
    }
}
