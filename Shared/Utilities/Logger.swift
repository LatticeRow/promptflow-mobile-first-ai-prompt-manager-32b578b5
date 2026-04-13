import OSLog

enum AppLogger {
    static let persistence = Logger(subsystem: "com.codex.promptatelier", category: "persistence")
    static let sharing = Logger(subsystem: "com.codex.promptatelier", category: "sharing")
    static let widget = Logger(subsystem: "com.codex.promptatelier", category: "widget")
}
