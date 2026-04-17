import CoreData
import Foundation

@objc(PromptRecord)
public final class PromptRecord: NSManagedObject, Identifiable {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = .now
        updatedAt = .now
        captureMethod = "share_extension"
        sourceType = "text"
        copyCount = 0
        isPinned = false
        isFavorite = false
        classificationConfidence = 0
    }
}

extension PromptRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PromptRecord> {
        NSFetchRequest<PromptRecord>(entityName: "PromptRecord")
    }

    @NSManaged public var body: String?
    @NSManaged public var captureMethod: String?
    @NSManaged public var classificationConfidence: Double
    @NSManaged public var copyCount: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var isPinned: Bool
    @NSManaged public var lastCopiedAt: Date?
    @NSManaged public var sourceAppBundleID: String?
    @NSManaged public var sourceType: String?
    @NSManaged public var sourceURLString: String?
    @NSManaged public var suggestedTaskTag: String?
    @NSManaged public var suggestedToolTag: String?
    @NSManaged public var title: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var folder: FolderRecord?
    @NSManaged public var tags: Set<TagRecord>?

    var idValue: UUID {
        id ?? UUID()
    }

    var displayTitle: String {
        let fallback = "Untitled Prompt"
        guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }

        return title
    }

    var displayBody: String {
        body ?? ""
    }

    var previewBody: String {
        String(displayBody.prefix(120))
    }

    var sortedTags: [TagRecord] {
        (tags ?? []).sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}

enum LibraryRecentStatus: String, CaseIterable, Identifiable {
    case allTime = "All time"
    case addedRecently = "Added recently"
    case copiedRecently = "Copied recently"

    var id: String { rawValue }

    var accessibilityIdentifier: String {
        switch self {
        case .allTime:
            return "all_time"
        case .addedRecently:
            return "added_recently"
        case .copiedRecently:
            return "copied_recently"
        }
    }

    func matches(_ prompt: PromptRecord, now: Date = .now, calendar: Calendar = .current) -> Bool {
        switch self {
        case .allTime:
            return true
        case .addedRecently:
            guard let cutoff = calendar.date(byAdding: .day, value: -7, to: now),
                  let createdAt = prompt.createdAt else {
                return false
            }
            return createdAt >= cutoff
        case .copiedRecently:
            guard let cutoff = calendar.date(byAdding: .day, value: -7, to: now),
                  let lastCopiedAt = prompt.lastCopiedAt else {
                return false
            }
            return lastCopiedAt >= cutoff
        }
    }
}
