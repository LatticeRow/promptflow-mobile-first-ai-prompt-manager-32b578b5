import CoreData
import Foundation

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
    func savePrompt(text: String?, url: URL?, sourceAppBundleID: String?, captureMethod: String) -> PromptRecord? {
        guard let normalized = normalizer.normalize(text: text, url: url) else {
            return nil
        }

        let classification = categorizer.classify(normalized)
        let context = container.newBackgroundContext()

        var createdID: NSManagedObjectID?
        context.performAndWait {
            let prompt = PromptRecord(context: context)
            prompt.id = UUID()
            prompt.createdAt = .now
            prompt.updatedAt = .now
            prompt.title = normalized.title
            prompt.body = normalized.body
            prompt.sourceType = normalized.sourceType
            prompt.sourceAppBundleID = sourceAppBundleID
            prompt.sourceURLString = normalized.sourceURLString
            prompt.suggestedToolTag = classification.tool
            prompt.suggestedTaskTag = classification.task
            prompt.classificationConfidence = classification.confidence
            prompt.captureMethod = captureMethod
            prompt.copyCount = 0
            prompt.isPinned = false
            prompt.isFavorite = false

            do {
                try context.save()
                createdID = prompt.objectID
            } catch {
                AppLogger.persistence.error("Unable to save prompt: \(error.localizedDescription)")
            }
        }

        guard let createdID else {
            return nil
        }

        return container.viewContext.object(with: createdID) as? PromptRecord
    }

    func prompt(id: UUID, in context: NSManagedObjectContext) -> PromptRecord? {
        let request = PromptRecord.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        return try? context.fetch(request).first
    }

    func latestPrompts(limit: Int) -> [PromptRecord] {
        let request = PromptRecord.fetchRequest()
        request.fetchLimit = limit
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PromptRecord.updatedAt, ascending: false)]

        return (try? container.viewContext.fetch(request)) ?? []
    }

    func togglePinned(id: UUID) {
        updatePrompt(id: id) { prompt in
            prompt.isPinned.toggle()
        }
    }

    func toggleFavorite(id: UUID) {
        updatePrompt(id: id) { prompt in
            prompt.isFavorite.toggle()
        }
    }

    func markPromptCopied(id: UUID) {
        updatePrompt(id: id) { prompt in
            prompt.copyCount += 1
            prompt.lastCopiedAt = .now
        }
    }

    private func updatePrompt(id: UUID, mutate: @escaping (PromptRecord) -> Void) {
        let context = container.newBackgroundContext()
        context.perform {
            let request = PromptRecord.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let prompt = try? context.fetch(request).first else {
                return
            }

            mutate(prompt)
            prompt.updatedAt = .now

            do {
                try context.save()
            } catch {
                AppLogger.persistence.error("Unable to update prompt: \(error.localizedDescription)")
            }
        }
    }
}
