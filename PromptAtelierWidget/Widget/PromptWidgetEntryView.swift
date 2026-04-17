import SwiftUI
import WidgetKit

struct PromptWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PromptWidgetProvider.Entry

    var body: some View {
        content
            .padding()
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color(red: 0.12, green: 0.11, blue: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .widgetURL(entry.prompts.isEmpty ? WidgetDeepLinks.libraryURL() : nil)
    }

    @ViewBuilder
    private var content: some View {
        if entry.prompts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Prompt Atelier")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("AccentColor"))

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 6) {
                    Text("No prompts yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Share text or a link to save your first prompt.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Prompt Atelier")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("AccentColor"))

                ForEach(entry.prompts.prefix(displayLimit)) { prompt in
                    Link(destination: WidgetDeepLinks.promptURL(id: prompt.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let badge = prompt.badge {
                                Text(badge.uppercased())
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color("AccentColor"))
                            }
                            Text(prompt.title)
                                .font(.headline)
                                .lineLimit(1)
                                .foregroundStyle(.white)
                            Text(prompt.preview)
                                .font(.caption)
                                .lineLimit(family == .systemSmall ? 3 : 2)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var displayLimit: Int {
        switch family {
        case .systemSmall:
            return 1
        default:
            return 2
        }
    }
}
