import WidgetKit

struct PromptWidgetEntry: TimelineEntry {
    let date: Date
    let prompts: [PromptWidgetItem]
}

struct PromptWidgetItem: Identifiable {
    let id: UUID
    let title: String
    let preview: String
}

struct PromptWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptWidgetEntry {
        PromptWidgetEntry(
            date: .now,
            prompts: [
                PromptWidgetItem(id: UUID(), title: "Welcome prompt", preview: "Your latest prompts appear here.")
            ]
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
        let prompts = repository.latestPrompts(limit: 3).map {
            PromptWidgetItem(id: $0.idValue, title: $0.displayTitle, preview: $0.previewBody)
        }

        if prompts.isEmpty {
            return PromptWidgetEntry(
                date: .now,
                prompts: [
                    PromptWidgetItem(id: UUID(), title: "Save from Share Sheet", preview: "Recent prompts appear here.")
                ]
            )
        }

        return PromptWidgetEntry(date: .now, prompts: prompts)
    }
}
