import SwiftUI

@main
struct PromptAtelierApp: App {
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
                    if ProcessInfo.processInfo.arguments.contains("-promptatelier-seed-sample") {
                        appContainer.repository.seedSamplePromptsIfNeeded()
                    }
                }
                .onOpenURL { url in
                    appContainer.router.handle(url: url)
                }
        }
    }
}

private struct RootTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.path) {
                LibraryView()
                    .navigationDestination(for: AppRouter.Route.self) { route in
                        switch route {
                        case .prompt(let id):
                            PromptDetailView(promptID: id)
                        }
                    }
            }
            .tabItem {
                Label("Library", systemImage: "square.stack.3d.up.fill")
            }
            .tag(AppRouter.Tab.library)

            NavigationStack {
                FolderListView()
            }
            .tabItem {
                Label("Organize", systemImage: "folder.fill.badge.person.crop")
            }
            .tag(AppRouter.Tab.organize)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(AppRouter.Tab.settings)
        }
    }
}
