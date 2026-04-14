import CoreData
import SwiftUI

struct PromptDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appContainer: AppContainer

    let promptID: UUID

    @State private var prompt: PromptRecord?
    @State private var showingRecategorizationSheet = false

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
        .sheet(isPresented: $showingRecategorizationSheet) {
            if let prompt {
                RecategorizationSheet(prompt: prompt) { toolTag, taskTag in
                    do {
                        try appContainer.repository.recategorizePrompt(id: prompt.idValue, toolTag: toolTag, taskTag: taskTag)
                        reloadPrompt()
                    } catch {
                        AppLogger.persistence.error("Unable to recategorize prompt: \(error.localizedDescription)")
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .navigationTitle("Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reloadPrompt)
    }

    private func metadataCard(for prompt: PromptRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tags")
                    .font(.headline)
                Spacer()
                Button("Edit") {
                    showingRecategorizationSheet = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("AccentColor"))
                .accessibilityIdentifier("detail.editTags")
            }

            HStack(spacing: 10) {
                DetailTagChip(title: prompt.suggestedToolTag ?? PromptTaxonomy.ToolTag.genericAI.rawValue)
                DetailTagChip(title: prompt.suggestedTaskTag ?? PromptTaxonomy.TaskTag.writing.rawValue)
            }

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

private struct DetailTagChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color("AccentColor").opacity(0.2), in: Capsule())
    }
}

private struct RecategorizationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let prompt: PromptRecord
    let onSave: (PromptTaxonomy.ToolTag, PromptTaxonomy.TaskTag) -> Void

    @State private var selectedToolTag: PromptTaxonomy.ToolTag
    @State private var selectedTaskTag: PromptTaxonomy.TaskTag

    init(
        prompt: PromptRecord,
        onSave: @escaping (PromptTaxonomy.ToolTag, PromptTaxonomy.TaskTag) -> Void
    ) {
        self.prompt = prompt
        self.onSave = onSave
        _selectedToolTag = State(initialValue: PromptTaxonomy.toolTag(named: prompt.suggestedToolTag) ?? .genericAI)
        _selectedTaskTag = State(initialValue: PromptTaxonomy.taskTag(named: prompt.suggestedTaskTag) ?? .writing)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(prompt.displayTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text("Pick the tags that fit.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Tool")
                            .font(.headline)
                            .foregroundStyle(.white)
                        FlowChipSection(
                            values: PromptTaxonomy.ToolTag.allCases,
                            selection: $selectedToolTag,
                            accessibilityPrefix: "recategorize.tool."
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Task")
                            .font(.headline)
                            .foregroundStyle(.white)
                        FlowChipSection(
                            values: PromptTaxonomy.TaskTag.allCases,
                            selection: $selectedTaskTag,
                            accessibilityPrefix: "recategorize.task."
                        )
                    }
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
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("recategorize.close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedToolTag, selectedTaskTag)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("recategorize.save")
                }
            }
        }
    }
}

private protocol SelectableTaxonomyValue: Hashable {
    var rawValue: String { get }
    var accessibilityIdentifier: String { get }
}

extension PromptTaxonomy.ToolTag: SelectableTaxonomyValue {}
extension PromptTaxonomy.TaskTag: SelectableTaxonomyValue {}

private struct FlowChipSection<Value: SelectableTaxonomyValue & CaseIterable>: View where Value.AllCases: RandomAccessCollection {
    let values: Value.AllCases
    @Binding var selection: Value
    let accessibilityPrefix: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(Array(values), id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    HStack {
                        Text(value.rawValue)
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 8)
                        if selection == value {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selection == value ? Color("AccentColor").opacity(0.34) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selection == value ? Color("AccentColor") : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(accessibilityPrefix + value.accessibilityIdentifier)
            }
        }
    }
}
