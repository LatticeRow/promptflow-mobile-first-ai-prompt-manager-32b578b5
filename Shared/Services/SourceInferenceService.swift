import Foundation

struct SourceInferenceService {
    struct InferredSource {
        let tool: String
        let sourceLabel: String?
    }

    func inferTool(from capture: CaptureNormalizer.NormalizedCapture) -> String {
        inferSource(from: capture).tool
    }

    func inferSource(from capture: CaptureNormalizer.NormalizedCapture) -> InferredSource {
        let host = capture.sourceHost ?? normalizedHost(from: capture.sourceURLString)
        if let host, let tool = toolForKnownHost(host) {
            return InferredSource(tool: tool, sourceLabel: host)
        }

        let haystack = [capture.title, capture.body, capture.sourceURLString ?? ""].joined(separator: " ").lowercased()

        if haystack.contains("claude") {
            return InferredSource(tool: "Claude", sourceLabel: host)
        }

        if haystack.contains("midjourney") || haystack.contains("image prompt") {
            return InferredSource(tool: "Midjourney", sourceLabel: host)
        }

        if haystack.contains("chatgpt") {
            return InferredSource(tool: "ChatGPT", sourceLabel: host)
        }

        if haystack.contains("code") || haystack.contains("refactor") || haystack.contains("bug") {
            return InferredSource(tool: "Coding AI", sourceLabel: host)
        }

        return InferredSource(tool: "Generic AI", sourceLabel: host)
    }

    private func toolForKnownHost(_ host: String) -> String? {
        if host.contains("chatgpt.com") || host.contains("openai.com") {
            return "ChatGPT"
        }

        if host.contains("claude.ai") || host.contains("anthropic.com") {
            return "Claude"
        }

        if host.contains("midjourney.com") {
            return "Midjourney"
        }

        if host.contains("github.com") || host.contains("copilot") {
            return "Coding AI"
        }

        return nil
    }

    private func normalizedHost(from urlString: String?) -> String? {
        guard
            let urlString,
            let host = URLComponents(string: urlString)?.host?.lowercased()
        else {
            return nil
        }

        let prefixes = ["www.", "m."]
        return prefixes.reduce(host) { partialHost, prefix in
            partialHost.hasPrefix(prefix) ? String(partialHost.dropFirst(prefix.count)) : partialHost
        }
    }
}
