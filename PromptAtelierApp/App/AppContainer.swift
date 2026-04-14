import CoreData
import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class AppContainer: ObservableObject {
    let persistenceController: PersistenceController
    let repository: PromptRepository
    let router = AppRouter()
    private var hasHandledInitialActivation = false
    private var lastObservedCaptureToken: TimeInterval

    init() {
        let controller = if ProcessInfo.processInfo.arguments.contains("-promptatelier-ui-testing") {
            PersistenceController(target: .mainApp, inMemory: true)
        } else {
            PersistenceController.sharedApp
        }
        persistenceController = controller
        repository = PromptRepository(container: controller.container)
        lastObservedCaptureToken = AppGroupPaths.latestSharedCaptureToken()
    }

    func handleForegroundActivation() {
        let latestToken = AppGroupPaths.latestSharedCaptureToken()
        let shouldRefreshFromSharedStore = !hasHandledInitialActivation || latestToken > lastObservedCaptureToken

        if shouldRefreshFromSharedStore {
            persistenceController.container.viewContext.refreshAllObjects()
            lastObservedCaptureToken = latestToken
        }

        let enrichedPromptCount = repository.enrichPendingPrompts(limit: 50)
        if shouldRefreshFromSharedStore || enrichedPromptCount > 0 {
            persistenceController.container.viewContext.refreshAllObjects()
            WidgetCenter.shared.reloadAllTimelines()
        }

        hasHandledInitialActivation = true
    }
}
