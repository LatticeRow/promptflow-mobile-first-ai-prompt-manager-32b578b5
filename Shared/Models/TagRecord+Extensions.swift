import CoreData
import Foundation

@objc(TagRecord)
public final class TagRecord: NSManagedObject {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
    }
}

extension TagRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TagRecord> {
        NSFetchRequest<TagRecord>(entityName: "TagRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var kind: String?
    @NSManaged public var name: String?
    @NSManaged public var prompts: Set<PromptRecord>?

    var idValue: UUID {
        id ?? UUID()
    }

    var displayName: String {
        let fallback = "Untitled Tag"
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }

        return name
    }

    var kindValue: String {
        guard let kind, !kind.isEmpty else {
            return "custom"
        }

        return kind
    }
}
