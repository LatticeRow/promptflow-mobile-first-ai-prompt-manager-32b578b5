import SwiftUI

struct FolderListView: View {
    var body: some View {
        List {
            Section("Folders") {
                Label("Inbox", systemImage: "tray.full.fill")
                Label("Pinned", systemImage: "pin.fill")
                Label("Favorites", systemImage: "star.fill")
            }

            Section("Tags") {
                TagManagementView()
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.08, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Organize")
    }
}
