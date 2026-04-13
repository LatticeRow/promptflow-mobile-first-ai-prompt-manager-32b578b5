import Foundation
import NaturalLanguage

struct CategorizationService {
    func classify(_ capture: CaptureNormalizer.NormalizedCapture) -> (tool: String, task: String, confidence: Double) {
        let tool = SourceInferenceService().inferTool(from: capture)
        let body = [capture.title, capture.body].joined(separator: " ").lowercased()

        let keywordMap: [(String, String, Double)] = [
            ("summarize", "Summarization", 0.92),
            ("summary", "Summarization", 0.9),
            ("refactor", "Coding", 0.94),
            ("bug", "Coding", 0.86),
            ("logo", "Image generation", 0.84),
            ("image", "Image generation", 0.8),
            ("research", "Research", 0.82),
            ("brainstorm", "Brainstorming", 0.8),
            ("write", "Writing", 0.78)
        ]

        if let match = keywordMap.first(where: { body.contains($0.0) }) {
            return (tool, match.1, match.2)
        }

        let recognizer = NLTagger(tagSchemes: [.lexicalClass])
        recognizer.string = body
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        var counts: [String: Int] = [:]

        recognizer.enumerateTags(in: body.startIndex..<body.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if tag == .noun || tag == .verb {
                let token = String(body[tokenRange])
                counts[token, default: 0] += 1
            }
            return true
        }

        let task: String
        if counts.keys.contains(where: { ["code", "build", "debug"].contains($0) }) {
            task = "Coding"
        } else if counts.keys.contains(where: { ["plan", "outline", "story"].contains($0) }) {
            task = "Writing"
        } else {
            task = "Research"
        }

        return (tool, task, 0.55)
    }
}
