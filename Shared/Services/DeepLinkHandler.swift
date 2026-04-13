import Foundation

enum DeepLinkHandler {
    static func route(for url: URL) -> AppRouter.Route? {
        guard url.scheme == "promptatelier" else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard url.host == "prompt", components.count == 1, let id = UUID(uuidString: components[0]) else {
            return nil
        }

        return .prompt(id)
    }
}
