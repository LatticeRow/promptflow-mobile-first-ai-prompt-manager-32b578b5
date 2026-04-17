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
            prompts: [PromptWidgetItem(id: UUID(), title: "Pinned and recent", preview: "Keep your best prompts one tap away.", badge: "Pinned")]
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
        let prompts = repository.widgetSourcePrompts(limit: 3).map {
            PromptWidgetItem(
                id: $0.idValue,
                title: $0.displayTitle,
                preview: $0.previewBody,
                badge: $0.folder?.displayName ?? ($0.isPinned ? "Pinned" : $0.suggestedTaskTag)
            )
        }

        if prompts.isEmpty {
            return PromptWidgetEntry(
                date: .now,
                prompts: []
            )
        }

        return PromptWidgetEntry(date: .now, prompts: prompts)
    }
}
