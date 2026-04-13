import Foundation

struct ShareSaveService {
    func save(text: String?, url: URL?) {
        let repository = PromptRepository(container: PersistenceController(target: .shareExtension).container)
        _ = repository.savePrompt(
            text: text,
            url: url,
            sourceAppBundleID: Bundle.main.bundleIdentifier,
            captureMethod: "share_extension"
        )
    }
}
