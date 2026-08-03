import AppKit
import Foundation

@main
enum SettingsPanelControllerSmoke {
    static func main() throws {
        _ = NSApplication.shared
        L10n.use(.simplifiedChinese)
        let controller = SettingsPanelController()
        controller.setSelection(MenuBarSelection([.temperature, .fan]))
        precondition(controller.selectedMetricsForTesting == [.temperature, .fan])
        controller.setSelection(.all)
        precondition(controller.selectedMetricsForTesting == MenuBarMetric.allCases)
        guard let view = controller.contentViewForTesting,
              let temperatureCheckbox = checkbox(titled: "温度", in: view),
              let powerCheckbox = checkbox(titled: "功耗", in: view),
              let fanCheckbox = checkbox(titled: "风扇", in: view),
              let memoryCheckbox = checkbox(titled: "内存", in: view),
              let diskCheckbox = checkbox(titled: "磁盘", in: view),
              let networkCheckbox = checkbox(titled: "网速", in: view)
        else {
            fatalError("Could not find all menu-bar metric checkboxes")
        }
        precondition(view.bounds.height >= 220)
        controller.setSelection(MenuBarSelection([.temperature]))
        temperatureCheckbox.performClick(nil)
        precondition(controller.selectedMetricsForTesting.isEmpty)
        precondition(temperatureCheckbox.state == .off)
        powerCheckbox.performClick(nil)
        precondition(controller.selectedMetricsForTesting == [.power])
        temperatureCheckbox.performClick(nil)
        precondition(controller.selectedMetricsForTesting == [.power, .temperature])
        fanCheckbox.performClick(nil)
        memoryCheckbox.performClick(nil)
        diskCheckbox.performClick(nil)
        networkCheckbox.performClick(nil)
        precondition(controller.selectedMetricsForTesting == MenuBarMetric.allCases)

        var changedLanguage: AppLanguage?
        controller.onLanguageChange = { changedLanguage = $0 }
        L10n.use(.english)
        controller.selectLanguageForTesting(.english)
        controller.setLanguage(.english)
        precondition(controller.selectedLanguageForTesting == .english)
        precondition(changedLanguage == .english)
        guard checkbox(titled: "Temperature", in: view) != nil,
              checkbox(titled: "Power", in: view) != nil,
              checkbox(titled: "Fans", in: view) != nil,
              checkbox(titled: "Memory", in: view) != nil,
              checkbox(titled: "Disk", in: view) != nil,
              checkbox(titled: "Network", in: view) != nil
        else {
            fatalError("English settings labels were not applied")
        }

        if CommandLine.arguments.count > 1,
           let view = controller.contentViewForTesting {
            view.appearance = NSAppearance(named: .aqua)
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            view.layoutSubtreeIfNeeded()
            try render(view, to: CommandLine.arguments[1])
        }
        L10n.use(.simplifiedChinese)
        print("OK settings-panel=six-checkboxes language=switchable")
    }

    private static func checkbox(titled title: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == title {
            return button
        }
        return view.subviews.lazy.compactMap { checkbox(titled: title, in: $0) }.first
    }

    private static func render(_ view: NSView, to path: String) throws {
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw NSError(domain: "SettingsPanelControllerSmoke", code: 1)
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let png = representation.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SettingsPanelControllerSmoke", code: 2)
        }
        try png.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}
