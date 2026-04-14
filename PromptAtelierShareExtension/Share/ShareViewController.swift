import Social
import UIKit

final class ShareViewController: SLComposeServiceViewController {
    private let extractor = ShareItemExtractor()
    private let saveService = ShareSaveService()

    override func isContentValid() -> Bool {
        true
    }

    override func didSelectPost() {
        let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let composerText = contentText

        Task {
            let extractedShareItem = await extractor.extract(from: extensionItems)
            _ = saveService.save(payload: extractedShareItem, composerText: composerText)

            await MainActor.run {
                extensionContext?.completeRequest(returningItems: [])
            }
        }
    }

    override func configurationItems() -> [Any]! {
        []
    }
}
