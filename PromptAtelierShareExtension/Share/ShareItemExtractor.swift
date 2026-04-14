import Foundation
import UniformTypeIdentifiers

struct ExtractedShareItem {
    let text: String?
    let url: URL?
    let metadataTitle: String?
    let metadataText: String?
}

struct ShareItemExtractor {
    func extract(from items: [NSExtensionItem]) async -> ExtractedShareItem {
        var extractedText: String?
        var extractedURL: URL?
        var metadataTitle: String?
        var metadataText: String?

        for item in items {
            if metadataTitle == nil {
                metadataTitle = normalizedMetadataString(from: item.attributedTitle?.string)
            }

            if metadataText == nil {
                metadataText = normalizedMetadataString(from: item.attributedContentText?.string)
            }

            guard let attachments = item.attachments else {
                continue
            }

            for provider in attachments {
                if extractedURL == nil,
                   provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = await loadURL(from: provider) {
                    extractedURL = url
                }

                if extractedText == nil,
                   let text = await loadText(from: provider) {
                    extractedText = normalizedMetadataString(from: text)
                }
            }
        }

        return ExtractedShareItem(
            text: extractedText,
            url: extractedURL,
            metadataTitle: metadataTitle,
            metadataText: metadataText
        )
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        let candidateTypes = [
            UTType.plainText.identifier,
            UTType.text.identifier
        ]

        for candidateType in candidateTypes where provider.hasItemConformingToTypeIdentifier(candidateType) {
            let loadedText = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                provider.loadItem(forTypeIdentifier: candidateType, options: nil) { item, _ in
                    if let string = item as? String {
                        continuation.resume(returning: string)
                        return
                    }

                    if let attributedString = item as? NSAttributedString {
                        continuation.resume(returning: attributedString.string)
                        return
                    }

                    if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: string)
                        return
                    }

                    if let fileURL = item as? URL,
                       fileURL.isFileURL,
                       let string = try? String(contentsOf: fileURL, encoding: .utf8) {
                        continuation.resume(returning: string)
                        return
                    }

                    continuation.resume(returning: nil)
                }
            }

            if let loadedText, !loadedText.isEmpty {
                return loadedText
            }
        }

        return nil
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let string = item as? String {
                    continuation.resume(returning: URL(string: string))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func normalizedMetadataString(from value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
