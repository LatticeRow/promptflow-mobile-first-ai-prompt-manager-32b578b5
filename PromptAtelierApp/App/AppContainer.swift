import CoreData
import Foundation
import SwiftUI

final class AppContainer: ObservableObject {
    let persistenceController: PersistenceController
    let repository: PromptRepository
    let router = AppRouter()

    init() {
        let controller = if ProcessInfo.processInfo.arguments.contains("-promptatelier-ui-testing") {
            PersistenceController(target: .mainApp, inMemory: true)
        } else {
            PersistenceController.sharedApp
        }
        persistenceController = controller
        repository = PromptRepository(container: controller.container)
    }
}
