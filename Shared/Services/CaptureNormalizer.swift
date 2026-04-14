import Foundation

struct CaptureNormalizer {
    private let maximumBodyLength = 24_000

    struct NormalizedCapture {
        let title: String
        let body: String
        let sourceType: String
        let sourceURLString: String?
        let sourceHost: String?
    }

    func normalize(
        text: String?,
        url: URL?,
        metadataTitle: String? = nil,
        metadataText: String? = nil
    ) -> NormalizedCapture? {
        let trimmedText = normalizeBody(text ?? "")
        let trimmedMetadataTitle = normalizeInline(metadataTitle)
        let trimmedMetadataText = normalizeBody(metadataText ?? "")

        if let url {
            let title = resolveURLTitle(
                text: trimmedText,
                metadataTitle: trimmedMetadataTitle,
                metadataText: trimmedMetadataText,
                url: url
            )
            let body = resolveURLBody(
                text: trimmedText,
                metadataText: trimmedMetadataText,
                url: url
            )

            return NormalizedCapture(
                title: title,
                body: body,
                sourceType: "url",
                sourceURLString: url.absoluteString,
                sourceHost: canonicalHost(for: url)
            )
        }

        if !trimmedText.isEmpty || !trimmedMetadataText.isEmpty {
            let normalizedBody = !trimmedText.isEmpty ? trimmedText : trimmedMetadataText
            return NormalizedCapture(
                title: trimmedMetadataTitle ?? deriveTitle(from: normalizedBody),
                body: normalizedBody,
                sourceType: "text",
                sourceURLString: nil,
                sourceHost: nil
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

        let normalizedBody = normalizedLines.joined(separator: "\n")
        guard normalizedBody.count > maximumBodyLength else {
            return normalizedBody
        }

        return String(normalizedBody.prefix(maximumBodyLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func deriveTitle(from body: String, maxLength: Int = 80) -> String {
        let title = body
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            .map { String($0.prefix(maxLength)) }
            ?? "Untitled Prompt"

        return normalizeInline(title) ?? "Untitled Prompt"
    }

    func displayHost(for url: URL) -> String {
        guard let host = canonicalHost(for: url), !host.isEmpty else {
            return "Shared Link"
        }

        let mappedHost: [String: String] = [
            "chatgpt.com": "ChatGPT",
            "openai.com": "OpenAI",
            "claude.ai": "Claude",
            "anthropic.com": "Anthropic",
            "midjourney.com": "Midjourney",
            "github.com": "GitHub",
            "perplexity.ai": "Perplexity",
            "gemini.google.com": "Gemini"
        ]

        if let exactMatch = mappedHost[host] {
            return exactMatch
        }

        let rootHost = host
            .split(separator: ".")
            .prefix(2)
            .joined(separator: ".")

        if let rootMatch = mappedHost[rootHost] {
            return rootMatch
        }

        return host
            .split(separator: ".")
            .first
            .map { segment in
                segment
                    .replacingOccurrences(of: "-", with: " ")
                    .capitalized
            }
            ?? "Shared Link"
    }

    private func resolveURLTitle(
        text: String,
        metadataTitle: String?,
        metadataText: String,
        url: URL
    ) -> String {
        let titleCandidates = [
            metadataTitle,
            nonURLTextCandidate(from: text, url: url).map { deriveTitle(from: $0) },
            nonURLTextCandidate(from: metadataText, url: url).map { deriveTitle(from: $0) }
        ]

        if let title = titleCandidates.compactMap({ $0 }).first(where: { !$0.isEmpty }) {
            return title
        }

        return displayHost(for: url)
    }

    private func resolveURLBody(text: String, metadataText: String, url: URL) -> String {
        let urlString = url.absoluteString
        let bodyCandidates = [
            nonURLTextCandidate(from: text, url: url),
            nonURLTextCandidate(from: metadataText, url: url)
        ]

        if let bodyCandidate = bodyCandidates.compactMap({ $0 }).first(where: { !$0.isEmpty }) {
            if bodyCandidate.localizedCaseInsensitiveContains(urlString) {
                return bodyCandidate
            }

            return "\(bodyCandidate)\n\n\(urlString)"
        }

        return urlString
    }

    private func normalizeInline(_ rawValue: String?) -> String? {
        guard let rawValue else {
            return nil
        }

        let normalized = rawValue
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? nil : normalized
    }

    private func nonURLTextCandidate(from text: String, url: URL) -> String? {
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else {
            return nil
        }

        let urlString = url.absoluteString.lowercased()
        let host = canonicalHost(for: url) ?? ""
        let reducedCandidate = candidate
            .lowercased()
            .replacingOccurrences(of: urlString, with: "")
            .replacingOccurrences(of: host, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !reducedCandidate.isEmpty else {
            return nil
        }

        return candidate
    }

    private func canonicalHost(for url: URL) -> String? {
        guard let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host?.lowercased() else {
            return nil
        }

        let prefixes = ["www.", "m."]
        return prefixes.reduce(host) { partialHost, prefix in
            partialHost.hasPrefix(prefix) ? String(partialHost.dropFirst(prefix.count)) : partialHost
        }
    }
}
