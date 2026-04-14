import CoreData
import Foundation

struct PromptFilter {
    enum SortOrder {
        case updatedAtDescending
        case createdAtDescending
        case lastCopiedAtDescending
    }

    var searchText = ""
    var folderID: UUID?
    var tagIDs: Set<UUID> = []
    var sourceType: String?
    var favoritesOnly = false
    var pinnedOnly = false
    var copiedSince: Date?
    var sortOrder: SortOrder = .updatedAtDescending
    var limit: Int?
}

struct PromptCopyMetadata {
    let promptID: UUID
    let copyCount: Int32
    let lastCopiedAt: Date?
}

enum PromptRepositoryError: LocalizedError {
    case invalidCapture
    case missingPrompt(UUID)
    case missingFolder(UUID)
    case missingTag(UUID)
    case invalidFolderName
    case invalidTagName
    case writeDidNotReturn

    var errorDescription: String? {
        switch self {
        case .invalidCapture:
            return "The shared content did not contain a prompt or URL."
        case .missingPrompt(let id):
            return "No prompt exists for id \(id.uuidString)."
        case .missingFolder(let id):
            return "No folder exists for id \(id.uuidString)."
        case .missingTag(let id):
            return "No tag exists for id \(id.uuidString)."
        case .invalidFolderName:
            return "Folder names must not be empty."
        case .invalidTagName:
            return "Tag names must not be empty."
        case .writeDidNotReturn:
            return "The persistence write operation did not return a result."
        }
    }
}

final class PromptRepository {
    private let container: NSPersistentCloudKitContainer
    private let normalizer = CaptureNormalizer()
    private let categorizer = CategorizationService()

    init(container: NSPersistentCloudKitContainer) {
        self.container = container
    }

    func seedSamplePromptsIfNeeded(forceInsert: Bool = false) {
        let context = container.viewContext
        let request = PromptRecord.fetchRequest()
        request.fetchLimit = 1

        if !forceInsert, let count = try? context.count(for: request), count > 0 {
            return
        }

        let samples = [
            "Refactor this SwiftUI view so the state model is easier to test.",
            "Summarize the attached article into five concise bullets for executives."
        ]

        samples.forEach { sample in
            _ = savePrompt(text: sample, url: nil, sourceAppBundleID: "com.apple.mobilesafari", captureMethod: "sample")
        }
    }

    @discardableResult
    func savePrompt(
        text: String?,
        url: URL?,
        metadataTitle: String? = nil,
        metadataText: String? = nil,
        sourceAppBundleID: String?,
        captureMethod: String,
        folderID: UUID? = nil,
        tagIDs: [UUID] = [],
        shouldClassify: Bool = true
    ) -> PromptRecord? {
        do {
            let createdID = try createPrompt(
                text: text,
                url: url,
                metadataTitle: metadataTitle,
                metadataText: metadataText,
                sourceAppBundleID: sourceAppBundleID,
                captureMethod: captureMethod,
                folderID: folderID,
                tagIDs: tagIDs,
                shouldClassify: shouldClassify
            )
            return prompt(id: createdID, in: container.viewContext)
        } catch {
            AppLogger.persistence.error("Unable to save prompt: \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func createPrompt(
        text: String?,
        url: URL?,
        metadataTitle: String? = nil,
        metadataText: String? = nil,
        sourceAppBundleID: String?,
        captureMethod: String,
        folderID: UUID? = nil,
        tagIDs: [UUID] = [],
        shouldClassify: Bool = true
    ) throws -> UUID {
        guard let normalized = normalizer.normalize(
            text: text,
            url: url,
            metadataTitle: metadataTitle,
            metadataText: metadataText
        ) else {
            throw PromptRepositoryError.invalidCapture
        }

        let classification = shouldClassify ? categorizer.classify(normalized) : nil

        return try performWrite { context in
            let prompt = PromptRecord(context: context)
            prompt.title = normalized.title
            prompt.body = normalized.body
            prompt.sourceType = normalized.sourceType
            prompt.sourceAppBundleID = sourceAppBundleID
            prompt.sourceURLString = normalized.sourceURLString
            prompt.suggestedToolTag = classification?.tool
            prompt.suggestedTaskTag = classification?.task
            prompt.classificationConfidence = classification?.confidence ?? 0
            prompt.captureMethod = captureMethod
            prompt.updatedAt = .now

            if let folderID {
                prompt.folder = try fetchFolder(id: folderID, in: context)
            }

            if !tagIDs.isEmpty {
                prompt.tags = try Set(tagIDs.map { try fetchTag(id: $0, in: context) })
            }

            return prompt.idValue
        }
    }

    @discardableResult
    func enrichPendingPrompts(limit: Int = 25) -> Int {
        do {
            return try performWrite { context in
                let request = PromptRecord.fetchRequest()
                request.fetchLimit = limit
                request.sortDescriptors = [NSSortDescriptor(keyPath: \PromptRecord.createdAt, ascending: false)]
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "captureMethod == %@", "share_extension"),
                    NSCompoundPredicate(orPredicateWithSubpredicates: [
                        NSPredicate(format: "suggestedToolTag == nil"),
                        NSPredicate(format: "suggestedTaskTag == nil"),
                        NSPredicate(format: "classificationConfidence <= 0")
                    ])
                ])

                let promptsNeedingEnrichment = try context.fetch(request)
                for prompt in promptsNeedingEnrichment {
                    let normalized = normalizer.normalize(
                        text: prompt.body,
                        url: prompt.sourceURLString.flatMap(URL.init(string:)),
                        metadataTitle: prompt.title
                    ) ?? fallbackNormalizedCapture(for: prompt)
                    let classification = categorizer.classify(normalized)
                    prompt.suggestedToolTag = classification.tool
                    prompt.suggestedTaskTag = classification.task
                    prompt.classificationConfidence = classification.confidence
                }

                return promptsNeedingEnrichment.count
            }
        } catch {
            AppLogger.persistence.error("Unable to enrich pending prompts: \(error.localizedDescription)")
            return 0
        }
    }

    @discardableResult
    func createFolder(name: String, sortOrder: Int32 = 0) throws -> UUID {
        let sanitizedName = try validatedName(name, emptyError: .invalidFolderName)

        return try performWrite { context in
            let folder = FolderRecord(context: context)
            folder.name = sanitizedName
            folder.sortOrder = sortOrder
            return folder.idValue
        }
    }

    @discardableResult
    func createTag(name: String, kind: String) throws -> UUID {
        let sanitizedName = try validatedName(name, emptyError: .invalidTagName)

        return try performWrite { context in
            let tag = TagRecord(context: context)
            tag.name = sanitizedName
            tag.kind = kind
            return tag.idValue
        }
    }

    func prompt(id: UUID, in context: NSManagedObjectContext) -> PromptRecord? {
        let request = PromptRecord.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }

    func folder(id: UUID, in context: NSManagedObjectContext) -> FolderRecord? {
        let request = FolderRecord.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }

    func tag(id: UUID, in context: NSManagedObjectContext) -> TagRecord? {
        let request = TagRecord.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }

    func latestPrompts(limit: Int) -> [PromptRecord] {
        var filter = PromptFilter()
        filter.limit = limit
        filter.sortOrder = .updatedAtDescending
        return prompts(matching: filter)
    }

    func prompts(matching filter: PromptFilter = PromptFilter(), in context: NSManagedObjectContext? = nil) -> [PromptRecord] {
        let activeContext = context ?? container.viewContext
        let request = PromptRecord.fetchRequest()
        request.predicate = makePromptPredicate(filter: filter)
        request.sortDescriptors = sortDescriptors(for: filter.sortOrder)

        if let limit = filter.limit {
            request.fetchLimit = limit
        }

        return (try? activeContext.fetch(request)) ?? []
    }

    func recentlyCopiedPrompts(limit: Int, since date: Date? = nil) -> [PromptRecord] {
        var filter = PromptFilter()
        filter.limit = limit
        filter.copiedSince = date
        filter.sortOrder = .lastCopiedAtDescending

        let request = PromptRecord.fetchRequest()
        let copiedPredicate = NSPredicate(format: "lastCopiedAt != nil")
        let basePredicate = makePromptPredicate(filter: filter)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [copiedPredicate, basePredicate])
        request.sortDescriptors = sortDescriptors(for: .lastCopiedAtDescending)
        request.fetchLimit = limit

        return (try? container.viewContext.fetch(request)) ?? []
    }

    func copyMetadata(for id: UUID, in context: NSManagedObjectContext? = nil) -> PromptCopyMetadata? {
        guard let prompt = prompt(id: id, in: context ?? container.viewContext) else {
            return nil
        }

        return PromptCopyMetadata(promptID: prompt.idValue, copyCount: prompt.copyCount, lastCopiedAt: prompt.lastCopiedAt)
    }

    func folders(in context: NSManagedObjectContext? = nil) -> [FolderRecord] {
        let request = FolderRecord.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FolderRecord.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \FolderRecord.name, ascending: true)
        ]
        return (try? (context ?? container.viewContext).fetch(request)) ?? []
    }

    func tags(kind: String? = nil, in context: NSManagedObjectContext? = nil) -> [TagRecord] {
        let request = TagRecord.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TagRecord.kind, ascending: true),
            NSSortDescriptor(keyPath: \TagRecord.name, ascending: true)
        ]

        if let kind {
            request.predicate = NSPredicate(format: "kind == %@", kind)
        }

        return (try? (context ?? container.viewContext).fetch(request)) ?? []
    }

    func togglePinned(id: UUID) {
        do {
            guard let currentValue = prompt(id: id, in: container.viewContext)?.isPinned else {
                return
            }
            try setPinned(id: id, isPinned: !currentValue)
        } catch {
            AppLogger.persistence.error("Unable to toggle pinned state: \(error.localizedDescription)")
        }
    }

    func setPinned(id: UUID, isPinned: Bool) throws {
        try mutatePrompt(id: id) { prompt in
            prompt.isPinned = isPinned
        }
    }

    func toggleFavorite(id: UUID) {
        do {
            guard let currentValue = prompt(id: id, in: container.viewContext)?.isFavorite else {
                return
            }
            try setFavorite(id: id, isFavorite: !currentValue)
        } catch {
            AppLogger.persistence.error("Unable to toggle favorite state: \(error.localizedDescription)")
        }
    }

    func setFavorite(id: UUID, isFavorite: Bool) throws {
        try mutatePrompt(id: id) { prompt in
            prompt.isFavorite = isFavorite
        }
    }

    @discardableResult
    func markPromptCopied(id: UUID, copiedAt: Date = .now) -> PromptCopyMetadata? {
        do {
            return try performWrite { context in
                let prompt = try fetchPrompt(id: id, in: context)
                prompt.copyCount += 1
                prompt.lastCopiedAt = copiedAt
                prompt.updatedAt = copiedAt
                return PromptCopyMetadata(promptID: prompt.idValue, copyCount: prompt.copyCount, lastCopiedAt: prompt.lastCopiedAt)
            }
        } catch {
            AppLogger.persistence.error("Unable to mark prompt copied: \(error.localizedDescription)")
            return nil
        }
    }

    func updatePromptText(id: UUID, title: String, body: String) throws {
        let normalizedBody = normalizer.normalizeBody(body)
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? normalizer.deriveTitle(from: normalizedBody)
            : title.trimmingCharacters(in: .whitespacesAndNewlines)

        try mutatePrompt(id: id) { prompt in
            prompt.title = normalizedTitle
            prompt.body = normalizedBody
        }
    }

    func assignPrompt(id: UUID, toFolderID folderID: UUID?) throws {
        try performWrite { context in
            let prompt = try fetchPrompt(id: id, in: context)
            prompt.folder = try folderID.map { try fetchFolder(id: $0, in: context) }
            prompt.updatedAt = .now
        }
    }

    func setTags(forPromptID promptID: UUID, tagIDs: [UUID]) throws {
        try performWrite { context in
            let prompt = try fetchPrompt(id: promptID, in: context)
            prompt.tags = try Set(tagIDs.map { try fetchTag(id: $0, in: context) })
            prompt.updatedAt = .now
        }
    }

    func renameFolder(id: UUID, name: String, sortOrder: Int32? = nil) throws {
        let sanitizedName = try validatedName(name, emptyError: .invalidFolderName)

        try performWrite { context in
            let folder = try fetchFolder(id: id, in: context)
            folder.name = sanitizedName
            if let sortOrder {
                folder.sortOrder = sortOrder
            }
        }
    }

    func renameTag(id: UUID, name: String, kind: String? = nil) throws {
        let sanitizedName = try validatedName(name, emptyError: .invalidTagName)

        try performWrite { context in
            let tag = try fetchTag(id: id, in: context)
            tag.name = sanitizedName
            if let kind {
                tag.kind = kind
            }
        }
    }

    func deletePrompt(id: UUID) throws {
        try performWrite { context in
            context.delete(try fetchPrompt(id: id, in: context))
        }
    }

    func deleteFolder(id: UUID) throws {
        try performWrite { context in
            context.delete(try fetchFolder(id: id, in: context))
        }
    }

    func deleteTag(id: UUID) throws {
        try performWrite { context in
            context.delete(try fetchTag(id: id, in: context))
        }
    }

    private func mutatePrompt(id: UUID, mutation: @escaping (PromptRecord) -> Void) throws {
        try performWrite { context in
            let prompt = try fetchPrompt(id: id, in: context)
            mutation(prompt)
            prompt.updatedAt = .now
        }
    }

    private func fetchPrompt(id: UUID, in context: NSManagedObjectContext) throws -> PromptRecord {
        guard let prompt = prompt(id: id, in: context) else {
            throw PromptRepositoryError.missingPrompt(id)
        }

        return prompt
    }

    private func fetchFolder(id: UUID, in context: NSManagedObjectContext) throws -> FolderRecord {
        guard let folder = folder(id: id, in: context) else {
            throw PromptRepositoryError.missingFolder(id)
        }

        return folder
    }

    private func fetchTag(id: UUID, in context: NSManagedObjectContext) throws -> TagRecord {
        guard let tag = tag(id: id, in: context) else {
            throw PromptRepositoryError.missingTag(id)
        }

        return tag
    }

    private func validatedName(_ value: String, emptyError: PromptRepositoryError) throws -> String {
        let sanitized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            throw emptyError
        }

        return sanitized
    }

    private func sortDescriptors(for sortOrder: PromptFilter.SortOrder) -> [NSSortDescriptor] {
        switch sortOrder {
        case .updatedAtDescending:
            return [NSSortDescriptor(keyPath: \PromptRecord.updatedAt, ascending: false)]
        case .createdAtDescending:
            return [NSSortDescriptor(keyPath: \PromptRecord.createdAt, ascending: false)]
        case .lastCopiedAtDescending:
            return [
                NSSortDescriptor(keyPath: \PromptRecord.lastCopiedAt, ascending: false),
                NSSortDescriptor(keyPath: \PromptRecord.updatedAt, ascending: false)
            ]
        }
    }

    private func makePromptPredicate(filter: PromptFilter) -> NSPredicate {
        var predicates: [NSPredicate] = []

        let searchText = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchText.isEmpty {
            predicates.append(
                NSPredicate(
                    format: "title CONTAINS[cd] %@ OR body CONTAINS[cd] %@ OR suggestedToolTag CONTAINS[cd] %@ OR suggestedTaskTag CONTAINS[cd] %@",
                    searchText,
                    searchText,
                    searchText,
                    searchText
                )
            )
        }

        if let folderID = filter.folderID {
            predicates.append(NSPredicate(format: "folder.id == %@", folderID as CVarArg))
        }

        if !filter.tagIDs.isEmpty {
            predicates.append(NSPredicate(format: "ANY tags.id IN %@", Array(filter.tagIDs)))
        }

        if filter.favoritesOnly {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        if filter.pinnedOnly {
            predicates.append(NSPredicate(format: "isPinned == YES"))
        }

        if let copiedSince = filter.copiedSince {
            predicates.append(NSPredicate(format: "lastCopiedAt >= %@", copiedSince as NSDate))
        }

        if let sourceType = filter.sourceType {
            predicates.append(NSPredicate(format: "sourceType == %@", sourceType))
        }

        guard !predicates.isEmpty else {
            return NSPredicate(value: true)
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func fallbackNormalizedCapture(for prompt: PromptRecord) -> CaptureNormalizer.NormalizedCapture {
        CaptureNormalizer.NormalizedCapture(
            title: prompt.displayTitle,
            body: prompt.displayBody,
            sourceType: prompt.sourceType ?? "text",
            sourceURLString: prompt.sourceURLString,
            sourceHost: prompt.sourceURLString.flatMap { URLComponents(string: $0)?.host }
        )
    }

    private func performWrite<T>(_ work: (NSManagedObjectContext) throws -> T) throws -> T {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        var result: Result<T, Error>?
        context.performAndWait {
            do {
                let value = try work(context)
                if context.hasChanges {
                    try context.save()
                    container.viewContext.performAndWait {
                        container.viewContext.refreshAllObjects()
                    }
                }
                result = .success(value)
            } catch {
                context.rollback()
                result = .failure(error)
            }
        }

        guard let result else {
            throw PromptRepositoryError.writeDidNotReturn
        }

        return try result.get()
    }
}
