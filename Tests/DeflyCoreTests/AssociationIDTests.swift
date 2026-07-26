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

    func testRepresentativeURLUsesNormalizedScheme() throws {
        let id = try AssociationID.makeURLScheme("HTTPS")

        XCTAssertEqual(id.representativeURL?.absoluteString, "https:")
    }

    func testHandlerIdentityPrefersBundleIdentifier() {
        let app = HandlerApplication(
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app"),
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            compatibility: .systemCandidate
        )

        XCTAssertEqual(app.stableID, "bundle:com.apple.Safari")
    }
}
