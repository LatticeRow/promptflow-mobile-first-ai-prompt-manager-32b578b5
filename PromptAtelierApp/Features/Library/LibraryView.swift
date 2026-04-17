import CoreData
import SwiftUI

struct LibraryView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PromptRecord.updatedAt, ascending: false)],
        animation: .default
    ) private var prompts: FetchedResults<PromptRecord>
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \FolderRecord.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \FolderRecord.name, ascending: true),
        ],
        animation: .default
    ) private var folders: FetchedResults<FolderRecord>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TagRecord.name, ascending: true)],
        predicate: NSPredicate(format: "kind == %@", "custom"),
        animation: .default
    ) private var customTags: FetchedResults<TagRecord>
    @State private var searchText = ""
    @State private var selectedFolderID: UUID?
    @State private var selectedTagID: UUID?
    @State private var selectedRecentStatus: LibraryRecentStatus = .allTime
    @State private var showPinnedOnly = false
    @State private var showFavoritesOnly = false

    private var filteredPrompts: [PromptRecord] {
        prompts.filter { prompt in
            let matchesSearch = searchText.isEmpty
                || prompt.displayTitle.localizedCaseInsensitiveContains(searchText)
                || prompt.displayBody.localizedCaseInsensitiveContains(searchText)
                || prompt.sortedTags.contains(where: { $0.displayName.localizedCaseInsensitiveContains(searchText) })
            let matchesPinned = !showPinnedOnly || prompt.isPinned
            let matchesFavorites = !showFavoritesOnly || prompt.isFavorite
            let matchesFolder = selectedFolderID == nil || prompt.folder?.idValue == selectedFolderID
            let matchesTag = selectedTagID == nil || prompt.sortedTags.contains(where: { $0.idValue == selectedTagID })
            let matchesRecentStatus = selectedRecentStatus.matches(prompt)

            return matchesSearch && matchesPinned && matchesFavorites && matchesFolder && matchesTag && matchesRecentStatus
        }
    }

    private var recentPrompts: [PromptRecord] {
        Array(filteredPrompts.sorted(by: recentPromptSort).prefix(4))
    }

    private var libraryPrompts: [PromptRecord] {
        filteredPrompts.sorted(by: recentPromptSort)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Prompt Atelier")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Text("Keep every prompt ready to copy.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }

                LibraryFilterBar(
                    folders: Array(folders),
                    tags: Array(customTags),
                    selectedFolderID: $selectedFolderID,
                    selectedTagID: $selectedTagID,
                    selectedRecentStatus: $selectedRecentStatus,
                    showPinnedOnly: $showPinnedOnly,
                    showFavoritesOnly: $showFavoritesOnly
                )

                if libraryPrompts.isEmpty {
                    emptyState
                } else {
                    if !recentPrompts.isEmpty {
                        recentSurface
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Library")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))

                        LazyVStack(spacing: 14) {
                            ForEach(libraryPrompts, id: \.objectID) { prompt in
                                NavigationLink(value: AppRouter.Route.prompt(prompt.idValue)) {
                                    PromptRowView(prompt: prompt)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("library.promptRow")
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.03, blue: 0.05), Color(red: 0.09, green: 0.08, blue: 0.09)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search prompts")
    }

    private var recentSurface: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Spacer()

                if let latestPrompt = recentPrompts.first,
                   let lastMoment = latestPrompt.lastCopiedAt ?? latestPrompt.updatedAt {
                    Text(lastMoment, style: .relative)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("AccentColor").opacity(0.86))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recentPrompts, id: \.objectID) { prompt in
                        NavigationLink(value: AppRouter.Route.prompt(prompt.idValue)) {
                            RecentPromptCard(prompt: prompt)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("library.recentRow")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("No prompts yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(emptyStateMessage)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var emptyStateMessage: String {
        if selectedFolderID != nil || selectedTagID != nil || selectedRecentStatus != .allTime || showPinnedOnly || showFavoritesOnly || !searchText.isEmpty {
            return "Try a different filter."
        }

        return "Share text or a link into Prompt Atelier."
    }

    private func recentPromptSort(lhs: PromptRecord, rhs: PromptRecord) -> Bool {
        let lhsDate = lhs.lastCopiedAt ?? lhs.updatedAt ?? lhs.createdAt ?? .distantPast
        let rhsDate = rhs.lastCopiedAt ?? rhs.updatedAt ?? rhs.createdAt ?? .distantPast

        if lhsDate == rhsDate {
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }

        return lhsDate > rhsDate
    }
}

private struct RecentPromptCard: View {
    let prompt: PromptRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let folderName = prompt.folder?.displayName {
                    Label(folderName, systemImage: "folder.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("AccentColor"))
                } else if let taskTag = prompt.suggestedTaskTag {
                    Text(taskTag.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("AccentColor"))
                }

                Spacer()

                if prompt.copyCount > 0 {
                    Label("\(prompt.copyCount)", systemImage: "doc.on.doc")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text(prompt.displayTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(prompt.previewBody)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(4)

            if let timestamp = prompt.lastCopiedAt ?? prompt.updatedAt {
                Text(timestamp, style: .relative)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(18)
        .frame(width: 270, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color(red: 0.15, green: 0.12, blue: 0.08).opacity(0.74),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
