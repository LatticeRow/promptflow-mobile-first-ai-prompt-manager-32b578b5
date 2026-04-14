import WidgetKit

struct PromptWidgetEntry: TimelineEntry {
    let date: Date
    let prompts: [PromptWidgetItem]
}

struct PromptWidgetItem: Identifiable {
    let id: UUID
    let title: String
    let preview: String
    let badge: String?
}

struct PromptWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptWidgetEntry {
        PromptWidgetEntry(
            date: .now,
            prompts: [PromptWidgetItem(id: UUID(), title: "Recent prompts", preview: "Your last copy shows up here.", badge: "Recent")]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PromptWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PromptWidgetEntry>) -> Void) {
        let entry = makeEntry()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }

    private func makeEntry() -> PromptWidgetEntry {
        let repository = PromptRepository(container: PersistenceController.sharedWidget.container)
        let recentCopies = repository.recentlyCopiedPrompts(limit: 3)
        let sourcePrompts = recentCopies.isEmpty ? repository.latestPrompts(limit: 3) : recentCopies
        let prompts = sourcePrompts.map {
            PromptWidgetItem(
                id: $0.idValue,
                title: $0.displayTitle,
                preview: $0.previewBody,
                badge: $0.folder?.displayName ?? $0.suggestedTaskTag
            )
        }

        if prompts.isEmpty {
            return PromptWidgetEntry(
                date: .now,
                prompts: [PromptWidgetItem(id: UUID(), title: "Share to save", preview: "Recent prompts appear here.", badge: nil)]
            )
        }

        return PromptWidgetEntry(date: .now, prompts: prompts)
    }
}
