import XCTest
@testable import DeflyCore

@MainActor
final class ChangeExecutorTests: XCTestCase {
    func testExecutorContinuesAfterFailureAndVerifiesReadback() async throws {
        let workspace = FakeWorkspaceClient()
        let http = try AssociationID.makeURLScheme("http")
        let https = try AssociationID.makeURLScheme("https")
        workspace.setErrors[http] = TestError.denied
        let plan = ChangePlan(changes: [
            PlannedChange(
                association: http,
                previousHandler: TestApps.safari,
                targetHandler: TestApps.arc,
                compatibility: .systemCandidate
            ),
            PlannedChange(
                association: https,
                previousHandler: TestApps.safari,
                targetHandler: TestApps.arc,
                compatibility: .systemCandidate
            )
        ])

        let report = await ChangeExecutor(workspace: workspace)
            .execute(plan)

        XCTAssertEqual(
            report.results.map(\.status),
            [.failed, .verified]
        )
        XCTAssertEqual(
            report.retryPlan().changes.map(\.association),
            [http]
        )
        XCTAssertEqual(workspace.events, [
            "set:scheme:http",
            "set:scheme:https",
            "read:scheme:http",
            "read:scheme:https"
        ])
    }
}
