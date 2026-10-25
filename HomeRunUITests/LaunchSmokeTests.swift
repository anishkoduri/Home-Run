import XCTest

final class LaunchSmokeTests: XCTestCase {
    func testTermsGateThenCustomerTabsAndScenarioList() {
        let app = XCUIApplication()
        app.launch()
        let toggle = app.switches["I agree to the demo terms"]
        if toggle.waitForExistence(timeout: 20) {
            toggle.tap()
            let continueButton = app.buttons["Continue"]
            XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
            continueButton.tap()
        }
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Discover"].exists)
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
