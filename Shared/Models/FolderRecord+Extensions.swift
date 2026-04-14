import CoreData
import Foundation

@objc(FolderRecord)
public final class FolderRecord: NSManagedObject {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        sortOrder = 0
    }
}

extension FolderRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FolderRecord> {
        NSFetchRequest<FolderRecord>(entityName: "FolderRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var prompts: Set<PromptRecord>?

    var idValue: UUID {
        id ?? UUID()
    }

    var displayName: String {
        let fallback = "Untitled Folder"
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }

        return name
    }

    var sortedPrompts: [PromptRecord] {
        (prompts ?? []).sorted {
            ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
        }
    }
}
