import Foundation
import NaturalLanguage

struct CategorizationService {
    struct Classification {
        let tool: String
        let task: String
        let confidence: Double
    }

    private let sourceInferenceService = SourceInferenceService()

    func classify(_ capture: CaptureNormalizer.NormalizedCapture, sourceAppBundleID: String?) -> Classification {
        let inferredSource = sourceInferenceService.inferSource(from: capture, sourceAppBundleID: sourceAppBundleID)
        let evidence = ClassificationEvidence(capture: capture, sourceAppBundleID: sourceAppBundleID)
        let scoredTasks = taskScores(from: evidence, inferredTool: inferredSource.tool)
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.rawValue < rhs.key.rawValue
                }

                return lhs.value > rhs.value
            }

        let bestTask = scoredTasks.first?.key ?? .writing
        let bestTaskScore = scoredTasks.first?.value ?? 0
        let runnerUpScore = scoredTasks.dropFirst().first?.value ?? 0
        let confidence = confidence(toolConfidence: inferredSource.confidence, bestTaskScore: bestTaskScore, runnerUpScore: runnerUpScore)

        return Classification(
            tool: inferredSource.tool.rawValue,
            task: bestTask.rawValue,
            confidence: confidence
        )
    }

    private func taskScores(
        from evidence: ClassificationEvidence,
        inferredTool: PromptTaxonomy.ToolTag
    ) -> [PromptTaxonomy.TaskTag: Double] {
        var scores = Dictionary(uniqueKeysWithValues: PromptTaxonomy.TaskTag.allCases.map { ($0, 0.0) })

        for task in PromptTaxonomy.TaskTag.allCases {
            for rule in task.phraseRules where evidence.haystack.contains(rule.pattern) {
                scores[task, default: 0] += rule.weight
            }

            for term in evidence.lexicalTerms {
                if let weight = task.tokenWeights[term] {
                    scores[task, default: 0] += weight
                }
            }
        }

        if evidence.urlPath.contains("/imagine") || evidence.urlPath.contains("image") || evidence.urlPath.contains("gallery") {
            scores[.imageGeneration, default: 0] += 1.6
        }

        if evidence.urlPath.contains("research") || evidence.urlPath.contains("discover") {
            scores[.research, default: 0] += 1.2
        }

        if evidence.urlPath.contains("summary") || evidence.urlPath.contains("summarize") {
            scores[.summarization, default: 0] += 1.3
        }

        switch inferredTool {
        case .midjourney:
            scores[.imageGeneration, default: 0] += 2.2
        case .codingAI:
            scores[.coding, default: 0] += 2.0
        case .chatGPT, .claude, .genericAI:
            break
        }

        if scores.values.allSatisfy({ $0 == 0 }) {
            scores[defaultTask(for: evidence), default: 0] = 0.6
        }

        return scores
    }

    private func defaultTask(for evidence: ClassificationEvidence) -> PromptTaxonomy.TaskTag {
        if evidence.haystack.contains("idea") || evidence.haystack.contains("brainstorm") {
            return .brainstorming
        }

        if evidence.haystack.contains("research") || evidence.haystack.contains("compare") {
            return .research
        }

        return .writing
    }

    private func confidence(toolConfidence: Double, bestTaskScore: Double, runnerUpScore: Double) -> Double {
        let taskSignal = min(bestTaskScore * 0.09, 0.36)
        let marginSignal = min(max(bestTaskScore - runnerUpScore, 0) * 0.08, 0.18)
        let confidence = 0.34 + (toolConfidence * 0.34) + taskSignal + marginSignal
        return min(max(confidence, 0.42), 0.98)
    }

    private struct ClassificationEvidence {
        let haystack: String
        let urlPath: String
        let lexicalTerms: [String]

        init(capture: CaptureNormalizer.NormalizedCapture, sourceAppBundleID: String?) {
            let sourceURL = capture.sourceURLString ?? ""
            haystack = [capture.title, capture.body, sourceURL, sourceAppBundleID ?? ""]
                .joined(separator: " ")
                .lowercased()

            if let sourceURLString = capture.sourceURLString,
               let components = URLComponents(string: sourceURLString) {
                urlPath = [components.host ?? "", components.path].joined(separator: "/").lowercased()
            } else {
                urlPath = ""
            }

            lexicalTerms = Self.extractLexicalTerms(from: haystack)
        }

        private static func extractLexicalTerms(from text: String) -> [String] {
            let tagger = NLTagger(tagSchemes: [.lemma])
            tagger.string = text

            let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther, .joinNames]
            var terms: [String] = []

            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: options) { tag, tokenRange in
                let surface = String(text[tokenRange]).lowercased()
                if surface.count >= 3 {
                    terms.append(surface)
                }

                if let lemma = tag?.rawValue.lowercased(), lemma.count >= 3, lemma != surface {
                    terms.append(lemma)
                }

                return true
            }

            return terms
        }
    }
}
