import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appContainer: AppContainer

    var body: some View {
        List {
            Section("Sync") {
                SyncStatusView(snapshot: appContainer.syncMonitor.snapshot)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Share") {
                Label("Share text or links to save them here.", systemImage: "square.and.arrow.up.fill")
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.07, green: 0.08, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Settings")
    }
}
