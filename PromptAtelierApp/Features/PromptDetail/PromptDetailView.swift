import CoreData
import SwiftUI

struct PromptDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appContainer: AppContainer

    let promptID: UUID

    @State private var prompt: PromptRecord?
    @State private var showingOrganizerSheet = false

    var body: some View {
        Group {
            if let prompt {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(prompt.displayTitle)
                                .font(.system(size: 30, weight: .semibold, design: .serif))
                                .foregroundStyle(.white)

                            if let lastCopiedAt = prompt.lastCopiedAt {
                                Label(lastCopiedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock.fill")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(Color("AccentColor").opacity(0.88))
                            }
                        }

                        bodyCard(for: prompt)
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
                                Label("Favorite", systemImage: prompt.isFavorite ? "star.fill" : "star")
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
                        colors: [Color(red: 0.02, green: 0.03, blue: 0.05), Color(red: 0.09, green: 0.08, blue: 0.09)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            } else {
                ContentUnavailableView("Prompt unavailable", systemImage: "exclamationmark.triangle")
            }
        }
        .sheet(isPresented: $showingOrganizerSheet) {
            if let prompt {
                PromptOrganizerSheet(prompt: prompt, onSave: saveChanges)
                    .environmentObject(appContainer)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationTitle("Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reloadPrompt)
    }

    private func bodyCard(for prompt: PromptRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prompt")
                .font(.headline)
                .foregroundStyle(.white)

            Text(prompt.displayBody)
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))
                .textSelection(.enabled)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func metadataCard(for prompt: PromptRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prompt info")
                    .font(.headline)

                Spacer()

                Button("Edit") {
                    showingOrganizerSheet = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("AccentColor"))
                .accessibilityIdentifier("detail.manage")
            }

            HStack(spacing: 10) {
                DetailTagChip(title: prompt.suggestedToolTag ?? PromptTaxonomy.ToolTag.genericAI.rawValue)
                DetailTagChip(title: prompt.suggestedTaskTag ?? PromptTaxonomy.TaskTag.writing.rawValue)
            }

            LabeledContent("Folder", value: prompt.folder?.displayName ?? "None")
            LabeledContent("Source", value: sourceLabel(for: prompt))
            LabeledContent("Copied", value: copySummary(for: prompt))

            VStack(alignment: .leading, spacing: 10) {
                Text("Tags")
                    .font(.subheadline.weight(.semibold))

                if prompt.sortedTags.isEmpty {
                    Text("None")
                        .foregroundStyle(.white.opacity(0.65))
                } else {
                    FlexibleTagLayout(tags: prompt.sortedTags.map(\.displayName))
                }
            }
        }
        .font(.callout)
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func reloadPrompt() {
        prompt = appContainer.repository.prompt(id: promptID, in: viewContext)
    }

    private func saveChanges(
        toolTag: PromptTaxonomy.ToolTag,
        taskTag: PromptTaxonomy.TaskTag,
        folderID: UUID?,
        customTagIDs: [UUID]
    ) {
        do {
            try appContainer.repository.recategorizePrompt(id: promptID, toolTag: toolTag, taskTag: taskTag)
            try appContainer.repository.assignPrompt(id: promptID, toFolderID: folderID)
            try appContainer.repository.setTags(forPromptID: promptID, tagIDs: customTagIDs)
            reloadPrompt()
        } catch {
            AppLogger.persistence.error("Unable to save prompt details: \(error.localizedDescription)")
        }
    }

    private func sourceLabel(for prompt: PromptRecord) -> String {
        switch prompt.sourceType?.lowercased() {
        case "url":
            return "Link"
        default:
            return "Text"
        }
    }

    private func copySummary(for prompt: PromptRecord) -> String {
        if let lastCopiedAt = prompt.lastCopiedAt {
            return "\(prompt.copyCount) • \(lastCopiedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return "\(prompt.copyCount)"
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

private struct FlexibleTagLayout: View {
    let tags: [String]

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tagRows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { tag in
                            DetailTagChip(title: tag)
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        DetailTagChip(title: tag)
                    }
                }
            }
        }
    }

    private var tagRows: [[String]] {
        stride(from: 0, to: tags.count, by: 2).map { index in
            Array(tags[index..<min(index + 2, tags.count)])
        }
    }
}

private struct PromptOrganizerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer

    let prompt: PromptRecord
    let onSave: (PromptTaxonomy.ToolTag, PromptTaxonomy.TaskTag, UUID?, [UUID]) -> Void

    @State private var selectedToolTag: PromptTaxonomy.ToolTag
    @State private var selectedTaskTag: PromptTaxonomy.TaskTag
    @State private var selectedFolderID: UUID?
    @State private var selectedCustomTagIDs: Set<UUID>
    @State private var availableFolders: [FolderRecord]
    @State private var availableTags: [TagRecord]
    @State private var newFolderName = ""
    @State private var newTagName = ""

    init(
        prompt: PromptRecord,
        onSave: @escaping (PromptTaxonomy.ToolTag, PromptTaxonomy.TaskTag, UUID?, [UUID]) -> Void
    ) {
        self.prompt = prompt
        self.onSave = onSave
        _selectedToolTag = State(initialValue: PromptTaxonomy.toolTag(named: prompt.suggestedToolTag) ?? .genericAI)
        _selectedTaskTag = State(initialValue: PromptTaxonomy.taskTag(named: prompt.suggestedTaskTag) ?? .writing)
        _selectedFolderID = State(initialValue: prompt.folder?.idValue)
        _selectedCustomTagIDs = State(initialValue: Set(prompt.sortedTags.map(\.idValue)))
        _availableFolders = State(initialValue: [])
        _availableTags = State(initialValue: [])
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
                        Text("Set the folder and tags.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tool")
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

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Folder")
                            .font(.headline)
                            .foregroundStyle(.white)

                        SelectionRow(
                            title: "None",
                            isSelected: selectedFolderID == nil,
                            accessibilityIdentifier: "organize.folder.none"
                        ) {
                            selectedFolderID = nil
                        }

                        ForEach(availableFolders, id: \.idValue) { folder in
                            SelectionRow(
                                title: folder.displayName,
                                isSelected: selectedFolderID == folder.idValue,
                                accessibilityIdentifier: "organize.folder.\(folder.idValue.uuidString)"
                            ) {
                                selectedFolderID = folder.idValue
                            }
                        }

                        HStack(spacing: 12) {
                            TextField("New folder", text: $newFolderName)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .accessibilityIdentifier("organize.newFolder")

                            Button("Add") {
                                createFolder()
                            }
                            .buttonStyle(.bordered)
                            .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("organize.addFolder")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if availableTags.isEmpty {
                            Text("No tags yet")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.65))
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                                ForEach(availableTags, id: \.idValue) { tag in
                                    Button {
                                        toggleTag(id: tag.idValue)
                                    } label: {
                                        HStack {
                                            Text(tag.displayName)
                                                .font(.subheadline.weight(.semibold))
                                            Spacer(minLength: 8)
                                            if selectedCustomTagIDs.contains(tag.idValue) {
                                                Image(systemName: "checkmark.circle.fill")
                                            }
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(selectedCustomTagIDs.contains(tag.idValue) ? Color("AccentColor").opacity(0.34) : Color.white.opacity(0.06))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(selectedCustomTagIDs.contains(tag.idValue) ? Color("AccentColor") : Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("organize.tag.\(tag.idValue.uuidString)")
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            TextField("New custom tag", text: $newTagName)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .accessibilityIdentifier("organize.newTag")

                            Button("Add") {
                                createTag()
                            }
                            .buttonStyle(.bordered)
                            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("organize.addTag")
                        }
                    }
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.02, green: 0.03, blue: 0.05), Color(red: 0.09, green: 0.08, blue: 0.09)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: reloadOptions)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("recategorize.close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedToolTag, selectedTaskTag, selectedFolderID, Array(selectedCustomTagIDs))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("recategorize.save")
                }
            }
        }
    }

    private func reloadOptions() {
        availableFolders = appContainer.repository.folders()
        availableTags = appContainer.repository.tags(kind: "custom")
    }

    private func createFolder() {
        let draft = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else {
            return
        }

        do {
            let id = try appContainer.repository.createFolder(name: draft, sortOrder: Int32(availableFolders.count))
            selectedFolderID = id
            newFolderName = ""
            reloadOptions()
        } catch {
            AppLogger.persistence.error("Unable to create folder: \(error.localizedDescription)")
        }
    }

    private func createTag() {
        let draft = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else {
            return
        }

        do {
            let id = try appContainer.repository.createTag(name: draft, kind: "custom")
            selectedCustomTagIDs.insert(id)
            newTagName = ""
            reloadOptions()
        } catch {
            AppLogger.persistence.error("Unable to create tag: \(error.localizedDescription)")
        }
    }

    private func toggleTag(id: UUID) {
        if selectedCustomTagIDs.contains(id) {
            selectedCustomTagIDs.remove(id)
        } else {
            selectedCustomTagIDs.insert(id)
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

private struct SelectionRow: View {
    let title: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color("AccentColor").opacity(0.34) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color("AccentColor") : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
