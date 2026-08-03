import Foundation

enum AppPaths {
    static let applicationSupportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("LidRunSwitch", isDirectory: true)
    }()

    static let legacyDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex-lid-run-switch", isDirectory: true)

    static func ensureApplicationSupportDirectory() throws {
        try FileManager.default.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true
        )
    }

    static func migrateLegacyFileIfNeeded(named name: String) throws {
        let destination = applicationSupportDirectory.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }

        let source = legacyDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: source.path) else { return }

        try ensureApplicationSupportDirectory()
        try FileManager.default.copyItem(at: source, to: destination)
    }
}
