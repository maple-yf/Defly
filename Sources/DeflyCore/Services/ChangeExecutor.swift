import Foundation

@MainActor
public final class ChangeExecutor {
    private let workspace: WorkspaceClient

    public init(workspace: WorkspaceClient) {
        self.workspace = workspace
    }

    public func execute(_ plan: ChangePlan) async -> ChangeReport {
        var results: [ChangeItemResult] = []

        for change in plan.changes {
            do {
                try await workspace.setDefaultApplication(
                    change.targetHandler,
                    for: change.association
                )
                let actual = workspace.defaultApplication(
                    for: change.association
                )
                let status: ChangeItemResult.Status =
                    actual?.stableID == change.targetHandler.stableID
                    ? .verified
                    : .notApplied
                results.append(
                    ChangeItemResult(
                        change: change,
                        status: status,
                        errorDescription: nil
                    )
                )
            } catch {
                results.append(
                    ChangeItemResult(
                        change: change,
                        status: .failed,
                        errorDescription: String(describing: error)
                    )
                )
            }
        }

        return ChangeReport(sourcePlan: plan, results: results)
    }
}
