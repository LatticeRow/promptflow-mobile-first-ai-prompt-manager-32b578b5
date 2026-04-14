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

        app.tabBars.buttons["Organize"].tap()
        app.tabBars.buttons["Settings"].tap()
        app.switches["settings.preferICloud"].tap()
        app.tabBars.buttons["Library"].tap()

        let searchField = app.searchFields["Search prompts"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Refactor")

        if app.buttons["Search"].exists {
            app.buttons["Search"].tap()
        }

        if app.buttons["Clear text"].exists {
            app.buttons["Clear text"].tap()
        }

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
        app.buttons["detail.copy"].tap()
        app.buttons["detail.editTags"].tap()

        XCTAssertTrue(app.buttons["recategorize.close"].waitForExistence(timeout: 5))
        app.buttons["recategorize.close"].tap()

        app.buttons["detail.editTags"].tap()

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

        let sheetScrollView = app.scrollViews.firstMatch
        if sheetScrollView.exists {
            sheetScrollView.swipeUp()
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
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
        }

        app.buttons["recategorize.save"].tap()
    }
}
