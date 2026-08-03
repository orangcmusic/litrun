import Foundation

@main
enum MenuBarPreferencesSmoke {
    static func main() {
        let suiteName = "io.github.achengbatian.lidrunswitch.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = MenuBarPreferences(defaults: defaults)
        precondition(preferences.selection == .defaultSelection)

        let temperatureAndFan = MenuBarSelection([.temperature, .fan])
        preferences.selection = temperatureAndFan
        precondition(preferences.selection == temperatureAndFan)
        precondition(temperatureAndFan.contains(.temperature))
        precondition(!temperatureAndFan.contains(.power))
        precondition(temperatureAndFan.contains(.fan))

        let memoryAndDisk = MenuBarSelection([.memory, .disk])
        precondition(memoryAndDisk.contains(.memory))
        precondition(memoryAndDisk.contains(.disk))
        precondition(memoryAndDisk.orderedMetrics == [.memory, .disk])

        let temperatureOnly = MenuBarSelection([.temperature])
        precondition(temperatureOnly.toggling(.temperature) == .empty)
        precondition(temperatureOnly.toggling(.power) == MenuBarSelection([.temperature, .power]))
        precondition(MenuBarSelection.empty.toggling(.power) == MenuBarSelection([.power]))
        precondition(MenuBarSelection.empty.statusRows().isEmpty)
        precondition(
            MenuBarSelection.empty.stackedStatusTitle(
                powerText: "12 W",
                fanText: "3200 RPM",
                temperatureText: "65°C"
            ).isEmpty
        )

        precondition(
            MenuBarSelection([.temperature]).stackedStatusTitle(
                powerText: "12 W",
                fanText: "3200 RPM",
                temperatureText: "65°C"
            ) == "65°C"
        )
        precondition(
            MenuBarSelection([.power, .fan]).stackedStatusTitle(
                powerText: "12 W",
                fanText: "3200 RPM",
                temperatureText: "65°C"
            ) == "12 W\n3.2k R"
        )
        precondition(
            MenuBarSelection.defaultSelection.stackedStatusTitle(
                powerText: "12 W",
                fanText: "3200 RPM",
                temperatureText: "65°C",
                memoryText: "18.6G",
                diskText: "92%"
            ) == "12 W  18.6G\n65°C  92%\n3.2k R"
        )
        precondition(
            MenuBarSelection.all.stackedStatusTitle(
                powerText: "12 W",
                fanText: "-- RPM",
                temperatureText: "65°C",
                memoryText: "--G",
                diskText: "--%"
            ) == "12 W  --G\n65°C  --%\n-- R  Net --"
        )
        precondition(
            MenuBarSelection([.power, .temperature, .fan, .memory, .network])
                .stackedStatusTitle(
                    powerText: "12 W",
                    fanText: "3200 RPM",
                    temperatureText: "65°C",
                    memoryText: "18.6G",
                    networkText: "↓2.1k ↑1k"
                ) == "12 W  3.2k R\n65°C  18.6G\n↓2.1k ↑1k"
        )
        precondition(MenuBarSelection.all.statusRows().count == 3)
        precondition(MenuBarSelection.all.statusRows()[0] == [.power, .memory])
        precondition(MenuBarSelection.all.statusRows()[1] == [.temperature, .disk])
        precondition(MenuBarSelection.all.statusRows()[2] == [.fan, .network])
        precondition(MenuBarSelection([.power, .temperature, .fan, .memory, .network]).statusRows()
            == [[.power, .fan], [.temperature, .memory], [.network]])
        precondition(MenuBarSelection([.power, .temperature, .fan, .memory]).statusRows()
            == [[.power, .fan], [.temperature, .memory]])

        defaults.removeObject(forKey: "menuBarMetrics")
        defaults.set("fan", forKey: "menuBarDisplayMode")
        precondition(
            preferences.selection == MenuBarSelection([.temperature, .fan])
        )

        preferences.selection = .empty
        precondition(preferences.selection == .empty)

        print("OK menu-bar-preference=empty-selection-persisted default=5 layout=vertical-two-column-grid migration=legacy")
    }
}
