import XCTest

/// Behaviour of the commercial flows in the real app UI. Uses synthetic demo data and the DEBUG preview store
/// (`-storeMode`), so no App Store account is needed; reminders use the real notification center.
final class CommercialFlowsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(store: String = "free", tab: String = "profile", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoScenario", "teen", "-storeMode", store, "-initialTab", tab] + extra
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    // 1–4: open Profile, open Premium, view the paywall, close it.
    func testOpenPremiumViewPaywallAndClose() {
        let app = launch()
        let explore = app.buttons["premium.explore"]
        XCTAssertTrue(explore.waitForExistence(timeout: 10), "Profile shows the Premium card for free users")
        explore.tap()

        XCTAssertTrue(element(app, "paywall.title").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["plan.year"].waitForExistence(timeout: 5), "prices load")
        XCTAssertTrue(app.buttons["plan.month"].exists)
        XCTAssertTrue(element(app, "paywall.terms").exists, "billing terms are present")
        let purchase = app.buttons["paywall.purchase"]
        XCTAssertTrue(purchase.exists)
        XCTAssertTrue(purchase.label.contains("$39.99"), "the purchase button shows the price: \(purchase.label)")
        XCTAssertTrue(app.buttons["paywall.restore"].exists, "restore is always available")

        app.buttons["plan.month"].tap()
        XCTAssertTrue(purchase.label.contains("$5.99"), purchase.label)

        app.buttons["paywall.close"].tap()
        XCTAssertTrue(explore.waitForExistence(timeout: 5), "closing returns to Profile")
    }

    func testPurchaseShowsProgressThenPremium() {
        let app = launch()
        app.buttons["premium.explore"].tap()
        let purchase = app.buttons["paywall.purchase"]
        XCTAssertTrue(app.buttons["plan.year"].waitForExistence(timeout: 5))
        purchase.tap()
        XCTAssertTrue(element(app, "paywall.active").waitForExistence(timeout: 10), "success state after a verified purchase")
        app.buttons["paywall.done"].tap()
        XCTAssertFalse(app.buttons["premium.explore"].waitForExistence(timeout: 2), "Profile shows Premium as active")
        XCTAssertTrue(app.buttons["profile.manageSubscription"].exists)
    }

    func testCancelledPurchaseIsNeutral() {
        let app = launch(store: "cancelPurchase")
        app.buttons["premium.explore"].tap()
        XCTAssertTrue(app.buttons["plan.year"].waitForExistence(timeout: 5))
        app.buttons["paywall.purchase"].tap()
        let status = element(app, "paywall.status")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Purchase cancelled.")
        XCTAssertTrue(app.buttons["paywall.purchase"].isEnabled, "can try again")
    }

    func testFailedPurchaseOffersRetry() {
        let app = launch(store: "failPurchase")
        app.buttons["premium.explore"].tap()
        XCTAssertTrue(app.buttons["plan.year"].waitForExistence(timeout: 5))
        app.buttons["paywall.purchase"].tap()
        XCTAssertTrue(element(app, "paywall.status").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.purchase"].label.hasPrefix("Try again"))
    }

    // 5–6: open notification settings, enable and disable a reminder (real UNUserNotificationCenter).
    func testEnableAndDisableDailyCheckIn() {
        let app = launch()
        addUIInterruptionMonitor(withDescription: "Notifications permission") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.buttons["profile.reminders"].tap()
        let toggle = app.switches["notifications.toggle.dailyCheckIn"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0", "reminders are off by default")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        app.tap() // lets the interruption monitor run if the alert was attached to the app

        let next = element(app, "notifications.next.daily")
        XCTAssertTrue(next.waitForExistence(timeout: 10), "a reminder was scheduled and read back from iOS")
        let scheduled = NSPredicate(format: "label CONTAINS[c] 'Next check-in reminder' AND NOT (label CONTAINS[c] 'Scheduling')")
        expectation(for: scheduled, evaluatedWith: next)
        waitForExpectations(timeout: 10)
        XCTAssertEqual(toggle.value as? String, "1")

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertFalse(next.waitForExistence(timeout: 2) && next.isHittable, "turning it off removes the schedule")
        XCTAssertEqual(toggle.value as? String, "0")
    }

    // 7–8: open the report and generate it.
    func testReportPreviewAndGeneration() {
        let app = launch(store: "premium")
        app.buttons["profile.reports"].tap()
        XCTAssertTrue(element(app, "report.sections").waitForExistence(timeout: 5), "preview lists what's included")
        let generate = app.buttons["report.generate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        generate.tap()
        XCTAssertTrue(element(app, "report.ready").waitForExistence(timeout: 20), "PDF generated on the device")
        XCTAssertTrue(element(app, "report.share").exists)
    }

    func testFreeReportPreviewIsVisibleAndGenerationOpensPaywall() {
        let app = launch()
        app.buttons["profile.reports"].tap()
        XCTAssertTrue(element(app, "report.sections").waitForExistence(timeout: 5), "free users can see the full preview")
        app.buttons["report.generate"].tap()
        XCTAssertTrue(element(app, "paywall.title").waitForExistence(timeout: 5))
        app.buttons["paywall.close"].tap()
        XCTAssertTrue(element(app, "report.sections").waitForExistence(timeout: 5))
    }

    func testCoreResultStaysFree() {
        let app = launch(tab: "growth")
        XCTAssertTrue(app.staticTexts["Growth chart"].waitForExistence(timeout: 5), "chart is free")
        XCTAssertTrue(element(app, "analysis.locked").waitForExistence(timeout: 5) || app.staticTexts["Advanced growth analysis"].exists)
    }
}
