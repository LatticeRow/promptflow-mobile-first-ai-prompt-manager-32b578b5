import SwiftUI

struct PromptRowView: View {
    let prompt: PromptRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(prompt.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer()

                if prompt.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(Color("AccentColor"))
                }
            }

            Text(prompt.previewBody)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(3)

            HStack(spacing: 8) {
                if let toolTag = prompt.suggestedToolTag {
                    TagBadge(title: toolTag)
                }

                if let taskTag = prompt.suggestedTaskTag {
                    TagBadge(title: taskTag)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

private struct TagBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color("AccentColor").opacity(0.18), in: Capsule())
    }
}
