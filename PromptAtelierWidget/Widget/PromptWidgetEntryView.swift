import SwiftUI
import WidgetKit

struct PromptWidgetEntryView: View {
    var entry: PromptWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prompt Atelier")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("AccentColor"))

            ForEach(entry.prompts.prefix(2)) { prompt in
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
                            .lineLimit(2)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color(red: 0.12, green: 0.11, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
