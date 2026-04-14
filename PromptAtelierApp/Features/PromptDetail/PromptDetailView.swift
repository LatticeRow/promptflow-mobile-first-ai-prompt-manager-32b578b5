import CoreData
import SwiftUI

struct PromptDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appContainer: AppContainer

    let promptID: UUID

    @State private var prompt: PromptRecord?

    var body: some View {
        Group {
            if let prompt {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(prompt.displayTitle)
                                .font(.title.weight(.bold))
                                .foregroundStyle(.white)
                            Text(prompt.displayBody)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .textSelection(.enabled)
                        }

                        metadataCard(for: prompt)

                        HStack(spacing: 12) {
                            Button {
                                appContainer.repository.togglePinned(id: prompt.idValue)
                                reloadPrompt()
                            } label: {
                                Label(prompt.isPinned ? "Pinned" : "Pin", systemImage: prompt.isPinned ? "pin.fill" : "pin")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("detail.pin")

                            Button {
                                appContainer.repository.toggleFavorite(id: prompt.idValue)
                                reloadPrompt()
                            } label: {
                                Label(prompt.isFavorite ? "Favorite" : "Favorite", systemImage: prompt.isFavorite ? "star.fill" : "star")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("detail.favorite")
                        }

                        CopyButton(prompt: prompt, repository: appContainer.repository)
                    }
                    .padding(20)
                }
                .background(
                    LinearGradient(
                        colors: [Color.black, Color(red: 0.09, green: 0.09, blue: 0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            } else {
                ContentUnavailableView("Prompt unavailable", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reloadPrompt)
    }

    private func metadataCard(for prompt: PromptRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Tool", value: prompt.suggestedToolTag ?? "Generic AI")
            LabeledContent("Task", value: prompt.suggestedTaskTag ?? "Writing")
            LabeledContent("Source", value: sourceLabel(for: prompt))
            LabeledContent("Copies", value: "\(prompt.copyCount)")
        }
        .font(.callout)
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func reloadPrompt() {
        prompt = appContainer.repository.prompt(id: promptID, in: viewContext)
    }

    private func sourceLabel(for prompt: PromptRecord) -> String {
        switch prompt.sourceType?.lowercased() {
        case "url":
            return "Link"
        default:
            return "Text"
        }
    }
}
