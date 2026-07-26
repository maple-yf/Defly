import Foundation

@MainActor
public struct ChangePlanner {
    private let workspace: WorkspaceClient

    public init(workspace: WorkspaceClient) {
        self.workspace = workspace
    }

    public func makePlan(
        associations: [AssociationID],
        target: HandlerApplication
    ) -> ChangePlan {
        let unique = Dictionary(
            associations.map { ($0.stableKey, $0) },
            uniquingKeysWith: { current, _ in current }
        )

        let changes = unique.values
            .sorted { $0.stableKey < $1.stableKey }
            .compactMap { association -> PlannedChange? in
                let current = workspace.defaultApplication(
                    for: association
                )
                guard current?.stableID != target.stableID else {
                    return nil
                }

                let isCandidate = workspace
                    .candidateApplications(for: association)
                    .contains { $0.stableID == target.stableID }

                return PlannedChange(
                    association: association,
                    previousHandler: current,
                    targetHandler: target,
                    compatibility: isCandidate
                        ? .systemCandidate
                        : .manuallySelected
                )
            }

        return ChangePlan(changes: changes)
    }
}
