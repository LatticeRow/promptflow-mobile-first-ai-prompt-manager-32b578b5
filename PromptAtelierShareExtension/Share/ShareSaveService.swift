import Foundation
import WidgetKit

struct ShareSaveService {
    @discardableResult
    func save(payload: ExtractedShareItem, composerText: String?) -> Bool {
        let repository = PromptRepository(container: PersistenceController.sharedShareExtension.container)
        let primaryText = normalizedComposerText(composerText) ?? payload.text
        let prompt = repository.savePrompt(
            text: primaryText,
            url: payload.url,
            metadataTitle: payload.metadataTitle,
            metadataText: payload.metadataText,
            sourceAppBundleID: nil,
            captureMethod: "share_extension",
            shouldClassify: false
        )

        guard prompt != nil else {
            AppLogger.sharing.error("Share extension received content but could not create a prompt.")
            return false
        }

        AppGroupPaths.recordSharedCapture()
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }

    private func normalizedComposerText(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
