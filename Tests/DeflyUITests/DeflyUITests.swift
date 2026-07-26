import XCTest

final class DeflyUITests: XCTestCase {
    func testFirstLaunchIsChineseAndShowsFiveDestinations() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-preferences"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["概览"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["文件类型"].exists)
        XCTAssertTrue(app.staticTexts["URL 协议"].exists)
        XCTAssertTrue(app.staticTexts["应用"].exists)
        XCTAssertTrue(app.staticTexts["设置"].exists)
    }
}
