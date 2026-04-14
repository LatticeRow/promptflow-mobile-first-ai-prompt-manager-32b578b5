import SwiftUI

struct SyncStatusView: View {
    let isICloudPreferred: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(isICloudPreferred ? "iCloud sync is used when available." : "Saved on this iPhone.", systemImage: isICloudPreferred ? "icloud.fill" : "internaldrive.fill")
                .foregroundStyle(.white)
            Text("Prompts save here first.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
