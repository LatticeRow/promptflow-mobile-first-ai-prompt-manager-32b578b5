import SwiftUI

@main
struct PromptAtelierApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appContainer = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.managedObjectContext, appContainer.persistenceController.container.viewContext)
                .environmentObject(appContainer)
                .environmentObject(appContainer.router)
                .preferredColorScheme(.dark)
                .tint(Color("AccentColor"))
                .task {
                    seedLaunchDataIfNeeded()

                    if ProcessInfo.processInfo.arguments.contains("-promptatelier-seed-sample") {
                        appContainer.repository.seedSamplePromptsIfNeeded()
                    }

                    if let deepLink = launchDeepLinkURL() {
                        seedLaunchTestPromptIfNeeded(for: deepLink, repository: appContainer.repository)
                        appContainer.router.handle(url: deepLink)
                    }

                    appContainer.handleForegroundActivation()
                }
                .onOpenURL { url in
                    appContainer.router.handle(url: url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else {
                        return
                    }

                    appContainer.handleForegroundActivation()
                }
        }
    }

    private func seedLaunchDataIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-promptatelier-seed-browse-flow") {
            appContainer.repository.seedScenarioForUITests(.browseFlow)
        }

        if arguments.contains("-promptatelier-seed-copy-flow") {
            appContainer.repository.seedScenarioForUITests(.copyFlow)
        }
    }
}

private func launchDeepLinkURL() -> URL? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let flagIndex = arguments.firstIndex(of: "-promptatelier-open-url"),
          arguments.indices.contains(flagIndex + 1) else {
        return nil
    }

    return URL(string: arguments[flagIndex + 1])
}

private func seedLaunchTestPromptIfNeeded(for url: URL, repository: PromptRepository) {
    guard ProcessInfo.processInfo.arguments.contains("-promptatelier-ui-testing"),
          case .prompt(let promptID) = DeepLinkHandler.route(for: url) else {
        return
    }

    repository.seedPromptForTesting(
        id: promptID,
        title: "Deep Link Prompt",
        body: "Open this prompt straight from a widget or URL."
    )
}

private struct RootTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.path) {
                LibraryView()
                    .navigationDestination(for: AppRouter.Route.self) { route in
                        switch route {
                        case .library:
                            LibraryView()
                        case .prompt(let id):
                            PromptDetailView(promptID: id)
                        }
                    }
            }
            .tabItem {
                Label("Library", systemImage: "square.stack.3d.up.fill")
                    .accessibilityIdentifier("tab.library")
            }
            .tag(AppRouter.Tab.library)

            NavigationStack {
                FolderListView()
            }
            .tabItem {
                Label("Organize", systemImage: "folder.fill.badge.person.crop")
                    .accessibilityIdentifier("tab.organize")
            }
            .tag(AppRouter.Tab.organize)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
                    .accessibilityIdentifier("tab.settings")
            }
            .tag(AppRouter.Tab.settings)
        }
    }
}
