import Foundation

struct SourceInferenceService {
    struct InferredSource {
        let tool: PromptTaxonomy.ToolTag
        let sourceLabel: String?
        let confidence: Double
    }

    func inferTool(from capture: CaptureNormalizer.NormalizedCapture, sourceAppBundleID: String?) -> PromptTaxonomy.ToolTag {
        inferSource(from: capture, sourceAppBundleID: sourceAppBundleID).tool
    }

    func inferSource(from capture: CaptureNormalizer.NormalizedCapture, sourceAppBundleID: String?) -> InferredSource {
        let host = capture.sourceHost ?? normalizedHost(from: capture.sourceURLString)
        if let host, let inference = toolForKnownHost(host) {
            return InferredSource(tool: inference.tool, sourceLabel: host, confidence: inference.confidence)
        }

        if let sourceAppBundleID, let inference = toolForKnownBundleID(sourceAppBundleID) {
            return InferredSource(tool: inference.tool, sourceLabel: readableSourceLabel(bundleID: sourceAppBundleID), confidence: inference.confidence)
        }

        let haystack = [capture.title, capture.body, capture.sourceURLString ?? "", sourceAppBundleID ?? ""]
            .joined(separator: " ")
            .lowercased()

        for tool in PromptTaxonomy.ToolTag.allCases where tool != .genericAI {
            if tool.keywordHints.contains(where: { haystack.contains($0) }) {
                return InferredSource(tool: tool, sourceLabel: host ?? readableSourceLabel(bundleID: sourceAppBundleID), confidence: 0.78)
            }
        }

        return InferredSource(tool: .genericAI, sourceLabel: host ?? readableSourceLabel(bundleID: sourceAppBundleID), confidence: 0.42)
    }

    private func toolForKnownHost(_ host: String) -> (tool: PromptTaxonomy.ToolTag, confidence: Double)? {
        for tool in PromptTaxonomy.ToolTag.allCases where tool != .genericAI {
            if tool.sourceHosts.contains(where: { host.contains($0) }) {
                return (tool, 0.97)
            }
        }

        return nil
    }

    private func toolForKnownBundleID(_ bundleID: String) -> (tool: PromptTaxonomy.ToolTag, confidence: Double)? {
        let normalizedBundleID = bundleID.lowercased()

        for tool in PromptTaxonomy.ToolTag.allCases where tool != .genericAI {
            if tool.sourceBundleHints.contains(where: { normalizedBundleID.contains($0) }) {
                return (tool, 0.9)
            }
        }

        return nil
    }

    private func readableSourceLabel(bundleID: String?) -> String? {
        guard let bundleID else {
            return nil
        }

        let components = bundleID.split(separator: ".")
        guard let lastComponent = components.last else {
            return bundleID
        }

        return lastComponent
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
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
