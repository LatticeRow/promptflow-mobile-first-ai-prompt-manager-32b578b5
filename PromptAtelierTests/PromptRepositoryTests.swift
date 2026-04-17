import XCTest
@testable import PromptAtelier

final class PromptRepositoryTests: XCTestCase {
    private var persistenceController: PersistenceController!
    private var repository: PromptRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistenceController = PersistenceController(target: .mainApp, inMemory: true)
        repository = PromptRepository(container: persistenceController.container)
    }

    override func tearDownWithError() throws {
        repository = nil
        persistenceController = nil
        try super.tearDownWithError()
    }

    func testRepositoryCRUDAndFiltering() throws {
        let folderID = try repository.createFolder(name: "Inbox", sortOrder: 1)
        let toolTagID = try repository.createTag(name: "ChatGPT", kind: "tool")
        let taskTagID = try repository.createTag(name: "Writing", kind: "task")

        let promptID = try repository.createPrompt(
            text: "Write a concise launch announcement for PromptAtelier.",
            url: nil,
            sourceAppBundleID: "com.apple.mobilesafari",
            captureMethod: "unit_test",
            folderID: folderID,
            tagIDs: [toolTagID, taskTagID]
        )

        let context = persistenceController.container.viewContext
        let createdPrompt = try XCTUnwrap(repository.prompt(id: promptID, in: context))
        XCTAssertEqual(createdPrompt.displayTitle, "Write a concise launch announcement for PromptAtelier.")
        XCTAssertEqual(createdPrompt.folder?.idValue, folderID)
        XCTAssertEqual(Set(createdPrompt.sortedTags.map(\.idValue)), Set([toolTagID, taskTagID]))

        var filter = PromptFilter()
        filter.searchText = "launch announcement"
        XCTAssertEqual(repository.prompts(matching: filter).map(\.idValue), [promptID])

        filter = PromptFilter()
        filter.folderID = folderID
        XCTAssertEqual(repository.prompts(matching: filter).map(\.idValue), [promptID])

        filter = PromptFilter()
        filter.tagIDs = [toolTagID]
        XCTAssertEqual(repository.prompts(matching: filter).map(\.idValue), [promptID])

        try repository.updatePromptText(
            id: promptID,
            title: "",
            body: "Summarize the release notes into three short bullets."
        )
        try repository.setPinned(id: promptID, isPinned: true)
        try repository.setFavorite(id: promptID, isFavorite: true)

        let updatedPrompt = try XCTUnwrap(repository.prompt(id: promptID, in: context))
        XCTAssertEqual(updatedPrompt.displayTitle, "Summarize the release notes into three short bullets.")
        XCTAssertTrue(updatedPrompt.isPinned)
        XCTAssertTrue(updatedPrompt.isFavorite)

        let copyDate = Date(timeIntervalSinceReferenceDate: 123_456)
        let copyMetadata = try XCTUnwrap(repository.markPromptCopied(id: promptID, copiedAt: copyDate))
        XCTAssertEqual(copyMetadata.copyCount, 1)
        XCTAssertEqual(copyMetadata.lastCopiedAt, copyDate)

        let recentPrompts = repository.recentlyCopiedPrompts(limit: 5)
        XCTAssertEqual(recentPrompts.map(\.idValue), [promptID])

        let storedMetadata = try XCTUnwrap(repository.copyMetadata(for: promptID))
        XCTAssertEqual(storedMetadata.copyCount, 1)
        XCTAssertEqual(storedMetadata.lastCopiedAt, copyDate)

        try repository.deletePrompt(id: promptID)
        XCTAssertNil(repository.prompt(id: promptID, in: context))
    }

    func testFolderAndTagCRUD() throws {
        let folderID = try repository.createFolder(name: "  Saved  ", sortOrder: 2)
        let tagID = try repository.createTag(name: "  Research  ", kind: "task")

        try repository.renameFolder(id: folderID, name: "Archive", sortOrder: 9)
        try repository.renameTag(id: tagID, name: "Research Notes", kind: "custom")

        let context = persistenceController.container.viewContext
        let folder = try XCTUnwrap(repository.folder(id: folderID, in: context))
        let tag = try XCTUnwrap(repository.tag(id: tagID, in: context))

        XCTAssertEqual(folder.displayName, "Archive")
        XCTAssertEqual(folder.sortOrder, 9)
        XCTAssertEqual(tag.displayName, "Research Notes")
        XCTAssertEqual(tag.kindValue, "custom")

        XCTAssertEqual(repository.folders().map(\.idValue), [folderID])
        XCTAssertEqual(repository.tags(kind: "custom").map(\.idValue), [tagID])

        try repository.deleteTag(id: tagID)
        try repository.deleteFolder(id: folderID)

        XCTAssertNil(repository.tag(id: tagID, in: context))
        XCTAssertNil(repository.folder(id: folderID, in: context))
    }

    func testNormalizerPreservesURLMetadataAndCollapsesSpacing() throws {
        let url = try XCTUnwrap(URL(string: "https://chatgpt.com/share/abc123"))
        let normalized = try XCTUnwrap(
            CaptureNormalizer().normalize(
                text: "  Build a concise launch brief.  \n\n\nInclude risks. ",
                url: url,
                metadataTitle: "  Prompt Strategy  ",
                metadataText: "  Prompt Strategy  "
            )
        )

        XCTAssertEqual(normalized.title, "Prompt Strategy")
        XCTAssertEqual(
            normalized.body,
            """
            Build a concise launch brief.

            Include risks.

            https://chatgpt.com/share/abc123
            """
        )
        XCTAssertEqual(normalized.sourceType, "url")
        XCTAssertEqual(normalized.sourceURLString, "https://chatgpt.com/share/abc123")
        XCTAssertEqual(normalized.sourceHost, "chatgpt.com")
    }

    func testDeferredEnrichmentClassifiesSharedCaptureOnForegroundPath() throws {
        let promptID = try repository.createPrompt(
            text: "Research a better system prompt structure for release planning.",
            url: URL(string: "https://chatgpt.com/share/brief"),
            metadataTitle: "Release Planning",
            sourceAppBundleID: nil,
            captureMethod: "share_extension",
            shouldClassify: false
        )

        let context = persistenceController.container.viewContext
        let pendingPrompt = try XCTUnwrap(repository.prompt(id: promptID, in: context))
        XCTAssertNil(pendingPrompt.suggestedToolTag)
        XCTAssertNil(pendingPrompt.suggestedTaskTag)
        XCTAssertEqual(pendingPrompt.classificationConfidence, 0)

        XCTAssertEqual(repository.enrichPendingPrompts(limit: 10), 1)

        let enrichedPrompt = try XCTUnwrap(repository.prompt(id: promptID, in: context))
        XCTAssertEqual(enrichedPrompt.suggestedToolTag, "ChatGPT")
        XCTAssertEqual(enrichedPrompt.suggestedTaskTag, "Research")
        XCTAssertGreaterThan(enrichedPrompt.classificationConfidence, 0.5)
    }

    func testCategorizerUsesSourceHintsAndNaturalLanguageScoring() throws {
        let service = CategorizationService()

        let codingCapture = try XCTUnwrap(
            CaptureNormalizer().normalize(
                text: "Debug this SwiftUI view and refactor the async state handling.",
                url: nil
            )
        )
        let codingClassification = service.classify(codingCapture, sourceAppBundleID: "com.apple.dt.xcode")
        XCTAssertEqual(codingClassification.tool, PromptTaxonomy.ToolTag.codingAI.rawValue)
        XCTAssertEqual(codingClassification.task, PromptTaxonomy.TaskTag.coding.rawValue)
        XCTAssertGreaterThan(codingClassification.confidence, 0.8)

        let imageCapture = try XCTUnwrap(
            CaptureNormalizer().normalize(
                text: "Create a logo prompt with cinematic lighting and strong negative space.",
                url: URL(string: "https://www.midjourney.com/imagine")!,
                metadataTitle: "Luxury logo prompt"
            )
        )
        let imageClassification = service.classify(imageCapture, sourceAppBundleID: nil)
        XCTAssertEqual(imageClassification.tool, PromptTaxonomy.ToolTag.midjourney.rawValue)
        XCTAssertEqual(imageClassification.task, PromptTaxonomy.TaskTag.imageGeneration.rawValue)
        XCTAssertGreaterThan(imageClassification.confidence, 0.85)
    }

    func testManualRecategorizationPersistsSelectedTags() throws {
        let promptID = try repository.createPrompt(
            text: "Summarize this roadmap update for the team.",
            url: nil,
            sourceAppBundleID: nil,
            captureMethod: "unit_test"
        )

        try repository.recategorizePrompt(
            id: promptID,
            toolTag: .claude,
            taskTag: .brainstorming
        )

        let prompt = try XCTUnwrap(repository.prompt(id: promptID, in: persistenceController.container.viewContext))
        XCTAssertEqual(prompt.suggestedToolTag, PromptTaxonomy.ToolTag.claude.rawValue)
        XCTAssertEqual(prompt.suggestedTaskTag, PromptTaxonomy.TaskTag.brainstorming.rawValue)
        XCTAssertEqual(prompt.classificationConfidence, 1, accuracy: 0.0001)
    }

    func testPromptAssignmentAndRecentCopyOrdering() throws {
        let folderID = try repository.createFolder(name: "Client Work", sortOrder: 0)
        let customTagID = try repository.createTag(name: "Launch", kind: "custom")

        let olderPromptID = try repository.createPrompt(
            text: "Draft a launch note for the mobile app.",
            url: nil,
            sourceAppBundleID: nil,
            captureMethod: "unit_test"
        )
        let newerPromptID = try repository.createPrompt(
            text: "Refactor the library screen for better readability.",
            url: nil,
            sourceAppBundleID: nil,
            captureMethod: "unit_test"
        )

        try repository.assignPrompt(id: newerPromptID, toFolderID: folderID)
        try repository.setTags(forPromptID: newerPromptID, tagIDs: [customTagID])

        _ = repository.markPromptCopied(id: olderPromptID, copiedAt: Date(timeIntervalSinceReferenceDate: 100))
        _ = repository.markPromptCopied(id: newerPromptID, copiedAt: Date(timeIntervalSinceReferenceDate: 200))

        let recentlyCopied = repository.recentlyCopiedPrompts(limit: 2)
        XCTAssertEqual(recentlyCopied.map(\.idValue), [newerPromptID, olderPromptID])

        let prompt = try XCTUnwrap(repository.prompt(id: newerPromptID, in: persistenceController.container.viewContext))
        XCTAssertEqual(prompt.folder?.idValue, folderID)
        XCTAssertEqual(prompt.sortedTags.map(\.idValue), [customTagID])
    }

    func testWidgetSourcePromptsPreferPinnedThenRecentThenLatest() throws {
        let latestOnlyPromptID = try repository.createPrompt(
            text: "Polish the release note for the app update.",
            url: nil,
            sourceAppBundleID: nil,
            captureMethod: "unit_test"
        )
        let recentPromptID = try repository.createPrompt(
            text: "Summarize the client workshop into three bullets.",
            url: nil,
            sourceAppBundleID: nil,
            captureMethod: "unit_test"
        )
        let pinnedPromptID = try repository.createPrompt(
            text: "Refine the evergreen product positioning prompt.",
            url: nil,
            sourceAppBundleID: nil,
            captureMethod: "unit_test"
        )

        try repository.setPinned(id: pinnedPromptID, isPinned: true)
        _ = repository.markPromptCopied(id: recentPromptID, copiedAt: Date(timeIntervalSinceReferenceDate: 300))

        let widgetPrompts = repository.widgetSourcePrompts(limit: 3)
        XCTAssertEqual(widgetPrompts.map(\.idValue), [pinnedPromptID, recentPromptID, latestOnlyPromptID])
    }

    func testDeepLinkHandlerRoutesLibraryAndPromptLinks() throws {
        XCTAssertEqual(
            DeepLinkHandler.route(for: try XCTUnwrap(URL(string: "promptatelier://library"))),
            .library
        )

        let promptID = UUID()
        XCTAssertEqual(
            DeepLinkHandler.route(for: try XCTUnwrap(URL(string: "promptatelier://prompt/\(promptID.uuidString)"))),
            .prompt(promptID)
        )
        XCTAssertNil(DeepLinkHandler.route(for: try XCTUnwrap(URL(string: "promptatelier://prompt/not-a-uuid"))))
        XCTAssertNil(DeepLinkHandler.route(for: try XCTUnwrap(URL(string: "https://promptatelier.app/prompt/\(promptID.uuidString)"))))
    }

    func testRecentStatusMatchesRecentAndStalePrompts() throws {
        let now = Date(timeIntervalSinceReferenceDate: 500_000)
        let recentPromptID = try repository.createPrompt(
            text: "Draft a new home screen prompt.",
            url: nil,
            sourceAppBundleID: nil,
            captureMethod: "unit_test"
        )
        let stalePromptID = try repository.createPrompt(
            text: "Summarize the archive notes.",
            url: nil,
            sourceAppBundleID: nil,
            captureMethod: "unit_test"
        )

        let context = persistenceController.container.viewContext
        let recentPrompt = try XCTUnwrap(repository.prompt(id: recentPromptID, in: context))
        let stalePrompt = try XCTUnwrap(repository.prompt(id: stalePromptID, in: context))

        recentPrompt.createdAt = Calendar.current.date(byAdding: .day, value: -1, to: now)
        recentPrompt.lastCopiedAt = Calendar.current.date(byAdding: .day, value: -1, to: now)
        stalePrompt.createdAt = Calendar.current.date(byAdding: .day, value: -10, to: now)
        stalePrompt.lastCopiedAt = Calendar.current.date(byAdding: .day, value: -10, to: now)
        try context.save()

        XCTAssertTrue(LibraryRecentStatus.allTime.matches(recentPrompt, now: now))
        XCTAssertTrue(LibraryRecentStatus.allTime.matches(stalePrompt, now: now))
        XCTAssertTrue(LibraryRecentStatus.addedRecently.matches(recentPrompt, now: now))
        XCTAssertFalse(LibraryRecentStatus.addedRecently.matches(stalePrompt, now: now))
        XCTAssertTrue(LibraryRecentStatus.copiedRecently.matches(recentPrompt, now: now))
        XCTAssertFalse(LibraryRecentStatus.copiedRecently.matches(stalePrompt, now: now))
    }
}
