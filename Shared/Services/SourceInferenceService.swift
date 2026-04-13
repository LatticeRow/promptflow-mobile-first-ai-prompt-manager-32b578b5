import Foundation

struct SourceInferenceService {
    func inferTool(from capture: CaptureNormalizer.NormalizedCapture) -> String {
        let haystack = [capture.title, capture.body, capture.sourceURLString ?? ""].joined(separator: " ").lowercased()

        if haystack.contains("claude") {
            return "Claude"
        }

        if haystack.contains("midjourney") || haystack.contains("image prompt") {
            return "Midjourney"
        }

        if haystack.contains("chatgpt") {
            return "ChatGPT"
        }

        if haystack.contains("code") || haystack.contains("refactor") || haystack.contains("bug") {
            return "Coding AI"
        }

        return "Generic AI"
    }
}
