import XCTest

final class PromptAtelierUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPrimaryNavigationAndControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-promptatelier-ui-testing", "-promptatelier-seed-sample"]
        app.launch()

        app.tabBars.buttons["tab.organize"].tap()

        let folderField = app.textFields["organize.screen.newFolder"]
        XCTAssertTrue(folderField.waitForExistence(timeout: 5))
        folderField.tap()
        folderField.typeText("Clients")
        app.buttons["organize.screen.addFolder"].tap()

        let folderRename = app.buttons.matching(identifierPrefix: "organize.screen.folder.").firstMatch
        XCTAssertTrue(folderRename.waitForExistence(timeout: 5))
        folderRename.tap()
        app.buttons["Save"].tap()

        let tagField = app.textFields["organize.screen.newTag"]
        XCTAssertTrue(tagField.waitForExistence(timeout: 5))
        tagField.tap()
        tagField.typeText("Launch")
        app.buttons["organize.screen.addTag"].tap()

        let tagRename = app.buttons.matching(identifierPrefix: "organize.screen.tag.").firstMatch
        XCTAssertTrue(tagRename.waitForExistence(timeout: 5))
        tagRename.tap()
        app.buttons["Save"].tap()

        dismissKeyboardIfPresent(in: app)
        app.tabBars.buttons["tab.library"].tap()

        let pinnedButton = app.buttons["library.filter.pinned"]
        XCTAssertTrue(pinnedButton.waitForExistence(timeout: 5))
        pinnedButton.tap()
        pinnedButton.tap()

        let favoritesButton = app.buttons["library.filter.favorites"]
        XCTAssertTrue(favoritesButton.waitForExistence(timeout: 5))
        favoritesButton.tap()
        favoritesButton.tap()

        let firstRow = app.buttons["library.promptRow"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()

        XCTAssertTrue(app.buttons["detail.pin"].waitForExistence(timeout: 5))
        app.buttons["detail.pin"].tap()
        app.buttons["detail.favorite"].tap()
        app.buttons["detail.manage"].tap()

        XCTAssertTrue(app.buttons["recategorize.close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["organize.folder.none"].waitForExistence(timeout: 5))

        let toolIdentifiers = [
            "recategorize.tool.chatgpt",
            "recategorize.tool.claude",
            "recategorize.tool.midjourney",
            "recategorize.tool.coding_ai",
            "recategorize.tool.generic_ai",
        ]

        for identifier in toolIdentifiers {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
        }

        let taskIdentifiers = [
            "recategorize.task.writing",
            "recategorize.task.coding",
            "recategorize.task.image_generation",
            "recategorize.task.summarization",
            "recategorize.task.research",
            "recategorize.task.brainstorming",
        ]

        for identifier in taskIdentifiers {
            let button = app.buttons[identifier]
            tapWhenVisible(button, in: app)
        }

        let newFolderField = app.textFields["organize.newFolder"]
        XCTAssertTrue(newFolderField.waitForExistence(timeout: 5))
        newFolderField.tap()
        newFolderField.typeText("Archive")
        app.buttons["organize.addFolder"].tap()

        let folderOption = app.buttons.matching(identifierPrefix: "organize.folder.").firstMatch
        XCTAssertTrue(folderOption.waitForExistence(timeout: 5))
        folderOption.tap()

        let newTagField = app.textFields["organize.newTag"]
        XCTAssertTrue(newTagField.waitForExistence(timeout: 5))
        newTagField.tap()
        newTagField.typeText("Urgent")
        app.buttons["organize.addTag"].tap()

        let customTag = app.buttons.matching(identifierPrefix: "organize.tag.").firstMatch
        XCTAssertTrue(customTag.waitForExistence(timeout: 5))
        customTag.tap()

        app.buttons["recategorize.save"].tap()

        XCTAssertTrue(app.buttons["detail.copy"].waitForExistence(timeout: 5))
        app.buttons["detail.copy"].tap()

        app.buttons["detail.manage"].tap()
        XCTAssertTrue(app.buttons["recategorize.close"].waitForExistence(timeout: 5))
        app.buttons["recategorize.close"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()

        let folderFilter = app.buttons["library.filter.folder"]
        XCTAssertTrue(folderFilter.waitForExistence(timeout: 5))
        folderFilter.tap()
        XCTAssertTrue(app.buttons["Clients"].waitForExistence(timeout: 5))
        app.buttons["Clients"].tap()

        folderFilter.tap()
        XCTAssertTrue(app.buttons["All folders"].waitForExistence(timeout: 5))
        app.buttons["All folders"].tap()

        let tagFilter = app.buttons["library.filter.tag"]
        XCTAssertTrue(tagFilter.waitForExistence(timeout: 5))
        tagFilter.tap()
        XCTAssertTrue(app.buttons["Launch"].waitForExistence(timeout: 5))
        app.buttons["Launch"].tap()

        tagFilter.tap()
        XCTAssertTrue(app.buttons["All tags"].waitForExistence(timeout: 5))
        app.buttons["All tags"].tap()
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
}

private extension XCUIElementQuery {
    func matching(identifierPrefix prefix: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }
}

private func dismissKeyboardIfPresent(in app: XCUIApplication) {
    guard app.keyboards.count > 0 else {
        return
    }

    let candidateLabels = ["Return", "Done", "Hide keyboard"]
    for label in candidateLabels {
        let button = app.keyboards.buttons[label]
        if button.exists {
            button.tap()
            return
        }
    }
}

private func tapWhenVisible(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 5) {
    XCTAssertTrue(element.waitForExistence(timeout: 5))

    for _ in 0..<maxSwipes where !element.isHittable {
        app.swipeUp()
    }

    XCTAssertTrue(element.isHittable)
    element.tap()
}
