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

    func testFileTypeSearchSelectsPDFAndShowsIdentifier() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-use-fixtures"]
        app.launch()

        app.staticTexts["文件类型"].click()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.click()
        search.typeText("pdf")
        app.staticTexts["PDF 文档"].click()

        XCTAssertTrue(
            app.staticTexts["com.adobe.pdf"].waitForExistence(
                timeout: 3
            )
        )
    }
}
