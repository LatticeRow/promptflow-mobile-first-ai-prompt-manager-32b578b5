import CoreData
import Foundation
import SwiftUI

final class AppContainer: ObservableObject {
    let persistenceController: PersistenceController
    let repository: PromptRepository
    let router = AppRouter()

    init() {
        let controller = PersistenceController(
            target: .mainApp,
            inMemory: ProcessInfo.processInfo.arguments.contains("-promptatelier-ui-testing")
        )
        persistenceController = controller
        repository = PromptRepository(container: controller.container)
    }
}
