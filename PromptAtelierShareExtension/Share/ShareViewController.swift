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

        Task {
            let extracted = await extractor.extract(from: extensionItems)
            let text = contentText?.isEmpty == false ? contentText : extracted.text
            saveService.save(text: text, url: extracted.url)
            extensionContext?.completeRequest(returningItems: [])
        }
    }

    override func configurationItems() -> [Any]! {
        []
    }
}
