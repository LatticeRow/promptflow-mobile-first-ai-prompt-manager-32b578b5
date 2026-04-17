import XCTest

final class PromptAtelierUITests: XCTestCase {
    private let browsePromptID = "A9D7E2A2-CF74-4B42-AE35-1F80A6FD10C1"
    private let secondaryBrowsePromptID = "C5E50609-78D0-4B8A-B730-F0A89CDEE5D1"
    private let copyPromptID = "AE3D138F-C42B-4D31-92CC-C65DDF9A654B"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLibraryBrowseFlowWithSeededData() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-promptatelier-ui-testing", "-promptatelier-seed-browse-flow"]
        app.launch()

        let primaryRow = app.buttons["library.promptRow.\(browsePromptID)"]
        let secondaryRow = app.buttons["library.promptRow.\(secondaryBrowsePromptID)"]

        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))
        XCTAssertTrue(secondaryRow.waitForExistence(timeout: 5))

        let pinnedButton = app.buttons["library.filter.pinned"]
        XCTAssertTrue(pinnedButton.waitForExistence(timeout: 5))
        pinnedButton.tap()
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))
        XCTAssertFalse(secondaryRow.exists)
        pinnedButton.tap()

        let folderFilter = app.buttons["library.filter.folder"]
        XCTAssertTrue(folderFilter.waitForExistence(timeout: 5))
        folderFilter.tap()
        XCTAssertTrue(app.buttons["Clients"].waitForExistence(timeout: 5))
        app.buttons["Clients"].tap()
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))
        XCTAssertFalse(secondaryRow.exists)

        folderFilter.tap()
        XCTAssertTrue(app.buttons["All folders"].waitForExistence(timeout: 5))
        app.buttons["All folders"].tap()

        let tagFilter = app.buttons["library.filter.tag"]
        XCTAssertTrue(tagFilter.waitForExistence(timeout: 5))
        tagFilter.tap()
        XCTAssertTrue(app.buttons["Launch"].waitForExistence(timeout: 5))
        app.buttons["Launch"].tap()
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))
        XCTAssertFalse(secondaryRow.exists)

        primaryRow.tap()

        XCTAssertTrue(app.navigationBars["Prompt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Executive launch brief"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detail.folderValue"].label, "Clients")
        XCTAssertTrue(app.buttons["detail.copy"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPromptDetailCopyFlowWithSeededData() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-promptatelier-ui-testing", "-promptatelier-seed-copy-flow"]
        app.launch()

        let row = app.buttons["library.promptRow.\(copyPromptID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let copiedValue = app.staticTexts["detail.copiedValue"]
        XCTAssertTrue(copiedValue.waitForExistence(timeout: 5))
        XCTAssertEqual(copiedValue.label, "0")

        let copyButton = app.buttons["detail.copy"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5))
        copyButton.tap()

        XCTAssertEqual(copyButton.label, "Copied")
    }

    @MainActor
    func testSettingsShowsLocalOnlySyncMessaging() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-promptatelier-ui-testing", "-promptatelier-sync-local-only"]
        app.launch()

        app.tabBars.buttons["tab.settings"].tap()

        XCTAssertTrue(app.staticTexts["This iPhone only"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your prompts stay available here even when iCloud is unavailable."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsShowsOfflineAndSignedOutSyncMessaging() throws {
        let offlineApp = XCUIApplication()
        offlineApp.launchArguments = ["-promptatelier-ui-testing", "-promptatelier-sync-offline"]
        offlineApp.launch()

        offlineApp.tabBars.buttons["tab.settings"].tap()

        XCTAssertTrue(offlineApp.staticTexts["Offline right now"].waitForExistence(timeout: 5))
        XCTAssertTrue(offlineApp.staticTexts["Your prompts stay usable here and sync when your connection returns."].waitForExistence(timeout: 5))

        offlineApp.terminate()

        let signedOutApp = XCUIApplication()
        signedOutApp.launchArguments = ["-promptatelier-ui-testing", "-promptatelier-sync-no-account"]
        signedOutApp.launch()

        signedOutApp.tabBars.buttons["tab.settings"].tap()

        XCTAssertTrue(signedOutApp.staticTexts["Sync is off"].waitForExistence(timeout: 5))
        XCTAssertTrue(signedOutApp.staticTexts["Your prompts stay on this iPhone until iCloud is turned on."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWidgetDeepLinkOpensPromptDetail() throws {
        let promptID = UUID(uuidString: "2F7D8B75-2E88-4A37-B2CA-E4A66B503B70")!
        let app = XCUIApplication()
        app.launchArguments = [
            "-promptatelier-ui-testing",
            "-promptatelier-seed-sample",
            "-promptatelier-open-url",
            "promptatelier://prompt/\(promptID.uuidString)",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Prompt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["detail.copy"].waitForExistence(timeout: 5))
    }
}
