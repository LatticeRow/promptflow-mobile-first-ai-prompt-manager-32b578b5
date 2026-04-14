import SwiftUI

struct SyncStatusView: View {
    let snapshot: SyncStatusSnapshot

    private var accentColor: Color {
        switch snapshot.tone {
        case .positive:
            return Color(red: 0.53, green: 0.82, blue: 0.75)
        case .warning:
            return Color(red: 0.96, green: 0.76, blue: 0.47)
        case .critical:
            return Color(red: 0.95, green: 0.48, blue: 0.48)
        case .neutral:
            return Color(red: 0.78, green: 0.82, blue: 0.9)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: snapshot.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("settings.sync.title")

                    Text(snapshot.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.sync.message")
                }

                Spacer(minLength: 8)

                if snapshot.showsProgress {
                    ProgressView()
                        .tint(accentColor)
                }
            }

            if let lastSyncDate = snapshot.lastSyncDate {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(accentColor)
                    Text("Last sync")
                        .foregroundStyle(.white.opacity(0.72))
                    Text(lastSyncDate, style: .relative)
                        .foregroundStyle(.white)
                }
                .font(.footnote.weight(.medium))
                .accessibilityIdentifier("settings.sync.timestamp")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), accentColor.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accentColor.opacity(0.32), lineWidth: 1)
        )
        .accessibilityIdentifier("settings.sync.card")
    }
}
