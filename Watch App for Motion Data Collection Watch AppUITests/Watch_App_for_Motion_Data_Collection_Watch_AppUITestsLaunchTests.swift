//
//  Watch_App_for_Motion_Data_Collection_Watch_AppUITestsLaunchTests.swift
//  Watch App for Motion Data Collection Watch AppUITests
//
//  Created by Anika Ganu on 6/4/25.
//

import XCTest

final class Watch_App_for_Motion_Data_Collection_Watch_AppUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
