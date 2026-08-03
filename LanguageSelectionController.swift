import AppKit

enum LanguageSelectionController {
    static func chooseInitialLanguage() -> AppLanguage {
        let alert = NSAlert()
        alert.messageText = "不熄！ / LitRun!"
        alert.informativeText = "选择语言  ·  Choose a language"
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "中文")
        alert.addButton(withTitle: "English")

        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertSecondButtonReturn
            ? .english
            : .simplifiedChinese
    }
}
