import Foundation

enum PromptTaxonomy {
    /// Intentionally small offline taxonomy for MVP categorization and manual recategorization.
    enum ToolTag: String, CaseIterable, Identifiable {
        case chatGPT = "ChatGPT"
        case claude = "Claude"
        case midjourney = "Midjourney"
        case codingAI = "Coding AI"
        case genericAI = "Generic AI"

        var id: String { rawValue }

        var accessibilityIdentifier: String {
            switch self {
            case .chatGPT:
                return "chatgpt"
            case .claude:
                return "claude"
            case .midjourney:
                return "midjourney"
            case .codingAI:
                return "coding_ai"
            case .genericAI:
                return "generic_ai"
            }
        }

        var sourceHosts: [String] {
            switch self {
            case .chatGPT:
                return ["chatgpt.com", "openai.com"]
            case .claude:
                return ["claude.ai", "anthropic.com"]
            case .midjourney:
                return ["midjourney.com"]
            case .codingAI:
                return ["github.com", "copilot.microsoft.com"]
            case .genericAI:
                return []
            }
        }

        var sourceBundleHints: [String] {
            switch self {
            case .chatGPT:
                return ["com.openai.chatgpt", "openai"]
            case .claude:
                return ["claude", "anthropic"]
            case .midjourney:
                return ["midjourney"]
            case .codingAI:
                return ["copilot", "github", "xcode", "com.apple.dt.xcode"]
            case .genericAI:
                return []
            }
        }

        var keywordHints: [String] {
            switch self {
            case .chatGPT:
                return ["chatgpt", "gpt-4", "gpt 4", "gpt-5", "gpt 5", "openai"]
            case .claude:
                return ["claude", "anthropic"]
            case .midjourney:
                return ["midjourney", "/imagine", "image prompt"]
            case .codingAI:
                return ["copilot", "refactor", "debug", "bug", "swift", "xcode", "code review"]
            case .genericAI:
                return []
            }
        }
    }

    enum TaskTag: String, CaseIterable, Identifiable {
        case writing = "Writing"
        case coding = "Coding"
        case imageGeneration = "Image generation"
        case summarization = "Summarization"
        case research = "Research"
        case brainstorming = "Brainstorming"

        var id: String { rawValue }

        var accessibilityIdentifier: String {
            switch self {
            case .writing:
                return "writing"
            case .coding:
                return "coding"
            case .imageGeneration:
                return "image_generation"
            case .summarization:
                return "summarization"
            case .research:
                return "research"
            case .brainstorming:
                return "brainstorming"
            }
        }

        var phraseRules: [WeightedRule] {
            switch self {
            case .writing:
                return [
                    .init(pattern: "write", weight: 1.4),
                    .init(pattern: "rewrite", weight: 1.7),
                    .init(pattern: "draft", weight: 1.5),
                    .init(pattern: "email", weight: 1.2),
                    .init(pattern: "tweet thread", weight: 1.8),
                    .init(pattern: "headline", weight: 1.2),
                ]
            case .coding:
                return [
                    .init(pattern: "refactor", weight: 2.4),
                    .init(pattern: "debug", weight: 2.3),
                    .init(pattern: "bug", weight: 2.0),
                    .init(pattern: "swiftui", weight: 2.1),
                    .init(pattern: "xcode", weight: 1.8),
                    .init(pattern: "code review", weight: 1.8),
                    .init(pattern: "pull request", weight: 1.5),
                ]
            case .imageGeneration:
                return [
                    .init(pattern: "midjourney", weight: 2.6),
                    .init(pattern: "logo", weight: 2.2),
                    .init(pattern: "image", weight: 1.8),
                    .init(pattern: "illustration", weight: 2.0),
                    .init(pattern: "poster", weight: 1.7),
                    .init(pattern: "photo", weight: 1.5),
                    .init(pattern: "render", weight: 1.6),
                ]
            case .summarization:
                return [
                    .init(pattern: "summarize", weight: 2.6),
                    .init(pattern: "summary", weight: 2.3),
                    .init(pattern: "tl;dr", weight: 2.0),
                    .init(pattern: "bullet points", weight: 1.8),
                    .init(pattern: "recap", weight: 1.7),
                ]
            case .research:
                return [
                    .init(pattern: "research", weight: 2.2),
                    .init(pattern: "analyze", weight: 1.8),
                    .init(pattern: "compare", weight: 1.8),
                    .init(pattern: "sources", weight: 1.6),
                    .init(pattern: "competitive", weight: 1.5),
                    .init(pattern: "find evidence", weight: 1.7),
                ]
            case .brainstorming:
                return [
                    .init(pattern: "brainstorm", weight: 2.3),
                    .init(pattern: "ideas", weight: 1.7),
                    .init(pattern: "name ideas", weight: 2.1),
                    .init(pattern: "concepts", weight: 1.6),
                    .init(pattern: "options", weight: 1.4),
                    .init(pattern: "variations", weight: 1.3),
                ]
            }
        }

        var tokenWeights: [String: Double] {
            switch self {
            case .writing:
                return [
                    "write": 0.9,
                    "rewrite": 1.0,
                    "draft": 0.9,
                    "edit": 0.8,
                    "copy": 0.7,
                    "headline": 0.7,
                    "email": 0.7,
                ]
            case .coding:
                return [
                    "code": 0.9,
                    "debug": 1.0,
                    "refactor": 1.1,
                    "swift": 1.0,
                    "swiftui": 1.0,
                    "api": 0.8,
                    "function": 0.8,
                    "regex": 0.7,
                    "test": 0.6,
                ]
            case .imageGeneration:
                return [
                    "image": 0.9,
                    "logo": 1.0,
                    "poster": 0.8,
                    "illustration": 0.9,
                    "photo": 0.7,
                    "render": 0.8,
                    "style": 0.6,
                ]
            case .summarization:
                return [
                    "summarize": 1.1,
                    "summary": 1.0,
                    "recap": 0.8,
                    "brief": 0.7,
                    "shorten": 0.8,
                    "condense": 0.9,
                ]
            case .research:
                return [
                    "research": 1.0,
                    "analyze": 0.9,
                    "compare": 0.9,
                    "source": 0.7,
                    "market": 0.6,
                    "evidence": 0.8,
                    "competitor": 0.7,
                ]
            case .brainstorming:
                return [
                    "brainstorm": 1.1,
                    "idea": 0.9,
                    "option": 0.7,
                    "concept": 0.8,
                    "name": 0.8,
                    "generate": 0.5,
                    "creative": 0.6,
                ]
            }
        }
    }

    struct WeightedRule {
        let pattern: String
        let weight: Double
    }

    static let toolTags = ToolTag.allCases.map(\.rawValue)
    static let taskTags = TaskTag.allCases.map(\.rawValue)

    static func toolTag(named value: String?) -> ToolTag? {
        guard let value else {
            return nil
        }

        return ToolTag.allCases.first { $0.rawValue == value }
    }

    static func taskTag(named value: String?) -> TaskTag? {
        guard let value else {
            return nil
        }

        return TaskTag.allCases.first { $0.rawValue == value }
    }
}
