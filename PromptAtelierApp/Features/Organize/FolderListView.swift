import CoreData
import SwiftUI

struct FolderListView: View {
    private enum RenameTarget: Identifiable {
        case folder(FolderRecord)
        case tag(TagRecord)

        var id: String {
            switch self {
            case .folder(let folder):
                return "folder-\(folder.idValue.uuidString)"
            case .tag(let tag):
                return "tag-\(tag.idValue.uuidString)"
            }
        }

        var title: String {
            switch self {
            case .folder:
                return "Rename folder"
            case .tag:
                return "Rename tag"
            }
        }

        var currentName: String {
            switch self {
            case .folder(let folder):
                return folder.displayName
            case .tag(let tag):
                return tag.displayName
            }
        }
    }

    @EnvironmentObject private var appContainer: AppContainer
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \FolderRecord.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \FolderRecord.name, ascending: true),
        ],
        animation: .default
    ) private var folders: FetchedResults<FolderRecord>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TagRecord.name, ascending: true)],
        animation: .default
    ) private var customTags: FetchedResults<TagRecord>
    @State private var newFolderName = ""
    @State private var newTagName = ""
    @State private var renameTarget: RenameTarget?
    @State private var renameDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                adminCard(
                    title: "Folders",
                    subtitle: "Place prompts where you expect them.",
                    textFieldTitle: "New folder",
                    text: $newFolderName,
                    addIdentifier: "organize.screen.addFolder",
                    fieldIdentifier: "organize.screen.newFolder",
                    action: createFolder
                ) {
                    if folders.isEmpty {
                        emptyLine("No folders yet")
                    } else {
                        ForEach(folders, id: \.idValue) { folder in
                            itemRow(
                                title: folder.displayName,
                                detail: "\(folder.sortedPrompts.count) prompts",
                                accessibilityIdentifier: "organize.screen.folder.\(folder.idValue.uuidString)"
                            ) {
                                renameDraft = folder.displayName
                                renameTarget = .folder(folder)
                            }
                        }
                    }
                }

                adminCard(
                    title: "Custom tags",
                    subtitle: "Keep your own shorthand close.",
                    textFieldTitle: "New custom tag",
                    text: $newTagName,
                    addIdentifier: "organize.screen.addTag",
                    fieldIdentifier: "organize.screen.newTag",
                    action: createTag
                ) {
                    if customTags.isEmpty {
                        emptyLine("No custom tags yet")
                    } else {
                        ForEach(customTags, id: \.idValue) { tag in
                            itemRow(
                                title: tag.displayName,
                                detail: "\(tag.prompts?.count ?? 0) prompts",
                                accessibilityIdentifier: "organize.screen.tag.\(tag.idValue.uuidString)"
                            ) {
                                renameDraft = tag.displayName
                                renameTarget = .tag(tag)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Smart tags")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    TagManagementView()
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.03, blue: 0.05), Color(red: 0.09, green: 0.08, blue: 0.09)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Organize")
        .alert(renameTarget?.title ?? "", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Name", text: $renameDraft)
                .accessibilityIdentifier("organize.screen.renameField")
            Button("Save") {
                saveRename()
            }
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
        } message: {
            Text(renameTarget?.currentName ?? "")
        }
    }

    private func adminCard<Content: View>(
        title: String,
        subtitle: String,
        textFieldTitle: String,
        text: Binding<String>,
        addIdentifier: String,
        fieldIdentifier: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            HStack(spacing: 12) {
                TextField(textFieldTitle, text: text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier(fieldIdentifier)

                Button("Add", action: action)
                    .buttonStyle(.bordered)
                    .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier(addIdentifier)
            }

            content()
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

    private func itemRow(
        title: String,
        detail: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Button("Rename", action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    private func emptyLine(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.68))
    }

    private func createFolder() {
        let draft = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else {
            return
        }

        do {
            _ = try appContainer.repository.createFolder(name: draft, sortOrder: Int32(folders.count))
            newFolderName = ""
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
            _ = try appContainer.repository.createTag(name: draft, kind: "custom")
            newTagName = ""
        } catch {
            AppLogger.persistence.error("Unable to create tag: \(error.localizedDescription)")
        }
    }

    private func saveRename() {
        guard let renameTarget else {
            return
        }

        do {
            switch renameTarget {
            case .folder(let folder):
                try appContainer.repository.renameFolder(id: folder.idValue, name: renameDraft, sortOrder: folder.sortOrder)
            case .tag(let tag):
                try appContainer.repository.renameTag(id: tag.idValue, name: renameDraft, kind: "custom")
            }
            self.renameTarget = nil
            renameDraft = ""
        } catch {
            AppLogger.persistence.error("Unable to rename item: \(error.localizedDescription)")
        }
    }
}
