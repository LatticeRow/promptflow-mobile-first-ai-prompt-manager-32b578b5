import Foundation

final class AppRouter: ObservableObject {
    enum Route: Hashable {
        case library
        case prompt(UUID)
    }

    enum Tab: Hashable {
        case library
        case organize
        case settings
    }

    @Published var selectedTab: Tab = .library
    @Published var path: [Route] = []

    func handle(url: URL) {
        guard let route = DeepLinkHandler.route(for: url) else {
            return
        }

        selectedTab = .library
        switch route {
        case .library:
            path = []
        case .prompt:
            path = [route]
        }
    }
}
