//
//  CrossStreetsUITests.swift
//  CrossStreetsUITests
//
//  Created by Tyler Amos 24 on 7/11/25.
//

import XCTest

final class CrossStreetsUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAppLaunch() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Verify the app launched successfully
        XCTAssertTrue(app.exists)
        
        // Verify basic UI elements are present
        // Note: These selectors may need adjustment based on actual UI structure
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be present")
    }
    
    @MainActor
    func testBasicNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that we can navigate to different tabs
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be present")
        
        // Note: Add more specific navigation tests based on your actual UI structure
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
