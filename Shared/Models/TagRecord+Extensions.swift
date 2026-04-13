import CoreData

@objc(TagRecord)
public final class TagRecord: NSManagedObject {
}

extension TagRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TagRecord> {
        NSFetchRequest<TagRecord>(entityName: "TagRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var kind: String?
    @NSManaged public var name: String?
    @NSManaged public var prompts: Set<PromptRecord>?
}
