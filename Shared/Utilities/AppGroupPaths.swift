import Foundation

enum AppGroupPaths {
    static let appGroupIdentifier = "group.com.codex.promptatelier"
    static let cloudKitContainerIdentifier = "iCloud.com.codex.promptatelier"
    static let storeFileName = "PromptAtelier.sqlite"

    static func storeURL() -> URL {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL.appendingPathComponent(storeFileName)
        }

        let fallbackDirectory = URL.applicationSupportDirectory.appending(path: "PromptAtelier", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)
        return fallbackDirectory.appending(path: storeFileName)
    }
}
