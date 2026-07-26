import XCTest
@testable import DeflyCore

@MainActor
final class ChangePlannerTests: XCTestCase {
    func testPlannerRemovesNoOpAndDeduplicatesAssociations() throws {
        let workspace = FakeWorkspaceClient()
        let safari = TestApps.safari
        let arc = TestApps.arc
        let http = try AssociationID.makeURLScheme("http")
        let https = try AssociationID.makeURLScheme("https")
        workspace.defaults = [http: safari, https: arc]
        workspace.candidates = [
            http: [safari, arc],
            https: [safari, arc]
        ]

        let plan = ChangePlanner(workspace: workspace).makePlan(
            associations: [https, http, http],
            target: arc
        )

        XCTAssertEqual(plan.changes.map(\.association), [http])
        XCTAssertEqual(
            plan.changes.first?.compatibility,
            .systemCandidate
        )
    }
}
