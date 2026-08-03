import Foundation

enum AppLanguage: String, CaseIterable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var productName: String {
        switch self {
        case .simplifiedChinese:
            return "不熄！"
        case .english:
            return "LitRun!"
        }
    }

    var segmentIndex: Int {
        switch self {
        case .simplifiedChinese:
            return 0
        case .english:
            return 1
        }
    }

    init?(segmentIndex: Int) {
        switch segmentIndex {
        case 0:
            self = .simplifiedChinese
        case 1:
            self = .english
        default:
            return nil
        }
    }
}

final class LanguagePreferences {
    private static let languageKey = "appLanguage"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedLanguage: AppLanguage? {
        get {
            defaults.string(forKey: Self.languageKey).flatMap(AppLanguage.init(rawValue:))
        }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Self.languageKey)
            } else {
                defaults.removeObject(forKey: Self.languageKey)
            }
        }
    }
}

enum L10n {
    private static let lock = NSLock()
    private static var storedLanguage = AppLanguage.simplifiedChinese

    static var language: AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        return storedLanguage
    }

    static func use(_ language: AppLanguage) {
        lock.lock()
        storedLanguage = language
        lock.unlock()
    }

    static func text(_ simplifiedChinese: String, _ english: String) -> String {
        language == .simplifiedChinese ? simplifiedChinese : english
    }

    static func format(
        _ simplifiedChinese: String,
        _ english: String,
        _ arguments: CVarArg...
    ) -> String {
        let language = language
        let format = language == .simplifiedChinese ? simplifiedChinese : english
        return String(
            format: format,
            locale: Locale(identifier: language.rawValue),
            arguments: arguments
        )
    }
}
