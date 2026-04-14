import Foundation

enum AppGroupPaths {
    static let appGroupIdentifier = "group.com.codex.promptatelier"
    static let cloudKitContainerIdentifier = "iCloud.com.codex.promptatelier"
    private static let storeDirectoryName = "SharedStore"
    private static let storeFileName = "PromptAtelier.sqlite"
    private static let sharedCaptureTokenKey = "sharedCaptureToken"

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

    static func recordSharedCapture(at date: Date = .now) {
        sharedDefaults().set(date.timeIntervalSince1970, forKey: sharedCaptureTokenKey)
    }

    static func latestSharedCaptureToken() -> TimeInterval {
        sharedDefaults().double(forKey: sharedCaptureTokenKey)
    }

    private static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
