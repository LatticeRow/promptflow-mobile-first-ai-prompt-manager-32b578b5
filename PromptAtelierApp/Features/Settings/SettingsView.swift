import SwiftUI

struct SettingsView: View {
    @AppStorage("preferICloudSync") private var preferICloudSync = true

    var body: some View {
        List {
            Section("Sync") {
                Toggle("Prefer iCloud Sync", isOn: $preferICloudSync)
                    .accessibilityIdentifier("settings.preferICloud")
                SyncStatusView(isICloudPreferred: preferICloudSync)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Share") {
                Label("Use the share sheet to save text or links.", systemImage: "square.and.arrow.up.fill")
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
