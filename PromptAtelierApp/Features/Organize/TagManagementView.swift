import SwiftUI

struct TagManagementView: View {
    private var suggestedTags: [String] {
        [
            PromptTaxonomy.ToolTag.chatGPT.rawValue,
            PromptTaxonomy.ToolTag.claude.rawValue,
            PromptTaxonomy.ToolTag.codingAI.rawValue,
            PromptTaxonomy.TaskTag.writing.rawValue,
            PromptTaxonomy.TaskTag.research.rawValue,
        ]
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestedTags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
            }
            .padding(.vertical, 6)
        }
    }
}
