import Foundation

enum WidgetDeepLinks {
    static func promptURL(id: UUID) -> URL {
        URL(string: "promptatelier://prompt/\(id.uuidString)")!
    }
}
