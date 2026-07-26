import Foundation

@MainActor
public final class ChangeExecutor {
    private let workspace: WorkspaceClient

    public init(workspace: WorkspaceClient) {
        self.workspace = workspace
    }

    public func execute(_ plan: ChangePlan) async -> ChangeReport {
        var errorsByChangeID: [String: String] = [:]

        for change in plan.changes {
            do {
                try await workspace.setDefaultApplication(
                    change.targetHandler,
                    for: change.association
                )
            } catch {
                errorsByChangeID[change.id] = String(
                    describing: error
                )
            }
        }

        let results = plan.changes.map { change in
            let actual = workspace.defaultApplication(
                for: change.association
            )
            let errorDescription = errorsByChangeID[change.id]
            let status: ChangeItemResult.Status

            if actual?.stableID == change.targetHandler.stableID {
                status = .verified
            } else if errorDescription != nil {
                status = .failed
            } else {
                status = .notApplied
            }

            return ChangeItemResult(
                change: change,
                status: status,
                errorDescription: errorDescription
            )
        }

        return ChangeReport(sourcePlan: plan, results: results)
    }
}
