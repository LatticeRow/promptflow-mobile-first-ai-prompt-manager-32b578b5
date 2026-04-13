import CoreData
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PromptRecord.updatedAt, ascending: false)],
        animation: .default
    ) private var prompts: FetchedResults<PromptRecord>
    @State private var searchText = ""
    @State private var showPinnedOnly = false
    @State private var showFavoritesOnly = false

    private var filteredPrompts: [PromptRecord] {
        prompts.filter { prompt in
            let matchesSearch = searchText.isEmpty
                || prompt.displayTitle.localizedCaseInsensitiveContains(searchText)
                || prompt.displayBody.localizedCaseInsensitiveContains(searchText)
            let matchesPinned = !showPinnedOnly || prompt.isPinned
            let matchesFavorites = !showFavoritesOnly || prompt.isFavorite

            return matchesSearch && matchesPinned && matchesFavorites
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Prompt Atelier")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Capture once. Reuse fast.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }

                LibraryFilterBar(showPinnedOnly: $showPinnedOnly, showFavoritesOnly: $showFavoritesOnly)

                if filteredPrompts.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredPrompts, id: \.objectID) { prompt in
                            NavigationLink(value: AppRouter.Route.prompt(prompt.idValue)) {
                                PromptRowView(prompt: prompt)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("library.promptRow")
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.07, green: 0.08, blue: 0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search prompts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appContainer.repository.seedSamplePromptsIfNeeded(forceInsert: true)
                } label: {
                    Label("Add Sample", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("library.addSample")
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nothing saved yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Share text or a link into Prompt Atelier, or add one sample to test the flow.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))
            Button("Add Sample Prompt") {
                appContainer.repository.seedSamplePromptsIfNeeded(forceInsert: true)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("library.empty.addSample")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}
