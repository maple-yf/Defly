import XCTest
@testable import DeflyCore

final class AssociationIDTests: XCTestCase {
    func testURLSchemeIsTrimmedAndLowercased() throws {
        let id = try AssociationID.makeURLScheme(" HTTPS ")

        XCTAssertEqual(id, .urlScheme("https"))
        XCTAssertEqual(id.stableKey, "scheme:https")
    }

    func testContentTypeRejectsBlankIdentifier() {
        XCTAssertThrowsError(try AssociationID.makeContentType("   "))
    }
}
