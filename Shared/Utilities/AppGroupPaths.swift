import Foundation

enum AppGroupPaths {
    static let appGroupIdentifier = "group.com.codex.promptatelier"
    static let cloudKitContainerIdentifier = "iCloud.com.codex.promptatelier"
    private static let storeDirectoryName = "SharedStore"
    private static let storeFileName = "PromptAtelier.sqlite"

    static func storeURL() -> URL {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            let storeDirectory = groupURL.appendingPathComponent(storeDirectoryName, isDirectory: true)
            try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            return storeDirectory.appendingPathComponent(storeFileName)
        }

        let fallbackDirectory = URL.applicationSupportDirectory.appending(path: "PromptAtelier/\(storeDirectoryName)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)
        return fallbackDirectory.appending(path: storeFileName)
    }
}
