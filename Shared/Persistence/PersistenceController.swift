import CoreData
import Foundation

struct PersistenceController {
    enum Target {
        case mainApp
        case shareExtension
        case widget

        var usesCloudKit: Bool {
            self == .mainApp
        }
    }

    let container: NSPersistentCloudKitContainer

    init(target: Target, inMemory: Bool = false) {
        container = Self.makeContainer(target: target, inMemory: inMemory)
    }

    private static func makeContainer(target: Target, inMemory: Bool) -> NSPersistentCloudKitContainer {
        let model = ManagedObjectModelFactory.makeModel()

        func configuredContainer(usesCloudKit: Bool) -> NSPersistentCloudKitContainer {
            let container = NSPersistentCloudKitContainer(name: "CoreDataModel", managedObjectModel: model)
            let description = NSPersistentStoreDescription()

            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            } else {
                description.url = AppGroupPaths.storeURL()
            }

            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.cloudKitContainerOptions = usesCloudKit
                ? NSPersistentCloudKitContainerOptions(containerIdentifier: AppGroupPaths.cloudKitContainerIdentifier)
                : nil

            container.persistentStoreDescriptions = [description]
            return container
        }

        func load(_ container: NSPersistentCloudKitContainer) -> Error? {
            let semaphore = DispatchSemaphore(value: 0)
            var loadError: Error?

            container.loadPersistentStores { _, error in
                loadError = error
                semaphore.signal()
            }

            semaphore.wait()
            return loadError
        }

        let preferredContainer = configuredContainer(usesCloudKit: target.usesCloudKit)
        if let loadError = load(preferredContainer) {
            guard target.usesCloudKit else {
                fatalError("Failed to load persistent stores: \(loadError.localizedDescription)")
            }

            AppLogger.persistence.error("CloudKit store unavailable, falling back to local store: \(loadError.localizedDescription)")
            let fallbackContainer = configuredContainer(usesCloudKit: false)

            if let fallbackError = load(fallbackContainer) {
                fatalError("Failed to load fallback persistent stores: \(fallbackError.localizedDescription)")
            }

            configureViewContext(for: fallbackContainer)
            return fallbackContainer
        }

        configureViewContext(for: preferredContainer)
        return preferredContainer
    }

    private static func configureViewContext(for container: NSPersistentCloudKitContainer) {
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = "PromptAtelier"
    }
}

private enum ManagedObjectModelFactory {
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let folder = NSEntityDescription()
        folder.name = "FolderRecord"
        folder.managedObjectClassName = NSStringFromClass(FolderRecord.self)

        let prompt = NSEntityDescription()
        prompt.name = "PromptRecord"
        prompt.managedObjectClassName = NSStringFromClass(PromptRecord.self)

        let tag = NSEntityDescription()
        tag.name = "TagRecord"
        tag.managedObjectClassName = NSStringFromClass(TagRecord.self)

        let folderID = attribute(name: "id", type: .UUIDAttributeType)
        let folderName = attribute(name: "name", type: .stringAttributeType)
        let folderSortOrder = attribute(name: "sortOrder", type: .integer32AttributeType, defaultValue: 0)

        let promptBody = attribute(name: "body", type: .stringAttributeType)
        let promptCaptureMethod = attribute(name: "captureMethod", type: .stringAttributeType, defaultValue: "share_extension")
        let promptClassificationConfidence = attribute(name: "classificationConfidence", type: .doubleAttributeType, defaultValue: 0.0)
        let promptCopyCount = attribute(name: "copyCount", type: .integer32AttributeType, defaultValue: 0)
        let promptCreatedAt = attribute(name: "createdAt", type: .dateAttributeType)
        let promptID = attribute(name: "id", type: .UUIDAttributeType)
        let promptIsFavorite = attribute(name: "isFavorite", type: .booleanAttributeType, defaultValue: false)
        let promptIsPinned = attribute(name: "isPinned", type: .booleanAttributeType, defaultValue: false)
        let promptLastCopiedAt = attribute(name: "lastCopiedAt", type: .dateAttributeType)
        let promptSourceAppBundleID = attribute(name: "sourceAppBundleID", type: .stringAttributeType)
        let promptSourceType = attribute(name: "sourceType", type: .stringAttributeType)
        let promptSourceURLString = attribute(name: "sourceURLString", type: .stringAttributeType)
        let promptSuggestedTaskTag = attribute(name: "suggestedTaskTag", type: .stringAttributeType)
        let promptSuggestedToolTag = attribute(name: "suggestedToolTag", type: .stringAttributeType)
        let promptTitle = attribute(name: "title", type: .stringAttributeType)
        let promptUpdatedAt = attribute(name: "updatedAt", type: .dateAttributeType)

        let tagID = attribute(name: "id", type: .UUIDAttributeType)
        let tagKind = attribute(name: "kind", type: .stringAttributeType)
        let tagName = attribute(name: "name", type: .stringAttributeType)

        let folderPrompts = relationship(name: "prompts", destination: prompt, toMany: true)
        let promptFolder = relationship(name: "folder", destination: folder, toMany: false)
        folderPrompts.inverseRelationship = promptFolder
        promptFolder.inverseRelationship = folderPrompts

        let promptTags = relationship(name: "tags", destination: tag, toMany: true)
        let tagPrompts = relationship(name: "prompts", destination: prompt, toMany: true)
        promptTags.inverseRelationship = tagPrompts
        tagPrompts.inverseRelationship = promptTags

        folder.properties = [folderID, folderName, folderSortOrder, folderPrompts]
        prompt.properties = [
            promptBody,
            promptCaptureMethod,
            promptClassificationConfidence,
            promptCopyCount,
            promptCreatedAt,
            promptID,
            promptIsFavorite,
            promptIsPinned,
            promptLastCopiedAt,
            promptSourceAppBundleID,
            promptSourceType,
            promptSourceURLString,
            promptSuggestedTaskTag,
            promptSuggestedToolTag,
            promptTitle,
            promptUpdatedAt,
            promptFolder,
            promptTags,
        ]
        tag.properties = [tagID, tagKind, tagName, tagPrompts]

        model.entities = [folder, prompt, tag]
        return model
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        defaultValue: Any? = nil,
        optional: Bool = true
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static func relationship(
        name: String,
        destination: NSEntityDescription,
        toMany: Bool
    ) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.deleteRule = .nullifyDeleteRule
        relationship.minCount = 0
        relationship.maxCount = toMany ? 0 : 1
        relationship.isOptional = true
        relationship.isOrdered = false
        return relationship
    }
}
