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
}
