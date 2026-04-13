import SwiftUI
import WidgetKit

@main
struct PromptAtelierWidgetBundle: WidgetBundle {
    var body: some Widget {
        PromptAtelierWidget()
    }
}

struct PromptAtelierWidget: Widget {
    let kind = "PromptAtelierWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PromptWidgetProvider()) { entry in
            PromptWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Recent Prompts")
        .description("Open your latest saved prompts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
