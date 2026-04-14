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

        var transactionAuthor: String {
            switch self {
            case .mainApp:
                return "PromptAtelier.app"
            case .shareExtension:
                return "PromptAtelier.shareExtension"
            case .widget:
                return "PromptAtelier.widget"
            }
        }
    }

    static let sharedApp = PersistenceController(target: .mainApp)
    static let sharedShareExtension = PersistenceController(target: .shareExtension)
    static let sharedWidget = PersistenceController(target: .widget)
    static let preview = PersistenceController(target: .mainApp, inMemory: true)

    let container: NSPersistentCloudKitContainer

    init(target: Target, inMemory: Bool = false) {
        container = Self.makeContainer(target: target, inMemory: inMemory)
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    private static func makeContainer(target: Target, inMemory: Bool) -> NSPersistentCloudKitContainer {
        let model = ManagedObjectModelFactory.model

        func configuredContainer(usesCloudKit: Bool) -> NSPersistentCloudKitContainer {
            let container = NSPersistentCloudKitContainer(name: "CoreDataModel", managedObjectModel: model)
            let description = inMemory
                ? NSPersistentStoreDescription()
                : NSPersistentStoreDescription(url: AppGroupPaths.storeURL())
            description.type = inMemory ? NSInMemoryStoreType : NSSQLiteStoreType
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            if !inMemory {
                description.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, forKey: NSPersistentStoreFileProtectionKey)
            }
            description.cloudKitContainerOptions = usesCloudKit && !inMemory
                ? NSPersistentCloudKitContainerOptions(containerIdentifier: AppGroupPaths.cloudKitContainerIdentifier)
                : nil
            container.persistentStoreDescriptions = [description]
            return container
        }

        func load(_ container: NSPersistentCloudKitContainer, author: String) -> Error? {
            let semaphore = DispatchSemaphore(value: 0)
            var loadError: Error?

            container.loadPersistentStores { _, error in
                loadError = error
                configureContexts(for: container, author: author)
                semaphore.signal()
            }

            semaphore.wait()
            return loadError
        }

        let preferredContainer = configuredContainer(usesCloudKit: target.usesCloudKit)
        if let loadError = load(preferredContainer, author: target.transactionAuthor) {
            guard target.usesCloudKit, !inMemory else {
                fatalError("Failed to load persistent stores: \(loadError.localizedDescription)")
            }

            AppLogger.persistence.error("CloudKit store unavailable, falling back to local store: \(loadError.localizedDescription)")
            let fallbackContainer = configuredContainer(usesCloudKit: false)

            if let fallbackError = load(fallbackContainer, author: target.transactionAuthor) {
                fatalError("Failed to load fallback persistent stores: \(fallbackError.localizedDescription)")
            }

            return fallbackContainer
        }

        return preferredContainer
    }

    private static func configureContexts(for container: NSPersistentCloudKitContainer, author: String) {
        container.viewContext.name = author
        container.viewContext.transactionAuthor = author
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.shouldDeleteInaccessibleFaults = true
    }
}

private enum ManagedObjectModelFactory {
    static let model = makeModel()

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
