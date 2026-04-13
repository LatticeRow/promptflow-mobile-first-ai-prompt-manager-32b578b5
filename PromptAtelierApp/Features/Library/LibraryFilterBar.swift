import SwiftUI

struct LibraryFilterBar: View {
    @Binding var showPinnedOnly: Bool
    @Binding var showFavoritesOnly: Bool

    var body: some View {
        HStack(spacing: 12) {
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
        .font(.footnote.weight(.medium))
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
}
