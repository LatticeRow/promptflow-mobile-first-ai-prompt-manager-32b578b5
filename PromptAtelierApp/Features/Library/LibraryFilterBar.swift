import SwiftUI

struct LibraryFilterBar: View {
    let folders: [FolderRecord]
    let tags: [TagRecord]
    @Binding var selectedFolderID: UUID?
    @Binding var selectedTagID: UUID?
    @Binding var showPinnedOnly: Bool
    @Binding var showFavoritesOnly: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                menuChip(
                    title: selectedFolderTitle,
                    systemImage: "folder.fill",
                    accessibilityIdentifier: "library.filter.folder"
                ) {
                    Button("All folders") {
                        selectedFolderID = nil
                    }

                    if !folders.isEmpty {
                        Divider()
                    }

                    ForEach(folders, id: \.idValue) { folder in
                        Button(folder.displayName) {
                            selectedFolderID = folder.idValue
                        }
                    }
                }

                menuChip(
                    title: selectedTagTitle,
                    systemImage: "tag.fill",
                    accessibilityIdentifier: "library.filter.tag"
                ) {
                    Button("All tags") {
                        selectedTagID = nil
                    }

                    if !tags.isEmpty {
                        Divider()
                    }

                    ForEach(tags, id: \.idValue) { tag in
                        Button(tag.displayName) {
                            selectedTagID = tag.idValue
                        }
                    }
                }

                filterButton(
                    title: "Pinned",
                    systemImage: "pin.fill",
                    isActive: showPinnedOnly,
                    accessibilityIdentifier: "library.filter.pinned"
                ) {
                    showPinnedOnly.toggle()
                }

                filterButton(
                    title: "Favorites",
                    systemImage: "star.fill",
                    isActive: showFavoritesOnly,
                    accessibilityIdentifier: "library.filter.favorites"
                ) {
                    showFavoritesOnly.toggle()
                }
            }
        }
        .font(.footnote.weight(.medium))
    }

    private var selectedFolderTitle: String {
        folders.first(where: { $0.idValue == selectedFolderID })?.displayName ?? "All folders"
    }

    private var selectedTagTitle: String {
        tags.first(where: { $0.idValue == selectedTagID })?.displayName ?? "All tags"
    }

    private func filterButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 0)
                .background(
                    Capsule()
                        .fill(isActive ? Color("AccentColor").opacity(0.2) : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Color("AccentColor") : .white.opacity(0.86))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func menuChip<Content: View>(
        title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            Label(title, systemImage: systemImage)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
        }
        .foregroundStyle(.white.opacity(0.86))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
