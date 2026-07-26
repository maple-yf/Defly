import XCTest

@MainActor
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

    func testChangeRequiresConfirmationAndRetriesOnlyFailure() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-use-fixtures",
            "-fixture-partial-failure"
        ]
        app.launch()

        app.buttons["更改默认应用"].firstMatch.click()
        app.buttons["Arc"].click()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(
            sheet.staticTexts["确认更改默认应用？"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(sheet.staticTexts["http"].exists)
        XCTAssertTrue(sheet.staticTexts["https"].exists)
        XCTAssertTrue(sheet.staticTexts[".html"].exists)

        sheet.buttons["确认更改"].click()
        XCTAssertTrue(
            sheet.buttons["重试失败项"].waitForExistence(
                timeout: 3
            )
        )
    }

    func testEnglishPersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-reset-preferences"
        ]
        app.launch()

        app.staticTexts["设置"].click()
        app.popUpButtons["语言"].click()
        app.menuItems["English"].click()
        XCTAssertTrue(
            app.staticTexts["Overview"].waitForExistence(
                timeout: 2
            )
        )

        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Overview"].waitForExistence(
                timeout: 2
            )
        )
    }
}
