import SwiftUI

struct LibraryFilterBar: View {
    let folders: [FolderRecord]
    let tags: [TagRecord]
    @Binding var selectedFolderID: UUID?
    @Binding var selectedTagID: UUID?
    @Binding var selectedRecentStatus: LibraryRecentStatus
    @Binding var showPinnedOnly: Bool
    @Binding var showFavoritesOnly: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                menuChip(
                    title: selectedFolderTitle,
                    systemImage: "folder.fill",
                    isActive: selectedFolderID != nil,
                    accessibilityIdentifier: "library.filter.folder"
                ) {
                    selectionButton("All folders", isSelected: selectedFolderID == nil) {
                        selectedFolderID = nil
                    }

                    if !folders.isEmpty {
                        Divider()
                    }

                    ForEach(folders, id: \.idValue) { folder in
                        selectionButton(folder.displayName, isSelected: selectedFolderID == folder.idValue) {
                            selectedFolderID = folder.idValue
                        }
                    }
                }

                menuChip(
                    title: selectedTagTitle,
                    systemImage: "tag.fill",
                    isActive: selectedTagID != nil,
                    accessibilityIdentifier: "library.filter.tag"
                ) {
                    selectionButton("All tags", isSelected: selectedTagID == nil) {
                        selectedTagID = nil
                    }

                    if !tags.isEmpty {
                        Divider()
                    }

                    ForEach(tags, id: \.idValue) { tag in
                        selectionButton(tag.displayName, isSelected: selectedTagID == tag.idValue) {
                            selectedTagID = tag.idValue
                        }
                    }
                }

                menuChip(
                    title: selectedRecentStatus.rawValue,
                    systemImage: "clock.fill",
                    isActive: selectedRecentStatus != .allTime,
                    accessibilityIdentifier: "library.filter.recent"
                ) {
                    ForEach(LibraryRecentStatus.allCases) { status in
                        selectionButton(status.rawValue, isSelected: selectedRecentStatus == status) {
                            selectedRecentStatus = status
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

    private func selectionButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
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
        isActive: Bool,
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
                        .fill(isActive ? Color("AccentColor").opacity(0.2) : Color.white.opacity(0.06))
                )
        }
        .foregroundStyle(isActive ? Color("AccentColor") : .white.opacity(0.86))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
