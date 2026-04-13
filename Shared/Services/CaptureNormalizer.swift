import Foundation

struct CaptureNormalizer {
    struct NormalizedCapture {
        let title: String
        let body: String
        let sourceType: String
        let sourceURLString: String?
    }

    func normalize(text: String?, url: URL?) -> NormalizedCapture? {
        let trimmedText = normalizeBody(text ?? "")
        if !trimmedText.isEmpty {
            return NormalizedCapture(
                title: deriveTitle(from: trimmedText),
                body: trimmedText,
                sourceType: "text",
                sourceURLString: url?.absoluteString
            )
        }

        if let url {
            let title = url.host?.replacingOccurrences(of: "www.", with: "") ?? "Shared Link"
            return NormalizedCapture(
                title: title.capitalized,
                body: url.absoluteString,
                sourceType: "url",
                sourceURLString: url.absoluteString
            )
        }

        return nil
    }

    func normalizeBody(_ rawBody: String) -> String {
        let cleaned = rawBody
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lines = cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var normalizedLines: [String] = []
        var previousBlank = false

        for line in lines {
            let isBlank = line.isEmpty
            if isBlank && previousBlank {
                continue
            }

            normalizedLines.append(line)
            previousBlank = isBlank
        }

        return normalizedLines.joined(separator: "\n")
    }

    func deriveTitle(from body: String) -> String {
        body
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            .map { String($0.prefix(60)) }
            ?? "Untitled Prompt"
    }
}
