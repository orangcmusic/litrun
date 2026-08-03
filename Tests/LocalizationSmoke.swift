import Foundation

@main
enum LocalizationSmoke {
    static func main() {
        let suiteName = "io.github.achengbatian.lidrunswitch.language.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = LanguagePreferences(defaults: defaults)
        precondition(preferences.selectedLanguage == nil)
        preferences.selectedLanguage = .simplifiedChinese
        precondition(preferences.selectedLanguage == .simplifiedChinese)
        preferences.selectedLanguage = .english
        precondition(preferences.selectedLanguage == .english)

        let reading = PowerReading(
            watts: 12.8,
            source: .acCharging,
            chargingWatts: 18.4,
            adapterInputWatts: 31.2,
            externalConnected: true
        )
        L10n.use(.simplifiedChinese)
        precondition(L10n.language.productName == "不熄！")
        precondition(reading.shortText == "电脑用电 12.8 W")

        L10n.use(.english)
        precondition(L10n.language.productName == "LitRun!")
        precondition(reading.shortText == "Mac use 12.8 W")
        precondition(reading.inputShortText == "Power in 31.2 W")

        L10n.use(.simplifiedChinese)
        print("OK localization=zh-Hans+en first-launch-preference=persistent")
    }
}
