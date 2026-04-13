import CoreData

@objc(FolderRecord)
public final class FolderRecord: NSManagedObject {
}

extension FolderRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FolderRecord> {
        NSFetchRequest<FolderRecord>(entityName: "FolderRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var prompts: Set<PromptRecord>?
}
