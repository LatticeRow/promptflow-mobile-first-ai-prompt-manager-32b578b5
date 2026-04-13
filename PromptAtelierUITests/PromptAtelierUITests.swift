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

        let addSampleButton = app.buttons["library.addSample"]
        XCTAssertTrue(addSampleButton.waitForExistence(timeout: 5))
        addSampleButton.tap()

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
    }
}
