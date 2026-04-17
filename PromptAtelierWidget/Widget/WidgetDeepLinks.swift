import Foundation

enum WidgetDeepLinks {
    static func libraryURL() -> URL {
        URL(string: "promptatelier://library")!
    }

    static func promptURL(id: UUID) -> URL {
        URL(string: "promptatelier://prompt/\(id.uuidString)")!
    }
}
