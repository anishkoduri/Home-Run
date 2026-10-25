import XCTest

final class LaunchSmokeTests: XCTestCase {
    func testTermsGateThenCustomerTabsAndScenarioList() {
        let app = XCUIApplication()
        app.launch()
        let demo = app.buttons["demo-entry"]
        if demo.waitForExistence(timeout: 8) {
            demo.tap()
        }
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Discover"].exists)
        app.buttons["bring-food"].tap()
        XCTAssertTrue(app.staticTexts["Requests"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.alerts["This account is for ordering"].exists)
        app.buttons["get-food"].tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Orders"].exists)
        XCTAssertTrue(app.buttons["Profile"].exists)
        app.buttons["Profile"].tap()
        let controls = app.buttons["Demo controls"]
        if !controls.waitForExistence(timeout: 5) {
            app.swipeUp()
        }
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        controls.tap()
        XCTAssertTrue(app.buttons["scenario-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["scenario-10"].exists)
        app.buttons["scenario-1"].tap()
        let prepared = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "From Houston, with dinner")).firstMatch
        XCTAssertTrue(prepared.waitForExistence(timeout: 10))
    }
}
