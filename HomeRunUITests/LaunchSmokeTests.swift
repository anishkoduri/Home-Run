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

    func testTypingAPickupRequestAndATripNote() {
        let app = XCUIApplication()
        app.launch()
        let demo = app.buttons["demo-entry"]
        if demo.waitForExistence(timeout: 8) { demo.tap() }
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 15))
        let personal = app.buttons["home-or-personal"]
        XCTAssertTrue(personal.waitForExistence(timeout: 5))
        personal.tap()
        if app.buttons["pickup-city-option-Houston"].waitForExistence(timeout: 2) {
            app.buttons["pickup-city-option-Houston"].tap()
            XCTAssertTrue(personal.waitForExistence(timeout: 3))
            personal.tap()
        }
        let details = app.textViews["request-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        details.tap()
        details.typeText("Black backpack with a red tag")
        XCTAssertEqual(details.value as? String, "Black backpack with a red tag")
        app.buttons["Orders"].tap()
        XCTAssertTrue(app.staticTexts["Orders"].waitForExistence(timeout: 5))
        app.buttons["Discover"].tap()
        XCTAssertTrue(app.staticTexts["Discover"].waitForExistence(timeout: 5))
        app.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["home-or-personal"].waitForExistence(timeout: 5))
        app.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 5))
        app.buttons["bring-food"].tap()
        let postTrip = app.buttons["Post a trip"]
        XCTAssertTrue(postTrip.waitForExistence(timeout: 5))
        postTrip.tap()
        let notes = app.textViews["trip-notes"]
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        notes.tap()
        notes.typeText("Leaving after class")
        XCTAssertEqual(notes.value as? String, "Leaving after class")
    }

    func testOrderThenDriveAcceptsFromTheAcceptScreen() {
        let app = XCUIApplication()
        app.launch()
        let demo = app.buttons["demo-entry"]
        if demo.waitForExistence(timeout: 8) { demo.tap() }
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["coverage-map"].waitForExistence(timeout: 5))

        app.buttons["Discover"].tap()
        let search = app.textFields["Restaurant or store"]
        if !search.waitForExistence(timeout: 3), app.buttons["pickup-city-option-Houston"].waitForExistence(timeout: 2) {
            app.buttons["pickup-city-option-Houston"].tap()
        }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        app.buttons["Food"].tap()
        search.tap()
        search.typeText("Chipotle")
        app.buttons["place-search-submit"].tap()
        let place = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place-result-' AND label != 'Save place' AND NOT (label BEGINSWITH 'Photo')")).firstMatch
        XCTAssertTrue(place.waitForExistence(timeout: 8))
        let placeName = place.label.components(separatedBy: ",").first ?? place.label
        place.tap()
        let continueOrder = app.buttons["continue-order"]
        if !continueOrder.waitForExistence(timeout: 2) { app.swipeUp() }
        XCTAssertTrue(continueOrder.waitForExistence(timeout: 4))
        continueOrder.tap()

        let details = app.textViews["request-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        details.tap()
        details.typeText("Two takeout bags")
        let quantity = app.textFields["request-quantity"]
        quantity.tap()
        quantity.typeText("2 bags")
        let contact = app.textFields["request-contact"]
        contact.tap()
        contact.typeText("Anish")
        if app.keyboards.buttons["Return"].exists { app.keyboards.buttons["Return"].tap() }
        let post = app.buttons["post-pickup-submit"]
        if !post.isHittable { app.swipeUp() }
        XCTAssertTrue(post.waitForExistence(timeout: 3))
        post.tap()
        XCTAssertTrue(app.staticTexts["Request posted"].waitForExistence(timeout: 8))

        app.buttons["Profile"].tap()
        let jordan = app.buttons["demo-actor-demo-jordan"]
        if !jordan.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(jordan.waitForExistence(timeout: 5))
        jordan.tap()
        let request = app.descendants(matching: .any)["available-request"]
        XCTAssertTrue(request.waitForExistence(timeout: 8))
        request.tap()
        XCTAssertTrue(app.descendants(matching: .any)["accept-screen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["Name on the order"].exists)
        XCTAssertFalse(app.textViews["Pickup details"].exists)
        let accept = app.descendants(matching: .any)["claim-request"]
        XCTAssertTrue(accept.waitForExistence(timeout: 3))
        accept.tap()

        if app.buttons["get-food"].waitForExistence(timeout: 4) { app.buttons["get-food"].tap() }
        app.buttons["Profile"].tap()
        let anish = app.buttons["demo-actor-demo-maya"]
        if !anish.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(anish.waitForExistence(timeout: 5))
        anish.tap()
        app.buttons["Orders"].tap()
        let order = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", placeName)).firstMatch
        XCTAssertTrue(order.waitForExistence(timeout: 8))
        order.tap()
        let approve = app.buttons["Approve delivery fee"]
        XCTAssertTrue(approve.waitForExistence(timeout: 5))
        approve.tap()
        XCTAssertTrue(app.descendants(matching: .any)["driver-track"].waitForExistence(timeout: 5))
    }
}
